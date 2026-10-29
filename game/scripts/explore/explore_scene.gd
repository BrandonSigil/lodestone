extends Node2D
## Walk a big map: the party leader is the one piece on the map (the rest travel with them, unseen).
## Fog of war past what the leader can see, enemy groups that spot you, and things to use (doors, chests)
## with options that depend on who is in the party.
## A fight breaks out in place: first the party deploys around the leader (quick members may start
## further out, heavy ones at the leader's side), then the same board becomes the battlefield.
## F6 on explore.tscn, or F10 from any screen. The map is Game.explore_map (data/explore/<name>.json).
##
## Controls: WASD (free, not cell by cell) or click ground = walk. Click a thing = walk up and use it.
## F = use the nearest lit thing. Arrows or right drag = look around, wheel = zoom,
## Space = back to the leader. The view never turns ([USER] 2026-10-28: one approved angle per map). Hover an enemy to see what it can see.

enum M { WALK, BUSY, DIALOG, DEPLOY, FIGHT, OVER }

const CLIMB_RATE := 10.0  ## levels a second the leader's feet follow the ground on keys
const ZOOM_START := 1.35  ## [USER] 2026-10-29: close in; what's on screen is what the party gets
const ZOOM_MIN := 1.0
const ZOOM_MAX := 1.8
const PAN_SPEED := 700.0
const PATH_COLOR := Color(1.0, 1.0, 1.0, 0.16)
const GOAL_COLOR := Color(0.4, 0.75, 1.0, 0.45)
const WATCH_COLOR := Color(1.0, 0.35, 0.3, 0.22)  ## cells a hovered enemy group can see
const DEPLOY_COLOR := Color(0.35, 0.6, 1.0, 0.35)  ## where the picked member may start the fight

var map: ExploreMap
var grid: CombatGrid
var board: CombatBoard
var overlay: ExploreOverlay
var hud: FrameHud
var party: Array = []  ## CombatUnit, leader first; only the leader stands on the map outside fights
## {"def": the map's group dict, "units": Array of CombatUnit, "state": idle / noticed / calm / fighting / gone}
var groups: Array[Dictionary] = []
var things: Array[Dictionary] = []  ## the map's things plus "done"
var seen := {}  ## every cell the party has ever had in sight
var in_sight := {}  ## cells in sight now
var locked := {}  ## cells behind a shut door or rubble: left undrawn until the way opens
var _reached := {}  ## every cell the party could walk to so far
var mode := M.WALK
var battle: Battle
var zoom := ZOOM_START
var focus := Vector2.ZERO  ## grid point the camera centres on (unturned grid coords, so the camera turn keeps it)
var focus_h := 0.0  ## height of that point
var follow := true  ## the camera follows the leader until the player pans
var walking_now := false

var _walk_token := 0
var _stepping := false
var _drag := false
var _ui: CanvasLayer
var _dialog: PanelContainer
var _info: Label
var _log_label: Label
var _phase: Label
var _keys_walking := false  ## the leader is walking on WASD
var _menu_open := false  ## the pack or the Lodestone menu is the open dialog
## Deploying: the fight waiting to start, the member being placed and the cells it may take.
var _pending := {}
var _placing: CombatUnit = null
var _ring: Array[Vector2i] = []


func _ready() -> void:
	Game.ensure_run()
	Game.refresh_party()
	map = ExploreMap.load_named(Game.explore_map)
	grid = map.grid
	board = CombatBoard.new()
	board.grid = grid
	board.strangeness = map.strangeness
	board.art_set = map.art_set
	board.rot = map.view
	board.fog_on = fogged()
	board.walls = map.walls
	board.show_grid = false
	board.backdrop = true  # the map's look: sky, mountains and forest for valley looks, a dark floor indoors
	# Outdoors, the painted look's staging (as in the map maker and fights): the set's skyline fixed behind
	# the view and a solid foreground band. Interiors keep their dark floor.
	board.wallpaper = MapLook.resolve(grid.look, map.art_set, map.strangeness).staging != "plain"
	add_child(board)
	overlay = ExploreOverlay.new()
	overlay.scene = self
	board.add_child(overlay)
	board.cell_clicked.connect(_on_cell_clicked)
	board.cell_hovered.connect(_on_cell_hovered)
	board.rotated.connect(_on_rotated)

	var start := _free_start()
	for m in Game.run.alive():
		var u := CombatUnit.from_member(m)
		u.place(start, grid.height_at(start))
		party.append(u)
	for g in map.groups:
		var units: Array = []
		for e: Dictionary in g.units:
			var cls := Db.class_def(e.id)
			if cls == null or not grid.passable(e.cell):
				continue
			var u := CombatUnit.enemy(cls)
			u.place(e.cell, grid.height_at(e.cell))
			units.append(u)
		groups.append({"def": g, "units": units, "state": "idle"})
	var memory: Dictionary = Game.explore_memory.get(map.map_name, {})
	seen = memory.get("seen", {}).duplicate()
	# Groups beaten or calmed before the party stepped through a door stay that way (Brandon's E2E notes).
	var settled: Dictionary = memory.get("groups", {})
	for g in groups:
		if settled.has(String(g.def.id)):
			g.state = settled[String(g.def.id)]
	var done_before: Array = memory.get("done", [])
	for t in map.things:
		var copy := t.duplicate()
		copy["done"] = done_before.has(t.id) or _once_done(t)
		things.append(copy)
		if copy.done and t.kind in ["door", "rubble"]:
			grid.set_terrain(t.cell, _letter_terrain(String(t.floor)))
		elif t.kind == "door" or t.kind == "rubble":
			grid.set_terrain(t.cell, CombatGrid.T.RUIN)  # shut until opened
	if map.walls:  # after the doors shut, so no front edge opens a way round one
		var shaped := ExploreRules.shape_walls(grid, [board.front_dir(false), board.front_dir(true)], map.outdoors)
		board.wall_cells = shaped.walls
		board.rims = shaped.rims

	hud = FrameHud.new()
	add_child(hud)
	_ui = CanvasLayer.new()
	_ui.layer = 4
	add_child(_ui)
	_walk_side()
	_refresh_locked()
	_refresh_sight()
	_refresh_units()
	_refresh_hud()
	var lead := leader()
	if lead:
		_snap_to(lead)
	if not Game.pending_lines.is_empty():
		_show_pending()
	elif lead:
		check_groups(true)  # stepping in beside a group: the party gets the first look, not an ambush
		_refresh_units()


## Lines left for this screen (waking in the square after a fall, GO HOME).
func _show_pending() -> void:
	if Game.pending_lines.is_empty():
		return
	var text := "\n".join(Game.pending_lines)
	Game.pending_lines = []
	mode = M.DIALOG
	var box := _new_dialog(text)
	_dialog_button(box, Txt.t("UI_CONTINUE"), func() -> void:
		_close_dialog()
		mode = M.WALK)


# --- queries the overlay and tests use ------------------------------------------------

func leader() -> CombatUnit:
	return party[0] if not party.is_empty() else null


func walking() -> bool:
	return mode == M.WALK


func party_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for u: CombatUnit in party:
		out.append(u.cell)
	return out


func thing_at(c: Vector2i) -> Dictionary:
	for t in things:
		if not t.done and t.cell == c and shown(t):
			return t
	return {}


func group_at(c: Vector2i) -> Dictionary:
	for g in groups:
		if g.state == "gone":
			continue
		for u: CombatUnit in g.units:
			if u.alive() and u.cell == c:
				return g
	return {}


func _group_cells(g: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for u: CombatUnit in g.units:
		if u.alive():
			out.append(u.cell)
	return out


## Cells the party can't walk into: enemies and things (doors and rubble are ruin terrain while shut).
func _blocked() -> Dictionary:
	var out := {}
	for g in groups:
		if g.state != "gone":
			for c in _group_cells(g):
				out[c] = true
	for t in things:
		if not t.done:
			out[t.cell] = true
	return out


func _free_start() -> Vector2i:
	var from: Vector2i = map.start[0] if not map.start.is_empty() else Vector2i.ZERO
	if grid.in_bounds(Game.explore_entry):
		from = Game.explore_entry
	Game.explore_entry = Vector2i(-1, -1)
	for r in range(0, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := from + Vector2i(dx, dy)
				if grid.passable(c):
					return c
	return from


# --- camera -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if board == null:
		return
	var pan := Vector2.ZERO
	_wasd(delta)
	if Input.is_key_pressed(KEY_LEFT):
		pan.x -= 1
	if Input.is_key_pressed(KEY_RIGHT):
		pan.x += 1
	if Input.is_key_pressed(KEY_UP):
		pan.y -= 1
	if Input.is_key_pressed(KEY_DOWN):
		pan.y += 1
	if pan != Vector2.ZERO:
		follow = false
		focus += _screen_to_grid(pan.normalized() * PAN_SPEED * delta / zoom)
	var lead := leader()
	if follow and lead != null:
		var t := minf(1.0, delta * 8.0)
		focus = focus.lerp(Vector2(lead.vis) + Vector2(0.5, 0.5), t)
		focus_h = lerpf(focus_h, lead.vis_h, t)
	_apply_camera()


## Centre the camera on a unit's ground point at once (no glide).
func _snap_to(u: CombatUnit) -> void:
	focus = Vector2(u.vis) + Vector2(0.5, 0.5)
	focus_h = u.vis_h


## Q turns the view about the party: while the camera follows the leader, the leader stays in the middle.
## Otherwise the turn keeps the same grid point in the middle (a fight, or after the player panned).
func _on_rotated() -> void:
	if mode == M.WALK and leader() != null:
		follow = true
		_snap_to(leader())


## A screen move (pixels at zoom 1) as the same move across the grid at the current camera turn.
func _screen_to_grid(d: Vector2) -> Vector2:
	var o := board.iso(0.0, 0.0, 0.0)
	var ex := board.iso(1.0, 0.0, 0.0) - o
	var ey := board.iso(0.0, 1.0, 0.0) - o
	var det := ex.x * ey.y - ey.x * ex.y
	return Vector2((d.x * ey.y - ey.x * d.y) / det, (ex.x * d.y - ex.y * d.x) / det)


## WASD walks the leader freely toward the held screen direction (W = up the screen), sliding along walls
## and easing round corners (ExploreRules.slide). Crossing into a new cell checks sight and enemies, as a
## step along a clicked path does.
func _wasd(delta: float) -> void:
	var want := Vector2.ZERO
	if mode == M.WALK:
		if Input.is_key_pressed(KEY_W):
			want.y -= 1
		if Input.is_key_pressed(KEY_S):
			want.y += 1
		if Input.is_key_pressed(KEY_A):
			want.x -= 1
		if Input.is_key_pressed(KEY_D):
			want.x += 1
	var lead := leader()
	if want == Vector2.ZERO or lead == null:
		if _keys_walking:
			_keys_walking = false
			if lead:
				board.play_anim(lead, "idle")
		return
	if _stepping:
		_walk_token += 1  # keys take over from a clicked path once its current step lands
		return
	walking_now = false
	if not _keys_walking:
		_keys_walking = true
		_walk_token += 1
		board.play_anim(lead, "walk")
		board.highlights = {}
	follow = true
	var dir := _screen_to_grid(want).normalized()
	var at := lead.vis + Vector2(0.5, 0.5)
	var to := ExploreRules.slide(grid, at, dir * ExploreRules.WALK_SPEED * delta, ExploreRules.BODY, lead.jump, _blocked())
	lead.facing = Vector2i(roundi(dir.x), roundi(dir.y))
	lead.vis = to - Vector2(0.5, 0.5)
	var cell := Vector2i(to.floor())
	lead.vis_h = move_toward(lead.vis_h, float(grid.height_at(cell)), CLIMB_RATE * delta)
	if cell != lead.cell:
		lead.cell = cell
		if _after_step():
			_keys_walking = false
			board.play_anim(leader(), "idle")


func _apply_camera() -> void:
	var r := hud.center_rect()
	var centre := board.iso(focus.x, focus.y, focus_h)
	board.scale = Vector2.ONE * zoom
	board.position = r.get_center() - centre * zoom
	board.view_rect = r
	# Only cells near the play area get drawn; tall cells hang below their top, so the bottom margin is deep.
	var local := Rect2((r.position - board.position) / zoom, r.size / zoom)
	board.cull = local.grow_individual(CombatBoard.TW, CombatBoard.TH * 2, CombatBoard.TW, CombatBoard.HS * 10)
	if battle:
		battle.layout(r)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = clampf(zoom * 1.1, ZOOM_MIN, ZOOM_MAX)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = clampf(zoom / 1.1, ZOOM_MIN, ZOOM_MAX)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE or (mb.button_index == MOUSE_BUTTON_RIGHT and mode != M.FIGHT):
			_drag = mb.pressed
	elif event is InputEventMouseMotion and _drag:
		follow = false
		focus -= _screen_to_grid((event as InputEventMouseMotion).relative / zoom)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.is_echo():
		return
	match event.keycode:
		KEY_SPACE:
			follow = true
		KEY_ENTER:
			if mode == M.DEPLOY:
				_begin_battle()
		KEY_F:
			if mode == M.WALK:
				var t := _nearest_thing()
				if not t.is_empty():
					_go_use(t)


func _nearest_thing() -> Dictionary:
	var lead := leader()
	var best := {}
	var best_d := INF
	for t in things:
		if t.done or not in_sight.has(t.cell) or not shown(t):
			continue
		var d := ExploreRules.dist(lead.cell, t.cell)
		if d <= ExploreRules.HINT_RANGE and d < best_d:
			best = t
			best_d = d
	return best


# --- sight -------------------------------------------------------------------------------

func _refresh_sight() -> void:
	var eyes: Array = party_cells() if mode == M.FIGHT else [leader().cell]
	# Sight is who the party can spot, fog or not; without fog the whole map counts as seen and is drawn lit.
	in_sight = ExploreRules.sight(grid, eyes, ExploreRules.PARTY_SIGHT)
	if not fogged():
		for c in _every_cell():
			seen[c] = true
		var lit := {}
		for c in seen:
			if not locked.has(c):
				lit[c] = 2
		board.fog = lit
		return
	for c in in_sight:
		seen[c] = true
	var fog := {}
	for c in seen:
		if not locked.has(c):
			fog[c] = 2 if in_sight.has(c) else 1
	board.fog = fog


## Work out which rooms are still behind a shut door or rubble. On arrival and when a way opens.
func _refresh_locked() -> void:
	var doors: Array[Vector2i] = []
	for t in things:
		if not t.done and (t.kind == "door" or t.kind == "rubble"):
			doors.append(t.cell)
	var jump: int = leader().jump if leader() else 1
	_reached.merge(ExploreRules.reach(grid, party_cells(), jump))
	locked = ExploreRules.locked_cells(grid, _reached, doors, jump)
	board.fog_on = fogged() or not locked.is_empty()


## Fog of war on this map: the map asks for it and the switch is on (it is off for now, ExploreRules.FOG_OF_WAR).
func fogged() -> bool:
	return map.fog and ExploreRules.FOG_OF_WAR


## Every cell of the map, for maps without fog of war.
func _every_cell() -> Dictionary:
	var all := {}
	for y in grid.h:
		for x in grid.w:
			all[Vector2i(x, y)] = true
	return all


## Out of a fight the board shows the leader and the enemies in sight; in a fight, every fighter.
func _refresh_units() -> void:
	if mode == M.FIGHT or mode == M.DEPLOY:
		return
	var shown: Array = [leader()]
	for g in groups:
		if g.state == "gone":
			continue
		for u: CombatUnit in g.units:
			if u.alive() and (in_sight.has(u.cell) or not fogged()) and not locked.has(u.cell):
				shown.append(u)
	board.units = shown


func _reveal_around(cells: Array, r: int) -> void:
	for c: Vector2i in cells:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if grid.in_bounds(n):
					seen[n] = true
	_refresh_sight()


# --- walking ------------------------------------------------------------------------------

func _on_cell_clicked(c: Vector2i, right: bool) -> void:
	if mode == M.DEPLOY and not right and c != CombatBoard.NONE:
		_on_deploy_click(c)
		return
	if mode != M.WALK or right or c == CombatBoard.NONE:
		return
	var t := thing_at(c)
	if not t.is_empty():
		_go_use(t)
		return
	if not group_at(c).is_empty():
		return
	var lead := leader()
	var path := ExploreRules.find_path(grid, lead.cell, c, leader().jump, _blocked(), seen, true)
	if path.size() < 2:
		board.float_text(c, Txt.t("UI_EX_NO_WAY"), Color(0.9, 0.8, 0.7))
		return
	follow = true
	walk(path)


func _go_use(t: Dictionary) -> void:
	var lead := leader()
	var path := ExploreRules.path_to_use(grid, lead.cell, t.cell, leader().jump, _blocked(), seen, true)
	if path.is_empty():
		board.float_text(t.cell, Txt.t("UI_EX_NO_WAY"), Color(0.9, 0.8, 0.7))
		return
	follow = true
	if path.size() == 1:
		_open_thing(t)
	else:
		walk(path, t)


## Walk the leader along path (path[0] is where the leader stands), gliding at an even pace.
## Stops early when something happens. A new walk cancels the one in progress after its current step.
func walk(path: Array[Vector2i], then_use := {}) -> void:
	_walk_token += 1
	var token := _walk_token
	while _stepping:
		await get_tree().process_frame
	if token != _walk_token or mode != M.WALK:
		return
	board.highlights = {}
	walking_now = true
	var lead := leader()
	board.play_anim(lead, "walk")
	var stopped := false
	var spare := 0.0  # distance left over from the frame that finished the last step
	_stepping = true
	for i in range(maxi(path.find(lead.cell), 0) + 1, path.size()):
		if token != _walk_token or mode != M.WALK:
			stopped = true
			break
		var next: Vector2i = path[i]
		if _blocked().has(next):
			stopped = true
			break
		spare = await _glide(lead, next, spare)
		if _after_step():
			stopped = true
			break
	_stepping = false
	if token != _walk_token:
		return  # a newer walk took over
	walking_now = false
	board.play_anim(lead, "idle")
	if not stopped and not then_use.is_empty() and mode == M.WALK and ExploreRules.can_use_from(grid, leader().cell, then_use.cell):
		_open_thing(then_use)


## Move a piece from where it stands into cell `to` at walking speed, frame by frame: no bob on flat ground,
## a small hop where the ground changes height. Returns the distance this frame had left after arriving.
func _glide(u: CombatUnit, to: Vector2i, spare: float) -> float:
	var from := u.vis
	var from_h := u.vis_h
	var to_h := float(grid.height_at(to))
	var length := maxf(0.01, from.distance_to(Vector2(to)))
	var rise := absf(to_h - from_h)
	if to != u.cell:
		u.facing = to - u.cell
	var gone := spare
	while gone < length:
		await get_tree().process_frame
		gone += get_process_delta_time() * ExploreRules.WALK_SPEED
		var t := minf(1.0, gone / length)
		u.vis = from.lerp(Vector2(to), t)
		u.vis_h = lerpf(from_h, to_h, t)
		u.hop = sin(t * PI) * rise * CombatBoard.HS * 0.6 if rise > 0.01 else 0.0
	u.hop = 0.0
	u.place(to, grid.height_at(to))
	return minf(gone - length, 0.5)


## After each step: update the fog, then see who spotted whom. True when the walk must stop.
func _after_step() -> bool:
	_refresh_sight()
	var spotted := check_groups()
	_refresh_units()
	return spotted


## A group that sees the party attacks (they move first). A group the party sees first stops the walk
## and asks what to do. Returns true when either happened.
## arriving: the party just came through a door, so a group that sees it asks first instead of attacking.
func check_groups(arriving := false) -> bool:
	var cells := [leader().cell]
	for g in groups:
		if g.state != "idle" and g.state != "noticed":
			continue
		var gc := _group_cells(g)
		if gc.is_empty():
			continue
		if not arriving and ExploreRules.sees(grid, gc, cells, int(g.def.sight)):
			board.float_text(leader().cell, Txt.t("UI_EX_SPOTTED"), Color(1.0, 0.5, 0.4))
			start_fight(g, "ambushed")
			return true
		var visible := gc.any(func(c: Vector2i) -> bool: return in_sight.has(c))
		if arriving:
			visible = visible or ExploreRules.sees(grid, gc, cells, int(g.def.sight))
		if visible and g.state == "idle":
			g.state = "noticed"
			open_event(String(g.def.event), {"group": g})
			return true
		if not visible and g.state == "noticed":
			g.state = "idle"  # out of sight again: the next sighting asks again
	return false


# --- hover ---------------------------------------------------------------------------------

func _on_cell_hovered(c: Vector2i) -> void:
	if mode != M.WALK:
		return
	board.highlights = {}
	if c == CombatBoard.NONE:
		return
	var g := group_at(c)
	if not g.is_empty() and (in_sight.has(c) or not fogged()) and not locked.has(c):
		for s in ExploreRules.sight(grid, _group_cells(g), int(g.def.sight)):
			if seen.has(s):
				board.highlights[s] = WATCH_COLOR
		_info.text = _enemy_text(g)
		return
	var t := thing_at(c)
	if not t.is_empty():
		_info.text = Txt.t("EX_KIND_" + String(t.kind).to_upper())
		return
	_info.text = "%s  H%d" % [CombatGrid.T.keys()[grid.terrain_at(c)], grid.height_at(c)]
	if walking_now:
		return
	var path := ExploreRules.find_path(grid, leader().cell, c, leader().jump, _blocked(), seen, true)
	for p in path.slice(1):
		board.highlights[p] = PATH_COLOR
	if path.size() > 1:
		board.highlights[c] = GOAL_COLOR


func _enemy_text(g: Dictionary) -> String:
	var names: PackedStringArray = []
	for u: CombatUnit in g.units:
		if u.alive():
			names.append("%s  HP %d" % [Txt.t(u.name_key), u.hp])
	if g.state == "calm":
		names.append(Txt.t("UI_EX_PACIFIED"))
	return "\n".join(names)


# --- things and choices -----------------------------------------------------------------------

func _open_thing(t: Dictionary) -> void:
	if t.done or mode != M.WALK or not shown(t):
		return
	if t.kind == "enter" and String(t.event) == "":
		_travel(t)  # a plain doorway: no box, just go through
		return
	open_event(String(t.event), {"thing": t})


## A hidden thing shows (and can be used) only once the leader stands next to it. A thing with a "when"
## flag shows only once that flag is set (the dog's door opens from inside once he is out).
func shown(t: Dictionary) -> bool:
	if String(t.get("when", "")) != "" and not Game.has_flag(t.when):
		return false
	return t.kind != "hidden" or ExploreRules.dist(leader().cell, t.cell) <= 1.5


## Gone for good: one of the thing's once flags is set (the book was taken, a smithy weapon was picked).
func _once_done(t: Dictionary) -> bool:
	for f in String(t.get("once", "")).split("|", false):
		if Game.has_flag(f):
			return true
	return false


func _letter_terrain(letter: String) -> int:
	for key in CombatGrid.LETTERS:
		if CombatGrid.LETTERS[key] == letter:
			return key
	return CombatGrid.T.STONE


## Walk through a door into another map (a house, back out to the street). This map is remembered.
func _travel(t: Dictionary) -> void:
	var done: Array = []
	for x in things:
		if x.done:
			done.append(x.id)
	var settled := {}
	for g in groups:
		if g.state == "gone" or g.state == "calm":
			settled[String(g.def.id)] = g.state
	Game.explore_memory[map.map_name] = {"seen": seen.duplicate(), "done": done, "groups": settled}
	mode = M.OVER
	Game.explore_map = String(t.to)
	Game.explore_entry = t.at
	Game.go(Game.EXPLORE)


## Show an event from data/explore_events.csv with the options this party has.
func open_event(id: String, ctx: Dictionary) -> void:
	var ev: Dictionary = Db.explore_events.get(id, {})
	if ev.is_empty():
		push_warning("no explore event '%s'" % id)
		return
	mode = M.DIALOG
	walking_now = false
	board.highlights = {}
	var box := _new_dialog(Txt.t(ev.text_key))
	for o: Dictionary in ExploreRules.options_for(ev, _defs(), {"items": Game.run.items, "flags": Game.meta.flags}):
		var label := Txt.t(o.key)
		if o.check != "none":
			var who: Dictionary = TrailRules.best_member(Game.run, o.check)
			var bonus := TrailRules.party_bonus(Game.run, o.check)
			label += "      " + Txt.f("UI_EX_CHANCE", [Txt.t((who.def as CharacterDef).name_key), Txt.t("CHECK_" + String(o.check).to_upper()),
				bonus, int(round(Dice.chance(bonus, o.dc) * 100))])
		_dialog_button(box, label, choose.bind(o, ctx))


func _defs() -> Array:
	return Game.run.alive().map(func(m: Dictionary) -> CharacterDef: return m.def)


## Roll the option's check (if any), apply what happens to the run, show the roll, then the map effects.
func choose(o: Dictionary, ctx: Dictionary) -> void:
	var success := true
	var lines: PackedStringArray = []
	if o.check != "none":
		var r := TrailRules.roll(Game.run, o.check, o.dc)
		success = r.success
		var who: Dictionary = TrailRules.best_member(Game.run, o.check)
		lines.append("%s  %s  %s" % [Txt.t((who.def as CharacterDef).name_key), Txt.t("CHECK_" + String(o.check).to_upper()), Dice.describe(r)])
		lines.append(Txt.t("UI_EX_WIN") if success else Txt.t("UI_EX_LOSE"))
		_log(lines[0])
	var fx := ExploreRules.split_effects(o.win if success else o.lose)
	if fx.run != "":
		var out := TrailRules.apply_effects(Game.run, fx.run)
		Game.absorb(out.unlocks)
		_after_change()
		for f: String in out.unlocks:
			if Txt.has("UI_GOT_" + f.to_upper()):
				lines.append(Txt.t("UI_GOT_" + f.to_upper()))  # the dog joins, the Lodestone is taken
		lines.append(fx.run.replace(";", "  "))
	if Game.run.wiped():
		# A trap took the last one standing: the run ends as a lost fight does.
		lines.append(Txt.t("UI_DEFEAT"))
		mode = M.OVER
		_dialog_button(_new_dialog("\n".join(lines)), Txt.t("UI_CONTINUE"), func() -> void: Game.recall())
		return
	if lines.is_empty():
		_close_dialog()
		_apply_map_fx(fx.map, ctx)
		return
	var box := _new_dialog("\n".join(lines))
	_dialog_button(box, Txt.t("UI_CONTINUE"), func() -> void:
		_close_dialog()
		_apply_map_fx(fx.map, ctx))


func _apply_map_fx(list: Array, ctx: Dictionary) -> void:
	var t: Dictionary = ctx.get("thing", {})
	var g: Dictionary = ctx.get("group", {})
	mode = M.WALK
	for k: String in list:
		match k:
			"open":
				grid.set_terrain(t.cell, _letter_terrain(String(t.floor)))
				t.done = true
			"remove":
				t.done = true
			"reveal":
				for y in grid.h:
					for x in grid.w:
						seen[Vector2i(x, y)] = true
				board.float_text(leader().cell, Txt.t("UI_EX_REVEAL"), Color(0.8, 0.85, 1.0))
			"pacify":
				g.state = "calm"
				board.float_text(_group_cells(g)[0], Txt.t("UI_EX_PACIFIED"), Color(0.7, 1.0, 0.7))
			"fight":
				start_fight(g, "party")
			"sneak_attack":
				start_fight(g, "sneak")
			"ambushed":
				start_fight(g, "ambushed")
			"noise":
				var at: Vector2i = t.cell if not t.is_empty() else leader().cell
				board.float_text(at, Txt.t("UI_EX_NOISE"), Color(1.0, 0.75, 0.4))
				var near := _nearest_group(at, ExploreRules.NOISE_RANGE)
				if not near.is_empty():
					start_fight(near, "ambushed")
			"exit":
				_finish_map()
			"travel":
				_travel(t)
	if mode == M.WALK:
		if "open" in list:
			_refresh_locked()
		_refresh_sight()
		_refresh_units()
		check_groups(true)  # right after a choice (BACK OFF included) nobody pounces before the party moves
		_refresh_units()


func _nearest_group(at: Vector2i, within: float) -> Dictionary:
	var best := {}
	var best_d := within
	for g in groups:
		if g.state != "idle" and g.state != "noticed":
			continue
		for c in _group_cells(g):
			var d := ExploreRules.dist(at, c)
			if d <= best_d:
				best = g
				best_d = d
	return best


## After anything that changes the party: someone joined, a level, a Lodestone pick, a potion.
func _after_change() -> void:
	Game.refresh_party()
	_rebuild_party()
	_sync_party_hp()
	_refresh_hud()


## Party pieces rebuilt from the run (new members, new stats). They stand with the leader. Not mid-fight.
func _rebuild_party() -> void:
	if mode == M.FIGHT or mode == M.DEPLOY or Game.run.wiped():
		return  # a wiped party keeps its fallen pieces until the run ends
	var lead := leader()
	var at: Vector2i = lead.cell if lead else _free_start()
	var facing: Vector2i = lead.facing if lead else Vector2i(1, 0)
	party = []
	for m in Game.run.alive():
		var u := CombatUnit.from_member(m)
		u.place(at, grid.height_at(at))
		u.facing = facing
		party.append(u)
	_refresh_units()


func _sync_party_hp() -> void:
	for u: CombatUnit in party:
		u.hp = clampi(int(u.member.hp), 0, u.max_hp)
		u.shown_hp = u.hp


func _new_dialog(text: String, top := false) -> VBoxContainer:
	if _dialog:
		_dialog.queue_free()
	_dialog = PanelContainer.new()
	_dialog.add_theme_stylebox_override("panel", Battle._panel_style(Color(0.1, 0.12, 0.12, 0.96)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_dialog.add_child(box)
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(420, 0)
	l.add_theme_font_size_override("font_size", 16)
	box.add_child(l)
	_ui.add_child(_dialog)
	var r := hud.center_rect()
	_dialog.position = Vector2(r.get_center().x - 220, r.position.y + 16 if top else r.end.y - 230)
	if text == "":
		l.queue_free()
	return box


func _dialog_button(box: VBoxContainer, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(420, 30)
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(cb)
	box.add_child(b)


func _close_dialog() -> void:
	if _dialog:
		_dialog.queue_free()
		_dialog = null


# --- fights -----------------------------------------------------------------------------------

## A fight on this very map. how: "party" (the party moves first), "sneak" (party first, the group
## sleeps through its first phase and everyone may deploy a step further), "ambushed" (the enemy moves
## first and everyone starts at the leader's side). Groups close by join in.
## The party deploys first: everyone but the leader gets a spot around the leader.
func start_fight(g: Dictionary, how: String) -> void:
	_walk_token += 1
	walking_now = false
	_close_dialog()
	board.play_anim(leader(), "idle")
	var foes: Array[Dictionary] = [g]
	for o in groups:
		if o == g or (o.state != "idle" and o.state != "noticed"):
			continue
		for a in _group_cells(o):
			if _group_cells(g).any(func(b: Vector2i) -> bool: return ExploreRules.dist(a, b) <= ExploreRules.JOIN_RANGE):
				foes.append(o)
				break
	var enemies: Array = []
	for f in foes:
		f.state = "fighting"
		for u: CombatUnit in f.units:
			if u.alive():
				enemies.append(u)
				if how == "sneak" and f == g:
					u.statuses[CombatRules.STATUS_SLEEP] = 1
	_pending = {"how": how, "foes": foes, "enemies": enemies, "spots": ExploreRules.auto_deploy(grid, party, how, _blocked())}
	mode = M.DEPLOY
	board.highlights = {}
	board.show_grid = true  # the grid is for fights only
	_reveal_around(enemies.map(func(u: CombatUnit) -> Vector2i: return u.cell), 1)
	_reveal_around([leader().cell], 4)
	for u: CombatUnit in party:
		if _pending.spots.has(u):
			u.place(_pending.spots[u], grid.height_at(_pending.spots[u]))
	_show_deployed()
	follow = false
	var sum := Vector2.ZERO
	var heights := 0.0
	var fighters := _deployed() + enemies
	for u: CombatUnit in fighters:
		sum += Vector2(u.cell) + Vector2(0.5, 0.5)
		heights += grid.height_at(u.cell)
	focus = sum / fighters.size()
	focus_h = heights / fighters.size()
	if how == "ambushed":
		board.float_text(leader().cell, Txt.t("UI_EX_SPOTTED"), Color(1.0, 0.5, 0.4))
	if Battle.auto_fight:
		_begin_battle()  # testing: the auto placement stands and the fight plays itself
		return
	_deploy_side()
	_pick_member(party[1] if party.size() > 1 else null)


## Party members with a starting spot (the leader always has one).
func _deployed() -> Array:
	return party.filter(func(u: CombatUnit) -> bool: return _pending.spots.has(u))


func _show_deployed() -> void:
	board.units = _deployed() + _pending.enemies


## Pick which member to place next; their ring lights up.
func _pick_member(u: CombatUnit) -> void:
	_placing = u
	board.selected = u
	board.highlights = {}
	_ring = []
	if u == null:
		return
	var others := _blocked()
	for o: CombatUnit in _deployed():
		if o != u:
			others[o.cell] = true
	_ring = ExploreRules.deploy_cells(grid, leader().cell, u, ExploreRules.deploy_radius(u, _pending.how), _blocked())
	for c in _ring:
		if not others.has(c):
			board.highlights[c] = DEPLOY_COLOR
	_info.text = "%s\n%s %d" % [Txt.t(u.name_key), Txt.t("UI_EX_DEPLOY_RANGE"), ExploreRules.deploy_radius(u, _pending.how)]


func _on_deploy_click(c: Vector2i) -> void:
	var on: CombatUnit = null
	for o: CombatUnit in _deployed():
		if o.cell == c:
			on = o
	if on != null and on != leader():
		_pick_member(on)
		return
	if _placing == null or not board.highlights.has(c):
		return
	_pending.spots[_placing] = c
	_placing.place(c, grid.height_at(c))
	_show_deployed()
	# Move on to the next member, round and round.
	var i := party.find(_placing)
	_pick_member(party[1 + i % (party.size() - 1)] if party.size() > 1 else null)


func _begin_battle() -> void:
	var how: String = _pending.how
	var units: Array = _deployed() + _pending.enemies
	board.highlights = {}
	board.selected = null
	mode = M.FIGHT
	battle = Battle.new()
	add_child(battle)
	battle.setup(grid, units, Game.run.rng.randi(), map.strangeness, {"medicine": Game.run.medicine, "food": Game.run.food}, board)
	battle.log_line.connect(_log)
	battle.info.connect(func(text: String) -> void: _info.text = text)
	battle.phase_changed.connect(func(team: int) -> void:
		_phase.text = Txt.t("UI_PLAYER_PHASE") if team == 0 else Txt.t("UI_ENEMY_PHASE"))
	battle.changed.connect(_on_fight_changed)
	battle.finished.connect(_on_fight_over.bind(_pending.foes))
	_fight_side()
	battle.layout(hud.center_rect())
	battle.start(how == "ambushed")


func _on_fight_changed() -> void:
	_refresh_sight()
	_reveal_around(battle.units.filter(func(u: CombatUnit) -> bool: return u.team == 1 and u.alive()).map(func(u: CombatUnit) -> Vector2i: return u.cell), 1)
	Game.run.medicine = int(battle.supplies.get("medicine", Game.run.medicine))
	Game.run.food = int(battle.supplies.get("food", Game.run.food))
	_refresh_hud()


func _on_fight_over(won: bool, foes: Array) -> void:
	for u: CombatUnit in party:
		u.member.hp = u.hp
	var box := _new_dialog(Txt.t("UI_VICTORY") if won else Txt.t("UI_DEFEAT"))
	if not won:
		_dialog_button(box, Txt.t("UI_CONTINUE"), func() -> void: Game.recall())
		mode = M.OVER
		return
	var downed := 0
	var boss := false
	var ends := false
	for f: Dictionary in foes:
		f.state = "gone"
		downed += f.units.size()
		boss = boss or bool(f.def.get("boss", false))
		ends = ends or bool(f.def.get("end", false))
		if f.def.loot != "":
			var out := TrailRules.apply_effects(Game.run, f.def.loot)
			Game.absorb(out.unlocks)
	for u: CombatUnit in party:
		u.member.hp = maxi(1, u.hp)  # downed members get back up after a win
	var xp := LevelRules.fight_xp(downed, boss, Db.levels)
	var lines := Game.award_xp(xp)
	lines.insert(0, Txt.f("UI_XP_GAIN", xp))
	_sync_party_hp()
	_refresh_hud()
	if ends:
		# The boss is down: the end of the E2E test.
		Game.set_flag("e2e_done")
		box = _new_dialog("%s\n%s\n\n%s" % [Txt.t("UI_VICTORY"), "\n".join(lines), Txt.t("UI_E2E_DONE")])
		_dialog_button(box, Txt.t("UI_E2E_WAKE"), func() -> void: Game.wake_in_town(false))
		_dialog_button(box, Txt.t("UI_E2E_LAUNCH"), func() -> void: Game.go(Game.LAUNCH))
		mode = M.OVER
		return
	box = _new_dialog("%s\n%s" % [Txt.t("UI_VICTORY"), "\n".join(lines)])
	_dialog_button(box, Txt.t("UI_CONTINUE"), _end_fight)


func _end_fight() -> void:
	_close_dialog()
	if battle:
		battle.queue_free()
		battle = null
	board.highlights = {}
	board.danger = {}
	board.area = {}
	board.selected = null
	board.show_grid = false
	for u: CombatUnit in party:
		u.moved = false
		u.acted = false
		u.spooked = false
		u.statuses.clear()
		u.cooldowns.clear()
	# The others fall back in with the leader, who walks on alone.
	var lead := leader()
	for u: CombatUnit in party:
		if u != lead:
			u.place(lead.cell, grid.height_at(lead.cell))
	_pending = {}
	mode = M.WALK
	follow = true
	_rebuild_party()  # levels from the fight show up in the pieces' stats
	_walk_side()
	_refresh_sight()
	_refresh_units()


## Out the way out: onto the overworld, standing at the place this map belongs to.
func _finish_map() -> void:
	mode = M.OVER
	Game.explore_memory.clear()
	Game.travel = {"at": TravelRules.node_for_map(Db.world_nodes, map.map_name)}
	Game.go(Game.OVERWORLD)


# --- hud ----------------------------------------------------------------------------------------

func _walk_side() -> void:
	hud.clear_side()
	hud.top_label.text = "%s   %s" % [Txt.t("UI_EX_TITLE"), map.map_name.to_upper()]
	_phase = null
	_info = hud.add_side_label("", 14)
	hud.add_side_label(Txt.t("UI_EX_HELP"), 11)
	_log_label = hud.add_side_label("", 12)


func _deploy_side() -> void:
	hud.clear_side()
	hud.top_label.text = Txt.t("UI_EX_DEPLOY")
	_phase = null
	_info = hud.add_side_label("", 14)
	for u: CombatUnit in party.slice(1):
		hud.add_button(Txt.t(u.name_key), _pick_member.bind(u))
	hud.add_button(Txt.t("UI_EX_START_FIGHT"), _begin_battle)
	hud.add_side_label(Txt.t("UI_EX_DEPLOY_HELP"), 11)
	_log_label = hud.add_side_label("", 12)


func _fight_side() -> void:
	hud.clear_side()
	hud.top_label.text = Txt.t("UI_EX_FIGHT")
	_phase = hud.add_side_label("", 20)
	_info = hud.add_side_label("", 14)
	hud.add_button(Txt.t("UI_END_PHASE"), func() -> void: battle.end_player_phase())
	hud.add_button(Txt.t("UI_DANGER"), func() -> void:
		battle.show_danger = not battle.show_danger
		battle._refresh_danger())
	hud.add_side_label(Txt.t("UI_HELP_COMBAT"), 11)
	_log_label = hud.add_side_label("", 12)


func _log(line: String) -> void:
	if _log_label == null:
		return
	var lines := _log_label.text.split("\n", false)
	lines.append(line)
	_log_label.text = "\n".join(lines.slice(-8))


func _refresh_hud() -> void:
	var entries := []
	for u: CombatUnit in party:
		entries.append({"name": Txt.t(u.name_key), "hp": u.hp, "max_hp": u.max_hp, "tint": u.tint,
			"note": Txt.t("TAG_SPOOKED") if u.spooked else ""})
	hud.set_party(entries)
	hud.set_slots(Game.run.slot_list(), RunState.CAPACITY)
	var tools := [{"text": Txt.t("UI_PACK"), "cb": _open_menu.bind("pack")}]
	if Game.has_flag("has_lodestone"):
		tools.append({"text": Txt.t("UI_LODESTONE"), "cb": _open_menu.bind("lodestone"), "glow": Game.pending_picks() > 0})
	hud.set_tools(tools)


## The pack or the Lodestone menu, from the bottom bar. Only while walking.
func _open_menu(which: String) -> void:
	if mode != M.WALK and not (mode == M.DIALOG and _menu_open):
		return
	_walk_token += 1
	walking_now = false
	mode = M.DIALOG
	_menu_open = true
	var box := _new_dialog("", true)
	var changed := func() -> void:
		_after_change()
		_open_menu(which)
	var close := func() -> void:
		_close_dialog()
		_menu_open = false
		mode = M.WALK
	if which == "pack":
		AdventureMenu.pack(box, changed, close)
	else:
		AdventureMenu.lodestone(box, changed, close, map.map_name != "village")

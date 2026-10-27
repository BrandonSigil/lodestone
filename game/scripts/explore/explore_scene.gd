extends Node2D
## Walk a big map: the party leader is the one piece on the map (the rest travel with them, unseen).
## Fog of war past what the leader can see, enemy groups that spot you, and things to use (doors, chests)
## with options that depend on who is in the party.
## A fight breaks out in place: first the party deploys around the leader (quick members may start
## further out, heavy ones at the leader's side), then the same board becomes the battlefield.
## F6 on explore.tscn, or F10 from any screen. The map is Game.explore_map (data/explore/<name>.json).
##
## Controls: click ground = walk there. Click a thing = walk up and use it.
## F = use the nearest lit thing. Q = turn the camera. Arrows or right drag = look around, wheel = zoom,
## Space = back to the leader. Hover an enemy to see what it can see.

enum M { WALK, BUSY, DIALOG, DEPLOY, FIGHT, OVER }

const STEP_TIME := 0.15
const ZOOM_MIN := 0.55
const ZOOM_MAX := 1.6
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
var mode := M.WALK
var battle: Battle
var zoom := 1.0
var focus := Vector2.ZERO  ## board-local point the camera centres on
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
## Deploying: the fight waiting to start, the member being placed and the cells it may take.
var _pending := {}
var _placing: CombatUnit = null
var _ring: Array[Vector2i] = []


func _ready() -> void:
	Game.ensure_run()
	map = ExploreMap.load_named(Game.explore_map)
	grid = map.grid
	board = CombatBoard.new()
	board.grid = grid
	board.strangeness = map.strangeness
	board.art_set = map.art_set
	board.rot = map.view
	board.fog_on = true
	add_child(board)
	overlay = ExploreOverlay.new()
	overlay.scene = self
	board.add_child(overlay)
	board.cell_clicked.connect(_on_cell_clicked)
	board.cell_hovered.connect(_on_cell_hovered)

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
	for t in map.things:
		var copy := t.duplicate()
		copy["done"] = false
		things.append(copy)
		if t.kind == "door" or t.kind == "rubble":
			grid.set_terrain(t.cell, CombatGrid.T.RUIN)  # shut until opened

	hud = FrameHud.new()
	add_child(hud)
	_ui = CanvasLayer.new()
	_ui.layer = 4
	add_child(_ui)
	_walk_side()
	_refresh_sight()
	_refresh_units()
	_refresh_hud()
	var lead := leader()
	if lead:
		focus = board.cell_top(lead.cell)


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
		if not t.done and t.cell == c:
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
		focus += pan.normalized() * PAN_SPEED * delta / zoom
	var lead := leader()
	if follow and lead != null:
		var target := board.iso(lead.vis.x + 0.5, lead.vis.y + 0.5, lead.vis_h)
		focus = focus.lerp(target, minf(1.0, delta * 8.0))
	_apply_camera()


func _apply_camera() -> void:
	var r := hud.center_rect()
	board.scale = Vector2.ONE * zoom
	board.position = r.get_center() - focus * zoom
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
		focus -= (event as InputEventMouseMotion).relative / zoom


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
		if t.done or not in_sight.has(t.cell):
			continue
		var d := ExploreRules.dist(lead.cell, t.cell)
		if d <= ExploreRules.HINT_RANGE and d < best_d:
			best = t
			best_d = d
	return best


# --- sight -------------------------------------------------------------------------------

func _refresh_sight() -> void:
	var eyes: Array = party_cells() if mode == M.FIGHT else [leader().cell]
	in_sight = ExploreRules.sight(grid, eyes, ExploreRules.PARTY_SIGHT)
	for c in in_sight:
		seen[c] = true
	var fog := {}
	for c in seen:
		fog[c] = 2 if in_sight.has(c) else 1
	board.fog = fog


## Out of a fight the board shows the leader and the enemies in sight; in a fight, every fighter.
func _refresh_units() -> void:
	if mode == M.FIGHT or mode == M.DEPLOY:
		return
	var shown: Array = [leader()]
	for g in groups:
		if g.state == "gone":
			continue
		for u: CombatUnit in g.units:
			if u.alive() and in_sight.has(u.cell):
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
	var path := ExploreRules.find_path(grid, lead.cell, c, leader().jump, _blocked(), seen)
	if path.size() < 2:
		board.float_text(c, Txt.t("UI_EX_NO_WAY"), Color(0.9, 0.8, 0.7))
		return
	follow = true
	walk(path)


func _go_use(t: Dictionary) -> void:
	var lead := leader()
	var path := ExploreRules.path_to_use(grid, lead.cell, t.cell, leader().jump, _blocked(), seen)
	if path.is_empty():
		board.float_text(t.cell, Txt.t("UI_EX_NO_WAY"), Color(0.9, 0.8, 0.7))
		return
	follow = true
	if path.size() == 1:
		_open_thing(t)
	else:
		walk(path, t)


## Walk the leader along path (path[0] is where the leader stands).
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
	var start := path.find(lead.cell)
	for i in range(maxi(start, 0) + 1, path.size()):
		if token != _walk_token or mode != M.WALK:
			stopped = true
			break
		var next: Vector2i = path[i]
		if _blocked().has(next):
			stopped = true
			break
		await _step_all([lead], [next])
		if _after_step():
			stopped = true
			break
	if token != _walk_token:
		return  # a newer walk took over
	walking_now = false
	board.play_anim(lead, "idle")
	if not stopped and not then_use.is_empty() and mode == M.WALK and ExploreRules.can_use_from(grid, leader().cell, then_use.cell):
		_open_thing(then_use)


## Move units[i] one cell toward targets[i], all at once.
func _step_all(units: Array, targets: Array) -> void:
	_stepping = true
	var froms: Array[Vector2] = []
	var from_h: Array[float] = []
	for i in units.size():
		var u: CombatUnit = units[i]
		froms.append(Vector2(u.cell))
		from_h.append(float(grid.height_at(u.cell)))
		if targets[i] != u.cell:
			u.facing = targets[i] - u.cell
	var step := func(t: float) -> void:
		for i in units.size():
			var u: CombatUnit = units[i]
			var to: Vector2i = targets[i]
			u.vis = froms[i].lerp(Vector2(to), t)
			u.vis_h = lerpf(from_h[i], float(grid.height_at(to)), t)
			u.hop = sin(t * PI) * (2.0 + absf(grid.height_at(to) - from_h[i]) * CombatBoard.HS * 0.6) if to != Vector2i(froms[i]) else 0.0
	var tw := create_tween()
	tw.tween_method(step, 0.0, 1.0, STEP_TIME)
	await tw.finished
	for i in units.size():
		var u: CombatUnit = units[i]
		u.hop = 0.0
		u.place(targets[i], grid.height_at(targets[i]))
	_stepping = false


## After each step: update the fog, then see who spotted whom. True when the walk must stop.
func _after_step() -> bool:
	_refresh_sight()
	var spotted := check_groups()
	_refresh_units()
	return spotted


## A group that sees the party attacks (they move first). A group the party sees first stops the walk
## and asks what to do. Returns true when either happened.
func check_groups() -> bool:
	var cells := [leader().cell]
	for g in groups:
		if g.state != "idle" and g.state != "noticed":
			continue
		var gc := _group_cells(g)
		if gc.is_empty():
			continue
		if ExploreRules.sees(grid, gc, cells, int(g.def.sight)):
			board.float_text(leader().cell, Txt.t("UI_EX_SPOTTED"), Color(1.0, 0.5, 0.4))
			start_fight(g, "ambushed")
			return true
		var visible := gc.any(func(c: Vector2i) -> bool: return in_sight.has(c))
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
	if not g.is_empty() and in_sight.has(c):
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
	var path := ExploreRules.find_path(grid, leader().cell, c, leader().jump, _blocked(), seen)
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
	if t.done or mode != M.WALK:
		return
	open_event(String(t.event), {"thing": t})


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
	for o: Dictionary in ExploreRules.options_for(ev, _defs()):
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
		_sync_party_hp()
		_refresh_hud()
		lines.append(fx.run.replace(";", "  "))
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
				var floor_t: int = CombatGrid.T.STONE
				for key in CombatGrid.LETTERS:
					if CombatGrid.LETTERS[key] == t.floor:
						floor_t = key
				grid.set_terrain(t.cell, floor_t)
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
	if mode == M.WALK:
		_refresh_sight()
		_refresh_units()
		check_groups()
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


func _sync_party_hp() -> void:
	for u: CombatUnit in party:
		u.hp = clampi(int(u.member.hp), 0, u.max_hp)
		u.shown_hp = u.hp


func _new_dialog(text: String) -> VBoxContainer:
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
	_dialog.position = Vector2(r.get_center().x - 220, r.end.y - 230)
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
	_reveal_around(enemies.map(func(u: CombatUnit) -> Vector2i: return u.cell), 1)
	_reveal_around([leader().cell], 4)
	for u: CombatUnit in party:
		if _pending.spots.has(u):
			u.place(_pending.spots[u], grid.height_at(_pending.spots[u]))
	_show_deployed()
	follow = false
	var sum := Vector2.ZERO
	var fighters := _deployed() + enemies
	for u: CombatUnit in fighters:
		sum += board.cell_top(u.cell)
	focus = sum / fighters.size()
	if how == "ambushed":
		board.float_text(leader().cell, Txt.t("UI_EX_SPOTTED"), Color(1.0, 0.5, 0.4))
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
	for f: Dictionary in foes:
		f.state = "gone"
		if f.def.loot != "":
			var out := TrailRules.apply_effects(Game.run, f.def.loot)
			Game.absorb(out.unlocks)
	for u: CombatUnit in party:
		u.member.hp = maxi(1, u.hp)  # downed members get back up after a win
	_sync_party_hp()
	_refresh_hud()
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
	_walk_side()
	_refresh_sight()
	_refresh_units()


func _finish_map() -> void:
	mode = M.OVER
	var box := _new_dialog(Txt.t("UI_EX_DONE"))
	_dialog_button(box, Txt.t("UI_CONTINUE"), func() -> void: Game.go(Game.TRAIL))


# --- hud ----------------------------------------------------------------------------------------

func _walk_side() -> void:
	hud.clear_side()
	hud.top_label.text = "%s   %s" % [Txt.t("UI_EX_TITLE"), map.map_name.to_upper()]
	_phase = null
	_info = hud.add_side_label("", 14)
	hud.add_button(Txt.t("UI_TURN_VIEW"), func() -> void: board.turn())
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
	hud.add_button(Txt.t("UI_TURN_VIEW"), func() -> void: board.turn())
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

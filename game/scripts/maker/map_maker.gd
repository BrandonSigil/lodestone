extends Node2D
## The map maker (F8 from any screen): build battle and exploration maps on the fly, seen the whole time in
## their finished look. Sculpt terraces, paint ground, lay paths, dig rivers, cut stairs and the outline;
## pick assets from a catalog sorted into drawers (Building interior > Furniture > fireplace) and drag them
## onto the map, turned to any angle their art is painted from; place interactables (doors, chests, ways
## out) with ids to script them by, named placeholder blobs that turn into art when it lands, and the
## party start; select, move, turn and delete anything placed; undo anything, save, and play the map.
## Tool labels are designer tool text, not player-facing copy, so they don't go through Txt.
## How to use it: docs/systems/map-maker.md. Design: docs/design/map-look.md. Research: docs/research/map-editors.md.

const UI_SCALE := 0.8  ## the maker's bars, rail, panels and text draw at this share of their size; the map keeps its own
const RAIL_W := 56.0
const DOCK_W := 324.0
const TOP_H := 48.0
const OPT_H := 46.0
const BOTTOM_H := 30.0
const GAP := 10.0
const ZOOM_MIN := 0.3
const ZOOM_MAX := 2.5
const PAN_SPEED := 800.0
const UNDO_DEPTH := 80
const MAX_SIZE := 128
const RECENT_MAX := 10
const FIRST_MAP := "maps/highland"  ## what the maker opens the first time
const PREFS := "user://map_maker.cfg"
const T := CombatGrid.T

## [id, icon, key, name, help]; ["|"] separates groups on the rail.
const TOOLS := [
	["select", "select", "V", "Select", "click anything placed to select it, drag to move it. R turns, M mirrors, Del deletes, ctrl D copies it to the stamp. Alt click with any tool: pick up what's under the cursor."],
	["stamp", "stamp", "B", "Place", "place the asset picked in the catalog (or drag a tile onto the map). Drag places a row of small props. R turns, M mirrors. Right click: back to select."],
	["erase", "erase", "X", "Erase", "click or drag: take away props, blobs and things under the brush."],
	["party", "party", "U", "Party", "click a walkable cell to stand the party member picked below there (replaces what stands there). Right click: remove what stands there. Battle maps only."],
	["enemy", "enemy", "E", "Enemy", "click a walkable cell to place the enemy picked below there (replaces what stands there). Right click: remove what stands there. Battle maps only."],
	["|"],
	["raise", "height", "1", "Height", "one tool, three modes (the arrows in the options bar; press 1 again to cycle): up raises a level, flat flattens into a terrace at the height box (right click takes a cell's height; - and = change it), down lowers a level. Right click does the opposite."],
	["smooth", "smooth", "2", "Smooth", "drag: soften bumps toward the ground around them."],
	["tidy", "tidy", "3", "Tidy", "drag: square off ragged edges under the brush, so edges step two cells at a time and lone spurs and notches go (rule V9). The Map tab's Tidy edges does the whole map."],
	["pillar", "pillar", "4", "Pillar", "click a cell: it rises two levels over its neighbours into a lone rock pillar, snow-capped in the painted look (rule V10). Right click: back down."],
	["|"],
	["paint", "paint", "P", "Ground", "pick a ground type above, then drag to paint it. Painting a hole fills it first. Right: grass."],
	["path", "path", "L", "Path", "drag a path's course (size 1 to 4: [ and ] set how wide); stairs are cut where it climbs. With 'follow ground' it finds the easiest walk from where you press to where you let go."],
	["river", "river", "W", "River", "drag along the river's course from high ground down: it digs a channel that never runs uphill; every drop becomes a waterfall."],
	["stairs", "stairs", "T", "Stairs", "click a cell at a cliff: stairs that join both sides. Drag from the bottom to the top of a cliff: a flight. Size 1 to 4 ([ and ]) makes it that wide: one stair, even steps across, flush at the top. Right drag: clear stairs."],
	["bridge", "deck", "N", "Bridge", "drag from one landing to another across water, a gap or lower ground: a bridge is built between them at the landings' height (a step if they differ by one), with rails and piers, and the ground under it is not touched. Right drag: take a bridge away along the line. Size 1 to 4 ([ and ]) makes it that many cells wide, rails on its outer edges only."],
	["deck", "deck", "J", "Deck", "drag: a bridge floor at the level height over the cells, with the lane under it still open (it stands at least two levels over the ground). Right drag: take decks away."],
	["|"],
	["region", "square", "A", "Area", "drag a box (or click a flat area) to select cells; then Height (or PageUp and PageDown) moves every cell in it one level, keeping its ground, walls, stairs, decks and props. Right click clears the selection."],
	["cut", "cut", "C", "Cut", "cut cells out of the map: the outline, chasms, pits. Right: fill them back."],
	["fill", "fill", "F", "Fill", "give holes ground again at the height around them. Right: cut."],
	["zone", "zone", "Z", "Zone", "paint another tile set onto cells (blend forest into ruins). Right: back to the map's set."],
]
const FIGHT_LABELS := {"hp_pct": "hp %", "attack": "crit (5% a point)", "defense": "armor", "damage": "damage", "move": "move"}
## Ground materials ([USER] 2026-10-30: "we call everything grass right now": one map should go from snow into a castle):
## [label, ground, tile set]. The ground sets what a cell is (walkable, cover, cost), the tile set what it looks like, per
## cell, so a map can start snowy and move into a castle. Saved maps keep their per-cell sets (grid zones), so old maps load.
const MATERIALS := [["grass", T.GRASS, ""], ["forest", T.FOREST, ""], ["snow", T.GRASS, "snow"], ["snow pines", T.FOREST, "snow"],
		["dirt", T.ROAD, ""], ["stone floor", T.STONE, "ruins"], ["castle tiles", T.STONE, "dungeon"], ["cobbles", T.STONE, "village"],
		["marsh", T.GRASS, "marsh"], ["farmland", T.GRASS, "farmland"], ["canyon rock", T.ROCK, "canyon"], ["rock", T.ROCK, ""],
		["ruin", T.RUIN, ""], ["water", T.WATER, ""]]
const GROUNDS := [["grass", T.GRASS], ["forest", T.FOREST], ["road", T.ROAD], ["stone", T.STONE], ["rock", T.ROCK], ["ruin", T.RUIN], ["water", T.WATER]]
const PATH_GROUNDS := [["road", T.ROAD], ["stone", T.STONE], ["grass", T.GRASS]]
const BRUSH_TOOLS := ["erase", "raise", "lower", "level", "smooth", "tidy", "paint", "path", "river", "cut", "fill", "zone", "deck"]
## Map creation phases ([USER] 2026-10-30: "break this out into map creation phases"): 1 shape the ground, 2 dress it,
## 3 set up where players go. Only the current phase's tools and assets show; the view (flat or isometric) and the
## current tool stay as they are when either changes.
const PHASES := [["shape", "1  Shape", "The map itself: size, name, environment, ground, height, walls, water, stairs"],
		["decor", "2  Decor", "What shows on the map: props, foliage, buildings, dressing"],
		["play", "3  Play", "Where players go: spawns, enemy groups, goals, doors, chests, events and triggers"]]
const TOOL_PHASE := {"select": ["decor", "play"], "stamp": ["decor", "play"], "erase": ["decor", "play"], "party": ["play"], "enemy": ["play"]}
const PLAY_DRAWERS := ["Interactables", "Markers"]  ## the catalog drawers that are Play-phase things; the rest is Decor
const PHASE_PAGES := {"shape": ["map"], "decor": ["assets", "inspect"], "play": ["assets", "inspect"]}
const THING_COLOR := Color(0.98, 0.84, 0.48)
const START_COLOR := Color(0.45, 0.72, 1.0)
const FOE_COLOR := Color(1.0, 0.48, 0.42)

var doc: MapDoc
var board: CombatBoard
var overlay: MakerOverlay
var flat: FlatView  ## the flat sketch mode (Tab): a top-down grid of the same map
var tool := "select"
var width := 1  ## brush size and line width, 1 to 4 cells: the paint brushes, paths, rivers, bridges and stairs
var square := false
var level_h := 3  ## the height tool's flat mode: the height it flattens to
const HEIGHT_MODES := ["raise", "level", "lower"]  ## the height tool's modes (tool ids): up, flat, down
var height_last := "raise"  ## the mode the Height button and the 1 key return to
var paint_t: int = T.GRASS
var paint_set := ""  ## the tile set the Ground tool paints with (the material picked)
var paint_mat := "grass"
var path_t: int = T.ROAD
var follow_ground := false
var gen_seed := 1
var zoom := 1.0
var focus := Vector2.ZERO
var hide_ui := false
var phase := "shape"
var region := {}  ## the Area tool's selected cells (Vector2i -> true)
var _box := {}  ## {"start", "last"} while the Area tool drags a box
## The stamp: a catalog entry and how it's turned.
var item := {}
var item_face := 0
var item_flip := false
var item_foot := Vector2i.ONE
## What's selected: {"type": "prop", "cell"} | {"type": "thing", "i"} | {"type": "start", "i"} |
## {"type": "piece", "list": "party"/"enemies", "i"}; {} = nothing.
var selection := {}
var recent: Array[String] = []

var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _stroke := {}  ## {"button", "start", "last", "done": {}, "path": []} while a mouse stroke runs
var _move := {}  ## {"from": cell, "to": cell} while the select tool drags something
var _drag_item := false  ## a catalog tile is being dragged onto the map
var _pan := false
var _dirty := false
var _god := {}  ## God mode: where Back to play goes (Game.god_return, taken when the maker opens)
var _back_btn: Button
var _closed := {}  ## drawer keys folded shut
var _syncing := false
var _hover_cell := CombatBoard.NONE

var _ui: CanvasLayer
var _root: Control
var _panels: Array[Control] = []
var _top: PanelContainer
var _rail: PanelContainer
var _opts: PanelContainer
var _dock: PanelContainer
var _bottom: PanelContainer
var _tool_buttons := {}
var _phase_buttons := {}
var _rail_col: VBoxContainer
var _rail_seps: Array[VBoxContainer] = []
var _title: Label
var _status: Label
var _help: Label
var _open_menu: PopupMenu
# save as
var _save_box: Control  ## dims the screen behind the save as card; hidden when it's closed
var _save_name: LineEdit
var _save_list: ItemList
var _save_where: Label
var _save_warn: Label
var _save_ok: Button
var _view_buttons := {}
# options bar
var _opt_groups := {}
var _height_buttons := {}
var _keys_panel: PanelContainer
var _radius_slider: HSlider
var _radius_label: Label
var _shape_buttons: Array[MakerUI.IconButton] = []
var _level_spin: SpinBox
var _ground_buttons := {}
var _path_buttons := {}
var _zone_pick: OptionButton
var _stamp_label: Label
var _stamp_angles: Label
# dock
var _tabs := {}
var _pages := {}
var _search: LineEdit
var _recent_row: HFlowContainer
var _cat_box: VBoxContainer
var _tiles: Array[MakerUI.AssetTile] = []
var _insp_box: VBoxContainer
var _outline: ItemList
var _outline_sel: Array[Dictionary] = []
# map page
var _name_edit: LineEdit
var _kind_pick: OptionButton
var _set_pick: OptionButton
var _look_pick: OptionButton
var _party_pick: OptionButton
var _enemy_pick: OptionButton
var _fight_drawer: MakerUI.Drawer
var _fight_spins := {}  ## fight dials by "party.hp_pct", "enemy.move", "extra", "medicine", "food", "seed"
var _fight_checks := {}  ## "counters"
var _w_spin: SpinBox
var _h_spin: SpinBox
var _floor_spin: SpinBox
var _skirt_spin: SpinBox
var _strange_spin: SpinBox
var _seed_spin: SpinBox
var _recipe_pick: OptionButton


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.2, 0.23, 0.25))
	_load_prefs()
	board = CombatBoard.new()
	board.can_turn = true  # an editing aid; players never turn the view
	board.backdrop = true
	board.wallpaper = true  # the newest look: skyline wallpaper, solid foreground band, silhouette trees
	board.edit_void = true
	board.show_grid = true
	add_child(board)
	overlay = MakerOverlay.new()
	overlay.maker = self
	board.add_child(overlay)
	get_tree().node_added.connect(_on_node_added)
	_build_ui()
	var opened: MapDoc = null
	if Game.maker_map != "":
		opened = MapDoc.load_path(Game.maker_map)
	if opened == null:
		opened = MapDoc.load_path(FIRST_MAP)
	if opened == null:
		opened = MapDoc.create("battle", "valley_%d" % gen_seed, MapGen.valley(gen_seed), "snow")
	_open(opened)
	get_viewport().size_changed.connect(_fit_view)
	_god = Game.god_return
	Game.god_return = {}
	_back_btn.visible = not _god.is_empty()
	if Game.maker_focus != Vector2i(-1, -1) and doc.grid.in_bounds(Game.maker_focus):
		zoom = clampf(1.2, ZOOM_MIN, ZOOM_MAX)  # the party's spot, close enough to work
		_look_at(Game.maker_focus)
		if flat != null:
			flat.fit()
	Game.maker_focus = Vector2i(-1, -1)


# --- document -------------------------------------------------------------------------

func _open(d: MapDoc) -> void:
	doc = d
	region = {}
	_undo.clear()
	_redo.clear()
	_dirty = false
	selection = {}
	board.grid = doc.grid
	board.art_set = doc.art_set
	board.strangeness = doc.strangeness
	board.rot = doc.view
	Game.maker_map = doc.key()
	_sync_ui()
	_build_catalog()
	_refresh_marks()
	_build_inspector()
	_fit_view()


func _snapshot() -> Dictionary:
	return {"grid": doc.grid.to_dict(), "set": doc.art_set, "strange": doc.strangeness, "data": doc.data.duplicate(true), "view": doc.view}


func _push_undo() -> void:
	_undo.append(_snapshot())
	if _undo.size() > UNDO_DEPTH:
		_undo.pop_front()
	_redo.clear()
	_dirty = true


func _restore(s: Dictionary) -> void:
	doc.grid = CombatGrid.from_dict(s.grid)
	doc.art_set = s.set
	doc.strangeness = s.strange
	doc.data = s.data
	doc.view = int(s.get("view", doc.view))
	board.grid = doc.grid
	board.art_set = doc.art_set
	board.strangeness = doc.strangeness
	if not _sel_valid():
		selection = {}
	_sync_ui()
	_refresh_marks()
	_build_inspector()


func undo() -> void:
	if _undo.is_empty():
		return
	_redo.append(_snapshot())
	_restore(_undo.pop_back())
	_say("undo")


func redo() -> void:
	if _redo.is_empty():
		return
	_undo.append(_snapshot())
	_restore(_redo.pop_back())
	_say("redo")


func save() -> void:
	doc.map_name = SandboxSetup.safe_name(_name_edit.text)
	_name_edit.text = doc.map_name
	var path := doc.save()
	_dirty = false
	Game.maker_map = doc.key()
	_say(("saved " + path) if path != "" else "save failed")
	_refresh_marks()


## Save under a new name, or over another map of the same kind. The map under its old name stays as it was.
func save_as(new_name: String) -> void:
	doc.map_name = SandboxSetup.safe_name(new_name)
	_syncing = true
	_name_edit.text = doc.map_name
	_syncing = false
	save()


func open_save_as() -> void:
	if hide_ui:
		hide_ui = false
		_root.visible = true
		_fit_view()
	_save_name.text = doc.map_name
	_save_list.clear()
	var prefix := doc.key().get_slice("/", 0) + "/"
	for key in MapDoc.list_all():
		if key.begins_with(prefix):
			_save_list.add_item(key.substr(prefix.length()))
	_save_where.text = "%s maps go in %s" % [doc.kind, MapDoc.DIRS[doc.kind].trim_prefix("res://")]
	_save_box.visible = true
	_on_save_name(_save_name.text)
	_save_name.grab_focus()
	_save_name.select_all()


func _close_save_as() -> void:
	_save_box.visible = false
	_save_name.release_focus()


func _confirm_save_as() -> void:
	if not _save_ok.disabled:
		_close_save_as()
		save_as(_save_name.text)


## Says where the map lands and whether that writes over another map.
func _on_save_name(t: String) -> void:
	var n := SandboxSetup.safe_name(t)
	var taken := MapDoc.exists(doc.kind, n)
	var other := taken and n != SandboxSetup.safe_name(doc.map_name)
	_save_ok.disabled = t.strip_edges() == ""
	_save_ok.text = ("Overwrite " + n) if other else "Save"
	if t.strip_edges() == "":
		_save_warn.text = ""
	elif other:
		_save_warn.text = "%s/%s already exists; saving replaces it" % [doc.key().get_slice("/", 0), n]
	elif taken:
		_save_warn.text = "saves over this map"
	else:
		_save_warn.text = "new map: %s%s.json" % [MapDoc.DIRS[doc.kind].trim_prefix("res://"), n]
	_save_warn.add_theme_color_override("font_color", MakerUI.BAD if other else MakerUI.DIM)


## God mode: save, then land on the map you jumped from, on the same cell (a battle map starts as a fight).
func back_to_play() -> void:
	if _god.is_empty():
		return
	save()
	var back := _god
	_god = {}
	if String(back.get("kind", "")) == "explore":
		Game.ensure_run()
		Game.explore_map = String(back.map)
		Game.explore_entry = back.get("cell", Vector2i(-1, -1))
		Game.go(Game.EXPLORE)
	else:
		play_test()


## Play the map: save it, then a battle map opens in the combat sandbox with its fight started, an
## exploration map in the explore scene. F8 comes back here.
func play_test() -> void:
	save()
	if doc.kind == "battle":
		Game.sandbox_map = SandboxSetup.MAP_DIR + doc.map_name + ".json"
		if not FileAccess.file_exists(Game.sandbox_map):
			Game.sandbox_map = SandboxSetup.USER_MAP_DIR + doc.map_name + ".json"
		Game.sandbox_play = true
		Game.go(Game.BATTLE)
	else:
		Game.ensure_run()
		Game.explore_map = doc.map_name
		Game.explore_entry = Vector2i(-1, -1)
		Game.explore_memory.erase(doc.map_name)
		Game.go(Game.EXPLORE)


func new_valley() -> void:
	_push_undo()
	gen_seed = int(_seed_spin.value)
	var look_id := _look_id()
	var g := MapGen.valley(gen_seed, int(_w_spin.value), int(_h_spin.value), look_id if look_id != "" else "snow")
	doc.grid = g
	if doc.art_set == "" and (look_id == "" or look_id == "snow"):
		doc.art_set = "snow"
	board.grid = g
	board.art_set = doc.art_set
	if doc.map_name == "untitled" or doc.map_name.begins_with("valley_"):
		doc.map_name = "valley_%d" % gen_seed
	selection = {}
	_after_map_change()
	_say("new valley, seed %d" % gen_seed)


## Replace the map with a hand-laid layout from MapRecipes (it keeps this map's name and kind).
func new_from_recipe() -> void:
	var recipe := _recipe_pick.get_item_text(_recipe_pick.selected)
	var g := MapRecipes.build(recipe)
	if g == null:
		return
	_push_undo()
	doc.grid = g
	if doc.art_set == "":
		doc.art_set = "snow"
	board.grid = g
	board.art_set = doc.art_set
	if doc.map_name == "untitled" or doc.map_name.begins_with("valley_"):
		doc.map_name = recipe
	selection = {}
	_after_map_change()
	_say("template " + recipe)


func new_blank() -> void:
	_push_undo()
	var g := CombatGrid.flat(int(_w_spin.value), int(_h_spin.value))
	for y in g.h:
		for x in g.w:
			g.set_height(Vector2i(x, y), 2)
	g.look = doc.grid.look.duplicate()
	doc = MapDoc.create(doc.kind, "untitled", g, doc.art_set)
	board.grid = g
	selection = {}
	_after_map_change()


func _resize() -> void:
	_push_undo()
	doc.grid = doc.grid.resized(int(_w_spin.value), int(_h_spin.value))
	board.grid = doc.grid
	if not _sel_valid():
		selection = {}
	_after_map_change()


func _after_map_change() -> void:
	_sync_ui()
	_refresh_marks()
	_build_inspector()
	_fit_view()


# --- camera ---------------------------------------------------------------------------

func _map_area() -> Rect2:
	var vs := get_viewport_rect().size
	if hide_ui:
		return Rect2(0, 0, vs.x, vs.y)
	var x0 := (GAP * 2 + RAIL_W) * UI_SCALE
	var y0 := (TOP_H + GAP * 2 + OPT_H) * UI_SCALE
	return Rect2(x0, y0, vs.x - x0 - (DOCK_W + GAP * 2) * UI_SCALE, vs.y - y0 - (BOTTOM_H + GAP) * UI_SCALE)


## The UI root is scaled down, so it is sized to the window in its own units: it still fills the window.
func _fit_root() -> void:
	_root.size = get_viewport_rect().size / UI_SCALE


func _fit_view() -> void:
	if board == null or board.grid == null:
		return
	var vs := get_viewport_rect().size
	var area := _map_area()
	var bs := board.board_size()
	zoom = clampf(minf(area.size.x / bs.x, area.size.y / bs.y) * 0.9, ZOOM_MIN, ZOOM_MAX)
	focus = board.board_origin() + bs * 0.5
	focus += (Vector2(vs.x * 0.5, vs.y * 0.5) - area.get_center()) / zoom
	_apply_camera()
	if flat != null and flat.visible:
		flat.fit()


## Centre the map area on a cell (the outline list's click).
func _look_at(c: Vector2i) -> void:
	var vs := get_viewport_rect().size
	focus = board.cell_top(c) + (vs * 0.5 - _map_area().get_center()) / zoom
	_apply_camera()


func _apply_camera() -> void:
	var vs := get_viewport_rect().size
	board.scale = Vector2.ONE * zoom
	board.position = vs * 0.5 - focus * zoom
	board.view_rect = Rect2(Vector2.ZERO, vs)
	var local := Rect2(-board.position / zoom, vs / zoom)
	board.cull = local.grow_individual(CombatBoard.TW * 2, CombatBoard.TH * 4, CombatBoard.TW * 2, CombatBoard.HS * 14)


func _zoom_at(screen: Vector2, factor: float) -> void:
	var before := (screen - board.position) / zoom
	zoom = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	var vs := get_viewport_rect().size
	focus = before - (screen - vs * 0.5) / zoom
	_apply_camera()


func _process(delta: float) -> void:
	var pan := Vector2.ZERO
	if not _typing():
		if Input.is_key_pressed(KEY_LEFT):
			pan.x -= 1
		if Input.is_key_pressed(KEY_RIGHT):
			pan.x += 1
		if Input.is_key_pressed(KEY_UP):
			pan.y -= 1
		if Input.is_key_pressed(KEY_DOWN):
			pan.y += 1
	if pan != Vector2.ZERO:
		focus += pan.normalized() * PAN_SPEED * delta / zoom
	_apply_camera()
	if flat != null and flat.visible:
		var area := _map_area()
		if flat.position != area.position or flat.size != area.size:
			flat.position = area.position
			flat.size = area.size
			flat.fit()
	_hover()
	_title.text = "%s%s" % [doc.key(), "  *" if _dirty else ""]


## Let go of keyboard focus, so painting and the shortcuts work again ([USER] 2026-10-30: the level box "doesnt really let
## you unfocus this text box"). Every number box and text box lets go on Enter, Escape, a click anywhere outside it and
## after its arrows change the value.
func _drop_focus() -> void:
	var f := get_viewport().gui_get_focus_owner()
	if f != null:
		f.release_focus()


func _edit_owner() -> Control:
	var f := get_viewport().gui_get_focus_owner()
	if f == null:
		return null
	if f.get_parent() is SpinBox:
		return f.get_parent() as Control
	return f if (f is LineEdit or f is TextEdit or f is SpinBox) else null


func _input(event: InputEvent) -> void:
	var owner := _edit_owner()
	if owner == null:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var rect: Rect2 = owner.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, owner.size)
		if not rect.has_point((event as InputEventMouseButton).position):
			_drop_focus()  # a click outside the box (the click itself still goes on to what it hit)
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE:
			_drop_focus()
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
			_drop_focus.call_deferred()  # after the box has taken its value


## Wire every number box the maker builds (the panels rebuild them): the arrows and Enter hand focus back.
func _on_node_added(n: Node) -> void:
	if n is SpinBox and _ui != null and _ui.is_ancestor_of(n):
		var sb := n as SpinBox
		sb.value_changed.connect(func(_v: float) -> void: _drop_focus.call_deferred())
		sb.get_line_edit().text_submitted.connect(func(_t: String) -> void: _drop_focus.call_deferred())


func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit or f is SpinBox or (f != null and f.get_parent() is SpinBox)


## Is the screen point over one of the maker's panels?
func _over_ui(p: Vector2) -> bool:
	if hide_ui:
		return false
	for c in _panels:
		if c.visible and c.get_global_rect().has_point(p):
			return true
	return false


# --- input ------------------------------------------------------------------------------

## A left or right button press or release: the tool code, whichever view it came from.
func _mouse_button(mb: InputEventMouseButton) -> void:
	if mb.pressed and mb.alt_pressed:
		_eyedrop(_cell_under_mouse())
	elif mb.pressed and _stroke.is_empty() and _move.is_empty() and not _pan:
		_press(mb.button_index)
	elif not mb.pressed and not _box.is_empty() and mb.button_index == MOUSE_BUTTON_LEFT:
		_end_box()
	elif not mb.pressed and not _move.is_empty() and mb.button_index == MOUSE_BUTTON_LEFT:
		_end_move()
	elif not mb.pressed and not _stroke.is_empty() and _stroke.button == mb.button_index:
		_end_stroke()


## The Area tool: the box being dragged shows as the selection.
func _preview_box() -> void:
	var a: Vector2i = _box.start
	var b: Vector2i = _box.last
	region = {}
	for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			if doc.grid.solid(Vector2i(x, y)):
				region[Vector2i(x, y)] = true


## Let go: a click without a drag picks the connected flat area under it (same height, same ground).
func _end_box() -> void:
	var a: Vector2i = _box.start
	var b: Vector2i = _box.last
	_box = {}
	if a != b:
		return
	var g := doc.grid
	if not g.solid(a):
		region = {}
		return
	var h := g.height_at(a)
	var t := g.terrain_at(a)
	region = {a: true}
	var queue: Array[Vector2i] = [a]
	var i := 0
	while i < queue.size():
		var c: Vector2i = queue[i]
		i += 1
		for d: Vector2i in CombatRules.DIRS:
			var n := c + d
			if not region.has(n) and g.solid(n) and g.height_at(n) == h and g.terrain_at(n) == t:
				region[n] = true
				queue.append(n)
	_say("%d cells selected: PageUp and PageDown move them, drag a box to pick differently" % region.size())


## Move every selected cell up or down `dz` levels ([USER] 2026-10-30: "a level up or down button that honors whatever
## terrain its on"). Heights shift together, so each cell keeps its ground, tile set, walls, stairs and props, and a
## deck over it moves with it. Undoable.
func region_shift(dz: int) -> void:
	if region.is_empty():
		_say("select an area first: drag a box or click a flat area with the Area tool")
		return
	var g := doc.grid
	for c: Vector2i in region:
		var h := g.height_at(c) + dz
		if h < 0 or h > CombatGrid.MAX_HEIGHT:
			_say("can't go %s: a selected cell would leave the map's %d to %d levels" % ["up" if dz > 0 else "down", 0, CombatGrid.MAX_HEIGHT])
			return
	_push_undo()
	for c: Vector2i in region:
		g.set_height(c, g.height_at(c) + dz)
		if g.has_deck(c):
			var dk: Dictionary = g.decks[c]
			g.add_deck(c, int(dk.h) + dz, int(dk.t))
	_refresh_marks()
	_say("%d cells %s one level" % [region.size(), "raised" if dz > 0 else "lowered"])


## The level height (number keys in the flat view): and the Level tool, which paints it.
func set_level_height(h: int) -> void:
	level_h = clampi(h, 0, 24)
	if _level_spin != null:
		_level_spin.set_value_no_signal(level_h)
	_set_tool("level")
	_say("level height %d  (Level tool: drag to flatten a terrace at that height)" % level_h)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(mb.position, 1.1)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(mb.position, 1.0 / 1.1)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE or (mb.button_index == MOUSE_BUTTON_LEFT and mb.shift_pressed and _stroke.is_empty()):
			_pan = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_button(mb)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _pan:
			focus -= mm.relative / zoom
			_apply_camera()
	elif event is InputEventPanGesture:
		focus += (event as InputEventPanGesture).delta * 12.0 / zoom
		_apply_camera()
	elif event is InputEventMagnifyGesture:
		_zoom_at(get_viewport().get_mouse_position(), (event as InputEventMagnifyGesture).factor)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.is_echo():
		return
	if _save_box.visible:
		if k.keycode == KEY_ESCAPE:
			_close_save_as()
		return
	if _typing():
		return
	var cmd := k.ctrl_pressed or k.meta_pressed
	if cmd:
		match k.keycode:
			KEY_Z:
				if k.shift_pressed:
					redo()
				else:
					undo()
			KEY_Y:
				redo()
			KEY_S:
				if k.shift_pressed:
					open_save_as()
				else:
					save()
			KEY_D:
				_copy_to_stamp()
		return
	match k.keycode:
		KEY_TAB:
			set_flat(not flat.visible)
			get_viewport().set_input_as_handled()
		KEY_PAGEUP:
			if tool == "region":
				region_shift(1)
		KEY_PAGEDOWN:
			if tool == "region":
				region_shift(-1)
		KEY_H:
			hide_ui = not hide_ui
			_root.visible = not hide_ui
			_fit_view()
		KEY_G:
			_toggle_view("grid")
		KEY_K:
			_toggle_view("greybox")
		KEY_BRACKETLEFT:
			_set_width(width - 1)
		KEY_BRACKETRIGHT:
			_set_width(width + 1)
		KEY_SPACE:
			_fit_view()
		KEY_R:
			_turn_item()
		KEY_M:
			_mirror_item()
		KEY_DELETE, KEY_BACKSPACE:
			_delete_selected()
		KEY_ESCAPE:
			if _keys_panel != null and _keys_panel.visible:
				_keys_panel.visible = false
				return
			selection = {}
			_set_tool("select")
			_refresh_marks()
			_build_inspector()
		KEY_MINUS:
			if HEIGHT_MODES.has(tool):
				set_level_height(level_h - 1)
		KEY_EQUAL:
			if HEIGHT_MODES.has(tool):
				set_level_height(level_h + 1)
		KEY_SLASH:
			if k.shift_pressed:
				_toggle_keys()
		KEY_QUESTION:
			_toggle_keys()
		_:
			for t in TOOLS:
				if t.size() > 1 and OS.find_keycode_from_string(String(t[2])) == k.keycode:
					if t[0] == "raise":  # 1: the Height tool, and pressed again the next mode (up, flat, down)
						var i := HEIGHT_MODES.find(tool)
						_set_tool(HEIGHT_MODES[(i + 1) % 3] if i >= 0 else height_last)
					else:
						_set_tool(String(t[0]))


func _cell_under_mouse() -> Vector2i:
	if flat != null and flat.visible:
		return flat.cell_under_mouse()  # the flat view is only another view: same tools, its own cell grid
	return board.pick(board.get_local_mouse_position())


func _hover() -> void:
	var mouse := get_viewport().get_mouse_position()
	var over := _over_ui(mouse)
	var c := CombatBoard.NONE if over else _cell_under_mouse()
	if not _stroke.is_empty():
		_stroke_to(c)
	if not _box.is_empty() and c != CombatBoard.NONE and c != _box.last:
		_box.last = c
		_preview_box()
	if not _move.is_empty() and c != CombatBoard.NONE:
		_move.to = c
	overlay.brush = []
	overlay.ghost = {}
	overlay.hover_cells = []
	if c != CombatBoard.NONE:
		if not _move.is_empty():
			overlay.ghost = _sel_ghost(_move.to)
		elif tool == "stamp" and not item.is_empty() and (_stroke.is_empty() or _drag_item):
			overlay.ghost = _item_ghost(c)
		elif tool == "select":
			overlay.hover_cells = _cells_of(_pick(c))
		elif _stroke.get("button", 0) == 0 and not _path_tool():
			overlay.brush = _brush_cells(c)
	if c == _hover_cell:
		return
	_hover_cell = c
	if c == CombatBoard.NONE:
		_status.text = ""
		return
	var g := doc.grid
	var zone := g.zone_at(c)
	var p := g.prop_at(c)
	var th := _thing_at(c)
	_status.text = "(%d, %d)   %s   height %d%s%s%s" % [c.x, c.y, String(T.keys()[g.terrain_at(c)]).to_lower(), g.height_at(c),
		("   zone " + zone) if zone != "" else "", ("   " + _prop_title(p)) if not p.is_empty() else "",
		("   " + String(_things()[th].id)) if th >= 0 else ""]


func _path_tool() -> bool:
	return tool == "river" or tool == "stairs" or tool == "path" or tool == "bridge"


func _brush_cells(c: Vector2i) -> Array[Vector2i]:
	if c == CombatBoard.NONE:
		return []
	if tool == "stairs" or tool == "bridge" or tool == "party" or tool == "enemy" or tool == "region":
		return [c]
	return MapOps.sized(doc.grid, c, width, square)


func _press(button: int) -> void:
	var c := _cell_under_mouse()
	if c == CombatBoard.NONE:
		if tool == "select":
			_select({})
		return
	if tool == "select":
		if button == MOUSE_BUTTON_RIGHT:
			_select({})
			return
		var sel := _pick(c)
		_select(sel)
		if not sel.is_empty():
			_move = {"from": c, "to": c}
		return
	if tool == "stamp" and button == MOUSE_BUTTON_RIGHT:
		_set_tool("select")
		return
	if tool == "region":
		if button == MOUSE_BUTTON_RIGHT:
			region = {}
		else:
			_box = {"start": c, "last": c}
			_preview_box()
		return
	_push_undo()
	_stroke = {"button": button, "start": c, "last": c, "done": {}, "path": [c] as Array[Vector2i]}
	if _path_tool():
		overlay.path = [c]
		overlay.path_color = {"river": Color(0.45, 0.8, 1.0), "path": Color(0.92, 0.78, 0.55)}.get(tool, MakerUI.ACCENT)
	else:
		_apply(c, button == MOUSE_BUTTON_RIGHT)


func _stroke_to(c: Vector2i) -> void:
	if c == CombatBoard.NONE or c == _stroke.last:
		return
	var cells := MapOps.line(_stroke.last, c)
	_stroke.last = c
	if _path_tool():
		var path: Array[Vector2i] = _stroke.path
		for p in cells.slice(1):
			path.append(p)
		overlay.path = MapOps.line(_stroke.start, c) if tool == "stairs" or tool == "bridge" or (tool == "path" and follow_ground) else path
		return
	if tool == "stamp" and not _row_item():
		return
	for p in cells.slice(1):
		_apply(p, _stroke.button == MOUSE_BUTTON_RIGHT)


func _end_stroke() -> void:
	var right: bool = _stroke.button == MOUSE_BUTTON_RIGHT
	var g := doc.grid
	if tool == "river" and not right:
		MapOps.river(g, _stroke.path, 1, width)
	elif tool == "path" and not right:
		var course: Array[Vector2i] = _stroke.path
		if follow_ground:
			course = MapOps.road(g, _stroke.start, _stroke.last)
			if course.is_empty():
				_say("no walkable way between those cells")
		MapOps.path(g, course, path_t, width)
	elif tool == "bridge":
		var a: Vector2i = _stroke.start
		var b: Vector2i = _stroke.last
		if right:
			var n := MapOps.bridge_clear(g, a, b)
			_say("took away %d bridge cells" % n if n > 0 else "no bridge along that line")
		else:
			var res := MapOps.bridge_span(g, a, b, width)
			if String(res.error) != "":
				_say(String(res.error))
				_undo.pop_back()
			else:
				_say("bridge: %d cells" % (res.cells as Array).size())
	elif tool == "stairs":
		var a: Vector2i = _stroke.start
		var b: Vector2i = _stroke.last
		if right:
			for c in MapOps.line(a, b):
				if g.terrain_at(c) == T.STAIRS:
					g.set_terrain(c, T.GRASS)
		elif a == b:
			if not MapOps.stairs_wide(g, a, width):
				_say("no cliff next to that cell to cut stairs into")
		else:
			MapOps.flight(g, a, b, width)
	_stroke = {}
	overlay.path = []
	_refresh_marks()


## One brush dab of the current tool at c (right = the tool's opposite).
func _apply(c: Vector2i, right: bool) -> void:
	var g := doc.grid
	if tool == "stamp":
		_stamp(c)
		return
	if tool == "party" or tool == "enemy":
		if c == _stroke.start:
			_piece(c, right)
		return
	if tool == "pillar":
		if c == _stroke.start and not MapOps.pillar(g, c, right):
			_say("no pillar here: water, stairs, a hole or too high already")
		return
	var done: Dictionary = _stroke.done
	var cells: Array[Vector2i] = []
	for p in _brush_cells(c):
		if not done.has(p):
			done[p] = true
			cells.append(p)
	if cells.is_empty():
		return
	match tool:
		"raise":
			MapOps.raise(g, cells, -1 if right else 1)
		"lower":
			MapOps.raise(g, cells, 1 if right else -1)
		"level":
			if right:
				if g.solid(c):
					level_h = g.height_at(c)
					_level_spin.value = level_h
			else:
				MapOps.level(g, cells, level_h)
		"smooth":
			MapOps.smooth(g, cells)
		"tidy":
			var area := {}
			for p in _brush_cells(c):
				area[p] = true
			MapOps.tidy(g, {}, area)
		"cut":
			if right:
				MapOps.fill(g, cells)
			else:
				MapOps.cut(g, cells)
		"fill":
			if right:
				MapOps.cut(g, cells)
			else:
				MapOps.fill(g, cells)
		"deck":
			var low := 0
			for p in cells:
				if right:
					if g.has_deck(p):
						g.remove_deck(p)
				elif g.solid(p) and level_h >= g.height_at(p) + CombatGrid.DECK_CLEAR:
					g.add_deck(p, level_h, T.STONE)
				elif g.solid(p):
					low += 1
			if low > 0:
				_say("a deck stands at least %d levels over the ground: raise the level height" % CombatGrid.DECK_CLEAR)
		"zone":
			var z := "" if right else String(_zone_pick.get_item_metadata(_zone_pick.selected))
			for p in cells:
				if g.solid(p):
					g.set_zone(p, z)
		"paint":
			MapOps.fill(g, cells)
			MapOps.paint(g, cells, T.GRASS if right else paint_t)
			for p in cells:
				if g.solid(p):
					g.set_zone(p, "" if right else paint_set)  # the material's look, per cell
		"erase":
			for p in cells:
				var i := _thing_at(p)
				if i >= 0:
					_things().remove_at(i)
				var a := g.prop_anchor(p)
				if a != CombatGrid.NONE_CELL:
					MapOps.remove_prop(g, a)
			if not _sel_valid():
				selection = {}
				_build_inspector()
			_refresh_marks()


# --- placing ------------------------------------------------------------------------------

## Pick a catalog entry for the stamp.
func pick_item(e: Dictionary) -> void:
	item = e
	item_face = 0
	item_flip = false
	item_foot = e.foot
	_set_tool("stamp")
	_remember(String(e.id))
	_mark_tiles()


func _row_item() -> bool:
	return item.get("kind", "") == "prop" and item_foot == Vector2i.ONE


func _foot_cells(a: Vector2i, foot: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in foot.y:
		for dx in foot.x:
			out.append(a + Vector2i(dx, dy))
	return out


func _fits(cells: Array[Vector2i]) -> bool:
	for c in cells:
		if not doc.grid.in_bounds(c) or not doc.grid.solid(c):
			return false
	return true


## Can the stamp's kind go on this map? Things and the start live on explore maps only.
func _kind_ok(kind: String) -> bool:
	return doc.kind == "explore" or (kind != "thing" and kind != "start")


func _item_ghost(c: Vector2i) -> Dictionary:
	var kind := String(item.kind)
	var cells := _foot_cells(c, item_foot) if kind == "prop" or kind == "blob" else ([c] as Array[Vector2i])
	var gh := {"cells": cells, "ok": _fits(cells) and _kind_ok(kind)}
	match kind:
		"prop":
			var p := {"sprite": MakerCatalog.stem_for(item, doc.art_set), "foot": item_foot, "tall": item.tall, "face": item_face}
			var tex := board.prop_texture(p, doc.grid.zone_at(c)) if doc.grid.in_bounds(c) else null
			if tex == null:
				tex = BattleArt.texture(String(item.sprite))
			if tex != null and doc.grid.in_bounds(c):
				gh["tex"] = tex
				gh["rect"] = board._prop_rect(c, p, tex)
				gh["flip"] = item_flip
		"blob":
			gh["blob"] = Color(0.6, 0.7, 0.88)
			gh["tall"] = item.tall
		_:
			gh["icon"] = MakerCatalog.icon_for(item)
	return gh


## Place the stamp at c. Blobs and things are selected straight away, so they can be named.
func _stamp(c: Vector2i) -> void:
	if item.is_empty():
		return
	var g := doc.grid
	var kind := String(item.kind)
	if not _kind_ok(kind):
		_say("interactables and the party start go on explore maps (MAP tab: kind)")
		return
	match kind:
		"prop":
			var cells := _foot_cells(c, item_foot)
			if not _fits(cells) or _stroke.done.has(c):
				return
			for p in cells:
				_stroke.done[p] = true
			var extra := {}
			if item_face != 0:
				extra["face"] = item_face
			if item_flip:
				extra["flip"] = true
			if item.get("arch", false):
				extra["arch"] = true
			MapOps.add_prop(g, c, MakerCatalog.stem_for(item, doc.art_set), item_foot, item.tall, item.sight, item.walk, extra)
		"blob":
			var cells := _foot_cells(c, item_foot)
			if not _fits(cells):
				return
			var id := _unique_id("blob")
			MapOps.add_prop(g, c, "ph_" + id, item_foot, item.tall, item.sight, false, {"blob": true, "name": id, "id": id})
			_select({"type": "prop", "cell": c}, true)
		"thing":
			if not g.solid(c):
				return
			var i := _thing_at(c)
			if i >= 0:
				_things().remove_at(i)
			var th := {"id": _unique_id(String(item.thing)), "kind": item.thing, "event": item.event, "cell": [c.x, c.y]}
			if item.thing == "door" or item.thing == "rubble":
				th["floor"] = CombatGrid.LETTERS[g.terrain_at(c)] if g.terrain_at(c) != T.RUIN else "s"
			if item.thing == "enter":
				th["to"] = ""
				th["at"] = [-1, -1]
			_things().append(th)
			_select({"type": "thing", "i": _things().size() - 1}, true)
		"start":
			if not g.passable(c):
				return
			var st: Array = doc.data.get("start", [])
			if st.is_empty():
				st.append([c.x, c.y])
			else:
				st[0] = [c.x, c.y]
			doc.data["start"] = st
	_refresh_marks()


## A unique id on this map: kind_01, kind_02...
func _unique_id(base: String) -> String:
	var taken := {}
	for t in _things():
		taken[String(t.get("id", ""))] = true
	for a: Vector2i in doc.grid.props:
		taken[String(doc.grid.props[a].get("id", ""))] = true
	var n := 1
	while taken.has("%s_%02d" % [base, n]):
		n += 1
	return "%s_%02d" % [base, n]


## Turn the stamp or the selected prop to its next painted angle; one angle only: mirror it instead.
## An odd quarter turn swaps the footprint (2x1 becomes 1x2).
func _turn_item() -> void:
	if tool == "stamp" and not item.is_empty():
		var r := _turned(String(item.get("sprite", "")), item_face, item_flip, item_foot)
		item_face = r[0]
		item_flip = r[1]
		item_foot = r[2]
		_sync_options()
	elif selection.get("type", "") == "prop":
		_change_prop(func(p: Dictionary) -> void:
			var r := _turned(String(p.sprite), int(p.get("face", 0)), bool(p.get("flip", false)), p.foot)
			if p.has("open") and r[1] != bool(p.get("flip", false)):  # a one-angle sprite turns by mirroring
				p["open"] = CombatGrid.mirror_open(p.open)
			p["face"] = r[0]
			p["flip"] = r[1]
			p["foot"] = r[2])


func _mirror_item() -> void:
	if tool == "stamp" and not item.is_empty():
		item_flip = not item_flip
		item_foot = Vector2i(item_foot.y, item_foot.x)
		_sync_options()
	elif selection.get("type", "") == "prop":
		_change_prop(func(p: Dictionary) -> void:
			p["flip"] = not bool(p.get("flip", false))
			if p.has("open"):
				p["open"] = CombatGrid.mirror_open(p.open)
			p["foot"] = Vector2i(p.foot.y, p.foot.x))


func _turned(sprite: String, face: int, flip: bool, foot: Vector2i) -> Array:
	var stem := sprite if sprite.contains("/") or doc.art_set == "" else doc.art_set + "/" + sprite
	var angles := MakerCatalog.angles(stem)
	if angles.size() <= 1:
		return [face, not flip, Vector2i(foot.y, foot.x)]
	var next: int = angles[(angles.find(face) + 1) % angles.size()]
	var swap := absi(next - face) % 2 == 1
	return [next, flip, Vector2i(foot.y, foot.x) if swap else foot]


## Change the selected prop (turn, resize, fields) as one undo step; refused when it no longer fits.
func _change_prop(change: Callable) -> void:
	var a: Vector2i = selection.cell
	var g := doc.grid
	if not g.props.has(a):
		return
	_push_undo()
	var p: Dictionary = (g.props[a] as Dictionary).duplicate()
	change.call(p)
	MapOps.remove_prop(g, a)
	var cells := _foot_cells(a, p.foot)
	var ok := _fits(cells)
	if not ok:
		_say("that doesn't fit there")
		_restore(_undo.pop_back())
		return
	_readd(a, p)
	_refresh_marks()
	_build_inspector()


func _readd(a: Vector2i, p: Dictionary) -> void:
	if p.get("face", 0) == 0:
		p.erase("face")
	if not p.get("flip", false):
		p.erase("flip")
	MapOps.add_prop(doc.grid, a, String(p.sprite), p.foot, float(p.tall), float(p.sight), bool(p.walk), p)


## Alt click: take what's under the cursor as the stamp (with its angle).
func _eyedrop(c: Vector2i) -> void:
	if c == CombatBoard.NONE:
		return
	if tool == "paint":  # alt click with the Ground tool picks up the ground material under the cursor
		var g := doc.grid
		for mat in MATERIALS:
			if mat[1] == g.terrain_at(c) and mat[2] == g.zone_at(c) and _ground_buttons.has(mat[0]):
				paint_t = mat[1]
				paint_set = mat[2]
				paint_mat = mat[0]
				for k in _ground_buttons:
					_ground_buttons[k].set_pressed_no_signal(k == paint_mat)
				return
		return
	var a := doc.grid.prop_anchor(c)
	if a == CombatGrid.NONE_CELL:
		return
	selection = {"type": "prop", "cell": a}
	_copy_to_stamp()


## Ctrl D: the selected prop becomes the stamp, turned the same way.
func _copy_to_stamp() -> void:
	if selection.get("type", "") != "prop" or not doc.grid.props.has(selection.cell):
		return
	var p: Dictionary = doc.grid.props[selection.cell]
	var e := _entry_for(p)
	pick_item(e)
	item_face = int(p.get("face", 0))
	item_flip = bool(p.get("flip", false))
	item_foot = p.foot
	_sync_options()


## The catalog entry a placed prop came from (or one made up for it).
func _entry_for(p: Dictionary) -> Dictionary:
	var stem := String(p.sprite)
	if p.get("blob", false):
		return MakerCatalog.by_id("blob_%dx%d" % [mini(p.foot.x, p.foot.y), maxi(p.foot.x, p.foot.y)]).merged({"foot": p.foot, "tall": p.tall}, true)
	for e in MakerCatalog.entries():
		if e.kind == "prop" and MakerCatalog.stem_for(e, doc.art_set) == stem:
			return e
	return {"id": stem, "drawer": MakerCatalog.UNSORTED, "group": "", "kind": "prop", "sprite": stem, "foot": p.foot,
		"tall": p.tall, "sight": p.sight, "walk": p.walk, "thing": "", "event": "", "label": stem.get_file()}


# --- selection ----------------------------------------------------------------------------

func _things() -> Array:
	if not doc.data.has("things"):
		doc.data["things"] = []
	return doc.data.things


func _thing_at(c: Vector2i) -> int:
	if doc.kind != "explore":
		return -1
	var list := _things()
	for i in list.size():
		var cell: Array = list[i].cell
		if int(cell[0]) == c.x and int(cell[1]) == c.y:
			return i
	return -1


## What the select tool picks at c: a thing first, then the start or a piece, then a prop.
func _pick(c: Vector2i) -> Dictionary:
	if c == CombatBoard.NONE:
		return {}
	var i := _thing_at(c)
	if i >= 0:
		return {"type": "thing", "i": i}
	if doc.kind == "explore":
		var gs: Array = doc.data.get("groups", [])
		for gi in gs.size():
			var us: Array = gs[gi].get("units", [])
			for ui in us.size():
				if int(us[ui].cell[0]) == c.x and int(us[ui].cell[1]) == c.y:
					return {"type": "group", "i": gi, "u": ui}
		var st: Array = doc.data.get("start", [])
		for j in st.size():
			if int(st[j][0]) == c.x and int(st[j][1]) == c.y:
				return {"type": "start", "i": j}
	else:
		for list in ["party", "enemies"]:
			var arr: Array = doc.data.get(list, [])
			for j in arr.size():
				if int(arr[j].x) == c.x and int(arr[j].y) == c.y:
					return {"type": "piece", "list": list, "i": j}
	var a := doc.grid.prop_anchor(c)
	if a != CombatGrid.NONE_CELL:
		return {"type": "prop", "cell": a}
	return {}


func _sel_valid() -> bool:
	match selection.get("type", ""):
		"prop":
			return doc.grid.props.has(selection.cell)
		"thing":
			return doc.kind == "explore" and int(selection.i) < _things().size()
		"group":
			var gs: Array = doc.data.get("groups", [])
			return doc.kind == "explore" and int(selection.i) < gs.size() and int(selection.u) < (gs[selection.i].get("units", []) as Array).size()
		"start":
			return int(selection.i) < (doc.data.get("start", []) as Array).size()
		"piece":
			return int(selection.i) < (doc.data.get(selection.list, []) as Array).size()
	return false


func _sel_cell(sel: Dictionary) -> Vector2i:
	match sel.get("type", ""):
		"prop":
			return sel.cell
		"thing":
			var cell: Array = _things()[sel.i].cell
			return Vector2i(int(cell[0]), int(cell[1]))
		"group":
			var gc: Array = doc.data.groups[sel.i].units[sel.u].cell
			return Vector2i(int(gc[0]), int(gc[1]))
		"start":
			var s: Array = doc.data.start[sel.i]
			return Vector2i(int(s[0]), int(s[1]))
		"piece":
			var e: Dictionary = doc.data[sel.list][sel.i]
			return Vector2i(int(e.x), int(e.y))
	return CombatBoard.NONE


func _cells_of(sel: Dictionary) -> Array[Vector2i]:
	if sel.is_empty():
		return []
	if sel.type == "prop" and doc.grid.props.has(sel.cell):
		return _foot_cells(sel.cell, doc.grid.props[sel.cell].foot)
	return [_sel_cell(sel)]


func _select(sel: Dictionary, show_inspector := false) -> void:
	selection = sel
	_refresh_marks()
	_build_inspector()
	if show_inspector and not sel.is_empty():
		_show_page("inspect")


## The ghost of the selection while it's dragged to `to`.
func _sel_ghost(to: Vector2i) -> Dictionary:
	var at: Vector2i = _sel_cell(selection) + (to - (_move.from as Vector2i))
	if selection.type == "prop":
		var p: Dictionary = doc.grid.props[selection.cell]
		var cells := _foot_cells(at, p.foot)
		var gh := {"cells": cells, "ok": _fits(cells)}
		var tex := board.prop_texture(p)
		if p.get("blob", false) and tex == null:
			gh["blob"] = CombatBoard.blob_color(String(p.get("name", "")))
			gh["tall"] = p.tall
		elif tex != null and doc.grid.in_bounds(at):
			gh["tex"] = tex
			gh["rect"] = board._prop_rect(at, p, tex)
			gh["flip"] = p.get("flip", false)
		return gh
	var ok: bool = doc.grid.in_bounds(at) and doc.grid.solid(at) and (selection.type == "thing" or doc.grid.passable(at))
	return {"cells": [at] as Array[Vector2i], "ok": ok, "icon": "start" if selection.type != "thing" else
		MakerCatalog.thing_icon(String(_things()[selection.i].kind), String(_things()[selection.i].event))}


func _end_move() -> void:
	var to: Vector2i = _move.to
	var from: Vector2i = _move.from
	if to == from or not _sel_valid():
		_move = {}
		return
	var gh := _sel_ghost(to)
	_move = {}
	if not gh.ok:
		_say("can't put it there")
		return
	var at: Vector2i = (gh.cells as Array)[0]
	_push_undo()
	var g := doc.grid
	match selection.type:
		"prop":
			var p: Dictionary = (g.props[selection.cell] as Dictionary).duplicate()
			MapOps.remove_prop(g, selection.cell)
			_readd(at, p)
			selection.cell = at
		"thing":
			var th: Dictionary = _things()[selection.i]
			th.cell = [at.x, at.y]
			if th.has("floor") and g.terrain_at(at) != T.RUIN:
				th.floor = CombatGrid.LETTERS[g.terrain_at(at)]
		"group":
			doc.data.groups[selection.i].units[selection.u].cell = [at.x, at.y]
		"start":
			doc.data.start[selection.i] = [at.x, at.y]
		"piece":
			doc.data[selection.list][selection.i].x = at.x
			doc.data[selection.list][selection.i].y = at.y
	_refresh_marks()
	_build_inspector()


func _delete_selected() -> void:
	if not _sel_valid():
		return
	_push_undo()
	match selection.type:
		"prop":
			MapOps.remove_prop(doc.grid, selection.cell)
		"thing":
			_things().remove_at(selection.i)
		"group":
			var gd: Array = doc.data.groups
			(gd[selection.i].units as Array).remove_at(selection.u)
			if (gd[selection.i].units as Array).is_empty():
				gd.remove_at(selection.i)
		"start":
			if (doc.data.start as Array).size() <= 1:
				_say("an explore map needs a start; move it instead")
				_undo.pop_back()
				return
			doc.data.start.remove_at(selection.i)
		"piece":
			doc.data[selection.list].remove_at(selection.i)
	_select({})


func _prop_title(p: Dictionary) -> String:
	if p.get("blob", false):
		return "blob \"%s\"" % String(p.get("name", ""))
	var t := String(p.sprite).get_file().trim_prefix("prop_").trim_prefix("b_").replace("_", " ")
	return t + ((" [%s]" % p.id) if String(p.get("id", "")) != "" else "")


## Pieces, the party start, things and selection marks for the overlay.
func _refresh_marks() -> void:
	var marks: Array[Dictionary] = []
	var d := doc.data
	var sel_t := String(selection.get("type", ""))
	if doc.kind == "battle":
		for list in ["party", "enemies"]:
			var arr: Array = d.get(list, [])
			for i in arr.size():
				var e: Dictionary = arr[i]
				marks.append({"cell": Vector2i(int(e.x), int(e.y)), "color": START_COLOR if list == "party" else FOE_COLOR,
					"icon": "start" if list == "party" else "rack", "label": "",
					"selected": sel_t == "piece" and selection.list == list and int(selection.i) == i})
	else:
		var st: Array = d.get("start", [])
		for i in st.size():
			marks.append({"cell": Vector2i(int(st[i][0]), int(st[i][1])), "color": START_COLOR, "icon": "start",
				"label": "start" if i == 0 else "", "selected": sel_t == "start" and int(selection.i) == i})
		var gl: Array = d.get("groups", [])
		for gi in gl.size():
			var ul: Array = gl[gi].get("units", [])
			for ui in ul.size():
				var u: Dictionary = ul[ui]
				marks.append({"cell": Vector2i(int(u.cell[0]), int(u.cell[1])), "color": FOE_COLOR, "icon": "rack",
					"label": "boss" if bool(u.get("leader", false)) else "",
					"selected": sel_t == "group" and int(selection.i) == gi and int(selection.u) == ui})
		var things := _things()
		for i in things.size():
			var t: Dictionary = things[i]
			marks.append({"cell": Vector2i(int(t.cell[0]), int(t.cell[1])), "color": THING_COLOR,
				"icon": MakerCatalog.thing_icon(String(t.kind), String(t.get("event", ""))), "label": String(t.id),
				"selected": sel_t == "thing" and int(selection.i) == i})
	overlay.marks = marks
	overlay.selected_cells = _cells_of(selection) if _sel_valid() else ([] as Array[Vector2i])
	_refresh_outline()


# --- settings ---------------------------------------------------------------------------

func _look_id() -> String:
	if _look_pick.selected <= 0:
		return ""
	return _look_pick.get_item_text(_look_pick.selected)


func _set_look_field(key: String, value: Variant) -> void:
	if _syncing:
		return
	_push_undo()
	var l := doc.grid.look.duplicate()
	if value == null:
		l.erase(key)
	else:
		l[key] = value
	doc.grid.look = l
	_sync_ui()


## Pieces edit the battle setup the map carries: the same data the combat sandbox read.
func _setup() -> SandboxSetup:
	var s := SandboxSetup.from_dict(doc.data) if doc.data.has("map") else SandboxSetup.new()
	s.grid = doc.grid
	return s


func _store_setup(s: SandboxSetup) -> void:
	doc.data = s.to_dict()


func _piece(c: Vector2i, right: bool) -> void:
	if doc.kind != "battle":
		_say("party and enemies go on battle maps (MAP tab: kind)")
		return
	if not right and not doc.grid.passable(c):
		_say("pieces stand on walkable ground")
		return
	var s := _setup()
	if right:
		s.remove_at(c)
	elif tool == "party":
		s.place_party(String(_party_pick.get_item_metadata(_party_pick.selected)), c)
	else:
		s.place_enemy(String(_enemy_pick.get_item_metadata(_enemy_pick.selected)), c)
	_store_setup(s)
	_refresh_marks()


func _mods_of(s: SandboxSetup, side: String) -> Dictionary:
	return s.party_mods if side == "party" else s.enemy_mods


## Any fight dial change: one undo step, then the setup is written back to the map.
func _fight_edit(edit: Callable) -> void:
	if _syncing or doc.kind != "battle":
		return
	_push_undo()
	var s := _setup()
	edit.call(s)
	_store_setup(s)


func _sync_fight() -> void:
	_fight_drawer.visible = doc.kind == "battle"
	if doc.kind != "battle":
		return
	var s := _setup()
	for key in SandboxSetup.MOD_KEYS:
		_fight_spins["party.%s" % key].set_value_no_signal(s.party_mods[key])
		_fight_spins["enemy.%s" % key].set_value_no_signal(s.enemy_mods[key])
	_fight_spins["extra"].set_value_no_signal(s.extra_enemies)
	_fight_spins["medicine"].set_value_no_signal(s.supplies["medicine"])
	_fight_spins["food"].set_value_no_signal(s.supplies["food"])
	_fight_spins["seed"].set_value_no_signal(s.seed_value)
	_fight_checks["counters"].set_pressed_no_signal(s.counters)


func _sync_ui() -> void:
	_syncing = true
	_name_edit.text = doc.map_name
	_kind_pick.select(MapDoc.KINDS.find(doc.kind))
	_w_spin.value = doc.grid.w
	_h_spin.value = doc.grid.h
	_set_pick.select(0)
	for i in _set_pick.item_count:
		if i > 0 and _set_pick.get_item_text(i) == doc.art_set:
			_set_pick.select(i)
	_look_pick.select(0)
	var want := String(doc.grid.look.get("id", ""))
	for i in _look_pick.item_count:
		if i > 0 and _look_pick.get_item_text(i) == want:
			_look_pick.select(i)
	var l := MapLook.resolve(doc.grid.look, doc.art_set, doc.strangeness)
	_floor_spin.value = l.floor_h
	_skirt_spin.value = l.skirt
	_strange_spin.value = doc.strangeness
	_level_spin.value = level_h
	_sync_fight()
	_syncing = false
	_sync_options()


func _set_tool(t: String) -> void:
	tool = t
	if HEIGHT_MODES.has(t):
		height_last = t
	if not _tool_in_phase(t, phase) and _phase_buttons.size() > 0:
		_set_phase((TOOL_PHASE.get(t, ["shape"]) as Array)[0], true)  # a shortcut into another phase's tool goes there
	for k in _tool_buttons:
		_tool_buttons[k].set_pressed_no_signal(k == t or (k == "raise" and HEIGHT_MODES.has(t)))
		_tool_buttons[k].queue_redraw()
	if t != "stamp":
		_mark_tiles()
	_sync_options()


func _tool_row(id: String) -> Array:
	if HEIGHT_MODES.has(id):
		id = "raise"  # the three height modes are one tool on the rail
	for r in TOOLS:
		if r.size() > 1 and r[0] == id:
			return r
	return []


func _set_width(w: int) -> void:
	width = clampi(w, 1, 4)
	if _radius_slider != null:
		_radius_slider.set_value_no_signal(width)
		_radius_label.text = "%d" % width


func _say(text: String) -> void:
	_status.text = text
	_hover_cell = Vector2i(-77, -77)  # the next hover redraws the cell line


func _toggle_view(key: String) -> void:
	var b: MakerUI.IconButton = _view_buttons[key]
	b.button_pressed = not b.button_pressed


# --- prefs --------------------------------------------------------------------------------

func _load_prefs() -> void:
	var cf := ConfigFile.new()
	if cf.load(PREFS) != OK:
		return
	for id in cf.get_value("catalog", "recent", []):
		recent.append(String(id))
	for k in cf.get_value("catalog", "closed", []):
		_closed[String(k)] = true


func _save_prefs() -> void:
	var cf := ConfigFile.new()
	cf.set_value("catalog", "recent", recent)
	cf.set_value("catalog", "closed", _closed.keys())
	cf.save(PREFS)


func _remember(id: String) -> void:
	recent.erase(id)
	recent.push_front(id)
	while recent.size() > RECENT_MAX:
		recent.pop_back()
	_save_prefs()
	_build_recent()


# --- UI -----------------------------------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 2
	add_child(_ui)
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.scale = Vector2.ONE * UI_SCALE
	_fit_root()
	get_viewport().size_changed.connect(_fit_root)
	_root.theme = MakerUI.make_theme()
	_ui.add_child(_root)
	flat = FlatView.new()
	flat.maker = self
	flat.visible = false
	_ui.add_child(flat)
	_ui.move_child(flat, 0)  # behind the panels
	_build_top()
	_build_rail()
	_build_options()
	_build_dock()
	_bottom = _card(0)
	_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.offset_top = -BOTTOM_H
	var sb := HBoxContainer.new()
	_bottom.add_child(sb)
	_status = MakerUI.label("", 12, MakerUI.INK)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sb.add_child(_status)
	_help = MakerUI.label("", 12, MakerUI.DIM)
	_help.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_help.size_flags_stretch_ratio = 2.0
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sb.add_child(_help)
	_build_save_as()
	_show_page("assets")
	_set_phase("shape")


## The save as card, centred over a dimmed screen: a name, the maps of this kind to pick one to overwrite.
func _build_save_as() -> void:
	_save_box = ColorRect.new()
	(_save_box as ColorRect).color = Color(0, 0, 0, 0.45)
	_save_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_save_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_save_box.visible = false
	_root.add_child(_save_box)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", MakerUI.box(MakerUI.BG, 10, 16.0, MakerUI.LINE))
	card.custom_minimum_size = Vector2(420, 0)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_save_box.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	col.add_child(MakerUI.label("Save as", 17, MakerUI.ACCENT, true))
	_save_name = LineEdit.new()
	_save_name.placeholder_text = "map name, e.g. highland_02"
	_save_name.text_changed.connect(_on_save_name)
	_save_name.text_submitted.connect(func(_t: String) -> void: _confirm_save_as())
	col.add_child(_save_name)
	_save_warn = MakerUI.label("", 12, MakerUI.DIM)
	col.add_child(_save_warn)
	_save_where = MakerUI.label("", 12, MakerUI.DIM)
	col.add_child(_save_where)
	col.add_child(MakerUI.label("or pick one to overwrite:", 12, MakerUI.DIM))
	_save_list = ItemList.new()
	_save_list.custom_minimum_size = Vector2(0, 220)
	_save_list.item_selected.connect(func(i: int) -> void:
		_save_name.text = _save_list.get_item_text(i)
		_on_save_name(_save_name.text))
	_save_list.item_activated.connect(func(_i: int) -> void: _confirm_save_as())
	col.add_child(_save_list)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	_text_button(row, "Cancel", _close_save_as)
	_save_ok = _text_button(row, "Save", _confirm_save_as)


func _card(radius := 10) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := MakerUI.box(MakerUI.BG, radius, 8.0)
	if radius == 0:
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		sb.content_margin_left = 12
		sb.content_margin_right = 12
	p.add_theme_stylebox_override("panel", sb)
	_root.add_child(p)
	_panels.append(p)
	return p


func _icon(parent: Control, id: String, tip: String, cb: Callable, px := 34.0, words := "") -> MakerUI.IconButton:
	var b := MakerUI.IconButton.new(id, tip, px, words)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_top() -> void:
	_top = _card(0)
	_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top.offset_bottom = TOP_H
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	_top.add_child(bar)
	var logo := MakerUI.label("Map maker", 17, MakerUI.ACCENT, true)
	bar.add_child(logo)
	bar.add_child(MakerUI.spacer(14))
	_icon(bar, "new", "New blank map (size from the MAP tab)", new_blank)
	var open := _icon(bar, "open", "Open a map", func() -> void: pass)
	_open_menu = PopupMenu.new()
	open.add_child(_open_menu)
	_open_menu.id_pressed.connect(_on_open_menu)
	open.pressed.connect(func() -> void:
		_fill_open_menu()
		_open_menu.position = Vector2i(open.get_screen_position() + Vector2(0, open.size.y + 4))
		_open_menu.popup())
	_icon(bar, "save", "Save  (ctrl S)", save)
	_icon(bar, "save", "Save as: a new name, or over another map  (ctrl shift S)", open_save_as, 34.0, "Save as")
	bar.add_child(MakerUI.spacer(6))
	bar.add_child(MakerUI.separator(true))
	bar.add_child(MakerUI.spacer(6))
	_icon(bar, "undo", "Undo  (ctrl Z)", undo)
	_icon(bar, "redo", "Redo  (ctrl shift Z)", redo)
	bar.add_child(MakerUI.spacer(14))
	for ph in PHASES:
		var pb := MakerUI.IconButton.new("", ph[2], 34.0, ph[1])
		pb.toggle_mode = true
		pb.button_pressed = ph[0] == phase
		var pid: String = ph[0]
		pb.pressed.connect(func() -> void: _set_phase(pid))
		bar.add_child(pb)
		_phase_buttons[ph[0]] = pb
	bar.add_child(MakerUI.spacer(14))
	_title = MakerUI.label("", 14, MakerUI.INK)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(_title)
	for v in [["greybox", "greybox", "Greybox view  (K): hides every prop, building, tree and painted texture and shows the map as plain grey blocks shaded by height, to see its structure. A view only: nothing in the map changes.", false],
			["grid", "grid", "Grid lines  (G)", true], ["heights", "heights", "Height numbers", false], ["labels", "note", "Names over things and blobs", true],
			["flat", "flat", "Flat sketch mode  (Tab): a top-down grid of this map to paint ground, height, walls, water and stairs quickly. Toggle back to see it isometric.", false]]:
		var b := MakerUI.IconButton.new(v[1], v[2], 34.0)
		b.toggle_mode = true
		b.button_pressed = v[3]
		var key: String = v[0]
		b.toggled.connect(_on_view.bind(key))
		bar.add_child(b)
		_view_buttons[key] = b
	var qb := Button.new()
	qb.text = "?"
	qb.tooltip_text = "Keys  (?)"
	qb.custom_minimum_size = Vector2(30, 30)
	qb.focus_mode = Control.FOCUS_NONE
	qb.pressed.connect(_toggle_keys)
	bar.add_child(qb)
	_icon(bar, "turn", "Turn the view while editing  (Q). Players only ever see the map's own angle (MAP tab).", func() -> void: board.turn())
	_icon(bar, "fit", "Fit the map  (space)", _fit_view)
	_icon(bar, "eye", "Hide the panels  (H)", func() -> void:
		hide_ui = true
		_root.visible = false
		_fit_view())
	bar.add_child(MakerUI.spacer(8))
	var play := _icon(bar, "play", "Save and play this map", play_test, 34.0, "Play test")
	play.add_theme_color_override("font_color", MakerUI.ACCENT)
	_back_btn = Button.new()
	_back_btn.text = "Back to play"
	_back_btn.tooltip_text = "Save this map and go back to where you were playing"
	_back_btn.add_theme_color_override("font_color", MakerUI.ACCENT)
	_back_btn.pressed.connect(back_to_play)
	_back_btn.visible = false
	bar.add_child(_back_btn)


## Switch between the isometric board and the flat sketch grid (both edit doc.grid).
func set_flat(on: bool) -> void:
	if flat == null:
		return
	flat.visible = on
	board.visible = not on
	if _view_buttons.has("flat"):
		(_view_buttons["flat"] as Button).set_pressed_no_signal(on)
	if on:
		var a := _map_area()
		flat.position = a.position
		flat.size = a.size
		flat.fit()
		_say("flat view: the same tools. Tab goes back to isometric; 0-9 sets the level height")
	else:
		_refresh_marks()


func _on_view(on: bool, key: String) -> void:
	match key:
		"greybox":
			board.greybox = on
			if flat != null:
				flat.greybox = on
				flat.queue_redraw()
		"grid":
			board.show_grid = on
		"heights":
			overlay.show_heights = on
		"labels":
			overlay.show_labels = on
		"flat":
			set_flat(on)


func _build_rail() -> void:
	_rail = _card(12)
	_rail.position = Vector2(GAP, TOP_H + GAP)
	_rail.custom_minimum_size.x = RAIL_W
	var sb: StyleBoxFlat = _rail.get_theme_stylebox("panel")
	sb.set_content_margin_all(5)
	_rail_col = VBoxContainer.new()
	_rail_col.add_theme_constant_override("separation", 3)
	_rail.add_child(_rail_col)
	for r in TOOLS:
		if r.size() == 1:
			var sep := VBoxContainer.new()  # a separator with its spacing, shown only between two visible groups
			sep.add_theme_constant_override("separation", 3)
			sep.add_child(MakerUI.spacer(0, 2))
			var line := MakerUI.separator()
			line.custom_minimum_size = Vector2(36, 1)
			sep.add_child(line)
			sep.add_child(MakerUI.spacer(0, 2))
			_rail_col.add_child(sep)
			_rail_seps.append(sep)
			continue
		var b := MakerUI.IconButton.new(r[1], "%s  (%s)\n%s" % [r[3], r[2], r[4]], 42.0)
		b.toggle_mode = true
		b.pressed.connect(func() -> void: _set_tool(height_last if r[0] == "raise" else String(r[0])))
		_rail_col.add_child(b)
		_tool_buttons[r[0]] = b
	_fill_rail()


func _tool_in_phase(id: String, ph: String) -> bool:
	return (TOOL_PHASE.get(id, ["shape"]) as Array).has(ph)


## The rail shows only this phase's tools (grouped by the separators between them).
func _fill_rail() -> void:
	var pending: VBoxContainer = null
	var any := false
	var si := 0
	for sep in _rail_seps:
		sep.visible = false
	for r in TOOLS:
		if r.size() == 1:
			pending = _rail_seps[si]
			si += 1
			continue
		var vis := _tool_in_phase(String(r[0]), phase)
		_tool_buttons[r[0]].visible = vis
		if vis:
			if pending != null and any:
				pending.visible = true
			pending = null
			any = true


## Move to a phase: its tools, its assets, its tabs. The current tool stays when the phase has it; otherwise the phase's
## first tool takes over.
func _set_phase(ph: String, keep_tool := false) -> void:
	phase = ph
	for k in _phase_buttons:
		_phase_buttons[k].set_pressed_no_signal(k == ph)
		_phase_buttons[k].queue_redraw()
	_fill_rail()
	if not keep_tool and not _tool_in_phase(tool, ph):
		_set_tool({"shape": "raise", "decor": "stamp", "play": "select"}[ph])
	for k in _tabs:
		_tabs[k].visible = (PHASE_PAGES[ph] as Array).has(k)
	var cur := ""
	for k in _pages:
		if _pages[k].visible:
			cur = k
	if cur == "" or not (PHASE_PAGES[ph] as Array).has(cur):
		_show_page(PHASE_PAGES[ph][0])
	_build_catalog()


func _build_options() -> void:
	_opts = _card(10)
	_opts.position = Vector2(GAP * 2 + RAIL_W, TOP_H + GAP)
	_opts.custom_minimum_size.y = OPT_H
	var sb: StyleBoxFlat = _opts.get_theme_stylebox("panel")
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_opts.add_child(row)
	var name_l := MakerUI.label("", 14, MakerUI.ACCENT, true)
	name_l.name = "ToolName"
	row.add_child(name_l)
	# brush size and shape
	var brush := HBoxContainer.new()
	brush.add_theme_constant_override("separation", 6)
	brush.add_child(MakerUI.separator(true))
	brush.add_child(MakerUI.label("size", 12, MakerUI.DIM))
	_radius_slider = HSlider.new()
	_radius_slider.min_value = 1
	_radius_slider.max_value = 4
	_radius_slider.step = 1
	_radius_slider.custom_minimum_size = Vector2(90, 20)
	_radius_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_radius_slider.tooltip_text = "Size: how many cells wide a brush, path, river, bridge or stair is (1 to 4).  [ and ] change it."
	_radius_slider.focus_mode = Control.FOCUS_NONE
	_radius_slider.value_changed.connect(func(v: float) -> void: _set_width(int(v)))
	brush.add_child(_radius_slider)
	_radius_label = MakerUI.label("1", 12, MakerUI.INK)
	_radius_label.custom_minimum_size.x = 14
	brush.add_child(_radius_label)
	for shp in [["diamond", false, "Round brush"], ["square", true, "Square brush"]]:
		var b := MakerUI.IconButton.new(shp[0], shp[2], 30.0)
		b.toggle_mode = true
		b.button_pressed = shp[1] == square
		var sq: bool = shp[1]
		b.pressed.connect(func() -> void:
			square = sq
			for o in _shape_buttons:
				o.set_pressed_no_signal(o.icon_id == ("square" if sq else "diamond"))
				o.queue_redraw())
		brush.add_child(b)
		_shape_buttons.append(b)
	row.add_child(brush)
	_opt_groups["brush"] = brush
	# the height tool's three modes: up, flat, down
	var hm := HBoxContainer.new()
	hm.add_theme_constant_override("separation", 3)
	hm.add_child(MakerUI.separator(true))
	for m in [["raise", "h_up", "Raise: up one level  (right click: down)"], ["level", "h_flat", "Flatten: into a terrace at the height box  (right click takes a cell's height)"],
			["lower", "h_down", "Lower: down one level  (right click: up)"]]:
		var hb := MakerUI.IconButton.new(m[1], m[2], 30.0)
		hb.toggle_mode = true
		var mode: String = m[0]
		hb.pressed.connect(func() -> void: _set_tool(mode))
		hm.add_child(hb)
		_height_buttons[mode] = hb
	row.add_child(hm)
	_opt_groups["heightmode"] = hm
	# level height
	var lvl := HBoxContainer.new()
	lvl.add_child(MakerUI.separator(true))
	lvl.add_child(MakerUI.label("height", 12, MakerUI.DIM))
	_level_spin = _spin(lvl, 0, CombatGrid.MAX_HEIGHT, 1, level_h)
	_level_spin.value_changed.connect(func(v: float) -> void: level_h = int(v))
	row.add_child(lvl)
	_opt_groups["level"] = lvl
	# ground swatches
	var ground := HBoxContainer.new()
	ground.add_theme_constant_override("separation", 3)
	ground.add_child(MakerUI.separator(true))
	for mat in MATERIALS:
		if mat[2] != "" and not BattleArt.sets().has(mat[2]):
			continue  # no art for that set in this build
		var label: String = mat[0]
		var mset: String = mat[2]
		var pick := func(t: int) -> void:
			paint_t = t
			paint_set = mset
			paint_mat = label
		ground.add_child(_swatch(label, mat[1], _ground_buttons, pick, mset))
	row.add_child(ground)
	_opt_groups["paint"] = ground
	var path := HBoxContainer.new()
	path.add_theme_constant_override("separation", 3)
	path.add_child(MakerUI.separator(true))
	for gnd in PATH_GROUNDS:
		path.add_child(_swatch(gnd[0], gnd[1], _path_buttons, func(t: int) -> void: path_t = t))
	var follow := CheckBox.new()
	follow.text = "follow ground"
	follow.tooltip_text = "Find the easiest walk between where you press and where you let go"
	follow.focus_mode = Control.FOCUS_NONE
	follow.toggled.connect(func(on: bool) -> void: follow_ground = on)
	path.add_child(follow)
	row.add_child(path)
	_opt_groups["path"] = path
	var zone := HBoxContainer.new()
	zone.add_child(MakerUI.separator(true))
	zone.add_child(MakerUI.label("tile set", 12, MakerUI.DIM))
	_zone_pick = OptionButton.new()
	_zone_pick.add_item("map's own set")
	_zone_pick.set_item_metadata(0, "")
	for s in BattleArt.sets():
		_zone_pick.add_item(s)
		_zone_pick.set_item_metadata(_zone_pick.item_count - 1, s)
	_zone_pick.focus_mode = Control.FOCUS_NONE
	zone.add_child(_zone_pick)
	row.add_child(zone)
	_opt_groups["zone"] = zone
	var area := HBoxContainer.new()
	area.add_theme_constant_override("separation", 6)
	area.add_child(MakerUI.separator(true))
	var up := Button.new()
	up.text = "Raise ▲"
	up.tooltip_text = "Raise every selected cell one level (PageUp)"
	up.pressed.connect(func() -> void: region_shift(1))
	area.add_child(up)
	var down := Button.new()
	down.text = "Lower ▼"
	down.tooltip_text = "Lower every selected cell one level (PageDown)"
	down.pressed.connect(func() -> void: region_shift(-1))
	area.add_child(down)
	var clr := Button.new()
	clr.text = "Clear"
	clr.pressed.connect(func() -> void: region = {})
	area.add_child(clr)
	for b in [up, down, clr]:
		b.focus_mode = Control.FOCUS_NONE
	row.add_child(area)
	_opt_groups["region"] = area
	var stamp := HBoxContainer.new()
	stamp.add_theme_constant_override("separation", 6)
	stamp.add_child(MakerUI.separator(true))
	_stamp_label = MakerUI.label("", 13, MakerUI.INK)
	stamp.add_child(_stamp_label)
	_stamp_angles = MakerUI.label("", 12, MakerUI.DIM)
	stamp.add_child(_stamp_angles)
	_icon(stamp, "rotate", "Turn  (R): the next painted angle, or a mirror when there is only one", _turn_item, 30.0)
	_icon(stamp, "mirror", "Mirror  (M)", _mirror_item, 30.0)
	row.add_child(stamp)
	_opt_groups["stamp"] = stamp
	var party_row := HBoxContainer.new()
	party_row.add_theme_constant_override("separation", 6)
	party_row.add_child(MakerUI.label("who", 12, MakerUI.DIM))
	_party_pick = OptionButton.new()
	for d in Db.roster():
		_party_pick.add_item(Txt.t(d.name_key))
		_party_pick.set_item_metadata(_party_pick.item_count - 1, String(d.id))
	party_row.add_child(_party_pick)
	row.add_child(party_row)
	_opt_groups["party"] = party_row
	var foe_row := HBoxContainer.new()
	foe_row.add_theme_constant_override("separation", 6)
	foe_row.add_child(MakerUI.label("who", 12, MakerUI.DIM))
	_enemy_pick = OptionButton.new()
	for id in Db.class_ids():
		_enemy_pick.add_item(id)
		_enemy_pick.set_item_metadata(_enemy_pick.item_count - 1, id)
	foe_row.add_child(_enemy_pick)
	row.add_child(foe_row)
	_opt_groups["enemy"] = foe_row
	var sel := HBoxContainer.new()
	sel.add_theme_constant_override("separation", 6)
	sel.add_child(MakerUI.separator(true))
	_icon(sel, "rotate", "Turn the selection  (R)", _turn_item, 30.0)
	_icon(sel, "mirror", "Mirror the selection  (M)", _mirror_item, 30.0)
	_icon(sel, "stamp", "Copy the selection to the stamp  (ctrl D)", _copy_to_stamp, 30.0)
	_icon(sel, "trash", "Delete the selection  (Del)", _delete_selected, 30.0)
	row.add_child(sel)
	_opt_groups["select"] = sel
	_set_width(width)


## A ground swatch: a little tile of the set's own ground texture.
func _swatch(id: String, t: int, group: Dictionary, cb: Callable, tile_set := "") -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(36, 34)
	b.tooltip_text = id
	b.draw.connect(func() -> void:
		var tex := BattleArt.top(t, tile_set if tile_set != "" else (doc.art_set if doc != null else ""))
		var c := b.size * 0.5 + Vector2(0, -1)
		var hw := 13.0
		var pts := PackedVector2Array([c + Vector2(0, -hw * 0.55), c + Vector2(hw, 0), c + Vector2(0, hw * 0.55), c + Vector2(-hw, 0)])
		if tex != null:
			b.draw_polygon(pts, PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]),
				PackedVector2Array([Vector2(0.5, 0), Vector2(1, 0.5), Vector2(0.5, 1), Vector2(0, 0.5)]), tex)
		else:
			b.draw_colored_polygon(pts, CombatBoard.TOP_COLORS.get(t, Color.GRAY))
		pts.append(pts[0])
		b.draw_polyline(pts, Color(0, 0, 0, 0.4), 1.0, true))
	b.pressed.connect(func() -> void:
		cb.call(t)
		for k in group:
			group[k].set_pressed_no_signal(k == id))
	group[id] = b
	b.button_pressed = (id == paint_mat) if group == _ground_buttons else (t == path_t)
	return b


func _sync_options() -> void:
	if _opts == null:
		return
	var row := _tool_row(tool)
	(_opts.get_child(0).get_node("ToolName") as Label).text = String(row[3]) if not row.is_empty() else ""
	_help.text = String(row[4]) if not row.is_empty() else ""
	_opt_groups.brush.visible = BRUSH_TOOLS.has(tool) or tool == "bridge" or tool == "stairs"
	for o in _shape_buttons:  # the brush shape only matters to the brushes
		o.visible = BRUSH_TOOLS.has(tool)
	_opt_groups.level.visible = tool == "level" or tool == "deck"
	_opt_groups.heightmode.visible = HEIGHT_MODES.has(tool)
	for m in _height_buttons:
		(_height_buttons[m] as MakerUI.IconButton).set_pressed_no_signal(m == tool)
	_opt_groups.paint.visible = tool == "paint"
	_opt_groups.path.visible = tool == "path"
	_opt_groups.zone.visible = tool == "zone"
	_opt_groups.region.visible = tool == "region"
	_opt_groups.stamp.visible = tool == "stamp"
	_opt_groups.party.visible = tool == "party"
	_opt_groups.enemy.visible = tool == "enemy"
	_opt_groups.select.visible = tool == "select" and not selection.is_empty()
	for k in _ground_buttons:
		_ground_buttons[k].queue_redraw()
	for k in _path_buttons:
		_path_buttons[k].queue_redraw()
	if tool == "stamp":
		if item.is_empty():
			_stamp_label.text = "pick something in the catalog"
			_stamp_angles.text = ""
		else:
			_stamp_label.text = "%s  %dx%d" % [item.label, item_foot.x, item_foot.y]
			var n := MakerCatalog.angles(String(item.sprite)).size() if item.kind == "prop" else 1
			_stamp_angles.text = ("%d angles" % n if n > 1 else "1 angle") + ("  mirrored" if item_flip else "")
	_opts.reset_size()


# --- dock -----------------------------------------------------------------------------------

func _build_dock() -> void:
	_dock = _card(12)
	_dock.anchor_left = 1.0
	_dock.anchor_right = 1.0
	_dock.anchor_bottom = 1.0
	_dock.offset_left = -DOCK_W - GAP
	_dock.offset_right = -GAP
	_dock.offset_top = TOP_H + GAP
	_dock.offset_bottom = -BOTTOM_H - GAP
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_dock.add_child(col)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	col.add_child(tabs)
	for t in [["assets", "assets", "Assets"], ["inspect", "inspect", "Inspector"], ["map", "map", "Map"]]:
		var b := MakerUI.IconButton.new(t[1], "", 32.0, t[2])
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_show_page.bind(String(t[0])))
		tabs.add_child(b)
		_tabs[t[0]] = b
		var page := ScrollContainer.new()
		page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(page)
		var body := VBoxContainer.new()
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_theme_constant_override("separation", 6)
		page.add_child(body)
		_pages[t[0]] = page
	_build_assets_page(_pages.assets.get_child(0))
	_insp_box = _pages.inspect.get_child(0)
	_build_map_page(_pages.map.get_child(0))


func _show_page(id: String) -> void:
	for k in _pages:
		_pages[k].visible = k == id
		_tabs[k].set_pressed_no_signal(k == id)
		_tabs[k].queue_redraw()


func _build_assets_page(body: VBoxContainer) -> void:
	var srow := HBoxContainer.new()
	body.add_child(srow)
	_search = LineEdit.new()
	_search.placeholder_text = "search assets"
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_t: String) -> void: _build_catalog())
	srow.add_child(_search)
	body.add_child(MakerUI.label("RECENT", 11, MakerUI.DIM))
	_recent_row = HFlowContainer.new()
	_recent_row.add_theme_constant_override("h_separation", 4)
	_recent_row.add_theme_constant_override("v_separation", 4)
	body.add_child(_recent_row)
	_cat_box = VBoxContainer.new()
	_cat_box.add_theme_constant_override("separation", 6)
	body.add_child(_cat_box)


func _tile_for(e: Dictionary) -> MakerUI.AssetTile:
	var tex: Texture2D = BattleArt.texture(String(e.sprite)) if e.kind == "prop" else null
	var tip := "%s\n%s > %s\n%dx%d" % [e.label, e.drawer, e.group, e.foot.x, e.foot.y]
	if e.kind == "prop":
		var n := MakerCatalog.angles(String(e.sprite)).size()
		tip += "   %d angle%s" % [n, "s" if n > 1 else ""]
	elif e.kind == "thing":
		tip += "   event " + (String(e.event) if e.event != "" else "(none)")
	if not _kind_ok(e.kind):
		tip += "\nexplore maps only"
	var t := MakerUI.AssetTile.new(e, tex, tip)
	t.disabled = not _kind_ok(e.kind)
	t.picked.connect(pick_item)
	t.drag_started.connect(func(en: Dictionary) -> void:
		pick_item(en)
		_drag_item = true)
	t.drag_ended.connect(func(_en: Dictionary) -> void:
		_drag_item = false
		var mouse := get_viewport().get_mouse_position()
		if _over_ui(mouse):
			return
		var c := _cell_under_mouse()
		if c != CombatBoard.NONE:
			_push_undo()
			_stroke = {"button": MOUSE_BUTTON_LEFT, "done": {}}
			_stamp(c)
			_stroke = {})
	t.button_pressed = not item.is_empty() and item.id == e.id and tool == "stamp"
	_tiles.append(t)
	return t


func _build_catalog() -> void:
	if _cat_box == null or doc == null:
		return
	for c in _cat_box.get_children():
		c.queue_free()
	_tiles.clear()
	_build_recent()
	var q := _search.text.strip_edges()
	if q != "":
		var hits := MakerCatalog.search(q).filter(func(e: Dictionary) -> bool: return _entry_in_phase(e))
		_cat_box.add_child(MakerUI.label("%d found" % hits.size(), 11, MakerUI.DIM))
		var flow := _flow()
		for e in hits:
			flow.add_child(_tile_for(e))
		_cat_box.add_child(flow)
		return
	for dname in MakerCatalog.drawers():
		if not _drawer_in_phase(dname):
			continue
		var groups: Array[String] = []
		var count := 0
		for e in MakerCatalog.entries():
			if e.drawer == dname:
				count += 1
				if not groups.has(e.group):
					groups.append(e.group)
		var drawer := MakerUI.Drawer.new(dname, dname, count, not _closed.has(dname))
		drawer.toggled_open.connect(_on_drawer)
		_cat_box.add_child(drawer)
		for gname in groups:
			var key := dname + "/" + gname
			var sub := MakerUI.Drawer.new(key, gname, -1, not _closed.has(key), 12, true)
			sub.toggled_open.connect(_on_drawer)
			drawer.body.add_child(sub)
			var flow := _flow()
			for e in MakerCatalog.entries():
				if e.drawer == dname and e.group == gname:
					flow.add_child(_tile_for(e))
			sub.body.add_child(flow)


func _drawer_in_phase(dname: String) -> bool:
	return PLAY_DRAWERS.has(dname) == (phase == "play")


func _entry_in_phase(e: Dictionary) -> bool:
	return _drawer_in_phase(String(e.drawer))


func _flow() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 4)
	f.add_theme_constant_override("v_separation", 4)
	return f


func _build_recent() -> void:
	for c in _recent_row.get_children():
		_recent_row.remove_child(c)
		_tiles.erase(c)
		c.queue_free()
	for id in recent:
		var e := MakerCatalog.by_id(id)
		if not e.is_empty():
			var t := _tile_for(e)
			t.custom_minimum_size = Vector2(48, 54)
			_recent_row.add_child(t)
	_recent_row.get_parent().get_child(_recent_row.get_index() - 1).visible = not recent.is_empty()


func _on_drawer(key: String, open: bool) -> void:
	if open:
		_closed.erase(key)
	else:
		_closed[key] = true
	_save_prefs()


func _mark_tiles() -> void:
	for t in _tiles:
		if is_instance_valid(t):
			t.set_pressed_no_signal(tool == "stamp" and not item.is_empty() and t.entry.id == item.id)
			t.queue_redraw()


# --- inspector -----------------------------------------------------------------------------

func _build_inspector() -> void:
	if _insp_box == null:
		return
	for c in _insp_box.get_children():
		_insp_box.remove_child(c)
		c.queue_free()
	_sync_options()
	if not _sel_valid():
		_insp_box.add_child(MakerUI.label("Nothing selected", 15, MakerUI.INK, true))
		var hint := MakerUI.label("Pick the select tool (V) and click a prop, blob, door or the party start. Names and notes set here are what Claude reads when you ask for a door's behaviour or a blob's art.", 12, MakerUI.DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_insp_box.add_child(hint)
	else:
		match selection.type:
			"prop":
				_inspect_prop()
			"thing":
				_inspect_thing()
			"group":
				_inspect_group()
			"start", "piece":
				var c := _sel_cell(selection)
				_insp_box.add_child(MakerUI.label("Party start" if selection.type == "start" else String(doc.data[selection.list][selection.i].id), 15, MakerUI.INK, true))
				_insp_box.add_child(MakerUI.label("cell %d, %d  ·  drag it to move it" % [c.x, c.y], 12, MakerUI.DIM))
	_insp_box.add_child(MakerUI.spacer(0, 6))
	var d := MakerUI.Drawer.new("outline", "On this map", -1, true, 13)
	_insp_box.add_child(d)
	_outline = ItemList.new()
	_outline.auto_height = true
	_outline.focus_mode = Control.FOCUS_NONE
	_outline.item_clicked.connect(func(i: int, _p: Vector2, _b: int) -> void:
		var sel: Dictionary = _outline_sel[i]
		_select(sel)
		_look_at(_sel_cell(sel)))
	d.body.add_child(_outline)
	_refresh_outline()


## The named things on the map: interactables, blobs and props with an id or a note.
func _refresh_outline() -> void:
	if _outline == null or not is_instance_valid(_outline):
		return
	_outline.clear()
	_outline_sel.clear()
	if doc.kind == "explore":
		var things := _things()
		for i in things.size():
			var t: Dictionary = things[i]
			_outline.add_item("%s   %s%s" % [t.id, t.kind, "   ✎" if String(t.get("note", "")) != "" else ""])
			_outline_sel.append({"type": "thing", "i": i})
	var anchors: Array = doc.grid.props.keys()
	anchors.sort()
	for a: Vector2i in anchors:
		var p: Dictionary = doc.grid.props[a]
		if p.get("blob", false) or String(p.get("id", "")) != "" or String(p.get("note", "")) != "":
			_outline.add_item("%s%s" % [_prop_title(p), "   ✎" if String(p.get("note", "")) != "" else ""])
			_outline_sel.append({"type": "prop", "cell": a})
	if _outline.item_count == 0:
		_outline.add_item("(no named things yet)")
		_outline.set_item_disabled(0, true)
		_outline_sel.append({})
	for i in _outline_sel.size():
		if _outline_sel[i] == selection and not selection.is_empty():
			_outline.select(i)


func _row(label: String, c: Control) -> Control:
	var row := HBoxContainer.new()
	var l := MakerUI.label(label, 12, MakerUI.DIM)
	l.custom_minimum_size.x = 64
	row.add_child(l)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(c)
	_insp_box.add_child(row)
	return c


func _line_field(label: String, value: String, placeholder: String, commit: Callable) -> LineEdit:
	var e := LineEdit.new()
	e.text = value
	e.placeholder_text = placeholder
	e.text_submitted.connect(func(t: String) -> void:
		commit.call(t)
		e.release_focus())
	e.focus_exited.connect(func() -> void:
		if e.text != value:
			commit.call(e.text))
	_row(label, e)
	return e


func _note_field(value: String, commit: Callable) -> void:
	_insp_box.add_child(MakerUI.label("note for Claude", 12, MakerUI.DIM))
	var t := TextEdit.new()
	t.text = value
	t.placeholder_text = "what it should do or look like, e.g. barred from the other side; a strong character can smash it"
	t.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	t.custom_minimum_size.y = 84
	t.focus_exited.connect(func() -> void:
		if t.text != value:
			commit.call(t.text))
	_insp_box.add_child(t)


func _num_field(label: String, value: float, lo: float, hi: float, step: float, commit: Callable) -> void:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.value_changed.connect(func(v: float) -> void: commit.call(v))
	_row(label, s)


func _inspect_prop() -> void:
	var a: Vector2i = selection.cell
	var p: Dictionary = doc.grid.props[a]
	var blob: bool = p.get("blob", false)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var sw := ColorRect.new()
	sw.color = CombatBoard.blob_color(String(p.get("name", ""))) if blob else MakerUI.RAISED
	sw.custom_minimum_size = Vector2(14, 14)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if blob:
		head.add_child(sw)
	head.add_child(MakerUI.label(("Blob  " + String(p.get("name", ""))) if blob else _prop_title(p), 15, MakerUI.INK, true))
	_insp_box.add_child(head)
	_insp_box.add_child(MakerUI.label("cell %d, %d  ·  %dx%d  ·  %s" % [a.x, a.y, p.foot.x, p.foot.y,
		"placeholder" if blob else String(p.sprite)], 12, MakerUI.DIM))
	if blob:
		_line_field("name", String(p.get("name", "")), "e.g. what it stands for", func(t: String) -> void:
			var n := t.strip_edges()
			if n == "":
				return
			_change_prop(func(q: Dictionary) -> void:
				q["name"] = n
				q["sprite"] = "ph_" + MakerCatalog.slug(n)))
		var stem := String(p.sprite)
		var has_art := BattleArt.texture(stem) != null
		var art := MakerUI.label(("art found: %s.png" if has_art else "art goes in art/source/battle/%s.png (then it replaces the blob)") % stem, 11,
			MakerUI.GOOD if has_art else MakerUI.DIM)
		art.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_insp_box.add_child(art)
		_num_field("width", p.foot.x, 1, 8, 1, func(v: float) -> void:
			_change_prop(func(q: Dictionary) -> void: q["foot"] = Vector2i(int(v), q.foot.y)))
		_num_field("depth", p.foot.y, 1, 8, 1, func(v: float) -> void:
			_change_prop(func(q: Dictionary) -> void: q["foot"] = Vector2i(q.foot.x, int(v))))
	else:
		var n := MakerCatalog.angles(String(p.sprite) if String(p.sprite).contains("/") or doc.art_set == "" else doc.art_set + "/" + String(p.sprite)).size()
		_insp_box.add_child(MakerUI.label("angle %d of %d%s" % [int(p.get("face", 0)) + 1, n, "  ·  mirrored" if p.get("flip", false) else ""], 12, MakerUI.DIM))
		_line_field("id", String(p.get("id", "")), "optional, to script it by", func(t: String) -> void:
			var id := MakerCatalog.slug(t)
			_change_prop(func(q: Dictionary) -> void:
				if id == "":
					q.erase("id")
				else:
					q["id"] = id))
	_num_field("height", p.tall, 0, 4, 0.05, func(v: float) -> void:
		_change_prop(func(q: Dictionary) -> void: q["tall"] = v))
	_num_field("blocks sight", p.sight, 0, 4, 0.5, func(v: float) -> void:
		_change_prop(func(q: Dictionary) -> void: q["sight"] = v))
	var walk := CheckBox.new()
	walk.text = "can be stood on (a rug)"
	walk.button_pressed = p.walk
	walk.toggled.connect(func(on: bool) -> void: _change_prop(func(q: Dictionary) -> void: q["walk"] = on))
	_insp_box.add_child(walk)
	_note_field(String(p.get("note", "")), func(t: String) -> void:
		_change_prop(func(q: Dictionary) -> void:
			if t.strip_edges() == "":
				q.erase("note")
			else:
				q["note"] = t.strip_edges()))


func _inspect_thing() -> void:
	var th: Dictionary = _things()[selection.i]
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(MakerUI.label(String(th.id), 15, MakerUI.INK, true))
	_insp_box.add_child(head)
	_insp_box.add_child(MakerUI.label("%s  ·  cell %d, %d  ·  on %s" % [th.kind, int(th.cell[0]), int(th.cell[1]), doc.map_name], 12, MakerUI.DIM))
	_line_field("id", String(th.id), "unique on this map", func(t: String) -> void:
		var id := MakerCatalog.slug(t)
		if id == "" or id == th.id:
			return
		if _unique_id(id) != "%s_01" % id and _id_taken(id):
			_say("another thing on this map is already called " + id)
			_build_inspector()
			return
		_set_thing("id", id))
	var kind := OptionButton.new()
	for k in MakerCatalog.THING_KINDS:
		kind.add_item(k)
	kind.select(maxi(0, MakerCatalog.THING_KINDS.find(String(th.kind))))
	kind.item_selected.connect(func(i: int) -> void: _set_thing("kind", MakerCatalog.THING_KINDS[i]))
	_row("kind", kind)
	var ev := OptionButton.new()
	ev.add_item("(none)")
	var ids := _event_ids()
	for id in ids:
		ev.add_item(id)
		if id == String(th.get("event", "")):
			ev.select(ev.item_count - 1)
	ev.item_selected.connect(func(i: int) -> void: _set_thing("event", "" if i == 0 else ids[i - 1]))
	_row("event", ev)
	if th.kind == "enter":
		var to := OptionButton.new()
		to.add_item("(pick a map)")
		var maps := ExploreMap.list_maps()
		for m in maps:
			to.add_item(m)
			if m == String(th.get("to", "")):
				to.select(to.item_count - 1)
		to.item_selected.connect(func(i: int) -> void: _set_thing("to", "" if i == 0 else maps[i - 1]))
		_row("leads to", to)
		var at: Array = th.get("at", [-1, -1])
		_num_field("arrive x", int(at[0]), -1, MAX_SIZE, 1, func(v: float) -> void: _set_thing("at", [int(v), int(th.get("at", [-1, -1])[1])]))
		_num_field("arrive y", int(at[1]), -1, MAX_SIZE, 1, func(v: float) -> void: _set_thing("at", [int(th.get("at", [-1, -1])[0]), int(v)]))
	_line_field("gone if", String(th.get("once", "")), "flags, a|b: once any is set it's gone", func(t: String) -> void: _set_thing("once", t.strip_edges()))
	_note_field(String(th.get("note", "")), func(t: String) -> void: _set_thing("note", t.strip_edges()))


## A foe group's fight goals (FightGoals; docs/systems/combat.md): any one met wins. Set per group; the clicked
## unit can be marked the leader. Written to the group's `goals` ("leader|exit"), `exit` and the unit's `leader`.
func _inspect_group() -> void:
	var gr: Dictionary = doc.data.groups[selection.i]
	var unit: Dictionary = gr.units[selection.u]
	_insp_box.add_child(MakerUI.label("Foe group %s" % String(gr.get("id", "")), 15, MakerUI.INK, true))
	_insp_box.add_child(MakerUI.label("%s  ·  unit %d of %d  ·  drag to move it" % [String(unit.get("id", "")), int(selection.u) + 1, (gr.units as Array).size()], 12, MakerUI.DIM))
	var goals := String(gr.get("goals", "")).split("|", false)
	_insp_box.add_child(MakerUI.label("Win by (any one)", 12, MakerUI.DIM))
	var hold := 0
	var kinds := {"defeat": false, "leader": false, "exit": false}
	for g in goals:
		if g.begins_with("hold:"):
			hold = int(g.get_slice(":", 1))
		elif kinds.has(g):
			kinds[g] = true
	if goals.is_empty():
		kinds.defeat = true
	for k in ["defeat", "leader", "exit"]:
		var cb := CheckBox.new()
		cb.text = {"defeat": "defeat every foe", "leader": "beat the leader", "exit": "everyone on the exit"}[k]
		cb.button_pressed = kinds[k]
		cb.toggled.connect(func(on: bool) -> void:
			kinds[k] = on
			_set_group_goals(kinds, hold))
		_insp_box.add_child(cb)
	_num_field("hold N rounds", hold, 0, 30, 1, func(v: float) -> void:
		hold = int(v)
		_set_group_goals(kinds, hold))
	var lead := CheckBox.new()
	lead.text = "this unit is the leader (BOSS)"
	lead.button_pressed = bool(unit.get("leader", false))
	lead.toggled.connect(func(on: bool) -> void:
		_push_undo()
		if on:
			unit["leader"] = true
		else:
			unit.erase("leader")
		_build_inspector())
	_insp_box.add_child(lead)
	var ex := PackedStringArray()
	for c in gr.get("exit", []):
		ex.append("%d,%d" % [int(c[0]), int(c[1])])
	_line_field("exit cells", ";".join(ex), "x,y;x,y  (the green ring)", func(t: String) -> void:
		var cells: Array = []
		for part in t.split(";", false):
			var xy := part.split(",", false)
			if xy.size() == 2 and xy[0].strip_edges().is_valid_int() and xy[1].strip_edges().is_valid_int():
				cells.append([int(xy[0]), int(xy[1])])
		_push_undo()
		if cells.is_empty():
			gr.erase("exit")
		else:
			gr["exit"] = cells
		_build_inspector())


func _set_group_goals(kinds: Dictionary, hold: int) -> void:
	if not _sel_valid() or selection.type != "group":
		return
	var parts: Array[String] = []
	for k in ["defeat", "leader", "exit"]:
		if kinds[k]:
			parts.append(k)
	if hold > 0:
		parts.append("hold:%d" % hold)
	_push_undo()
	var gr: Dictionary = doc.data.groups[selection.i]
	if parts.is_empty() or parts == ["defeat"]:
		gr.erase("goals")
	else:
		gr["goals"] = "|".join(parts)
	_build_inspector()


func _id_taken(id: String) -> bool:
	for t in _things():
		if String(t.id) == id:
			return true
	for a: Vector2i in doc.grid.props:
		if String(doc.grid.props[a].get("id", "")) == id:
			return true
	return false


func _set_thing(key: String, value: Variant) -> void:
	if not _sel_valid() or selection.type != "thing":
		return
	_push_undo()
	var th: Dictionary = _things()[selection.i]
	if (value is String and value == "" and key in ["note", "once"]):
		th.erase(key)
	else:
		th[key] = value
	_refresh_marks()
	_build_inspector()


func _event_ids() -> Array[String]:
	var out: Array[String] = []
	for row in CsvTable.load_rows("res://data/explore_events.csv"):
		out.append(String(row.id))
	return out


# --- map page -----------------------------------------------------------------------------

func _build_map_page(body: VBoxContainer) -> void:
	var m := MakerUI.Drawer.new("map/file", "Map", -1, true, 14)
	body.add_child(m)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "map name, e.g. goblin_cave_01"
	_name_edit.text_changed.connect(func(t: String) -> void: if not _syncing: doc.map_name = t)
	m.body.add_child(_name_edit)
	_kind_pick = OptionButton.new()
	_kind_pick.add_item("battle map (data/maps)")
	_kind_pick.add_item("explore map (data/explore)")
	_kind_pick.item_selected.connect(func(i: int) -> void:
		if not _syncing:
			doc.kind = MapDoc.KINDS[i]
			selection = {}
			_refresh_marks()
			_build_inspector()
			_build_catalog())
	m.body.add_child(_kind_pick)
	var size_row := HBoxContainer.new()
	m.body.add_child(size_row)
	size_row.add_child(MakerUI.label("size", 12, MakerUI.DIM))
	_w_spin = _spin(size_row, 6, MAX_SIZE, 1, MapGen.FIGHT_W)
	size_row.add_child(MakerUI.label("x", 12, MakerUI.DIM))
	_h_spin = _spin(size_row, 6, MAX_SIZE, 1, MapGen.FIGHT_H)
	var rs := Button.new()
	rs.text = "Resize"
	rs.pressed.connect(_resize)
	size_row.add_child(rs)
	var lk := MakerUI.Drawer.new("map/look", "Look", -1, true, 14)
	body.add_child(lk)
	_set_pick = OptionButton.new()
	_set_pick.add_item("forest")
	for s in BattleArt.sets():
		_set_pick.add_item(s)
	_set_pick.item_selected.connect(func(i: int) -> void:
		if _syncing:
			return
		_push_undo()
		doc.art_set = "" if i == 0 else _set_pick.get_item_text(i)
		board.art_set = doc.art_set
		_sync_ui())
	_labeled(lk.body, "tiles", _set_pick)
	_look_pick = OptionButton.new()
	_look_pick.add_item("as the tiles")
	for id in MapLook.ids():
		_look_pick.add_item(id)
	_look_pick.item_selected.connect(func(i: int) -> void:
		_set_look_field("id", null if i == 0 else _look_pick.get_item_text(i)))
	_labeled(lk.body, "look", _look_pick)
	var wall_check := CheckBox.new()
	wall_check.text = "wallpaper and foreground"
	wall_check.button_pressed = board.wallpaper
	wall_check.toggled.connect(func(on: bool) -> void: board.wallpaper = on)
	lk.body.add_child(wall_check)
	var vrow := HBoxContainer.new()
	lk.body.add_child(vrow)
	_text_button(vrow, "Use this view as the map's angle", func() -> void:
		_push_undo()
		doc.view = board.rot
		_say("players see this map from this angle now (turn %d)" % doc.view))
	_text_button(vrow, "Back to it", func() -> void: board.rot = doc.view)
	_floor_spin = _spin_row(lk.body, "cliff depth", -12, -1, 1, func(v: float) -> void: _set_look_field("floor", int(v)))
	_skirt_spin = _spin_row(lk.body, "forest rings", 0, 5, 1, func(v: float) -> void: _set_look_field("skirt", int(v)))
	_strange_spin = _spin_row(lk.body, "strangeness", 0, 1, 0.05, func(v: float) -> void:
		if _syncing:
			return
		doc.strangeness = v
		board.strangeness = v)
	var fight := MakerUI.Drawer.new("map/fight", "Fight", -1, false, 14)
	body.add_child(fight)
	_fight_drawer = fight
	for side in ["party", "enemy"]:
		fight.body.add_child(MakerUI.label(side, 13, MakerUI.INK, true))
		for key in SandboxSetup.MOD_KEYS:
			var lo := 10.0 if key == "hp_pct" else -10.0
			var hi := 300.0 if key == "hp_pct" else 20.0
			_fight_spins["%s.%s" % [side, key]] = _spin_row(fight.body, FIGHT_LABELS[key], lo, hi, 1, func(v: float) -> void: _fight_edit(func(s: SandboxSetup) -> void: _mods_of(s, side)[key] = int(v)))
	_fight_spins["extra"] = _spin_row(fight.body, "extra enemies", 0, 12, 1, func(v: float) -> void: _fight_edit(func(s: SandboxSetup) -> void: s.extra_enemies = int(v)))
	_fight_spins["medicine"] = _spin_row(fight.body, "medicine", 0, 20, 1, func(v: float) -> void: _fight_edit(func(s: SandboxSetup) -> void: s.supplies["medicine"] = int(v)))
	_fight_spins["food"] = _spin_row(fight.body, "food", 0, 60, 1, func(v: float) -> void: _fight_edit(func(s: SandboxSetup) -> void: s.supplies["food"] = int(v)))
	_fight_spins["seed"] = _spin_row(fight.body, "dice seed", 1, 99999, 1, func(v: float) -> void: _fight_edit(func(s: SandboxSetup) -> void: s.seed_value = int(v)))
	for pair in [["counters", "counterattacks"]]:
		var check := CheckBox.new()
		check.text = pair[1]
		var field: String = pair[0]
		check.toggled.connect(func(on: bool) -> void: _fight_edit(func(s: SandboxSetup) -> void: s[field] = on))
		fight.body.add_child(check)
		_fight_checks[field] = check
	var gen := MakerUI.Drawer.new("map/gen", "Generate", -1, not _closed.has("map/gen"), 14)
	gen.toggled_open.connect(_on_drawer)
	body.add_child(gen)
	_seed_spin = _spin_row(gen.body, "seed", 1, 99999, 1, func(_v: float) -> void: pass)
	_seed_spin.value = gen_seed
	var grow := HBoxContainer.new()
	gen.body.add_child(grow)
	_text_button(grow, "New valley", new_valley)
	_text_button(grow, "Next seed", func() -> void:
		_seed_spin.value += 1
		new_valley())
	var grow2 := HBoxContainer.new()
	gen.body.add_child(grow2)
	_text_button(grow2, "Roughen outline", func() -> void:
		_push_undo()
		MapOps.roughen(doc.grid, int(_seed_spin.value) + 17, 0.45)
		_refresh_marks())
	_text_button(grow2, "Link with stairs", func() -> void:
		_push_undo()
		_say("placed %d stairs" % MapOps.link(doc.grid, int(_seed_spin.value))))
	var grow3 := HBoxContainer.new()
	gen.body.add_child(grow3)
	_text_button(grow3, "Tidy edges", func() -> void:
		_push_undo()
		var n := MapOps.tidy(doc.grid)
		MapOps.keep_largest(doc.grid)
		var st := MapOps.link(doc.grid, int(_seed_spin.value))
		_refresh_marks()
		_say("tidied %d cells%s" % [n, (", added %d stairs to keep it joined" % st) if st > 0 else ""]))
	_text_button(grow3, "Add pillars", func() -> void:
		_push_undo()
		var got := MapOps.pillars(doc.grid, int(_seed_spin.value) + 9, 3)
		_refresh_marks()
		_say("added %d pillars" % got.size()))
	var tpl_row := HBoxContainer.new()
	gen.body.add_child(tpl_row)
	_recipe_pick = OptionButton.new()
	for r in MapRecipes.names():
		_recipe_pick.add_item(r)
	_recipe_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tpl_row.add_child(_recipe_pick)
	_text_button(tpl_row, "Template", new_from_recipe)
	var keys := MakerUI.Drawer.new("map/keys", "Keys", -1, not _closed.has("map/keys"), 14)
	keys.toggled_open.connect(_on_drawer)
	body.add_child(keys)
	var k := MakerUI.label("Drag paints, right drag does the opposite. Shift drag, middle drag or two fingers: pan.\n\n" + keys_text(), 12, MakerUI.DIM)
	k.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys.body.add_child(k)


func _fill_open_menu() -> void:
	_open_menu.clear()
	var i := 0
	var last := ""
	for key in MapDoc.list_all():
		var group := key.get_slice("/", 0)
		if group != last:
			_open_menu.add_separator("battle maps" if group == "maps" else "explore maps")
			i += 1
			last = group
		_open_menu.add_item(key.get_slice("/", 1), i)
		_open_menu.set_item_metadata(_open_menu.item_count - 1, key)
		i += 1


func _on_open_menu(id: int) -> void:
	var key := String(_open_menu.get_item_metadata(_open_menu.get_item_index(id)))
	var d := MapDoc.load_path(key)
	if d == null:
		_say("could not read that map")
		return
	_open(d)
	_say("opened " + d.key())


## The one key map, built from the tool list so it can't drift: a number key only ever picks a tool (and types nowhere
## unless a box has focus); the height value is the - and = keys.
func keys_text() -> String:
	var names := {}
	for r in TOOLS:
		if r.size() > 1:
			names[r[0]] = "%s %s" % [r[2], r[3]]
	var groups := []
	var cur := []
	for r in TOOLS:
		if r.size() == 1:
			groups.append(", ".join(cur))
			cur = []
		else:
			cur.append(names[r[0]])
	groups.append(", ".join(cur))
	return "TOOLS\n%s\n\nHEIGHT TOOL  1 again cycles up, flat, down;  - and = change the flat height\nSIZE  [ and ] (brush, path, river, bridge, stairs: 1 to 4)\n\nVIEW  Tab flat or iso, K greybox, G grid, Q turn, Space fit, H hide panels, arrows or shift-drag pan, wheel zoom\nITEMS  R turn, M mirror, Del delete, ctrl D copy to the stamp, alt click pick up, Esc deselect\nAREA  PageUp and PageDown raise or lower the selection\nFILE  ctrl Z undo, ctrl shift Z redo, ctrl S save, ctrl shift S save as, F8 back here after a play test\n\nNumber keys never type into a box unless you clicked in it; Enter or Esc lets go of it." % "\n".join(groups)


func _toggle_keys() -> void:
	if _keys_panel == null:
		_keys_panel = _card(12)
		_keys_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		var l := MakerUI.label(keys_text(), 13, MakerUI.INK)
		l.custom_minimum_size.x = 520
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_keys_panel.add_child(l)
		_keys_panel.visible = false
	_keys_panel.visible = not _keys_panel.visible
	if _keys_panel.visible:
		_keys_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_keys_panel.grow_vertical = Control.GROW_DIRECTION_BOTH


func _text_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _labeled(parent: Control, text: String, c: Control) -> void:
	var row := HBoxContainer.new()
	var l := MakerUI.label(text, 12, MakerUI.DIM)
	l.custom_minimum_size.x = 50
	row.add_child(l)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(c)
	parent.add_child(row)


func _spin(parent: Control, lo: float, hi: float, step: float, v: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = v
	parent.add_child(s)
	return s


func _spin_row(parent: Control, text: String, lo: float, hi: float, step: float, cb: Callable) -> SpinBox:
	var row := HBoxContainer.new()
	var l := MakerUI.label(text, 12, MakerUI.DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var s := _spin(row, lo, hi, step, lo)
	s.value_changed.connect(cb)
	parent.add_child(row)
	return s

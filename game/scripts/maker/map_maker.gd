extends Node2D
## The map maker (F8 from any screen): build battle and exploration maps on the fly, seen the whole time in
## their finished look (sky and mountains, the forest around the map, grass lips, tall cliffs, carved stairs,
## waterfalls). Sculpt terraces, paint ground, dig rivers that fall down the terraces, cut stairs into
## cliffs, shape the outline, stand props, pick the tile set and the look, start from a generated valley,
## undo anything, save, and play the map straight away (battle maps open in the combat sandbox,
## exploration maps in the explore scene).
## Tool labels are designer tool text, not player-facing copy, so they don't go through Txt.
## How to use it: docs/systems/map-maker.md. Design: docs/design/map-look.md.

const LEFT_W := 196.0
const RIGHT_W := 236.0
const TOP_H := 40.0
const BOTTOM_H := 28.0
const PANEL := Color(0.12, 0.15, 0.17, 0.88)
const INK := Color(0.92, 0.93, 0.88)
const ACCENT := Color(0.98, 0.86, 0.5)
const ZOOM_MIN := 0.3
const ZOOM_MAX := 2.5
const PAN_SPEED := 800.0
const UNDO_DEPTH := 60
const MAX_SIZE := 48
const FIRST_MAP := "maps/highland"  ## what the maker opens the first time

## Tool name -> [group, help line]
const TOOLS := {
	"RAISE": ["SCULPT", "click or drag: up one level (each cell once per stroke). Right: down."],
	"LOWER": ["SCULPT", "click or drag: down one level. Right: up."],
	"LEVEL": ["SCULPT", "drag: flatten into a terrace at the level height. Right click: take a cell's height."],
	"GRASS": ["PAINT", "paint grass. Painting a hole fills it first. Right: grass."],
	"FOREST": ["PAINT", "pines (cover, slow to cross). Right: grass."],
	"ROAD": ["PAINT", "dirt road. Right: grass."],
	"STONE": ["PAINT", "paved stone floor. Right: grass."],
	"ROCK": ["PAINT", "boulder: blocks the way and a little sight. Right: grass."],
	"RUIN": ["PAINT", "ruin pillar: blocks the way and sight. Right: grass."],
	"WATER": ["PAINT", "still water at the cell's height. Right: grass."],
	"RIVER": ["BUILD", "drag along the river's course from high ground down: it digs a channel that never runs uphill; every drop becomes a waterfall."],
	"STAIRS": ["BUILD", "click a cell at a cliff: stairs that join both sides. Drag from the bottom to the top of a cliff: a flight."],
	"PROP": ["BUILD", "click: stand the picked prop on a cell. Right: take it away."],
	"CUT": ["SHAPE", "cut cells out of the map: the outline, chasms, pits. Right: fill them back."],
	"FILL": ["SHAPE", "give holes ground again at the height around them. Right: cut."],
	"ZONE": ["SHAPE", "paint another tile set onto cells (blend forest into ruins). Right: back to the map's set."],
}
const PAINT := {"GRASS": CombatGrid.T.GRASS, "FOREST": CombatGrid.T.FOREST, "ROAD": CombatGrid.T.ROAD,
	"STONE": CombatGrid.T.STONE, "ROCK": CombatGrid.T.ROCK, "RUIN": CombatGrid.T.RUIN, "WATER": CombatGrid.T.WATER}
## How tall a placed prop draws (tile widths) and how much sight it blocks, by sprite name.
const PROP_TALL := {"prop_pine_1": [1.25, 1.0], "prop_pine_2": [1.25, 1.0], "prop_tree": [1.3, 1.0], "prop_bush": [0.55, 0.5],
	"prop_boulder": [0.6, 1.0], "prop_pillar": [1.6, 2.0], "prop_ruin": [1.1, 1.5], "prop_landmark": [1.6, 2.0]}

var doc: MapDoc
var board: CombatBoard
var overlay: MakerOverlay
var tool := "RAISE"
var radius := 0  ## brush size: 0 = one cell
var square := false
var level_h := 3  ## LEVEL tool height
var gen_seed := 1
var zoom := 1.0
var focus := Vector2.ZERO
var hide_ui := false

var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _stroke := {}  ## {"button", "start", "last", "done": {}, "path": []} while a mouse stroke runs
var _pan := false
var _dirty := false
var _ui: CanvasLayer
var _root: Control
var _tool_buttons := {}
var _name_edit: LineEdit
var _kind_pick: OptionButton
var _load_pick: OptionButton
var _set_pick: OptionButton
var _look_pick: OptionButton
var _prop_pick: OptionButton
var _zone_pick: OptionButton
var _w_spin: SpinBox
var _h_spin: SpinBox
var _floor_spin: SpinBox
var _skirt_spin: SpinBox
var _strange_spin: SpinBox
var _level_spin: SpinBox
var _radius_spin: SpinBox
var _seed_spin: SpinBox
var _recipe_pick: OptionButton
var _grid_check: CheckBox
var _height_check: CheckBox
var _status: Label
var _help: Label
var _title: Label
var _syncing := false


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.1, 0.12, 0.14))
	board = CombatBoard.new()
	board.backdrop = true
	board.edit_void = true
	board.show_grid = true
	add_child(board)
	overlay = MakerOverlay.new()
	overlay.maker = self
	board.add_child(overlay)
	_build_ui()
	var opened: MapDoc = null
	if Game.maker_map != "":
		opened = MapDoc.load_path(Game.maker_map)
	if opened == null:
		opened = MapDoc.load_path(FIRST_MAP)
	if opened == null:
		opened = MapDoc.create("battle", "valley_%d" % gen_seed, MapGen.valley(gen_seed), "alpine")
	_open(opened)
	get_viewport().size_changed.connect(_fit_view)


# --- document -------------------------------------------------------------------------

func _open(d: MapDoc) -> void:
	doc = d
	_undo.clear()
	_redo.clear()
	_dirty = false
	board.grid = doc.grid
	board.art_set = doc.art_set
	board.strangeness = doc.strangeness
	board.rot = doc.view
	Game.maker_map = doc.key()
	_sync_ui()
	_refresh_marks()
	_fit_view()


func _snapshot() -> Dictionary:
	return {"grid": doc.grid.to_dict(), "set": doc.art_set, "strange": doc.strangeness}


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
	board.grid = doc.grid
	board.art_set = doc.art_set
	board.strangeness = doc.strangeness
	_sync_ui()
	_refresh_marks()


func undo() -> void:
	if _undo.is_empty():
		return
	_redo.append(_snapshot())
	_restore(_undo.pop_back())
	_status.text = "undo"


func redo() -> void:
	if _redo.is_empty():
		return
	_undo.append(_snapshot())
	_restore(_redo.pop_back())
	_status.text = "redo"


func save() -> void:
	doc.map_name = SandboxSetup.safe_name(_name_edit.text)
	_name_edit.text = doc.map_name
	doc.view = board.rot
	var path := doc.save()
	_dirty = false
	Game.maker_map = doc.key()
	_status.text = ("saved " + path) if path != "" else "save failed"
	_refresh_load_menu()
	_refresh_marks()


## Play the map: save it, then a battle map opens in the combat sandbox with its fight started, an
## exploration map in the explore scene. F8 comes back here.
func play_test() -> void:
	save()
	if doc.kind == "battle":
		Game.sandbox_map = SandboxSetup.MAP_DIR + doc.map_name + ".json"
		if not FileAccess.file_exists(Game.sandbox_map):
			Game.sandbox_map = SandboxSetup.USER_MAP_DIR + doc.map_name + ".json"
		Game.sandbox_play = true
		Game.go(Game.SANDBOX)
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
	var g := MapGen.valley(gen_seed, int(_w_spin.value), int(_h_spin.value), look_id if look_id != "" else "alpine")
	doc.grid = g
	if doc.art_set == "" and (look_id == "" or look_id == "alpine"):
		doc.art_set = "alpine"
	board.grid = g
	board.art_set = doc.art_set
	if doc.map_name == "untitled" or doc.map_name.begins_with("valley_"):
		doc.map_name = "valley_%d" % gen_seed
	_sync_ui()
	_refresh_marks()
	_fit_view()
	_status.text = "new valley, seed %d" % gen_seed


## Replace the map with a hand-laid layout from MapRecipes (it keeps this map's name and kind).
func new_from_recipe() -> void:
	var recipe := _recipe_pick.get_item_text(_recipe_pick.selected)
	var g := MapRecipes.build(recipe)
	if g == null:
		return
	_push_undo()
	doc.grid = g
	if doc.art_set == "":
		doc.art_set = "alpine"
	board.grid = g
	board.art_set = doc.art_set
	if doc.map_name == "untitled" or doc.map_name.begins_with("valley_"):
		doc.map_name = recipe
	_sync_ui()
	_refresh_marks()
	_fit_view()
	_status.text = "template " + recipe


func new_blank() -> void:
	_push_undo()
	var g := CombatGrid.flat(int(_w_spin.value), int(_h_spin.value))
	for y in g.h:
		for x in g.w:
			g.set_height(Vector2i(x, y), 2)
	g.look = doc.grid.look.duplicate()
	doc = MapDoc.create(doc.kind, "untitled", g, doc.art_set)
	board.grid = g
	_sync_ui()
	_refresh_marks()
	_fit_view()


func _resize() -> void:
	_push_undo()
	doc.grid = doc.grid.resized(int(_w_spin.value), int(_h_spin.value))
	board.grid = doc.grid
	_refresh_marks()
	_fit_view()


# --- camera ---------------------------------------------------------------------------

func _fit_view() -> void:
	if board == null or board.grid == null:
		return
	var vs := get_viewport_rect().size
	var area := Rect2(0, 0, vs.x, vs.y) if hide_ui else Rect2(LEFT_W, TOP_H, vs.x - LEFT_W - RIGHT_W, vs.y - TOP_H - BOTTOM_H)
	var bs := board.board_size()
	zoom = clampf(minf(area.size.x / bs.x, area.size.y / bs.y) * 0.9, ZOOM_MIN, ZOOM_MAX)
	focus = board.board_origin() + bs * 0.5
	focus += (Vector2(vs.x * 0.5, vs.y * 0.5) - area.get_center()) / zoom
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
	_title.text = "MAP MAKER   %s%s   %s   %d x %d" % [doc.key(), " *" if _dirty else "", board.look.id, doc.grid.w, doc.grid.h]


func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is SpinBox or (f != null and f.get_parent() is SpinBox)


# --- input ------------------------------------------------------------------------------

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
			if mb.pressed and _stroke.is_empty() and not _pan:
				_begin_stroke(mb.button_index)
			elif not mb.pressed and not _stroke.is_empty() and _stroke.button == mb.button_index:
				_end_stroke()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _pan:
			focus -= mm.relative / zoom
			_apply_camera()
		else:
			_hover()
	elif event is InputEventPanGesture:
		focus += (event as InputEventPanGesture).delta * 12.0 / zoom
		_apply_camera()
	elif event is InputEventMagnifyGesture:
		_zoom_at(get_viewport().get_mouse_position(), (event as InputEventMagnifyGesture).factor)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.is_echo():
		return
	var cmd := k.ctrl_pressed or k.meta_pressed
	match k.keycode:
		KEY_Z:
			if cmd:
				if k.shift_pressed:
					redo()
				else:
					undo()
		KEY_Y:
			if cmd:
				redo()
		KEY_S:
			if cmd:
				save()
		KEY_H:
			hide_ui = not hide_ui
			_root.visible = not hide_ui
			_fit_view()
		KEY_G:
			_grid_check.button_pressed = not _grid_check.button_pressed
		KEY_BRACKETLEFT:
			_radius_spin.value = maxi(0, radius - 1)
		KEY_BRACKETRIGHT:
			_radius_spin.value = mini(4, radius + 1)
		KEY_SPACE:
			_fit_view()


func _cell_under_mouse() -> Vector2i:
	return board.pick(board.get_local_mouse_position())


func _hover() -> void:
	var c := _cell_under_mouse()
	if not _stroke.is_empty():
		_stroke_to(c)
	overlay.brush = _brush_cells(c) if c != CombatBoard.NONE and _stroke.get("button", 0) == 0 and not _path_tool() else ([] as Array[Vector2i])
	if c == CombatBoard.NONE:
		_status.text = ""
		return
	var g := doc.grid
	var zone := g.zone_at(c)
	var p := g.prop_at(c)
	_status.text = "(%d, %d)   %s   height %d%s%s" % [c.x, c.y, CombatGrid.T.keys()[g.terrain_at(c)], g.height_at(c),
		("   zone " + zone) if zone != "" else "", ("   prop " + String(p.sprite)) if not p.is_empty() else ""]


func _path_tool() -> bool:
	return tool == "RIVER" or tool == "STAIRS"


func _brush_cells(c: Vector2i) -> Array[Vector2i]:
	if c == CombatBoard.NONE:
		return []
	if tool == "PROP" or tool == "STAIRS":
		return [c]
	return MapOps.brush(doc.grid, c, radius, square)


func _begin_stroke(button: int) -> void:
	var c := _cell_under_mouse()
	if c == CombatBoard.NONE:
		return
	_push_undo()
	_stroke = {"button": button, "start": c, "last": c, "done": {}, "path": [c] as Array[Vector2i]}
	if _path_tool():
		overlay.path = [c]
		overlay.path_color = Color(0.45, 0.8, 1.0) if tool == "RIVER" else ACCENT
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
		overlay.path = path if tool == "RIVER" else MapOps.line(_stroke.start, c)
		return
	for p in cells.slice(1):
		_apply(p, _stroke.button == MOUSE_BUTTON_RIGHT)


func _end_stroke() -> void:
	var right: bool = _stroke.button == MOUSE_BUTTON_RIGHT
	if tool == "RIVER" and not right:
		MapOps.river(doc.grid, _stroke.path, 1, radius + 1)
	elif tool == "STAIRS":
		var a: Vector2i = _stroke.start
		var b: Vector2i = _stroke.last
		if right:
			for c in MapOps.line(a, b):
				if doc.grid.terrain_at(c) == CombatGrid.T.STAIRS:
					doc.grid.set_terrain(c, CombatGrid.T.GRASS)
		elif a == b:
			if not MapOps.stairs(doc.grid, a):
				_status.text = "no cliff next to that cell to cut stairs into"
		else:
			MapOps.flight(doc.grid, a, b)
	_stroke = {}
	overlay.path = []
	_refresh_marks()


## One brush dab of the current tool at c (right = the tool's opposite).
func _apply(c: Vector2i, right: bool) -> void:
	var g := doc.grid
	var done: Dictionary = _stroke.done
	var cells: Array[Vector2i] = []
	for p in _brush_cells(c):
		if not done.has(p):
			done[p] = true
			cells.append(p)
	if cells.is_empty():
		return
	match tool:
		"RAISE":
			MapOps.raise(g, cells, -1 if right else 1)
		"LOWER":
			MapOps.raise(g, cells, 1 if right else -1)
		"LEVEL":
			if right:
				if g.solid(c):
					level_h = g.height_at(c)
					_level_spin.value = level_h
			else:
				MapOps.level(g, cells, level_h)
		"CUT":
			if right:
				MapOps.fill(g, cells)
			else:
				MapOps.cut(g, cells)
		"FILL":
			if right:
				MapOps.cut(g, cells)
			else:
				MapOps.fill(g, cells)
		"PROP":
			if right:
				MapOps.remove_prop(g, g.prop_anchor(c))
			elif g.passable(c) or not g.prop_at(c).is_empty():
				var stem := _prop_pick.get_item_text(_prop_pick.selected) if _prop_pick.item_count > 0 else ""
				if stem != "":
					var spec: Array = PROP_TALL.get(stem.get_file(), [0.9, 1.0])
					MapOps.add_prop(g, c, stem, Vector2i.ONE, spec[0], spec[1])
		"ZONE":
			var z := "" if right else String(_zone_pick.get_item_metadata(_zone_pick.selected))
			for p in cells:
				if g.solid(p):
					g.set_zone(p, z)
		_:
			if PAINT.has(tool):
				var t: int = CombatGrid.T.GRASS if right else PAINT[tool]
				MapOps.fill(g, cells)
				MapOps.paint(g, cells, t)


## Pieces, the party start, enemy groups and things from the file, as markers.
func _refresh_marks() -> void:
	var marks: Array[Dictionary] = []
	var d := doc.data
	if doc.kind == "battle":
		for e in d.get("party", []):
			marks.append({"cell": Vector2i(int(e.x), int(e.y)), "color": Color(0.4, 0.7, 1.0)})
		for e in d.get("enemies", []):
			marks.append({"cell": Vector2i(int(e.x), int(e.y)), "color": Color(1.0, 0.45, 0.4)})
	else:
		for c in d.get("start", []):
			marks.append({"cell": Vector2i(int(c[0]), int(c[1])), "color": Color(0.4, 0.7, 1.0)})
		for gr in d.get("groups", []):
			for u in gr.get("units", []):
				marks.append({"cell": Vector2i(int(u.cell[0]), int(u.cell[1])), "color": Color(1.0, 0.45, 0.4)})
		for t in d.get("things", []):
			marks.append({"cell": Vector2i(int(t.cell[0]), int(t.cell[1])), "color": ACCENT})
	overlay.marks = marks


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
	_radius_spin.value = radius
	_refresh_props()
	_syncing = false


func _refresh_props() -> void:
	var keep := _prop_pick.get_item_text(_prop_pick.selected) if _prop_pick.selected >= 0 and _prop_pick.item_count > 0 else ""
	_prop_pick.clear()
	var stems := {}
	for dir in [BattleArt.DIR, BattleArt.DIR + doc.art_set + "/"]:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for f in DirAccess.get_files_at(dir):
			if f.begins_with("prop_") and f.ends_with(".png"):
				stems[f.get_basename()] = true
	var names: Array = stems.keys()
	names.sort()
	for n in names:
		_prop_pick.add_item(n)
		if n == keep:
			_prop_pick.select(_prop_pick.item_count - 1)


func _set_tool(t: String) -> void:
	tool = t
	for k in _tool_buttons:
		_tool_buttons[k].set_pressed_no_signal(k == t)
	_help.text = t + ": " + String(TOOLS[t][1])
	_prop_pick.visible = t == "PROP"
	_zone_pick.visible = t == "ZONE"
	_level_spin.get_parent().visible = t == "LEVEL"


# --- UI -----------------------------------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 2
	add_child(_ui)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = 13
	_root.theme = theme
	_ui.add_child(_root)

	# Top bar: title, file and history.
	var top := _panel(_root, 4)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = TOP_H
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	top.add_child(bar)
	_title = _label("", 14, ACCENT)
	_title.custom_minimum_size.x = 380
	bar.add_child(_title)
	_button(bar, "NEW", new_blank)
	_load_pick = OptionButton.new()
	_load_pick.custom_minimum_size.x = 150
	_load_pick.item_selected.connect(_on_load)
	bar.add_child(_load_pick)
	_refresh_load_menu()
	_button(bar, "SAVE", save)
	_button(bar, "UNDO", undo)
	_button(bar, "REDO", redo)
	_button(bar, "TURN (Q)", func() -> void: board.turn())
	var play := _button(bar, "PLAY TEST", play_test)
	play.add_theme_color_override("font_color", ACCENT)

	# Left: tools.
	var left := _panel(_root)
	left.anchor_bottom = 1.0
	left.offset_top = TOP_H
	left.offset_right = LEFT_W
	left.offset_bottom = -BOTTOM_H
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	var lb := VBoxContainer.new()
	lb.custom_minimum_size.x = LEFT_W - 28
	lb.add_theme_constant_override("separation", 3)
	scroll.add_child(lb)
	var group := ""
	var row: HBoxContainer = null
	for t in TOOLS:
		if TOOLS[t][0] != group:
			group = TOOLS[t][0]
			lb.add_child(_label(group, 12, ACCENT))
			row = null
		if row == null or row.get_child_count() == 2:
			row = HBoxContainer.new()
			lb.add_child(row)
		var b := Button.new()
		b.text = t
		b.toggle_mode = true
		b.custom_minimum_size = Vector2((LEFT_W - 34) * 0.5, 26)
		b.pressed.connect(_set_tool.bind(t))
		row.add_child(b)
		_tool_buttons[t] = b
	_prop_pick = OptionButton.new()
	lb.add_child(_prop_pick)
	_zone_pick = OptionButton.new()
	_zone_pick.add_item("map's tile set")
	_zone_pick.set_item_metadata(0, "")
	for s in BattleArt.sets():
		_zone_pick.add_item(s)
		_zone_pick.set_item_metadata(_zone_pick.item_count - 1, s)
	lb.add_child(_zone_pick)
	_level_spin = _spin_row(lb, "level height", 0, CombatGrid.MAX_HEIGHT, 1, func(v: float) -> void: level_h = int(v))
	_radius_spin = _spin_row(lb, "brush size", 0, 4, 1, func(v: float) -> void: radius = int(v))
	var sq := CheckBox.new()
	sq.text = "square brush"
	sq.toggled.connect(func(on: bool) -> void: square = on)
	lb.add_child(sq)
	_help = _label("", 12, INK)
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.custom_minimum_size.x = LEFT_W - 28
	lb.add_child(_help)
	var keys := _label("drag = paint, right drag = the opposite\nshift drag, middle drag or two fingers = pan\nwheel or pinch = zoom, arrows = pan\nQ turn   [ ] brush   G grid\nH hide panels   space = fit\nctrl Z undo, ctrl shift Z redo, ctrl S save\nF8 comes back here after a play test", 11, Color(INK, 0.7))
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys.custom_minimum_size.x = LEFT_W - 28
	lb.add_child(keys)

	# Right: the map.
	var right := _panel(_root)
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_bottom = 1.0
	right.offset_left = -RIGHT_W
	right.offset_top = TOP_H
	right.offset_bottom = -BOTTOM_H
	var rscroll := ScrollContainer.new()
	rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(rscroll)
	var rb := VBoxContainer.new()
	rb.custom_minimum_size.x = RIGHT_W - 28
	rb.add_theme_constant_override("separation", 4)
	rscroll.add_child(rb)
	rb.add_child(_label("MAP", 12, ACCENT))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "map name"
	_name_edit.text_changed.connect(func(t: String) -> void: if not _syncing: doc.map_name = t)
	rb.add_child(_name_edit)
	_kind_pick = OptionButton.new()
	_kind_pick.add_item("battle map (data/maps)")
	_kind_pick.add_item("explore map (data/explore)")
	_kind_pick.item_selected.connect(func(i: int) -> void:
		if not _syncing:
			doc.kind = MapDoc.KINDS[i]
			_refresh_marks())
	rb.add_child(_kind_pick)
	var size_row := HBoxContainer.new()
	rb.add_child(size_row)
	_w_spin = _spin(size_row, 6, MAX_SIZE, 1, 22)
	_h_spin = _spin(size_row, 6, MAX_SIZE, 1, 20)
	_button(size_row, "RESIZE", _resize)
	rb.add_child(_label("LOOK", 12, ACCENT))
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
	_labeled(rb, "tiles", _set_pick)
	_look_pick = OptionButton.new()
	_look_pick.add_item("as the tiles")
	for id in MapLook.ids():
		_look_pick.add_item(id)
	_look_pick.item_selected.connect(func(i: int) -> void:
		_set_look_field("id", null if i == 0 else _look_pick.get_item_text(i)))
	_labeled(rb, "look", _look_pick)
	_floor_spin = _spin_row(rb, "cliff depth", -12, -1, 1, func(v: float) -> void: _set_look_field("floor", int(v)))
	_skirt_spin = _spin_row(rb, "forest rings", 0, 5, 1, func(v: float) -> void: _set_look_field("skirt", int(v)))
	_strange_spin = _spin_row(rb, "strangeness", 0, 1, 0.05, func(v: float) -> void:
		if _syncing:
			return
		doc.strangeness = v
		board.strangeness = v)
	rb.add_child(_label("GENERATE", 12, ACCENT))
	_seed_spin = _spin_row(rb, "seed", 1, 99999, 1, func(_v: float) -> void: pass)
	_seed_spin.value = gen_seed
	_button(rb, "NEW VALLEY (W x H)", new_valley)
	_button(rb, "NEXT SEED", func() -> void:
		_seed_spin.value += 1
		new_valley())
	_button(rb, "ROUGHEN OUTLINE", func() -> void:
		_push_undo()
		MapOps.roughen(doc.grid, int(_seed_spin.value) + 17, 0.45)
		_refresh_marks())
	_button(rb, "LINK WITH STAIRS", func() -> void:
		_push_undo()
		_status.text = "placed %d stairs" % MapOps.link(doc.grid, int(_seed_spin.value)))
	var tpl_row := HBoxContainer.new()
	rb.add_child(tpl_row)
	_recipe_pick = OptionButton.new()
	for r in MapRecipes.names():
		_recipe_pick.add_item(r)
	_recipe_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tpl_row.add_child(_recipe_pick)
	_button(tpl_row, "TEMPLATE", new_from_recipe)
	rb.add_child(_label("VIEW", 12, ACCENT))
	_grid_check = CheckBox.new()
	_grid_check.text = "grid lines (G)"
	_grid_check.button_pressed = true
	_grid_check.toggled.connect(func(on: bool) -> void: board.show_grid = on)
	rb.add_child(_grid_check)
	_height_check = CheckBox.new()
	_height_check.text = "height numbers"
	_height_check.toggled.connect(func(on: bool) -> void: overlay.show_heights = on)
	rb.add_child(_height_check)
	_button(rb, "FIT VIEW (space)", _fit_view)

	# Bottom: what's under the cursor.
	var bottom := _panel(_root, 4)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -BOTTOM_H
	_status = _label("", 12, INK)
	bottom.add_child(_status)
	_set_tool(tool)


func _refresh_load_menu() -> void:
	_load_pick.clear()
	_load_pick.add_item("OPEN MAP...")
	for k in MapDoc.list_all():
		_load_pick.add_item(k)
	_load_pick.select(0)


func _on_load(i: int) -> void:
	if i <= 0:
		return
	var d := MapDoc.load_path(_load_pick.get_item_text(i))
	_load_pick.select(0)
	if d == null:
		_status.text = "could not read that map"
		return
	_open(d)
	_status.text = "opened " + d.key()


func _panel(parent: Control, margin := 8.0) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.set_content_margin_all(margin)
	sb.content_margin_left = 8
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	return p


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _labeled(parent: Control, text: String, c: Control) -> void:
	var row := HBoxContainer.new()
	var l := _label(text, 12, INK)
	l.custom_minimum_size.x = 44
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
	var l := _label(text, 12, INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var s := _spin(row, lo, hi, step, lo)
	s.value_changed.connect(cb)
	parent.add_child(row)
	return s

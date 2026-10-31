class_name FlatView
extends Control
## The map maker's flat view ([USER] 2026-10-30): the same map as the isometric board seen top-down, one crisp square a
## cell in the plan look (flat colours on cream paper, the height as a gentle shade). It is only a second view: the
## maker's current tool, brush and options stay exactly as they are when Tab switches between the two, and every tool
## works here, because mouse presses go to the maker's own tool code with the cell under the mouse from this grid.
## It adds only its camera: wheel zooms, middle or shift drag pans, digit keys set the level height.

const T := CombatGrid.T
## The plan look's palette (the top-down plan Brandon liked in the crypt presentations).
const COLORS := {T.GRASS: Color8(150, 190, 110), T.FOREST: Color8(70, 120, 70), T.WATER: Color8(110, 160, 220), T.ROCK: Color8(150, 150, 155),
		T.ROAD: Color8(200, 180, 140), T.STONE: Color8(215, 205, 185), T.STAIRS: Color8(235, 225, 160), T.RUIN: Color8(190, 185, 175),
		T.VOID: Color8(245, 241, 230)}
const PAPER := Color8(245, 241, 230)
## What a tile set does to a cell's colour: [blend colour, share]. Sets without a row draw as the plain ground.
const SET_TINT := {"snow": [Color8(250, 252, 255), 0.62], "dungeon": [Color8(70, 66, 74), 0.35], "ruins": [Color8(120, 112, 100), 0.22],
		"village_in": [Color8(150, 110, 70), 0.25], "marsh": [Color8(60, 90, 80), 0.3], "canyon": [Color8(200, 120, 70), 0.3],
		"crystal": [Color8(150, 190, 240), 0.35], "farmland": [Color8(210, 190, 90), 0.28], "alpine": [Color8(190, 200, 215), 0.3]}

var maker: Node  ## the map maker scene
var cs := 16.0  ## screen pixels a cell (whole pixels, so the squares stay crisp)
var origin := Vector2.ZERO  ## screen position of cell (0, 0), inside this control
var _pan := false
var _seen_version := -1
var _over: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over.draw.connect(_draw_marks)
	add_child(_over)


## Fit the whole map into this control (called when the view opens, and on resize).
func fit() -> void:
	var g: CombatGrid = maker.doc.grid
	var avail := size - Vector2(24, 24)
	cs = clampf(floorf(minf(avail.x / g.w, avail.y / g.h)), 4.0, 48.0)
	origin = ((size - Vector2(g.w, g.h) * cs) * 0.5).floor()
	queue_redraw()


func cell_at(p: Vector2) -> Vector2i:
	var q := (p - origin) / cs
	return Vector2i(floori(q.x), floori(q.y))


## The cell under the mouse, or CombatBoard.NONE off the map.
func cell_under_mouse() -> Vector2i:
	var c := cell_at(get_local_mouse_position())
	return c if maker.doc.grid.in_bounds(c) else CombatBoard.NONE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(mb.position, 1.12)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(mb.position, 1.0 / 1.12)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE or (mb.button_index == MOUSE_BUTTON_LEFT and mb.shift_pressed and not maker.get("_stroke").size() > 0):
			_pan = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			maker.call("_mouse_button", mb)  # the maker's own tool code, with this grid's cell under the mouse
		accept_event()
	elif event is InputEventMouseMotion:
		if _pan:
			origin += (event as InputEventMouseMotion).relative
			queue_redraw()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.is_echo() or not is_visible_in_tree() or maker.call("_typing"):
		return
	if k.ctrl_pressed or k.meta_pressed:
		return
	if k.keycode >= KEY_0 and k.keycode <= KEY_9:
		maker.call("set_level_height", k.keycode - KEY_0 + (10 if k.shift_pressed else 0))
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_MINUS:
		maker.call("set_level_height", int(maker.get("level_h")) - 1)
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_EQUAL:
		maker.call("set_level_height", int(maker.get("level_h")) + 1)
		get_viewport().set_input_as_handled()


func _zoom(at: Vector2, f: float) -> void:
	var before := (at - origin) / cs
	var next := clampf(roundf(cs * f), 4.0, 64.0)
	if next == cs:
		next = clampf(cs + (1.0 if f > 1.0 else -1.0), 4.0, 64.0)
	cs = next
	origin = (at - before * cs).floor()
	queue_redraw()


func _process(_delta: float) -> void:
	if not is_visible_in_tree() or maker == null or maker.doc == null:
		return
	var g: CombatGrid = maker.doc.grid
	if g.version != _seen_version:
		_seen_version = g.version
		queue_redraw()
	_over.queue_redraw()


## A cell's colour: its ground, tinted by its tile set (snow, dungeon...), shaded a little by its height.
func ground_color(g: CombatGrid, c: Vector2i) -> Color:
	var t := g.terrain_at(c)
	var col: Color = COLORS.get(t, Color.MAGENTA)
	if t == T.VOID:
		return col
	var z := g.zone_at(c)
	if SET_TINT.has(z):
		col = col.lerp(SET_TINT[z][0], SET_TINT[z][1])
	var shade := 0.78 + 0.04 * float(g.height_at(c))
	return Color(minf(col.r * shade, 1.0), minf(col.g * shade, 1.0), minf(col.b * shade, 1.0))


func _draw() -> void:
	if maker == null or maker.doc == null:
		return
	var g: CombatGrid = maker.doc.grid
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	var font := ThemeDB.fallback_font
	var fs := clampi(int(cs * 0.55), 8, 20)
	var numbers: bool = maker.overlay.show_heights
	var lines: bool = maker.board.show_grid and cs >= 12.0
	for y in g.h:
		for x in g.w:
			var c := Vector2i(x, y)
			var r := Rect2(origin + Vector2(x, y) * cs, Vector2(cs, cs))
			var t := g.terrain_at(c)
			draw_rect(r, ground_color(g, c))
			if t == T.STAIRS:
				for i in 3:
					var yy := r.position.y + cs * (0.25 + 0.25 * i)
					draw_line(Vector2(r.position.x + cs * 0.15, yy), Vector2(r.end.x - cs * 0.15, yy), Color(0.3, 0.25, 0.1, 0.8), maxf(1.0, cs * 0.06))
			if numbers and cs >= 14.0 and t != T.VOID:
				draw_string(font, r.position + Vector2(0, cs * 0.5 + fs * 0.35), str(g.height_at(c)), HORIZONTAL_ALIGNMENT_CENTER, cs, fs, Color(0, 0, 0, 0.55))
			if lines and t != T.VOID:
				draw_rect(r, Color(0, 0, 0, 0.08), false, 1.0)


func _cell_rect(c: Vector2i) -> Rect2:
	return Rect2(origin + Vector2(c) * cs, Vector2(cs, cs))


## What is placed, and the maker's tool marks (brush, path, ghost, selection), redrawn every frame over the map.
func _draw_marks() -> void:
	if maker == null or maker.doc == null:
		return
	var o: Control = _over
	var g: CombatGrid = maker.doc.grid
	var d: Dictionary = maker.doc.data
	var ov = maker.overlay
	var dot := func(c: Vector2i, col: Color) -> void:
		var p: Vector2 = origin + (Vector2(c) + Vector2(0.5, 0.5)) * cs
		o.draw_circle(p, maxf(2.5, cs * 0.3), col)
		o.draw_arc(p, maxf(2.5, cs * 0.3), 0, TAU, 12, Color(0, 0, 0, 0.7), 1.2)
	for s in d.get("start", []):
		dot.call(Vector2i(int(s[0]), int(s[1])), Color(0.45, 0.72, 1.0))
	for gr in d.get("groups", []):
		for u in gr.get("units", []):
			dot.call(Vector2i(int(u.cell[0]), int(u.cell[1])), Color(1.0, 0.48, 0.42))
	var show_labels: bool = ov.show_labels
	for t in d.get("things", []):
		var c := Vector2i(int(t.cell[0]), int(t.cell[1]))
		var r := Rect2(origin + (Vector2(c) + Vector2(0.2, 0.2)) * cs, Vector2(cs, cs) * 0.6)
		o.draw_rect(r, Color(0.98, 0.84, 0.48))
		o.draw_rect(r, Color(0, 0, 0, 0.7), false, 1.2)
		if show_labels and cs >= 8.0:
			o.draw_string(ThemeDB.fallback_font, origin + Vector2(c) * cs + Vector2(0, -2), String(t.get("id", "")).left(6), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.63, 0.08, 0.08))
	for list in ["party", "enemies"]:
		for e in d.get(list, []):
			dot.call(Vector2i(int(e.x), int(e.y)), Color(0.45, 0.72, 1.0) if list == "party" else Color(1.0, 0.48, 0.42))
	for a: Vector2i in g.props:
		o.draw_rect(Rect2(origin + (Vector2(a) + Vector2(0.35, 0.35)) * cs, Vector2(cs, cs) * 0.3), Color(0.25, 0.25, 0.28, 0.9))
	# the maker's own marks for the current tool
	for c: Vector2i in ov.hover_cells:
		o.draw_rect(_cell_rect(c), Color(1, 1, 1, 0.8), false, 1.5)
	for c: Vector2i in ov.selected_cells:
		o.draw_rect(_cell_rect(c), Color(MakerUI.ACCENT, 0.25))
		o.draw_rect(_cell_rect(c), MakerUI.ACCENT, false, 2.0)
	var ghost: Dictionary = ov.ghost
	if not ghost.is_empty():
		var ok: bool = ghost.get("ok", true)
		for c: Vector2i in ghost.get("cells", []):
			o.draw_rect(_cell_rect(c), Color(0.3, 0.9, 0.4, 0.45) if ok else Color(0.95, 0.3, 0.3, 0.45))
	var path: Array = ov.path
	if path.size() > 1:
		var pts := PackedVector2Array()
		for c: Vector2i in path:
			pts.append(origin + (Vector2(c) + Vector2(0.5, 0.5)) * cs)
		o.draw_polyline(pts, ov.path_color, maxf(2.0, cs * 0.25))
	for c: Vector2i in ov.brush:
		o.draw_rect(_cell_rect(c), Color(1, 1, 1, 0.9), false, 2.0)
	for m in ov.marks:
		if m.get("selected", false):
			o.draw_rect(_cell_rect(m.cell), MakerUI.ACCENT, false, 2.5)

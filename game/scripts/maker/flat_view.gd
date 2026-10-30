class_name FlatView
extends Control
## The map maker's flat sketch mode ([USER] 2026-10-30: "a tab to switch to a flat mode where I can quickly sketch out the
## shapes of the map, then toggle back over to the isometric version"). A top-down pixel grid of the same map the
## isometric board shows: one square a cell, coloured by ground, shaded by height, the height drawn as a number. Left drag
## paints with the brush (ground, height, or both); right click picks up what is under it; number keys set the height
## (shift adds 10, - and = nudge it); [ and ] size the brush (the maker's own); wheel zooms, middle or shift drag pans.
## It edits the maker's grid directly, so toggling back shows the same map, and undo (ctrl Z) covers both views.

const T := CombatGrid.T
const GROUNDS := [["grass", T.GRASS], ["forest", T.FOREST], ["road", T.ROAD], ["stone", T.STONE], ["wall", T.ROCK],
		["water", T.WATER], ["stairs", T.STAIRS], ["ruin", T.RUIN], ["empty", T.VOID]]
const COLORS := {T.GRASS: Color("8fbf68"), T.FOREST: Color("3e7a4a"), T.WATER: Color("5a9fe0"), T.ROCK: Color("8a8a92"),
		T.ROAD: Color("d2b68a"), T.STONE: Color("dcd2bd"), T.STAIRS: Color("f0d878"), T.RUIN: Color("b07a5a"), T.VOID: Color("232a30")}
const MAX_H := 24

var maker: Node  ## the map maker scene
var paint_ground := true
var paint_height := true
var ground: int = T.GRASS
var height := 3
var cs := 16.0  ## screen pixels a cell
var origin := Vector2.ZERO  ## screen position of cell (0, 0), inside this control
var _stroke := false
var _last := Vector2i(-999, -999)
var _pan := false
var _seen_version := -1
var _hover := Vector2i(-999, -999)
var _ground_buttons := {}
var _height_spin: SpinBox
var _box: PanelContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_build_bar()


func _build_bar() -> void:
	_box = PanelContainer.new()
	_box.position = Vector2(8, 8)
	add_child(_box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_box.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	col.add_child(row)
	for g in GROUNDS:
		var b := Button.new()
		b.text = g[0]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(54, 26)
		b.add_theme_font_size_override("font_size", 12)
		var sw := StyleBoxFlat.new()
		sw.bg_color = COLORS[g[1]]
		sw.set_corner_radius_all(3)
		b.add_theme_stylebox_override("pressed", sw)
		b.add_theme_stylebox_override("hover_pressed", sw)
		b.add_theme_color_override("font_pressed_color", Color(0.1, 0.1, 0.1))
		b.add_theme_color_override("font_hover_pressed_color", Color(0.1, 0.1, 0.1))
		var t: int = g[1]
		b.pressed.connect(func() -> void: set_ground(t))
		row.add_child(b)
		_ground_buttons[t] = b
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	col.add_child(row2)
	var cg := CheckBox.new()
	cg.text = "ground"
	cg.button_pressed = paint_ground
	cg.focus_mode = Control.FOCUS_NONE
	cg.toggled.connect(func(on: bool) -> void: paint_ground = on)
	row2.add_child(cg)
	var ch := CheckBox.new()
	ch.text = "height"
	ch.button_pressed = paint_height
	ch.focus_mode = Control.FOCUS_NONE
	ch.toggled.connect(func(on: bool) -> void: paint_height = on)
	row2.add_child(ch)
	_height_spin = SpinBox.new()
	_height_spin.min_value = 0
	_height_spin.max_value = MAX_H
	_height_spin.value = height
	_height_spin.custom_minimum_size.x = 70
	_height_spin.value_changed.connect(func(v: float) -> void: height = int(v))
	row2.add_child(_height_spin)
	var hint := Label.new()
	hint.text = "drag paints  ·  right click picks up  ·  0-9 sets the height  ·  [ ] brush  ·  Tab: back to the isometric view"
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.7)
	col.add_child(hint)
	set_ground(ground)


func set_ground(t: int) -> void:
	ground = t
	for k in _ground_buttons:
		_ground_buttons[k].set_pressed_no_signal(k == t)


func set_height(h: int) -> void:
	height = clampi(h, 0, MAX_H)
	if _height_spin != null:
		_height_spin.set_value_no_signal(height)


## Fit the whole map into this control (called when the mode opens, and on resize).
func fit() -> void:
	var g: CombatGrid = maker.doc.grid
	var avail := size - Vector2(24, 24)
	cs = clampf(floorf(minf(avail.x / g.w, avail.y / g.h)), 4.0, 48.0)
	origin = (size - Vector2(g.w, g.h) * cs) * 0.5
	queue_redraw()


func cell_at(p: Vector2) -> Vector2i:
	var q := (p - origin) / cs
	return Vector2i(floori(q.x), floori(q.y))


## Cells under a brush of the maker's radius around c.
func brush_cells(c: Vector2i) -> Array[Vector2i]:
	var r: int = maker.radius
	var out: Array[Vector2i] = []
	var g: CombatGrid = maker.doc.grid
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if (maker.square or dx * dx + dy * dy <= r * r + r) and g.in_bounds(c + Vector2i(dx, dy)):
				out.append(c + Vector2i(dx, dy))
	return out


func paint_at(c: Vector2i) -> void:
	var g: CombatGrid = maker.doc.grid
	for p in brush_cells(c):
		if paint_ground:
			if g.terrain_at(p) != ground:
				g.set_terrain(p, ground)
		if paint_height and ground != T.VOID:
			if g.height_at(p) != height:
				g.set_height(p, height)


## Paint a straight run of cells from a to b (a stroke that moved faster than the mouse events).
func paint_line(a: Vector2i, b: Vector2i) -> void:
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in range(n + 1):
		var t := float(i) / maxf(n, 1)
		paint_at(Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t))))
	maker.call("_refresh_marks")


func pick_up(c: Vector2i) -> void:
	var g: CombatGrid = maker.doc.grid
	if not g.in_bounds(c):
		return
	set_ground(g.terrain_at(c))
	set_height(g.height_at(c))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(mb.position, 1.12)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(mb.position, 1.0 / 1.12)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE or (mb.button_index == MOUSE_BUTTON_LEFT and mb.shift_pressed and not _stroke):
			_pan = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				maker.call("_push_undo")
				_stroke = true
				_last = cell_at(mb.position)
				paint_at(_last)
			elif _stroke:
				_stroke = false
				maker.call("_refresh_marks")
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			pick_up(cell_at(mb.position))
		accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_hover = cell_at(mm.position)
		if _pan:
			origin += mm.relative
		elif _stroke:
			var c := cell_at(mm.position)
			if c != _last:
				paint_line(_last, c)
				_last = c
		queue_redraw()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.is_echo() or not is_visible_in_tree() or maker.call("_typing"):
		return
	if k.ctrl_pressed or k.meta_pressed:
		return
	if k.keycode >= KEY_0 and k.keycode <= KEY_9:
		set_height(k.keycode - KEY_0 + (10 if k.shift_pressed else 0))
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_MINUS:
		set_height(height - 1)
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_EQUAL:
		set_height(height + 1)
		get_viewport().set_input_as_handled()


func _zoom(at: Vector2, f: float) -> void:
	var before := (at - origin) / cs
	cs = clampf(cs * f, 4.0, 64.0)
	origin = at - before * cs
	queue_redraw()


func _process(_delta: float) -> void:
	if not is_visible_in_tree() or maker == null or maker.doc == null:
		return
	var g: CombatGrid = maker.doc.grid
	if g.version != _seen_version:
		_seen_version = g.version
		queue_redraw()


func _draw() -> void:
	if maker == null or maker.doc == null:
		return
	var g: CombatGrid = maker.doc.grid
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.13, 0.15, 0.17))
	var top := 1
	for y in g.h:
		for x in g.w:
			top = maxi(top, g.height_at(Vector2i(x, y)))
	var font := ThemeDB.fallback_font
	var fs := clampi(int(cs * 0.55), 8, 20)
	for y in g.h:
		for x in g.w:
			var c := Vector2i(x, y)
			var r := Rect2(origin + Vector2(x, y) * cs, Vector2(cs, cs))
			var t := g.terrain_at(c)
			var col: Color = COLORS.get(t, Color.MAGENTA)
			if t != T.VOID:
				var shade := 0.62 + 0.5 * float(g.height_at(c)) / float(top)
				col = Color(minf(col.r * shade, 1.0), minf(col.g * shade, 1.0), minf(col.b * shade, 1.0))
			draw_rect(r, col)
			if t == T.STAIRS:
				for i in 3:
					var yy := r.position.y + cs * (0.25 + 0.25 * i)
					draw_line(Vector2(r.position.x + cs * 0.15, yy), Vector2(r.end.x - cs * 0.15, yy), Color(0.3, 0.25, 0.1, 0.8), maxf(1.0, cs * 0.06))
			if cs >= 14.0 and t != T.VOID:
				draw_string(font, r.position + Vector2(0, cs * 0.5 + fs * 0.35), str(g.height_at(c)), HORIZONTAL_ALIGNMENT_CENTER, cs, fs, Color(0, 0, 0, 0.55))
			if cs >= 6.0:
				draw_rect(r, Color(0, 0, 0, 0.12), false, 1.0)
	_marks(g)
	if g.in_bounds(_hover):
		for p in brush_cells(_hover):
			draw_rect(Rect2(origin + Vector2(p) * cs, Vector2(cs, cs)), Color(1, 1, 1, 0.85), false, 2.0)


## The party start, foes and things, so the sketch stays tied to what is placed.
func _marks(g: CombatGrid) -> void:
	var d: Dictionary = maker.doc.data
	var dot := func(c: Vector2i, col: Color) -> void:
		draw_circle(origin + (Vector2(c) + Vector2(0.5, 0.5)) * cs, maxf(2.5, cs * 0.3), col)
		draw_arc(origin + (Vector2(c) + Vector2(0.5, 0.5)) * cs, maxf(2.5, cs * 0.3), 0, TAU, 12, Color(0, 0, 0, 0.7), 1.2)
	for s in d.get("start", []):
		dot.call(Vector2i(int(s[0]), int(s[1])), Color(0.45, 0.72, 1.0))
	for gr in d.get("groups", []):
		for u in gr.get("units", []):
			dot.call(Vector2i(int(u.cell[0]), int(u.cell[1])), Color(1.0, 0.48, 0.42))
	for t in d.get("things", []):
		var c := Vector2i(int(t.cell[0]), int(t.cell[1]))
		var r := Rect2(origin + (Vector2(c) + Vector2(0.2, 0.2)) * cs, Vector2(cs, cs) * 0.6)
		draw_rect(r, Color(0.98, 0.84, 0.48))
		draw_rect(r, Color(0, 0, 0, 0.7), false, 1.2)
	for list in ["party", "enemies"]:
		for e in d.get(list, []):
			dot.call(Vector2i(int(e.x), int(e.y)), Color(0.45, 0.72, 1.0) if list == "party" else Color(1.0, 0.48, 0.42))
	for a: Vector2i in g.props:
		var p: Dictionary = g.props[a]
		draw_rect(Rect2(origin + (Vector2(a) + Vector2(0.35, 0.35)) * cs, Vector2(cs, cs) * 0.3), Color(0.25, 0.25, 0.28, 0.9))

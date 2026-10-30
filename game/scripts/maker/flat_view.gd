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
## The plan look (the top-down plan Brandon liked in the crypt presentations): flat colours on cream paper, one crisp
## square a cell, the height as a gentle shade, no grid lines or numbers unless asked.
const COLORS := {T.GRASS: Color8(150, 190, 110), T.FOREST: Color8(70, 120, 70), T.WATER: Color8(110, 160, 220), T.ROCK: Color8(150, 150, 155),
		T.ROAD: Color8(200, 180, 140), T.STONE: Color8(215, 205, 185), T.STAIRS: Color8(235, 225, 160), T.RUIN: Color8(190, 185, 175),
		T.VOID: Color8(245, 241, 230)}
const PAPER := Color8(245, 241, 230)
const MAX_H := 24

var maker: Node  ## the map maker scene
var paint_ground := true
var paint_height := true
var show_numbers := false
var show_grid := false
var show_labels := true
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
var _drawer: MakerUI.Drawer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


## The brush controls, as a drawer for the maker's right panel (closed by default; the handle says what the brush is).
func build_drawer() -> MakerUI.Drawer:
	_drawer = MakerUI.Drawer.new("flat", "Flat brush", -1, false, 14)
	var col: VBoxContainer = _drawer.body
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	col.add_child(flow)
	for g in GROUNDS:
		var b := Button.new()
		b.text = g[0]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(66, 28)
		b.add_theme_font_size_override("font_size", 13)
		var sw := StyleBoxFlat.new()
		sw.bg_color = COLORS[g[1]]
		sw.set_corner_radius_all(3)
		sw.border_color = Color(0, 0, 0, 0.35)
		sw.set_border_width_all(1)
		for k in ["pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(k, sw)
		for k in ["font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(k, Color(0.1, 0.1, 0.1))
		var t: int = g[1]
		b.pressed.connect(func() -> void: set_ground(t))
		flow.add_child(b)
		_ground_buttons[t] = b
	var row2 := HFlowContainer.new()
	row2.add_theme_constant_override("h_separation", 8)
	col.add_child(row2)
	for opt in [["ground", "paint_ground"], ["height", "paint_height"], ["numbers", "show_numbers"], ["grid", "show_grid"], ["labels", "show_labels"]]:
		var co := CheckBox.new()
		co.text = opt[0]
		co.button_pressed = bool(get(opt[1]))
		co.focus_mode = Control.FOCUS_NONE
		var prop: String = opt[1]
		co.toggled.connect(func(on: bool) -> void:
			set(prop, on)
			queue_redraw())
		row2.add_child(co)
	var hrow := HBoxContainer.new()
	col.add_child(hrow)
	var hl := Label.new()
	hl.text = "height"
	hrow.add_child(hl)
	_height_spin = SpinBox.new()
	_height_spin.min_value = 0
	_height_spin.max_value = MAX_H
	_height_spin.value = height
	_height_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_height_spin.value_changed.connect(func(v: float) -> void:
		height = int(v)
		_sum())
	hrow.add_child(_height_spin)
	var hint := Label.new()
	hint.text = "drag paints  ·  right click picks up  ·  0-9 sets the height  ·  [ ] brush size  ·  Tab: back to isometric"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.7)
	col.add_child(hint)
	set_ground(ground)
	return _drawer


## The handle's text: what the brush is right now, so it reads without opening the drawer.
func _sum() -> void:
	if _drawer == null:
		return
	var nm := "brush"
	for g in GROUNDS:
		if g[1] == ground:
			nm = g[0]
	_drawer.head.text = "Flat brush:  %s%s%s" % [nm if paint_ground else "-", ", height %d" % height if paint_height else "", "" if _drawer.open else "   (open)"]
	_drawer.head.queue_redraw()


func set_ground(t: int) -> void:
	ground = t
	for k in _ground_buttons:
		_ground_buttons[k].set_pressed_no_signal(k == t)
	_sum()


func set_height(h: int) -> void:
	height = clampi(h, 0, MAX_H)
	if _height_spin != null:
		_height_spin.set_value_no_signal(height)
	_sum()


## Fit the whole map into this control (called when the mode opens, and on resize).
func fit() -> void:
	var g: CombatGrid = maker.doc.grid
	var bar_h := 0.0
	var avail := size - Vector2(24, 24)
	cs = clampf(floorf(minf(avail.x / g.w, avail.y / g.h)), 4.0, 48.0)
	origin = (Vector2((size.x - g.w * cs) * 0.5, bar_h + (size.y - bar_h - g.h * cs) * 0.5)).floor()
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
	var next := clampf(roundf(cs * f), 4.0, 64.0)
	if next == cs:
		next = clampf(cs + (1.0 if f > 1.0 else -1.0), 4.0, 64.0)
	cs = next  # whole pixels a cell, so the squares stay crisp
	origin = (at - before * cs).floor()
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
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
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
				var shade := 0.78 + 0.04 * float(g.height_at(c))
				col = Color(minf(col.r * shade, 1.0), minf(col.g * shade, 1.0), minf(col.b * shade, 1.0))
			draw_rect(r, col)
			if t == T.STAIRS:
				for i in 3:
					var yy := r.position.y + cs * (0.25 + 0.25 * i)
					draw_line(Vector2(r.position.x + cs * 0.15, yy), Vector2(r.end.x - cs * 0.15, yy), Color(0.3, 0.25, 0.1, 0.8), maxf(1.0, cs * 0.06))
			if show_numbers and cs >= 14.0 and t != T.VOID:
				draw_string(font, r.position + Vector2(0, cs * 0.5 + fs * 0.35), str(g.height_at(c)), HORIZONTAL_ALIGNMENT_CENTER, cs, fs, Color(0, 0, 0, 0.55))
			if show_grid and cs >= 6.0:
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
		if show_labels and cs >= 8.0:
			draw_string(ThemeDB.fallback_font, origin + Vector2(c) * cs + Vector2(0, -2), String(t.get("id", "")).left(6), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.63, 0.08, 0.08))
	for list in ["party", "enemies"]:
		for e in d.get(list, []):
			dot.call(Vector2i(int(e.x), int(e.y)), Color(0.45, 0.72, 1.0) if list == "party" else Color(1.0, 0.48, 0.42))
	for a: Vector2i in g.props:
		var p: Dictionary = g.props[a]
		draw_rect(Rect2(origin + (Vector2(a) + Vector2(0.35, 0.35)) * cs, Vector2(cs, cs) * 0.3), Color(0.25, 0.25, 0.28, 0.9))

class_name CombatBoard
extends Node2D
## Draws the isometric height map and the pieces, and turns mouse input into cells.
## All graybox: flat-shaded blocks and pawn shapes. Brandon's tiles and paper dolls replace _draw later.

signal cell_clicked(cell: Vector2i, right: bool)
signal cell_hovered(cell: Vector2i)

const TW := 64.0  ## tile width on screen
const TH := 32.0  ## tile height on screen
const HS := 16.0  ## pixels per height level
const BASE := -0.6  ## how far below height 0 the block sides go
const NONE := Vector2i(-1, -1)

const TOP_COLORS := {
	CombatGrid.T.GRASS: Color(0.56, 0.66, 0.47),
	CombatGrid.T.FOREST: Color(0.33, 0.48, 0.36),
	CombatGrid.T.WATER: Color(0.42, 0.6, 0.72),
	CombatGrid.T.ROCK: Color(0.55, 0.55, 0.53),
	CombatGrid.T.ROAD: Color(0.7, 0.63, 0.5),
}
## Earth to Alien: the same board drifts toward these as strangeness rises.
const ALIEN_COLORS := {
	CombatGrid.T.GRASS: Color(0.5, 0.42, 0.62),
	CombatGrid.T.FOREST: Color(0.2, 0.5, 0.5),
	CombatGrid.T.WATER: Color(0.75, 0.45, 0.6),
	CombatGrid.T.ROCK: Color(0.35, 0.3, 0.45),
	CombatGrid.T.ROAD: Color(0.55, 0.5, 0.65),
}

var grid: CombatGrid
var units: Array = []
var strangeness := 0.0
var highlights := {}  # cell -> Color
var hover := NONE
var selected: CombatUnit = null
var _floaters: Array[Dictionary] = []  # {"text", "pos", "t", "color"}
var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	for f in _floaters:
		f.t -= delta
		f.pos.y -= 30.0 * delta
	_floaters = _floaters.filter(func(f: Dictionary) -> bool: return f.t > 0.0)
	queue_redraw()  # idle breathing and spooked jitter


# --- coordinates ------------------------------------------------------------

func iso(x: float, y: float, h: float) -> Vector2:
	return Vector2((x - y) * TW * 0.5, (x + y) * TH * 0.5 - h * HS)


func cell_top(c: Vector2i) -> Vector2:
	return iso(c.x + 0.5, c.y + 0.5, grid.height_at(c))


func board_size() -> Vector2:
	return Vector2((grid.w + grid.h) * TW * 0.5, (grid.w + grid.h) * TH * 0.5 + (CombatGrid.MAX_HEIGHT + 1) * HS)


## Offset from the node origin to the board's top-left corner on screen.
func board_origin() -> Vector2:
	return Vector2(-grid.h * TW * 0.5, -CombatGrid.MAX_HEIGHT * HS)


func _diamond(c: Vector2i, h: float) -> PackedVector2Array:
	return PackedVector2Array([iso(c.x, c.y, h), iso(c.x + 1, c.y, h), iso(c.x + 1, c.y + 1, h), iso(c.x, c.y + 1, h)])


func pick(local: Vector2) -> Vector2i:
	# Front-most cells first so taller blocks in front win.
	for depth in range(grid.w + grid.h - 2, -1, -1):
		for x in range(grid.w - 1, -1, -1):
			var y := depth - x
			if y < 0 or y >= grid.h:
				continue
			var c := Vector2i(x, y)
			if Geometry2D.is_point_in_polygon(local, _diamond(c, grid.height_at(c))):
				return c
	return NONE


func _unhandled_input(event: InputEvent) -> void:
	if grid == null:
		return
	if event is InputEventMouseMotion:
		var c := pick(get_local_mouse_position())
		if c != hover:
			hover = c
			cell_hovered.emit(c)
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			cell_clicked.emit(pick(get_local_mouse_position()), mb.button_index == MOUSE_BUTTON_RIGHT)


# --- drawing ------------------------------------------------------------------

func _draw() -> void:
	if grid == null:
		return
	for depth in range(grid.w + grid.h - 1):
		for x in grid.w:
			var y := depth - x
			if y >= 0 and y < grid.h:
				_draw_tile(Vector2i(x, y))
		for u: CombatUnit in units:
			if u.alive() and int(round(u.vis.x + u.vis.y)) == depth:
				_draw_unit(u)
	var font := ThemeDB.fallback_font
	for f in _floaters:
		var a := clampf(f.t, 0.0, 1.0)
		draw_string_outline(font, f.pos, f.text, HORIZONTAL_ALIGNMENT_CENTER, 120, 16, 4, Color(0, 0, 0, a))
		draw_string(font, f.pos, f.text, HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color(f.color, a))


func _terrain_color(t: int) -> Color:
	return (TOP_COLORS[t] as Color).lerp(ALIEN_COLORS[t], strangeness)


func _draw_tile(c: Vector2i) -> void:
	var h := float(grid.height_at(c))
	var t := grid.terrain_at(c)
	var top_col := _terrain_color(t).lightened(h * 0.04)
	var tl := iso(c.x, c.y, h)
	var tr := iso(c.x + 1, c.y, h)
	var br := iso(c.x + 1, c.y + 1, h)
	var bl := iso(c.x, c.y + 1, h)
	var drop := Vector2(0, (h - BASE) * HS)
	draw_colored_polygon(PackedVector2Array([bl, br, br + drop, bl + drop]), top_col.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([br, tr, tr + drop, br + drop]), top_col.darkened(0.45))
	var top := PackedVector2Array([tl, tr, br, bl])
	draw_colored_polygon(top, top_col)
	if highlights.has(c):
		draw_colored_polygon(top, highlights[c])
	if c == hover:
		draw_colored_polygon(top, Color(1, 1, 1, 0.18))
	var edge := top_col.darkened(0.55)
	draw_polyline(PackedVector2Array([tl, tr, br, bl, tl]), Color(edge, 0.6), 1.0, true)
	var mid := cell_top(c)
	match t:
		CombatGrid.T.FOREST:
			for o in [Vector2(-10, -2), Vector2(9, 1), Vector2(0, 6)]:
				var p: Vector2 = mid + o
				var tree := top_col.darkened(0.35)
				draw_colored_polygon(PackedVector2Array([p + Vector2(-7, 0), p + Vector2(0, -20), p + Vector2(7, 0)]), tree)
		CombatGrid.T.ROCK:
			draw_colored_polygon(PackedVector2Array([mid + Vector2(-14, 4), mid + Vector2(-8, -14), mid + Vector2(6, -18), mid + Vector2(15, 2)]), top_col.darkened(0.25))
		CombatGrid.T.WATER:
			var wob := sin(_time * 2.0 + c.x + c.y) * 2.0
			draw_line(mid + Vector2(-10 + wob, -2), mid + Vector2(4 + wob, -2), top_col.lightened(0.3), 2.0)
			draw_line(mid + Vector2(-2 - wob, 4), mid + Vector2(10 - wob, 4), top_col.lightened(0.3), 2.0)


func _draw_unit(u: CombatUnit) -> void:
	var base := iso(u.vis.x + 0.5, u.vis.y + 0.5, u.vis_h) + u.offset - Vector2(0, u.hop)
	if u.spooked:
		base += Vector2(sin(_time * 40.0) * 1.5, 0)
	var breathe := 1.0 + sin(_time * 2.0 + u.vis.x) * 0.02
	var col := u.tint
	if u.team == 0 and u.acted:
		col = col.darkened(0.35)
	var ring := Color(0.4, 0.7, 1.0) if u.team == 0 else Color(1.0, 0.4, 0.35)
	if u == selected:
		ring = Color(1.0, 0.9, 0.4)
	Pawn.draw(self, base, 26.0 * breathe, col, ring)
	# HP pips
	var w := 34.0
	var p := base + Vector2(-w * 0.5, -48)
	draw_rect(Rect2(p, Vector2(w, 4)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(p, Vector2(w * float(u.hp) / u.cls.max_hp, 4)), ring)


func float_text(c: Vector2i, text: String, color := Color.WHITE) -> void:
	_floaters.append({"text": text, "pos": cell_top(c) + Vector2(-60, -56), "t": 1.2, "color": color})


# --- animation -------------------------------------------------------------------

## Hop along a path like a piece lifted off the board, one tile at a time.
func animate_move(u: CombatUnit, path: Array[Vector2i]) -> void:
	for i in range(1, path.size()):
		var a := Vector2(path[i - 1])
		var b := Vector2(path[i])
		var ha := float(grid.height_at(path[i - 1]))
		var hb := float(grid.height_at(path[i]))
		var lift := 10.0 + absf(hb - ha) * HS * 0.6
		var step := func(t: float) -> void:
			u.vis = a.lerp(b, t)
			u.vis_h = lerpf(ha, hb, t)
			u.hop = sin(t * PI) * lift
		var tw := create_tween()
		tw.tween_method(step, 0.0, 1.0, 0.16)
		await tw.finished
	u.hop = 0.0


func animate_attack(att: CombatUnit, tgt: CombatUnit, hit: bool) -> void:
	var dir := (cell_top(tgt.cell) - cell_top(att.cell)).normalized() * 10.0
	var tw := create_tween()
	tw.tween_property(att, "offset", dir, 0.08)
	tw.tween_property(att, "offset", Vector2.ZERO, 0.12)
	await tw.finished
	if hit:
		var shake := create_tween()
		for i in 4:
			shake.tween_property(tgt, "offset", Vector2(4 if i % 2 == 0 else -4, 0), 0.04)
		shake.tween_property(tgt, "offset", Vector2.ZERO, 0.04)
		await shake.finished

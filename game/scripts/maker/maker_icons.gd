class_name MakerIcons
extends RefCounted
## The map maker's icons, drawn in code as simple line glyphs (no art files): tools, file and view
## commands, catalog kinds. draw() paints one into a rect on any CanvasItem; IconButton uses it.

static var _ci: CanvasItem
static var _r: Rect2
static var _col: Color
static var _w := 2.0


static func _p(x: float, y: float) -> Vector2:
	return _r.position + Vector2(x, y) * _r.size


static func _line(pts: Array, closed := false) -> void:
	var a := PackedVector2Array()
	for q: Vector2 in pts:
		a.append(_p(q.x, q.y))
	if closed:
		a.append(a[0])
	_ci.draw_polyline(a, _col, _w, true)


static func _poly(pts: Array, alpha := 1.0) -> void:
	var a := PackedVector2Array()
	for q: Vector2 in pts:
		a.append(_p(q.x, q.y))
	_ci.draw_colored_polygon(a, Color(_col, _col.a * alpha))


static func _circle(x: float, y: float, rad: float, filled := false) -> void:
	if filled:
		_ci.draw_circle(_p(x, y), rad * _r.size.x, _col)
	else:
		_ci.draw_arc(_p(x, y), rad * _r.size.x, 0, TAU, 24, _col, _w, true)


static func _arc(x: float, y: float, rad: float, a0: float, a1: float) -> void:
	_ci.draw_arc(_p(x, y), rad * _r.size.x, a0, a1, 20, _col, _w, true)


## A flat iso tile (diamond) centred at (x, y), half-width hw.
static func _tile(x: float, y: float, hw: float, filled := false, alpha := 1.0) -> void:
	var pts := [Vector2(x, y - hw * 0.5), Vector2(x + hw, y), Vector2(x, y + hw * 0.5), Vector2(x - hw, y)]
	if filled:
		_poly(pts, alpha)
	else:
		_line(pts, true)


## An iso block: lid at y, sides down by d.
static func _block(x: float, y: float, hw: float, d: float) -> void:
	_tile(x, y, hw)
	_line([Vector2(x - hw, y), Vector2(x - hw, y + d), Vector2(x, y + hw * 0.5 + d), Vector2(x + hw, y + d), Vector2(x + hw, y)])
	_line([Vector2(x, y + hw * 0.5), Vector2(x, y + hw * 0.5 + d)])


static func _arrow(a: Vector2, b: Vector2, head := 0.16) -> void:
	_line([a, b])
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	_line([b - d * head + n * head * 0.8, b, b - d * head - n * head * 0.8])


static func draw(ci: CanvasItem, id: String, r: Rect2, col: Color) -> void:
	_ci = ci
	var side := minf(r.size.x, r.size.y)
	_r = Rect2(r.position + (r.size - Vector2(side, side)) * 0.5, Vector2(side, side))
	_col = col
	_w = maxf(1.5, side / 13.0)
	match id:
		"party":
			_line([Vector2(0.4, 0.1), Vector2(0.6, 0.1), Vector2(0.6, 0.32), Vector2(0.4, 0.32)], true)
			_line([Vector2(0.28, 0.92), Vector2(0.36, 0.46), Vector2(0.64, 0.46), Vector2(0.72, 0.92)], true)
		"enemy":
			_line([Vector2(0.5, 0.08), Vector2(0.92, 0.5), Vector2(0.5, 0.92), Vector2(0.08, 0.5)], true)
			_line([Vector2(0.5, 0.36), Vector2(0.64, 0.5), Vector2(0.5, 0.64), Vector2(0.36, 0.5)], true)
		"select":
			_poly([Vector2(0.28, 0.14), Vector2(0.28, 0.8), Vector2(0.44, 0.64), Vector2(0.56, 0.88), Vector2(0.66, 0.83), Vector2(0.54, 0.6), Vector2(0.76, 0.6)])
		"stamp":
			_block(0.5, 0.52, 0.32, 0.2)
			_arrow(Vector2(0.5, 0.06), Vector2(0.5, 0.42), 0.12)
		"erase":
			_line([Vector2(0.2, 0.62), Vector2(0.5, 0.3), Vector2(0.8, 0.56), Vector2(0.52, 0.86), Vector2(0.36, 0.86)], true)
			_line([Vector2(0.36, 0.46), Vector2(0.66, 0.72)])
			_line([Vector2(0.52, 0.86), Vector2(0.86, 0.86)])
		"raise":
			_block(0.5, 0.62, 0.34, 0.14)
			_arrow(Vector2(0.5, 0.5), Vector2(0.5, 0.08))
		"lower":
			_block(0.5, 0.62, 0.34, 0.14)
			_arrow(Vector2(0.5, 0.08), Vector2(0.5, 0.5))
		"level":
			_block(0.5, 0.5, 0.36, 0.2)
			_line([Vector2(0.06, 0.32), Vector2(0.94, 0.32)])
		"smooth":
			_line([Vector2(0.08, 0.7), Vector2(0.24, 0.52), Vector2(0.4, 0.62), Vector2(0.56, 0.42), Vector2(0.72, 0.5), Vector2(0.92, 0.36)])
			_line([Vector2(0.08, 0.86), Vector2(0.92, 0.86)])
		"paint":
			_tile(0.42, 0.7, 0.34, true, 0.45)
			_tile(0.42, 0.7, 0.34)
			_line([Vector2(0.58, 0.52), Vector2(0.86, 0.12)])
			_poly([Vector2(0.5, 0.5), Vector2(0.62, 0.58), Vector2(0.52, 0.68), Vector2(0.42, 0.62)])
		"path":
			for i in 4:
				var t := float(i) / 3.0
				_circle(lerpf(0.18, 0.82, t), 0.82 - 0.22 * sin(t * PI) - 0.38 * t, 0.06, true)
			_line([Vector2(0.18, 0.82), Vector2(0.4, 0.56), Vector2(0.62, 0.48), Vector2(0.82, 0.22)])
		"river":
			for y in [0.34, 0.54, 0.74]:
				_line([Vector2(0.1, y), Vector2(0.26, y - 0.08), Vector2(0.42, y), Vector2(0.58, y - 0.08), Vector2(0.74, y), Vector2(0.9, y - 0.08)])
		"stairs":
			_line([Vector2(0.12, 0.86), Vector2(0.12, 0.7), Vector2(0.32, 0.7), Vector2(0.32, 0.52), Vector2(0.52, 0.52), Vector2(0.52, 0.34), Vector2(0.72, 0.34), Vector2(0.72, 0.16), Vector2(0.9, 0.16), Vector2(0.9, 0.86)], true)
		"cut":
			_circle(0.28, 0.74, 0.12)
			_circle(0.72, 0.74, 0.12)
			_line([Vector2(0.36, 0.64), Vector2(0.74, 0.12)])
			_line([Vector2(0.64, 0.64), Vector2(0.26, 0.12)])
		"fill":
			_tile(0.5, 0.66, 0.36)
			_line([Vector2(0.5, 0.1), Vector2(0.5, 0.48)])
			_line([Vector2(0.31, 0.29), Vector2(0.69, 0.29)])
		"zone":
			_poly([Vector2(0.5, 0.3), Vector2(0.88, 0.5), Vector2(0.5, 0.7)], 0.9)
			_tile(0.5, 0.5, 0.38)
		"new":
			_line([Vector2(0.22, 0.1), Vector2(0.6, 0.1), Vector2(0.78, 0.28), Vector2(0.78, 0.9), Vector2(0.22, 0.9)], true)
			_line([Vector2(0.5, 0.42), Vector2(0.5, 0.74)])
			_line([Vector2(0.34, 0.58), Vector2(0.66, 0.58)])
		"open":
			_line([Vector2(0.1, 0.24), Vector2(0.38, 0.24), Vector2(0.46, 0.34), Vector2(0.9, 0.34), Vector2(0.9, 0.82), Vector2(0.1, 0.82)], true)
			_line([Vector2(0.1, 0.46), Vector2(0.9, 0.46)])
		"save":
			_line([Vector2(0.14, 0.14), Vector2(0.72, 0.14), Vector2(0.86, 0.28), Vector2(0.86, 0.86), Vector2(0.14, 0.86)], true)
			_line([Vector2(0.3, 0.14), Vector2(0.3, 0.36), Vector2(0.64, 0.36), Vector2(0.64, 0.14)])
			_line([Vector2(0.28, 0.86), Vector2(0.28, 0.58), Vector2(0.72, 0.58), Vector2(0.72, 0.86)])
		"undo":
			_arc(0.54, 0.56, 0.28, PI * 1.05, PI * 2.25)
			_line([Vector2(0.1, 0.36), Vector2(0.26, 0.6), Vector2(0.44, 0.42)])
		"redo":
			_arc(0.46, 0.56, 0.28, -PI * 0.25, PI * 0.95)
			_line([Vector2(0.9, 0.36), Vector2(0.74, 0.6), Vector2(0.56, 0.42)])
		"turn":
			_arc(0.5, 0.5, 0.32, -PI * 0.3, PI * 1.4)
			_line([Vector2(0.88, 0.3), Vector2(0.76, 0.48), Vector2(0.6, 0.32)])
			_tile(0.5, 0.52, 0.14, true)
		"rotate":
			_arc(0.5, 0.52, 0.3, PI * 0.1, PI * 1.75)
			_line([Vector2(0.62, 0.08), Vector2(0.78, 0.24), Vector2(0.58, 0.32)])
		"mirror":
			_poly([Vector2(0.42, 0.2), Vector2(0.42, 0.8), Vector2(0.1, 0.8)])
			_line([Vector2(0.58, 0.2), Vector2(0.58, 0.8), Vector2(0.9, 0.8)], true)
			_line([Vector2(0.5, 0.06), Vector2(0.5, 0.94)])
		"trash":
			_line([Vector2(0.24, 0.3), Vector2(0.3, 0.88), Vector2(0.7, 0.88), Vector2(0.76, 0.3)])
			_line([Vector2(0.14, 0.24), Vector2(0.86, 0.24)])
			_line([Vector2(0.4, 0.24), Vector2(0.42, 0.12), Vector2(0.58, 0.12), Vector2(0.6, 0.24)])
		"grid":
			for t in [0.36, 0.64]:
				_line([Vector2(t, 0.1), Vector2(t, 0.9)])
				_line([Vector2(0.1, t), Vector2(0.9, t)])
		"heights":
			_line([Vector2(0.14, 0.86), Vector2(0.14, 0.62), Vector2(0.38, 0.62), Vector2(0.38, 0.38), Vector2(0.62, 0.38), Vector2(0.62, 0.14), Vector2(0.86, 0.14), Vector2(0.86, 0.86)], true)
		"fit":
			for c in [Vector2(0.12, 0.12), Vector2(0.88, 0.12), Vector2(0.88, 0.88), Vector2(0.12, 0.88)]:
				var dx := 0.24 if c.x < 0.5 else -0.24
				var dy := 0.24 if c.y < 0.5 else -0.24
				_line([c + Vector2(dx, 0), c, c + Vector2(0, dy)])
		"eye":
			var top := []
			var bot := []
			for k in 9:
				var t := float(k) / 8.0
				top.append(Vector2(0.08 + 0.84 * t, 0.5 - 0.3 * sin(t * PI)))
				bot.append(Vector2(0.08 + 0.84 * t, 0.5 + 0.3 * sin(t * PI)))
			_line(top)
			_line(bot)
			_circle(0.5, 0.5, 0.12, true)
		"play":
			_poly([Vector2(0.28, 0.14), Vector2(0.84, 0.5), Vector2(0.28, 0.86)])
		"assets":
			for q in [Vector2(0.12, 0.12), Vector2(0.54, 0.12), Vector2(0.12, 0.54), Vector2(0.54, 0.54)]:
				_line([q, q + Vector2(0.34, 0), q + Vector2(0.34, 0.34), q + Vector2(0, 0.34)], true)
		"inspect":
			for y in [0.24, 0.5, 0.76]:
				_line([Vector2(0.1, y), Vector2(0.9, y)])
			_circle(0.34, 0.24, 0.08, true)
			_circle(0.66, 0.5, 0.08, true)
			_circle(0.44, 0.76, 0.08, true)
		"map":
			_line([Vector2(0.06, 0.84), Vector2(0.36, 0.3), Vector2(0.54, 0.58), Vector2(0.68, 0.42), Vector2(0.94, 0.84)], true)
			_circle(0.76, 0.2, 0.08, true)
		"search":
			_circle(0.42, 0.42, 0.24)
			_line([Vector2(0.6, 0.6), Vector2(0.88, 0.88)])
		"chev_right":
			_line([Vector2(0.36, 0.2), Vector2(0.66, 0.5), Vector2(0.36, 0.8)])
		"chev_down":
			_line([Vector2(0.2, 0.36), Vector2(0.5, 0.66), Vector2(0.8, 0.36)])
		"star":
			var pts := []
			for i in 10:
				var a := -PI * 0.5 + i * PI / 5.0
				var rad := 0.42 if i % 2 == 0 else 0.18
				pts.append(Vector2(0.5 + cos(a) * rad, 0.54 + sin(a) * rad))
			_poly(pts)
		"door", "door_locked", "door_sealed", "door_stuck":
			_line([Vector2(0.24, 0.9), Vector2(0.24, 0.3), Vector2(0.5, 0.1), Vector2(0.76, 0.3), Vector2(0.76, 0.9)])
			_line([Vector2(0.14, 0.9), Vector2(0.86, 0.9)])
			if id == "door_sealed":
				_line([Vector2(0.3, 0.36), Vector2(0.7, 0.8)])
				_line([Vector2(0.7, 0.36), Vector2(0.3, 0.8)])
			elif id == "door_stuck":
				_line([Vector2(0.2, 0.56), Vector2(0.8, 0.5)])
			else:
				_circle(0.5, 0.5, 0.07, true)
				_line([Vector2(0.5, 0.56), Vector2(0.5, 0.72)])
		"enter":
			_line([Vector2(0.4, 0.9), Vector2(0.4, 0.3), Vector2(0.6, 0.14), Vector2(0.84, 0.3), Vector2(0.84, 0.9)])
			_arrow(Vector2(0.04, 0.6), Vector2(0.58, 0.6), 0.14)
		"exit":
			_line([Vector2(0.12, 0.86), Vector2(0.88, 0.86)])
			_line([Vector2(0.24, 0.86), Vector2(0.24, 0.14)])
			_poly([Vector2(0.24, 0.14), Vector2(0.76, 0.26), Vector2(0.24, 0.4)])
		"chest":
			_line([Vector2(0.12, 0.44), Vector2(0.88, 0.44), Vector2(0.88, 0.84), Vector2(0.12, 0.84)], true)
			_line([Vector2(0.12, 0.44), Vector2(0.16, 0.24), Vector2(0.84, 0.24), Vector2(0.88, 0.44)])
			_line([Vector2(0.5, 0.38), Vector2(0.5, 0.56)])
		"rack":
			_line([Vector2(0.5, 0.06), Vector2(0.5, 0.72)])
			_line([Vector2(0.32, 0.62), Vector2(0.68, 0.62)])
			_line([Vector2(0.5, 0.72), Vector2(0.5, 0.92)])
		"hidden":
			_circle(0.5, 0.36, 0.2)
			_line([Vector2(0.5, 0.56), Vector2(0.5, 0.68)])
			_circle(0.5, 0.84, 0.05, true)
		"shrine":
			_line([Vector2(0.3, 0.9), Vector2(0.34, 0.2), Vector2(0.5, 0.08), Vector2(0.66, 0.2), Vector2(0.7, 0.9)], true)
			_circle(0.5, 0.42, 0.09, true)
		"rubble":
			_line([Vector2(0.08, 0.86), Vector2(0.2, 0.58), Vector2(0.42, 0.56), Vector2(0.5, 0.86)], true)
			_line([Vector2(0.42, 0.86), Vector2(0.56, 0.4), Vector2(0.78, 0.44), Vector2(0.92, 0.86)], true)
		"blob":
			_block(0.5, 0.34, 0.36, 0.34)
		"start":
			_line([Vector2(0.26, 0.92), Vector2(0.26, 0.1)])
			_poly([Vector2(0.26, 0.1), Vector2(0.84, 0.24), Vector2(0.26, 0.42)])
		"note":
			_line([Vector2(0.16, 0.12), Vector2(0.84, 0.12), Vector2(0.84, 0.66), Vector2(0.6, 0.9), Vector2(0.16, 0.9)], true)
			for y in [0.32, 0.5]:
				_line([Vector2(0.28, y), Vector2(0.72, y)])
		"brush":
			_circle(0.5, 0.5, 0.36)
			_circle(0.5, 0.5, 0.08, true)
		"square":
			_line([Vector2(0.14, 0.14), Vector2(0.86, 0.14), Vector2(0.86, 0.86), Vector2(0.14, 0.86)], true)
		"diamond":
			_line([Vector2(0.5, 0.08), Vector2(0.92, 0.5), Vector2(0.5, 0.92), Vector2(0.08, 0.5)], true)
		"generate":
			for c in [Vector2(0.3, 0.3), Vector2(0.7, 0.3), Vector2(0.5, 0.5), Vector2(0.3, 0.7), Vector2(0.7, 0.7)]:
				_circle(c.x, c.y, 0.07, true)
			_line([Vector2(0.1, 0.1), Vector2(0.9, 0.1), Vector2(0.9, 0.9), Vector2(0.1, 0.9)], true)
		"focus":
			_circle(0.5, 0.5, 0.3)
			for d in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
				_line([Vector2(0.5, 0.5) + d * 0.3, Vector2(0.5, 0.5) + d * 0.46])
		_:
			_circle(0.5, 0.5, 0.3)

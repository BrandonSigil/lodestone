class_name MakerOverlay
extends Node2D
## Draws the map maker's marks over the board (a child of it, so it shares the board's transform):
## the brush footprint, a river or stair drag in progress, height numbers, and where the map's pieces,
## party start, enemy groups and things stand.

var maker: Node  ## the map maker scene (map_maker.gd)
var brush: Array[Vector2i] = []
var path: Array[Vector2i] = []
var path_color := Color(0.45, 0.8, 1.0)
var show_heights := false
var marks: Array[Dictionary] = []  ## {"cell": Vector2i, "color": Color}


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var b: CombatBoard = get_parent()
	if b == null or b.grid == null:
		return
	var g := b.grid
	var font := ThemeDB.fallback_font
	if show_heights:
		for y in g.h:
			for x in g.w:
				var c := Vector2i(x, y)
				if not g.solid(c) or b.hidden(c):
					continue
				var p := b.cell_top(c)
				draw_string_outline(font, p + Vector2(-10, 5), str(g.height_at(c)), HORIZONTAL_ALIGNMENT_CENTER, 20, 12, 3, Color(0, 0, 0, 0.6))
				draw_string(font, p + Vector2(-10, 5), str(g.height_at(c)), HORIZONTAL_ALIGNMENT_CENTER, 20, 12, Color(1, 1, 0.9))
	for m in marks:
		var c: Vector2i = m.cell
		if not g.in_bounds(c):
			continue
		var p := b.cell_top(c)
		Pawn.ellipse(self, p, 13.0, 5.0, Color(m.color, 0.85), false, 2.5)
		draw_line(p, p + Vector2(0, -22), Color(m.color, 0.9), 2.0, true)
		draw_circle(p + Vector2(0, -24), 4.0, m.color)
	for c in path:
		_outline(b, c, path_color, 2.5)
	for c in brush:
		_outline(b, c, Color(1, 1, 1, 0.85), 1.5)


func _outline(b: CombatBoard, c: Vector2i, col: Color, width: float) -> void:
	var g := b.grid
	var h := float(g.height_at(c)) if g.solid(c) else 0.0
	var pts := PackedVector2Array([b.iso(c.x, c.y, h), b.iso(c.x + 1, c.y, h), b.iso(c.x + 1, c.y + 1, h), b.iso(c.x, c.y + 1, h)])
	pts.append(pts[0])
	draw_polyline(pts, Color(0, 0, 0, 0.35), width + 2.0, true)
	draw_polyline(pts, col, width, true)

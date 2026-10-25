class_name Pawn
extends RefCounted
## Draws the graybox piece on any CanvasItem: foot disc, tapered body, round head.


static func ellipse(ci: CanvasItem, center: Vector2, rx: float, ry: float, color: Color, filled := true, width := 2.0) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	if filled:
		ci.draw_colored_polygon(pts, color)
	else:
		pts.append(pts[0])
		ci.draw_polyline(pts, color, width, true)


## base = point where the piece touches the ground; s = size (about body height).
static func draw(ci: CanvasItem, base: Vector2, s: float, color: Color, ring := Color(0, 0, 0, 0)) -> void:
	var dark := color.darkened(0.35)
	ellipse(ci, base + Vector2(0, 2), s * 0.6, s * 0.2, Color(0, 0, 0, 0.25))
	if ring.a > 0.0:
		ellipse(ci, base, s * 0.62, s * 0.22, ring, false, 2.5)
	ellipse(ci, base, s * 0.5, s * 0.16, dark)
	var body := PackedVector2Array([
		base + Vector2(-s * 0.42, -s * 0.05), base + Vector2(-s * 0.2, -s * 0.95),
		base + Vector2(s * 0.2, -s * 0.95), base + Vector2(s * 0.42, -s * 0.05)])
	ci.draw_colored_polygon(body, color)
	var outline := body.duplicate()
	outline.append(body[0])
	ci.draw_polyline(outline, dark, 2.0, true)
	var head := base + Vector2(0, -s * 1.22)
	ci.draw_circle(head, s * 0.3, color.lightened(0.25))
	ci.draw_arc(head, s * 0.3, 0, TAU, 24, dark, 2.0, true)
	ci.draw_circle(head + Vector2(-s * 0.1, 0), s * 0.04, dark)
	ci.draw_circle(head + Vector2(s * 0.1, 0), s * 0.04, dark)

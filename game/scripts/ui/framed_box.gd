class_name FramedBox
extends StyleBox
## UiTheme's panel: the leaf frame's look drawn in code (not a nine-slice): the fill, a double parchment rule and
## a blue diamond at each corner, so menus can grow, fade and animate (Brandon, 2026-10-30).

var bg_color := UiTheme.GREEN


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var rs := RenderingServer
	rs.canvas_item_add_rect(to_canvas_item, rect, bg_color)
	for ring: Array in [[rect.grow(-1), 2.0, UiTheme.RULE], [rect.grow(-5), 1.0, Color(UiTheme.RULE, 0.55)]]:
		var r: Rect2 = ring[0]
		if r.size.x <= 4 or r.size.y <= 4:
			continue
		rs.canvas_item_add_polyline(to_canvas_item, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.position.x, r.end.y), r.position]), PackedColorArray([ring[2]]), ring[1])
	for c in [rect.position + Vector2(1, 1), Vector2(rect.end.x - 1, rect.position.y + 1), Vector2(rect.position.x + 1, rect.end.y - 1), rect.end - Vector2(1, 1)]:
		var d := 5.0
		rs.canvas_item_add_polygon(to_canvas_item, PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]),
			PackedColorArray([UiTheme.DIAMOND]))

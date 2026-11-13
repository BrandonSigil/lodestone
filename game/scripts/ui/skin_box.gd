class_name SkinBox
extends StyleBox
## The drawn skin's panel (prototype, branch menus-prototype; docs/design/menus-v3.md): no bitmap, so it is sharp at
## any size and its rim is one pixel on a tooltip and on the win screen alike. Outside in: a soft drop shadow, an ink
## line, a gold hairline, then dark glass that is lighter at the top. `gem` sets the frame's blue diamond on the top
## edge (windows), `ticks` cuts a small diamond into each corner (the old corner gems, quiet), `plate` is a title tab.
## The world behind shows through blurred (SkinBackdrop, added by UiSkin.watch).

var radius := 6.0
var top := Color(0.075, 0.2, 0.175, 0.8)  ## the glass at its top edge
var bottom := Color(0.03, 0.095, 0.085, 0.86)  ## and at its foot
var rim := Color(0.93, 0.85, 0.62, 0.6)  ## the hairline
var rim_w := 1.0
var ink := Color(0.01, 0.04, 0.035, 0.85)  ## the line outside the hairline: holds the panel off a bright map
var shadow := 18.0  ## drop shadow size; 0 for none
var gem := false
var ticks := false
var plate := false
var sheen := 0.07  ## the lit line just inside the top edge
var blur := true  ## a PanelContainer wearing this gets the blurred world behind it (UiSkin.watch)


func _draw(to: RID, rect: Rect2) -> void:
	var rs := RenderingServer
	if shadow > 0.0:
		var sh := StyleBoxFlat.new()
		sh.draw_center = false
		sh.set_corner_radius_all(int(radius + 2.0))
		sh.shadow_color = Color(0, 0, 0, 0.42)
		sh.shadow_size = int(shadow)
		sh.shadow_offset = Vector2(0, shadow * 0.3)
		sh.draw(to, rect)
	# the glass: one polygon, coloured by height
	var pts := _rounded(rect.grow(-0.5), radius)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, clampf((p.y - rect.position.y) / maxf(1.0, rect.size.y), 0.0, 1.0)))
	rs.canvas_item_add_polygon(to, pts, cols)
	# the lit line inside the top edge
	if sheen > 0.0 and rect.size.x > radius * 4.0:
		rs.canvas_item_add_line(to, rect.position + Vector2(radius + 2.0, 2.5), Vector2(rect.end.x - radius - 2.0, rect.position.y + 2.5), Color(1, 1, 1, sheen), 1.0)
	# ink outside, the hairline inside it
	_ring(to, rect.grow(1.0), radius + 1.0, ink, 1.0)
	_ring(to, rect, radius, rim, rim_w)
	if ticks:
		var d := 4.5
		for c: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			var at := c + Vector2(signf(rect.get_center().x - c.x), signf(rect.get_center().y - c.y)) * (radius * 0.3 + 1.0)
			_diamond(to, at, d + 2.0, ink)
			_diamond(to, at, d, Color(rim, 1.0))
			_diamond(to, at, d - 2.0, Color(0.06, 0.45, 0.82))
	if gem:
		var at := Vector2(rect.get_center().x, rect.position.y)
		_diamond(to, at, 9.0, ink)
		_diamond(to, at, 7.5, Color(rim, 1.0))
		_diamond(to, at, 5.5, Color(0.06, 0.45, 0.82))
		_diamond(to, at + Vector2(-1.2, -1.2), 2.0, Color(0.62, 0.84, 1.0))
	if plate:
		for x: float in [rect.position.x + 13.0, rect.end.x - 13.0]:  # inside the tab, so a tab as wide as its window isn't clipped
			var at := Vector2(x, rect.get_center().y)
			_diamond(to, at, 6.5, ink)
			_diamond(to, at, 5.0, Color(rim, 1.0))
			_diamond(to, at, 3.2, Color(0.06, 0.45, 0.82))


static func _ring(to: RID, r: Rect2, rad: float, col: Color, w: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = col
	sb.set_border_width_all(maxi(1, int(round(w))))
	sb.set_corner_radius_all(int(rad))
	sb.corner_detail = 8
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 0.6
	sb.draw(to, r)


static func _diamond(to: RID, c: Vector2, r: float, col: Color) -> void:
	RenderingServer.canvas_item_add_polygon(to, PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), PackedColorArray([col]))


static func _rounded(r: Rect2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var corners := [[Vector2(r.end.x - rad, r.position.y + rad), -PI * 0.5], [Vector2(r.end.x - rad, r.end.y - rad), 0.0],
		[Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5], [Vector2(r.position.x + rad, r.position.y + rad), PI]]
	for c in corners:
		for i in 7:
			var a: float = float(c[1]) + PI * 0.5 * float(i) / 6.0
			pts.append((c[0] as Vector2) + Vector2(cos(a), sin(a)) * rad)
	return pts

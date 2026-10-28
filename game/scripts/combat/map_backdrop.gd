class_name MapBackdrop
extends RefCounted
## The valley staging's backdrop, drawn first on the board: sky, flat clouds, two mountain ranges and the
## forest the map stands in. Each band slides a little with the camera (parallax), so a big map feels deep;
## looking down a big map the bands lock behind its far edge. Code-drawn flat shapes in the look's colours
## (data/looks.csv) until painted strips replace them (docs/design/map-look.md, "Assets").

const PERIOD := 1600.0  ## board pixels before a band (a mountain range, a row of trees) repeats
## Parallax: how much of the camera's movement each band follows (0 = fixed to the world, 1 = to the screen).
const FOLLOW := {"cloud": 0.96, "far": 0.88, "near": 0.8, "wood_far": 0.65, "wood": 0.5}

static var _strips := {}  ## built bands, by shape and colours


## Flat shapes gathered into one triangle list: a band is built once, then drawn with a single call per
## repeat wherever the camera puts it. It takes the same calls the shapes make on a CanvasItem.
class Strip:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()

	func draw_colored_polygon(p: PackedVector2Array, c: Color) -> void:
		if p.size() < 3:
			return
		var tri := PackedInt32Array([0, 1, 2]) if p.size() == 3 else Geometry2D.triangulate_polygon(p)
		var base := pts.size()
		pts.append_array(p)
		for k in p.size():
			cols.append(c)
		for i in tri:
			idx.append(base + i)

	func draw_line(a: Vector2, b: Vector2, c: Color, width := 1.0, _aa := false) -> void:
		var n := (b - a).orthogonal().normalized() * width * 0.5
		draw_colored_polygon(PackedVector2Array([a + n, b + n, b - n, a - n]), c)

	func draw_circle(p: Vector2, r: float, c: Color) -> void:
		var ring := PackedVector2Array()
		for k in 14:
			ring.append(p + Vector2.from_angle(TAU * k / 14.0) * r)
		draw_colored_polygon(ring, c)

	func paint(ci: CanvasItem, at: Vector2) -> void:
		if idx.is_empty():
			return
		ci.draw_set_transform(at)
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, pts, cols)
		ci.draw_set_transform(Vector2.ZERO)


## The cached band for key, or null when it still has to be built (then _keep it).
static func _cached(key: String) -> Strip:
	return _strips.get(key)


static func _keep(key: String, st: Strip) -> Strip:
	if _strips.size() > 256:
		_strips.clear()
	_strips[key] = st
	return st


static func draw(ci: CanvasItem, b: CombatBoard, look: MapLook, lr: Rect2) -> void:
	var g := b.grid
	var tw := CombatBoard.TW
	var th := CombatBoard.TH
	var top := INF
	for corner in [Vector2(0, 0), Vector2(g.w, 0), Vector2(0, g.h), Vector2(g.w, g.h)]:
		top = minf(top, b.iso(corner.x, corner.y, g.top_height()).y)
	var cam := lr.get_center() - b.iso(g.w * 0.5, g.h * 0.5, 0.0)
	cam.y = minf(cam.y, 0.0)
	# Where the mountains meet the forest: a little way down the map, so the peaks rise from behind its far
	# terraces (as in the reference) instead of floating above it.
	var front := b.iso(g.w, g.h, 0.0).y
	for corner in [Vector2(g.w, 0), Vector2(0, g.h)]:
		front = maxf(front, b.iso(corner.x, corner.y, 0.0).y)
	var horizon := top + maxf(th * 1.2, (front - top) * 0.2)
	var seed_v := look.id.hash()
	var mh := tw * 2.5  # tallest peak
	ci.draw_rect(lr, look.color("wood"))
	var far_base: float = horizon + cam.y * FOLLOW.far
	var sky_low := far_base + th
	if sky_low > lr.position.y:
		var st := look.color("sky_top")
		var sl := look.color("sky_low")
		ci.draw_polygon(PackedVector2Array([lr.position, Vector2(lr.end.x, lr.position.y), Vector2(lr.end.x, sky_low), Vector2(lr.position.x, sky_low)]),
			PackedColorArray([st, st, sl, sl]))
		# A soft glow where the sun sits (upper left, B10).
		var sun := Vector2(lr.position.x + lr.size.x * 0.18, far_base - mh * 1.7)
		for k in 4:
			Pawn.ellipse(ci, sun, tw * (4.0 - k * 0.8), tw * (2.4 - k * 0.5), Color(1, 1, 0.94, 0.06), true)
		_clouds(ci, look, lr, far_base - mh * 1.45, cam * FOLLOW.cloud, seed_v)
	if look.ridge != "none":
		_range(ci, lr, far_base, cam.x * FOLLOW.far, mh, look.color("far"), look.color("far").darkened(0.16), look.color("snow"), seed_v, look.ridge)
		var near_base: float = horizon + th * 0.7 + cam.y * FOLLOW.near
		_range(ci, lr, near_base, cam.x * FOLLOW.near + PERIOD * 0.37, mh * 0.62, look.color("near"), look.color("near").darkened(0.16), look.color("snow").darkened(0.06), seed_v + 7, look.ridge)
		var haze := look.color("haze")
		var hz0 := near_base - mh * 0.45
		ci.draw_polygon(PackedVector2Array([Vector2(lr.position.x, hz0), Vector2(lr.end.x, hz0), Vector2(lr.end.x, near_base + th), Vector2(lr.position.x, near_base + th)]),
			PackedColorArray([Color(haze, 0.0), Color(haze, 0.0), Color(haze, 0.6), Color(haze, 0.6)]))
	var shape := "pine"
	match look.ridge:
		"mesas":
			shape = "mound"
		"spires", "none":
			shape = "shard"
	# Rows of forest from the treeline down past the bottom of the view, each nearer row bigger, darker and
	# following the world a little more, so holes and the ground's edges look into deep woods.
	var base := horizon + th * 1.3
	var k := 0
	while k < 40:
		var f := minf(k / 6.0, 1.0)
		var size := tw * lerpf(0.6, 1.1, f)
		var follow := lerpf(FOLLOW.wood_far, FOLLOW.wood, f)
		var y := base + cam.y * follow
		if y - size * 1.4 > lr.end.y:
			break
		var col := look.color("wood_far").lerp(look.color("wood"), minf(k / 4.0, 1.0)).lerp(look.color("floor_col"), clampf((k - 4) / 10.0, 0.0, 1.0))
		_treeline(ci, lr, y, cam.x * follow + k * 37.0, size, col, shape, seed_v + 3 + k)
		base += th * lerpf(1.3, 2.2, f)
		k += 1


static func _rng(seed_v: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	return r


static func _hash01(i: int, seed_v: int) -> float:
	return float(absi((i * 73856093) ^ (seed_v * 19349663)) % 1009) / 1009.0


## A mountain range along base_y, repeating every PERIOD. Lit left slopes, shaded right slopes, snow caps
## (peaks), rounded tops (hills), flat tops with a pale rim (mesas) or thin needles (spires).
static func _range(ci: CanvasItem, lr: Rect2, base_y: float, shift: float, hmax: float, lit: Color, shade: Color, snow: Color, seed_v: int, style: String) -> void:
	if base_y - hmax * 1.3 > lr.end.y or base_y < lr.position.y:
		return
	var key := "range|%d|%s|%s|%s|%s|%s" % [seed_v, style, hmax, lit.to_html(), shade.to_html(), snow.to_html()]
	var st := _cached(key)
	if st == null:
		st = _keep(key, _build_range(seed_v, style, hmax, lit, shade, snow))
	ci.draw_rect(Rect2(lr.position.x, base_y - 1.0, lr.size.x, CombatBoard.TH * 3.0), lit)
	var k0 := floori((lr.position.x - shift - hmax * 2.0) / PERIOD) - 1
	var k1 := floori((lr.end.x - shift + hmax * 2.0) / PERIOD)
	for k in range(k0, k1 + 1):
		st.paint(ci, Vector2(k * PERIOD + shift, base_y))


static func _build_range(seed_v: int, style: String, hmax: float, lit: Color, shade: Color, snow: Color) -> Strip:
	var b := Strip.new()
	var rng := _rng(seed_v)
	var peaks: Array = []
	var x := 0.0
	while x < PERIOD:
		# Mostly middling peaks, now and then a big one; peaks get a lower shoulder beside them so the range
		# reads as massifs rather than a row of teeth.
		var h := hmax * (0.42 + 0.5 * pow(rng.randf(), 1.5))
		if rng.randf() < 0.2:
			h = hmax * rng.randf_range(1.0, 1.22)
		var w := h * rng.randf_range(0.85, 1.4)
		peaks.append([x, h, w])
		if rng.randf() < 0.55:
			var sh := h * rng.randf_range(0.45, 0.7)
			peaks.append([x + w * rng.randf_range(0.35, 0.7) * (1.0 if rng.randf() < 0.5 else -1.0), sh, sh * rng.randf_range(0.9, 1.3)])
		x += w * rng.randf_range(0.6, 1.15)
	# Tall ones first, so the smaller peaks stand in front of them like foothills.
	peaks.sort_custom(func(p: Array, q: Array) -> bool: return p[1] > q[1])
	for p: Array in peaks:
		var px: float = p[0]
		var ph: float = p[1]
		var pw: float = p[2]
		match style:
			"hills":
				_hill(b, px, 0.0, ph * 0.55, pw * 1.2, lit, shade)
			"mesas":
				_mesa(b, px, 0.0, ph * 0.6, pw, lit, shade, snow)
			"spires":
				_spire(b, px, 0.0, ph * 1.1, pw * 0.28, lit, shade, snow)
			_:
				_peak(b, px, 0.0, ph, pw, lit, shade, snow)
	return b


static func _peak(b: Object, px: float, base: float, h: float, w: float, lit: Color, shade: Color, snow: Color) -> void:
	var l := Vector2(px - w, base)
	var t := Vector2(px, base - h)
	var r := Vector2(px + w, base)
	var foot := Vector2(px + w * 0.14, base)
	b.draw_colored_polygon(PackedVector2Array([l, t, r]), lit)
	b.draw_colored_polygon(PackedVector2Array([t, r, foot]), shade)
	var f := 0.36
	var cl := t.lerp(l, f)
	var cr := t.lerp(r, f)
	var cm := t.lerp(foot, f)
	var cap := PackedVector2Array([t, cr])
	for k in range(5, 0, -1):  # a zigzag snow line
		var q := cl.lerp(cr, k / 6.0)
		cap.append(q + Vector2(0, h * (0.07 if k % 2 == 0 else -0.02)))
	cap.append(cl)
	b.draw_colored_polygon(cap, snow)
	b.draw_colored_polygon(PackedVector2Array([t, cr, cm + Vector2(0, h * 0.04)]), snow.darkened(0.14))


static func _hill(b: Object, px: float, base: float, h: float, w: float, lit: Color, shade: Color) -> void:
	var pts := PackedVector2Array()
	var sh := PackedVector2Array()
	for k in 17:
		var dx := -w + 2.0 * w * k / 16.0
		var q := Vector2(px + dx, base - h * (0.5 + 0.5 * cos(PI * dx / w)))
		pts.append(q)
		if dx >= w * 0.1:
			sh.append(q)
	pts.append(Vector2(px + w, base))
	pts.append(Vector2(px - w, base))
	b.draw_colored_polygon(pts, lit)
	sh.append(Vector2(px + w, base))
	sh.append(Vector2(px + w * 0.25, base))
	if sh.size() >= 3:
		b.draw_colored_polygon(sh, shade)


static func _mesa(b: Object, px: float, base: float, h: float, w: float, lit: Color, shade: Color, rim: Color) -> void:
	var tl := Vector2(px - w * 0.55, base - h)
	var tr := Vector2(px + w * 0.55, base - h)
	b.draw_colored_polygon(PackedVector2Array([Vector2(px - w, base), tl, tr, Vector2(px + w, base)]), lit)
	b.draw_colored_polygon(PackedVector2Array([tr, Vector2(px + w, base), Vector2(px + w * 0.35, base), Vector2(px + w * 0.3, base - h)]), shade)
	b.draw_colored_polygon(PackedVector2Array([tl, tr, tr + Vector2(w * 0.04, h * 0.1), tl + Vector2(-w * 0.04, h * 0.1)]), rim)
	b.draw_line(Vector2(px - w * 0.75, base - h * 0.45), Vector2(px + w * 0.3, base - h * 0.45), shade, 2.0)


static func _spire(b: Object, px: float, base: float, h: float, w: float, lit: Color, shade: Color, glow: Color) -> void:
	var t := Vector2(px, base - h)
	b.draw_colored_polygon(PackedVector2Array([Vector2(px - w, base), t, Vector2(px + w, base)]), lit)
	b.draw_colored_polygon(PackedVector2Array([t, Vector2(px + w, base), Vector2(px + w * 0.1, base)]), shade)
	b.draw_line(t + Vector2(-w * 0.05, h * 0.1), Vector2(px - w * 0.45, base), Color(glow, 0.7), 2.0, true)


static func _clouds(b: CanvasItem, look: MapLook, lr: Rect2, y: float, shift: Vector2, seed_v: int) -> void:
	var col := look.color("cloud")
	var drift := fmod(Time.get_ticks_msec() * 0.004, PERIOD)
	for k in range(-1, 3):
		for i in 5:
			var r := _hash01(i, seed_v)
			var x := k * PERIOD + i * PERIOD / 5.0 + r * 120.0 + shift.x + drift
			if x < lr.position.x - 200.0 or x > lr.end.x + 200.0:
				continue
			var s := 22.0 + r * 18.0
			_cloud(b, Vector2(x, y + shift.y - (i % 3) * 34.0 + r * 20.0), s, col)


static func _cloud(b: CanvasItem, p: Vector2, s: float, col: Color) -> void:
	b.draw_circle(p + Vector2(-s * 0.9, 0), s * 0.55, col)
	b.draw_circle(p + Vector2(0, -s * 0.35), s * 0.78, col)
	b.draw_circle(p + Vector2(s * 0.95, -s * 0.05), s * 0.6, col)
	b.draw_rect(Rect2(p.x - s * 1.45, p.y - s * 0.05, s * 2.95, s * 0.55), col)
	b.draw_rect(Rect2(p.x - s * 1.45, p.y + s * 0.38, s * 2.95, s * 0.12), col.darkened(0.08))


## A row of tree silhouettes along base with the same colour filled in below it. The row repeats every
## PERIOD, so it is built once and stamped across the view.
static func _treeline(ci: CanvasItem, lr: Rect2, base: float, shift: float, size: float, col: Color, shape: String, seed_v: int) -> void:
	if base - size * 1.4 > lr.end.y:
		return
	if base < lr.end.y:
		ci.draw_rect(Rect2(lr.position.x, base, lr.size.x, lr.end.y - base + 1.0), col)
	var m := maxi(1, roundi(PERIOD / (size * 0.42)))
	var key := "row|%d|%s|%s|%s" % [seed_v, shape, size, col.to_html()]
	var st := _cached(key)
	if st == null:
		st = _keep(key, _build_row(m, seed_v, size, col, shape))
	var k0 := floori((lr.position.x - shift - size) / PERIOD) - 1
	var k1 := floori((lr.end.x - shift + size) / PERIOD)
	for k in range(k0, k1 + 1):
		st.paint(ci, Vector2(shift + k * PERIOD, base))


static func _build_row(m: int, seed_v: int, size: float, col: Color, shape: String) -> Strip:
	var b := Strip.new()
	var sp := PERIOD / m
	for i in m:
		var r := _hash01(i, seed_v)
		var r2 := _hash01(i + 7919, seed_v)
		var p := Vector2(i * sp + (r - 0.5) * sp * 0.9, (r2 - 0.5) * size * 0.45)
		var hh := size * (0.6 + 0.8 * r * r2 + 0.2 * r)
		match shape:
			"mound":
				b.draw_circle(p, hh * 0.32, col)
			"shard":
				b.draw_colored_polygon(PackedVector2Array([p + Vector2(-hh * 0.12, 2), p + Vector2(0, -hh * 0.9), p + Vector2(hh * 0.12, 2)]), col)
			_:
				pine(b, p + Vector2(0, 2), hh, col)
	return b


## A two-tier folk pine silhouette, feet at base; its sunny left half a shade lighter.
static func pine(ci: Object, base: Vector2, hh: float, col: Color) -> void:
	var w := hh * 0.34
	var lit := col.lightened(0.07)
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-w, 0), base + Vector2(0, -hh * 0.66), base + Vector2(w, 0)]), col)
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-w, 0), base + Vector2(0, -hh * 0.66), base]), lit)
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-w * 0.74, -hh * 0.38), base + Vector2(0, -hh), base + Vector2(w * 0.74, -hh * 0.38)]), col)
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-w * 0.74, -hh * 0.38), base + Vector2(0, -hh), base + Vector2(0, -hh * 0.38)]), lit)

class_name SkinBox
extends StyleBox
## The drawn skin's panel (prototype, branch menus-prototype; docs/design/menus-v3.md): no bitmap, so it is sharp at
## any size and its rim is the same few pixels on a tooltip and on the win screen alike. Round two ([USER] 2026-11-13:
## "fold back in just a bit more high-fantasy/painterly look ... it reads a bit like glassmorphism", "diamond shaped
## flourishes on major frames"): the fill is painted felt, not glass (deep green, nearly flat, with only a hint of brushed
## grain), almost solid. Outside in: a soft drop shadow, an ink line, a bevelled gold band, then the felt.
## `ornate` (windows): a dark gap and a cream hairline inside the gold, the hairline stepping in round a gold stud
## at each corner. `gem`: the blue diamond on the top edge, on a gold swell with a stud either side, and a small one on
## the foot. `plate`: a title banner with pointed ends and a diamond either side of the words.
## The world behind still shows through a little, blurred (SkinBackdrop, added by UiSkin.watch).
## The settings are exported so a duplicate() keeps them (MenuKit.window pads its title plate on a copy).

@export var radius := 6.0
@export var top := Color(0.05, 0.272, 0.218, 0.93)  ## the felt at its top edge
@export var bottom := Color(0.027, 0.162, 0.132, 0.95)  ## and at its foot
@export var rim := Color(0.95, 0.87, 0.62)  ## the gold band's lit edge
@export var rim_deep := Color(0.66, 0.5, 0.22)  ## and its shaded edge
@export var ink := Color(0.01, 0.04, 0.035, 0.9)  ## the line outside the gold: holds the panel off a bright map
@export var shadow := 18.0  ## drop shadow size; 0 for none
@export var ornate := false
@export var gem := false
@export var plate := false
@export var grain := GRAIN  ## how strongly the brushed grain shows; 0 for a flat fill
@export var blur := true  ## a PanelContainer wearing this gets the blurred world behind it (UiSkin.watch)

const GEM := Color(0.06, 0.45, 0.82)
## How strongly the grain shows. [USER] 2026-11-13: "make the marbling green even more subtle. Like closer to a flat
## green with just a hint of texture/marbling" (it was 0.22).
const GRAIN := 0.07
const CREAM := Color(0.95, 0.93, 0.86)
const GRAIN_TINT := Color(0.42, 0.95, 0.76)  ## the grain's light strokes; its dark strokes fall to the ink

static var _grain: ImageTexture


## The felt's brushed grain, made once: warped noise that tiles, in grey (each use tints it).
static func grain_tex() -> ImageTexture:
	if _grain == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.seed = 11
		n.frequency = 0.011
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = 4
		n.fractal_gain = 0.55
		n.domain_warp_enabled = true
		n.domain_warp_type = FastNoiseLite.DOMAIN_WARP_SIMPLEX
		n.domain_warp_amplitude = 46.0
		n.domain_warp_frequency = 0.018
		_grain = ImageTexture.create_from_image(n.get_seamless_image(256, 256, false, false, 0.25))
	return _grain


func _draw(to: RID, rect: Rect2) -> void:
	var rs := RenderingServer
	if plate:
		_draw_banner(to, rect)
		return
	if shadow > 0.0:
		var sh := StyleBoxFlat.new()
		sh.draw_center = false
		sh.set_corner_radius_all(int(radius + 2.0))
		sh.shadow_color = Color(0, 0, 0, 0.42)
		sh.shadow_size = int(shadow)
		sh.shadow_offset = Vector2(0, shadow * 0.3)
		sh.draw(to, rect)
	# the felt: one polygon coloured by height, the grain tiled over it, then a soft wash as wide as the panel
	var pts := _rounded(rect.grow(-0.5), radius)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, clampf((p.y - rect.position.y) / maxf(1.0, rect.size.y), 0.0, 1.0)))
	rs.canvas_item_add_polygon(to, pts, cols)
	if grain > 0.0 and rect.size.x > 8.0 and rect.size.y > 8.0:
		rs.canvas_item_add_texture_rect(to, rect.grow(-2.0), grain_tex().get_rid(), true, Color(GRAIN_TINT, grain * top.a))
		var uvs := PackedVector2Array()
		var wash := PackedColorArray()
		var span := maxf(rect.size.x, rect.size.y)
		for p in pts:
			uvs.append(Vector2(0.21, 0.13) + (p - rect.position) / span * 0.34)
			wash.append(Color(GRAIN_TINT, grain * 0.6 * top.a))
		rs.canvas_item_add_polygon(to, pts, wash, uvs, grain_tex().get_rid())
	# the rim: ink outside, then gold with a lit outer edge and a shaded inner one
	_ring(to, rect.grow(1.0), radius + 1.0, ink, 1.0)
	_ring(to, rect, radius, rim, 1.0)
	_ring(to, rect.grow(-1.0), maxf(radius - 1.0, 0.0), rim_deep, 1.0)
	var big := minf(rect.size.x, rect.size.y) >= 64.0  # room for the inner line and its corners
	if ornate and big:
		_ring(to, rect.grow(-2.0), maxf(radius - 2.0, 0.0), Color(ink, 0.5), 2.0)
		var inner := rect.grow(-7.5)
		var line := FramedBox._notched(inner, 9.0)
		line.append(line[0])
		rs.canvas_item_add_polyline(to, line, PackedColorArray([Color(CREAM, 0.5)]), 1.0, true)
		for c: Vector2 in [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]:
			stud(to, c, 4.0)
	if gem and rect.size.x >= 200.0:
		var at := Vector2(rect.get_center().x, rect.position.y + 0.5)
		_swell(to, at, 62.0, 3.6)
		for dx: float in [-74.0, 74.0]:
			stud(to, at + Vector2(dx, 0), 2.8)
		jewel(to, at, 8.0, 8.0)
		var foot := Vector2(rect.get_center().x, rect.end.y - 0.5)
		_swell(to, foot, 30.0, 2.6)
		stud(to, foot, 3.6)


## The title banner: a bar with pointed ends, gold round it, a diamond inside each end.
func _draw_banner(to: RID, rect: Rect2) -> void:
	var rs := RenderingServer
	var d := clampf(rect.size.y * 0.42, 5.0, 22.0)
	if shadow > 0.0:
		rs.canvas_item_add_polygon(to, _banner(Rect2(rect.position + Vector2(0, 3.0), rect.size).grow(1.5), d + 1.0), PackedColorArray([Color(0, 0, 0, 0.3)]))
	rs.canvas_item_add_polygon(to, _banner(rect.grow(1.5), d + 1.0), PackedColorArray([ink]))
	rs.canvas_item_add_polygon(to, _banner(rect, d), PackedColorArray([rim]))
	rs.canvas_item_add_polygon(to, _banner(rect.grow_individual(-1.4, -1.0, -1.4, 0.0), d - 0.6), PackedColorArray([rim_deep]))
	var body := rect.grow_individual(-3.2, -2.0, -3.2, -2.0)
	var pts := _banner(body, d - 1.6)
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var wash := PackedColorArray()
	for p in pts:
		cols.append(Color(top, 1.0).lerp(Color(bottom, 1.0), clampf((p.y - rect.position.y) / maxf(1.0, rect.size.y), 0.0, 1.0)))
		uvs.append(Vector2(0.1, 0.4) + (p - rect.position) / maxf(rect.size.x, 1.0) * 0.8)
		wash.append(Color(GRAIN_TINT, grain * 1.2))
	rs.canvas_item_add_polygon(to, pts, cols)
	if grain > 0.0:
		rs.canvas_item_add_polygon(to, pts, wash, uvs, grain_tex().get_rid())
	if rect.size.y >= 26.0:  # the cream line inside, as on a window
		var line := _banner(rect.grow(-5.5), d - 3.2)
		line.append(line[0])
		rs.canvas_item_add_polyline(to, line, PackedColorArray([Color(CREAM, 0.38)]), 1.0, true)
	var r := clampf(rect.size.y * 0.15, 3.2, 7.0)
	var cy := rect.get_center().y
	var left := maxf(rect.position.x + d + r + 5.0, rect.position.x + content_margin_left - r - 12.0)
	var right := minf(rect.end.x - d - r - 5.0, rect.end.x - content_margin_right + r + 12.0)
	if right - left > r * 8.0:
		jewel(to, Vector2(left, cy), r, r)
		jewel(to, Vector2(right, cy), r, r)


## A blue diamond in a gold mount: ink, bevelled gold, four facets and a light on the upper left. `lit` (0..1)
## brightens it (under the mouse, or calling for a click); `dim` greys it (nothing to open).
static func jewel(to: RID, c: Vector2, rx: float, ry: float, lit := 0.0, dim := false) -> void:
	var rs := RenderingServer
	var dia := func(k: float) -> PackedVector2Array:
		var kx := rx + k
		var ky := ry + k * ry / rx
		return PackedVector2Array([c + Vector2(0, -ky), c + Vector2(kx, 0), c + Vector2(0, ky), c + Vector2(-kx, 0)])
	var m := clampf(rx * 0.22, 1.2, 3.2)  # the mount's width
	var gold := Color(0.95, 0.87, 0.62)
	var gold_deep := Color(0.66, 0.5, 0.22)
	var blue := GEM
	if dim:
		gold = gold.lerp(Color(0.5, 0.52, 0.48), 0.5)
		gold_deep = gold_deep.lerp(Color(0.3, 0.32, 0.3), 0.5)
		blue = blue.lerp(Color(0.2, 0.3, 0.33), 0.6)
	if lit > 0.0:
		rs.canvas_item_add_polygon(to, dia.call(m + 5.0), PackedColorArray([Color(0.55, 0.85, 1.0, 0.22 * lit)]))
		rs.canvas_item_add_polygon(to, dia.call(m + 3.0), PackedColorArray([Color(0.7, 0.9, 1.0, 0.3 * lit)]))
	rs.canvas_item_add_polygon(to, dia.call(m + 1.2), PackedColorArray([Color(0.01, 0.04, 0.035, 0.95)]))
	rs.canvas_item_add_polygon(to, dia.call(m), PackedColorArray([gold_deep]))
	var d0: PackedVector2Array = dia.call(m)
	rs.canvas_item_add_polygon(to, PackedVector2Array([d0[3], d0[0], d0[1], c + Vector2(rx * 0.5, 0), c + Vector2(0, -ry * 0.5), c + Vector2(-rx * 0.5, 0)]), PackedColorArray([gold]))
	var d1: PackedVector2Array = dia.call(0.0)
	var shades := [blue.lightened(0.34 + 0.3 * lit), blue.lightened(0.1 + 0.3 * lit), blue.darkened(0.38 - 0.2 * lit), blue.darkened(0.12)]
	for i in 4:  # up left, up right, down right, down left
		var a: Vector2 = d1[(i + 3) % 4]
		var b: Vector2 = d1[i]
		rs.canvas_item_add_polygon(to, PackedVector2Array([c, a, b]), PackedColorArray([shades[i]]))
	if rx >= 5.0:  # the table: a smaller diamond on top, and the light on it
		var t := PackedVector2Array([c + Vector2(0, -ry * 0.42), c + Vector2(rx * 0.42, 0), c + Vector2(0, ry * 0.42), c + Vector2(-rx * 0.42, 0)])
		rs.canvas_item_add_polygon(to, t, PackedColorArray([Color(blue.lightened(0.2 + 0.35 * lit), 0.85)]))
		rs.canvas_item_add_polygon(to, PackedVector2Array([c + Vector2(-rx * 0.5, -ry * 0.12), c + Vector2(-rx * 0.12, -ry * 0.5), c + Vector2(-rx * 0.04, -ry * 0.36), c + Vector2(-rx * 0.36, -ry * 0.04)]),
			PackedColorArray([Color(1, 1, 1, 0.2 if dim else 0.7)]))


## A small gold diamond with a lit upper half: the corner of a frame, the end of a rule.
static func stud(to: RID, c: Vector2, r: float, alpha := 1.0) -> void:
	var rs := RenderingServer
	var dia := func(k: float) -> PackedVector2Array:
		return PackedVector2Array([c + Vector2(0, -k), c + Vector2(k, 0), c + Vector2(0, k), c + Vector2(-k, 0)])
	rs.canvas_item_add_polygon(to, dia.call(r + 1.2), PackedColorArray([Color(0.01, 0.04, 0.035, 0.9 * alpha)]))
	rs.canvas_item_add_polygon(to, dia.call(r), PackedColorArray([Color(0.66, 0.5, 0.22, alpha)]))
	rs.canvas_item_add_polygon(to, PackedVector2Array([c + Vector2(-r, 0), c + Vector2(0, -r), c + Vector2(r, 0)]), PackedColorArray([Color(0.95, 0.87, 0.62, alpha)]))


## The gold swell under an edge's diamond: a long thin lozenge lying on the edge, lit on top.
static func _swell(to: RID, c: Vector2, half: float, thick: float) -> void:
	var rs := RenderingServer
	rs.canvas_item_add_polygon(to, PackedVector2Array([c + Vector2(-half - 2.0, 0), c + Vector2(0, -thick - 1.2), c + Vector2(half + 2.0, 0), c + Vector2(0, thick + 1.2)]), PackedColorArray([Color(0.01, 0.04, 0.035, 0.9)]))
	rs.canvas_item_add_polygon(to, PackedVector2Array([c + Vector2(-half, 0), c + Vector2(0, -thick), c + Vector2(half, 0), c + Vector2(0, thick)]), PackedColorArray([Color(0.66, 0.5, 0.22)]))
	rs.canvas_item_add_polygon(to, PackedVector2Array([c + Vector2(-half, 0), c + Vector2(0, -thick), c + Vector2(half, 0)]), PackedColorArray([Color(0.95, 0.87, 0.62)]))


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


## A bar with pointed ends, `d` deep: the banner's outline, clockwise from the left point.
static func _banner(r: Rect2, d: float) -> PackedVector2Array:
	d = clampf(d, 1.0, r.size.x * 0.4)
	var cy := r.get_center().y
	return PackedVector2Array([Vector2(r.position.x, cy), Vector2(r.position.x + d, r.position.y), Vector2(r.end.x - d, r.position.y),
		Vector2(r.end.x, cy), Vector2(r.end.x - d, r.end.y), Vector2(r.position.x + d, r.end.y)])


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

class_name FramedBox
extends StyleBox
## UiTheme's panels and buttons, drawn in code ([USER] 2026-10-30, Brandon picked "frame green", direction A, from
## his own Picsart run; art/picsart/out/hand/menu_style_brandon.png). Outside in: an ink outline, a pale silver band
## with a lighter top edge, a blue band with a dark lower edge, a dark line, a cream line and an ink line, then deep
## green with a soft mottle. At each corner the inner lines step in round a notch holding a blue gem in a silver
## mount, and two olive leaves come out of the outer corner. `pill`: round ends (buttons), a gem and leaves at each
## end. `pointer`: a small V on the bottom edge (tooltips). Bands scale with the box, so a button's rim stays thin.

const INK := Color("1e1f1b")
const SILVER := Color("c7d3df")
const SILVER_LIGHT := Color("dbe4ea")
const BLUE := Color("1077c1")
const BLUE_DARK := Color("0e3e69")
const CREAM := Color("f2eddb")
const INK_GREEN := Color("0a201a")
const FILL := Color("064e3c")
const MOTTLE_LO := Color("034334")
const MOTTLE_HI := Color("0c5944")
const GEM := Color("1081e0")
const GEM_DARK := Color("0c65ad")
const LEAF := Color("a1ad59")
const LEAF_SHADE := Color("89974b")
const LEAF_INK := Color("182719")
const REF := 120.0  ## the box size (shorter side) the full-width rim is drawn for; smaller boxes scale it down

var pill := false
var pointer := false
var ornaments := true
var tint := Color.WHITE  ## hover, pressed and disabled looks: multiplies the fill and lifts or dims the rim
var glow := 0.0  ## 0..1: the rim's cream line brightens (a hovered or focused button)

static var _mottle: ImageTexture


## The green's soft mottle, made once: value noise between the two greens.
static func mottle() -> ImageTexture:
	if _mottle == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.02
		noise.fractal_octaves = 3
		noise.seed = 7
		var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
		for y in 256:
			for x in 256:
				var v := clampf(noise.get_noise_2d(x, y) * 0.9 + 0.5, 0.0, 1.0)
				img.set_pixel(x, y, MOTTLE_LO.lerp(MOTTLE_HI, v))
		_mottle = ImageTexture.create_from_image(img)
	return _mottle


func _draw(to: RID, rect: Rect2) -> void:
	var rs := RenderingServer
	var k := clampf(minf(rect.size.x, rect.size.y) / REF, 0.32, 1.0)
	var radius := rect.size.y * 0.5 if pill else 3.0 * k
	var bands: Array = [  # [inset from the outside, colour], each drawn filled inside the last
		[0.0, INK], [2.5 * k, SILVER], [5.5 * k, BLUE], [8.5 * k, INK_GREEN], [9.5 * k, CREAM], [12.0 * k, INK_GREEN]]
	var notch := (0.0 if pill else 9.0 * k)  # the inner lines step in round each corner's gem
	for i in bands.size():
		var inset: float = bands[i][0]
		var col: Color = bands[i][1]
		if rect.size.x - inset * 2.0 < 2.0 or rect.size.y - inset * 2.0 < 2.0:
			return  # too small for the rest of the rim
		if i >= 4 and not pill:
			rs.canvas_item_add_polygon(to, _notched(rect.grow(-inset), notch), PackedColorArray([_lift(col)]))
		else:
			rs.canvas_item_add_polygon(to, _rounded(rect.grow(-inset), maxf(radius - inset, 0.0)), PackedColorArray([_lift(col)]))
		if i == 1:  # the silver band's lighter top edge
			rs.canvas_item_add_line(to, rect.position + Vector2(radius, inset + k), Vector2(rect.end.x - radius, rect.position.y + inset + k), _lift(SILVER_LIGHT), maxf(1.0, k))
		if i == 2:  # the blue band's dark lower edge
			var y := rect.end.y - inset - 1.5 * k
			rs.canvas_item_add_line(to, Vector2(rect.position.x + radius, y), Vector2(rect.end.x - radius, y), BLUE_DARK, maxf(1.0, 1.5 * k))
	if glow > 0.0:  # a lit rim: the cream line brightens
		var g := rect.grow(-10.5 * k)
		var pts := _rounded(g, maxf(radius - 10.5 * k, 0.0)) if pill else _notched(g, notch)
		pts.append(pts[0])
		rs.canvas_item_add_polyline(to, pts, PackedColorArray([Color(1, 0.95, 0.7, glow)]), maxf(1.5, 2.0 * k))
	# the fill: deep green with the mottle, inside the last ink line
	var inner := rect.grow(-13.0 * k)
	if inner.size.x < 2.0 or inner.size.y < 2.0:
		return
	var poly := _rounded(inner, maxf(radius - 13.0 * k, 0.0)) if pill else _notched(inner, notch)
	var uvs := PackedVector2Array()
	var span := maxf(rect.size.x, rect.size.y)
	for p in poly:
		uvs.append((p - rect.position) / span)
	var cols := PackedColorArray()
	for p in poly:
		cols.append(tint)
	rs.canvas_item_add_polygon(to, poly, cols, uvs, mottle().get_rid())
	if pointer:  # a small V under the middle of the bottom edge
		var c := Vector2(rect.get_center().x, rect.end.y)
		var w := 10.0 * k
		rs.canvas_item_add_polygon(to, PackedVector2Array([c + Vector2(-w, -1), c + Vector2(w, -1), c + Vector2(0, w)]), PackedColorArray([INK]))
		rs.canvas_item_add_polygon(to, PackedVector2Array([c + Vector2(-w + 3 * k, -2), c + Vector2(w - 3 * k, -2), c + Vector2(0, w - 3 * k)]), PackedColorArray([FILL * tint]))
	if not ornaments:
		return
	var ok := clampf(k * 1.5, 0.55, 1.0)  # ornaments shrink less than the rim, so a button's gems still read
	if pill:  # a gem with a leaf each side at both ends
		var g := 6.0 * ok
		for side: float in [-1.0, 1.0]:
			var at := Vector2(rect.position.x + radius * 0.8 if side < 0 else rect.end.x - radius * 0.8, rect.get_center().y)
			var inward := Vector2(side, 0)
			_leaf(to, at + inward * g * 0.4, inward.rotated(-0.75).angle(), 14.0 * ok, 6.0 * ok)
			_leaf(to, at + inward * g * 0.4, inward.rotated(0.75).angle(), 14.0 * ok, 6.0 * ok)
			_gem(to, at, g)
		return
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var o: Vector2 = rect.position + rect.size * corner
		var away := Vector2(-1 if corner.x == 0 else 1, -1 if corner.y == 0 else 1)  # out of the corner
		var base: Vector2 = o - away * 9.0 * ok  # from just inside the corner, over the rim
		_leaf(to, base, Vector2(away.x * 0.3, away.y).angle(), 26.0 * ok, 11.0 * ok)  # one out past the side
		_leaf(to, base, Vector2(away.x, away.y * 0.3).angle(), 26.0 * ok, 11.0 * ok)  # one out past the edge
		_gem(to, o - away * (12.0 * k + notch * 0.35), 8.0 * ok)  # on the notch, inside the corner


## Lifts a rim colour for a lit button, dims it for a disabled one.
func _lift(c: Color) -> Color:
	return Color(c.r * lerpf(1.0, tint.r, 0.35), c.g * lerpf(1.0, tint.g, 0.35), c.b * lerpf(1.0, tint.b, 0.35), c.a * tint.a)


## A rounded rectangle's outline as points (radius 0: square corners).
static func _rounded(r: Rect2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	radius = minf(radius, minf(r.size.x, r.size.y) * 0.5)
	if radius < 0.75:  # square corners: four points (repeats break the triangulation)
		return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var centres := [r.position + Vector2(radius, radius), Vector2(r.end.x - radius, r.position.y + radius),
		r.end - Vector2(radius, radius), Vector2(r.position.x + radius, r.end.y - radius)]
	var start := [PI, PI * 1.5, 0.0, PI * 0.5]
	var segs := 8 if radius > 3.0 else 1
	for i in 4:
		for s in segs + 1:
			var a: float = start[i] + PI * 0.5 * s / segs
			var p: Vector2 = centres[i] + Vector2(cos(a), sin(a)) * radius
			if pts.is_empty() or pts[pts.size() - 1].distance_to(p) > 0.05:  # a pill's ends meet: no repeated points
				pts.append(p)
	if pts.size() > 1 and pts[0].distance_to(pts[pts.size() - 1]) <= 0.05:
		pts.remove_at(pts.size() - 1)
	return pts


## A rectangle whose corners step inward round a small notch (the inner lines round each corner's gem): at each
## corner a concave quarter circle of radius n, centred on the corner itself. Points go clockwise from the top left.
static func _notched(r: Rect2, n: float) -> PackedVector2Array:
	if n <= 0.5 or n * 2.5 >= minf(r.size.x, r.size.y):
		return _rounded(r, 0.0)
	var pts := PackedVector2Array()
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		var c: Vector2 = corners[i]
		var a0 := PI * 0.5 * (i + 1)  # top left 90..0 degrees, top right 180..90, bottom right 270..180, bottom left 360..270
		for s in 7:
			var a := a0 - PI * 0.5 * s / 6.0
			pts.append(c + Vector2(cos(a), sin(a)) * n)
	return pts


## A blue gem in a silver mount, with an ink outline and a darker facet.
static func _gem(to: RID, c: Vector2, r: float) -> void:
	var rs := RenderingServer
	var dia := func(rr: float) -> PackedVector2Array:
		return PackedVector2Array([c + Vector2(0, -rr), c + Vector2(rr, 0), c + Vector2(0, rr), c + Vector2(-rr, 0)])
	rs.canvas_item_add_polygon(to, dia.call(r + 2.2), PackedColorArray([INK]))
	rs.canvas_item_add_polygon(to, dia.call(r + 1.0), PackedColorArray([SILVER]))
	rs.canvas_item_add_polygon(to, dia.call(r * 0.68), PackedColorArray([GEM]))
	rs.canvas_item_add_polygon(to, PackedVector2Array([c, c + Vector2(r * 0.68, 0), c + Vector2(0, r * 0.68)]), PackedColorArray([GEM_DARK]))
	rs.canvas_item_add_circle(to, c + Vector2(-r * 0.22, -r * 0.22), maxf(0.8, r * 0.12), Color(1, 1, 1, 0.8))


## An olive leaf from `base` pointing at `angle`: light, a shaded half, a dark outline and a vein.
static func _leaf(to: RID, base: Vector2, angle: float, length: float, width: float) -> void:
	var rs := RenderingServer
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var steps := 10
	for s in steps + 1:
		var t := float(s) / steps
		var half := width * 0.5 * pow(sin(PI * t), 0.75)
		left.append(base + Vector2(t * length, -half).rotated(angle))
		right.append(base + Vector2(t * length, half).rotated(angle))
	var outline := left.duplicate()
	for i in range(right.size() - 1, -1, -1):
		outline.append(right[i])
	rs.canvas_item_add_polygon(to, outline, PackedColorArray([LEAF]))
	var shade := PackedVector2Array()
	for s in steps + 1:
		shade.append(base + Vector2(float(s) / steps * length, 0).rotated(angle))
	for i in range(right.size() - 1, -1, -1):
		shade.append(right[i])
	rs.canvas_item_add_polygon(to, shade, PackedColorArray([LEAF_SHADE]))
	outline.append(outline[0])
	rs.canvas_item_add_polyline(to, outline, PackedColorArray([LEAF_INK]), 1.2)
	rs.canvas_item_add_line(to, base, base + Vector2(length * 0.85, 0).rotated(angle), LEAF_INK, 0.9)

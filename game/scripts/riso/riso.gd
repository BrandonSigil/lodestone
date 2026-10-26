class_name Riso
extends RefCounted
## The riso drawing kit from style lab draft 1 (docs/style-lab/index.html), ported to Godot.
## Palettes blended by strangeness, plus the shape vocabulary every screen draws with:
## gumdrops, scallop pines, lollipops, houses, pieces, folk stamps and the Lodestone medallion.
## Everything is a pure function of seed and strangeness (style bible section 0).
## Call the draw_* helpers from a CanvasItem's _draw().

const ROLES := ["sky_top", "horizon", "far", "mid", "near", "ground", "dark", "accent", "light"]

## Style bible section 5. Each region: strangeness, then the nine roles in ROLES order.
const REGIONS := [
	[0.00, ["#b6a2d0", "#f2b36b", "#9a86b6", "#7f8c5c", "#4c5a3b", "#d6cc96", "#2e2440", "#ffcf4a", "#fbf1d8"]],
	[0.25, ["#5f8bc6", "#ece8c6", "#3d8ff5", "#79c0f6", "#1d68cf", "#c6e1e2", "#1a2c55", "#ffe08a", "#f1f8f8"]],
	[0.50, ["#c46a01", "#ec5a10", "#8a3b6e", "#6a46a0", "#3c0f2a", "#6c4aa6", "#2a0a1c", "#f4e04d", "#c2aef0"]],
	[0.75, ["#7891db", "#d6a6cf", "#c28594", "#f99487", "#c9664c", "#ebbacb", "#3b2a5a", "#ff5fa8", "#ffe6da"]],
	[1.00, ["#14302f", "#3d6c5c", "#9de0b5", "#e6f29a", "#6b3278", "#2c1f3d", "#110c1e", "#ff8a3d", "#f5ffe0"]],
]

## Piece colors never change between regions (R7).
const RED := Color("#c8363c")
const OCHRE := Color("#e0a03a")
const CREAM := Color("#f3ead2")
const INDIGO := Color("#3a3f7a")
const BASE := Color("#2a2433")

## Frame A (embroidered band) colors.
const GOLD := Color("#e6c76a")
const GOLD_DARK := Color("#b8913c")
const PAPER := Color("#f7eccb")
const INK := Color("#3b2c2a")

const FONT_PATH := "res://fonts/YoungSerif-Regular.ttf"
const GRAIN_SHADER := "res://shaders/riso_grain.gdshader"

static var _font: Font


## The nine roles at strangeness s, as Colors keyed by ROLES names.
static func palette_at(s: float) -> Dictionary:
	s = clampf(s, 0.0, 1.0)
	var i := 0
	while i < REGIONS.size() - 2 and s > float(REGIONS[i + 1][0]):
		i += 1
	var a: Array = REGIONS[i]
	var b: Array = REGIONS[i + 1]
	var t := (s - float(a[0])) / (float(b[0]) - float(a[0]))
	var p := {}
	for k in ROLES.size():
		p[ROLES[k]] = Color(a[1][k]).lerp(Color(b[1][k]), t)
	return p


static func mix(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, t)


static func alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


static func rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


static func smooth(a: float, b: float, x: float) -> float:
	return smoothstep(a, b, x)


static func font() -> Font:
	if _font == null:
		_font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else ThemeDB.fallback_font
	return _font


## A ColorRect covering the screen that lays the fixed paper grain and mottle over
## everything drawn below it (R6). Put it in a CanvasLayer above the scene.
static func grain_rect(seed_value := 7) -> ColorRect:
	var cr := ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load(GRAIN_SHADER)
	m.set_shader_parameter("seed", float(seed_value % 1000))
	cr.material = m
	return cr


# --- geometry -------------------------------------------------------------

static func cubic(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, steps := 10) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var u := 1.0 - t
		out.append(p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t)
	return out


static func quad(p0: Vector2, p1: Vector2, p2: Vector2, steps := 8) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(1, steps + 1):
		var t := float(i) / steps
		out.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))
	return out


static func circle_pts(c: Vector2, rx: float, ry: float, n := 28, a0 := 0.0, a1 := TAU) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out


## Soft round mountain sitting on y = base (R3).
static func gumdrop_pts(x: float, base: float, w: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(x - w / 2, base)])
	pts.append_array(cubic(Vector2(x - w / 2, base), Vector2(x - w * 0.3, base - h * 0.12), Vector2(x - w * 0.34, base - h), Vector2(x, base - h)))
	pts.append_array(cubic(Vector2(x, base - h), Vector2(x + w * 0.34, base - h), Vector2(x + w * 0.3, base - h * 0.12), Vector2(x + w / 2, base)))
	return pts


static func ridge_y(x: float, w: float, y0: float, amp: float, freq: float, phase: float) -> float:
	return y0 - amp * (sin(x / w * freq * TAU + phase) * 0.6 + sin(x / w * freq * 2.7 * TAU + phase * 1.7) * 0.4)


## A rolling hill filled down to the bottom edge h.
static func ridge_pts(w: float, h: float, y0: float, amp: float, freq: float, phase: float, x0 := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(x0, h)])
	for i in 81:
		var x := x0 + (w - x0) * i / 80.0
		pts.append(Vector2(x, ridge_y(x, w, y0, amp, freq, phase)))
	pts.append(Vector2(w, h))
	return pts


static func poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() >= 3:
		ci.draw_colored_polygon(pts, col)


## Vertical gradient (skies only, R2) drawn as a strip of quads.
static func draw_sky(ci: CanvasItem, rect: Rect2, top: Color, low: Color) -> void:
	var mid := mix(top, low, 0.38)
	var stops := [[0.0, top], [0.6, mid], [1.0, low]]
	for i in stops.size() - 1:
		var y0: float = rect.position.y + rect.size.y * float(stops[i][0])
		var y1: float = rect.position.y + rect.size.y * float(stops[i + 1][0])
		var c0: Color = stops[i][1]
		var c1: Color = stops[i + 1][1]
		ci.draw_polygon(
			PackedVector2Array([Vector2(rect.position.x, y0), Vector2(rect.end.x, y0), Vector2(rect.end.x, y1), Vector2(rect.position.x, y1)]),
			PackedColorArray([c0, c0, c1, c1]))


# --- shape vocabulary -------------------------------------------------------

## Gumdrop with one or two lighter inner bands, like the cats-on-log mountains (R3, R4).
static func draw_gumdrop(ci: CanvasItem, x: float, base: float, w: float, h: float, col: Color, light: Color) -> void:
	poly(ci, gumdrop_pts(x, base, w, h), col)
	poly(ci, gumdrop_pts(x + w * 0.16, base, w * 0.78, h * 0.76), mix(col, light, 0.28))
	poly(ci, gumdrop_pts(x + w * 0.32, base, w * 0.56, h * 0.52), mix(col, light, 0.5))


static func draw_crescent(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	# The moon disc minus a bite circle offset up and right, as in the style lab.
	var bite_c := c + Vector2(r * 0.5, -r * 0.25)
	var bite_r := r * 0.92
	var pts := PackedVector2Array()
	var n := 48
	for i in n:
		var a := TAU * i / n
		var q := c + Vector2(cos(a), sin(a)) * r
		if q.distance_to(bite_c) >= bite_r:
			pts.append(q)
	# walk the bite's edge back, keeping only the part inside the moon
	var inner := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var q := bite_c + Vector2(cos(a), sin(a)) * bite_r
		if q.distance_to(c) < r:
			inner.append(q)
	# order both runs by angle around the moon's center so they join into one outline
	var outer_sorted := _sort_around(pts, c, bite_c)
	var inner_sorted := _sort_around(inner, c, bite_c)
	inner_sorted.reverse()
	outer_sorted.append_array(inner_sorted)
	poly(ci, outer_sorted, col)


## Sorts points by angle measured from the direction pointing away from the bite,
## so a run that wraps past angle 0 stays contiguous.
static func _sort_around(pts: PackedVector2Array, c: Vector2, bite_c: Vector2) -> PackedVector2Array:
	var away := (c - bite_c).angle()
	var arr: Array = Array(pts)
	arr.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return wrapf((a - c).angle() - away, -PI, PI) < wrapf((b - c).angle() - away, -PI, PI))
	return PackedVector2Array(arr)


## Stepped cut-paper cloud.
static func draw_step_cloud(ci: CanvasItem, x: float, y: float, w: float, h: float, col: Color, r: RandomNumberGenerator) -> void:
	var n := 3 + r.randi_range(0, 2)
	var cx := x
	for i in n:
		var ww := w * (0.4 + r.randf() * 0.6)
		ci.draw_rect(Rect2(cx, y + i * h, ww, h + 1), col)
		cx += (r.randf() - 0.3) * w * 0.35


## Four stacked scallops (R3).
static func draw_pine(ci: CanvasItem, x: float, y: float, h: float, col: Color, light: Color) -> void:
	var w := h * 0.42
	for i in 4:
		var ty := y - h * (i * 0.22)
		var tw := w * (1.0 - i * 0.2)
		var pts := PackedVector2Array([Vector2(x - tw / 2, ty)])
		pts.append_array(quad(Vector2(x - tw / 2, ty), Vector2(x - tw * 0.15, ty - h * 0.12), Vector2(x, ty - h * 0.34)))
		pts.append_array(quad(Vector2(x, ty - h * 0.34), Vector2(x + tw * 0.15, ty - h * 0.12), Vector2(x + tw / 2, ty)))
		pts.append_array(quad(Vector2(x + tw / 2, ty), Vector2(x + tw * 0.25, ty - h * 0.05), Vector2(x, ty - h * 0.02)))
		pts.append_array(quad(Vector2(x, ty - h * 0.02), Vector2(x - tw * 0.25, ty - h * 0.05), Vector2(x - tw / 2, ty)))
		poly(ci, pts, col)
	for i in 3:
		ci.draw_circle(Vector2(x + (i - 1) * h * 0.06, y - h * (0.2 + i * 0.18)), maxf(1.0, h * 0.018), light)


static func draw_lolly(ci: CanvasItem, x: float, y: float, h: float, trunk: Color, crown: Color, r: RandomNumberGenerator) -> void:
	var lw := maxf(1.5, h * 0.035)
	ci.draw_line(Vector2(x, y), Vector2(x, y - h * 0.75), trunk, lw, true)
	ci.draw_line(Vector2(x, y - h * 0.45), Vector2(x + h * 0.12, y - h * 0.62), trunk, lw, true)
	for i in 4 + r.randi_range(0, 2):
		ci.draw_circle(Vector2(x + (r.randf() - 0.5) * h * 0.32, y - h * (0.6 + r.randf() * 0.38)), h * (0.08 + r.randf() * 0.07), crown)


## Dark block house with a light roof and one lit window (R8). y is the ground line.
static func draw_house(ci: CanvasItem, x: float, y: float, w: float, p: Dictionary, lit: bool, wall: Color = Color.TRANSPARENT) -> void:
	var dark: Color = p.dark if wall.a == 0.0 else wall
	var roof := mix(p.light, p.sky_top, 0.25)
	var h := w * 0.55
	ci.draw_rect(Rect2(x - w / 2, y - h, w, h), dark)
	poly(ci, PackedVector2Array([Vector2(x - w * 0.62, y - h + 2), Vector2(x - w * 0.1, y - h - w * 0.42),
		Vector2(x + w * 0.12, y - h - w * 0.42), Vector2(x + w * 0.62, y - h + 2)]), roof)
	ci.draw_rect(Rect2(x + w * 0.2, y - h - w * 0.5, w * 0.08, w * 0.18), dark)
	if lit:
		ci.draw_circle(Vector2(x - w * 0.2, y - h * 0.48), w * 0.13, alpha(p.accent, 0.22))
		ci.draw_rect(Rect2(x - w * 0.26, y - h * 0.58, w * 0.12, w * 0.14), p.accent)
	else:
		ci.draw_rect(Rect2(x + w * 0.05, y - h * 0.58, w * 0.1, w * 0.12), alpha(p.light, 0.25))


## Ticks, dots, fans or rings scattered inside a polygon, one step off its plane (R4).
static func draw_marks(ci: CanvasItem, area: PackedVector2Array, rect: Rect2, col: Color, kind: String, count: int, r: RandomNumberGenerator) -> void:
	for i in count:
		var pos := Vector2(rect.position.x + r.randf() * rect.size.x, rect.position.y + r.randf() * rect.size.y)
		var s := 3.0 + r.randf() * 5.0
		if not Geometry2D.is_point_in_polygon(pos, area):
			continue
		match kind:
			"tick":
				ci.draw_line(pos, pos + Vector2(s * 2.2, -s * 0.35), col, 1.6, true)
			"dot":
				ci.draw_circle(pos, s * 0.35, col)
			"fan":
				for k in range(-2, 3):
					ci.draw_line(pos, pos + Vector2(k * s * 0.45, -s * 1.4), col, 1.4, true)
			"ring":
				ci.draw_arc(pos, s * 0.55, 0, TAU, 14, col, 1.4, true)


# --- pieces -----------------------------------------------------------------

## A board-game piece: base disc, bell body, round head, two dot eyes, optional hat and pack.
## base = where it touches the ground, h = full height. opt keys: hat ("hood"/"point"),
## pack (bool), rim (Color, for dark ground), stone (accent Color: carries the Lodestone),
## dim (bool, locked or downed), dir (1 or -1).
static func draw_piece(ci: CanvasItem, base: Vector2, h: float, col: Color, opt := {}) -> void:
	var x := base.x
	var y := base.y
	if opt.get("dim", false):
		col = mix(col, BASE, 0.55)
	poly(ci, circle_pts(Vector2(x, y), h * 0.34, h * 0.09), alpha(BASE, 0.35))
	poly(ci, circle_pts(Vector2(x, y - h * 0.04), h * 0.27, h * 0.075), mix(col, BASE, 0.35))
	var dir: float = opt.get("dir", 1.0)
	if opt.get("pack", false):
		poly(ci, circle_pts(Vector2(x - dir * h * 0.17, y - h * 0.45), h * 0.14, h * 0.17), mix(OCHRE, BASE, 0.25))
	var body := PackedVector2Array([Vector2(x - h * 0.22, y - h * 0.06)])
	body.append_array(quad(Vector2(x - h * 0.22, y - h * 0.06), Vector2(x - h * 0.2, y - h * 0.55), Vector2(x, y - h * 0.6)))
	body.append_array(quad(Vector2(x, y - h * 0.6), Vector2(x + h * 0.2, y - h * 0.55), Vector2(x + h * 0.22, y - h * 0.06)))
	var head := Vector2(x, y - h * 0.74)
	var rim: Color = opt.get("rim", Color.TRANSPARENT)
	if rim.a > 0.0:
		var loop := body.duplicate()
		loop.append(body[0])
		ci.draw_polyline(loop, rim, h * 0.07, true)
		ci.draw_arc(head, h * 0.17, 0, TAU, 24, rim, h * 0.07, true)
	poly(ci, body, col)
	ci.draw_circle(head, h * 0.17, mix(col, Color.WHITE, 0.25))
	ci.draw_circle(head + Vector2(-h * 0.06, -h * 0.01), maxf(1.0, h * 0.022), BASE)
	ci.draw_circle(head + Vector2(h * 0.06, -h * 0.01), maxf(1.0, h * 0.022), BASE)
	match opt.get("hat", ""):
		"point":
			poly(ci, PackedVector2Array([Vector2(x - h * 0.15, y - h * 0.84), Vector2(x + h * 0.04, y - h * 1.12), Vector2(x + h * 0.16, y - h * 0.84)]), mix(col, BASE, 0.3))
		"hood":
			poly(ci, circle_pts(head + Vector2(0, -h * 0.04), h * 0.19, h * 0.19, 16, PI * 1.05, PI * 1.95), mix(col, BASE, 0.2))
	var stone: Color = opt.get("stone", Color.TRANSPARENT)
	if stone.a > 0.0:
		ci.draw_circle(Vector2(x + h * 0.28, y - h * 0.42), h * 0.14, alpha(stone, 0.3))
		ci.draw_circle(Vector2(x + h * 0.28, y - h * 0.42), h * 0.06, stone)


## Piece colors and hats for roster members, until Brandon draws them (style bible section 8).
static func piece_style(d: CharacterDef) -> Dictionary:
	match String(d.id):
		"lead": return {"col": RED, "hat": "hood", "pack": true}
		"stardrop": return {"col": INDIGO, "hat": "point"}
		"hunter": return {"col": OCHRE, "pack": true}
		"wizard": return {"col": mix(INDIGO, RED, 0.35), "hat": "point", "pack": true}
		"bushberry": return {"col": Color("#5e7d4a")}
		"skeleton_archer": return {"col": CREAM}
		"lewith_flark": return {"col": mix(RED, OCHRE, 0.5), "hat": "hood"}
	return {"col": d.tint}


# --- folk stamps (R9) ---------------------------------------------------------

static func draw_stamp_star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := i * PI / 4 - PI / 2
		var rr := r * 0.32 if i % 2 else r
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	poly(ci, pts, col)


static func draw_stamp_step(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var u := r / 3.0
	for i in range(-2, 3):
		var w := (3 - absi(i)) * u * 1.1
		ci.draw_rect(Rect2(c.x - w / 2, c.y + i * u - u / 2, w, u * 0.8), col)


static func draw_stamp_tree(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var x := c.x
	var y := c.y
	poly(ci, PackedVector2Array([Vector2(x, y - r), Vector2(x + r * 0.5, y - r * 0.25), Vector2(x + r * 0.25, y - r * 0.25),
		Vector2(x + r * 0.7, y + r * 0.45), Vector2(x - r * 0.7, y + r * 0.45), Vector2(x - r * 0.25, y - r * 0.25), Vector2(x - r * 0.5, y - r * 0.25)]), col)
	ci.draw_rect(Rect2(x - r * 0.12, y + r * 0.45, r * 0.24, r * 0.35), col)


static func draw_stamp_checker(ci: CanvasItem, c: Vector2, r: float, a: Color, b: Color) -> void:
	var u := r * 2.0 / 4.0
	for i in 4:
		for j in 4:
			ci.draw_rect(Rect2(c.x - r + i * u, c.y - r + j * u, u, u), a if (i + j) % 2 else b)


# --- UI pieces -----------------------------------------------------------------

## The Lodestone medallion. s fills the travelled arc (0 = home, 1 = deepest).
static func draw_stone(ci: CanvasItem, c: Vector2, r: float, p: Dictionary, s: float) -> void:
	ci.draw_circle(c, r * 1.25, alpha(p.accent, 0.22))
	ci.draw_circle(c, r, Color("#3a3350"))
	ci.draw_circle(c - Vector2(r, r) * 0.12, r * 0.86, Color("#4d4568"))
	var a0 := PI * 0.85
	var steps := 22
	for i in steps:
		if i % 2 == 0:
			ci.draw_arc(c, r * 0.64, a0 + PI * 1.3 * i / steps, a0 + PI * 1.3 * (i + 1) / steps, 3, Color("#d9cfa8"), r * 0.04, true)
	var a := a0 + PI * 1.3 * clampf(s, 0.0, 1.0)
	if s > 0.0:
		ci.draw_arc(c, r * 0.64, a0, a, 24, Color("#ffe9a8"), r * 0.07, true)
	var wa := PI * 1.5
	ci.draw_line(c + Vector2(cos(wa), sin(wa)) * r * 0.5, c + Vector2(cos(wa), sin(wa)) * r * 0.8, Color("#b49be6"), r * 0.05, true)
	ci.draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.64, r * 0.09, p.accent)
	poly(ci, PackedVector2Array([c + Vector2(0, -r * 0.2), c + Vector2(r * 0.07, 0), c + Vector2(0, r * 0.2), c + Vector2(-r * 0.07, 0)]), Color("#ffe9a8"))


## Item icon by kind ("food", "med", "book", "crate", "herb"), centered in a box of size sz.
static func draw_item_icon(ci: CanvasItem, kind: String, c: Vector2, sz: float) -> void:
	match kind:
		"food":
			poly(ci, circle_pts(c, sz * 0.36, sz * 0.24), Color("#c98a3c"))
			for i in range(-1, 2):
				ci.draw_line(c + Vector2(i * sz * 0.14 - sz * 0.05, -sz * 0.12), c + Vector2(i * sz * 0.14 + sz * 0.05, sz * 0.02), Color("#8a5a22"), sz * 0.05, true)
		"crate":
			ci.draw_rect(Rect2(c - Vector2(sz, sz) * 0.36, Vector2(sz, sz) * 0.72), Color("#a8743a"))
			ci.draw_rect(Rect2(c - Vector2(sz, sz) * 0.36, Vector2(sz, sz) * 0.72), Color("#6e4520"), false, sz * 0.05)
			ci.draw_line(c + Vector2(-sz * 0.36, -sz * 0.36), c + Vector2(sz * 0.36, sz * 0.36), Color("#6e4520"), sz * 0.05)
			ci.draw_line(c + Vector2(sz * 0.36, -sz * 0.36), c + Vector2(-sz * 0.36, sz * 0.36), Color("#6e4520"), sz * 0.05)
		"med":
			ci.draw_circle(c, sz * 0.3, Color("#6f9a6a"))
			ci.draw_rect(Rect2(c.x - sz * 0.06, c.y - sz * 0.18, sz * 0.12, sz * 0.36), CREAM)
			ci.draw_rect(Rect2(c.x - sz * 0.18, c.y - sz * 0.06, sz * 0.36, sz * 0.12), CREAM)
		"herb":
			for k in range(-1, 2):
				poly(ci, circle_pts(c + Vector2(k * sz * 0.16, -sz * 0.05 - absf(k) * -sz * 0.06), sz * 0.08, sz * 0.2), Color("#6f9a6a"))
			ci.draw_line(c + Vector2(0, sz * 0.05), c + Vector2(0, sz * 0.3), Color("#4b6b46"), sz * 0.05)
		"book":
			var cols := [Color("#7a4a8c"), Color("#3a5f8a"), Color("#a8433f")]
			for i in 3:
				ci.draw_rect(Rect2(c.x - sz * 0.3 + i * sz * 0.04, c.y + sz * 0.18 - i * sz * 0.15, sz * 0.56, sz * 0.13), cols[i])


## Row of hit-point dots.
static func draw_hp(ci: CanvasItem, pos: Vector2, n: int, max_n: int, r: float, on: Color, off: Color) -> void:
	for i in max_n:
		ci.draw_circle(pos + Vector2(i * r * 2.4, 0), r, on if i < n else off)


static func draw_label(ci: CanvasItem, text: String, pos: Vector2, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f := font()
	var w := width
	var x := pos.x
	if align != HORIZONTAL_ALIGNMENT_LEFT and width < 0.0:
		w = 600.0
		x -= w / 2.0 if align == HORIZONTAL_ALIGNMENT_CENTER else w
	ci.draw_string(f, Vector2(x, pos.y + size * 0.35), text, align, w, size, col)

class_name PlaceholderFigure
extends RefCounted
## Code-drawn stand-in for a character with no art yet: a graybox body with a head and a weapon.
## Party members differ by body colour (green, blue, purple...). Enemies are all red and differ by a glyph
## over the head and by their weapon. The anims match the sprite anims (idle, walk, attack, cast, hurt,
## down), so the board's timing and hit frames work the same as for sprites. Placeholder only: specs here
## are stand-ins until Brandon's art lands (docs/art/environments.md).

const PARTY := {
	&"lead": {"weapon": "sword", "body": Color(0.35, 0.72, 0.4)},
	&"stardrop": {"weapon": "staff", "body": Color(0.36, 0.52, 0.92)},
	&"hunter": {"weapon": "bow", "body": Color(0.6, 0.4, 0.86)},
	&"wizard": {"weapon": "staff", "body": Color(0.3, 0.76, 0.74)},
	&"lewith_flark": {"weapon": "dagger", "body": Color(0.86, 0.72, 0.3)},
	&"bushberry": {"weapon": "club", "body": Color(0.6, 0.84, 0.3)},
	&"skeleton_archer": {"weapon": "bow", "body": Color(0.55, 0.84, 0.82)},
	&"dog": {"weapon": "claws", "body": Color(0.78, 0.56, 0.32)},
}
const ENEMY := {
	&"bandit": {"weapon": "sword", "glyph": "triangle"},
	&"bandit_archer": {"weapon": "bow", "glyph": "diamond"},
	&"wolf": {"weapon": "claws", "glyph": "circle"},
	&"strange_thing": {"weapon": "staff", "glyph": "cross"},
	&"lich": {"weapon": "staff", "glyph": "square"},
}
const ENEMY_BODY := Color(0.82, 0.2, 0.2)
const ENEMY_GLYPH := Color(1.0, 0.9, 0.82)
const ANIMS := {
	"idle": {"len": 1.2, "hit": 0.0},
	"walk": {"len": 0.5, "hit": 0.0},
	"attack": {"len": 0.5, "hit": 0.22},
	"cast": {"len": 0.7, "hit": 0.35},
	"hurt": {"len": 0.35, "hit": 0.0},
	"down": {"len": 0.6, "hit": 0.0},
}


## Body colour, weapon and glyph for a character id on a team (0 party, 1 enemy).
static func spec(id: StringName, team: int) -> Dictionary:
	if team == 1:
		var e: Dictionary = ENEMY.get(id, {"weapon": "sword", "glyph": "triangle"})
		return {"body": ENEMY_BODY, "weapon": e.weapon, "glyph": e.glyph}
	var p: Dictionary = PARTY.get(id, {"weapon": "sword", "body": Color(0.4, 0.7, 0.45)})
	return {"body": p.body, "weapon": p.weapon, "glyph": ""}


static func length(anim: String) -> float:
	return float(ANIMS.get(anim, ANIMS.idle).len)


## Seconds from an anim's start to its hit frame; 0 when it has none.
static func hit_time(anim: String) -> float:
	return float(ANIMS.get(anim, ANIMS.idle).hit)


## Joint and body offsets at time t into an anim. Looping anims wrap; one-shot anims hold their last pose.
static func pose(anim: String, t: float) -> Dictionary:
	var dur := length(anim)
	var p := clampf(t / dur, 0.0, 1.0)
	var q := {"bob": 0.0, "arm": 0.3, "legs": 0.0, "lunge": 0.0, "glow": 0.0, "flash": 0.0,
		"lean": 0.0, "fall": 0.0, "knock": 0.0}
	match anim:
		"idle":
			q.bob = sin(t / dur * TAU) * 1.2
			q.arm = 0.3 + sin(t / dur * TAU) * 0.05
		"walk":
			var ph := fposmod(t, dur) / dur * TAU
			q.legs = sin(ph)
			q.bob = absf(sin(ph)) * 1.5
		"attack":
			if p < 0.3:
				q.arm = lerpf(0.3, -1.2, p / 0.3)
			elif p < 0.6:
				q.arm = lerpf(-1.2, 1.6, (p - 0.3) / 0.3)
				q.lunge = 4.0
			else:
				q.arm = lerpf(1.6, 0.3, (p - 0.6) / 0.4)
		"cast":
			q.arm = lerpf(0.3, -2.4, minf(p / 0.25, 1.0))
			q.glow = sin(p * PI)
		"hurt":
			q.flash = 1.0 - p
			q.lean = -0.25 * (1.0 - p)
			q.knock = 3.0 * (1.0 - p)
		"down":
			q.fall = p
	return q


## Draws the figure for a character id on a team. Returns how far above base the HP pips go.
static func draw(ci: CanvasItem, base: Vector2, s: float, id: StringName, team: int, anim: String, t: float,
		flip: bool, ring: Color, dim := false) -> float:
	return draw_spec(ci, base, s, spec(id, team), anim, t, flip, ring, dim)


## Same as draw, for an explicit spec ({body, weapon, glyph}); the gallery uses it for weapons no unit carries.
static func draw_spec(ci: CanvasItem, base: Vector2, s: float, sp: Dictionary, anim: String, t: float,
		flip: bool, ring: Color, dim := false) -> float:
	var q := pose(anim, t)
	var f := -1.0 if flip else 1.0
	var lean: float = q.lean * f + q.fall * PI * 0.5 * f
	var knock := Vector2((q.lunge - q.knock) * f, 0.0)
	var body: Color = sp.body.lerp(Color.WHITE, 0.6 * q.flash)
	if dim:
		body = body.darkened(0.35)
	var dark := body.darkened(0.35)
	var at := func(v: Vector2) -> Vector2:
		return base + knock + Vector2(v.x * f, v.y - q.bob).rotated(lean)

	Pawn.ellipse(ci, base + Vector2(0, 2), s * 0.6, s * 0.2, Color(0, 0, 0, 0.25))
	if ring.a > 0.0:
		Pawn.ellipse(ci, base, s * 0.62, s * 0.22, ring, false, 2.5)

	var stride: float = q.legs * 0.18 * s
	ci.draw_line(at.call(Vector2(-0.12 * s, -0.3 * s)), at.call(Vector2(-0.2 * s + stride, 0.0)), dark, 3.0)
	ci.draw_line(at.call(Vector2(0.12 * s, -0.3 * s)), at.call(Vector2(0.2 * s - stride, 0.0)), dark, 3.0)

	var pts := PackedVector2Array([at.call(Vector2(-0.42 * s, -0.05 * s)), at.call(Vector2(-0.2 * s, -0.95 * s)),
		at.call(Vector2(0.2 * s, -0.95 * s)), at.call(Vector2(0.42 * s, -0.05 * s))])
	_poly(ci, pts, body, dark)

	var head: Vector2 = at.call(Vector2(0, -1.22 * s))
	ci.draw_circle(head, s * 0.3, body.lightened(0.25))
	ci.draw_arc(head, s * 0.3, 0, TAU, 24, dark, 2.0, true)
	ci.draw_circle(at.call(Vector2(-0.1 * s, -1.22 * s)), s * 0.04, dark)
	ci.draw_circle(at.call(Vector2(0.1 * s, -1.22 * s)), s * 0.04, dark)

	var shoulder: Vector2 = at.call(Vector2(0.3 * s, -0.75 * s))
	var hand: Vector2 = at.call(Vector2(0.3 * s + sin(q.arm) * 0.5 * s, -0.75 * s + cos(q.arm) * 0.5 * s))
	var dir := (hand - shoulder).normalized()
	ci.draw_line(shoulder, hand, body, 4.0)
	_weapon(ci, String(sp.weapon), hand, dir, s, q, dark)
	ci.draw_circle(hand, s * 0.07, body.lightened(0.25))

	if String(sp.glyph) != "":
		glyph(ci, String(sp.glyph), at.call(Vector2(0, -2.0 * s)), s * 0.24)
	return 2.2 * s


static func _poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, edge: Color) -> void:
	ci.draw_colored_polygon(pts, fill)
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, edge, 2.0, true)


static func _weapon(ci: CanvasItem, kind: String, hand: Vector2, dir: Vector2, s: float, q: Dictionary,
		dark: Color) -> void:
	var steel := Color(0.84, 0.86, 0.88)
	var wood := Color(0.52, 0.38, 0.24)
	var perp := dir.orthogonal()
	match kind:
		"sword":
			ci.draw_line(hand, hand + dir * 0.95 * s, steel, 3.0)
			ci.draw_line(hand - perp * 0.16 * s, hand + perp * 0.16 * s, wood, 3.0)
		"dagger":
			ci.draw_line(hand, hand + dir * 0.5 * s, steel, 3.0)
		"staff":
			var top := hand + dir * 1.5 * s
			ci.draw_line(hand, top, wood, 3.0)
			if q.glow > 0.0:
				ci.draw_circle(top, 0.3 * s, Color(0.8, 0.95, 1.0, 0.3 * q.glow))
			ci.draw_circle(top, 0.12 * s, Color(0.8, 0.9, 1.0))
			ci.draw_arc(top, 0.12 * s, 0, TAU, 12, dark, 1.5, true)
		"bow":
			var a := dir.angle()
			ci.draw_arc(hand, 0.6 * s, a - 1.1, a + 1.1, 16, wood, 3.0, true)
			ci.draw_line(hand + Vector2.from_angle(a - 1.1) * 0.6 * s, hand + Vector2.from_angle(a + 1.1) * 0.6 * s,
				Color(0.92, 0.92, 0.86), 1.0)
		"spear":
			var tip := hand + dir * 1.6 * s
			ci.draw_line(hand, tip, wood, 2.5)
			ci.draw_colored_polygon(PackedVector2Array([tip + dir * 0.2 * s, tip + perp * 0.12 * s,
				tip - perp * 0.12 * s]), steel)
		"axe":
			var e := hand + dir * 1.0 * s
			ci.draw_line(hand, e, wood, 3.0)
			ci.draw_colored_polygon(PackedVector2Array([e + perp * 0.3 * s, e + dir * 0.15 * s,
				e - perp * 0.05 * s]), steel)
		"club":
			var e := hand + dir * 0.8 * s
			ci.draw_line(hand, e, wood, 5.0)
			ci.draw_circle(e, 0.14 * s, wood)
		"claws":
			for i: float in [-1.0, 0.0, 1.0]:
				var a: Vector2 = hand + perp * i * 0.08 * s
				ci.draw_line(a, a + dir * 0.32 * s, steel, 2.0)


## A glyph over the head tells enemies apart: triangle, diamond, circle, cross, square.
static func glyph(ci: CanvasItem, kind: String, c: Vector2, r: float) -> void:
	var edge := Color(0.3, 0.05, 0.05)
	match kind:
		"triangle":
			_poly(ci, PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, r * 0.8), c + Vector2(-r, r * 0.8)]),
				ENEMY_GLYPH, edge)
		"diamond":
			_poly(ci, PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]),
				ENEMY_GLYPH, edge)
		"square":
			_poly(ci, PackedVector2Array([c + Vector2(-r, -r), c + Vector2(r, -r), c + Vector2(r, r), c + Vector2(-r, r)]),
				ENEMY_GLYPH, edge)
		"circle":
			ci.draw_circle(c, r * 0.9, ENEMY_GLYPH)
			ci.draw_arc(c, r * 0.9, 0, TAU, 16, edge, 1.5, true)
		"cross":
			ci.draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), ENEMY_GLYPH, r * 0.6)
			ci.draw_line(c + Vector2(0, -r), c + Vector2(0, r), ENEMY_GLYPH, r * 0.6)

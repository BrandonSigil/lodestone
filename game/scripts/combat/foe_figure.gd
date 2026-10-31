class_name FoeFigure
extends RefCounted
## Code-drawn placeholder foes, until Brandon's enemy art lands. Each foe is a board-game piece: a round token
## base with a simple body on top, picked by its row in data/foe_looks.csv (body plan, size, two colours, weapon,
## head piece, one extra). Body plans: biped, skeleton, boss, quad (four legs: wolf, bear, boar, bull), blob,
## flyer, spider, crystal.
##
## Every foe reads in all four combat facings: it is drawn for the two right-hand facings, SE (three-quarter front:
## face, eyes, head nearest the camera) and NE (three-quarter back: no face, tail or back nearest the camera), and
## mirrored for SW and NW. The anims share PlaceholderFigure's timing (idle, walk, attack, cast, hurt, down), so
## hit frames land the same as for every other placeholder. Placeholder only: no story, the looks are stand-ins.

const LOOKS_PATH := "res://data/foe_looks.csv"
const LINE := Color(0.216, 0.2, 0.208)  # warm charcoal outline, never black (style bible)
const TOKEN := Color(0.43, 0.17, 0.16)  # the foe team's token base
const SKIN := Color(0.85, 0.71, 0.56)
const BONE := Color(0.9, 0.88, 0.8)
const GOLD := Color(0.88, 0.72, 0.3)
const STEEL := Color(0.78, 0.8, 0.82)
const BASE_SIZE := 26.0  # the same scale the party placeholders use

static var _looks := {}


## The look row for a foe id ({} when it has none).
static func look(id: StringName) -> Dictionary:
	if _looks.is_empty():
		for row: Dictionary in CsvTable.load_rows(LOOKS_PATH):
			var l := row.duplicate()
			l.size = float(row.get("size", "1"))
			l.color = Color(String(row.get("color", "888888")))
			l.accent = Color(String(row.get("accent", "444444")))
			_looks[StringName(row.id)] = l
	return _looks.get(id, {})


static func has_look(id: StringName) -> bool:
	return not look(id).is_empty()


static func ids() -> Array[StringName]:
	look(&"")
	var out: Array[StringName] = []
	for k: StringName in _looks:
		out.append(k)
	return out


## Draws foe id standing on base, facing the screen direction dir (y down; only its signs matter).
## Returns how far above base the HP pips go.
static func draw(ci: CanvasItem, base: Vector2, id: StringName, dir: Vector2, anim: String, t: float,
		ring: Color, dim := false) -> float:
	var l := look(id)
	if l.is_empty():
		return 48.0
	var s: float = BASE_SIZE * float(l.size)
	var fx := -1.0 if dir.x < 0.0 else 1.0
	var front := dir.y >= 0.0
	var q := PlaceholderFigure.pose(anim, t)
	var body: Color = l.color
	var accent: Color = l.accent
	var flash: float = q.flash
	if dim:
		body = body.darkened(0.35)
		accent = accent.darkened(0.35)
	body = body.lerp(Color.WHITE, 0.6 * flash)
	accent = accent.lerp(Color.WHITE, 0.4 * flash)

	var kind := String(l.body)
	if kind != "flyer":
		_token(ci, base, s, ring)
	else:
		Pawn.ellipse(ci, base + Vector2(0, 1), s * 0.4, s * 0.15, Color(0, 0, 0, 0.22))
		if ring.a > 0.0:
			Pawn.ellipse(ci, base, s * 0.5, s * 0.19, ring, false, 2.0)

	# Local space: origin on the base, +x is the side the foe faces, up is -y. Flipping x mirrors SE into SW.
	var fwd := Vector2(1.0, 0.5 if front else -0.5).normalized()
	var push: float = (q.lunge - q.knock) * float(l.size)
	var at := base + Vector2(fwd.x * push * fx, fwd.y * push)
	var rot: float = fx * (q.lean - q.fall * 1.3)
	ci.draw_set_transform(at, rot, Vector2(fx, 1.0))
	var top := 0.0
	match kind:
		"biped", "skeleton", "boss":
			top = _biped(ci, s, l, body, accent, front, q, kind)
		"quad":
			top = _quad(ci, s, l, body, accent, front, q, t)
		"blob":
			top = _blob(ci, s, l, body, accent, front, q, t)
		"flyer":
			top = _flyer(ci, s, l, body, accent, front, q, t)
		"spider":
			top = _spider(ci, s, body, accent, front, q, t)
		"crystal":
			top = _crystal(ci, s, body, accent)
		_:
			top = _blob(ci, s, l, body, accent, front, q, t)
	ci.draw_set_transform(Vector2.ZERO)
	return top + 10.0


# --- pieces ------------------------------------------------------------------------------------------------------

## The round board-game token every foe stands on: a thick disc, its rim, then the team ring.
static func _token(ci: CanvasItem, base: Vector2, s: float, ring: Color) -> void:
	var rx := minf(s * 0.62, 30.0 + s * 0.12)
	var ry := rx * 0.36
	Pawn.ellipse(ci, base + Vector2(0, 4), rx + 1.0, ry + 1.0, Color(0, 0, 0, 0.25))
	Pawn.ellipse(ci, base + Vector2(0, 3), rx, ry, TOKEN.darkened(0.4))
	Pawn.ellipse(ci, base, rx, ry, TOKEN)
	Pawn.ellipse(ci, base, rx, ry, LINE, false, 1.5)
	if ring.a > 0.0:
		Pawn.ellipse(ci, base, rx + 2.0, ry + 1.5, ring, false, 2.5)


## A filled shape with the warm outline.
static func _fill(ci: CanvasItem, pts: PackedVector2Array, fill: Color, width := 2.0) -> void:
	ci.draw_colored_polygon(pts, fill)
	var o := pts.duplicate()
	o.append(pts[0])
	ci.draw_polyline(o, LINE, width, true)


## Points of an ellipse at c, turned by rot.
static func _oval(c: Vector2, rx: float, ry: float, rot := 0.0, n := 22) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


static func _dot(ci: CanvasItem, c: Vector2, r: float, fill: Color) -> void:
	ci.draw_circle(c, r, fill)
	ci.draw_arc(c, r, 0, TAU, 18, LINE, 2.0, true)


static func _eyes(ci: CanvasItem, a: Vector2, b: Vector2, r: float, col := LINE) -> void:
	ci.draw_circle(a, r, col)
	ci.draw_circle(b, r, col)


# --- body plans --------------------------------------------------------------------------------------------------

## Two legs, a body, a head, a weapon hand. skeleton: ribs and a skull; boss: a long robe, a crown, glowing eyes.
static func _biped(ci: CanvasItem, s: float, l: Dictionary, body: Color, accent: Color, front: bool, q: Dictionary,
		kind: String) -> float:
	var bob: float = q.bob
	var up := Vector2(0, -bob)
	var dark := body.darkened(0.35)
	var hat := String(l.get("hat", ""))
	var extra := String(l.get("extra", ""))
	var weapon := String(l.get("weapon", ""))
	var robe := kind == "boss" or extra == "robe"
	var head := Vector2(0, -1.22 * s) + up
	var shoulder := Vector2(0.3 * s, -0.75 * s) + up
	var arm: float = q.arm
	var hand := shoulder + Vector2(sin(arm), cos(arm)) * 0.5 * s
	var wdir := (hand - shoulder).normalized()

	if kind == "boss":  # a faint aura behind the big baddie
		Pawn.ellipse(ci, Vector2(0, -0.9 * s) + up, s * 0.75, s * 0.95, Color(accent, 0.18 + 0.2 * float(q.glow)))
	# behind the body: the weapon when seen from the back, the shield and quiver when seen from the front
	if not front and weapon != "":
		_hand_weapon(ci, weapon, hand, wdir, s, q, dark, body, kind)
	if front and extra == "quiver":
		_fill(ci, PackedVector2Array([Vector2(-0.34 * s, -1.05 * s), Vector2(-0.18 * s, -1.12 * s),
			Vector2(-0.05 * s, -0.45 * s) + up, Vector2(-0.2 * s, -0.4 * s) + up]), accent.darkened(0.2))
	if not front and extra == "shield":
		_fill(ci, _oval(Vector2(-0.34 * s, -0.6 * s) + up, 0.24 * s, 0.3 * s), STEEL.darkened(0.15))

	# legs
	if not robe:
		var stride: float = q.legs * 0.18 * s
		var leg_col := LINE if kind != "skeleton" else BONE.darkened(0.2)
		if kind == "skeleton":
			ci.draw_line(Vector2(-0.12 * s, -0.3 * s) + up, Vector2(-0.2 * s + stride, 0.0), LINE, maxf(5.0, s * 0.17))
			ci.draw_line(Vector2(0.12 * s, -0.3 * s) + up, Vector2(0.2 * s - stride, 0.0), LINE, maxf(5.0, s * 0.17))
		ci.draw_line(Vector2(-0.12 * s, -0.3 * s) + up, Vector2(-0.2 * s + stride, 0.0), leg_col, maxf(3.0, s * 0.11))
		ci.draw_line(Vector2(0.12 * s, -0.3 * s) + up, Vector2(0.2 * s - stride, 0.0), leg_col, maxf(3.0, s * 0.11))

	# body
	if robe:
		var sway := sin(float(q.legs)) * 0.04 * s
		_fill(ci, PackedVector2Array([Vector2(-0.52 * s + sway, 0.0), Vector2(-0.24 * s, -0.98 * s) + up,
			Vector2(0.24 * s, -0.98 * s) + up, Vector2(0.52 * s + sway, 0.0)]), body)
		ci.draw_line(Vector2(0, -0.95 * s) + up, Vector2(sway, -0.05 * s), body.darkened(0.25), 2.0)
	elif kind == "skeleton":
		ci.draw_line(Vector2(0, -0.95 * s) + up, Vector2(0, -0.3 * s) + up, LINE, maxf(5.0, s * 0.18))
		ci.draw_line(Vector2(0, -0.95 * s) + up, Vector2(0, -0.3 * s) + up, BONE, maxf(3.0, s * 0.12))
		for i in 3:
			var y := (-0.85 + i * 0.16) * s
			ci.draw_line(Vector2(-0.24 * s, y) + up, Vector2(0.24 * s, y) + up, LINE, maxf(4.5, s * 0.14))
			ci.draw_line(Vector2(-0.22 * s, y) + up, Vector2(0.22 * s, y) + up, BONE, maxf(2.5, s * 0.08))
		_fill(ci, _oval(Vector2(0, -0.3 * s) + up, 0.2 * s, 0.08 * s), BONE)
	else:
		var wide := 0.42 if extra != "belly" else 0.5
		_fill(ci, PackedVector2Array([Vector2(-wide * s, -0.05 * s) + up, Vector2(-0.22 * s, -0.95 * s) + up,
			Vector2(0.22 * s, -0.95 * s) + up, Vector2(wide * s, -0.05 * s) + up]), body)
		if extra == "belly" and front:
			_fill(ci, _oval(Vector2(0.08 * s, -0.42 * s) + up, 0.26 * s, 0.24 * s), body.lightened(0.15), 1.5)

	# in front of the body: the quiver from the back, the shield from the front
	if not front and extra == "quiver":
		_fill(ci, PackedVector2Array([Vector2(-0.22 * s, -1.08 * s) + up, Vector2(-0.04 * s, -1.15 * s) + up,
			Vector2(0.06 * s, -0.4 * s) + up, Vector2(-0.12 * s, -0.36 * s) + up]), accent.darkened(0.2))
		for i in 3:
			var x := (-0.18 + i * 0.07) * s
			ci.draw_line(Vector2(x, -1.1 * s) + up, Vector2(x + 0.02 * s, -1.28 * s) + up, Color(0.9, 0.88, 0.8), 2.0)

	_head(ci, s, head, body, accent, front, hat, kind, q)

	if front and extra == "shield":
		_fill(ci, _oval(Vector2(-0.3 * s, -0.55 * s) + up, 0.24 * s, 0.3 * s), STEEL)
		_dot(ci, Vector2(-0.3 * s, -0.55 * s) + up, 0.06 * s, accent)
	if front and weapon != "":
		_hand_weapon(ci, weapon, hand, wdir, s, q, dark, body, kind)
	var crown := 0.3 if hat == "crown" or hat == "witch" else 0.0
	return (1.55 + crown) * s


static func _hand_weapon(ci: CanvasItem, weapon: String, hand: Vector2, wdir: Vector2, s: float, q: Dictionary,
		dark: Color, body: Color, kind: String) -> void:
	var shoulder := hand - wdir * 0.5 * s
	var arm_col := BONE if kind == "skeleton" else body
	ci.draw_line(shoulder, hand, LINE, maxf(6.0, s * 0.2))
	ci.draw_line(shoulder, hand, arm_col, maxf(4.0, s * 0.14))
	var d := wdir
	if weapon == "staff":  # a staff stands upright in the hand and tips with the arm
		d = Vector2(0.15, -1.0).normalized().rotated(float(q.arm) - 0.3)
		hand -= d * 0.55 * s
	PlaceholderFigure._weapon(ci, weapon, hand, d, s, q, dark)
	hand = shoulder + wdir * 0.5 * s
	ci.draw_circle(hand, s * 0.08, SKIN if kind == "biped" else arm_col.lightened(0.2))


## The head and what is on it. Front: a face turned toward +x with two eyes. Back: the back of the head, no face.
static func _head(ci: CanvasItem, s: float, head: Vector2, body: Color, accent: Color, front: bool, hat: String,
		kind: String, q: Dictionary) -> void:
	var r := 0.3 * s
	var face := head + Vector2(0.07 * s, 0.03 * s)
	var eye_a := face + Vector2(-0.03 * s, -0.02 * s)
	var eye_b := face + Vector2(0.12 * s, 0.0)
	if kind == "skeleton":
		_dot(ci, head, r, BONE)
		if front:
			_eyes(ci, eye_a, eye_b, s * 0.07, LINE)
			ci.draw_line(face + Vector2(0.0, 0.14 * s), face + Vector2(0.12 * s, 0.14 * s), LINE, 2.0)
		return
	if kind == "boss":  # a deep hood with a dark void and two glowing eyes, a crown on top
		_dot(ci, head, r * 1.15, body.darkened(0.15))
		if front:
			_fill(ci, _oval(face + Vector2(0.02 * s, 0.04 * s), r * 0.55, r * 0.6), Color(0.1, 0.08, 0.14), 1.5)
			var glow := Color(accent.lightened(0.3), 1.0)
			_eyes(ci, eye_a + Vector2(0.04 * s, 0.02 * s), eye_b + Vector2(-0.02 * s, 0.02 * s), s * 0.04, glow)
		_crown(ci, head + Vector2(0, -r * 1.0), s)
		return
	match hat:
		"hood", "cowl", "mask":
			_dot(ci, head + Vector2(-0.03 * s, -0.02 * s), r * 1.12, accent)
			if front:
				_fill(ci, _oval(face, r * 0.68, r * 0.72), SKIN, 1.5)
				if hat == "mask":
					ci.draw_line(face + Vector2(-0.18 * s, -0.03 * s), face + Vector2(0.2 * s, -0.01 * s), LINE, s * 0.12)
					_eyes(ci, eye_a, eye_b, s * 0.035, Color(0.95, 0.9, 0.8))
				else:
					_eyes(ci, eye_a, eye_b, s * 0.045)
			else:
				# the hood's peak hangs down the back
				_fill(ci, PackedVector2Array([head + Vector2(-0.2 * s, 0.1 * s), head + Vector2(0.2 * s, 0.1 * s),
					head + Vector2(0.0, 0.42 * s)]), accent.darkened(0.15), 1.5)
		"witch":
			_dot(ci, head, r, SKIN if front else accent.darkened(0.1))
			if front:
				_eyes(ci, eye_a, eye_b, s * 0.045)
			_fill(ci, _oval(head + Vector2(0, -0.2 * s), r * 1.5, r * 0.35), accent)
			_fill(ci, PackedVector2Array([head + Vector2(-0.24 * s, -0.24 * s), head + Vector2(0.24 * s, -0.24 * s),
				head + Vector2(-0.08 * s, -0.8 * s)]), accent)
		"helm":
			_dot(ci, head, r, SKIN if front else STEEL)
			ci.draw_arc(head, r, PI, TAU, 16, STEEL, r * 0.7, true)
			ci.draw_arc(head, r * 1.02, PI * 1.02, TAU * 0.99, 16, LINE, 2.0, true)
			if front:
				_eyes(ci, eye_a, eye_b, s * 0.045)
				ci.draw_line(face + Vector2(0.05 * s, -0.25 * s), face + Vector2(0.05 * s, 0.04 * s), STEEL.darkened(0.2), 3.0)
		"crown":
			_dot(ci, head, r, SKIN)
			if front:
				_eyes(ci, eye_a, eye_b, s * 0.045)
			_crown(ci, head + Vector2(0, -r * 0.9), s)
		_:  # bald (the ogre): the body's own colour, little ears
			var skin := body.lightened(0.2)
			_dot(ci, head + Vector2(-r * 0.95, 0.02 * s), r * 0.28, skin)
			_dot(ci, head, r, skin)
			if front:
				_dot(ci, head + Vector2(r * 0.95, 0.02 * s), r * 0.28, skin)
				_eyes(ci, eye_a, eye_b, s * 0.045)
				ci.draw_line(face + Vector2(-0.02 * s, 0.13 * s), face + Vector2(0.14 * s, 0.11 * s), LINE, 2.0)
			else:
				_dot(ci, head + Vector2(r * 0.95, 0.02 * s), r * 0.28, skin)


static func _crown(ci: CanvasItem, c: Vector2, s: float) -> void:
	var w := 0.24 * s
	var h := 0.18 * s
	_fill(ci, PackedVector2Array([c + Vector2(-w, 0), c + Vector2(-w, -h), c + Vector2(-w * 0.5, -h * 0.45),
		c + Vector2(0, -h * 1.2), c + Vector2(w * 0.5, -h * 0.45), c + Vector2(w, -h), c + Vector2(w, 0)]), GOLD, 1.5)


## Four legs: the body's long axis runs down-right when it faces the camera, up-right when it faces away. Front:
## the head is nearest and shows eyes and snout. Back: the head sits behind the body and the tail is nearest.
static func _quad(ci: CanvasItem, s: float, l: Dictionary, body: Color, accent: Color, front: bool, q: Dictionary,
		t: float) -> float:
	var hat := String(l.get("hat", ""))
	var extra := String(l.get("extra", ""))
	var chunky := float(l.size) >= 1.3
	var rot := 0.32 if front else -0.32
	var axis := Vector2.RIGHT.rotated(rot)
	var bob: float = q.bob * 0.6
	var c := Vector2(0, -0.5 * s - bob)
	var rx := 0.5 * s
	var ry := (0.3 if chunky else 0.24) * s
	var dark := body.darkened(0.3)
	var stride: float = q.legs * 0.14 * s
	var attack_dip := 0.08 * s if q.lunge > 0.0 else 0.0
	var head := c + axis * (0.55 * s) + Vector2(0, -0.16 * s + attack_dip)
	var hr := (0.24 if chunky else 0.2) * s
	var tail_root := c - axis * rx * 0.92
	var wag := sin(t * 5.0) * 0.08 * s

	var far_legs := func() -> void:
		for sx: float in [-0.3, 0.3]:
			var top := c + axis * (sx * s) + Vector2(0.04 * s, -0.02 * s)
			var sw := stride if sx > 0.0 else -stride
			ci.draw_line(top, Vector2(top.x + 0.04 * s - sw, -0.05 * s), dark.darkened(0.15), maxf(4.0, s * (0.15 if chunky else 0.11)))
	var near_legs := func() -> void:
		for sx: float in [-0.3, 0.3]:
			var top := c + axis * (sx * s) + Vector2(-0.05 * s, 0.05 * s)
			var sw := -stride if sx > 0.0 else stride
			ci.draw_line(top, Vector2(top.x - 0.02 * s + sw, 0.0), dark, maxf(4.0, s * (0.16 if chunky else 0.12)))
	var tail := func() -> void:
		match extra:
			"tail" when String(l.id) != "foe_bull":  # a bushy wolf tail, dipping low
				var tip := tail_root + Vector2(-0.42 * s, (0.02 if front else 0.08) * s + wag)
				_fill(ci, PackedVector2Array([tail_root + Vector2(0.04 * s, -0.1 * s), tail_root + Vector2(-0.2 * s, -0.12 * s),
					tip, tail_root + Vector2(-0.12 * s, 0.06 * s), tail_root + Vector2(0.04 * s, 0.07 * s)]), body.darkened(0.08))
				_fill(ci, PackedVector2Array([tip, tip + Vector2(0.12 * s, -0.08 * s), tip + Vector2(0.1 * s, 0.03 * s)]),
					body.lightened(0.3), 1.5)
			"tail":
				var tip := tail_root + Vector2(-0.3 * s, (-0.22 if front else -0.1) * s + wag)
				ci.draw_line(tail_root, tip, LINE, maxf(6.0, s * 0.2))
				ci.draw_line(tail_root, tip, body, maxf(4.0, s * 0.15))
				if String(l.id) != "foe_bull":
					_dot(ci, tip, s * 0.08, body.lightened(0.2))
			"mane", "":
				var tip := tail_root + Vector2(-0.34 * s, -0.12 * s + wag)
				_fill(ci, PackedVector2Array([tail_root + Vector2(0, -0.08 * s), tip, tail_root + Vector2(0.02 * s, 0.08 * s)]), body)
			_:
				_dot(ci, tail_root + Vector2(-0.04 * s, -0.04 * s), s * 0.07, body.lightened(0.1))
	var head_piece := func() -> void:
		# ears, horns or tusks first so the head overlaps their roots
		match hat:
			"ears":
				for e: float in [-0.12, 0.08]:
					var b := head + Vector2(e * s, -hr * 0.6)
					_fill(ci, PackedVector2Array([b + Vector2(-0.07 * s, 0.04 * s), b + Vector2(0.02 * s, -0.22 * s),
						b + Vector2(0.09 * s, 0.04 * s)]), body.darkened(0.1), 1.5)
			"round_ears":
				_dot(ci, head + Vector2(-0.14 * s, -hr * 0.8), s * 0.08, body)
				_dot(ci, head + Vector2(0.1 * s, -hr * 0.85), s * 0.08, body)
			"horns":
				for e: float in [-1.0, 1.0]:
					var b := head + Vector2(e * 0.12 * s, -hr * 0.6)
					var pts := PackedVector2Array([b, b + Vector2(e * 0.16 * s, -0.12 * s), b + Vector2(e * 0.2 * s, -0.3 * s)])
					ci.draw_polyline(pts, LINE, maxf(6.0, s * 0.16), true)
					ci.draw_polyline(pts, accent, maxf(4.0, s * 0.11), true)
		if extra == "mane":
			var m := PackedVector2Array()
			for i in 9:
				var a := PI * 0.55 + TAU * i / 9.0
				var rr := hr * (1.55 if i % 2 == 0 else 1.15)
				m.append(head + Vector2(-0.1 * s, 0.06 * s) + Vector2(cos(a), sin(a)) * rr)
			_fill(ci, m, accent.darkened(0.1))
		_dot(ci, head, hr, body)
		if front:
			var snout := head + Vector2(hr * 0.95, hr * 0.35)
			var long := 1.35 if hat == "ears" else 1.0  # a wolf's long muzzle
			snout += Vector2(hr * 0.25 * (long - 1.0), 0)
			_fill(ci, _oval(snout, hr * 0.62 * long, hr * 0.4, 0.2), body.lightened(0.18), 1.5)
			ci.draw_circle(snout + Vector2(hr * 0.5 * long, -hr * 0.02), s * 0.045, LINE)
			_eyes(ci, head + Vector2(hr * 0.1, -hr * 0.2), head + Vector2(hr * 0.6, -hr * 0.12), s * 0.04)
			if hat == "tusks":
				for e: float in [-0.08, 0.06]:
					var b := snout + Vector2(e * s, hr * 0.3)
					_fill(ci, PackedVector2Array([b, b + Vector2(0.06 * s, 0), b + Vector2(0.02 * s, -0.14 * s)]), accent, 1.0)
		elif hat == "tusks":
			var b := head + Vector2(hr * 0.8, hr * 0.1)
			_fill(ci, PackedVector2Array([b, b + Vector2(0.06 * s, 0), b + Vector2(0.03 * s, -0.12 * s)]), accent, 1.0)

	if front:
		tail.call()
		far_legs.call()
		_fill(ci, _oval(c, rx, ry, rot), body)
		near_legs.call()
		head_piece.call()
	else:
		head_piece.call()
		far_legs.call()
		_fill(ci, _oval(c, rx, ry, rot), body)
		# a lighter back stripe tells the back from the belly
		ci.draw_line(c - axis * rx * 0.6 + Vector2(0, -ry * 0.55), c + axis * rx * 0.5 + Vector2(0, -ry * 0.6),
			body.lightened(0.15), maxf(3.0, s * 0.08))
		near_legs.call()
		tail.call()
	return (1.0 + (0.15 if hat == "horns" else 0.0)) * s


## A soft dome. Front: two eyes on the side it faces. Back: no eyes, the shine on its back. strange_thing grows
## eye-stalks.
static func _blob(ci: CanvasItem, s: float, l: Dictionary, body: Color, accent: Color, front: bool, q: Dictionary,
		t: float) -> float:
	var squash := sin(t * 3.0) * 0.05
	if q.lunge > 0.0:
		squash = -0.15
	if q.legs != 0.0:
		squash = absf(float(q.legs)) * 0.1
	var rx := 0.56 * s * (1.0 + squash)
	var ry := 0.52 * s * (1.0 - squash)
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		var w := 1.0 + sin(a * 3.0 + t * 2.0) * 0.03
		pts.append(Vector2(cos(a) * rx * w, -0.06 * s + sin(a) * ry * w))
	pts.append(Vector2(rx * 0.92, 0.0))
	pts.append(Vector2(-rx * 0.92, 0.0))
	var hat := String(l.get("hat", ""))
	var stalks := func() -> void:
		for i in 3:
			var root := Vector2((-0.22 + i * 0.2) * s, -ry * 0.85)
			var tip := root + Vector2((0.06 + i * 0.05) * s + sin(t * 2.0 + i) * 0.04 * s, (-0.32 - 0.08 * (i % 2)) * s)
			ci.draw_line(root, tip, LINE, 5.0)
			ci.draw_line(root, tip, body, 3.0)
			_dot(ci, tip, s * 0.09, accent)
			if front:
				ci.draw_circle(tip + Vector2(0.03 * s, 0), s * 0.04, LINE)
	if hat == "stalks" and not front:
		pass
	_fill(ci, pts, body)
	if hat == "stalks":
		stalks.call()
	if front:
		ci.draw_circle(Vector2(-0.24 * s, -ry * 0.75), s * 0.07, Color(1, 1, 1, 0.45))
		if hat != "stalks":
			_eyes(ci, Vector2(0.1 * s, -ry * 0.55), Vector2(0.3 * s, -ry * 0.5), s * 0.06)
			ci.draw_arc(Vector2(0.22 * s, -ry * 0.28), 0.07 * s, 0.2, PI - 0.2, 8, LINE, 2.0, true)
		else:
			ci.draw_arc(Vector2(0.18 * s, -ry * 0.3), 0.1 * s, 0.2, PI - 0.2, 8, LINE, 2.0, true)
	else:
		ci.draw_circle(Vector2(-0.1 * s, -ry * 0.85), s * 0.09, Color(1, 1, 1, 0.4))
		ci.draw_line(Vector2(-0.3 * s, -ry * 0.4), Vector2(0.3 * s, -ry * 0.45), accent.lightened(0.1), 2.0)
	return ry + (0.5 * s if hat == "stalks" else 0.1 * s)


## A body hovering over its shadow, two flapping wings, ears. Front shows the face, back doesn't.
static func _flyer(ci: CanvasItem, s: float, l: Dictionary, body: Color, accent: Color, front: bool, q: Dictionary,
		t: float) -> float:
	var c := Vector2(0, -1.15 * s + sin(t * 4.0) * 0.08 * s - float(q.bob))
	if q.lunge > 0.0:
		c += Vector2(0.15 * s, 0.35 * s)
	var flap := sin(t * 14.0) * 0.55
	for side: float in [-1.0, 1.0]:
		var root := c + Vector2(side * 0.12 * s, 0)
		var tip := root + Vector2(side * 0.62 * s, 0).rotated(-side * flap)
		var mid := root + Vector2(side * 0.36 * s, 0.24 * s).rotated(-side * flap)
		var mid2 := root + Vector2(side * 0.16 * s, 0.2 * s)
		var wing := PackedVector2Array([root + Vector2(0, -0.12 * s), tip, mid, mid2])
		_fill(ci, wing, accent if front == (side < 0.0) else accent.lightened(0.08), 1.5)
	for e: float in [-0.1, 0.1]:
		var b := c + Vector2(e * s, -0.18 * s)
		_fill(ci, PackedVector2Array([b + Vector2(-0.06 * s, 0.04 * s), b + Vector2(e * 0.4 * s, -0.2 * s),
			b + Vector2(0.06 * s, 0.04 * s)]), body, 1.5)
	_dot(ci, c, 0.24 * s, body)
	if front:
		_eyes(ci, c + Vector2(0.0, -0.04 * s), c + Vector2(0.13 * s, -0.03 * s), s * 0.045, Color(0.96, 0.85, 0.5))
		ci.draw_line(c + Vector2(0.03 * s, 0.1 * s), c + Vector2(0.12 * s, 0.09 * s), LINE, 1.5)
	return 1.7 * s


## A round body with a smaller head toward the facing, eight bent legs. Front: a cluster of red eyes. Back: the
## big abdomen nearest, with a red mark.
static func _spider(ci: CanvasItem, s: float, body: Color, accent: Color, front: bool, q: Dictionary, t: float) -> float:
	var rot := 0.3 if front else -0.3
	var axis := Vector2.RIGHT.rotated(rot)
	var c := Vector2(0, -0.42 * s - float(q.bob) * 0.5)
	var abdomen := c - axis * 0.2 * s
	var head := c + axis * 0.32 * s + Vector2(0, 0.02 * s)
	if q.lunge > 0.0:
		head += axis * 0.08 * s
	var legs := func(near: bool) -> void:
		for i in 4:
			var along := (-0.18 + i * 0.14) * s
			var root := c + axis * along + Vector2(0, (0.04 if near else -0.06) * s)
			var swing := sin(t * 10.0 + i * 1.7) * 0.06 * s * (1.0 if q.legs != 0.0 else 0.2)
			var spread := (0.42 - absf(i - 1.5) * 0.04) * s
			var knee := root + Vector2((i - 1.5) * 0.18 * s + swing, -0.28 * s)
			var foot := Vector2(root.x + (i - 1.5) * 0.3 * s + swing, (0.02 if near else -0.08) * s) + Vector2(0, spread * 0.0)
			var col := body.darkened(0.3 if near else 0.45)
			ci.draw_polyline(PackedVector2Array([root, knee, foot]), col, maxf(2.5, s * 0.07), true)
	legs.call(false)
	if front:
		_fill(ci, _oval(abdomen, 0.36 * s, 0.3 * s, rot), body)
		_fill(ci, _oval(head, 0.2 * s, 0.17 * s, rot), body.lightened(0.1))
		for e in [Vector2(0.0, -0.06), Vector2(0.09, -0.05), Vector2(0.04, 0.01), Vector2(0.12, 0.02)]:
			ci.draw_circle(head + e * s, s * 0.035, accent)
	else:
		_fill(ci, _oval(head, 0.2 * s, 0.17 * s, rot), body.lightened(0.1))
		_fill(ci, _oval(abdomen, 0.36 * s, 0.3 * s, rot), body)
		var m := abdomen + Vector2(0, -0.06 * s)
		_fill(ci, PackedVector2Array([m + Vector2(-0.07 * s, -0.09 * s), m + Vector2(0.07 * s, -0.09 * s), m]), accent, 1.0)
		_fill(ci, PackedVector2Array([m + Vector2(-0.07 * s, 0.09 * s), m, m + Vector2(0.07 * s, 0.09 * s)]), accent, 1.0)
	legs.call(true)
	return 0.95 * s


## A tall ice shard with two small ones beside it. Faces nowhere.
static func _crystal(ci: CanvasItem, s: float, body: Color, accent: Color) -> float:
	var main := PackedVector2Array([Vector2(-0.22 * s, 0), Vector2(-0.26 * s, -0.95 * s), Vector2(0.0, -1.4 * s),
		Vector2(0.24 * s, -1.0 * s), Vector2(0.2 * s, 0)])
	_fill(ci, PackedVector2Array([Vector2(-0.42 * s, 0), Vector2(-0.4 * s, -0.45 * s), Vector2(-0.26 * s, -0.62 * s),
		Vector2(-0.18 * s, 0)]), body.darkened(0.1))
	_fill(ci, main, body)
	ci.draw_line(Vector2(0.0, -1.38 * s), Vector2(-0.02 * s, -0.05 * s), accent, 3.0)
	_fill(ci, PackedVector2Array([Vector2(0.16 * s, 0), Vector2(0.22 * s, -0.5 * s), Vector2(0.38 * s, -0.64 * s),
		Vector2(0.42 * s, 0)]), body.lightened(0.1))
	return 1.45 * s

class_name CorgiDrive
extends HuntGame
## D · Corgi Drive: you are Doggo. WASD runs him through a meadow; the birds flee from him as a loose flock. Space
## barks a cone that shoves them hard (a few barks, one comes back every few seconds). Run straight at one and it
## panics and flies off. A hedge runs down the right side with one gap; the hero waits behind it. Herd the flock
## through the gap and click (or E) as a bird crosses the gold middle to shoot it. The Hunter shoots every bird
## that passes on his own.

const DOG_SPEED := 300.0

var dog := Vector2.ZERO
var dog_face := Vector2.RIGHT
var dog_speed := 0.0
var birds: Array = []  ## {p, v, state, row, in_gap, shot_at}
var time_left := 60.0
var barks := 4
var bark_back := 0.0
var bark_fx := -1.0  ## seconds since the last bark (for its rings)
var shots: Array[Dictionary] = []  ## {from, to, t}


func start() -> void:
	mode = "drive"
	var f := field()
	dog = f.position + Vector2(60, f.size.y * 0.5)
	time_left = HuntRules.tune("drive_time", 60.0)
	barks = int(HuntRules.tune("drive_barks", 4))
	var pool := HuntRules.pool("drive")
	var centre := f.position + Vector2(f.size.x * 0.35, f.size.y * rng.randf_range(0.3, 0.7))
	var kind := HuntRules.pick(rng, pool)  # one kind a flock
	for i in 7:
		birds.append({"p": centre + Vector2(rng.randf_range(-70, 70), rng.randf_range(-60, 60)), "v": Vector2.ZERO,
			"state": "flock", "row": kind, "in_gap": false})


func _hedge_x() -> float:
	return field().end.x - 150.0


func _gap() -> Rect2:
	var f := field()
	return Rect2(Vector2(_hedge_x() - 20, f.get_center().y - 70), Vector2(60, 140))


func step(dt: float) -> void:
	var f := field()
	time_left -= dt
	bark_fx = bark_fx + dt if bark_fx >= 0.0 else -1.0
	var mv := Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	var was := dog
	if mv.length() > 0.0:
		dog_face = mv.normalized()
		dog = (dog + dog_face * DOG_SPEED * dt).clamp(f.position, Vector2(_hedge_x() - 30, f.end.y))
	dog_speed = dog.distance_to(was) / maxf(dt, 0.001)
	if barks < int(HuntRules.tune("drive_barks", 4)):
		bark_back += dt
		if bark_back >= HuntRules.tune("drive_bark_back", 6.0):
			bark_back = 0.0
			barks += 1
	HuntRules.flock_step(birds, dog, dog_speed, dt, f)
	var gap := _gap()
	for b: Dictionary in birds:
		if b.state != "flock":
			continue
		var in_gap_rows: bool = b.p.y > gap.position.y and b.p.y < gap.end.y
		if b.p.x > _hedge_x() and not in_gap_rows and b.p.x < _hedge_x() + 30:
			b.p.x = _hedge_x()
			b.v.x = -absf(b.v.x) * 0.3
		var now_in := gap.has_point(b.p)
		if now_in and not b.in_gap and mods.get("hunter", false):
			_shoot(b)
		b.in_gap = now_in
		if b.p.x > gap.end.x + 10 and b.state == "flock":
			b.state = "gone"
			toast(Txt.t("HUNT_FLEW_PAST"), 0.9)
	for s in shots:
		s.t = float(s.t) + dt
	var flock := birds.filter(func(b: Dictionary) -> bool: return b.state == "flock")
	if time_left <= 0.0 or flock.is_empty():
		_end()


func _bark() -> void:
	barks -= 1
	bark_fx = 0.0
	if HuntRules.bark(birds, dog, dog_face) == 0:
		toast(Txt.t("HUNT_BARK_MISS"), 0.6)


func _shoot(b: Dictionary) -> void:
	var hero := Vector2(field().end.x - 60, _gap().get_center().y)
	var hit := HuntRules.gap_shot(b.p, _gap(), mods)
	shots.append({"from": hero, "to": b.p + (Vector2.ZERO if hit else Vector2(0, -30)), "t": 0.0})
	if hit:
		b.state = "shot"
		caught.append(b.row)
		toast(Txt.t("HUNT_HIT") % Txt.t(String(b.row.name_key)), 0.9)
	else:
		toast(Txt.t("HUNT_MISS"), 0.8)


func _try_shot() -> void:
	var best: Dictionary = {}
	for b: Dictionary in birds:
		if b.state == "flock" and _gap().has_point(b.p):
			if best.is_empty() or absf(b.p.y - _gap().get_center().y) < absf(best.p.y - _gap().get_center().y):
				best = b
	if not best.is_empty():
		_shoot(best)


func play_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_shot()


func _unhandled_key_input(event: InputEvent) -> void:
	if not over and event.pressed and not event.is_echo():
		var k := (event as InputEventKey).keycode
		if k == KEY_SPACE and barks > 0:
			_bark()
			get_viewport().set_input_as_handled()
			return
		if k == KEY_E:
			_try_shot()
			get_viewport().set_input_as_handled()
			return
	super(event)


func paint() -> void:
	var f := field()
	var p := Riso.palette_at(0.0)
	draw_rect(Rect2(Vector2.ZERO, size), p.sky_top)
	draw_rect(f, MEADOW)
	var tufts := Riso.rng(17)
	for i in 70:
		var tp := f.position + Vector2(tufts.randf() * (f.size.x - 180), tufts.randf() * f.size.y)
		for k in 3:
			draw_line(tp + Vector2(k * 4 - 4, 0), tp + Vector2(k * 5 - 5, -9), LEAF, 2.0, true)
	# hedge with its gap, the hero behind it
	var gap := _gap()
	var hx := _hedge_x()
	var y := f.position.y
	while y < f.end.y:
		if y + 30 < gap.position.y or y > gap.end.y:
			draw_bush(Vector2(hx + 14, y + 16), 22, PINE)
		y += 30
	draw_rect(gap, Riso.alpha(AMBER, 0.22))
	draw_rect(Rect2(gap.position + Vector2(0, gap.size.y * 0.2), Vector2(gap.size.x, gap.size.y * 0.6)), Riso.alpha(AMBER, 0.25))
	draw_tree(Vector2(hx + 14, gap.position.y), 90)
	draw_tree(Vector2(hx + 14, gap.end.y + 20), 90)
	draw_hero(Vector2(f.end.x - 60, gap.get_center().y + 24), 56.0)
	for s in shots:
		if float(s.t) < 0.25:
			draw_line(s.from, (s.from as Vector2).lerp(s.to, clampf(float(s.t) / 0.12, 0.0, 1.0)), BARK_BROWN, 3.0, true)
	for b: Dictionary in birds:
		if b.state == "flock" or (b.state == "gone" and field().grow(60).has_point(b.p)):
			if b.state == "gone":
				b.p += b.v * get_process_delta_time()
			draw_animal(String(b.row.id), b.p, b.v if (b.v as Vector2).length() > 1.0 else Vector2.LEFT, 0.85, "run" if (b.v as Vector2).length() > 30.0 else "stand")
	draw_dog(dog, dog_face, 1.0)
	if bark_fx >= 0.0 and bark_fx < 0.5:
		for i in 3:
			var rr := 40.0 + i * 40.0 + bark_fx * 120.0
			draw_arc(dog, rr, dog_face.angle() - 0.6, dog_face.angle() + 0.6, 12, Riso.alpha(RED, 1.0 - bark_fx * 2.0), 3.0, true)
	hud_strip()
	var x := pips(Vector2(30, hud_y()), int(HuntRules.tune("drive_barks", 4)), barks, AMBER, Txt.t("HUNT_BARKS"))
	text(Txt.t("HUNT_TIME") % ceili(maxf(time_left, 0.0)), Vector2(x + 30, hud_y() + 6), 16, CREAM)
	var keys := Txt.t("HUNT_KEYS_DRIVE")
	text(keys, Vector2(size.x - 24 - Riso.font().get_string_size(keys, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, hud_y() + 6), 15, Color("#cbbfd9"))

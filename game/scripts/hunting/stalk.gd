class_name Stalk
extends HuntGame
## B · Stalk: a top-down meadow. WASD creeps the hero along the hoof prints toward a grazing deer. Move while its head
## is down; when the tail flicks it's about to look up, so freeze. While it looks, its sight cone shows: moving in it
## fills its alert, and tall grass hides you. The wind carries your scent from you toward it. A snapped twig is a
## nerve check. Inside the gold ring, hold the left button to draw and let go to loose: one deer, one shot.
## Hunter: an earlier warning (ear twitch) and a wider shot ring. Doggo: SNIFF shows the deer and the old tracks.

const CREEP := 125.0  ## pixels a second, crouched
const SIGHT := 380.0  ## how far the deer sees

var hero := Vector2.ZERO
var deer := Vector2.ZERO
var facing := Vector2.LEFT
var phase := "down"
var phase_t := 2.0
var alert := 0.0
var wind := Vector2.RIGHT
var grass: Array[Rect2] = []
var tracks: Array[Vector2] = []
var twigs: Array[Vector2] = []
var drawing := false
var draw_t := 0.0
var aim := Vector2.ZERO
var bolting := false
var shot := false
var arrow := {}
var _moving := false
var _smelled := false
var _wounded := false
var _fetch_t := -1.0


func start() -> void:
	mode = "stalk"
	var f := field()
	hero = f.position + Vector2(f.size.x * 0.1, f.size.y * 0.85)
	deer = f.position + Vector2(f.size.x * rng.randf_range(0.68, 0.85), f.size.y * rng.randf_range(0.2, 0.4))
	facing = Vector2.from_angle(rng.randf_range(0, TAU))
	wind = Vector2.from_angle(rng.randf_range(0, TAU))
	for i in 7:
		var c := f.position + Vector2(f.size.x * rng.randf_range(0.15, 0.85), f.size.y * rng.randf_range(0.15, 0.9))
		grass.append(Rect2(c, Vector2(rng.randf_range(110, 200), rng.randf_range(60, 110))))
	var a := hero + Vector2(60, -20)
	for i in 22:
		var u := i / 21.0
		tracks.append(a.lerp(deer + Vector2(-50, 20), u) + Vector2(sin(u * 9.0) * 30.0, cos(u * 7.0) * 18.0))
	for i in 7:
		twigs.append(tracks[rng.randi_range(3, 18)] + Vector2(rng.randf_range(-40, 40), rng.randf_range(-30, 30)))
	phase_t = HuntRules.head_time(rng, "down", mods)
	aim = deer


func _in_cover(p: Vector2) -> bool:
	for g in grass:
		if g.has_point(p):
			return true
	return false


func step(dt: float) -> void:
	aim = mouse()
	if _fetch_t >= 0.0:
		_fetch_t -= dt
		if _fetch_t < 0.0:
			caught.append(Db.hunt_animals.deer)
			toast(Txt.t("HUNT_FETCHED") % Txt.t("HUNT_DEER"))
			_end()
		return
	if bolting:
		deer += (deer - hero).normalized() * 380.0 * dt
		if not field().grow(80).has_point(deer):
			if _wounded and mods.get("doggo", false):
				_fetch_t = 1.2
				toast(Txt.t("HUNT_DOG_RUNS"), 1.1)
			else:
				_end()
		return
	if not arrow.is_empty():
		_step_arrow(dt)
		return
	# the hero creeps
	var mv := Vector2(float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	_moving = mv.length() > 0.0 and not drawing
	if _moving:
		var was := hero
		hero = (hero + mv.normalized() * CREEP * dt).clamp(field().position + Vector2(10, 10), field().end - Vector2(10, 10))
		for i in range(twigs.size() - 1, -1, -1):
			if twigs[i].distance_to(hero) < 14.0 and twigs[i].distance_to(was) >= 14.0:
				twigs.remove_at(i)
				var r := Dice.check(rng, int(mods.get("bonus", 0)) / 2, 11)
				if r.success:
					toast(Txt.t("HUNT_TWIG_OK") % Dice.describe(r), 1.4)
				else:
					toast(Txt.t("HUNT_TWIG_BAD") % Dice.describe(r), 1.6)
					phase = "up"
					phase_t = HuntRules.head_time(rng, "up", mods)
					facing = (hero - deer).normalized()
					alert = minf(1.0, alert + 0.3)
	if drawing:
		draw_t += dt
	# the deer's head
	phase_t -= dt
	if phase_t <= 0.0:
		match phase:
			"down":
				phase = "tell"
			"tell":
				phase = "up"
				facing = (hero - deer).normalized().rotated(rng.randf_range(-0.9, 0.9)) if rng.randf() < 0.45 else Vector2.from_angle(rng.randf_range(0, TAU))
			_:
				phase = "down"
		phase_t = HuntRules.head_time(rng, phase, mods)
	var seen := phase == "up" and HuntRules.in_cone(deer, facing, hero, 60.0, SIGHT)
	var visible_move := _moving or (drawing and draw_t < 0.3)
	if phase == "up":
		alert += HuntRules.alert_rate(seen, visible_move, _in_cover(hero)) * dt
	else:
		alert = maxf(0.0, alert - 0.12 * dt)
	if HuntRules.smells(hero, deer, wind):
		alert += 0.45 * dt
		if not _smelled:
			_smelled = true
			toast(Txt.t("HUNT_SCENT"), 1.4)
	if alert >= HuntRules.tune("stalk_alert_full", 1.0):
		toast(Txt.t("HUNT_BOLTED"), 1.4)
		bolting = true


func _step_arrow(dt: float) -> void:
	var from: Vector2 = arrow.p
	var d: Vector2 = arrow.v * dt
	if d.length() > float(arrow.left):
		d = d.normalized() * float(arrow.left)
	arrow.p = from + d
	arrow.left = float(arrow.left) - d.length()
	var near := Geometry2D.get_closest_point_to_segment(deer, from, arrow.p)
	var grade := HuntRules.hit_grade(near.distance_to(deer), 26.0)
	if grade == "clean":
		caught.append(Db.hunt_animals.deer)
		toast(Txt.t("HUNT_HIT") % Txt.t("HUNT_DEER"))
		arrow = {}
		_end()
	elif grade == "graze":
		toast(Txt.t("HUNT_GRAZE"), 1.0)
		arrow = {}
		_wounded = true
		bolting = true
	elif float(arrow.left) <= 0.5:
		toast(Txt.t("HUNT_MISS"), 1.2)
		arrow = {}
		bolting = true


func play_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) or shot or bolting:
		return
	var in_ring := hero.distance_to(deer) <= HuntRules.shot_ring(mods)
	if event.pressed and in_ring:
		drawing = true
		draw_t = 0.0
	elif not event.pressed and drawing:
		drawing = false
		var st := HuntRules.draw_state(draw_t, mods)
		if float(st.power) < 0.15:
			return
		shot = true
		var target := aim + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * float(st.shake)
		var dist := hero.distance_to(target) * HuntRules.arrow_reach(float(st.power))
		arrow = {"p": hero, "v": (target - hero).normalized() * HuntRules.arrow_speed(float(st.power)), "left": dist}


func paint() -> void:
	var f := field()
	draw_rect(Rect2(Vector2.ZERO, size), MEADOW.darkened(0.05))
	draw_rect(f, MEADOW)
	for g in grass:
		draw_rect(g, Riso.alpha(LEAF, 0.75))
		var cols := int(g.size.x / 14.0)
		for i in cols:
			for j in 2:
				var x := g.position.x + 8 + i * 14
				var y := g.position.y + 14 + j * (g.size.y * 0.5)
				draw_line(Vector2(x, y + 14), Vector2(x + sin(t * 2.0 + i) * 2.0, y), PINE, 2.0, true)
	var dog_sniff: bool = mods.get("doggo", false)
	for i in tracks.size():
		var a := 0.55 if dog_sniff else (0.35 if i > tracks.size() * 0.4 else 0.12)
		var tp := tracks[i]
		draw_circle(tp, 3.0, Riso.alpha(BARK_BROWN, a))
		draw_circle(tp + Vector2(6, 2), 3.0, Riso.alpha(BARK_BROWN, a))
	for tw in twigs:
		draw_line(tw - Vector2(9, 3), tw + Vector2(9, 3), BARK_BROWN.darkened(0.2), 2.5, true)
	for i in 3:
		draw_tree(f.position + Vector2(f.size.x * (0.05 + i * 0.44), f.size.y * 0.12 + i * 30), 90)
	var deer_shown := dog_sniff or hero.distance_to(deer) < 330.0 or bolting
	if deer_shown:
		if phase == "up" and not bolting:
			var pts := PackedVector2Array([deer])
			for k in 13:
				pts.append(deer + facing.rotated(deg_to_rad(-60.0 + k * 10.0)) * SIGHT)
			draw_colored_polygon(pts, Riso.alpha(RED, 0.13))
		var ring := HuntRules.shot_ring(mods)
		draw_arc(deer, ring, 0, TAU, 64, Riso.alpha(AMBER, 0.85 if hero.distance_to(deer) <= ring else 0.4), 2.5, true)
		var pose := "run" if bolting else ("graze" if phase == "down" else "look")
		draw_animal("deer", deer, facing if phase == "up" or bolting else Vector2(-1 if hero.x < deer.x else 1, 0), 1.6, pose)
		if phase == "tell" and not bolting:
			text(Txt.t("HUNT_TELL_HUNTER") if mods.get("hunter", false) else Txt.t("HUNT_TELL"), deer + Vector2(0, -60), 16, RED, true)
	else:
		text("?", deer + Vector2(0, 8), 30, Riso.alpha(INK, 0.35), true)
	draw_hero(hero + Vector2(0, 18), 64.0, true)
	if not arrow.is_empty():
		var dv: Vector2 = (arrow.v as Vector2).normalized()
		draw_line(arrow.p - dv * 24.0, arrow.p, BARK_BROWN, 3.0, true)
	if hero.distance_to(deer) <= HuntRules.shot_ring(mods) and not bolting and not shot:
		var st := HuntRules.draw_state(draw_t, mods) if drawing else {"power": 0.0, "shake": 0.0, "sweet": false}
		draw_reticle(aim + Vector2(sin(t * 31.0), cos(t * 27.0)) * float(st.shake) * 0.6, st, drawing)
	hud_strip()
	# alert bar, wind
	text(Txt.t("HUNT_ALERT"), Vector2(30, hud_y() + 6), 16, CREAM)
	var bar := Rect2(Vector2(100, hud_y() - 8), Vector2(220, 16))
	draw_rect(bar, Riso.alpha(CREAM, 0.2))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(alert, 0.0, 1.0), bar.size.y)), RED)
	var wc := Vector2(400, hud_y())
	text(Txt.t("HUNT_WIND"), wc + Vector2(-42, 6), 16, CREAM)
	draw_line(wc + Vector2(20, 0) - wind * 18.0, wc + Vector2(20, 0) + wind * 18.0, CREAM, 3.0, true)
	draw_line(wc + Vector2(20, 0) + wind * 18.0, wc + Vector2(20, 0) + wind * 18.0 - wind.rotated(0.5) * 10.0, CREAM, 3.0, true)
	draw_line(wc + Vector2(20, 0) + wind * 18.0, wc + Vector2(20, 0) + wind * 18.0 - wind.rotated(-0.5) * 10.0, CREAM, 3.0, true)
	var keys := Txt.t("HUNT_KEYS_STALK")
	text(keys, Vector2(size.x - 24 - Riso.font().get_string_size(keys, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, hud_y() + 6), 15, Color("#cbbfd9"))

class_name BowBlind
extends HuntGame
## A · Bow Blind (Brandon's idea, 2026-11-17): a forest glade seen from behind a log. Animals break from one bush and
## run for another; the mouse is the aim. Hold the left button to draw (the ring tightens, gold at a full draw, then
## the aim starts to shake), let go to loose. Arrows fly, so lead the runners. A fast-moving aim makes noise: animals
## bolt and stop pausing. Doggo: the next bush rustles first (SNIFF), F sends him in to break it now (FLUSH), and he
## runs down a wounded animal (FETCH). The glade's size comes from the party's hunt roll.

var bushes: Array[Dictionary] = []  ## {c, r}
var trees: Array[Vector2] = []
var left := 0  ## animals still hiding in the glade
var arrows := 0
var noise := 0.0
var runner := {}  ## the animal out in the open (see _spawn), or {}
var flights: Array[Dictionary] = []  ## arrows in the air: {p, v, left (pixels to go)}
var stuck: Array[Dictionary] = []  ## arrows in the ground: {p, a}
var next_in := 2.0  ## seconds until the next animal breaks
var next_bush := -1  ## the bush it will break from (Doggo sniffs it)
var flush_cool := 0.0
var drawing := false
var draw_t := 0.0
var aim := Vector2.ZERO
var _last_aim := Vector2.ZERO
var _fetch_t := -1.0  ## Doggo is running down a wounded animal: seconds until he's back
var _fetch_row := {}
var _roll := {}


func start() -> void:
	mode = "bow"
	var f := field()
	var spots := [Vector2(0.12, 0.42), Vector2(0.33, 0.30), Vector2(0.52, 0.48), Vector2(0.72, 0.32), Vector2(0.9, 0.46), Vector2(0.24, 0.62), Vector2(0.8, 0.64)]
	for s: Vector2 in spots:
		bushes.append({"c": f.position + f.size * s + Vector2(rng.randf_range(-20, 20), rng.randf_range(-12, 12)), "r": rng.randf_range(30, 40)})
	for i in 9:
		trees.append(Vector2(f.position.x + f.size.x * (i + 0.5) / 9.0 + rng.randf_range(-30, 30), f.position.y + f.size.y * rng.randf_range(0.2, 0.3)))
	_roll = Dice.check(rng, int(mods.get("bonus", 0)), int(HuntRules.tune("hunt_dc", 12)))
	left = HuntRules.glade_size(_roll)
	arrows = int(HuntRules.tune("hunt_arrows", 5))
	toast(Txt.t("HUNT_ROLL") % [Dice.describe(_roll), left], 2.6)
	_pick_next()
	aim = f.get_center()
	_last_aim = aim


func _hero_base() -> Vector2:
	var f := field()
	return Vector2(f.get_center().x, f.end.y - 6)


func _pick_next() -> void:
	next_bush = rng.randi_range(0, bushes.size() - 1)
	next_in = rng.randf_range(1.6, 3.4)


func step(dt: float) -> void:
	aim = mouse()
	var speed := aim.distance_to(_last_aim) / maxf(dt, 0.001)
	_last_aim = aim
	noise = HuntRules.noise_step(noise, speed, dt)
	flush_cool = maxf(0.0, flush_cool - dt)
	if drawing:
		draw_t += dt
	if mods.get("doggo", false) and Input.is_key_pressed(KEY_F) and flush_cool <= 0.0 and runner.is_empty() and left > 0:
		var best := 0
		for i in bushes.size():
			if bushes[i].c.distance_to(aim) < bushes[best].c.distance_to(aim):
				best = i
		next_bush = best
		next_in = 0.35
		flush_cool = HuntRules.tune("hunt_flush_cool", 6.0)
		toast(Txt.t("HUNT_FLUSH"), 0.9)
	if runner.is_empty() and left > 0:
		next_in -= dt
		if next_in <= 0.0:
			_spawn()
	_step_runner(dt)
	_step_arrows(dt)
	if _fetch_t >= 0.0:
		_fetch_t -= dt
		if _fetch_t < 0.0:
			caught.append(_fetch_row)
			toast(Txt.t("HUNT_FETCHED") % Txt.t(String(_fetch_row.name_key)))
	var nothing_left: bool = left <= 0 and runner.is_empty()
	var no_arrows: bool = arrows <= 0 and flights.is_empty() and (runner.is_empty() or runner.state != "wounded")
	if (nothing_left or no_arrows) and _fetch_t < 0.0 and flights.is_empty():
		_end()


func _spawn() -> void:
	var row := HuntRules.pick(rng, HuntRules.pool("bow"))
	var a: Dictionary = bushes[next_bush]
	var to := next_bush
	while to == next_bush:
		to = rng.randi_range(0, bushes.size() - 1)
	var b: Dictionary = bushes[to]
	var lift := rng.randf_range(60, 140)
	var ctrl: Vector2 = (a.c + b.c) * 0.5 + Vector2(0, -lift if rng.randf() < 0.6 else lift * 0.6)
	var length: float = a.c.distance_to(b.c) * 1.15
	left -= 1
	runner = {
		"row": row, "from": a.c, "to": b.c, "ctrl": ctrl, "u": 0.0, "len": length, "state": "run",
		"pause_at": rng.randf_range(0.4, 0.62) if rng.randf() < HuntRules.pause_chance(row, noise) else 9.0,
		"pause_t": rng.randf_range(float(row.pause_min), float(row.pause_max)), "spooked": false,
		"p": a.c, "face": (b.c - a.c).normalized(), "scale": 0.5 + float(row.size) * 0.9,
	}
	_pick_next()


func _bez(r: Dictionary, u: float) -> Vector2:
	var p0: Vector2 = r.from
	var p1: Vector2 = r.ctrl
	var p2: Vector2 = r.to
	return p0.lerp(p1, u).lerp(p1.lerp(p2, u), u)


func _step_runner(dt: float) -> void:
	if runner.is_empty():
		return
	var row: Dictionary = runner.row
	match String(runner.state):
		"pause":
			runner.pause_t -= dt
			if runner.pause_t <= 0.0 or noise > 0.6:
				runner.state = "run"
				runner.pause_at = 9.0
		"wounded":
			runner.p += runner.face * 420.0 * dt
			if not field().grow(60).has_point(runner.p):
				if mods.get("doggo", false):
					_fetch_row = row
					_fetch_t = 1.2
					toast(Txt.t("HUNT_DOG_RUNS"), 1.1)
				else:
					toast(Txt.t("HUNT_GOT_AWAY"))
				runner = {}
		_:
			var sp := HuntRules.run_speed(row, noise) * (1.5 if runner.spooked else 1.0)
			var was: Vector2 = runner.p
			runner.u = minf(1.0, float(runner.u) + sp * dt / float(runner.len))
			runner.p = _bez(runner, runner.u)
			if (runner.p - was).length() > 0.01:
				runner.face = (runner.p - was).normalized()
			if runner.u >= runner.pause_at and not runner.spooked:
				runner.state = "pause"
			if runner.u >= 1.0:
				if not runner.spooked:
					left += 1  # back in cover, still in the glade
				runner = {}


func _step_arrows(dt: float) -> void:
	for i in range(flights.size() - 1, -1, -1):
		var a: Dictionary = flights[i]
		var from: Vector2 = a.p
		var d: Vector2 = a.v * dt
		if d.length() > float(a.left):
			d = d.normalized() * float(a.left)
		a.p = from + d
		a.left = float(a.left) - d.length()
		if not runner.is_empty() and runner.state != "wounded":
			var r := 18.0 * float(runner.scale)
			var near := Geometry2D.get_closest_point_to_segment(runner.p, from, a.p)
			var grade := HuntRules.hit_grade(near.distance_to(runner.p), r)
			if grade == "clean":
				caught.append(runner.row)
				toast(Txt.t("HUNT_HIT") % Txt.t(String(runner.row.name_key)))
				runner = {}
				flights.remove_at(i)
				continue
			elif grade == "graze":
				runner.state = "wounded"
				runner.face = (runner.p - _hero_base()).normalized()
				toast(Txt.t("HUNT_GRAZE"), 1.0)
				flights.remove_at(i)
				continue
		if float(a.left) <= 0.5:
			stuck.append({"p": a.p, "a": (a.v as Vector2).angle()})
			if not runner.is_empty() and runner.p.distance_to(a.p) < 90.0 and runner.state != "wounded":
				runner.spooked = true
				runner.state = "run"
				runner.pause_at = 9.0
			flights.remove_at(i)


func play_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and arrows > 0:
			drawing = true
			draw_t = 0.0
		elif not event.pressed and drawing:
			drawing = false
			_loose()


func _loose() -> void:
	var st := HuntRules.draw_state(draw_t, mods)
	if float(st.power) < 0.15:
		return
	arrows -= 1
	var start_p := _hero_base() + Vector2(0, -50)
	var wobble := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * float(st.shake)
	var target := aim + wobble
	var dist := start_p.distance_to(target) * HuntRules.arrow_reach(float(st.power))
	flights.append({"p": start_p, "v": (target - start_p).normalized() * HuntRules.arrow_speed(float(st.power)), "left": dist})
	noise = minf(1.0, noise + 0.12)


func paint() -> void:
	var f := field()
	var p := Riso.palette_at(0.0)
	Riso.draw_sky(self, Rect2(Vector2.ZERO, Vector2(size.x, f.position.y + f.size.y * 0.32)), p.sky_top, p.horizon)
	for i in 5:
		Riso.draw_gumdrop(self, f.position.x + f.size.x * (i + 0.3) / 5.0, f.position.y + f.size.y * 0.3, f.size.x * 0.3, f.size.y * 0.16, p.far, p.light)
	draw_rect(Rect2(0, f.position.y + f.size.y * 0.28, size.x, size.y), MEADOW)
	for tr in trees:
		draw_tree(tr, 120.0)
	for s in stuck:
		var d := Vector2.from_angle(float(s.a))
		draw_line(s.p - d * 22.0, s.p, BARK_BROWN, 2.5, true)
	var order := bushes.duplicate()
	order.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.c.y < y.c.y)
	if not runner.is_empty() and runner.p.y < f.position.y + f.size.y * 0.5:
		_paint_runner()
	for b: Dictionary in order:
		draw_bush(b.c, b.r, LEAF, 2.5 if bushes.find(b) == next_bush and runner.is_empty() and next_in < (1.4 if mods.get("doggo", false) else 0.5) else 0.0)
	if not runner.is_empty() and runner.p.y >= f.position.y + f.size.y * 0.5:
		_paint_runner()
	if mods.get("doggo", false) and runner.is_empty() and left > 0 and next_in < 1.4:  # SNIFF: Doggo points at it
		var nb: Dictionary = bushes[next_bush]
		draw_circle(nb.c + Vector2(0, -nb.r - 22), 13, Riso.alpha(INK, 0.75))
		text("!", nb.c + Vector2(0, -nb.r - 14), 20, AMBER, true)
	for a in flights:
		var d: Vector2 = (a.v as Vector2).normalized()
		draw_line(a.p - d * 26.0, a.p, BARK_BROWN, 3.0, true)
		draw_line(a.p - d * 26.0, a.p - d * 20.0, CREAM, 5.0, true)
	# the blind: a log, the hero and maybe Doggo behind it
	var hb := _hero_base()
	draw_hero(hb + Vector2(0, -2), 100.0, true)
	if mods.get("doggo", false) and _fetch_t < 0.0:
		draw_dog(hb + Vector2(-95, -22), Vector2.RIGHT, 1.2)
	draw_rect(Rect2(hb + Vector2(-150, -24), Vector2(300, 30)), BARK_BROWN)
	draw_circle(hb + Vector2(150, -9), 15, BARK_BROWN.lightened(0.15))
	draw_circle(hb + Vector2(150, -9), 7, BARK_BROWN.darkened(0.15))
	var st := HuntRules.draw_state(draw_t, mods) if drawing else {"power": 0.0, "shake": 0.0, "sweet": false}
	var shake := Vector2(sin(t * 31.0), cos(t * 27.0)) * float(st.shake) * 0.6
	draw_reticle(aim + shake, st, drawing)
	hud_strip()
	var x := pips(Vector2(30, hud_y()), 3, ceili(noise * 3.0 - 0.05), RED, Txt.t("HUNT_NOISE"))
	x = pips(Vector2(x + 30, hud_y()), int(HuntRules.tune("hunt_arrows", 5)), arrows, CREAM, Txt.t("HUNT_ARROWS"))
	x = pips(Vector2(x + 30, hud_y()), maxi(left, 0), left, AMBER, Txt.t("HUNT_LEFT"))
	text(Txt.t("HUNT_KEYS_BOW") + ("" if not mods.get("doggo", false) else Txt.t("HUNT_KEYS_FLUSH")), Vector2(size.x - 24 - Riso.font().get_string_size(Txt.t("HUNT_KEYS_BOW") + ("" if not mods.get("doggo", false) else Txt.t("HUNT_KEYS_FLUSH")), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, hud_y() + 6), 15, Color("#cbbfd9"))


func _paint_runner() -> void:
	var pose := "run"
	if runner.state == "pause":
		pose = "look"
	draw_animal(String(runner.row.id), runner.p, runner.face, float(runner.scale), pose)
	if runner.state == "wounded":
		draw_circle(runner.p + Vector2(0, 16), 3.0, RED)

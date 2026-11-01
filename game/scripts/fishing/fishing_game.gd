class_name FishingGame
extends Control
## The fishing minigame on screen ([USER] 2026-11-01): Look, Strike, Reel (rules in FishingRules).
## Opened over any scene with FishingGame.open(); it takes every input while up and emits `finished` once,
## then frees itself. Graybox: the pool, shadows, rod and bar are flat shapes drawn in code.
## Controls: mouse or touch, arrows / A D, or a controller (stick, d-pad, A to act, B to leave). At Look the mouse, the
## arrows or the stick aim the cast; at Reel left and right pull the marker and let go springs it back to the centre.

signal finished(result: Dictionary)  ## {"outcome": one of FishingRules.OUTCOMES, "fish": the fish row or {}}

enum S { LOOK, CAST, STRIKE, REEL, RESULT, WAIT, COME }  ## WAIT: the bobber sits, nothing noticed it yet. COME: a fish noticed and swims over

const CAST_TIME := 0.45  ## seconds the bobber flies
const WATER := Color("#4a7fb5")
const DEEP := Color("#3c6aa0")
const GRASS := Color("#7f8c5c")
const GRASS_DARK := Color("#5f6c42")
const PAD := Color("#6f9a4e")
const SHADOW := Color(0.11, 0.13, 0.24, 0.5)
const ROD := Color("#6b4a2b")

var spot := "lake"
var mods := {}
var state := S.LOOK
var result := {}

var _rng := RandomNumberGenerator.new()
var _shadows: Array[Dictionary] = []
var _t := 0.0  ## seconds since the minigame opened (shadows drift on it)
var _phase_t := 0.0  ## seconds since the current beat began
var _aim := Vector2(0.5, 0.5)  ## pool coords the cast is aimed at (Look)
var _hook := -1  ## the shadow that noticed the bobber
var _cast_at := Vector2.ZERO  ## pool coords of the bobber
var _pond: Array = []  ## the fish ids left in this pond; shadows are built from it and a fish gone for good comes out
var _pond_in: Variant = null  ## the caller's pond (Game.pond), or null for a fresh one
var _come_from := Vector2.ZERO  ## where the fish that noticed the bobber was when it turned
var _check_t := 0.0  ## seconds since the idle bobber last gave the shadows a chance to notice it
var _plan := {}
var _reel := {}
var _mouse := Vector2.ZERO
var _use_mouse := true
var _splash: Array[Dictionary] = []
var _new_kind := false
var _blob: PackedVector2Array = []  ## the pool's outline, pool coords
var _pads: Array[Vector3] = []  ## lily pads: x, y (pool coords), radius (pool widths)
var _done := false


## Open the minigame over `parent` on its own canvas layer. spot picks the fish pool (data/fish.csv spots). `pond` is the
## list of fish ids left in it (Game.pond; this takes fish out of it): null gives a fresh pond that is not kept.
static func open(parent: Node, spot_id := "lake", party_mods := {}, seed_value := 0, pond: Variant = null) -> FishingGame:
	var layer := CanvasLayer.new()
	layer.layer = 20
	parent.add_child(layer)
	var g := FishingGame.new()
	g.spot = spot_id
	g.mods = party_mods
	g._pond_in = pond
	if seed_value != 0:
		g._rng.seed = seed_value
	else:
		g._rng.randomize()
	layer.add_child(g)
	return g


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _pond_in is Array:
		_pond = _pond_in
	else:
		_pond = FishingRules.new_pond(_rng, FishingRules.pool(Db.fish, spot), int(FishingRules.tune("fish_pond_size", 3)))
	var rows: Array[Dictionary] = []
	for id in _pond:
		if Db.fish.has(String(id)):
			rows.append(Db.fish[String(id)])
	_shadows = FishingRules.shadows_of(_rng, rows)
	var r := Riso.rng(int(_rng.seed % 100000))
	for i in 28:
		var a := TAU * i / 28.0
		var k := 0.47 + r.randf_range(-0.035, 0.02)
		_blob.append(Vector2(0.5 + cos(a) * k, 0.5 + sin(a) * k * 0.98))
	for i in 3:
		_pads.append(Vector3(r.randf_range(0.15, 0.85), r.randf_range(0.2, 0.75), r.randf_range(0.03, 0.045)))
	_mouse = get_viewport_rect().size * 0.5
	resized.connect(queue_redraw)


# --- layout -----------------------------------------------------------------------------------------

func _panel() -> Rect2:
	var w := minf(size.x - 32.0, 980.0)
	var h := minf(size.y - 32.0, 660.0)
	return Rect2((size - Vector2(w, h)) * 0.5, Vector2(w, h))


func _pool() -> Rect2:
	var p := _panel()
	return Rect2(p.position + Vector2(28, 70), Vector2(p.size.x - 56, p.size.y * 0.58))


func _bar() -> Rect2:
	var p := _panel()
	var pool := _pool()
	return Rect2(Vector2(p.position.x + 70, pool.end.y + 58), Vector2(p.size.x - 140, 30))


func _leave_rect() -> Rect2:
	var p := _panel()
	return Rect2(p.end.x - 120, p.position.y + 16, 100, 34)


func _to_screen(pc: Vector2) -> Vector2:
	var pool := _pool()
	return pool.position + pc * pool.size


func _to_pool(sp: Vector2) -> Vector2:
	var pool := _pool()
	return (sp - pool.position) / pool.size


## Where the angler stands: on the near shore, under the pool.
func _hand() -> Vector2:
	var pool := _pool()
	return Vector2(pool.position.x + pool.size.x * 0.5, pool.end.y + 18)


# --- the beats ----------------------------------------------------------------------------------

## Cast at the aimed spot: the bobber flies there. Only water takes a cast, and an empty pond takes none.
func _cast_aimed() -> void:
	if _shadows.is_empty() or not Geometry2D.is_point_in_polygon(_aim, _blob):
		return
	_hook = -1
	_cast_at = _aim
	state = S.CAST
	_phase_t = 0.0


## The bobber has landed: a fish near it may notice (it turns and comes), else it sits and waits for one.
func _landed() -> void:
	_check_t = 0.0
	_notice()
	if state == S.CAST:
		state = S.WAIT
		_phase_t = 0.0


func _notice() -> void:
	var i := FishingRules.noticed(_rng, _shadows, _cast_at, _t)
	if i < 0:
		return
	_hook = i
	_come_from = FishingRules.shadow_pos(_shadows[i], _t)
	state = S.COME
	_phase_t = 0.0


## Back to Look with the line in: nothing noticed the bobber, nothing is lost.
func _reel_in() -> void:
	_hook = -1
	state = S.LOOK
	_phase_t = 0.0


func _strike_now() -> void:
	var verdict := FishingRules.strike(_plan, _phase_t)
	if verdict == "hit":
		state = S.REEL
		_phase_t = 0.0
		_reel = FishingRules.reel_start(_shadows[_hook].fish, mods)
		_use_mouse = false  # the pointer pulls only once it moves: where it sat for the strike isn't a pull
		_burst(_to_screen(_cast_at), 10)
	else:
		_end(verdict)


func _end(outcome: String) -> void:
	result = {"outcome": outcome, "fish": _shadows[_hook].fish if _hook >= 0 and outcome == "caught" else {}}
	if _hook >= 0 and FishingRules.GONE.has(outcome):  # a catch, a scared, missed or lost fish: gone from the pond for good
		var pi := int(_shadows[_hook].pond_i)
		if pi < _pond.size():
			_pond.remove_at(pi)
		Game.pond_changed()
	state = S.RESULT
	_phase_t = 0.0
	if outcome == "caught":
		var id := "caught_fish_" + String(result.fish.id)
		_new_kind = not Game.has_flag(id)
		_burst(_to_screen(Vector2(0.5, 0.42)), 24)


## End now with this outcome (tests, and callers that skip the minigame).
func resolve(outcome: String, fish := {}) -> void:
	result = {"outcome": outcome, "fish": fish}
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit(result)
	var layer := get_parent()
	if layer is CanvasLayer:
		layer.queue_free()
	else:
		queue_free()


func _process(delta: float) -> void:
	if size != get_viewport_rect().size:
		size = get_viewport_rect().size  # on a CanvasLayer: fill the screen
	_t += delta
	_phase_t += delta
	match state:
		S.LOOK:
			_move_aim(delta)
		S.CAST:
			if _phase_t >= CAST_TIME:
				_landed()
		S.WAIT:
			_check_t += delta
			if _check_t >= 0.5:  # the shadows drift: another chance for one to find the bobber
				_check_t = 0.0
				_notice()
			if state == S.WAIT and _phase_t >= FishingRules.tune("fish_idle", 4.0):
				_reel_in()
		S.COME:
			if _phase_t >= FishingRules.tune("fish_approach", 0.9):
				state = S.STRIKE
				_phase_t = 0.0
				_plan = FishingRules.strike_plan(_rng, _shadows[_hook].fish, float(mods.get("window_bonus", 0.0)))
		S.STRIKE:
			if FishingRules.bobber_at(_plan, _phase_t) == "gone":
				_end("late")
		S.REEL:
			var input := {}
			var axis := Input.get_axis("ui_left", "ui_right")
			if Input.is_key_pressed(KEY_A):
				axis -= 1.0
			if Input.is_key_pressed(KEY_D):
				axis += 1.0
			var stick := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
			if absf(stick) > 0.2:
				axis += stick
			if absf(axis) > 0.05:
				_use_mouse = false
			if _use_mouse:  # the pointer left or right of the bar's middle pulls like an arrow held
				var bar := _bar()
				input["axis"] = FishingRules.axis_from_pointer(_mouse.x, bar.get_center().x, bar.size.x * 0.3)
			else:
				input["axis"] = axis
			FishingRules.reel_step(_reel, _rng, delta, input)
			if bool(_reel.on) and _rng.randf() < delta * 6.0:
				_burst(_hooked_screen(), 1)
			if _reel.done != "":
				_end(String(_reel.done))
	for s in _splash:
		s.v = (s.v as Vector2) + Vector2(0, 520) * delta
		s.p = (s.p as Vector2) + (s.v as Vector2) * delta
		s.life = float(s.life) - delta
	_splash = _splash.filter(func(s: Dictionary) -> bool: return float(s.life) > 0.0)
	queue_redraw()


## Keys and the stick walk the aim across the pool; the mouse sets it where it points (see _input).
func _move_aim(delta: float) -> void:
	var v := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if stick.length() > 0.2:
		v += stick
	if v.length() > 0.05:
		_use_mouse = false
		_aim = (_aim + v.limit_length(1.0) * delta * 0.55).clamp(Vector2(0.04, 0.06), Vector2(0.96, 0.94))


func _burst(at: Vector2, n: int) -> void:
	for i in n:
		_splash.append({"p": at, "v": Vector2(_rng.randf_range(-140, 140), _rng.randf_range(-320, -120)),
			"life": _rng.randf_range(0.35, 0.7), "r": _rng.randf_range(2.5, 5.5)})


# --- input --------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventKey and (event as InputEventKey).keycode >= KEY_F1 and (event as InputEventKey).keycode <= KEY_F12:
		return  # F7 and friends still work
	if event is InputEventMouseMotion:
		_mouse = (event as InputEventMouseMotion).position
		_use_mouse = true
		if state == S.LOOK:
			_aim = _to_pool(_mouse).clamp(Vector2.ZERO, Vector2.ONE)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_mouse = (event as InputEventMouseButton).position
		_use_mouse = true
		_press(true)
	elif event.is_action_pressed("ui_cancel"):
		if state == S.LOOK:
			result = {"outcome": "left", "fish": {}}
			_finish()
		elif state == S.RESULT:
			_finish()
	elif event.is_action_pressed("ui_accept"):
		_press(false)
	get_viewport().set_input_as_handled()


func _press(by_mouse: bool) -> void:
	match state:
		S.LOOK:
			if by_mouse and _leave_rect().has_point(_mouse):
				result = {"outcome": "left", "fish": {}}
				_finish()
				return
			if by_mouse:
				_aim = _to_pool(_mouse)
			_cast_aimed()
		S.WAIT:
			_reel_in()
		S.STRIKE:
			_strike_now()
		S.RESULT:
			if _phase_t > 0.35:  # a click meant for the reel doesn't skip the catch
				_finish()


# --- drawing ------------------------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.06, 0.1, 0.6))
	var p := _panel()
	var box := StyleBoxFlat.new()
	box.bg_color = Riso.PAPER
	box.border_color = Riso.GOLD_DARK
	box.set_border_width_all(4)
	box.set_corner_radius_all(16)
	draw_style_box(box, p)
	var font := Riso.font()
	draw_string(font, p.position + Vector2(28, 40), Txt.t("UI_FISH_TITLE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Riso.INK)
	draw_string(font, p.position + Vector2(120, 40), _headline(), HORIZONTAL_ALIGNMENT_LEFT, p.size.x - 270, 18, Riso.INK)
	if state == S.LOOK:
		var lr := _leave_rect()
		var lb := StyleBoxFlat.new()
		lb.bg_color = Riso.CREAM
		lb.border_color = Riso.INK
		lb.set_border_width_all(2)
		lb.set_corner_radius_all(8)
		draw_style_box(lb, lr)
		draw_string(font, lr.position + Vector2(0, 23), Txt.t("UI_FISH_LEAVE"), HORIZONTAL_ALIGNMENT_CENTER, lr.size.x, 16, Riso.INK)
	_draw_pool()
	_draw_angler()
	if state == S.REEL or (state == S.RESULT and not _reel.is_empty()):
		_draw_bar()
	var keys := "UI_FISH_KEYS_LOOK"
	if state == S.STRIKE or state == S.CAST or state == S.COME:
		keys = "UI_FISH_KEYS_STRIKE"
	elif state == S.WAIT:
		keys = "UI_FISH_KEYS_WAIT"
	elif state == S.REEL:
		keys = "UI_FISH_KEYS_REEL"
	elif state == S.RESULT:
		keys = "UI_FISH_CLOSE"
	draw_string(font, Vector2(p.position.x + 28, p.end.y - 20), Txt.t(keys), HORIZONTAL_ALIGNMENT_CENTER, p.size.x - 56, 14, Riso.alpha(Riso.INK, 0.75))
	for s in _splash:
		draw_circle(s.p, float(s.r), Riso.alpha(Riso.CREAM, clampf(float(s.life) * 2.0, 0.0, 1.0)))
	if state == S.RESULT:
		_draw_result()


func _headline() -> String:
	match state:
		S.LOOK:
			return Txt.t("UI_FISH_LOOK") if not _shadows.is_empty() else Txt.t("UI_FISH_EMPTY")
		S.CAST:
			return Txt.t("UI_FISH_WAIT")
		S.WAIT:
			return Txt.t("UI_FISH_NOTHING")
		S.COME:
			return Txt.t("UI_FISH_NOTICED")
		S.STRIKE:
			var b := FishingRules.bobber_at(_plan, _phase_t)
			return Txt.t("UI_FISH_BITE") if b == "bite" else (Txt.t("UI_FISH_NIBBLE") if b == "nibble" else Txt.t("UI_FISH_WAIT"))
		S.REEL:
			return Txt.t("UI_FISH_REEL")
	return ""


func _draw_pool() -> void:
	var pool := _pool()
	var g := StyleBoxFlat.new()
	g.bg_color = GRASS
	g.set_corner_radius_all(12)
	draw_style_box(g, pool)
	var outline := PackedVector2Array()
	var inner := PackedVector2Array()
	for v in _blob:
		outline.append(_to_screen(v))
		inner.append(_to_screen(Vector2(0.5, 0.5) + (v - Vector2(0.5, 0.5)) * 0.68))
	var lip := PackedVector2Array()
	for v in _blob:
		lip.append(_to_screen(Vector2(0.5, 0.5) + (v - Vector2(0.5, 0.5)) * 1.03 + Vector2(0, 0.012)))
	draw_colored_polygon(lip, GRASS_DARK)
	draw_colored_polygon(outline, WATER)
	draw_colored_polygon(inner, DEEP)
	# slow ripples
	for i in 4:
		var c := _to_screen(Vector2(0.25 + 0.17 * i, 0.3 + 0.12 * float(i % 2)))
		var a := fmod(_t * 0.6 + i * 0.37, 1.0)
		draw_arc(c, 10.0 + a * 26.0, PI * 1.1, PI * 1.9, 12, Riso.alpha(Riso.CREAM, 0.35 * (1.0 - a)), 2.0)
	# the shadows, under the surface
	for i in _shadows.size():
		if (state == S.REEL or state == S.RESULT) and i == _hook:
			continue
		var s := _shadows[i]
		var at := _to_screen(FishingRules.shadow_pos(s, _t))
		var heading := FishingRules.shadow_heading(s, _t)
		if state == S.STRIKE and i == _hook:
			at = _to_screen(_cast_at + Vector2(-0.04, 0.0))  # the fish that noticed it noses the bobber
		elif state == S.COME and i == _hook:  # it turns and swims over
			var k := clampf(_phase_t / maxf(0.01, FishingRules.tune("fish_approach", 0.9)), 0.0, 1.0)
			var goal := _cast_at + Vector2(-0.04, 0.0)
			at = _to_screen(_come_from.lerp(goal, k * k * (3.0 - 2.0 * k)))
			heading = (goal - _come_from).normalized()
		var len := float(s.fish.get("size", 1.0)) * pool.size.x * 0.07
		_draw_fish(at, heading, len, SHADOW)
	# lily pads ride on top
	for pd in _pads:
		var c := _to_screen(Vector2(pd.x, pd.y))
		var r := pd.z * pool.size.x
		draw_colored_polygon(Riso.circle_pts(c, r, r * 0.8, 20, 0.5, TAU - 0.1), PAD)
	# reeds along the far shore
	for i in 9:
		var x := pool.position.x + pool.size.x * (0.12 + 0.09 * i)
		var y := pool.position.y + 6.0 + absf(sin(i * 1.7)) * 8.0
		var sway := sin(_t * 1.4 + i) * 3.0
		draw_line(Vector2(x, y + 22), Vector2(x + sway, y), GRASS_DARK, 3.0)
		draw_circle(Vector2(x + sway, y), 3.2, Riso.OCHRE)
	if state == S.LOOK:
		_draw_aim()
	if state == S.CAST or state == S.STRIKE or state == S.WAIT or state == S.COME:
		_draw_bobber()
	if state == S.REEL:
		var hs := _shadows[_hook]
		var len := float(hs.fish.get("size", 1.0)) * pool.size.x * 0.07
		var dir := Vector2.RIGHT if float(_reel.target) >= float(_reel.fish) else Vector2.LEFT
		_draw_fish(_hooked_screen(), dir.rotated(sin(_t * 18.0) * 0.25), len, Riso.alpha(SHADOW, 0.7))
		draw_arc(_hooked_screen(), len * 0.8 + sin(_t * 9.0) * 4.0, 0, TAU, 24, Riso.alpha(Riso.CREAM, 0.6), 2.0)


## The aim: a cross where the bobber will land, inside a faint ring that shows how close a fish must be to notice it.
func _draw_aim() -> void:
	if _shadows.is_empty():
		return
	var pool := _pool()
	var at := _to_screen(_aim)
	var reach := FishingRules.tune("fish_notice", 0.18)
	var ring := PackedVector2Array()
	for i in 41:
		var a := TAU * i / 40.0
		ring.append(at + Vector2(cos(a) * reach * pool.size.x, sin(a) * reach / FishingRules.POOL_ASPECT * pool.size.y))
	var wet := Geometry2D.is_point_in_polygon(_aim, _blob)
	draw_polyline(ring, Riso.alpha(Riso.CREAM, 0.45 if wet else 0.2), 2.0)
	var col := Riso.CREAM if wet else Riso.alpha(Riso.RED, 0.8)
	draw_line(at + Vector2(-12, 0), at + Vector2(12, 0), col, 3.0)
	draw_line(at + Vector2(0, -12), at + Vector2(0, 12), col, 3.0)
	draw_arc(at, 7.0, 0.0, TAU, 16, col, 2.0)


## The hooked fish in the pool follows its spot on the bar.
func _hooked_screen() -> Vector2:
	var f := float(_reel.get("fish", 0.5))
	return _to_screen(Vector2(0.15 + 0.7 * f, 0.45 + sin(_t * 3.0) * 0.02))


func _bobber_screen() -> Vector2:
	var to := _to_screen(_cast_at)
	if state == S.CAST:
		var k := clampf(_phase_t / CAST_TIME, 0.0, 1.0)
		var from := _rod_tip()
		return from.lerp(to, k) + Vector2(0, -sin(k * PI) * 90.0)
	return to


func _draw_bobber() -> void:
	var at := _bobber_screen()
	var look := FishingRules.bobber_at(_plan, _phase_t) if state == S.STRIKE else "wait"
	var r := 8.0
	match look:
		"wait":
			at.y += sin(_t * 3.0) * 1.5
		"nibble":
			at.y += 3.0
			draw_arc(at, 14.0, 0, TAU, 20, Riso.alpha(Riso.CREAM, 0.7), 2.0)
		"bite":
			at.y += 6.0
			r = 5.0
			var a := fmod(_phase_t * 3.0, 1.0)
			draw_arc(at, 12.0 + a * 24.0, 0, TAU, 24, Riso.alpha(Riso.CREAM, 1.0 - a), 3.0)
			draw_string(Riso.font(), at + Vector2(-8, -24), "!", HORIZONTAL_ALIGNMENT_CENTER, 16, 30, Riso.RED)
	if state == S.STRIKE:
		draw_arc(at, r + 3.0, 0, TAU, 20, Riso.alpha(Riso.INK, 0.25), 2.0)
	draw_circle(at, r, Riso.CREAM)
	draw_colored_polygon(Riso.circle_pts(at, r, r, 16, PI, TAU), Riso.RED)


## The rod tip: leans toward the hooked fish and bends harder the further off the marker is.
func _rod_tip() -> Vector2:
	var hand := _hand() + Vector2(12, -24)
	var lean := 0.0
	if state == S.REEL:
		lean = float(_reel.pull)
	elif state == S.STRIKE or state == S.CAST or state == S.WAIT or state == S.COME:
		lean = clampf((_cast_at.x - 0.5) * 1.4, -0.7, 0.7)
	elif state == S.LOOK:
		lean = clampf((_aim.x - 0.5) * 0.8, -0.5, 0.5)
	var tug := 0.0
	if state == S.REEL and not bool(_reel.on):
		tug = sin(_t * 30.0) * 4.0
	return hand + Vector2(lean * 140.0 + tug, -150.0 + absf(lean) * 30.0)


func _draw_angler() -> void:
	var hand := _hand() + Vector2(12, -24)
	var tip := _rod_tip()
	var bend := 0.0
	if state == S.REEL:
		bend = 0.5 + absf(float(_reel.pull)) * 0.5
	elif state == S.STRIKE and FishingRules.bobber_at(_plan, _phase_t) == "bite":
		bend = 0.4
	var ctrl := hand.lerp(tip, 0.55) + (tip - hand).orthogonal().normalized() * (-26.0 * bend * signf(tip.x - hand.x + 0.001))
	var rod := Riso.quad(hand, ctrl, tip, 10)
	# the line: to the bobber, or to the hooked fish
	var end := Vector2.ZERO
	if state == S.CAST or state == S.STRIKE or state == S.WAIT or state == S.COME:
		end = _bobber_screen()
	elif state == S.REEL:
		end = _hooked_screen()
	if end != Vector2.ZERO:
		var slack := 0.0 if state == S.REEL else 30.0
		draw_polyline(Riso.quad(tip, tip.lerp(end, 0.5) + Vector2(0, slack), end, 12), Riso.alpha(Riso.CREAM, 0.9), 1.5)
	draw_polyline(rod, ROD, 5.0)
	draw_circle(tip, 2.5, Riso.INK)
	Riso.draw_piece(self, _hand() + Vector2(-4, 8), 46.0, Riso.RED)


func _draw_bar() -> void:
	var bar := _bar()
	var track := StyleBoxFlat.new()
	track.bg_color = Riso.mix(WATER, Riso.CREAM, 0.35)
	track.border_color = Riso.INK
	track.set_border_width_all(2)
	track.set_corner_radius_all(15)
	draw_style_box(track, bar)
	for i in range(1, 10):
		var x := bar.position.x + bar.size.x * i / 10.0
		draw_line(Vector2(x, bar.position.y + 8), Vector2(x, bar.end.y - 8), Riso.alpha(Riso.INK, 0.15), 2.0)
	var half := float(_reel.half)
	var m := float(_reel.marker)
	var on := bool(_reel.on)
	var mr := Rect2(bar.position.x + bar.size.x * (m - half), bar.position.y - 6, bar.size.x * half * 2.0, bar.size.y + 12)
	var mk := StyleBoxFlat.new()
	mk.bg_color = Riso.alpha(Riso.OCHRE, 0.6) if on else Riso.alpha(Riso.RED, 0.3)
	mk.border_color = Riso.INK
	mk.set_border_width_all(3)
	mk.set_corner_radius_all(8)
	draw_style_box(mk, mr)
	var fx := bar.position.x + bar.size.x * float(_reel.fish)
	var dir := Vector2.RIGHT if float(_reel.target) >= float(_reel.fish) else Vector2.LEFT
	_draw_fish(Vector2(fx, bar.get_center().y), dir, 34.0, Riso.INDIGO)
	# the catch meter
	var meter := Rect2(bar.position.x, bar.end.y + 16, bar.size.x, 12)
	var mb := StyleBoxFlat.new()
	mb.bg_color = Riso.alpha(Riso.INK, 0.12)
	mb.set_corner_radius_all(6)
	draw_style_box(mb, meter)
	var fill := Rect2(meter.position, Vector2(meter.size.x * float(_reel.catch), meter.size.y))
	if fill.size.x > 1.0:
		var fb := StyleBoxFlat.new()
		fb.bg_color = Riso.GOLD_DARK if on else Riso.alpha(Riso.GOLD_DARK, 0.6)
		fb.set_corner_radius_all(6)
		draw_style_box(fb, fill)


func _draw_result() -> void:
	var pool := _pool()
	var c := pool.get_center() + Vector2(0, -10)
	var font := Riso.font()
	var o := String(result.get("outcome", ""))
	var card := StyleBoxFlat.new()
	card.bg_color = Riso.alpha(Riso.PAPER, 0.94)
	card.border_color = Riso.GOLD_DARK
	card.set_border_width_all(3)
	card.set_corner_radius_all(14)
	var cr := Rect2(c - Vector2(230, 90), Vector2(460, 180))
	draw_style_box(card, cr)
	if o == "caught":
		var row: Dictionary = result.fish
		var len := 60.0 + float(row.get("size", 1.0)) * 40.0
		var hold := c + Vector2(0, -26 + sin(_phase_t * 4.0) * 3.0)
		_draw_fish(hold, Vector2.RIGHT.rotated(-0.25), len, Riso.INDIGO)
		draw_string(font, c + Vector2(-220, 44), Txt.f("UI_FISH_CAUGHT", Txt.t(String(row.name_key))), HORIZONTAL_ALIGNMENT_CENTER, 440, 20, Riso.INK)
		var grade := Txt.t("GRADE_" + String(row.get("grade", "small")).to_upper())
		draw_string(font, c + Vector2(-220, 70), grade, HORIZONTAL_ALIGNMENT_CENTER, 440, 16, Riso.RED if String(row.grade) == "prize" else Riso.INK)
		if _new_kind:
			draw_string(font, cr.position + Vector2(14, 28), Txt.t("UI_FISH_NEW"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Riso.RED)
	else:
		var key: String = {"lost": "UI_FISH_LOST", "early": "UI_FISH_EARLY", "late": "UI_FISH_LATE"}.get(o, "UI_FISH_LOST")
		draw_string(font, c + Vector2(-220, 8), Txt.t(String(key)), HORIZONTAL_ALIGNMENT_CENTER, 440, 22, Riso.INK)


## A flat fish: an oval body and a tail fin, nose along dir.
func _draw_fish(at: Vector2, dir: Vector2, length: float, col: Color) -> void:
	var a := dir.angle()
	var body := PackedVector2Array()
	for i in 18:
		var t := TAU * i / 18.0
		body.append(at + Vector2(cos(t) * length * 0.5, sin(t) * length * 0.2).rotated(a))
	draw_colored_polygon(body, col)
	var back := at - dir * length * 0.45
	var tail := PackedVector2Array([back, back - dir * length * 0.3 + dir.orthogonal() * length * 0.2,
		back - dir * length * 0.3 - dir.orthogonal() * length * 0.2])
	draw_colored_polygon(tail, col)

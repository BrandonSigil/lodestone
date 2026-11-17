class_name HuntGame
extends Control
## Shared base for the four hunting prototypes (HuntRules has the rules): the play field, the end card, Esc, and the
## flat graybox shapes they all draw (bushes, pines, animals, the hero, Doggo). A game calls _end(caught) when its
## round is over; the card then waits for AGAIN (Space, Enter, click) or BACK (Esc) and emits `finished`.

signal finished(result: Dictionary)  ## {"mode", "caught": [animal rows], "food": int, "next": "again" | "back"}

const INK := Color("#2a2433")
const CREAM := Color("#f3ead2")
const OCHRE := Color("#e0a03a")
const RED := Color("#c8363c")
const INDIGO := Color("#3a3f7a")
const AMBER := Color("#ffcf4a")
const LEAF := Color("#7f8c5c")
const PINE := Color("#4c5a3b")
const MEADOW := Color("#d6cc96")
const BARK_BROWN := Color("#7a5a3a")
const ANIMAL_COL := {
	"rabbit": Color("#efe3c8"), "pheasant": Color("#b8582f"), "deer": Color("#c98a3e"),
	"boar": Color("#5a4636"), "fox": Color("#e07a2c"),
}

var mode := ""
var mods := {}
var rng := RandomNumberGenerator.new()
var caught: Array[Dictionary] = []
var over := false
var t := 0.0
var _card_t := 0.0
var _toast := ""
var _toast_t := 0.0
var aim_override := Vector2(-1, -1)  ## screenshot tools set the aim here instead of moving the mouse


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	resized.connect(queue_redraw)
	if rng.seed == 0:
		rng.randomize()
	grab_focus.call_deferred()
	start()


func mouse() -> Vector2:
	return aim_override if aim_override.x >= 0.0 else get_local_mouse_position()


## Override: set up the round.
func start() -> void:
	pass


## Override: one frame of play (not called once the round is over).
func step(_dt: float) -> void:
	pass


## Override: draw the play field (the base draws the card and toast on top).
func paint() -> void:
	pass


func _process(dt: float) -> void:
	t += dt
	_toast_t = maxf(0.0, _toast_t - dt)
	if over:
		_card_t += dt
	else:
		step(dt)
	queue_redraw()


func _draw() -> void:
	paint()
	if _toast_t > 0.0 and _toast != "":
		var a := clampf(_toast_t / 0.4, 0.0, 1.0)
		var w := 18.0 * _toast.length() * 0.62 + 40.0
		var r := Rect2(Vector2((size.x - w) * 0.5, field().position.y + 20), Vector2(w, 40))
		draw_rect(r, Riso.alpha(INK, 0.82 * a))
		text(_toast, r.get_center() + Vector2(0, 7), 20, Riso.alpha(CREAM, a), true)
	if over:
		_paint_card()


## The play area: the whole window less a thin margin, and a strip at the bottom for the HUD.
func field() -> Rect2:
	return Rect2(Vector2(24, 20), size - Vector2(48, 96))


func hud_y() -> float:
	return size.y - 46.0


func toast(msg: String, secs := 1.4) -> void:
	_toast = msg
	_toast_t = secs


func _end() -> void:
	if over:
		return
	over = true
	_card_t = 0.0


func _finish(next: String) -> void:
	finished.emit({"mode": mode, "caught": caught, "food": HuntRules.food(caught), "next": next})


func _gui_input(event: InputEvent) -> void:
	if over and _card_t > 0.6:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_finish("again")
			accept_event()
	elif not over:
		play_input(event)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.is_echo():
		return
	var k := (event as InputEventKey).keycode
	if k == KEY_ESCAPE:
		_finish("back")
		get_viewport().set_input_as_handled()
	elif over and _card_t > 0.6 and (k == KEY_SPACE or k == KEY_ENTER or k == KEY_KP_ENTER):
		_finish("again")
		get_viewport().set_input_as_handled()


## Override: mouse input during play (keys are read with Input in step()).
func play_input(_event: InputEvent) -> void:
	pass


func _paint_card() -> void:
	var a := clampf(_card_t / 0.3, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Riso.alpha(INK, 0.45 * a))
	var w := 460.0
	var h := 250.0
	var r := Rect2((size - Vector2(w, h)) * 0.5, Vector2(w, h))
	draw_rect(r, Riso.alpha(Color("#3a2f50"), a))
	draw_rect(r, Riso.alpha(AMBER, a), false, 3.0)
	var head := Txt.t("HUNT_CARD_GOOD") if not caught.is_empty() else Txt.t("HUNT_CARD_EMPTY")
	text(head, r.position + Vector2(w * 0.5, 50), 30, Riso.alpha(AMBER, a), true)
	if caught.is_empty():
		text(Txt.t("HUNT_CARD_EMPTY_SUB"), r.position + Vector2(w * 0.5, 115), 18, Riso.alpha(CREAM, a), true)
	else:
		var n := caught.size()
		var gap := minf(80.0, (w - 60.0) / n)
		for i in n:
			var c := r.position + Vector2(w * 0.5 + (i - (n - 1) * 0.5) * gap, 110)
			draw_animal(String(caught[i].id), c, Vector2.RIGHT, 0.8, "stand")
		text(Txt.t("HUNT_CARD_FOOD") % HuntRules.food(caught), r.position + Vector2(w * 0.5, 165), 20, Riso.alpha(CREAM, a), true)
	text(Txt.t("HUNT_CARD_KEYS"), r.position + Vector2(w * 0.5, h - 24), 15, Riso.alpha(Color("#cbbfd9"), a), true)


# --- drawing helpers ------------------------------------------------------------------------------

func text(s: String, at: Vector2, px: int, col: Color, centre := false) -> void:
	var f := Riso.font()
	var x := at.x
	if centre:
		x -= f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x * 0.5
	draw_string(f, Vector2(x, at.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


## A row of round pips, `full` of `count` lit (noise, arrows, barks, snares).
func pips(at: Vector2, count: int, full: int, lit: Color, label := "") -> float:
	var x := at.x
	if label != "":
		text(label, Vector2(x, at.y + 6), 16, CREAM)
		x += Riso.font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 12
	for i in count:
		draw_circle(Vector2(x + 9, at.y), 7.0, lit if i < full else Riso.alpha(CREAM, 0.22))
		x += 20
	return x


func hud_strip() -> void:
	draw_rect(Rect2(0, size.y - 70, size.x, 70), Color("#2e2440"))


func draw_bush(c: Vector2, r: float, col := LEAF, shake := 0.0) -> void:
	var o := Vector2(sin(t * 40.0) * shake, 0)
	draw_circle(c + Vector2(0, r * 0.15), r * 1.05, Riso.alpha(INK, 0.18))
	draw_circle(c + o + Vector2(-r * 0.55, r * 0.1), r * 0.7, col.darkened(0.12))
	draw_circle(c + o + Vector2(r * 0.6, r * 0.12), r * 0.65, col.darkened(0.08))
	draw_circle(c + o, r * 0.85, col)
	draw_circle(c + o + Vector2(-r * 0.2, -r * 0.35), r * 0.35, col.lightened(0.12))


func draw_tree(base: Vector2, h: float) -> void:
	Riso.draw_pine(self, base.x, base.y, h, PINE, LEAF.lightened(0.2))


## Animals as flat shapes. pose: "run" bobs and stretches, "stand" stands, "graze" has its head down, "look" head up.
func draw_animal(kind: String, c: Vector2, facing: Vector2, scale_k := 1.0, pose := "run", tint := Color.WHITE) -> void:
	var col: Color = ANIMAL_COL.get(kind, CREAM) * tint
	var dir := 1.0 if facing.x >= 0.0 else -1.0
	var bob := sin(t * 22.0) * 3.0 * scale_k if pose == "run" else 0.0
	var s := scale_k
	var p := c + Vector2(0, bob)
	draw_set_transform(p, 0.0, Vector2(dir * s, s))
	draw_circle(Vector2(0, 14), 14.0, Riso.alpha(INK, 0.15))
	match kind:
		"rabbit":
			Riso.poly(self, Riso.circle_pts(Vector2.ZERO, 14, 9), col)
			draw_circle(Vector2(12, -6), 6.5, col)
			var ear := -1.0 if pose == "look" else 0.0
			Riso.poly(self, Riso.circle_pts(Vector2(10, -17 + ear), 2.4, 7), col)
			Riso.poly(self, Riso.circle_pts(Vector2(15, -16 + ear), 2.4, 7), col)
			draw_circle(Vector2(-14, -2), 4.0, CREAM)
			draw_circle(Vector2(15, -7), 1.4, INK)
		"pheasant":
			Riso.poly(self, Riso.circle_pts(Vector2.ZERO, 13, 8), col)
			draw_line(Vector2(-10, -2), Vector2(-30, -10), col.darkened(0.2), 4.0, true)
			draw_circle(Vector2(11, -8), 5.0, Color("#2f5d50"))
			draw_circle(Vector2(12, -9), 2.0, RED)
		"deer":
			var head_down := pose == "graze"
			for lx in [-12.0, -6.0, 8.0, 14.0]:
				draw_line(Vector2(lx, 6), Vector2(lx, 22), col.darkened(0.2), 3.0, true)
			Riso.poly(self, Riso.circle_pts(Vector2.ZERO, 22, 11), col)
			draw_circle(Vector2(-22, -4), 4.0, CREAM)
			var neck := Vector2(26, 14) if head_down else Vector2(28, -20)
			draw_line(Vector2(16, -2), neck, col, 8.0, true)
			draw_circle(neck, 7.0, col)
			if not head_down:
				draw_line(neck + Vector2(-2, -6), neck + Vector2(-8, -20), BARK_BROWN, 2.5, true)
				draw_line(neck + Vector2(2, -6), neck + Vector2(6, -20), BARK_BROWN, 2.5, true)
				draw_line(neck + Vector2(-5, -14), neck + Vector2(-12, -16), BARK_BROWN, 2.0, true)
				draw_circle(neck + Vector2(3, -1), 1.6, INK)
		"boar":
			for lx in [-10.0, 10.0]:
				draw_line(Vector2(lx, 4), Vector2(lx, 16), INK, 4.0, true)
			Riso.poly(self, PackedVector2Array([Vector2(-20, 6), Vector2(-16, -12), Vector2(6, -14), Vector2(22, -2), Vector2(18, 8)]), col)
			draw_line(Vector2(18, 2), Vector2(24, -6), CREAM, 2.5, true)
			draw_circle(Vector2(12, -6), 1.6, CREAM)
		"fox":
			Riso.poly(self, Riso.circle_pts(Vector2.ZERO, 15, 7), col)
			draw_line(Vector2(-12, 0), Vector2(-28, -6), col, 7.0, true)
			draw_circle(Vector2(-29, -6), 3.5, CREAM)
			Riso.poly(self, PackedVector2Array([Vector2(10, -4), Vector2(14, -14), Vector2(18, -6), Vector2(22, -14), Vector2(26, -2), Vector2(14, 2)]), col)
			draw_circle(Vector2(20, -4), 1.5, INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_hero(base: Vector2, h := 52.0, crouch := false) -> void:
	Riso.draw_piece(self, base, h * (0.78 if crouch else 1.0), INDIGO, {})


## Doggo: an ochre loaf with big ears, top-down-ish so he reads on every field.
func draw_dog(c: Vector2, facing: Vector2, s := 1.0) -> void:
	var dir := 1.0 if facing.x >= 0.0 else -1.0
	draw_set_transform(c + Vector2(0, sin(t * 20.0) * 1.5), 0.0, Vector2(dir * s, s))
	draw_circle(Vector2(0, 10), 16.0, Riso.alpha(INK, 0.18))
	Riso.poly(self, Riso.circle_pts(Vector2.ZERO, 18, 10), OCHRE)
	Riso.poly(self, Riso.circle_pts(Vector2(-2, 4), 12, 5), CREAM)
	draw_circle(Vector2(16, -6), 9.0, OCHRE)
	Riso.poly(self, PackedVector2Array([Vector2(11, -12), Vector2(12, -26), Vector2(18, -14)]), OCHRE)
	Riso.poly(self, PackedVector2Array([Vector2(17, -14), Vector2(24, -25), Vector2(24, -10)]), OCHRE)
	draw_circle(Vector2(24, -4), 2.2, INK)
	draw_circle(Vector2(19, -8), 1.5, INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The bow's reticle: the outer ring tightens with the draw, gold when it's in the sweet spot, red when shaking.
func draw_reticle(at: Vector2, draw: Dictionary, drawing: bool) -> void:
	var col := CREAM
	if drawing:
		col = AMBER if draw.sweet else (RED if float(draw.shake) > 0.0 else CREAM)
	var ring := lerpf(34.0, 10.0, float(draw.power)) if drawing else 34.0
	draw_arc(at, ring, 0, TAU, 40, col, 2.5, true)
	draw_arc(at, 4.0, 0, TAU, 16, col, 2.0, true)
	for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(at + d * (ring + 4), at + d * (ring + 12), col, 2.0, true)

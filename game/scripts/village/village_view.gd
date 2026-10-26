class_name VillageView
extends Control
## The starting village, drawn in the riso style (style lab draft 1, rules R1-R10).
## Four places to click: the mayor's house, the shop, the hearth where the roster waits,
## and the gate. Picked members wait at the gate. Pure function of SEED.

signal place_pressed(id: String)

const SEED := 1207
const S := 0.03  ## strangeness: home
const W := 1280.0
const H := 720.0
const HORIZON := 330.0
const NEAR_Y := 452.0
const BAND_TOP := 570.0

## id -> hit rect, label anchor
const PLACES := {
	"mayor": {"rect": Rect2(196, 380, 210, 160), "tag": Vector2(300, 372), "key": "VIL_MAYOR"},
	"shop": {"rect": Rect2(560, 410, 180, 130), "tag": Vector2(648, 396), "key": "VIL_SHOP"},
	"hearth": {"rect": Rect2(800, 420, 210, 140), "tag": Vector2(912, 404), "key": "VIL_HEARTH"},
	"gate": {"rect": Rect2(1060, 380, 200, 180), "tag": Vector2(1176, 372), "key": "VIL_GATE"},
}

var waiting: Array[CharacterDef] = []  ## unlocked, not picked: around the hearth
var picked: Array[CharacterDef] = []  ## at the gate
var hover := ""
var active := true  ## false while a panel is open


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS


func set_people(w: Array[CharacterDef], p: Array[CharacterDef]) -> void:
	waiting = w
	picked = p
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if not active:
		return
	if e is InputEventMouseMotion:
		var h := _place_at(e.position)
		if h != hover:
			hover = h
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h != "" else Control.CURSOR_ARROW
			queue_redraw()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var h := _place_at(e.position)
		if h != "":
			place_pressed.emit(h)


func _place_at(pos: Vector2) -> String:
	for id in PLACES:
		if (PLACES[id].rect as Rect2).has_point(pos):
			return id
	return ""


func set_active(on: bool) -> void:
	active = on
	if not on:
		hover = ""
	queue_redraw()


func _draw() -> void:
	var p := Riso.palette_at(S)
	var r := Riso.rng(SEED)
	_draw_sky(p, r)
	_draw_far(p, r)
	var mid_phase := r.randf() * 6.0
	var mid := Riso.ridge_pts(W, H, HORIZON + 43, 29, 1.3, mid_phase)
	Riso.poly(self, mid, p.mid)
	Riso.draw_marks(self, mid, Rect2(0, HORIZON, W, H - HORIZON), Riso.mix(p.mid, p.light, 0.25), "tick", 70, r)
	var near_phase := r.randf() * 6.0
	_draw_back_trees(p, r, near_phase)
	var ground := Riso.ridge_pts(W, H, NEAR_Y, 22, 0.8, near_phase)
	Riso.poly(self, ground, p.ground)
	Riso.draw_marks(self, ground, Rect2(0, NEAR_Y - 30, W, H - NEAR_Y), Riso.mix(p.ground, p.dark, 0.18), "tick", 110, r)
	Riso.draw_marks(self, ground, Rect2(0, NEAR_Y - 30, W, H - NEAR_Y), Riso.mix(p.ground, p.light, 0.4), "fan", 45, r)
	_draw_path(p)
	_draw_mayor(p)
	_draw_shop(p, r)
	_draw_hearth(p, r)
	_draw_gate(p)
	_draw_tags(p)


func _draw_sky(p: Dictionary, r: RandomNumberGenerator) -> void:
	Riso.draw_sky(self, Rect2(0, 0, W, HORIZON), p.sky_top, p.horizon)
	draw_rect(Rect2(0, HORIZON, W, H - HORIZON), p.horizon)
	var moon := Vector2(W * (0.18 + r.randf() * 0.64), H * (0.12 + r.randf() * 0.12))
	Riso.draw_crescent(self, moon, W * 0.022, p.accent)
	for i in 3:
		Riso.draw_step_cloud(self, r.randf() * W * 0.85, H * (0.06 + r.randf() * 0.2), W * (0.12 + r.randf() * 0.16), H * 0.018, Riso.alpha(p.light, 0.38), r)


func _draw_far(p: Dictionary, r: RandomNumberGenerator) -> void:
	for row in [0, 1]:
		var n := 7 if row == 1 else 9
		var base := HORIZON + H * (0.1 if row == 1 else 0.08)
		for i in n:
			var x := (i + 0.2 + r.randf() * 0.6) / n * W * 1.15 - W * 0.07
			var w := W * ((0.16 + r.randf() * 0.12) if row == 1 else (0.13 + r.randf() * 0.1))
			var h := H * ((0.1 + r.randf() * 0.1) if row == 1 else (0.16 + r.randf() * 0.14))
			var col: Color = Riso.mix(p.far, p.mid, 0.15 + 0.15 * r.randf()) if row == 1 else Riso.mix(p.far, p.horizon, 0.3 + 0.25 * r.randf())
			Riso.draw_gumdrop(self, x, base, w, h, col, p.light)


func _draw_back_trees(p: Dictionary, r: RandomNumberGenerator, phase: float) -> void:
	var light := Riso.mix(p.near, p.light, 0.35)
	for x in [40.0, 92.0, 150.0, 455.0, 520.0, 770.0, 1012.0, 1050.0, 1250.0]:
		var y := Riso.ridge_y(x, W, NEAR_Y, 22, 0.8, phase) + 8
		Riso.draw_pine(self, x + r.randf_range(-10, 10), y, r.randf_range(70, 115), p.near, light)


func _draw_path(p: Dictionary) -> void:
	var pts := Riso.cubic(Vector2(250, 548), Vector2(560, 590), Vector2(900, 520), Vector2(1290, 534), 40)
	pts.insert(0, Vector2(250, 548))
	var col := Riso.mix(p.ground, p.light, 0.45)
	for i in range(0, pts.size() - 1, 2):
		draw_line(pts[i], pts[i + 1], col, 9.0)


## The tag lifts and goes cream when its place is hovered.
func _draw_tags(_p: Dictionary) -> void:
	var f := Riso.font()
	for id in PLACES:
		var text: String = Txt.t(PLACES[id].key)
		var on: bool = hover == id
		var size := 15
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 22
		var c: Vector2 = PLACES[id].tag + (Vector2(0, -6) if on else Vector2.ZERO)
		var rect := Rect2(c.x - tw / 2, c.y - 14, tw, 28)
		draw_line(Vector2(c.x, rect.end.y), Vector2(c.x, rect.end.y + 10), Riso.INK, 2.0)
		draw_rect(rect, Riso.PAPER if on else Riso.GOLD)
		draw_rect(rect, Riso.INK, false, 2.0)
		Riso.draw_label(self, text, Vector2(c.x, c.y), size, Riso.INK, HORIZONTAL_ALIGNMENT_CENTER)


func _hover_glow(id: String, c: Vector2, rx: float, p: Dictionary) -> void:
	if hover == id:
		Riso.poly(self, Riso.circle_pts(c, rx, rx * 0.22), Riso.alpha(p.light, 0.55))


func _draw_mayor(p: Dictionary) -> void:
	_hover_glow("mayor", Vector2(300, 528), 130, p)
	Riso.draw_house(self, 160, 498, 84, p, false)
	Riso.draw_house(self, 300, 530, 168, p, true)
	# door and banner pole: the hall reads as the big house
	draw_rect(Rect2(318, 488, 26, 42), Riso.mix(p.dark, p.ground, 0.25))
	draw_line(Vector2(398, 530), Vector2(398, 384), p.dark, 4.0)
	Riso.poly(self, PackedVector2Array([Vector2(400, 388), Vector2(446, 400), Vector2(400, 414)]), Riso.RED)
	Riso.draw_stamp_star(self, Vector2(416, 401), 6, Riso.CREAM)
	Riso.draw_piece(self, Vector2(356, 548), 50, Riso.mix(Riso.INDIGO, Riso.BASE, 0.15), {"hat": "point"})
	draw_rect(Rect2(347, 520, 18, 4), Riso.GOLD)


func _draw_shop(p: Dictionary, r: RandomNumberGenerator) -> void:
	_hover_glow("shop", Vector2(650, 532), 110, p)
	Riso.draw_house(self, 640, 524, 132, p, true)
	# striped awning over the counter
	var x0 := 572.0
	var y0 := 466.0
	for i in 7:
		var col := Riso.RED if i % 2 == 0 else Riso.CREAM
		Riso.poly(self, PackedVector2Array([Vector2(x0 + i * 20, y0), Vector2(x0 + i * 20 + 20, y0),
			Vector2(x0 + i * 20 + 20, y0 + 22), Vector2(x0 + i * 20 + 10, y0 + 28), Vector2(x0 + i * 20, y0 + 22)]), col)
	draw_rect(Rect2(574, 500, 136, 8), Riso.mix(p.dark, p.ground, 0.3))
	# goods out front
	draw_rect(Rect2(716, 498, 26, 26), Color("#a8743a"))
	draw_rect(Rect2(716, 498, 26, 26), Color("#6e4520"), false, 2.0)
	draw_rect(Rect2(728, 480, 20, 18), Color("#a8743a"))
	Riso.poly(self, Riso.circle_pts(Vector2(560, 516), 13, 10), Color("#c98a3c"))
	Riso.draw_piece(self, Vector2(612, 538), 46, Riso.OCHRE, {"pack": false})


func _draw_hearth(p: Dictionary, r: RandomNumberGenerator) -> void:
	var fire := Vector2(905, 528)
	Riso.draw_house(self, 960, 474, 104, p, true)
	_hover_glow("hearth", fire, 120, p)
	Riso.poly(self, Riso.circle_pts(fire, 64, 18), Riso.alpha(p.accent, 0.22))
	for i in 9:
		var a := TAU * i / 9.0
		draw_circle(fire + Vector2(cos(a) * 20, sin(a) * 6), 4.5, Riso.mix(p.dark, p.ground, 0.4))
	for f in [[-6, 28, Riso.RED], [5, 22, Riso.OCHRE], [0, 15, p.accent]]:
		var fx: float = fire.x + f[0]
		var fh: float = f[1]
		var pts := PackedVector2Array([Vector2(fx - fh * 0.3, fire.y)])
		pts.append_array(Riso.quad(Vector2(fx - fh * 0.3, fire.y), Vector2(fx - fh * 0.3, fire.y - fh * 0.6), Vector2(fx, fire.y - fh)))
		pts.append_array(Riso.quad(Vector2(fx, fire.y - fh), Vector2(fx + fh * 0.3, fire.y - fh * 0.6), Vector2(fx + fh * 0.3, fire.y)))
		Riso.poly(self, pts, f[2])
	# the roster waits around the fire, back row first so the front row overlaps it
	var spots: Array[Vector2] = []
	for i in waiting.size():
		var a := PI * (1.15 + 0.7 * float(i) / maxi(1, waiting.size() - 1)) if waiting.size() > 1 else PI * 1.5
		spots.append(fire + Vector2(cos(a) * 82, sin(a) * 20 + 22))
	var order := range(waiting.size())
	order.sort_custom(func(a: int, b: int) -> bool: return spots[a].y < spots[b].y)
	for i in order:
		_piece(waiting[i], spots[i], 44, fire.x)


func _draw_gate(p: Dictionary) -> void:
	_hover_glow("gate", Vector2(1160, 548), 110, p)
	var post := Riso.mix(p.dark, p.near, 0.2)
	draw_rect(Rect2(1110, 420, 16, 120), post)
	draw_rect(Rect2(1222, 420, 16, 120), post)
	draw_rect(Rect2(1096, 408, 156, 18), post)
	for i in 4:
		Riso.draw_stamp_step(self, Vector2(1126 + i * 32, 417), 7, Riso.mix(p.light, p.ground, 0.3))
	for i in picked.size():
		_piece(picked[i], Vector2(1136 + (i % 2) * 40 - (i / 2) * 18, 540 + (i / 2) * 16 - (i % 2) * 4), 44, 1300.0)


func _piece(d: CharacterDef, base: Vector2, h: float, look_x: float) -> void:
	var st := Riso.piece_style(d)
	var opt := {"hat": st.get("hat", ""), "pack": st.get("pack", false), "dir": 1.0 if look_x > base.x else -1.0}
	if d.party_slots > 1:
		Riso.draw_piece(self, base + Vector2(-h * 0.32, 0), h * 0.82, st.col, opt)
		Riso.draw_piece(self, base + Vector2(h * 0.32, 2), h * 0.82, Riso.mix(st.col, Riso.INDIGO, 0.4), opt)
	else:
		Riso.draw_piece(self, base, h, st.col, opt)

class_name VillageFrame
extends Control
## Frame candidate A from the style lab (embroidered band): a thin gold border that thickens
## into a stitched bottom band holding the party, the Lodestone medallion and the pack.
## Drawing only; the screen puts real buttons over the tabs and the medallion.

const BAND := 150.0
const B := 14.0
const PARTY_RECT := Rect2(40, 610, 440, 78)
const PACK_RECT := Rect2(800, 610, 440, 78)
const MEDALLION := Vector2(640, 622)
const MEDALLION_R := 84.0
const MINI_CELL := 22.0

var party: Array[CharacterDef] = []
var outfit: Outfit
var status_text := ""
var strangeness := 0.03


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh(members: Array[CharacterDef], kit: Outfit, status: String) -> void:
	party = members
	outfit = kit
	status_text = status
	queue_redraw()


func _draw() -> void:
	var W := size.x
	var H := size.y
	var p := Riso.palette_at(strangeness)
	draw_rect(Rect2(0, 0, W, B), Riso.GOLD)
	draw_rect(Rect2(0, 0, B, H), Riso.GOLD)
	draw_rect(Rect2(W - B, 0, B, H), Riso.GOLD)
	draw_rect(Rect2(0, H - BAND, W, BAND), Riso.GOLD)
	draw_rect(Rect2(B, B, W - 2 * B, H - BAND - B), Riso.INK, false, 2.0)
	# embroidery rows
	for ry in [H - BAND + 18, H - 14]:
		var x := 26.0
		while x < W:
			Riso.draw_stamp_step(self, Vector2(x, ry), 10, Riso.PAPER)
			x += 34.0
	draw_line(Vector2(B, H - BAND + 34), Vector2(W - B, H - BAND + 34), Riso.GOLD_DARK, 2.0)
	draw_line(Vector2(B, H - 30), Vector2(W - B, H - 30), Riso.GOLD_DARK, 2.0)
	_draw_party()
	_draw_pack(p)
	_draw_medallion(p)
	_draw_status_tab()


func _panel(r: Rect2) -> void:
	draw_rect(r, Riso.PAPER)
	draw_rect(r, Riso.INK, false, 2.0)


func _draw_party() -> void:
	_panel(PARTY_RECT)
	if party.is_empty():
		Riso.draw_label(self, Txt.t("UI_PICK_PARTY"), PARTY_RECT.get_center(), 15, Riso.mix(Riso.INK, Riso.PAPER, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
		return
	var step := PARTY_RECT.size.x / 4.0
	for i in party.size():
		var d := party[i]
		var x := PARTY_RECT.position.x + 30 + i * step
		var st := Riso.piece_style(d)
		Riso.draw_piece(self, Vector2(x, PARTY_RECT.end.y - 10), 52, st.col, {"hat": st.get("hat", "")})
		var nm := Txt.t(d.name_key).split(" ")[0]
		Riso.draw_label(self, nm, Vector2(x + 24, PARTY_RECT.position.y + 22), 13, Riso.INK, HORIZONTAL_ALIGNMENT_LEFT, step - 30)
		var hp := d.class_def.max_hp
		Riso.draw_hp(self, Vector2(x + 28, PARTY_RECT.position.y + 46), mini(hp, 8), mini(hp, 8), 3.0, Riso.RED, Color("#d9cba8"))
		Riso.draw_label(self, str(hp), Vector2(x + 30, PARTY_RECT.position.y + 62), 11, Riso.mix(Riso.INK, Riso.PAPER, 0.3))


func _draw_pack(p: Dictionary) -> void:
	_panel(PACK_RECT)
	if outfit == null:
		return
	var origin := PACK_RECT.position + Vector2(14, 6)
	PackView.draw_bag(self, outfit.bag, outfit.items_db, origin, MINI_CELL, false)
	var tx := origin.x + MINI_CELL * outfit.bag.cols + 22
	var lines := [Txt.f("UI_FOOD", outfit.food()), Txt.f("UI_MEDICINE", outfit.medicine()), Txt.f("UI_GOLD", outfit.gold)]
	for i in lines.size():
		Riso.draw_label(self, lines[i], Vector2(tx, PACK_RECT.position.y + 18 + i * 21), 15, Riso.INK)
	Riso.draw_label(self, Txt.f("UI_SLOTS_USED", [outfit.bag.used_cells(), outfit.bag.capacity()]), Vector2(PACK_RECT.end.x - 16, PACK_RECT.position.y + 18), 13, Riso.mix(Riso.INK, Riso.PAPER, 0.3), HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_medallion(p: Dictionary) -> void:
	var m := MEDALLION
	draw_circle(m, MEDALLION_R, Riso.GOLD)
	draw_arc(m, MEDALLION_R, 0, TAU, 64, Riso.INK, 2.0, true)
	for i in 16:
		var a := i / 16.0 * TAU
		Riso.draw_stamp_star(self, m + Vector2(cos(a), sin(a)) * (MEDALLION_R - 12), 6, Riso.PAPER)
	Riso.draw_stone(self, m, MEDALLION_R - 24, p, float(Game.meta.best_distance) / RunState.GOAL)


func _draw_status_tab() -> void:
	var r := Rect2(40, size.y - BAND - 30, 330, 32)
	draw_rect(r, Riso.GOLD)
	draw_rect(r, Riso.INK, false, 2.0)
	Riso.draw_label(self, status_text, r.get_center(), 14, Riso.INK, HORIZONTAL_ALIGNMENT_CENTER)

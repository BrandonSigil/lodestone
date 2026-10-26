extends Node2D
## The starting village hub. Click a place to open its panel:
## the hearth (pick the party), the shop (buy supplies), the mayor (story and side jobs),
## the gate (head out). The pack button arranges the grid inventory; the Lodestone opens the map.

const PANEL_RECT := Rect2(150, 34, 980, 486)

var kit: Outfit
var picked: Array[CharacterDef] = []
var ui: Control
var view: VillageView
var frame: VillageFrame
var panel: PanelContainer
var body: VBoxContainer
var open_id := ""
var message := ""  ## text key shown once in the next panel
var mayor_mode := "hello"
var lore_index := 0
var notice: PackedStringArray = []


func _ready() -> void:
	kit = Game.village_outfit()
	for id in Game.village_party:
		picked.append(Db.character(id))
	if picked.is_empty():
		picked.append(Db.character(&"lead"))
	kit.sync_party(picked)

	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.theme = RisoTheme.make()
	layer.add_child(ui)

	view = VillageView.new()
	view.place_pressed.connect(_on_place)
	ui.add_child(view)
	frame = VillageFrame.new()
	ui.add_child(frame)

	var stone := Button.new()
	stone.flat = true
	stone.tooltip_text = Txt.t("UI_OPEN_MAP")
	stone.position = VillageFrame.MEDALLION - Vector2.ONE * VillageFrame.MEDALLION_R
	stone.size = Vector2.ONE * VillageFrame.MEDALLION_R * 2
	stone.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	stone.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	stone.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	stone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	stone.pressed.connect(_open_map)
	ui.add_child(stone)

	var tabs := [["UI_PACK", _open.bind("pack")], ["UI_OPEN_MAP", _open_map], ["UI_START", _on_place.bind("gate")]]
	for i in tabs.size():
		var b := Button.new()
		b.text = Txt.t(tabs[i][0])
		b.position = Vector2(810 + i * 144, 720 - VillageFrame.BAND - 34)
		b.size = Vector2(134, 36)
		b.pressed.connect(tabs[i][1])
		ui.add_child(b)

	var grain := CanvasLayer.new()
	grain.layer = 5
	grain.add_child(Riso.grain_rect(VillageView.SEED))
	add_child(grain)

	notice = Game.pending_lines
	Game.pending_lines = []
	_refresh()
	if not notice.is_empty():
		_open("notice")


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE and panel:
		_close()


func _refresh() -> void:
	var waiting: Array[CharacterDef] = []
	for d in Db.roster():
		if Game.is_unlocked(d) and not picked.has(d):
			waiting.append(d)
	view.set_people(waiting, picked)
	frame.refresh(picked, kit, Txt.f("UI_STATUS_TAB", [kit.gold, int(Game.meta.runs), int(Game.meta.best_distance)]))
	Game.village_party.clear()
	for d in picked:
		Game.village_party.append(d.id)


func _on_place(id: String) -> void:
	if id == "gate":
		if picked.is_empty():
			message = "UI_PICK_PARTY"
			_open("hearth")
		else:
			Game.start_run(picked, kit)
		return
	if id == "mayor":
		mayor_mode = "hello"
	_open(id)


func _open_map() -> void:
	if ResourceLoader.exists(Game.WORLD_MAP):
		Game.go(Game.WORLD_MAP)
	else:
		notice = [Txt.t("UI_NO_MAP")]
		_open("notice")


# --- panels -----------------------------------------------------------------

func _close() -> void:
	if panel:
		panel.queue_free()
		panel = null
	open_id = ""
	view.set_active(true)


func _open(id: String) -> void:
	if panel:
		panel.queue_free()
	open_id = id
	view.set_active(false)
	panel = PanelContainer.new()
	panel.position = PANEL_RECT.position
	panel.custom_minimum_size = PANEL_RECT.size
	panel.size = PANEL_RECT.size
	ui.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	var title := Label.new()
	title.text = Txt.t({"hearth": "VIL_HEARTH", "shop": "VIL_SHOP", "mayor": "VIL_MAYOR", "pack": "UI_PACK", "notice": "GAME_TITLE"}[id])
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := Button.new()
	x.text = Txt.t("UI_CLOSE")
	x.custom_minimum_size = Vector2(40, 36)
	x.pressed.connect(_close)
	head.add_child(x)
	var rule := ColorRect.new()
	rule.color = Riso.GOLD_DARK
	rule.custom_minimum_size = Vector2(0, 2)
	outer.add_child(rule)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)
	match id:
		"hearth": _fill_team()
		"shop": _fill_shop()
		"pack": _fill_pack()
		"mayor": _fill_mayor()
		"notice": _fill_notice()
	if message != "":
		var m := _label(Txt.t(message), 15)
		m.add_theme_color_override("font_color", Riso.RED)
		body.add_child(m)
		message = ""


func _label(text: String, size := 16, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _fill_notice() -> void:
	for line in notice:
		body.add_child(_label(line, 20))
	notice = []
	var ok := Button.new()
	ok.text = Txt.t("UI_CONTINUE")
	ok.custom_minimum_size = Vector2(120, 38)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ok.pressed.connect(_close)
	body.add_child(ok)


# Team select: every roster member as a card. Locked ones show how to unlock them.
func _fill_team() -> void:
	var used := 0
	for d in picked:
		used += d.party_slots
	body.add_child(_label("%s   %s" % [Txt.t("UI_TEAM_HELP"), Txt.f("UI_SLOTS_USED", [used, Game.PARTY_SLOTS])], 16))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	body.add_child(grid)
	for d in Db.roster():
		grid.add_child(_team_card(d))


func _team_card(d: CharacterDef) -> Control:
	var unlocked := Game.is_unlocked(d)
	var on := picked.has(d)
	var b := Button.new()
	b.custom_minimum_size = Vector2(228, 182)
	b.disabled = not unlocked
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := RisoTheme.card(on or (state == "hover" and unlocked), not unlocked)
		b.add_theme_stylebox_override(state, sb)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_top = 6
	box.offset_left = 8
	box.offset_right = -8
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	b.add_child(box)
	box.add_child(RisoIcon.piece(d, Vector2(80, 70), not unlocked))
	var nm := _label(Txt.t(d.name_key), 15)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(nm)
	var sub := _label(Txt.t(d.class_def.name_key), 12)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Riso.mix(Riso.INK, Riso.PAPER, 0.35))
	box.add_child(sub)
	var tags: Array[String] = []
	if not unlocked:
		tags.append(Txt.t("UNLOCK_" + d.unlock.to_upper()))
	else:
		for k in d.off_skills:
			tags.append("%s +%d" % [k, d.off_skills[k]])
		for p in d.perks:
			tags.append(String(p))
		if d.deficiency != &"":
			tags.append("(-) " + String(d.deficiency))
		if d.party_slots > 1:
			tags.append(Txt.f("UI_TAKES_SLOTS", d.party_slots))
		if d.inventory_slots > 0:
			tags.append(Txt.f("UI_TAKES_PACK", d.inventory_slots))
	var t := _label(", ".join(tags), 11)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	for c in box.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.pressed.connect(_toggle.bind(d))
	return b


func _toggle(d: CharacterDef) -> void:
	var used := 0
	for m in picked:
		used += m.party_slots
	if picked.has(d):
		picked.erase(d)
	elif used + d.party_slots > Game.PARTY_SLOTS:
		message = "TEAM_FULL"
	elif not kit.gear_fits(d):
		message = "TEAM_NO_ROOM"
	else:
		picked.append(d)
	kit.sync_party(picked)
	_refresh()
	_open("hearth")


# Shop: buy into the first free spot in the pack. Selling happens in the pack.
func _fill_shop() -> void:
	var top := HBoxContainer.new()
	body.add_child(top)
	var hello := _label(Txt.t("SHOP_HELLO"), 16)
	hello.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(hello)
	top.add_child(_label(Txt.f("UI_GOLD", kit.gold), 20, false))
	var pack := Button.new()
	pack.text = Txt.t("UI_PACK")
	pack.custom_minimum_size = Vector2(110, 38)
	pack.pressed.connect(_open.bind("pack"))
	top.add_child(pack)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	body.add_child(grid)
	for id in Db.shop_items():
		grid.add_child(_shop_row(id))


func _shop_row(id: String) -> Control:
	var it: Dictionary = Db.items[id]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", RisoTheme.card())
	card.custom_minimum_size = Vector2(462, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	row.add_child(RisoIcon.item(id, 18))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	col.add_child(_label(Txt.t(it.name_key), 17))
	var what: Array[String] = []
	if int(it.food) > 0:
		what.append(Txt.f("UI_FOOD", int(it.food)))
	if int(it.medicine) > 0:
		what.append(Txt.f("UI_MEDICINE", int(it.medicine)))
	what.append(Txt.f("UI_CELLS", InventoryGrid.parse_shape(it.shape).size()))
	var sub := _label("  ".join(what), 12)
	sub.add_theme_color_override("font_color", Riso.mix(Riso.INK, Riso.PAPER, 0.35))
	col.add_child(sub)
	var price := _label(Txt.f("UI_PRICE", int(it.price)), 18, false)
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(price)
	var buy := Button.new()
	buy.text = Txt.t("UI_BUY")
	buy.custom_minimum_size = Vector2(76, 38)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.disabled = kit.gold < int(it.price)
	buy.pressed.connect(_buy.bind(id))
	row.add_child(buy)
	return card


func _buy(id: String) -> void:
	message = kit.buy(id)
	_refresh()
	_open("shop")


# Pack: the grid you arrange by hand.
var _pack_totals: Label


func _fill_pack() -> void:
	body.add_child(_label(Txt.t("UI_PACK_HELP"), 15))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	body.add_child(row)
	var pv := PackView.new()
	pv.setup(kit)
	row.add_child(pv)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	row.add_child(side)
	_pack_totals = _label("", 18)
	side.add_child(_pack_totals)
	var shop := Button.new()
	shop.text = Txt.t("VIL_SHOP")
	shop.custom_minimum_size = Vector2(160, 38)
	shop.pressed.connect(_open.bind("shop"))
	side.add_child(shop)
	pv.changed.connect(_pack_changed)
	_pack_changed()


func _pack_changed() -> void:
	_pack_totals.text = "\n".join([Txt.f("UI_FOOD", kit.food()), Txt.f("UI_MEDICINE", kit.medicine()), Txt.f("UI_GOLD", kit.gold),
		Txt.f("UI_SLOTS_USED", [kit.bag.used_cells(), kit.bag.capacity()])])
	_refresh()


# Mayor: placeholder story lines and side jobs. Brandon writes the real ones.
class MayorPortrait extends Control:
	func _draw() -> void:
		var p := Riso.palette_at(VillageView.S)
		draw_circle(Vector2(size.x * 0.5, size.y * 0.55), size.x * 0.48, Riso.mix(Riso.PAPER, Riso.GOLD, 0.3))
		Riso.draw_stamp_star(self, Vector2(size.x * 0.5, 34), 14, Riso.GOLD)
		Riso.draw_piece(self, Vector2(size.x * 0.5, size.y - 18), size.y * 0.72, Riso.mix(Riso.INDIGO, Riso.BASE, 0.15), {"hat": "point", "stone": p.accent})
		draw_rect(Rect2(size.x * 0.5 - 22, size.y - 18 - size.y * 0.72 * 0.36, 44, 8), Riso.GOLD)


func _fill_mayor() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	body.add_child(row)
	var face := MayorPortrait.new()
	face.custom_minimum_size = Vector2(220, 300)
	row.add_child(face)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	match mayor_mode:
		"hello":
			col.add_child(_label(Txt.t("MAYOR_HELLO"), 20))
			col.add_child(_label(Txt.f("MAYOR_PROVE", Game.bonus_gold()), 16))
		"lore":
			col.add_child(_label(Txt.t("MAYOR_LORE_%d" % (lore_index % 3 + 1)), 20))
		"work":
			col.add_child(_label(Txt.t("MAYOR_WORK"), 20))
			for q in Db.quests:
				col.add_child(_quest_row(q))
	var opts := HBoxContainer.new()
	opts.add_theme_constant_override("separation", 10)
	col.add_child(opts)
	for spec in [["MAYOR_OPT_LORE", _mayor.bind("lore")], ["MAYOR_OPT_WORK", _mayor.bind("work")], ["MAYOR_OPT_BYE", _close]]:
		var b := Button.new()
		b.text = Txt.t(spec[0])
		b.custom_minimum_size = Vector2(0, 38)
		b.pressed.connect(spec[1])
		opts.add_child(b)


func _quest_row(q: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", RisoTheme.card(Game.has_quest(q.id)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var t := _label(Txt.t(q.text_key), 16)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	row.add_child(_label(Txt.f("UI_REWARD", int(q.reward_gold)), 16))
	var b := Button.new()
	b.text = Txt.t("UI_TAKEN" if Game.has_quest(q.id) else "UI_TAKE")
	b.disabled = Game.has_quest(q.id)
	b.pressed.connect(func() -> void:
		Game.take_quest(q.id)
		_open("mayor"))
	row.add_child(b)
	return card


func _mayor(mode: String) -> void:
	if mode == "lore" and mayor_mode == "lore":
		lore_index += 1
	mayor_mode = mode
	_open("mayor")

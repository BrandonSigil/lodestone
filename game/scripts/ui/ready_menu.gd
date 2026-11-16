class_name ReadyMenu
extends RefCounted
## The get-ready screen at the village gate ([USER] 2026-11-16, backlog P31, docs/design/ready-screen.md): one window
## with three tabs (PARTY, PACK, SUPPLIES) and a road panel beside them that always shows the food in days, the
## warnings and LEAVE. Few words: the panel warns only about early snags (short food, someone Spent, a full pack).
## The destination is picked on the world map after ([USER] 2026-11-16: "Get to the open world then pick").

const TABS := ["party", "pack", "supplies"]
const TAB_TEXT := {"party": "UI_PARTY", "pack": "UI_PACK", "supplies": "READY_SUPPLIES"}
const WARN := Color(1.0, 0.72, 0.55)


## Fill `box` (a menu window's body). go: reopen on a tab (id); leave: out of the gate; stay: close, back to the map.
static func open(box: VBoxContainer, which: String, go: Callable, leave: Callable, stay: Callable) -> void:
	if not TABS.has(which):
		which = "party"
	MenuKit.title_on(box, Txt.t("READY_TITLE"))
	var items := []
	for id: String in TABS:
		items.append({"id": id, "text": Txt.t(String(TAB_TEXT[id]))})
	box.add_child(MenuKit.tabs(items, which, go))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size = Vector2(1000, 300)  # the same size on every tab, so the window doesn't jump
	box.add_child(row)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(page)
	var again := go.bind(which)
	match which:
		"pack":
			AdventureMenu.pack(page, again, stay)
		"supplies":
			_supplies(page, again)
		_:
			_party(page, again)
	_road(row, go, leave, stay)
	ContainerUi.bare(box, null, stay)  # the frame's X stays in town
	AdventureMenu._esc_closes(box)


# --- PARTY ------------------------------------------------------------------------------------------

static func _party(page: VBoxContainer, again: Callable) -> void:
	var cards := HFlowContainer.new()
	cards.add_theme_constant_override("h_separation", 10)
	cards.add_theme_constant_override("v_separation", 10)
	cards.custom_minimum_size.x = 560
	page.add_child(cards)
	for id: String in _roster():
		cards.add_child(_card(id, again))
	var strip := HBoxContainer.new()  # what the party covers in a fight
	strip.add_theme_constant_override("separation", 8)
	page.add_child(strip)
	strip.add_child(MenuKit.label(Txt.f("READY_PARTY_COUNT", [Game.adventure_defs().size(), Game.party_max()]), UiSkin.T_BODY, MenuKit.TEXT_DIM))
	var cover := ReadyRules.cover(Game.adventure_defs())
	for r: String in ReadyRules.ROLES:
		var n := int(cover[r])
		strip.add_child(MenuKit.chip("%s %d" % [Txt.t("READY_ROLE_" + r.to_upper()), n], "", MenuKit.TEXT if n > 0 else MenuKit.TEXT_DIM,
			Txt.t("READY_ROLE_" + r.to_upper() + "_TIP"), UiSkin.T_SMALL))


## Everyone the hero has met and could bring (dev mode: everyone with art), the hero first.
static func _roster() -> Array[String]:
	var out: Array[String] = []
	for id in Game.ADVENTURE_ROSTER:
		if Game.dev_mode or Game.is_unlocked(Db.character(StringName(id))) or Game.in_party(String(id)):
			out.append(String(id))
	return out


## One character: face, name, what they do in a fight, what they eat, and whether they come. Click to bring or leave
## them; the hero always comes.
static func _card(id: String, again: Callable) -> Button:
	var d := Db.character(StringName(id))
	var going := Game.in_party(id)
	var card := Button.new()
	card.custom_minimum_size = Vector2(132, 168)
	card.toggle_mode = true
	card.button_pressed = going
	card.disabled = id == "lead"
	card.tooltip_text = Txt.t(d.name_key)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 3)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(col)
	var face := AdventureMenu._face(id, d.tint, 64)
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(face)
	var name := MenuKit.label(Txt.t(d.name_key), UiSkin.T_BODY, UiTheme.PARCHMENT)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.clip_text = true
	col.add_child(name)
	var roles := HBoxContainer.new()
	roles.alignment = BoxContainer.ALIGNMENT_CENTER
	roles.add_theme_constant_override("separation", 4)
	col.add_child(roles)
	for r in ReadyRules.roles(d):
		roles.add_child(MenuKit.label(Txt.t("READY_ROLE_" + r.to_upper()), UiSkin.T_SMALL, MenuKit.TEXT_DIM))
	var eats := Txt.f("READY_EATS", d.food_per_day) if d.food_per_day > 0 else Txt.t("READY_EATS_NONE")
	if d.party_slots > 1:
		eats += "  " + Txt.f("READY_SLOTS", d.party_slots)
	var e := MenuKit.label(eats, UiSkin.T_SMALL, MenuKit.TEXT_DIM)
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(e)
	var tired := going and Game.spent(id)
	var tag := MenuKit.label(Txt.t("UI_SPENT_TAG" if tired else ("UI_PICK_IN" if going else "UI_PICK_OUT")), UiSkin.T_SMALL,
		WARN if tired else (UiTheme.GOLD if going else UiTheme.PARCHMENT_DARK))
	if tired:
		card.tooltip_text += "\n" + Txt.t("UI_SPENT_TIP")
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tag)
	for c in col.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate = Color.WHITE if going else Color(0.72, 0.72, 0.72)
	card.pressed.connect(func() -> void:
		if id == "lead":
			return
		if Game.in_party(id):
			Game.dismiss(id)
		else:
			if not Game.is_unlocked(d):
				Game.set_flag(d.unlock)  # dev mode: met on the spot
			if not Game.invite(id):
				Sfx.play("error")
		again.call())
	return card


# --- SUPPLIES ---------------------------------------------------------------------------------------

## The town chest beside the pack: a click moves one, ALL moves the lot.
static func _supplies(page: VBoxContainer, again: Callable) -> void:
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	page.add_child(cols)
	var chest := Game.chest()
	var mine := {}
	for id: String in Db.items:
		var kind := String(Db.items[id].kind)
		if kind in ["food", "med", "gear", "meal", "tonic"] and Game.run.item_count(id) > 0:
			mine[id] = Game.run.item_count(id)
	_column(cols, Txt.t("READY_CHEST"), chest, true, again)
	_column(cols, Txt.t("READY_IN_PACK"), mine, false, again)


static func _column(parent: Control, heading: String, items: Dictionary, to_pack: bool, again: Callable) -> void:
	var col := MenuKit.card(parent, heading)
	col.custom_minimum_size.x = 300
	if items.is_empty():
		col.add_child(MenuKit.label(Txt.t("READY_EMPTY"), UiSkin.T_BODY, MenuKit.TEXT_DIM))
		return
	var ids := items.keys()
	ids.sort()
	for id: String in ids:
		if not Db.items.has(id):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		col.add_child(row)
		row.add_child(MenuKit.icon_rect(id, 26))
		var l := MenuKit.label(Txt.t(String(Db.items[id].name_key)), UiSkin.T_BODY)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		l.tooltip_text = Txt.t(String(Db.items[id].name_key))
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(l)
		row.add_child(MenuKit.label("x%d" % int(items[id]), UiSkin.T_BODY, MenuKit.TEXT_DIM))
		var one := Button.new()
		one.text = Txt.t("READY_TAKE" if to_pack else "READY_STORE")
		one.custom_minimum_size = Vector2(66, 30)
		one.add_theme_font_size_override("font_size", UiSkin.T_SMALL)
		one.pressed.connect(func() -> void:
			if not Game.chest_move(id, to_pack):
				Sfx.play("error")
			again.call())
		row.add_child(one)
		if int(items[id]) > 1:
			var all := Button.new()
			all.text = Txt.t("READY_ALL")
			all.theme_type_variation = &"QuietButton"
			all.custom_minimum_size = Vector2(44, 30)
			all.add_theme_font_size_override("font_size", UiSkin.T_SMALL)
			all.pressed.connect(func() -> void:
				for i in int(items[id]):
					if not Game.chest_move(id, to_pack):
						break
				again.call())
			row.add_child(all)
		else:
			var gap := Control.new()  # keeps the buttons in one column
			gap.custom_minimum_size.x = 44
			row.add_child(gap)


# --- the road panel ---------------------------------------------------------------------------------

static func _road(parent: Control, go: Callable, leave: Callable, stay: Callable) -> void:
	var col := MenuKit.card(parent, Txt.t("READY_ROAD"))
	col.custom_minimum_size.x = 250
	var run := Game.run
	var r := CampRules.ration(Db.camp_rations, String(Game.meta.get("settings", {}).get("camp_ration", CampRules.FILLING)))
	var days := CampRules.food_days(run, r)
	var warn_days := int(Db.levels.get("gate_warn_days", 3))
	col.add_child(MenuKit.label(Txt.t("CAMP_FOOD_PLENTY") if days >= 99 else Txt.f("CAMP_FOOD_DAYS", days), UiSkin.T_HEAD,
		MenuKit.TEXT if days >= warn_days else WARN))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	col.add_child(chips)
	chips.add_child(MenuKit.chip(Txt.f("READY_PARTY_COUNT", [Game.adventure_defs().size(), Game.party_max()]), "", MenuKit.TEXT, "", UiSkin.T_SMALL))
	if run.medicine > 0:
		chips.add_child(MenuKit.chip(str(run.medicine), RunState.MED_ITEM, MenuKit.TEXT, Txt.t("READY_MEDICINE_TIP"), UiSkin.T_SMALL))
	if run.item_count("rod") > 0:
		chips.add_child(MenuKit.chip(Txt.t("ITEM_ROD"), "rod", MenuKit.TEXT, "", UiSkin.T_SMALL))
	var spent: Array = []
	for m in run.alive():
		if Game.spent(String((m.def as CharacterDef).id)):
			spent.append(Txt.t((m.def as CharacterDef).name_key))
	for w: Dictionary in ReadyRules.warnings(days, warn_days, spent, run.overfull()):
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		col.add_child(line)
		var l := MenuKit.label(Txt.f(String(w.key), w.arg) if str(w.arg) != "" else Txt.t(String(w.key)), UiSkin.T_BODY, WARN)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 170
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(l)
		var fix := Button.new()
		fix.text = Txt.t("READY_FIX")
		fix.theme_type_variation = &"QuietButton"
		fix.add_theme_font_size_override("font_size", UiSkin.T_SMALL)
		fix.pressed.connect(go.bind(String(w.tab)))
		line.add_child(fix)
	var push := Control.new()
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(push)
	var out := MenuKit.primary(Txt.t("READY_LEAVE"), leave, UiSkin.T_LEAD, 230.0)
	col.add_child(out)
	var home := Button.new()
	home.text = Txt.t("OPT_STAY")
	home.theme_type_variation = &"QuietButton"
	home.pressed.connect(stay)
	col.add_child(home)

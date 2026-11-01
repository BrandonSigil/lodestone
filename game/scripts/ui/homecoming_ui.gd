class_name HomecomingUi
extends Control
## The homecoming page ([USER] 2026-11-01 Pitch J): one full page after every return, a fall or GO HOME. Top to bottom:
## the wake-up line, then what the trip gave (materials banked, XP and levels, bond points, morale changes), on the
## right the boss card just learned (on a fall it leads), new knowledge and the restore steps that just finished, and at
## the foot the next goal with a bar for each thing it needs ("METAL 2 OF 3"). OK closes it and the square is playable.
## The numbers come from HomecomingRules; every word is a key in text/placeholder.csv.

signal done

const PAGE := Vector2(940, 0)
const SECTION_W := 450.0

var s: Dictionary = {}  ## HomecomingRules.summary + "headline"
var goal: Dictionary = {}  ## HomecomingRules.next_goal
var _ok: Button


static func make(summary: Dictionary) -> HomecomingUi:
	var ui := HomecomingUi.new()
	ui.s = summary
	ui.goal = HomecomingRules.next_goal(Db.restore, Game.meta.restore, Game.meta.tracked, Game.meta.materials, Game.meta.flags)
	return ui


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.05, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"DialogPanel"
	panel.custom_minimum_size = PAGE
	center.add_child(panel)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	panel.add_child(page)
	_header(page)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(cols)
	var left := _column(cols)
	var right := _column(cols)
	if bool(s.get("fell", false)) and not Array(s.get("cards", [])).is_empty():
		_cards(left)  # a fall leads with what the party learned
		_materials(right)
		_levels(right)
	else:
		_materials(left)
		_levels(left)
		_cards(right)
	_bonds(left)
	_morale(left)
	_knowledge(right)
	_restored(right)
	page.add_child(HSeparator.new())
	_goal(page)
	_ok = Button.new()
	_ok.text = Txt.t("UI_HC_OK")
	_ok.custom_minimum_size = Vector2(220, 46)
	_ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	_ok.add_theme_font_size_override("font_size", 20)
	_ok.pressed.connect(close)
	page.add_child(_ok)
	_ok.grab_focus.call_deferred()
	UiTheme.pop_in_later(panel)


func close() -> void:
	done.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and (event.is_action("ui_cancel") or event.is_action("ui_accept")):
		get_viewport().set_input_as_handled()
		close()


# --- sections ----------------------------------------------------------------------------------

func _header(page: VBoxContainer) -> void:
	var title := Label.new()
	title.theme_type_variation = &"MenuTitle"
	title.text = Txt.t("UI_HC_TITLE_FELL" if bool(s.get("fell", false)) else "UI_HC_TITLE_HOME")
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(title)
	var line := String(s.get("headline", ""))
	if line != "":
		var l := _label(page, line, 17)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", UiTheme.PARCHMENT_DARK)


func _materials(col: VBoxContainer) -> void:
	var box := _section(col, "UI_HC_MATERIALS")
	var mats: Dictionary = s.get("materials", {})
	if mats.is_empty():
		_quiet(box, "UI_HC_NONE")
		return
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
	box.add_child(row)
	var ids := mats.keys()
	ids.sort()
	for id: String in ids:
		var chip := PanelContainer.new()
		chip.theme_type_variation = &"InfoPanel"
		row.add_child(chip)
		var name := Txt.t(String(Db.items[id].name_key)) if Db.items.has(id) else id
		_label(chip, "%s  +%d" % [name, int(mats[id])], 16)


func _levels(col: VBoxContainer) -> void:
	var rows: Array = s.get("levels", [])
	if rows.is_empty():
		return
	var box := _section(col, "UI_HC_LEVELS")
	for r: Dictionary in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		box.add_child(line)
		var who := _label(line, _name(String(r.id)), 16)
		who.custom_minimum_size = Vector2(150, 0)
		var lv := Txt.f("UI_HC_LEVEL_UP", [int(r.from), int(r.to)]) if int(r.to) > int(r.from) else Txt.f("UI_HC_LEVEL", int(r.to))
		var l := _label(line, lv, 16)
		if int(r.to) > int(r.from):
			l.add_theme_color_override("font_color", UiTheme.GOLD)
		var bar := _bar(line, int(r.xp_now), int(r.xp_per))
		bar.custom_minimum_size = Vector2(90, 12)
		_label(line, Txt.f("UI_HC_XP", int(r.xp)), 14)


func _bonds(col: VBoxContainer) -> void:
	var rows: Array = s.get("bonds", [])
	if rows.is_empty():
		return
	var box := _section(col, "UI_HC_BONDS")
	for r: Dictionary in rows:
		var ids := String(r.key).split("+")
		var pair := "%s + %s" % [_name(ids[0]), _name(ids[1] if ids.size() > 1 else "")]
		var lv0 := BondRules.level(int(r.from), Db.bonds)
		var lv1 := BondRules.level(int(r.to), Db.bonds)
		var text := Txt.f("UI_HC_BOND", [pair, int(r.to) - int(r.from)])
		if lv1 > lv0:
			text += "   " + Txt.f("UI_HC_BOND_LEVEL", lv1)
		var l := _label(box, text, 15)
		if lv1 > lv0:
			l.add_theme_color_override("font_color", UiTheme.GOLD)


## Morale is per character ([USER] 2026-10-31 design-goodboy; MoraleRules): who went up or down on the trip, with the
## band they're in now, and the journey days gone (each one lifts whoever stayed home, [USER] design-morale).
func _morale(col: VBoxContainer) -> void:
	var rows: Array = s.get("morale", [])
	var days := int(s.get("days", 0))
	if rows.is_empty() and days <= 0:
		return
	var box := _section(col, "UI_HC_MORALE")
	if days > 0:
		_label(box, Txt.f("UI_HC_DAYS", days), 14).add_theme_color_override("font_color", UiTheme.PARCHMENT_DARK)
	for r: Dictionary in rows:
		var d := int(r.to) - int(r.from)
		var band := MoraleRules.band(int(r.to), Db.morale_bands)
		var l := _label(box, Txt.f("UI_HC_MORALE_LINE", [_name(String(r.id)), int(r.from), int(r.to), "+%d" % d if d > 0 else str(d)])
			+ "   " + Txt.t(String(band.get("name_key", ""))), 15)
		l.add_theme_color_override("font_color", UiTheme.GOLD if d > 0 else Color(0.95, 0.55, 0.45))


## A boss's card, learned on the first fight with him ([USER] design-boss-retry): his HP and every move, now shown.
func _cards(col: VBoxContainer) -> void:
	for cid: String in Array(s.get("cards", [])):
		if not ResourceLoader.exists("res://data/classes/%s.tres" % cid):
			continue
		var c := Db.class_def(cid)
		var box := _section(col, "UI_HC_CARD")
		var card := PanelContainer.new()
		card.theme_type_variation = &"InfoPanel"
		box.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		card.add_child(v)
		var name := _label(v, Txt.t(c.name_key), 20)
		name.add_theme_color_override("font_color", UiTheme.GOLD)
		_label(v, "%s %d   %s %d   %s %d" % [Txt.t("UI_STAT_HP"), c.max_hp, Txt.t("UI_STAT_ARMOR"), c.armor,
			Txt.t("UI_HC_MOVE"), c.move], 15)
		for aid in c.abilities:
			var a := Db.ability(String(aid))
			if a == null:
				continue
			var desc := "DESC_" + a.id.to_upper()
			var t := Txt.t(a.name_key)
			if Txt.t(desc) != desc:
				t += ": " + Txt.t(desc)
			var l := _label(v, t, 13)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(SECTION_W - 40, 0)


func _knowledge(col: VBoxContainer) -> void:
	var k: Dictionary = s.get("knowledge", {})
	if k.is_empty():
		return
	var box := _section(col, "UI_HC_KNOW")
	for kind: String in ["got", "beaten", "passed"]:
		if k.has(kind):
			_label(box, Txt.f("UI_HC_KNOW_" + kind.to_upper(), int(k[kind])), 15)


func _restored(col: VBoxContainer) -> void:
	var ids: Array = s.get("restored", [])
	if ids.is_empty():
		return
	var box := _section(col, "UI_HC_RESTORED")
	for id: String in ids:
		for r: Dictionary in Db.restore:
			if String(r.id) == id:
				var l := _label(box, "%s: %s" % [Txt.t("BUILDING_" + String(r.building).to_upper()), Txt.t(String(r.name_key))], 16)
				l.add_theme_color_override("font_color", UiTheme.GOLD)


## The page closes on the next goal ("2 of 3 metal"): the reason for one more run.
func _goal(page: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	page.add_child(row)
	var head := Label.new()
	head.theme_type_variation = &"SubTitle"
	head.text = Txt.t("UI_HC_NEXT")
	head.add_theme_font_size_override("font_size", 18)
	row.add_child(head)
	if goal.is_empty():
		_label(row, Txt.t("UI_HC_NO_GOAL"), 17)
		return
	var r: Dictionary = goal.row
	var name := _label(row, "%s: %s" % [Txt.t("BUILDING_" + String(r.building).to_upper()), Txt.t(String(r.name_key))], 17)
	name.add_theme_color_override("font_color", UiTheme.GOLD)
	for p: Dictionary in goal.parts:
		var part := VBoxContainer.new()
		part.add_theme_constant_override("separation", 2)
		row.add_child(part)
		var item := Txt.t(String(Db.items[p.id].name_key)) if Db.items.has(String(p.id)) else String(p.id)
		_label(part, Txt.f("UI_HC_OF", [int(p.have), int(p.need), item]), 14)
		var bar := _bar(part, int(p.have), int(p.need))
		bar.custom_minimum_size = Vector2(110, 10)
	if bool(goal.get("ready", false)):
		_label(row, Txt.t("UI_RESTORE_READY"), 15)


# --- pieces ------------------------------------------------------------------------------------

func _column(parent: HBoxContainer) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(SECTION_W, 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(v)
	return v


func _section(col: VBoxContainer, key: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	col.add_child(box)
	var head := Label.new()
	head.theme_type_variation = &"SubTitle"
	head.text = Txt.t(key)
	box.add_child(head)
	return box


func _quiet(box: Control, key: String) -> void:
	var l := _label(box, Txt.t(key), 15)
	l.add_theme_color_override("font_color", Color(UiTheme.PARCHMENT, 0.55))


func _label(parent: Control, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	return l


func _bar(parent: Control, have: int, need: int) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = maxi(1, need)
	b.value = clampi(have, 0, maxi(1, need))
	b.show_percentage = false
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_stylebox_override("background", UiTheme.box(Color(UiTheme.INK, 0.6), Color(UiTheme.PARCHMENT, 0.4), 1, 0.0, 3))
	b.add_theme_stylebox_override("fill", UiTheme.box(UiTheme.GOLD, UiTheme.GOLD, 0, 0.0, 3))
	parent.add_child(b)
	return b


static func _name(id: String) -> String:
	var d := Db.character(StringName(id))
	return Txt.t(d.name_key) if d else id

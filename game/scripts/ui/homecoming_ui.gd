class_name HomecomingUi
extends Control
## The homecoming page ([USER] 2026-11-01 Pitch J): one page after every return, a fall or GO HOME, as one kit window
## ([USER] 2026-11-01 "I like the second home again screen all in one page"; round 2 mockup C). The HOME AGAIN plate
## on its top rim, the X at its top right (OK's continue), the wake-up line under it; then three cards side by side:
## BROUGHT HOME (each material banked as an item slot with its +N), PARTY (a row per piece: round face, its level, the
## XP bar and the XP gained) and FRIENDS (morale: who moved and by how much, a heart in the band's colour; the bond
## pairs that grew; four rows, then SHOW ALL, and the card scrolls). A boss card just learned, new knowledge and the
## restore steps just finished make a second row (on a fall it leads). At the foot, NEXT: the next goal, one chip per
## thing it needs ("0/4"), and the gold ONE MORE GO. Only what changed is shown. The numbers come from HomecomingRules;
## every word is a key in text/placeholder.csv.

signal done

const COL_W := 300.0  ## a card's width
const BAR_LABEL := 64.0  ## room for a bar's name
const COL_H := 380.0  ## the three cards' height: four rows of friends and SHOW ALL fit whole, the rest scroll
const COL_H_SHORT := 236.0  ## the same with a second row of cards on the page (a fall's boss card): three rows fit
const ROWS := 4  ## rows a card shows before SHOW ALL
const FACE := 44.0
const FRAME_ROOM := 96.0  ## the bottom frame's height, kept clear

var s: Dictionary = {}  ## HomecomingRules.summary + "headline"
var goal: Dictionary = {}  ## HomecomingRules.next_goal
var _ok: Button
var _col_h := COL_H


static func make(summary: Dictionary) -> HomecomingUi:
	var ui := HomecomingUi.new()
	ui.s = summary
	ui.goal = HomecomingRules.next_goal(Db.restore, Game.meta.restore, Game.meta.tracked, Game.meta.materials, Game.meta.flags)
	return ui


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.05, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()  # above the bottom frame, which stays in view (mockup C)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -FRAME_ROOM
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var title := Txt.t("UI_HC_TITLE_FELL" if bool(s.get("fell", false)) else "UI_HC_TITLE_HOME")
	# an X at its top right (OK's continue), and the page scrolls when it runs past the window ([USER] 2026-11-01 X11)
	var w := MenuKit.window(title, func() -> Rect2: return get_viewport_rect().grow_individual(-20.0, -20.0, -20.0, -FRAME_ROOM), close, 40)
	center.add_child(w.root)
	var page: VBoxContainer = w.body
	var line := String(s.get("headline", ""))
	if line != "":
		var l := MenuKit.label(line, 19, MenuKit.TEXT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = COL_W * 2.0
		page.add_child(l)
	var extra := _extras()  # a boss card, knowledge, restored: a row of their own
	if extra != null:
		_col_h = COL_H_SHORT  # the page still fits the screen
	var fell_first := bool(s.get("fell", false)) and not Array(s.get("cards", [])).is_empty()
	if fell_first and extra != null:
		page.add_child(extra)  # a fall leads with what the party learned
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(cols)
	_materials(cols)
	_levels(cols)
	_friends(cols)
	if not fell_first and extra != null:
		page.add_child(extra)
	_goal(w.foot)
	_ok = MenuKit.primary(Txt.t("UI_HC_OK"), close, 22, 250.0)
	w.foot.add_child(_ok)
	_ok.grab_focus.call_deferred()
	UiTheme.pop_in_later(w.panel)


func close() -> void:
	done.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and (event.is_action("ui_cancel") or event.is_action("ui_accept")):
		get_viewport().set_input_as_handled()
		close()


# --- sections ----------------------------------------------------------------------------------

## A card of the top row: its heading, a column that scrolls when its rows run past the card (with a thin bar), all
## three the same height. Returns the column.
func _card(parent: Control, key: String) -> VBoxContainer:
	var v := MenuKit.card(parent, Txt.t(key))
	v.get_parent().custom_minimum_size = Vector2(COL_W, _col_h)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	return rows


func _materials(cols: HBoxContainer) -> void:
	var box := _card(cols, "UI_HC_MATERIALS")
	var mats: Dictionary = s.get("materials", {})
	if mats.is_empty():
		_quiet(box, "UI_HC_NONE")
		return
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(grid)
	var ids := mats.keys()
	ids.sort()
	for id: String in ids:
		var cell := VBoxContainer.new()  # the item in its slot, the number in a chip under it (mockup C)
		cell.add_theme_constant_override("separation", 6)
		grid.add_child(cell)
		var name := Txt.t(String(Db.items[id].name_key)) if Db.items.has(id) else id
		var sl := MenuKit.slot(id, 0, 76.0, name)
		sl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(sl)
		var c := MenuKit.chip("+%d" % int(mats[id]), "", MenuKit.TEXT, "", 17)
		c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(c)


func _levels(cols: HBoxContainer) -> void:
	var box := _card(cols, "UI_HC_LEVELS")
	var rows: Array = s.get("levels", [])
	if rows.is_empty():
		_quiet(box, "UI_HC_NONE")
		return
	for r: Dictionary in rows:
		var line := _row(box, String(r.id))
		var mid := VBoxContainer.new()
		mid.add_theme_constant_override("separation", 3)
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_child(mid)
		var up := int(r.to) > int(r.from)
		var lv := Txt.f("UI_HC_LEVEL_UP", [int(r.from), int(r.to)]) if up else Txt.f("UI_HC_LEVEL", int(r.to))
		mid.add_child(MenuKit.label(lv, 16, MenuKit.GOLD if up else MenuKit.TEXT))
		var bar := UiBar.new()
		var d := Db.character(StringName(String(r.id)))
		bar.fill = d.tint.lightened(0.15) if d else VictoryUi.XP_GOLD  # each member's own colour (mockup C)
		bar.value = float(r.xp_now) / maxf(1.0, float(r.xp_per))
		bar.tooltip_text = "%d/%d" % [int(r.xp_now), int(r.xp_per)]
		bar.mouse_filter = Control.MOUSE_FILTER_STOP
		bar.custom_minimum_size = Vector2(100, 16)
		mid.add_child(bar)
		line.add_child(MenuKit.chip("+%d" % int(r.xp), "", MenuKit.TEXT, Txt.f("UI_HC_XP", int(r.xp)), 16))


## FRIENDS: morale per character ([USER] 2026-10-31 design-goodboy; MoraleRules), the biggest moves first, a heart in the
## band's colour and the change in a chip (the band's name on hover); then the bond pairs that grew (two faces, a
## heart, the points; gold on a new bond level). Four rows, then SHOW ALL ([USER]-approved mockup C; research: "at most
## 7 rows before show all"); the journey days gone (each one lifts whoever stayed home) on the heading's hover.
func _friends(cols: HBoxContainer) -> void:
	var box := _card(cols, "UI_HC_MORALE")
	var lines: Array = []
	var morale: Array = s.get("morale", []).duplicate()
	morale.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absi(int(a.to) - int(a.from)) > absi(int(b.to) - int(b.from)))
	for r: Dictionary in morale:
		lines.append(_morale_row.bind(r))
	for r: Dictionary in Array(s.get("bonds", [])):
		lines.append(_bond_row.bind(r))
	var days := int(s.get("days", 0))
	if lines.is_empty() and days <= 0:
		_quiet(box, "UI_HC_NONE")
		return
	var rest: Array[Control] = []
	for i in lines.size():
		var row: Control = (lines[i] as Callable).call(box)
		if i >= ROWS:
			row.visible = false
			rest.append(row)
	if not rest.is_empty():
		var more := Button.new()
		more.theme_type_variation = &"QuietButton"
		more.text = Txt.t("UI_HC_SHOW_ALL")
		more.custom_minimum_size.y = 36
		more.add_theme_font_size_override("font_size", 15)
		more.pressed.connect(func() -> void:
			for r in rest:
				r.visible = true
			more.queue_free())
		box.add_child(more)
	if days > 0:  # the journey days gone, on the heading's hover: the card shows only rows
		var head := box.get_parent().get_parent().get_child(0) as Control
		head.tooltip_text = Txt.f("UI_HC_DAYS", days)
		head.mouse_filter = Control.MOUSE_FILTER_PASS
		for c in head.get_children():
			(c as Control).mouse_filter = Control.MOUSE_FILTER_PASS
		(head.get_child(0) as Control).tooltip_text = head.tooltip_text


func _morale_row(box: VBoxContainer, r: Dictionary) -> Control:
	var d := int(r.to) - int(r.from)
	var band := MoraleRules.band(int(r.to), Db.morale_bands)
	var line := _row(box, String(r.id))
	line.tooltip_text = "%s   %s" % [_name(String(r.id)), Txt.t(String(band.get("name_key", "")))]
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	var bars := VBoxContainer.new()  # HP, mana or rage, Morale, thin and labelled ([USER] 2026-11-02)
	bars.add_theme_constant_override("separation", 2)
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_child(bars)
	_vitals(bars, String(r.id))
	line.add_child(MenuKit.chip("+%d" % d if d > 0 else str(d), "", VictoryUi.UP_GREEN if d > 0 else VictoryUi.DOWN_RED, "", 17))
	return line


func _bond_row(box: VBoxContainer, r: Dictionary) -> Control:
	var ids := String(r.key).split("+")
	var lv0 := BondRules.level(int(r.from), Db.bonds)
	var lv1 := BondRules.level(int(r.to), Db.bonds)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	line.tooltip_text = Txt.f("UI_HC_BOND", ["%s + %s" % [_name(ids[0]), _name(ids[1] if ids.size() > 1 else "")], int(r.to) - int(r.from)])
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(line)
	line.add_child(MenuKit.portrait(ids[0], 40))
	line.add_child(MenuKit.icon_rect("heal", 24))
	line.add_child(MenuKit.portrait(ids[1] if ids.size() > 1 else "", 40))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(gap)
	var text := "+%d" % (int(r.to) - int(r.from))
	if lv1 > lv0:
		text = Txt.f("UI_HC_BOND_LEVEL", lv1)
	line.add_child(MenuKit.chip(text, "", MenuKit.GOLD if lv1 > lv0 else MenuKit.TEXT, "", 16))
	return line


## The second row: a boss card just learned ([USER] design-boss-retry: his HP and every move, now shown), new knowledge
## and the restore steps just finished, as cards side by side. Null when there is none of these.
func _extras() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for cid: String in Array(s.get("cards", [])):
		if not ResourceLoader.exists("res://data/classes/%s.tres" % cid):
			continue
		var c := Db.class_def(cid)
		var v := MenuKit.card(row, Txt.t("UI_HC_CARD"))
		v.get_parent().custom_minimum_size.x = COL_W * 1.6
		var name := MenuKit.label(Txt.t(c.name_key), 20, MenuKit.GOLD)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(name)
		var stats := HBoxContainer.new()
		stats.alignment = BoxContainer.ALIGNMENT_CENTER
		stats.add_theme_constant_override("separation", 8)
		v.add_child(stats)
		stats.add_child(MenuKit.chip("%s %d" % [Txt.t("UI_STAT_HP"), c.max_hp], "potion", MenuKit.TEXT, "", 15))
		stats.add_child(MenuKit.chip("%s %d" % [Txt.t("UI_STAT_ARMOR"), c.armor], "shield", MenuKit.TEXT, "", 15))
		stats.add_child(MenuKit.chip("%s %d" % [Txt.t("UI_HC_MOVE"), c.move], "dash", MenuKit.TEXT, "", 15))
		var moves := HFlowContainer.new()  # each move as a chip, its icon and name; what it does on hover (plain rules text)
		moves.alignment = FlowContainer.ALIGNMENT_CENTER
		moves.add_theme_constant_override("h_separation", 8)
		moves.add_theme_constant_override("v_separation", 6)
		moves.custom_minimum_size.x = COL_W * 1.6 - 40.0
		v.add_child(moves)
		for aid in c.abilities:
			var a := Db.ability(String(aid))
			if a == null:
				continue
			var desc := "DESC_" + a.id.to_upper()
			var icon := a.id if ActionInfo.icon(a.id) != null else "@dot"
			moves.add_child(MenuKit.chip(Txt.t(a.name_key), icon, MenuKit.TEXT, Txt.t(desc) if Txt.t(desc) != desc else Txt.t(a.name_key), 15))
	var k: Dictionary = s.get("knowledge", {})
	if not k.is_empty():
		var v := MenuKit.card(row, Txt.t("UI_HC_KNOW"))
		v.get_parent().custom_minimum_size.x = COL_W * 0.8
		for kind: String in ["got", "beaten", "passed"]:
			if k.has(kind):
				v.add_child(MenuKit.label(Txt.f("UI_HC_KNOW_" + kind.to_upper(), int(k[kind])), 16))
	var ids: Array = s.get("restored", [])
	if not ids.is_empty():
		var v := MenuKit.card(row, Txt.t("UI_HC_RESTORED"))
		v.get_parent().custom_minimum_size.x = COL_W * 0.8
		for id: String in ids:
			for r: Dictionary in Db.restore:
				if String(r.id) == id:
					var l := MenuKit.label(Txt.t(String(r.name_key)), 16, MenuKit.GOLD)
					l.tooltip_text = Txt.t("BUILDING_" + String(r.building).to_upper())
					l.mouse_filter = Control.MOUSE_FILTER_PASS
					v.add_child(l)
	return row if row.get_child_count() > 0 else null


## The foot closes on the next goal ("0/4" stone): the reason for one more run, beside ONE MORE GO.
func _goal(foot: HBoxContainer) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = &"KitCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var head := Label.new()
	head.theme_type_variation = &"KitHeading"
	head.text = Txt.t("UI_HC_NEXT")
	head.add_theme_font_size_override("font_size", 22)
	row.add_child(head)
	if goal.is_empty():
		row.add_child(MenuKit.label(Txt.t("UI_HC_NO_GOAL"), 17, MenuKit.TEXT_DIM))
		return
	var r: Dictionary = goal.row
	head.tooltip_text = "%s: %s" % [Txt.t("BUILDING_" + String(r.building).to_upper()), Txt.t(String(r.name_key))]
	head.mouse_filter = Control.MOUSE_FILTER_PASS
	for p: Dictionary in goal.parts:
		var item := Txt.t(String(Db.items[p.id].name_key)) if Db.items.has(String(p.id)) else String(p.id)
		var c := MenuKit.chip("%d/%d" % [int(p.have), int(p.need)], String(p.id), MenuKit.GOLD if int(p.have) >= int(p.need) else MenuKit.TEXT,
			Txt.f("UI_HC_OF", [int(p.have), int(p.need), item]), 18)
		row.add_child(c)
	if bool(goal.get("ready", false)):
		row.add_child(MenuKit.label(Txt.t("UI_RESTORE_READY"), 16, MenuKit.GOLD))


# --- pieces ------------------------------------------------------------------------------------

## A member's thin HP, energy and Morale bars ([USER] 2026-11-02: "they need Morale too as a bar ... all the HP/Mana/Morale
## bars can be overall thinner"), from the run's member when there is one.
func _vitals(col: VBoxContainer, id: String) -> void:
	var m: Dictionary = {}
	if Game.run != null:
		for mm: Dictionary in Game.run.members:
			if String((mm.def as CharacterDef).id) == id:
				m = mm
	if not m.is_empty():
		var u := CombatUnit.from_member(m)
		MenuKit.bar_row(col, Txt.t("UI_VIC_BAR_HP"), VictoryUi.HP_RED, float(m.hp) / maxf(1.0, float(u.max_hp)), "%d/%d" % [int(m.hp), u.max_hp], BAR_LABEL)
		if u.res_kind != "":
			MenuKit.bar_row(col, Txt.t("RES_" + u.res_kind.to_upper()) if Txt.has("RES_" + u.res_kind.to_upper()) else u.res_kind.to_upper(),
				FrameHud.RES_COLORS.get(u.res_kind, Color.WHITE), float(u.res) / maxf(1.0, float(u.res_max)), "%d/%d" % [u.res, u.res_max], BAR_LABEL)
	MenuKit.bar_row(col, Txt.t("UI_VIC_BAR_HEART"), VictoryUi.HEART_PINK, float(Game.morale_of(id)) / 100.0, str(Game.morale_of(id)), BAR_LABEL)

## A row that starts with a round face (party, friends).
func _row(box: VBoxContainer, id: String) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	box.add_child(line)
	line.add_child(MenuKit.portrait(id, FACE))
	return line


func _quiet(box: Control, key: String) -> void:
	var l := MenuKit.label(Txt.t(key), 16, MenuKit.TEXT_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)


static func _name(id: String) -> String:
	var d := Db.character(StringName(id))
	return Txt.t(d.name_key) if d else id

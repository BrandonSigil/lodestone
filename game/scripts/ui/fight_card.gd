class_name FightCard
extends VBoxContainer
## The fight's side card (the drawn skin; docs/design/menus-v3.md, round six). From the top: whose turn it is and the
## round; END TURN (the one gold button) and DANGER, which never move; then the piece picked or under the pointer (name,
## bars, its numbers as a small grid, its moves) and the tile under the pointer as one quiet line. It reads
## Battle.unit_card and Battle.tile_card: data, not the paragraph the old side box printed.

const W := 216.0  ## the card's inside width (the side panel's width less its pads)
const RES_COLORS := {"mana": Color(0.35, 0.55, 1.0), "rage": Color(0.9, 0.3, 0.25), "charges": Color(0.95, 0.8, 0.3)}

var battle: Battle
var phase: Label  ## YOUR TURN / ENEMY TURN
var info: Label  ## never shown: the hosts that still write a line of their own to the side box write it here
var end_turn: Button
var danger: Button
var _round: Label
var _rule: Control
var _who: VBoxContainer
var _tile: VBoxContainer
var _unit: CombatUnit = null  ## the piece under the pointer or clicked, or null: then the selected one shows
var _cell := CombatBoard.NONE
var _seen := 0  ## a hash of everything the card shows: it is rebuilt only when that changes


func _init(b: Battle) -> void:
	battle = b
	custom_minimum_size.x = W
	add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	add_child(head)
	phase = MenuKit.label("", UiSkin.T_LEAD, UiSkin.GOLD)
	phase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(phase)
	_round = MenuKit.label("", UiSkin.T_SMALL, UiSkin.TEXT_DIM)
	_round.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(_round)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	end_turn = MenuKit.primary(Txt.t("UI_END_PHASE"), func() -> void: battle.end_player_phase(), UiSkin.T_BODY, 0.0)
	end_turn.custom_minimum_size = Vector2(0, 36)
	end_turn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	end_turn.tooltip_text = Txt.t("UI_END_PHASE_TIP")
	end_turn.focus_mode = Control.FOCUS_NONE  # the dock keeps the keys
	row.add_child(end_turn)
	danger = Button.new()
	danger.theme_type_variation = &"QuietButton"
	danger.text = Txt.t("UI_DANGER_SHORT")
	danger.toggle_mode = true
	danger.tooltip_text = Txt.t("UI_DANGER_TIP")
	danger.custom_minimum_size = Vector2(0, 36)
	danger.focus_mode = Control.FOCUS_NONE
	danger.add_theme_font_size_override("font_size", UiSkin.T_SMALL)
	# a narrow button: the quiet button's looks with less pad; switched on, it keeps the gold hairline
	danger.add_theme_stylebox_override("normal", UiSkin.flat(Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.1), UiSkin.R_BUTTON, 10.0, 6.0))
	danger.add_theme_stylebox_override("hover", UiSkin.flat(Color(UiSkin.GOLD, 0.14), Color(UiSkin.HAIR, 0.95), UiSkin.R_BUTTON, 10.0, 6.0))
	for n in ["pressed", "hover_pressed"]:
		danger.add_theme_stylebox_override(n, UiSkin.flat(Color(0, 0, 0, 0.3), Color(UiSkin.HAIR, 0.95), UiSkin.R_BUTTON, 10.0, 6.0))
	danger.add_theme_color_override("font_pressed_color", UiSkin.GOLD)
	danger.add_theme_color_override("font_hover_pressed_color", UiSkin.GOLD)
	danger.toggled.connect(func(on: bool) -> void:
		if battle.show_danger != on:
			battle.show_danger = on
			battle._refresh_danger())
	row.add_child(danger)
	_rule = _line()
	add_child(_rule)
	_who = VBoxContainer.new()
	_who.add_theme_constant_override("separation", 5)
	add_child(_who)
	_tile = VBoxContainer.new()
	_tile.add_theme_constant_override("separation", 1)
	add_child(_tile)
	info = Label.new()
	info.visible = false
	add_child(info)
	battle.looked.connect(func(u: CombatUnit, c: Vector2i) -> void:
		_unit = u if u != battle.selected else null  # the piece picked is what shows anyway, and it must go when it is put down
		_cell = c)
	battle.phase_changed.connect(func(_team: int) -> void: _seen = 0)


func _process(_delta: float) -> void:
	if battle == null or not is_instance_valid(battle):
		return
	var u := shown()
	var d := battle.unit_card(u) if u != null else {}
	var t := battle.tile_card(_cell) if _cell != CombatBoard.NONE and battle.targeting == null else {}
	var mine := battle.is_player_turn()
	var now := hash([d, t, mine, battle.round_no, battle.show_danger, battle.targeting.id if battle.targeting != null else ""])
	if now == _seen:
		return
	_seen = now
	phase.text = Txt.t("UI_PLAYER_PHASE") if mine else Txt.t("UI_ENEMY_PHASE")
	phase.add_theme_color_override("font_color", UiSkin.GOLD if mine else UiSkin.TEXT_DIM)
	_round.text = Txt.f("UI_ROUND", battle.round_no) if battle.round_no > 0 else ""
	end_turn.disabled = not mine
	danger.set_pressed_no_signal(battle.show_danger)
	_fill_who(d)
	_fill_tile(t)
	_rule.visible = _who.get_child_count() > 0 or _tile.get_child_count() > 0
	reset_size()


## The piece the card shows: the one under the pointer (or clicked), else the one picked.
func shown() -> CombatUnit:
	return _unit if _unit != null else battle.selected


static func _empty(box: Control) -> void:
	for c in box.get_children():
		box.remove_child(c)  # gone now, so the card sizes to the new rows only
		c.queue_free()


func _fill_who(d: Dictionary) -> void:
	_empty(_who)
	if d.is_empty():
		return
	var name_row := HFlowContainer.new()
	name_row.add_theme_constant_override("h_separation", 6)
	name_row.add_theme_constant_override("v_separation", 3)
	_who.add_child(name_row)
	name_row.add_child(MenuKit.label(String(d.name), UiSkin.T_BODY))
	for tag: String in d.tags:
		name_row.add_child(MenuKit.chip(tag, "", UiSkin.TEXT_DIM, "", UiSkin.T_SMALL))
	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 1)
	_who.add_child(bars)
	var heads: Array[Control] = []
	var know := bool(d.know)
	var hp := MenuKit.bar_row(bars, Txt.t("UI_STAT_HP"), VictoryUi.HP_RED, float(d.hp) / maxf(1.0, float(d.max_hp)) if know else 1.0,
		"%d/%d" % [int(d.hp), int(d.max_hp)] if know else "?/?", 0.0)
	heads.append(hp.get_parent().get_child(0))
	if String(d.res_kind) != "":
		var res := MenuKit.bar_row(bars, Txt.t("RES_" + String(d.res_kind).to_upper()), RES_COLORS.get(String(d.res_kind), Color.WHITE),
			float(d.res) / maxf(1.0, float(d.res_max)), "%d/%d" % [int(d.res), int(d.res_max)], 0.0)
		heads.append(res.get_parent().get_child(0))
	var head_w := 0.0  # the bars start at the same place whatever their labels (HP, MANA, CHARGES)
	for h in heads:
		head_w = maxf(head_w, h.get_combined_minimum_size().x)
	for h in heads:
		h.custom_minimum_size.x = head_w
	var grid := GridContainer.new()  # the numbers: a quiet three-wide grid, label dim, value bright
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 1)
	_who.add_child(grid)
	for n: Array in d.numbers:
		grid.add_child(_pair(Txt.t(String(n[0])), String(n[1])))
	var aim := battle.targeting.name_key if battle.targeting != null and shown() == battle.selected else ""
	for s: Dictionary in d.skills:  # its moves, each with what it costs
		var on := aim != "" and Txt.t(aim) == String(s.name)
		var row := HBoxContainer.new()
		_who.add_child(row)
		var n := MenuKit.label(String(s.name), UiSkin.T_SMALL, UiSkin.GOLD if on else UiSkin.TEXT)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.clip_text = true
		row.add_child(n)
		if int(s.cost) > 0:
			row.add_child(MenuKit.label("%d %s" % [int(s.cost), Txt.t("RES_" + String(d.res_kind).to_upper())], UiSkin.T_SMALL, UiSkin.TEXT_DIM))
	for t: Dictionary in d.traits:
		var l := MenuKit.label("%s: %s" % [String(t.name), String(t.desc)], UiSkin.T_SMALL, UiSkin.TEXT_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = W
		_who.add_child(l)


## The tile under the pointer: its name, then height, what a step onto it costs and its cover; or what lands there.
func _fill_tile(t: Dictionary) -> void:
	_empty(_tile)
	if battle.targeting != null:
		_tile.add_child(MenuKit.label(Txt.f("UI_FIGHT_AIM", Txt.t(battle.targeting.name_key)), UiSkin.T_SMALL, UiSkin.GOLD))
		return
	if t.is_empty():
		return
	if _who.get_child_count() > 0:
		var gap := _line()
		gap.custom_minimum_size.y = 7.0
		_tile.add_child(gap)
	if String(t.mark) != "":
		var m := MenuKit.label(String(t.mark), UiSkin.T_SMALL, UiSkin.GOLD)
		m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		m.custom_minimum_size.x = W
		_tile.add_child(m)
	_tile.add_child(MenuKit.label(String(t.name).replace("_", " "), UiSkin.T_SMALL))
	var row := HFlowContainer.new()  # it wraps before it widens the card
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 1)
	row.custom_minimum_size.x = W
	_tile.add_child(row)
	row.add_child(_pair(Txt.t("UI_TILE_HEIGHT"), str(int(t.height))))
	row.add_child(_pair(Txt.t("UI_TILE_COST"), str(int(t.cost))) if int(t.cost) > 0 else MenuKit.label(Txt.t("UI_TILE_BLOCKED"), UiSkin.T_SMALL, UiSkin.TEXT_DIM))
	row.add_child(_pair(Txt.t("UI_TILE_COVER"), "%+d" % int(t.cover)))


## "MOVE 5": the label dim, the value bright.
static func _pair(text: String, value: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.add_child(MenuKit.label(text, UiSkin.T_SMALL, UiSkin.TEXT_DIM))
	h.add_child(MenuKit.label(value, UiSkin.T_SMALL))
	return h


## A quiet line across the card.
static func _line() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void: c.draw_rect(Rect2(0, floorf(c.size.y * 0.5), c.size.x, 1), UiSkin.LINE))
	return c

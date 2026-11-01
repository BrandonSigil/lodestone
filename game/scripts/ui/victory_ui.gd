class_name VictoryUi
extends PanelContainer
## The fight's victory screen ([USER] 2026-11-01: "Look at battle victory menus and beef up this report. Lots of
## JRPGs do it ... less text, more intuitive sharing of informations"). A dimmed screen over the board with, top to
## bottom: the WIN plate; a row of icon chips (XP each, foes down, coins, every loot item); one card per party piece
## (portrait, level, an XP bar that fills and rolls over into LV UP with the stats gained as icons, HP and heart bars);
## the bonds that grew; the buttons. Numbers and icons, no sentences: every word left is a key in placeholder.csv.
##
## The host fills a report (see `report`) and passes the buttons; a key or a click on the dim skips the bars to the
## end, and a second one presses the first button. It scales down to fit any window.

const ICONS := "res://art/source/icons/"
const STAT_ICON := {"hp": "potion", "damage": "strength", "armor": "shield", "magic": "rare", "crit": "focus"}
const CARD_W := 232.0
const FACE := 112.0
const FILL_TIME := 1.1  ## seconds an XP bar takes to fill (a level up rolls it over and goes on)
const STAGGER := 0.18  ## each card starts this much after the one before
const XP_GOLD := Color(0.98, 0.8, 0.32)
const HP_RED := Color(0.82, 0.24, 0.2)
const HEART_PINK := Color(0.93, 0.47, 0.5)
const UP_GREEN := Color(0.62, 0.9, 0.5)
const DOWN_RED := Color(1.0, 0.5, 0.42)

var r: Dictionary = {}  ## the report: see `report`
var buttons: Array = []  ## [[text, Callable], ...]
var _page: VBoxContainer
var _holder: Control
var _tween: Tween
var _cards: Array = []  ## per member: {"m": member, "lv": Label, "xp": Bar, "badge": Control, "gains": Control, "heart": Bar}
var _first: Button


## What every piece had before the fight's XP and heart changes: {id: {"lv", "xp", "heart"}}. Take it before
## Game.fight_morale and Game.award_xp.
static func snapshot(ids: Array) -> Dictionary:
	var out := {}
	for id: String in ids:
		var s := Game.level_state(id)
		out[id] = {"lv": int(s.level), "xp": int(s.xp), "heart": Game.morale_of(id)}
	return out


## The report for a won fight, from the snapshot taken before it and the party's pieces after it.
## `fight` holds "title" (a text key), "xp", "downed", "coins", "loot" (an items string, "meat:3;potion:1") and
## "bonds" ([[pair key "a+b", level], ...], Battle.bond_ups).
static func report(before: Dictionary, pieces: Array, fight: Dictionary) -> Dictionary:
	var members := []
	var ups := {}
	for e: Dictionary in Game.level_ups:
		ups[String(e.id)] = e
	for u: CombatUnit in pieces:
		if u.member.is_empty():
			continue
		var d: CharacterDef = u.member.def
		var id := String(d.id)
		var was: Dictionary = before.get(id, {"lv": 1, "xp": 0, "heart": Game.morale_of(id)})
		var now := Game.level_state(id)
		var gained: Dictionary = (ups.get(id, {}) as Dictionary).get("stats", {})
		var top := u.max_hp + int(gained.get("hp", 0))  # the piece's max is from before the level
		members.append({"id": id, "name": Txt.t(d.name_key), "tint": d.tint, "hp": maxi(1, u.hp), "max_hp": top,
			"lv0": int(was.lv), "xp0": int(was.xp), "lv1": int(now.level), "xp1": int(now.xp),
			"stats": gained, "heart0": int(was.heart), "heart1": Game.morale_of(id),
			"pick": int(Game.rank_state(id).pending) > 0})
	var out := fight.duplicate()
	out.members = members
	return out


static func make(rep: Dictionary, btns: Array) -> VictoryUi:
	var ui := VictoryUi.new()
	ui.r = rep
	ui.buttons = btns
	return ui


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := StyleBoxFlat.new()
	dim.bg_color = Color(0.02, 0.05, 0.05, 0.74)
	add_theme_stylebox_override("panel", dim)
	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 16)
	_page.alignment = BoxContainer.ALIGNMENT_CENTER
	_holder.add_child(_page)
	_title()
	_chips()
	_party()
	_bonds()
	var end := String(r.get("end_text", ""))
	if end != "":
		var l := _label(end, 20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_page.add_child(l)
	_buttons()
	_holder.resized.connect(_fit)
	_fit.call_deferred()
	_play.call_deferred()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, UiTheme.OPEN_TIME)


## Scales the page down (never up) to fit the window with a margin, centred.
func _fit() -> void:
	if not is_instance_valid(_page):
		return
	_page.reset_size()
	var room := _holder.size - Vector2(40, 40)
	var k := minf(1.0, minf(room.x / maxf(1.0, _page.size.x), room.y / maxf(1.0, _page.size.y)))
	_page.scale = Vector2(k, k)
	_page.position = ((_holder.size - _page.size * k) * 0.5).floor()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_skip_or_go()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action("ui_cancel") or event.is_action("ui_accept"):
		get_viewport().set_input_as_handled()
		_skip_or_go()


## The first press fills every bar at once; the next presses the first button.
func _skip_or_go() -> void:
	if _tween != null and _tween.is_running():
		_tween.custom_step(60.0)
		return
	if _first != null and is_instance_valid(_first):
		_first.pressed.emit()


# --- pieces --------------------------------------------------------------------------------------

func _title() -> void:
	var plate := PanelContainer.new()
	plate.theme_type_variation = &"TitlePlate"
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var t := Label.new()
	t.theme_type_variation = &"MenuTitle"
	t.text = Txt.t(String(r.get("title", "UI_VICTORY")))
	t.add_theme_font_size_override("font_size", 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(t)
	_page.add_child(plate)


## XP each, foes down, coins, then every loot item as its own icon and count.
func _chips() -> void:
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 8)
	row.custom_minimum_size.x = 4 * (CARD_W + 16)
	_page.add_child(row)
	# each chip names itself on hover, like the pack's icons ([USER] 2026-11-01 "What do these icons mean?")
	row.add_child(_chip("star_guide", "+%d" % int(r.get("xp", 0)), XP_GOLD, Txt.t("UI_WIN_XP_TIP")))
	if int(r.get("downed", 0)) > 0:
		row.add_child(_chip("knock_out", "%d" % int(r.downed), UiTheme.PARCHMENT, Txt.t("UI_WIN_DOWNED_TIP")))
	if int(r.get("coins", 0)) > 0:
		row.add_child(_chip("gold", "+%d" % int(r.coins), XP_GOLD, Txt.t("UI_PACK_GOLD_TIP")))
	for part in String(r.get("loot", "")).split(";", false):
		var kv := part.split(":")
		var id := kv[0].strip_edges()
		id = {"food": RunState.FOOD_ITEM, "medicine": RunState.MED_ITEM}.get(id, id)
		var item: Dictionary = Db.items.get(id, {})
		var tip := Txt.t(String(item.name_key)) if item.has("name_key") else id
		row.add_child(_chip(id if _icon(id) != null else "sack", "x%d" % (int(kv[1]) if kv.size() > 1 else 1), UiTheme.PARCHMENT, tip))


func _chip(icon: String, text: String, col := UiTheme.PARCHMENT, tip := "") -> Control:
	var p := PanelContainer.new()
	p.theme_type_variation = &"InfoPanel"
	p.tooltip_text = tip
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	h.add_child(_tex(icon, 38))
	var l := _label(text, 22)
	l.add_theme_color_override("font_color", col)
	h.add_child(l)
	return p


func _party() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_page.add_child(row)
	for m: Dictionary in r.get("members", []):
		row.add_child(_card(m))


func _card(m: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"InfoPanel"
	card.custom_minimum_size.x = CARD_W
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	# the face, the LV UP plate over its foot and a gem when a pick waits
	var face := Control.new()
	face.custom_minimum_size = Vector2(CARD_W - 16, FACE)
	col.add_child(face)
	var frame := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.12, 0.11)
	sb.border_color = UiTheme.PARCHMENT_DARK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	frame.add_theme_stylebox_override("panel", sb)
	frame.size = Vector2(FACE, FACE)
	frame.position = Vector2((CARD_W - 16 - FACE) * 0.5, 0)
	face.add_child(frame)
	var pf := "res://art/source/portraits/%s.png" % String(m.id)
	if ResourceLoader.exists(pf):
		var t := TextureRect.new()
		t.texture = load(pf)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.position = Vector2(3, 3)
		t.size = Vector2(FACE - 6, FACE - 6)
		frame.add_child(t)
	else:
		var p := PawnIcon.new()
		p.tint = m.tint
		p.position = Vector2(FACE * 0.25, FACE * 0.12)
		p.size = Vector2(FACE * 0.5, FACE * 0.8)
		frame.add_child(p)
	var badge := PanelContainer.new()
	badge.theme_type_variation = &"TitlePlate"
	var bl := Label.new()
	bl.theme_type_variation = &"MenuTitle"
	bl.text = Txt.t("UI_VIC_LV_UP")
	bl.add_theme_font_size_override("font_size", 20)
	badge.add_child(bl)
	badge.visible = false
	face.add_child(badge)
	badge.resized.connect(func() -> void:
		badge.pivot_offset = badge.size * 0.5
		badge.position = Vector2((CARD_W - 16 - badge.size.x) * 0.5, FACE - badge.size.y * 0.6))
	# name and level
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	col.add_child(top)
	var nm := _label(String(m.name), 20)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	top.add_child(nm)
	var lv_tag := _label(Txt.t("UI_VIC_LV"), 15)
	lv_tag.add_theme_color_override("font_color", UiTheme.PARCHMENT_DARK)
	lv_tag.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(lv_tag)
	var lv := _label(str(int(m.lv0)), 26)
	lv.add_theme_color_override("font_color", XP_GOLD)
	top.add_child(lv)
	# the bars: XP (fills), HP, heart (moves)
	var per := float(maxi(1, int(Db.levels.get("xp_per_level", 100))))
	var xp := _bar_row(col, "star_guide", XP_GOLD, float(m.xp0) / per, "+%d" % int(r.get("xp", 0)))
	xp.text_color = XP_GOLD
	var hp := _bar_row(col, "potion", HP_RED, float(m.hp) / maxf(1.0, float(m.max_hp)), "%d/%d" % [int(m.hp), int(m.max_hp)])
	var dh := int(m.heart1) - int(m.heart0)
	var heart := _bar_row(col, "heal", HEART_PINK, float(m.heart0) / 100.0,
		("+%d" % dh if dh > 0 else str(dh)) if dh != 0 else "")
	heart.text_color = UP_GREEN if dh > 0 else DOWN_RED
	hp.text_color = UiTheme.PARCHMENT
	# the stats a level gave, as icons, and a gem when a new trick waits (shown when the bar rolls over)
	var gains := HBoxContainer.new()
	gains.alignment = BoxContainer.ALIGNMENT_CENTER
	gains.add_theme_constant_override("separation", 8)
	gains.custom_minimum_size.y = 30
	gains.modulate.a = 0.0
	col.add_child(gains)
	var stats: Dictionary = m.get("stats", {})
	for k in LevelRules.STATS:
		if int(stats.get(k, 0)) > 0:
			var g := HBoxContainer.new()
			g.add_theme_constant_override("separation", 1)
			g.add_child(_tex(String(STAT_ICON[k]), 26))
			var gl := _label("+%d" % int(stats[k]), 17)
			gl.add_theme_color_override("font_color", UP_GREEN)
			g.add_child(gl)
			g.tooltip_text = Txt.t("UI_STAT_" + k.to_upper())
			gains.add_child(g)
	if bool(m.get("pick", false)) and int(m.lv1) > int(m.lv0):
		var g := HBoxContainer.new()
		g.add_theme_constant_override("separation", 4)
		g.add_child(_Gem.new())
		var gl := _label(Txt.t("UI_VIC_PICK"), 15)
		gl.add_theme_color_override("font_color", UiTheme.GOLD)
		g.add_child(gl)
		gains.add_child(g)
	gains.visible = gains.get_child_count() > 0
	_cards.append({"m": m, "lv": lv, "xp": xp, "badge": badge, "gains": gains, "heart": heart})
	return card


func _bar_row(col: VBoxContainer, icon: String, fill: Color, value: float, text: String) -> UiBar:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	col.add_child(h)
	h.add_child(_tex(icon, 26))
	var b := UiBar.new()
	b.fill = fill
	b.value = clampf(value, 0.0, 1.0)
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	return b


## Pairs whose bond went up: both faces, a heart between, the new level.
func _bonds() -> void:
	var ups: Array = r.get("bonds", [])
	if ups.is_empty():
		return
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_page.add_child(row)
	for up: Array in ups:
		var ids := String(up[0]).split("+")
		var p := PanelContainer.new()
		p.theme_type_variation = &"InfoPanel"
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		p.add_child(h)
		h.add_child(_face_small(ids[0]))
		h.add_child(_tex("heal", 30))
		h.add_child(_face_small(ids[1] if ids.size() > 1 else ""))
		var l := _label("%s %d" % [Txt.t("UI_VIC_LV"), int(up[1])], 18)
		l.add_theme_color_override("font_color", HEART_PINK)
		h.add_child(l)
		row.add_child(p)


func _face_small(id: String) -> Control:
	var pf := "res://art/source/portraits/%s.png" % id
	if id != "" and ResourceLoader.exists(pf):
		var t := TextureRect.new()
		t.texture = load(pf)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.custom_minimum_size = Vector2(34, 34)
		return t
	var p := PawnIcon.new()
	var d := Db.character(StringName(id))
	p.tint = d.tint if d else Color.GRAY
	p.custom_minimum_size = Vector2(26, 34)
	return p


func _buttons() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	_page.add_child(row)
	for b: Array in buttons:
		var btn := Button.new()
		btn.text = String(b[0])
		btn.custom_minimum_size = Vector2(220, 48)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(b[1])
		row.add_child(btn)
		if _first == null:
			_first = btn
	if _first != null:
		_first.grab_focus.call_deferred()


# --- the fill ----------------------------------------------------------------------------------

## Every card's XP bar fills (rolling over on each level: the level number ticks, LV UP pops, the stats show), and
## the heart bar slides to its new value.
func _play() -> void:
	if _cards.is_empty():
		return
	var per := float(maxi(1, int(Db.levels.get("xp_per_level", 100))))
	_tween = create_tween().set_parallel()
	for i in _cards.size():
		var c: Dictionary = _cards[i]
		var m: Dictionary = c.m
		var from := float(m.lv0) + float(m.xp0) / per
		var to := float(m.lv1) + float(m.xp1) / per
		var at := 0.25 + i * STAGGER
		_tween.tween_method(_show_xp.bind(c), from, to, FILL_TIME).set_delay(at) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(c.heart, "value", clampf(float(m.heart1) / 100.0, 0.0, 1.0), FILL_TIME * 0.7).set_delay(at)


func _show_xp(t: float, c: Dictionary) -> void:
	var lv := int(floor(t))
	(c.xp as UiBar).value = t - lv
	var label: Label = c.lv
	if str(lv) != label.text:
		label.text = str(lv)
		if lv > int(c.m.lv0):
			_level_pop(c)


func _level_pop(c: Dictionary) -> void:
	var badge: Control = c.badge
	badge.visible = true
	badge.scale = Vector2(0.4, 0.4)
	var tw := badge.create_tween()
	tw.tween_property(badge, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var gains: Control = c.gains
	gains.create_tween().tween_property(gains, "modulate:a", 1.0, 0.3)
	(c.xp as UiBar).flash = 1.0
	(c.xp as UiBar).create_tween().tween_property(c.xp, "flash", 0.0, 0.5)


# --- helpers -----------------------------------------------------------------------------------

static func _icon(id: String) -> Texture2D:
	return ActionInfo.icon(id)


func _tex(id: String, px: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _icon(id)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _label(text: String, px: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	return l


## A blue gem with a "!" on a portrait's corner: a skill pick is waiting.
class _Gem extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(22, 22)
		size = Vector2(22, 22)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		var c := size * 0.5
		var pts := PackedVector2Array([c + Vector2(0, -11), c + Vector2(11, 0), c + Vector2(0, 11), c + Vector2(-11, 0)])
		draw_colored_polygon(pts, UiTheme.DIAMOND)
		pts.append(pts[0])
		draw_polyline(pts, UiTheme.PARCHMENT, 2.0)
		var font := get_theme_default_font()
		draw_string(font, c + Vector2(-3, 6), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiTheme.PARCHMENT)

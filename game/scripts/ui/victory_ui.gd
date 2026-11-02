class_name VictoryUi
extends PanelContainer
## The fight's victory screen ([USER] 2026-11-01: "Look at battle victory menus and beef up this report"; X7 "show the loot
## earned in a box that fits the size of whatever the loot is, with your inventory under it"; dev-x7-win-review: "one big
## window with a simple clear background and simple framing"; round 2 mockup D). One big kit window (MenuKit.window) in
## the play area above the bottom frame, which stays in view: the WIN plate on its top rim, the X at its top right. On
## the left a card per party piece in a grid (round portrait, name and level, labelled bars: HP, the job's resource, EXP
## that fills and rolls over into LV UP with the stats gained, and the heart when it moved); on the right the loot as a
## section (sized to the loot, TAKE ALL) over the pack to drag into (r.loot_grid; r.changed runs after a move), the gold
## as a chip; the bonds that grew under the party; the buttons at the foot, the first one gold. Every word is a key in
## placeholder.csv.
##
## The host fills a report (see `report`) and passes the buttons; a key or a click off the window skips the bars to the
## end, and a second one presses the first button. It scales down to fit any window.

const ICONS := "res://art/source/icons/"
const STAT_ICON := {"hp": "potion", "damage": "strength", "armor": "shield", "magic": "rare", "crit": "focus"}
const CARD_W := 236.0
const FACE := 76.0
const LOOT_CELL := 62.0  ## the loot and pack grids' cell size here
const FILL_TIME := 1.1  ## seconds an XP bar takes to fill (a level up rolls it over and goes on)
const BAR_LABEL := 76.0  ## room for a bar's name (CHARGES, MORALE)
const MIN_SCALE := 0.8  ## the smallest the window shrinks to before its inside scrolls
const STAGGER := 0.18  ## each card starts this much after the one before
const XP_GOLD := Color(0.98, 0.8, 0.32)
const HP_RED := Color(0.82, 0.24, 0.2)
const HEART_PINK := Color(0.93, 0.47, 0.5)
const UP_GREEN := Color(0.62, 0.9, 0.5)
const DOWN_RED := Color(1.0, 0.5, 0.42)

var r: Dictionary = {}  ## the report: see `report`
var buttons: Array = []  ## [[text, Callable], ...]
var area := Callable()  ## the room it may use (the play area above the bottom frame); the viewport when not given
var _page: VBoxContainer
var _holder: Control
var _win: Control  ## the window (MenuKit.window's root)
var _foot: HBoxContainer  ## the buttons' row, under the scroll
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
			"res_kind": u.res_kind, "res": u.res, "res_max": u.res_max,
			"pick": int(Game.rank_state(id).pending) > 0})
	var out := fight.duplicate()
	out.members = members
	return out


static func make(rep: Dictionary, btns: Array, room := Callable()) -> VictoryUi:
	var ui := VictoryUi.new()
	ui.r = rep
	ui.buttons = btns
	ui.area = room
	return ui


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var dim := _Dim.new()  # a simple clear background: the map dimmed, only above the bottom frame
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.room = _room
	_holder = dim
	add_child(_holder)
	# the window scales down to fit before its inside would scroll (research: to 85%, then scroll)
	var w := MenuKit.window(Txt.t(String(r.get("title", "UI_VICTORY"))), _room, _press_first, 46, func() -> Rect2:
		var rr := _room()
		rr.size.y /= MIN_SCALE
		return rr)
	_win = w.root
	_holder.add_child(_win)
	_page = w.body
	_foot = w.foot
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	_page.add_child(body)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 14)
	body.add_child(left)
	_party(left)
	_bonds(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	body.add_child(right)
	_loot(right)
	var end := String(r.get("end_text", ""))
	if end != "":
		var l := _label(end, 20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_page.add_child(l)
	_summary(_foot)  # EXP and GOLD in the foot, left of the buttons: the window stays short enough to show full size
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_foot.add_child(gap)
	_buttons()
	_win.resized.connect(_fit)
	_holder.resized.connect(_fit)
	_fit.call_deferred()
	_play.call_deferred()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, UiTheme.OPEN_TIME)


func _room() -> Rect2:
	if area.is_valid():
		return area.call()
	return get_viewport_rect()


## The window centred in the room, scaled down (never up) to fit it with a margin.
func _fit() -> void:
	if not is_instance_valid(_win):
		return
	_win.reset_size()
	var room := _room()
	var free := room.size - Vector2(32, 32)
	var k := minf(1.0, minf(free.x / maxf(1.0, _win.size.x), free.y / maxf(1.0, _win.size.y)))
	_win.scale = Vector2(k, k)
	_win.position = (room.position + (room.size - _win.size * k) * 0.5).floor()
	_holder.queue_redraw()


func _press_first() -> void:
	if _first != null and is_instance_valid(_first):
		_first.pressed.emit()


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

## The fight's take as plain words ([USER] 2026-11-01 X7: "the stars are XP? Just say "EXP:"", "I dont care how many foes
## were knocked out either"): EXP and the gold. The loot's things wait in the loot window under it.
func _summary(col: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(row)
	row.add_child(MenuKit.chip(Txt.f("UI_VIC_EXP", int(r.get("xp", 0))), "star_guide", XP_GOLD, "", 18))
	if int(r.get("coins", 0)) > 0:
		row.add_child(MenuKit.chip(Txt.f("UI_VIC_GOLD", int(r.coins)), "gold", XP_GOLD, Txt.t("UI_PACK_GOLD_TIP"), 18))


## The loot window, sized to the loot, with the pack under it to drag things into (ContainerUi.stacked).
func _loot(col: VBoxContainer) -> void:
	var grid: InventoryGrid = r.get("loot_grid")
	if grid == null or grid.items.is_empty() or Game.run == null:
		return
	var view := PackView.new()
	view.sections = true  # LOOT and PACK as sections of this one window (mockup D)
	view.setup_bag(Game.run.pack, Db.items, Callable(), LOOT_CELL)
	ContainerUi.stacked(view, grid, Txt.t("UI_LOOT_TITLE"))
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.resized.connect(view.stretch_sections)
	if r.get("changed") is Callable and (r.changed as Callable).is_valid():
		view.changed.connect(r.changed)
	col.add_child(view)


func _party(into: Control) -> void:
	var members: Array = r.get("members", [])
	var grid := GridContainer.new()  # two across for three or four (three past four pieces), as in mockup D
	grid.columns = 1 if members.size() <= 2 else (2 if members.size() <= 4 else 3)  # two stand one over the other
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	into.add_child(grid)
	for m: Dictionary in members:
		grid.add_child(_card(m))


func _card(m: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"KitCard"
	card.custom_minimum_size.x = CARD_W
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	# the round face, the LV UP plate over its foot, and a gem when a pick waits
	var face := Control.new()
	face.custom_minimum_size = Vector2(CARD_W - 28, FACE + 4)
	col.add_child(face)
	var pic := MenuKit.portrait(String(m.id), FACE, true)
	pic.size = Vector2(FACE, FACE)
	face.add_child(pic)
	face.resized.connect(func() -> void: pic.position = Vector2(roundf((face.size.x - FACE) * 0.5), 2))
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
		badge.position = Vector2((face.size.x - badge.size.x) * 0.5, FACE - badge.size.y * 0.55))
	# the level as a chip on the face's corner; the name under the face
	var lvc := MenuKit.chip("%s %d" % [Txt.t("UI_VIC_LV"), int(m.lv0)], "", XP_GOLD, "", 15)
	face.add_child(lvc)
	lvc.resized.connect(func() -> void: lvc.position = Vector2(pic.position.x + FACE - lvc.size.x * 0.6, FACE - lvc.size.y + 4))
	var lv: Label = lvc.get_child(0).get_child(0)
	var nm := _label(String(m.name), 17)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.clip_text = true
	col.add_child(nm)
	# the bars, each named in small plain words ([USER] 2026-11-01 X7: "Which bar is health? Which bar is Energy?")
	var hp := MenuKit.bar_row(col, Txt.t("UI_VIC_BAR_HP"), HP_RED, float(m.hp) / maxf(1.0, float(m.max_hp)), "%d/%d" % [int(m.hp), int(m.max_hp)], BAR_LABEL)
	hp.text_color = UiTheme.PARCHMENT
	var rk := String(m.get("res_kind", ""))
	if rk != "":  # the job's resource: mana, rage or charges ("I want to see their energy levels too")
		var res := MenuKit.bar_row(col, Txt.t("RES_" + rk.to_upper()) if Txt.has("RES_" + rk.to_upper()) else rk.to_upper(),
			FrameHud.RES_COLORS.get(rk, Color.WHITE), float(m.res) / maxf(1.0, float(m.res_max)), "%d/%d" % [int(m.res), int(m.res_max)], BAR_LABEL)
		res.text_color = UiTheme.PARCHMENT
	var per := float(maxi(1, int(Db.levels.get("xp_per_level", 100))))
	var xp := MenuKit.bar_row(col, Txt.t("UI_VIC_BAR_EXP"), XP_GOLD, float(m.xp0) / per, "%d/%d" % [int(m.xp1), int(per)], BAR_LABEL)  # where it stands; the gain is the EXP chip
	xp.text_color = UiTheme.PARCHMENT
	var dh := int(m.heart1) - int(m.heart0)
	var heart: UiBar = null
	if dh != 0:  # the heart only when it moved: show only what changed (menus research)
		heart = MenuKit.bar_row(col, Txt.t("UI_VIC_BAR_HEART"), HEART_PINK, float(m.heart0) / 100.0, "+%d" % dh if dh > 0 else str(dh), BAR_LABEL)
		heart.text_color = UP_GREEN if dh > 0 else DOWN_RED
	# the stats a level gave, as icons, and a gem when a new trick waits (shown when the bar rolls over)
	var gains := HBoxContainer.new()
	gains.alignment = BoxContainer.ALIGNMENT_CENTER
	gains.add_theme_constant_override("separation", 8)
	gains.custom_minimum_size.y = 28
	gains.modulate.a = 0.0
	col.add_child(gains)
	var stats: Dictionary = m.get("stats", {})
	for k in LevelRules.STATS:
		if int(stats.get(k, 0)) > 0:
			var g := HBoxContainer.new()
			g.add_theme_constant_override("separation", 1)
			g.add_child(_tex(String(STAT_ICON[k]), 24))
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


func _bar_row(col: VBoxContainer, label: String, fill: Color, value: float, text: String) -> UiBar:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	col.add_child(h)
	var l := _label(label, 12)
	l.add_theme_color_override("font_color", UiTheme.PARCHMENT_DARK)
	l.custom_minimum_size.x = 54.0
	h.add_child(l)
	var b := UiBar.new()
	b.fill = fill
	b.value = clampf(value, 0.0, 1.0)
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	return b


## Pairs whose bond went up: both faces, a heart between, the new level.
func _bonds(col: VBoxContainer) -> void:
	var ups: Array = r.get("bonds", [])
	if ups.is_empty():
		return
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 8)
	col.add_child(row)
	for up: Array in ups:
		var ids := String(up[0]).split("+")
		var p := PanelContainer.new()
		p.theme_type_variation = &"KitChip"
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		p.add_child(h)
		h.add_child(MenuKit.portrait(ids[0], 34))
		h.add_child(_tex("heal", 26))
		h.add_child(MenuKit.portrait(ids[1] if ids.size() > 1 else "", 34))
		var l := _label("%s %d" % [Txt.t("UI_VIC_LV"), int(up[1])], 18)
		l.add_theme_color_override("font_color", HEART_PINK)
		h.add_child(l)
		row.add_child(p)


## The buttons at the window's foot, on the right and clear of the corner leaves (the mockup's flag); the first is the
## one to press (gold), the X does what it does.
func _buttons() -> void:
	var row := _foot
	for b: Array in buttons:
		var btn := MenuKit.primary(String(b[0]), b[1], 21, 210.0) if _first == null else Button.new()
		if _first != null:
			btn.text = String(b[0])
			btn.custom_minimum_size = Vector2(210, 52)
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
		if c.heart != null:
			_tween.tween_property(c.heart, "value", clampf(float(m.heart1) / 100.0, 0.0, 1.0), FILL_TIME * 0.7).set_delay(at)


func _show_xp(t: float, c: Dictionary) -> void:
	var lv := int(floor(t))
	(c.xp as UiBar).value = t - lv
	var label: Label = c.lv
	var shown := "%s %d" % [Txt.t("UI_VIC_LV"), lv]
	if shown != label.text:
		label.text = shown
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


## The clear background: the room dimmed (the map shows faintly through), the bottom frame left bright.
class _Dim extends Control:
	var room := Callable()

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var r: Rect2 = room.call() if room.is_valid() else get_viewport_rect()
		draw_rect(Rect2(r.position - global_position, r.size), Color(0.02, 0.05, 0.05, 0.62))

class_name ActionHud
extends Control
## The selected piece's actions in one of the switchable layouts ([USER] 2026-10-30, three versions to pick from):
## "bar" an action bar of icon slots with keys 1 to 0 and resource pips; "ring" icons on an arc round the piece with a
## small move/guard/wait wheel under it; "cards" the skills as a hand of cards. Every slot shows the hover card
## (ActionInfo) and lights its range on the board. Battle hands it the entries; "list" stays Battle's own menu.

const LAYOUTS := ["list", "bar", "ring", "cards"]
const BASIC := ["move", "undo", "talk", "guard", "wait"]
const SLOT := 52.0
const RING_SLOT := 46.0
const CARD := Vector2(112, 164)

var layout := "bar"
var on_hover: Callable  ## (ability or null): light its range
var on_unhover: Callable
var _unit: CombatUnit
var _slots: Array[ActionSlot] = []
var _tip: PanelContainer
var _tip_box: VBoxContainer
var _ring_box := Rect2()
var _bar_panel: Control  ## the ring's icons on screen, for placing the hover card clear of them


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip = PanelContainer.new()
	_tip.theme_type_variation = &"TipPanel"
	_tip_box = VBoxContainer.new()
	_tip_box.add_theme_constant_override("separation", 2)
	_tip.add_child(_tip_box)
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	_tip.z_index = 10
	add_child(_tip)


func clear() -> void:
	for s in _slots:
		s.queue_free()
	_slots.clear()
	for c in get_children():
		if c != _tip:
			c.queue_free()
	_tip.visible = false
	visible = false


## Shows u's entries. at: the piece on screen; area: the play area to stay inside.
func show_for(u: CombatUnit, entries: Array, at: Vector2, area: Rect2) -> void:
	clear()
	_unit = u
	visible = true
	for e in entries:  # load the icons now, not mid-draw
		if e.get("ability") != null:
			ActionInfo.icon_for(e.ability)
	var skills := entries.filter(func(e: Dictionary) -> bool: return not String(e.kind) in BASIC)
	var basics := entries.filter(func(e: Dictionary) -> bool: return String(e.kind) in BASIC)
	for i in skills.size():
		skills[i]["key"] = i if i < 10 else -1
	match layout:
		"bar":
			_bar(u, skills, basics, area)
		"ring":
			_ring(u, skills, basics, at, area)
		"cards":
			_cards(u, skills, basics, area)


## Keys 1 to 0 use the skill in that slot.
func press_key(i: int) -> bool:
	for s in _slots:
		if int(s.entry.get("key", -1)) == i and not s.disabled:
			s.entry.cb.call()
			return true
	return false


func hovering() -> bool:
	return _slots.any(func(s: ActionSlot) -> bool: return s.is_hovered() or s.has_focus())


func _slot(e: Dictionary, u: CombatUnit, sz: Vector2, parent: Control) -> ActionSlot:
	var s := ActionSlot.new()
	s.entry = e
	s.unit = u
	s.custom_minimum_size = sz
	s.size = sz
	s.disabled = not bool(e.enabled)
	s.tooltip_text = ""
	s.pressed.connect(func() -> void:
		_tip.visible = false
		e.cb.call())
	s.mouse_entered.connect(_hover.bind(s))
	s.focus_entered.connect(_hover.bind(s))
	s.mouse_exited.connect(_unhover.bind(s))
	s.focus_exited.connect(_unhover.bind(s))
	parent.add_child(s)
	_slots.append(s)
	return s


func _small(e: Dictionary, parent: Control) -> Button:
	var b := Button.new()
	b.text = String(e.text)
	b.disabled = not bool(e.enabled)
	b.add_theme_font_size_override("font_size", 12)
	b.custom_minimum_size = Vector2(70, 26)
	b.pressed.connect(func() -> void: e.cb.call())
	parent.add_child(b)
	return b


func _hover(s: ActionSlot) -> void:
	var a: Ability = s.entry.get("ability")
	if on_hover.is_valid():
		on_hover.call(a)
	for c in _tip_box.get_children():
		c.queue_free()
	var lines: PackedStringArray = ActionInfo.lines(_unit, a) if a != null else PackedStringArray([String(s.entry.text)])
	for i in lines.size():
		var l := Label.new()
		l.text = lines[i]
		if i == 0:
			l.theme_type_variation = &"SubTitle"
		else:
			l.add_theme_font_size_override("font_size", 12)
		if i == lines.size() - 1 and i > 3:
			l.add_theme_color_override("font_color", Color(0.75, 0.9, 0.75))  # the caveman line
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(220, 0)
		_tip_box.add_child(l)
	_tip.visible = true
	_tip.reset_size()
	await get_tree().process_frame
	if not is_instance_valid(s) or not _tip.visible:
		return
	var r := s.get_global_rect()
	var vs := get_viewport_rect().size
	var p := Vector2(r.get_center().x - _tip.size.x * 0.5, r.position.y - _tip.size.y - 10)
	if layout == "ring":  # beside the whole ring, on the side away from its middle, so no icon is covered
		var right := r.get_center().x >= _ring_box.get_center().x
		p = Vector2(_ring_box.end.x + 12 if right else _ring_box.position.x - _tip.size.x - 12, r.position.y - 20)
	elif layout == "bar" and is_instance_valid(_bar_panel):  # above the whole bar, clear of its name and pips
		p.y = _bar_panel.get_global_rect().position.y - _tip.size.y - 6
	elif layout == "cards":  # beside the raised card
		p = Vector2(r.end.x + 12, r.position.y - s.lift)
	elif p.y < 4:
		p = Vector2(r.end.x + 10, r.position.y)
	p.x = clampf(p.x, 4, vs.x - _tip.size.x - 4)
	p.y = clampf(p.y, 4, vs.y - _tip.size.y - 4)
	_tip.global_position = p


func _unhover(s: ActionSlot) -> void:
	await get_tree().process_frame
	if not hovering():
		_tip.visible = false
		if on_unhover.is_valid():
			on_unhover.call()
	if is_instance_valid(s) and s.card:
		_settle_cards()


# --- (a) standard: the action bar ---------------------------------------------------------------

func _bar(u: CombatUnit, skills: Array, basics: Array, area: Rect2) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"MenuPanel"
	add_child(panel)
	_bar_panel = panel
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	var name_l := Label.new()
	name_l.text = "%s  HP %d/%d" % [Txt.t(u.name_key), u.hp, u.max_hp]
	name_l.add_theme_font_size_override("font_size", 13)
	head.add_child(name_l)
	if u.res_kind != "":
		head.add_child(_pips(u))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	col.add_child(row)
	var left := VBoxContainer.new()
	row.add_child(left)
	for e in basics.filter(func(e: Dictionary) -> bool: return e.kind in ["move", "undo", "talk"]):
		_small(e, left)
	for e in skills:
		_slot(e, u, Vector2(SLOT, SLOT), row)
	var right := VBoxContainer.new()
	row.add_child(right)
	for e in basics.filter(func(e: Dictionary) -> bool: return e.kind in ["guard", "wait"]):
		_small(e, right)
	panel.reset_size()
	await get_tree().process_frame
	if is_instance_valid(panel):
		panel.position = Vector2(area.get_center().x - panel.size.x * 0.5, area.end.y - panel.size.y - 8)


## The job's resource as pips: mana and charges full or spent, rage filling up.
func _pips(u: CombatUnit) -> Control:
	var c := Control.new()
	var n := maxi(1, u.res_max)
	var w := minf(14.0, 160.0 / n)
	c.custom_minimum_size = Vector2(n * w + 60, 16)
	var col: Color = {"mana": Color(0.35, 0.55, 1.0), "rage": Color(0.95, 0.35, 0.25), "charges": Color(0.95, 0.8, 0.3)}.get(u.res_kind, Color.WHITE)
	c.draw.connect(func() -> void:
		var font := ThemeDB.fallback_font
		c.draw_string(font, Vector2(0, 13), Txt.t("RES_" + u.res_kind.to_upper()), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.85, 0.8))
		for i in n:
			var p := Vector2(58 + i * w + w * 0.5, 8)
			c.draw_circle(p, w * 0.38, col if i < u.res else Color(0.2, 0.2, 0.22))
			c.draw_arc(p, w * 0.38, 0, TAU, 12, Color(0, 0, 0, 0.8), 1.0))
	return c


# --- (b) unique: the ring round the piece ----------------------------------------------------------

func _ring(u: CombatUnit, skills: Array, basics: Array, at: Vector2, area: Rect2) -> void:
	var radius := 62.0 + skills.size() * 6.0
	var c := at + Vector2(0, -24)
	c.x = clampf(c.x, area.position.x + radius + RING_SLOT, area.end.x - radius - RING_SLOT)
	c.y = clampf(c.y, area.position.y + radius + RING_SLOT, area.end.y - 90)
	var n := skills.size()
	var span := minf(PI * 1.2, maxf(PI * 0.5, n * 0.42))
	var halo := Control.new()  # a faint arc the icons sit on
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.draw.connect(func() -> void:
		halo.draw_arc(c, radius, -PI / 2.0 - span / 2.0 - 0.2, -PI / 2.0 + span / 2.0 + 0.2, 32, Color(1, 0.9, 0.6, 0.35), 10.0, true)
		halo.draw_arc(c, radius, -PI / 2.0 - span / 2.0 - 0.2, -PI / 2.0 + span / 2.0 + 0.2, 32, Color(0, 0, 0, 0.5), 2.0, true))
	add_child(halo)
	halo.queue_redraw()
	_ring_box = Rect2(c, Vector2.ZERO)
	for i in n:
		var t := -PI / 2.0 + (0.0 if n == 1 else -span / 2.0 + span * i / (n - 1))
		var s := _slot(skills[i], u, Vector2(RING_SLOT, RING_SLOT), self)
		s.position = c + Vector2(cos(t), sin(t)) * radius - Vector2(RING_SLOT, RING_SLOT) * 0.5
		_ring_box = _ring_box.merge(Rect2(s.position, s.size))
	# the small wheel: move, guard, wait (and undo, talk) on a tight arc under the piece
	var m := basics.size()
	for i in m:
		var t := PI / 2.0 + (0.0 if m == 1 else -0.9 + 1.8 * i / (m - 1))
		var b := _small(basics[i], self)
		b.custom_minimum_size = Vector2(64, 24)
		b.size = b.custom_minimum_size
		b.position = c + Vector2(0, 30) + Vector2(cos(t), sin(t)) * 58 - b.size * 0.5


# --- (c) gutsy: a hand of cards ----------------------------------------------------------------------

var _cards_row: Array[ActionSlot] = []
var _hand_mid := Vector2.ZERO


func _cards(u: CombatUnit, skills: Array, basics: Array, area: Rect2) -> void:
	_cards_row.clear()
	var n := skills.size()
	var step := minf(CARD.x * 0.82, (area.size.x * 0.7) / maxf(1, n))
	_hand_mid = Vector2(area.get_center().x, area.end.y - CARD.y * 0.62)
	for i in n:
		var s := _slot(skills[i], u, CARD, self)
		s.card = true
		_cards_row.append(s)
		s.mouse_entered.connect(_raise.bind(s))
		s.focus_entered.connect(_raise.bind(s))
	_settle_cards()
	# the plain moves as round tokens beside the hand
	var x := _hand_mid.x + n * step * 0.5 + CARD.x * 0.6
	for i in basics.size():
		var b := _small(basics[i], self)
		b.custom_minimum_size = Vector2(76, 28)
		b.size = b.custom_minimum_size
		b.position = Vector2(minf(x, area.end.x - 84), area.end.y - 40 - (basics.size() - i) * 32)


func _settle_cards() -> void:
	var n := _cards_row.size()
	var step := minf(CARD.x * 0.82, 640.0 / maxf(1, n))
	for i in n:
		var s := _cards_row[i]
		if not is_instance_valid(s):
			continue
		var f := 0.0 if n == 1 else float(i) / (n - 1) - 0.5
		s.pivot_offset = Vector2(CARD.x * 0.5, CARD.y)
		s.rotation = f * 0.35
		s.position = _hand_mid + Vector2((i - (n - 1) * 0.5) * step - CARD.x * 0.5, absf(f) * 26.0)
		s.lift = 0.0
		s.move_to_front()  # left to right, each over the last
		s.queue_redraw()


func _raise(s: ActionSlot) -> void:
	_settle_cards()
	s.rotation = 0.0
	s.lift = CARD.y * 0.45  # the whole card shows
	s.move_to_front()
	_tip.move_to_front()
	s.queue_redraw()

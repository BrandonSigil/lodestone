class_name ActionHud
extends Control
## The selected piece's actions as a hand of cards ([USER] 2026-10-30, Brandon picked the cards on dev-action-ui):
## the first hand is MOVE, ATTACK, ABILITIES and ITEMS, then GUARD and WAIT (UNDO, TALK and AID when they apply);
## ABILITIES deals a second hand of the piece's skills and ITEMS one of its belt, each with BACK. Keys 1 to 0 play
## the cards in order. The hover card stays quiet ("it takes up a lot of space"): it fills a fixed panel in the
## bottom-left corner of the play area only when asked, by `tip_mode` "delay" (rest on a card for TIP_DELAY) or
## "corner" (point at the card's info corner), and holding Shift asks in either. Battle hands it the entries;
## "list" stays Battle's own menu.

const LAYOUTS := ["cards", "list"]
const TIP_MODES := ["delay", "corner"]
const BASIC := ["move", "undo", "talk", "guard", "wait"]
const CARD := Vector2(112, 164)
const PEEK := 92.0  ## how much of a card shows over the bottom of the play area
const FRAME_ART := 90.0  ## how far the bottom frame's art (the crest, the leaves) reaches up into the play area
const TIP_DELAY := 0.5  ## seconds resting on a card before its details show (tip_mode "delay")
const TIP_W := 250.0

var layout := "cards"
var tip_mode := "delay"
var on_hover: Callable  ## (ability or null): light its range
var on_unhover: Callable
var _unit: CombatUnit
var _entries: Array = []
var _hand := "main"  ## "main", "skills" or "items"
var _area := Rect2()
var _slots: Array[ActionSlot] = []
var _tip: PanelContainer
var _tip_box: VBoxContainer
var _tip_for: ActionSlot = null
var _hand_mid := Vector2.ZERO


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
	add_child(_tip)


func clear() -> void:
	_clear_cards()
	_entries = []
	_hand = "main"
	visible = false


func _clear_cards() -> void:
	for s in _slots:
		s.queue_free()
	_slots.clear()
	_hide_tip()


## Shows u's entries, the first hand. at: the piece on screen (unused by the hand); area: the play area above the frame.
func show_for(u: CombatUnit, entries: Array, _at: Vector2, area: Rect2) -> void:
	_clear_cards()
	_unit = u
	_entries = entries
	_area = area
	_hand = "main"
	visible = true
	for e in entries:  # load the icons now, not mid-draw
		if e.get("ability") != null:
			ActionInfo.icon_for(e.ability)
	_deal()


## The cards of the hand showing now, in order.
func hand_entries() -> Array:
	var skills := _entries.filter(func(e: Dictionary) -> bool:
		return (e.kind == "skill" and e.ability.id != "strike") or e.kind == "aid")
	var items := _entries.filter(func(e: Dictionary) -> bool: return e.kind == "item")
	var back := {"text": Txt.t("ACT_BACK"), "enabled": true, "cb": _open.bind("main"), "kind": "back", "ability": null, "count": 0}
	match _hand:
		"skills":
			return skills + [back]
		"items":
			return items + [back]
	var out := []
	for e in _entries.filter(func(e: Dictionary) -> bool: return e.kind == "move"):
		out.append(e)
	for e in _entries.filter(func(e: Dictionary) -> bool: return e.kind == "skill" and e.ability.id == "strike"):
		out.append(e)
	if not skills.is_empty():
		out.append({"text": Txt.t("ACT_ABILITIES"), "enabled": skills.any(func(e: Dictionary) -> bool: return e.enabled),
			"cb": _open.bind("skills"), "kind": "group", "ability": null, "count": skills.size(), "icon": skills[0].ability.id})
	if not items.is_empty():
		out.append({"text": Txt.t("ACT_ITEMS"), "enabled": items.any(func(e: Dictionary) -> bool: return e.enabled),
			"cb": _open.bind("items"), "kind": "group", "ability": null, "count": items.size(), "icon": items[0].ability.spends})
	for k in ["undo", "talk", "guard", "wait"]:
		for e in _entries.filter(func(e: Dictionary) -> bool: return e.kind == k):
			out.append(e)
	return out


func _open(hand: String) -> void:
	_hand = hand
	_clear_cards()
	_deal()


## Keys 1 to 0 play the cards of the hand in order.
func press_key(i: int) -> bool:
	if i < _slots.size() and not _slots[i].disabled:
		_slots[i].entry.cb.call()
		return true
	return false


func hovering() -> bool:
	return _slots.any(func(s: ActionSlot) -> bool: return s.is_hovered() or s.has_focus())


func _deal() -> void:
	var hand := hand_entries()
	var n := hand.size()
	_hand_mid = Vector2(_area.get_center().x, _area.end.y - PEEK)  # tops peek over the frame; the rest sits behind it
	for i in n:
		var e: Dictionary = hand[i]
		e["key"] = i if i < 10 else -1
		var s := ActionSlot.new()
		s.entry = e
		s.unit = _unit
		s.card = true
		s.info_corner = tip_mode == "corner" and e.get("ability") != null
		s.custom_minimum_size = CARD
		s.size = CARD
		s.disabled = not bool(e.enabled)
		s.pressed.connect(func() -> void:
			_hide_tip()
			e.cb.call())
		s.mouse_entered.connect(_hover.bind(s))
		s.focus_entered.connect(_hover.bind(s))
		s.mouse_exited.connect(_unhover.bind(s))
		s.focus_exited.connect(_unhover.bind(s))
		s.info_asked.connect(_show_tip.bind(s))
		add_child(s)
		_slots.append(s)
	_settle()
	_tip.move_to_front()


func _settle() -> void:
	var n := _slots.size()
	var step := minf(CARD.x * 0.82, (_area.size.x * 0.62) / maxf(1, n))
	for i in n:
		var s := _slots[i]
		if not is_instance_valid(s):
			continue
		var f := 0.0 if n == 1 else float(i) / (n - 1) - 0.5
		s.pivot_offset = Vector2(CARD.x * 0.5, CARD.y)
		s.rotation = f * 0.35
		s.position = _hand_mid + Vector2((i - (n - 1) * 0.5) * step - CARD.x * 0.5, absf(f) * 26.0)
		s.lift = 0.0
		s.move_to_front()
		s.queue_redraw()
	_tip.move_to_front()


func _raise(s: ActionSlot) -> void:
	_settle()
	s.rotation = 0.0
	s.lift = CARD.y - PEEK + FRAME_ART  # the whole card rises clear of the frame and its crest
	s.move_to_front()
	_tip.move_to_front()
	s.queue_redraw()


func _hover(s: ActionSlot) -> void:
	_raise(s)
	var a: Ability = s.entry.get("ability")
	if on_hover.is_valid():
		on_hover.call(a)
	if a == null or tip_mode != "delay":
		return
	await get_tree().create_timer(TIP_DELAY).timeout  # a short rest on the card asks for its details
	if is_instance_valid(s) and (s.is_hovered() or s.has_focus()):
		_show_tip(s)


func _unhover(s: ActionSlot) -> void:
	await get_tree().process_frame
	if not hovering():
		_hide_tip()
		_settle()
		if on_unhover.is_valid():
			on_unhover.call()
	elif _tip_for == s:
		_hide_tip()


func _process(_delta: float) -> void:
	if not visible or not Input.is_key_pressed(KEY_SHIFT):  # holding Shift asks for the card under the pointer
		return
	for s in _slots:
		if (s.is_hovered() or s.has_focus()) and s.entry.get("ability") != null and _tip_for != s:
			_show_tip(s)


## The details of s's action in the fixed corner panel, bottom left above the frame.
func _show_tip(s: ActionSlot) -> void:
	var a: Ability = s.entry.get("ability")
	if a == null or not is_instance_valid(s):
		return
	_tip_for = s
	for c in _tip_box.get_children():
		_tip_box.remove_child(c)  # gone now, so the panel sizes to the new lines only
		c.queue_free()
	var lines := ActionInfo.lines(_unit, a)
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
		l.custom_minimum_size = Vector2(TIP_W, 0)
		_tip_box.add_child(l)
	_tip.visible = true
	_tip.reset_size()
	await get_tree().process_frame
	if _tip_for == s:
		_tip.position = Vector2(_area.position.x + 10, _area.end.y - _tip.size.y - FRAME_ART * 0.6)


func _hide_tip() -> void:
	_tip_for = null
	if _tip:
		_tip.visible = false

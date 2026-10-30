class_name ActionHud
extends Control
## The selected piece's actions in a dock right above the Lodestone diamond ([USER] 2026-10-30, dev-action-tips:
## "a portrait of the current character selected then boxes for each option"): the portrait, then a row of boxes,
## MOVE, ATTACK, TRICKS, STUFF, GUARD, WAIT (UNDO, TALK and AID when they apply). TRICKS and STUFF open a second row
## of the piece's spells or belt over the first. SWAP goes to the next character who still has moves. Keys 1 to 0
## press the boxes of the top row. A box's details stay quiet: they fill a fixed panel in the bottom-left corner after
## a short rest on the box (TIP_DELAY), or at once while Shift is held. Battle hands it the entries; "list" stays
## Battle's own menu.

const LAYOUTS := ["dock", "list"]
const BASIC := ["move", "undo", "talk", "guard", "wait"]
const BOX := 52.0
const PORTRAIT := 84.0
const FRAME_ART := 90.0  ## how far the bottom frame's art (the diamond crest, the leaves) reaches up into the play area
const TIP_DELAY := 0.5  ## seconds resting on a box before its details show
const TIP_W := 250.0
const PORTRAIT_DIR := "res://art/source/portraits/"

var layout := "dock"
var on_hover: Callable  ## (ability or null): light its range
var on_unhover: Callable
var on_swap: Callable  ## SWAP: the next character with moves
var swap_count := 0  ## other characters who still have moves (SWAP shows when there are any)
var _unit: CombatUnit
var _entries: Array = []
var _hand := "main"  ## the second row open: "skills", "items", or "main" for none
var _area := Rect2()
var _slots: Array[ActionSlot] = []  ## the boxes of the top row (keys 1 to 0), then the rest
var _dock: PanelContainer
var _tip: PanelContainer
var _tip_box: VBoxContainer
var _tip_for: ActionSlot = null


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
	_clear_dock()
	_entries = []
	_hand = "main"
	visible = false


func _clear_dock() -> void:
	_slots.clear()
	if _dock != null:
		remove_child(_dock)
		_dock.queue_free()
		_dock = null
	_hide_tip()


## Shows u's entries. area: the play area above the frame.
func show_for(u: CombatUnit, entries: Array, _at: Vector2, area: Rect2) -> void:
	_clear_dock()
	_unit = u
	_entries = entries
	_area = area
	_hand = "main"
	visible = true
	for e in entries:  # load the icons now, not mid-draw
		if e.get("ability") != null:
			ActionInfo.icon_for(e.ability)
	_build()


## The first row's boxes, in order.
func hand_entries() -> Array:
	var skills := _skills()
	var items := _entries.filter(func(e: Dictionary) -> bool: return e.kind == "item")
	var out := []
	for e in _entries.filter(func(e: Dictionary) -> bool: return e.kind == "move"):
		out.append(e)
	for e in _entries.filter(func(e: Dictionary) -> bool: return e.kind == "skill" and e.ability.id == "strike"):
		out.append(e)
	if not skills.is_empty():
		out.append({"text": Txt.t("ACT_ABILITIES"), "enabled": skills.any(func(e: Dictionary) -> bool: return e.enabled),
			"cb": _open.bind("skills"), "kind": "group", "ability": null, "count": skills.size(), "icon": skills[0].ability.id, "opens": "skills"})
	if not items.is_empty():
		out.append({"text": Txt.t("ACT_ITEMS"), "enabled": items.any(func(e: Dictionary) -> bool: return e.enabled),
			"cb": _open.bind("items"), "kind": "group", "ability": null, "count": items.size(), "icon": items[0].ability.spends, "opens": "items"})
	for k in ["undo", "talk", "guard", "wait"]:
		for e in _entries.filter(func(e: Dictionary) -> bool: return e.kind == k):
			out.append(e)
	return out


## The second row: the spells or the belt, while TRICKS or STUFF is open.
func second_entries() -> Array:
	match _hand:
		"skills":
			return _skills()
		"items":
			return _entries.filter(func(e: Dictionary) -> bool: return e.kind == "item")
	return []


func _skills() -> Array:
	return _entries.filter(func(e: Dictionary) -> bool: return (e.kind == "skill" and e.ability.id != "strike") or e.kind == "aid")


## TRICKS or STUFF: open its row, or shut it if it's open.
func _open(hand: String) -> void:
	_hand = "main" if _hand == hand else hand
	_clear_dock()
	_build()


## Keys 1 to 0 press the top row's boxes: the second row while it's open, else the first.
func press_key(i: int) -> bool:
	var row := second_entries() if _hand != "main" else hand_entries()
	if i >= row.size() or not bool(row[i].enabled):
		return false
	row[i].cb.call()
	return true


func hovering() -> bool:
	return _slots.any(func(s: ActionSlot) -> bool: return s.is_hovered() or s.has_focus())


func _build() -> void:
	_dock = PanelContainer.new()
	_dock.theme_type_variation = &"MenuPanel"
	add_child(_dock)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_dock.add_child(row)
	row.add_child(_portrait(_unit))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	var head := Label.new()
	head.text = "%s  HP %d/%d%s" % [Txt.t(_unit.name_key), _unit.hp, _unit.max_hp,
		("  %s %d/%d" % [Txt.t("RES_" + _unit.res_kind.to_upper()), _unit.res, _unit.res_max]) if _unit.res_kind != "" else ""]
	head.theme_type_variation = &"SubTitle"
	col.add_child(head)
	var second := second_entries()
	if not second.is_empty():
		col.add_child(_row(second, true))
	col.add_child(_row(hand_entries(), second.is_empty()))
	if swap_count > 0:
		var swap := Button.new()
		swap.text = Txt.t("UI_SWAP")
		swap.custom_minimum_size = Vector2(70, BOX)
		swap.size_flags_vertical = Control.SIZE_SHRINK_END
		swap.pressed.connect(func() -> void:
			if on_swap.is_valid():
				on_swap.call())
		row.add_child(swap)
	_dock.reset_size()
	_place.call_deferred()
	_tip.move_to_front()


## Right above the Lodestone diamond: centred, standing on the frame's crest.
func _place() -> void:
	if _dock == null:
		return
	_dock.reset_size()
	_dock.position = Vector2(_area.get_center().x - _dock.size.x * 0.5, _area.end.y - FRAME_ART - _dock.size.y)


func _row(entries: Array, keys: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for i in entries.size():
		var e: Dictionary = entries[i]
		e["key"] = i if keys and i < 10 else -1
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 1)
		var s := ActionSlot.new()
		s.entry = e
		s.unit = _unit
		s.custom_minimum_size = Vector2(BOX, BOX)
		s.disabled = not bool(e.enabled)
		s.open = String(e.get("opens", "")) != "" and String(e.get("opens", "")) == _hand
		s.pressed.connect(func() -> void:
			_hide_tip()
			e.cb.call())
		s.mouse_entered.connect(_hover.bind(s))
		s.focus_entered.connect(_hover.bind(s))
		s.mouse_exited.connect(_unhover.bind(s))
		s.focus_exited.connect(_unhover.bind(s))
		box.add_child(s)
		var l := Label.new()
		l.text = String(e.text)
		l.add_theme_font_size_override("font_size", 10)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(BOX, 0)
		l.clip_text = true
		box.add_child(l)
		row.add_child(box)
		_slots.append(s)
	return row


## The selected character's face: its approved portrait (art/source/portraits/<id>.png), else its name.
func _portrait(u: CombatUnit) -> Control:
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"InfoPanel"
	frame.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	var p := PORTRAIT_DIR + String(u.figure) + ".png"
	if ResourceLoader.exists(p):
		var t := TextureRect.new()
		t.texture = load(p)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.custom_minimum_size = Vector2(PORTRAIT - 8, PORTRAIT - 8)
		frame.add_child(t)
	else:
		var l := Label.new()
		l.text = Txt.t(u.name_key)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		frame.add_child(l)
	return frame


func _hover(s: ActionSlot) -> void:
	var a: Ability = s.entry.get("ability")
	if on_hover.is_valid():
		on_hover.call(a)
	if a == null:
		return
	await get_tree().create_timer(TIP_DELAY).timeout  # a short rest on the box asks for its details
	if is_instance_valid(s) and (s.is_hovered() or s.has_focus()):
		_show_tip(s)


func _unhover(s: ActionSlot) -> void:
	await get_tree().process_frame
	if not hovering():
		_hide_tip()
		if on_unhover.is_valid():
			on_unhover.call()
	elif _tip_for == s:
		_hide_tip()


func _process(_delta: float) -> void:
	if not visible or not Input.is_key_pressed(KEY_SHIFT):  # holding Shift asks for the box under the pointer
		return
	for s in _slots:
		if is_instance_valid(s) and (s.is_hovered() or s.has_focus()) and s.entry.get("ability") != null and _tip_for != s:
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

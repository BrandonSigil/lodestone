class_name ActionHud
extends Control
## The selected piece's actions in a dock right above the Lodestone diamond ([USER] 2026-10-30, dev-action-tips and
## Brandon's pictures on dev-action-dock): a framed portrait panel (face, HP bar, the job's resource as pips) and a
## framed bar of numbered boxes, MOVE (UNDO once moved), HIT, TRICKS, BELT, WAIT. Hovering or focusing a box pops its
## column up above it: GUARD (and AID, TALK) over HIT, the spells over TRICKS, the belt over BELT. Left and right go
## along the bar, up and down along a column (keys or a controller); keys 1 to 0 pick a bar box. SWAP goes to the
## next character who still has moves. A box's details stay quiet: they fill a fixed panel in the bottom-left corner after
## a short rest on the box (TIP_DELAY), or at once while Shift is held. Battle hands it the entries; "list" stays
## Battle's own menu.

const LAYOUTS := ["dock", "list"]
const BASIC := ["move", "undo", "talk", "guard", "wait"]
const BOX := 52.0
const DOCK_ART := "res://art/source/ui/dock/"  ## Brandon's painted dock pieces (approved 2026-10-30)
const KS := 0.36  ## bar pieces: the art's pixels to dock units (the ends stay fixed, the fill stretches to the boxes)
const KP := 0.32  ## portrait frame
const KC := 0.7  ## pop-up column pieces
const PW := 127.0  ## the portrait frame's inner width, window and meters
const FRAME_ART := 90.0  ## how far the bottom frame's art (the diamond crest, the leaves) reaches up into the play area
const TIP_DELAY := 0.5  ## seconds resting on a box before its details show
const TIP_W := 205.0  ## narrow enough to sit beside the dock's portrait panel
const PORTRAIT_DIR := "res://art/source/portraits/"

var layout := "dock"
var on_hover: Callable  ## (ability or null): light its range
var on_unhover: Callable
var on_swap: Callable  ## SWAP: the next character with moves
var swap_count := 0  ## other characters who still have moves (SWAP shows when there are any)
var _unit: CombatUnit
var _entries: Array = []
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
	visible = false


func _clear_dock() -> void:
	_close_pop()
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
	visible = true
	for e in entries:  # load the icons now, not mid-draw
		if e.get("ability") != null:
			ActionInfo.icon_for(e.ability)
	_build()


## The bar's boxes, in order ([USER] 2026-10-30, Brandon's picture on dev-action-dock): MOVE (UNDO once moved), HIT,
## TRICKS, BELT, WAIT. Each may carry a column ("pop") that pops up above it: GUARD (and AID, TALK) over HIT, the
## spells over TRICKS, belt items 2 on over BELT (the box itself is belt item 1).
func hand_entries() -> Array:
	var out := []
	var first := _entries.filter(func(e: Dictionary) -> bool: return e.kind == "undo")
	if first.is_empty():
		first = _entries.filter(func(e: Dictionary) -> bool: return e.kind == "move")
	out.append_array(first)
	var strike := _entries.filter(func(e: Dictionary) -> bool: return e.kind == "skill" and e.ability.id == "strike")
	var under_hit := _entries.filter(func(e: Dictionary) -> bool: return e.kind in ["guard", "aid", "talk"])
	if not strike.is_empty():
		var hit: Dictionary = strike[0].duplicate()
		hit["pop"] = under_hit
		out.append(hit)
	elif not under_hit.is_empty():
		out.append(under_hit[0])
	var skills := _skills()
	if not skills.is_empty():
		out.append({"text": Txt.t("ACT_ABILITIES"), "enabled": skills.any(func(e: Dictionary) -> bool: return e.enabled),
			"cb": Callable(), "kind": "group", "ability": null, "count": skills.size(), "icon": skills[0].ability.id, "pop": skills})
	var items := _entries.filter(func(e: Dictionary) -> bool: return e.kind == "item")
	if not items.is_empty():
		var belt: Dictionary = items[0].duplicate()  # [USER] 2026-10-30: the box is the first item, the column holds the rest
		belt["pop"] = items.slice(1)
		out.append(belt)
	out.append_array(_entries.filter(func(e: Dictionary) -> bool: return e.kind == "wait"))
	return out


## The column popped up now (its entries, nearest the bar first), or [].
func second_entries() -> Array:
	return _pop_entries


func _skills() -> Array:
	return _entries.filter(func(e: Dictionary) -> bool: return e.kind == "skill" and e.ability.id != "strike")


## Keys 1 to 0: the bar's boxes. TRICKS and BELT pop their column and go up into it; HIT strikes (GUARD is up its
## column); the rest are pressed.
func press_key(i: int) -> bool:
	if i >= _bar_slots.size():
		return false
	var s := _bar_slots[i]
	if s.entry.has("pop") and not (s.entry.pop as Array).is_empty() and not s.entry.cb.is_valid():  # TRICKS, BELT
		_pop(s)
		if not _pop_slots.is_empty():
			_pop_slots[0].grab_focus()
		return true
	if s.disabled:
		return false
	s.entry.cb.call()
	return true


func hovering() -> bool:
	return _slots.any(func(s: ActionSlot) -> bool: return is_instance_valid(s) and (s.is_hovered() or s.has_focus()))


var _bar_slots: Array[ActionSlot] = []
var _pop_slots: Array[ActionSlot] = []
var _pop_entries: Array = []
var _pop_for: ActionSlot = null
var _pop_panel: PanelContainer = null
var _bar: PanelContainer = null


func _build() -> void:
	_bar_slots.clear()
	_tex("bar_fill")  # loads every piece
	_dock = PanelContainer.new()  # a bare holder: the portrait panel and the bar are framed apart, as in his picture
	_dock.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_dock)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_dock.add_child(row)
	row.add_child(_portrait_panel(_unit))
	var bar := _art_panel(Vector2(38, 20), Vector2(38, 20), Vector2(0, 292 * KS), _draw_bar)  # left piece, fill, right piece
	bar.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(bar)
	_bar = bar
	var boxes := HBoxContainer.new()
	boxes.add_theme_constant_override("separation", 4)
	bar.add_child(boxes)
	var hand := hand_entries()
	for i in hand.size():
		if i > 0:
			boxes.add_child(_diamond_sep())
		var e: Dictionary = hand[i]
		e["key"] = i if i < 10 else -1
		var s := _box(e, boxes)
		_bar_slots.append(s)
		if e.has("pop") and not (e.pop as Array).is_empty():
			s.mouse_entered.connect(_pop.bind(s))
			s.focus_entered.connect(_pop.bind(s))
	for i in _bar_slots.size():  # left and right along the bar
		var s := _bar_slots[i]
		s.focus_neighbor_left = s.get_path_to(_bar_slots[(i - 1 + _bar_slots.size()) % _bar_slots.size()])
		s.focus_neighbor_right = s.get_path_to(_bar_slots[(i + 1) % _bar_slots.size()])
		s.focus_neighbor_top = s.get_path()
		s.focus_neighbor_bottom = s.get_path()
	if swap_count > 0:
		var swap := Button.new()
		swap.text = Txt.t("UI_SWAP")
		swap.custom_minimum_size = Vector2(70, BOX)
		swap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swap.pressed.connect(func() -> void:
			if on_swap.is_valid():
				on_swap.call())
		row.add_child(swap)
	_dock.reset_size()
	_place.call_deferred()
	_tip.move_to_front()


## One box: the icon, its key number, the label under it.
func _box(e: Dictionary, parent: Control) -> ActionSlot:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	var s := ActionSlot.new()
	s.entry = e
	s.unit = _unit
	s.custom_minimum_size = Vector2(BOX, BOX)
	s.disabled = not bool(e.enabled)
	s.pressed.connect(func() -> void:
		_hide_tip()
		if e.has("pop") and not (e.pop as Array).is_empty() and not e.cb.is_valid():
			_pop(s)  # TRICKS and BELT only pop their column
			if not _pop_slots.is_empty():
				_pop_slots[0].grab_focus()
			return
		e.cb.call())
	s.mouse_entered.connect(_hover.bind(s))
	s.focus_entered.connect(_hover.bind(s))
	s.mouse_exited.connect(_unhover.bind(s))
	s.focus_exited.connect(_unhover.bind(s))
	col.add_child(s)
	var l := Label.new()
	l.text = String(e.text)
	l.add_theme_font_size_override("font_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # a long caveman name wraps under its box
	l.custom_minimum_size = Vector2(BOX + 10, 0)
	col.add_child(l)
	parent.add_child(col)
	_slots.append(s)
	return s


const PIECES := ["bar_left", "bar_fill", "bar_right", "bar_crest_top", "bar_crest_bottom", "portrait_frame", "column_top", "column_mid", "column_bottom"]
var _pieces := {}


## A dock piece. They are all loaded before the first build: a texture first loaded mid-draw paints white.
func _tex(n: String) -> Texture2D:
	if _pieces.is_empty():
		for k in PIECES:
			_pieces[k] = load(DOCK_ART + k + ".png")
	return _pieces[n]


## A panel whose frame is painted pieces: empty margins keep the content clear of the rims; draw paints the pieces.
func _art_panel(margin_from: Vector2, margin_to: Vector2, min_size: Vector2, painter: Callable) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = margin_from.x
	sb.content_margin_top = margin_from.y
	sb.content_margin_right = margin_to.x
	sb.content_margin_bottom = margin_to.y
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = min_size
	p.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # painted big, drawn small
	p.draw.connect(painter.bind(p))
	return p


## The bar: fixed left and right ends, a fill that grows or shrinks with the boxes, the crests on top and under.
func _draw_bar(c: Control) -> void:
	var left := _tex("bar_left")
	var lw := left.get_width() * KS
	c.draw_texture_rect(_tex("bar_fill"), Rect2(lw - 1.0, 0, c.size.x - 2.0 * lw + 2.0, c.size.y), false)
	c.draw_texture_rect(left, Rect2(0, 0, lw, c.size.y), false)
	c.draw_texture_rect(_tex("bar_right"), Rect2(c.size.x - lw, 0, lw, c.size.y), false)
	var top := _tex("bar_crest_top")
	var tw := top.get_width() * KS
	c.draw_texture_rect(top, Rect2((c.size.x - tw) * 0.5, 55 * KS - top.get_height() * KS, tw, top.get_height() * KS), false)
	var bottom := _tex("bar_crest_bottom")
	var bw := bottom.get_width() * KS
	c.draw_texture_rect(bottom, Rect2((c.size.x - bw) * 0.5, c.size.y - 55 * KS, bw, bottom.get_height() * KS), false)


## A pop-up column: the arched top, a middle that stretches to the entries, the hanging bottom.
func _draw_column(c: Control) -> void:
	var th := _tex("column_top").get_height() * KC
	var bh := _tex("column_bottom").get_height() * KC
	if c.size.y - th - bh > 0.0:
		c.draw_texture_rect(_tex("column_mid"), Rect2(0, th - 1.0, c.size.x, c.size.y - th - bh + 2.0), false)
	c.draw_texture_rect(_tex("column_top"), Rect2(0, 0, c.size.x, th), false)
	c.draw_texture_rect(_tex("column_bottom"), Rect2(0, c.size.y - bh, c.size.x, bh), false)


func _diamond_sep() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(10, BOX)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void: UiTheme.diamond(c, Vector2(5, BOX + 8), 4.0))
	return c


## The column over bar box s: its entries stacked upward, the first nearest the bar. Up and down move along it; down
## from the first goes back to s.
func _pop(s: ActionSlot) -> void:
	if _pop_for == s and _pop_panel != null:
		return
	_close_pop()
	var entries: Array = s.entry.pop
	_pop_for = s
	_pop_entries = entries
	_pop_panel = _art_panel(Vector2(24, 75 * KC), Vector2(24, 40 * KC), Vector2(160 * KC, (128 + 104) * KC), _draw_column)
	add_child(_pop_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	_pop_panel.add_child(col)
	var made: Array[ActionSlot] = []
	for i in range(entries.size() - 1, -1, -1):  # built top-down, so the first entry ends up nearest the bar
		var e: Dictionary = entries[i]
		e["key"] = -1
		made.push_front(_box(e, col))
		made[0].mouse_exited.connect(_maybe_close_pop)
	_pop_slots = made
	for i in made.size():
		var m := made[i]
		m.focus_neighbor_bottom = m.get_path_to(s) if i == 0 else m.get_path_to(made[i - 1])
		m.focus_neighbor_top = m.get_path_to(made[mini(i + 1, made.size() - 1)])
		m.focus_neighbor_left = m.get_path()
		m.focus_neighbor_right = m.get_path()
	s.focus_neighbor_top = s.get_path_to(made[0])
	_pop_panel.reset_size()
	await get_tree().process_frame
	if not is_instance_valid(_pop_panel) or _pop_for != s:
		return
	_pop_panel.reset_size()
	var k := UiTheme.small()
	_pop_panel.scale = Vector2(k, k)
	var r := s.get_global_rect()
	var top := r.position.y - _pop_panel.size.y * k - 4
	var x := r.get_center().x - _pop_panel.size.x * k * 0.5
	if _bar != null and is_instance_valid(_bar):  # the bar's top crest rises above the boxes: a column over it stands on the crest
		var crest := _tex("bar_crest_top")
		var cw := crest.get_width() * KS * k
		var bx := _bar.global_position.x + (_bar.size.x * k - cw) * 0.5
		if x < bx + cw and x + _pop_panel.size.x * k > bx:
			top = minf(top, _bar.global_position.y + (55 * KS - crest.get_height() * KS) * k - _pop_panel.size.y * k - 2)
	_pop_panel.global_position = Vector2(x, top)
	_tip.move_to_front()


func _close_pop() -> void:
	if _pop_for != null and is_instance_valid(_pop_for):
		_pop_for.focus_neighbor_top = _pop_for.get_path()
	for m in _pop_slots:
		_slots.erase(m)
	_pop_slots.clear()
	_pop_entries = []
	_pop_for = null
	if _pop_panel != null:
		remove_child(_pop_panel)
		_pop_panel.queue_free()
		_pop_panel = null


## The pointer or focus left both the box and its column: the column goes.
func _maybe_close_pop() -> void:
	await get_tree().process_frame
	if _pop_for == null:
		return
	var on := is_instance_valid(_pop_for) and (_pop_for.is_hovered() or _pop_for.has_focus())
	for m in _pop_slots:
		on = on or (is_instance_valid(m) and (m.is_hovered() or m.has_focus()))
	if not on:
		_close_pop()


## Right above the Lodestone diamond: centred, standing on the frame's crest. MOVE takes the focus, so the arrow
## keys and a controller's stick work at once.
func _place() -> void:
	if _dock == null:
		return
	_dock.reset_size()
	var k := UiTheme.small()  # [USER] 2026-10-30: the fight dock much smaller, with a size option
	_dock.scale = Vector2(k, k)
	_dock.position = Vector2(_area.get_center().x - _dock.size.x * k * 0.5, _area.end.y - FRAME_ART - _dock.size.y * k)
	if not _bar_slots.is_empty() and not hovering():
		_bar_slots[0].grab_focus()


## The portrait panel: the painted frame, the selected character's face in its window, an HP bar with HP/max and the
## job's resource as pips with res/max in the green band under it.
func _portrait_panel(u: CombatUnit) -> Control:
	var frame := _tex("portrait_frame")
	var panel := Control.new()
	panel.custom_minimum_size = frame.get_size() * KP
	panel.size_flags_vertical = Control.SIZE_SHRINK_END
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	panel.draw.connect(func() -> void: panel.draw_texture_rect(frame, Rect2(Vector2.ZERO, frame.get_size() * KP), false))
	var window := Rect2(Vector2(82, 108) * KP, Vector2(392, 322) * KP)  # the cream window, in the art's pixels
	panel.add_child(_portrait(u, window))
	var x := 80.0 * KP
	var y := 442.0 * KP
	var hp := _meter(u.hp, u.max_hp, Color(0.78, 0.2, 0.17), false)
	hp.position = Vector2(x, y)
	panel.add_child(hp)
	if u.res_kind != "":
		var tint: Color = {"mana": Color(0.35, 0.55, 1.0), "rage": Color(0.9, 0.35, 0.2), "charges": Color(0.9, 0.7, 0.2)}.get(u.res_kind, Color.WHITE)
		var res := _meter(u.res, u.res_max, tint, true)
		res.position = Vector2(x, y + 13.0)
		panel.add_child(res)
	return panel


## A bar (HP) or a row of pips (the resource), with value/max beside it.
func _meter(v: int, most: int, tint: Color, pips: bool) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(PW, 13)
	c.size = c.custom_minimum_size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var w := PW - 32.0
		var r := Rect2(0, 1, w, 11)
		c.draw_rect(r, Color(0.06, 0.08, 0.07))
		if pips and most > 0:
			var each := (w - 2.0) / most
			for i in most:
				var pr := Rect2(1 + i * each + 1, 2, each - 2, 9)
				c.draw_rect(pr, tint if i < v else Color(tint, 0.15))
		elif most > 0:
			c.draw_rect(Rect2(1, 2, (w - 2) * clampf(float(v) / most, 0, 1), 9), tint)
		c.draw_rect(r, UiTheme.RULE, false, 1.0)
		c.draw_string(ThemeDB.fallback_font, Vector2(w + 3, 11), "%d/%d" % [v, most], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UiTheme.PARCHMENT))
	return c


## The selected character's face: its approved portrait (art/source/portraits/<id>.png), else its name.
func _portrait(u: CombatUnit, window: Rect2) -> Control:
	var p := PORTRAIT_DIR + String(u.figure) + ".png"
	var c: Control
	if ResourceLoader.exists(p):
		var t := TextureRect.new()
		t.texture = load(p)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		c = t
	else:
		var l := Label.new()
		l.text = Txt.t(u.name_key)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", Color(0.2, 0.17, 0.12))
		c = l
	c.position = window.position
	c.size = window.size
	c.clip_contents = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


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
	_maybe_close_pop()
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
		var k := UiTheme.small()
		_tip.scale = Vector2(k, k)
		_tip.position = Vector2(_area.position.x + 10, _area.end.y - _tip.size.y * k - FRAME_ART * 0.6)  # bottom left


func _hide_tip() -> void:
	_tip_for = null
	if _tip:
		_tip.visible = false

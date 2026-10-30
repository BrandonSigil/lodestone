class_name FrameHud
extends CanvasLayer
## The border that frames every screen: party strip on the left, the pack along the bottom,
## a status line on top and a side panel for the screen's own controls.
## Graybox panels for now; Brandon's 9-slice border replaces the StyleBoxes later.

const LEFT_W := 210.0
const RIGHT_W := 250.0
const TOP_H := 40.0
const BOTTOM_H := 78.0
const PACK_CELL := 15.0  ## the bottom bar's copy of the pack grid
## Brandon's leaf frame ([USER] 2026-10-29), and spots in its own pixels (2000 x 261).
const LEAF_ART := "res://art/source/ui/frame_bottom.webp"
const LEAF_BAND_TOP := 102.0  ## the solid band starts here; above it only leaves and the diamond poke up
const LEAF_PACK := Rect2(128, 133, 130, 108)  ## inside the left square's rim: the inventory button
const LEAF_PARTY := Rect2(1295, 132, 495, 104)  ## inside the right panel's rim: the party, up to 4
const LEAF_BAR := Rect2(345, 134, 380, 48)  ## the long bar's top half (its ornament runs below): tracked goals
const LEAF_PARTY_MAX := 4
const LEAF_DECOR_TOP := 50.0  ## the corner leaves reach up to here; buttons above the frame sit higher
const LEAF_DIAMOND_TOP := 2.0  ## the centre diamond's tip
const FRAME := Color(0.17, 0.23, 0.22)
const PANEL := Color(0.23, 0.29, 0.28)
const INK := Color(0.9, 0.92, 0.87)

var top_label: Label
var party_box: VBoxContainer
var slots_box: HBoxContainer
var slots_label: Label
var side: VBoxContainer
var tools_box: HBoxContainer  ## bottom-right buttons: PACK, and the Lodestone once it is found
var root: Control
var bottom_h := BOTTOM_H  ## the bottom border; the leaf frame's band is taller
var clear_h := BOTTOM_H  ## the bottom border plus whatever art pokes above it (the leaf frame's diamond)
var leaf: Control = null  ## the leaf frame along the bottom (explore maps and the overworld walk), or null
var side_panel: PanelContainer = null  ## with the leaf frame: the screen's controls float over the map, top right
var leaf_pack: Button
var leaf_party: HBoxContainer
var leaf_goals: Label  ## tracked restore steps and what they still miss ([USER] omr-5)
var _leaf_art: TextureRect
var _leaf_block: Control
var _leaf_pack_cb := Callable()
var _border: StyleBoxFlat


func _init() -> void:
	layer = 1
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var border := Panel.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = FRAME
	sb.set_border_width(SIDE_LEFT, int(LEFT_W))
	sb.set_border_width(SIDE_RIGHT, int(RIGHT_W))
	sb.set_border_width(SIDE_TOP, int(TOP_H))
	sb.set_border_width(SIDE_BOTTOM, int(BOTTOM_H))
	border.add_theme_stylebox_override("panel", sb)
	_border = sb
	root.add_child(border)

	top_label = _label("", 18)
	_pin(top_label, 0, 0, 1, 0, LEFT_W, 8, -RIGHT_W, TOP_H)
	root.add_child(top_label)

	party_box = VBoxContainer.new()
	_pin(party_box, 0, 0, 0, 1, 12, TOP_H, LEFT_W - 12, -BOTTOM_H)
	party_box.add_theme_constant_override("separation", 6)
	root.add_child(party_box)
	party_box.add_child(_label(Txt.t("UI_PARTY"), 14))

	slots_label = _label(Txt.t("UI_ITEMS"), 14)
	_pin(slots_label, 0, 1, 1, 1, LEFT_W, -BOTTOM_H + 4, -RIGHT_W, -BOTTOM_H + 24)
	root.add_child(slots_label)
	slots_box = HBoxContainer.new()
	_pin(slots_box, 0, 1, 1, 1, LEFT_W, -BOTTOM_H + 28, -RIGHT_W, -8)
	slots_box.add_theme_constant_override("separation", 6)
	root.add_child(slots_box)

	tools_box = HBoxContainer.new()
	_pin(tools_box, 1, 1, 1, 1, -RIGHT_W + 14, -BOTTOM_H + 12, -14, -10)
	tools_box.add_theme_constant_override("separation", 8)
	tools_box.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(tools_box)

	side = VBoxContainer.new()
	_pin(side, 1, 0, 1, 1, -RIGHT_W + 14, TOP_H, -14, -BOTTOM_H)
	side.add_theme_constant_override("separation", 8)
	root.add_child(side)


## Anchors (0 or 1 per edge) plus pixel offsets from those anchors.
static func _pin(c: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, orr: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = orr
	c.offset_bottom = ob


func _label(text: String, font_size := 16) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## The play area inside the border, in viewport coordinates.
func center_rect() -> Rect2:
	var vs := root.get_viewport_rect().size
	if leaf != null:  # [USER] 2026-10-29: the game fills the whole window above the leaf frame
		return Rect2(0, 0, vs.x, vs.y - bottom_h)
	return Rect2(LEFT_W, TOP_H, vs.x - LEFT_W - RIGHT_W, vs.y - TOP_H - bottom_h)


## The play area with nothing drawn over it: center_rect less the art that pokes above the bottom band.
## For screens laid out to fit (the overworld map); a scrolling map can run under the leaves.
func clear_rect() -> Rect2:
	var r := center_rect()
	r.size.y -= clear_h - bottom_h
	return r


## Swaps the bottom bar for Brandon's leaf frame: the band scaled to the screen width, the inventory
## button in its left square, the party in its right panel, each member in a small square frame. The long
## bar and the centre diamond stay bare art for now (the Lodestone medallion goes in the diamond later).
## Clicks on the band don't reach the map. set_tools gives the entry with "id": "pack" to the square; the rest
## sit above the frame on the right. [USER] 2026-10-29: nothing else frames the game: no grey border, no
## party list on the left, no title along the top, no help text; the screen's own buttons and lines float in
## a small see-through box at the top right of the map.
func use_leaf_frame() -> void:
	if leaf != null:
		return
	leaf = Control.new()
	leaf.set_anchors_preset(Control.PRESET_FULL_RECT)
	leaf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(leaf)
	_leaf_block = Control.new()
	_leaf_block.mouse_filter = Control.MOUSE_FILTER_STOP
	leaf.add_child(_leaf_block)
	_leaf_art = TextureRect.new()
	_leaf_art.texture = load(LEAF_ART)
	_leaf_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_leaf_art.stretch_mode = TextureRect.STRETCH_SCALE
	_leaf_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	leaf.add_child(_leaf_art)
	leaf_pack = Button.new()
	leaf_pack.text = Txt.t("UI_PACK")
	leaf_pack.flat = true
	leaf_pack.add_theme_color_override("font_color", INK)
	leaf_pack.add_theme_font_size_override("font_size", 18)
	leaf_pack.pressed.connect(func() -> void:
		if _leaf_pack_cb.is_valid():
			_leaf_pack_cb.call())
	leaf.add_child(leaf_pack)
	leaf_goals = _label("", 11)
	leaf_goals.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	leaf_goals.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	leaf_goals.clip_text = true
	leaf.add_child(leaf_goals)
	leaf_party = HBoxContainer.new()
	leaf_party.add_theme_constant_override("separation", 4)
	leaf_party.mouse_filter = Control.MOUSE_FILTER_IGNORE
	leaf.add_child(leaf_party)
	slots_label.visible = false
	slots_box.visible = false
	party_box.visible = false
	top_label.visible = false
	_border.set_border_width_all(0)
	side_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.1, 0.72)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	side_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(side_panel)
	root.move_child(side_panel, leaf.get_index())  # under the frame and its buttons
	side.get_parent().remove_child(side)
	side.set_anchors_preset(Control.PRESET_TOP_LEFT)
	side_panel.add_child(side)
	for c in side.get_children():
		if c.has_meta("help"):
			c.visible = false
	leaf.resized.connect(_layout_leaf)
	_layout_leaf()


func _layout_leaf() -> void:
	var vs := leaf.size if leaf.size.x > 0.0 else root.get_viewport_rect().size
	var art := _leaf_art.texture.get_size()
	var s := vs.x / art.x
	var top := vs.y - art.y * s
	_leaf_art.position = Vector2(0, top)
	_leaf_art.size = art * s
	bottom_h = (art.y - LEAF_BAND_TOP) * s
	clear_h = (art.y - LEAF_DIAMOND_TOP) * s
	_leaf_block.position = Vector2(0, vs.y - bottom_h)
	_leaf_block.size = Vector2(vs.x, bottom_h)
	leaf_pack.position = Vector2(0, top) + LEAF_PACK.position * s
	leaf_pack.size = LEAF_PACK.size * s
	leaf_goals.position = Vector2(0, top) + LEAF_BAR.position * s
	leaf_goals.size = LEAF_BAR.size * s
	leaf_party.position = Vector2(0, top) + LEAF_PARTY.position * s
	leaf_party.size = LEAF_PARTY.size * s
	for c in leaf_party.get_children():
		(c as Control).custom_minimum_size = _member_size()
	var clear := (art.y - LEAF_DECOR_TOP) * s + 6.0
	_pin(tools_box, 1, 1, 1, 1, -RIGHT_W + 14, -clear - 52, -14, -clear)
	_pin(side_panel, 1, 0, 1, 0, -RIGHT_W + 4, 46, -10, 46)  # under a fight's AUTO FIGHT button
	side_panel.grow_vertical = Control.GROW_DIRECTION_END


const RES_COLORS := {"mana": Color(0.35, 0.55, 1.0), "rage": Color(0.9, 0.3, 0.25), "charges": Color(0.95, 0.8, 0.3)}


## The job's resource as a thin bar in its own colour (mana blue, rage red, charges gold).
func _res_bar(e: Dictionary, size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = maxi(1, int(e.res_max))
	bar.value = int(e.res)
	bar.show_percentage = false
	bar.custom_minimum_size = size
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = RES_COLORS.get(String(e.res_kind), Color.WHITE)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _process(_delta: float) -> void:
	# the floating controls box only shows while it holds a button or a line to read
	if side_panel != null:
		side_panel.visible = side.get_children().any(func(c: Node) -> bool:
			return (c as CanvasItem).visible and (c is Button or (c is Label and (c as Label).text != "")))


## A member's square in the party panel: as tall as the panel, four fit across.
func _member_size() -> Vector2:
	var side_len := minf(leaf_party.size.y, leaf_party.size.x / LEAF_PARTY_MAX - 6.0)
	return Vector2(side_len, side_len)


## One member in the leaf frame's party panel ([USER] 2026-10-29: little square frames that fit inside that
## rectangle): pawn, name and HP numbers, the HP bar, and in a fight the job's bar.
func _leaf_member(e: Dictionary) -> Control:
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = _member_size()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.12, 0.12, 0.55)
	sb.border_color = Color(0.93, 0.88, 0.74, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := PawnIcon.new()
	icon.tint = e.tint
	icon.dim = e.hp <= 0
	icon.custom_minimum_size = Vector2(16, 22)
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -2)
	words.add_child(_label(e.name, 10))
	words.add_child(_label("%d/%d%s" % [e.hp, e.max_hp, (" " + e.note) if e.get("note", "") != "" else ""], 9))
	row.add_child(words)
	col.add_child(row)
	var bar := ProgressBar.new()
	bar.max_value = e.max_hp
	bar.value = e.hp
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 5)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bar)
	if e.get("res_kind", "") != "":
		col.add_child(_res_bar(e, Vector2(0, 4)))
	return frame


## entries: [{"name": String, "hp": int, "max_hp": int, "tint": Color, "note": String}], plus in a fight
## "res_kind" ("mana", "rage", "charges" or ""), "res" and "res_max": the job's bar under the HP.
func set_party(entries: Array) -> void:
	for c in party_box.get_children().slice(1):
		c.queue_free()
	for e in entries:
		var row := HBoxContainer.new()
		var icon := PawnIcon.new()
		icon.tint = e.tint
		icon.dim = e.hp <= 0
		row.add_child(icon)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.add_child(_label(e.name, 13))
		var bar := ProgressBar.new()
		bar.max_value = e.max_hp
		bar.value = e.hp
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(120, 8)
		col.add_child(bar)
		if e.get("res_kind", "") != "":
			col.add_child(_res_bar(e, Vector2(120, 5)))
		var hp_text := "%d / %d" % [e.hp, e.max_hp]
		if e.get("note", "") != "":
			hp_text += "  " + e.note
		col.add_child(_label(hp_text, 11))
		row.add_child(col)
		party_box.add_child(row)
	if leaf != null:
		for c in leaf_party.get_children():
			c.queue_free()
		for e in entries.slice(0, LEAF_PARTY_MAX):
			leaf_party.add_child(_leaf_member(e))


## The party pack along the bottom: a small copy of the grid, and what's in it in words.
func set_pack(bag: InventoryGrid) -> void:
	for c in slots_box.get_children():
		c.queue_free()
	slots_label.text = "%s   %s" % [Txt.t("UI_ITEMS"), Txt.f("UI_SLOTS_USED", [bag.used_cells(), bag.capacity()])]
	var shrunk := Control.new()
	shrunk.custom_minimum_size = Vector2(PACK_CELL * bag.cols, PACK_CELL * bag.rows)
	shrunk.draw.connect(func() -> void: PackView.draw_bag(shrunk, bag, Db.items, Vector2.ZERO, PACK_CELL, false))
	slots_box.add_child(shrunk)
	var counts := {}
	for it in bag.items:
		counts[it.id] = int(counts.get(it.id, 0)) + int(it.get("n", 1))
	var words: PackedStringArray = []
	for id: String in counts:
		words.append("%s %d" % [Txt.t(String(Db.items[id].name_key)), counts[id]])
	var l := _label("   ".join(words), 13)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slots_box.add_child(l)


## entries: [{"text": String, "cb": Callable, "glow": bool}]. A glowing button has something waiting.
func set_tools(entries: Array) -> void:
	for c in tools_box.get_children():
		c.queue_free()
	for e: Dictionary in entries:
		if leaf != null and e.get("id", "") == "pack":
			_leaf_pack_cb = e.cb
			continue
		var b := Button.new()
		b.text = e.text
		b.custom_minimum_size = Vector2(100, 52)
		b.pressed.connect(e.cb)
		if e.get("glow", false):
			b.add_theme_color_override("font_color", Color(0.65, 0.95, 1.0))
		tools_box.add_child(b)


## Tracked village goals in the frame's long bar (up to two lines; nothing tracked leaves it bare).
func set_goals(lines: PackedStringArray) -> void:
	if leaf_goals != null:
		leaf_goals.text = "\n".join(lines.slice(0, 2))


## The "saved" cue ([USER] omr-11): a word that shows in the top left and fades.
func flash_saved() -> void:
	var l := _label(Txt.t("UI_SAVED"), 15)
	l.position = Vector2(16, 12)
	root.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.7)
	tw.tween_callback(l.queue_free)


func clear_side() -> void:
	for c in side.get_children():
		c.queue_free()


func add_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 36)
	b.pressed.connect(on_press)
	side.add_child(b)
	return b


## The screen's own help ("WASD = walk ..."). Hidden under the leaf frame ([USER] 2026-10-29: no explainers
## round the game); it can come back behind a key later.
func add_help(text: String) -> Label:
	var l := add_side_label(text, 11)
	l.set_meta("help", true)
	l.visible = leaf == null
	return l


func add_side_label(text: String, font_size := 14) -> Label:
	var l := _label(text, font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(RIGHT_W - 28, 0)
	side.add_child(l)
	return l


static func party_entries_from_run(run: RunState) -> Array:
	var out := []
	for m in run.members:
		var d: CharacterDef = m.def
		out.append({"name": Txt.t(d.name_key), "hp": m.hp, "max_hp": run.max_hp(m), "tint": d.tint, "note": ""})
	return out

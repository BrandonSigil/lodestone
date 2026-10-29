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
	return Rect2(LEFT_W, TOP_H, vs.x - LEFT_W - RIGHT_W, vs.y - TOP_H - BOTTOM_H)


## entries: [{"name": String, "hp": int, "max_hp": int, "tint": Color, "note": String}]
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
		var hp_text := "%d / %d" % [e.hp, e.max_hp]
		if e.get("note", "") != "":
			hp_text += "  " + e.note
		col.add_child(_label(hp_text, 11))
		row.add_child(col)
		party_box.add_child(row)


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
		var b := Button.new()
		b.text = e.text
		b.custom_minimum_size = Vector2(100, 52)
		b.pressed.connect(e.cb)
		if e.get("glow", false):
			b.add_theme_color_override("font_color", Color(0.65, 0.95, 1.0))
		tools_box.add_child(b)


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

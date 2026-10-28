class_name MakerUI
extends RefCounted
## The map maker's look and widgets: its theme (dark slate cards, warm accent), icon buttons, catalog tiles
## and collapsible drawers. Everything is drawn in code; icons come from MakerIcons.

const BG := Color(0.105, 0.125, 0.145, 0.95)
const RAISED := Color(0.165, 0.195, 0.225)
const HOVER := Color(0.215, 0.255, 0.295)
const LINE := Color(0.27, 0.31, 0.35)
const INK := Color(0.9, 0.91, 0.87)
const DIM := Color(0.62, 0.65, 0.66)
const ACCENT := Color(0.98, 0.84, 0.48)
const ACCENT_INK := Color(0.16, 0.14, 0.1)
const GOOD := Color(0.45, 0.9, 0.55)
const BAD := Color(1.0, 0.42, 0.38)
const HEADER_FONT := "res://fonts/YoungSerif-Regular.ttf"


static func box(col: Color, radius := 6, margin := 6.0, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	if border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(1)
	sb.anti_aliasing = true
	return sb


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 13
	t.set_stylebox("normal", "Button", box(RAISED))
	t.set_stylebox("hover", "Button", box(HOVER))
	t.set_stylebox("pressed", "Button", box(ACCENT))
	t.set_stylebox("hover_pressed", "Button", box(ACCENT.lightened(0.1)))
	t.set_stylebox("disabled", "Button", box(Color(RAISED, 0.5)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT_INK)
	t.set_color("font_hover_pressed_color", "Button", ACCENT_INK)
	t.set_color("font_focus_color", "Button", INK)
	for k in ["normal", "focus", "read_only"]:
		t.set_stylebox(k, "LineEdit", box(Color(0.07, 0.085, 0.1), 5, 5.0, LINE if k != "focus" else ACCENT))
		t.set_stylebox(k, "TextEdit", box(Color(0.07, 0.085, 0.1), 5, 5.0, LINE if k != "focus" else ACCENT))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", DIM)
	t.set_color("font_color", "TextEdit", INK)
	t.set_color("font_placeholder_color", "TextEdit", DIM)
	t.set_color("font_color", "Label", INK)
	t.set_stylebox("normal", "OptionButton", box(RAISED, 5, 5.0))
	t.set_stylebox("hover", "OptionButton", box(HOVER, 5, 5.0))
	t.set_stylebox("pressed", "OptionButton", box(HOVER, 5, 5.0))
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_color("font_color", "OptionButton", INK)
	t.set_stylebox("panel", "PopupMenu", box(Color(0.12, 0.14, 0.16), 6, 6.0, LINE))
	t.set_stylebox("hover", "PopupMenu", box(HOVER, 4, 4.0))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_stylebox("panel", "TooltipPanel", box(Color(0.06, 0.07, 0.08, 0.96), 5, 7.0, LINE))
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_stylebox("panel", "ItemList", box(Color(0.07, 0.085, 0.1), 5, 4.0))
	t.set_stylebox("selected", "ItemList", box(Color(ACCENT, 0.3), 4, 2.0))
	t.set_stylebox("selected_focus", "ItemList", box(Color(ACCENT, 0.35), 4, 2.0))
	t.set_stylebox("hovered", "ItemList", box(HOVER, 4, 2.0))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_color("font_color", "ItemList", INK)
	t.set_stylebox("slider", "HSlider", box(Color(0.07, 0.085, 0.1), 3, 2.0))
	t.set_stylebox("grabber_area", "HSlider", box(ACCENT, 3, 2.0))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT.lightened(0.15), 3, 2.0))
	t.set_stylebox("panel", "PanelContainer", box(BG, 10, 8.0))
	t.set_color("font_color", "CheckBox", INK)
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_color("font_pressed_color", "CheckBox", INK)
	t.set_color("font_hover_pressed_color", "CheckBox", Color.WHITE)
	t.set_stylebox("normal", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("hover_pressed", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckBox", StyleBoxEmpty.new())
	t.set_icon("unchecked", "CheckBox", _check_icon(false))
	t.set_icon("checked", "CheckBox", _check_icon(true))
	return t


## A rounded-ish check box drawn into a small texture (the default one vanishes on the dark panels).
static func _check_icon(on: bool) -> ImageTexture:
	var n := 16
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in n:
		for x in n:
			var edge := x <= 1 or y <= 1 or x >= n - 2 or y >= n - 2
			var corner := (x <= 1 or x >= n - 2) and (y <= 1 or y >= n - 2)
			if corner:
				continue
			if on:
				img.set_pixel(x, y, ACCENT)
			elif edge:
				img.set_pixel(x, y, DIM)
			else:
				img.set_pixel(x, y, Color(0.07, 0.085, 0.1))
	if on:
		for i in range(4, 12):
			var y := 8 + (i - 4) / 2 if i < 7 else 10 - (i - 7)
			img.set_pixel(i, clampi(y, 2, 13), ACCENT_INK)
			img.set_pixel(i, clampi(y + 1, 2, 13), ACCENT_INK)
	return ImageTexture.create_from_image(img)


static func label(text: String, size := 13, col := INK, header := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if header and ResourceLoader.exists(HEADER_FONT):
		l.add_theme_font_override("font", load(HEADER_FONT))
	return l


static func spacer(w := 0.0, h := 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func separator(vertical := false) -> Control:
	var c := ColorRect.new()
	c.color = LINE
	c.custom_minimum_size = Vector2(1, 22) if vertical else Vector2(22, 1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## A square button showing one of MakerIcons; with text, the icon sits left of it.
class IconButton extends Button:
	var icon_id := ""
	var icon_scale := 0.56

	func _init(id := "", tip := "", px := 36.0, words := "") -> void:
		icon_id = id
		tooltip_text = tip
		text = words
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(px, px) if words == "" else Vector2(0, px)
		if words != "":
			for k in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
				var sb: StyleBoxFlat = MakerUI.box(MakerUI.ACCENT if k.begins_with("pressed") or k == "hover_pressed" else (MakerUI.HOVER if k == "hover" else MakerUI.RAISED))
				sb.content_margin_left = px * 0.95
				sb.content_margin_right = 10
				add_theme_stylebox_override(k, sb)

	func _draw() -> void:
		var col := MakerUI.ACCENT_INK if button_pressed else (Color.WHITE if is_hovered() else MakerUI.INK)
		if disabled:
			col = Color(MakerUI.DIM, 0.5)
		var s := minf(size.x, size.y) * icon_scale
		var at := Vector2((size.y - s) * 0.5, (size.y - s) * 0.5) if text != "" else (size - Vector2(s, s)) * 0.5
		MakerIcons.draw(self, icon_id, Rect2(at, Vector2(s, s)), col)


## One catalog entry: its art (or icon) over a short label. Emits picked on click, dragged when the press
## is dragged off it (the maker then places it where it's let go).
class AssetTile extends Button:
	signal picked(entry: Dictionary)
	signal drag_started(entry: Dictionary)
	signal drag_ended(entry: Dictionary)
	var entry := {}
	var tex: Texture2D
	var _press := Vector2(-1, -1)
	var _dragging := false

	func _init(e: Dictionary, t: Texture2D, tip: String) -> void:
		entry = e
		tex = t
		tooltip_text = tip
		focus_mode = Control.FOCUS_NONE
		toggle_mode = true
		custom_minimum_size = Vector2(66, 74)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		gui_input.connect(_input_on_tile)

	func _input_on_tile(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mb := ev as InputEventMouseButton
			if mb.pressed:
				_press = mb.position
				_dragging = false
			else:
				if _dragging:
					drag_ended.emit(entry)
				_dragging = false
				_press = Vector2(-1, -1)
		elif ev is InputEventMouseMotion and _press.x >= 0.0 and not _dragging:
			if (ev as InputEventMouseMotion).position.distance_to(_press) > 10.0:
				_dragging = true
				drag_started.emit(entry)

	func _pressed() -> void:
		if not _dragging:
			picked.emit(entry)

	func _draw() -> void:
		var area := Rect2(6, 5, size.x - 12, size.y - 26)
		if tex != null:
			var asp := tex.get_width() / float(tex.get_height())
			var w := area.size.x
			var h := w / asp
			if h > area.size.y:
				h = area.size.y
				w = h * asp
			draw_texture_rect(tex, Rect2(area.position + Vector2((area.size.x - w) * 0.5, area.size.y - h), Vector2(w, h)), false)
		elif entry.kind == "blob":
			var foot: Vector2i = entry.foot
			var col := Color(0.6, 0.7, 0.85)
			var cx := area.get_center().x
			var hw := 7.0 + 4.0 * maxi(foot.x, foot.y)
			var y := area.position.y + area.size.y * 0.42
			var d := 10.0 + 3.0 * maxi(foot.x, foot.y)
			draw_colored_polygon(PackedVector2Array([Vector2(cx - hw, y), Vector2(cx, y + hw * 0.5), Vector2(cx, y + hw * 0.5 + d), Vector2(cx - hw, y + d)]), col.darkened(0.15))
			draw_colored_polygon(PackedVector2Array([Vector2(cx + hw, y), Vector2(cx, y + hw * 0.5), Vector2(cx, y + hw * 0.5 + d), Vector2(cx + hw, y + d)]), col.darkened(0.32))
			draw_colored_polygon(PackedVector2Array([Vector2(cx, y - hw * 0.5), Vector2(cx + hw, y), Vector2(cx, y + hw * 0.5), Vector2(cx - hw, y)]), col.lightened(0.15))
			draw_string(get_theme_default_font(), Vector2(0, area.position.y + 11), "%dx%d" % [foot.x, foot.y], HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, MakerUI.INK)
		else:
			var icon := MakerCatalog.icon_for(entry)
			var s := minf(area.size.x, area.size.y) * 0.8
			MakerIcons.draw(self, icon, Rect2(area.get_center() - Vector2(s, s) * 0.5, Vector2(s, s)), MakerUI.ACCENT_INK if button_pressed else MakerUI.ACCENT)
		var font := get_theme_default_font()
		var col2 := MakerUI.ACCENT_INK if button_pressed else (MakerUI.DIM if disabled else MakerUI.INK)
		draw_string(font, Vector2(3, size.y - 7), String(entry.label), HORIZONTAL_ALIGNMENT_CENTER, size.x - 6, 10, col2)


## A section with a clickable header (chevron, title, count) that folds its body away.
class Drawer extends VBoxContainer:
	signal toggled_open(key: String, open: bool)
	var key := ""
	var body := VBoxContainer.new()
	var head: IconButton
	var open := true

	func _init(k: String, title: String, count := -1, start_open := true, size := 14, sub := false) -> void:
		key = k
		open = start_open
		add_theme_constant_override("separation", 4)
		head = IconButton.new("chev_down" if open else "chev_right", "", 26.0 if sub else 30.0, title + ("   %d" % count if count >= 0 else ""))
		head.icon_scale = 0.42
		head.alignment = HORIZONTAL_ALIGNMENT_LEFT
		head.add_theme_font_size_override("font_size", size)
		if sub:
			for k2 in ["normal", "hover", "pressed", "hover_pressed"]:
				var sb := MakerUI.box(Color(0, 0, 0, 0) if k2 == "normal" else MakerUI.HOVER, 5, 3.0)
				sb.content_margin_left = 24
				head.add_theme_stylebox_override(k2, sb)
			head.add_theme_color_override("font_color", MakerUI.DIM)
		elif ResourceLoader.exists(MakerUI.HEADER_FONT):
			head.add_theme_font_override("font", load(MakerUI.HEADER_FONT))
		head.pressed.connect(_flip)
		add_child(head)
		body.visible = open
		body.add_theme_constant_override("separation", 4)
		add_child(body)

	func _flip() -> void:
		open = not open
		body.visible = open
		head.icon_id = "chev_down" if open else "chev_right"
		head.queue_redraw()
		toggled_open.emit(key, open)

class_name CombatLog
extends PanelContainer
## The fight's log, bottom right of the fight screen ([USER] 2026-10-30 design-scale): every event in plain words,
## newest at the bottom, scrollable with the wheel (it follows the newest line until you scroll up).

const MAX_LINES := 400

var _text: RichTextLabel


## The drawn skin (menus v3, round six): the log is one quiet line, the newest thing that happened, bottom right. A click
## opens the whole log over it; another click (or HIDE LOG) puts it away.
const LINE_H := 26.0
const OPEN_H := 190.0
const WIDE := 300.0

var open := false
var _line: Button  ## the quiet line (the drawn skin), or null
var _last := ""
var _room := Rect2()
var _avoid := Rect2()


func _init() -> void:
	_text = RichTextLabel.new()
	_text.scroll_active = true
	_text.scroll_following = true
	_text.bbcode_enabled = false
	_text.fit_content = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_color_override("default_color", Color(0.93, 0.9, 0.82))
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if UiSkin.on():
		_text.add_theme_font_size_override("normal_font_size", UiSkin.T_SMALL)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		add_child(col)
		col.add_child(_text)
		_line = Button.new()
		_line.flat = true
		_line.focus_mode = Control.FOCUS_NONE
		_line.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_line.clip_text = true
		_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_line.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_line.add_theme_font_size_override("font_size", UiSkin.T_SMALL)
		_line.add_theme_color_override("font_outline_color", Color(UiSkin.INK, 0.9))  # it stands on the map: an ink edge keeps it readable on snow
		_line.add_theme_constant_override("outline_size", 4)
		for n in ["normal", "hover", "pressed", "focus"]:
			_line.add_theme_stylebox_override(n, StyleBoxEmpty.new())
		_line.add_theme_color_override("font_color", UiSkin.TEXT)
		_line.add_theme_color_override("font_hover_color", UiSkin.GOLD)
		_line.add_theme_color_override("font_pressed_color", UiSkin.GOLD)
		_line.pressed.connect(func() -> void: set_open(not open))
		col.add_child(_line)
		set_open(false)
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.14, 0.11, 0.86)
	sb.border_color = Color(0.9, 0.82, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(6)
	add_theme_stylebox_override("panel", sb)
	_text.add_theme_font_size_override("normal_font_size", 11)
	add_child(_text)
	custom_minimum_size = Vector2(180, 90)


## The drawn skin: the whole log open over the line, or only the line.
func set_open(on: bool) -> void:
	if _line == null:
		return
	open = on
	_text.visible = on
	if on:
		var felt := UiSkin.panel(10.0, 8.0, false, false, 10.0)
		felt.blur = false  # nothing is blurred behind it (it opens and shuts in place), so its felt is near solid
		felt.top = Color(UiSkin.FELT_TOP, 0.97)
		felt.bottom = Color(UiSkin.FELT_BOTTOM, 0.97)
		add_theme_stylebox_override("panel", felt)
	else:  # a soft ink pill under the words, no rim
		add_theme_stylebox_override("panel", UiSkin.flat(Color(UiSkin.INK, 0.38), Color(1, 1, 1, 0.0), UiSkin.R_CHIP, 10.0, 2.0, 0))
	_line.text = Txt.t("UI_LOG_HIDE") if on else _last
	_line.tooltip_text = "" if on else Txt.t("UI_LOG_SHOW")
	_line.add_theme_color_override("font_color", UiSkin.TEXT_DIM if on else UiSkin.TEXT)
	visible = on or _last != ""
	if _room.has_area():
		place(_room, _avoid)


## One line, in plain words. Lines that start with spaces are the details of the one above.
func add(line: String) -> void:
	if line.strip_edges() == "":
		return
	_text.add_text(line + "\n")
	if _line != null:
		_last = line.strip_edges()
		if not open:
			_line.text = _last
			visible = true
			if _room.has_area():
				place(_room, _avoid)
	while _text.get_paragraph_count() > MAX_LINES:
		_text.remove_paragraph(0)


func clear() -> void:
	_text.clear()
	if _line != null:
		_last = ""
		set_open(false)


## The log's box inside the fight's screen rect r: bottom right, clear of the action dock `avoid` (a rect, or empty).
func place(r: Rect2, avoid: Rect2) -> void:
	_room = r
	_avoid = avoid
	var w := minf(250.0, r.size.x * 0.22)  # [USER] 2026-11-01 "make it much smaller"
	var h := minf(96.0, r.size.y * 0.18)
	if _line != null:
		w = minf(WIDE, r.size.x * 0.26)
		h = minf(OPEN_H, r.size.y * 0.4) if open else LINE_H
		custom_minimum_size = Vector2.ZERO
		if not open:  # the pill hugs its words
			var font := _line.get_theme_font("font")
			w = minf(w, ceilf(font.get_string_size(_last, HORIZONTAL_ALIGNMENT_LEFT, -1, UiSkin.T_SMALL).x) + 26.0)
	var x := r.end.x - w - 8.0
	if avoid.has_area() and avoid.end.x + 8.0 > x and avoid.position.y < r.end.y and avoid.end.y > r.end.y - h - 8.0:
		w = maxf(150.0, r.end.x - avoid.end.x - 16.0)  # squeezed between the dock and the edge
		x = r.end.x - w - 8.0
	size = Vector2(w, h)
	position = Vector2(x, r.end.y - h - 8.0)

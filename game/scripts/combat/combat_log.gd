class_name CombatLog
extends PanelContainer
## The fight's log, bottom right of the fight screen ([USER] 2026-10-30 design-scale): every event in plain words,
## newest at the bottom, scrollable with the wheel (it follows the newest line until you scroll up).

const MAX_LINES := 400

var _text: RichTextLabel


func _init() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.14, 0.11, 0.86)
	sb.border_color = Color(0.9, 0.82, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(6)
	add_theme_stylebox_override("panel", sb)
	_text = RichTextLabel.new()
	_text.scroll_active = true
	_text.scroll_following = true
	_text.bbcode_enabled = false
	_text.fit_content = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("normal_font_size", 11)
	_text.add_theme_color_override("default_color", Color(0.93, 0.9, 0.82))
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_text)
	custom_minimum_size = Vector2(180, 90)


## One line, in plain words. Lines that start with spaces are the details of the one above.
func add(line: String) -> void:
	if line.strip_edges() == "":
		return
	_text.add_text(line + "\n")
	while _text.get_paragraph_count() > MAX_LINES:
		_text.remove_paragraph(0)


func clear() -> void:
	_text.clear()


## The log's box inside the fight's screen rect r: bottom right, clear of the action dock `avoid` (a rect, or empty).
func place(r: Rect2, avoid: Rect2) -> void:
	var w := minf(250.0, r.size.x * 0.22)  # [USER] 2026-11-01 "make it much smaller"
	var h := minf(96.0, r.size.y * 0.18)
	var x := r.end.x - w - 8.0
	if avoid.has_area() and avoid.end.x + 8.0 > x and avoid.position.y < r.end.y and avoid.end.y > r.end.y - h - 8.0:
		w = maxf(150.0, r.end.x - avoid.end.x - 16.0)  # squeezed between the dock and the edge
		x = r.end.x - w - 8.0
	size = Vector2(w, h)
	position = Vector2(x, r.end.y - h - 8.0)

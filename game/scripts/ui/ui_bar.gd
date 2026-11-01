class_name UiBar
extends Control
## A rounded bar (victory screen, Lodestone menu): dark track, flat fill with a lighter top band, an optional number on it. `flash` whitens the fill.

var fill := Color.WHITE
var text_color := UiTheme.PARCHMENT
var text := "":
	set(v):
		text = v
		queue_redraw()
var value := 0.0:
	set(v):
		value = v
		queue_redraw()
var flash := 0.0:
	set(v):
		flash = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(80, 18)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var rr := Rect2(Vector2.ZERO, size)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.02, 0.07, 0.06, 0.9)
	track.border_color = Color(UiTheme.PARCHMENT_DARK, 0.7)
	track.set_border_width_all(1)
	track.set_corner_radius_all(int(size.y * 0.5))
	draw_style_box(track, rr)
	var w := (size.x - 4) * clampf(value, 0.0, 1.0)
	if w > 1.0:
		var f := StyleBoxFlat.new()
		f.bg_color = fill.lerp(Color.WHITE, flash * 0.7)
		f.set_corner_radius_all(int((size.y - 4) * 0.5))
		draw_style_box(f, Rect2(2, 2, w, size.y - 4))
		draw_rect(Rect2(2 + 3, 3, maxf(0.0, w - 6), (size.y - 4) * 0.28), Color(1, 1, 1, 0.22))
	if text != "":
		var font := get_theme_default_font()
		var fs := 14
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(size.x - tw - 6, size.y * 0.5 + fs * 0.36)
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.75))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)

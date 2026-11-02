class_name UiBar
extends Control
## A thin rounded bar (victory screen, Lodestone menu, HOME AGAIN): a lifted track, flat fill with a lighter top band, an
## optional number beside it. `flash` whitens the fill.

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


const THICK := 11.0  ## the bar's height ([USER] 2026-11-02: "all the HP/Mana/Morale bars can be overall thinner")
const TEXT_PX := 15


func _init() -> void:
	custom_minimum_size = Vector2(80, 16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## A thin rounded bar with its number beside it on the right, on the window's felt where it always reads.
func _draw() -> void:
	var font := get_theme_default_font()
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_PX).x + 8.0 if text != "" else 0.0
	var th := minf(THICK, size.y)
	var rr := Rect2(0, roundf((size.y - th) * 0.5), maxf(10.0, size.x - tw), th)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.1, 0.26, 0.23, 0.95)  # a lifted inset, not black (style bible R5)
	track.border_color = Color(UiTheme.PARCHMENT_DARK, 0.8)
	track.set_border_width_all(1)
	track.set_corner_radius_all(int(th * 0.5))
	draw_style_box(track, rr)
	var w := (rr.size.x - 2) * clampf(value, 0.0, 1.0)
	if w > 1.0:
		var f := StyleBoxFlat.new()
		f.bg_color = fill.lerp(Color.WHITE, flash * 0.7)
		f.set_corner_radius_all(int((th - 2) * 0.5))
		draw_style_box(f, Rect2(rr.position + Vector2(1, 1), Vector2(w, th - 2)))
		draw_rect(Rect2(rr.position + Vector2(3, 2), Vector2(maxf(0.0, w - 4), (th - 2) * 0.3)), Color(1, 1, 1, 0.22))
	if text != "":
		var pos := Vector2(size.x - tw + 8.0, size.y * 0.5 + TEXT_PX * 0.36)
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_PX, 4, Color(0.02, 0.05, 0.04, 0.8))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_PX, text_color)

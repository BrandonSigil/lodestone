class_name UiTheme
extends RefCounted
## The one look every menu shares ([USER] 2026-10-30: the Lodestone menu, character sheets, the pack, options,
## dialogues and the world map look consistent, with variety where needed). Game merges it into the engine's default
## theme, so every screen without its own gets it; the riso screens (launch, village) keep RisoTheme for now.
## Graybox for now: flat dark panels with a thin gold keyline. When Brandon picks the art runner's menu style, its
## nine-slice pieces go in KIT_DIR under the names in PIECES and replace the flat boxes with no code change.
##
## Type variations: DialogPanel (dialogues, the Lodestone menu, PACK), MenuPanel (small menus by a piece),
## InfoPanel (forecasts, read-outs), TipPanel (hover cards), MenuTitle and SubTitle (Labels).

const KIT_DIR := "res://art/source/ui/menu/"
## piece file -> [theme item, type, nine-slice margin]
const PIECES := {
	"panel.png": ["panel", "DialogPanel", 14],
	"panel_small.png": ["panel", "MenuPanel", 10],
	"panel_info.png": ["panel", "InfoPanel", 10],
	"tooltip.png": ["panel", "TipPanel", 10],
	"button.png": ["normal", "Button", 8],
	"button_hover.png": ["hover", "Button", 8],
	"button_pressed.png": ["pressed", "Button", 8],
	"button_disabled.png": ["disabled", "Button", 8],
}

# The palette: the leaf frame's look (the character sheet's, 2026-10-30): deep green, parchment rules and plates,
# blue diamonds. Every menu draws from these; the art runner's pitch replaces them here when Brandon picks one.
const GREEN := Color(0.11, 0.2, 0.18)
const GREEN_LIGHT := Color(0.2, 0.31, 0.28)
const PARCHMENT := Color(0.93, 0.88, 0.74)
const PARCHMENT_DARK := Color(0.84, 0.77, 0.6)
const INK := Color(0.2, 0.18, 0.16)
const RULE := Color(0.93, 0.88, 0.74, 0.9)
const DIAMOND := Color(0.45, 0.68, 0.95)
const GOLD := Color(0.95, 0.82, 0.45)
const KEYLINE := RULE
const OPEN_TIME := 0.14  ## seconds a menu takes to open or close


static func box(bg: Color, line := KEYLINE, width := 1, pad := 6.0, radius := 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = line
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb


static func make() -> Theme:
	var t := Theme.new()
	t.default_font = load("res://fonts/YoungSerif-Regular.ttf") as Font
	for v in ["DialogPanel", "MenuPanel", "InfoPanel", "TipPanel"]:
		t.set_type_variation(v, "PanelContainer")
	t.set_stylebox("panel", "DialogPanel", framed(Color(GREEN, 0.97), 14.0))
	t.set_stylebox("panel", "MenuPanel", framed(Color(GREEN, 0.95), 8.0))
	t.set_stylebox("panel", "InfoPanel", box(Color(GREEN.darkened(0.3), 0.92), Color(RULE, 0.5), 1, 8.0))
	var tip := framed(Color(GREEN.darkened(0.35), 0.97), 9.0)
	t.set_stylebox("panel", "TipPanel", tip)
	t.set_stylebox("panel", "TooltipPanel", tip)  # Godot's own hover tooltips too
	t.set_color("font_color", "TooltipLabel", PARCHMENT)
	t.set_color("font_color", "Label", PARCHMENT)
	for v in ["MenuTitle", "SubTitle"]:
		t.set_type_variation(v, "Label")
	t.set_font_size("font_size", "MenuTitle", 21)
	t.set_color("font_color", "MenuTitle", GOLD)
	t.set_font_size("font_size", "SubTitle", 15)
	t.set_color("font_color", "SubTitle", GOLD.lerp(PARCHMENT, 0.5))
	t.set_stylebox("normal", "Button", box(GREEN_LIGHT, RULE, 2, 5.0))
	t.set_stylebox("hover", "Button", box(GREEN_LIGHT.lightened(0.15), RULE, 2, 5.0))
	t.set_stylebox("pressed", "Button", box(GREEN, GOLD, 2, 5.0))
	t.set_stylebox("hover_pressed", "Button", box(GREEN.lightened(0.05), GOLD, 2, 5.0))
	t.set_stylebox("disabled", "Button", box(GREEN.darkened(0.2), Color(RULE, 0.35), 2, 5.0))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), GOLD, 2, 5.0))
	t.set_color("font_color", "Button", PARCHMENT)
	t.set_color("font_hover_color", "Button", Color(1, 0.97, 0.88))
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", PARCHMENT)
	t.set_color("font_disabled_color", "Button", PARCHMENT.darkened(0.35))
	_kit(t)
	return t


## A panel with the frame's double parchment rule (the outer one as the border, the inner one drawn by
## FramedBox) and a blue diamond at each corner.
static func framed(bg: Color, pad: float) -> StyleBox:
	var sb := FramedBox.new()
	sb.bg_color = bg
	sb.set_content_margin_all(pad + 4)
	return sb


# --- drawing for screens that paint themselves (the character sheet) --------------------------------------

static func frame(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(r, GREEN)
	ci.draw_rect(r.grow(-6), RULE, false, 2.0)
	ci.draw_rect(r.grow(-11), RULE, false, 1.0)
	for c in [r.position + Vector2(8, 8), Vector2(r.end.x - 8, r.position.y + 8), Vector2(r.position.x + 8, r.end.y - 8), r.end - Vector2(8, 8)]:
		diamond(ci, c, 7.0)


static func plate(ci: CanvasItem, r: Rect2, col := PARCHMENT) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = Color(INK, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	ci.draw_style_box(sb, r)


static func diamond(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), DIAMOND)


# --- open and close ([USER] 2026-10-30: menus built in-engine so they can animate) -------------------------

## A menu opening: grows a little from its middle and fades in.
static func pop_in(c: Control) -> void:
	if not c.is_inside_tree():
		return
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(0.94, 0.94)
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, OPEN_TIME)
	tw.tween_property(c, "modulate:a", 1.0, OPEN_TIME * 0.8)


## A screen that sets its own scale (the character sheet): fade in only.
static func fade_in(c: Control) -> void:
	c.modulate.a = 0.0
	c.create_tween().tween_property(c, "modulate:a", 1.0, OPEN_TIME)


## A menu closing: shrinks a touch and fades, then frees itself. Its buttons die at once, so nothing on the way
## out can be pressed.
static func pop_out(c: Control) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree():
		if is_instance_valid(c):
			c.queue_free()
		return
	for b in c.find_children("*", "BaseButton", true, false):
		(b as BaseButton).disabled = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween().set_parallel()
	tw.tween_property(c, "scale", Vector2(0.96, 0.96), OPEN_TIME * 0.7)
	tw.tween_property(c, "modulate:a", 0.0, OPEN_TIME * 0.7)
	tw.chain().tween_callback(c.queue_free)


## The art runner's nine-slice pieces, where they exist, over the flat boxes.
static func _kit(t: Theme) -> void:
	for f: String in PIECES:
		var p := KIT_DIR + f
		if not ResourceLoader.exists(p):
			continue
		var sb := StyleBoxTexture.new()
		sb.texture = load(p)
		var m := int(PIECES[f][2])
		sb.texture_margin_left = m
		sb.texture_margin_right = m
		sb.texture_margin_top = m
		sb.texture_margin_bottom = m
		sb.set_content_margin_all(m)
		t.set_stylebox(String(PIECES[f][0]), String(PIECES[f][1]), sb)

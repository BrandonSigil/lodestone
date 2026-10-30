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
# The palette: Brandon's "frame green" (direction A, 2026-10-30; FramedBox draws the rims and ornaments from it).
const GREEN := Color("064e3c")
const GREEN_LIGHT := Color("0c5944")
const PARCHMENT := Color("f2eddb")
const PARCHMENT_DARK := Color("ddd3b6")
const INK := Color("1e1f1b")
const RULE := Color("f2eddb")
const DIAMOND := Color("1081e0")
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
	for v in ["DialogPanel", "MenuPanel", "InfoPanel", "TipPanel", "TitlePlate"]:
		t.set_type_variation(v, "PanelContainer")
	t.set_stylebox("panel", "DialogPanel", framed(18.0))
	t.set_stylebox("panel", "MenuPanel", framed(10.0))
	t.set_stylebox("panel", "InfoPanel", framed(8.0, false))
	t.set_stylebox("panel", "TitlePlate", framed(8.0))
	t.set_stylebox("panel", "TipPanel", framed(12.0))  # the fight's corner panel: no pointer, it points at nothing
	var tip := framed(12.0)
	tip.pointer = true
	t.set_stylebox("panel", "TooltipPanel", tip)  # Godot's own hover tooltips: the V under the middle
	t.set_color("font_color", "TooltipLabel", PARCHMENT)
	t.set_color("font_color", "Label", PARCHMENT)
	for v in ["MenuTitle", "SubTitle"]:
		t.set_type_variation(v, "Label")
	t.set_font_size("font_size", "MenuTitle", 21)
	t.set_color("font_color", "MenuTitle", GOLD)
	t.set_font_size("font_size", "SubTitle", 15)
	t.set_color("font_color", "SubTitle", GOLD.lerp(PARCHMENT, 0.5))
	# Buttons: the pill, a gem and leaves at each end; lit, pressed and greyed by tint and glow.
	t.set_stylebox("normal", "Button", pill(Color.WHITE, 0.0))
	t.set_stylebox("hover", "Button", pill(Color(1.25, 1.25, 1.2), 0.6))
	t.set_stylebox("pressed", "Button", pill(Color(0.75, 0.75, 0.7), 0.9))
	t.set_stylebox("hover_pressed", "Button", pill(Color(0.85, 0.85, 0.8), 1.0))
	t.set_stylebox("disabled", "Button", pill(Color(0.55, 0.55, 0.55, 0.85), 0.0))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())  # focus shows as the lit rim (hover) via the theme's own focus pass
	t.set_color("font_color", "Button", PARCHMENT)
	t.set_color("font_hover_color", "Button", Color(1, 0.97, 0.88))
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", Color(1, 0.97, 0.88))
	t.set_color("font_disabled_color", "Button", PARCHMENT.darkened(0.35))
	_kit(t)
	return t


## A panel in Brandon's frame: the banded rim, the mottled green, gems and leaves at the corners (FramedBox).
static func framed(pad: float, ornaments := true) -> FramedBox:
	var sb := FramedBox.new()
	sb.ornaments = ornaments
	sb.set_content_margin_all(pad + 6)
	return sb


## A button: the frame as a pill with round ends, a gem and leaves at each end.
static func pill(tint: Color, glow: float) -> FramedBox:
	var sb := FramedBox.new()
	sb.pill = true
	sb.tint = tint
	sb.glow = glow
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


# --- drawing for screens that paint themselves (the character sheet) --------------------------------------

static func frame(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_style_box(framed(0.0), r)  # the same frame every panel wears


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


## pop_in once the menu has its size (the next frame), unless it was freed or swapped by then (a menu rebuilt at
## once, a fight starting): a deferred call straight to pop_in errored on the freed dialog (playtest, 2026-10-30).
static func pop_in_later(c: Control) -> void:
	var ref: WeakRef = weakref(c)
	(func() -> void:
		var live := ref.get_ref() as Control
		if live != null and live.is_inside_tree():
			pop_in(live)).call_deferred()


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

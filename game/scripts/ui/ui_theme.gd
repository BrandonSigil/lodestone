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

const GOLD := Color(0.95, 0.82, 0.45)
const INK := Color(0.92, 0.92, 0.88)
const KEYLINE := Color(0.9, 0.85, 0.6, 0.5)


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
	for v in ["DialogPanel", "MenuPanel", "InfoPanel", "TipPanel"]:
		t.set_type_variation(v, "PanelContainer")
	t.set_stylebox("panel", "DialogPanel", box(Color(0.1, 0.12, 0.12, 0.96), KEYLINE, 1, 10.0))
	t.set_stylebox("panel", "MenuPanel", box(Color(0.12, 0.15, 0.15, 0.94)))
	t.set_stylebox("panel", "InfoPanel", box(Color(0.08, 0.1, 0.1, 0.9)))
	var tip := box(Color(0.06, 0.07, 0.09, 0.96), Color(0.75, 0.65, 0.4), 2, 8.0)
	t.set_stylebox("panel", "TipPanel", tip)
	t.set_stylebox("panel", "TooltipPanel", tip)  # Godot's own hover tooltips too
	t.set_color("font_color", "TooltipLabel", INK)
	for v in ["MenuTitle", "SubTitle"]:
		t.set_type_variation(v, "Label")
	t.set_font_size("font_size", "MenuTitle", 20)
	t.set_color("font_color", "MenuTitle", GOLD)
	t.set_font_size("font_size", "SubTitle", 15)
	t.set_color("font_color", "SubTitle", GOLD.lerp(INK, 0.4))
	t.set_stylebox("normal", "Button", box(Color(0.2, 0.23, 0.24), Color(0, 0, 0, 0.6), 1, 5.0))
	t.set_stylebox("hover", "Button", box(Color(0.27, 0.31, 0.32), GOLD, 1, 5.0))
	t.set_stylebox("pressed", "Button", box(Color(0.33, 0.29, 0.18), GOLD, 1, 5.0))
	t.set_stylebox("hover_pressed", "Button", box(Color(0.36, 0.32, 0.2), GOLD, 1, 5.0))
	t.set_stylebox("disabled", "Button", box(Color(0.15, 0.16, 0.17, 0.8), Color(0, 0, 0, 0.4), 1, 5.0))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), GOLD, 1, 5.0))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.55, 0.52))
	_kit(t)
	return t


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

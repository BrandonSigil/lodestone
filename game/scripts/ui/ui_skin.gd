class_name UiSkin
extends RefCounted
## The drawn skin (prototype, branch menus-prototype; docs/design/menus-v3.md). Brandon, 2026-11-13: the menus "look
## very jpeg's pasted onto a frame", "very clunky, very bulky, very amateur looking"; he asked for menus that "feel more
## baked into the game, more dynamically sizable, and just AAA clean feeling". So nothing here is a bitmap: every panel,
## button, chip and slot is drawn by the engine from the tokens below (SkinBox), the same thin rim at any size.
## Round two, Brandon the same day: "I like these A LOT MORE, but now can we fold back in just a bit more
## high-fantasy/painterly look? Some transparency is fine, but it reads a bit like glassmorphism", "a little bit of like
## diamond shaped flourishes on major frames". So the fill is painted felt, nearly solid (the world behind shows through
## only faintly, SkinBackdrop), the rim is bevelled gold with a cream line inside, and windows, titles and headings
## carry diamonds.
## UiTheme.make calls `apply` last, so every menu in the game wears it with no change to the menus themselves.
## LODESTONE_SKIN=old in the environment keeps the painted frame, for before and after pictures.

# --- tokens: colour ----------------------------------------------------------------------------------
const FELT_TOP := Color(0.05, 0.272, 0.218, 0.93)  ## a window's felt at its top edge: nearly solid
const FELT_BOTTOM := Color(0.027, 0.162, 0.132, 0.95)
const HAIR := Color(0.93, 0.85, 0.62)  ## the gold hairline
const INK := Color(0.01, 0.04, 0.035)
const TEXT := Color("f2eddb")
const TEXT_DIM := Color(0.8, 0.83, 0.78)
const GOLD := Color(0.97, 0.84, 0.47)
const GOLD_DEEP := Color(0.83, 0.67, 0.3)
const GEM := Color(0.06, 0.45, 0.82)
const WELL := Color(0, 0, 0, 0.26)  ## a sunk place: slots, chips, bar tracks
const LIFT := Color(1, 1, 1, 0.05)  ## a raised place: cards, plain buttons
const LINE := Color(1, 1, 1, 0.1)  ## a quiet edge inside a window
# --- tokens: shape -----------------------------------------------------------------------------------
const R_WINDOW := 6.0
const R_BUTTON := 5
const R_CHIP := 9
const R_SLOT := 4
const SPACE := 8.0  ## the spacing unit: gaps and pads are 1, 1.5, 2 or 3 of these
const BAR_TOP := Color(0.046, 0.258, 0.207, 0.96)  ## the bottom bar's felt
const BAR_FOOT := Color(0.024, 0.15, 0.122, 0.97)
const X_SIZE := 26.0  ## a window's close button
const X_INSET := 13.0  ## and how far in from the window's top right corner it sits (clear of the corner stud)
const BAR := Color(0.03, 0.1, 0.09, 0.72)  ## a plain button: dark enough to stand alone on a bright map


static func on() -> bool:
	return OS.get_environment("LODESTONE_SKIN") != "old"


## A panel. `ornate`: a window's full rim (the cream line inside the gold, a stud in each corner). `gem`: the blue
## diamond on its top edge.
static func panel(pad_x: float, pad_y: float, gem := false, ornate := false, shadow := 18.0) -> SkinBox:
	var sb := SkinBox.new()
	sb.top = FELT_TOP
	sb.bottom = FELT_BOTTOM
	sb.gem = gem
	sb.ornate = ornate
	sb.shadow = shadow
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


## A window for a screen that paints itself (the character sheet): nothing blurs behind it, so its felt is solid.
static func solid_panel() -> SkinBox:
	var sb := panel(0.0, 0.0, true, true)
	sb.top = Color(FELT_TOP, 0.98)
	sb.bottom = Color(FELT_BOTTOM, 0.98)
	return sb


static func flat(bg: Color, rim: Color, radius: int, pad_x: float, pad_y: float, width := 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = rim
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 8
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 0.6
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


## Lays the skin over the theme UiTheme.make built: the same type variations, drawn instead of painted.
static func apply(t: Theme) -> void:
	# windows: dialogues and the big screens carry the gem on the top edge; small menus and the fight's corner panel don't
	t.set_stylebox("panel", "DialogPanel", panel(24.0, 20.0, true, true))
	t.set_stylebox("panel", "MenuPanel", panel(12.0, 10.0, false, false, 12.0))
	t.set_stylebox("panel", "TipPanel", panel(16.0, 14.0, false, false, 12.0))
	t.set_stylebox("panel", "InfoPanel", flat(Color(INK, 0.55), LINE, 5, 12.0, 8.0))
	var tip := panel(10.0, 7.0, false, false, 8.0)
	tip.radius = 4.0
	tip.blur = false
	tip.top = Color(0.05, 0.13, 0.115, 0.96)
	tip.bottom = Color(0.03, 0.085, 0.075, 0.97)
	t.set_stylebox("panel", "TooltipPanel", tip)
	# the title: a banner with pointed ends and a diamond either side of the words (it sits across a window's top edge)
	var plate := panel(40.0, 4.0, false, false, 6.0)
	plate.plate = true
	plate.blur = false
	plate.top = Color(0.075, 0.33, 0.265, 1.0)
	plate.bottom = Color(0.035, 0.2, 0.16, 1.0)
	t.set_stylebox("panel", "TitlePlate", plate)
	t.set_color("font_color", "MenuTitle", TEXT)
	# inside a window
	t.set_stylebox("panel", "KitCard", flat(Color(0, 0, 0, 0.16), Color(1, 1, 1, 0.07), 5, 14.0, 12.0))
	t.set_stylebox("panel", "KitChip", flat(WELL, Color(1, 1, 1, 0.12), R_CHIP, 10.0, 2.0))
	t.set_stylebox("panel", "KitSlot", flat(Color(0, 0, 0, 0.3), Color(1, 1, 1, 0.1), R_SLOT, 4.0, 4.0))
	# buttons: a plain one is a quiet raised bar; under the mouse or the keys it takes the gold hairline. The one to
	# press is solid gold with dark words, the only solid thing in a window, so it reads first.
	_buttons(t, "Button", BAR, Color(HAIR, 0.3), TEXT)
	_buttons(t, "QuietButton", Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.1), TEXT_DIM)
	t.set_stylebox("normal", "PrimaryButton", _gold(1.0))
	t.set_stylebox("hover", "PrimaryButton", _gold(1.1))
	t.set_stylebox("pressed", "PrimaryButton", _gold(0.85))
	t.set_stylebox("hover_pressed", "PrimaryButton", _gold(0.85))
	t.set_stylebox("disabled", "PrimaryButton", flat(Color(GOLD_DEEP, 0.25), Color(HAIR, 0.2), R_BUTTON, 22.0, 7.0))
	t.set_stylebox("focus", "PrimaryButton", _focus())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "PrimaryButton", Color(0.1, 0.07, 0.02))
	t.set_color("font_disabled_color", "PrimaryButton", Color(TEXT, 0.4))
	# the thin scrollbar
	var track := flat(Color(0, 0, 0, 0.25), Color(1, 1, 1, 0.0), 3, 0.0, 0.0, 0)
	track.content_margin_left = 3
	track.content_margin_right = 3
	t.set_stylebox("scroll", "VScrollBar", track)
	t.set_stylebox("scroll_focus", "VScrollBar", track)
	t.set_stylebox("grabber", "VScrollBar", flat(Color(HAIR, 0.5), Color(1, 1, 1, 0.0), 3, 0.0, 0.0, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", flat(Color(HAIR, 0.8), Color(1, 1, 1, 0.0), 3, 0.0, 0.0, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", flat(GOLD, Color(1, 1, 1, 0.0), 3, 0.0, 0.0, 0))


static func _buttons(t: Theme, type: String, bg: Color, rim: Color, text: Color) -> void:
	t.set_stylebox("normal", type, flat(bg, rim, R_BUTTON, 20.0, 7.0))
	t.set_stylebox("hover", type, flat(Color(GOLD, 0.14), Color(HAIR, 0.95), R_BUTTON, 20.0, 7.0))
	t.set_stylebox("pressed", type, flat(Color(0, 0, 0, 0.3), Color(HAIR, 0.95), R_BUTTON, 20.0, 7.0))
	t.set_stylebox("hover_pressed", type, flat(Color(0, 0, 0, 0.3), Color(HAIR, 0.95), R_BUTTON, 20.0, 7.0))
	t.set_stylebox("disabled", type, flat(Color(bg, bg.a * 0.5), Color(rim, rim.a * 0.4), R_BUTTON, 20.0, 7.0))
	t.set_stylebox("focus", type, _focus())
	t.set_color("font_color", type, text)
	t.set_color("font_hover_color", type, Color(1, 0.97, 0.88))
	t.set_color("font_pressed_color", type, GOLD)
	t.set_color("font_focus_color", type, Color(1, 0.97, 0.88))
	t.set_color("font_hover_pressed_color", type, GOLD)
	t.set_color("font_disabled_color", type, Color(text, 0.4))


static func _gold(k: float) -> StyleBoxFlat:
	var sb := flat(Color(GOLD.r * k, GOLD.g * k, GOLD.b * k).clamp(), Color(1.0, 0.95, 0.75), R_BUTTON, 22.0, 7.0)
	sb.shadow_color = Color(GOLD, 0.22)
	sb.shadow_size = 5
	return sb


static func _focus() -> StyleBoxFlat:
	var sb := flat(Color(GOLD, 0.1), Color(HAIR, 1.0), R_BUTTON, 20.0, 7.0)
	sb.draw_center = false
	return sb


## A heading's rule: a gold diamond at `near` (beside the words), a line that fades out toward `far`.
static func rule(ci: CanvasItem, near: Vector2, far: Vector2) -> void:
	var dir := (far - near).normalized()
	ci.draw_polyline_colors(PackedVector2Array([near + dir * 9.0, far]), PackedColorArray([Color(HAIR, 0.75), Color(HAIR, 0.0)]), 1.5, true)
	SkinBox.stud(ci.get_canvas_item(), near + dir * 3.5, 3.4)


# --- the world behind a window ---------------------------------------------------------------------

const BLUR := preload("res://shaders/skin_backdrop.gdshader")


## Every skin window blurs what is behind it. Game calls this once: each PanelContainer that enters the tree wearing a
## window style gets a SkinBackdrop under it.
static func watch(tree: SceneTree) -> void:
	if not on():
		return
	tree.node_added.connect(func(n: Node) -> void:
		if n is PanelContainer:
			_back.call_deferred(n))


static func _back(p: PanelContainer) -> void:
	if not is_instance_valid(p) or not p.is_inside_tree() or p.has_node("SkinBackdrop"):
		return
	var sb := p.get_theme_stylebox("panel") as SkinBox
	if sb == null or not sb.blur:
		return
	var b := SkinBackdrop.new()
	b.name = "SkinBackdrop"
	p.add_child(b, false, Node.INTERNAL_MODE_FRONT)

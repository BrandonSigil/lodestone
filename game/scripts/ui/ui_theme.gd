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
	# Brandon's approved painted pieces where they exist (art/source/ui/menu/look_*.png), else FramedBox's code drawing.
	# Panel corners: the leaves and the gem reach about 105 px into the painted piece, so 110 keeps them whole.
	t.set_stylebox("panel", "DialogPanel", look("look_panel.png", 110, 110, 0.45, 32.0, 28.0))  # text clear of the corner leaves
	t.set_stylebox("panel", "MenuPanel", look("look_panel.png", 110, 110, 0.3, 14.0, 12.0))
	t.set_stylebox("panel", "InfoPanel", framed(8.0, false))
	t.set_stylebox("panel", "TitlePlate", look("look_title_plate.png", 88, 0, 0.3, 30.0, 8.0))
	t.set_stylebox("panel", "TipPanel", look("look_panel.png", 110, 110, 0.4, 26.0, 24.0))  # the fight's corner panel
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
	t.set_stylebox("normal", "Button", button(Color.WHITE, 0.0))
	t.set_stylebox("hover", "Button", button(Color(1.25, 1.25, 1.2), 0.6))
	t.set_stylebox("pressed", "Button", button(Color(0.75, 0.75, 0.7), 0.9))
	t.set_stylebox("hover_pressed", "Button", button(Color(0.85, 0.85, 0.8), 1.0))
	t.set_stylebox("disabled", "Button", button(Color(0.55, 0.55, 0.55, 0.85), 0.0))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())  # focus shows as the lit rim (hover) via the theme's own focus pass
	t.set_color("font_color", "Button", PARCHMENT)
	t.set_color("font_hover_color", "Button", Color(1, 0.97, 0.88))
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", Color(1, 0.97, 0.88))
	t.set_color("font_disabled_color", "Button", PARCHMENT.darkened(0.35))
	_kit(t)
	return t


const LOOK_DIR := "res://art/source/ui/menu/"
static var _looks := {}  ## "file@scale" -> the piece scaled to game size, made once


## One of Brandon's painted pieces as a nine-slice box ([USER] 2026-10-30, the art runner's cut of his approved
## "frame green"): scaled to game size, the corners (mx, my at the piece's own size) kept whole and the bands and the
## fill tiled between them, so nothing smears. Falls back to FramedBox's code drawing if the piece isn't there.
static func look(file: String, mx: int, my: int, scale: float, pad_x: float, pad_y: float, tint := Color.WHITE) -> StyleBox:
	var p := LOOK_DIR + file
	if not ResourceLoader.exists(p):
		return framed(pad_y) if not file.contains("button") else pill(tint, 0.0)
	var key := "%s@%s" % [file, scale]
	if not _looks.has(key):
		var img := (load(p) as Texture2D).get_image()
		img.resize(maxi(1, roundi(img.get_width() * scale)), maxi(1, roundi(img.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
		_looks[key] = ImageTexture.create_from_image(img)
	var sb := StyleBoxTexture.new()
	sb.texture = _looks[key]
	sb.texture_margin_left = mx * scale
	sb.texture_margin_right = mx * scale
	sb.texture_margin_top = my * scale
	sb.texture_margin_bottom = my * scale
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	# a plate or a pill is one band tall: it stretches to a taller button rather than stacking a second pill
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT if my > 0 else StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.modulate_color = Color(minf(tint.r, 1.0), minf(tint.g, 1.0), minf(tint.b, 1.0), tint.a)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


## A button: Brandon's painted pill (round ends, a gem and leaves each end), lit, pressed or greyed; a lit one
## (glow) brightens its painting a little.
static func button(tint: Color, glow: float) -> StyleBox:
	var sb := look("look_button.png", 85, 0, 0.24, 24.0, 7.0, tint)
	if sb is StyleBoxTexture and glow > 0.0:
		(sb as StyleBoxTexture).modulate_color = (sb as StyleBoxTexture).modulate_color.lightened(0.18 * glow)
	return sb


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
	ci.draw_style_box(look("look_panel.png", 72, 72, 0.5, 0.0, 0.0), r)  # the same frame every panel wears


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

const SMALL := 0.5  ## [USER] 2026-10-30 (dev-menu-frame): all but the full-page screens about half the size
const SIZE_STEP := 0.05  ## the UI size option moves in 5% notches


## The size of the small UI (the fight dock, its details, event dialogues): half, times the UI size option.
static func small() -> float:
	return SMALL * clampf(float(Game.meta.get("settings", {}).get("ui_size", 1.0)), 0.5, 2.0)


## A menu opening: grows a little from its middle and fades in (to whatever size it was set to).
static func pop_in(c: Control) -> void:
	if not c.is_inside_tree():
		return
	var target := c.scale
	c.pivot_offset = Vector2.ZERO  # it grows in place: its position already accounts for its size
	c.scale = target * 0.94
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if c.has_meta("fit_k"):  # a box kept inside the screen: the size it fits at may change mid-open
		tw.tween_method(func(f: float) -> void: c.scale = Vector2.ONE * float(c.get_meta("fit_k")) * f, 0.94, 1.0, OPEN_TIME)
	else:
		tw.tween_property(c, "scale", target, OPEN_TIME)
	tw.tween_property(c, "modulate:a", 1.0, OPEN_TIME * 0.8)


## A screen that sets its own scale (the character sheet): fade in only.
static func fade_in(c: Control) -> void:
	c.modulate.a = 0.0
	c.create_tween().tween_property(c, "modulate:a", 1.0, OPEN_TIME)


## pop_in once the menu has its size (the next frame), unless it was freed or swapped by then (a menu rebuilt at
## once, a fight starting): a deferred call straight to pop_in errored on the freed dialog (playtest, 2026-10-30), and
## a deferred weak reference errored at shutdown ("slot >= slot_max"), so it waits a frame on the tree instead.
static func pop_in_later(c: Control) -> void:
	if not c.is_inside_tree():
		return
	await c.get_tree().process_frame  # a frame's wait on the tree: if the game is shutting down it never resumes
	if is_instance_valid(c) and c.is_inside_tree():
		pop_in(c)


## Keeps a box inside the play area ([USER] 2026-11-01: "Menus spill out of the window"; "too small or too large"):
## centred across, its top at the area's top (`top`) or standing on its foot, and scaled down from `base` whenever it
## would spill over. Runs again each time the box changes size (a menu rebuilt, a detail filled in). `area` returns
## the Rect2 the box may use.
static func keep_inside(c: Control, area: Callable, base := 1.0, top := true) -> void:
	var fit := func() -> void:
		if not is_instance_valid(c) or not c.is_inside_tree():
			return
		if c.size != c.get_combined_minimum_size():
			c.reset_size()  # shrink back when the box loses rows (this runs again from resized)
			return
		var r: Rect2 = area.call()
		var room := r.size - Vector2(FIT_MARGIN, FIT_MARGIN) * 2.0
		var k := minf(base, minf(room.x / maxf(1.0, c.size.x), room.y / maxf(1.0, c.size.y)))
		c.set_meta("fit_k", k)  # pop_in grows to this even when the box changes size while it opens
		c.scale = Vector2(k, k)
		c.position.x = roundf(r.get_center().x - c.size.x * k * 0.5)
		c.position.y = roundf(r.position.y + FIT_MARGIN if top else r.end.y - FIT_MARGIN - c.size.y * k)
	c.resized.connect(fit)
	fit.call()


const FIT_MARGIN := 12.0


## A menu closing: shrinks a touch and fades, then frees itself. Its buttons die at once, so nothing on the way
## out can be pressed.
## Esc on an open box ([USER] 2026-11-01: "Let esc close out windows in game too"): presses the box's own
## close-type button (CLOSE, BACK, OK, CANCEL, LEAVE...), the last one if there are several. A box with none
## (a real choice, or the full pack whose way out throws things away) stays open. True if it pressed one.
const ESC_KEYS := ["UI_CLOSE_MENU", "UI_CLOSE", "UI_OPT_BACK", "UI_CONTINUE", "UI_CANCEL", "UI_STAY_MAP", "OPT_LEAVE"]


static func press_close(box: Control) -> bool:
	if box == null or not is_instance_valid(box):
		return false
	var texts: PackedStringArray = []
	for k: String in ESC_KEYS:
		texts.append(Txt.t(k))
	var pick: Button = null
	for b: Button in box.find_children("*", "Button", true, false):
		if b.visible and not b.disabled and texts.has(b.text):
			pick = b
	if pick == null:
		return false
	pick.pressed.emit()
	return true


static func pop_out(c: Control) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree():
		if is_instance_valid(c):
			c.queue_free()
		return
	for b in c.find_children("*", "BaseButton", true, false):
		(b as BaseButton).disabled = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := c.create_tween().set_parallel()
	tw.tween_property(c, "scale", c.scale * 0.96, OPEN_TIME * 0.7)
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

class_name MenuKit
extends RefCounted
## The menu kit ([USER] 2026-11-02, the round 2 mockups in docs/art/references/menus/, "LOVE THIS"): one set of pieces every
## screen builds from. The window is Brandon's painted frame with its felt darkened and a touch see-through ([USER]
## 2026-11-01: "what if the inner menus were a darker green with a touch of transparency"); bright green only on title
## plates. Buttons are dark with a thin rim: the primary one wears a gold rim and glows, a quiet one (LEAVE, BACK OFF)
## is dimmer but still easy to read. Pills and chips, item slots, portrait frames, labelled bars, section headings, the
## round X and the thin scrollbar are all here, drawn in code from the palette below. The styles are theme type
## variations (UiTheme.make calls `style`), so a Control picks one by name: "KitCard", "KitChip", "KitSlot",
## "PrimaryButton", "QuietButton", "KitX", "KitHeading". docs/systems/ui-kit.md.

# the palette (from the mockups): dark felt, a pale blue-grey rim, gold for the one thing to press
const FELT := Color("0f3a32")  ## a working window's felt (the painted panel's green, darkened)
const FELT_ALPHA := 0.93  ## "a touch of transparency"
const CARD := Color(0.02, 0.13, 0.11, 0.62)  ## a section card inside a window
const INSET := Color(0.02, 0.1, 0.09, 0.85)  ## chips, slots, bar tracks
const BTN := Color(0.035, 0.16, 0.14, 0.94)
const BTN_HOVER := Color(0.06, 0.22, 0.19, 0.96)
const RIM := Color(0.66, 0.78, 0.82, 0.55)  ## the thin pale rim on cards, chips and buttons
const RIM_DIM := Color(0.66, 0.78, 0.82, 0.3)
const GOLD := Color(0.97, 0.84, 0.47)
const X_BLUE := Color("1d3a5c")
const TEXT := Color("f2eddb")
const TEXT_QUIET := Color(0.86, 0.85, 0.78)  ## a quiet button's words: dimmer, never faint (the LEAVE flag)
const TEXT_DIM := Color(0.78, 0.82, 0.78)
const PORTRAIT_BG := Color("b9cfdc")

const ROW_H := 50.0  ## a dialogue option's height
const ICON := 36.0  ## an option's icon
const BODY := 19  ## body text size
const HEAD := 18  ## a section heading
const CALL := 28  ## a dialogue's call line ("THIS CHEST IS LOCKED")
const WINDOW_TOP := 26.0  ## a big window's inside starts this far down: below the title plate's foot and the X

## an option's icon by its text key: an icon in art/source/icons, or a drawn glyph (talk, plus, leave, dot) where
## there is no art yet (graybox)
const OPTION_ICONS := {
	"OPT_FIGHT": "strike", "OPT_SNEAK_HIT": "stab", "OPT_SNEAK": "stab", "OPT_TALK": "@talk", "OPT_CALM": "@talk",
	"OPT_INVITE": "@plus", "OPT_WELCOME": "@plus", "OPT_HELP_UP": "@plus", "OPT_LEAVE": "@leave", "OPT_BACK_OFF": "@leave",
	"OPT_STAY": "@leave", "OPT_RUN": "@leave", "UI_BOX_LEAVE": "@leave", "UI_BOX_CLOSE": "@leave", "OPT_SEND_HOME": "@leave",
	"OPT_PICK_LOCK": "stab", "UI_BOX_USE_KEY": "key", "UI_BOX_PICK": "stab", "UI_BOX_DISARM": "trap", "OPT_DISARM": "trap",
	"OPT_BASH": "smash", "UI_BOX_OPEN_ANYWAY": "smash", "OPT_TAKE": "backpack", "OPT_RUMMAGE": "backpack",
	"OPT_SEARCH": "lantern", "OPT_DIG": "stone", "OPT_EAT": "meat", "OPT_FISH": "rod", "OPT_SLEEP": "moon_sleep",
	"OPT_SHELTER": "guard", "OPT_HUDDLE": "guard", "OPT_TRADE": "gold", "OPT_READ_STARS": "star_guide",
	"OPT_READ_MARKS": "scroll", "OPT_TAKE_BOOK": "books", "OPT_TIE_ROPE": "rope", "OPT_CLIMB_DOWN": "rope",
	"OPT_FEED_FLAME": "fire", "OPT_HIDE_LIGHT": "smoke", "OPT_TAKE_STONE": "rare", "OPT_STONE_CALLS": "rare",
	"OPT_FIX_STONE": "rare", "OPT_MOON_OPEN": "moonbeam", "OPT_PASS": "dash", "OPT_GO_ON": "dash", "OPT_PUSH_ON": "dash",
	"OPT_FORD": "water", "OPT_AROUND": "dash", "UI_GATE_GO": "dash", "UI_GATE_FOOD_GO": "dash", "UI_GATE_FOOD_BACK": "@leave",
}
## quiet options: the way out, dimmer and always last
const QUIET_KEYS := ["OPT_LEAVE", "OPT_BACK_OFF", "OPT_STAY", "UI_BOX_LEAVE", "UI_BOX_CLOSE", "OPT_RUN", "UI_GATE_FOOD_BACK"]


# --- the styles (theme type variations) ------------------------------------------------------------

static func flat(bg: Color, rim: Color, width := 1.5, radius := 10, pad_x := 12.0, pad_y := 8.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = rim
	sb.set_border_width_all(int(ceil(width)))
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 10
	sb.anti_aliasing = true
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


static func _glow(sb: StyleBoxFlat, col: Color, size: int) -> StyleBoxFlat:
	sb.shadow_color = col
	sb.shadow_size = size
	return sb


static func style(t: Theme) -> void:
	for v in ["KitCard", "KitChip", "KitSlot"]:
		t.set_type_variation(v, "PanelContainer")
	t.set_stylebox("panel", "KitCard", flat(CARD, RIM_DIM, 1.0, 10, 14.0, 12.0))
	t.set_stylebox("panel", "KitChip", flat(INSET, RIM, 1.0, 16, 12.0, 3.0))
	t.set_stylebox("panel", "KitSlot", flat(INSET, RIM_DIM, 1.0, 8, 4.0, 4.0))
	# buttons: a dialogue option or any plain button; the rim lights gold under the mouse or the keys
	_buttons(t, "Button", BTN, RIM, TEXT, 1.5)
	for v in ["PrimaryButton", "QuietButton", "KitX"]:
		t.set_type_variation(v, "Button")
	_buttons(t, "PrimaryButton", BTN, Color(GOLD, 0.9), TEXT, 2.0)
	t.set_stylebox("normal", "PrimaryButton", _glow(flat(BTN, Color(GOLD, 0.9), 2.0, 14, 24.0, 8.0), Color(GOLD, 0.28), 6))
	_buttons(t, "QuietButton", Color(BTN, 0.72), RIM_DIM, TEXT_QUIET, 1.0)
	# the X: drawn round by XButton; its own boxes stay empty
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(st, "KitX", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		t.set_color(c, "KitX", Color(0, 0, 0, 0))
	# a section heading: parchment small caps size, centred by the builder
	t.set_type_variation("KitHeading", "Label")
	t.set_font_size("font_size", "KitHeading", HEAD)
	t.set_color("font_color", "KitHeading", TEXT)
	# the thin scrollbar: a dark track with a pale rounded thumb
	var track := flat(Color(INSET, 0.7), RIM_DIM, 1.0, 5, 0.0, 0.0)
	track.content_margin_left = 3
	track.content_margin_right = 3
	var thumb := flat(Color(TEXT, 0.7), Color(TEXT, 0.0), 0.0, 4, 0.0, 0.0)
	t.set_stylebox("scroll", "VScrollBar", track)
	t.set_stylebox("scroll_focus", "VScrollBar", track)
	t.set_stylebox("grabber", "VScrollBar", thumb)
	t.set_stylebox("grabber_highlight", "VScrollBar", flat(TEXT, Color(TEXT, 0.0), 0.0, 4, 0.0, 0.0))
	t.set_stylebox("grabber_pressed", "VScrollBar", flat(GOLD, Color(GOLD, 0.0), 0.0, 4, 0.0, 0.0))
	t.set_constant("scrollbar_h_separation", "ScrollContainer", 8)


static func _buttons(t: Theme, type: String, bg: Color, rim: Color, text: Color, width: float) -> void:
	t.set_stylebox("normal", type, flat(bg, rim, width, 14, 24.0, 8.0))
	t.set_stylebox("hover", type, _glow(flat(BTN_HOVER, GOLD, 2.0, 14, 24.0, 8.0), Color(GOLD, 0.4), 8))
	t.set_stylebox("pressed", type, flat(bg.darkened(0.25), GOLD, 2.0, 14, 24.0, 8.0))
	t.set_stylebox("hover_pressed", type, flat(bg.darkened(0.25), GOLD, 2.0, 14, 24.0, 8.0))
	t.set_stylebox("disabled", type, flat(Color(bg, bg.a * 0.6), Color(rim, rim.a * 0.5), 1.0, 14, 24.0, 8.0))
	var focus := _glow(flat(Color(0, 0, 0, 0), GOLD, 2.0, 14, 24.0, 8.0), Color(GOLD, 0.35), 8)
	focus.draw_center = false
	t.set_stylebox("focus", type, focus)
	t.set_color("font_color", type, text)
	t.set_color("font_hover_color", type, Color(1, 0.97, 0.88))
	t.set_color("font_pressed_color", type, GOLD)
	t.set_color("font_focus_color", type, Color(1, 0.97, 0.88))
	t.set_color("font_hover_pressed_color", type, GOLD)
	t.set_color("font_disabled_color", type, Color(text, 0.45))


# --- the window -----------------------------------------------------------------------------------

## A big window with a title plate on its top edge (HOME AGAIN, WIN): returns {"root", "panel", "body", "x"}. `body`
## (a VBox) is the window's inside; it scrolls past the room `area` gives (frame_window). The root is what the host
## places (keep_inside or a CenterContainer); the plate straddles the frame's top rim, bright green, the one call-out.
static func window(title: String, area: Callable, close := Callable(), title_px := 40, scroll_room := Callable()) -> Dictionary:
	var root := MarginContainer.new()
	var plate := PanelContainer.new()
	plate.theme_type_variation = &"TitlePlate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := Label.new()
	t.theme_type_variation = &"MenuTitle"
	t.text = title
	t.add_theme_font_size_override("font_size", title_px)
	t.add_theme_color_override("font_color", TEXT)
	t.add_theme_color_override("font_outline_color", Color(0.02, 0.1, 0.08, 0.9))
	t.add_theme_constant_override("outline_size", 4)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(t)
	var psb := plate.get_theme_stylebox("panel", "TitlePlate").duplicate() as StyleBox
	var clear := 58.0 if UiSkin.on() else 84.0  # the words well clear of the plate's ends (leaf and gem, or the banner's point and diamond)
	psb.content_margin_left = clear
	psb.content_margin_right = clear
	plate.add_theme_stylebox_override("panel", psb)
	var over := plate.get_combined_minimum_size().y * 0.62  # how far the plate stands above the frame
	root.add_theme_constant_override("margin_top", int(over))
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"DialogPanel"
	panel.set_meta("x_drop", 10.0)
	root.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	var x := UiTheme.frame_window(panel, body, scroll_room if scroll_room.is_valid() else area, close)
	var room := Control.new()  # the inside starts below the plate's foot and the X
	room.custom_minimum_size.y = WINDOW_TOP
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(room)
	var foot := HBoxContainer.new()  # the primary button's row: under the scroll, so it never scrolls away (research B2)
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_theme_constant_override("separation", 14)
	var foot_pad := MarginContainer.new()
	foot_pad.add_theme_constant_override("margin_right", 30)  # clear of the corner leaves (the mockup's CONTINUE flag)
	foot_pad.add_theme_constant_override("margin_top", 6)
	foot_pad.add_theme_constant_override("margin_bottom", 8)
	foot_pad.add_child(foot)
	panel.get_child(0).add_child(foot_pad)
	var top := Control.new()  # the plate's stand: full width, the plate centred on the rim
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	top.add_child(plate)
	var place := func() -> void:
		plate.reset_size()
		plate.custom_minimum_size.x = maxf(plate.get_combined_minimum_size().x, 380.0)
		plate.position = Vector2(roundf((top.size.x - plate.size.x) * 0.5), -over)
	top.resized.connect(place)
	plate.resized.connect(place)
	return {"root": root, "panel": panel, "body": body, "x": x, "foot": foot}


## The little point under a dialogue window, aimed at the bottom frame's diamond (mockups A and B). Goes last in the
## window's column; it draws below the frame's rim.
static func pointer(col: Control, drop := 30.0) -> void:
	if UiSkin.on():  # the drawn bar's gem marks the spot; a point on top of it only clutters
		return
	var p := _Pointer.new()
	p.drop = drop
	col.add_child(p)


# --- the dialogue call/response screen ---------------------------------------------------------------

const DIALOG_W := 520.0  ## the options' width
const DIALOG_PORTRAIT := 190.0
const CALL_CHARS := 44  ## a call line this short or shorter is the window's heading

## The dialogue call/response screen ([USER] 2026-11-01: "the same screen for "This chest is locked" "I have the key!!!"
## "Use lockpick" "Smash it". Or when you meet a character it should be the exact same screen", with "a "has-portrait"
## element"; round 2 mockups A and B): one window for every event, prompt and talk, on the explore maps, the overworld
## and in fights. A short call line stands centred at the top (mockup A); longer words sit under it as body text; with
## a portrait (art/source/portraits/<id>.png) the speaker's framed face is on the left, the words and options on its
## right (mockup B). Fills `panel` (empty) and returns the column the options go in (`answer`). The host adds the panel
## and places it (UiTheme.at_diamond, with `pointer`).
static func dialogue(panel: PanelContainer, text: String, area: Callable, face_id := "") -> VBoxContainer:
	panel.theme_type_variation = &"DialogPanel"
	var face := face_id != "" and ResourceLoader.exists("res://art/source/portraits/%s.png" % face_id)
	var call := text != "" and not face and text.length() <= CALL_CHARS and not text.contains("\n")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	panel.set_meta("frame_x", UiTheme.frame_window(panel, row, area, Callable(), text if call else ""))  # the X; scrolls past the room
	panel.set_meta("kit_w", DIALOG_W - (DIALOG_PORTRAIT * 0.5 if face else 0.0))
	if face:
		var pic := portrait(face_id, DIALOG_PORTRAIT, false)
		pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(pic)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)
	if face:  # the speaker's name over the words (mockup B's dialogue with a portrait)
		var d := Db.character(StringName(face_id))
		if d != null:
			var nm := label(Txt.t(d.name_key), 20, GOLD)
			box.add_child(nm)
	if text != "" and not call:
		var l := label(text, 21)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if face else HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(float(panel.get_meta("kit_w")) - 48.0, 0)
		var pad := MarginContainer.new()  # clear of the X on the top right corner
		pad.add_theme_constant_override("margin_right", 48)
		pad.add_theme_constant_override("margin_left", 0 if face else 48)
		pad.add_child(l)
		box.add_child(pad)
		var gap := Control.new()  # the words, then a breath before the options
		gap.custom_minimum_size.y = 4
		box.add_child(gap)
	return box


## An answer on a dialogue (`dialogue`'s column): its icon from its words, the odds or cost in a chip on its right
## (`chip`, who rolls in `tip`), quiet if it is the way out.
static func answer(box: VBoxContainer, text: String, cb: Callable, chip_text := "", tip := "") -> Button:
	var w := DIALOG_W
	var n: Node = box
	while n != null and not (n is PanelContainer and n.has_meta("kit_w")):
		n = n.get_parent()
	if n != null:
		w = float(n.get_meta("kit_w"))
	var icon := icon_for(text)
	var b := option(text, cb, icon if icon != "" else "@dot", chip_text, is_quiet(text), w)
	b.tooltip_text = tip
	var first := not box.get_children().any(func(c: Node) -> bool: return c is Button)
	box.add_child(b)
	if first:  # the first answer has the keys' focus: its rim lights gold (mockup A)
		b.grab_focus.call_deferred()
	return b


# --- pieces ---------------------------------------------------------------------------------------

## A section card with a heading (BROUGHT HOME, PARTY, LOOT): returns the card's inside (a VBox).
static func card(parent: Control, heading := "", rules := false) -> VBoxContainer:
	var c := PanelContainer.new()
	c.theme_type_variation = &"KitCard"
	parent.add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	c.add_child(v)
	if heading != "":
		v.add_child(heading_row(heading, rules))
	return v


## A heading, centred; with `rules`, a thin line runs out either side (LOOT, PACK on the win screen).
static func heading_row(text: String, rules := false) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	if rules:
		h.add_child(_Rule.new())
	var l := Label.new()
	l.theme_type_variation = &"KitHeading"
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(l)
	if rules:
		var right := _Rule.new()
		right.flip = true
		h.add_child(right)
	return h


## A chip: a small pill with an optional icon and a short value ("+3", "60%", "0/4"). Hover names it (`tip`).
static func chip(text: String, icon := "", col := TEXT, tip := "", px := 17) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = &"KitChip"
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # a pill, never stretched tall by its row
	p.tooltip_text = tip
	p.mouse_filter = Control.MOUSE_FILTER_STOP if tip != "" else Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(h)
	if icon != "":
		h.add_child(icon_rect(icon, px + 9))
	h.add_child(label(text, px, col))
	return p


## An item slot: the item's icon in a dark rounded square, its count in the corner (the win screen's loot and pack,
## HOME AGAIN's haul). `count` 0 hides the number; an empty `icon` is an empty slot.
static func slot(icon: String, count := 0, px := 52.0, tip := "") -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = &"KitSlot"
	p.custom_minimum_size = Vector2(px, px)
	p.tooltip_text = tip
	p.mouse_filter = Control.MOUSE_FILTER_STOP if tip != "" else Control.MOUSE_FILTER_IGNORE
	if icon != "" and (icon.begins_with("@") or ActionInfo.icon(icon) != null):
		p.add_child(icon_rect(icon, px - 12))
	elif icon != "":  # graybox: no picture yet, so its name, small
		var n := label(Txt.t(String(Db.items[icon].name_key)) if Db.items.has(icon) else icon, 11, MenuKit.TEXT_DIM)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(n)
	if count > 0:
		var n := label(str(count), 15)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		n.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		n.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		n.add_theme_constant_override("outline_size", 4)
		n.add_theme_constant_override("line_spacing", -4)
		p.add_child(n)
	return p


## A portrait in its frame: round (party rows, win cards) or square (the dialogue's speaker). The face is the
## character's portrait (art/source/portraits/<id>.png), or a graybox stand-in drawn in its tint until there is one.
static func portrait(id: String, px: float, round := true) -> Control:
	var p := _Portrait.new()
	p.round = round
	p.custom_minimum_size = Vector2(px, px)
	var path := "res://art/source/portraits/%s.png" % id
	if id != "" and ResourceLoader.exists(path):
		p.face = load(path)
	else:
		var d := Db.character(StringName(id)) if id != "" else null
		p.tint = d.tint if d else Color(0.55, 0.6, 0.62)
	return p


## A labelled bar: the label outside on the left ("HP", "MP"), the bar with its number on it.
static func bar_row(parent: Control, text: String, fill: Color, value: float, number: String, label_w := 44.0) -> UiBar:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	parent.add_child(h)
	if text != "":
		var l := label(text, 15, TEXT)
		l.custom_minimum_size.x = label_w
		h.add_child(l)
	var b := UiBar.new()
	b.fill = fill
	b.value = clampf(value, 0.0, 1.0)
	b.text = number
	b.custom_minimum_size = Vector2(130, 16)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	return b


## A dialogue option or action: a full-width row with its icon on the left, its words, and an odds or cost chip on the
## right. Its text stays the plain label (Esc and the robot find buttons by it). `quiet` for the way out.
static func option(text: String, cb: Callable, icon := "", chip_text := "", quiet := false, width := 520.0) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(width, ROW_H)
	b.add_theme_font_size_override("font_size", 20)
	if quiet:
		b.theme_type_variation = &"QuietButton"
	if cb.is_valid():
		b.pressed.connect(cb)
	var pad := 24.0
	if icon != "":
		pad = 22.0 + ICON + 18.0
		var ic := icon_rect(icon, ICON)
		ic.position = Vector2(22.0, (ROW_H - ICON) * 0.5)
		ic.modulate = Color(1, 1, 1, 0.8) if quiet else Color.WHITE
		b.add_child(ic)
		b.resized.connect(func() -> void: ic.position.y = roundf((b.size.y - ICON) * 0.5))
	for s in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var sb := b.get_theme_stylebox(s).duplicate() as StyleBox
		sb.content_margin_left = pad
		if chip_text != "":
			sb.content_margin_right = 96.0
		b.add_theme_stylebox_override(s, sb)
	if chip_text != "":
		var c := chip(chip_text, "", TEXT, "", 16)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(c)
		var put := func() -> void:
			c.reset_size()
			c.position = Vector2(b.size.x - c.size.x - 14.0, roundf((b.size.y - c.size.y) * 0.5))
		b.resized.connect(put)
		c.resized.connect(put)
	return b


## The icon for an option's words (OPTION_ICONS by the key whose text it is), "" when none fits.
static func icon_for(text: String) -> String:
	for k: String in OPTION_ICONS:
		if Txt.t(k) == text:
			return String(OPTION_ICONS[k])
	return ""


static func is_quiet(text: String) -> bool:
	return QUIET_KEYS.any(func(k: String) -> bool: return Txt.t(k) == text)


## An icon by id: a picture from art/source/icons, or a drawn glyph for "@talk", "@plus", "@leave", "@dot".
static func icon_rect(id: String, px: float) -> Control:
	if id.begins_with("@"):
		var g := _Glyph.new()
		g.kind = id.substr(1)
		g.custom_minimum_size = Vector2(px, px)
		g.size = Vector2(px, px)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return g
	var t := TextureRect.new()
	t.texture = ActionInfo.icon(id)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.size = Vector2(px, px)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func label(text: String, px := BODY, col := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	return l


## A button in the kit's primary look (the one to press: CONTINUE, ONE MORE GO, TAKE ALL).
static func primary(text: String, cb: Callable, px := 22, w := 240.0) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"PrimaryButton"
	b.text = text
	b.custom_minimum_size = Vector2(w, 52)
	b.add_theme_font_size_override("font_size", px)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


## The round X at the top right of every window: a blue disc, a white ring, a white cross; the ring lights gold under
## the mouse. Its text stays "X" (the robot skips it by that), drawn by hand instead.
class XButton extends Button:
	func _init() -> void:
		text = "X"
		theme_type_variation = &"KitX"
		custom_minimum_size = Vector2(UiTheme.FRAME_X, UiTheme.FRAME_X)
		size = custom_minimum_size
		focus_mode = Control.FOCUS_NONE
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 1.0
		var lit := is_hovered() and not disabled
		var a := 0.45 if disabled else 1.0
		if UiSkin.on():  # the drawn skin: a small quiet square, the cross in the hairline's gold
			var box := UiSkin.flat(Color(UiSkin.GOLD, 0.16) if lit else Color(0, 0, 0, 0.22), Color(UiSkin.HAIR, 0.95 if lit else 0.3), 4, 0.0, 0.0)
			var side := minf(minf(size.x, size.y), UiSkin.X_SIZE)  # a square in the middle, whatever room it was given
			draw_style_box(box, Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side)))
			var q := side * 0.2
			var cross := Color(UiSkin.TEXT if lit else UiSkin.HAIR, a)
			draw_line(c + Vector2(-q, -q), c + Vector2(q, q), cross, 1.6, true)
			draw_line(c + Vector2(-q, q), c + Vector2(q, -q), cross, 1.6, true)
			return
		if lit:
			draw_circle(c, r + 4.0, Color(MenuKit.GOLD, 0.25))
		draw_circle(c, r, Color(0.02, 0.06, 0.08, a))
		draw_circle(c, r - 1.5, Color(MenuKit.X_BLUE.lightened(0.12 if lit else 0.0), a))
		draw_arc(c, r - 2.5, 0.0, TAU, 40, Color(MenuKit.GOLD if lit else Color(0.95, 0.96, 0.95), a), 2.0, true)
		var k := r * 0.36
		var ink := Color(0.97, 0.97, 0.95, a)
		draw_line(c + Vector2(-k, -k), c + Vector2(k, k), ink, 3.0, true)
		draw_line(c + Vector2(-k, k), c + Vector2(k, -k), ink, 3.0, true)


# --- drawn bits -----------------------------------------------------------------------------------

class _Rule extends Control:
	var flip := false  ## the rule on the heading's right: its words are to its left

	func _init() -> void:
		custom_minimum_size = Vector2(70, 8)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y * 0.5
		if UiSkin.on():  # the drawn skin: the rule fades out from a gold diamond beside the words
			var near := Vector2(0.0 if flip else size.x, y)
			var far := Vector2(size.x if flip else 0.0, y)
			UiSkin.rule(self, near, far)
			return
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(MenuKit.TEXT, 0.55), 1.5, true)


class _Pointer extends Control:
	var drop := 30.0

	func _init() -> void:
		custom_minimum_size = Vector2(0, 0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y + drop)
		var w := 15.0
		var pts := PackedVector2Array([c + Vector2(-w, -2), c + Vector2(w, -2), c + Vector2(0, w * 0.9)])
		draw_colored_polygon(pts, Color(MenuKit.FELT, 0.98))
		draw_polyline(PackedVector2Array([pts[0], pts[2], pts[1]]), Color(0.85, 0.9, 0.94), 3.0, true)
		draw_polyline(PackedVector2Array([pts[0] + Vector2(0, -1), pts[2] + Vector2(0, 3), pts[1] + Vector2(0, -1)]), Color(UiTheme.DIAMOND, 0.9), 1.5, true)


class _Portrait extends Control:
	var face: Texture2D
	var tint := Color.GRAY
	var round := true

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var c := size * 0.5
		var rad := minf(size.x, size.y) * 0.5
		var pts := PackedVector2Array()
		if round:
			for i in 48:
				pts.append(c + Vector2.from_angle(TAU * i / 48.0) * (rad - 3.0))
		else:
			var g := r.grow(-3.0)
			pts = PackedVector2Array([g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)])
		draw_colored_polygon(pts, MenuKit.PORTRAIT_BG)
		if face != null:
			var uvs := PackedVector2Array()
			var inner := r.grow(-3.0)
			for p in pts:
				uvs.append((p - inner.position) / inner.size)
			draw_colored_polygon(pts, Color.WHITE, uvs, face)
		else:  # graybox: a head and shoulders in the character's tint
			draw_circle(c + Vector2(0, -rad * 0.18), rad * 0.3, tint)
			var body := PackedVector2Array()
			for i in 17:
				body.append(c + Vector2(0, rad * 0.62) + Vector2.from_angle(PI + PI * i / 16.0) * Vector2(rad * 0.55, rad * 0.5))
			draw_colored_polygon(body, tint.darkened(0.15))
		var ring := pts.duplicate()
		ring.append(pts[0])
		draw_polyline(ring, Color(0.03, 0.1, 0.09), 5.0, true)
		draw_polyline(ring, Color(0.93, 0.95, 0.94), 2.5, true)


class _Glyph extends Control:
	var kind := "dot"

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var c := size * 0.5
		var ink := Color(0.95, 0.94, 0.9)
		var line := Color(0.05, 0.12, 0.1, 0.9)
		match kind:
			"talk":  # a speech bubble
				var pts := PackedVector2Array()
				for i in 32:
					pts.append(c + Vector2(0, -s * 0.06) + Vector2.from_angle(TAU * i / 32.0) * Vector2(s * 0.42, s * 0.32))
				draw_colored_polygon(pts, ink)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.22, s * 0.12), c + Vector2(-s * 0.02, s * 0.2),
					c + Vector2(-s * 0.34, s * 0.42)]), ink)
			"plus":
				draw_rect(Rect2(c - Vector2(s * 0.08, s * 0.36), Vector2(s * 0.16, s * 0.72)), ink)
				draw_rect(Rect2(c - Vector2(s * 0.36, s * 0.08), Vector2(s * 0.72, s * 0.16)), ink)
			"leave":  # two footprints
				for k in [-1.0, 1.0]:
					var base := c + Vector2(k * s * 0.16, k * s * 0.1)
					var foot := PackedVector2Array()
					for i in 24:
						foot.append(base + Vector2.from_angle(TAU * i / 24.0) * Vector2(s * 0.11, s * 0.2))
					draw_colored_polygon(foot, ink)
					draw_polyline(foot + PackedVector2Array([foot[0]]), line, 1.0, true)
			_:
				var pts := PackedVector2Array([c + Vector2(0, -s * 0.22), c + Vector2(s * 0.22, 0), c + Vector2(0, s * 0.22), c + Vector2(-s * 0.22, 0)])
				draw_colored_polygon(pts, UiTheme.DIAMOND)
				draw_polyline(pts + PackedVector2Array([pts[0]]), ink, 1.5, true)

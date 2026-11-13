class_name MainMenu
extends Control
## The player's front door (the game's main scene): Brandon's title video looping, muted (Brandon 2026-11-13: "Loop the
## video on the menu screen"), with the calm menu music; the logo is in the art, so the menu draws no title of its own.
## The video starts on the title painting with its logo and ends without it, so the painting waits underneath: the
## video fades out over its last moments, the logo seems to fade back in, and the video starts again on that same
## frame. Both drift slowly, with CONTINUE, NEW GAME, OPTIONS and QUIT in the middle of the screen, under
## the logo (Brandon 2026-11-13: "Put em smack in the middle"). A small DEV TOOLS button (debug builds and Brandon's
## machines only, Game.dev_available) opens the old launch page with every tool on it; anything started from there runs in dev mode.
## Brandon 2026-11-13: "there should be a main menu player path, with ... the Dev Tools menu that if you click it opens
## all of our other tools we currently have on that main launch page".

const BACKDROP := "res://art/source/ui/menu/title_screen.webp"  ## Brandon 2026-11-13: "Make this the menu screen"
const VIDEO := "res://art/source/ui/menu/title_intro.ogv"  ## no sound track; the player is muted too
const LOOP_FADE := 0.6  ## seconds the video takes to fade out into the painting before it loops
const LOOP_IN := 0.15  ## seconds it takes to fade back in once it restarts (the same picture, so it is unseen)
const DRIFT_SECONDS := 60.0  ## one slow pan across the painting and back
const DRIFT := 0.04  ## how much wider than the screen the painting is drawn, for the pan
const LOGO_BOTTOM := 0.32  ## where the painted logo ends, as a share of the painting's height: the buttons stay below

var _art: TextureRect  ## the title painting: the video's first frame, under the video
var _video: VideoStreamPlayer
var _column: VBoxContainer
var _box: Control  ## the open window (options, the new-game check), or null
var _dim: ColorRect  ## the shade behind it
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Game.dev_mode = false  # the player path: no god mode, no test buttons, no developer keys
	Sfx.music("menu")
	_art = TextureRect.new()
	_art.texture = load(BACKDROP) as Texture2D
	_art.stretch_mode = TextureRect.STRETCH_SCALE  # sized in _process: covers the screen, pinned to the top (the logo)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	_video = VideoStreamPlayer.new()
	_video.stream = load(VIDEO) as VideoStream
	_video.volume = 0.0
	_video.expand = true
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video.modulate.a = 0.0
	_video.finished.connect(_loop)
	add_child(_video)
	if DisplayServer.get_name() != "headless":
		_video.play()
	var shade := TextureRect.new()  # a soft pool of shade behind the buttons; the edges of the painting stay clear
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.55)
	g.fill_to = Vector2(0.5, 1.0)
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color(0.02, 0.04, 0.08, 0.4))
	g.gradient.set_color(1, Color(0.02, 0.04, 0.08, 0.0))
	shade.texture = g
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_column = VBoxContainer.new()
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_theme_constant_override("separation", 12)
	add_child(_column)
	var has_save := _has_save()
	if has_save:
		_column.add_child(_centred(MenuKit.primary(Txt.t("UI_MENU_CONTINUE"), _continue, 24, 300)))
	var fresh := MenuKit.primary(Txt.t("UI_MENU_NEW"), _new_game, 24, 300) if not has_save else _plain(Txt.t("UI_MENU_NEW"), _ask_new_game)
	_column.add_child(_centred(fresh))
	_column.add_child(_centred(_plain(Txt.t("UI_MENU_OPTIONS"), _options)))
	_column.add_child(_centred(_plain(Txt.t("UI_MENU_QUIT"), func() -> void: get_tree().quit())))

	var foot := Label.new()  # the build, bottom left; the feedback key, so testers know it is there
	foot.text = Txt.t("UI_MENU_FOOT")
	foot.add_theme_font_size_override("font_size", 14)
	foot.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	foot.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	foot.add_theme_constant_override("outline_size", 4)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position = Vector2(18, -34)
	foot.name = "Foot"
	add_child(foot)
	if Game.dev_available():
		var dev := Button.new()
		dev.text = Txt.t("UI_MENU_DEV")
		dev.tooltip_text = Txt.t("UI_MENU_DEV_TIP")
		dev.custom_minimum_size = Vector2(150, 38)
		dev.add_theme_font_size_override("font_size", 14)
		dev.pressed.connect(func() -> void: Game.go(Game.LAUNCH))
		dev.name = "Dev"
		add_child(dev)
	resized.connect(_fit)
	_fit.call_deferred()
	UiTheme.fade_in(_column)


func _process(delta: float) -> void:
	_t += delta
	if _art == null or _art.texture == null:
		return
	var r := art_rect(size, _art.texture.get_size(), 0.5 - 0.5 * cos(_t / DRIFT_SECONDS * TAU))
	_art.position = r.position
	_art.size = r.size
	if _video:  # framed like the painting (the same picture, the same shape), so they line up as they swap
		_video.position = r.position
		_video.size = r.size
		var length := _video.get_stream_length()
		if _video.is_playing() and length > 0.0:
			var pos := _video.stream_position
			_video.modulate.a = clampf(minf(pos / LOOP_IN, (length - pos) / LOOP_FADE), 0.0, 1.0)


func _loop() -> void:
	_video.modulate.a = 0.0
	_video.play()


## Where the painting sits, for a screen of `screen` size and a picture of `tex` size, `k` (0 to 1) along its sway.
## A slow drift: the painting a little wider than the screen, panning side to side. It covers the screen at any window
## shape and stays pinned to the top, so the painted logo is never cut; extra height crops the bottom. The sway is the
## same small amount at any window shape, around the picture's middle.
static func art_rect(screen: Vector2, tex: Vector2, k: float) -> Rect2:
	var s := maxf(screen.x / tex.x, screen.y / tex.y) * (1.0 + DRIFT)
	var sz := tex * s
	return Rect2(Vector2(-(sz.x - screen.x) * 0.5 + screen.x * DRIFT * (k - 0.5), 0.0).floor(), sz)


func _fit() -> void:
	var need := _column.get_combined_minimum_size()
	_column.size = need
	var s := minf(1.0, minf((size.x - 80.0) / maxf(1.0, need.x), (size.y - 80.0) / maxf(1.0, need.y)))
	_column.scale = Vector2(s, s)
	var top := (size.y - need.y * s) * 0.5  # the middle of the screen, but never over the painted logo
	if _art and _art.texture:
		top = maxf(top, _art.size.y * LOGO_BOTTOM + 8.0)
	_column.position = Vector2((size.x - need.x * s) * 0.5, top).floor()
	var foot := get_node_or_null("Foot") as Control
	if foot:
		foot.position = Vector2(18, size.y - 34)
	var dev := get_node_or_null("Dev") as Control
	if dev:
		dev.position = Vector2(size.x - dev.size.x - 18, size.y - dev.size.y - 16)
	if _box:
		UiTheme.centre_menu(_box, _area)


func _area() -> Rect2:
	return Rect2(Vector2.ZERO, size).grow(-24)


func _centred(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return c


func _plain(text: String, cb: Callable, w := 300.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 48)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	return b


## A save worth continuing: a bookmark, or anything found (the save has flags).
func _has_save() -> bool:
	return Game.has_bookmark() or not (Game.meta.get("flags", []) as Array).is_empty()


func _continue() -> void:
	if Game.has_bookmark():
		Game.continue_game()
	else:
		Game.explore_memory = {}
		Game.explore_map = "home"
		Game.explore_entry = Vector2i(-1, -1)
		Game.go(Game.EXPLORE)


func _new_game() -> void:
	Game.new_game()


## A save exists: starting over erases it, so ask first.
func _ask_new_game() -> void:
	var w := _window(Txt.t("UI_MENU_NEW"))
	w.body.add_child(MenuKit.label(Txt.t("UI_MENU_NEW_SURE"), 18))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.add_child(_plain(Txt.t("UI_MENU_NEW_YES"), _new_game))
	row.add_child(_plain(Txt.t("UI_CANCEL"), _close))
	w.body.add_child(row)


func _options() -> void:
	var w := _window(Txt.t("UI_OPTIONS"))
	AdventureMenu.options(w.body, func() -> void:
		_close()
		_options(), _close)
	for c in w.body.get_children():  # the page's own OPTIONS plate: the window's plate already says it
		if c is PanelContainer and c.get_child_count() > 0 and c.get_child(0) is Label \
				and (c.get_child(0) as Label).text == Txt.t("UI_OPTIONS"):
			c.free()
			break


func _window(title: String) -> Dictionary:
	_close()
	_dim = ColorRect.new()  # the menu behind steps back, so the open box reads on its own
	_dim.color = Color(0.01, 0.03, 0.04, 0.72)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	var w := MenuKit.window(title, _area, _close)
	_box = w.root
	add_child(_box)
	UiTheme.centre_menu(_box, _area)
	UiTheme.pop_in(_box)
	return w


func _close() -> void:
	if _box:
		_box.queue_free()
		_box = null
	if _dim:
		_dim.queue_free()
		_dim = null


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.is_echo() and event.keycode == KEY_ESCAPE and _box:
		_close()
		get_viewport().set_input_as_handled()


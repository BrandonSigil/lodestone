class_name LoadingScreen
extends Control
## The game's first screen (its main scene): Brandon's title video plays, muted, while the main menu loads behind it,
## and the calm menu music starts at once and carries on into the menu without a restart. When the video ends (or the
## player clicks or presses a key), it crossfades into the menu: the video's last frame is the menu's painting
## without its logo, framed the same way (MainMenu.art_rect), so the logo seems to fade back in.
## Brandon 2026-11-13: "Use this video as the loading screen, but play the calm music we have instead of the sound that
## plays in this video. Mute this video entirely." The file has no sound track at all (stripped when it was converted
## to Ogg Theora, the one video format Godot plays), and the player is muted as well.

const VIDEO := "res://art/source/ui/menu/title_intro.ogv"
const FADE := 0.8  ## seconds of crossfade into the menu
const HINT_AFTER := 1.5  ## seconds before the skip hint shows

var _video: VideoStreamPlayer
var _hint: Label
var _layer: CanvasLayer  ## over the menu while it fades in underneath
var _skin: Control  ## what fades out
var _done := false  ## the video ended or was skipped
var _leaving := false
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Sfx.music("menu")  # the menu calls the same mood, so the music runs on unbroken
	ResourceLoader.load_threaded_request(Game.MAIN_MENU)
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)
	_skin = Control.new()
	_skin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_skin)
	var black := ColorRect.new()  # behind the video, for the frame before it starts
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skin.add_child(black)
	_video = VideoStreamPlayer.new()
	_video.stream = load(VIDEO) as VideoStream
	_video.volume = 0.0
	_video.expand = true
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video.finished.connect(func() -> void: _done = true)
	_skin.add_child(_video)
	_hint = Label.new()
	_hint.text = Txt.t("UI_LOADING_SKIP")
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hint.add_theme_constant_override("outline_size", 4)
	_hint.modulate.a = 0.0
	_skin.add_child(_hint)
	_fit()
	if DisplayServer.get_name() == "headless":  # nothing to watch: straight on (the smoke runs, the tests)
		_done = true
	else:
		_video.play()


func _process(delta: float) -> void:
	_t += delta
	_fit()
	if _t > HINT_AFTER and not _leaving:
		_hint.modulate.a = minf(1.0, _hint.modulate.a + delta * 2.0)
	if _done and not _leaving:
		var status := ResourceLoader.load_threaded_get_status(Game.MAIN_MENU)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_leave(ResourceLoader.load_threaded_get(Game.MAIN_MENU) as PackedScene)
		elif status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:  # a failed threaded load: the plain way
			_leave(load(Game.MAIN_MENU) as PackedScene)


## The video framed exactly like the menu's painting at its start, so the crossfade lines up.
func _fit() -> void:
	var r := MainMenu.art_rect(size, Vector2(1280, 720), 0.0)
	_video.position = r.position
	_video.size = r.size
	_hint.reset_size()
	_hint.position = (size - _hint.size - Vector2(18, 16)).floor()


## The menu goes in underneath and becomes the current scene; the video fades off the top of it, then goes.
func _leave(menu_scene: PackedScene) -> void:
	_leaving = true
	var menu := menu_scene.instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	var tw := _skin.create_tween()
	tw.tween_property(_skin, "modulate:a", 0.0, FADE)
	tw.tween_callback(queue_free)


## _input, not _unhandled_input: this screen is a full-window Control, so a click would be taken as its own GUI input
## and never reach the unhandled pass (the first skip test, 2026-11-13).
func _input(event: InputEvent) -> void:
	if _leaving:
		return
	var key := event is InputEventKey and (event as InputEventKey).pressed and not event.is_echo()
	var click := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	if key or click:
		_done = true
		get_viewport().set_input_as_handled()

class_name FeedbackNote
extends CanvasLayer
## F12 anywhere (2026-11-13 playtest, for friends and family): the screen as it is now is saved, then a small box asks
## what happened. SAVE NOTE writes the note beside the picture with where the player was (scene, map, goal, trips),
## so a tester's report needs no explaining. Files go to user://feedback/<stamp>.png and .txt; OPEN FOLDER shows them.

const DIR := "user://feedback"

var _stamp := ""
var _text: TextEdit


static func open(tree: SceneTree) -> void:
	if tree.root.get_node_or_null("FeedbackNote") != null:
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	tree.root.get_texture().get_image().save_png("%s/%s.png" % [DIR, stamp])  # before the box covers anything
	var f := FeedbackNote.new()
	f.name = "FeedbackNote"
	f._stamp = stamp
	f.layer = 120
	tree.root.add_child(f)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var area := func() -> Rect2: return root.get_viewport_rect().grow(-40)
	var w := MenuKit.window(Txt.t("UI_FEEDBACK_TITLE"), area, queue_free)  # the title sits on the banner at the type scale (menus v3)
	root.add_child(w.root)
	var ask := MenuKit.label(Txt.t("UI_FEEDBACK_ASK"), 16)
	ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ask.custom_minimum_size.x = 600
	w.body.add_child(ask)
	_text = TextEdit.new()
	_text.custom_minimum_size = Vector2(600, 160)
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.add_theme_font_size_override("font_size", 16)
	w.body.add_child(_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	w.body.add_child(row)
	row.add_child(MenuKit.primary(Txt.t("UI_FEEDBACK_SAVE"), _save, 18, 200))
	var folder := Button.new()
	folder.text = Txt.t("UI_FEEDBACK_FOLDER")
	folder.custom_minimum_size = Vector2(180, 44)
	folder.pressed.connect(func() -> void: OS.shell_open(ProjectSettings.globalize_path(DIR)))
	row.add_child(folder)
	UiTheme.centre_menu(w.root, area)
	UiTheme.pop_in(w.root)
	_text.grab_focus.call_deferred()


func _save() -> void:
	var game := get_node("/root/Game")
	var scene := get_tree().current_scene
	var lines := PackedStringArray([
		_text.text.strip_edges(),
		"",
		"time: " + Time.get_datetime_string_from_system(),
		"scene: " + (scene.scene_file_path if scene else "?"),
		"map: " + String(game.get("explore_map")),
		"goal: " + Txt.t(GoalRules.main_goal(game.call("flags_now"))),
		"trips: " + str(game.get("meta").get("trips", 0)),
		"version: " + String(ProjectSettings.get_setting("application/config/version", "")),
	])
	var f := FileAccess.open("%s/%s.txt" % [DIR, _stamp], FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
		f.close()
	var layer := CanvasLayer.new()  # over every scene's own layers; gone with the toast
	layer.layer = 120
	get_tree().root.add_child(layer)
	var toast := HintToast.open(layer, Txt.t("UI_FEEDBACK_SAVED"), func() -> Rect2: return layer.get_viewport().get_visible_rect())
	toast.tree_exited.connect(layer.queue_free)
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.is_echo() and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		queue_free()

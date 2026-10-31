class_name GodMode
extends CanvasLayer
## God mode (dev builds): a small round "!" at the top left of every map screen. It opens the map maker on the map you
## are standing on, centred on the party; the maker's "Back to play" saves and drops you back on that spot.
## A screen takes part by having `god_jump() -> Dictionary` ({"key": map key, "cell": Vector2i, "back": {...}}).

const SIZE := 34.0

var _btn: Button


## On in debug builds (the editor, Brandon's runs) or with an empty ~/.lodestone/dev file; never in an export.
static func enabled() -> bool:
	return OS.is_debug_build() or FileAccess.file_exists(OS.get_environment("HOME") + "/.lodestone/dev")


func _ready() -> void:
	layer = 100
	_btn = Button.new()
	_btn.text = "!"
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.tooltip_text = "God mode: edit the map you are on"
	_btn.position = Vector2(10, 10)
	_btn.custom_minimum_size = Vector2(SIZE, SIZE)
	_btn.size = Vector2(SIZE, SIZE)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color(0.16, 0.2, 0.26, 0.85), "hover": Color(0.25, 0.4, 0.55, 0.95), "pressed": Color(0.1, 0.14, 0.2, 1.0)}[st]
		sb.border_color = Color(0.85, 0.9, 1.0, 0.9)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(int(SIZE / 2.0))
		sb.set_content_margin_all(0)
		_btn.add_theme_stylebox_override(st, sb)
	_btn.add_theme_font_size_override("font_size", 20)
	_btn.pressed.connect(jump)
	add_child(_btn)
	_btn.visible = false


func _process(_delta: float) -> void:
	var s := get_tree().current_scene
	_btn.visible = enabled() and s != null and s.has_method("god_jump")


func jump() -> void:
	var s := get_tree().current_scene
	if s == null or not s.has_method("god_jump"):
		return
	var j: Dictionary = s.call("god_jump")
	if j.is_empty():
		return
	var g := get_node("/root/Game")  # by path: Game builds this node, so naming it here would be a compile cycle
	g.god_return = j.get("back", {})
	g.maker_map = String(j.key)
	g.maker_focus = j.get("cell", Vector2i(-1, -1))
	g.go(g.MAKER)

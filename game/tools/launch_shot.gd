extends SceneTree
## Opens the launch menu at a given window size and saves a PNG (checks that the menu fits).
## Args after "--": <png path> [width] [height].

var _frames := 0
var _out := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	if args.size() > 2:
		DisplayServer.window_set_size(Vector2i(int(args[1]), int(args[2])))
	root.get_node("Game").set("save_enabled", false)
	change_scene_to_file("res://scenes/launch.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 20:
		return false
	root.get_texture().get_image().save_png(_out)
	return true

extends SceneTree
## Loads a scene, waits a few frames, saves the viewport to PNG, quits.
## Args after "--": <scene path> <png path>

var _frames := 0
var _out := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[1]
	change_scene_to_file(args[0])


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 20:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(_out)
		quit()
	return false

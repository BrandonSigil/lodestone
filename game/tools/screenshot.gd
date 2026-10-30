extends SceneTree
## Loads a scene, waits a few frames, saves the viewport to PNG, quits.
## Args after "--": <scene path> <png path> [panel id] [item ids to buy first...]
## The panel args drive the village hub so its panels can be checked too.

var _frames := 0
var _out := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[1]
	root.get_node("Game").set("save_enabled", false)  # screens bookmark as they open: a shot never writes the real save
	change_scene_to_file(args[0])


func _process(_delta: float) -> bool:
	_frames += 1
	var args := OS.get_cmdline_user_args()
	if _frames == 5 and args.size() > 2:
		var scene := current_scene
		for id in args.slice(3):
			scene.kit.buy(id)
		scene._refresh()
		scene._open(args[2])
	if _frames == 20:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(_out)
		quit()
	return false

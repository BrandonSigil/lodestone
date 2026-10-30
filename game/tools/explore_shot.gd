extends SceneTree
## Drives the explore scene into a state and saves a PNG, so the walkable map can be checked headless.
## Args after "--": <png path> <step> [map]. Steps: start, walk, wasd, door, spot, deploy, fight (crypt),
## overview, pack, pack_full, lodestone, gate (village), near:<x>,<y>, use:<thing id> (any map). The map defaults to crypt. See explore_shot_steps.gd.

var _frames := 0
var _out := ""
var _step := ""
var _steps: Object


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	_step = args[1] if args.size() > 1 else "start"
	root.get_node("Game").set("explore_map", args[2] if args.size() > 2 else "crypt")
	change_scene_to_file("res://scenes/explore.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	# Game classes are loaded at runtime: a -s script compiles before the autoloads exist.
	if _steps == null:
		_steps = load("res://tools/explore_shot_steps.gd").new()
	var done: bool = _steps.call("run", current_scene, _frames, _step)
	if done:
		root.get_viewport().get_texture().get_image().save_png(_out)
		quit()
	return false

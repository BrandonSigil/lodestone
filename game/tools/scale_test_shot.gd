extends SceneTree
## The scale C test fight (Launch > FIGHT > Scale C test) as a PNG, one piece selected so its move shows.
## Args after "--": <png path> [party index to select, default 1 = the rogue; -1: auto fight for a while, to fill the log]. Windowed: through tools/godot.sh.

var _frames := 0
var _out := ""
var _steps: Object


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	var game := root.get_node("Game")
	game.set("sandbox_map", "res://data/maps/arena_c.json")
	game.set("sandbox_play", true)
	game.set("scale_test", true)
	change_scene_to_file("res://scenes/combat_sandbox.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _steps == null:
		_steps = load("res://tools/scale_test_shot_steps.gd").new()
	var args := OS.get_cmdline_user_args()
	_steps.call("run", current_scene, _frames, int(args[1]) if args.size() > 1 else 1)
	if _frames == (300 if args.size() > 1 and int(args[1]) < 0 else 40):
		root.get_viewport().get_texture().get_image().save_png(_out)
		quit()
	return false

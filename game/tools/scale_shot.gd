extends SceneTree
## One fight at a study scale with a piece's move (blue) and the cells it could then hit (red) drawn
## (docs/design/scale-study.md). Args after "--": <png path> <today|a|b|c> [encounter id: that foe group, with the danger zone instead]
## Windowed: run it through tools/godot.sh.

var _frames := 0
var _out := ""
var _which := "today"
var _steps: Object


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	_which = args[1] if args.size() > 1 else "today"
	change_scene_to_file("res://scenes/combat_sandbox.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _steps == null:  # game classes load at runtime: a -s script compiles before the autoloads exist
		_steps = load("res://tools/scale_shot_steps.gd").new()
	var args := OS.get_cmdline_user_args()
	_steps.call("run", current_scene, _frames, _which, args[2] if args.size() > 2 else "")
	if _frames == 30:
		root.get_viewport().get_texture().get_image().save_png(_out)
		quit()
	return false

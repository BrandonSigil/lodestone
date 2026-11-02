extends SceneTree
## Renders a plot as the battle map a road fight draws (MapPlot.build) to a PNG.
## Args after "--": <png path> <region/id> [seed] [rot 0-3]. Needs a window (tools/godot.sh).

var _frames := 0
var _steps: Object
var _root: Node2D


func _initialize() -> void:
	_root = Node2D.new()
	root.add_child(_root)


func _process(_delta: float) -> bool:
	_frames += 1
	var args := OS.get_cmdline_user_args()
	if _frames == 2:
		_steps = load("res://tools/plot_shot_steps.gd").new()
		_steps.call("build", _root, args)
	if _frames == 12:
		root.get_viewport().get_texture().get_image().save_png(args[0])
		quit()
	return false

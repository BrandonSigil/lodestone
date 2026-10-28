extends SceneTree
## Renders one map with its look (backdrop, forest, lips) to a PNG, so map work can be checked headless.
## Args after "--": <png path> <map> [rot 0-3] [grid]
## <map>: maps/<name> (a sandbox map), explore/<name> (an exploration map), gen:<seed>:<w>:<h>[:<look>]
## (MapGen.valley) or recipe:<name> (MapRecipes). Needs a display: in the cloud use xvfb-run and --rendering-driver opengl3.

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
		_steps = load("res://tools/map_shot_steps.gd").new()
		_steps.call("build", _root, args)
	if _frames == 12:
		root.get_viewport().get_texture().get_image().save_png(args[0])
		quit()
	return false

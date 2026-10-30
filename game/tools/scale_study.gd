extends SceneTree
## Map size, move and reach study (docs/design/scale-study.md): today's numbers, then road fights at three scales,
## measured with the AI sim only (rounds to first contact, win %, close wins, stalls). Prints markdown.
## Usage: godot --headless --path game -s res://tools/scale_study.gd -- [fights per cell]


func _initialize() -> void:
	var r: Object = load("res://tools/scale_study_run.gd").new()
	r.call("run", OS.get_cmdline_user_args())
	quit()

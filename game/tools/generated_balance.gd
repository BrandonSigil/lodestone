extends SceneTree
## Prints AI-vs-AI results on generated maps, plain against irregular outlines.
## Usage: godot --headless --path game -s res://tools/generated_balance.gd -- [seeds] [fights]


func _initialize() -> void:
	var r: Object = load("res://tools/generated_balance_run.gd").new()
	r.call("run", OS.get_cmdline_user_args())
	quit()

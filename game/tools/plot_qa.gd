extends SceneTree
## Plot QA from the command line: every seed of each plot through MapQA (the plot maker's checks and the box bar).
## Usage: godot --headless --path game -s res://tools/plot_qa.gd -- forest/hollow snow/zigzag [--seeds=12]
## Prints per plot how many seeds pass each check and the first failure of each kind. Never writes a file.


func _initialize() -> void:
	var r: Object = load("res://tools/plot_qa_run.gd").new()
	quit(r.call("run", OS.get_cmdline_user_args()))

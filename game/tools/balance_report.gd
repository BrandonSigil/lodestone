extends SceneTree
## Prints AI-vs-AI win rates for every saved sandbox map at each difficulty preset.
## Usage: godot --headless --path game -s res://tools/balance_report.gd [-- fights]


func _initialize() -> void:
	var r: Object = load("res://tools/balance_report_run.gd").new()
	r.call("run", OS.get_cmdline_user_args())
	quit()

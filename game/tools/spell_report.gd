extends SceneTree
## Compares caster spell loadouts with AI-vs-AI fights on the default sandbox map at NORMAL.
## Usage: godot --headless --path game -s res://tools/spell_report.gd [-- fights]


func _initialize() -> void:
	var r: Object = load("res://tools/spell_report_run.gd").new()
	r.call("run", OS.get_cmdline_user_args())
	quit()

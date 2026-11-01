extends SceneTree
## The map maker's QA panel from the command line (MapQA, docs/systems/map-qa.md): every check on each map, one line
## a check and its first problems. Exit status 1 when any map fails a check.
## Usage: godot --headless --path game -s res://tools/map_qa.gd -- explore/crypt maps/highland [...] [--all]
##   --all  every problem, not just the first three a check


func _initialize() -> void:
	var r: Object = load("res://tools/map_qa_run.gd").new()
	var code: int = r.call("run", OS.get_cmdline_user_args())
	quit(code)

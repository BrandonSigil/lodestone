extends SceneTree
## Plays the end-to-end loop headless, start to boss, with fights on auto, and prints each step.
## godot --headless --path game -s res://tools/e2e_play.gd [-- seed]
## The seed fixes the dice (default 1), so a run can be repeated; fights can still be lost on bad rolls.
## Exit code 0 when every step passed. The steps live in e2e_play_steps.gd (game classes load at runtime).

var _steps: Object
var _started := false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		var args := OS.get_cmdline_user_args()
		seed(int(args[0]) if args.size() > 0 else 1)
		_steps = load("res://tools/e2e_play_steps.gd").new()
		_steps.call("play", self)
	if _steps.get("finished"):
		quit(1 if int(_steps.get("fails")) > 0 else 0)
	return false

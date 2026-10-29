extends SceneTree
## Walks into a group on an explore map the way a player would (the real walk, from the map start)
## and lets the fight play on auto. Prints the result of each try.
## godot --headless --path game -s res://tools/fight_probe.gd -- <map> <group> [tries]

var _steps: Object
var _started := false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_steps = load("res://tools/fight_probe_run.gd").new()
		_steps.call("play", self, OS.get_cmdline_user_args())
	if _steps.get("finished"):
		quit()
	return false

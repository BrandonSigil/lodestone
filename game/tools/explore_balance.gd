extends SceneTree
## AI-vs-AI win rates for the starting party (hero with a sword, the dog) against every enemy group
## on the E2E explore maps, met where the walk would meet them: party first, or ambushed.
## Road fights too (a snow valley per seed). The leader stands where the real walk meets the group, but a
## player who climbs first does better: check a fight that looks off with tools/fight_probe.gd.
## Usage: godot --headless --path game -s res://tools/explore_balance.gd [-- fights level weapon]


func _initialize() -> void:
	var r: Object = load("res://tools/explore_balance_run.gd").new()
	r.call("run", OS.get_cmdline_user_args())
	quit()

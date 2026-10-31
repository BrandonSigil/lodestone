extends SceneTree
## The outing in the sim: the road to the Lich, fight after fight, with HP, mana and charges carried (docs/design/outing-tuning.md).
## Usage: godot --headless --path game -s res://tools/outing_sim.gd -- <runs per weapon> <gap tiles> [key=value ...]
## key=value overrides a levels.csv or combat.csv row for this run (trickle_steps=6, mana_regen_pct=25 ...).


func _initialize() -> void:
	var r: Object = load("res://tools/outing_sim_run.gd").new()
	r.call("run", OS.get_cmdline_user_args())
	quit()

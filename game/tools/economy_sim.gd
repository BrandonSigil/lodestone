extends SceneTree
## The economy in the sim: the road's nights, food, morale and evening actions, and the whole pass trip to the Lich (docs/design/balance-master-plan.md).
## Usage: godot --headless --audio-driver Dummy --path game -s res://tools/economy_sim.gd -- <acts|road|chain|levels> [key=value ...]
## Nothing here touches game/data: key=value overrides (levels.csv, combat.csv, camp.csv, morale.csv rows) live in this process only.


func _initialize() -> void:
	var r: Object = load("res://tools/economy_sim_run.gd").new()
	r.call("run", OS.get_cmdline_user_args())
	quit()

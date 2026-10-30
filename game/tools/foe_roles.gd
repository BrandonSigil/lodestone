extends SceneTree
## AI-vs-AI results for the caster and charger foe groups against the usual road foes (120 fights a row, no stalls
## allowed). Usage: godot --headless --path game -s res://tools/foe_roles.gd -- [fights]


func _initialize() -> void:
	var r: Object = load("res://tools/foe_roles_run.gd").new()
	r.call("run", OS.get_cmdline_user_args())
	quit()

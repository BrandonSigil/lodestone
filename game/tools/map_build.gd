extends SceneTree
## Saves a MapRecipes layout as a battle map in data/maps, with a test party and foes at either end.
## Args after "--": <recipe> [tile set, default alpine]
## godot --headless --path game -s res://tools/map_build.gd -- highland


func _process(_delta: float) -> bool:
	var args := OS.get_cmdline_user_args()
	var recipes: Script = load("res://scripts/maker/map_recipes.gd")
	print(recipes.call("save", args[0], args[1] if args.size() > 1 else "alpine"))
	quit()
	return false

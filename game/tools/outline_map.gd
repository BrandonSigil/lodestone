extends SceneTree
## Writes a generated irregular-outline map as a sandbox file so it can be shot: godot -s res://tools/outline_map.gd -- <seed> <name> [relief]
## Game classes load at runtime (a -s script compiles before the autoloads exist).


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var setup = load("res://scripts/sandbox/sandbox_setup.gd").default_setup()
	var relief := float(args[2]) if args.size() > 2 else 1.0
	setup.grid = load("res://scripts/combat/combat_grid.gd").generate(int(args[0]), 14, 9, 0.0, true, relief)
	setup.clean()
	var f := FileAccess.open("res://data/maps/%s.json" % args[1], FileAccess.WRITE)
	f.store_string(JSON.stringify(setup.to_dict(), "\t"))
	f.close()
	quit(0)

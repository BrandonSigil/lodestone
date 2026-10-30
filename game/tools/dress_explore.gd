extends SceneTree
## Applies the painted-look authoring rules (V9 tidy edges, V10 pillars, V12 a road ribbon) to an explore map
## that a Python builder wrote, the same operations the map maker's Generate menu runs. Things, groups, the
## start and the cells around them are kept as built.
## godot --headless --path game -s res://tools/dress_explore.gd -- <map> [road_from_thing road_to_thing] [pillars] [pillar cap]
## e.g. -- snow_pass pass_exit crypt_stair 3   (tools/explore/build_snow_pass.py runs it after writing the map)


func _initialize() -> void:
	load("res://tools/dress_explore_run.gd").new().call("run", OS.get_cmdline_user_args())
	quit()

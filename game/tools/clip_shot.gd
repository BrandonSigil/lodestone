extends SceneTree
## Saves a short run of frames from an explore map, for a clip of something that moves (the trees in the
## wind, the snow): godot --path game -s res://tools/clip_shot.gd -- <out prefix> <map> <x>,<y> [frames] [every] [calm]
## calm: no wind and no weather, for a before picture.
## Writes <out prefix>_000.png and on. Needs a window (tools/godot.sh). The shot tools' own rule: no real save.

var _f := 0
var _args: PackedStringArray
var _saved := 0


func _initialize() -> void:
	_args = OS.get_cmdline_user_args()
	root.get_node("Game").set("save_enabled", false)
	root.get_node("Game").set("explore_map", _args[1])
	change_scene_to_file("res://scenes/explore.tscn")


func _process(_delta: float) -> bool:
	_f += 1
	var frames := int(_args[3]) if _args.size() > 3 else 24
	var every := int(_args[4]) if _args.size() > 4 else 3
	if _f == 5:
		var s: Node = current_scene
		var xy := _args[2].split(",")
		var c := Vector2i(int(xy[0]), int(xy[1]))
		var lead = s.call("leader")
		lead.place(c, s.get("grid").height_at(c))
		s.call("_refresh_sight")
		s.call("_refresh_units")
		s.set("focus", Vector2(c) + Vector2(0.5, 0.5))
		if _args.size() > 5 and _args[5] == "calm":
			s.get("board").get("_sway_mat").set_shader_parameter("lean", 0.0)
			s.get("weather").call("setup", "", Rect2(), 0)
	if _f > 40 and (_f - 40) % every == 0:
		root.get_viewport().get_texture().get_image().save_png("%s_%03d.png" % [_args[0], _saved])
		_saved += 1
		if _saved >= frames:
			quit()
	return false

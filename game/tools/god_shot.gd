extends SceneTree
## God mode walk-through: explore a map, press "!", look at the maker, press Back to play. Args after "--": <png prefix> [map] [x,y]
## Writes <prefix>_play.png, <prefix>_maker.png, <prefix>_back.png and prints where the leader stood before and after.

var _f := 0
var _args: PackedStringArray


func _process(_d: float) -> bool:
	_f += 1
	var g: Node = root.get_node("Game")
	if _f == 1:
		_args = OS.get_cmdline_user_args()
		g.ensure_run()
		g.explore_map = _args[1] if _args.size() > 1 else "village_v2"
		if _args.size() > 2:
			var p := _args[2].split(",")
			g.explore_entry = Vector2i(int(p[0]), int(p[1]))
		g.go(g.EXPLORE)
	elif _f == 60:
		_shot("_play")
		var lead = current_scene.leader()
		print("BEFORE ", lead.cell)
		root.get_node("Game").get_children().filter(func(n): return n is GodMode)[0].jump()
	elif _f == 140:
		_shot("_maker")
		print("MAKER ", current_scene.name, " focus ", current_scene.focus)
		current_scene.back_to_play()
	elif _f == 220:
		_shot("_back")
		print("AFTER ", current_scene.leader().cell)
		quit()
	return false


func _shot(tag: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(_args[0] + tag + ".png")

extends SceneTree
## A road fight (the overworld's random encounter, combat.tscn) as a PNG, to check its fight UI.
## Args after "--": <png path> [encounter id, default pair_bandits] [select: 1 selects the first piece] [flags, comma list:
## met_dog,met_fire_mage,found_bushberry brings everyone with art]. Windowed: tools/godot.sh.

var _frames := 0
var _out := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	var game := root.get_node("Game")
	game.set("save_enabled", false)  # a shot never writes the real save
	root.get_node("Db").call("reload")
	if args.size() > 3:
		(game.get("meta").flags as Array).append_array(args[3].split(",", false))
	change_scene_to_file("res://scenes/overworld.tscn")  # the road fight starts from the overworld, as in play


func _process(_delta: float) -> bool:
	_frames += 1
	var args := OS.get_cmdline_user_args()
	if _frames == 4:
		root.get_node("Game").call("start_combat", args[1] if args.size() > 1 else "pair_bandits", "snow", "overworld")
	if _frames == 40 and args.size() > 2 and current_scene != null and current_scene.get("battle") != null:
		var b: Object = current_scene.get("battle")
		b.call("_select", b.get("units")[0])
	if _frames == 80:
		root.get_viewport().get_texture().get_image().save_png(_out)
		quit()
	return false

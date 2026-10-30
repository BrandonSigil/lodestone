extends SceneTree
## Screenshots the fight's action layouts ([USER] 2026-10-30, three to pick from) for the desk card.
## Args after "--": <png path> <layout: cards|list> [card to point at, -1 none] [map, default highland]. For the real frame, use explore_shot.gd cards:...
## Run it windowed through tools/godot.sh. Never writes the save.

var _frames := 0
var _out := ""
var _layout := "bar"
var _hover := -1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	_layout = args[1] if args.size() > 1 else "bar"
	_hover = int(args[2]) if args.size() > 2 else -1
	var game := root.get_node("Game")
	game.set("save_enabled", false)
	game.set("sandbox_map", "res://data/maps/%s.json" % (args[3] if args.size() > 3 else "highland"))
	change_scene_to_file("res://scenes/battle_view.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	var battle = current_scene.get("battle") if current_scene else null  # untyped: compiles before the game classes
	if _frames == 6 and battle:
		battle.set_layout(_layout)
		var best = null
		for u in battle.units:  # the party piece with the most to show
			if u.team == 0 and (best == null or u.abilities.size() > best.abilities.size()):
				best = u
		battle._select(best)
	if _frames == 14 and battle and _hover >= 0:
		var slots: Array = battle._hud._slots
		if _hover < slots.size():
			slots[_hover].grab_focus()
	if _frames == 30:
		root.get_viewport().get_texture().get_image().save_png(_out)
		quit()
	return false

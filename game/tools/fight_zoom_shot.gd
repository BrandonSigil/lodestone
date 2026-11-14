extends SceneTree
## A fight's opening view as a PNG, to check how close the fight camera frames it (backlog P22).
## Args after "--": <png path> <road|map> <art set for road ("" = the old 10x8 trail island) or map name for map>
##   [seed, default 7] [encounter, default pair_wolves] [steps, comma list]
## road: a road fight through combat.tscn with the leader and the dog (as in play). map: data/maps/<name>.json in the
## battle view (the map maker's Play test). Steps, run in order before the shot: "end" ends the player turn (the enemy
## moves, the camera follows it), "zin" / "zout" wheel the zoom one notch, "pan" holds the right arrow for a moment.
## Windowed: tools/godot.sh.

var _frames := 0
var _args: PackedStringArray
var _steps: Array = []
var _wait := 0


func _initialize() -> void:
	_args = OS.get_cmdline_user_args()
	var game := root.get_node("Game")
	game.set("save_enabled", false)  # a shot never writes the real save
	root.get_node("Db").call("reload")
	_steps = Array(_args[5].split(",", false)) if _args.size() > 5 else []
	(game.get("meta").flags as Array).append("hint_fight")  # the first-fight card would cover the left of the view
	if _args[1] == "map":
		game.set("sandbox_map", "res://data/maps/%s.json" % _args[2])
		change_scene_to_file("res://scenes/battle_view.tscn")
		return
	(game.get("meta").flags as Array).append("met_dog")
	game.call("ensure_run")
	game.set("_combat_setup", {"encounter": _args[4] if _args.size() > 4 else "pair_wolves",
		"seed": int(_args[3]) if _args.size() > 3 else 7, "strangeness": 0.0, "art_set": _args[2]})
	change_scene_to_file("res://scenes/combat.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 60:
		return false
	if _wait > 0:
		_wait -= 1
		return false
	var b: Object = current_scene.get("battle") if current_scene != null else null
	if not _steps.is_empty() and b != null:
		var s: String = _steps.pop_front()
		match s:
			"end":
				b.call("end_player_phase")
				_wait = 360
			"zin", "zout":
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_WHEEL_UP if s == "zin" else MOUSE_BUTTON_WHEEL_DOWN
				ev.pressed = true
				ev.position = root.get_visible_rect().size * 0.5
				root.push_input(ev)
				_wait = 30
			"pan":
				b.get("cam").call("nudge", Vector2(1, 0), 0.6)
				_wait = 60
		return false
	if b != null:
		var bd: Node2D = b.get("board")
		print("FIGHT_ZOOM %s scale %.3f grid %dx%d" % [_args[0].get_file(), bd.scale.x, b.get("grid").get("w"), b.get("grid").get("h")])
	root.get_viewport().get_texture().get_image().save_png(_args[0])
	quit()
	return false

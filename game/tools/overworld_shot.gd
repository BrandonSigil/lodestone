extends SceneTree
## Drives the overworld into a state and saves a PNG. Args after "--": <png path> <step>.
## Steps: camp (walking to the pass with a stew in the pack, MAKE CAMP open), carry (the party panel after fights:
## the book hero's mana and the dog's charges half spent), carry_camp (the same with MAKE CAMP open: rest and tonic).

var _frames := 0
var _out := ""
var _step := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	_step = args[1] if args.size() > 1 else "camp"
	root.get_node("Game").set("save_enabled", false)  # a shot never writes the real save
	change_scene_to_file("res://scenes/overworld.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	var s := current_scene
	if _frames == 5 and _step == "camp":
		var game: Node = root.get_node("Game")
		game.get("run").call("add_item", "meal_stew", 1)
		s.call("_start_leg", "pass")
		game.get("travel")["t"] = 12.0
		s.call("_side")
		s.call("make_camp")
	if _frames == 5 and _step.begins_with("carry"):
		var game: Node = root.get_node("Game")
		game.call("take_weapon", "book")
		game.get("meta")["flags"].append("met_dog")
		game.call("refresh_party")
		var run: Object = game.get("run")
		run.call("add_item", "tonic", 1)
		run.set("food", 30)
		var members: Array = run.get("members")
		for m: Dictionary in members:
			var id := String((m["def"] as Resource).get("id"))
			m["res"] = 4 if id == "lead" else 1
		s.call("_start_leg", "pass")
		game.get("travel")["t"] = 12.0
		s.call("_side")
		if _step == "carry_camp":
			s.call("make_camp")
	if _frames == 30:
		root.get_viewport().get_texture().get_image().save_png(_out)
		quit()
	return false

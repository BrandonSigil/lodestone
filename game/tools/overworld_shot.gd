extends SceneTree
## Drives the overworld into a state and saves a PNG. Args after "--": <png path> <step>.
## Steps: camp (walking to the pass with a stew in the pack, at nightfall: the campfire), carry (the party panel after fights:
## the book hero's mana and the dog's charges half spent), carry_camp (the same at the campfire),
## pack (I pressed: the inventory page, the dog along), map (the hex world map at home, nothing open), walk (halfway
## along the leg to forest roads), arrive (at forest roads), night (the campfire: the dog along, the hero
## hurt, meat, a ration, a fish and a stew in the pack), hungry (one portion for two: the pot's hunger warning).
## Campsites (option C; the steps above use EVERY NIGHT): site_map (at home: the tents on the roads out), site_ask
## (walking to the pass: the river camp asks CAMP HERE or WALK ON), site_camp (the hilltop camp's evening), site_dark
## (night falls on the road: the rough camp).

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
	if _frames == 3:  # the old steps show the camp every night (option A); site_* the campsites (option C)
		var meta: Dictionary = root.get_node("Game").get("meta")
		if not meta.has("settings"):
			meta["settings"] = {}
		meta.settings["camp_style"] = "sites" if _step.begins_with("site") else "nightly"
	if _frames == 5 and _step.begins_with("site"):
		var game: Node = root.get_node("Game")
		game.get("meta")["flags"].append("met_dog")
		game.call("refresh_party")
		var run: Object = game.get("run")
		run.call("add_item", "rod", 1)
		run.call("add_item", "ration", 2)
		match _step:
			"site_ask":
				s.call("_start_leg", "pass")
				game.get("travel")["stops"] = []
				s.call("_advance_to", 20.0)  # the river camp, a quarter of the way
			"site_camp":
				s.call("_start_leg", "pass")
				game.get("travel")["stops"] = []
				game.get("travel")["t"] = 20.0
				s.call("_night", Callable(), (root.get_node("Db").get("campsites") as Dictionary).hill)
			"site_dark":
				s.call("_start_leg", "pass")
				game.get("travel")["stops"] = []
				game.get("travel")["passed"] = [0, 1, 2]
				game.get("travel")["since"] = 25.0
				s.call("_advance_to", 40.0)  # the light runs out on the road
			_:
				s.call("_side")
	if _frames == 5 and _step == "camp":
		var game: Node = root.get_node("Game")
		game.get("run").call("add_item", "meal_stew", 1)
		s.call("_start_leg", "pass")
		game.get("travel")["t"] = 12.0
		s.call("_side")
		game.get("travel")["stops"] = []
		s.call("_advance_to", 30.5)  # nightfall: the campfire
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
			game.get("travel")["stops"] = []
			s.call("_advance_to", 30.5)  # nightfall: the campfire
	if _frames == 5 and _step == "night":
		var game: Node = root.get_node("Game")
		game.get("meta")["flags"].append("met_dog")
		game.call("refresh_party")
		var run: Object = game.get("run")
		run.set("food", 6)
		run.call("add_item", "ration", 1)
		run.call("add_item", "fish_good", 1)
		run.call("add_item", "meal_stew", 1)
		var members: Array = run.get("members")
		members[0]["hp"] = 7
		s.call("_start_leg", "pass")
		game.get("travel")["stops"] = []
		game.get("travel")["t"] = 29.0
		s.call("_advance_to", 30.5)
	if _frames == 20 and _step == "night_evening":  # the campfire after a hunt and a cook
		var camp: Node = s.get("_camp")
		camp.call("_do", "hunt")
		camp.call("_do", "cook")
	if _frames == 5 and _step == "night_evening":
		_step_night(s)
	if _frames == 5 and _step == "hungry":  # morale is hunger: one ration for a party of two, past the free nights
		var game: Node = root.get_node("Game")
		game.get("meta")["flags"].append("met_dog")
		game.get("meta")["trips"] = 5
		game.call("refresh_party")
		var run: Object = game.get("run")
		run.set("food", 1)
		game.get("meta")["morale"]["dog"] = 0  # the dog Spent: the SPENT tag on his row
		s.call("_start_leg", "pass")
		game.get("travel")["stops"] = []
		game.get("travel")["t"] = 29.0
		s.call("_advance_to", 30.5)
	if _frames == 5 and _step == "arrive":
		root.get_node("Game").get("run").set("food", 20)  # the camp meals on the way
		s.call("_start_leg", "forest_roads")
		root.get_node("Game").get("travel")["stops"] = []
		s.call("fast_forward")
	if _frames == 5 and _step == "walk":
		s.call("_start_leg", "forest_roads")
		root.get_node("Game").get("travel")["t"] = 30.0
		s.call("_side")
	if _frames == 5 and _step == "pack":
		var game: Node = root.get_node("Game")
		game.get("meta")["flags"].append("met_dog")
		game.call("refresh_party")
		game.get("run").set("food", 24)
		var k := InputEventKey.new()
		k.keycode = KEY_I
		k.pressed = true
		Input.parse_input_event(k)
	if _frames == 30:
		root.get_viewport().get_texture().get_image().save_png(_out)
		quit()
	return false


## The night step's state, shared by night_evening.
func _step_night(s: Node) -> void:
	var game: Node = root.get_node("Game")
	game.get("meta")["flags"].append("met_dog")
	game.call("refresh_party")
	var run: Object = game.get("run")
	run.call("add_item", "ration", 1)
	run.call("add_item", "fish_good", 1)
	run.call("add_item", "rod", 1)
	var members: Array = run.get("members")
	members[0]["hp"] = 7
	s.call("_start_leg", "pass")
	game.get("travel")["stops"] = []
	game.get("travel")["t"] = 29.0
	s.call("_advance_to", 30.5)

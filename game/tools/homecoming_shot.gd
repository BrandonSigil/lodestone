extends SceneTree
## Saves the homecoming page over the village square to a PNG ([USER] Pitch J). The page's numbers are a made-up
## trip so every section shows. Args after "--": <png path> <fell|home>.
## Run: xvfb-run tools/godot.sh --path game -s res://tools/homecoming_shot.gd -- /tmp/hc.png fell

var _frames := 0
var _out := ""
var _fell := true
var _full := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://homecoming.png"
	_fell = args.size() < 2 or args[1] == "fell"
	_full = args.size() > 1 and args[1] == "full"


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		var g: Node = root.get_node("Game")
		g.save_enabled = false
		g.meta = g._fresh_meta()
		g.meta.flags = ["settler_smith", "met_dog"]
		g.meta.materials = {"metal": 2, "wood": 1}
		if not _fell:
			g.meta.restore = {"smithy_1": {"state": "done", "trip": 1}}  # it just finished: the goal moves on
		g.homecoming = {"fell": _fell,
			"headline": "WAKE UP IN SQUARE. ALL STUFF HERE. lorem." if _fell else "GLOW ROCK PULL. HOME AGAIN. lorem.",
			"materials": {"metal": 2, "wood": 1, "herb": 3},
			"levels": [{"id": "lead", "from": 2, "to": 3, "xp": 140, "xp_now": 40, "xp_per": 100},
				{"id": "dog", "from": 2, "to": 2, "xp": 60, "xp_now": 85, "xp_per": 100}],
			"bonds": [{"key": "dog+lead", "from": 8, "to": 11}],
			"days": 6,
			"morale": [{"id": "lead", "from": 62, "to": 47}, {"id": "dog", "from": 70, "to": 82}],
			"cards": ["lich"] if _fell else [],
			"knowledge": {"got": 1, "beaten": 2} if not _fell else {"got": 1},
			"restored": ["smithy_1"] if not _fell else []}
		if _full:  # the round 2 mockup C's case: four in the party, more than four hearts moved
			g.homecoming.materials = {"meat": 3, "potion": 3, "rope": 3, "wood": 3, "metal": 3, "herb": 3}
			g.homecoming.levels = [{"id": "lead", "from": 2, "to": 3, "xp": 130, "xp_now": 30, "xp_per": 100},
				{"id": "dog", "from": 3, "to": 3, "xp": 130, "xp_now": 60, "xp_per": 100},
				{"id": "fire_mage", "from": 3, "to": 3, "xp": 130, "xp_now": 72, "xp_per": 100},
				{"id": "lich_prince", "from": 3, "to": 3, "xp": 130, "xp_now": 45, "xp_per": 100}]
			g.homecoming.morale = [{"id": "lead", "from": 50, "to": 56}, {"id": "dog", "from": 60, "to": 66},
				{"id": "fire_mage", "from": 40, "to": 46}, {"id": "lich_prince", "from": 30, "to": 36}, {"id": "bushberry", "from": 50, "to": 53}]
			g.homecoming.bonds = [{"key": "dog+lead", "from": 8, "to": 11}]
			g.homecoming.knowledge = {}
			g.homecoming.restored = []
		if _full:
			for id in ["fire_mage", "lich_prince"]:  # met and along (the gate picker's playtest join)
				var d: Resource = root.get_node("Db").character(StringName(id))
				g.set_flag(d.unlock)
				g.invite(id)
		g.explore_map = "village"
		g.explore_entry = g.SQUARE
		change_scene_to_file("res://scenes/explore.tscn")
	if _frames < 40:
		return false
	root.get_viewport().get_texture().get_image().save_png(_out)
	print("saved ", _out)
	return true

extends SceneTree
## Saves the homecoming page over the village square to a PNG ([USER] Pitch J). The page's numbers are a made-up
## trip so every section shows. Args after "--": <png path> <fell|home>.
## Run: xvfb-run tools/godot.sh --path game -s res://tools/homecoming_shot.gd -- /tmp/hc.png fell

var _frames := 0
var _out := ""
var _fell := true


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://homecoming.png"
	_fell = args.size() < 2 or args[1] == "fell"


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
		g.explore_map = "village"
		g.explore_entry = g.SQUARE
		change_scene_to_file("res://scenes/explore.tscn")
	if _frames < 40:
		return false
	root.get_viewport().get_texture().get_image().save_png(_out)
	print("saved ", _out)
	return true

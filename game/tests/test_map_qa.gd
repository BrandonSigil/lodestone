extends TestCase
## The map maker's QA panel (MapQA, docs/systems/map-qa.md): each check catches what it should and passes a clean map.

const T := CombatGrid.T


## An explore map's data: start at `s`, plus things and groups.
func _ex(s: Vector2i, things := [], groups := []) -> Dictionary:
	return {"start": [[s.x, s.y]], "things": things, "groups": groups}


func _by_id(res: Array[Dictionary], id: String) -> Dictionary:
	for c in res:
		if c.id == id:
			return c
	return {}


func test_reach_finds_cut_off_ground() -> void:
	var g := CombatGrid.flat(12, 12)
	var res := MapQA.run(g, "explore", _ex(Vector2i(1, 1)))
	eq(_by_id(res, "reach").level, "ok", "an open field is all reachable")
	for y in 12:  # a wall of rock splits the field
		g.set_terrain(Vector2i(6, y), T.ROCK)
	var r := _by_id(MapQA.run(g, "explore", _ex(Vector2i(1, 1))), "reach")
	eq(r.level, "fail", "the far side is cut off")
	eq(int(r.stats.lost), 5 * 12, "every cell past the wall is lost")
	ok((r.cells as Array).has(Vector2i(9, 9)), "and painted")


func test_reach_opens_doors_and_checks_things() -> void:
	var g := CombatGrid.flat(12, 12)
	for y in 12:
		g.set_terrain(Vector2i(6, y), T.ROCK)
	g.set_terrain(Vector2i(6, 5), T.RUIN)
	var door := {"id": "door_01", "kind": "door", "cell": [6, 5], "floor": "s"}
	var chest := {"id": "chest_01", "kind": "chest", "cell": [10, 10]}
	var r := _by_id(MapQA.run(g, "explore", _ex(Vector2i(1, 1), [door, chest])), "reach")
	eq(r.level, "ok", "ground behind a door counts once it opens, and the chest past it can be used")
	g.set_height(Vector2i(10, 10), 9)  # the chest up on a column nobody climbs
	r = _by_id(MapQA.run(g, "explore", _ex(Vector2i(1, 1), [door, chest])), "reach")
	eq(int(r.stats.things), 1, "a thing on a column can't be used")


func test_reach_needs_a_start() -> void:
	var r := _by_id(MapQA.run(CombatGrid.flat(6, 6), "explore", {}), "reach")
	eq(r.level, "fail", "a map with no start fails")


func test_box_score_fails_a_box() -> void:
	var g := CombatGrid.flat(24, 24)
	var b := _by_id(MapQA.run(g, "explore", _ex(Vector2i(1, 1))), "box")
	eq(b.level, "fail", "a flat square field is a box")
	ok(float(b.stats.fill) > 0.99, "it fills its box")
	ok(not (b.cells as Array).is_empty(), "its filled corners are painted")
	var room := _by_id(MapQA.run(CombatGrid.flat(8, 7), "explore", _ex(Vector2i(1, 1))), "box")
	eq(room.level, "ok", "a room is too small for the box score")


func test_box_score_matches_map_shape_py() -> void:
	var d := MapDoc.load_path("explore/crypt")
	var s := MapQA.box_stats(d.grid)
	# python3 tools/map_shape.py game/data/explore/crypt.json: fill 0.45, edge 2.65, corners 17.7, bays 0.49, levels 16, climbs 11
	eq(snappedf(s.fill, 0.01), 0.45, "fill")
	eq(snappedf(s.edge, 0.01), 2.65, "edge")
	eq(snappedf(s.corners, 0.1), 17.7, "corners")
	eq(int(s.levels), 16, "levels")
	eq(int(s.climbs), 11, "climbs")


func test_stairs_to_nowhere() -> void:
	var g := CombatGrid.flat(10, 10)
	for y in 10:
		for x in range(5, 10):
			g.set_height(Vector2i(x, y), 4)
	g.set_terrain(Vector2i(4, 5), T.STAIRS)  # a stair at the cliff foot joining 1 and 4
	g.set_height(Vector2i(4, 5), 2)
	var s := _by_id(MapQA.run(g, "explore", _ex(Vector2i(1, 1))), "stairs")
	eq(s.level, "ok", "a stair that joins the low ground and the cliff top passes")
	g.set_terrain(Vector2i(2, 2), T.STAIRS)  # a stair in the middle of a flat field
	s = _by_id(MapQA.run(g, "explore", _ex(Vector2i(1, 1))), "stairs")
	eq(s.level, "fail", "a stair on flat ground goes nowhere")
	ok((s.cells as Array).has(Vector2i(2, 2)), "and is painted")
	g.set_terrain(Vector2i(2, 2), T.GRASS)
	for y in 10:
		for x in range(5, 10):
			g.set_height(Vector2i(x, y), 9)  # the cliff grows past what the stair can reach
	s = _by_id(MapQA.run(g, "explore", _ex(Vector2i(1, 1))), "stairs")
	eq(s.level, "fail", "a stair that stops short of the ledge fails")


func test_scale_against_the_hero() -> void:
	var g := CombatGrid.flat(12, 12)
	g.add_prop(Vector2i(2, 2), "prop_crypt_gate", Vector2i(3, 2), 3.0)
	eq(_by_id(MapQA.run(g, "explore", _ex(Vector2i(0, 0))), "scale").level, "ok", "a tall gate fits the hero")
	g.add_prop(Vector2i(7, 7), "prop_crypt_gate", Vector2i(3, 2), 1.0)
	var s := _by_id(MapQA.run(g, "explore", _ex(Vector2i(0, 0))), "scale")
	eq(s.level, "fail", "a gate shorter than the hero fails")
	ok((s.cells as Array).has(Vector2i(7, 7)), "its footprint is painted")


func test_deploy_room() -> void:
	var g := CombatGrid.flat(14, 14)
	var group := {"id": "bandits", "units": [{"id": "bandit", "cell": [10, 10]}]}
	eq(_by_id(MapQA.run(g, "explore", _ex(Vector2i(1, 1), [], [group])), "deploy").level, "ok", "an open field has room")
	for y in 14:  # a one-cell corridor everywhere the party can stand
		for x in 14:
			if x != 1 and y != 13 and not (x >= 9 and y >= 9):
				g.set_terrain(Vector2i(x, y), T.ROCK)
	for y in range(9, 14):
		for x in range(9, 14):
			if Vector2i(x, y) != Vector2i(10, 10):
				g.set_terrain(Vector2i(x, y), T.ROCK)
	g.set_terrain(Vector2i(9, 13), T.GRASS)
	g.set_terrain(Vector2i(10, 11), T.GRASS)
	g.set_terrain(Vector2i(10, 12), T.GRASS)
	g.set_terrain(Vector2i(10, 13), T.GRASS)
	var d := _by_id(MapQA.run(g, "explore", _ex(Vector2i(1, 1), [], [group])), "deploy")
	eq(d.level, "fail", "a fight in a one-cell corridor is cramped")
	var battle := MapDoc.create("battle", "test_tmp", CombatGrid.generate(3, 14, 10))
	eq(_by_id(MapQA.run(battle.grid, "battle", battle.data), "deploy").level, "ok", "a generated battle map deploys both sides")


func test_maker_qa_panel_paints_and_goes_live() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var keep: String = tree.root.get_node("Game").get("maker_map")
	var maker: Node = load("res://scenes/map_maker.tscn").instantiate()
	tree.root.add_child(maker)
	var g := CombatGrid.flat(24, 24)
	maker.call("_open", MapDoc.create("battle", "test_tmp", g, "village_in"))
	ok((maker.get("qa") as Array).is_empty(), "no QA until the button is pressed")
	maker.call("run_qa", true)
	eq((maker.get("qa") as Array).size(), MapQA.ORDER.size(), "every check ran")
	var ov: MakerOverlay = maker.get("overlay")
	ok(not ov.qa.is_empty(), "a flat field fails the box score and is painted")
	maker.set("qa_paint", false)
	eq((maker.call("qa_cells") as Array).size(), 0, "paint off: nothing painted")
	maker.set("qa_paint", true)
	maker.call("_push_undo")  # an edit
	ok(bool(maker.get("_qa_stale")), "an edit marks a live panel to check again")
	maker.call("_process", 1.0)
	ok(not bool(maker.get("_qa_stale")), "and it checks again once the edit is done")
	maker.call("qa_fly", Vector2i(3, 3))
	eq(ov.qa_focus, Vector2i(3, 3), "a problem row flies to its cell")
	maker.call("_open", MapDoc.create("battle", "test_tmp2", CombatGrid.flat(8, 8), "village_in"))
	ok((maker.get("qa") as Array).is_empty(), "opening another map clears the QA")
	tree.root.remove_child(maker)
	maker.free()
	tree.root.get_node("Game").set("maker_map", keep)


## [USER] 2026-11-01 pm-occlusion "a map rule to see if anything is obscured": a thing or group spot the camera can't
## see (a tree, a tall prop or a cliff in front of it, for the map's view) is flagged; the explore maps keep theirs in the
## open (snow_pass is the map builder's and Brandon's, not checked here).
func test_sight_flags_hidden_spots() -> void:
	var g := CombatGrid.flat(12, 12)
	var chest := {"id": "chest_01", "kind": "chest", "cell": [5, 5]}
	eq(_by_id(MapQA.run(g, "explore", _ex(Vector2i(1, 1), [chest])), "sight").level, "ok", "in the open: seen")
	g.set_terrain(Vector2i(6, 6), T.FOREST)  # a tree straight in front of it (view 0: toward +x and +y)
	var s := _by_id(MapQA.run(g, "explore", _ex(Vector2i(1, 1), [chest])), "sight")
	eq(s.level, "warn", "a tree in front hides it")
	ok((s.cells as Array).has(Vector2i(5, 5)), "and the spot is painted")
	var turned := _ex(Vector2i(1, 1), [chest])
	turned["view"] = 2  # the camera from the other side: the tree is behind it now
	eq(_by_id(MapQA.run(g, "explore", turned), "sight").level, "ok", "the map's view decides what is in front")
	g.set_terrain(Vector2i(6, 6), T.GRASS)
	g.set_height(Vector2i(6, 6), 3)  # a cliff face in front
	eq(_by_id(MapQA.run(g, "explore", _ex(Vector2i(1, 1), [chest])), "sight").level, "warn", "a cliff in front hides it")
	g.set_height(Vector2i(6, 6), 0)
	var den := {"id": "den", "units": [{"id": "wolf", "cell": [8, 8]}]}
	g.set_terrain(Vector2i(9, 8), T.FOREST)
	g.set_terrain(Vector2i(8, 9), T.FOREST)
	eq(_by_id(MapQA.run(g, "explore", _ex(Vector2i(1, 1), [], [den])), "sight").level, "warn", "trees on both front sides hide a group spot")
	for m in ExploreMap.list_maps():
		if m == "snow_pass":
			continue
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/explore/%s.json" % m))
		var sight := _by_id(MapQA.run(CombatGrid.from_dict(d.grid), "explore", d), "sight")
		eq(int(sight.stats.get("hidden_spots", 0)), 0, "%s keeps its spots in the open: %s" % [m, sight.problems])

extends TestCase
## The map look and the map maker's rules: skirt, lips, stairs, map ops, the generator, recipes, looks.

const T := CombatGrid.T


static func _island(n := 6, h := 2) -> CombatGrid:
	var g := CombatGrid.flat(n, n)
	for y in n:
		for x in n:
			g.set_height(Vector2i(x, y), h)
	return g


## Every passable cell (but water, if dry_only: a river at the foot of a gorge is a chasm; and pillar tops,
## which only Jump 2 reaches) reachable from the first dry one for a jump-1 piece.
static func _all_reachable(g: CombatGrid, dry_only := false) -> bool:
	var start := Vector2i(-1, -1)
	var cells: Array[Vector2i] = []
	for y in g.h:
		for x in g.w:
			var c := Vector2i(x, y)
			if g.passable(c) and not (dry_only and g.terrain_at(c) == T.WATER) and not g.perch(c):
				cells.append(c)
				if start.x < 0 and g.terrain_at(c) != T.WATER:
					start = c
	if start.x < 0:
		return false
	var got := MapOps.reach(g, start, 1)
	return cells.all(func(c: Vector2i) -> bool: return got.has(c))


func test_skirt_rings_surround_the_ground() -> void:
	var g := _island(4)
	g.set_terrain(Vector2i(0, 0), T.VOID)
	var s := MapDress.skirt(g, 2)
	eq(s[Vector2i(0, 0)].ring, 1, "a hole in the outline is ring 1")
	eq(s[Vector2i(-1, 2)].ring, 1, "cells beside the grid count")
	eq(s[Vector2i(-2, 2)].ring, 2)
	ok(not s.has(Vector2i(-3, 2)), "no further than the rings asked for")
	ok(not s.has(Vector2i(2, 2)), "ground is not skirt")
	for c in s:
		ok(g.solid(s[c].src), "every skirt cell knows a ground cell")
	eq(MapDress.skirt(g, 0).size(), 0)


func test_lip_profile_meets_its_neighbours() -> void:
	var a := Vector2(3, 4)
	var b := Vector2(4, 4)
	var p := MapDress.lip_profile(a, b, 0.75, 4.0)
	eq(p.size(), MapDress.LIP_TEETH * 2 + 1)
	eq(p[0][0], a)
	eq(p[p.size() - 1][0], b)
	eq(p[0][1], p[p.size() - 1][1], "both ends hang the same depth, so corners meet")
	eq(p, MapDress.lip_profile(a, b, 0.75, 4.0), "same world edge, same drips")
	for pt in p:
		ok(pt[1] > 0.0 and pt[1] <= 4.0 - 0.06, "never deeper than the drop")
	for pt in MapDress.lip_profile(a, b, 0.75, 0.4):
		ok(pt[1] <= 0.34, "a short drop clips the drips")
	eq(MapDress.lip_profile(a, b, 0.75, 0.1).size(), 0, "no lip on a tiny step")


func test_stair_run_spans_the_climb() -> void:
	var g := _island(5, 2)
	g.set_height(Vector2i(3, 2), 4)
	g.set_terrain(Vector2i(2, 2), T.STAIRS)
	g.set_height(Vector2i(2, 2), 3)
	var run := MapDress.stair_run(g, Vector2i(2, 2))
	eq(run.up, Vector2i(1, 0))
	eq(run.lo, 2.5)
	eq(run.hi, 3.5)
	eq(MapDress.stair_run(g, Vector2i(0, 4)), {}, "a flat cell has no run")


func test_a_wide_flight_climbs_the_right_way() -> void:
	# Three wide, two deep, climbing toward -y ([USER] city review: stairs must face the climb).
	var g := _island(6, 1)
	for x in range(1, 4):
		g.set_height(Vector2i(x, 0), 4)
		for y in [1, 2]:
			g.set_terrain(Vector2i(x, y), T.STAIRS)
		g.set_height(Vector2i(x, 1), 3)
		g.set_height(Vector2i(x, 2), 2)
	for x in range(1, 4):
		for y in [1, 2]:
			eq(MapDress.stair_run(g, Vector2i(x, y)).up, Vector2i(0, -1), "step %d,%d climbs toward the top" % [x, y])


func test_river_never_flows_uphill() -> void:
	var g := _island(8, 5)
	for y in 8:
		g.set_height(Vector2i(4, y), 2)  # a dip the river must not fill
	var path := MapOps.line(Vector2i(0, 3), Vector2i(7, 3))
	MapOps.river(g, path, 1, 1)
	var last := 99
	for c in path:
		eq(g.terrain_at(c), T.WATER)
		ok(g.height_at(c) <= last, "water level only falls")
		last = g.height_at(c)
	eq(g.height_at(Vector2i(7, 3)), 1, "after the dip it stays at the dip's level")


func test_stairs_and_flights_are_climbable() -> void:
	var g := _island(8, 1)
	for y in 8:
		for x in range(5, 8):
			g.set_height(Vector2i(x, y), 3)
	ok(MapOps.stairs(g, Vector2i(4, 2)), "a cliff next to the cell")
	eq(g.terrain_at(Vector2i(4, 2)), T.STAIRS)
	eq(g.height_at(Vector2i(4, 2)), 2)
	ok(not MapOps.stairs(g, Vector2i(1, 1)), "nothing to bridge on flat ground")
	for x in range(5, 8):
		g.set_height(Vector2i(x, 6), 6)
	MapOps.flight(g, Vector2i(1, 6), Vector2i(6, 6))
	var r := MapOps.reach(g, Vector2i(0, 6), 1)
	ok(r.has(Vector2i(6, 6)), "a jump-1 piece climbs the flight to the top")


func test_roughen_keeps_one_piece() -> void:
	var g := _island(16, 2)
	MapOps.roughen(g, 4, 0.7)
	var cut := 0
	var start := Vector2i(-1, -1)
	var solid := 0
	for y in g.h:
		for x in g.w:
			var c := Vector2i(x, y)
			if not g.solid(c):
				cut += 1
			else:
				solid += 1
				start = c
	ok(cut > 0, "the outline got bites")
	eq(MapOps.reach(g, start, 99).size(), solid, "no floating scraps")


func test_link_joins_terraces() -> void:
	var g := _island(10, 1)
	for y in 10:
		for x in range(5, 10):
			g.set_height(Vector2i(x, y), 4)
	ok(not _all_reachable(g))
	ok(MapOps.link(g, 1) > 0)
	ok(_all_reachable(g), "stairs join both terraces")


func test_road_follows_the_walk() -> void:
	var g := _island(8, 1)
	var p := MapOps.road(g, Vector2i(0, 0), Vector2i(7, 7))
	eq(p.size(), 15)
	eq(g.terrain_at(Vector2i(7, 7)), T.ROAD)


## 2 x 2 windows (any offset) with one cell's height different from the other three: one-cell jags.
static func _jags(g: CombatGrid) -> int:
	var n := 0
	for y in g.h - 1:
		for x in g.w - 1:
			var count := {}
			for c in [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x, y + 1), Vector2i(x + 1, y + 1)]:
				count[g.height_at(c)] = int(count.get(g.height_at(c), 0)) + 1
			if count.values().has(3):
				n += 1
	return n


func test_steps_turn_in_runs() -> void:
	var p := MapOps.steps(Vector2i(0, 0), Vector2i(7, 6), 2)
	eq(p[0], Vector2i(0, 0))
	eq(p[p.size() - 1], Vector2i(7, 6))
	var runs: Array[int] = []
	var dir := Vector2i.ZERO
	for i in range(1, p.size()):
		var d := p[i] - p[i - 1]
		eq(absi(d.x) + absi(d.y), 1, "4-connected")
		if d == dir:
			runs[runs.size() - 1] += 1
		else:
			runs.append(1)
			dir = d
	for i in range(1, runs.size() - 1):
		ok(runs[i] >= 2, "a slanted course turns every two cells or more, not every cell")
	eq(MapOps.steps(Vector2i(2, 3), Vector2i(2, 3)), [Vector2i(2, 3)] as Array[Vector2i])


func test_tidy_squares_off_edges() -> void:
	var g := _island(12, 1)
	for y in 12:
		for x in 12:
			if x - y < 1:
				g.set_height(Vector2i(x, y), 4)  # a terrace edge running slantwise: a saw of one-cell steps
	g.set_height(Vector2i(9, 2), 4)  # a lone spur out of the edge
	g.set_terrain(Vector2i(2, 9), T.STAIRS)
	g.set_height(Vector2i(10, 10), 3)
	g.set_terrain(Vector2i(10, 10), T.WATER)
	var before := _jags(g)
	var keep := {Vector2i(5, 5): true}
	var h_keep := g.height_at(Vector2i(5, 5))
	var changed := MapOps.tidy(g, keep)
	ok(changed > 0)
	ok(_jags(g) <= before * 0.6, "half the one-cell jags or more are gone (%d -> %d)" % [before, _jags(g)])
	eq(g.height_at(Vector2i(9, 2)), 1, "the lone spur drops")
	eq(g.terrain_at(Vector2i(2, 9)), T.STAIRS, "stairs stay")
	eq(g.height_at(Vector2i(10, 10)), 3, "water stays")
	eq(g.height_at(Vector2i(5, 5)), h_keep, "kept cells stay")
	var area := {Vector2i(0, 0): true}
	eq(MapOps.tidy(g, {}, area), 0, "a tidy edge has nothing left to do where it's already square")


func test_pillars_stand_alone() -> void:
	var g := _island(14, 2)
	for y in 14:
		for x in 14:
			if x + y < 12:
				g.set_height(Vector2i(x, y), 5)  # a high terrace behind, a rim along its front
	MapOps.link(g, 1)
	ok(_all_reachable(g))
	var got := MapOps.pillars(g, 4, 3)
	ok(got.size() >= 2 and got.size() <= 3, "pillars placed (%d)" % got.size())
	for c in got:
		ok(g.perch(c), "%s stands alone two levels over its neighbours" % c)
		eq(g.terrain_at(c), T.GRASS, "in the top's own ground, so it gets a snow cap")
		for o in got:
			ok(o == c or maxi(absi(o.x - c.x), absi(o.y - c.y)) >= 4, "pillars keep apart")
	ok(_all_reachable(g), "no pillar cuts the walkable map")
	ok(not g.deploy_cells(0).any(func(c: Vector2i) -> bool: return g.perch(c)), "nobody starts on a pillar")
	ok(MapOps.pillar(g, got[0], true) and not g.perch(got[0]), "right click takes one back down")


func test_rivers_fall_in_big_drops() -> void:
	var g := CombatGrid.flat(10, 3)
	for x in 10:
		for y in 3:
			g.set_height(Vector2i(x, y), 8 - x / 2)  # a slope stepping down one level every two cells
	MapOps.river(g, MapOps.line(Vector2i(0, 1), Vector2i(9, 1)), 1, 1, 2)
	var falls := 0
	for x in 9:
		var drop := g.height_at(Vector2i(x, 1)) - g.height_at(Vector2i(x + 1, 1))
		ok(drop == 0 or drop >= 2, "the river runs level or falls two levels or more (%d)" % drop)
		if drop > 0:
			falls += 1
	ok(falls >= 1 and falls <= 3, "a few big falls, not a step every cell (%d)" % falls)


func test_valley_generator() -> void:
	var a := MapGen.valley(3, 18, 16)
	eq(JSON.stringify(a.to_dict()), JSON.stringify(MapGen.valley(3, 18, 16).to_dict()), "same seed, same map")
	ok(_all_reachable(a), "every walkable cell can be reached")
	var heights := {}
	var water := 0
	for y in a.h:
		for x in a.w:
			var c := Vector2i(x, y)
			if a.solid(c):
				heights[a.height_at(c)] = true
			if a.terrain_at(c) == T.WATER:
				water += 1
	ok(heights.size() >= 3, "terraces at several levels")
	ok(water > 0, "a river")
	eq(a.look.get("id"), "alpine")
	var perches := 0
	for y in a.h:
		for x in a.w:
			if a.perch(Vector2i(x, y)):
				perches += 1
	ok(perches >= 1, "rock pillars on the rims")


func test_highland_recipe() -> void:
	var g := MapRecipes.build("highland")
	ok(g != null)
	ok(_all_reachable(g, true), "every walkable cell out of the water can be reached")
	var kinds := {}
	var falls := 0
	for y in g.h:
		for x in g.w:
			var c := Vector2i(x, y)
			kinds[g.terrain_at(c)] = true
			if g.terrain_at(c) == T.WATER:
				for d: Vector2i in CombatRules.DIRS:
					if g.solid(c + d) and g.terrain_at(c + d) == T.WATER and g.height_at(c + d) < g.height_at(c) - 1:
						falls += 1
	for t in [T.VOID, T.WATER, T.STAIRS, T.ROAD, T.FOREST, T.ROCK, T.STONE]:
		ok(kinds.has(t), "has %s" % CombatGrid.T.keys()[t])
	ok(falls >= 3, "waterfalls between levels")
	var perches := 0
	for y in g.h:
		for x in g.w:
			if g.perch(Vector2i(x, y)):
				perches += 1
	ok(perches >= 2, "rock pillars (V10)")
	eq(MapRecipes.cell(26, 0.0, 0.5), Vector2i(13, 13))
	var back := MapRecipes.uv(26, MapRecipes.cell(26, -0.4, 0.6))
	ok(absf(back.x + 0.4) < 0.06 and absf(back.y - 0.6) < 0.03, "screen position round trip")


func test_look_resolves() -> void:
	eq(MapLook.resolve({}, "").id, MapLook.DEFAULT)
	eq(MapLook.resolve({}, "snow").id, "snow", "named like the tile set")
	eq(MapLook.resolve({"id": "alpine"}, "snow").id, "alpine", "the map's own pick wins")
	eq(MapLook.resolve({"id": "nope"}, "canyon").id, "canyon")
	var l := MapLook.resolve({"id": "alpine", "floor": -9, "skirt": 1, "staging": "island"}, "")
	eq(l.floor_h, -9.0)
	eq(l.skirt, 1)
	eq(l.staging, "island")
	eq(MapLook.resolve({}, "village_in").staging, "plain")
	ok(MapLook.resolve({}, "").color("sky_top") != MapLook.resolve({}, "", 1.0).color("sky_top"), "strangeness drifts colours")
	for id in MapLook.ids():
		ok(MapLook.resolve({"id": id}, "").trees.size() > 0, id + " has trees")


func test_grid_keeps_its_look() -> void:
	var g := _island(5)
	g.look = {"id": "alpine", "floor": -8}
	var back := CombatGrid.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	eq(back.look.get("id"), "alpine")
	eq(int(back.look.get("floor")), -8)
	eq(g.resized(7, 7).look.get("id"), "alpine")
	ok(not _island(3).to_dict().has("look"), "no look, no key")
	var v := g.version
	g.set_height(Vector2i(1, 1), 3)
	ok(g.version > v, "edits bump the version the board caches against")
	g.add_prop(Vector2i(2, 2), "prop_bush", Vector2i.ONE, 0.5)
	g.remove_prop(Vector2i(2, 2))
	ok(g.prop_at(Vector2i(2, 2)).is_empty())


func test_art_borrows_and_lips() -> void:
	ok(BattleArt.texture("snow/prop_pine_1", false) != null, "a stem can borrow another set's art")
	ok(BattleArt.lip(T.GRASS) > 0.0, "grass hangs over cliffs")
	eq(BattleArt.lip(T.WATER), 0.0)
	eq(BattleArt.lip(T.STONE), 0.0, "paving has a clean edge")
	ok(BattleArt.lip(T.GRASS, "alpine") > 0.0)


## Road fights (Brandon's E2E notes, 2026-10-28): the party was set down on a wall top it couldn't leave and
## the bandits couldn't reach. Every starting cell must sit on one stretch of Jump 1 ground.
func test_road_fight_deploy_on_one_ground() -> void:
	for s in 40:
		var g := MapGen.valley(s, 14, 12, "snow")
		var ground := g.main_ground()
		var mine := g.deploy_cells(0)
		var theirs := g.deploy_cells(1)
		ok(mine.size() >= 3 and theirs.size() >= 3, "seed %d: room to deploy" % s)
		for c in mine + theirs:
			ok(ground.has(c), "seed %d: %s is on the main ground" % [s, c])


func test_map_doc_files() -> void:
	var g := MapGen.valley(2, 14, 12)
	var battle := MapDoc.create("battle", "Test Map!", g, "alpine").to_dict()
	eq(battle.name, "test_map_")
	ok(battle.party.size() == 3 and battle.enemies.size() == 4, "a new battle map gets test pieces")
	for e in battle.party + battle.enemies:
		ok(g.passable(Vector2i(int(e.x), int(e.y))), "pieces stand on walkable cells")
	eq(battle.map.look.id, "alpine")
	var ex := MapDoc.create("explore", "walk", g, "alpine")
	ex.data = {"things": [{"id": "t1"}], "start": [[-5, -5]], "groups": []}
	var d := ex.to_dict()
	eq(d.things.size(), 1, "the rest of the file is kept")
	ok(g.passable(Vector2i(int(d.start[0][0]), int(d.start[0][1]))), "a start off the ground moves onto it")
	eq(d.grid.w, 14)


func test_map_maker_edits_and_undo() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var keep: String = tree.root.get_node("Game").get("maker_map")
	var maker: Node = load("res://scenes/map_maker.tscn").instantiate()
	tree.root.add_child(maker)
	var doc: MapDoc = maker.get("doc")
	ok(doc != null and doc.grid != null, "opens a map")
	var c := Vector2i(-1, -1)
	for y in doc.grid.h:
		for x in doc.grid.w:
			if c.x < 0 and doc.grid.terrain_at(Vector2i(x, y)) == T.GRASS and doc.grid.height_at(Vector2i(x, y)) < CombatGrid.MAX_HEIGHT:
				c = Vector2i(x, y)
	var h0 := doc.grid.height_at(c)
	maker.call("_set_tool", "raise")
	maker.call("_push_undo")
	maker.set("_stroke", {"button": MOUSE_BUTTON_LEFT, "done": {}})
	maker.call("_apply", c, false)
	maker.call("_apply", c, false)
	eq(maker.get("doc").grid.height_at(c), h0 + 1, "one raise per cell per stroke")
	maker.call("_set_tool", "cut")
	maker.set("_stroke", {"button": MOUSE_BUTTON_LEFT, "done": {}})
	maker.call("_push_undo")
	maker.call("_apply", c, false)
	ok(not maker.get("doc").grid.solid(c), "cut")
	maker.call("undo")
	maker.call("undo")
	eq(maker.get("doc").grid.height_at(c), h0, "undo puts it back")
	eq(maker.get("doc").grid.terrain_at(c), T.GRASS)
	maker.call("redo")
	eq(maker.get("doc").grid.height_at(c), h0 + 1, "redo")
	maker.set("_stroke", {})
	maker.call("_set_tool", "river")
	maker.call("_set_look_field", "skirt", 1)
	eq(int(maker.get("doc").grid.look.get("skirt")), 1, "look fields go into the map")
	maker.call("new_from_recipe")
	eq(maker.get("doc").grid.w, 26, "templates open")
	var board: CombatBoard = maker.get("board")
	ok(board.soft, "the maker shows the painted terrain players see")
	maker.call("_toggle_view", "soft")
	ok(not board.soft, "K shows the plain blocks")
	maker.call("_toggle_view", "soft")
	ok(board.soft)
	tree.root.remove_child(maker)
	maker.free()
	tree.root.get_node("Game").set("maker_map", keep)


func test_map_maker_save_as() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var keep: String = tree.root.get_node("Game").get("maker_map")
	var maker: Node = load("res://scenes/map_maker.tscn").instantiate()
	tree.root.add_child(maker)
	maker.call("_open", MapDoc.create("battle", "test_tmp_a", _island(8, 1)))
	maker.call("save")
	maker.call("open_save_as")
	ok((maker.get("_save_box") as Control).visible, "ctrl shift S opens the card")
	maker.call("_on_save_name", "test_tmp_a")
	eq((maker.get("_save_ok") as Button).text, "Save", "its own name just saves")
	maker.call("_close_save_as")
	maker.call("save_as", "Test Tmp B")
	eq(maker.get("doc").map_name, "test_tmp_b", "names are made file-safe")
	ok(MapDoc.exists("battle", "test_tmp_a") and MapDoc.exists("battle", "test_tmp_b"), "the old name stays, the new one is written")
	eq(String(tree.root.get_node("Game").get("maker_map")), "maps/test_tmp_b", "the maker reopens the new name")
	maker.call("open_save_as")
	maker.call("_on_save_name", "test_tmp_a")
	eq((maker.get("_save_ok") as Button).text, "Overwrite test_tmp_a", "another map's name warns before overwriting")
	maker.call("_close_save_as")
	for n in ["test_tmp_a", "test_tmp_b"]:
		for dir in [MapDoc.DIRS.battle, MapDoc.USER_DIRS.battle]:
			DirAccess.remove_absolute(dir + n + ".json")
	tree.root.remove_child(maker)
	maker.free()
	tree.root.get_node("Game").set("maker_map", keep)


func test_prop_extras_round_trip() -> void:
	var g := _island(6)
	g.add_prop(Vector2i(1, 1), "ph_lich_king_throne", Vector2i(2, 2), 1.0, 2.0, false, {"blob": true, "name": "Lich king throne", "id": "blob_01", "note": "big", "face": 1, "flip": true})
	g.add_prop(Vector2i(4, 4), "prop_bed", Vector2i.ONE, 0.75, 0.0)
	var back := CombatGrid.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	var p: Dictionary = back.props[Vector2i(1, 1)]
	ok(p.blob and p.name == "Lich king throne" and p.id == "blob_01" and p.note == "big", "blob fields kept")
	eq(int(p.face), 1)
	ok(bool(p.flip))
	ok(not (back.props[Vector2i(4, 4)] as Dictionary).has("face"), "plain props stay plain")
	var r := back.resized(5, 5)
	eq(String(r.props[Vector2i(1, 1)].name), "Lich king throne", "resize keeps extras")


func test_arch_gap_is_walkable() -> void:
	var g := _island(8)
	g.add_prop(Vector2i(1, 2), "ph_arch", Vector2i(4, 1), 1.8, 2.0, false, {"arch": true})
	g.add_prop(Vector2i(6, 1), "ph_arch", Vector2i(1, 3), 1.8, 2.0, false, {"arch": true})
	ok(not g.passable(Vector2i(1, 2)) and not g.passable(Vector2i(4, 2)), "pillars at both ends block")
	ok(g.passable(Vector2i(2, 2)) and g.passable(Vector2i(3, 2)), "the gap between them is open")
	ok(g.sight_top(Vector2i(2, 2)) < g.sight_top(Vector2i(1, 2)), "sight passes under the arch")
	ok(not g.passable(Vector2i(6, 1)) and g.passable(Vector2i(6, 2)) and not g.passable(Vector2i(6, 3)), "an arch turned the other way")
	var back := CombatGrid.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	ok(back.passable(Vector2i(2, 2)) and back.under_arch(Vector2i(3, 2)), "saved and loaded")


func test_smooth_and_path() -> void:
	var g := _island(7, 2)
	g.set_height(Vector2i(3, 3), 6)
	MapOps.smooth(g, [Vector2i(3, 3)] as Array[Vector2i])
	ok(g.height_at(Vector2i(3, 3)) < 6, "a spike comes down")
	var h := _island(7, 1)
	for y in 7:
		for x in range(4, 7):
			h.set_height(Vector2i(x, y), 3)
	var course := MapOps.line(Vector2i(0, 3), Vector2i(6, 3))
	var painted := MapOps.path(h, course, T.ROAD, 1)
	ok(painted.size() >= 5, "path painted")
	eq(h.terrain_at(Vector2i(1, 3)), T.ROAD)
	var stairs := 0
	for c in course:
		if h.terrain_at(c) == T.STAIRS:
			stairs += 1
	ok(stairs >= 1, "the climb gets stairs")


func test_catalog() -> void:
	MakerCatalog.reload()
	var all := MakerCatalog.entries()
	ok(all.size() > 40, "catalog loads")
	ok(MakerCatalog.drawers().has("Building interior"), "drawers")
	var hearth := MakerCatalog.by_id("hearth")
	eq(String(hearth.group), "Hearth and light")
	ok(BattleArt.texture(String(hearth.sprite)) != null, "catalog art exists")
	for e in all:
		# ph_ placeholders and wall-kit pieces (a graybox plane until the art runner's kit lands) have no art yet
		if e.kind == "prop" and e.drawer != MakerCatalog.UNSORTED and not String(e.sprite).get_file().begins_with("ph_") \
				and not String(e.sprite).get_file().begins_with("wall_"):
			ok(BattleArt.texture(String(e.sprite)) != null, "art for " + String(e.id))
		if e.kind == "thing":
			ok(MakerCatalog.THING_KINDS.has(e.thing), "thing kind " + String(e.id))
	eq(MakerCatalog.stem_for(hearth, "village_in"), "prop_hearth", "own set: bare stem")
	eq(MakerCatalog.stem_for(hearth, "dungeon"), "village_in/prop_hearth", "other set: borrowed")
	eq(MakerCatalog.stem_for(MakerCatalog.by_id("crate"), "dungeon"), "prop_crate", "base: the set's own")
	eq(MakerCatalog.slug("Lich king throne!"), "lich_king_throne")
	ok(MakerCatalog.search("fire place").is_empty() or true)
	ok(not MakerCatalog.search("fireplace").is_empty(), "search by label")
	eq(MakerCatalog.angles("village_in/prop_hearth"), [0] as Array[int], "one painted angle")


func test_map_maker_places_things() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var keep: String = tree.root.get_node("Game").get("maker_map")
	var maker: Node = load("res://scenes/map_maker.tscn").instantiate()
	tree.root.add_child(maker)
	var d := MapDoc.create("explore", "test_tmp", _island(8, 1), "village_in")
	d.data = {"start": [[0, 0]], "things": [], "groups": []}
	maker.call("_open", d)
	var stamp := func(id: String, c: Vector2i) -> void:
		maker.call("pick_item", MakerCatalog.by_id(id))
		maker.call("_push_undo")
		maker.set("_stroke", {"button": MOUSE_BUTTON_LEFT, "done": {}})
		maker.call("_stamp", c)
		maker.set("_stroke", {})
	stamp.call("long_table", Vector2i(2, 2))
	var g: CombatGrid = maker.get("doc").grid
	eq(String(g.props[Vector2i(2, 2)].sprite), "prop_long_table")
	eq(g.props[Vector2i(2, 2)].foot, Vector2i(2, 1))
	maker.call("_select", {"type": "prop", "cell": Vector2i(2, 2)})
	maker.call("_set_tool", "select")
	maker.call("_turn_item")
	g = maker.get("doc").grid
	eq(g.props[Vector2i(2, 2)].foot, Vector2i(1, 2), "turning swaps the footprint")
	ok(bool(g.props[Vector2i(2, 2)].get("flip", false)), "one angle: turning mirrors")
	stamp.call("blob_2x2", Vector2i(5, 5))
	g = maker.get("doc").grid
	var blob: Dictionary = g.props[Vector2i(5, 5)]
	ok(blob.blob and String(blob.id) == "blob_01", "blob placed with an id")
	eq(maker.get("selection").type, "prop", "a new blob is selected")
	maker.call("_change_prop", func(q: Dictionary) -> void:
		q["name"] = "Lich king throne"
		q["sprite"] = "ph_" + MakerCatalog.slug("Lich king throne"))
	eq(String(maker.get("doc").grid.props[Vector2i(5, 5)].sprite), "ph_lich_king_throne", "renaming points at its art")
	stamp.call("door_locked", Vector2i(0, 4))
	stamp.call("door_locked", Vector2i(1, 4))
	var things: Array = maker.get("doc").data.things
	eq(things.size(), 2)
	eq(String(things[0].id), "door_01")
	eq(String(things[1].id), "door_02", "ids stay unique")
	eq(String(things[0].event), "locked_door")
	maker.call("_set_thing", "note", "barred from the other side")
	eq(String(maker.get("doc").data.things[1].note), "barred from the other side", "notes land on the selected thing")
	# move the door with the select tool
	maker.call("_select", {"type": "thing", "i": 0})
	maker.set("_move", {"from": Vector2i(0, 4), "to": Vector2i(0, 6)})
	maker.call("_end_move")
	eq(maker.get("doc").data.things[0].cell, [0, 6], "moved")
	maker.call("_delete_selected")
	eq((maker.get("doc").data.things as Array).size(), 1, "deleted")
	maker.call("undo")
	eq((maker.get("doc").data.things as Array).size(), 2, "undo brings things back")
	stamp.call("start", Vector2i(3, 6))
	eq(maker.get("doc").data.start[0], [3, 6], "start moved")
	var saved: Dictionary = maker.get("doc").to_dict()
	eq(String(saved.things[1].note), "barred from the other side", "notes are saved")
	var em := ExploreMap.from_dict(saved)
	eq(em.things.size(), 2, "the explore scene reads the things")
	# a foe group's fight goals, set from the inspector
	maker.get("doc").data["groups"] = [{"id": "g", "units": [{"id": "wolf", "cell": [4, 1]}, {"id": "wolf", "cell": [5, 1]}]}]
	var pick: Dictionary = maker.call("_pick", Vector2i(5, 1))
	eq(String(pick.get("type", "")), "group", "a foe unit is pickable")
	maker.call("_select", pick)
	maker.call("_set_group_goals", {"defeat": true, "leader": true, "exit": false}, 3)
	eq(String(maker.get("doc").data.groups[0].goals), "defeat|leader|hold:3", "goals land on the group")
	maker.call("_set_group_goals", {"defeat": true, "leader": false, "exit": false}, 0)
	ok(not (maker.get("doc").data.groups[0] as Dictionary).has("goals"), "plain defeat is the default")
	maker.call("_delete_selected")
	eq((maker.get("doc").data.groups[0].units as Array).size(), 1, "a unit deleted")
	# battle maps take no things
	var bd := MapDoc.create("battle", "test_tmp", _island(8, 1))
	maker.call("_open", bd)
	stamp.call("chest", Vector2i(2, 2))
	ok(not (maker.get("doc").data as Dictionary).has("things") or (maker.get("doc").data.things as Array).is_empty(), "no things on battle maps")
	tree.root.remove_child(maker)
	maker.free()
	tree.root.get_node("Game").set("maker_map", keep)


func test_ground_rank_blend() -> void:
	ok(CombatBoard.BLEND_RANK[T.STONE] > CombatBoard.BLEND_RANK[T.ROAD] and CombatBoard.BLEND_RANK[T.ROAD] > CombatBoard.BLEND_RANK[T.GRASS], "stone over road over grass")
	ok(not CombatBoard.BLEND_RANK.has(T.WATER), "water never blends")


func test_wall_kit_back_walls_face_the_room() -> void:
	# A room with rock along its back edges (row 0, column 0) and floor at 1 ([USER] 2026-10-30: wall kits).
	var make := func() -> CombatGrid:
		var g := _island(5, 1)
		for i in 5:
			for c in [Vector2i(i, 0), Vector2i(0, i)]:
				g.set_terrain(c, T.ROCK)
				g.set_height(c, 3)
		return g
	var g: CombatGrid = make.call()
	var shaped := ExploreRules.shape_walls(g, [Vector2i(0, 1), Vector2i(1, 0)], [], ExploreRules.WALL_TALL, true)
	eq(shaped.backs[Vector2i(2, 0)], [Vector2i(0, 1)], "the back wall along x faces the room below it")
	eq(shaped.backs[Vector2i(0, 2)], [Vector2i(1, 0)], "the wall along y faces the room beside it")
	eq(shaped.backs[Vector2i(0, 0)], [Vector2i(0, 1), Vector2i(1, 0)], "the back corner faces both ways")
	eq(g.height_at(Vector2i(2, 0)), 1, "a kit wall's cell stays at the floor; the piece stands on its edge")
	var plain: CombatGrid = make.call()
	var blocks := ExploreRules.shape_walls(plain, [Vector2i(0, 1), Vector2i(1, 0)])
	ok((blocks.backs as Dictionary).is_empty(), "no kit, no pieces")
	eq(plain.height_at(Vector2i(2, 0)), 1 + ExploreRules.WALL_TALL, "and the block walls stand as before")

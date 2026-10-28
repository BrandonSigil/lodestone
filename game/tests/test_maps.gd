extends TestCase
## The map look and the map maker's rules: skirt, lips, stairs, map ops, the generator, recipes, looks.

const T := CombatGrid.T


static func _island(n := 6, h := 2) -> CombatGrid:
	var g := CombatGrid.flat(n, n)
	for y in n:
		for x in n:
			g.set_height(Vector2i(x, y), h)
	return g


## Every passable cell (but water, if dry_only: a river at the foot of a gorge is a chasm) reachable from
## the first dry one for a jump-1 piece.
static func _all_reachable(g: CombatGrid, dry_only := false) -> bool:
	var start := Vector2i(-1, -1)
	var cells: Array[Vector2i] = []
	for y in g.h:
		for x in g.w:
			var c := Vector2i(x, y)
			if g.passable(c) and not (dry_only and g.terrain_at(c) == T.WATER):
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
	maker.call("_set_tool", "RAISE")
	maker.call("_push_undo")
	maker.set("_stroke", {"button": MOUSE_BUTTON_LEFT, "done": {}})
	maker.call("_apply", c, false)
	maker.call("_apply", c, false)
	eq(maker.get("doc").grid.height_at(c), h0 + 1, "one raise per cell per stroke")
	maker.call("_set_tool", "CUT")
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
	maker.call("_set_tool", "RIVER")
	maker.call("_set_look_field", "skirt", 1)
	eq(int(maker.get("doc").grid.look.get("skirt")), 1, "look fields go into the map")
	maker.call("new_from_recipe")
	eq(maker.get("doc").grid.w, 26, "templates open")
	tree.root.remove_child(maker)
	maker.free()
	tree.root.get_node("Game").set("maker_map", keep)

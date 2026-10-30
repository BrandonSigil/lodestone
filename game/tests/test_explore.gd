extends TestCase
## Exploration maps: paths, fog of war, spotting, interaction options, deploying for a fight.


func _crypt() -> ExploreMap:
	return ExploreMap.load_named("crypt")


func _unit(class_id: String) -> CombatUnit:
	if Db.abilities.is_empty():
		Db.reload()
	return CombatUnit.enemy(Db.class_def(class_id))


## A walled room: open floor, a wall down the middle with one gap at y = 2.
func _room() -> CombatGrid:
	var g := CombatGrid.flat(9, 5)
	for y in 5:
		if y != 2:
			g.set_terrain(Vector2i(4, y), CombatGrid.T.ROCK)
			g.set_height(Vector2i(4, y), 3)
	return g


func test_crypt_loads_with_things_and_groups() -> void:
	var m := _crypt()
	ok(m != null, "crypt.json loads")
	eq(m.grid.w, 34, "width")
	ok(m.start.size() >= 1 and m.grid.passable(m.start[0]), "start cell is walkable")
	ok(m.groups.size() >= 3, "several enemy groups")
	ok(m.things.size() >= 5, "doors, chests and an exit")
	for g in m.groups:
		for u: Dictionary in g.units:
			ok(m.grid.passable(u.cell), "%s stands on walkable ground" % g.id)
			ok(Db.class_def(u.id) != null, "%s is a class" % u.id)


func test_events_and_text_exist() -> void:
	if Db.explore_events.is_empty():
		Db.reload()
	var m := _crypt()
	for t in m.things:
		if t.kind == "enter" and t.event == "":
			continue  # a plain doorway walks straight through
		if t.kind in ExploreRules.LASTING_KINDS:
			continue  # a lasting reward holds its reward in its event, not an event row
		ok(Db.explore_events.has(t.event), "event %s for %s" % [t.event, t.id])
	for g in m.groups:
		ok(Db.explore_events.has(g.event), "event %s for group %s" % [g.event, g.id])
	for id in Db.explore_events:
		var ev: Dictionary = Db.explore_events[id]
		ok(Txt.has(ev.text_key), "text %s" % ev.text_key)
		ok(not ev.options.is_empty(), "%s has options" % id)
		for o: Dictionary in ev.options:
			ok(Txt.has(o.key), "option text %s" % o.key)
			if o.check != "none":
				ok(Txt.has("CHECK_" + String(o.check).to_upper()), "check %s has a name" % o.check)


func test_way_out_is_reachable_once_doors_open() -> void:
	var m := _crypt()
	var exit_cell := Vector2i(-1, -1)
	for t in m.things:
		if t.kind == "exit":
			exit_cell = t.cell
	ok(ExploreRules.path_to_use(m.grid, m.start[0], exit_cell, 1).is_empty(), "shut doors and rubble block every way")
	for t in m.things:
		if t.kind == "door" or t.kind == "rubble":
			m.grid.set_terrain(t.cell, CombatGrid.T.STONE)
	var p := ExploreRules.path_to_use(m.grid, m.start[0], exit_cell, 1)
	ok(not p.is_empty(), "a jump 1 leader can walk from the yard to the way out")


func test_door_blocks_until_opened() -> void:
	var m := _crypt()
	var door: Dictionary = m.things.filter(func(t: Dictionary) -> bool: return t.id == "gate")[0]
	var g := m.grid
	g.set_terrain(door.cell, CombatGrid.T.RUIN)
	var north: Vector2i = door.cell + Vector2i(0, -1)
	var south: Vector2i = door.cell + Vector2i(0, 1)
	ok(not g.passable(door.cell), "a shut door can't be walked through")
	ok(not g.line_of_sight(south, north + Vector2i(0, -2)), "a shut door blocks sight")
	g.set_terrain(door.cell, CombatGrid.T.ROAD)
	ok(g.passable(door.cell), "an open door is floor")


func test_rooms_past_a_shut_door_stay_locked() -> void:
	var g := _room()
	var gap := Vector2i(4, 2)
	g.set_terrain(gap, CombatGrid.T.RUIN)
	var open := ExploreRules.reach(g, [Vector2i(0, 0)], 1)
	ok(open.has(Vector2i(3, 4)) and not open.has(Vector2i(5, 0)), "the party reaches only its own side")
	var locked := ExploreRules.locked_cells(g, open, [gap], 1)
	ok(locked.has(Vector2i(5, 0)) and locked.has(Vector2i(8, 4)), "the far side is locked")
	ok(not locked.has(gap), "the door itself shows")
	ok(not locked.has(Vector2i(4, 0)), "a wall that faces the party shows")
	ok(not locked.has(Vector2i(2, 2)), "the party's side never locks")
	g.set_terrain(gap, CombatGrid.T.STONE)
	open = ExploreRules.reach(g, [Vector2i(0, 0)], 1)
	ok(ExploreRules.locked_cells(g, open, [], 1).is_empty(), "nothing is locked once the door opens")


func test_crypt_chest_is_locked_until_the_door_opens() -> void:
	var m := _crypt()
	var doors: Array[Vector2i] = []
	var chest := Vector2i(-1, -1)
	for t in m.things:
		if t.kind == "door" or t.kind == "rubble":
			m.grid.set_terrain(t.cell, CombatGrid.T.RUIN)
			doors.append(t.cell)
		if t.id == "crypt_chest":
			chest = t.cell
	var open := ExploreRules.reach(m.grid, [m.start[0]], 1)
	var locked := ExploreRules.locked_cells(m.grid, open, doors, 1)
	ok(locked.has(chest), "the crypt chest sits in a locked room")
	ok(not locked.has(Vector2i(26, 18)), "the gate, facing the yard, shows")
	ok(locked.has(Vector2i(28, 15)), "the crypt door, off the corridor past the gate, is locked too")
	ok(not locked.has(m.start[0]), "the yard the party starts in is open")


func _walled(w: int, h: int, floor_cells: Callable) -> CombatGrid:
	var g := CombatGrid.flat(w, h)
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			var inside: bool = floor_cells.call(c)
			g.set_terrain(c, CombatGrid.T.STONE if inside else CombatGrid.T.ROCK)
			g.set_height(c, 1 if inside else 2)
	return g


func test_walls_tall_at_the_back_floor_with_a_rim_in_front() -> void:
	# A 3 x 3 floor at height 1 in a 7 x 7 field of rock; the camera looks from +x, +y.
	var g := _walled(7, 7, func(c: Vector2i) -> bool: return c.x >= 2 and c.x <= 4 and c.y >= 2 and c.y <= 4)
	var rims: Dictionary = ExploreRules.shape_walls(g, [Vector2i(0, 1), Vector2i(1, 0)]).rims
	eq(g.height_at(Vector2i(3, 1)), 1 + ExploreRules.WALL_TALL, "the back wall stands tall")
	eq(g.height_at(Vector2i(1, 3)), 1 + ExploreRules.WALL_TALL, "so does the other back wall")
	for c: Vector2i in [Vector2i(3, 5), Vector2i(5, 3), Vector2i(5, 5)]:
		ok(rims.has(c) and g.passable(c) and g.height_at(c) == 1, "front edge %s is walkable floor with a rim" % c)
	eq(g.terrain_at(Vector2i(0, 0)), CombatGrid.T.VOID, "rock touching no floor is not drawn")


func test_outdoor_zones_get_a_tree_line_not_walls() -> void:
	var g := _walled(7, 7, func(c: Vector2i) -> bool: return c.x >= 2 and c.x <= 4 and c.y >= 2 and c.y <= 4)
	for y in 7:
		for x in 7:
			g.set_zone(Vector2i(x, y), "forest")
	var rims: Dictionary = ExploreRules.shape_walls(g, [Vector2i(0, 1), Vector2i(1, 0)], ["forest"]).rims
	ok(rims.is_empty(), "no front-edge walls outside")
	for c: Vector2i in [Vector2i(3, 1), Vector2i(3, 5), Vector2i(0, 0)]:
		eq(g.terrain_at(c), CombatGrid.T.VOID, "edge rock %s opens onto the tree line" % c)


func test_outdoor_edge_facing_a_pocket_is_a_wall() -> void:
	# A forest yard (rows 6-7) under an interior hall (row 1) with side passages; the rock between them shuts in a
	# pocket the world's edge never reaches. The yard's back edge faces that pocket, so it is a wall.
	var g := _walled(11, 9, func(c: Vector2i) -> bool:
		return (c.y == 1 or c.y == 6 or c.y == 7 or c.x == 1 or c.x == 9) and c.x >= 1 and c.x <= 9 and c.y >= 1 and c.y <= 7)
	for y in range(5, 9):
		for x in 11:
			g.set_zone(Vector2i(x, y), "forest")
	var shaped := ExploreRules.shape_walls(g, [Vector2i(0, 1), Vector2i(1, 0)], ["forest"])
	eq(g.height_at(Vector2i(5, 5)), 1 + ExploreRules.WALL_TALL, "the yard's back edge stands tall")
	ok(shaped.walls.has(Vector2i(5, 5)), "and draws as a wall")
	eq(g.terrain_at(Vector2i(5, 8)), CombatGrid.T.VOID, "its front edge still opens onto the tree line")


func test_a_front_rim_never_joins_two_rooms() -> void:
	# Two rooms side by side, a rock wall between them, sharing the front edge.
	var g := _walled(7, 5, func(c: Vector2i) -> bool: return c.y >= 1 and c.y <= 2 and c.x != 0 and c.x != 3 and c.x != 6)
	var rims: Dictionary = ExploreRules.shape_walls(g, [Vector2i(0, 1), Vector2i(1, 0)]).rims
	ok(not rims.has(Vector2i(3, 3)), "the front row under the dividing wall stays a wall")
	ok(not g.passable(Vector2i(2, 3)) and not g.passable(Vector2i(4, 3)), "so does the rest of that row")
	ok(ExploreRules.find_path(g, Vector2i(1, 1), Vector2i(5, 1), 1).is_empty(), "the rooms stay apart")
	eq(g.height_at(Vector2i(3, 3)), 1 + ExploreRules.WALL_HALF, "a half wall")


func test_path_goes_through_the_gap() -> void:
	var g := _room()
	var p := ExploreRules.find_path(g, Vector2i(0, 0), Vector2i(8, 0), 1)
	ok(not p.is_empty(), "there is a way round")
	ok(p.has(Vector2i(4, 2)), "it uses the gap")
	eq(p[0], Vector2i(0, 0), "starts where the leader stands")
	eq(p.back(), Vector2i(8, 0), "ends at the click")
	var blocked := {Vector2i(4, 2): true}
	ok(ExploreRules.find_path(g, Vector2i(0, 0), Vector2i(8, 0), 1, blocked).is_empty(), "an enemy in the gap closes it")


func test_path_only_through_known_cells() -> void:
	var g := _room()
	var known := {}
	for x in 4:
		for y in 5:
			known[Vector2i(x, y)] = true
	ok(ExploreRules.find_path(g, Vector2i(0, 0), Vector2i(8, 0), 1, {}, known).is_empty(), "no walking into the unknown")


func test_fog_stops_at_walls() -> void:
	var g := _room()
	var seen := ExploreRules.sight(g, [Vector2i(1, 0)], 7)
	ok(seen.has(Vector2i(3, 0)), "sees its own side")
	ok(seen.has(Vector2i(4, 0)), "sees the wall itself")
	ok(not seen.has(Vector2i(6, 0)), "can't see behind the wall")
	var far := ExploreRules.sight(CombatGrid.flat(20, 3), [Vector2i(0, 1)], 7)
	ok(far.has(Vector2i(7, 1)) and not far.has(Vector2i(9, 1)), "sight has a range")


func test_spotting_needs_range_and_sight() -> void:
	var g := _room()
	ok(ExploreRules.sees(g, [Vector2i(0, 2)], [Vector2i(3, 2)], 4), "in range, clear line")
	ok(not ExploreRules.sees(g, [Vector2i(0, 0)], [Vector2i(6, 0)], 8), "wall in the way")
	ok(not ExploreRules.sees(g, [Vector2i(0, 2)], [Vector2i(8, 2)], 4), "too far")


func test_use_needs_to_stand_next_to_it() -> void:
	var g := CombatGrid.flat(6, 6)
	ok(ExploreRules.can_use_from(g, Vector2i(2, 2), Vector2i(3, 3)), "diagonal counts")
	ok(not ExploreRules.can_use_from(g, Vector2i(1, 1), Vector2i(3, 3)), "two away doesn't")
	g.set_height(Vector2i(3, 3), 4)
	ok(not ExploreRules.can_use_from(g, Vector2i(2, 2), Vector2i(3, 3)), "not up a cliff")
	var p := ExploreRules.path_to_use(CombatGrid.flat(6, 6), Vector2i(0, 0), Vector2i(4, 0), 1)
	eq(p.back(), Vector2i(3, 0), "walks up next to it")


func test_options_depend_on_the_party() -> void:
	if Db.explore_events.is_empty():
		Db.reload()
	var ev: Dictionary = Db.explore_events["locked_door"]
	var lead: CharacterDef = load("res://data/characters/lead.tres")
	var hunter: CharacterDef = load("res://data/characters/hunter.tres")
	var star: CharacterDef = load("res://data/characters/stardrop.tres")
	var keys := func(defs: Array) -> Array:
		return ExploreRules.options_for(ev, defs).map(func(o: Dictionary) -> String: return o.key)
	ok(not keys.call([lead]).has("OPT_PICK_LOCK"), "no sneak, no lock picking")
	ok(keys.call([lead, hunter]).has("OPT_PICK_LOCK"), "the hunter can pick it")
	ok(keys.call([lead, star]).has("OPT_MOON_OPEN"), "a moon mage opens it")
	ok(keys.call([lead]).has("OPT_BASH") and keys.call([lead]).has("OPT_LEAVE"), "anyone can bash or leave")
	ok(ExploreRules.need_met("char:stardrop", [star]), "char need")
	ok(not ExploreRules.need_met("class:wizard", [lead, star]), "class need")


func test_effects_split_between_map_and_run() -> void:
	var fx := ExploreRules.split_effects("open;food:+3;noise;hp_one:-2")
	eq(fx.map, ["open", "noise"] as Array[String], "map effects in order")
	eq(fx.run, "food:+3;hp_one:-2", "the rest goes to the run")


func test_deploy_radius_follows_speed() -> void:
	var knight := _unit("knight")
	var hunter := _unit("hunter")
	eq(ExploreRules.deploy_radius(knight, "party"), 1, "the heavy knight starts at the leader's side")
	ok(ExploreRules.deploy_radius(hunter, "party") > ExploreRules.deploy_radius(knight, "party"), "the quick hunter ranges further")
	eq(ExploreRules.deploy_radius(hunter, "ambushed"), 1, "caught: everyone starts close")
	eq(ExploreRules.deploy_radius(knight, "sneak"), 2, "a sneak attack gives a step more")


func test_deploy_cells_stay_on_the_leaders_side() -> void:
	var g := _room()
	var u := _unit("hunter")
	var cells := ExploreRules.deploy_cells(g, Vector2i(2, 0), u, 3)
	ok(not cells.has(Vector2i(2, 0)), "not the leader's own cell")
	ok(cells.has(Vector2i(0, 0)) and cells.has(Vector2i(2, 3)), "around the leader")
	for c in cells:
		ok(c.x < 4, "never through the wall: %s" % c)
		ok(absi(c.x - 2) + absi(c.y) <= 3, "within 3 steps: %s" % c)


func test_auto_deploy_gives_each_member_a_free_spot() -> void:
	var g := CombatGrid.flat(8, 8)
	var lead := _unit("knight")
	lead.place(Vector2i(4, 4), 0)
	var party := [lead, _unit("hunter"), _unit("mage"), _unit("knight")]
	var spots := ExploreRules.auto_deploy(g, party, "party", {Vector2i(5, 4): true})
	eq(spots.size(), 4, "everyone placed")
	eq(spots[lead], Vector2i(4, 4), "the leader stays put")
	var used := {}
	for u in spots:
		ok(not used.has(spots[u]), "no two on one cell")
		used[spots[u]] = true
		ok(spots[u] != Vector2i(5, 4), "not on a blocked cell")


func test_wasd_diagonals_dont_cut_corners() -> void:
	var g := CombatGrid.flat(5, 5)
	ok(ExploreRules.can_step_to(g, Vector2i(2, 2), Vector2i(2, 2) + Vector2i(1, 1), 1), "open ground: diagonal ok")
	g.set_terrain(Vector2i(3, 2), CombatGrid.T.ROCK)
	ok(not ExploreRules.can_step_to(g, Vector2i(2, 2), Vector2i(2, 2) + Vector2i(1, 1), 1), "a wall beside it blocks the diagonal")
	ok(ExploreRules.can_step_to(g, Vector2i(2, 2), Vector2i(2, 2) + Vector2i(0, 1), 1), "straight still fine")
	g.set_height(Vector2i(2, 1), 3)
	ok(not ExploreRules.can_step_to(g, Vector2i(2, 2), Vector2i(2, 2) + Vector2i(0, -1), 1), "no climbing a cliff")


func test_free_walk_slides_and_rounds_corners() -> void:
	var g := CombatGrid.flat(6, 6)
	var b := ExploreRules.BODY
	eq(ExploreRules.slide(g, Vector2(2.5, 2.5), Vector2(0.3, 0.0), b, 1), Vector2(2.8, 2.5), "open ground: the whole move")
	g.set_terrain(Vector2i(3, 2), CombatGrid.T.ROCK)
	var p := ExploreRules.slide(g, Vector2(2.5, 2.5), Vector2(0.6, 0.0), b, 1)
	ok(p.x + b <= 3.0 and p.x > 2.6, "stops against a wall: %s" % p)
	p = ExploreRules.slide(g, Vector2(2.5, 2.5), Vector2(0.6, 0.2), b, 1)
	ok(p.y > 2.6 and p.x + b <= 3.0, "slides along it: %s" % p)
	# Brushing a corner: the body overlaps the blocked row a little; it eases into the open lane.
	p = ExploreRules.slide(g, Vector2(2.5, 1.8), Vector2(0.4, 0.0), b, 1)
	ok(p.y < 1.8 and p.y >= 1.5, "eases off the corner instead of stopping: %s" % p)
	g.set_height(Vector2i(2, 1), 3)
	p = ExploreRules.slide(g, Vector2(2.5, 2.5), Vector2(0.0, -0.6), b, 1)
	ok(p.y - b >= 2.0, "no walking up a cliff: %s" % p)
	g.set_height(Vector2i(2, 1), 1)
	p = ExploreRules.slide(g, Vector2(2.5, 2.5), Vector2(0.0, -0.6), b, 1)
	ok(is_equal_approx(p.y, 1.9), "a one-level step is fine: %s" % p)


func test_walk_paths_take_diagonals() -> void:
	var g := CombatGrid.flat(8, 8)
	var p := ExploreRules.find_path(g, Vector2i(0, 0), Vector2i(5, 5), 1, {}, {}, true)
	eq(p.size(), 6, "straight down the diagonal")
	eq(ExploreRules.find_path(g, Vector2i(0, 0), Vector2i(5, 5), 1).size(), 11, "fights keep straight steps")
	g.set_terrain(Vector2i(1, 0), CombatGrid.T.ROCK)
	p = ExploreRules.find_path(g, Vector2i(0, 0), Vector2i(1, 1), 1, {}, {}, true)
	eq(p.size(), 3, "no cutting a corner")


func test_placed_props_block_and_save() -> void:
	var g := CombatGrid.flat(8, 8)
	g.add_prop(Vector2i(2, 2), "b_tavern", Vector2i(3, 2), 0.0, 3.0)
	g.add_prop(Vector2i(6, 6), "prop_rug", Vector2i.ONE, 0.45, 0.0, true)
	ok(not g.passable(Vector2i(4, 3)), "a house blocks its whole footprint")
	ok(g.passable(Vector2i(5, 3)) and g.passable(Vector2i(4, 4)), "but not past it")
	ok(g.passable(Vector2i(6, 6)), "a rug can be walked on")
	ok(not g.line_of_sight(Vector2i(0, 3), Vector2i(7, 3)), "a house blocks sight")
	var back := CombatGrid.from_dict(g.to_dict())
	ok(not back.passable(Vector2i(3, 2)), "props survive a save")
	eq(back.prop_at(Vector2i(4, 3)).sprite, "b_tavern", "footprint cell finds its prop")


func test_open_footprint_cells() -> void:
	var g := CombatGrid.flat(8, 8)
	g.add_prop(Vector2i(1, 1), "b_smithy", Vector2i(3, 4), 0.0, 3.0, false, {"open": "2,2"})
	ok(g.passable(Vector2i(3, 3)), "an open cell in a footprint can be walked (the smithy yard)")
	ok(not g.passable(Vector2i(3, 4)) and not g.passable(Vector2i(2, 3)), "the rest still blocks")
	eq(g.prop_anchor(Vector2i(3, 3)), CombatGrid.NONE_CELL, "the open cell belongs to no prop")
	var back := CombatGrid.from_dict(g.to_dict())
	ok(back.passable(Vector2i(3, 3)), "open cells survive a save")
	eq(CombatGrid.mirror_open("2,2|0,3"), "2,2|3,0", "mirroring swaps each open offset")
	g.remove_prop(Vector2i(1, 1))
	ok(g.passable(Vector2i(3, 4)), "removing it frees the footprint")


func test_village_maps_link_up() -> void:
	if Db.explore_events.is_empty():
		Db.reload()
	for n in ["home", "village", "house_ne", "tavern"]:
		var m := ExploreMap.load_named(n)
		ok(m != null and m.grid.passable(m.start[0]), "%s loads with a walkable start" % n)
		ok(not m.turn, "%s keeps the camera fixed for its building art" % n)
		for t in m.things:
			if t.kind == "restore":  # a village building: its event names the building's restore ladder
				ok(not RestoreRules.ladder(Db.restore, String(t.event)).is_empty(), "%s/%s: a ladder for %s" % [n, t.id, t.event])
			elif t.event != "":
				ok(Db.explore_events.has(t.event), "%s/%s: event %s exists" % [n, t.id, t.event])
			if t.to != "":
				var there := ExploreMap.load_named(t.to)
				ok(there != null and there.grid.passable(t.at), "%s/%s leads to a walkable cell in %s" % [n, t.id, t.to])
	var v := ExploreMap.load_named("village")
	var rack := v.things.filter(func(t: Dictionary) -> bool: return t.kind == "rack")
	eq(rack.size(), 1, "one weapon rack at the smithy")
	eq(v.fog, false, "the village shows the whole town")
	var quiet: Dictionary = v.things.filter(func(t: Dictionary) -> bool: return t.id == "quiet_house")[0]
	ok(not ExploreRules.find_path(v.grid, v.start[0], quiet.cell, 1).is_empty(),
		"the bluff house is reachable from the start on jump 1")
	ok(not ExploreRules.find_path(v.grid, v.start[0], rack[0].cell + Vector2i(-1, 0), 1).is_empty(),
		"the weapon rack is reachable from the start on jump 1")
	var q := ExploreMap.load_named("house_ne")
	var book: Array = q.things.filter(func(t: Dictionary) -> bool: return t.kind == "hidden")
	eq(book.size(), 1, "one hidden book")
	var door: Dictionary = q.things.filter(func(t: Dictionary) -> bool: return t.kind == "enter")[0]
	var inside: Vector2i = door.cell + Vector2i(0, -1)
	ok(not q.grid.line_of_sight(inside, book[0].cell), "the book can't be seen from the door")


func test_a_beaten_boss_stays_beaten() -> void:
	var throne := {"id": "throne", "boss": true}
	var cave := {"id": "cave", "boss": false}
	var flag := ExploreRules.beaten_flag("crypt", "throne")
	ok(not ExploreRules.stays_beaten("crypt", throne, []), "the boss is there before he's beaten")
	ok(ExploreRules.stays_beaten("crypt", throne, [flag]), "once beaten he stays gone")
	ok(not ExploreRules.stays_beaten("crypt", cave, [ExploreRules.beaten_flag("crypt", "cave")]), "other groups come back")
	ok(not ExploreRules.stays_beaten("snow_pass", throne, [flag]), "the flag is per map")
	var crypt := _crypt()
	ok(crypt.groups.any(func(g: Dictionary) -> bool: return g.id == "throne" and g.boss), "the crypt's throne group is a boss")


func test_only_full_height_props_see_through() -> void:
	# [USER] 2026-10-30: rocks, bushes, carts and crates stay solid; buildings, trees and arches open the window.
	ok(CombatBoard.see_through({"sprite": "b_home_a", "tall": 0.0}), "a building")
	ok(CombatBoard.see_through({"sprite": "prop_arch", "tall": 1.8, "arch": true}), "an arch")
	ok(CombatBoard.see_through({"sprite": "village/prop_tree", "tall": 1.6}), "a tree, marked in the catalog")
	ok(not CombatBoard.see_through({"sprite": "prop_cart", "tall": 1.3}), "a cart stays solid though it's tall")
	ok(not CombatBoard.see_through({"sprite": "prop_boulder", "tall": 0.6}), "a rock stays solid")
	ok(not CombatBoard.see_through({"sprite": "prop_crates", "tall": 0.8}), "crates stay solid")
	ok(CombatBoard.see_through({"sprite": "ph_building", "tall": 2.0}), "an uncatalogued gray box taller than a piece")
	ok(not CombatBoard.see_through({"sprite": "prop_bush_2", "tall": 0.55}), "an uncatalogued bush")
	for low in ["prop_bench", "prop_table", "prop_stool", "prop_barrel", "prop_fence", "prop_board", "prop_lamp", "prop_planter"]:
		ok(not CombatBoard.see_through({"sprite": low, "tall": 1.5}), low + " stays solid whatever its height")
	ok(CombatBoard.see_through({"sprite": "prop_well", "tall": 1.8}), "a roofed well taller than a piece")
	ok(not CombatBoard.see_through({"sprite": "prop_well", "tall": 0.8}), "a low well")
	ok(not CombatBoard.see_through({"sprite": "prop_stall", "tall": 0.9 - 0.01}), "a stall no taller than a piece")


## Brandon's bug (2026-10-30, note bug-f-key-no-interact): a "!" with its F hint by a wall, and F did nothing.
## F used the leader's line of sight, the hint the board's lit cells. Now both use thing_to_use.
func test_f_uses_the_marked_thing_round_a_corner() -> void:
	var lit := {}
	for y in 6:
		for x in 6:
			lit[Vector2i(x, y)] = 2
	var bench := {"id": "bench", "cell": Vector2i(3, 1)}
	var far := {"id": "far", "cell": Vector2i(5, 5)}
	eq(ExploreRules.thing_to_use([bench, far], Vector2i(1, 2), Vector2i(1, 0), lit).get("id"), "bench", "two cells off, wall or not")
	eq(ExploreRules.thing_to_use([far], Vector2i(1, 2), Vector2i(1, 0), lit), {}, "past the hint range")
	lit[Vector2i(3, 1)] = 1
	eq(ExploreRules.thing_to_use([bench], Vector2i(1, 2), Vector2i(1, 0), lit), {}, "not on a cell drawn lit")
	var left := {"id": "left", "cell": Vector2i(1, 3)}
	var right := {"id": "right", "cell": Vector2i(3, 3)}
	eq(ExploreRules.thing_to_use([left, right], Vector2i(2, 3), Vector2i(1, 0), lit).get("id"), "right", "a tie goes to the one faced")
	eq(ExploreRules.thing_to_use([left, right], Vector2i(2, 3), Vector2i(-1, 0), lit).get("id"), "left")

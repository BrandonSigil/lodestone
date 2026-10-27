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
	ok(ExploreRules.can_step_dir(g, Vector2i(2, 2), Vector2i(1, 1), 1), "open ground: diagonal ok")
	g.set_terrain(Vector2i(3, 2), CombatGrid.T.ROCK)
	ok(not ExploreRules.can_step_dir(g, Vector2i(2, 2), Vector2i(1, 1), 1), "a wall beside it blocks the diagonal")
	ok(ExploreRules.can_step_dir(g, Vector2i(2, 2), Vector2i(0, 1), 1), "straight still fine")
	g.set_height(Vector2i(2, 1), 3)
	ok(not ExploreRules.can_step_dir(g, Vector2i(2, 2), Vector2i(0, -1), 1), "no climbing a cliff")


func test_wasd_picks_the_screen_direction() -> void:
	# Camera turn 0: grid (-1, -1) is straight up the screen, (1, -1) is right.
	var screen_of := func(d: Vector2i) -> Vector2: return Vector2((d.x - d.y) * 32.0, (d.x + d.y) * 16.0)
	eq(ExploreRules.steps_toward(Vector2(0, -1), screen_of)[0], Vector2i(-1, -1), "W goes up")
	eq(ExploreRules.steps_toward(Vector2(1, 0), screen_of)[0], Vector2i(1, -1), "D goes right")
	ok(not ExploreRules.steps_toward(Vector2(0, -1), screen_of).has(Vector2i(1, 1)), "never backwards")


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


func test_village_maps_link_up() -> void:
	if Db.explore_events.is_empty():
		Db.reload()
	for n in ["home", "village", "house_ne", "tavern"]:
		var m := ExploreMap.load_named(n)
		ok(m != null and m.grid.passable(m.start[0]), "%s loads with a walkable start" % n)
		ok(not m.turn, "%s keeps the camera fixed for its building art" % n)
		for t in m.things:
			if t.event != "":
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
	var q := ExploreMap.load_named("house_ne")
	var book: Array = q.things.filter(func(t: Dictionary) -> bool: return t.kind == "hidden")
	eq(book.size(), 1, "one hidden book")
	var door: Dictionary = q.things.filter(func(t: Dictionary) -> bool: return t.kind == "enter")[0]
	var inside: Vector2i = door.cell + Vector2i(0, -1)
	ok(not q.grid.line_of_sight(inside, book[0].cell), "the book can't be seen from the door")

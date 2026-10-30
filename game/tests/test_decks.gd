extends TestCase
## Two-level cells ([USER] 2026-10-30, card builder-city-overpass): a deck over a lane, a bridge you walk on
## with a lane you walk under. Places: a cell is its ground, deck_of(cell) its deck.


## A lane along y = 2 at height 0, with banks of height 3 either side and a deck over (2, 2) at 3: a bridge.
func _bridge() -> CombatGrid:
	var g := CombatGrid.flat(5, 5)
	for x in 5:
		for y in 5:
			if y != 2:
				g.set_height(Vector2i(x, y), 3)
	g.add_deck(Vector2i(2, 2), 3)
	return g


func test_a_deck_is_a_second_floor() -> void:
	var g := _bridge()
	var lane := Vector2i(2, 2)
	var deck := CombatGrid.deck_of(lane)
	ok(CombatGrid.on_deck(deck) and not CombatGrid.on_deck(lane))
	eq(CombatGrid.ground(deck), lane)
	eq(g.height_at(lane), 0, "the lane underneath")
	eq(g.height_at(deck), 3, "the deck on top")
	eq(g.terrain_at(deck), CombatGrid.T.STONE)
	ok(g.passable(lane) and g.passable(deck), "both walkable")
	eq(g.places_at(lane), [lane, deck] as Array[Vector2i])
	eq(g.places_at(Vector2i(1, 2)), [Vector2i(1, 2)] as Array[Vector2i], "no deck, one place")
	eq(g.top_height(), 3)


func test_steps_on_and_under() -> void:
	var g := _bridge()
	var deck := CombatGrid.deck_of(Vector2i(2, 2))
	ok(g.can_step(Vector2i(2, 1), deck, 1), "from the bank onto the bridge, level")
	ok(not g.can_step(Vector2i(2, 1), Vector2i(2, 2), 1), "not down three levels into the lane")
	ok(g.can_step(Vector2i(1, 2), Vector2i(2, 2), 1), "along the lane, under the bridge")
	ok(not g.can_step(Vector2i(2, 2), deck, 9), "never straight from the lane up through the deck")


func test_a_low_deck_shuts_the_lane() -> void:
	var g := CombatGrid.flat(3, 3)
	g.add_deck(Vector2i(1, 1), 1)
	ok(not g.passable(Vector2i(1, 1)), "one level is no room to walk under")
	ok(g.passable(CombatGrid.deck_of(Vector2i(1, 1))))


func test_a_house_on_the_bridge_blocks_the_deck_not_the_lane() -> void:
	var g := _bridge()
	var deck := CombatGrid.deck_of(Vector2i(2, 2))
	g.add_prop(deck, "ph_house")
	ok(not g.passable(deck), "the house fills the deck")
	ok(g.passable(Vector2i(2, 2)), "the lane under it stays open")
	eq(g.prop_at(Vector2i(2, 2)), {}, "nothing stands in the lane")


func test_decks_and_deck_props_save() -> void:
	var g := _bridge()
	g.add_deck(Vector2i(3, 2), 3, CombatGrid.T.STAIRS)
	g.add_prop(CombatGrid.deck_of(Vector2i(2, 2)), "ph_house")
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	ok(d.decks.any(func(e: Dictionary) -> bool: return int(e.x) == 3 and String(e.t) == "t"), "decks as [{x, y, h, t}]")
	ok(d.props[0].deck, "a prop on a deck says so")
	var back := CombatGrid.from_dict(d)
	eq(back.height_at(CombatGrid.deck_of(Vector2i(3, 2))), 3)
	eq(back.terrain_at(CombatGrid.deck_of(Vector2i(3, 2))), CombatGrid.T.STAIRS, "a stair deck, so a flight can climb on")
	ok(not back.passable(CombatGrid.deck_of(Vector2i(2, 2))), "the house is back on the deck")
	ok(back.passable(Vector2i(2, 2)))
	eq(back.resized(4, 4).decks.size(), 2, "decks survive a resize")


# --- step 2: walking and pathing --------------------------------------------------------

func _walker(g: CombatGrid, c: Vector2i, team := 0) -> CombatUnit:
	var u := CombatUnit.enemy(load("res://data/classes/bandit.tres"))
	u.team = team
	u.jump = 1
	u.move = 4
	u.place(c, g.height_at(c))
	return u


func test_explore_paths_cross_the_bridge_and_run_under_it() -> void:
	var g := _bridge()
	var deck := CombatGrid.deck_of(Vector2i(2, 2))
	eq(ExploreRules.find_path(g, Vector2i(2, 1), Vector2i(2, 3), 1), [Vector2i(2, 1), deck, Vector2i(2, 3)] as Array[Vector2i], "over the deck, bank to bank")
	var under := ExploreRules.find_path(g, Vector2i(0, 2), Vector2i(4, 2), 1)
	ok(under.has(Vector2i(2, 2)) and not under.has(deck), "along the lane, under the deck")
	ok(ExploreRules.find_path(g, Vector2i(2, 1), Vector2i(2, 2), 1).is_empty(), "no way down into the lane from the bank")
	ok(not ExploreRules.find_path(g, Vector2i(1, 1), Vector2i(3, 3), 1, {}, {}, true).is_empty(), "diagonal walking crosses too")
	var known := {Vector2i(2, 1): true, Vector2i(2, 2): true, Vector2i(2, 3): true}
	eq(ExploreRules.find_path(g, Vector2i(2, 1), Vector2i(2, 3), 1, {}, known).size(), 3, "seeing the cell is seeing its deck")
	var r := ExploreRules.reach(g, [Vector2i(0, 0)], 1)
	ok(r.has(deck) and not r.has(Vector2i(2, 2)), "the banks reach the deck, not the lane")


func test_free_walking_keeps_its_level() -> void:
	var g := _bridge()
	var deck := CombatGrid.deck_of(Vector2i(2, 2))
	eq(g.step_place(Vector2i(2, 1), Vector2i(2, 2), 1), deck, "from the bank: onto the deck")
	eq(g.step_place(Vector2i(1, 2), Vector2i(2, 2), 1), Vector2i(2, 2), "from the lane: under it")
	eq(g.step_place(Vector2i(2, 2), Vector2i(2, 1), 1), CombatGrid.NO_PLACE, "the bank is a cliff from the lane")
	var p := ExploreRules.slide(g, Vector2(2.5, 1.5), Vector2(0, 1), ExploreRules.BODY, 1)
	ok(is_equal_approx(p.y, 2.5), "walks out onto the bridge")
	p = ExploreRules.slide(g, Vector2(2.5, 2.5), Vector2(0, 1), ExploreRules.BODY, 1, {}, deck)
	ok(is_equal_approx(p.y, 3.5), "and off the far end")
	p = ExploreRules.slide(g, Vector2(2.5, 2.5), Vector2(0, 1), ExploreRules.BODY, 1, {}, Vector2i(2, 2))
	ok(p.y < 2.75, "in the lane the bank is a wall")
	p = ExploreRules.slide(g, Vector2(0.5, 2.5), Vector2(2, 0), ExploreRules.BODY, 1, {}, Vector2i(0, 2))
	ok(is_equal_approx(p.x, 2.5), "walks the lane under the bridge")


func test_fight_moves_and_deploys_on_both_levels() -> void:
	var g := _bridge()
	var deck := CombatGrid.deck_of(Vector2i(2, 2))
	var top := _walker(g, Vector2i(2, 1))
	var low := _walker(g, Vector2i(0, 2))
	eq(top.vis, Vector2(2, 1))
	var rt: Dictionary = CombatRules.reachable(g, top, [top, low]).cost
	ok(rt.has(deck) and rt.has(Vector2i(2, 3)) and not rt.has(Vector2i(2, 2)), "on top: across the bridge")
	var rl: Dictionary = CombatRules.reachable(g, low, [top, low]).cost
	ok(rl.has(Vector2i(2, 2)) and not rl.has(deck), "below: under it")
	top.place(deck, 3)
	eq(top.vis, Vector2(2, 2), "a piece on a deck is drawn at its cell")
	var foe := _walker(g, Vector2i(2, 3), 1)
	ok(CombatRules.reachable(g, low, [top, low, foe]).cost.has(Vector2i(2, 2)), "a piece on the deck doesn't block the lane")
	eq(CombatRules.dist(deck, Vector2i(2, 3)), 1)
	eq(int(EnemyAi.walk_distance(g, foe, [top, low, foe]).get(Vector2i(2, 4), -1)), 2, "the AI measures over the bridge")
	var cells := ExploreRules.deploy_cells(g, deck, _walker(g, Vector2i(0, 0)), 1)
	ok(cells.has(Vector2i(2, 1)) and cells.has(Vector2i(2, 3)) and not cells.has(Vector2i(2, 2)), "deploy round a leader on the deck")


# --- step 3: fights on two levels ---------------------------------------------------------

func test_pushed_along_a_deck_or_off_its_side() -> void:
	var g := _bridge()
	g.add_deck(Vector2i(3, 2), 3)
	var deck := CombatGrid.deck_of(Vector2i(2, 2))
	var k := _walker(g, deck)
	var b := _walker(g, CombatGrid.deck_of(Vector2i(3, 2)), 1)
	var hp := b.hp
	CombatRules.push(g, [k, b], k.cell, b, 1)
	eq(b.cell, Vector2i(4, 2), "off the end of the bridge, down into the lane")
	eq(b.hp, hp - 2 * CombatRules.FALL_DAMAGE, "a 3 level fall")
	b.place(Vector2i(2, 1), 3)
	b.hp = hp
	k.place(Vector2i(2, 0), 3)
	CombatRules.push(g, [k, b], k.cell, b, 1)
	eq(b.cell, deck, "from the bank onto the bridge, level")
	eq(b.hp, hp, "no fall")
	var low := _walker(g, Vector2i(1, 2), 1)
	var shover := _walker(g, Vector2i(0, 2))
	CombatRules.push(g, [shover, low, k, b], shover.cell, low, 1)
	eq(low.cell, Vector2i(2, 2), "in the lane it slides under the bridge")


func test_blasts_keep_to_their_level() -> void:
	var g := _bridge()
	g.add_deck(Vector2i(3, 2), 3)
	var deck := CombatGrid.deck_of(Vector2i(2, 2))
	var moon := Db.ability("moonbeam")
	var top := CombatRules.area(g, moon, deck)
	ok(top.has(CombatGrid.deck_of(Vector2i(3, 2))) and top.has(Vector2i(1, 2)), "on the deck: along it, and down past its edge")
	ok(not top.has(Vector2i(2, 2)) and not top.has(Vector2i(3, 2)), "not the lane under it")
	var low := CombatRules.area(g, moon, Vector2i(2, 2))
	ok(low.has(Vector2i(3, 2)) and not low.has(deck), "under the deck: the deck shields what's on it")


func test_guard_ring_only_where_the_guard_can_hit() -> void:
	var g := _bridge()
	var gd := _walker(g, CombatGrid.deck_of(Vector2i(2, 2)))
	CombatRules.guard(gd)
	var ring := CombatRules.guard_ring(g, [gd], 0)
	ok(ring.has(Vector2i(2, 1)) and ring.has(Vector2i(2, 3)), "the banks beside the bridge")
	ok(not ring.has(Vector2i(1, 2)) and not ring.has(Vector2i(3, 2)), "not the lane three levels down")

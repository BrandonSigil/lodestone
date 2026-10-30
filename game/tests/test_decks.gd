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

extends TestCase
## Road set pieces (SetPiece, docs/systems/set-pieces.md): every encounter that names a map loads it, starts the
## party where the road choice put it, hides foes only from a party that walked in, and leaves nobody cut off.


func _members(n: int) -> Array:
	var def: CharacterDef = load("res://data/characters/stardrop.tres")
	var out := []
	for i in n:
		out.append({"def": def, "hp": 8})
	return out


func _pieces() -> Array:
	var out := []
	for id in Db.encounters:
		if String(Db.encounters[id].get("map", "")) != "":
			out.append(id)
	return out


func test_every_set_piece_fight_builds() -> void:
	ok(_pieces().size() >= 3, "the wagon (in and out) and the bulls are set pieces")
	for id in _pieces():
		var enc: Dictionary = Db.encounters[id]
		var setup := SetPiece.load_map(enc.map)
		ok(setup != null, "%s: map %s loads" % [id, enc.map])
		if setup == null:
			continue
		var walked_in: bool = enc.start != "out"
		var units := SetPiece.units(setup, _members(4), walked_in)
		var party := units.filter(func(u: CombatUnit) -> bool: return u.team == 0)
		var foes := units.filter(func(u: CombatUnit) -> bool: return u.team == 1)
		eq(party.size(), 4, "%s: the whole party has a start cell" % id)
		eq(foes.size(), setup.enemies.size(), "%s: every foe stands on free ground" % id)
		var seen := {}
		for u: CombatUnit in units:
			ok(not seen.has(u.cell), "%s: one piece per cell" % id)
			seen[u.cell] = true
		var reach := MapOps.reach(setup.grid, party[0].cell)
		for u: CombatUnit in units:
			ok(reach.has(u.cell), "%s: the piece at %s can be walked to" % [id, u.cell])
		var goals := FightGoals.parse(enc.goals, setup.piece.get("exit", []))
		if goals.kinds.has("exit"):
			ok(not goals.exit_cells.is_empty(), "%s: an exit goal has exit cells" % id)
			for c in goals.exit_cells:
				ok(reach.has(c), "%s: exit %s can be walked to" % [id, c])


func test_foes_hide_only_from_a_party_that_walked_in() -> void:
	var setup := SetPiece.load_map("sp_wagon")
	var hidden := func(units: Array) -> int:
		return units.filter(func(u: CombatUnit) -> bool: return u.team == 1 and u.hiding).size()
	ok(hidden.call(SetPiece.units(setup, _members(3), true)) >= 2, "walking up to the wagon springs the trap")
	eq(hidden.call(SetPiece.units(setup, _members(3), false)), 0, "spotted from the road, nobody is hidden")
	var near := SetPiece.party_cells(setup, true, 3)
	var far := SetPiece.party_cells(setup, false, 3)
	ok(near[0] != far[0], "the two starts are different places")


func test_road_events_stay_on_their_road() -> void:
	var wagon := {}
	for ev in Db.travel_events:
		if ev.id == "tr_wagon":
			wagon = ev
	ok(not wagon.is_empty(), "the wagon event is in the table")
	ok(TrailRules.on_road(wagon, ["town", "forest_roads"]), "the wagon is on the west road")
	ok(not TrailRules.on_road(wagon, ["town", "farmland"]), "and not on the east road")
	ok(TrailRules.on_road({"road": []}, ["town", "farmland"]), "an event with no road is on every road")

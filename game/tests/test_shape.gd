extends TestCase
## Irregular floor outlines (IslandShape): deterministic, connected, deploy-ready, and not a plain rectangle.


func test_outline_is_deterministic() -> void:
	var a := CombatGrid.generate(42, 14, 9, 0.0, true)
	var b := CombatGrid.generate(42, 14, 9, 0.0, true)
	eq(a.to_dict(), b.to_dict(), "same seed, same outline")


func test_outline_connects_and_deploys() -> void:
	for s in range(1, 25):
		var g := CombatGrid.generate(s, 14, 9, 0.0, true)
		ok(g.connected(1), "seed %d connects both deploy zones" % s)
		ok(g.deploy_cells(0).size() > 0 and g.deploy_cells(1).size() > 0, "seed %d has deploy cells on both sides" % s)


func test_outline_is_not_a_rectangle() -> void:
	var void_seen := 0
	for s in range(1, 25):
		var g := CombatGrid.generate(s, 14, 9, 0.0, true)
		var voids := 0
		for y in g.h:
			for x in g.w:
				var c := Vector2i(x, y)
				if g.terrain_at(c) == CombatGrid.T.VOID:
					voids += 1
					eq(g.height_at(c), 0, "void cells sit at height 0")
		if voids > 0:
			void_seen += 1
	ok(void_seen >= 20, "most seeds cut the corners off (%d of 24)" % void_seen)


func test_plain_generate_is_still_available() -> void:
	var g := CombatGrid.generate(5, 10, 8, 0.0, false)
	var none := true
	for y in g.h:
		for x in g.w:
			if g.terrain_at(Vector2i(x, y)) == CombatGrid.T.VOID:
				none = false
	ok(none, "outline = false still gives a plain rectangle")


func test_default_generate_is_irregular() -> void:
	var cut := false
	for s in range(1, 25):
		var g := CombatGrid.generate(s, 10, 8)
		if g.terrain_at(Vector2i(0, 0)) == CombatGrid.T.VOID or g.terrain_at(Vector2i(9, 7)) == CombatGrid.T.VOID:
			cut = true
	ok(cut, "the default generator cuts corners for some seeds")

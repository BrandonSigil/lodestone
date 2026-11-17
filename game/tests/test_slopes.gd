extends TestCase
## Slopes ([USER] 2026-11-17, docs/systems/slopes.md): a grassy bank in place of a cliff face or a stair. A slope cell
## keeps its ground but its top tilts from the ground below up to the lip above; pieces walk it like flat ground.


## A meadow at 1 (y 3 to 5) below a terrace at 3 (y 0 to 1), with row 2 between them: a cliff until it is sloped.
func _hill(w := 5) -> CombatGrid:
	var g := CombatGrid.flat(w, 6)
	for x in w:
		for y in 6:
			g.set_height(Vector2i(x, y), 3 if y < 2 else 1)
	return g


func test_a_cliff_foot_tilts_up_to_the_lip() -> void:
	var g := _hill()
	var c := Vector2i(2, 2)
	ok(not g.can_step(Vector2i(2, 3), Vector2i(2, 1), 1), "a two-level cliff stops a jump-1 piece")
	ok(MapOps.slope(g, c))
	ok(g.is_slope(c))
	eq(g.height_at(c), 2, "halfway between the meadow and the terrace")
	var z := g.slope_corners(c)
	eq(z[0], 3.0, "back corners meet the terrace")
	eq(z[1], 3.0)
	eq(z[2], 1.0, "front corners meet the meadow")
	eq(z[3], 1.0)
	eq(g.edge_h(c, Vector2i(0, -1)), 3.0)
	eq(g.edge_h(c, Vector2i(0, 1)), 1.0)
	eq(g.stand_h(c), 2.0, "a piece stands halfway up")


func test_pieces_walk_up_a_slope() -> void:
	var g := _hill()
	MapOps.slope(g, Vector2i(2, 2))
	ok(g.can_step(Vector2i(2, 3), Vector2i(2, 2), 1), "from the meadow onto the bank")
	ok(g.can_step(Vector2i(2, 2), Vector2i(2, 1), 1), "from the bank onto the terrace")
	ok(not g.can_step(Vector2i(1, 2), Vector2i(2, 2), 0) or g.is_slope(Vector2i(1, 2)), "the cliff beside it still a cliff")
	var steps := MapOps.reach(g, Vector2i(2, 5), 1)
	ok(steps.has(Vector2i(2, 0)), "the terrace is reached up the bank")


func test_a_bank_along_a_cliff_is_one_surface() -> void:
	var g := _hill()
	for x in 5:
		ok(MapOps.slope(g, Vector2i(x, 2)))
	for x in 4:
		ok(g.can_step(Vector2i(x, 2), Vector2i(x + 1, 2), 0), "along the bank, level")
	var a := g.slope_corners(Vector2i(1, 2))
	var b := g.slope_corners(Vector2i(2, 2))
	eq(a[1], b[0], "neighbours share their corners")
	eq(a[2], b[3])


func test_a_slope_end_twists_into_the_cliff_beside_it() -> void:
	var g := _hill()
	MapOps.slope(g, Vector2i(2, 2))
	var z := g.slope_corners(Vector2i(2, 2))
	eq(z[0], 3.0, "both back corners stay on the lip")
	eq(z[1], 3.0)
	ok(not g.can_step(Vector2i(3, 3), Vector2i(3, 1), 1), "next door, the cliff still blocks")


func test_a_slope_spans_at_most_two_levels() -> void:
	var g := CombatGrid.flat(3, 3)
	for x in 3:
		g.set_height(Vector2i(x, 0), 5)
	MapOps.slope(g, Vector2i(1, 1))
	var z := g.slope_corners(Vector2i(1, 1))
	eq(g.height_at(Vector2i(1, 1)), 1, "a five-level cliff: the bank starts at the foot")
	ok(z[0] <= 2.0 and z[1] <= 2.0, "and climbs no more than a level over its own height")
	ok(not g.can_step(Vector2i(1, 1), Vector2i(1, 0), 1), "the rest of the cliff still stands")


func test_bank_slopes_only_cliff_feet() -> void:
	var g := _hill()
	g.set_terrain(Vector2i(4, 2), CombatGrid.T.WATER)
	var cells: Array[Vector2i] = []
	for y in 6:
		for x in 5:
			cells.append(Vector2i(x, y))
	eq(MapOps.bank(g, cells), 4, "the four dry cells at the foot of the terrace")
	ok(not g.is_slope(Vector2i(2, 1)), "the terrace stays flat")
	ok(not g.is_slope(Vector2i(2, 4)), "and so does the open meadow")
	ok(not g.is_slope(Vector2i(4, 2)), "water never tilts")


func test_slopes_save_and_load() -> void:
	var g := _hill()
	MapOps.slope(g, Vector2i(1, 2))
	MapOps.slope(g, Vector2i(2, 2))
	var d := g.to_dict()
	ok(d.has("slopes"))
	eq(String(d.slopes[2]), ".//..", "one row string, / a slope")
	var back := CombatGrid.from_dict(d)
	ok(back.is_slope(Vector2i(1, 2)) and back.is_slope(Vector2i(2, 2)) and not back.is_slope(Vector2i(3, 2)))
	ok(not CombatGrid.from_dict(_hill().to_dict()).to_dict().has("slopes"), "maps with no slopes save as before")
	ok(back.resized(3, 3).is_slope(Vector2i(2, 2)), "a resize keeps them")


func test_painting_water_or_stairs_flattens_a_slope() -> void:
	var g := _hill()
	MapOps.slope(g, Vector2i(2, 2))
	g.set_terrain(Vector2i(2, 2), CombatGrid.T.WATER)
	ok(not g.is_slope(Vector2i(2, 2)))
	g.set_terrain(Vector2i(2, 2), CombatGrid.T.STAIRS)
	ok(MapOps.slope(g, Vector2i(2, 2)), "a stair turns into bank")
	eq(g.terrain_at(Vector2i(2, 2)), CombatGrid.T.GRASS)


func test_walkers_follow_the_slope() -> void:
	var g := _hill()
	MapOps.slope(g, Vector2i(2, 2))
	var c := Vector2i(2, 2)
	ok(absf(ExploreRules.ground_h(g, c, Vector2(2.5, 2.05), 1) - 2.9) < 0.01, "near the top edge the feet are near the lip")
	ok(absf(ExploreRules.ground_h(g, c, Vector2(2.5, 2.95), 1) - 1.1) < 0.01, "near the foot, near the meadow")
	ok(absf(ExploreRules.ground_h(g, Vector2i(2, 1), Vector2(2.5, 1.98), 1) - 3.0) < 0.01, "the terrace meets the bank level")


func test_outer_corner_folds_along_the_contour() -> void:
	# A block at 3 in the top-left (x < 2, y < 2), the rest at 1; the cell at its corner is a slope.
	var g := CombatGrid.flat(4, 4)
	for y in 4:
		for x in 4:
			g.set_height(Vector2i(x, y), 3 if x < 2 and y < 2 else 1)
	for c in [Vector2i(2, 0), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]:
		MapOps.slope(g, c)
	var z := g.slope_corners(Vector2i(2, 2))
	eq(z[0], 3.0, "only the corner touching the block is up")
	eq(z[1], 1.0)
	eq(z[2], 1.0)
	eq(z[3], 1.0)
	eq(CombatGrid.slope_fold(z), 1, "folded along the level diagonal")
	eq(CombatGrid.surface_of(z, Vector2(0.9, 0.9)), 1.0, "the far half lies flat")

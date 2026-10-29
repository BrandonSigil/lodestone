extends TestCase
## The soft terrain pass's rules (TerrainShape): corner shapes, outlines, lips and water flow.

const T := CombatGrid.T


## A corner radius of this kind, give or take its jitter.
func _near(r: float, kind: float, msg: String) -> void:
	ok(absf(r) >= kind * (1.0 - TerrainShape.JITTER) - 0.0001 and absf(r) <= kind * (1.0 + TerrainShape.JITTER) + 0.0001,
		"%s (got %s)" % [msg, r])


static func _flat(n: int, h: int) -> CombatGrid:
	var g := CombatGrid.flat(n, n)
	for y in n:
		for x in n:
			g.set_height(Vector2i(x, y), h)
	return g


## A cell's drawn surface, or a deep floor off the ground (what CombatBoard._surf_or_floor gives).
static func _surf(g: CombatGrid) -> Callable:
	return func(c: Vector2i) -> float:
		if not g.solid(c):
			return -6.0
		return float(g.height_at(c)) - (0.3 if g.terrain_at(c) == T.WATER else 0.0)


func test_corners_round_where_both_sides_drop() -> void:
	var g := _flat(5, 1)
	for y in 3:
		for x in 3:
			g.set_height(Vector2i(x, y), 4)  # a 3 x 3 block in the corner of the map
	var s := _surf(g)
	_near(TerrainShape.corner_radius(g, Vector2i(2, 2), 2, s), TerrainShape.ROUND, "the block's outer corner rounds")
	eq(TerrainShape.corner_radius(g, Vector2i(2, 2), 0, s), 0.0, "an inner corner of the block stays square")
	eq(TerrainShape.corner_radius(g, Vector2i(1, 2), 2, s), 0.0, "the middle of a side stays straight")
	_near(TerrainShape.corner_radius(g, Vector2i(0, 0), 0, s), TerrainShape.ROUND, "the map's own edge counts as a drop")
	eq(TerrainShape.corner_radius(g, Vector2i(2, 2), 2, s), TerrainShape.corner_radius(g, Vector2i(2, 2), 2, s), "fixed per corner")
	var lone := _flat(3, 0)
	lone.set_height(Vector2i(1, 1), 3)
	for k in 4:
		_near(TerrainShape.corner_radius(lone, Vector2i(1, 1), k, _surf(lone)), TerrainShape.PILLAR, "a lone block rounds into a column")


func test_fillets_where_higher_ground_wraps_a_corner() -> void:
	var g := _flat(4, 4)
	g.set_height(Vector2i(1, 1), 1)  # a notch, higher ground all round it
	var s := _surf(g)
	for k in 4:
		var r := TerrainShape.corner_radius(g, Vector2i(1, 1), k, s)
		ok(r < 0.0, "corner %d of the notch is filleted" % k)
		_near(r, TerrainShape.FILLET, "a fillet's radius")
	var gp := TerrainShape.gap(g, Vector2i(1, 1), 0, s)
	eq(gp.h, 4.0, "the fillet is the higher ground's")
	ok(gp.has("src"))
	g.set_height(Vector2i(0, 1), 6)  # the two sides at different heights: no fillet
	eq(TerrainShape.corner_radius(g, Vector2i(1, 1), 0, s), 0.0)


func test_water_and_stairs_stay_square() -> void:
	var g := _flat(3, 0)
	g.set_height(Vector2i(1, 1), 3)
	g.set_terrain(Vector2i(1, 1), T.WATER)
	eq(TerrainShape.corner_radius(g, Vector2i(1, 1), 2, _surf(g)), 0.0, "water never rounds off")
	g.set_terrain(Vector2i(1, 1), T.GRASS)
	g.set_terrain(Vector2i(2, 1), T.STAIRS)
	eq(TerrainShape.corner_radius(g, Vector2i(1, 1), 2, _surf(g)), 0.0, "a corner beside a stair stays cut")
	ok(TerrainShape.corner_radius(g, Vector2i(1, 1), 0, _surf(g)) > 0.0, "the far side still rounds")


func test_outline_is_a_closed_loop() -> void:
	var c := Vector2i(3, 2)
	var plain := TerrainShape.outline(c, PackedFloat32Array([0, 0, 0, 0]))
	eq(plain.size(), 4, "a square is four sides")
	eq(plain[0].a, Vector2(3, 2))
	var r := PackedFloat32Array([0.3, 0.0, -0.25, 0.46])
	var segs := TerrainShape.outline(c, r)
	eq(segs.size(), 4 + 3 * TerrainShape.ARC_STEPS)
	for i in segs.size():
		var nxt: Dictionary = segs[(i + 1) % segs.size()]
		ok((segs[i].b as Vector2).is_equal_approx(nxt.a), "segment %d meets the next" % i)
		ok(is_equal_approx((segs[i].na as Vector2).length(), 1.0), "normals are unit length")
		var p: Vector2 = segs[i].a
		ok(p.x >= c.x - 0.001 and p.x <= c.x + 1.001 and p.y >= c.y - 0.001 and p.y <= c.y + 1.001, "the outline stays in its cell")
	var gp := TerrainShape.gap_polygon(c, 0, 0.3)
	eq(gp[0], Vector2(3, 2), "the cut-away bit starts at the corner")
	for p in gp:
		ok(p.distance_to(Vector2(3, 2)) <= 0.3 + 0.001)


func test_lip_runs_on_unbroken() -> void:
	var last := TerrainShape.lip_depth(0.0, 1.0)
	for i in range(1, 400):
		var d := TerrainShape.lip_depth(i * 0.01, 1.0)
		ok(d > 0.2 and d <= 1.0, "a lip hangs between its scallops and its longest drip")
		ok(absf(d - last) < 0.3, "no jumps along the edge")
		last = d
	eq(TerrainShape.lip_depth(2.37, 0.8), TerrainShape.lip_depth(2.37, 0.8), "same place, same drips")


func test_water_flows_down_the_river() -> void:
	var g := _flat(8, 5)
	var path := MapOps.line(Vector2i(0, 3), Vector2i(7, 3))
	MapOps.river(g, path, 1, 1)
	g.set_height(Vector2i(5, 3), g.height_at(Vector2i(4, 3)) - 1)  # a fall partway down
	g.set_height(Vector2i(6, 3), g.height_at(Vector2i(5, 3)))
	g.set_height(Vector2i(7, 3), g.height_at(Vector2i(5, 3)))
	var fl := TerrainShape.flow(g)
	eq(fl.size(), 8)
	for c: Vector2i in fl:
		ok((fl[c] as Vector2).x > 0.5, "water at %s runs toward the low end" % c)
	var strokes := TerrainShape.strokes(g, fl)
	ok(not strokes.is_empty(), "a river gets flow strokes")
	var cut := TerrainShape.by_cell(strokes)
	for c: Vector2i in cut:
		eq(g.terrain_at(c), T.WATER, "strokes only lie on water")
		for piece: Dictionary in cut[c]:
			for p: Vector2 in piece.pts:
				ok(p.x >= c.x - 0.001 and p.x <= c.x + 1.001 and p.y >= c.y - 0.001 and p.y <= c.y + 1.001, "a piece stays in its cell")
	eq(TerrainShape.strokes(g, fl).size(), strokes.size(), "the same map gets the same strokes")


func test_drifts_stay_under_their_depth() -> void:
	var last := TerrainShape.drift_height(0.0, 0.5)
	for i in range(1, 300):
		var d := TerrainShape.drift_height(i * 0.01, 0.5)
		ok(d > 0.0 and d <= 0.5 + 0.0001, "a drift is never higher than its depth")
		ok(absf(d - last) < 0.1, "no jumps along the wall")
		last = d


func test_stairs_climb_along_their_flight() -> void:
	# A flight down a trench along x (6, then stairs 5 5 4 4, then water at 2), walls at 6 either side, and one
	# low forest cell beside the third step: that step still climbs along the flight, not across it.
	var g := _flat(7, 5)
	for x in 7:
		for y in 5:
			g.set_height(Vector2i(x, y), 6)
	var steps := [5, 5, 4, 4]
	for i in 4:
		g.set_height(Vector2i(i + 1, 2), steps[i])
		g.set_terrain(Vector2i(i + 1, 2), T.STAIRS)
	g.set_height(Vector2i(5, 2), 2)
	g.set_terrain(Vector2i(5, 2), T.WATER)
	g.set_height(Vector2i(3, 1), 3)
	g.set_terrain(Vector2i(3, 1), T.FOREST)
	for i in 4:
		var run := MapDress.stair_run(g, Vector2i(i + 1, 2))
		ok(not run.is_empty(), "step %d has a run" % i)
		eq(run.up, Vector2i(-1, 0), "step %d climbs back up the flight" % i)


func test_roads_draw_as_ribbons() -> void:
	var g := _flat(8, 2)
	for x in range(1, 7):
		g.set_terrain(Vector2i(x, 2), T.ROAD)  # along x...
	for y in range(3, 7):
		g.set_terrain(Vector2i(6, y), T.ROAD)  # ...then round a corner
	g.set_height(Vector2i(3, 3), 5)  # a block beside the road: the ribbon never climbs it
	var r := TerrainShape.ribbons(g)
	var bands: Dictionary = r.bands
	ok(not bands.is_empty() and not (r.edges as Dictionary).is_empty(), "a road gets a ribbon and its two edges")
	ok(not bands.has(Vector2i(3, 3)), "only on ground at the road's level")
	for c: Vector2i in bands:
		for poly: PackedVector2Array in bands[c]:
			for p in poly:
				ok(p.x >= c.x - 0.001 and p.x <= c.x + 1.001 and p.y >= c.y - 0.001 and p.y <= c.y + 1.001, "each piece stays in its cell")
	for c in [Vector2i(2, 2), Vector2i(4, 2), Vector2i(6, 4)]:
		var centre := Vector2(c) + Vector2(0.5, 0.5)
		ok((bands.get(c, []) as Array).any(func(poly: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(centre, poly)),
			"the ribbon runs through road cell %s" % c)
	var corner := Vector2(6.5, 2.5)
	ok(not (bands.get(Vector2i(6, 2), []) as Array).any(func(poly: PackedVector2Array) -> bool:
		return Geometry2D.is_point_in_polygon(corner + Vector2(0.4, -0.4), poly)), "it rounds the corner instead of filling it square")

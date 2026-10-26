extends TestCase
## World map layout and discovery.


func _world() -> WorldMap:
	return WorldMap.load_default(1)


func test_route_spans_the_trail() -> void:
	var w := _world()
	eq(w.route_length(), float(RunState.GOAL), "route d ends at the trail goal")
	eq(w.route_point(0), w.landmark("village").pos, "route starts at the village")
	eq(w.route_point(RunState.GOAL), w.landmark("end").pos, "route ends at the end mark")
	ok(w.route_point(RunState.WALL).distance_to(w.landmark("gate").pos) < 1.0, "the Wall gate sits at the Wall league")


func test_wall_splits_the_route() -> void:
	var w := _world()
	for d in range(0, RunState.GOAL + 1, 5):
		var east := w.is_east(w.route_point(d))
		if d < RunState.WALL - 5:
			ok(not east, "league %d is home side" % d)
		elif d > RunState.WALL + 5:
			ok(east, "league %d is past the Wall" % d)


func test_strangeness_follows_the_route() -> void:
	var w := _world()
	for d in range(0, RunState.GOAL + 1, 10):
		var expect := float(d) / RunState.GOAL
		var got := w.strangeness_at(w.route_point(d))
		ok(absf(got - expect) <= 0.25, "league %d: map strangeness %.2f vs trail %.2f" % [d, got, expect])
	eq(w.strangeness_at(w.landmark("village").pos), 0.0, "village is home")
	eq(w.strangeness_at(w.landmark("end").pos), 1.0, "end is deepest")


func test_regions_never_cross_the_wall() -> void:
	var w := _world()
	for y in range(10, 1080, 37):
		for x in range(10, 1920, 41):
			var p := Vector2(x, y)
			ok(w.region_at(p).east == w.is_east(p), "region side at %s" % p)


func test_regions_valid() -> void:
	var w := _world()
	var kinds := MapPainter.DENSITY.keys()
	var keys := {}
	for row in CsvTable.load_rows("res://text/placeholder.csv"):
		keys[row["keys"]] = true
	ok(w.regions.size() <= WorldMap.MAX_REGIONS, "fits the ground shader's uniform arrays")
	for r in w.regions:
		ok(kinds.has(r.kind), "%s kind %s" % [r.id, r.kind])
		ok(r.name_key == "" or keys.has(r.name_key), "%s name key" % r.id)
	for l in w.landmarks:
		ok(l.name_key == "" or keys.has(l.name_key), "%s name key" % l.id)


func test_same_seed_same_map() -> void:
	var a := WorldMap.load_default(5)
	var b := WorldMap.load_default(5)
	eq(a.phase, b.phase)
	ok(a.phase != WorldMap.load_default(6).phase, "seed changes the borders")


func test_discovery_starts_at_village() -> void:
	var w := _world()
	var c := Discovery.start(w)
	ok(Discovery.has(c, w.landmark("village").pos), "village known")
	ok(Discovery.has(c, w.landmark("village").pos + Vector2(100, 0)), "a few miles around it known")
	ok(not Discovery.has(c, w.landmark("gate").pos), "the Wall unknown")
	ok(Discovery.known_fraction(c) < 0.05, "most of the map is hidden")


func test_walking_reveals_the_route() -> void:
	var w := _world()
	var c := Discovery.start(w)
	ok(Discovery.reveal_route(c, w, 160), "walking past the Wall reveals new ground")
	ok(Discovery.has(c, w.landmark("gate").pos), "the gate is known")
	ok(not Discovery.has(c, w.landmark("end").pos), "the end is still hidden")
	var n := c.size()
	ok(not Discovery.reveal_route(c, w, 100), "walking known ground reveals nothing new")
	eq(c.size(), n)
	Discovery.reveal_route(c, w, RunState.GOAL)
	ok(c.size() <= Discovery.MAX_CIRCLES, "fits the fog shader")
	ok(Discovery.has(c, w.landmark("end").pos))

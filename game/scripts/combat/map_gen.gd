class_name MapGen
extends RefCounted
## One-click maps for the map maker, built only from MapOps calls so the result is an ordinary map to
## keep editing. `valley` makes a terraced valley like Brandon's reference: high ground at the back, a
## river that falls down the terraces toward the front, stairs wherever a climb is needed, roads along the
## easiest walk, pines and boulders on the terraces, rock pillars on the rims and a ragged outline. It keeps
## the authoring rules for the painted look (docs/design/map-look.md section 7): edges step two cells at a
## time (V9), pillars (V10), rivers that fall in a few big drops (V11). Same seed, same map.

const LEVELS: Array[int] = [0, 3, 6, 8]  ## terrace heights: two or three levels apart, so every step is a cliff


## Scale C ([USER] 2026-10-30, dev-scale-c-test: "this feels right"): a fight area is 21 x 18, a start gap of 18.
## Road fights and new maps come out at this size; docs/design/scale-study.md.
const FIGHT_W := 21
const FIGHT_H := 18


## A road fight's map ([USER] 2026-11-01 battle-maps plan): from one of the region's plots (data/plots/<region>, MapPlot)
## when it has any, picked and varied by the seed; a map that fails the checks tries the next seed (up to 8), and a
## region with no plots (or no plot that holds) falls back to the generated valley.
static func road_fight(seed_value: int, region: String, w := FIGHT_W, h := FIGHT_H) -> CombatGrid:
	var plots := MapPlot.list(region, false)
	for k in 8 if not plots.is_empty() else 0:
		var sd := seed_value + k * 7919
		var g := MapPlot.build(plots[posmod(sd, plots.size())], sd, region)
		if g.deploy_cells(0).size() >= CombatGrid.DEPLOY_MIN and g.deploy_cells(1).size() >= CombatGrid.DEPLOY_MIN \
				and MapOps.walk_steps(g, g.deploy_cells(0)[0]).has(g.deploy_cells(1)[0]):
			return g
	return valley(seed_value, w, h, region)


## [USER] 2026-11-01 battle-maps plan, step 1 (docs/design/battle-maps-research.md): the river has a job and the road
## comes first. A "flank" river (the default) runs along one side, parallel to the road, so it never splits the two
## starts; a "crossing" river cuts between them and the road crosses it on exactly one bridge, laid where the road
## meets the water. No other crossings: the generator never invents a ford or a second bridge.
const RIVER_JOBS := ["flank", "crossing"]

static func valley(seed_value: int, w := FIGHT_W, h := FIGHT_H, look_id := "alpine", river_job := "flank") -> CombatGrid:
	var g := CombatGrid.flat(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_terraces(g, seed_value)
	MapOps.roughen(g, seed_value + 3, 0.55)
	MapOps.tidy(g)
	MapOps.keep_largest(g)
	if river_job == "crossing":
		_river(g, rng)
	else:
		_river_flank(g, rng)
	_dress(g, seed_value, rng)
	MapOps.link(g, seed_value + 5, 1, false)  # stairs, and bridges over dry gaps only: the river's one bridge comes next
	if river_job == "crossing":
		_road_bridge(g)  # the one bridge, where the road's line meets the river
	MapOps.pillars(g, seed_value + 9, clampi(w * h / 160, 2, 4))
	MapOps.flatten_dead_stairs(g)
	MapOps.seal_unreachable(g)
	_roads(g, rng)
	g.look = {"id": look_id}
	return g


## A flank river: from the left edge to the right one inside a band of rows along one side (the back or the front),
## so it runs beside the road between the starts and never cuts across it. Straight for two cells before a turn (V9),
## falls of two levels (V11).
static func _river_flank(g: CombatGrid, rng: RandomNumberGenerator) -> void:
	var front := rng.randf() < 0.5
	var lo := 1 if not front else maxi(1, g.h - 4)
	var hi := mini(g.h - 2, lo + 2)
	var c := Vector2i(0, rng.randi_range(lo, hi))
	while c.x < g.w and not g.solid(c):
		c.x += 1
	if c.x >= g.w:
		return
	var path: Array[Vector2i] = [c]
	var seen := {c: true}
	var dir := Vector2i(1, 0)
	var run := 0
	for guard in g.w * 3:
		var pick := Vector2i(-999, -999)
		var pick_s := INF
		for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb := c + d
			if seen.has(nb) or nb.y < lo or nb.y > hi:
				continue
			if not g.solid(nb):
				if d.x > 0:
					pick = nb
					pick_s = -INF
				continue
			var s := g.height_at(nb) * 1.2 - d.x * 2.0 + rng.randf() * 1.4
			if run < 2:
				s += -4.0 if d == dir else 4.0
			if s < pick_s:
				pick_s = s
				pick = nb
		if pick.x == -999 or not g.solid(pick):
			break
		run = run + 1 if pick - c == dir else 1
		dir = pick - c
		path.append(pick)
		seen[pick] = true
		c = pick
	MapOps.river(g, path, 1, 2 if rng.randf() < 0.5 else 1, 2)


## A crossing river's one bridge, where the road would cross ([USER] 2026-11-01: "A bridge exists because a road meets a
## river"): of the places two banks within a level face each other across the water, the one that makes the walk between
## the two starts' ends shortest. None when the river does not split them (the road just goes round).
static func _road_bridge(g: CombatGrid) -> void:
	var ends := _road_ends(g)
	if ends[0].x < 0 or ends[1].x < 0:
		return
	var d0 := MapOps.walk_steps(g, ends[0])
	if d0.has(ends[1]):
		return
	var d1 := MapOps.walk_steps(g, ends[1])
	var best: Array = []
	var best_cost := INF
	for pair: Array in MapOps.river_crossings(g):
		if absi(g.height_at(pair[0]) - g.height_at(pair[1])) > 1:
			continue
		var a: Vector2i = pair[0]
		var b: Vector2i = pair[1]
		var k := absi(b.x - a.x) + absi(b.y - a.y)
		for ab in [[a, b], [b, a]]:
			if d0.has(ab[0]) and d1.has(ab[1]):
				var cost := float(d0[ab[0]]) + float(d1[ab[1]]) + k
				if cost < best_cost:
					best_cost = cost
					best = pair
	if not best.is_empty():
		MapOps.bridge_span(g, best[0], best[1])


## Terraces: low-frequency noise leaning high toward the far corner, cut into LEVELS, then a mode filter
## so the terraces come out as chunky blocks instead of noisy edges, plus the odd one-level ledge.
static func _terraces(g: CombatGrid, seed_value: int) -> void:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = 0.07
	n.fractal_octaves = 2
	var ledge := FastNoiseLite.new()
	ledge.seed = seed_value + 11
	ledge.frequency = 0.18
	var lv := {}
	for y in g.h:
		for x in g.w:
			var v := (n.get_noise_2d(x, y) + 1.0) * 0.5
			var back := 1.0 - float(x + y) / float(g.w + g.h - 2)
			v = v * 0.7 + back * 0.5 - 0.12
			lv[Vector2i(x, y)] = clampi(int(v * LEVELS.size()), 0, LEVELS.size() - 1)
	for _round in 2:
		var next := {}
		for c: Vector2i in lv:
			var count := {}
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var k: Variant = lv.get(c + Vector2i(dx, dy))
					if k != null:
						count[k] = int(count.get(k, 0)) + 1
			var best: int = lv[c]
			for k in count:
				if count[k] > count.get(best, 0):
					best = k
			next[c] = best
		lv = next
	for c: Vector2i in lv:
		var hh: int = LEVELS[lv[c]]
		if ledge.get_noise_2d(c.x, c.y) > 0.5:
			hh += 1
		g.set_height(c, mini(hh, CombatGrid.MAX_HEIGHT))


## A river from high ground at the back, walking downhill (and frontward) until it leaves the map. It keeps
## going straight for at least two cells before it turns, so a slanted course steps instead of zigzagging
## (V9), and falls at least two levels wherever it falls (V11).
static func _river(g: CombatGrid, rng: RandomNumberGenerator) -> void:
	var start := Vector2i(-1, -1)
	var best := -INF
	for y in g.h:
		for x in g.w:
			var c := Vector2i(x, y)
			if not g.solid(c) or x + y > (g.w + g.h) / 3:
				continue
			var score := g.height_at(c) + rng.randf() * 3.0 - absf(x - y) * 0.15
			if score > best:
				best = score
				start = c
	if start.x < 0:
		return
	var path: Array[Vector2i] = [start]
	var seen := {start: true}
	var c := start
	var dir := Vector2i.ZERO
	var run := 0
	for guard in g.w + g.h + 20:
		var pick := Vector2i(-999, -999)
		var pick_s := INF
		for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			var nb := c + d
			if seen.has(nb):
				continue
			if not g.solid(nb):
				if d.x + d.y > 0 and c.x + c.y > (g.w + g.h) / 2:  # off the front half: the river leaves the map
					pick = nb
					pick_s = -INF
				continue
			var s := g.height_at(nb) * 1.5 - (d.x + d.y) * 1.2 + rng.randf() * 1.6
			if dir != Vector2i.ZERO and run < 2:  # straight on for at least two cells
				s += -4.0 if d == dir else 4.0
			if s < pick_s:
				pick_s = s
				pick = nb
		if pick.x == -999 or not g.solid(pick):
			break
		run = run + 1 if pick - c == dir else 1
		dir = pick - c
		path.append(pick)
		seen[pick] = true
		c = pick
	MapOps.river(g, path, 1, 2 if rng.randf() < 0.5 else 1, 2)


## Pine woods in clumps on the terraces, boulders on some rims.
static func _dress(g: CombatGrid, seed_value: int, rng: RandomNumberGenerator) -> void:
	var n := FastNoiseLite.new()
	n.seed = seed_value + 29
	n.frequency = 0.2
	for y in g.h:
		for x in g.w:
			var c := Vector2i(x, y)
			if g.terrain_at(c) != CombatGrid.T.GRASS:
				continue
			var rim := false
			for d: Vector2i in CombatRules.DIRS:
				if not g.solid(c + d) or g.height_at(c + d) <= g.height_at(c) - 2:
					rim = true
			var v := n.get_noise_2d(x, y)
			if v > 0.38 or (rim and v > 0.25):
				g.set_terrain(c, CombatGrid.T.FOREST)
			elif rim and rng.randf() < 0.07:
				g.set_terrain(c, CombatGrid.T.ROCK)


## A road from the left side of the map to the right, the easiest walk between them.
## The road between the two starts' sides (the party deploys on the low-x columns, the foes on the high-x ones): from the
## middle-most open cell of the first column to that of the last, over the bridge if a crossing river has one.
static func _roads(g: CombatGrid, _rng: RandomNumberGenerator) -> void:
	var ends := _road_ends(g)
	if ends[0].x >= 0 and ends[1].x >= 0:
		MapOps.road(g, ends[0], ends[1])


static func _road_ends(g: CombatGrid) -> Array[Vector2i]:
	var ends: Array[Vector2i] = []
	for xs in [range(g.w), range(g.w - 1, -1, -1)]:
		var got := Vector2i(-1, -1)
		for x in xs:
			var rows := range(g.h)
			rows.sort_custom(func(p: int, q: int) -> bool: return absf(p - (g.h - 1) * 0.5) < absf(q - (g.h - 1) * 0.5))
			for y in rows:
				var c := Vector2i(x, y)
				if g.passable(c) and g.terrain_at(c) != CombatGrid.T.STAIRS:
					got = c
					break
			if got.x >= 0:
				break
		ends.append(got)
	return ends

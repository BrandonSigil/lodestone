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


static func valley(seed_value: int, w := FIGHT_W, h := FIGHT_H, look_id := "alpine") -> CombatGrid:
	var g := CombatGrid.flat(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_terraces(g, seed_value)
	MapOps.roughen(g, seed_value + 3, 0.55)
	MapOps.tidy(g)
	MapOps.keep_largest(g)
	_river(g, rng)
	_dress(g, seed_value, rng)
	MapOps.link(g, seed_value + 5)
	MapOps.pillars(g, seed_value + 9, clampi(w * h / 160, 2, 4))
	MapOps.seal_unreachable(g)
	_roads(g, rng)
	g.look = {"id": look_id}
	return g


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
static func _roads(g: CombatGrid, rng: RandomNumberGenerator) -> void:
	var a := Vector2i(-1, -1)
	var b := Vector2i(-1, -1)
	for y in g.h:
		for x in g.w:
			var c := Vector2i(x, y)
			if not g.passable(c) or g.terrain_at(c) == CombatGrid.T.WATER:
				continue
			var side := y - x  # high = screen left at the starting view
			if a.x < 0 or side > a.y - a.x:
				a = c
			if b.x < 0 or side < b.y - b.x:
				b = c
	if a.x >= 0 and b.x >= 0 and rng.randf() < 0.85:
		MapOps.road(g, a, b)

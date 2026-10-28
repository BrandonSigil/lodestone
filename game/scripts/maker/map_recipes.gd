class_name MapRecipes
extends RefCounted
## Hand-laid maps written as a few lines of map maker work (the same MapOps the brushes use), so a layout
## can be rebuilt, tweaked and checked in code. The map maker opens them from its template list and
## tools/map_build.gd saves them to data/maps.
## Regions are placed in screen terms for the default view: u runs from the left of the screen (-1) to the
## right (1), v from the back of the map (0) to the front (1).

const T := CombatGrid.T


static func names() -> Array[String]:
	return ["highland"]


static func build(recipe: String) -> CombatGrid:
	match recipe:
		"highland":
			return highland()
	return null


## Cell at screen position (u, v) on an n x n map.
static func cell(n: int, u: float, v: float) -> Vector2i:
	var s := float(n - 1)
	return Vector2i(roundi(s * (v + u * 0.5)), roundi(s * (v - u * 0.5)))


static func uv(n: int, c: Vector2i) -> Vector2:
	var s := float(n - 1)
	return Vector2((c.x - c.y) / s, (c.x + c.y) / (2.0 * s))


## A path through screen waypoints, as 4-connected cells.
static func path(n: int, points: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in points.size() - 1:
		var a := cell(n, points[i].x, points[i].y)
		var b := cell(n, points[i + 1].x, points[i + 1].y)
		var seg := MapOps.line(a, b)
		for c in seg.slice(1 if i > 0 else 0):
			out.append(c)
	return out


## The reference layout (docs/design/map-look.md): a meadow in the middle with a crossroads, high
## plateaus behind and to the right, a lower terrace on the left behind a gorge, two terraces in front, a
## low river along the front, and three waterfalls: the left gorge, the right plateau's big drop and the
## meadow's stream falling off the front cliff.
static func highland() -> CombatGrid:
	var n := 26
	var g := CombatGrid.flat(n, n)
	var wob := FastNoiseLite.new()
	wob.seed = 11
	wob.frequency = 0.16
	for y in n:
		for x in n:
			var c := Vector2i(x, y)
			var p := uv(n, c)
			var w := wob.get_noise_2d(x, y) * 0.07
			var u := p.x + w
			var v := p.y - w
			if v < 0.12 or v > 0.93 or absf(u) > 0.9 - maxf(0.0, v - 0.75) * 1.2:
				g.set_terrain(c, T.VOID)
				continue
			g.set_height(c, _highland_h(u, v))

	# Rivers: the left gorge from the knoll behind, the right plateau's stream, the meadow stream, and the
	# low river along the front that takes them all off the map.
	MapOps.river(g, path(n, [Vector2(0.62, 0.95), Vector2(0.62, 0.86), Vector2(0.0, 0.84), Vector2(-0.62, 0.86), Vector2(-0.68, 0.95)]), 1, 2)
	MapOps.river(g, path(n, [Vector2(-0.04, 0.13), Vector2(-0.04, 0.27), Vector2(-0.3, 0.36), Vector2(-0.47, 0.44), Vector2(-0.47, 0.62), Vector2(-0.42, 0.84)]), 2, 2)
	MapOps.river(g, path(n, [Vector2(0.66, 0.22), Vector2(0.64, 0.42), Vector2(0.56, 0.6), Vector2(0.48, 0.72), Vector2(0.46, 0.85)]), 1, 2)
	MapOps.river(g, path(n, [Vector2(0.06, 0.52), Vector2(0.1, 0.66), Vector2(0.12, 0.84)]), 1, 1)

	# Ways up: a flight from the meadow to the plateau behind, one to the right plateau, steps down to each
	# front terrace, and a stone bridge over the gorge to the left terrace.
	MapOps.flight(g, cell(n, -0.12, 0.42), cell(n, -0.12, 0.27))
	MapOps.flight(g, cell(n, 0.3, 0.5), cell(n, 0.5, 0.42))
	MapOps.flight(g, cell(n, -0.32, 0.6), cell(n, -0.32, 0.72))
	MapOps.flight(g, cell(n, 0.26, 0.6), cell(n, 0.34, 0.7))
	var crossed := false
	var span := cell(n, -0.36, 0.52)
	for k in 12:  # along the grid's x axis (up and left on screen) until the far bank
		var c := span + Vector2i(-k, 0)
		if not g.solid(c):
			break
		if g.terrain_at(c) == T.WATER:
			crossed = true
		elif crossed:
			break
		g.set_terrain(c, T.STONE)
		g.set_height(c, 4 if crossed else 5)

	# Ground cover: pines on the high ground and the left terrace, scattered on the front terraces.
	var trees := FastNoiseLite.new()
	trees.seed = 5
	trees.frequency = 0.22
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for y in n:
		for x in n:
			var c := Vector2i(x, y)
			if g.terrain_at(c) != T.GRASS:
				continue
			var h := g.height_at(c)
			var f := trees.get_noise_2d(x, y)
			if (h >= 7 and f > 0.05) or (h == 4 and f > 0.15) or (h == 3 and f > 0.3) or (h == 5 and f > 0.55):
				g.set_terrain(c, T.FOREST)

	# Roads: a crossroads on the meadow joining the left terrace, the plateau behind and the right plateau.
	var hub := cell(n, 0.0, 0.5)
	for to in [cell(n, -0.74, 0.5), cell(n, -0.12, 0.2), cell(n, 0.7, 0.36), cell(n, -0.34, 0.76)]:
		MapOps.road(g, hub, to)

	# Boulders along the rims, like the standing stones of the reference.
	for y in n:
		for x in n:
			var c := Vector2i(x, y)
			if g.terrain_at(c) not in [T.GRASS, T.FOREST] or rng.randf() > 0.12:
				continue
			var drop := 0
			for d: Vector2i in CombatRules.DIRS:
				if g.solid(c + d):
					drop = maxi(drop, g.height_at(c) - g.height_at(c + d))
				else:
					drop = maxi(drop, 3)
			if drop >= 3:
				g.set_terrain(c, T.ROCK)

	MapOps.link(g, 7)
	# Scraps of high ground the rivers cut off become part of the drop (water in the gorges may stay out of
	# reach: it is a chasm, not a place to stand).
	var main := MapOps.reach(g, hub, 1)
	for y in n:
		for x in n:
			var c := Vector2i(x, y)
			if g.passable(c) and g.terrain_at(c) != T.WATER and not main.has(c):
				g.set_terrain(c, T.VOID)
	g.look = {"id": "alpine"}
	return g


static func _highland_h(u: float, v: float) -> int:
	if v < 0.3:
		return 8
	if u < -0.46 and v < 0.7:
		return 4
	if u > 0.42 and v < 0.62:
		return 8
	if v > 0.76:
		return 1
	if v > 0.64 and (u < -0.2 or u > 0.3):
		return 3
	return 6


## Builds a recipe and saves it as a battle map in data/maps with the given tile set. Returns the path.
static func save(recipe: String, art_set := "alpine") -> String:
	var g := build(recipe)
	if g == null:
		return ""
	return MapDoc.create("battle", recipe, g, art_set).save()

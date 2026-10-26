class_name Discovery
extends RefCounted
## What the player has unearthed on the world map: a list of revealed circles [x, y, radius]
## in map units. Kept in Game.meta.revealed so it survives a Lodestone recall.
## The map shows everything for now; the fog shader reads these circles when fog is turned on.

const START_RADIUS := 170.0  ## the village and the few miles around it
const ROUTE_RADIUS := 95.0  ## how far either side of the route a walk reveals
const ROUTE_STEP := 10  ## leagues between revealed circles along the route
const MAX_CIRCLES := 128  ## the fog shader's uniform array size


static func start(world: WorldMap) -> Array:
	var p := world.start_pos()
	return [[p.x, p.y, START_RADIUS]]


static func has(circles: Array, p: Vector2) -> bool:
	for c in circles:
		if p.distance_to(Vector2(c[0], c[1])) <= c[2]:
			return true
	return false


## Adds a circle unless an existing one already covers it. Returns true if anything changed.
static func reveal(circles: Array, p: Vector2, radius: float) -> bool:
	for c in circles:
		if p.distance_to(Vector2(c[0], c[1])) + radius <= c[2]:
			return false
	if circles.size() >= MAX_CIRCLES:
		return false
	circles.append([p.x, p.y, radius])
	return true


## Reveals the route up to `distance` leagues.
static func reveal_route(circles: Array, world: WorldMap, distance: int) -> bool:
	var changed := false
	var d := 0
	while d <= mini(distance, int(world.route_length())):
		changed = reveal(circles, world.route_point(d), ROUTE_RADIUS) or changed
		d += ROUTE_STEP
	return changed


## Share of the map revealed, 0 to 1, sampled on a coarse grid.
static func known_fraction(circles: Array) -> float:
	var hits := 0
	var n := 0
	for y in range(20, int(WorldMap.SIZE.y), 40):
		for x in range(20, int(WorldMap.SIZE.x), 40):
			n += 1
			if has(circles, Vector2(x, y)):
				hits += 1
	return float(hits) / n

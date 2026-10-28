class_name MapDress
extends RefCounted
## Pure rules that dress a map's raw heights and terrain for drawing: the forest skirt around the outline,
## the drip profile of grass lips and the run of a stair. No drawing here, so tests can run it headless.
## Design: docs/design/map-look.md.

const LIP_TEETH := 3  ## drips along one cell edge


## Cells around the playable ground (holes inside it too), out to `rings` steps (diagonals count as one):
## cell -> {"ring": 1.., "src": the ground cell it was reached from}. Includes cells outside the grid.
static func skirt(grid: CombatGrid, rings: int) -> Dictionary:
	var out := {}
	if rings <= 0:
		return out
	var dist := {}
	var src := {}
	var queue: Array[Vector2i] = []
	for y in grid.h:
		for x in grid.w:
			var c := Vector2i(x, y)
			if grid.solid(c):
				dist[c] = 0
				src[c] = c
				queue.append(c)
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		var dc: int = dist[c]
		if dc >= rings:
			continue
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n := c + Vector2i(dx, dy)
				if dist.has(n) or n.x < -rings or n.y < -rings or n.x >= grid.w + rings or n.y >= grid.h + rings:
					continue
				dist[n] = dc + 1
				src[n] = src[c]
				queue.append(n)
				out[n] = {"ring": dc + 1, "src": src[c]}
	return out


## The bottom edge of a lip hanging from the grid edge a..b: [[grid point, depth in levels], ...] from a to b.
## Shallow notches alternate with drips, now and then a long one. The pattern is a function of the world
## position only, so neighbouring cells line up, and both ends sit at the same depth so corners meet.
## Never deeper than the drop allows; [] when the drop is too small to show a lip.
static func lip_profile(a: Vector2, b: Vector2, depth: float, drop: float) -> Array:
	var room := drop - 0.06
	if room < 0.12 or depth <= 0.0:
		return []
	var out := []
	var m := LIP_TEETH * 2
	for k in m + 1:
		var f := float(k) / m
		var r := noise(a.lerp(b, f))
		var dd := depth * 0.38
		if k > 0 and k < m:
			if k % 2 == 0:
				dd = depth * (0.34 + 0.18 * r)
			else:
				f += (r - 0.5) * 0.6 / m
				dd = depth * (0.75 + 0.4 * r) * (1.5 if r > 0.8 else 1.0)
		out.append([a.lerp(b, f), minf(dd, room)])
	return out


## 0..1, fixed for a world point.
static func noise(g: Vector2) -> float:
	var x := roundi(g.x * 48.0)
	var y := roundi(g.y * 48.0)
	return float(absi((x * 73856093) ^ (y * 19349663) ^ 83492791) % 10007) / 10007.0


## How a stair cell climbs: {"up": direction of the high side, "lo": height at its low edge, "hi": at its
## high edge}, centred on the cell's own height so a piece standing on it is mid-flight.
## {} when no walkable neighbour is higher or lower (a flat landing).
static func stair_run(grid: CombatGrid, c: Vector2i) -> Dictionary:
	var h := float(grid.height_at(c))
	var low := h
	var high := h
	var down := Vector2i.ZERO
	var up := Vector2i.ZERO
	for d: Vector2i in CombatRules.DIRS:
		var n := c + d
		if not grid.solid(n) or not grid.passable(n):
			continue
		var nh := float(grid.height_at(n))
		if nh < low:
			low = nh
			down = d
		if nh > high:
			high = nh
			up = d
	if up == Vector2i.ZERO and down == Vector2i.ZERO:
		return {}
	if up == Vector2i.ZERO:
		up = -down
	return {"up": up, "lo": h - minf(h - low, 2.0) * 0.5, "hi": h + minf(high - h, 2.0) * 0.5}

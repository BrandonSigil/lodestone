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
## It climbs along one axis: the one its flight carries on along (stair neighbours), else the one with the
## biggest change in height, so every step of a flight runs the same way (a step picking its highest and
## lowest neighbours separately could climb sideways across the flight and leave a hole beside it).
## {} when nothing walkable along that axis is higher or lower (a flat landing).
static func stair_run(grid: CombatGrid, c: Vector2i) -> Dictionary:
	var h := float(grid.height_at(c))
	var best := Vector2i.ZERO
	var best_score := 0.0
	for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
		var score := 0.0
		for e: Vector2i in [d, -d]:
			var n := c + e
			if not grid.solid(n) or not grid.passable(n):
				continue
			if grid.terrain_at(n) == CombatGrid.T.STAIRS:
				score += 100.0
			score += absf(float(grid.height_at(n)) - h)
		if score > best_score:
			best_score = score
			best = d
	if best == Vector2i.ZERO:
		return {}
	var hp := _walk_height(grid, c + best, h)
	var hm := _walk_height(grid, c - best, h)
	var up := best if hp >= hm else -best
	var high := maxf(hp, hm)
	var low := minf(hp, hm)
	var lo := h - minf(maxf(h - low, 0.0), 2.0) * 0.5
	var hi := h + minf(maxf(high - h, 0.0), 2.0) * 0.5
	if is_equal_approx(lo, hi):
		return {}
	return {"up": up, "lo": lo, "hi": hi}


## A neighbour's height for a stair, or the stair's own when it can't be walked onto.
static func _walk_height(grid: CombatGrid, n: Vector2i, own: float) -> float:
	return float(grid.height_at(n)) if grid.solid(n) and grid.passable(n) else own

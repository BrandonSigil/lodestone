class_name MapOps
extends RefCounted
## Map maker operations on a CombatGrid: what the editor's tools do, and what generators and builder
## scripts call. Pure (no drawing), so tests can run them. Design: docs/design/map-look.md.

const T := CombatGrid.T


## The cells a brush covers around c: a diamond (radius in steps) or a square, inside the grid.
static func brush(grid: CombatGrid, c: Vector2i, radius: int, square := false) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if not square and absi(dx) + absi(dy) > radius:
				continue
			var n := c + Vector2i(dx, dy)
			if grid.in_bounds(n):
				out.append(n)
	return out


## Every cell on the straight line from a to b (4-connected, so a drag never skips a cell).
static func line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = [a]
	var c := a
	while c != b:
		var d := b - c
		if absi(d.x) >= absi(d.y):
			c.x += signi(d.x)
		else:
			c.y += signi(d.y)
		out.append(c)
	return out


## Raise or lower ground (holes stay holes), clamped to the editor's range.
static func raise(grid: CombatGrid, cells: Array[Vector2i], dh: int) -> void:
	for c in cells:
		if grid.solid(c):
			grid.set_height(c, clampi(grid.height_at(c) + dh, 0, CombatGrid.MAX_HEIGHT))


## Set ground to one height: a terrace or plateau. Holes become grass at that height.
static func level(grid: CombatGrid, cells: Array[Vector2i], h: int) -> void:
	for c in cells:
		if not grid.solid(c):
			grid.set_terrain(c, T.GRASS)
		grid.set_height(c, clampi(h, 0, CombatGrid.MAX_HEIGHT))


## Paint a terrain on ground cells (holes stay holes; use fill first).
static func paint(grid: CombatGrid, cells: Array[Vector2i], t: int) -> void:
	for c in cells:
		if grid.solid(c):
			grid.set_terrain(c, t)


## Cut cells out of the map (the outline, or a pit). Placed props standing on them go too.
static func cut(grid: CombatGrid, cells: Array[Vector2i]) -> void:
	for c in cells:
		var a := grid.prop_anchor(c)
		if a != CombatGrid.NONE_CELL:
			remove_prop(grid, a)
		grid.set_terrain(c, T.VOID)


## Give holes ground again: grass at h, or (h < 0) at the height of the highest ground next to them.
static func fill(grid: CombatGrid, cells: Array[Vector2i], h := -1) -> void:
	for c in cells:
		if grid.solid(c):
			continue
		var lvl := h
		if lvl < 0:
			lvl = 0
			for d: Vector2i in CombatRules.DIRS:
				if grid.solid(c + d):
					lvl = maxi(lvl, grid.height_at(c + d))
		grid.set_terrain(c, T.GRASS)
		grid.set_height(c, lvl)


## A river along a path: water dug `depth` levels below the ground, never flowing uphill, so every place
## the ground steps down becomes a waterfall. width 2 also floods the cell beside each step.
## A path that runs off the ground stops there (the river leaves the map).
static func river(grid: CombatGrid, path: Array[Vector2i], depth := 1, width := 1) -> void:
	var lvl := CombatGrid.MAX_HEIGHT
	var prev := Vector2i(-999, -999)
	for c in path:
		if not grid.solid(c):
			if prev.x > -999:
				break
			continue
		lvl = mini(lvl, maxi(0, grid.height_at(c) - depth)) if grid.terrain_at(c) != T.WATER else mini(lvl, grid.height_at(c))
		var cells: Array[Vector2i] = [c]
		if width > 1 and prev.x > -999:
			var d := c - prev
			var side := c + Vector2i(-d.y, d.x)
			if grid.solid(side):
				cells.append(side)
		for w in cells:
			var a := grid.prop_anchor(w)
			if a != CombatGrid.NONE_CELL:
				remove_prop(grid, a)
			grid.set_terrain(w, T.WATER)
			grid.set_height(w, lvl)
		prev = c


## Stairs on c, set at the height that joins its lowest and highest walkable neighbours (the steepest pair
## on one axis), so a jump-1 piece can climb the flight. Returns false when c has no slope to bridge.
static func stairs(grid: CombatGrid, c: Vector2i) -> bool:
	if not grid.solid(c):
		return false
	var best := -1
	var lo := 0
	var hi := 0
	for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
		var a := c + d
		var b := c - d
		var ha := _walk_h(grid, a, grid.height_at(c))
		var hb := _walk_h(grid, b, grid.height_at(c))
		if absi(ha - hb) > best:
			best = absi(ha - hb)
			lo = mini(ha, hb)
			hi = maxi(ha, hb)
	if best <= 0:
		return false
	grid.set_terrain(c, T.STAIRS)
	grid.set_height(c, clampi((lo + hi) / 2, lo, hi))
	return true


static func _walk_h(grid: CombatGrid, c: Vector2i, fallback: int) -> int:
	return grid.height_at(c) if grid.solid(c) and grid.terrain_at(c) != T.ROCK and grid.terrain_at(c) != T.RUIN else fallback


## A flight of stairs from a (bottom) to b (top) in a straight line: the cells between take heights stepping
## evenly from a's height to b's, so a cliff of any height becomes climbable.
static func flight(grid: CombatGrid, a: Vector2i, b: Vector2i) -> void:
	var cells := line(a, b)
	if cells.size() < 3:
		stairs(grid, cells[cells.size() - 1] if cells.size() > 1 else a)
		return
	var ha := grid.height_at(a)
	var hb := grid.height_at(b)
	for i in range(1, cells.size() - 1):
		var c: Vector2i = cells[i]
		if not grid.solid(c):
			grid.set_terrain(c, T.GRASS)
		grid.set_terrain(c, T.STAIRS)
		grid.set_height(c, roundi(lerpf(ha, hb, float(i) / (cells.size() - 1))))


## Place a prop (a sprite stem from the tile set) with its footprint, replacing any it overlaps.
static func add_prop(grid: CombatGrid, anchor: Vector2i, sprite: String, foot := Vector2i.ONE, tall := 0.9, sight := 1.0, walk := false, extra := {}) -> void:
	for dy in foot.y:
		for dx in foot.x:
			var a := grid.prop_anchor(anchor + Vector2i(dx, dy))
			if a != CombatGrid.NONE_CELL:
				remove_prop(grid, a)
	grid.add_prop(anchor, sprite, foot, tall, sight, walk, extra)


## Soften ground: each cell takes the rounded mean height of itself and its ground neighbours.
## Water, stairs and holes keep their height (they would break rivers and flights).
static func smooth(grid: CombatGrid, cells: Array[Vector2i]) -> void:
	var want := {}
	for c in cells:
		if not grid.solid(c) or grid.terrain_at(c) == T.WATER or grid.terrain_at(c) == T.STAIRS:
			continue
		var sum := grid.height_at(c)
		var n := 1
		for d: Vector2i in CombatRules.DIRS:
			if grid.solid(c + d) and grid.terrain_at(c + d) != T.WATER:
				sum += grid.height_at(c + d)
				n += 1
		want[c] = roundi(float(sum) / n)
	for c: Vector2i in want:
		grid.set_height(c, want[c])


## A path (road, paved stone) along a dragged course, `width` cells wide. Where the course climbs more
## than one level between two cells, stairs are cut so the path stays walkable. Water and holes are
## left alone (a path stops at a river; bridge it with STONE). Returns the cells painted.
static func path(grid: CombatGrid, course: Array[Vector2i], t: int, width := 1) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var seen := {}
	for i in course.size():
		var c: Vector2i = course[i]
		for p in brush(grid, c, width - 1):
			if seen.has(p) or not grid.solid(p):
				continue
			var pt := grid.terrain_at(p)
			if pt == T.WATER or pt == T.STAIRS:
				continue
			seen[p] = true
			var a := grid.prop_anchor(p)
			if a != CombatGrid.NONE_CELL:
				remove_prop(grid, a)
			grid.set_terrain(p, t)
			out.append(p)
		if i > 0 and grid.solid(c) and grid.solid(course[i - 1]):
			var lo: Vector2i = course[i - 1]
			if absi(grid.height_at(c) - grid.height_at(lo)) > 1 and grid.terrain_at(c) != T.WATER:
				stairs(grid, c if grid.height_at(c) < grid.height_at(lo) else lo)
	return out


static func remove_prop(grid: CombatGrid, anchor: Vector2i) -> void:
	grid.remove_prop(anchor)


## Roughen a map's outline: ground near the rectangle's edge is cut where noise says so (more the closer
## to the edge), then any ground left cut off from the main piece goes too. Cells in `keep` stay.
static func roughen(grid: CombatGrid, seed_value: int, amount := 0.5, keep := {}) -> void:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = 0.22
	var cut_cells: Array[Vector2i] = []
	for y in grid.h:
		for x in grid.w:
			var c := Vector2i(x, y)
			if keep.has(c) or not grid.solid(c):
				continue
			var edge := mini(mini(x, y), mini(grid.w - 1 - x, grid.h - 1 - y))
			if edge > 2:
				continue
			var v := (n.get_noise_2d(x, y) + 1.0) * 0.5
			if v < amount * (1.0 - edge * 0.33):
				cut_cells.append(c)
	cut(grid, cut_cells)
	keep_largest(grid)


## Keep only the biggest piece of connected ground; smaller islands become holes.
static func keep_largest(grid: CombatGrid) -> void:
	var seen := {}
	var best: Array[Vector2i] = []
	for y in grid.h:
		for x in grid.w:
			var s := Vector2i(x, y)
			if seen.has(s) or not grid.solid(s):
				continue
			var piece: Array[Vector2i] = [s]
			seen[s] = true
			var i := 0
			while i < piece.size():
				var c: Vector2i = piece[i]
				i += 1
				for d: Vector2i in CombatRules.DIRS:
					var nb := c + d
					if grid.solid(nb) and not seen.has(nb):
						seen[nb] = true
						piece.append(nb)
			if piece.size() > best.size():
				best = piece
	var keep := {}
	for c in best:
		keep[c] = true
	var gone: Array[Vector2i] = []
	for y in grid.h:
		for x in grid.w:
			var c := Vector2i(x, y)
			if grid.solid(c) and not keep.has(c):
				gone.append(c)
	cut(grid, gone)


## Cells a piece with this Jump can walk to from `from` (stairs help, as in combat).
static func reach(grid: CombatGrid, from: Vector2i, jump := 1) -> Dictionary:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	var i := 0
	while i < queue.size():
		var c: Vector2i = queue[i]
		i += 1
		for d: Vector2i in CombatRules.DIRS:
			var nb := c + d
			if not seen.has(nb) and grid.passable(nb) and grid.can_step(c, nb, jump):
				seen[nb] = true
				queue.append(nb)
	return seen


## Join every walkable part of the map to the biggest one with stairs, where the climb is 4 levels or less
## (a 4-level step gets its stair raised one). Returns how many stairs it placed.
static func link(grid: CombatGrid, seed_value: int, jump := 1) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var placed := 0
	for guard in 60:
		var start := _biggest_walk(grid, jump)
		if start.x < 0:
			return placed
		var got := reach(grid, start, jump)
		var options: Array = []
		for c: Vector2i in got:
			for d: Vector2i in CombatRules.DIRS:
				var nb := c + d
				if got.has(nb) or not grid.passable(nb):
					continue
				var diff := absi(grid.height_at(nb) - grid.height_at(c))
				if diff <= 4 and grid.terrain_at(c) != T.WATER and grid.terrain_at(nb) != T.WATER:
					options.append([c, nb, diff])
		if options.is_empty():
			return placed
		var pick: Array = options[rng.randi() % options.size()]
		var a: Vector2i = pick[0]
		var b: Vector2i = pick[1]
		var low := a if grid.height_at(a) < grid.height_at(b) else b
		var high := b if low == a else a
		grid.set_terrain(low, T.STAIRS)
		if pick[2] == 4:
			grid.set_height(low, grid.height_at(low) + 1)
		if grid.terrain_at(high) == T.FOREST:
			grid.set_terrain(high, T.GRASS)
		placed += 1
		if _all_walkable_reached(grid, reach(grid, start, jump)):
			return placed
	return placed


static func _biggest_walk(grid: CombatGrid, jump: int) -> Vector2i:
	var seen := {}
	var best := Vector2i(-1, -1)
	var best_n := 0
	for y in grid.h:
		for x in grid.w:
			var c := Vector2i(x, y)
			if seen.has(c) or not grid.passable(c):
				continue
			var got := reach(grid, c, jump)
			for k in got:
				seen[k] = true
			if got.size() > best_n:
				best_n = got.size()
				best = c
	return best


static func _all_walkable_reached(grid: CombatGrid, got: Dictionary) -> bool:
	for y in grid.h:
		for x in grid.w:
			var c := Vector2i(x, y)
			if grid.passable(c) and not got.has(c):
				return false
	return true


## A road between two cells along the easiest walk (stairs and flat ground preferred, water avoided): the
## path's ground cells become road, its stairs stay stairs.
static func road(grid: CombatGrid, a: Vector2i, b: Vector2i, jump := 1) -> Array[Vector2i]:
	var cost := {a: 0}
	var came := {}
	var open: Array[Vector2i] = [a]
	while not open.is_empty():
		var bi := 0
		for i in open.size():
			if cost[open[i]] < cost[open[bi]]:
				bi = i
		var c: Vector2i = open[bi]
		open.remove_at(bi)
		if c == b:
			break
		for d: Vector2i in CombatRules.DIRS:
			var nb := c + d
			if not grid.passable(nb) or not grid.can_step(c, nb, jump):
				continue
			var step := 1 + (6 if grid.terrain_at(nb) == T.WATER else 0) + (2 if grid.terrain_at(nb) == T.FOREST else 0)
			var nc: int = cost[c] + step
			if not cost.has(nb) or nc < cost[nb]:
				cost[nb] = nc
				came[nb] = c
				if not open.has(nb):
					open.append(nb)
	var path: Array[Vector2i] = []
	if not came.has(b) and a != b:
		return path
	var c := b
	while true:
		path.push_front(c)
		if c == a:
			break
		c = came[c]
	for p in path:
		var t := grid.terrain_at(p)
		if t == T.GRASS or t == T.FOREST:
			grid.set_terrain(p, T.ROAD)
	return path

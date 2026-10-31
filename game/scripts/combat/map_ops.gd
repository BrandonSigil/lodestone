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


## The cells a brush of `size` 1 to 4 covers around c: 1 a cell, 2 a 2 x 2 block (c and the cells right and below),
## 3 a diamond one step out (a 3 x 3 block when square), 4 a 4 x 4 block (its corners off when round).
static func sized(grid: CombatGrid, c: Vector2i, size: int, square := false) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var lo := -((size - 1) / 2)
	var hi := size / 2
	for dy in range(lo, hi + 1):
		for dx in range(lo, hi + 1):
			if not square and size >= 3:
				var far := maxi(absi(dx), absi(dy)) if size == 4 else absi(dx) + absi(dy)
				if size == 3 and far > 1:
					continue
				if size == 4 and (dx == lo or dx == hi) and (dy == lo or dy == hi):
					continue
			var n := c + Vector2i(dx, dy)
			if grid.in_bounds(n):
				out.append(n)
	return out


## The offsets across a line `width` cells wide: 1 -> [0], 2 -> [0, 1], 3 -> [-1, 0, 1], 4 -> [-1, 0, 1, 2].
static func lanes(width: int) -> Array[int]:
	var out: Array[int] = []
	for k in range(-((width - 1) / 2), width / 2 + 1):
		out.append(k)
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


## Every cell from a to b, 4-connected, moving `run` cells along one axis at a time, so a slanted course
## turns in steps two or three cells long instead of zigzagging one cell at a time (rule V9).
static func steps(a: Vector2i, b: Vector2i, run := 2) -> Array[Vector2i]:
	var out: Array[Vector2i] = [a]
	var d := b - a
	var sx := signi(d.x)
	var sy := signi(d.y)
	var c := a
	while c != b:
		var rx := absi(b.x - c.x)
		var ry := absi(b.y - c.y)
		var along_x := ry == 0
		if rx > 0 and ry > 0:  # take the axis that is further behind the straight line
			along_x = float(rx) / absi(d.x) >= float(ry) / absi(d.y)
		var left := rx if along_x else ry
		var n := mini(run, left)
		if left - n == 1:  # never leave a single cell for the end of a run
			n = left
		for i in n:
			c += Vector2i(sx, 0) if along_x else Vector2i(0, sy)
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
## `min_fall`: where the water would step down less than this, it digs deeper and falls this far instead,
## so a river runs level and drops in a few big falls rather than a little every cell (rule V11).
## A path that runs off the ground stops there (the river leaves the map).
static func river(grid: CombatGrid, path: Array[Vector2i], depth := 1, width := 1, min_fall := 1) -> void:
	var lvl := CombatGrid.MAX_HEIGHT
	var prev := Vector2i(-999, -999)
	for c in path:
		if not grid.solid(c):
			if prev.x > -999:
				break
			continue
		var want := mini(lvl, maxi(0, grid.height_at(c) - depth)) if grid.terrain_at(c) != T.WATER else mini(lvl, grid.height_at(c))
		if prev.x > -999 and want < lvl and lvl - want < min_fall:
			want = maxi(0, lvl - min_fall)
		lvl = want
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
static func flight(grid: CombatGrid, a: Vector2i, b: Vector2i, width := 1) -> void:
	if width > 1:  # one stair, `width` cells across: every lane takes the middle lane's even steps, landing flush at both ends
		flight_wide(grid, a, b, width)
		return
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


## A wide flight: b snaps onto a's row or column; each lane across steps by the middle lane's heights, and the cells at
## its two ends (the landings) take the bottom and top heights so the stair meets the ground flush across its width.
static func flight_wide(grid: CombatGrid, a: Vector2i, b: Vector2i, width: int) -> void:
	if absi(b.x - a.x) >= absi(b.y - a.y):
		b = Vector2i(b.x, a.y)
	else:
		b = Vector2i(a.x, b.y)
	if a == b:
		return
	var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	var across := Vector2i(step.y, step.x)
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	var ha := grid.height_at(a)
	var hb := grid.height_at(b)
	for off in lanes(width):
		for i in range(n + 1):
			var c := a + step * i + across * off
			if not grid.in_bounds(c):
				continue
			if i == 0 or i == n:  # the landings: ground at the end heights
				if grid.solid(c) and grid.terrain_at(c) != T.WATER and grid.terrain_at(c) != T.STAIRS:
					if grid.terrain_at(c) in [T.FOREST, T.ROCK, T.RUIN]:
						grid.set_terrain(c, T.GRASS)
					grid.set_height(c, ha if i == 0 else hb)
				continue
			if not grid.solid(c):
				grid.set_terrain(c, T.GRASS)
			var a2 := grid.prop_anchor(c)
			if a2 != CombatGrid.NONE_CELL:
				remove_prop(grid, a2)
			grid.set_terrain(c, T.STAIRS)
			grid.set_height(c, roundi(lerpf(ha, hb, float(i) / n)))


## A wide stair at a cliff: the cell's stairs, and the cells across the slope take the same height.
static func stairs_wide(grid: CombatGrid, c: Vector2i, width: int) -> bool:
	if not stairs(grid, c):
		return false
	if width <= 1:
		return true
	var h := grid.height_at(c)
	var axis := Vector2i(1, 0)  # across the slope: the axis whose neighbours are level with each other
	var d := Vector2i(1, 0)
	var dh := absi(_walk_h(grid, c + d, h) - _walk_h(grid, c - d, h))
	var dv := absi(_walk_h(grid, c + Vector2i(0, 1), h) - _walk_h(grid, c - Vector2i(0, 1), h))
	axis = Vector2i(0, 1) if dh >= dv else Vector2i(1, 0)
	for off in lanes(width):
		var n := c + axis * off
		if off == 0 or not grid.in_bounds(n) or not grid.solid(n) or grid.terrain_at(n) == T.WATER:
			continue
		grid.set_terrain(n, T.STAIRS)
		grid.set_height(n, h)
	return true


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


## Square off ragged edges (rule V9), so every edge runs at least two cells between turns. Edges re-step two
## cells at a time: in each 2 x 2 block (at the offset that changes least), a cell that is the odd one out of
## three takes their height, or goes when the other three are holes, or fills when it is the hole. Then a
## dry cell whose dry neighbours are at least three at one other height takes it (a cell sticking out drops,
## a notch fills, a lone column goes; add pillars after). Water, stairs, cells next to stairs and `keep` stay as they are.
## `area` (cells) limits it to those cells (the maker's brush); empty means the whole map.
## Returns how many cells changed; run keep_largest and link after it.
static func tidy(grid: CombatGrid, keep := {}, area := {}) -> int:
	var cells: Array[Vector2i] = []
	if area.is_empty():
		for y in grid.h:
			for x in grid.w:
				cells.append(Vector2i(x, y))
	else:
		for c: Vector2i in area:
			if grid.in_bounds(c):
				cells.append(c)
	var free := func(c: Vector2i) -> bool: return grid.in_bounds(c) and (area.is_empty() or area.has(c)) and _tidy_free(grid, c, keep)
	var best := {}
	var best_n := -1
	for off: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var moves := {}
		var blocks := {}
		for c in cells:
			blocks[Vector2i(floori((c.x - off.x) / 2.0), floori((c.y - off.y) / 2.0))] = true
		for b: Vector2i in blocks:
			var block: Array[Vector2i] = []
			for j in 2:
				for i in 2:
					block.append(off + Vector2i(b.x * 2 + i, b.y * 2 + j))
			if not block.all(free):
				continue
			var count := {}
			for c in block:
				var k := _tidy_level(grid, c)
				count[k] = int(count.get(k, 0)) + 1
			for k: int in count:
				if count[k] == 3:
					for c in block:
						if _tidy_level(grid, c) != k:
							moves[c] = k
		if best_n < 0 or moves.size() < best_n:
			best = moves
			best_n = moves.size()
	for c: Vector2i in best:
		_tidy_set(grid, c, best[c])
	var changed := best.size()
	for _pass in 1:  # one pass: a single cell sticking out goes; a longer spur only loses its tip
		var lone := {}
		for c in cells:
			if not grid.solid(c) or not free.call(c):
				continue
			var count := {}
			for d: Vector2i in CombatRules.DIRS:
				var n := c + d
				if grid.solid(n) and _tidy_free(grid, n, {}):
					count[grid.height_at(n)] = int(count.get(grid.height_at(n), 0)) + 1
			for k: int in count:
				if count[k] >= 3 and k != grid.height_at(c):
					lone[c] = k
		if lone.is_empty():
			break
		for c: Vector2i in lone:
			grid.set_height(c, lone[c])
		changed += lone.size()
	return changed


## Dry, natural ground tidy may move: not water, stairs, masonry, a cell next to stairs, or kept.
static func _tidy_free(grid: CombatGrid, c: Vector2i, keep: Dictionary) -> bool:
	if keep.has(c):
		return false
	if grid.solid(c) and grid.terrain_at(c) not in [T.GRASS, T.FOREST, T.ROCK, T.ROAD]:
		return false
	for d: Vector2i in CombatRules.DIRS:
		if grid.in_bounds(c + d) and grid.terrain_at(c + d) == T.STAIRS:
			return false
	return true


## A cell's level for tidy: its height, or -1 for a hole.
static func _tidy_level(grid: CombatGrid, c: Vector2i) -> int:
	return grid.height_at(c) if grid.solid(c) else -1


static func _tidy_set(grid: CombatGrid, c: Vector2i, k: int) -> void:
	if k < 0:
		cut(grid, [c] as Array[Vector2i])
	elif not grid.solid(c):
		grid.set_terrain(c, T.GRASS)
		grid.set_height(c, k)
	else:
		grid.set_height(c, k)


## One rock pillar (rule V10): the cell rises two levels over its highest neighbour into a lone column, in the
## top's own ground (the soft look rounds it into a snow-capped pillar; rock would grow a boulder on it).
## `down` lowers one back to its neighbours. False when the cell can't hold one.
## `cap`: the highest a pillar may stand; the map maker's tool goes to MAX_HEIGHT, dressing keeps PILLAR_MAX.
static func pillar(grid: CombatGrid, c: Vector2i, down := false, cap := CombatGrid.MAX_HEIGHT) -> bool:
	if not grid.solid(c) or grid.terrain_at(c) in [T.WATER, T.STAIRS]:
		return false
	var top := -1
	for d: Vector2i in CombatRules.DIRS:
		if grid.solid(c + d):
			top = maxi(top, grid.height_at(c + d))
	if top < 0:
		return false
	if down:
		grid.set_height(c, top)
		return true
	if top + 2 > cap:
		return false
	var a := grid.prop_anchor(c)
	if a != CombatGrid.NONE_CELL:
		remove_prop(grid, a)
	grid.set_terrain(c, T.GRASS)
	grid.set_height(c, top + 2)
	return true


## Place up to `count` pillars (rule V10) on high rims and in front of cliffs, at least four cells apart, off
## roads, water, stairs and `keep`, never cutting a piece of the walkable map off. Returns their cells.
## Dressing keeps the pillars it always placed: no higher than PILLAR_MAX, whatever MAX_HEIGHT allows (raising
## the cap to 24 must not change a re-dressed map: the map builder, 2026-10-30).
const PILLAR_MAX := 8

## `cap`: a map built tall on purpose (village_v2) may let its pillars stand higher.
static func pillars(grid: CombatGrid, seed_value: int, count := 3, keep := {}, cap := PILLAR_MAX) -> Array[Vector2i]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var options := []
	for y in grid.h:
		for x in grid.w:
			var c := Vector2i(x, y)
			if keep.has(c) or not grid.solid(c) or grid.terrain_at(c) not in [T.GRASS, T.FOREST, T.ROCK]:
				continue
			if grid.prop_anchor(c) != CombatGrid.NONE_CELL:
				continue
			var ok := true
			var rim := false
			var foot := false
			for d: Vector2i in CombatRules.DIRS:
				var n := c + d
				if not grid.solid(n):
					rim = true
					continue
				if grid.terrain_at(n) in [T.STAIRS, T.ROAD, T.WATER]:
					ok = false
				var diff := grid.height_at(n) - grid.height_at(c)
				rim = rim or diff <= -2
				foot = foot or diff >= 2
			if ok and (rim or foot):
				options.append([c, (2.0 if rim else 1.0) + rng.randf()])
	options.sort_custom(func(p: Array, q: Array) -> bool: return p[1] > q[1])
	var placed: Array[Vector2i] = []
	var start := _biggest_walk(grid, 1)
	for o: Array in options:
		if placed.size() >= count:
			break
		var c: Vector2i = o[0]
		if placed.any(func(p: Vector2i) -> bool: return maxi(absi(p.x - c.x), absi(p.y - c.y)) < 4):
			continue
		var before := reach(grid, start, 1)
		var h0 := grid.height_at(c)
		var t0 := grid.terrain_at(c)
		if not pillar(grid, c, false, cap):
			continue
		var after := reach(grid, start if start != c else Vector2i(-1, -1), 1)
		var lost := false
		for k: Vector2i in before:
			if k != c and not after.has(k):
				lost = true
				break
		if lost:
			grid.set_height(c, h0)
			grid.set_terrain(c, t0)
			continue
		placed.append(c)
	return placed


## Cells a piece with this Jump can walk to from `from` (stairs help, as in combat).
static func reach(grid: CombatGrid, from: Vector2i, jump := 1) -> Dictionary:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	var i := 0
	while i < queue.size():
		var c: Vector2i = queue[i]
		i += 1
		for d: Vector2i in CombatRules.DIRS:
			for nb in grid.places_next(c, d):
				if not seen.has(nb) and grid.passable(nb) and grid.can_step(c, nb, jump):
					seen[nb] = true
					queue.append(nb)
	return seen


## Join every walkable part of the map to the biggest one with a real flight of stairs: a straight run of cells
## stepping one level at a time, from the part's edge out to the main ground ([USER] 2026-10-30, scale C road fight:
## "no way to get up onto that central shelf, stairs seem flat or lead to nowhere"). The run climbs by the cheapest
## line; each rise's lower cell becomes a stair. A part no run can reach (water or a third part in the way) is made
## rock, so nothing walkable is left cut off. Where two shelves of about the same height face each other across a gap
## (water or a low dip) up to BRIDGE_MAX wide, it lays a deck bridge instead ([USER] 2026-10-30: "this area should have a
## bridge between it, not a stair that goes down to nowhere"). Returns how many stair or bridge cells it placed.
const RAMP_MAX := 12  ## the longest run, in cells
const BRIDGE_MAX := 4  ## the widest gap a bridge spans, in cells


static func link(grid: CombatGrid, seed_value: int, jump := 1) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var placed := 0
	for guard in 40:
		var start := _biggest_walk(grid, jump)
		if start.x < 0:
			return placed
		var main := reach(grid, start, jump)
		if _all_walkable_reached(grid, main):
			return placed
		# the part to join: the biggest one not on the main ground
		var part := {}
		for y in grid.h:
			for x in grid.w:
				var c := Vector2i(x, y)
				if grid.passable(c) and not main.has(c) and not part.has(c):
					var got := reach(grid, c, jump)
					if got.size() > part.size():
						part = got
		var best: Array = []
		var best_cost := INF
		var best_bridge := false
		for p: Vector2i in part:
			if grid.terrain_at(p) == T.WATER:
				continue  # a flight or bridge starts on dry ground
			for d: Vector2i in CombatRules.DIRS:
				var run: Array[Vector2i] = [p]
				var stair_ok := true
				var hp := grid.height_at(p)
				for k in range(1, RAMP_MAX + 1):
					var q := p + d * k
					if not grid.solid(q) or part.has(q):
						break
					run.append(q)
					if main.has(q) and grid.terrain_at(q) != T.WATER:
						var ht := grid.height_at(q)
						# a bridge: two shelves of about the same height facing each other across a gap or a low dip
						if k >= 2 and k <= BRIDGE_MAX + 1 and absi(ht - hp) <= 1:
							var gap := true
							for j in range(1, k):
								var g := run[j]
								if grid.terrain_at(g) != T.WATER and grid.height_at(g) > mini(hp, ht) - 1:
									gap = false
							if gap:
								var bc := float(k) * 0.7 + rng.randf() * 0.3
								if bc < best_cost:
									best_cost = bc
									best = run.duplicate()
									best_bridge = true
						if stair_ok and absi(ht - hp) <= k:
							var cost := float(k) + 2.0 + rng.randf() * 0.5
							for j in range(1, k):
								var want := hp + signi(ht - hp) * mini(j, absi(ht - hp))
								if want != grid.height_at(run[j]):
									cost += 1.5
							if cost < best_cost:
								best_cost = cost
								best = run.duplicate()
								best_bridge = false
					if grid.terrain_at(q) == T.WATER:
						stair_ok = false
		if best.is_empty():
			for c: Vector2i in part:  # nothing can reach it: it is rock now
				grid.set_terrain(c, T.ROCK)
			continue
		var hp := grid.height_at(best[0])
		var ht := grid.height_at(best[best.size() - 1])
		if best_bridge:  # the bridge kit's span over the gap, at the landings' height
			placed += (bridge_span(grid, best[0], best[best.size() - 1]).cells as Array).size()
			continue
		for j in range(1, best.size() - 1):
			var q: Vector2i = best[j]
			grid.set_height(q, hp + signi(ht - hp) * mini(j, absi(ht - hp)))
			if grid.terrain_at(q) in [T.FOREST, T.ROCK, T.WATER]:
				grid.set_terrain(q, T.GRASS)
		for j in range(best.size() - 1):  # the lower cell of each one-level rise is the stair
			var a: Vector2i = best[j]
			var b: Vector2i = best[j + 1]
			if absi(grid.height_at(a) - grid.height_at(b)) == 1:
				var low := a if grid.height_at(a) < grid.height_at(b) else b
				if low == best[0] or low == best[best.size() - 1]:
					continue  # the ends stay as they are: a one-level step needs no stair of its own
				if grid.terrain_at(low) != T.STAIRS:
					grid.set_terrain(low, T.STAIRS)
					placed += 1
	return placed


## A bridge from landing a to landing b ([USER] 2026-10-30): a straight run of bridge deck over whatever is between (water,
## a gap, lower ground), at the landings' height, with one step where they differ by one. It never changes the terrain
## under it. b is snapped onto a's row or column. Returns {"cells": placed cells, "error": why not}.
static func bridge_span(grid: CombatGrid, a: Vector2i, b: Vector2i, width := 1) -> Dictionary:
	var out := {"cells": [] as Array[Vector2i], "error": ""}
	if absi(b.x - a.x) >= absi(b.y - a.y):
		b = Vector2i(b.x, a.y)
	else:
		b = Vector2i(a.x, b.y)
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	if n < 2:
		out.error = "drag from one landing to another, with something to cross between them"
		return out
	if not grid.solid(a) or not grid.solid(b) or grid.terrain_at(a) == T.WATER or grid.terrain_at(b) == T.WATER:
		out.error = "a bridge starts and ends on dry ground"
		return out
	var ha := grid.height_at(a)
	var hb := grid.height_at(b)
	if absi(ha - hb) > 1:
		out.error = "the landings are %d levels apart; a bridge steps at most one" % absi(ha - hb)
		return out
	var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	var across := Vector2i(step.y, step.x)  # a wide bridge is `width` lanes side by side, the dragged line in the middle
	var plan: Array = []
	for off in lanes(width):
		for i in range(1, n):
			var c := a + step * i + across * off
			if not grid.in_bounds(c):
				out.error = "the bridge would run off the map"
				return out
			var dh := ha if i <= n / 2 else hb
			if grid.solid(c) and grid.terrain_at(c) != T.WATER and grid.height_at(c) >= dh:
				out.error = "the bridge would run into higher ground at (%d, %d)" % [c.x, c.y]
				return out
			plan.append([c, dh])
	for pr: Array in plan:
		grid.add_deck(pr[0], pr[1], T.STONE, true)
		(out.cells as Array[Vector2i]).append(pr[0])
	return out


## Take the bridge decks away along a line.
static func bridge_clear(grid: CombatGrid, a: Vector2i, b: Vector2i) -> int:
	var n := 0
	for c in line(a, b):
		if grid.has_deck(c) and (grid.decks[CombatGrid.ground(c)] as Dictionary).get("bridge", false):
			grid.remove_deck(c)
			n += 1
	return n


## Steps from `from` to every cell it can walk to (stairs help, as in `reach`).
static func walk_steps(grid: CombatGrid, from: Vector2i, jump := 1) -> Dictionary:
	var dist := {from: 0}
	var queue: Array[Vector2i] = [from]
	var i := 0
	while i < queue.size():
		var c: Vector2i = queue[i]
		i += 1
		for d: Vector2i in CombatRules.DIRS:
			for nb in grid.places_next(c, d):
				if not dist.has(nb) and grid.passable(nb) and grid.can_step(c, nb, jump):
					dist[nb] = int(dist[c]) + 1
					queue.append(nb)
	return dist


## Pairs of dry cells facing each other across 1 to 3 water cells, with their walk between (99 when there is none):
## [a, b, walk]. A bridge there (banks within a level) or a ford (the water cells stepped between the banks) would
## shorten a crossing.
static func river_crossings(grid: CombatGrid, jump := 1) -> Array:
	var out: Array = []
	for y in grid.h:
		for x in grid.w:
			var a := Vector2i(x, y)
			if not grid.passable(a) or grid.terrain_at(a) in [T.WATER, T.STAIRS]:
				continue
			var steps := {}
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				for k in range(2, 5):
					var b := a + d * k
					if not grid.solid(b):
						break
					var wet := true
					for j in range(1, k):
						if grid.terrain_at(a + d * j) != T.WATER:
							wet = false
					if not wet:
						break
					if not grid.passable(b) or grid.terrain_at(b) in [T.WATER, T.STAIRS] or absi(grid.height_at(a) - grid.height_at(b)) > k - 1:
						continue  # banks level enough for a bridge, or a ford can step down between them
					if steps.is_empty():
						steps = walk_steps(grid, a, jump)
					out.append([a, b, int(steps.get(b, 99))])
	return out


## Make sure a river that splits the map can be crossed near the middle ([USER] 2026-10-30: "this section should have a
## bridge over the river or else it'll be a pain to get around the whole map"): of the places two banks face each other
## with a long walk between (CROSS_FAR or more steps), the one nearest the middle gets a deck bridge (or a ford where
## the banks differ by more than a level), then a second one
## well apart from it. Returns how many bridges it laid.
const CROSS_FAR := 10
const CROSS_WALK := 12  ## a crossing near the middle is at most this many steps after


static func cross_river(grid: CombatGrid, count := 2) -> int:
	var centre := Vector2(grid.w - 1, grid.h - 1) * 0.5
	var laid: Array[Vector2i] = []
	var n := 0
	for round_ in count:
		var best: Array = []
		var best_d := INF
		for pair: Array in river_crossings(grid):
			if int(pair[2]) < CROSS_FAR:
				continue
			var a: Vector2i = pair[0]
			var b: Vector2i = pair[1]
			var mid := Vector2(a + b) * 0.5
			if laid.any(func(l: Vector2i) -> bool: return Vector2(l).distance_to(mid) < 7.0):
				continue
			var d := mid.distance_to(centre)
			if absi(grid.height_at(a) - grid.height_at(b)) <= 1:
				d -= 3.0  # a bridge is better than a ford
			if d < best_d:
				best_d = d
				best = pair
		if best.is_empty():
			break
		var a: Vector2i = best[0]
		var b: Vector2i = best[1]
		var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
		var ha := grid.height_at(a)
		var hb := grid.height_at(b)
		if absi(ha - hb) <= 1:
			n += (bridge_span(grid, a, b).cells as Array).size()
		else:
			var c := a + step
			var j := 1
			while c != b:  # a ford: the water steps from one bank's height to the other's, a level a cell
				grid.set_height(c, ha + signi(hb - ha) * mini(j, absi(hb - ha) - 1))
				n += 1
				c += step
				j += 1
		laid.append((a + b) / 2)
	return n


## Walkable cells the main ground can't reach (a pillar's top, a nook) become rock, so no one stands cut off.
static func seal_unreachable(grid: CombatGrid, jump := 1) -> int:
	var start := _biggest_walk(grid, jump)
	if start.x < 0:
		return 0
	var got := reach(grid, start, jump)
	var n := 0
	for y in grid.h:
		for x in grid.w:
			var c := Vector2i(x, y)
			if grid.passable(c) and not got.has(c):
				grid.set_terrain(c, T.ROCK)
				n += 1
	return n


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

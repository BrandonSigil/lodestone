class_name TerrainShape
extends RefCounted
## Pure rules for the soft terrain pass (CombatBoard.soft): the grid's square cells drawn as one continuous,
## hand-shaped ground. Which block corners round off and what ground shows in the rounded-off bit, each
## cell's outline, the lip's drip line along any edge, and which way water runs plus the flow strokes that
## follow it down a whole river. No drawing here, so tests can run it headless.
## Design: docs/design/terrain-engine.md.

## Corner radii in cells. Small, like a brush going round a corner, not a rounded box; each corner varies a
## little (JITTER) so no two match.
const ROUND := 0.13  ## where both sides of a block drop away
const PILLAR := 0.2  ## a block standing alone: a rounded column, still flat sided
const BUILT := 0.04  ## masonry (stone floor, ruins) stays crisp
const FILLET := 0.1  ## where a low cell's corner is tucked between higher ground, that ground curves in this far
const JITTER := 0.35  ## each corner's radius is its kind's times 1 +- this, fixed per corner
const MIN_DROP := 0.2  ## a step lower than this doesn't round
const ARC_STEPS := 6
const STROKE_STEP := 0.07  ## flow strokes are traced in steps this long (cells)
const STROKE_GAP := 0.26  ## and kept at least this far apart

## Corner k of a cell sits between edge k - 1 and edge k; edge k runs from corner k to corner k + 1.
const CORNERS := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
const NORMALS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]  ## outward, per edge


## How corner k of cell c is shaped: > 0 rounds it off (both sides drop away; the radius in cells), < 0 is
## a fillet (both sides rise to the same ground, which curves round into this cell's corner), 0 is square.
## `surf` gives a cell's surface height, or the floor where there is no ground. Water never rounds off;
## stairs, and corners beside a stair, stay square so the stair stays cut into the block.
static func corner_radius(grid: CombatGrid, c: Vector2i, k: int, surf: Callable) -> float:
	var t := grid.terrain_at(c)
	if t == CombatGrid.T.STAIRS:
		return 0.0
	var n1: Vector2i = c + NORMALS[(k + 3) % 4]
	var n2: Vector2i = c + NORMALS[k]
	if _is(grid, n1, CombatGrid.T.STAIRS) or _is(grid, n2, CombatGrid.T.STAIRS):
		return 0.0
	var h: float = surf.call(c)
	var h1: float = surf.call(n1)
	var h2: float = surf.call(n2)
	var vary := 1.0 + JITTER * (2.0 * _hf(c + Vector2i(CORNERS[k]), 97) - 1.0)
	if h - h1 >= MIN_DROP and h - h2 >= MIN_DROP and t != CombatGrid.T.WATER:
		if t == CombatGrid.T.STONE or t == CombatGrid.T.RUIN:
			return BUILT * vary
		for d: Vector2i in NORMALS:
			if h - float(surf.call(c + d)) < MIN_DROP:
				return ROUND * vary
		return PILLAR * vary
	var hd: float = surf.call(n1 + NORMALS[k])
	if h1 - h >= MIN_DROP and absf(h1 - h2) < 0.01 and hd >= h1 - 0.01 and _fills(grid, n1) and _fills(grid, n2):
		return -FILLET * vary
	return 0.0


static func _is(grid: CombatGrid, c: Vector2i, t: int) -> bool:
	return grid.in_bounds(c) and grid.terrain_at(c) == t


## Ground that can curve round into a lower neighbour's corner: dry, natural, not a stair.
static func _fills(grid: CombatGrid, c: Vector2i) -> bool:
	if not grid.solid(c):
		return false
	var t := grid.terrain_at(c)
	return t != CombatGrid.T.WATER and t != CombatGrid.T.STAIRS and t != CombatGrid.T.STONE and t != CombatGrid.T.RUIN


## The four corner radii of a cell.
static func radii(grid: CombatGrid, c: Vector2i, surf: Callable) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in 4:
		out.append(corner_radius(grid, c, k, surf))
	return out


## The ground in the bit of a corner that is cut away: where it rounds off, the higher of the two neighbours
## it drops to; where it is a fillet, the higher ground curving in. {"h": its height, "src": that neighbour
## (no "src" where neither side has ground), "low": the other neighbour}.
static func gap(grid: CombatGrid, c: Vector2i, k: int, surf: Callable) -> Dictionary:
	var n1: Vector2i = c + NORMALS[(k + 3) % 4]
	var n2: Vector2i = c + NORMALS[k]
	var h1: float = surf.call(n1)
	var h2: float = surf.call(n2)
	var src := n1 if h1 >= h2 else n2
	var out := {"h": maxf(h1, h2), "low": n2 if src == n1 else n1}
	if grid.solid(src):
		out.src = src
	return out


## Cell c's outline in grid units, going round from corner 0, as segments
## {"a", "b": end points, "na", "nb": outward normals there, "edge": the side it lies on or -1, "corner": the
## corner it rounds or -1}. Straight sides are one segment; a rounded corner is ARC_STEPS short ones.
static func outline(c: Vector2i, r: PackedFloat32Array) -> Array:
	var o := Vector2(c)
	var segs := []
	for k in 4:
		var ck: Vector2 = o + CORNERS[k]
		var e1: Vector2 = CORNERS[(k + 3) % 4] - CORNERS[k]
		var e2: Vector2 = CORNERS[(k + 1) % 4] - CORNERS[k]
		var rk := absf(r[k])  # a fillet cuts the same curve out of this cell; the higher ground fills it
		if rk > 0.0:
			var centre := ck + (e1 + e2) * rk
			for i in ARC_STEPS:
				var f0 := float(i) / ARC_STEPS * PI * 0.5
				var f1 := float(i + 1) / ARC_STEPS * PI * 0.5
				var n0 := -e2 * cos(f0) - e1 * sin(f0)
				var n1 := -e2 * cos(f1) - e1 * sin(f1)
				segs.append({"a": centre + n0 * rk, "b": centre + n1 * rk, "na": n0, "nb": n1, "edge": -1, "corner": k})
		var k2 := (k + 1) % 4
		var a := ck + e2 * absf(r[k])
		var b: Vector2 = o + CORNERS[k2] + (CORNERS[k] - CORNERS[k2]) * absf(r[k2])
		var n := Vector2(NORMALS[k])
		segs.append({"a": a, "b": b, "na": n, "nb": n, "edge": k, "corner": -1})
	return segs


## The bit of a cell a shaped corner cuts away, in grid units: the corner point, then along the arc.
static func gap_polygon(c: Vector2i, k: int, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(c) + CORNERS[k]])
	var segs := arc(c, k, r)
	for s: Dictionary in segs:
		pts.append(s.a)
	pts.append(segs[segs.size() - 1].b)
	return pts


## Just the arc of corner k (radius |r|), as outline segments.
static func arc(c: Vector2i, k: int, r: float) -> Array:
	var only := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	only[k] = absf(r)
	return outline(c, only).filter(func(s: Dictionary) -> bool: return s.corner == k)


## How far a lip hangs, in levels, at screen position s (cell widths along the screen, so its edge runs on
## unbroken from cell to cell and round the corners): an uneven brushed edge and, now and then, a short drip.
static func lip_depth(s: float, depth: float) -> float:
	var out := depth * (0.3 + 0.52 * noise1(s * 1.25, 1) + 0.18 * noise1(s * 4.2, 2))
	var j := floori(s * 2.0)
	for k in range(j - 1, j + 2):
		if _h1(k) < 0.78:
			continue
		var centre := (k + 0.2 + 0.6 * _h1(k * 7 + 3)) / 2.0
		var width := 0.06 + 0.04 * _h1(k * 13 + 5)
		var x := (s - centre) / width
		if absf(x) < 1.0:
			out = maxf(out, depth * (0.85 + 0.15 * _h1(k * 17 + 11)) * pow(1.0 - x * x, 2.0))
	return out


## How high snow piles against the foot of a wall, in levels, at screen position s: low banks that swell into
## mounds now and then, never higher than `depth`.
static func drift_height(s: float, depth: float) -> float:
	var m := noise1(s * 1.15, 21)
	return minf(depth, depth * (0.15 + 0.85 * m * m + 0.12 * noise1(s * 4.3, 22)))


## Smooth 1D value noise, 0..1: random heights at whole numbers, eased between. `salt` picks the series.
static func noise1(s: float, salt: int) -> float:
	var i := floori(s)
	var f := s - i
	var e := f * f * (3.0 - 2.0 * f)
	return lerpf(_h1(i * 31 + salt * 7919), _h1((i + 1) * 31 + salt * 7919), e)


## 0..1, fixed for an integer.
static func _h1(k: int) -> float:
	return float(absi((k * 73856093) ^ 83492791) % 10007) / 10007.0


# --- water ---------------------------------------------------------------------------

## Which way water runs in every water cell (unit vectors, grid units): toward where each body of water
## pours off the map, or failing that toward its lowest pool, so it goes down every fall and along every
## level stretch. Cells with nowhere to run get (1, 0).
static func flow(grid: CombatGrid) -> Dictionary:
	var water := {}
	for y in grid.h:
		for x in grid.w:
			var c := Vector2i(x, y)
			if grid.terrain_at(c) == CombatGrid.T.WATER:
				water[c] = true
	var dist := {}
	var seen := {}
	for start: Vector2i in water:
		if seen.has(start):
			continue
		# One body of water at a time.
		var body: Array[Vector2i] = [start]
		seen[start] = true
		var i := 0
		while i < body.size():
			for d: Vector2i in NORMALS:
				var n := body[i] + d
				if water.has(n) and not seen.has(n):
					seen[n] = true
					body.append(n)
			i += 1
		var low := 1 << 30
		for c in body:
			low = mini(low, grid.height_at(c))
		var sinks: Array[Vector2i] = []
		for c in body:
			if grid.height_at(c) == low and NORMALS.any(func(d: Vector2i) -> bool: return not grid.solid(c + d)):
				sinks.append(c)
		if sinks.is_empty():
			for c in body:
				if grid.height_at(c) == low:
					sinks.append(c)
		var queue: Array[Vector2i] = []
		for c in sinks:
			dist[c] = 0
			queue.append(c)
		var head := 0
		while head < queue.size():
			var c := queue[head]
			head += 1
			for d: Vector2i in NORMALS:
				var n := c + d
				if water.has(n) and not dist.has(n):
					dist[n] = dist[c] + 1
					queue.append(n)
	var raw := {}
	for c: Vector2i in water:
		var v := Vector2.ZERO
		for d: Vector2i in NORMALS:
			if water.has(c + d) and dist[c + d] < dist[c]:
				v += Vector2(d)
		if v == Vector2.ZERO:
			for d: Vector2i in NORMALS:
				if water.has(c + d) and dist[c + d] > dist[c]:
					v -= Vector2(d)
		if v == Vector2.ZERO:  # a sink at the map's edge: pour off it
			for d: Vector2i in NORMALS:
				if not grid.solid(c + d):
					v += Vector2(d)
		raw[c] = v.normalized() if v != Vector2.ZERO else Vector2(1, 0)
	# Smooth along each level so bends sweep instead of turning square.
	for _pass in 3:
		var next := {}
		for c: Vector2i in raw:
			var v: Vector2 = raw[c] * 1.5
			for d: Vector2i in NORMALS:
				var n := c + d
				if raw.has(n) and grid.height_at(n) == grid.height_at(c):
					v += raw[n]
			next[c] = v.normalized() if v.length() > 0.01 else raw[c]
		raw = next
	return raw


## The flow at a point (grid units) on one level of water: the four nearest cells' flows blended.
static func flow_at(grid: CombatGrid, fl: Dictionary, p: Vector2) -> Vector2:
	var home := Vector2i(floori(p.x), floori(p.y))
	var hv: Vector2 = fl.get(home, Vector2(1, 0))
	var level := grid.height_at(home) if grid.in_bounds(home) else -1
	var x0 := floori(p.x - 0.5)
	var y0 := floori(p.y - 0.5)
	var fx := p.x - 0.5 - x0
	var fy := p.y - 0.5 - y0
	var out := Vector2.ZERO
	for j in 2:
		for i in 2:
			var n := Vector2i(x0 + i, y0 + j)
			var v: Vector2 = fl[n] if fl.has(n) and grid.height_at(n) == level else hv
			out += v * (fx if i == 1 else 1.0 - fx) * (fy if j == 1 else 1.0 - fy)
	return out.normalized() if out.length() > 0.001 else hv


## Flow strokes: lines that follow the water down the river, kept evenly apart, each on one level only
## (falls draw their own). [{"pts": PackedVector2Array, "dark": bool}], deterministic for a map.
static func strokes(grid: CombatGrid, fl: Dictionary) -> Array:
	var cells: Array = fl.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _seed(a, 0) < _seed(b, 0))
	var taken := {}  # spatial hash of points already drawn
	var out := []
	for c: Vector2i in cells:
		for s in 3:
			var p := Vector2(c) + Vector2(0.15 + 0.7 * _hf(c, s * 2 + 1), 0.15 + 0.7 * _hf(c, s * 2 + 2))
			if _near(taken, p, STROKE_GAP):
				continue
			var reach := 1.0 + 2.6 * _hf(c, s + 11)
			var fwd := _trace(grid, fl, p, 1.0, reach * 0.6, taken)
			var back := _trace(grid, fl, p, -1.0, reach * 0.4, taken)
			back.reverse()
			var pts := PackedVector2Array(back)
			pts.append(p)
			pts.append_array(PackedVector2Array(fwd))
			if pts.size() * STROKE_STEP < 0.45:
				continue
			for q in pts:
				taken[Vector2i(floori(q.x / STROKE_GAP), floori(q.y / STROKE_GAP))] = true
			# A hand-drawn line wavers: bend it gently from side to side along its length.
			var amp := 0.025 + 0.035 * _hf(c, s + 31)
			var freq := TAU / (0.7 + 0.9 * _hf(c, s + 37))
			var phase := TAU * _hf(c, s + 41)
			var bent := PackedVector2Array()
			for i in pts.size():
				var d := pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]
				bent.append(pts[i] + Vector2(-d.y, d.x).normalized() * amp * sin(phase + i * STROKE_STEP * freq))
			out.append({"pts": bent, "dark": _hf(c, s + 23) < 0.22})
	return out


static func _trace(grid: CombatGrid, fl: Dictionary, p: Vector2, dir: float, reach: float, taken: Dictionary) -> Array:
	var pts := []
	var home := Vector2i(floori(p.x), floori(p.y))
	var level := grid.height_at(home)
	var q := p
	var went := 0.0
	while went < reach:
		var mid := q + flow_at(grid, fl, q) * dir * STROKE_STEP * 0.5
		var nq := q + flow_at(grid, fl, mid) * dir * STROKE_STEP
		var cell := Vector2i(floori(nq.x), floori(nq.y))
		if not fl.has(cell) or grid.height_at(cell) != level or _near(taken, nq, STROKE_GAP * 0.7):
			break
		pts.append(nq)
		q = nq
		went += STROKE_STEP
	return pts


static func _near(taken: Dictionary, p: Vector2, gap_v: float) -> bool:
	var k := Vector2i(floori(p.x / STROKE_GAP), floori(p.y / STROKE_GAP))
	var reach := ceili(gap_v / STROKE_GAP)
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if taken.has(k + Vector2i(dx, dy)):
				return true
	return false


## Strokes cut at cell sides, so each cell draws its own piece at its own depth:
## cell -> [{"pts": PackedVector2Array, "f": PackedFloat32Array (0..1 along the whole stroke), "dark"}].
static func by_cell(list: Array) -> Dictionary:
	var out := {}
	for s: Dictionary in list:
		var pts: PackedVector2Array = s.pts
		var n := pts.size()
		var piece := PackedVector2Array([pts[0]])
		var f := PackedFloat32Array([0.0])
		var cell := Vector2i(floori(pts[0].x), floori(pts[0].y))
		for i in range(1, n):
			var q := pts[i]
			var qc := Vector2i(floori(q.x), floori(q.y))
			var fq := float(i) / (n - 1)
			if qc != cell:
				# Split where the step crosses the cell side, so neither cell draws past its own edge.
				var a := pts[i - 1]
				var t := _cross(a, q, cell)
				var m := a.lerp(q, t)
				piece.append(m)
				f.append(lerpf(float(i - 1) / (n - 1), fq, t))
				_add_piece(out, cell, piece, f, s.dark)
				piece = PackedVector2Array([m])
				f = PackedFloat32Array([f[f.size() - 1]])
				cell = qc
			piece.append(q)
			f.append(fq)
		_add_piece(out, cell, piece, f, s.dark)
	return out


static func _add_piece(out: Dictionary, cell: Vector2i, pts: PackedVector2Array, f: PackedFloat32Array, dark: bool) -> void:
	if pts.size() < 2:
		return
	if not out.has(cell):
		out[cell] = []
	out[cell].append({"pts": pts, "f": f, "dark": dark})


## Where along a -> b (0..1) the segment leaves cell c.
static func _cross(a: Vector2, b: Vector2, c: Vector2i) -> float:
	var t := 1.0
	var d := b - a
	if d.x > 0.0:
		t = minf(t, (c.x + 1 - a.x) / d.x)
	elif d.x < 0.0:
		t = minf(t, (c.x - a.x) / d.x)
	if d.y > 0.0:
		t = minf(t, (c.y + 1 - a.y) / d.y)
	elif d.y < 0.0:
		t = minf(t, (c.y - a.y) / d.y)
	return clampf(t, 0.0, 1.0)


## 0..1, fixed for a cell and a salt.
static func _hf(c: Vector2i, salt: int) -> float:
	return float(_seed(c, salt) % 10007) / 10007.0


static func _seed(c: Vector2i, salt: int) -> int:
	return absi((c.x * 73856093) ^ (c.y * 19349663) ^ (salt * 83492791))

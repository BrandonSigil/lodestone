class_name WaterField
extends RefCounted
## Pure rules for the moving water (shaders/water_surface.gdshader): a small picture of the map, PER_CELL
## texels to a cell, that tells the shader at every spot of water how far the bank is, which way the river
## runs, and how hard a fall above it churns the water. The shader draws the flat painted water from it:
## the bank line, flow dashes, foam and ripple rings. No drawing here, so tests can run it headless.
## Design: docs/systems/water.md.

const PER_CELL := 6  ## texels per cell side
const SHORE_REACH := 0.6  ## cells: the shore channel reads 1 this far from a bank, and past it
const CHURN_REACH := 1.1  ## cells: how far out from a fall's foot the water churns
const LEVEL_EPS := 0.01


## The field as an image (RGBA8, PER_CELL texels to a cell): R the distance to the bank (0 at the bank, 1 at
## SHORE_REACH or more), G and B the flow direction (x and y in grid units, 0.5 = still), A the churn below
## falls (1 at a fall's foot). Texels with no water near them stay clear.
## `flow` comes from TerrainShape.flow, `radii` is cell -> its four corner radii (TerrainShape.radii) and
## `surf` gives a cell's drawn surface height.
static func build(grid: CombatGrid, flow: Dictionary, radii: Dictionary, surf: Callable) -> Image:
	var img := Image.create(maxi(1, grid.w * PER_CELL), maxi(1, grid.h * PER_CELL), false, Image.FORMAT_RGBA8)
	img.fill(CLEAR)
	update(img, grid, flow, radii, surf, near_water(grid, flow, {}))
	return img


const CLEAR := Color(0, 0.5, 0.5, 0)
static var _SQUARE := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])


## The cells the field covers: water and the ground round it (a bank's rounded-off corner shows water).
## With `only` given, just those of them.
static func near_water(grid: CombatGrid, flow: Dictionary, only: Dictionary) -> Dictionary:
	var out := {}
	for c: Vector2i in flow:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n := c + Vector2i(dx, dy)
				if grid.in_bounds(n) and (only.is_empty() or only.has(n)):
					out[n] = true
	return out


## Redo the field's texels in `cells` (after an edit near them); other cells in `clear` are wiped.
static func update(img: Image, grid: CombatGrid, flow: Dictionary, radii: Dictionary, surf: Callable, cells: Dictionary,
		clear := {}) -> void:
	for c: Vector2i in clear:
		if not cells.has(c) and grid.in_bounds(c):
			img.fill_rect(Rect2i(c * PER_CELL, Vector2i(PER_CELL, PER_CELL)), CLEAR)
	for c: Vector2i in cells:
		var wet := _is_water(grid, c)
		var level := float(surf.call(c)) if wet else _level_beside(grid, c, surf)
		var dir: Vector2 = flow.get(c, Vector2.ZERO) if wet else _flow_beside(grid, c, flow)
		var around := _around(grid, c, level, radii, surf)
		for j in PER_CELL:
			for i in PER_CELL:
				var p := Vector2(c) + Vector2((i + 0.5) / PER_CELL, (j + 0.5) / PER_CELL)
				var s := _eval(around, p)
				var f := TerrainShape.flow_at(grid, flow, p) if wet else dir
				img.set_pixel(c.x * PER_CELL + i, c.y * PER_CELL + j, Color(
					clampf(s.x / SHORE_REACH, 0.0, 1.0), f.x * 0.5 + 0.5, f.y * 0.5 + 0.5, s.y))


## The water at grid point p (in cell `home`, on water at `level`): {"shore": cells to the nearest bank
## within a cell or so, below 0 inside the bank, INF with none near; "churn": 0..1 from falls landing near}.
static func sample(grid: CombatGrid, home: Vector2i, p: Vector2, level: float, radii: Dictionary, surf: Callable) -> Dictionary:
	var s := _eval(_around(grid, home, level, radii, surf), p)
	return {"shore": s.x, "churn": s.y}


## What shapes the water in and round one cell: the banks (cells higher than the water, with their rounded
## corners; higher water among them is a fall landing here) and the fillets curving into its water corners.
static func _around(grid: CombatGrid, home: Vector2i, level: float, radii: Dictionary, surf: Callable) -> Dictionary:
	var banks := []
	var fillets := []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := home + Vector2i(dx, dy)
			if not grid.solid(n):
				continue  # off the ground: the water pours away, no bank
			var h: float = surf.call(n)
			var r: PackedFloat32Array = radii.get(n, PackedFloat32Array([0.0, 0.0, 0.0, 0.0]))
			if h > level + LEVEL_EPS:  # not the same water or lower ground it runs down to
				var drop := (h - level) if _is_water(grid, n) else 0.0
				banks.append([n, r, drop])
			elif _is_water(grid, n) and absf(h - level) <= LEVEL_EPS:
				for k in 4:
					if r[k] >= 0.0:
						continue
					var rk := -r[k]
					var ck: Vector2 = Vector2(n) + TerrainShape.CORNERS[k]
					var inward := Vector2(n) + Vector2(0.5, 0.5) - ck
					var centre := ck + Vector2(signf(inward.x), signf(inward.y)) * rk
					fillets.append([centre, rk, Vector2(minf(ck.x, centre.x), minf(ck.y, centre.y)),
						Vector2(maxf(ck.x, centre.x), maxf(ck.y, centre.y))])
	return {"banks": banks, "fillets": fillets}


## (shore, churn) at p from _around's shapes.
static func _eval(around: Dictionary, p: Vector2) -> Vector2:
	var shore := INF
	var churn := 0.0
	for b: Array in around.banks:
		shore = minf(shore, box_distance(p, b[0], b[1]))
		if b[2] > 0.0:  # higher water: it falls in here
			var reach := clampf(1.0 - box_distance(p, b[0], _SQUARE) / CHURN_REACH, 0.0, 1.0)
			churn = maxf(churn, pow(reach, 1.2) * clampf(0.55 + float(b[2]) * 0.2, 0.0, 1.0))
	for f: Array in around.fillets:  # the bank curving into a water cell's corner
		var lo: Vector2 = f[2]
		var hi: Vector2 = f[3]
		if p.x >= lo.x and p.x <= hi.x and p.y >= lo.y and p.y <= hi.y:
			shore = minf(shore, float(f[1]) - p.distance_to(f[0]))
	return Vector2(shore, churn)


## Signed distance (cells) from p to cell n's square with its corners rounded off by r (TerrainShape.radii;
## a fillet, below 0, leaves the corner square): below 0 inside.
static func box_distance(p: Vector2, n: Vector2i, r: PackedFloat32Array) -> float:
	var d := p - (Vector2(n) + Vector2(0.5, 0.5))
	var k := (1 if d.x >= 0.0 else 0) if d.y < 0.0 else (2 if d.x >= 0.0 else 3)
	var rk := maxf(r[k], 0.0)
	var v := Vector2(absf(d.x), absf(d.y)) - Vector2(0.5, 0.5) + Vector2(rk, rk)
	return minf(maxf(v.x, v.y), 0.0) + Vector2(maxf(v.x, 0.0), maxf(v.y, 0.0)).length() - rk


static func _is_water(grid: CombatGrid, c: Vector2i) -> bool:
	return grid.in_bounds(c) and grid.terrain_at(c) == CombatGrid.T.WATER


## The water a dry cell's rounded-off corners show: the highest water beside it.
static func _level_beside(grid: CombatGrid, c: Vector2i, surf: Callable) -> float:
	var best := -INF
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := c + Vector2i(dx, dy)
			if _is_water(grid, n):
				best = maxf(best, float(surf.call(n)))
	return best


static func _flow_beside(grid: CombatGrid, c: Vector2i, flow: Dictionary) -> Vector2:
	var out := Vector2.ZERO
	for d: Vector2i in TerrainShape.NORMALS:
		out += flow.get(c + d, Vector2.ZERO)
	return out.normalized() if out.length() > 0.001 else Vector2.ZERO

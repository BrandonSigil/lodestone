class_name IslandShape
extends RefCounted
## Irregular floor outlines for generated maps. A seeded blob decides which cells are ground; the rest is
## void, so the floor's edge (and the scenery ring around it) follows the shape. Pure math, so tests run
## headless. Opt-in through CombatGrid.generate(..., outline = true).

const SEED_OFFSET := 313  ## keeps the outline noise apart from the height and terrain noise


## Marks the grid's cells outside a seeded blob as void. The middle row runs through the whole map, so both
## deploy zones always reach each other, and only the piece that holds that row is kept.
static func carve(g: CombatGrid, seed_value: int, deploy_cols: int) -> void:
	var mask := ground(seed_value, g.w, g.h)
	var mid := g.h / 2
	for x in g.w:
		mask[mid * g.w + x] = true
	for y in g.h:  # the deploy columns stay ground along the middle band, so every deploy cell is real
		for x in range(0, mini(deploy_cols, g.w)):
			if absi(y - mid) <= 1:
				mask[y * g.w + x] = true
		for x in range(maxi(g.w - deploy_cols, 0), g.w):
			if absi(y - mid) <= 1:
				mask[y * g.w + x] = true
	mask = _largest_piece(mask, g.w, g.h, mid * g.w + g.w / 2)
	for y in g.h:
		for x in g.w:
			var c := Vector2i(x, y)
			if not mask[y * g.w + x]:
				g.set_terrain(c, CombatGrid.T.VOID)
				g.set_height(c, 0)


## True for cells inside the blob. Edge radius varies with the angle and each cell's own noise breaks it up.
static func ground(seed_value: int, width: int, height: int) -> Array[bool]:
	var cell_noise := FastNoiseLite.new()
	cell_noise.seed = seed_value + SEED_OFFSET
	cell_noise.frequency = 0.9
	var edge_noise := FastNoiseLite.new()
	edge_noise.seed = seed_value + SEED_OFFSET * 2
	edge_noise.frequency = 0.6
	var cx := (width - 1) * 0.5
	var cy := (height - 1) * 0.5
	var out: Array[bool] = []
	out.resize(width * height)
	for y in height:
		for x in width:
			var u := (x - cx) / (width * 0.5)
			var v := (y - cy) / (height * 0.5)
			var a := atan2(v, u)
			var rim := 0.86 + 0.24 * edge_noise.get_noise_2d(cos(a) * 2.5, sin(a) * 2.5)
			var jitter := 0.1 * cell_noise.get_noise_2d(x, y)
			out[y * width + x] = sqrt(u * u + v * v) < rim + jitter
	return out


## Keeps only the cells connected (4 ways) to the start cell.
static func _largest_piece(mask: Array[bool], width: int, height: int, start: int) -> Array[bool]:
	var keep: Array[bool] = []
	keep.resize(width * height)
	keep.fill(false)
	if not mask[start]:
		return keep
	var queue: Array[int] = [start]
	keep[start] = true
	while not queue.is_empty():
		var i: int = queue.pop_back()
		var x := i % width
		var y := i / width
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if nx < 0 or ny < 0 or nx >= width or ny >= height:
				continue
			var j := ny * width + nx
			if mask[j] and not keep[j]:
				keep[j] = true
				queue.append(j)
	return keep

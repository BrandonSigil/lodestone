class_name CombatGrid
extends RefCounted
## The battle map: a height and a terrain type per cell.

## STONE is paved ruin floor. STAIRS let pieces climb STAIRS_CLIMB more levels than their Jump.
## RUIN is a broken wall or pillar: impassable, and it stands RUIN_RISE levels above its cell for line of sight.
enum T { GRASS, FOREST, WATER, ROCK, ROAD, STONE, STAIRS, RUIN }

const BLOCKED := 999
const STEP_COST := {T.GRASS: 1, T.FOREST: 2, T.WATER: 3, T.ROCK: BLOCKED, T.ROAD: 1, T.STONE: 1, T.STAIRS: 1, T.RUIN: BLOCKED}
const COVER := {T.GRASS: 0, T.FOREST: 2, T.WATER: -2, T.ROCK: 0, T.ROAD: 0, T.STONE: 0, T.STAIRS: 0, T.RUIN: 0}
## How far above the ground each terrain blocks sight (trees and boulders block a little, ruins a lot).
const SIGHT_BLOCK := {T.GRASS: 0.0, T.FOREST: 0.8, T.WATER: 0.0, T.ROCK: 1.0, T.ROAD: 0.0, T.STONE: 0.0, T.STAIRS: 0.0, T.RUIN: 2.0}
const RUIN_RISE := 2
const STAIRS_CLIMB := 2
const MAX_HEIGHT := 8  ## editor and saved maps
const GEN_MAX_HEIGHT := 4  ## the random generator stays gentle; stairs keep it crossable
const DEPLOY_COLS := 2  ## columns kept clear at each side for deployment

var w := 0
var h := 0
var heights := PackedInt32Array()
var terrain := PackedInt32Array()
var _sight := {}  ## line of sight cache, cleared on any edit


static func flat(width: int, height: int) -> CombatGrid:
	var g := CombatGrid.new()
	g.w = width
	g.h = height
	g.heights.resize(width * height)
	g.terrain.resize(width * height)
	g.heights.fill(0)
	g.terrain.fill(T.GRASS)
	return g


## Seeded map. Retries until the two deploy zones connect for a jump-1 unit.
static func generate(seed_value: int, width := 10, height := 8, strangeness := 0.0) -> CombatGrid:
	for attempt in 20:
		var g := _try(seed_value + attempt * 7919, width, height, strangeness)
		if g.connected(1):
			return g
	return flat(width, height)


static func _try(seed_value: int, width: int, height: int, strangeness: float) -> CombatGrid:
	var g := flat(width, height)
	var hn := FastNoiseLite.new()
	hn.seed = seed_value
	hn.frequency = 0.16
	var tn := FastNoiseLite.new()
	tn.seed = seed_value + 101
	tn.frequency = 0.3
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			var hv := (hn.get_noise_2d(x, y) + 1.0) * 0.5  # 0..1
			var lvl := clampi(int(hv * (GEN_MAX_HEIGHT + 1.5)) - 1, 0, GEN_MAX_HEIGHT)
			g.set_height(c, lvl)
			var tv := tn.get_noise_2d(x, y)
			var edge := x < DEPLOY_COLS or x >= width - DEPLOY_COLS
			var t := T.GRASS
			if lvl == 0 and tv > 0.05 and not edge:
				t = T.WATER
			elif lvl > 0 and tv > 0.25 - strangeness * 0.15:
				t = T.FOREST
			elif tv < -0.55 and not edge:
				t = T.RUIN if lvl >= 2 and strangeness < 0.5 else T.ROCK
			g.terrain[g.idx(c)] = t
	# Stairs where the ground jumps two levels, so ledges become chokepoints instead of walls.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if g.terrain_at(c) != T.GRASS:
				continue
			for d in CombatRules.DIRS:
				var n: Vector2i = c + d
				if g.in_bounds(n) and g.passable(n) and g.height_at(n) - g.height_at(c) == 2 and rng.randf() < 0.5:
					g.set_terrain(c, T.STAIRS)
					break
	return g


func idx(c: Vector2i) -> int:
	return c.y * w + c.x


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


func height_at(c: Vector2i) -> int:
	return heights[idx(c)]


func set_height(c: Vector2i, v: int) -> void:
	heights[idx(c)] = v
	_sight.clear()


func terrain_at(c: Vector2i) -> int:
	return terrain[idx(c)]


func set_terrain(c: Vector2i, t: int) -> void:
	terrain[idx(c)] = t
	_sight.clear()


## A copy at a new size. Cells that still fit keep their height and terrain; new cells are flat grass.
func resized(width: int, height: int) -> CombatGrid:
	var g := flat(width, height)
	for y in mini(h, height):
		for x in mini(w, width):
			var c := Vector2i(x, y)
			g.set_height(c, height_at(c))
			g.set_terrain(c, terrain_at(c))
	return g


## Saved maps store terrain as letters, one string per row: g grass, f forest, w water, r rock, d road,
## s stone, t stairs, u ruin.
## Heights are digits 0-8, one string per row. Easy to read and hand-edit in the JSON.
const LETTERS := {T.GRASS: "g", T.FOREST: "f", T.WATER: "w", T.ROCK: "r", T.ROAD: "d", T.STONE: "s", T.STAIRS: "t", T.RUIN: "u"}


func to_dict() -> Dictionary:
	var t_rows: Array[String] = []
	var h_rows: Array[String] = []
	for y in h:
		var tr := ""
		var hr := ""
		for x in w:
			tr += LETTERS[terrain_at(Vector2i(x, y))]
			hr += str(height_at(Vector2i(x, y)))
		t_rows.append(tr)
		h_rows.append(hr)
	return {"w": w, "h": h, "terrain": t_rows, "heights": h_rows}


static func from_dict(d: Dictionary) -> CombatGrid:
	var g := flat(int(d.get("w", 10)), int(d.get("h", 8)))
	var from_letter := {}
	for k in LETTERS:
		from_letter[LETTERS[k]] = k
	var t_rows: Array = d.get("terrain", [])
	var h_rows: Array = d.get("heights", [])
	for y in g.h:
		for x in g.w:
			var c := Vector2i(x, y)
			if y < t_rows.size() and x < String(t_rows[y]).length():
				g.set_terrain(c, from_letter.get(String(t_rows[y])[x], T.GRASS))
			if y < h_rows.size() and x < String(h_rows[y]).length():
				g.set_height(c, clampi(int(String(h_rows[y])[x]), 0, MAX_HEIGHT))
	return g


func step_cost(c: Vector2i) -> int:
	return STEP_COST[terrain_at(c)]


func cover(c: Vector2i) -> int:
	return COVER[terrain_at(c)]


func passable(c: Vector2i) -> bool:
	return in_bounds(c) and step_cost(c) < BLOCKED


## Can a piece with this Jump step between two neighbouring cells? Stairs on either end help it climb.
func can_step(a: Vector2i, b: Vector2i, jump: int) -> bool:
	var limit := jump
	if terrain_at(a) == T.STAIRS or terrain_at(b) == T.STAIRS:
		limit += STAIRS_CLIMB
	return absi(height_at(b) - height_at(a)) <= limit


## Highest point of the cell for line of sight: ground plus whatever stands on it.
func sight_top(c: Vector2i) -> float:
	return height_at(c) + SIGHT_BLOCK[terrain_at(c)]


func top_height() -> int:
	var m := 0
	for v in heights:
		m = maxi(m, v)
	return m


## Clear line from an eye one level above `from` to the body of whoever stands on `to`?
## Walks the straight line between cell centres; any cell in between whose top rises above the line blocks it.
func line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var key := ((from.y * w + from.x) << 16) | (to.y * w + to.x)
	if _sight.has(key):
		return _sight[key]
	var clear := _trace_sight(from, to)
	_sight[key] = clear
	return clear


func _trace_sight(from: Vector2i, to: Vector2i) -> bool:
	var a := Vector2(from) + Vector2(0.5, 0.5)
	var b := Vector2(to) + Vector2(0.5, 0.5)
	var ha := height_at(from) + 1.0
	var hb := height_at(to) + 0.6
	var steps := int(ceil(a.distance_to(b) * 4.0))
	for i in range(1, steps):
		var t := float(i) / steps
		var p := a.lerp(b, t)
		var c := Vector2i(int(floor(p.x)), int(floor(p.y)))
		if c == from or c == to or not in_bounds(c):
			continue
		if sight_top(c) > lerpf(ha, hb, t) + 0.05:
			return false
	return true

## Can a unit with this jump walk from the left deploy zone to the right one?
func connected(jump: int) -> bool:
	var start := Vector2i(-1, -1)
	for y in h:
		if passable(Vector2i(0, y)):
			start = Vector2i(0, y)
			break
	if start.x < 0:
		return false
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c.x == w - 1:
			return true
		for d in CombatRules.DIRS:
			var n: Vector2i = c + d
			if passable(n) and not seen.has(n) and can_step(c, n, jump):
				seen[n] = true
				queue.append(n)
	return false


## Passable cells in the deploy zone for team 0 (left) or 1 (right), center rows first.
func deploy_cells(team: int) -> Array[Vector2i]:
	var cols := range(DEPLOY_COLS) if team == 0 else range(w - DEPLOY_COLS, w)
	if team == 0:
		cols.reverse()  # front column first
	var out: Array[Vector2i] = []
	var rows := range(h)
	rows.sort_custom(func(a: int, b: int) -> bool: return absf(a - (h - 1) * 0.5) < absf(b - (h - 1) * 0.5))
	for x in cols:
		for y in rows:
			var c := Vector2i(x, y)
			if passable(c):
				out.append(c)
	return out

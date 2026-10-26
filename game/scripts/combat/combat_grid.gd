class_name CombatGrid
extends RefCounted
## The battle map: a height and a terrain type per cell.

enum T { GRASS, FOREST, WATER, ROCK, ROAD }

const BLOCKED := 999
const STEP_COST := {T.GRASS: 1, T.FOREST: 2, T.WATER: 3, T.ROCK: BLOCKED, T.ROAD: 1}
const COVER := {T.GRASS: 0, T.FOREST: 2, T.WATER: -2, T.ROCK: 0, T.ROAD: 0}
const MAX_HEIGHT := 3
const DEPLOY_COLS := 2  ## columns kept clear at each side for deployment

var w := 0
var h := 0
var heights := PackedInt32Array()
var terrain := PackedInt32Array()


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
			var lvl := clampi(int(hv * (MAX_HEIGHT + 1.5)) - 1, 0, MAX_HEIGHT)
			g.set_height(c, lvl)
			var tv := tn.get_noise_2d(x, y)
			var edge := x < DEPLOY_COLS or x >= width - DEPLOY_COLS
			var t := T.GRASS
			if lvl == 0 and tv > 0.05 and not edge:
				t = T.WATER
			elif lvl > 0 and tv > 0.25 - strangeness * 0.15:
				t = T.FOREST
			elif tv < -0.55 and not edge:
				t = T.ROCK
			g.terrain[g.idx(c)] = t
	return g


func idx(c: Vector2i) -> int:
	return c.y * w + c.x


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


func height_at(c: Vector2i) -> int:
	return heights[idx(c)]


func set_height(c: Vector2i, v: int) -> void:
	heights[idx(c)] = v


func terrain_at(c: Vector2i) -> int:
	return terrain[idx(c)]


func set_terrain(c: Vector2i, t: int) -> void:
	terrain[idx(c)] = t


## A copy at a new size. Cells that still fit keep their height and terrain; new cells are flat grass.
func resized(width: int, height: int) -> CombatGrid:
	var g := flat(width, height)
	for y in mini(h, height):
		for x in mini(w, width):
			var c := Vector2i(x, y)
			g.set_height(c, height_at(c))
			g.set_terrain(c, terrain_at(c))
	return g


## Saved maps store terrain as letters, one string per row: g grass, f forest, w water, r rock, d road.
## Heights are digits, one string per row. Easy to read and hand-edit in the JSON.
const LETTERS := {T.GRASS: "g", T.FOREST: "f", T.WATER: "w", T.ROCK: "r", T.ROAD: "d"}


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
			if passable(n) and not seen.has(n) and absi(height_at(n) - height_at(c)) <= jump:
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

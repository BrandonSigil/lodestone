class_name ExploreRules
extends RefCounted
## Rules for walking a map outside combat: paths, what the party can see (fog of war), who spots whom,
## which interaction options the party has, and how effects split between the map and the run.
## Pure functions on a CombatGrid, so tests run them headless.

const PARTY_SIGHT := 7  ## cells the party sees around each member (line of sight still applies)
## [USER] 2026-10-28: no fog of war for now; every map is drawn whole. The party still spots enemy groups
## (and gets spotted) by line of sight within PARTY_SIGHT. True brings back each map's own `fog` setting.
const FOG_OF_WAR := false
const ENEMY_SIGHT := 4  ## default for groups; a map can set its own per group
const INTERACT_CLIMB := 2  ## a thing on a ledge more than this above or below can't be reached
const HINT_RANGE := 3  ## the interact icon lights up when the leader is this close
const NOISE_RANGE := 12  ## a noisy failure draws the nearest group within this many cells
const JOIN_RANGE := 3  ## other groups this close to a fight join it

## Effects the map handles itself. Anything else ("food:+3", "hp_one:-2") goes to TrailRules on the run.
const MAP_EFFECTS := ["open", "remove", "noise", "reveal", "exit", "fight", "sneak_attack", "ambushed", "pacify", "travel", "fish"]


## A beaten boss stays beaten for good, through falls and new trips in ([USER] 2026-10-29: once the
## Lich King is cleared the party doesn't fight through his map again unless it wants to). Other groups
## come back after a fall or a trip out, as before.
static func beaten_flag(map_name: String, group_id: String) -> String:
	return "beaten_%s_%s" % [map_name, group_id]


## Set when the party gets past a boss, beaten or escaped by its fight's exit: what completes the region and opens
## what comes after ([USER] 2026-10-30 design-world-gate: sneaking past the Lich King is fine too). Only beating
## him pays the boss XP and his loot.
static func passed_flag(map_name: String, group_id: String) -> String:
	return "passed_%s_%s" % [map_name, group_id]


## Set after the party's first fight with a boss of this class, won, lost or escaped ([USER] design-boss-retry,
## "you learn him"): from then on his card shows his HP and every move, for good.
static func learned_flag(class_id: String) -> String:
	return "learned_%s" % class_id


## The flag that keeps a lasting reward taken for good ([USER] omr-10): stat items, keys, rare caches.
static func taken_flag(map_name: String, thing_id: String) -> String:
	return "got_%s_%s" % [map_name, thing_id]


const LASTING_KINDS := ["boost", "key", "rare", "find"]  ## find: a one-time cache; its event is the effects, "rod:+1"


## Bosses and elite groups, once beaten, stay beaten.
static func stays_beaten(map_name: String, group: Dictionary, flags: Array) -> bool:
	return (bool(group.get("boss", false)) or bool(group.get("elite", false))) and flags.has(beaten_flag(map_name, String(group.id)))


## The stat mods an elite group's foes fight with (data/combat.csv: tougher; [USER] pc-6, pc-15).
## The road's cost ([USER] 2026-10-30, "Fights must cost"; docs/design/outing-tuning.md): the ordinary groups on an
## explore map come with combat.csv `explore_foe_hp_pct` % of their HP. Elite groups and bosses are tuned by hand.
static func road_mods() -> Dictionary:
	var pct := int(CombatRules.num("explore_foe_hp_pct"))
	return {} if pct <= 0 or pct == 100 else {"hp_pct": pct}


static func elite_mods() -> Dictionary:
	return {"hp_pct": int(CombatRules.num("elite_hp_pct")), "damage": int(CombatRules.num("elite_damage")),
		"defense": int(CombatRules.num("elite_armor"))}


## Foes by depth ([USER] design-foe-scale): a foe on a level-N place rolls the heroes' growth table (data/growth.csv)
## once per level above 1, as a hero levelling up would, seeded by the place, the group and its slot so the same foe
## always comes out the same. Casters roll the mage's odds, ranged foes the archer's, the rest the knight's.
## Returns stat mods for CombatUnit.enemy ({} at level 1). Boss groups never roll: callers pass group_depth.
static func depth_mods(map_name: String, level: int, group_id: String, slot: int, cls: ClassDef) -> Dictionary:
	if level <= 1:
		return {}
	var row := "mage" if cls.magic else ("archer" if cls.range_max > 1 else "knight")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|%d|%d" % [map_name, group_id, slot, level])
	var s := LevelRules.fresh()
	LevelRules.gain(s, (level - 1) * int(Db.levels.get("xp_per_level", 100)), Db.levels, Db.growth.get(row, {}), rng)
	return LevelRules.bonus(s, Db.levels)


## The depth a group's foes roll at: the place's level, but 1 for a boss group, whose numbers are tuned by hand
## (game designer 2026-10-30).
static func group_depth(level: int, group: Dictionary) -> int:
	return 1 if bool(group.get("boss", false)) else level


## Elite groups on these maps still standing: what the overworld's elite badge warns of.
static func elites_left(maps: Array, flags: Array) -> int:
	var n := 0
	for name: String in maps:
		if name == "":
			continue
		for g: Dictionary in ExploreMap.load_named(name).groups:
			if g.get("elite", false) and not flags.has(beaten_flag(name, String(g.id))):
				n += 1
	return n


static func dist(a: Vector2i, b: Vector2i) -> float:
	return Vector2(CombatGrid.ground(a)).distance_to(Vector2(CombatGrid.ground(b)))


# --- sight ------------------------------------------------------------------------

## Every place within radius of any eye that the eye has a clear line to (a deck and the lane under it apart).
static func sight(grid: CombatGrid, eyes: Array, radius: int) -> Dictionary:
	var out := {}
	for e: Vector2i in eyes:
		out[e] = true
		var g := CombatGrid.ground(e)
		for y in range(maxi(0, g.y - radius), mini(grid.h, g.y + radius + 1)):
			for x in range(maxi(0, g.x - radius), mini(grid.w, g.x + radius + 1)):
				for c in grid.places_at(Vector2i(x, y)):  # a deck and the lane under it are seen apart
					if out.has(c) or dist(e, c) > radius + 0.25:
						continue
					if grid.line_of_sight(e, c):
						out[c] = true
	return out


## Does anyone at `from` see anyone at `to` within radius?
static func sees(grid: CombatGrid, from: Array, to: Array, radius: int) -> bool:
	for a: Vector2i in from:
		for b: Vector2i in to:
			if dist(a, b) <= radius + 0.25 and grid.line_of_sight(a, b):
				return true
	return false


# --- locked rooms -----------------------------------------------------------------

## Every place (cells and decks) a walker with this Jump can get to from the `from` places, on the steps walking takes.
static func reach(grid: CombatGrid, from: Array, jump: int) -> Dictionary:
	var out := {}
	var todo: Array[Vector2i] = []
	for c: Vector2i in from:
		if grid.in_bounds(c) and not out.has(c):
			out[c] = true
			todo.append(c)
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d in STEPS:
			for n in grid.places_next(c, d):
				if not out.has(n) and can_step_to(grid, c, n, jump):
					out[n] = true
					todo.append(n)
	return out


## Cells behind a shut door or rubble: ground the party can't reach (`open` is what it can) but could once
## one of `doors` opens, plus the walls and ledges that face only that ground. A door shows while it touches
## open ground; one deeper in (a door off a locked corridor) is locked with the rest.
## [USER] 2026-10-29: these rooms stay fogged until the party gets in.
static func locked_cells(grid: CombatGrid, open: Dictionary, doors: Array, jump: int) -> Dictionary:
	var past := {}
	var todo: Array[Vector2i] = []
	for door: Vector2i in doors:
		past[door] = true
		todo.append(door)
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		var through := doors.has(c)  # a doorway leads onto whatever ground lies past it
		for d in CombatRules.DIRS:
			var n: Vector2i = c + d
			if past.has(n) or open.has(n) or not grid.in_bounds(n):
				continue
			if doors.has(n) or (grid.passable(n) and (through or grid.can_step(c, n, jump))):
				past[n] = true
				todo.append(n)
	var out := {}
	for c: Vector2i in past:
		if not doors.has(c) or not STEPS.any(func(e: Vector2i) -> bool: return open.has(c + e)):
			out[c] = true
	var ground := out.keys()
	for c: Vector2i in ground:
		for d in STEPS:
			var w: Vector2i = c + d
			if out.has(w) or not grid.in_bounds(w) or grid.passable(w) or doors.has(w) or open.has(w):
				continue
			if not STEPS.any(func(e: Vector2i) -> bool: return open.has(w + e)):
				out[w] = true
	return out


# --- walls ------------------------------------------------------------------------

const WALL_TALL := 3  ## a back wall stands this many levels over the floor beside it
const WALL_HALF := 1  ## a block standing in a room (a tomb, an altar) stands this high
const FENCE_RUN := 3  ## a wall between two floors at least this long (or joining a wall) is a fence (CombatGrid.fences)


## Walls maps ([USER] 2026-10-29). Rock beside ground is a wall: WALL_TALL over that ground where nothing walkable
## lies behind it (back walls), WALL_HALF where floor lies both behind and in front (inner walls). A front wall
## (floor behind, none in front but a doorway in its own line) becomes floor like the floor behind it, and the
## board draws a stubby wall on its outer edge. A run of rim cells that would join two areas a walker couldn't
## get between (round a shut door, say) stays a half wall instead. Rock touching no ground is void. Run it with
## shut doors already in place. `front`: the two directions toward the camera.
## `outdoors` ([USER] 2026-10-29): zones that are outside, not interior. Their rock between two floors stays
## natural rock; their edge rock is void, so the forest skirt's tree line frames the area, except a back edge
## facing a pocket the world's edge doesn't reach (the space between buildings), which is a tall wall.
## `tall`: how many levels a back wall stands over its floor (a map's wall_tall).
## `kit` ([USER] 2026-10-30, a map's wall_kit): back walls are thin wall pieces from a kit, not blocks. Their cells
## stay at the floor's height and the board stands a piece on each, on the edge it shares with the room.
## Returns {"walls": rock cells drawn as walls, "rims": front-edge floor cells, "backs": back-wall cell -> the
## directions toward the room it faces (two at a corner), "fences": walls between two floors, now
## CombatGrid.fences, "plugs": rock shut in by walls -> the level its dark block stands at}.
static func shape_walls(grid: CombatGrid, front: Array, outdoors := [], tall := WALL_TALL, kit := false) -> Dictionary:
	var f0: Vector2i = front[0]
	var f1: Vector2i = front[1]
	var back: Array[Vector2i] = [-f0, -f1, -f0 - f1]
	var heights := {}
	var rims := {}
	var floors := {}
	var backs := {}
	var fences: Array[Vector2i] = []
	var mass: Array[Vector2i] = []
	var world := _world(grid)
	for y in grid.h:
		for x in grid.w:
			var c := Vector2i(x, y)
			if grid.terrain_at(c) != CombatGrid.T.ROCK:
				continue
			var floor_h := -1
			for d in STEPS:
				if _ground(grid, c + d):
					floor_h = maxi(floor_h, grid.height_at(c + d))
			if floor_h < 0:
				mass.append(c)
				continue
			var outside := outdoors.has(grid.zone_at(c))
			var behind := -1
			for i in back.size():
				if _ground(grid, c + back[i]):
					behind = i
					break
			floors[c] = floor_h
			if outside:
				var pocket := behind < 0 and not STEPS.any(func(d: Vector2i) -> bool: return world.has(c + d))
				if pocket:
					heights[c] = floor_h + tall
				elif behind < 0 or _open_front(grid, c, f0, f1):
					mass.append(c)
				continue
			if behind < 0:
				heights[c] = floor_h + tall
				if kit:
					heights[c] = floor_h
					backs[c] = _room_sides(grid, c, f0, f1)
			elif _open_front(grid, c, f0, f1):
				rims[c] = c + back[behind]
			else:
				fences.append(c)
	for c: Vector2i in _joining_rims(grid, rims):
		rims.erase(c)
		fences.append(c)
	# A wall between two floors is a fence ([USER] 2026-10-30): the higher floor's ground with a very short,
	# thin wall along it, still solid (CombatGrid.fences). A lone block or a pair standing in a room (a tomb, an
	# altar) is no wall: it keeps its half-wall block, unless it runs on into a wall.
	var short := _short_runs(fences, heights, FENCE_RUN)
	for c: Vector2i in short:
		fences.erase(c)
		heights[c] = int(floors[c]) + WALL_HALF
	var looks := {}
	for c: Vector2i in fences:
		var best := c
		for d in STEPS:
			if _ground(grid, c + d) and (best == c or grid.height_at(c + d) > grid.height_at(best)):
				best = c + d
		looks[c] = best
	# Rock shut in by the walls (a pocket, not the world round the map) is solid dark rock, not a hole to the sky
	# ([USER] 2026-11-01: "holes everywhere"): the board draws it as a dark block at the lowest floor beside it.
	var plugs := {}
	for c in mass:
		if not world.has(c) and not outdoors.has(grid.zone_at(c)):
			plugs[c] = _plug_level(c, floors)
	for c in mass:
		grid.set_terrain(c, CombatGrid.T.VOID)
	for c: Vector2i in heights:
		grid.set_height(c, int(heights[c]))
	for c: Vector2i in looks:
		grid.set_terrain(c, grid.terrain_at(looks[c]))
		grid.set_height(c, int(floors[c]))
		grid.fences[c] = true
	for c: Vector2i in rims:
		var from: Vector2i = rims[c]
		grid.set_terrain(c, grid.terrain_at(from))
		grid.set_height(c, grid.height_at(from))
		rims[c] = true
	return {"walls": heights, "rims": rims, "backs": backs, "fences": grid.fences, "plugs": plugs}


## A shut-in rock cell's level: the lowest floor of the walls nearest it (rings out to 4), so it never stands
## taller than the ground round it.
static func _plug_level(c: Vector2i, floors: Dictionary) -> int:
	for r in range(1, 5):
		var low := 1 << 20
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) == r and floors.has(c + Vector2i(dx, dy)):
					low = mini(low, int(floors[c + Vector2i(dx, dy)]))
		if low < (1 << 20):
			return low
	return 0


## Fence cells in runs (4-neighbour) shorter than `run` that touch no wall cell.
static func _short_runs(cells: Array[Vector2i], walls: Dictionary, run: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var left := {}
	for c in cells:
		left[c] = true
	while not left.is_empty():
		var start: Vector2i = left.keys()[0]
		var part: Array[Vector2i] = [start]
		left.erase(start)
		var i := 0
		var joined := false
		while i < part.size():
			for d in CombatRules.DIRS:
				var n: Vector2i = part[i] + d
				if left.has(n):
					left.erase(n)
					part.append(n)
				elif walls.has(n):
					joined = true
			i += 1
		if part.size() < run and not joined:
			out.append_array(part)
	return out


## The sides of a back-wall cell that face the room: the front directions with floor beyond them, or both at a
## corner (floor only on the diagonal).
static func _room_sides(grid: CombatGrid, c: Vector2i, f0: Vector2i, f1: Vector2i) -> Array:
	var out := []
	for d: Vector2i in [f0, f1]:
		if _ground(grid, c + d):
			out.append(d)
	return out if not out.is_empty() else [f0, f1]


## The open world round the map: everything off the grid, plus the void and the rock touching no ground that
## reach the grid's edge. Rock touching no ground shut in by walls is a pocket, not the world.
static func _world(grid: CombatGrid) -> Dictionary:
	var open := func(c: Vector2i) -> bool:
		if grid.terrain_at(c) == CombatGrid.T.VOID:
			return true
		if grid.terrain_at(c) != CombatGrid.T.ROCK:
			return false
		for d in STEPS:
			if _ground(grid, c + d):
				return false
		return true
	var out := {}
	var todo: Array[Vector2i] = []
	for y in range(-1, grid.h + 1):
		for x in range(-1, grid.w + 1):
			var c := Vector2i(x, y)
			if not grid.in_bounds(c):
				out[c] = true
			elif (x == 0 or y == 0 or x == grid.w - 1 or y == grid.h - 1) and open.call(c):
				out[c] = true
				todo.append(c)
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d in CombatRules.DIRS:
			var n: Vector2i = c + d
			if grid.in_bounds(n) and not out.has(n) and open.call(n):
				out[n] = true
				todo.append(n)
	return out


## Rim cells in runs that touch more than one walkable area (as a Jump 1 walker finds them before the rims open).
static func _joining_rims(grid: CombatGrid, rims: Dictionary) -> Array[Vector2i]:
	var area := {}
	var n_areas := 0
	for y in grid.h:
		for x in grid.w:
			var c := Vector2i(x, y)
			if area.has(c) or not _ground(grid, c):
				continue
			for k: Vector2i in reach(grid, [c], 1):
				area[k] = n_areas
			n_areas += 1
	var out: Array[Vector2i] = []
	var done := {}
	for start: Vector2i in rims:
		if done.has(start):
			continue
		var run: Array[Vector2i] = [start]
		var touched := {}
		done[start] = true
		var i := 0
		while i < run.size():
			var c := run[i]
			i += 1
			for d in STEPS:
				var n: Vector2i = c + d
				if area.has(n):
					touched[area[n]] = true
				elif rims.has(n) and not done.has(n):
					done[n] = true
					run.append(n)
		if touched.size() > 1:
			out.append_array(run)
	return out


## No ground in front of this wall, except a doorway: a gap in its own wall line with rock on its far side.
static func _open_front(grid: CombatGrid, c: Vector2i, f0: Vector2i, f1: Vector2i) -> bool:
	for pair: Array in [[f0, f1], [f1, f0], [f0 + f1, Vector2i.ZERO]]:
		var d: Vector2i = pair[0]
		var o: Vector2i = pair[1]
		var n := c + d
		if not _ground(grid, n):
			continue
		var doorway := o != Vector2i.ZERO and _ground(grid, c - o) and _ground(grid, n - o) \
			and grid.in_bounds(n + d) and grid.terrain_at(n + d) == CombatGrid.T.ROCK
		if not doorway:
			return false
	return true


static func _ground(grid: CombatGrid, c: Vector2i) -> bool:
	return grid.in_bounds(c) and grid.step_cost(c) < CombatGrid.BLOCKED and not grid.fences.has(c)


# --- walking ----------------------------------------------------------------------

## The party walks at the pace of its worst climber, so everyone can follow the leader's steps.
static func party_jump(units: Array) -> int:
	var j := 99
	for u: CombatUnit in units:
		j = mini(j, u.jump)
	return 1 if j == 99 else j


## Cheapest path from `from` to `to`, both included. Empty when there is none.
## `blocked`: cells nobody may enter (enemies, things). `known`: cells the party has seen; empty = every cell.
## diagonal: walking also takes the four diagonal steps (never cutting a corner), so a path up the screen
## runs straight instead of zigzagging. Fights keep the four straight steps.
static func find_path(grid: CombatGrid, from: Vector2i, to: Vector2i, jump: int, blocked := {}, known := {}, diagonal := false) -> Array[Vector2i]:
	var none: Array[Vector2i] = []
	if not _open(grid, to, blocked, known) and to != from:
		return none
	var cost := {from: 0}
	var prev := {}
	var frontier: Array = [[0, from]]
	while not frontier.is_empty():
		var best := 0
		for i in frontier.size():
			if frontier[i][0] < frontier[best][0]:
				best = i
		var item: Array = frontier[best]
		frontier.remove_at(best)
		var c: Vector2i = item[1]
		if c == to:
			break
		if int(item[0]) > int(cost[c]):
			continue
		for d in (STEPS if diagonal else CombatRules.DIRS):
			for n in grid.places_next(c, d):
				if not can_step_to(grid, c, n, jump, blocked, known):
					continue
				var nc: int = int(cost[c]) + grid.step_cost(n) * (14 if d.x != 0 and d.y != 0 else 10)
				if not cost.has(n) or nc < int(cost[n]):
					cost[n] = nc
					prev[n] = c
					frontier.append([nc, n])
	if not cost.has(to):
		return none
	var path: Array[Vector2i] = [to]
	while path[0] != from:
		path.push_front(prev[path[0]])
	return path


static func _open(grid: CombatGrid, c: Vector2i, blocked: Dictionary, known: Dictionary) -> bool:
	return grid.walkable(c) and not blocked.has(c) and (known.is_empty() or known.has(CombatGrid.ground(c)))


# --- free walking (WASD) ------------------------------------------------------------

const WALK_SPEED := 5.0  ## cells a second, on keys and along clicked paths
const BODY := 0.26  ## the leader's half-width in cells: what bumps into walls on keys


## WASD walking is free, not cell by cell: move a body of half-width `body` from `pos` by `move` (cell units,
## cell c spans c to c + 1), one axis at a time so it slides along walls. When only a corner is in the way
## it eases sideways into the open lane instead of stopping, so nobody has to line up with a doorway.
## Climbing follows the cell rules: every cell the body touches must be a step the walker can take from
## the place under its middle. `at` is that place when the walker stands on a deck (see CombatGrid.DECK).
static func slide(grid: CombatGrid, pos: Vector2, move: Vector2, body: float, jump: int, blocked := {}, at := CombatGrid.NO_PLACE) -> Vector2:
	var from := Vector2i(pos.floor())
	if CombatGrid.ground(at) == from:
		from = at
	var p := pos
	for axis in 2:
		var d: float = move[axis]
		if d == 0.0:
			continue
		var q := p
		q[axis] += d
		if body_fits(grid, from, q, body, jump, blocked):
			p = q
			continue
		var side := 1 - axis
		var lane := floorf(p[side]) + 0.5
		var straight := q
		straight[side] = lane
		if absf(p[side] - lane) > 0.01 and body_fits(grid, from, straight, body, jump, blocked):
			p[side] = move_toward(p[side], lane, absf(d))  # a corner, not a wall: ease round it
			continue
		for i in 4:  # a wall: close up to it
			d *= 0.5
			q = p
			q[axis] += d
			if body_fits(grid, from, q, body, jump, blocked):
				p = q
	return p


## Does a body centred on `q` touch only cells it may stand in, coming from place `from`?
static func body_fits(grid: CombatGrid, from: Vector2i, q: Vector2, body: float, jump: int, blocked := {}) -> bool:
	for y in range(floori(q.y - body + 0.001), floori(q.y + body - 0.001) + 1):
		for x in range(floori(q.x - body + 0.001), floori(q.x + body - 0.001) + 1):
			if grid.step_place(from, Vector2i(x, y), jump, blocked) == CombatGrid.NO_PLACE:
				return false
	return true


## The eight grid steps walking paths take (fights keep the four straight ones).
const STEPS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]


## Can the leader take one step from place `from` onto the next place `to` (diagonals too)? A diagonal can't
## cut a corner: on both sides there must be a place it could step through on the way.
static func can_step_to(grid: CombatGrid, from: Vector2i, to: Vector2i, jump: int, blocked := {}, known := {}) -> bool:
	if not _open(grid, to, blocked, known):
		return false
	var d := CombatGrid.ground(to) - CombatGrid.ground(from)
	if d.x == 0 or d.y == 0:
		return grid.can_step(from, to, jump)
	for side: Vector2i in [Vector2i(d.x, 0), Vector2i(0, d.y)]:
		var through := false
		for mid in grid.places_next(from, side):
			if _open(grid, mid, blocked, known) and grid.can_step(from, mid, jump) and grid.can_step(mid, to, jump):
				through = true
				break
		if not through:
			return false
	return true


## The thing F uses ([USER] bug f-key, 2026-10-30): the nearest of `things` (already shown and not done) whose
## cell the board draws lit (`lit`: cell -> 2) within HINT_RANGE of `at`; a tie goes to the one `facing` points
## at. It's the one the "!" with the F hint marks, so the key always answers the hint: no line-of-sight test
## here (the board lights every cell while fog of war is off), and walking up to it goes round any corner.
static func thing_to_use(things: Array, at: Vector2i, facing: Vector2i, lit: Dictionary) -> Dictionary:
	var best := {}
	var best_d := INF
	var face := Vector2(facing).normalized()
	for t: Dictionary in things:
		var c: Vector2i = t.cell
		if lit.get(CombatGrid.ground(c), 0) != 2:
			continue
		var d := dist(at, c)
		if d > HINT_RANGE:
			continue
		d -= 0.01 * Vector2(CombatGrid.ground(c) - CombatGrid.ground(at)).normalized().dot(face)
		if d < best_d:
			best = t
			best_d = d
	return best


## Things the party walks over instead of round: doorways and ways out (Brandon's bug, 2026-10-30: a door's
## "!" on the lane in front of a house was an invisible wall). A shut `door` and `rubble` still block.
const WALK_ON_KINDS := ["enter", "exit"]


## Can someone standing at `at` use the thing at `thing`? Next to it (diagonals count) and not a cliff apart.
static func can_use_from(grid: CombatGrid, at: Vector2i, thing: Vector2i) -> bool:
	var g := CombatGrid.ground(at) - CombatGrid.ground(thing)
	if maxi(absi(g.x), absi(g.y)) > 1 or at == thing:
		return false
	return absi(grid.height_at(at) - grid.height_at(thing)) <= INTERACT_CLIMB


## Shortest walk to a cell from which the thing can be used. Empty when it can't be reached.
static func path_to_use(grid: CombatGrid, from: Vector2i, thing: Vector2i, jump: int, blocked := {}, known := {}, diagonal := false) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	if from == thing or can_use_from(grid, from, thing):  # standing on a doorway uses it too
		best.append(from)
		return best
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for c in grid.places_next(thing, Vector2i(dx, dy)):
				if not grid.in_bounds(c) or not can_use_from(grid, c, thing):
					continue
				var p := find_path(grid, from, c, jump, blocked, known, diagonal)
				if not p.is_empty() and (best.is_empty() or p.size() < best.size()):
					best = p
	return best


## How far from the leader a member may start a fight, in steps: quick pieces fan out wide,
## heavy ones start at the leader's side. A sneak attack gives everyone a step more; when the party
## is caught (ambushed) everyone starts right next to the leader.
const DEPLOY_FROM_MOVE := 3  ## radius = move - this, at least 1

static func deploy_radius(u: CombatUnit, how: String) -> int:
	if how == "ambushed":
		return 1
	return maxi(1, u.move - DEPLOY_FROM_MOVE) + (1 if how == "sneak" else 0)


## Cells a member may start a fight on: walkable for them within `radius` steps of the leader
## (so never behind a wall the leader can't get past), not the leader's own cell, not blocked.
static func deploy_cells(grid: CombatGrid, lead: Vector2i, u: CombatUnit, radius: int, blocked := {}) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var steps := {lead: 0}
	var queue: Array[Vector2i] = [lead]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if int(steps[c]) >= radius:
			continue
		for d in CombatRules.DIRS:
			for n in grid.places_next(c, d):
				if steps.has(n) or not grid.passable(n) or blocked.has(n) or not grid.can_step(c, n, u.jump):
					continue
				steps[n] = int(steps[c]) + 1
				queue.append(n)
				out.append(n)
	return out


## Starting cells for the party, leader first and staying put; each other member takes the free cell
## of their ring closest to the leader. Members with no room are left out of the result.
static func auto_deploy(grid: CombatGrid, party: Array, how: String, blocked := {}) -> Dictionary:
	var lead: CombatUnit = party[0]
	var out := {lead: lead.cell}
	var taken := blocked.duplicate()
	taken[lead.cell] = true
	for i in range(1, party.size()):
		var u: CombatUnit = party[i]
		for c in deploy_cells(grid, lead.cell, u, deploy_radius(u, how), blocked):
			if not taken.has(c):
				out[u] = c
				taken[c] = true
				break
	return out


# --- interactions -------------------------------------------------------------------

## Rows of data/explore_events.csv. Each option: {"key", "need", "check", "dc", "win", "lose"}.
static func parse_events(rows: Array[Dictionary]) -> Dictionary:
	var out := {}
	for row in rows:
		var ev := {"id": row.id, "text_key": row.text_key, "options": [], "portrait": row.get("portrait", "")}
		for n in range(1, 6):
			var key: String = row.get("opt%d_key" % n, "")
			if key == "":
				continue
			ev.options.append({
				"key": key,
				"need": row.get("opt%d_need" % n, ""),
				"check": row.get("opt%d_check" % n, "none"),
				"dc": int(row.get("opt%d_dc" % n, "0")),
				"win": row.get("opt%d_win" % n, ""),
				"lose": row.get("opt%d_lose" % n, ""),
			})
		out[ev.id] = ev
	return out


## "" (anyone), "skill:<check>" (someone has it), "class:<id>", "char:<id>", "item:<id>" (the pack holds one),
## "flag:<id>" or "noflag:<id>" (a meta flag is or isn't set), "party:<id>" or "noparty:<id>" (a companion is or
## isn't in the party: have.party); several joined by "&" must all hold.
## `defs`: the party's CharacterDefs. have: {"items": id -> count, "flags": Array of set flags}.
static func need_met(need: String, defs: Array, have := {}) -> bool:
	if need == "":
		return true
	if need.contains("&"):
		return Array(need.split("&", false)).all(func(n: String) -> bool: return need_met(n.strip_edges(), defs, have))
	var kv := need.split(":")
	if kv.size() != 2:
		return false
	match kv[0]:
		"item":
			return int(have.get("items", {}).get(kv[1], 0)) > 0
		"noitem":  # the pack holds none (the dock's NO ROD line)
			return int(have.get("items", {}).get(kv[1], 0)) <= 0
		"flag":
			return have.get("flags", []).has(kv[1])
		"noflag":
			return not have.get("flags", []).has(kv[1])
		"party":  # the companion is coming along / staying home ([USER] pc-10)
			return have.get("party", []).has(kv[1])
		"noparty":
			return not have.get("party", []).has(kv[1])
	for d: CharacterDef in defs:
		match kv[0]:
			"skill":
				if d.skill(kv[1]) > 0:
					return true
			"class":
				if d.class_def != null and String(d.class_def.id) == kv[1]:
					return true
			"char":
				if String(d.id) == kv[1]:
					return true
	return false


## The builds a weapon rack offers ([USER] 2026-10-30, the rack's character sheets): every option of its event
## whose effect takes a weapon, in the event's order, open or not (the book waits until it's found):
## [{"weapon": id, "option": the option, "open": bool}].
static func rack_builds(ev: Dictionary, defs: Array, have := {}) -> Array:
	var out := []
	for o: Dictionary in ev.get("options", []):
		for part in String(o.win).split(";", false):
			if part.strip_edges().begins_with("weapon:"):
				out.append({"weapon": part.strip_edges().substr(7), "option": o, "open": need_met(o.need, defs, have)})
	return out


## The options this party can pick.
static func options_for(ev: Dictionary, defs: Array, have := {}) -> Array:
	return ev.options.filter(func(o: Dictionary) -> bool: return need_met(o.need, defs, have))


## Splits "open;food:+3;noise" into the map's own effects (in order) and the run effects string.
static func split_effects(effects: String) -> Dictionary:
	var map_fx: Array[String] = []
	var run_fx: PackedStringArray = []
	for part in effects.split(";", false):
		var p := part.strip_edges()
		if p in MAP_EFFECTS:
			map_fx.append(p)
		else:
			run_fx.append(p)
	return {"map": map_fx, "run": ";".join(run_fx)}

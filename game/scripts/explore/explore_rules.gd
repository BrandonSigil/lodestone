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
const MAP_EFFECTS := ["open", "remove", "noise", "reveal", "exit", "fight", "sneak_attack", "ambushed", "pacify", "travel"]


## A beaten boss stays beaten for good, through falls and new trips in ([USER] 2026-10-29: once the
## Lich King is cleared the party doesn't fight through his map again unless it wants to). Other groups
## come back after a fall or a trip out, as before.
static func beaten_flag(map_name: String, group_id: String) -> String:
	return "beaten_%s_%s" % [map_name, group_id]


## Bosses and elite groups, once beaten, stay beaten.
static func stays_beaten(map_name: String, group: Dictionary, flags: Array) -> bool:
	return (bool(group.get("boss", false)) or bool(group.get("elite", false))) and flags.has(beaten_flag(map_name, String(group.id)))


## The stat mods an elite group's foes fight with (data/combat.csv: tougher; [USER] pc-6, pc-15).
static func elite_mods() -> Dictionary:
	return {"hp_pct": int(CombatRules.num("elite_hp_pct")), "damage": int(CombatRules.num("elite_damage")),
		"defense": int(CombatRules.num("elite_armor"))}


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
	return Vector2(a).distance_to(Vector2(b))


# --- sight ------------------------------------------------------------------------

## Every cell within radius of any eye that the eye has a clear line to.
static func sight(grid: CombatGrid, eyes: Array, radius: int) -> Dictionary:
	var out := {}
	for e: Vector2i in eyes:
		out[e] = true
		for y in range(maxi(0, e.y - radius), mini(grid.h, e.y + radius + 1)):
			for x in range(maxi(0, e.x - radius), mini(grid.w, e.x + radius + 1)):
				var c := Vector2i(x, y)
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

## Every cell a walker with this Jump can get to from the `from` cells, on the steps walking takes.
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
			var n: Vector2i = c + d
			if not out.has(n) and can_step_dir(grid, c, d, jump):
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
const WALL_HALF := 1  ## a wall between two floors stands this high


## Walls maps ([USER] 2026-10-29). Rock beside ground is a wall: WALL_TALL over that ground where nothing walkable
## lies behind it (back walls), WALL_HALF where floor lies both behind and in front (inner walls). A front wall
## (floor behind, none in front but a doorway in its own line) becomes floor like the floor behind it, and the
## board draws a stubby wall on its outer edge. A run of rim cells that would join two areas a walker couldn't
## get between (round a shut door, say) stays a half wall instead. Rock touching no ground is void. Run it with
## shut doors already in place. `front`: the two directions toward the camera.
## `outdoors` ([USER] 2026-10-29): zones that are outside, not interior. Their rock between two floors stays
## natural rock; their edge rock is void, so the forest skirt's tree line frames the area, except a back edge
## facing a pocket the world's edge doesn't reach (the space between buildings), which is a tall wall.
## Returns {"walls": rock cells drawn as walls, "rims": front-edge floor cells}.
static func shape_walls(grid: CombatGrid, front: Array, outdoors := []) -> Dictionary:
	var f0: Vector2i = front[0]
	var f1: Vector2i = front[1]
	var back: Array[Vector2i] = [-f0, -f1, -f0 - f1]
	var heights := {}
	var rims := {}
	var floors := {}
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
					heights[c] = floor_h + WALL_TALL
				elif behind < 0 or _open_front(grid, c, f0, f1):
					mass.append(c)
				continue
			if behind < 0:
				heights[c] = floor_h + WALL_TALL
			elif _open_front(grid, c, f0, f1):
				rims[c] = c + back[behind]
			else:
				heights[c] = floor_h + WALL_HALF
	for c: Vector2i in _joining_rims(grid, rims):
		rims.erase(c)
		heights[c] = int(floors[c]) + WALL_HALF
	for c in mass:
		grid.set_terrain(c, CombatGrid.T.VOID)
	for c: Vector2i in heights:
		grid.set_height(c, int(heights[c]))
	for c: Vector2i in rims:
		var from: Vector2i = rims[c]
		grid.set_terrain(c, grid.terrain_at(from))
		grid.set_height(c, grid.height_at(from))
		rims[c] = true
	return {"walls": heights, "rims": rims}


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
	return grid.in_bounds(c) and grid.step_cost(c) < CombatGrid.BLOCKED


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
			var n: Vector2i = c + d
			if d.x != 0 and d.y != 0:
				if not can_step_dir(grid, c, d, jump, blocked, known):
					continue
			elif not _open(grid, n, blocked, known) or not grid.can_step(c, n, jump):
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
	return grid.passable(c) and not blocked.has(c) and (known.is_empty() or known.has(c))


# --- free walking (WASD) ------------------------------------------------------------

const WALK_SPEED := 5.0  ## cells a second, on keys and along clicked paths
const BODY := 0.26  ## the leader's half-width in cells: what bumps into walls on keys


## WASD walking is free, not cell by cell: move a body of half-width `body` from `pos` by `move` (cell units,
## cell c spans c to c + 1), one axis at a time so it slides along walls. When only a corner is in the way
## it eases sideways into the open lane instead of stopping, so nobody has to line up with a doorway.
## Climbing follows the cell rules: every cell the body touches must be a step the walker can take from
## the cell under its middle.
static func slide(grid: CombatGrid, pos: Vector2, move: Vector2, body: float, jump: int, blocked := {}) -> Vector2:
	var from := Vector2i(pos.floor())
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


## Does a body centred on `q` touch only cells it may stand in, coming from cell `from`?
static func body_fits(grid: CombatGrid, from: Vector2i, q: Vector2, body: float, jump: int, blocked := {}) -> bool:
	for y in range(floori(q.y - body + 0.001), floori(q.y + body - 0.001) + 1):
		for x in range(floori(q.x - body + 0.001), floori(q.x + body - 0.001) + 1):
			var c := Vector2i(x, y)
			if c == from:
				continue
			if not grid.passable(c) or blocked.has(c) or not grid.can_step(from, c, jump):
				return false
	return true


## The eight grid steps walking paths take (fights keep the four straight ones).
const STEPS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]


## Can the leader take one step from `from` along d? A diagonal can't cut a corner: both cells beside it
## must be walkable on the way.
static func can_step_dir(grid: CombatGrid, from: Vector2i, d: Vector2i, jump: int, blocked := {}, known := {}) -> bool:
	var to := from + d
	if not _open(grid, to, blocked, known):
		return false
	if d.x == 0 or d.y == 0:
		return grid.can_step(from, to, jump)
	for side: Vector2i in [Vector2i(d.x, 0), Vector2i(0, d.y)]:
		var mid := from + side
		if not _open(grid, mid, blocked, known) or not grid.can_step(from, mid, jump) or not grid.can_step(mid, to, jump):
			return false
	return true


## Can someone standing at `at` use the thing at `thing`? Next to it (diagonals count) and not a cliff apart.
static func can_use_from(grid: CombatGrid, at: Vector2i, thing: Vector2i) -> bool:
	if maxi(absi(at.x - thing.x), absi(at.y - thing.y)) > 1 or at == thing:
		return false
	return absi(grid.height_at(at) - grid.height_at(thing)) <= INTERACT_CLIMB


## Shortest walk to a cell from which the thing can be used. Empty when it can't be reached.
static func path_to_use(grid: CombatGrid, from: Vector2i, thing: Vector2i, jump: int, blocked := {}, known := {}, diagonal := false) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	if can_use_from(grid, from, thing):
		best.append(from)
		return best
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c := thing + Vector2i(dx, dy)
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
			var n: Vector2i = c + d
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
		var ev := {"id": row.id, "text_key": row.text_key, "options": []}
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

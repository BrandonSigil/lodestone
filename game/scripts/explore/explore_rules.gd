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
		for n in range(1, 5):
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
## "flag:<id>" or "noflag:<id>" (a meta flag is or isn't set). `defs`: the party's CharacterDefs.
## have: {"items": id -> count, "flags": Array of set flags}.
static func need_met(need: String, defs: Array, have := {}) -> bool:
	if need == "":
		return true
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

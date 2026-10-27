class_name ExploreRules
extends RefCounted
## Rules for walking a map outside combat: paths, what the party can see (fog of war), who spots whom,
## which interaction options the party has, and how effects split between the map and the run.
## Pure functions on a CombatGrid, so tests run them headless.

const PARTY_SIGHT := 7  ## cells the party sees around each member (line of sight still applies)
const ENEMY_SIGHT := 4  ## default for groups; a map can set its own per group
const INTERACT_CLIMB := 2  ## a thing on a ledge more than this above or below can't be reached
const HINT_RANGE := 3  ## the interact icon lights up when the leader is this close
const NOISE_RANGE := 12  ## a noisy failure draws the nearest group within this many cells
const JOIN_RANGE := 3  ## other groups this close to a fight join it

## Effects the map handles itself. Anything else ("food:+3", "hp_one:-2") goes to TrailRules on the run.
const MAP_EFFECTS := ["open", "remove", "noise", "reveal", "exit", "fight", "sneak_attack", "ambushed", "pacify"]


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


# --- walking ----------------------------------------------------------------------

## The party walks at the pace of its worst climber, so everyone can follow the leader's steps.
static func party_jump(units: Array) -> int:
	var j := 99
	for u: CombatUnit in units:
		j = mini(j, u.jump)
	return 1 if j == 99 else j


## Cheapest path from `from` to `to`, both included. Empty when there is none.
## `blocked`: cells nobody may enter (enemies, things). `known`: cells the party has seen; empty = every cell.
static func find_path(grid: CombatGrid, from: Vector2i, to: Vector2i, jump: int, blocked := {}, known := {}) -> Array[Vector2i]:
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
		for d in CombatRules.DIRS:
			var n: Vector2i = c + d
			if not _open(grid, n, blocked, known) or not grid.can_step(c, n, jump):
				continue
			var nc: int = int(cost[c]) + grid.step_cost(n)
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


## Can someone standing at `at` use the thing at `thing`? Next to it (diagonals count) and not a cliff apart.
static func can_use_from(grid: CombatGrid, at: Vector2i, thing: Vector2i) -> bool:
	if maxi(absi(at.x - thing.x), absi(at.y - thing.y)) > 1 or at == thing:
		return false
	return absi(grid.height_at(at) - grid.height_at(thing)) <= INTERACT_CLIMB


## Shortest walk to a cell from which the thing can be used. Empty when it can't be reached.
static func path_to_use(grid: CombatGrid, from: Vector2i, thing: Vector2i, jump: int, blocked := {}, known := {}) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	if can_use_from(grid, from, thing):
		best.append(from)
		return best
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c := thing + Vector2i(dx, dy)
			if not grid.in_bounds(c) or not can_use_from(grid, c, thing):
				continue
			var p := find_path(grid, from, c, jump, blocked, known)
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


## "" (anyone), "skill:<check>" (someone has it), "class:<id>", or "char:<id>". `defs`: the party's CharacterDefs.
static func need_met(need: String, defs: Array) -> bool:
	if need == "":
		return true
	var kv := need.split(":")
	if kv.size() != 2:
		return false
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
static func options_for(ev: Dictionary, defs: Array) -> Array:
	return ev.options.filter(func(o: Dictionary) -> bool: return need_met(o.need, defs))


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

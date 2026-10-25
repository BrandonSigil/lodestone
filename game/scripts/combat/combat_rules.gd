class_name CombatRules
extends RefCounted
## Pure combat math. No nodes, so tests can call it headless.
## Numbers are [AI] proposals; see docs/decisions.md.

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const HEIGHT_HIT := 2  ## to-hit per level above the target
const HEIGHT_LEVELS_MAX := 2  ## levels of height that count
const FLANK_HIT := 2
const SPOOKED_HIT := -3
const SPOOKED_MOVE := -2
const MELEE_REACH := 2  ## melee can't hit across more height than this
const SKITTISH_DC := 11
const SKITTISH_RANGE := 3


static func dist(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func height_levels(grid: CombatGrid, from: Vector2i, to: Vector2i) -> int:
	return clampi(grid.height_at(from) - grid.height_at(to), -HEIGHT_LEVELS_MAX, HEIGHT_LEVELS_MAX)


static func move_points(u: CombatUnit) -> int:
	return maxi(1, u.cls.move + (SPOOKED_MOVE if u.spooked else 0))


static func unit_at(units: Array, c: Vector2i) -> CombatUnit:
	for o: CombatUnit in units:
		if o.alive() and o.cell == c:
			return o
	return null


## Dijkstra over move cost. Returns {"cost": {cell: int}, "prev": {cell: cell}}.
## Units pass through allies but can't stop on them, and can't pass enemies.
static func reachable(grid: CombatGrid, u: CombatUnit, units: Array) -> Dictionary:
	var cost := {u.cell: 0}
	var prev := {}
	var open: Array[Vector2i] = [u.cell]
	var budget := move_points(u)
	while not open.is_empty():
		var bi := 0
		for i in open.size():
			if cost[open[i]] < cost[open[bi]]:
				bi = i
		var c: Vector2i = open.pop_at(bi)
		for d in DIRS:
			var n: Vector2i = c + d
			if not grid.passable(n):
				continue
			if absi(grid.height_at(n) - grid.height_at(c)) > u.cls.jump:
				continue
			var other := unit_at(units, n)
			if other != null and other.team != u.team:
				continue
			var nc: int = cost[c] + grid.step_cost(n)
			if nc > budget or (cost.has(n) and nc >= cost[n]):
				continue
			cost[n] = nc
			prev[n] = c
			if not open.has(n):
				open.append(n)
	for c: Vector2i in cost.keys():
		if c != u.cell and unit_at(units, c) != null:
			cost.erase(c)
	return {"cost": cost, "prev": prev}


static func path_to(prev: Dictionary, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [to]
	var c := to
	while c != from:
		if not prev.has(c):
			return [from]
		c = prev[c]
		path.push_front(c)
	return path


static func can_attack(grid: CombatGrid, att: CombatUnit, tgt: CombatUnit, from: Vector2i) -> bool:
	if not tgt.alive() or tgt.team == att.team:
		return false
	var d := dist(from, tgt.cell)
	var dh := grid.height_at(from) - grid.height_at(tgt.cell)
	if d < att.cls.range_min:
		return false
	var reach := att.cls.range_max
	if reach > 1:
		reach += maxi(0, dh)  # high ground extends bows and spells
	elif absi(dh) > MELEE_REACH:
		return false
	return d <= reach


static func flanked(att: CombatUnit, tgt: CombatUnit, units: Array, from: Vector2i) -> bool:
	for o: CombatUnit in units:
		if o == att or not o.alive() or o.team != att.team:
			continue
		if dist(o.cell, tgt.cell) == 1 and o.cell != from:
			return true
	return false


static func hit_bonus(grid: CombatGrid, att: CombatUnit, tgt: CombatUnit, units: Array, from: Vector2i) -> int:
	var b := att.cls.attack + height_levels(grid, from, tgt.cell) * HEIGHT_HIT
	if flanked(att, tgt, units, from):
		b += FLANK_HIT
	if att.spooked:
		b += SPOOKED_HIT
	return b


static func target_number(grid: CombatGrid, att: CombatUnit, tgt: CombatUnit) -> int:
	return tgt.cls.defense + (0 if att.cls.magic else grid.cover(tgt.cell))


static func hit_chance(grid: CombatGrid, att: CombatUnit, tgt: CombatUnit, units: Array, from: Vector2i) -> float:
	return Dice.chance(hit_bonus(grid, att, tgt, units, from), target_number(grid, att, tgt))


static func damage(grid: CombatGrid, att: CombatUnit, tgt: CombatUnit, from: Vector2i) -> int:
	return maxi(1, att.cls.damage + height_levels(grid, from, tgt.cell))


## Rolls and applies one attack. Returns the Dice result plus "damage".
static func attack(rng: RandomNumberGenerator, grid: CombatGrid, att: CombatUnit, tgt: CombatUnit, units: Array) -> Dictionary:
	var r := Dice.check(rng, hit_bonus(grid, att, tgt, units, att.cell), target_number(grid, att, tgt))
	var dmg := 0
	if r.success:
		dmg = damage(grid, att, tgt, att.cell) * (2 if r.crit else 1)
		tgt.hp = maxi(0, tgt.hp - dmg)
	r["damage"] = dmg
	return r


## Stardrop's deficiency. Returns {} if no roll was needed.
static func skittish_check(rng: RandomNumberGenerator, u: CombatUnit, units: Array) -> Dictionary:
	u.spooked = false
	if u.deficiency != &"skittish":
		return {}
	var near := false
	for o: CombatUnit in units:
		if o.alive() and o.team != u.team and dist(o.cell, u.cell) <= SKITTISH_RANGE:
			near = true
	if not near:
		return {}
	var r := Dice.check(rng, int(u.skills.get("nerve", 0)), SKITTISH_DC)
	u.spooked = not r.success
	return r


static func team_alive(units: Array, team: int) -> bool:
	for o: CombatUnit in units:
		if o.team == team and o.alive():
			return true
	return false

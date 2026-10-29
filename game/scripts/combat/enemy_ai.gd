class_name EnemyAi
extends RefCounted
## Greedy AI: for every tile it can reach and every skill it has ready, score the expected result
## and take the best. Otherwise close on the nearest foe. Also drives the party in the balance sim.

const KILL_BONUS := 15.0
const HEIGHT_PULL := 1.5
const COUNTER_FEAR := 3.0  ## how much it dislikes eating a counterattack (damage taken counts less than damage dealt)
const GUARD_SCORE := 4.0  ## guard when hurt and nothing better to do


## Returns {"move": Vector2i, "ability": Ability or null, "aim": Vector2i, "path": Array[Vector2i], "guard": bool}.
## "target" is kept for the old single-strike callers: the unit at "aim" if any.
static func plan(grid: CombatGrid, u: CombatUnit, units: Array) -> Dictionary:
	var reach := CombatRules.reachable(grid, u, units)
	var cost: Dictionary = reach.cost
	var best_score := 0.0
	var best_cell := u.cell
	var best_ability: Ability = null
	var best_aim := u.cell
	var leave := {}  # cell -> what walking away from guards costs there ([USER] c13)
	for cell: Vector2i in cost:
		leave[cell] = leave_cost(grid, u, units, cell)
	for cell: Vector2i in cost:
		for a in u.abilities:
			if not CombatRules.usable(u, a):
				continue
			for aim in _aims(grid, u, a, units, cell):
				var s := score(grid, u, a, aim, units, cell)
				if s <= -INF:
					continue
				s += grid.height_at(cell) * HEIGHT_PULL - int(cost[cell]) * 0.2 - float(leave[cell])
				if s > best_score:
					best_score = s
					best_cell = cell
					best_ability = a
					best_aim = aim
	var guard := false
	if best_ability == null:
		best_cell = _approach(grid, u, units, cost, leave)
		guard = u.hp * 2 < u.max_hp
	var target := CombatRules.unit_at(units, best_aim) if best_ability else null
	return {"move": best_cell, "ability": best_ability, "aim": best_aim, "target": target,
		"path": CombatRules.path_to(reach.prev, u.cell, best_cell), "guard": guard}


## Aim points worth scoring: unit cells only (area skills centred on a unit or next to one).
static func _aims(grid: CombatGrid, u: CombatUnit, a: Ability, units: Array, from: Vector2i) -> Array[Vector2i]:
	var cells := CombatRules.target_cells(grid, u, a, units, from)
	if a.target != "cell":
		return cells
	var out: Array[Vector2i] = []
	for c in cells:
		for o: CombatUnit in units:
			if o.alive() and o.team != u.team and CombatRules.dist(o.cell, c) <= a.radius:
				out.append(c)
				break
	return out


## Expected value of using `a` aimed at `aim` from `from`. Hurting foes is good, hurting friends is bad.
static func score(grid: CombatGrid, u: CombatUnit, a: Ability, aim: Vector2i, units: Array, from: Vector2i) -> float:
	var f := CombatRules.forecast(grid, u, a, aim, units, from)
	if f.targets.is_empty():
		return -INF
	var s := 0.0
	for e in f.targets:
		var t: CombatUnit = e.unit
		var side := 1.0 if t.team != u.team else -1.5
		match a.kind:
			"attack":
				s += side * _avg(e) * e.swings * 10.0
				if e.dmg * e.swings >= t.hp:
					s += side * KILL_BONUS
				if a.status != "" and not t.has_status(a.status):
					s += side * 6.0
				if a.push > 0 and not t.has_trait(CombatRules.TRAIT_DEEP_ROOTS):
					s += side * 3.0
			"hex":
				if not t.has_status(a.status):
					s += side * _hex_value(t, a.status)
			"heal":
				s += e.heal * 6.0 if t.team == u.team else -e.heal * 6.0
			"buff":
				s += _buff_value(u, t, a.status)
	if a.kind != "attack" and s <= 0.0:
		return -INF
	if not f.counter.is_empty():
		s -= _avg(f.counter) * COUNTER_FEAR
	if a.cooldown > 0:
		s += 2.0  # spend skills when they're good, not only strikes
	return s


## What ending the move on `cell` costs in free hits from guards u walks away from, on the attack score's
## scale; a hit that could down u costs a lot more.
static func leave_cost(grid: CombatGrid, u: CombatUnit, units: Array, cell: Vector2i) -> float:
	var total := 0.0
	var worst := 0
	for g in CombatRules.left_at(grid, u, units, cell):
		total += CombatRules.expected_damage(grid, g, u, g.cell, null, units)
		worst += CombatRules.damage_range(grid, g, u, g.cell, null, units).y * int(CombatRules.num("crit_mult"))
	if total <= 0.0:
		return 0.0
	return total * COUNTER_FEAR * 2.0 + (KILL_BONUS * 2.0 if worst >= u.hp else 0.0)


## Average damage of one blow from a forecast entry: the middle of the range, crits counted.
static func _avg(e: Dictionary) -> float:
	return (int(e.dmg_min) + int(e.dmg_max)) * 0.5 * (1.0 + float(e.crit) * (CombatRules.num("crit_mult") - 1.0))


## What taking a foe out of play is worth: sleep costs it a whole turn, about one of its hits plus change.
static func _hex_value(t: CombatUnit, status: String) -> float:
	match status:
		CombatRules.STATUS_SLEEP:
			return 8.0 + t.damage * 6.0
		CombatRules.STATUS_ROOTED:
			return 6.0
	return 4.0


static func _buff_value(u: CombatUnit, t: CombatUnit, status: String) -> float:
	if t.team != u.team or t.has_status(status):
		return 0.0
	match status:
		CombatRules.STATUS_GUIDED:
			return 5.0 if t != u and not t.acted else 0.0
	return 5.0 if t.hp < t.max_hp else 0.0


## Nobody in reach: walk toward the nearest foe by the way there on foot (round cliffs, up the stairs),
## not in a straight line, which left pieces stuck at the foot of a wall with the foe on top.
## Foes nobody can walk to: the straight-line distance, as before.
static func _approach(grid: CombatGrid, u: CombatUnit, units: Array, cost: Dictionary, leave := {}) -> Vector2i:
	var walk := walk_distance(grid, u, units)
	var best := u.cell
	var best_d := INF
	for cell: Vector2i in cost:
		var d: float
		if walk.has(cell):
			d = float(walk[cell])
		else:
			d = INF
			for t: CombatUnit in units:
				if t.team != u.team and t.alive():
					d = minf(d, 1000.0 + CombatRules.dist(cell, t.cell))
		d -= grid.height_at(cell) * 0.1
		d += float(leave.get(cell, 0.0)) * 0.2
		if d < best_d:
			best_d = d
			best = cell
	return best


## Steps on foot from every cell to the nearest living foe of u (u's jump, stairs count), over the whole map.
static func walk_distance(grid: CombatGrid, u: CombatUnit, units: Array) -> Dictionary:
	var out := {}
	var queue: Array[Vector2i] = []
	for t: CombatUnit in units:
		if t.team != u.team and t.alive():
			out[t.cell] = 0
			queue.append(t.cell)
	var i := 0
	while i < queue.size():
		var c: Vector2i = queue[i]
		i += 1
		for d in CombatRules.DIRS:
			var n: Vector2i = c + d
			if out.has(n) or not grid.passable(n) or not grid.can_step(c, n, u.jump):
				continue
			var other := CombatRules.unit_at(units, n)
			if other != null and other.team != u.team:
				continue
			out[n] = int(out[c]) + 1
			queue.append(n)
	return out

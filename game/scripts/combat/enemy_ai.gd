class_name EnemyAi
extends RefCounted
## Simple greedy AI: take the best attack it can reach, else close on the nearest foe.
## Also drives the party in headless simulation tests.


## Returns {"move": Vector2i, "target": CombatUnit or null, "path": Array[Vector2i]}.
static func plan(grid: CombatGrid, u: CombatUnit, units: Array) -> Dictionary:
	var reach := CombatRules.reachable(grid, u, units)
	var cost: Dictionary = reach.cost
	var best_score := -INF
	var best_cell := u.cell
	var best_target: CombatUnit = null
	for cell: Vector2i in cost:
		for t: CombatUnit in units:
			if not CombatRules.can_attack(grid, u, t, cell):
				continue
			var p := CombatRules.hit_chance(grid, u, t, units, cell)
			var dmg := CombatRules.damage(grid, u, t, cell)
			var score: float = p * dmg * 10.0 + grid.height_at(cell) * 1.5 - int(cost[cell]) * 0.2
			if dmg >= t.hp:
				score += 15.0 * p
			if score > best_score:
				best_score = score
				best_cell = cell
				best_target = t
	if best_target == null:
		best_cell = _approach(grid, u, units, cost)
	return {"move": best_cell, "target": best_target, "path": CombatRules.path_to(reach.prev, u.cell, best_cell)}


static func _approach(grid: CombatGrid, u: CombatUnit, units: Array, cost: Dictionary) -> Vector2i:
	var best := u.cell
	var best_d := INF
	for cell: Vector2i in cost:
		for t: CombatUnit in units:
			if t.team == u.team or not t.alive():
				continue
			var d := CombatRules.dist(cell, t.cell) - grid.height_at(cell) * 0.1
			if d < best_d:
				best_d = d
				best = cell
	return best

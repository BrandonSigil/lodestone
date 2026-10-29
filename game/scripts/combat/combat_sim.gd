class_name CombatSim
extends RefCounted
## Plays whole fights with the AI on both sides, no nodes. The sandbox's balance button and the tests use it.

const MAX_ROUNDS := 40


## Runs one AI turn for unit u: move, then act or guard. Returns the plan plus the events.
static func take_turn(rng: RandomNumberGenerator, grid: CombatGrid, u: CombatUnit, units: Array) -> Dictionary:
	var plan := EnemyAi.plan(grid, u, units)
	var events := CombatRules.leave_hits(rng, grid, u, units, plan.move)
	if not u.alive():
		plan["events"] = events
		return plan
	u.place(plan.move, grid.height_at(plan.move))
	u.moved = true
	if plan.ability != null:
		events.append_array(CombatRules.resolve(rng, grid, u, plan.ability, plan.aim, units))
	elif plan.guard:
		CombatRules.guard(u)
	u.acted = true
	plan["events"] = events
	return plan


## Fights until one side falls. Mutates the units. Returns {"winner": 0, 1 or -1 for a stall, "rounds": int}.
## supplies: counts that pack belts for pieces without one (CombatUnit.pack_belts).
static func fight(rng: RandomNumberGenerator, grid: CombatGrid, units: Array, supplies: Dictionary = {}) -> Dictionary:
	CombatUnit.pack_belts(units, supplies)
	for u: CombatUnit in units:
		u.reset_resource()
	var rounds := 0
	while rounds < MAX_ROUNDS:
		rounds += 1
		for team in [0, 1]:
			CombatRules.begin_phase(units, team)
			for u: CombatUnit in units:
				if u.team == team and u.alive():
					CombatRules.skittish_check(rng, u, units)
			for u: CombatUnit in units:
				if u.team == team and u.alive() and not u.done():
					take_turn(rng, grid, u, units)
					if not CombatRules.team_alive(units, 1 - team):
						return {"winner": team, "rounds": rounds}
			CombatRules.end_phase(units, team)
	return {"winner": -1, "rounds": rounds}

class_name CombatSim
extends RefCounted
## Plays whole fights with the AI on both sides, no nodes. The sandbox's balance button and the tests use it.

const MAX_ROUNDS := 40


## Runs one AI turn for unit u: move, then act or guard. Returns the plan plus the events.
static func take_turn(rng: RandomNumberGenerator, grid: CombatGrid, u: CombatUnit, units: Array, supplies: Dictionary) -> Dictionary:
	var plan := EnemyAi.plan(grid, u, units, supplies)
	u.place(plan.move, grid.height_at(plan.move))
	u.moved = true
	var events := []
	if plan.ability != null:
		events = CombatRules.resolve(rng, grid, u, plan.ability, plan.aim, units, supplies)
	elif plan.guard:
		CombatRules.guard(u)
	u.acted = true
	plan["events"] = events
	return plan


## Fights until one side falls. Mutates the units. Returns {"winner": 0, 1 or -1 for a stall, "rounds": int}.
static func fight(rng: RandomNumberGenerator, grid: CombatGrid, units: Array, supplies: Dictionary = {}) -> Dictionary:
	var rounds := 0
	while rounds < MAX_ROUNDS:
		rounds += 1
		for team in [0, 1]:
			CombatRules.begin_phase(units, team)
			for u: CombatUnit in units:
				if u.team == team and u.alive():
					CombatRules.skittish_check(rng, u, units)
			for u: CombatUnit in units:
				if u.team == team and u.alive():
					take_turn(rng, grid, u, units, supplies)
					if not CombatRules.team_alive(units, 1 - team):
						return {"winner": team, "rounds": rounds}
			CombatRules.end_phase(units, team)
	return {"winner": -1, "rounds": rounds}

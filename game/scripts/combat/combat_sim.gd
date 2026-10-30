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
	u.move_spent += int(plan.cost)
	if plan.ability != null:
		events.append_array(CombatRules.resolve(rng, grid, u, plan.ability, plan.aim, units))
		if CombatRules.hit_and_run(u, plan.ability):  # the rogue steps back out of the foes' reach
			var away := EnemyAi.retreat(grid, u, units)
			events.append_array(CombatRules.leave_hits(rng, grid, u, units, away.move))
			if u.alive():
				u.place(away.move, grid.height_at(away.move))
			u.moved = true
	elif plan.guard:
		CombatRules.guard(u)
	u.acted = true
	plan["events"] = events
	return plan


## Every ready piece of `team` takes its turn, and round the list again while a piece helped up after its place
## came by still can (a revived piece may act, as the player's can). True when the other side is gone.
static func play_phase(rng: RandomNumberGenerator, grid: CombatGrid, units: Array, team: int) -> bool:
	var again := true
	while again:
		again = false
		for u: CombatUnit in units:
			if u.team == team and u.alive() and not u.done():
				take_turn(rng, grid, u, units)
				again = true
				if not CombatRules.team_alive(units, 1 - team):
					return true
	return false


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
			if not CombatRules.team_alive(units, team):  # poison can finish a side at the start of its phase
				return {"winner": 1 - team, "rounds": rounds}
			for u: CombatUnit in units:
				if u.team == team and u.alive():
					CombatRules.skittish_check(rng, u, units)
			if play_phase(rng, grid, units, team):
				return {"winner": team, "rounds": rounds}
			CombatRules.end_phase(units, team)
	return {"winner": -1, "rounds": rounds}

class_name CombatSim
extends RefCounted
## Plays whole fights with the AI on both sides, no nodes. The sandbox's balance button and the tests use it.

const MAX_ROUNDS := 40


## Runs one AI turn for unit u: move, then act or guard. Returns the plan plus the events.
static func take_turn(rng: RandomNumberGenerator, grid: CombatGrid, u: CombatUnit, units: Array) -> Dictionary:
	var plan := EnemyAi.plan(grid, u, units)
	var stop := CombatRules.walk_stop(grid, u, plan.path, units)  # a foe on OVERWATCH, or a trap, stops the walk
	if not stop.is_empty():
		plan.move = stop.cell
		plan.cost = int(plan.cost)
	var events := CombatRules.leave_hits(rng, grid, u, units, plan.move)
	if not u.alive():
		plan["events"] = events
		return plan
	var moved: bool = plan.move != u.cell
	u.place(plan.move, grid.height_at(plan.move))
	if moved:
		events.append_array(CombatRules.hand_chill(grid, u, units))  # ended its move by the Lich Prince's hand (NEPO BABY)
	if not stop.is_empty():
		events.append_array(CombatRules.stop_events(rng, grid, stop, u, units))
		u.moved = true
		u.move_spent = CombatRules.move_points(u)  # its move ends here; it acts from where it stopped, if it still can
		if not u.alive():
			u.acted = true
			plan["events"] = events
			return plan
		var again := EnemyAi.plan(grid, u, units)
		plan.ability = again.ability
		plan.aim = again.aim
		plan.guard = again.guard
		plan.dest = again.dest
		plan.spot = again.spot
	u.moved = true
	u.move_spent += int(plan.cost)
	CombatRules.spot(grid, units, u)
	if plan.ability != null and plan.ability.kind == "carry":
		var friend := CombatRules.occupant(units, plan.aim)
		events.append_array(CombatRules.carry(rng, grid, u, friend, plan.dest, plan.spot, units))
		u.uses[plan.ability.id] = int(u.uses.get(plan.ability.id, 0)) + 1
	elif plan.ability != null and plan.ability.kind == "command":
		events.append_array(CombatRules.command(u, plan.ability, CombatRules.unit_at(units, plan.aim)))
		u.uses[plan.ability.id] = int(u.uses.get(plan.ability.id, 0)) + 1
	elif plan.ability != null and plan.ability.kind == "swap":  # the rogue's move; then it acts from where it landed
		events.append_array(CombatRules.shadow_swap(grid, u, plan.ability, CombatRules.occupant(units, plan.aim)))
		u.uses[plan.ability.id] = int(u.uses.get(plan.ability.id, 0)) + 1
		u.move_spent = CombatRules.swap_spent(u)
		var then := EnemyAi.plan(grid, u, units)
		if then.ability != null and then.ability.kind not in ["carry", "command", "swap"]:
			events.append_array(CombatRules.resolve(rng, grid, u, then.ability, then.aim, units))
		elif then.guard:
			CombatRules.guard(u)
	elif plan.ability != null:
		if plan.ability.id in ["overwatch", "ward"]:
			u.uses[plan.ability.id] = int(u.uses.get(plan.ability.id, 0)) + 1
		events.append_array(CombatRules.resolve(rng, grid, u, plan.ability, plan.aim, units))
		while u.alive() and CombatRules.extra_shot(u):  # GOOD SHOT: another attack from where it stands
			var shot := EnemyAi.second_shot(grid, u, units)
			if shot.is_empty():
				break
			events.append_array(CombatRules.resolve(rng, grid, u, shot.ability, shot.aim, units))
		if CombatRules.hit_and_run(u, plan.ability):  # the rogue steps back out of the foes' reach
			var away := EnemyAi.retreat(grid, u, units)
			events.append_array(CombatRules.leave_hits(rng, grid, u, units, away.move))
			if u.alive():
				u.place(away.move, grid.height_at(away.move))
				CombatRules.spot(grid, units, u)
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
		for u: CombatUnit in by_turn(units, grid):
			if u.team == team and u.alive() and not u.done():
				take_turn(rng, grid, u, units)
				again = true
				if not CombatRules.team_alive(units, 1 - team):
					return true
	return false


## One whole phase of `team`: its start (statuses tick, a boss's marked move lands, his pieces come), every
## piece's turn, a boss's new mark, its end. Returns the winning team once a side is gone, else -1.
static func run_phase(rng: RandomNumberGenerator, grid: CombatGrid, units: Array, team: int) -> int:
	CombatRules.begin_phase(units, team, grid)
	CombatRules.boss_start(rng, grid, units, team)
	for side in [team, 1 - team]:  # poison or a big move can finish a side before anyone moves
		if not CombatRules.team_alive(units, side):
			return 1 - side
	for u: CombatUnit in units:
		if u.team == team and u.alive():
			CombatRules.skittish_check(rng, u, units)
	if play_phase(rng, grid, units, team):
		return team
	CombatRules.boss_end(grid, units, team)
	CombatRules.cold(units, team)  # ice pillars chill whoever ends next to them
	if not CombatRules.team_alive(units, team):
		return 1 - team
	CombatRules.end_phase(units, team)
	return -1


const COMMAND_WAIT := 20.0  ## a piece with COMMAND ready waits for its friend when its own best action scores under this


## The order a side's pieces take their turns ([USER] design-clutch-tools-2, game designer 2026-10-30): one with
## COMMAND ready whose own best action now is weak goes last, so the friend it would send again has had its turn,
## as a player would order them; with a good action in hand, or COMMAND on its wait, it goes in turn.
static func by_turn(units: Array, grid: CombatGrid = null) -> Array:
	var waits := func(u: CombatUnit) -> bool:
		if not u.abilities.any(func(a: Ability) -> bool: return a.kind == "command" and CombatRules.usable(u, a)):
			return false
		return grid == null or u.done() or float(EnemyAi.plan(grid, u, units).score) < COMMAND_WAIT
	var first := units.filter(func(u: CombatUnit) -> bool: return not waits.call(u))
	return first + units.filter(func(u: CombatUnit) -> bool: return waits.call(u))


## Fights until one side falls. Mutates the units. Returns {"winner": 0, 1 or -1 for a stall, "rounds": int}.
## supplies: counts that pack belts for pieces without one (CombatUnit.pack_belts). first: the side that moves first.
static func fight(rng: RandomNumberGenerator, grid: CombatGrid, units: Array, supplies: Dictionary = {}, first := 0) -> Dictionary:
	CombatUnit.pack_belts(units, supplies)
	for u: CombatUnit in units:
		u.reset_resource()
	var rounds := 0
	while rounds < MAX_ROUNDS:
		rounds += 1
		for team in [first, 1 - first]:
			var w := run_phase(rng, grid, units, team)
			if w >= 0:
				return {"winner": w, "rounds": rounds}
	return {"winner": -1, "rounds": rounds}

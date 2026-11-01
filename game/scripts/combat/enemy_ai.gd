class_name EnemyAi
extends RefCounted
## Greedy AI: for every tile it can reach and every skill it has ready, score the expected result
## and take the best. Otherwise close on the nearest foe. Also drives the party in the balance sim.

const KILL_BONUS := 15.0
const HEIGHT_PULL := 1.5
const COUNTER_FEAR := 3.0  ## how much it dislikes eating a counterattack (damage taken counts less than damage dealt)
const GUARD_SCORE := 4.0  ## guard when hurt and nothing better to do
const REVIVE_SCORE := 40.0  ## helping a downed teammate up beats most hits
const KNOCKOUT_SCORE := 12.0  ## a downed foe kept down for the fight: about a solid hit's worth
const COST_WEIGHT := 0.4  ## how much a point of mana, rage or charge weighs against a skill's worth
const TAUNT_RANGE := 5
const HEXES := [CombatRules.STATUS_SPOOK, CombatRules.STATUS_SLOW]  ## a hero under one hex is not hexed again
const AMBUSH_PICK := 60.0  ## an ambusher's pull toward soft targets, so armor and HP outweigh the damage it would do  ## foes this close are the ones a taunt will pull


## Returns {"move": Vector2i, "ability": Ability or null, "aim": Vector2i, "path": Array[Vector2i], "guard": bool}.
## "target" is kept for the old single-strike callers: the unit at "aim" if any.
static func plan(grid: CombatGrid, u: CombatUnit, units: Array) -> Dictionary:
	if u.has_trait(CombatRules.TRAIT_STRUCTURE):  # an ice pillar only stands there
		return {"move": u.cell, "ability": null, "aim": u.cell, "target": null, "path": [] as Array[Vector2i], "guard": false, "cost": 0}
	_reach_cache = {}
	var reach := CombatRules.reachable(grid, u, units)
	var cost: Dictionary = reach.cost
	var best_score := 0.0
	var best_cell := u.cell
	var best_ability: Ability = null
	var best_aim := u.cell
	var leave := {}  # cell -> what walking away from guards, or ending on a boss's marked tiles, costs there ([USER] c13)
	var marked := CombatRules.marks(units)
	for cell: Vector2i in cost:
		leave[cell] = leave_cost(grid, u, units, cell) + mark_cost(grid, u, units, cell, marked)
	if u.has_trait(CombatRules.TRAIT_STAND_WATCH) and u.move_spent == 0 and not _foe_reach(grid, u, units).has(u.cell):
		leave[u.cell] = float(leave[u.cell]) - watch_value(grid, u, units)  # standing still readies the watch shot, out of harm's way
	var actions: Array[Ability] = u.abilities.duplicate()
	actions.append_array(CombatRules.extra_actions(u))  # AID or a knock-out too
	var safe := _safe_cells(u, units, cost) if u.has_trait(CombatRules.TRAIT_KEEPS_BACK) else {}
	if not safe.is_empty():  # a piece that keeps back never strikes while it has somewhere to stand 2 tiles off the heroes
		actions = actions.filter(func(a: Ability) -> bool: return a.kind != "attack")
	var extra := {}  # CARRY's destination and set-down cell, when a clutch tool wins
	for c: Dictionary in _clutch(grid, u, units, cost, leave):
		if float(c.score) > best_score:
			best_score = float(c.score)
			best_cell = c.cell
			best_ability = c.ability
			best_aim = c.aim
			extra = c
	# A barking dog (TAUNT): if u can walk somewhere and hit him this phase, it must ([USER] 2026-10-29). The best
	# such strike wins over anything else, even a better hit on someone softer.
	var taunt_cells := {}
	for o: CombatUnit in units:
		if o.alive() and o.team != u.team and o.has_status(CombatRules.STATUS_TAUNT):
			taunt_cells[o.cell] = true
	var taunt_best := -INF
	var taunt_pick := {}
	for cell: Vector2i in cost:
		if not safe.is_empty() and not safe.has(cell) and taunt_cells.is_empty():
			continue
		for a in actions:
			if not CombatRules.usable(u, a) or a.boss_move() or a.kind in ["carry", "command", "swap"]:
				continue
			for aim in _aims(grid, u, a, units, cell):
				var s := score(grid, u, a, aim, units, cell)
				if s <= -INF:
					continue
				s += grid.height_at(cell) * HEIGHT_PULL - int(cost[cell]) * 0.2 - float(leave[cell])
				if a.hostile() and taunt_cells.has(aim):
					if s > taunt_best:
						taunt_best = s
						taunt_pick = {"cell": cell, "ability": a, "aim": aim}
					continue
				if not safe.is_empty() and not safe.has(cell):
					continue
				if s > best_score:
					best_score = s
					best_cell = cell
					best_ability = a
					best_aim = aim
					extra = {}
	if not taunt_pick.is_empty():
		best_score = maxf(taunt_best, 0.0)
		best_cell = taunt_pick.cell
		best_ability = taunt_pick.ability
		best_aim = taunt_pick.aim
		extra = {}
	var guard := false
	if best_ability == null and u.hiding:
		best_cell = u.cell  # an ambusher waits where it hides until something comes in reach
	elif best_ability == null:
		best_cell = _stay_back(u, units, safe, cost) if not safe.is_empty() else _approach(grid, u, units, cost, leave)
		guard = u.hp * 2 < u.max_hp
	var target := CombatRules.unit_at(units, best_aim) if best_ability else null
	return {"move": best_cell, "ability": best_ability, "aim": best_aim, "target": target,
		"path": CombatRules.path_to(reach.prev, u.cell, best_cell), "guard": guard, "cost": int(cost.get(best_cell, 0)),
		"score": best_score, "dest": extra.get("dest", best_cell), "spot": extra.get("spot", best_aim)}


const CARRY_DOWNED := 20.0  ## carrying a downed friend out of reach; below AID (REVIVE_SCORE), which gets them back up
const CARRY_BAD_CELL := 12.0
const SWAP_DOWNED := 20.0  ## SHADOW SWAP on a downed friend: under AID, which gets them up
const SWAP_HURT := 16.0  ## on a friend under a quarter HP next to a foe  ## a friend on a cold, marked or guarded cell


## The clutch tools' best uses from here ([USER] design-clutch-tools-2): CARRY when a friend is down or stands on a
## cold, marked or guarded cell, COMMAND when the friend's fresh phase would score more than u's own action.
## [{"ability", "cell", "aim", "score", "dest", "spot"}].
static func _clutch(grid: CombatGrid, u: CombatUnit, units: Array, cost: Dictionary, leave: Dictionary) -> Array:
	var out := []
	for a in u.abilities:
		if not CombatRules.usable(u, a):
			continue
		if a.kind == "command":
			var best: CombatUnit = null
			var best_s := 0.0
			for f: CombatUnit in units:
				if f == u or f.team != u.team or not f.alive() or not f.done():
					continue  # a friend still to act already has its turn
				var keep := [f.moved, f.acted, f.move_spent, f.move_origin]
				f.moved = false
				f.acted = false
				f.move_spent = 0
				f.move_origin = f.cell
				var p := plan(grid, f, units)
				f.moved = keep[0]
				f.acted = keep[1]
				f.move_spent = keep[2]
				f.move_origin = keep[3]
				if p.ability != null and float(p.score) > best_s:
					best_s = float(p.score)
					best = f
			if best != null:
				out.append({"ability": a, "cell": u.cell, "aim": best.cell, "score": best_s})
		elif a.kind == "swap" and u.move_spent == 0:  # SHADOW SWAP is the rogue's move (playtest, 2026-10-30): from where it
			var threat := _foe_reach(grid, u, units)  # stands, pull a friend who is down, or low next to a foe, to safety
			for f: CombatUnit in units:
				if f == u or f.team != u.team or not (f.downed() or (f.alive() and f.hp * 4 < f.max_hp and _next_to_foe(f, units))):
					continue
				if CombatRules.dist(u.cell, f.cell) > a.range_max:
					continue
				var s := (SWAP_DOWNED if f.downed() else SWAP_HURT) + (15.0 if threat.has(f.cell) else 0.0) \
					- (15.0 if threat.has(u.cell) else 0.0) - float(leave[u.cell])
				var then := 0.0  # it's the move: the rogue still strikes from the friend's cell, next to the foe there
				for b in u.abilities:
					if b.kind != "attack" or not CombatRules.usable(u, b) or b.boss_move():
						continue
					for o: CombatUnit in units:
						if o.team != u.team and o.alive() and CombatRules.dist(o.cell, f.cell) == 1:
							var hit := score(grid, u, b, o.cell, units, f.cell)
							if hit > then:
								then = hit
				out.append({"ability": a, "cell": u.cell, "aim": f.cell, "score": s + then})
		elif a.kind == "carry":
			var marked := CombatRules.marks(units)
			var guarded := CombatRules.guard_ring(grid, units, 1 - u.team)
			var bad := func(c: Vector2i) -> float:  # a big move about to land matters; a pillar's chill or a guard far less
				var n := 0.0
				if marked.has(c):
					n += 20.0
				if guarded.has(c):
					n += 4.0
				for o: CombatUnit in units:
					if o.team != u.team and o.alive() and o.has_trait(CombatRules.TRAIT_STRUCTURE) and CombatRules.dist(o.cell, c) == 1:
						n += 2.0
				return n
			# A standing friend is only worth carrying off a marked tile, and only once it has had its turn (before that
			# it can walk off itself); one in melee chose to be there.
			var needy := units.filter(func(f: CombatUnit) -> bool:
				return f != u and f.team == u.team and (f.downed() or (f.alive() and f.done() and marked.has(f.cell))))
			if needy.is_empty():
				continue
			var threat := hit_reach(grid, u, units)
			var danger := func(c: Vector2i) -> float: return bad.call(c) + (15.0 if threat.has(c) else 0.0)
			var home := u.cell
			for cell: Vector2i in cost:
				for f: CombatUnit in needy:
					if CombatRules.dist(cell, f.cell) != 1:
						continue
					u.cell = cell  # as if the carrier had walked here first
					var spots := CombatRules.carry_spots(grid, u, f, a, units, threat)
					u.cell = home
					for dest: Vector2i in spots:
						var s: float = (CARRY_DOWNED if f.downed() else CARRY_BAD_CELL) + danger.call(f.cell) - danger.call(spots[dest]) \
							- int(cost[cell]) * 0.2 - mark_cost(grid, u, units, dest, marked)  # the carrier ends at dest
						if danger.call(spots[dest]) >= danger.call(f.cell) and not f.downed():
							continue
						out.append({"ability": a, "cell": cell, "aim": f.cell, "score": s, "dest": dest, "spot": spots[dest]})
	return out


## Hit and run, after the strike: the nearest cell u can still reach outside the foes' reach, without walking off
## a guard; where it stands if that's safe or nothing is. combat.csv `run_melee_only` 1 (the default, game
## designer 2026-10-30): the reach of foes whose plain hit reaches 1; 0: everything they could hit next phase,
## spells too (the danger zone), so it stays by the foe and its teammate keeps the team-up. Same shape as plan's move part:
## {"move", "path", "cost"}.
static func retreat(grid: CombatGrid, u: CombatUnit, units: Array) -> Dictionary:
	var reach := CombatRules.reachable(grid, u, units)
	var cost: Dictionary = reach.cost
	var zone := hit_reach(grid, u, units, true) if CombatRules.num("run_melee_only") > 0.0 \
		else CombatRules.danger_zone(grid, units, 1 - u.team)
	var marks := CombatRules.marks(units)
	var best := u.cell
	if zone.has(u.cell):
		for cell: Vector2i in cost:
			if zone.has(cell) or leave_cost(grid, u, units, cell) > 0.0 or marks.has(cell):
				continue
			if best == u.cell or int(cost[cell]) < int(cost[best]):
				best = cell
	return {"move": best, "path": CombatRules.path_to(reach.prev, u.cell, best), "cost": int(cost.get(best, 0))}


## Every cell a foe of u could strike with its plain hit next phase; melee_only: only foes whose hit reaches 1.
static func hit_reach(grid: CombatGrid, u: CombatUnit, units: Array, melee_only := false) -> Dictionary:
	var zone := {}
	for o: CombatUnit in units:
		if o.team == u.team or not o.alive() or o.has_status(CombatRules.STATUS_SLEEP) or o.hiding:
			continue
		var r := CombatRules.ability_range(o, null)
		if melee_only and r.y > 1:
			continue
		for f: Vector2i in CombatRules.reachable(grid, o, units).cost:
			var g := CombatGrid.ground(f)
			for dy in range(-r.y, r.y + 1):
				for dx in range(-r.y, r.y + 1):
					var at := g + Vector2i(dx, dy)
					if absi(dx) + absi(dy) > r.y or not grid.in_bounds(at):
						continue
					for n in grid.places_at(at):
						if not zone.has(n) and CombatRules.in_reach(grid, f, n, r):
							zone[n] = true
	return zone


## Aim points worth scoring: unit cells only (area skills centred on a unit or next to one).
static func _aims(grid: CombatGrid, u: CombatUnit, a: Ability, units: Array, from: Vector2i) -> Array[Vector2i]:
	var cells := CombatRules.target_cells(grid, u, a, units, from)
	if a.target != "cell":
		return cells
	var out: Array[Vector2i] = []
	for c in cells:
		for o: CombatUnit in units:
			if o.alive() and o.team != u.team and not o.hiding and CombatRules.dist(o.cell, c) <= a.radius:
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
				var worth := threat_worth(t, units) if t.team != u.team and CombatRules.num("threat_ai") > 0.0 else 1.0
				s += side * (_avg(e) * e.swings + int(e.help)) * 10.0 * (0.1 if worth < 0.2 else 1.0)
				if e.dmg * e.swings + int(e.help) >= t.hp:
					s += side * KILL_BONUS * worth
				if a.status != "" and not t.has_status(a.status):
					s += side * 6.0
				if a.push > 0 and not t.has_trait(CombatRules.TRAIT_DEEP_ROOTS):
					s += side * 3.0
				if u.has_trait(CombatRules.TRAIT_AMBUSH) and t.team != u.team:
					s += AMBUSH_PICK - t.armor * 10.0 - t.hp * 0.5  # the softest piece: lowest armor, then HP
			"hex":
				if not t.has_status(a.status) and not (a.status in HEXES and HEXES.any(func(h: String) -> bool: return t.has_status(h))):
					s += side * _hex_value(t, a.status)
			"heal":
				s += e.heal * 6.0 if t.team == u.team else -e.heal * 6.0
			"revive":
				s += REVIVE_SCORE if t.team == u.team else 0.0
			"knockout":
				s += KNOCKOUT_SCORE if t.team != u.team else 0.0
			"buff":
				s += _buff_value(u, t, a.status, units, grid)
	if a.kind != "attack" and s <= 0.0:
		return -INF
	if not f.counter.is_empty():
		s -= _avg(f.counter) * COUNTER_FEAR
	if a.res_cost > 0:
		s += 2.0 - a.res_cost * COST_WEIGHT  # spend the job's resource when a skill is good, not only strikes
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


## What ending the move on `cell` costs when a big move is marked on it: the blow it would take, as ending in
## reach of a guard costs, so the sim's pieces read the warning as a player would (game designer 2026-10-30).
static func mark_cost(grid: CombatGrid, u: CombatUnit, units: Array, cell: Vector2i, marked: Dictionary) -> float:
	var total := 0.0
	var worst := 0
	for m: Dictionary in marked.get(cell, []):
		var src: CombatUnit = m.src
		if src == u:
			continue
		total += CombatRules.expected_damage(grid, src, u, src.cell, m.ability, units)
		worst += CombatRules.damage_range(grid, src, u, src.cell, m.ability, units).y * int(CombatRules.num("crit_mult"))
	if total <= 0.0:
		return 0.0
	return total * COUNTER_FEAR * 2.0 + (KILL_BONUS * 2.0 if worst >= u.hp else 0.0)


## Where boss `u` marks its big move `a`: the cell in reach whose tiles catch the most standing foes right now
## (its own called pieces count against it). NONE_CELL when it would catch nobody.
static func mark_aim(grid: CombatGrid, u: CombatUnit, a: Ability, units: Array) -> Vector2i:
	var best := CombatGrid.NONE_CELL
	var best_s := 0.0
	for c in CombatRules.reach_cells(grid, u, a, u.cell):
		var s := 0.0
		for t in CombatRules.area(grid, a, c):
			var o := CombatRules.unit_at(units, t)
			if o == null or o == u or not o.alive():
				continue
			s += 10.0 if o.team != u.team else -4.0
		if s > best_s:
			best_s = s
			best = c
	return best if best_s >= 10.0 else CombatGrid.NONE_CELL


## What downing t is worth, 0.1 to 1 (game designer 2026-10-30, the threat-weighted AI): a piece by the damage it
## deals (a full 6 or more counts whole), an ice pillar by the cold it would deal next phase. Without this the AI
## spent its swings on harmless bodies for the kill bonus while the boss kept casting.
static func threat_worth(t: CombatUnit, units: Array) -> float:
	if t.has_trait(CombatRules.TRAIT_STRUCTURE):
		var next := 0
		for o: CombatUnit in units:
			if o.team != t.team and o.alive() and CombatRules.dist(o.cell, t.cell) == 1:
				next += 1
		var cold := mini(next, int(CombatRules.num("pillar_cold_max"))) * CombatRules.num("pillar_cold")
		return clampf(cold / 6.0, 0.1, 1.0)
	var support := 0.0  # a healer, warder or hexer is worth more than its own hits: it undoes or weakens everyone else's
	for a: Ability in t.abilities:
		if a.kind == "heal" and a.target == "ally" and t.team == 1:
			support = maxf(support, 1.0)
		elif a.status == CombatRules.STATUS_FOE_WARD:
			support = maxf(support, 0.8)
		elif a.kind == "hex" and t.team == 1:
			support = maxf(support, 0.7)
	return maxf(support, clampf(t.damage / 6.0, 0.3, 1.0))


## What a readied watch shot is worth to u (OVERWATCH): only when a foe out of the bow's reach could walk in on a
## downed or hurt friend next phase (one already in reach is better shot now); then about a real shot on it.
static func watch_value(grid: CombatGrid, u: CombatUnit, units: Array) -> float:
	var hurt := units.filter(func(f: CombatUnit) -> bool:
		return f.team == u.team and f != u and (f.downed() or (f.alive() and f.hp * 2 < f.max_hp)))
	if hurt.is_empty():
		return 0.0
	var r := CombatRules.ability_range(u, null)
	var best := 0.0
	for o: CombatUnit in units:
		if o.team == u.team or not o.alive() or o.hiding or o.has_trait(CombatRules.TRAIT_STRUCTURE) or CombatRules.in_reach(grid, u.cell, o.cell, r):
			continue
		var o_reach: Dictionary = CombatRules.reachable(grid, o, units).cost
		for f: CombatUnit in hurt:
			if o_reach.keys().any(func(c: Vector2i) -> bool: return CombatRules.dist(c, f.cell) <= CombatRules.ability_range(o, null).y):
				best = maxf(best, CombatRules.expected_damage(grid, u, o, u.cell, null, units) * 10.0 + 6.0)  # a real shot's worth
	return best


static var _reach_cache := {}  ## team -> the other side's hit reach, for one plan (WARD and OVERWATCH ask often)


static func _foe_reach(grid: CombatGrid, t: CombatUnit, units: Array) -> Dictionary:
	if not _reach_cache.has(t.team):
		_reach_cache[t.team] = hit_reach(grid, t, units)
	return _reach_cache[t.team]


static func _next_to_foe(f: CombatUnit, units: Array) -> bool:
	return units.any(func(o: CombatUnit) -> bool: return o.team != f.team and o.alive() and CombatRules.dist(o.cell, f.cell) == 1)


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
		CombatRules.STATUS_SPOOK:  # the hero who hits hardest first, so the hexes spread
			return 6.0 + t.damage * 3.0
		CombatRules.STATUS_SLOW:
			return 4.0 + t.damage * 2.0
	return 4.0


static func _buff_value(u: CombatUnit, t: CombatUnit, status: String, units: Array = [], grid: CombatGrid = null) -> float:
	if t.team != u.team or t.has_status(status):
		return 0.0
	match status:
		CombatRules.STATUS_WARD:  # on the friend likeliest to go down: in the foes' reach, and low
			if grid == null or not _foe_reach(grid, t, units).has(t.cell):
				return 0.0
			return 6.0 + 30.0 * (1.0 - float(t.hp) / t.max_hp)
		CombatRules.STATUS_OVERWATCH:
			return watch_value(grid, u, units) if grid != null else 0.0
		CombatRules.STATUS_FOE_WARD:  # the foe closest to a hero, once one is near enough to matter
			var nearest := 99
			for o: CombatUnit in units:
				if o.team != u.team and o.alive() and not o.hiding:
					nearest = mini(nearest, CombatRules.dist(o.cell, t.cell))
			return 5.0 + float(8 - nearest) if nearest < 8 else 0.0
		CombatRules.STATUS_GUIDED:
			return 5.0 if t != u and not t.acted else 0.0
		CombatRules.STATUS_TAUNT:
			# pull the foes onto a piece that can take it, while they're close enough to matter
			if u.hp * 2 < u.max_hp:
				return 0.0
			var near := 0
			for o: CombatUnit in units:
				if o.alive() and o.team != u.team and CombatRules.dist(o.cell, t.cell) <= TAUNT_RANGE:
					near += 1
			return 4.0 * near
	return 5.0 if t.hp < t.max_hp else 0.0


## Cells u could end on that are 2 or more tiles from every hero (a keeps_back piece's room). Empty when cornered.
static func _safe_cells(u: CombatUnit, units: Array, cost: Dictionary) -> Dictionary:
	var out := {}
	if not units.any(func(o: CombatUnit) -> bool:  # with no fighting friend left it has nothing to hide behind: no stalls
			return o != u and o.team == u.team and o.alive() and not o.has_trait(CombatRules.TRAIT_KEEPS_BACK) and not o.has_trait(CombatRules.TRAIT_STRUCTURE)):
		return out
	for c: Vector2i in cost:
		var near := 99
		for o: CombatUnit in units:
			if o.team != u.team and o.alive() and not o.hiding and not o.has_trait(CombatRules.TRAIT_STRUCTURE):
				near = mini(near, CombatRules.dist(o.cell, c))
		if near >= 2:
			out[c] = true
	return out


## Nothing to do from where it keeps back: stay with the line, the safe cell nearest a friend (the farthest from the
## heroes on a tie).
static func _stay_back(u: CombatUnit, units: Array, safe: Dictionary, cost: Dictionary) -> Vector2i:
	var best := u.cell
	var best_s := INF
	for c: Vector2i in safe:
		var friend := 99
		var hero := 99
		for o: CombatUnit in units:
			if o == u or not o.alive() or o.hiding:
				continue
			if o.team == u.team:
				friend = mini(friend, CombatRules.dist(o.cell, c))
			else:
				hero = mini(hero, CombatRules.dist(o.cell, c))
		var s := friend * 10.0 - hero + int(cost[c]) * 0.1
		if s < best_s:
			best_s = s
			best = c
	return best


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
				if t.team != u.team and t.alive() and not t.hiding:
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
		if t.team != u.team and t.alive() and not t.hiding:
			out[t.cell] = 0
			queue.append(t.cell)
	var i := 0
	while i < queue.size():
		var c: Vector2i = queue[i]
		i += 1
		for d in CombatRules.DIRS:
			for n in grid.places_next(c, d):
				if out.has(n) or not grid.passable(n) or not grid.can_step(c, n, u.jump):
					continue
				var other := CombatRules.unit_at(units, n)
				if other != null and other.team != u.team:
					continue
				out[n] = int(out[c]) + 1
				queue.append(n)
	return out

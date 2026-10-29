class_name CombatRules
extends RefCounted
## Pure combat math. No nodes, so tests and the balance sim can call it headless.
## Numbers are [AI] proposals; see docs/decisions.md.

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const HEIGHT_HIT := 2  ## to-hit per level above the target
const HEIGHT_LEVELS_MAX := 2  ## levels of height that count
const HEIGHT_DAMAGE_MAX := 1  ## height adds or takes at most this much damage (to-hit still counts both levels)
const FLANK_HIT := 2
const SPOOKED_HIT := -3
const SPOOKED_MOVE := -2
const MELEE_REACH := 2  ## melee can't hit across more height than this
const HIGH_RANGE_MAX := 3  ## bows and spells gain +1 range per level up, to this many
const SKITTISH_DC := 11
const SKITTISH_RANGE := 3
const GUARD_DEF := 3  ## Guard: +3 defense until the unit's next phase
const VEIL_DEF := 2
const MERCY_MAX := 3  ## party gets +1 to hit per miss in a row, up to this
const BUMP_DAMAGE := 2  ## pushed into a wall, rock, cliff face or another unit
const FALL_DAMAGE := 2  ## per level dropped beyond the first when pushed off a ledge

const STATUS_GUARD := "guard"
const STATUS_VEIL := "veil"
const STATUS_ROOTED := "rooted"
const STATUS_SLEEP := "sleep"  ## skips the owner's next phase, can't hit back; any damage wakes it
const STATUS_GUIDED := "guided"  ## +2 to hit until the owner's next phase
## Cleared when the owner's next phase starts (they protect through the enemy phase).
const STATUS_UNTIL_OWN_PHASE := [STATUS_GUARD, STATUS_VEIL, STATUS_GUIDED]
const GUIDED_HIT := 2

## Combat traits (one per roster character, a few for enemy classes). Ids live in the .tres traits arrays.
const TRAIT_SHIELD_WALL := &"shield_wall"  ## Lead: allies standing next to them get +2 defense
const TRAIT_STARLIT := &"starlit"  ## Stardrop: spells get +1 hit and +1 damage when cast from height 2 or more
const TRAIT_STEADY_AIM := &"steady_aim"  ## Hunter: +2 to hit when attacking without having moved this turn
const TRAIT_SCHOLAR := &"scholar"  ## Wizard: spells deal +1 damage and heal +1
const TRAIT_DEEP_ROOTS := &"deep_roots"  ## Bushberry: can't be pushed, regrows 1 HP at the start of its phase
const TRAIT_BONES := &"bones"  ## Skeleton: takes 2 less damage from arrows and other non-magic ranged hits
const TRAIT_DOUBLE_STRIKE := &"double_strike"  ## Lewith & Flark: the basic hit swings twice at -1 damage each
const TRAIT_PACK := &"pack"  ## Wolf: +1 damage on a flanked target
const PERK_FLAMMABLE := &"flammable"  ## takes +2 damage from fire
const SHIELD_WALL_DEF := 2
const STARLIT_HEIGHT := 2
const STEADY_AIM_HIT := 2
const BONES_DR := 2
const FLAMMABLE_DMG := 2
const REGROW := 1

## Rule switches the sandbox can flip to compare. Real fights use the defaults.
static var counters := true  ## melee units hit back once when attacked in reach
static var mercy := true  ## anti-streak help for the party (XCOM-style, but visible in the forecast)


static func reset_switches() -> void:
	counters = true
	mercy = true


static func dist(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func height_levels(grid: CombatGrid, from: Vector2i, to: Vector2i) -> int:
	return clampi(grid.height_at(from) - grid.height_at(to), -HEIGHT_LEVELS_MAX, HEIGHT_LEVELS_MAX)


static func move_points(u: CombatUnit) -> int:
	if u.has_status(STATUS_ROOTED) or u.has_status(STATUS_SLEEP):
		return 0
	return maxi(1, u.move + (SPOOKED_MOVE if u.spooked else 0))


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
			if not grid.can_step(c, n, u.jump):
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


# --- reach ----------------------------------------------------------------------

## Vector2i(min, max) for this unit using this ability. Strike and weapon-range skills use the unit's own range.
static func ability_range(u: CombatUnit, a: Ability) -> Vector2i:
	if a == null or a.uses_weapon_range():
		return Vector2i(u.range_min, u.range_max)
	return Vector2i(a.range_min, a.range_max)


## Range 1 is melee: it can't cross more than MELEE_REACH levels, except over a step a piece could walk (a stair
## spanning 3 levels): a foe on the stair would otherwise block the only way down and be safe from the top.
## Longer reach gains +1 per level of high ground
## (up to HIGH_RANGE_MAX) and needs a clear line of sight: walls, cliffs, boulders and trees in between block it.
static func in_reach(grid: CombatGrid, from: Vector2i, to: Vector2i, r: Vector2i) -> bool:
	var d := dist(from, to)
	if d < r.x:
		return false
	var dh := grid.height_at(from) - grid.height_at(to)
	var reach := r.y
	if reach > 1:
		reach += clampi(dh, 0, HIGH_RANGE_MAX)
	elif absi(dh) > MELEE_REACH and not (d <= 1 and grid.can_step(from, to, 1)):
		return false
	if d > reach:
		return false
	return reach <= 1 or d <= 1 or grid.line_of_sight(from, to)


static func can_attack(grid: CombatGrid, att: CombatUnit, tgt: CombatUnit, from: Vector2i) -> bool:
	if not tgt.alive() or tgt.team == att.team:
		return false
	return in_reach(grid, from, tgt.cell, ability_range(att, null))


## Can this unit use this ability right now (cooldown)? An item also has to be on the unit's own belt
## ([USER] 2026-10-29: in a fight a piece uses only what is on its belt, and using it is its action).
static func usable(u: CombatUnit, a: Ability) -> bool:
	if not u.can_use(a):
		return false
	if a.is_item():
		return u.belt != null and u.belt.count(a.spends) >= a.cost
	return true


## Cells the ability can be aimed at from `from`.
static func target_cells(grid: CombatGrid, u: CombatUnit, a: Ability, units: Array, from: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r := ability_range(u, a)
	match a.target:
		"self":
			out.append(from)
		"enemy", "ally":
			for o: CombatUnit in units:
				if not o.alive():
					continue
				if (a.target == "enemy") != (o.team != u.team):
					continue
				var oc := from if o == u else o.cell
				if in_reach(grid, from, oc, r):
					out.append(oc)
		"cell":
			for y in grid.h:
				for x in grid.w:
					var c := Vector2i(x, y)
					if in_reach(grid, from, c, r):
						out.append(c)
	return out


## Cells hit when aiming at `center` (a plus shape for radius 1).
static func area(grid: CombatGrid, a: Ability, center: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(center.y - a.radius, center.y + a.radius + 1):
		for x in range(center.x - a.radius, center.x + a.radius + 1):
			var c := Vector2i(x, y)
			if grid.in_bounds(c) and dist(c, center) <= a.radius:
				out.append(c)
	return out


## Units an ability affects when aimed at `center`. `user` stands in for whoever is at `from` while previewing a move.
static func affected_units(grid: CombatGrid, user: CombatUnit, a: Ability, center: Vector2i, units: Array, from: Vector2i) -> Array[CombatUnit]:
	var out: Array[CombatUnit] = []
	for c in area(grid, a, center):
		var o: CombatUnit = user if c == from else unit_at(units, c)
		if o == null or (o == user and c != from):
			continue
		if a.target == "enemy" and o.team == user.team:
			continue
		if a.target == "ally" and o.team != user.team:
			continue
		out.append(o)
	return out


# --- to-hit and damage ------------------------------------------------------------

static func flanked(att: CombatUnit, tgt: CombatUnit, units: Array, from: Vector2i) -> bool:
	for o: CombatUnit in units:
		if o == att or not o.alive() or o.team != att.team:
			continue
		if dist(o.cell, tgt.cell) == 1 and o.cell != from:
			return true
	return false


## Every modifier on one attack, as [label key, value] pairs. The forecast prints these.
static func hit_parts(grid: CombatGrid, att: CombatUnit, tgt: CombatUnit, units: Array, from: Vector2i, a: Ability = null) -> Array:
	var parts := [["MOD_ATTACK", att.attack]]
	if a and a.hit != 0:
		parts.append(["MOD_SKILL", a.hit])
	var hl := height_levels(grid, from, tgt.cell) * HEIGHT_HIT
	if hl != 0:
		parts.append(["MOD_HEIGHT", hl])
	if flanked(att, tgt, units, from):
		parts.append(["MOD_FLANK", FLANK_HIT])
	if att.spooked:
		parts.append(["MOD_SPOOKED", SPOOKED_HIT])
	if att.has_status(STATUS_GUIDED):
		parts.append(["MOD_GUIDED", GUIDED_HIT])
	if att.has_trait(TRAIT_STEADY_AIM) and not att.moved and from == att.cell:
		parts.append(["MOD_STEADY", STEADY_AIM_HIT])
	if _starlit(grid, att, from, a):
		parts.append(["MOD_STARLIT", 1])
	if mercy and att.team == 0 and att.miss_streak > 0:
		parts.append(["MOD_MERCY", mini(att.miss_streak, MERCY_MAX)])
	return parts


static func defense_parts(grid: CombatGrid, att: CombatUnit, tgt: CombatUnit, a: Ability = null, units: Array = []) -> Array:
	var parts := [["MOD_DEFENSE", tgt.defense]]
	var magic := att.magic or (a != null and a.magic)
	var cover := grid.cover(tgt.cell)
	if not magic and cover != 0:
		parts.append(["MOD_COVER", cover])
	if tgt.has_status(STATUS_GUARD):
		parts.append(["MOD_GUARD", GUARD_DEF])
	if tgt.has_status(STATUS_VEIL):
		parts.append(["MOD_VEIL", VEIL_DEF])
	if shielded(tgt, units):
		parts.append(["MOD_SHIELD", SHIELD_WALL_DEF])
	return parts


## Is someone with shield_wall standing next to this unit (and on its side)?
static func shielded(tgt: CombatUnit, units: Array) -> bool:
	for o: CombatUnit in units:
		if o != tgt and o.alive() and o.team == tgt.team and o.has_trait(TRAIT_SHIELD_WALL) and dist(o.cell, tgt.cell) == 1:
			return true
	return false


static func _starlit(grid: CombatGrid, u: CombatUnit, from: Vector2i, a: Ability) -> bool:
	return a != null and a.is_spell() and u.has_trait(TRAIT_STARLIT) and grid.height_at(from) >= STARLIT_HEIGHT


## How many times this ability rolls against each target (Lewith & Flark's basic hit swings twice).
static func swings(u: CombatUnit, a: Ability) -> int:
	return 2 if a != null and a.id == "strike" and u.has_trait(TRAIT_DOUBLE_STRIKE) else 1


## What a heal restores, before capping at max HP.
static func heal_amount(u: CombatUnit, a: Ability) -> int:
	return a.power + (1 if a.is_spell() and u.has_trait(TRAIT_SCHOLAR) else 0)


static func _sum(parts: Array) -> int:
	var s := 0
	for p in parts:
		s += int(p[1])
	return s


static func hit_bonus(grid: CombatGrid, att: CombatUnit, tgt: CombatUnit, units: Array, from: Vector2i, a: Ability = null) -> int:
	return _sum(hit_parts(grid, att, tgt, units, from, a))


static func target_number(grid: CombatGrid, att: CombatUnit, tgt: CombatUnit, a: Ability = null, units: Array = []) -> int:
	return _sum(defense_parts(grid, att, tgt, a, units))


static func hit_chance(grid: CombatGrid, att: CombatUnit, tgt: CombatUnit, units: Array, from: Vector2i, a: Ability = null) -> float:
	return Dice.chance(hit_bonus(grid, att, tgt, units, from, a), target_number(grid, att, tgt, a, units))


## Damage of one swing. `units` is only needed for the wolf's pack trait.
static func damage(grid: CombatGrid, att: CombatUnit, tgt: CombatUnit, from: Vector2i, a: Ability = null, units: Array = []) -> int:
	var dmg := att.damage + (a.power if a else 0) + clampi(height_levels(grid, from, tgt.cell), -HEIGHT_DAMAGE_MAX, HEIGHT_DAMAGE_MAX)
	var spell := a != null and a.is_spell()
	if spell and att.has_trait(TRAIT_SCHOLAR):
		dmg += 1
	if _starlit(grid, att, from, a):
		dmg += 1
	if swings(att, a) > 1:
		dmg -= 1
	if att.has_trait(TRAIT_PACK) and flanked(att, tgt, units, from):
		dmg += 1
	if a != null and a.element == "fire" and tgt.has_trait(PERK_FLAMMABLE):
		dmg += FLAMMABLE_DMG
	var magic := att.magic or (a != null and a.magic)
	if magic or spell:
		dmg += att.magic_power
	if tgt.has_trait(TRAIT_BONES) and not magic and dist(from, tgt.cell) > 1:
		dmg -= BONES_DR
	return maxi(1, dmg)


## Would `tgt` strike back at `att` standing on `from`?
static func counters_from(grid: CombatGrid, att: CombatUnit, tgt: CombatUnit, from: Vector2i) -> bool:
	if not counters or not tgt.alive() or tgt.team == att.team or tgt.has_status(STATUS_SLEEP):
		return false
	return in_reach(grid, tgt.cell, from, ability_range(tgt, null))


## What the player sees before committing. One entry per affected unit, plus the counter if any.
## {"targets": [{"unit", "hit", "dmg", "swings", "heal", "hit_parts", "def_parts"}], "counter": {"hit", "dmg"} or {}}
## dmg is per swing; swings is 2 for a double strike.
static func forecast(grid: CombatGrid, u: CombatUnit, a: Ability, center: Vector2i, units: Array, from: Vector2i) -> Dictionary:
	var out := {"targets": [], "counter": {}}
	var hit_list := affected_units(grid, u, a, center, units, from)
	for t in hit_list:
		var e := {"unit": t, "hit": 1.0, "dmg": 0, "swings": 1, "heal": 0, "hit_parts": [], "def_parts": []}
		match a.kind:
			"attack", "hex":
				e.hit = hit_chance(grid, u, t, units, from, a)
				e.dmg = damage(grid, u, t, from, a, units) if a.kind == "attack" else 0
				e.swings = swings(u, a)
				e.hit_parts = hit_parts(grid, u, t, units, from, a)
				e.def_parts = defense_parts(grid, u, t, a, units)
			"heal":
				e.heal = mini(heal_amount(u, a), t.max_hp - t.hp)
		out.targets.append(e)
	if a.kind == "attack" and a.radius == 0 and hit_list.size() == 1:
		var t: CombatUnit = hit_list[0]
		if counters_from(grid, u, t, from):
			out.counter = {"unit": t, "hit": hit_chance(grid, t, u, units, t.cell), "dmg": damage(grid, t, u, t.cell, null, units),
				"swings": swings(t, t.abilities[0])}
	return out


# --- resolving actions ------------------------------------------------------------

## Uses an ability (or item) and applies everything. Returns the events in order so the board can animate them:
## {"type": "hit"|"miss"|"heal"|"status"|"push"|"bump"|"fall"|"counter", "src", "unit", "amount", "roll", "path"}
## Item costs are paid from the user's belt here.
static func resolve(rng: RandomNumberGenerator, grid: CombatGrid, u: CombatUnit, a: Ability, center: Vector2i, units: Array, allow_counter := true) -> Array:
	var events := []
	if a.cooldown > 0:
		u.cooldowns[a.id] = a.cooldown
	if a.is_item():
		u.belt.take(a.spends, a.cost)
	var hit_list := affected_units(grid, u, a, center, units, u.cell)
	for t in hit_list:
		match a.kind:
			"attack", "hex":
				for i in swings(u, a):
					if not t.alive():
						break
					events.append_array(_swing(rng, grid, u, a, t, units))
			"heal":
				var before := t.hp
				t.hp = mini(t.max_hp, t.hp + heal_amount(u, a))
				events.append({"type": "heal", "src": u, "unit": t, "amount": t.hp - before})
			"buff":
				if a.status != "":
					t.statuses[a.status] = a.status_turns
					events.append({"type": "status", "src": u, "unit": t, "status": a.status})
	if allow_counter and a.kind == "attack" and a.radius == 0 and hit_list.size() == 1:
		var t: CombatUnit = hit_list[0]
		if u.alive() and counters_from(grid, u, t, u.cell):
			events.append({"type": "counter", "src": t, "unit": u})
			events.append_array(resolve(rng, grid, t, t.abilities[0], u.cell, units, false))
	return events


## One roll of an attack or hex against one target.
static func _swing(rng: RandomNumberGenerator, grid: CombatGrid, u: CombatUnit, a: Ability, t: CombatUnit, units: Array) -> Array:
	var events := []
	var r := Dice.check(rng, hit_bonus(grid, u, t, units, u.cell, a), target_number(grid, u, t, a, units))
	if not r.success:
		u.miss_streak += 1
		events.append({"type": "miss", "src": u, "unit": t, "amount": 0, "roll": r})
		return events
	u.miss_streak = 0
	if a.kind == "attack":
		var dmg := damage(grid, u, t, u.cell, a, units) * (2 if r.crit else 1)
		t.hp = maxi(0, t.hp - dmg)
		t.statuses.erase(STATUS_SLEEP)
		events.append({"type": "hit", "src": u, "unit": t, "amount": dmg, "roll": r})
	if t.alive() and a.status != "":
		t.statuses[a.status] = a.status_turns
		events.append({"type": "status", "src": u, "unit": t, "status": a.status, "roll": r})
	if t.alive() and a.push > 0:
		events.append_array(push(grid, units, u.cell, t, a.push))
	return events


## Shoves `t` away from `from` up to n tiles. Blocked: bump damage. Dropping 2+ levels: fall damage.
static func push(grid: CombatGrid, units: Array, from: Vector2i, t: CombatUnit, n: int) -> Array:
	var events := []
	if t.has_trait(TRAIT_DEEP_ROOTS):
		return events
	var delta := t.cell - from
	var dir := Vector2i(signi(delta.x), 0) if absi(delta.x) >= absi(delta.y) else Vector2i(0, signi(delta.y))
	if dir == Vector2i.ZERO:
		return events
	var path: Array[Vector2i] = [t.cell]
	for i in n:
		var dest := t.cell + dir
		var blocked := not grid.passable(dest) or unit_at(units, dest) != null
		if not blocked and grid.height_at(dest) - grid.height_at(t.cell) > 1:
			blocked = true
		if blocked:
			t.hp = maxi(0, t.hp - BUMP_DAMAGE)
			t.statuses.erase(STATUS_SLEEP)
			events.append({"type": "bump", "unit": t, "amount": BUMP_DAMAGE, "at": dest})
			break
		var drop := grid.height_at(t.cell) - grid.height_at(dest)
		t.place(dest, grid.height_at(dest))
		path.append(dest)
		if drop >= 2:
			var dmg := (drop - 1) * FALL_DAMAGE
			t.hp = maxi(0, t.hp - dmg)
			t.statuses.erase(STATUS_SLEEP)
			events.append({"type": "fall", "unit": t, "amount": dmg})
	if path.size() > 1:
		events.push_front({"type": "push", "unit": t, "path": path})
	return events


## Back-compat single strike (used by older tests and the simple sim).
static func attack(rng: RandomNumberGenerator, grid: CombatGrid, att: CombatUnit, tgt: CombatUnit, units: Array) -> Dictionary:
	var r := Dice.check(rng, hit_bonus(grid, att, tgt, units, att.cell), target_number(grid, att, tgt, null, units))
	var dmg := 0
	if r.success:
		dmg = damage(grid, att, tgt, att.cell, null, units) * (2 if r.crit else 1)
		tgt.hp = maxi(0, tgt.hp - dmg)
	r["damage"] = dmg
	return r


static func guard(u: CombatUnit) -> void:
	u.statuses[STATUS_GUARD] = 1


## Start of a team's phase: fresh actions, cooldowns tick, guard and veil end, sleepers lose the turn.
## Returns heal events for traits that regrow, so the board can show them.
static func begin_phase(units: Array, team: int) -> Array:
	var events := []
	for u: CombatUnit in units:
		if u.team != team:
			continue
		u.moved = false
		u.acted = false
		if u.has_status(STATUS_SLEEP):
			u.moved = true
			u.acted = true
		if u.alive() and u.has_trait(TRAIT_DEEP_ROOTS) and u.hp < u.max_hp:
			u.hp = mini(u.max_hp, u.hp + REGROW)
			events.append({"type": "heal", "src": u, "unit": u, "amount": REGROW})
		for s in STATUS_UNTIL_OWN_PHASE:
			u.statuses.erase(s)
		for id in u.cooldowns.keys():
			u.cooldowns[id] = int(u.cooldowns[id]) - 1
			if u.cooldowns[id] <= 0:
				u.cooldowns.erase(id)
	return events


## End of a team's phase: timed statuses like rooted tick down.
static func end_phase(units: Array, team: int) -> void:
	for u: CombatUnit in units:
		if u.team != team:
			continue
		for s in u.statuses.keys():
			if s in STATUS_UNTIL_OWN_PHASE:
				continue
			u.statuses[s] = int(u.statuses[s]) - 1
			if u.statuses[s] <= 0:
				u.statuses.erase(s)


## Every cell a team could hit next phase (Fire Emblem's danger zone).
static func danger_zone(grid: CombatGrid, units: Array, team: int) -> Dictionary:
	var zone := {}
	for u: CombatUnit in units:
		if u.team != team or not u.alive() or u.has_status(STATUS_SLEEP):
			continue
		var froms: Array = CombatRules.reachable(grid, u, units).cost.keys()
		var ranges: Array[Vector2i] = []
		for a in u.abilities:
			if a.hostile() and u.can_use(a):
				var r := ability_range(u, a)
				if a.target == "cell":
					r.y += a.radius
				if not ranges.has(r):
					ranges.append(r)
		for f: Vector2i in froms:
			for y in grid.h:
				for x in grid.w:
					var c := Vector2i(x, y)
					if zone.has(c):
						continue
					for r in ranges:
						if in_reach(grid, f, c, r):
							zone[c] = true
							break
	return zone


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

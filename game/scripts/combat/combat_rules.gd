class_name CombatRules
extends RefCounted
## Pure combat math. No nodes, so tests and the balance sim can call it headless.
## Numbers are [AI] proposals; see docs/decisions.md.

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const SPOOKED_MOVE := -2
const MELEE_REACH := 2  ## melee can't hit across more height than this
const HIGH_RANGE_MAX := 3  ## bows and spells gain +1 range per level up, to this many
const SKITTISH_DC := 11
const SKITTISH_RANGE := 3
const BUMP_DAMAGE := 2  ## pushed into a wall, rock, cliff face or another unit
const FALL_DAMAGE := 2  ## per level dropped beyond the first when pushed off a ledge

const STATUS_GUARD := "guard"
const STATUS_VEIL := "veil"
const STATUS_ROOTED := "rooted"
const STATUS_SLEEP := "sleep"  ## skips the owner's next phase, can't hit back; any damage wakes it
const STATUS_GUIDED := "guided"  ## STAR POINT: more crit chance until the owner's next phase
const STATUS_TAUNT := "taunt"  ## foes that can reach the taunter must hit it, until the taunter's next phase
const STATUS_SLOW := "slow"  ## less move for a phase
const STATUS_SPOOK := "spook"  ## a hexer's scare: hits for less until the end of the phase it lands in (acts as spooked)
const STATUS_FOE_WARD := "foe_ward"  ## a warder's ward on a foe: more armor until that side next moves
const STATUS_BLEED := "bleed"  ## loses a little HP at the start of each of its phases (a ranked bite)
const STATUS_BRANCH := "branch_armor"  ## Bushberry's BRANCH ARMOR: the next foe hit does branch_soften less (at least 1), the hitter takes branch_thorns; gone at his side's next phase
const STATUS_WARD := "ward"  ## the book's WARD: the next hit on this piece does 0 and no status; gone at the mage's next phase
const STATUS_OVERWATCH := "overwatch"  ## the bow's OVERWATCH: the first foe to move into its reach takes a plain shot and stops
const STATUS_BURN := "burn"  ## Amber's A Heart that Burns: `burn_damage` at the start of each phase for `burn_turns` phases
const STATUS_POISON := "poison"  ## the same, from the rogue's blades: `poison_damage` for `poison_turns` phases
const STATUS_BLIND := "blind"  ## FLASH: its ranged attacks reach only 1 tile (so a bow or a spell can't attack at all)
const STATUS_RALLIED := "rallied"  ## RALLY: walks again this phase with `rally_move` more
const STATUS_INSPIRED := "inspired"  ## INSPIRE: `inspire_damage` more on every hit
const STATUS_LAST_STAND := "last_stand"  ## LAST STAND: falling while it is on adds the skill's turns to the bleed-out
## Fields: what an ability leaves on the ground (CombatGrid.fields).
const FIELD_TRAP := "trap"  ## a foe walking onto it stops there and takes the trap's hit; the trap is spent
const FIELD_CALTROPS := "caltrops"  ## a foe walking onto it stops there, takes the hit and is slowed; it stays
const FIELD_FIRE := "fire"  ## burning ground: nobody can walk onto it
const FIELD_SMOKE := "smoke"  ## nobody can attack from more than 1 tile away into, out of or across it
## Cleared when the owner's next phase starts (they protect through the enemy phase).
const STATUS_UNTIL_OWN_PHASE := [STATUS_BRANCH, STATUS_GUARD, STATUS_VEIL, STATUS_GUIDED, STATUS_TAUNT, STATUS_WARD, STATUS_OVERWATCH, STATUS_FOE_WARD]

## Combat traits (one per roster character, a few for enemy classes). Ids live in the .tres traits arrays.
const TRAIT_SHIELD_WALL := &"shield_wall"  ## Lead: allies standing next to them get more armor
const TRAIT_STARLIT := &"starlit"  ## Stardrop: spells get +1 damage when cast from height 2 or more
const TRAIT_STEADY_AIM := &"steady_aim"  ## Hunter: more crit chance when attacking without having moved this turn
const TRAIT_SCHOLAR := &"scholar"  ## Wizard: spells deal +1 damage and heal +1
const TRAIT_DEEP_ROOTS := &"deep_roots"  ## Bushberry: can't be pushed, regrows 1 HP at the start of its phase
const TRAIT_BONES := &"bones"  ## Skeleton: makes the piece undead (arrows -2, fire +2: data/tags.csv)
const TRAIT_DOUBLE_STRIKE := &"double_strike"  ## Lewith & Flark: the basic hit swings twice at -1 damage each
const TRAIT_QUICK_HANDS := &"quick_hands"  ## Shade: the basic hit swings twice at -1 damage each (like double_strike), upgradable
const TRAIT_BLOODIED := &"bloodied"  ## Reaver: more damage and crit the lower its HP (combat.csv bloodied_*)
const TRAIT_KEEPS_BACK := &"keeps_back"  ## Mender foe: stays 2 or more tiles from heroes, attacks only when cornered
const TRAIT_CHARGE := &"charge"  ## Rusher and bull: a straight run of 3 or more tiles this phase adds charge_bonus to its hits
const TRAIT_PACK := &"pack"  ## Wolf: +1 damage on a flanked target
const TRAIT_GLEAN := &"glean"  ## Bushberry ([USER] 2026-11-01 design-bb-kit): friends next to him heal at the start of their phase; stacks with Good Boy
const TRAIT_GOOD_BOY := &"good_boy"  ## Doggo ([USER] 2026-10-31 design-goodboy): a friend next to him heals at the start of its phase
const TRAIT_HEART_BURNS := &"heart_burns"  ## Amber ([USER] 2026-11-01): plain attacks may set the target burning (heart_burn_pct)
const TRAIT_GOOD_SHOT := &"good_shot"  ## the bow ([USER] 2026-11-01 F5): plain attacks hit harder and crit more; a kill gives another attack
const TRAIT_POISON_BLADES := &"poison_blades"  ## Rogue: every hit leaves POISON ([USER] design-boss-daggers)
const TRAIT_STAND_WATCH := &"stand_watch"  ## Bow: an archer that doesn't move in its phase ends it on OVERWATCH, free
const TRAIT_STRUCTURE := &"structure"  ## an ice pillar: never acts or hits back, stands in the way, doesn't count toward winning
const TRAIT_AMBUSH := &"ambush"  ## Ambusher: waits hidden; its first strike from hiding counts as a flank ([USER] design-foe-roles)
const SPOT_RANGE := 3  ## a party piece ending a move this close, with line of sight, spots a hidden foe
const TRAIT_HIT_AND_RUN := &"hit_and_run"  ## Rogue: after a hit, may walk the move it didn't use before it
const PERK_FLAMMABLE := &"flammable"  ## takes +2 damage from fire
const STARLIT_HEIGHT := 2
const FLAMMABLE_DMG := 2
const REGROW := 1

## Rule switches the sandbox can flip to compare. Real fights use the defaults.
static var counters := true  ## melee units hit back once when attacked in reach


static func reset_switches() -> void:
	counters = true


## A rule number from data/combat.csv ([USER] 2026-10-29 defaults, tuned in play).
static func num(key: String) -> float:
	if Db.combat.is_empty():
		Db.reload()
	return float(Db.combat[key])


static func dist(a: Vector2i, b: Vector2i) -> int:
	var d := CombatGrid.ground(a) - CombatGrid.ground(b)
	return absi(d.x) + absi(d.y)


static func height_levels(grid: CombatGrid, from: Vector2i, to: Vector2i) -> int:
	var n := int(num("height_levels_max"))
	return clampi(grid.height_at(from) - grid.height_at(to), -n, n)


static func move_points(u: CombatUnit) -> int:
	if u.has_status(STATUS_ROOTED) or u.has_status(STATUS_SLEEP):
		return 0
	return maxi(1, u.move + (SPOOKED_MOVE if u.spooked else 0) + (int(num("slow_move")) if u.has_status(STATUS_SLOW) else 0) \
		+ (u.rally_move if u.has_status(STATUS_RALLIED) else 0))


## What's left of this phase's move: all of it, less what the piece already walked (hit and run spends the rest).
static func move_left(u: CombatUnit) -> int:
	return maxi(0, move_points(u) - u.move_spent)


## Hit and run (the rogue, [USER] design-boss-daggers, Fire Emblem's Canto): after an attack the piece may still
## walk what's left of its move. Reopens the move and returns true when there's any left.
static func hit_and_run(u: CombatUnit, a: Ability) -> bool:
	if a == null or a.kind != "attack" or not u.alive() or not u.has_trait(TRAIT_HIT_AND_RUN) or move_left(u) <= 0:
		return false
	u.moved = false
	return true


static func unit_at(units: Array, c: Vector2i) -> CombatUnit:
	for o: CombatUnit in units:
		if o.alive() and o.cell == c:
			return o
	return null


## Whoever takes up the cell: a standing piece, or a downed one bleeding out on it.
static func occupant(units: Array, c: Vector2i) -> CombatUnit:
	for o: CombatUnit in units:
		if (o.alive() or o.downed()) and o.cell == c:
			return o
	return null


## Dijkstra over move cost. Returns {"cost": {cell: int}, "prev": {cell: cell}}.
## Units pass through allies but can't stop on them, and can't pass enemies.
static func reachable(grid: CombatGrid, u: CombatUnit, units: Array, budget := -1) -> Dictionary:
	var cost := {u.cell: 0}
	var prev := {}
	var open: Array[Vector2i] = [u.cell]
	if budget < 0:
		budget = move_left(u)
	while not open.is_empty():
		var bi := 0
		for i in open.size():
			if cost[open[i]] < cost[open[bi]]:
				bi = i
		var c: Vector2i = open.pop_at(bi)
		for d in DIRS:
			for n in grid.places_next(c, d):
				if not grid.passable(n):
					continue
				if not grid.can_step(c, n, u.jump):
					continue
				if not grid.fields.is_empty() and field_at(grid, n, FIELD_FIRE) != null:
					continue  # IGNITE's burning ground blocks the way
				var other := occupant(units, n)
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
		if c != u.cell and occupant(units, c) != null:
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
	var r := Vector2i(u.range_min, u.range_max) if a == null or a.uses_weapon_range() else Vector2i(a.range_min, a.range_max)
	if u.has_status(STATUS_BLIND) and (a == null or a.hostile()):
		r.y = mini(r.y, 1)  # FLASH: blinded, it can only hit what is next to it
	return r


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
	if reach > 1 and d > 1 and not grid.fields.is_empty() and smoked(grid, from, to):
		return false
	return reach <= 1 or d <= 1 or grid.line_of_sight(from, to)


## Is there SMOKE on `from`, on `to`, or on a tile the line between them crosses?
static func smoked(grid: CombatGrid, from: Vector2i, to: Vector2i) -> bool:
	var a := Vector2(CombatGrid.ground(from)) + Vector2(0.5, 0.5)
	var b := Vector2(CombatGrid.ground(to)) + Vector2(0.5, 0.5)
	var steps := maxi(1, int(ceil(a.distance_to(b) * 3.0)))
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		var c := Vector2i(int(floor(p.x)), int(floor(p.y)))
		for q in grid.places_at(c):
			if field_at(grid, q, FIELD_SMOKE) != null:
				return true
		if field_at(grid, c, FIELD_SMOKE) != null:
			return true
	return false


## The field of `kind` on place c, or null.
static func field_at(grid: CombatGrid, c: Vector2i, kind: String):
	for f: Dictionary in grid.fields.get(c, []):
		if f.kind == kind:
			return f
	return null


## Cells a ranged piece standing at `from` could reach with its basic attack but can't see ([USER] c14:
## hovering a ranged piece shades them). Empty for melee pieces.
static func blind_cells(grid: CombatGrid, u: CombatUnit, from: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r := ability_range(u, null)
	if r.y <= 1:
		return out
	var far := r.y + HIGH_RANGE_MAX
	for y in range(from.y - far, from.y + far + 1):
		for x in range(from.x - far, from.x + far + 1):
			var c := Vector2i(x, y)
			var d := dist(from, c)
			if d < maxi(2, r.x) or not grid.in_bounds(c):
				continue
			if d <= r.y + clampi(grid.height_at(from) - grid.height_at(c), 0, HIGH_RANGE_MAX) and not grid.line_of_sight(from, c):
				out.append(c)
	return out


## The foes a taunter pulls ([USER] 2026-10-29: any foe that can reach it must hit it): every awake, unhidden foe
## that could walk somewhere this phase and land its plain hit on the taunter from there. Bark's feedback turns these
## to face the dog, and EnemyAi makes them hit him.
static func taunt_pulls(grid: CombatGrid, taunter: CombatUnit, units: Array) -> Array[CombatUnit]:
	var out: Array[CombatUnit] = []
	for o: CombatUnit in units:
		if o.team == taunter.team or not o.alive() or o.hiding or o.has_status(STATUS_SLEEP) or o.has_trait(TRAIT_STRUCTURE):
			continue
		var r := ability_range(o, null)
		for f: Vector2i in reachable(grid, o, units).cost:
			if in_reach(grid, f, taunter.cell, r):
				out.append(o)
				break
	return out


static func can_attack(grid: CombatGrid, att: CombatUnit, tgt: CombatUnit, from: Vector2i) -> bool:
	if not tgt.alive() or tgt.team == att.team:
		return false
	return in_reach(grid, from, tgt.cell, ability_range(att, null))


## Can this unit use this ability right now (enough mana, rage or charges)? An item also has to be on the unit's own belt
## ([USER] 2026-10-29: in a fight a piece uses only what is on its belt, and using it is its action).
static func usable(u: CombatUnit, a: Ability) -> bool:
	if not u.can_use(a):
		return false
	if a.cooldown > 0 and not a.boss_move() and u.phase_no < int(u.ready_at.get(a.id, a.first)):
		return false  # COMMAND: once every few of the user's phases
	if a.is_item():
		return u.belt != null and u.belt.count(a.spends) >= a.cost
	return true


## Cells the ability can be aimed at from `from`.
static func target_cells(grid: CombatGrid, u: CombatUnit, a: Ability, units: Array, from: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r := ability_range(u, a)
	var held := held_at(grid, u, units, from) if a.hostile() else ([] as Array[CombatUnit])
	if not held.is_empty():
		# [USER] c13: a piece still next to a guard that held it at the start of its phase can only attack the guard
		for g in held:
			if in_reach(grid, from, g.cell, r):
				out.append(g.cell)
		return out
	if a.hostile():
		# a taunting foe in reach must be the target ([USER] 2026-10-29, combat build step 5)
		var taunts: Array[Vector2i] = []
		for o: CombatUnit in units:
			if o.alive() and o.team != u.team and o.has_status(STATUS_TAUNT) and in_reach(grid, from, o.cell, r):
				taunts.append(o.cell)
		if not taunts.is_empty():
			return taunts
	if a.kind == "carry" or a.kind == "command" or a.kind == "swap":
		# CARRY: a friend next to the dog, up or down; COMMAND: any standing friend; SHADOW SWAP: a friend within 3,
		# up or down, through anything in between
		for o: CombatUnit in units:
			if o == u or o.team != u.team or not (o.alive() or (a.kind != "command" and o.downed())):
				continue
			if (a.kind == "command" and commandable(u, a, o, from)) or (a.kind == "carry" and dist(from, o.cell) == 1) or (a.kind == "swap" and dist(from, o.cell) <= a.range_max):
				out.append(o.cell)
		return out
	match a.target:
		"self":
			out.append(from)
		"downed":  # AID (own side) or a knock-out (the other side) on a piece bleeding out
			for o: CombatUnit in units:
				if o.downed() and (o.team == u.team) == (a.kind == "revive") and in_reach(grid, from, o.cell, r):
					out.append(o.cell)
		"enemy", "ally":
			for o: CombatUnit in units:
				if not o.alive():
					continue
				if (a.target == "enemy") != (o.team != u.team) or (o.hiding and o.team != u.team):
					continue  # a hidden foe can't be picked; an area blast still catches it
				var oc := from if o == u else o.cell
				if in_reach(grid, from, oc, r):
					out.append(oc)
			if raises(a):  # MEND stands a downed friend up ([USER] 2026-11-01 design-bb-kit)
				for o: CombatUnit in units:
					if o.downed() and o.team == u.team and in_reach(grid, from, o.cell, r):
						out.append(o.cell)
		"cell":
			var ground := a.field == FIELD_TRAP or a.field == FIELD_CALTROPS  # set on an empty tile a foe could walk onto
			for y in grid.h:
				for x in grid.w:
					for c in grid.places_at(Vector2i(x, y)):
						if ground and (not grid.passable(c) or occupant(units, c) != null or (c == from)):
							continue
						if in_reach(grid, from, c, r):
							out.append(c)
	return out


## Every place an ability used from `from` could aim at, foe or not ([USER] 2026-10-30, Brandon: hovering an
## action shows its range): the cells in its reach by the same height and sight rules as targeting. A
## self-only skill reaches its own cell.
static func reach_cells(grid: CombatGrid, u: CombatUnit, a: Ability, from: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if a.target == "self":
		out.append(from)
		return out
	var r := ability_range(u, a)
	var g := CombatGrid.ground(from)
	var span := r.y + HIGH_RANGE_MAX + 1
	for y in range(maxi(0, g.y - span), mini(grid.h, g.y + span + 1)):
		for x in range(maxi(0, g.x - span), mini(grid.w, g.x + span + 1)):
			for c in grid.places_at(Vector2i(x, y)):
				if c != from and grid.terrain_at(c) != CombatGrid.T.VOID and in_reach(grid, from, c, r):
					out.append(c)
	return out


## Cells hit when aiming at `center` (a plus shape for radius 1). On a deck the blast stays on the deck where
## the deck goes on and spills to the ground past its edge; in the lane under a deck the deck shields what's on it.
static func area(grid: CombatGrid, a: Ability, center: Vector2i, from := CombatGrid.NONE_CELL) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var mid := CombatGrid.ground(center)
	if a.line > 0 and from != CombatGrid.NONE_CELL:  # IGNITE: a line from the aimed tile, away from the user
		var d := mid - CombatGrid.ground(from)
		var dir := Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y))
		if dir == Vector2i.ZERO:
			dir = Vector2i(1, 0)
		for i in a.line:
			var c := mid + dir * i
			if grid.in_bounds(c):
				out.append(c)
		return out
	for y in range(mid.y - a.radius, mid.y + a.radius + 1):
		for x in range(mid.x - a.radius, mid.x + a.radius + 1):
			var c := Vector2i(x, y)
			if grid.in_bounds(c) and dist(c, mid) <= a.radius:
				out.append(CombatGrid.deck_of(c) if CombatGrid.on_deck(center) and grid.has_deck(c) else c)
	return out


## Units an ability affects when aimed at `center`. `user` stands in for whoever is at `from` while previewing a move.
static func affected_units(grid: CombatGrid, user: CombatUnit, a: Ability, center: Vector2i, units: Array, from: Vector2i) -> Array[CombatUnit]:
	var out: Array[CombatUnit] = []
	for c in area(grid, a, center, from):
		var o: CombatUnit = user if c == from else (occupant(units, c) if a.target == "downed" or a.status == STATUS_LAST_STAND or raises(a) else unit_at(units, c))
		if o == null or (o == user and c != from):
			continue
		if (a.target == "enemy" or a.kind == "hex") and o.team == user.team:
			continue  # a hex (FLASH, a scare) never lands on the user's own side
		if (a.target == "ally" or a.target == "self") and o.team != user.team:
			continue  # a buff round the user (INSPIRE, LAST STAND) only reaches friends
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


## [USER] 2026-10-29: hits always land. Damage = unit damage + skill power and the parts below, wobbling
## a point either way, minus armor, at least 1. Crits (10% base, more on a flank) double it.
## Every part is a [label key, value] pair so the forecast can print it.
static func damage_parts(grid: CombatGrid, att: CombatUnit, tgt: CombatUnit, from: Vector2i, a: Ability = null, units: Array = []) -> Array:
	var parts := [["MOD_DAMAGE", att.damage]]
	if a != null and a.power != 0:
		parts.append(["MOD_SKILL", a.power])
	var hl := height_levels(grid, from, tgt.cell) * int(num("height_damage"))
	if hl != 0:
		parts.append(["MOD_HEIGHT", hl])
	var spell := a != null and a.is_spell()
	if spell and att.has_trait(TRAIT_SCHOLAR):
		parts.append(["MOD_SCHOLAR", 1])
	if _starlit(grid, att, from, a):
		parts.append(["MOD_STARLIT", 1])
	if swings(att, a) > 1:
		parts.append(["MOD_TWICE", -1])
		if att.has_trait(TRAIT_QUICK_HANDS) and upg(att, "quick_damage") > 0:
			parts.append(["MOD_QUICK", upg(att, "quick_damage")])
	var blood := bloodied_level(att)
	if blood > 0:
		parts.append(["MOD_BLOODIED", blood + upg(att, "bloodied_damage")])
	if att.free_hitting and upg(att, "guard_hit") > 0:
		parts.append(["MOD_GUARD_HIT", upg(att, "guard_hit")])
	if att.cmd_bonus > 0:
		parts.append(["MOD_COMMANDED", att.cmd_bonus])
	if att.watching_shot and upg(att, "watch_damage") > 0:
		parts.append(["MOD_WATCH", upg(att, "watch_damage")])
	if att.has_trait(TRAIT_PACK) and flanked(att, tgt, units, from):
		parts.append(["MOD_PACK", 1])
	if a != null and a.element == "fire" and tgt.has_trait(PERK_FLAMMABLE):
		parts.append(["MOD_FLAMMABLE", FLAMMABLE_DMG])
	var magic := att.magic or (a != null and a.magic)
	if (magic or spell) and att.magic_power != 0:
		parts.append(["MOD_MAGIC", att.magic_power])
	var kinds := attack_kinds(att, a, from, tgt)
	for t in tgt.tags:  # foe tags ([USER] design-foe-weakness): at least 1 still gets through
		var n := 0
		for row: Dictionary in Db.foe_tags:
			if row.tag == String(t) and kinds.has(String(row.kind)):
				n += int(row.change)
		if n != 0:
			parts.append(["FOE_" + String(t).to_upper(), n])
	if att.spooked or att.has_status(STATUS_SPOOK):
		parts.append(["MOD_SPOOKED", int(num("spooked_damage")) + (att.spook_extra if att.has_status(STATUS_SPOOK) else 0)])
	if a != null and a.is_basic() and att.has_trait(TRAIT_GOOD_SHOT):
		parts.append(["MOD_GOOD_SHOT", int(num("good_shot_damage")) + upg(att, "good_shot_damage")])
	if att.has_status(STATUS_INSPIRED) and att.inspire_dmg != 0:
		parts.append(["MOD_INSPIRED", att.inspire_dmg])
	if att.rally_dmg > 0:
		parts.append(["MOD_RALLIED", att.rally_dmg])
	if att.has_trait(TRAIT_CHARGE) and charged(att, from):
		parts.append(["MOD_CHARGE", int(num("charge_bonus"))])
	return parts


## Did att run in a straight line (along a row or a column) for charge_min tiles or more this phase, ending on `from`?
static func charged(att: CombatUnit, from: Vector2i) -> bool:
	var d := CombatGrid.ground(from) - CombatGrid.ground(att.move_origin)
	return (d.x == 0 or d.y == 0) and maxi(absi(d.x), absi(d.y)) >= int(num("charge_min"))


## What kind of blow this is for the foe tags: blade (non-magic melee), arrow (non-magic ranged), spell (magic),
## and fire as well when its element is fire.
static func attack_kinds(att: CombatUnit, a: Ability, from: Vector2i, tgt: CombatUnit) -> Array[String]:
	var out: Array[String] = []
	if att.magic or (a != null and a.magic):
		out.append("spell")
	else:
		out.append("blade" if dist(from, tgt.cell) <= 1 else "arrow")
	if a != null and a.element == "fire":
		out.append("fire")
	return out


## What comes off every hit on tgt: its armor, GUARD, the veil, a shield wall, and half cover against ranged hits.
static func armor_parts(grid: CombatGrid, att: CombatUnit, tgt: CombatUnit, from: Vector2i, a: Ability = null, units: Array = []) -> Array:
	var parts := []
	if tgt.armor != 0:
		parts.append(["MOD_ARMOR", tgt.armor])
	if tgt.has_status(STATUS_GUARD):
		parts.append(["MOD_GUARD", int(num("guard_armor")) + upg(tgt, "guard_armor")])
	if tgt.has_status(STATUS_TAUNT) and upg(tgt, "taunt_armor") > 0:
		parts.append(["MOD_TAUNT", upg(tgt, "taunt_armor")])
	if tgt.has_status(STATUS_VEIL):
		parts.append(["MOD_VEIL", int(num("veil_armor"))])
	if tgt.has_status(STATUS_FOE_WARD):
		parts.append(["MOD_FOE_WARD", int(num("foe_ward_armor"))])
	var wall := shield_armor(tgt, units)
	if wall > 0:
		parts.append(["MOD_SHIELD", wall])
	if dist(from, tgt.cell) > 1 and grid.cover(tgt.cell) > 0:
		parts.append(["MOD_COVER", int(num("cover_ranged"))])  # [USER] c14: half cover, ranged hits only
	return parts


## % chance a hit is a crit, as parts: the base, a flank (an ally already next to the target), the skill,
## the attacker's own (class and attack bonuses), steady aim and STAR POINT.
static func crit_parts(grid: CombatGrid, att: CombatUnit, tgt: CombatUnit, units: Array, from: Vector2i, a: Ability = null) -> Array:
	var parts := [["MOD_CRIT", int(num("crit_base"))]]
	if flanked(att, tgt, units, from) or att.hiding:  # a strike from hiding counts as a flank
		parts.append(["MOD_FLANK", int(num("crit_flank"))])
	if a != null and a.crit != 0:
		parts.append(["MOD_SKILL", a.crit])
	if att.crit != 0:
		parts.append(["MOD_OWN", att.crit])
	if att.has_trait(TRAIT_STEADY_AIM) and not att.moved and from == att.cell:
		parts.append(["MOD_STEADY", int(num("crit_steady"))])
	if att.has_status(STATUS_GUIDED):
		parts.append(["MOD_GUIDED", int(num("crit_guided"))])
	if att.has_trait(TRAIT_QUICK_HANDS) and a != null and a.is_basic() and upg(att, "quick_crit") > 0:
		parts.append(["MOD_QUICK", upg(att, "quick_crit")])
	if a != null and a.is_basic() and att.has_trait(TRAIT_GOOD_SHOT):
		parts.append(["MOD_GOOD_SHOT", int(num("good_shot_crit")) + upg(att, "good_shot_crit")])
	if bloodied_level(att) > 0:
		parts.append(["MOD_BLOODIED", int(num("bloodied_crit")) + upg(att, "bloodied_crit")])
	if att.watching_shot and upg(att, "watch_crit") > 0:
		parts.append(["MOD_WATCH", upg(att, "watch_crit")])
	return parts


static func crit_chance(grid: CombatGrid, att: CombatUnit, tgt: CombatUnit, units: Array, from: Vector2i, a: Ability = null) -> float:
	return clampf(_sum(crit_parts(grid, att, tgt, units, from, a)) / 100.0, 0.0, 1.0)


## Is someone with shield_wall standing next to this unit (and on its side)?
static func shielded(tgt: CombatUnit, units: Array) -> bool:
	for o: CombatUnit in units:
		if o != tgt and o.alive() and o.team == tgt.team and o.has_trait(TRAIT_SHIELD_WALL) and dist(o.cell, tgt.cell) == 1:
			return true
	return false


## The armor a shield wall next to tgt gives it: the best of the wall-bearers close enough (1 tile, 2 with the upgrade), 0 if none.
static func shield_armor(tgt: CombatUnit, units: Array) -> int:
	var best := 0
	for o: CombatUnit in units:
		if o == tgt or not o.alive() or o.team != tgt.team or not o.has_trait(TRAIT_SHIELD_WALL):
			continue
		if dist(o.cell, tgt.cell) <= 1 + upg(o, "shield_wall_radius"):
			best = maxi(best, int(num("shield_wall_armor")) + upg(o, "shield_wall_armor"))
	return best


static func _starlit(grid: CombatGrid, u: CombatUnit, from: Vector2i, a: Ability) -> bool:
	return a != null and a.is_spell() and u.has_trait(TRAIT_STARLIT) and grid.height_at(from) >= STARLIT_HEIGHT


## How many times this ability rolls against each target (Lewith & Flark's basic hit swings twice, so do the shade's quick hands).
static func swings(u: CombatUnit, a: Ability) -> int:
	return 2 if a != null and a.is_basic() and (u.has_trait(TRAIT_DOUBLE_STRIKE) or u.has_trait(TRAIT_QUICK_HANDS)) else 1


## A number upgrade the piece took at a level-up ("guard_armor", "quick_damage"...): 0 without it.
static func upg(u: CombatUnit, key: String) -> int:
	return int(u.upgrades.get(key, 0))


## HP under which a bloodied piece is hurt enough for its bonus: half its max, plus the upgrade's % of max.
static func bloodied_level(u: CombatUnit) -> int:
	if not u.has_trait(TRAIT_BLOODIED):
		return 0
	var line := int(num("bloodied_half")) + upg(u, "bloodied_threshold")
	if u.hp * 100 <= u.max_hp * (line / 2):
		return 2
	return 1 if u.hp * 100 <= u.max_hp * line else 0


## What a heal restores, before capping at max HP.
## Spells heal more as the caster's magic grows ([USER] pc-8: skills grow with the character on their own).
static func heal_amount(u: CombatUnit, a: Ability) -> int:
	var rage := u.res if a.id == "second_wind" else 0  # the reaver's SECOND WIND adds all the rage it has left, and spends it
	return a.power + rage + (1 if a.is_spell() and u.has_trait(TRAIT_SCHOLAR) else 0) + (u.magic_power if a.is_spell() else 0)


static func _sum(parts: Array) -> int:
	var s := 0
	for p in parts:
		s += int(p[1])
	return s


## Damage of one hit before a crit: the parts, a wobble (-wobble..+wobble), minus armor, at least 1.
## `units` is needed for the wolf's pack trait and the shield wall.
static func damage(grid: CombatGrid, att: CombatUnit, tgt: CombatUnit, from: Vector2i, a: Ability = null, units: Array = [], wobble := 0) -> int:
	var raw := _sum(damage_parts(grid, att, tgt, from, a, units)) + wobble
	return maxi(int(num("min_damage")), raw - _sum(armor_parts(grid, att, tgt, from, a, units)))


## Lowest and highest damage of one hit, before a crit.
static func damage_range(grid: CombatGrid, att: CombatUnit, tgt: CombatUnit, from: Vector2i, a: Ability = null, units: Array = []) -> Vector2i:
	var w := int(num("wobble"))
	return Vector2i(damage(grid, att, tgt, from, a, units, -w), damage(grid, att, tgt, from, a, units, w))


## Average damage of one hit, crits counted. The AI weighs moves with it.
static func expected_damage(grid: CombatGrid, att: CombatUnit, tgt: CombatUnit, from: Vector2i, a: Ability = null, units: Array = []) -> float:
	var r := damage_range(grid, att, tgt, from, a, units)
	var c := crit_chance(grid, att, tgt, units, from, a)
	return (r.x + r.y) * 0.5 * (1.0 + c * (num("crit_mult") - 1.0))


## Would `tgt` strike back at `att` standing on `from`?
static func counters_from(grid: CombatGrid, att: CombatUnit, tgt: CombatUnit, from: Vector2i) -> bool:
	if not counters or not tgt.alive() or tgt.team == att.team or tgt.has_status(STATUS_SLEEP) or tgt.has_trait(TRAIT_STRUCTURE):
		return false
	return in_reach(grid, tgt.cell, from, ability_range(tgt, null))


## What the player sees before committing. One entry per affected unit, plus the counter if any.
## {"targets": [{"unit", "dmg", "dmg_min", "dmg_max", "crit", "swings", "heal", "dmg_parts", "armor_parts",
## "crit_parts"}], "counter": {"unit", "dmg", "dmg_min", "dmg_max", "crit", "swings"} or {}}
## dmg (the middle of the range) and the range are per swing, before a crit; swings is 2 for a double strike.
static func forecast(grid: CombatGrid, u: CombatUnit, a: Ability, center: Vector2i, units: Array, from: Vector2i) -> Dictionary:
	var out := {"targets": [], "counter": {}}
	var hit_list := affected_units(grid, u, a, center, units, from)
	for t in hit_list:
		var e := {"unit": t, "dmg": 0, "dmg_min": 0, "dmg_max": 0, "crit": 0.0, "swings": 1, "heal": 0,
			"dmg_parts": [], "armor_parts": [], "crit_parts": [], "help": 0, "helper": null}
		match a.kind:
			"attack":
				var r := damage_range(grid, u, t, from, a, units)
				e.dmg = damage(grid, u, t, from, a, units)
				e.dmg_min = r.x
				e.dmg_max = r.y
				e.crit = crit_chance(grid, u, t, units, from, a)
				e.swings = swings(u, a)
				e.dmg_parts = damage_parts(grid, u, t, from, a, units)
				e.armor_parts = armor_parts(grid, u, t, from, a, units)
				e.crit_parts = crit_parts(grid, u, t, units, from, a)
				var h := helper(u, t, units, from)
				if h != null:
					e.help = help_damage(u, h)
					e.helper = h
			"heal":
				e.heal = mini(heal_amount(u, a), t.max_hp - t.hp)
			"revive":
				e.heal = aid_hp(t)
		out.targets.append(e)
	if a.kind == "attack" and a.radius == 0 and hit_list.size() == 1:
		var t: CombatUnit = hit_list[0]
		if counters_from(grid, u, t, from):
			var r := damage_range(grid, t, u, t.cell, null, units)
			out.counter = {"unit": t, "dmg": damage(grid, t, u, t.cell, null, units), "dmg_min": r.x, "dmg_max": r.y,
				"crit": crit_chance(grid, t, u, units, t.cell), "swings": swings(t, t.abilities[0])}
	return out


# --- resolving actions ------------------------------------------------------------

## Uses an ability (or item) and applies everything. Returns the events in order so the board can animate them:
## {"type": "hit"|"heal"|"status"|"push"|"bump"|"fall"|"counter", "src", "unit", "amount", "crit", "struck", "path"}
## Item costs are paid from the user's belt here.
static func resolve(rng: RandomNumberGenerator, grid: CombatGrid, u: CombatUnit, a: Ability, center: Vector2i, units: Array, allow_counter := true) -> Array:
	var events := []
	if u.hiding and a.hostile():
		events.append({"type": "reveal", "unit": u})  # the strike still counts from hiding (crit_parts reads it first)
	if a.res_cost > 0:
		u.res = maxi(0, u.res - a.res_cost)
	if a.is_item():
		u.belt.take(a.spends, a.cost)
	if a.field != "":
		events.append_array(lay_field(grid, u, a, center))
		if a.field != FIELD_FIRE:  # a trap, caltrops or smoke only lies there; IGNITE's fire also hits who stands in it
			return events
	var hit_list := affected_units(grid, u, a, center, units, u.cell)
	for t in hit_list:
		match a.kind:
			"attack", "hex":
				for i in swings(u, a):
					if not t.alive():
						break
					events.append_array(_swing(rng, grid, u, a, t, units))
				var h := helper(u, t, units, u.cell) if allow_counter and a.kind == "attack" else null
				if h != null and t.alive():
					var n := help_damage(u, h)
					t.hp = maxi(0, t.hp - n)
					t.statuses.erase(STATUS_SLEEP)
					events.append({"type": "help", "src": h, "unit": t, "amount": n, "by": u})
			"heal":
				if t.downed() and raises(a):  # MEND on a downed friend: up again at its heal amount
					t.hp = mini(t.max_hp, heal_amount(u, a))
					t.bleed = 0
					events.append({"type": "revive", "src": u, "unit": t, "amount": t.hp})
					continue
				var before := t.hp
				t.hp = mini(t.max_hp, t.hp + heal_amount(u, a))
				if a.id == "second_wind":
					u.res = 0
				events.append({"type": "heal", "src": u, "unit": t, "amount": t.hp - before})
			"revive":
				if t.downed():
					t.hp = aid_hp(t)
					t.bleed = 0
					events.append({"type": "revive", "src": u, "unit": t, "amount": t.hp})
			"knockout":
				if t.downed():
					t.bleed = 0
					events.append({"type": "knockout", "src": u, "unit": t})
			"buff":
				if a.status != "":
					t.statuses[a.status] = a.status_turns
					if a.status == STATUS_WARD:
						t.ward_hits = 1 + upg(u, "ward_hits")
					if a.status == STATUS_BRANCH:  # the caster's numbers ride on the friend until the hit comes
						t.branch_soften = int(num("branch_soften")) + upg(u, "branch_soften")
						t.branch_thorns = int(num("branch_thorns")) + upg(u, "branch_thorns")
					events.append_array(_buff(u, a, t))
					events.append({"type": "status", "src": u, "unit": t, "status": a.status})
	if u.hiding and a.hostile():
		u.hiding = false
	if allow_counter and a.is_basic() and u.has_trait(TRAIT_GOOD_SHOT) and u.alive() \
			and hit_list.any(func(t: CombatUnit) -> bool: return t.team != u.team and not t.alive()):
		u.shot_kill = true  # GOOD SHOT: a plain attack that downs a foe earns another attack (extra_shot)
	if allow_counter and a.kind == "attack" and a.radius == 0 and hit_list.size() == 1:
		var t: CombatUnit = hit_list[0]
		if u.alive() and counters_from(grid, u, t, u.cell):
			events.append({"type": "counter", "src": t, "unit": u})
			events.append_array(resolve(rng, grid, t, t.abilities[0], u.cell, units, false))
	return events


## One blow of an attack or hex against one target. It always lands; an attack's damage wobbles and may crit.
static func _swing(rng: RandomNumberGenerator, grid: CombatGrid, u: CombatUnit, a: Ability, t: CombatUnit, units: Array) -> Array:
	var events := []
	if t.has_status(STATUS_WARD) and t.team != u.team:  # WARD takes the whole blow: no damage, no status
		t.ward_hits -= 1
		if t.ward_hits <= 0:  # an upgraded ward blocks more than one hit
			t.statuses.erase(STATUS_WARD)
		events.append({"type": "hit", "src": u, "unit": t, "amount": 0, "crit": false})
		events.append({"type": "status", "src": u, "unit": t, "status": STATUS_WARD})
		return events
	if a.kind == "attack":
		var w := int(num("wobble"))
		var crit := rng.randf() < crit_chance(grid, u, t, units, u.cell, a)
		var dmg := damage(grid, u, t, u.cell, a, units, rng.randi_range(-w, w)) * (int(num("crit_mult")) if crit else 1)
		var thorns := 0
		if t.has_status(STATUS_BRANCH) and t.team != u.team:  # BRANCH ARMOR softens this hit and pricks the hitter
			dmg = maxi(1, dmg - t.branch_soften)
			thorns = t.branch_thorns
			t.statuses.erase(STATUS_BRANCH)
		t.hp = maxi(0, t.hp - dmg)
		if thorns > 0 and u.alive():
			var n := mini(thorns, u.hp)  # through armor
			u.hp -= n
			events.append({"type": "hit", "src": t, "unit": u, "amount": n, "crit": false})
		for o: CombatUnit in [u, t]:  # rage builds on every hit dealt or taken
			if o.res_kind == "rage":
				o.res = mini(o.res_max, o.res + int(num("rage_per_hit")) + o.rage_bonus)
		if crit and u.crit_heal > 0 and u.alive():
			var before := u.hp
			u.hp = mini(u.max_hp, u.hp + u.crit_heal)
			if u.hp > before:
				events.append({"type": "heal", "src": u, "unit": u, "amount": u.hp - before})
		t.statuses.erase(STATUS_SLEEP)
		events.append({"type": "hit", "src": u, "unit": t, "amount": dmg, "crit": crit})
	if t.alive() and a.status != "":
		t.statuses[a.status] = a.status_turns
		if a.status == STATUS_WARD:
			t.ward_hits = 1 + upg(u, "ward_hits")
		if a.status == STATUS_SPOOK:
			t.spook_extra = upg(u, "spook_damage")  # an upgraded scare takes more off
		events.append({"type": "status", "src": u, "unit": t, "status": a.status, "struck": a.kind == "hex"})
	if t.alive() and a.bleed > 0:
		t.statuses[STATUS_BLEED] = a.bleed
		events.append({"type": "status", "src": u, "unit": t, "status": STATUS_BLEED})
	if t.alive() and a.kind == "attack" and u.has_trait(TRAIT_POISON_BLADES):  # renews, doesn't stack
		t.statuses[STATUS_POISON] = int(num("poison_turns")) + upg(u, "poison_turns")
		t.poison_dmg = maxi(t.poison_dmg, int(num("poison_damage")) + upg(u, "poison_damage"))
		events.append({"type": "status", "src": u, "unit": t, "status": STATUS_POISON})
	if t.alive() and a.is_basic() and u.has_trait(TRAIT_HEART_BURNS) and rng.randi_range(1, 100) <= int(num("heart_burn_pct")) + upg(u, "heart_burn_pct"):
		t.statuses[STATUS_BURN] = int(num("burn_turns"))  # renews, doesn't stack
		t.burn_dmg = maxi(t.burn_dmg, int(num("burn_damage")) + upg(u, "burn_damage"))
		events.append({"type": "status", "src": u, "unit": t, "status": STATUS_BURN})
	if t.alive() and a.push != 0:  # below 0 pulls toward the user (LURE)
		events.append_array(push(grid, units, u.cell, t, a.push))
	return events


## Shoves `t` away from `from` up to n tiles. Blocked: bump damage. Dropping 2+ levels: fall damage.
## n below 0 pulls it toward `from` instead (LURE): it stops short of whatever is in the way, with no bump.
static func push(grid: CombatGrid, units: Array, from: Vector2i, t: CombatUnit, n: int) -> Array:
	var events := []
	if t.has_trait(TRAIT_DEEP_ROOTS):
		return events
	var delta := CombatGrid.ground(t.cell) - CombatGrid.ground(from)
	var dir := Vector2i(signi(delta.x), 0) if absi(delta.x) >= absi(delta.y) else Vector2i(0, signi(delta.y))
	if dir == Vector2i.ZERO:
		return events
	var pull := n < 0
	if pull:
		dir = -dir
		n = mini(-n, maxi(absi(delta.x), absi(delta.y)) - 1)
	var path: Array[Vector2i] = [t.cell]
	for i in n:
		var dest := push_place(grid, t.cell, CombatGrid.ground(t.cell) + dir)
		var blocked := not grid.passable(dest) or occupant(units, dest) != null
		if not blocked and grid.height_at(dest) - grid.height_at(t.cell) > 1:
			blocked = true
		if blocked and pull:
			break
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


## Where a piece shoved from place `at` into cell c lands: on the highest floor there it isn't shoved up into
## (a deck it slides onto level), else the ground below: off the side of a bridge it falls.
static func push_place(grid: CombatGrid, at: Vector2i, c: Vector2i) -> Vector2i:
	var best := c
	for p in grid.places_at(c):
		if grid.passable(p) and grid.height_at(p) <= grid.height_at(at) + 1 and grid.height_at(p) > grid.height_at(best):
			best = p
	return best


## GOOD SHOT's extra attack: after the action that downed a foe with a plain attack, the piece may attack again
## from where it stands, `good_shot_again` times a turn (more with the upgrade). Reopens its action; true if it did.
static func extra_shot(u: CombatUnit) -> bool:
	var kill := u.shot_kill
	u.shot_kill = false
	if not kill or not u.alive() or u.shots_again >= int(num("good_shot_again")) + upg(u, "good_shot_again"):
		return false
	u.shots_again += 1
	u.acted = false
	return true


static func guard(u: CombatUnit) -> void:
	u.statuses[STATUS_GUARD] = 1


## Start of a team's phase: fresh actions, mana and charges come back, guard and veil end, sleepers lose the turn.
## Returns heal events for traits that regrow, so the board can show them.
static func begin_phase(units: Array, team: int, grid: CombatGrid = null) -> Array:
	var events := []
	if grid != null:
		tick_fields(grid, team)
	for side in [0, 1]:  # a side with nobody seen left standing: its hidden pieces come out, or the fight never ends
		if not units.any(func(o: CombatUnit) -> bool: return o.team == side and o.alive() and not o.hiding and not o.has_trait(TRAIT_STRUCTURE)):
			for o: CombatUnit in units:
				if o.team == side and o.alive() and o.hiding:
					o.hiding = false
					events.append({"type": "reveal", "unit": o})
	for u: CombatUnit in units:
		if u.team != team:
			continue
		u.moved = false
		u.acted = false
		u.move_origin = u.cell
		u.move_spent = 0
		u.left_guard = false
		u.shot_kill = false
		u.shots_again = 0
		if u.alive():
			u.phase_no += 1
		for s: String in [STATUS_BLEED, STATUS_POISON, STATUS_BURN]:  # through armor
			if u.alive() and u.has_status(s):
				var n := mini(maxi(int(num(s + "_damage")), u.poison_dmg if s == STATUS_POISON else (u.burn_dmg if s == STATUS_BURN else 0)), u.hp)
				u.hp -= n
				events.append({"type": "bleed", "unit": u, "amount": n, "status": s})
		if u.downed():
			u.bleed -= 1  # one of its own phases gone; at 0 it's out for the fight
			if u.bleed <= 0:
				events.append({"type": "bled_out", "unit": u})
		if u.has_status(STATUS_SLEEP):
			u.moved = true
			u.acted = true
		if u.alive() and u.has_trait(TRAIT_DEEP_ROOTS) and u.hp < u.max_hp:
			u.hp = mini(u.max_hp, u.hp + REGROW)
			events.append({"type": "heal", "src": u, "unit": u, "amount": REGROW})
		var gleaner := glean_near(u, units)
		if gleaner != null and u.hp < u.max_hp:  # Glean: one Bushberry's heal; it stacks with Good Boy
			var g := mini(int(num("glean_hp")) + upg(gleaner, "glean_hp"), u.max_hp - u.hp)
			u.hp += g
			events.append({"type": "heal", "src": gleaner, "unit": u, "amount": g})
		var boy := good_boy_near(u, units)
		if boy != null and u.hp < u.max_hp:  # Good Boy: one dog's heal, however many stand near
			var n := mini(int(num("good_boy_heal")) + upg(boy, "good_boy_heal"), u.max_hp - u.hp)
			u.hp += n
			events.append({"type": "heal", "src": boy, "unit": u, "amount": n})
		for s in STATUS_UNTIL_OWN_PHASE:
			u.statuses.erase(s)
		match u.res_kind:  # the job's resource comes back ([USER] c9, c16)
			"mana":
				u.res = mini(u.res_max, u.res + ceili(u.res_max * num("mana_regen_pct") / 100.0))
			"charges":
				u.res_tick += 1
				if u.res_every > 0 and u.res_tick >= u.res_every:
					u.res_tick = 0
					u.res = mini(u.res_max, u.res + 1)
	return events


## Does this heal stand a downed friend up? MEND does while mend_raise is on (data/combat.csv).
static func raises(a: Ability) -> bool:
	return a.kind == "heal" and a.id == "mend" and int(num("mend_raise")) > 0


## The Glean (a standing Bushberry of u's side, not u) whose reach covers u, or null. Reach: 1 tile, more with upgrades.
static func glean_near(u: CombatUnit, units: Array) -> CombatUnit:
	if not u.alive():
		return null
	for o: CombatUnit in units:
		if o != u and o.team == u.team and o.alive() and o.has_trait(TRAIT_GLEAN) \
				and dist(o.cell, u.cell) <= 1 + upg(o, "glean_radius"):
			return o
	return null


## The Good Boy (a standing dog of u's side, not u) whose reach covers u, or null. Reach: 1 tile, more with upgrades.
static func good_boy_near(u: CombatUnit, units: Array) -> CombatUnit:
	if not u.alive():
		return null
	for o: CombatUnit in units:
		if o != u and o.team == u.team and o.alive() and o.has_trait(TRAIT_GOOD_BOY) \
				and dist(o.cell, u.cell) <= 1 + upg(o, "good_boy_reach"):
			return o
	return null


## End of a team's phase: timed statuses like rooted tick down.
static func end_phase(units: Array, team: int) -> void:
	for u: CombatUnit in units:
		if u.team != team:
			continue
		var stood := u.cell == u.move_origin
		u.cmd_bonus = 0
		u.rally_dmg = 0
		u.move_spent = 0  # out of its own phase a piece's reach is its whole move (the other side's threat maps)
		for s in u.statuses.keys():
			if s in STATUS_UNTIL_OWN_PHASE:
				continue
			u.statuses[s] = int(u.statuses[s]) - 1
			if u.statuses[s] <= 0:
				u.statuses.erase(s)
		if stood and u.alive() and u.has_trait(TRAIT_STAND_WATCH):  # stand and watch: one shot readied till its next phase
			u.statuses[STATUS_OVERWATCH] = 1


# --- a boss's big moves ([USER] 2026-10-30 design-boss-warning, design-boss-shape) ---------------------------

## How many of its class's health lines u's HP is at or under (ClassDef.hp_phases).
static func hp_phase_of(u: CombatUnit) -> int:
	var n := 0
	if u.cls == null:
		return 0
	for line: Dictionary in u.cls.hp_phases:
		if u.hp * 100 <= int(line.below) * u.max_hp:
			n += 1
	return n


## At the start of u's phase: if its HP has fallen under the next health line, it moves up one phase (the earlier
## phase's abilities out, the new one's in). One step a phase, so a burst turn does not skip a phase.
static func hp_phase_step(u: CombatUnit) -> Array:
	if u.cls == null or u.cls.hp_phases.is_empty() or hp_phase_of(u) <= u.hp_phase:
		return []
	u.hp_phase += 1
	for a in u.phase_abilities:
		u.abilities.erase(a)
	u.phase_abilities.clear()
	var line: Dictionary = u.cls.hp_phases[u.hp_phase - 1]
	for id in line.get("abilities", []):
		var a := Db.ability(String(id))
		if a != null:
			u.abilities.append(a)
			u.phase_abilities.append(a)
	return [{"type": "hp_phase", "unit": u, "phase": u.hp_phase}]


## Is boss move `a` ready on u's current phase? From its `first` phase, then `cooldown` phases after each use.
static func boss_ready(u: CombatUnit, a: Ability) -> bool:
	return u.phase_no >= int(u.ready_at.get(a.id, a.first))


## The start of `team`'s phase, after begin_phase: a marked big move whose wind-up is over lands on everyone on
## its tiles (the caster's own side too), before anyone moves; then each caller due calls its pieces.
static func boss_start(rng: RandomNumberGenerator, grid: CombatGrid, units: Array, team: int) -> Array:
	var events := []
	for u: CombatUnit in units.duplicate():
		if u.team != team or not u.alive():
			continue
		events.append_array(hp_phase_step(u))
		if not u.mark.is_empty():
			u.mark.left = int(u.mark.left) - 1
			if int(u.mark.left) <= 0:
				var a: Ability = u.mark.ability
				var cells: Array = u.mark.cells
				u.mark = {}
				events.append({"type": "land", "src": u, "ability": a, "cells": cells})
				for c: Vector2i in cells:
					var t := unit_at(units, c)
					if t != null and t != u and t.alive():
						for ev in _swing(rng, grid, u, a, t, units):
							ev["big"] = true  # from the sky, not a lunge
							events.append(ev)
		for a in u.abilities:
			if a.kind == "summon" and u.alive() and boss_ready(u, a):
				u.ready_at[a.id] = u.phase_no + a.cooldown
				events.append_array(summon(grid, u, a, units))
	return events


## The end of `team`'s phase, before end_phase: a caster with a big move ready and nothing marked marks it,
## aimed where it would catch most of the other side right now. It lands `windup` of its phases later.
static func boss_end(grid: CombatGrid, units: Array, team: int) -> Array:
	var events := []
	for u: CombatUnit in units:
		if u.team != team or not u.alive() or not u.mark.is_empty():
			continue
		for a in u.abilities:
			if a.windup <= 0 or not boss_ready(u, a):
				continue
			var aim := EnemyAi.mark_aim(grid, u, a, units)
			if aim == CombatGrid.NONE_CELL:
				continue  # nobody to catch: it tries again next phase
			u.ready_at[a.id] = u.phase_no + a.cooldown
			u.mark = {"ability": a, "cells": area(grid, a, aim), "left": a.windup}
			events.append({"type": "mark", "src": u, "ability": a, "cells": u.mark.cells})
			break
	return events


## u's summon `a`: `count` pieces of its class into empty cells (the map's summon cells for u if it has any,
## else within 2 of u, nearest first), never more than `limit` standing. They act from their next phase.
static func summon(grid: CombatGrid, u: CombatUnit, a: Ability, units: Array) -> Array:
	var events := []
	var cls := Db.class_def(StringName(a.summon))
	if cls == null:
		return events
	var standing := u.minions.filter(func(m: CombatUnit) -> bool: return m.alive()).size()
	var n := mini(a.count, a.limit - standing) if a.limit > 0 else a.count
	var spots: Array[Vector2i] = []
	if a.spot == "party":
		spots = party_spots(grid, u, units)
	elif not u.summon_cells.is_empty():
		spots = u.summon_cells.duplicate()
	else:
		var g := CombatGrid.ground(u.cell)
		for y in range(g.y - 2, g.y + 3):
			for x in range(g.x - 2, g.x + 3):
				if not grid.in_bounds(Vector2i(x, y)):
					continue
				for c in grid.places_at(Vector2i(x, y)):
					if c != u.cell and dist(c, u.cell) <= 2:
						spots.append(c)
		spots.sort_custom(func(p: Vector2i, q: Vector2i) -> bool:
			return dist(p, u.cell) < dist(q, u.cell) if dist(p, u.cell) != dist(q, u.cell) else (p.y < q.y if p.y != q.y else p.x < q.x))
	for c in spots:
		if n <= 0:
			break
		if not grid.passable(c) or occupant(units, c) != null:
			continue
		var m := CombatUnit.enemy(cls)
		m.team = u.team
		m.place(c, grid.height_at(c))
		m.moved = true
		m.acted = true
		m.summoner = u
		u.minions.append(m)
		units.append(m)
		n -= 1
		events.append({"type": "summon", "src": u, "unit": m})
	return events


## Where pieces raised round the party go (ice pillars): empty floor exactly 2 steps from a party piece and next to none,
## never on the way out or a stair, closest to the whole party first.
static func party_spots(grid: CombatGrid, u: CombatUnit, units: Array) -> Array[Vector2i]:
	var party := units.filter(func(o: CombatUnit) -> bool: return o.team != u.team and o.alive())
	var out: Array[Vector2i] = []
	var near := {}
	for o: CombatUnit in party:
		var g := CombatGrid.ground(o.cell)
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var at := g + Vector2i(dx, dy)
				if absi(dx) + absi(dy) != 2 or not grid.in_bounds(at):
					continue
				for c in grid.places_at(at):
					near[c] = true
	for c: Vector2i in near:
		if not grid.passable(c) or grid.terrain_at(c) == CombatGrid.T.STAIRS or u.summon_avoid.has(c) or occupant(units, c) != null:
			continue
		if party.any(func(o: CombatUnit) -> bool: return dist(o.cell, c) <= 1):
			continue
		out.append(c)
	var total := func(c: Vector2i) -> int:
		var n := 0
		for o: CombatUnit in party:
			n += dist(o.cell, c)
		return n
	out.sort_custom(func(p: Vector2i, q: Vector2i) -> bool:
		return total.call(p) < total.call(q) if total.call(p) != total.call(q) else (p.y < q.y if p.y != q.y else p.x < q.x))
	return out


## The end of `team`'s phase: each of its standing pieces next to the other side's ice pillars (4 sides) loses
## `pillar_cold` HP a pillar, at most `pillar_cold_max` pillars, through armor. Events like poison's.
static func cold(units: Array, team: int) -> Array:
	var events := []
	for u: CombatUnit in units:
		if u.team != team or not u.alive():
			continue
		var n := 0
		for o: CombatUnit in units:
			if o.team != team and o.alive() and o.has_trait(TRAIT_STRUCTURE) and dist(o.cell, u.cell) == 1:
				n += 1
		n = mini(n, int(num("pillar_cold_max")))
		if n > 0:
			var d := mini(n * int(num("pillar_cold")), u.hp)
			u.hp -= d
			events.append({"type": "bleed", "unit": u, "amount": d, "status": "cold"})
	return events


## Every marked tile -> [{"src", "ability", "left"}], the boss warnings standing now.
static func marks(units: Array) -> Dictionary:
	var out := {}
	for u: CombatUnit in units:
		if not u.alive() or u.mark.is_empty():
			continue
		for c: Vector2i in u.mark.cells:
			if not out.has(c):
				out[c] = []
			out[c].append({"src": u, "ability": u.mark.ability, "left": int(u.mark.left)})
	return out


# --- clutch tools ([USER] 2026-10-30 design-clutch-tools-2: CARRY for the dog, COMMAND for the sword job) ------

## Where CARRY can take a friend: cells the carrier reaches in `power` (3) steps with a free cell next to them to
## set the friend down. dest -> the set-down cell (the one fewest foes could hit next phase, nearest first).
static func carry_spots(grid: CombatGrid, u: CombatUnit, friend: CombatUnit, a: Ability, units: Array, threat = null) -> Dictionary:
	var out := {}
	var others := units.filter(func(o: CombatUnit) -> bool: return o != friend)  # the friend comes along
	var standing := others.filter(func(o: CombatUnit) -> bool: return o != u)  # and the carrier's own cell comes free
	if threat == null:
		threat = EnemyAi.hit_reach(grid, u, units)
	var reach: Dictionary = reachable(grid, u, others, a.power).cost
	for dest: Vector2i in reach:
		var best := NONE_SPOT
		for d in DIRS:
			for n in grid.places_next(dest, d):
				if n == dest or not grid.passable(n) or occupant(standing, n) != null or not grid.can_step(dest, n, u.jump + 1):
					continue
				if best == NONE_SPOT or (threat.has(best) and not threat.has(n)):
					best = n
		if best != NONE_SPOT:
			out[dest] = best
	return out


const NONE_SPOT := Vector2i(-999, -999)


## The carrier walks to dest (a free hit from any guard it leaves goes to it), and the friend comes along, set down
## next to it at `spot`. A downed friend stays downed, its bleed still counting; a friend who hasn't acted still can.
static func carry(rng: RandomNumberGenerator, grid: CombatGrid, u: CombatUnit, friend: CombatUnit, dest: Vector2i, spot: Vector2i, units: Array) -> Array:
	var events := leave_hits(rng, grid, u, units, dest)
	if not u.alive():
		return events
	var from := friend.cell
	u.place(dest, grid.height_at(dest))
	friend.place(spot, grid.height_at(spot))
	events.append({"type": "carry", "src": u, "unit": friend, "from": from, "to": spot})
	return events


## SHADOW SWAP: u and friend trade places, through foes and guard zones, with no free hits. Then the wait.
static func shadow_swap(grid: CombatGrid, u: CombatUnit, a: Ability, friend: CombatUnit) -> Array:
	u.ready_at[a.id] = u.phase_no + a.cooldown
	var at := u.cell
	u.place(friend.cell, grid.height_at(friend.cell))
	friend.place(at, grid.height_at(at))
	return [{"type": "swap", "src": u, "unit": friend, "to": friend.cell}]


## What the swap's move spending is: the whole move, less what the upgrade leaves to walk after it.
static func swap_spent(u: CombatUnit) -> int:
	return maxi(0, move_points(u) - upg(u, "swap_move"))


## OVERWATCH: the first cell on mover's path in reach of a foe on watch: {"watcher", "cell"}, or {} when none.
static func watch_stop(grid: CombatGrid, mover: CombatUnit, path: Array, units: Array) -> Dictionary:
	for i in range(1, path.size()):
		var c: Vector2i = path[i]
		for w: CombatUnit in units:
			if w.team != mover.team and w.alive() and w.has_status(STATUS_OVERWATCH) and in_reach(grid, w.cell, c, ability_range(w, null)):
				return {"watcher": w, "cell": c}
	return {}


## The watcher's readied shot: a plain hit on mover, no counter; the watch is spent.
static func watch_shot(rng: RandomNumberGenerator, grid: CombatGrid, w: CombatUnit, mover: CombatUnit, units: Array) -> Array:
	var left := (w.watch_left if w.watch_left > 0 else 1 + upg(w, "watch_stops")) - 1
	w.watch_left = left
	if left <= 0:
		w.statuses.erase(STATUS_OVERWATCH)  # an upgraded watch has a second shot for the next foe that walks in
	var events := [{"type": "overwatch", "src": w, "unit": mover}]
	w.watching_shot = true
	events.append_array(resolve(rng, grid, w, w.abilities[0], mover.cell, units, false))
	w.watching_shot = false
	return events


# --- fields: traps, caltrops, fire and smoke on the ground -----------------------------------------------

## Lays a's field on the tiles it covers (walkable ones, for a trap and caltrops). A field lasts its maker's side's
## phases: the skill's status_turns when that status is the field itself (TRAP, SMOKE BOMB), else `field_turns`.
static func lay_field(grid: CombatGrid, u: CombatUnit, a: Ability, center: Vector2i) -> Array:
	var turns := a.status_turns if a.status == a.field else int(num("field_turns"))
	var cells: Array[Vector2i] = []
	for c in area(grid, a, center, u.cell):
		if a.field == FIELD_SMOKE or grid.passable(c):
			cells.append(c)
	for c in cells:
		var list: Array = grid.fields.get(c, []).filter(func(f: Dictionary) -> bool: return f.kind != a.field)
		list.append({"kind": a.field, "team": u.team, "turns": maxi(1, turns), "src": u, "ability": a})
		grid.fields[c] = list
	return [{"type": "field", "src": u, "field": a.field, "cells": cells}]


## The start of `team`'s phase: its fields lose a phase, and go at 0.
static func tick_fields(grid: CombatGrid, team: int) -> void:
	for c: Vector2i in grid.fields.keys():
		var keep := []
		for f: Dictionary in grid.fields[c]:
			if f.team == team:
				f.turns = int(f.turns) - 1
			if int(f.turns) > 0:
				keep.append(f)
		if keep.is_empty():
			grid.fields.erase(c)
		else:
			grid.fields[c] = keep


## Where a walk along `path` stops early, and why: a foe on OVERWATCH sees it ({"watcher", "cell"}), or it walks
## onto a trap or caltrops of the other side ({"field", "cell"}), whichever comes first. {} when it walks it all.
static func walk_stop(grid: CombatGrid, mover: CombatUnit, path: Array, units: Array) -> Dictionary:
	var watch := watch_stop(grid, mover, path, units)
	for i in range(1, path.size()):
		var c: Vector2i = path[i]
		if not watch.is_empty() and watch.cell == c:
			return watch
		for f: Dictionary in grid.fields.get(c, []):
			if f.team != mover.team and (f.kind == FIELD_TRAP or f.kind == FIELD_CALTROPS):
				return {"field": f, "cell": c}
	return watch


## What happens where a walk stopped (walk_stop): the watcher's shot, or the trap or caltrops going off on mover.
static func stop_events(rng: RandomNumberGenerator, grid: CombatGrid, stop: Dictionary, mover: CombatUnit, units: Array) -> Array:
	if stop.has("watcher"):
		return watch_shot(rng, grid, stop.watcher, mover, units)
	return spring(grid, stop.field, stop.cell, mover, units)


## A trap or caltrops on c goes off on mover: the maker's damage with the skill's power, less armor. A trap is spent;
## caltrops stay and slow it as well.
static func spring(grid: CombatGrid, f: Dictionary, c: Vector2i, mover: CombatUnit, units: Array) -> Array:
	var src: CombatUnit = f.src
	var a: Ability = f.ability
	var events := [{"type": "spring", "src": src, "unit": mover, "field": f.kind}]
	var dmg := damage(grid, src, mover, c, a, units)
	mover.hp = maxi(0, mover.hp - dmg)
	mover.statuses.erase(STATUS_SLEEP)
	events.append({"type": "hit", "src": src, "unit": mover, "amount": dmg, "crit": false, "big": true})
	if f.kind == FIELD_TRAP:
		var list: Array = grid.fields.get(c, [])
		list.erase(f)
		if list.is_empty():
			grid.fields.erase(c)
	elif mover.alive() and a.status != "":
		mover.statuses[a.status] = a.status_turns
		events.append({"type": "status", "src": src, "unit": mover, "status": a.status})
	return events


## What a buff does on top of its status: RALLY walks the friend again, INSPIRE and LAST STAND set their numbers.
static func _buff(u: CombatUnit, a: Ability, t: CombatUnit) -> Array:
	match a.status:
		STATUS_RALLIED:
			t.moved = false
			t.move_spent = 0
			t.move_origin = t.cell
			t.rally_move = int(num("rally_move")) + upg(u, "rally_move")
			t.rally_dmg = upg(u, "rally_damage")
		STATUS_INSPIRED:
			t.inspire_dmg = int(num("inspire_damage")) + upg(u, "inspire_damage")
		STATUS_LAST_STAND:
			t.stand_extra = a.status_turns
			t.statuses[a.status] = a.status_turns + 1  # through the foes' phase, when the falling happens
			if t.downed():
				t.bleed += a.status_turns
	return []


## COMMAND: u gives up its action and friend takes a fresh phase at once (move and action), even after acting.
## CALL COMPANION is the same for the party's beast (a class tagged `companion`), and costs charges.
static func command(u: CombatUnit, a: Ability, friend: CombatUnit) -> Array:
	u.ready_at[a.id] = u.phase_no + a.cooldown
	if a.res_cost > 0:
		u.res = maxi(0, u.res - a.res_cost)
	friend.moved = false
	friend.acted = false
	friend.move_spent = 0
	friend.move_origin = friend.cell
	friend.cmd_bonus = upg(u, "companion_bonus" if a.status == "companion" else "command_bonus")  # until the end of that phase
	return [{"type": "command", "src": u, "unit": friend}]


## Can COMMAND (or CALL COMPANION) give `o` a fresh turn? Any standing friend; CALL COMPANION only the beast, in reach.
static func commandable(u: CombatUnit, a: Ability, o: CombatUnit, from: Vector2i) -> bool:
	if o == u or o.team != u.team or not o.alive():
		return false
	if a.status != "companion":
		return true
	return o.tags.has(&"companion") and dist(from, o.cell) <= a.range_max  # the party's beast: Doggo's class is tagged


# --- helping strikes ([USER] c12, c15, c19, combat build step 4) ------------------------------------------

## The teammate who helps att's hit on tgt from `from`: both stand next to the foe (diagonal neighbours of
## each other, or anywhere round it while teamup_opposite is on). Awake and standing. null if nobody.
static func helper(att: CombatUnit, tgt: CombatUnit, units: Array, from: Vector2i) -> CombatUnit:
	if dist(from, tgt.cell) != 1 or tgt.team == att.team:
		return null
	var any_side := num("teamup_opposite") != 0.0
	for o: CombatUnit in units:
		if o == att or not o.alive() or o.team != att.team or o.has_status(STATUS_SLEEP):
			continue
		if dist(o.cell, tgt.cell) != 1 or o.cell == from:
			continue
		var side := CombatGrid.ground(o.cell) - CombatGrid.ground(from)
		if any_side or maxi(absi(side.x), absi(side.y)) == 1:
			return o
	return null


## What h's help adds to att's strike: `help_damage`, plus their bond's team-up bonus (BondRules, data/bonds.csv).
static func help_damage(att: CombatUnit, h: CombatUnit) -> int:
	return int(num("help_damage")) + int(att.bonds.get(String(h.figure), 0)) * int(Db.bonds.get("teamup_per_level", 1))


# --- bleeding out ([USER] c6 and c11, combat build step 3) ---------------------------------------------

## The HP AID brings a downed piece back with: `aid_hp` when that's set above 0, else `aid_pct` of its max (a
## quarter), at least 1.
static func aid_hp(t: CombatUnit) -> int:
	var flat := int(Db.combat.get("aid_hp", "0"))  # a set number of HP, whoever is helped up (game designer, design-boss-mix-2)
	if flat > 0:
		return mini(flat, t.max_hp)
	return maxi(1, ceili(t.max_hp * num("aid_pct") / 100.0))


## AID for the party, a knock-out for foes: the actions every piece has on top of its own skills.
static func extra_actions(u: CombatUnit) -> Array[Ability]:
	var out: Array[Ability] = []
	var a := Db.ability("aid" if u.team == 0 else "knock_out")
	if a != null:
		out.append(a)
	return out


# --- guard zones ([USER] c13, combat build step 2) ------------------------------------------------------

## Guarding foes next to the cell u began its phase on, awake and able to hit it there. They hold u: while u
## stays next to one it can only attack the guard; walking away costs a free hit from each.
static func holders(grid: CombatGrid, u: CombatUnit, units: Array) -> Array[CombatUnit]:
	var out: Array[CombatUnit] = []
	for g: CombatUnit in units:
		if g.alive() and g.team != u.team and g.has_status(STATUS_GUARD) and not g.has_status(STATUS_SLEEP) \
				and dist(g.cell, u.move_origin) == 1 and in_reach(grid, g.cell, u.move_origin, ability_range(g, null)):
			out.append(g)
	return out


## The holders u would still stand next to at `from`.
static func held_at(grid: CombatGrid, u: CombatUnit, units: Array, from: Vector2i) -> Array[CombatUnit]:
	var out: Array[CombatUnit] = []
	for g in holders(grid, u, units):
		if dist(g.cell, from) == 1:
			out.append(g)
	return out


## The holders u would walk away from by ending its move on `dest`.
static func left_at(grid: CombatGrid, u: CombatUnit, units: Array, dest: Vector2i) -> Array[CombatUnit]:
	var out: Array[CombatUnit] = []
	for g in holders(grid, u, units):
		if dist(g.cell, dest) > 1:
			out.append(g)
	return out


## Each guard u walks away from by moving to `dest` gets one free basic hit as u leaves (no counter).
## Resolve before u moves; if it goes down it stays put.
static func leave_hits(rng: RandomNumberGenerator, grid: CombatGrid, u: CombatUnit, units: Array, dest: Vector2i) -> Array:
	var events := []
	for g in left_at(grid, u, units, dest):
		if not u.alive():
			break
		u.left_guard = true
		events.append({"type": "free_hit", "src": g, "unit": u})
		g.free_hitting = true
		events.append_array(_swing(rng, grid, g, g.abilities[0], u, units))
		g.free_hitting = false
	return events


## Cells next to every guarding piece of `team`: the zone the board rings.
static func guard_ring(grid: CombatGrid, units: Array, team: int) -> Dictionary:
	var out := {}
	for g: CombatUnit in units:
		if g.alive() and g.team == team and g.has_status(STATUS_GUARD) and not g.has_status(STATUS_SLEEP):
			for d in DIRS:
				for n in grid.places_next(g.cell, d):
					if grid.in_bounds(n) and grid.passable(n) and in_reach(grid, g.cell, n, ability_range(g, null)):
						out[n] = true
	return out


## Every cell a team could hit next phase (Fire Emblem's danger zone).
static func danger_zone(grid: CombatGrid, units: Array, team: int) -> Dictionary:
	var zone := {}
	for u: CombatUnit in units:
		if u.team != team or not u.alive() or u.has_status(STATUS_SLEEP) or u.hiding or u.has_trait(TRAIT_STRUCTURE):
			continue
		var froms: Array = CombatRules.reachable(grid, u, units).cost.keys()
		var ranges: Array[Vector2i] = []
		for a in u.abilities:
			if a.hostile() and u.can_use(a) and not a.boss_move():  # a big move shows as its marked tiles instead
				var r := ability_range(u, a)
				if a.target == "cell":
					r.y += a.radius
				if not ranges.has(r):
					ranges.append(r)
		for f: Vector2i in froms:
			for y in grid.h:
				for x in grid.w:
					for c in grid.places_at(Vector2i(x, y)):
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


## A piece of `mover`'s side ended a move: hidden foes within SPOT_RANGE it can see come out. Returns them.
static func spot(grid: CombatGrid, units: Array, mover: CombatUnit) -> Array[CombatUnit]:
	var out: Array[CombatUnit] = []
	for o: CombatUnit in units:
		if o.hiding and o.alive() and o.team != mover.team and dist(o.cell, mover.cell) <= SPOT_RANGE \
				and grid.line_of_sight(mover.cell, o.cell):
			o.hiding = false
			out.append(o)
	return out


static func team_alive(units: Array, team: int) -> bool:
	for o: CombatUnit in units:
		if o.team == team and o.alive() and not o.has_trait(TRAIT_STRUCTURE):
			return true
	return false

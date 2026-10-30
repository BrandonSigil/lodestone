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
const STATUS_BLEED := "bleed"  ## loses a little HP at the start of each of its phases (a ranked bite)
const STATUS_POISON := "poison"  ## the same, from the rogue's blades: `poison_damage` for `poison_turns` phases
## Cleared when the owner's next phase starts (they protect through the enemy phase).
const STATUS_UNTIL_OWN_PHASE := [STATUS_GUARD, STATUS_VEIL, STATUS_GUIDED, STATUS_TAUNT]

## Combat traits (one per roster character, a few for enemy classes). Ids live in the .tres traits arrays.
const TRAIT_SHIELD_WALL := &"shield_wall"  ## Lead: allies standing next to them get more armor
const TRAIT_STARLIT := &"starlit"  ## Stardrop: spells get +1 damage when cast from height 2 or more
const TRAIT_STEADY_AIM := &"steady_aim"  ## Hunter: more crit chance when attacking without having moved this turn
const TRAIT_SCHOLAR := &"scholar"  ## Wizard: spells deal +1 damage and heal +1
const TRAIT_DEEP_ROOTS := &"deep_roots"  ## Bushberry: can't be pushed, regrows 1 HP at the start of its phase
const TRAIT_BONES := &"bones"  ## Skeleton: makes the piece undead (arrows -2, fire +2: data/tags.csv)
const TRAIT_DOUBLE_STRIKE := &"double_strike"  ## Lewith & Flark: the basic hit swings twice at -1 damage each
const TRAIT_PACK := &"pack"  ## Wolf: +1 damage on a flanked target
const TRAIT_POISON_BLADES := &"poison_blades"  ## Rogue: every hit leaves POISON ([USER] design-boss-daggers)
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
	return maxi(1, u.move + (SPOOKED_MOVE if u.spooked else 0) + (int(num("slow_move")) if u.has_status(STATUS_SLOW) else 0))


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
static func reachable(grid: CombatGrid, u: CombatUnit, units: Array) -> Dictionary:
	var cost := {u.cell: 0}
	var prev := {}
	var open: Array[Vector2i] = [u.cell]
	var budget := move_left(u)
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


static func can_attack(grid: CombatGrid, att: CombatUnit, tgt: CombatUnit, from: Vector2i) -> bool:
	if not tgt.alive() or tgt.team == att.team:
		return false
	return in_reach(grid, from, tgt.cell, ability_range(att, null))


## Can this unit use this ability right now (enough mana, rage or charges)? An item also has to be on the unit's own belt
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
		"cell":
			for y in grid.h:
				for x in grid.w:
					for c in grid.places_at(Vector2i(x, y)):
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
static func area(grid: CombatGrid, a: Ability, center: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var mid := CombatGrid.ground(center)
	for y in range(mid.y - a.radius, mid.y + a.radius + 1):
		for x in range(mid.x - a.radius, mid.x + a.radius + 1):
			var c := Vector2i(x, y)
			if grid.in_bounds(c) and dist(c, mid) <= a.radius:
				out.append(CombatGrid.deck_of(c) if CombatGrid.on_deck(center) and grid.has_deck(c) else c)
	return out


## Units an ability affects when aimed at `center`. `user` stands in for whoever is at `from` while previewing a move.
static func affected_units(grid: CombatGrid, user: CombatUnit, a: Ability, center: Vector2i, units: Array, from: Vector2i) -> Array[CombatUnit]:
	var out: Array[CombatUnit] = []
	for c in area(grid, a, center):
		var o: CombatUnit = user if c == from else (occupant(units, c) if a.target == "downed" else unit_at(units, c))
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
	if att.spooked:
		parts.append(["MOD_SPOOKED", int(num("spooked_damage"))])
	return parts


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
		parts.append(["MOD_GUARD", int(num("guard_armor"))])
	if tgt.has_status(STATUS_VEIL):
		parts.append(["MOD_VEIL", int(num("veil_armor"))])
	if shielded(tgt, units):
		parts.append(["MOD_SHIELD", int(num("shield_wall_armor"))])
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
	return parts


static func crit_chance(grid: CombatGrid, att: CombatUnit, tgt: CombatUnit, units: Array, from: Vector2i, a: Ability = null) -> float:
	return clampf(_sum(crit_parts(grid, att, tgt, units, from, a)) / 100.0, 0.0, 1.0)


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
## Spells heal more as the caster's magic grows ([USER] pc-8: skills grow with the character on their own).
static func heal_amount(u: CombatUnit, a: Ability) -> int:
	return a.power + (1 if a.is_spell() and u.has_trait(TRAIT_SCHOLAR) else 0) + (u.magic_power if a.is_spell() else 0)


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
	if not counters or not tgt.alive() or tgt.team == att.team or tgt.has_status(STATUS_SLEEP):
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
				var before := t.hp
				t.hp = mini(t.max_hp, t.hp + heal_amount(u, a))
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
					events.append({"type": "status", "src": u, "unit": t, "status": a.status})
	if u.hiding and a.hostile():
		u.hiding = false
	if allow_counter and a.kind == "attack" and a.radius == 0 and hit_list.size() == 1:
		var t: CombatUnit = hit_list[0]
		if u.alive() and counters_from(grid, u, t, u.cell):
			events.append({"type": "counter", "src": t, "unit": u})
			events.append_array(resolve(rng, grid, t, t.abilities[0], u.cell, units, false))
	return events


## One blow of an attack or hex against one target. It always lands; an attack's damage wobbles and may crit.
static func _swing(rng: RandomNumberGenerator, grid: CombatGrid, u: CombatUnit, a: Ability, t: CombatUnit, units: Array) -> Array:
	var events := []
	if a.kind == "attack":
		var w := int(num("wobble"))
		var crit := rng.randf() < crit_chance(grid, u, t, units, u.cell, a)
		var dmg := damage(grid, u, t, u.cell, a, units, rng.randi_range(-w, w)) * (int(num("crit_mult")) if crit else 1)
		t.hp = maxi(0, t.hp - dmg)
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
		events.append({"type": "status", "src": u, "unit": t, "status": a.status, "struck": a.kind == "hex"})
	if t.alive() and a.bleed > 0:
		t.statuses[STATUS_BLEED] = a.bleed
		events.append({"type": "status", "src": u, "unit": t, "status": STATUS_BLEED})
	if t.alive() and a.kind == "attack" and u.has_trait(TRAIT_POISON_BLADES):  # renews, doesn't stack
		t.statuses[STATUS_POISON] = int(num("poison_turns"))
		events.append({"type": "status", "src": u, "unit": t, "status": STATUS_POISON})
	if t.alive() and a.push > 0:
		events.append_array(push(grid, units, u.cell, t, a.push))
	return events


## Shoves `t` away from `from` up to n tiles. Blocked: bump damage. Dropping 2+ levels: fall damage.
static func push(grid: CombatGrid, units: Array, from: Vector2i, t: CombatUnit, n: int) -> Array:
	var events := []
	if t.has_trait(TRAIT_DEEP_ROOTS):
		return events
	var delta := CombatGrid.ground(t.cell) - CombatGrid.ground(from)
	var dir := Vector2i(signi(delta.x), 0) if absi(delta.x) >= absi(delta.y) else Vector2i(0, signi(delta.y))
	if dir == Vector2i.ZERO:
		return events
	var path: Array[Vector2i] = [t.cell]
	for i in n:
		var dest := push_place(grid, t.cell, CombatGrid.ground(t.cell) + dir)
		var blocked := not grid.passable(dest) or occupant(units, dest) != null
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


## Where a piece shoved from place `at` into cell c lands: on the highest floor there it isn't shoved up into
## (a deck it slides onto level), else the ground below: off the side of a bridge it falls.
static func push_place(grid: CombatGrid, at: Vector2i, c: Vector2i) -> Vector2i:
	var best := c
	for p in grid.places_at(c):
		if grid.passable(p) and grid.height_at(p) <= grid.height_at(at) + 1 and grid.height_at(p) > grid.height_at(best):
			best = p
	return best


static func guard(u: CombatUnit) -> void:
	u.statuses[STATUS_GUARD] = 1


## Start of a team's phase: fresh actions, mana and charges come back, guard and veil end, sleepers lose the turn.
## Returns heal events for traits that regrow, so the board can show them.
static func begin_phase(units: Array, team: int) -> Array:
	var events := []
	for side in [0, 1]:  # a side with nobody seen left standing: its hidden pieces come out, or the fight never ends
		if not units.any(func(o: CombatUnit) -> bool: return o.team == side and o.alive() and not o.hiding):
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
		if u.alive():
			u.phase_no += 1
		for s: String in [STATUS_BLEED, STATUS_POISON]:  # through armor
			if u.alive() and u.has_status(s):
				var n := mini(int(num(s + "_damage")), u.hp)
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


## End of a team's phase: timed statuses like rooted tick down.
static func end_phase(units: Array, team: int) -> void:
	for u: CombatUnit in units:
		if u.team != team:
			continue
		u.move_spent = 0  # out of its own phase a piece's reach is its whole move (the other side's threat maps)
		for s in u.statuses.keys():
			if s in STATUS_UNTIL_OWN_PHASE:
				continue
			u.statuses[s] = int(u.statuses[s]) - 1
			if u.statuses[s] <= 0:
				u.statuses.erase(s)


# --- a boss's big moves ([USER] 2026-10-30 design-boss-warning, design-boss-shape) ---------------------------

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
	if not u.summon_cells.is_empty():
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
		events.append_array(_swing(rng, grid, g, g.abilities[0], u, units))
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
		if u.team != team or not u.alive() or u.has_status(STATUS_SLEEP) or u.hiding:
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
		if o.team == team and o.alive():
			return true
	return false

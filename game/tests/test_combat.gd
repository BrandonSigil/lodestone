extends TestCase


func _unit(cls_id: String, team: int, c: Vector2i, grid: CombatGrid) -> CombatUnit:
	var u := CombatUnit.enemy(load("res://data/classes/%s.tres" % cls_id))
	u.team = team
	u.place(c, grid.height_at(c))
	return u


func test_height_levels_clamp() -> void:
	var g := CombatGrid.flat(5, 5)
	g.set_height(Vector2i(0, 0), 3)
	eq(CombatRules.height_levels(g, Vector2i(0, 0), Vector2i(1, 0)), 2)
	eq(CombatRules.height_levels(g, Vector2i(1, 0), Vector2i(0, 0)), -2)


## [USER] 2026-10-29: high ground adds damage, +1 a level up to +2; low ground takes it off the same way.
func test_high_ground_adds_damage() -> void:
	var g := CombatGrid.flat(5, 5)
	var a := _unit("knight", 0, Vector2i(1, 1), g)
	var b := _unit("bandit", 1, Vector2i(2, 1), g)
	var flat_d := CombatRules.damage(g, a, b, a.cell)
	g.set_height(Vector2i(1, 1), 1)
	eq(CombatRules.damage(g, a, b, a.cell), flat_d + 1)
	g.set_height(Vector2i(1, 1), 2)
	eq(CombatRules.damage(g, a, b, a.cell), flat_d + 2, "two levels up: +2")
	g.set_height(Vector2i(1, 1), 3)
	eq(CombatRules.damage(g, a, b, a.cell), flat_d + 2, "no more than +2")
	g.set_height(Vector2i(1, 1), 2)
	var flat_up := CombatRules.damage(CombatGrid.flat(5, 5), b, a, b.cell)
	eq(CombatRules.damage(g, b, a, b.cell), maxi(1, flat_up - 2), "and -2 from below, never under 1")


## [USER] 2026-10-29: hits always land; damage wobbles a point either way, armor comes off, at least 1;
## about 1 hit in 10 is a crit for double.
func test_hits_always_land_wobble_and_crit() -> void:
	var g := CombatGrid.flat(3, 1)
	var k := _unit("knight", 0, Vector2i(0, 0), g)
	var b := _unit("bandit", 1, Vector2i(1, 0), g)
	var r := CombatRules.damage_range(g, k, b, k.cell)
	eq(r, Vector2i(CombatRules.damage(g, k, b, k.cell) - 1, CombatRules.damage(g, k, b, k.cell) + 1), "a point either way")
	eq(CombatRules.damage(g, k, b, k.cell), k.damage - b.armor, "armor comes off")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var crits := 0
	var seen := {}
	for i in 400:
		b.hp = b.max_hp
		var ev: Dictionary = CombatRules.resolve(rng, g, k, k.abilities[0], b.cell, [k, b], false)[0]
		eq(ev.type, "hit")
		var plain: int = ev.amount / (2 if ev.crit else 1)
		ok(plain >= r.x and plain <= r.y, "inside the range")
		seen[plain] = true
		crits += 1 if ev.crit else 0
	eq(seen.size(), 3, "all three wobbles happen")
	ok(crits > 20 and crits < 70, "about 10%% crits (%d of 400)" % crits)
	var wolf := _unit("wolf", 1, Vector2i(1, 0), g)
	var mage := _unit("mage", 0, Vector2i(0, 0), g)
	mage.damage = 1
	wolf.armor = 3
	eq(CombatRules.damage_range(g, mage, wolf, mage.cell), Vector2i(1, 1), "never under 1")


func test_melee_cant_reach_cliff() -> void:
	var g := CombatGrid.flat(5, 5)
	var a := _unit("knight", 0, Vector2i(1, 1), g)
	var b := _unit("bandit", 1, Vector2i(2, 1), g)
	g.set_height(Vector2i(2, 1), 3)
	ok(not CombatRules.can_attack(g, a, b, a.cell))



## A probe fight (2026-10-29): a bandit on a stair 3 levels below the party's ledge held the only way down,
## and neither side could swing at the other. Melee reaches over any step a piece could walk.
func test_melee_reaches_over_a_stair() -> void:
	var g := CombatGrid.flat(5, 5)
	var a := _unit("knight", 0, Vector2i(1, 1), g)
	var b := _unit("bandit", 1, Vector2i(2, 1), g)
	g.set_height(Vector2i(1, 1), 3)
	ok(not CombatRules.can_attack(g, a, b, a.cell), "a 3-level cliff: no swing")
	g.set_terrain(Vector2i(2, 1), CombatGrid.T.STAIRS)
	ok(CombatRules.can_attack(g, a, b, a.cell), "the same drop as a stair: down the stair")
	ok(CombatRules.can_attack(g, b, a, b.cell), "and up it")
	g.set_height(Vector2i(1, 1), 4)
	ok(not CombatRules.can_attack(g, a, b, a.cell), "a stair can't be climbed past its reach either")


func test_bow_range_grows_with_height() -> void:
	var g := CombatGrid.flat(8, 3)
	var a := _unit("hunter", 0, Vector2i(0, 1), g)
	var b := _unit("bandit", 1, Vector2i(6, 1), g)
	ok(not CombatRules.can_attack(g, a, b, a.cell), "6 tiles is out of range on flat ground (a bow reaches 5)")
	g.set_height(Vector2i(0, 1), 1)
	ok(CombatRules.can_attack(g, a, b, a.cell), "+1 range from 1 level up")


func test_bow_min_range() -> void:
	var g := CombatGrid.flat(5, 5)
	var a := _unit("hunter", 0, Vector2i(1, 1), g)
	var b := _unit("bandit", 1, Vector2i(2, 1), g)
	ok(not CombatRules.can_attack(g, a, b, a.cell))


## [USER] c14: brush, low walls and forest take 1 off ranged hits; melee ignores it.
func test_half_cover_against_ranged() -> void:
	var g := CombatGrid.flat(6, 5)
	var knight := _unit("knight", 0, Vector2i(1, 1), g)
	var hunter := _unit("hunter", 0, Vector2i(0, 3), g)
	var b := _unit("bandit", 1, Vector2i(2, 1), g)
	var melee := CombatRules.damage(g, knight, b, knight.cell)
	var shot := CombatRules.damage(g, hunter, b, hunter.cell)
	g.terrain[g.idx(b.cell)] = CombatGrid.T.FOREST
	eq(CombatRules.damage(g, knight, b, knight.cell), melee, "melee ignores cover")
	eq(CombatRules.damage(g, hunter, b, hunter.cell), maxi(1, shot - 1), "a shot loses 1")


## [USER] 2026-10-29: flanking adds crit chance (an ally already next to the target).
func test_flank_adds_crit() -> void:
	var g := CombatGrid.flat(5, 5)
	var a := _unit("knight", 0, Vector2i(1, 2), g)
	var b := _unit("bandit", 1, Vector2i(2, 2), g)
	var base := CombatRules.crit_chance(g, a, b, [a, b], a.cell)
	eq(base, CombatRules.num("crit_base") / 100.0)
	var c := _unit("knight", 0, Vector2i(3, 2), g)
	ok(absf(CombatRules.crit_chance(g, a, b, [a, b, c], a.cell) - base - CombatRules.num("crit_flank") / 100.0) < 0.001)


func test_reach_respects_jump_cost_and_enemies() -> void:
	var g := CombatGrid.flat(6, 1)
	var u := _unit("knight", 0, Vector2i(0, 0), g)  # move 4, jump 1
	var cost: Dictionary = CombatRules.reachable(g, u, [u]).cost
	ok(cost.has(Vector2i(4, 0)) and not cost.has(Vector2i(5, 0)), "4 grass steps")
	g.terrain[g.idx(Vector2i(1, 0))] = CombatGrid.T.FOREST
	cost = CombatRules.reachable(g, u, [u]).cost
	ok(cost.has(Vector2i(3, 0)) and not cost.has(Vector2i(4, 0)), "forest costs 2")
	g.terrain[g.idx(Vector2i(1, 0))] = CombatGrid.T.GRASS
	g.set_height(Vector2i(2, 0), 2)
	cost = CombatRules.reachable(g, u, [u]).cost
	ok(not cost.has(Vector2i(2, 0)), "2-level step too high for jump 1")
	g.set_height(Vector2i(2, 0), 0)
	var e := _unit("bandit", 1, Vector2i(2, 0), g)
	cost = CombatRules.reachable(g, u, [u, e]).cost
	ok(not cost.has(Vector2i(3, 0)), "can't pass an enemy")


func test_pass_through_ally_not_stop() -> void:
	var g := CombatGrid.flat(4, 1)
	var u := _unit("knight", 0, Vector2i(0, 0), g)
	var ally := _unit("knight", 0, Vector2i(1, 0), g)
	var cost: Dictionary = CombatRules.reachable(g, u, [u, ally]).cost
	ok(not cost.has(Vector2i(1, 0)) and cost.has(Vector2i(2, 0)))


func test_generated_maps_connect() -> void:
	for s in 60:
		var g := CombatGrid.generate(s * 31 + 1, 10, 8, s / 60.0)
		ok(g.connected(1), "seed %d" % s)
		ok(g.deploy_cells(0).size() >= 4 and g.deploy_cells(1).size() >= 4, "deploy room seed %d" % s)


func test_skittish() -> void:
	var g := CombatGrid.flat(6, 6)
	var stardrop: CharacterDef = load("res://data/characters/stardrop.tres")
	var u := CombatUnit.from_member({"def": stardrop, "hp": 8})
	u.place(Vector2i(0, 0), 0)
	var far := _unit("bandit", 1, Vector2i(5, 5), g)
	var rng := RandomNumberGenerator.new()
	ok(CombatRules.skittish_check(rng, u, [u, far]).is_empty(), "no roll when nobody is near")
	far.place(Vector2i(1, 1), 0)
	var spooked := 0
	for i in 400:
		CombatRules.skittish_check(rng, u, [u, far])
		if u.spooked:
			spooked += 1
	ok(spooked > 100 and spooked < 350, "spooks sometimes (%d/400)" % spooked)
	u.spooked = true
	eq(CombatRules.move_points(u), stardrop.class_def.move + CombatRules.SPOOKED_MOVE)


## AI plays both sides; every fight must end.
func test_ai_vs_ai_terminates() -> void:
	for s in 15:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var g := CombatGrid.generate(s, 10, 8, 0.0)
		var units: Array = []
		var spots := g.deploy_cells(0)
		for id in ["knight", "mage", "hunter"]:
			units.append(_unit(id, 0, spots.pop_front(), g))
		var es := g.deploy_cells(1)
		for id in ["bandit", "bandit", "bandit_archer"]:
			units.append(_unit(id, 1, es.pop_front(), g))
		var rounds := 0
		while CombatRules.team_alive(units, 0) and CombatRules.team_alive(units, 1) and rounds < 60:
			for team in [0, 1]:
				CombatRules.begin_phase(units, team)
				for u: CombatUnit in units:
					if u.team != team or not u.alive():
						continue
					CombatSim.take_turn(rng, g, u, units)
			rounds += 1
		ok(rounds < 60, "seed %d ended in %d rounds" % [s, rounds])


# --- skills, items, counters, pushes (sandbox build) ------------------------------------

func _ab(id: String) -> Ability:
	return Db.ability(id)


func test_counter_melee_only() -> void:
	CombatRules.reset_switches()
	var g := CombatGrid.flat(6, 3)
	var k := _unit("knight", 0, Vector2i(1, 1), g)
	var b := _unit("bandit", 1, Vector2i(2, 1), g)
	ok(CombatRules.counters_from(g, k, b, k.cell), "bandit hits back at an adjacent knight")
	var h := _unit("hunter", 0, Vector2i(0, 1), g)
	ok(not CombatRules.counters_from(g, h, b, h.cell), "melee can't hit back at range 2")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var events := CombatRules.resolve(rng, g, k, k.abilities[0], b.cell, [k, b])
	if b.alive():
		ok(events.any(func(e: Dictionary) -> bool: return e.type == "counter"), "counter event")
	CombatRules.counters = false
	ok(not CombatRules.counters_from(g, k, b, k.cell), "switch turns counters off")
	CombatRules.reset_switches()


func test_guard_and_phase_clear() -> void:
	var g := CombatGrid.flat(4, 1)
	var k := _unit("knight", 0, Vector2i(0, 0), g)
	var b := _unit("bandit", 1, Vector2i(1, 0), g)
	var hit := CombatRules.damage(g, b, k, b.cell, null, [], 3)
	CombatRules.guard(k)
	eq(CombatRules.damage(g, b, k, b.cell, null, [], 3), maxi(1, hit - int(CombatRules.num("guard_armor"))), "GUARD adds armor")
	CombatRules.begin_phase([k, b], 1)
	ok(k.has_status("guard"), "guard lasts through the enemy phase")
	CombatRules.begin_phase([k, b], 0)
	ok(not k.has_status("guard"), "guard ends at own next phase")


## [USER] c9, c16 (combat build step 5): skills cost the job's resource; no cooldowns.
func test_rage_builds_on_hits() -> void:
	var g := CombatGrid.flat(4, 1)
	var k := _unit("knight", 0, Vector2i(0, 0), g)
	var b := _unit("bandit", 1, Vector2i(1, 0), g)
	b.max_hp = 99
	b.hp = 99
	var shove := _ab("shove")
	eq(k.res_kind, "rage")
	eq(k.res, 0, "rage starts empty")
	ok(not k.can_use(shove), "no rage, no shove")
	CombatRules.counters = false
	CombatRules.resolve(RandomNumberGenerator.new(), g, k, k.abilities[0], b.cell, [k, b])
	CombatRules.resolve(RandomNumberGenerator.new(), g, b, b.abilities[0], k.cell, [k, b])
	CombatRules.reset_switches()
	eq(k.res, 2, "one hit dealt, one taken")
	ok(k.can_use(shove))
	CombatRules.resolve(RandomNumberGenerator.new(), g, k, shove, b.cell, [k, b])
	eq(k.res, 1, "shove spends 2, its own hit gives 1 back")


func test_mana_starts_full_and_comes_back() -> void:
	var g := CombatGrid.flat(6, 3)
	var s := CombatUnit.from_def(Db.character(&"stardrop"), {}, ["moonbeam"])
	s.place(Vector2i(0, 1), 0)
	var b := _unit("bandit", 1, Vector2i(3, 1), g)
	eq(s.res_kind, "mana")
	eq(s.res, s.res_max, "mana starts full")
	var beam := _ab("moonbeam")
	CombatRules.resolve(RandomNumberGenerator.new(), g, s, beam, b.cell, [s, b])
	eq(s.res, s.res_max - beam.res_cost)
	CombatRules.begin_phase([s, b], 0)
	eq(s.res, s.res_max - beam.res_cost + ceili(s.res_max / 5.0), "a fifth back each phase")


func test_the_dogs_charges() -> void:
	var g := CombatGrid.flat(4, 1)
	var dog := _unit("dog", 0, Vector2i(0, 0), g)
	var b := _unit("bandit", 1, Vector2i(1, 0), g)
	b.max_hp = 99
	b.hp = 99
	eq(dog.res, 3, "three to spend")
	var bite := _ab("bite")
	for i in 3:
		CombatRules.resolve(RandomNumberGenerator.new(), g, dog, bite, b.cell, [dog, b], false)
	ok(not dog.can_use(bite), "spent")
	ok(b.has_status(CombatRules.STATUS_SLOW), "the bite slows")
	eq(CombatRules.move_points(b), maxi(1, b.move - 2))
	for i in 2:
		CombatRules.begin_phase([dog, b], 0)
	eq(dog.res, 0)
	CombatRules.begin_phase([dog, b], 0)
	eq(dog.res, 1, "one back every 3 phases")


func test_a_bark_pulls_the_foes() -> void:
	var g := CombatGrid.flat(6, 3)
	var dog := _unit("dog", 0, Vector2i(2, 1), g)
	var hunter := _unit("hunter", 0, Vector2i(3, 2), g)
	var b := _unit("bandit", 1, Vector2i(3, 1), g)  # next to both
	var units := [dog, hunter, b]
	eq(CombatRules.target_cells(g, b, b.abilities[0], units, b.cell).size(), 2)
	CombatRules.resolve(RandomNumberGenerator.new(), g, dog, _ab("bark"), dog.cell, units)
	eq(CombatRules.target_cells(g, b, b.abilities[0], units, b.cell), [dog.cell] as Array[Vector2i], "only the barking dog")
	CombatRules.begin_phase(units, 0)
	eq(CombatRules.target_cells(g, b, b.abilities[0], units, b.cell).size(), 2, "the taunt ends at the dog's next phase")


## Brandon's playtest (2026-11-01): BARK next to the elite wolf did nothing, because the wolf stepped to a tile out of
## the dog's reach and bit someone softer. A foe that can walk to the dog and hit him this phase must.
func test_a_bark_pulls_a_wolf_that_could_walk_away() -> void:
	var g := CombatGrid.flat(10, 5)
	var dog := _unit("dog", 0, Vector2i(2, 2), g)
	var mage := _unit("job_ember", 0, Vector2i(7, 2), g)
	mage.hp = 3  # a soft kill the wolf would much rather have
	var wolf := _unit("alpha_wolf", 1, Vector2i(4, 2), g)
	wolf.elite = true
	var units := [dog, mage, wolf]
	ok(EnemyAi.plan(g, wolf, units).target == mage, "with no bark the wolf goes for the soft mage")
	CombatRules.resolve(RandomNumberGenerator.new(), g, dog, _ab("bark"), dog.cell, units)
	eq(CombatRules.taunt_pulls(g, dog, units), [wolf] as Array[CombatUnit], "the wolf can reach the dog, so the bark pulls it")
	var p := EnemyAi.plan(g, wolf, units)
	ok(p.target == dog, "after the bark the elite wolf must attack the dog")
	ok(CombatRules.in_reach(g, p.move, dog.cell, CombatRules.ability_range(wolf, p.ability)), "from where it ends up")
	var far := _unit("alpha_wolf", 1, Vector2i(9, 0), g)
	far.move = 1
	units.append(far)
	ok(not CombatRules.taunt_pulls(g, dog, units).has(far), "a wolf that can't reach the dog this phase isn't pulled")


## [USER] 2026-11-01: Amber starts with one plain ranged fire attack (FIRE ZAP, her HIT), no spells; her passive
## A Heart that Burns may set the target burning.
func test_amber_starts_with_her_fire_zap() -> void:
	var g := CombatGrid.flat(6, 3)
	var amber := CombatUnit.from_def(Db.character(&"fire_mage"))
	amber.place(Vector2i(0, 1), 0)
	eq(amber.abilities.size(), 1, "one action: her plain attack")
	var zap: Ability = amber.abilities[0]
	eq(zap.id, "fire_zap")
	ok(zap.is_basic() and not zap.is_spell(), "it is her basic attack, not a spell")
	eq(zap.element, "fire")
	eq(zap.res_cost, 0, "free")
	eq(CombatRules.ability_range(amber, zap), Vector2i(2, 3), "ranged, 2 to 3 tiles")
	ok(amber.has_trait(CombatRules.TRAIT_HEART_BURNS))
	var b := _unit("bandit", 1, Vector2i(3, 1), g)
	b.max_hp = 99
	b.hp = 99
	var burned := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 200:
		b.statuses.erase(CombatRules.STATUS_BURN)
		CombatRules.resolve(rng, g, amber, zap, b.cell, [amber, b])
		b.hp = 99
		if b.has_status(CombatRules.STATUS_BURN):
			burned += 1
	var pct := int(CombatRules.num("heart_burn_pct"))
	ok(burned > pct and burned < pct * 3, "burns about %d%% of hits (%d of 200)" % [pct, burned])
	b.statuses[CombatRules.STATUS_BURN] = int(CombatRules.num("burn_turns"))
	var hp := b.hp
	CombatRules.begin_phase([amber, b], 1)
	eq(b.hp, hp - int(CombatRules.num("burn_damage")), "a burn hurts at the start of the foe's phase, through armor")
	CombatRules.end_phase([amber, b], 1)
	CombatRules.begin_phase([amber, b], 1)
	CombatRules.end_phase([amber, b], 1)
	ok(not b.has_status(CombatRules.STATUS_BURN), "and ends after burn_turns phases")


func test_every_skill_has_something_to_pay_with() -> void:
	for f in DirAccess.get_files_at("res://data/classes"):
		if not f.ends_with(".tres"):
			continue
		var c: ClassDef = load("res://data/classes/" + f)
		for id in c.abilities:
			var a := _ab(String(id))
			ok(a != null and (a.res_cost == 0 or c.resource != ""), "%s pays for %s" % [f, id])
	for d in [Db.character(&"stardrop"), Db.character(&"wizard")]:
		eq(d.class_def.resource, "mana", "casters spend mana")

func test_push_fall_and_bump() -> void:
	var g := CombatGrid.flat(5, 1)
	g.set_height(Vector2i(1, 0), 3)
	g.set_height(Vector2i(2, 0), 3)
	var k := _unit("knight", 0, Vector2i(1, 0), g)
	var b := _unit("bandit", 1, Vector2i(2, 0), g)
	var hp := b.hp
	var ev := CombatRules.push(g, [k, b], k.cell, b, 1)
	eq(b.cell, Vector2i(3, 0), "pushed one tile")
	eq(b.hp, hp - 2 * CombatRules.FALL_DAMAGE, "3 level drop hurts")
	ok(ev[0].type == "push")
	g.set_terrain(Vector2i(4, 0), CombatGrid.T.ROCK)
	hp = b.hp
	k.place(Vector2i(2, 0), 3)
	CombatRules.push(g, [k, b], k.cell, b, 1)
	eq(b.cell, Vector2i(3, 0), "rock stops the push")
	eq(b.hp, hp - CombatRules.BUMP_DAMAGE)


func test_rooted() -> void:
	var g := CombatGrid.flat(4, 1)
	var b := _unit("bandit", 1, Vector2i(0, 0), g)
	b.statuses["rooted"] = 1
	eq(CombatRules.move_points(b), 0)
	CombatRules.end_phase([b], 1)
	ok(CombatRules.move_points(b) > 0, "free after its phase")


func test_area_hits_everyone_in_it() -> void:
	var g := CombatGrid.flat(7, 5)
	var m := _unit("mage", 0, Vector2i(0, 2), g)
	var e1 := _unit("bandit", 1, Vector2i(3, 2), g)
	var e2 := _unit("bandit", 1, Vector2i(4, 2), g)
	var ally := _unit("knight", 0, Vector2i(3, 3), g)
	var hit := CombatRules.affected_units(g, m, _ab("moonbeam"), Vector2i(3, 2), [m, e1, e2, ally], m.cell)
	eq(hit.size(), 3, "two foes and the ally in the plus")
	ok(CombatRules.forecast(g, m, _ab("moonbeam"), Vector2i(3, 2), [m, e1, e2, ally], m.cell).counter.is_empty(), "no counter for area hits")


func test_heal_item_spends_from_the_belt() -> void:
	var g := CombatGrid.flat(3, 1)
	var k := _unit("knight", 0, Vector2i(0, 0), g)
	k.hp = 5
	var salve: Ability = Db.combat_items["salve"]
	ok(not CombatRules.usable(k, salve), "no belt, no salve")
	k.belt = InventoryGrid.create(2, 1)
	k.belt.put(salve.spends, [Vector2i.ZERO] as Array[Vector2i], 1, 3)
	ok(CombatRules.usable(k, salve))
	CombatRules.resolve(RandomNumberGenerator.new(), g, k, salve, k.cell, [k])
	eq(k.hp, 5 + salve.power)
	eq(k.belt.count(salve.spends), 0, "spent from the belt")
	ok(not CombatRules.usable(k, salve), "belt empty")
	k.hp = k.max_hp - 1
	k.belt.put(salve.spends, [Vector2i.ZERO] as Array[Vector2i], 1, 3)
	CombatRules.resolve(RandomNumberGenerator.new(), g, k, salve, k.cell, [k])
	eq(k.hp, k.max_hp, "heal caps at max")


func test_scaling_mods() -> void:
	var c: ClassDef = load("res://data/classes/bandit.tres")
	var u := CombatUnit.enemy(c, {"hp_pct": 150, "attack": 2, "defense": 1, "damage": 1, "move": -1})
	eq(u.max_hp, int(round(c.max_hp * 1.5)))
	eq(u.attack, c.attack + 2)
	eq(u.defense, c.defense + 1)
	eq(u.armor, c.armor + 1, "a defense bonus is armor now")
	eq(u.crit, c.crit + 2 * int(CombatRules.num("crit_per_attack")), "an attack bonus is crit chance now")
	eq(u.damage, c.damage + 1)
	eq(u.move, c.move - 1)


func test_danger_zone() -> void:
	var g := CombatGrid.flat(10, 1)
	var b := _unit("bandit", 1, Vector2i(9, 0), g)
	var zone := CombatRules.danger_zone(g, [b], 1)
	ok(zone.has(Vector2i(4, 0)), "move 4 + reach 1")
	ok(not zone.has(Vector2i(3, 0)))


func test_grid_round_trip() -> void:
	var g := CombatGrid.generate(5, 9, 7, 0.3)
	var back := CombatGrid.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	eq(back.w, 9)
	eq(back.heights, g.heights)
	eq(back.terrain, g.terrain)


## AI plays both sides with skills; every fight must end.
func test_sim_terminates_with_skills() -> void:
	for s in 10:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var g := CombatGrid.generate(s, 10, 8, 0.0)
		var units: Array = []
		var spots := g.deploy_cells(0)
		for id in ["knight", "mage", "hunter", "wizard"]:
			units.append(_unit(id, 0, spots.pop_front(), g))
		var es := g.deploy_cells(1)
		for id in ["bandit", "bandit", "bandit_archer", "wolf"]:
			units.append(_unit(id, 1, es.pop_front(), g))
		var r := CombatSim.fight(rng, g, units, {"medicine": 2})
		ok(r.winner != -1, "seed %d stalled" % s)


# --- terrain and height -----------------------------------------------------------------

func test_stairs_let_jump1_climb() -> void:
	var g := CombatGrid.flat(3, 1)
	g.set_height(Vector2i(1, 0), 3)
	ok(not g.can_step(Vector2i(0, 0), Vector2i(1, 0), 1), "3 levels too tall for jump 1")
	g.set_terrain(Vector2i(0, 0), CombatGrid.T.STAIRS)
	ok(g.can_step(Vector2i(0, 0), Vector2i(1, 0), 1), "stairs add 2")
	var u := _unit("knight", 0, Vector2i(0, 0), g)
	ok(CombatRules.reachable(g, u, [u]).cost.has(Vector2i(1, 0)))


func test_ruin_blocks_sight_and_bow() -> void:
	var g := CombatGrid.flat(6, 1)
	var h := _unit("hunter", 0, Vector2i(0, 0), g)
	var b := _unit("bandit", 1, Vector2i(4, 0), g)
	ok(CombatRules.can_attack(g, h, b, h.cell), "clear shot")
	g.set_terrain(Vector2i(2, 0), CombatGrid.T.RUIN)
	ok(not g.line_of_sight(h.cell, b.cell), "ruin in the way")
	ok(not CombatRules.can_attack(g, h, b, h.cell), "no shot through a wall")
	g.set_height(Vector2i(0, 0), 4)
	h.place(Vector2i(0, 0), 4)
	ok(g.line_of_sight(h.cell, b.cell), "shoot over it from high up")


func test_cliff_edge_hides_target() -> void:
	var g := CombatGrid.flat(5, 1)
	for x in range(2, 5):
		g.set_height(Vector2i(x, 0), 3)
	var h := _unit("hunter", 0, Vector2i(0, 0), g)
	var b := _unit("bandit", 1, Vector2i(4, 0), g)
	ok(not CombatRules.can_attack(g, h, b, h.cell), "can't see someone back from the cliff edge")
	b.place(Vector2i(2, 0), 3)
	ok(CombatRules.can_attack(g, h, b, h.cell), "can see someone standing at the edge")


func test_high_range_capped() -> void:
	var g := CombatGrid.flat(12, 1)
	g.set_height(Vector2i(0, 0), 8)
	var h := _unit("hunter", 0, Vector2i(0, 0), g)  # range 5 ([USER] 2026-10-30: bows one ring further)
	var b := _unit("bandit", 1, Vector2i(8, 0), g)
	ok(CombatRules.can_attack(g, h, b, h.cell), "5 + 3")
	b.place(Vector2i(9, 0), 0)
	ok(not CombatRules.can_attack(g, h, b, h.cell), "8 levels only buy +3")


func test_tall_map_round_trip() -> void:
	var g := CombatGrid.flat(3, 1)
	g.set_height(Vector2i(1, 0), 8)
	g.set_terrain(Vector2i(2, 0), CombatGrid.T.RUIN)
	g.set_terrain(Vector2i(0, 0), CombatGrid.T.STAIRS)
	var back := CombatGrid.from_dict(g.to_dict())
	eq(back.height_at(Vector2i(1, 0)), 8)
	eq(back.terrain_at(Vector2i(2, 0)), CombatGrid.T.RUIN)
	eq(back.terrain_at(Vector2i(0, 0)), CombatGrid.T.STAIRS)


func test_void_cells_and_zones_round_trip() -> void:
	var g := CombatGrid.flat(4, 3)
	g.set_terrain(Vector2i(0, 0), CombatGrid.T.VOID)
	g.set_zone(Vector2i(3, 2), "ruins")
	g.set_zone(Vector2i(2, 2), "snow")
	ok(not g.passable(Vector2i(0, 0)), "void is not walkable")
	ok(not g.solid(Vector2i(0, 0)) and g.solid(Vector2i(1, 0)), "void is not ground")
	var back := CombatGrid.from_dict(g.to_dict())
	eq(back.terrain_at(Vector2i(0, 0)), CombatGrid.T.VOID)
	eq(back.zone_at(Vector2i(3, 2)), "ruins")
	eq(back.zone_at(Vector2i(2, 2)), "snow")
	eq(back.zone_at(Vector2i(1, 1)), "")
	ok(not CombatGrid.flat(2, 2).to_dict().has("zones"), "single-set maps save no zone rows")
	ok(not back.deploy_cells(0).has(Vector2i(0, 0)), "nobody deploys on void")


func test_blend_maps_load_and_connect() -> void:
	for name in ["blend_forest_castle", "blend_mountain_marsh", "blend_farm_crypt", "blend_canyon_crystal"]:
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % name))
		ok(d is Dictionary, name)
		var g := CombatGrid.from_dict(d.map)
		var zones := {}
		for z in g.zones:
			zones[z] = true
		ok(zones.size() >= 2, "%s mixes tile sets" % name)
		ok(g.terrain.has(CombatGrid.T.VOID), "%s has an island outline" % name)


# --- guard zones ([USER] c13, combat build step 2) ----------------------------------------------

func _guard_scene() -> Dictionary:
	var g := CombatGrid.flat(7, 5)
	var knight := _unit("knight", 0, Vector2i(2, 2), g)
	var archer := _unit("hunter", 0, Vector2i(4, 2), g)
	var bandit := _unit("bandit", 1, Vector2i(3, 2), g)  # next to the knight
	var units := [knight, archer, bandit]
	CombatRules.guard(knight)
	CombatRules.begin_phase(units, 1)
	return {"g": g, "knight": knight, "archer": archer, "bandit": bandit, "units": units}


func test_a_guard_holds_the_foe_next_to_it() -> void:
	var s := _guard_scene()
	var bandit: CombatUnit = s.bandit
	eq(bandit.move_origin, bandit.cell, "the phase start is remembered")
	eq(CombatRules.holders(s.g, bandit, s.units), [s.knight] as Array[CombatUnit])
	var strike := bandit.abilities[0]
	# next to the knight and to the archer: only the guard can be hit
	eq(CombatRules.target_cells(s.g, bandit, strike, s.units, bandit.cell), [s.knight.cell] as Array[Vector2i], "it can only hit the guard")
	var ring := CombatRules.guard_ring(s.g, s.units, 0)
	ok(ring.has(Vector2i(3, 2)) and ring.has(Vector2i(1, 2)) and ring.size() == 4, "the ring is the guard's four neighbours")


func test_walking_away_costs_a_free_hit() -> void:
	var s := _guard_scene()
	var bandit: CombatUnit = s.bandit
	var rng := RandomNumberGenerator.new()
	eq(CombatRules.leave_hits(rng, s.g, bandit, s.units, Vector2i(2, 1)), [], "staying next to the guard is free")
	var hp := bandit.hp
	var ev := CombatRules.leave_hits(rng, s.g, bandit, s.units, Vector2i(5, 3))
	eq(ev[0].type, "free_hit")
	eq(ev[1].type, "hit")
	ok(bandit.hp < hp, "the guard's free hit lands")
	ok(bandit.left_guard, "and the move can't be undone")
	bandit.place(Vector2i(5, 3), 0)
	eq(CombatRules.held_at(s.g, bandit, s.units, bandit.cell), [] as Array[CombatUnit], "walked away: free to pick")


func test_no_hold_without_an_awake_guard() -> void:
	var s := _guard_scene()
	var knight: CombatUnit = s.knight
	knight.statuses[CombatRules.STATUS_SLEEP] = 1
	eq(CombatRules.holders(s.g, s.bandit, s.units), [] as Array[CombatUnit], "a sleeping guard holds nobody")
	knight.statuses.clear()
	eq(CombatRules.holders(s.g, s.bandit, s.units), [] as Array[CombatUnit], "nor one that isn't guarding")


func test_the_ai_hits_the_guard_or_pays_to_leave() -> void:
	var s := _guard_scene()
	var bandit: CombatUnit = s.bandit
	for i in 5:
		var p := EnemyAi.plan(s.g, bandit, s.units)
		var held := CombatRules.dist(p.move, s.knight.cell) == 1
		if held and p.ability != null:
			eq(p.aim, s.knight.cell, "held: it swings at the guard")
		ok(held or EnemyAi.leave_cost(s.g, bandit, s.units, p.move) > 0.0, "walking away was weighed")


# --- bleeding out ([USER] c6, c11, combat build step 3) ------------------------------------------

func test_a_party_piece_bleeds_out_instead_of_dying() -> void:
	var g := CombatGrid.flat(5, 3)
	var knight := _unit("knight", 0, Vector2i(1, 1), g)
	var hunter := _unit("hunter", 0, Vector2i(1, 2), g)
	var bandit := _unit("bandit", 1, Vector2i(2, 1), g)
	var units := [knight, hunter, bandit]
	knight.hp = 0
	ok(knight.downed() and not knight.alive(), "downed, not gone")
	eq(knight.bleed, int(CombatRules.num("bleed_turns")))
	eq(CombatRules.occupant(units, knight.cell), knight, "it still takes up its cell")
	eq(CombatRules.unit_at(units, knight.cell), null, "but can't be hit")
	bandit.hp = 0
	ok(not bandit.downed(), "foes still fall for good")
	bandit.hp = bandit.max_hp
	for i in 2:
		CombatRules.begin_phase(units, 0)
	ok(knight.downed(), "two phases in, still waiting")
	var events := CombatRules.begin_phase(units, 0)
	ok(not knight.downed() and events.any(func(e: Dictionary) -> bool: return e.type == "bled_out"), "the third: out for the fight")


func test_aid_brings_a_downed_teammate_back() -> void:
	var g := CombatGrid.flat(5, 3)
	var knight := _unit("knight", 0, Vector2i(1, 1), g)
	var hunter := _unit("hunter", 0, Vector2i(3, 1), g)
	var units := [knight, hunter]
	knight.hp = 0
	var aid: Ability = CombatRules.extra_actions(hunter)[0]
	eq(aid.kind, "revive")
	eq(CombatRules.target_cells(g, hunter, aid, units, hunter.cell), [] as Array[Vector2i], "AID needs to stand next to it")
	hunter.place(Vector2i(2, 1), 0)
	eq(CombatRules.target_cells(g, hunter, aid, units, hunter.cell), [knight.cell] as Array[Vector2i])
	var ev := CombatRules.resolve(RandomNumberGenerator.new(), g, hunter, aid, knight.cell, units)
	eq(ev[0].type, "revive")
	eq(knight.hp, ceili(knight.max_hp / 4.0), "back at a quarter of max HP")
	eq(knight.bleed, 0)


func test_a_foe_can_knock_a_downed_piece_out() -> void:
	var g := CombatGrid.flat(5, 3)
	var knight := _unit("knight", 0, Vector2i(1, 1), g)
	var hunter := _unit("hunter", 0, Vector2i(1, 2), g)
	var bandit := _unit("bandit", 1, Vector2i(2, 1), g)
	var units := [knight, hunter, bandit]
	knight.hp = 0
	var ko: Ability = CombatRules.extra_actions(bandit)[0]
	eq(ko.kind, "knockout")
	CombatRules.begin_phase(units, 1)
	var p := EnemyAi.plan(g, bandit, units)
	ok(p.ability != null, "the bandit acts")
	CombatRules.resolve(RandomNumberGenerator.new(), g, bandit, ko, knight.cell, units)
	ok(not knight.downed(), "knocked out: no AID will help now")
	eq(CombatRules.target_cells(g, hunter, CombatRules.extra_actions(hunter)[0], units, hunter.cell), [] as Array[Vector2i])


func test_the_ai_helps_a_teammate_up() -> void:
	var g := CombatGrid.flat(6, 3)
	var knight := _unit("knight", 0, Vector2i(1, 1), g)
	var hunter := _unit("hunter", 0, Vector2i(3, 1), g)
	var units := [knight, hunter, _unit("bandit", 1, Vector2i(5, 2), g)]
	knight.hp = 0
	CombatRules.begin_phase(units, 0)
	var p := EnemyAi.plan(g, hunter, units)
	ok(p.ability != null and p.ability.kind == "revive" and p.aim == knight.cell, "the party AI picks AID")


# --- helping strikes ([USER] c15, c19, combat build step 4) --------------------------------------

func test_a_corner_pair_teams_up() -> void:
	# Brandon's picture: teammates above and left of the foe, next to each other on the diagonal.
	var g := CombatGrid.flat(5, 5)
	var a := _unit("knight", 0, Vector2i(2, 1), g)
	var b := _unit("hunter", 0, Vector2i(1, 2), g)
	var foe := _unit("bandit", 1, Vector2i(2, 2), g)
	foe.max_hp = 99
	foe.hp = 99
	var units := [a, b, foe]
	eq(CombatRules.helper(a, foe, units, a.cell), b)
	var f := CombatRules.forecast(g, a, a.abilities[0], foe.cell, units, a.cell)
	eq(f.targets[0].help, 1, "the forecast shows the help")
	CombatRules.counters = false
	var ev := CombatRules.resolve(RandomNumberGenerator.new(), g, a, a.abilities[0], foe.cell, units)
	CombatRules.reset_switches()
	var helps := ev.filter(func(e: Dictionary) -> bool: return e.type == "help")
	eq(helps.size(), 1, "one helper per attack")
	eq(helps[0].amount, 1, "a flat 1, past armor")
	eq(helps[0].src, b)


func test_who_teams_up() -> void:
	var g := CombatGrid.flat(5, 5)
	var a := _unit("knight", 0, Vector2i(1, 2), g)
	var b := _unit("hunter", 0, Vector2i(3, 2), g)
	var foe := _unit("bandit", 1, Vector2i(2, 2), g)
	var units := [a, b, foe]
	eq(CombatRules.helper(a, foe, units, a.cell), b, "opposite sides count ([USER] c19)")
	Db.combat["teamup_opposite"] = 0.0
	eq(CombatRules.helper(a, foe, units, a.cell), null, "with the switch off they must be next to each other")
	Db.combat["teamup_opposite"] = 1.0
	b.place(Vector2i(0, 2), 0)
	eq(CombatRules.helper(a, foe, units, a.cell), null, "one tile behind, not next to the foe: no team-up")
	b.place(Vector2i(3, 2), 0)
	var archer := _unit("hunter", 0, Vector2i(2, 0), g)
	eq(CombatRules.helper(archer, foe, units + [archer], archer.cell), null, "a shot from afar isn't a team-up")
	b.statuses[CombatRules.STATUS_SLEEP] = 1
	eq(CombatRules.helper(a, foe, units, a.cell), null, "a sleeping teammate doesn't help")


# --- fight goals and TALK ([USER] c10, c17, combat build step 6) --------------------------------

func _goal_units() -> Dictionary:
	var g := CombatGrid.flat(6, 3)
	var hero := CombatUnit.from_member({"def": Db.character(&"lead"), "hp": 20})
	hero.place(Vector2i(0, 1), 0)
	var boss := _unit("bandit", 1, Vector2i(4, 1), g)
	boss.leader = true
	var minion := _unit("wolf", 1, Vector2i(5, 2), g)
	return {"g": g, "hero": hero, "boss": boss, "minion": minion, "units": [hero, boss, minion]}


func test_goals_parse_and_any_one_wins() -> void:
	var f := FightGoals.parse("leader|hold:3|exit", [[5, 0]])
	eq(f.kinds, ["leader", "hold", "exit"] as Array[String])
	eq(f.hold_rounds, 3)
	eq(f.exit_cells, [Vector2i(5, 0)] as Array[Vector2i])
	eq(FightGoals.parse("").kinds, ["defeat"] as Array[String], "no goals: beat them all")
	var s := _goal_units()
	eq(f.check(s.units, 0).won, false)
	eq(f.check(s.units, 3).how, "hold", "held out three rounds")
	s.boss.hp = 0
	eq(f.check(s.units, 0).how, "leader", "the boss is down: the rest flee")
	s.boss.hp = 5
	s.hero.place(Vector2i(5, 0), 0)
	eq(f.check(s.units, 0).how, "exit", "everyone standing is on the way out")


func test_a_protected_piece_falling_loses() -> void:
	var s := _goal_units()
	var f := FightGoals.parse("defeat")
	var friend := _unit("hunter", 0, Vector2i(1, 1), s.g)
	friend.protect = true
	var units: Array = s.units + [friend]
	eq(f.check(units, 0).lost, false)
	friend.hp = 0
	eq(f.check(units, 0).lost, true, "keep it safe, or lose")


func test_escape_pays_half_for_foes_left_standing() -> void:
	var cfg := {"xp_win": 10, "xp_foe": 25, "xp_boss": 100}
	eq(LevelRules.fight_xp(1, false, cfg), 35)
	eq(LevelRules.fight_xp(1, false, cfg, 2), 35 + 25, "two left standing: half of 50")


func test_talk_needs_its_flag_and_enough_words() -> void:
	var f := FightGoals.parse("defeat", [], {"unit": 0, "need": "flag:knows_boss", "times": 2, "result": "join:boss_joined"})
	ok(not f.talk_open([]), "closed until you know something")
	ok(f.talk_open(["knows_boss"]))
	eq(f.talk_once(), "", "once is not enough")
	eq(f.talk_once(), "join:boss_joined", "twice and the foe comes round")
	ok(not FightGoals.parse("defeat").talk_open(["anything"]), "a fight not written for TALK has none")


func test_talk_in_a_battle() -> void:
	var s := _goal_units()
	s.boss.talk_to = true
	var b := Battle.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(b)
	b.setup(s.g, s.units, 1)
	b.goals = FightGoals.parse("defeat", [], {"unit": 0, "times": 1, "result": "flee"})
	b.talk_open = true
	eq(b._talk_target(s.hero), null, "too far to talk")
	s.hero.place(Vector2i(2, 1), 0)
	eq(b._talk_target(s.hero), s.boss, "within 3 tiles")
	b.selected = s.hero
	b._on_talk()
	eq(b.state, Battle.S.OVER)
	eq(b.outcome.how, "talk", "talked the group into leaving")
	b.free()


## Brandon (2026-10-30): hovering HIT or GOOD SHOT in the action menu shows what it can reach, by the same
## height and sight rules as aiming.
func test_an_actions_reach() -> void:
	var g := CombatGrid.flat(7, 7)
	var k := _unit("knight", 0, Vector2i(3, 3), g)
	var hit := CombatRules.reach_cells(g, k, k.abilities[0], k.cell)
	eq(hit.size(), 4, "melee: the four cells beside it")
	g.set_height(Vector2i(4, 3), 3)
	ok(not CombatRules.reach_cells(g, k, k.abilities[0], k.cell).has(Vector2i(4, 3)), "not up a cliff it can't hit")
	var arch := _unit("archer", 0, Vector2i(0, 3), g)
	var shot := CombatRules.reach_cells(g, arch, arch.abilities[0], arch.cell)
	var r := CombatRules.ability_range(arch, arch.abilities[0])
	ok(shot.all(func(c: Vector2i) -> bool: return CombatRules.dist(c, arch.cell) >= r.x and CombatRules.dist(c, arch.cell) <= r.y), "inside the bow's band")
	g.set_terrain(Vector2i(1, 3), CombatGrid.T.ROCK)
	g.set_height(Vector2i(1, 3), 4)
	ok(not CombatRules.reach_cells(g, arch, arch.abilities[0], arch.cell).has(Vector2i(2, 3)), "a wall in the way: out of sight, out of reach")


func test_hovering_an_action_shows_its_reach() -> void:
	var s := _goal_units()
	var b := Battle.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(b)
	b.setup(s.g, s.units, 1)
	b.selected = s.hero
	s.hero.place(Vector2i(3, 1), 0)
	b.preview_reach(s.hero.abilities[0])
	eq(b.board.reach.size(), 4, "HIT's reach: the four cells beside him")
	eq(b.board.reach.get(s.boss.cell, 0), 2, "the bandit next to him is marked")
	eq(b.board.reach.get(Vector2i(2, 1), 0), 1, "an empty cell in reach is plain")
	b.preview_reach(null)
	eq(b.board.reach, {}, "WAIT or GUARD: nothing")
	b.free()


## [USER] 2026-10-30: rangers and archers reach one ring further: the hero's bow 2 to 4, the bow foes 2 to 5,
## the hunter's SNARE 2 to 4.
func test_bows_reach_one_ring_further() -> void:
	var g := CombatGrid.flat(9, 1)
	var hero := CombatUnit.from_member({"def": Db.character(&"lead"), "hp": 20})
	hero.apply_class(load("res://data/classes/job_archer.tres"), Game.weapon_mods("lead", "bow"))
	eq(CombatRules.ability_range(hero, hero.abilities[0]), Vector2i(2, 4), "the hero's bow")
	for id in ["archer", "bandit_archer", "hunter"]:
		var u := _unit(id, 1, Vector2i(0, 0), g)
		eq(CombatRules.ability_range(u, u.abilities[0]), Vector2i(2, 5), id)
	eq(CombatRules.ability_range(_unit("hunter", 0, Vector2i(0, 0), g), Db.ability("snare")), Vector2i(2, 4), "SNARE")



## [USER] design-boss-daggers: the rogue's blades leave POISON on every hit: 1 HP at the start of each of the
## target's phases for `poison_turns` of them, through armor; a new hit renews it and doesn't stack.
func test_rogue_blades_poison_through_armor_and_renew() -> void:
	var g := CombatGrid.flat(3, 1)
	var r := _unit("job_rogue", 0, Vector2i(0, 0), g)
	var b := _unit("bandit", 1, Vector2i(1, 0), g)
	b.max_hp = 99
	b.hp = 99
	var units := [r, b]
	var rng := RandomNumberGenerator.new()
	CombatRules.resolve(rng, g, r, r.abilities[0], b.cell, units, false)
	var turns := int(CombatRules.num("poison_turns"))
	eq(int(b.statuses.get(CombatRules.STATUS_POISON, 0)), turns, "a hit poisons for poison_turns phases")
	b.armor = 9
	var ticks := 0
	for i in 5:
		var before := b.hp
		var ev := CombatRules.begin_phase(units, 1)
		if b.hp == before - 1:
			ticks += 1
			ok(ev.any(func(e: Dictionary) -> bool: return e.type == "bleed" and e.status == CombatRules.STATUS_POISON), "the board sees it")
		CombatRules.end_phase(units, 1)
	eq(ticks, turns, "1 a phase for poison_turns phases, whatever the armor")
	ok(not b.has_status(CombatRules.STATUS_POISON), "then it wears off")
	CombatRules.resolve(rng, g, r, r.abilities[0], b.cell, units, false)
	CombatRules.resolve(rng, g, r, r.abilities[0], b.cell, units, false)
	eq(int(b.statuses[CombatRules.STATUS_POISON]), turns, "a new hit renews it, no higher")
	var hp := b.hp
	CombatRules.begin_phase(units, 1)
	eq(b.hp, hp - 1, "and doesn't stack")
	var k := _unit("knight", 0, Vector2i(2, 0), g)
	b.statuses.clear()
	CombatRules.resolve(rng, g, k, k.abilities[0], b.cell, [k, b], false)
	ok(not b.has_status(CombatRules.STATUS_POISON), "other jobs' hits don't")


## [USER] design-boss-daggers: hit and run. After a hit the rogue may walk what's left of its move; the AI steps
## to a cell no foe could hit next phase, else stays.
func test_rogue_hits_and_runs() -> void:
	var g := CombatGrid.flat(9, 1)
	var r := _unit("job_rogue", 0, Vector2i(0, 0), g)
	var b := _unit("bandit", 1, Vector2i(3, 0), g)
	b.max_hp = 99
	b.hp = 99
	var units := [r, b]
	CombatRules.begin_phase(units, 0)
	r.place(Vector2i(2, 0), 0)
	r.moved = true
	r.move_spent = 2
	CombatRules.resolve(RandomNumberGenerator.new(), g, r, r.abilities[0], b.cell, units, false)
	r.acted = true
	ok(CombatRules.hit_and_run(r, r.abilities[0]), "a hit reopens the move")
	ok(not r.done(), "so the rogue isn't done")
	eq(CombatRules.move_left(r), r.move - 2, "only what it didn't walk")
	var cells: Dictionary = CombatRules.reachable(g, r, units).cost
	ok(cells.has(Vector2i(0, 0)) and not cells.has(Vector2i(2 - r.move, 0)), "the move tiles are the rest of the move")
	var away := EnemyAi.retreat(g, r, units)
	ok(not EnemyAi.hit_reach(g, r, units, true).has(away.move) or away.move == r.cell, "the AI steps out of melee reach")
	var keep: float = Db.combat["run_melee_only"]
	Db.combat["run_melee_only"] = 0.0  # the safe-cell rule, kept behind the switch
	away = EnemyAi.retreat(g, r, units)
	ok(not CombatRules.danger_zone(g, units, 1).has(away.move) or away.move == r.cell, "or out of the danger zone")
	Db.combat["run_melee_only"] = keep
	var boxed := CombatGrid.flat(3, 1)
	var r2 := _unit("job_rogue", 0, Vector2i(0, 0), boxed)
	var b2 := _unit("bandit", 1, Vector2i(1, 0), boxed)
	eq(EnemyAi.retreat(boxed, r2, [r2, b2]).move, r2.cell, "no safe cell: it stays by the foe")
	var k := _unit("knight", 0, Vector2i(2, 0), g)
	k.moved = true
	ok(not CombatRules.hit_and_run(k, k.abilities[0]), "other jobs don't")
	r.move_spent = r.move
	r.moved = true
	ok(not CombatRules.hit_and_run(r, r.abilities[0]), "nothing left to walk: done")
	CombatRules.end_phase(units, 0)
	eq(r.move_spent, 0, "out of its phase its reach is its whole move again")


## Game designer 2026-10-30: hit and run steps out of every foe's plain hit, the Lich's reach 2 too.
func test_hit_and_run_counts_reach_two() -> void:
	var g := CombatGrid.flat(30, 1)
	var r := _unit("job_rogue", 0, Vector2i(0, 0), g)
	var lich := _unit("lich", 1, Vector2i(20, 0), g)
	var reach := CombatRules.ability_range(lich, null)
	eq(reach.y, 2, "the Lich hits 2 away")
	var far := 20 - CombatRules.move_points(lich) - reach.y
	var zone := EnemyAi.hit_reach(g, r, [r, lich])
	ok(zone.has(Vector2i(far, 0)), "his walk plus his reach is in")
	ok(not zone.has(Vector2i(far - 1, 0)), "one further is out")


## A piece helped up after its place in the list came by still gets its turn, as the player's can (the robot's
## dagger stalemate at the throne, playtest bug 03).
func test_a_piece_helped_up_mid_phase_still_acts() -> void:
	var g := CombatGrid.flat(6, 1)
	var hero := _unit("job_rogue", 0, Vector2i(1, 0), g)
	var dog := _unit("dog", 0, Vector2i(0, 0), g)
	var foe := _unit("bandit", 1, Vector2i(4, 0), g)
	var units := [hero, dog, foe]
	CombatRules.begin_phase(units, 0)
	hero.hp = 0
	ok(hero.downed(), "the hero is down, first in the list")
	CombatSim.play_phase(RandomNumberGenerator.new(), g, units, 0)
	ok(hero.alive(), "the dog helped him up")
	ok(hero.done(), "and he still took his turn")


## Runs `team`'s phase edges only (no turns): begin, the boss's start step, then his end step. The events.
func _boss_phase(g: CombatGrid, units: Array, team: int) -> Array:
	CombatRules.begin_phase(units, team)
	var ev := CombatRules.boss_start(RandomNumberGenerator.new(), g, units, team)
	ev.append_array(CombatRules.boss_end(g, units, team))
	CombatRules.end_phase(units, team)
	return ev


## The Lich's big move (game designer 2026-10-30, [USER] design-boss-warning): marked on his 2nd phase on the
## tiles that catch the party, it lands at the start of his next one on everyone there, his own pieces too,
## then waits 3 of his phases.
func test_lich_marks_his_big_move_and_it_lands_next_phase() -> void:
	var g := CombatGrid.flat(12, 5)
	var lich := _unit("lich", 1, Vector2i(1, 2), g)
	var knight := _unit("knight", 0, Vector2i(4, 2), g)
	knight.max_hp = 99  # a crit mustn't down it before his next mark
	knight.hp = 99
	var units := [lich, knight]
	_boss_phase(g, units, 1)
	ok(CombatRules.marks(units).is_empty(), "nothing marked on his 1st phase")
	var ev := _boss_phase(g, units, 1)
	eq(ev.filter(func(e: Dictionary) -> bool: return e.type == "mark").size(), 1, "his 2nd phase marks it")
	var marked := CombatRules.marks(units)
	ok(marked.has(knight.cell), "on the knight")
	eq(marked.size(), 5, "a 5-cell plus")
	ok(not CombatRules.danger_zone(g, units, 1).has(Vector2i(9, 2)), "the big move stays out of the danger zone")
	var bone := _unit("lich_minion", 1, Vector2i(0, 0), g)
	for c: Vector2i in marked:
		if c != knight.cell and CombatRules.unit_at(units, c) == null:
			bone.place(c, 0)  # one of his own pieces wanders onto it
			break
	units.append(bone)
	var hp := knight.hp
	ev = _boss_phase(g, units, 1)
	ok(knight.hp < hp, "it lands on the knight at the start of his next phase")
	ok(bone.hp < bone.max_hp, "and on his own piece standing there")
	ok(ev.any(func(e: Dictionary) -> bool: return e.type == "land"), "a land event plays")
	ok(not ev.any(func(e: Dictionary) -> bool: return e.type == "mark"), "no new mark on that phase: cooldown")
	_boss_phase(g, units, 1)
	ok(CombatRules.marks(units).is_empty(), "nor the next")
	ev = _boss_phase(g, units, 1)
	ok(ev.any(func(e: Dictionary) -> bool: return e.type == "mark"), "3 of his phases after the first mark, the next")


## The party's AI reads the warning: it doesn't end its move on a marked tile when it has somewhere else to go.
func test_the_party_ai_steps_off_marked_tiles() -> void:
	var g := CombatGrid.flat(9, 5)
	var lich := _unit("lich", 1, Vector2i(0, 0), g)
	var knight := _unit("knight", 0, Vector2i(5, 2), g)
	var units := [lich, knight]
	lich.mark = {"ability": Db.ability("lich_doom"), "cells": CombatRules.area(g, Db.ability("lich_doom"), knight.cell), "left": 1}
	CombatRules.begin_phase(units, 0)
	var p := EnemyAi.plan(g, knight, units)
	ok(not CombatRules.marks(units).has(p.move), "the knight ends its move off the marked tiles")
	CombatRules.begin_phase(units, 1)
	p = EnemyAi.plan(g, lich, units)
	ok(p.ability == null or not p.ability.boss_move(), "the big moves are never his plain action")


## The Lich's minions (game designer 2026-10-30): 2 every 3rd of his phases from his 3rd, within 2 of him,
## at most 4 standing; they wait a phase before acting and crumble when he falls.
func test_lich_calls_minions_and_they_crumble_with_him() -> void:
	var g := CombatGrid.flat(9, 7)
	var lich := _unit("lich", 1, Vector2i(4, 3), g)
	lich.abilities = lich.abilities.filter(func(a: Ability) -> bool: return a.kind != "summon")  # just the minion call here
	lich.abilities.append(Db.ability("raise_dead"))  # off his class (Brandon picked ice pillars instead)
	var knight := _unit("knight", 0, Vector2i(8, 6), g)
	var units := [lich, knight]
	_boss_phase(g, units, 1)
	_boss_phase(g, units, 1)
	eq(lich.minions.size(), 0, "none before his 3rd phase")
	CombatRules.begin_phase(units, 1)
	var ev := CombatRules.boss_start(RandomNumberGenerator.new(), g, units, 1)
	eq(ev.filter(func(e: Dictionary) -> bool: return e.type == "summon").size(), 2, "2 on his 3rd phase")
	for m: CombatUnit in lich.minions:
		ok(units.has(m) and m.team == 1, "on the board, on his side")
		ok(CombatRules.dist(m.cell, lich.cell) <= 2, "within 2 of him")
		ok(m.done(), "acting from their next phase")
	CombatRules.end_phase(units, 1)
	for i in 3:
		_boss_phase(g, units, 1)
	eq(lich.minions.size(), 4, "2 more on his 6th")
	for i in 3:
		_boss_phase(g, units, 1)
	eq(lich.minions.size(), 4, "never more than 4 standing")
	lich.minions[0].hp = 0
	for i in 3:
		_boss_phase(g, units, 1)
	eq(lich.minions.filter(func(m: CombatUnit) -> bool: return m.alive()).size(), 4, "one fell, one more comes")
	lich.hp = 0
	ok(lich.minions.all(func(m: CombatUnit) -> bool: return not m.alive()), "they crumble when he falls")
	ok(lich.minions[0].crumbled == false and lich.minions[1].crumbled, "the one the party beat isn't crumbled")


## A map can mark where they come (a group's `summon` cells), for the map builder.
func test_minions_come_on_the_maps_summon_cells() -> void:
	var g := CombatGrid.flat(9, 7)
	var lich := _unit("lich", 1, Vector2i(1, 1), g)
	lich.abilities = lich.abilities.filter(func(a: Ability) -> bool: return a.kind != "summon")
	lich.abilities.append(Db.ability("raise_dead"))
	var knight := _unit("knight", 0, Vector2i(8, 6), g)
	var units := [lich, knight]
	lich.summon_cells = [Vector2i(7, 0), Vector2i(8, 6), Vector2i(6, 0)] as Array[Vector2i]
	lich.phase_no = 2
	CombatRules.begin_phase(units, 1)
	CombatRules.boss_start(RandomNumberGenerator.new(), g, units, 1)
	eq(lich.minions.map(func(m: CombatUnit) -> Vector2i: return m.cell), [Vector2i(7, 0), Vector2i(6, 0)], "the empty summon cells, in order")


## The ambusher ([USER] design-foe-roles, game designer 2026-10-30): hidden, it's out of the danger zone and
## can't be picked, until a party piece ends a move within 3 with line of sight; it waits for prey, strikes the
## softest piece in reach, and that first strike from hiding counts as a flank.
func test_ambusher_hides_until_spotted_and_strikes_soft() -> void:
	var g := CombatGrid.flat(12, 3)
	var amb := _unit("ambusher", 1, Vector2i(10, 1), g)
	amb.hiding = true
	var knight := _unit("knight", 0, Vector2i(1, 1), g)
	var mage := _unit("mage", 0, Vector2i(1, 2), g)
	var lookout := _unit("bandit", 1, Vector2i(11, 0), g)  # a seen piece of its side, so it stays hidden
	var units := [amb, knight, mage, lookout]
	ok(not CombatRules.danger_zone(g, units, 1).has(Vector2i(5, 1)), "not in the danger zone")
	CombatRules.begin_phase(units, 1)
	var p := EnemyAi.plan(g, amb, units)
	eq(p.move, amb.cell, "nothing in reach: it stays hidden where it is")
	knight.place(Vector2i(6, 1), 0)
	eq(CombatRules.spot(g, units, knight), [] as Array[CombatUnit], "4 away: not spotted")
	knight.place(Vector2i(7, 1), 0)
	mage.place(Vector2i(7, 2), 0)
	ok(not CombatRules.target_cells(g, knight, knight.abilities[0], units, Vector2i(9, 1)).has(amb.cell), "a hidden foe can't be picked")
	p = EnemyAi.plan(g, amb, units)
	eq(p.target, mage, "it goes for the softest piece")
	ok(CombatRules.crit_parts(g, amb, mage, units, p.move).any(func(x: Array) -> bool: return x[0] == "MOD_FLANK"), "its strike from hiding is a flank")
	amb.place(p.move, 0)
	CombatRules.resolve(RandomNumberGenerator.new(), g, amb, p.ability, p.aim, units)
	ok(not amb.hiding, "striking gives it away")
	amb.hiding = true
	amb.place(Vector2i(10, 1), 0)
	eq(CombatRules.spot(g, units, knight), [amb] as Array[CombatUnit], "3 away in sight: spotted")
	ok(not amb.hiding)


## The last foes the party can see fall: a hidden one comes out at the next phase start, so the fight can end
## (the map builder's plaza ambusher stalled the robot, 2026-10-30).
func test_a_hidden_piece_comes_out_when_its_side_is_otherwise_gone() -> void:
	var g := CombatGrid.flat(12, 3)
	var amb := _unit("ambusher", 1, Vector2i(10, 1), g)
	amb.hiding = true
	var bandit := _unit("bandit", 1, Vector2i(3, 1), g)
	var knight := _unit("knight", 0, Vector2i(1, 1), g)
	var units := [amb, bandit, knight]
	CombatRules.begin_phase(units, 0)
	ok(amb.hiding, "still hidden while a bandit stands")
	bandit.hp = 0
	var ev := CombatRules.begin_phase(units, 1)
	ok(not amb.hiding, "out once nobody else of its side is left")
	ok(ev.any(func(e: Dictionary) -> bool: return e.type == "reveal"), "and the board is told")


## The fight's hover card ([USER] 2026-10-30, WoW-style): name, cost, reach, the numbers, wait and the caveman line.
func test_action_hover_card_reads_the_data() -> void:
	var g := CombatGrid.flat(6, 3)
	var mage := _unit("mage", 0, Vector2i(1, 1), g)
	var beam := Db.ability("moonbeam")
	var lines := ActionInfo.lines(mage, beam)
	eq(lines[0], Txt.t(beam.name_key), "the name first")
	eq(lines[1], Txt.f("TIP_COST", [beam.res_cost, Txt.t("RES_MANA"), mage.res, mage.res_max]), "then the cost")
	ok(lines[2].begins_with(Txt.f("TIP_RANGE", "%d-%d" % [beam.range_min, beam.range_max])), "the reach")
	var hit := mage.damage + beam.power
	ok(lines[3].contains(Txt.f("TIP_HIT", "%d-%d" % [hit - 1, hit + 1])), "the damage from the data")
	eq(lines[lines.size() - 1], Txt.t("DESC_MOONBEAM"), "and the caveman line last")
	var dog := _unit("dog", 0, Vector2i(2, 1), g)
	dog.res = 0
	dog.res_tick = 1
	ok(ActionInfo.recharge(dog, Db.ability("bite")) > 0.0, "a spent charge sweeps back")
	eq(ActionInfo.wait_text(dog, Db.ability("bite")), Txt.f("TIP_CHARGE_BACK", dog.res_every))


## The dock (Brandon's pictures, dev-action-dock): MOVE, HIT, TRICKS, BELT, WAIT; GUARD pops up over HIT and the
## spells over TRICKS, the first nearest the bar; keys 1 to 0 pick a bar box, and up goes into its column.
func test_the_dock_bar_and_its_pop_up_columns() -> void:
	var hud := ActionHud.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(hud)
	var g := CombatGrid.flat(6, 3)
	var mage := _unit("mage", 0, Vector2i(1, 1), g)
	var fired := []
	var add := func(text: String, kind: String, a: Ability = null) -> Dictionary:
		return {"text": text, "enabled": true, "cb": func() -> void: fired.append(a.id if a else kind), "kind": kind, "ability": a, "count": 0}
	var entries := [add.call("MOVE", "move")]
	for a in mage.abilities:
		entries.append(add.call(Txt.t(a.name_key), "skill", a))
	entries.append(add.call("GUARD", "guard"))
	entries.append(add.call("WAIT", "wait"))
	hud.show_for(mage, entries, Vector2.ZERO, Rect2(0, 0, 1280, 640))
	var bar: Array = hud.hand_entries()
	eq(bar.map(func(e: Dictionary) -> String: return String(e.kind)), ["move", "skill", "group", "wait"], "MOVE, HIT, TRICKS, WAIT (no belt here)")
	eq((bar[1].pop as Array).map(func(e: Dictionary) -> String: return String(e.kind)), ["guard"], "GUARD tucked under HIT")
	ok(hud.press_key(1), "key 2: HIT")
	eq(fired, ["strike"])
	hud.press_key(2)  # TRICKS: pops its column and goes up into it
	eq(hud.second_entries().size(), mage.abilities.size() - 1, "the spells pop up over TRICKS")
	ok(hud._pop_slots[0].has_focus(), "focus goes up to the first, nearest the bar")
	eq(hud._pop_slots[0].entry.ability, mage.abilities[1])
	hud._pop_slots[0].entry.cb.call()
	eq(fired, ["strike", mage.abilities[1].id])
	hud.queue_free()
	# BELT (Brandon, 2026-10-30): the box is belt item 1 and fires it; its column holds item 2 on
	var hud2 := ActionHud.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(hud2)
	var belt := [add.call("MOVE", "move"), add.call("A", "item", mage.abilities[0]), add.call("B", "item", mage.abilities[1]),
		add.call("C", "item", mage.abilities[2]), add.call("WAIT", "wait")]
	hud2.show_for(mage, belt, Vector2.ZERO, Rect2(0, 0, 1280, 640))
	var bar2: Array = hud2.hand_entries()
	eq(bar2.map(func(e: Dictionary) -> String: return String(e.kind)), ["move", "item", "wait"], "BELT is the first item")
	eq((bar2[1].pop as Array).size(), 2, "items 2 and 3 pop up over it")
	fired.clear()
	ok(hud2.press_key(1), "key 2: the first belt item")
	eq(fired, [mage.abilities[0].id])
	hud2.queue_free()


## Ice pillars (Brandon, 2026-10-30; built, not on the Lich yet): raised 2 steps from a party piece and next to none,
## never on the way out or a stair; a party piece ending its phase next to them loses `pillar_cold` a pillar, at
## most `pillar_cold_max`; they never act, don't count toward winning, and crumble when he falls.
func test_ice_pillars_place_chill_and_crumble() -> void:
	var g := CombatGrid.flat(10, 7)
	var lich := _unit("lich", 1, Vector2i(8, 3), g)
	ok(lich.abilities.has(Db.ability("raise_ice")), "on his class (game designer dcba358)")
	var call := Db.ability("raise_ice").copy()
	call.count = 2  # two at once, to check they never share a cell or stand next to the party
	lich.abilities = lich.abilities.filter(func(a: Ability) -> bool: return a.id != "raise_ice")
	lich.abilities.append(call)
	var knight := _unit("knight", 0, Vector2i(3, 3), g)
	var units := [lich, knight]
	lich.summon_avoid = {Vector2i(5, 3): true}
	lich.phase_no = 2
	CombatRules.begin_phase(units, 1)
	CombatRules.boss_start(RandomNumberGenerator.new(), g, units, 1)
	eq(lich.minions.size(), 2, "2 raised on his 3rd phase")
	for p: CombatUnit in lich.minions:
		eq(CombatRules.dist(p.cell, knight.cell), 2, "2 steps from the party")
		ok(p.cell != Vector2i(5, 3), "never on the way out")
		ok(p.has_trait(CombatRules.TRAIT_STRUCTURE) and p.tags.has(&"ice"), "a pillar, tagged ice")
		eq(EnemyAi.plan(g, p, units).ability, null, "it never acts")
	knight.place(lich.minions[0].cell + Vector2i(1, 0) if CombatRules.unit_at(units, lich.minions[0].cell + Vector2i(1, 0)) == null else lich.minions[0].cell - Vector2i(1, 0), 0)
	var hp := knight.hp
	var ev := CombatRules.cold(units, 0)
	ok(knight.hp < hp and knight.hp >= hp - int(CombatRules.num("pillar_cold")) * int(CombatRules.num("pillar_cold_max")), "next to a pillar: cold, capped")
	ok(not ev.is_empty())
	lich.hp = 0
	ok(not CombatRules.team_alive(units, 1), "pillars don't keep his side in the fight")
	ok(lich.minions.all(func(p: CombatUnit) -> bool: return not p.alive()), "they crumble with him")


## CARRY ([USER] design-clutch-tools-2): the dog takes a friend next to it, up or down, up to 3 cells and sets them
## down beside it; a downed friend stays downed, its bleed still counting. The AI uses it for a friend on a marked
## tile. COMMAND (the sword job): the hero gives up their action and the dog gets a fresh phase; once every 3 phases.
func test_carry_and_command() -> void:
	var g := CombatGrid.flat(10, 5)
	var dog := _unit("dog", 0, Vector2i(2, 2), g)
	var hero := _unit("job_knight", 0, Vector2i(3, 2), g)
	var foe := _unit("bandit", 1, Vector2i(9, 4), g)
	var units := [dog, hero, foe]
	var carry := Db.ability("carry")
	ok(CombatRules.target_cells(g, dog, carry, units, dog.cell).has(hero.cell), "a friend next to the dog")
	hero.hp = 0
	ok(CombatRules.target_cells(g, dog, carry, units, dog.cell).has(hero.cell), "down too")
	var spots := CombatRules.carry_spots(g, dog, hero, carry, units)
	ok(not spots.is_empty())
	for d: Vector2i in spots:
		ok(CombatRules.dist(d, dog.cell) <= carry.power and CombatRules.dist(spots[d], d) == 1, "3 cells at most, set down beside")
	var dest: Vector2i = spots.keys()[0]
	var bleed := hero.bleed
	CombatRules.carry(RandomNumberGenerator.new(), g, dog, hero, dest, spots[dest], units)
	eq(dog.cell, dest)
	eq(hero.cell, spots[dest])
	ok(hero.downed() and hero.bleed == bleed, "still down, the bleed as it was")
	# the AI carries a friend off a marked tile
	hero.hp = hero.max_hp
	hero.bleed = 0
	hero.place(Vector2i(5, 2), 0)
	dog.place(Vector2i(4, 2), 0)
	var lich := _unit("lich", 1, Vector2i(9, 0), g)
	units.append(lich)
	lich.mark = {"ability": Db.ability("lich_doom"), "cells": CombatRules.area(g, Db.ability("lich_doom"), hero.cell), "left": 1}
	CombatRules.begin_phase(units, 0)
	hero.acted = true
	hero.moved = true
	var p := EnemyAi.plan(g, dog, units)
	ok(p.ability != null and p.ability.kind == "carry", "the dog carries the hero off the marked tiles")
	ok(not CombatRules.marks(units).has(p.spot), "to a cell the big move won't hit")
	# COMMAND
	units.erase(lich)
	var command := Db.ability("command")
	ok(hero.abilities.has(command), "the sword job has it")
	dog.acted = true
	dog.moved = true
	ok(CombatRules.usable(hero, command))
	CombatRules.command(hero, command, dog)
	ok(not dog.done() and dog.move_spent == 0, "the dog's fresh phase")
	ok(not CombatRules.usable(hero, command), "then a wait")
	for i in 3:
		CombatRules.begin_phase(units, 0)
	ok(CombatRules.usable(hero, command), "3 of the hero's phases later, again")


## The jobs' clutch tools ([USER] design-clutch-jobs): SHADOW SWAP (daggers) trades places with a friend up to 3
## away through anything, then waits 3 phases; OVERWATCH (bow) stops the first foe to walk into reach with a shot;
## WARD (book) makes the next hit on a friend do nothing.
func test_shadow_swap_overwatch_and_ward() -> void:
	var g := CombatGrid.flat(12, 5)
	var rogue := _unit("job_rogue", 0, Vector2i(1, 2), g)
	var dog := _unit("dog", 0, Vector2i(4, 2), g)
	var foe := _unit("bandit", 1, Vector2i(3, 2), g)
	var units := [rogue, dog, foe]
	var swap := Db.ability("shadow_swap")
	ok(rogue.abilities.has(swap), "the rogue job has it")
	CombatRules.begin_phase(units, 0)
	ok(CombatRules.target_cells(g, rogue, swap, units, rogue.cell).has(dog.cell), "a friend 3 away, a foe between")
	CombatRules.shadow_swap(g, rogue, swap, dog)
	eq([rogue.cell, dog.cell], [Vector2i(4, 2), Vector2i(1, 2)], "traded places")
	ok(not CombatRules.usable(rogue, swap), "then a wait")
	# OVERWATCH
	var archer := _unit("job_archer", 0, Vector2i(10, 2), g)  # OVERWATCH is built but off the job until the game designer's call
	var bandit := _unit("bandit", 1, Vector2i(10, 4), g)
	bandit.place(Vector2i(4, 4), 0)
	archer.range_min = 2  # the bow's reach (the weapon gives it in play)
	archer.range_max = 4
	archer.statuses[CombatRules.STATUS_OVERWATCH] = 1
	var walk: Array[Vector2i] = [Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4), Vector2i(8, 4)]
	var stop := CombatRules.watch_stop(g, bandit, walk, [archer, bandit])
	ok(not stop.is_empty() and stop.watcher == archer, "the first cell in the bow's reach stops it")
	ok(CombatRules.in_reach(g, archer.cell, stop.cell, CombatRules.ability_range(archer, null)), "in reach")
	var hp := bandit.hp
	bandit.place(stop.cell, 0)
	CombatRules.watch_shot(RandomNumberGenerator.new(), g, archer, bandit, [archer, bandit])
	ok(bandit.hp < hp and not archer.has_status(CombatRules.STATUS_OVERWATCH), "a shot, and the watch is spent")
	# WARD
	var mage := _unit("job_mage", 0, Vector2i(0, 0), g)
	var knight := _unit("knight", 0, Vector2i(6, 0), g)
	var thug := _unit("bandit", 1, Vector2i(7, 0), g)
	knight.statuses[CombatRules.STATUS_WARD] = 1
	hp = knight.hp
	CombatRules.resolve(RandomNumberGenerator.new(), g, thug, Db.ability("kick"), knight.cell, [mage, knight, thug])
	eq(knight.hp, hp, "the warded hit does nothing")
	eq(knight.cell, Vector2i(6, 0), "and no shove")
	ok(not knight.has_status(CombatRules.STATUS_WARD), "used up")
	CombatRules.resolve(RandomNumberGenerator.new(), g, thug, thug.abilities[0], knight.cell, [mage, knight, thug])
	ok(knight.hp < hp, "the next one lands")


## Stand and watch (game designer 2026-10-30): an archer that doesn't move in its phase ends it on OVERWATCH, free on
## top of its attack; one that moved doesn't.
func test_an_archer_that_stands_still_watches() -> void:
	var g := CombatGrid.flat(8, 3)
	var archer := _unit("job_archer", 0, Vector2i(1, 1), g)
	var units := [archer]
	ok(archer.has_trait(CombatRules.TRAIT_STAND_WATCH))
	CombatRules.begin_phase(units, 0)
	archer.acted = true
	CombatRules.end_phase(units, 0)
	ok(archer.has_status(CombatRules.STATUS_OVERWATCH), "stood still: watching")
	CombatRules.begin_phase(units, 0)
	ok(not archer.has_status(CombatRules.STATUS_OVERWATCH), "gone at its next phase")
	archer.place(Vector2i(3, 1), 0)
	CombatRules.end_phase(units, 0)
	ok(not archer.has_status(CombatRules.STATUS_OVERWATCH), "moved: no watch")


## Caster foes (game designer foe-roles-build, [USER] design-foes-boss2): the mender heals from 2 tiles and keeps
## back, the hexer picks the hardest hitter and never stacks, the warder armors the foe nearest a hero.
func test_caster_foes() -> void:
	var g := CombatGrid.flat(12, 5)
	var hero := _unit("knight", 0, Vector2i(2, 2), g)
	var bandit := _unit("bandit", 1, Vector2i(8, 2), g)
	var mender := _unit("foe_mender", 1, Vector2i(10, 2), g)
	bandit.hp = 3
	var units := [hero, bandit, mender]
	var p := EnemyAi.plan(g, mender, units)
	ok(p.ability != null and p.ability.id == "foe_mend" and p.aim == bandit.cell, "the mender heals the wounded foe from range")
	bandit.hp = bandit.max_hp
	hero.place(Vector2i(6, 2), 0)
	p = EnemyAi.plan(g, mender, units)
	ok(p.ability == null, "nothing to heal: it does not strike")
	ok(CombatRules.dist(p.move, hero.cell) >= 2, "and keeps 2 tiles off the hero")
	var tight := CombatGrid.flat(2, 1)
	var h2 := _unit("bandit_archer", 0, Vector2i(0, 0), tight)  # no counter-hit at 1 tile
	var m2 := _unit("foe_mender", 1, Vector2i(1, 0), tight)
	p = EnemyAi.plan(tight, m2, [h2, m2])
	ok(p.ability != null and p.ability.id == "strike", "cornered, it hits (1)")
	# the hexer
	var k := _unit("knight", 0, Vector2i(4, 1), g)
	var a := _unit("bandit_archer", 0, Vector2i(4, 3), g)
	var hexer := _unit("foe_hexer", 1, Vector2i(8, 2), g)
	p = EnemyAi.plan(g, hexer, [k, a, hexer])
	ok(p.ability != null and p.aim == k.cell, "the hexer picks the hardest hitter")
	k.statuses[CombatRules.STATUS_SLOW] = 1
	p = EnemyAi.plan(g, hexer, [k, a, hexer])
	ok(p.ability != null and p.aim == a.cell, "a hexed hero is not hexed again: it spreads")
	hexer.statuses.clear()
	var ev := CombatRules.resolve(RandomNumberGenerator.new(), g, hexer, Db.ability("foe_spook"), a.cell, [k, a, hexer])
	ok(a.has_status(CombatRules.STATUS_SPOOK), "the scare lands")
	ok(CombatRules.damage_parts(g, a, hexer, a.cell, null, [k, a, hexer]).any(func(x: Array) -> bool: return x[0] == "MOD_SPOOKED"), "and the scared hero hits softer")
	# the warder
	var near := _unit("bandit", 1, Vector2i(5, 2), g)
	var far := _unit("bandit", 1, Vector2i(11, 4), g)
	var warder := _unit("foe_warder", 1, Vector2i(9, 2), g)
	var hh := _unit("knight", 0, Vector2i(3, 2), g)
	p = EnemyAi.plan(g, warder, [hh, near, far, warder])
	ok(p.ability != null and p.ability.id == "foe_ward" and p.aim == near.cell, "the warder armors the foe nearest a hero")
	near.statuses[CombatRules.STATUS_FOE_WARD] = 1
	ok(CombatRules.armor_parts(g, hh, near, hh.cell, null, [hh, near]).any(func(x: Array) -> bool: return x[0] == "MOD_FOE_WARD" and x[1] == 2), "the ward is +2 armor")
	p = EnemyAi.plan(g, warder, [hh, near, far, warder])
	ok(p.ability == null or p.aim != near.cell, "it does not stack on a warded foe")
	ev.clear()


## Chargers: a straight run of 3 or more tiles adds 2; the bull's gore also shoves 1.
func test_charger_foes() -> void:
	var g := CombatGrid.flat(12, 6)
	var hero := _unit("knight", 0, Vector2i(6, 2), g)
	var rusher := _unit("foe_rusher", 1, Vector2i(0, 2), g)
	rusher.move_origin = Vector2i(0, 2)
	var has := func(from: Vector2i) -> bool:
		return CombatRules.damage_parts(g, rusher, hero, from, null, [hero, rusher]).any(func(x: Array) -> bool: return x[0] == "MOD_CHARGE" and x[1] == 2)
	ok(has.call(Vector2i(5, 2)), "five tiles straight: it charges")
	ok(not has.call(Vector2i(2, 2)), "two tiles: no")
	ok(not has.call(Vector2i(4, 3)), "not in a line: no")
	var p := EnemyAi.plan(g, rusher, [hero, rusher])
	ok(p.ability != null and p.aim == hero.cell and CombatRules.charged(rusher, p.move), "the AI runs in a line when it can")
	var bull := _unit("foe_bull", 1, Vector2i(7, 2), g)
	var gore := Db.ability("gore")
	CombatRules.resolve(RandomNumberGenerator.new(), g, bull, gore, hero.cell, [hero, bull])
	eq(hero.cell, Vector2i(5, 2), "the bull's gore shoves its target 1 tile")


## Boss phases by health (design-foes-boss2): the trigger is data on the class, one phase a boss phase, and a
## phase's ability set replaces the last one's. What a phase changes is not picked, so no real boss has any yet.
func test_boss_phases_by_health() -> void:
	var c := ClassDef.new()
	c.id = &"phase_test"
	c.name_key = "ENEMY_BANDIT"
	c.max_hp = 30
	c.hp_phases = [{"below": 67, "abilities": ["bark"]}, {"below": 33, "abilities": ["bite"]}]
	var g := CombatGrid.flat(4, 4)
	var boss := CombatUnit.enemy(c)
	boss.place(Vector2i(1, 1), 0)
	var rng := RandomNumberGenerator.new()
	var ids := func() -> Array:
		return boss.abilities.map(func(a: Ability) -> String: return a.id)
	boss.hp = 21  # 70%: above the first line
	CombatRules.boss_start(rng, g, [boss], 1)
	eq(boss.hp_phase, 0, "above the first line: no change")
	boss.hp = 20  # 66.7%
	var ev := CombatRules.boss_start(rng, g, [boss], 1)
	eq(boss.hp_phase, 1, "at 2/3: the first phase, at the start of its next phase")
	ok(ids.call().has("bark") and ev.any(func(e: Dictionary) -> bool: return e.type == "hp_phase"), "its set comes in")
	boss.hp = 3  # a burst turn: under both lines at once
	CombatRules.boss_start(rng, g, [boss], 1)
	eq(boss.hp_phase, 2, "then the second")
	ok(ids.call().has("bite") and not ids.call().has("bark"), "the second set replaces the first")
	CombatRules.boss_start(rng, g, [boss], 1)
	eq(boss.hp_phase, 2, "and it stays there")
	var one := CombatUnit.enemy(c)
	one.place(Vector2i(2, 2), 0)
	one.hp = 3
	CombatRules.boss_start(rng, g, [one], 1)
	eq(one.hp_phase, 1, "a burst does not skip a phase: one a phase")
	CombatRules.boss_start(rng, g, [one], 1)
	eq(one.hp_phase, 2)


## The wired kit passives and number upgrades: quick hands, bloodied, guard, shield wall, ward hits, poison, command.
func test_wired_kit_passives() -> void:
	var g := CombatGrid.flat(8, 4)
	var shade := _unit("knight", 0, Vector2i(1, 1), g)
	var foe := _unit("bandit", 1, Vector2i(2, 1), g)
	var dmg := func(u: CombatUnit, t: CombatUnit) -> int: return CombatRules.damage_range(g, u, t, u.cell, null, [u, t]).y
	# quick hands: two hits, each a point lighter, and an upgrade adds to each
	var plain := CombatRules.swings(shade, null)
	shade.traits.append(CombatRules.TRAIT_QUICK_HANDS)
	var quick := Db.ability("strike")
	eq(CombatRules.swings(shade, quick), 2, "quick hands swing twice")
	eq(plain, 1)
	shade.upgrades = {"quick_damage": 1, "quick_crit": 5}
	ok(CombatRules.damage_parts(g, shade, foe, shade.cell, quick, [shade, foe]).any(func(p: Array) -> bool: return p[0] == "MOD_QUICK" and p[1] == 1), "the upgrade adds to each hit")
	ok(CombatRules.crit_parts(g, shade, foe, [shade, foe], shade.cell, quick).any(func(p: Array) -> bool: return p[0] == "MOD_QUICK" and p[1] == 5), "and its crit")
	# bloodied: +1 under half, +2 under a quarter, and crit
	var reaver := _unit("knight", 0, Vector2i(1, 2), g)
	reaver.traits.append(CombatRules.TRAIT_BLOODIED)
	eq(CombatRules.bloodied_level(reaver), 0, "healthy: nothing")
	reaver.hp = reaver.max_hp / 2
	eq(CombatRules.bloodied_level(reaver), 1, "under half: +1")
	reaver.hp = maxi(1, reaver.max_hp / 4)
	eq(CombatRules.bloodied_level(reaver), 2, "under a quarter: +2")
	ok(CombatRules.crit_parts(g, reaver, foe, [reaver, foe], reaver.cell).any(func(p: Array) -> bool: return p[0] == "MOD_BLOODIED"), "and more crit")
	# guard armor and taunt armor upgrades, shield wall radius
	var def := _unit("knight", 0, Vector2i(3, 1), g)
	def.statuses[CombatRules.STATUS_GUARD] = 1
	var base := CombatRules.armor_parts(g, foe, def, foe.cell, null, [def, foe]).filter(func(p: Array) -> bool: return p[0] == "MOD_GUARD")[0][1] as int
	def.upgrades = {"guard_armor": 2}
	eq(CombatRules.armor_parts(g, foe, def, foe.cell, null, [def, foe]).filter(func(p: Array) -> bool: return p[0] == "MOD_GUARD")[0][1], base + 2, "GUARD gives its upgrade's armor")
	var wall := _unit("knight", 0, Vector2i(4, 2), g)
	wall.traits.append(CombatRules.TRAIT_SHIELD_WALL)
	var friend := _unit("knight", 0, Vector2i(4, 0), g)
	eq(CombatRules.shield_armor(friend, [wall, friend]), 0, "two tiles away: not covered")
	wall.upgrades = {"shield_wall_radius": 1, "shield_wall_armor": 1}
	eq(CombatRules.shield_armor(friend, [wall, friend]), int(CombatRules.num("shield_wall_armor")) + 1, "the upgrade covers two tiles and adds armor")
	# ward hits and poison
	var mage := _unit("mage", 0, Vector2i(5, 1), g)
	mage.upgrades = {"ward_hits": 1}
	var tgt := _unit("knight", 0, Vector2i(5, 2), g)
	CombatRules.resolve(RandomNumberGenerator.new(), g, mage, Db.ability("ward"), tgt.cell, [mage, tgt])
	eq(tgt.ward_hits, 2, "an upgraded ward blocks two hits")
	var rogue := _unit("knight", 0, Vector2i(6, 1), g)
	rogue.traits.append(CombatRules.TRAIT_POISON_BLADES)
	rogue.upgrades = {"poison_damage": 1, "poison_turns": 1}
	var victim := _unit("bandit", 1, Vector2i(6, 2), g)
	CombatRules.resolve(RandomNumberGenerator.new(), g, rogue, Db.ability("strike"), victim.cell, [rogue, victim])
	eq(int(victim.statuses.get(CombatRules.STATUS_POISON, 0)), int(CombatRules.num("poison_turns")) + 1, "poison lasts longer")
	eq(victim.poison_dmg, int(CombatRules.num("poison_damage")) + 1, "and bites harder")
	# second wind: heals and spends all the rage
	var sw := _unit("knight", 0, Vector2i(7, 1), g)
	sw.hp = 2
	sw.res_kind = "rage"
	sw.res_max = 5
	sw.res = 4
	CombatRules.resolve(RandomNumberGenerator.new(), g, sw, Db.ability("second_wind"), sw.cell, [sw])
	eq(sw.res, 0, "SECOND WIND spends all the rage")
	ok(sw.hp > 2 + 3, "and heals the power plus the rage left")

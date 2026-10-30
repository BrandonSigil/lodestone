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

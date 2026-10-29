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


func test_high_ground_helps_hit_and_damage() -> void:
	var g := CombatGrid.flat(5, 5)
	var a := _unit("knight", 0, Vector2i(1, 1), g)
	var b := _unit("bandit", 1, Vector2i(2, 1), g)
	var units := [a, b]
	var flat_p := CombatRules.hit_chance(g, a, b, units, a.cell)
	var flat_d := CombatRules.damage(g, a, b, a.cell)
	g.set_height(Vector2i(1, 1), 1)
	ok(CombatRules.hit_chance(g, a, b, units, a.cell) > flat_p, "higher hits more")
	eq(CombatRules.damage(g, a, b, a.cell), flat_d + 1)
	g.set_height(Vector2i(1, 1), 2)
	eq(CombatRules.damage(g, a, b, a.cell), flat_d + 1, "two levels up still adds only 1 damage")
	eq(CombatRules.damage(g, b, a, b.cell), maxi(1, CombatRules.damage(CombatGrid.flat(5, 5), b, a, b.cell) - 1), "and takes only 1 from below")


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
	var b := _unit("bandit", 1, Vector2i(5, 1), g)
	ok(not CombatRules.can_attack(g, a, b, a.cell), "5 tiles is out of range on flat ground")
	g.set_height(Vector2i(0, 1), 1)
	ok(CombatRules.can_attack(g, a, b, a.cell), "+1 range from 1 level up")


func test_bow_min_range() -> void:
	var g := CombatGrid.flat(5, 5)
	var a := _unit("hunter", 0, Vector2i(1, 1), g)
	var b := _unit("bandit", 1, Vector2i(2, 1), g)
	ok(not CombatRules.can_attack(g, a, b, a.cell))


func test_forest_cover_and_magic() -> void:
	var g := CombatGrid.flat(5, 5)
	var knight := _unit("knight", 0, Vector2i(1, 1), g)
	var mage := _unit("mage", 0, Vector2i(0, 2), g)
	var b := _unit("bandit", 1, Vector2i(2, 1), g)
	var tn := CombatRules.target_number(g, knight, b)
	g.terrain[g.idx(b.cell)] = CombatGrid.T.FOREST
	eq(CombatRules.target_number(g, knight, b), tn + 2)
	eq(CombatRules.target_number(g, mage, b), b.cls.defense, "magic ignores cover")


func test_flank_bonus() -> void:
	var g := CombatGrid.flat(5, 5)
	var a := _unit("knight", 0, Vector2i(1, 2), g)
	var b := _unit("bandit", 1, Vector2i(2, 2), g)
	var base := CombatRules.hit_bonus(g, a, b, [a, b], a.cell)
	var c := _unit("knight", 0, Vector2i(3, 2), g)
	eq(CombatRules.hit_bonus(g, a, b, [a, b, c], a.cell), base + CombatRules.FLANK_HIT)


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
				for u: CombatUnit in units:
					if u.team != team or not u.alive():
						continue
					var plan := EnemyAi.plan(g, u, units)
					u.place(plan.move, g.height_at(plan.move))
					if plan.target != null:
						CombatRules.attack(rng, g, u, plan.target, units)
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
	var tn := CombatRules.target_number(g, b, k)
	CombatRules.guard(k)
	eq(CombatRules.target_number(g, b, k), tn + CombatRules.GUARD_DEF)
	CombatRules.begin_phase([k, b], 1)
	ok(k.has_status("guard"), "guard lasts through the enemy phase")
	CombatRules.begin_phase([k, b], 0)
	ok(not k.has_status("guard"), "guard ends at own next phase")


func test_cooldown_ticks() -> void:
	var g := CombatGrid.flat(4, 1)
	var k := _unit("knight", 0, Vector2i(0, 0), g)
	var b := _unit("bandit", 1, Vector2i(1, 0), g)
	var shove := _ab("shove")
	CombatRules.resolve(RandomNumberGenerator.new(), g, k, shove, b.cell, [k, b])
	ok(not k.can_use(shove), "on cooldown")
	for i in shove.cooldown:
		CombatRules.begin_phase([k, b], 0)
	ok(k.can_use(shove), "ready after %d phases" % shove.cooldown)


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


func test_heal_item_spends_supplies() -> void:
	var g := CombatGrid.flat(3, 1)
	var k := _unit("knight", 0, Vector2i(0, 0), g)
	k.hp = 5
	var salve: Ability = Db.combat_items["salve"]
	var sup := {"medicine": 1}
	ok(CombatRules.usable(k, salve, sup))
	CombatRules.resolve(RandomNumberGenerator.new(), g, k, salve, k.cell, [k], sup)
	eq(k.hp, 5 + salve.power)
	eq(sup.medicine, 0)
	ok(not CombatRules.usable(k, salve, sup), "out of medicine")
	k.hp = k.max_hp - 1
	sup.medicine = 1
	CombatRules.resolve(RandomNumberGenerator.new(), g, k, salve, k.cell, [k], sup)
	eq(k.hp, k.max_hp, "heal caps at max")


func test_mercy_bonus() -> void:
	CombatRules.reset_switches()
	var g := CombatGrid.flat(3, 1)
	var k := _unit("knight", 0, Vector2i(0, 0), g)
	var b := _unit("bandit", 1, Vector2i(1, 0), g)
	var base := CombatRules.hit_bonus(g, k, b, [k, b], k.cell)
	k.miss_streak = 5
	eq(CombatRules.hit_bonus(g, k, b, [k, b], k.cell), base + CombatRules.MERCY_MAX)
	b.miss_streak = 5
	eq(CombatRules.hit_bonus(g, b, k, [k, b], b.cell), CombatRules.hit_bonus(g, b, k, [k, b], b.cell), "enemies get no mercy")
	ok(CombatRules.hit_parts(g, b, k, [k, b], b.cell).all(func(p: Array) -> bool: return p[0] != "MOD_MERCY"))
	CombatRules.mercy = false
	eq(CombatRules.hit_bonus(g, k, b, [k, b], k.cell), base)
	CombatRules.reset_switches()


func test_scaling_mods() -> void:
	var c: ClassDef = load("res://data/classes/bandit.tres")
	var u := CombatUnit.enemy(c, {"hp_pct": 150, "attack": 2, "defense": 1, "damage": 1, "move": -1})
	eq(u.max_hp, int(round(c.max_hp * 1.5)))
	eq(u.attack, c.attack + 2)
	eq(u.defense, c.defense + 1)
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
	var h := _unit("hunter", 0, Vector2i(0, 0), g)  # range 4
	var b := _unit("bandit", 1, Vector2i(7, 0), g)
	ok(CombatRules.can_attack(g, h, b, h.cell), "4 + 3")
	b.place(Vector2i(8, 0), 0)
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

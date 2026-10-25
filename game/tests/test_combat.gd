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


func test_melee_cant_reach_cliff() -> void:
	var g := CombatGrid.flat(5, 5)
	var a := _unit("knight", 0, Vector2i(1, 1), g)
	var b := _unit("bandit", 1, Vector2i(2, 1), g)
	g.set_height(Vector2i(2, 1), 3)
	ok(not CombatRules.can_attack(g, a, b, a.cell))


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

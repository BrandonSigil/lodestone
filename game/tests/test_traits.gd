extends TestCase
## Character traits and caster spell picks.


func _char(id: String, team: int, c: Vector2i, grid: CombatGrid) -> CombatUnit:
	var u := CombatUnit.from_def(Db.character(StringName(id)))
	u.team = team
	u.place(c, grid.height_at(c))
	return u


func _cls(id: String, team: int, c: Vector2i, grid: CombatGrid) -> CombatUnit:
	var u := CombatUnit.enemy(Db.class_def(id))
	u.team = team
	u.place(c, grid.height_at(c))
	return u


## An rng whose next few d20s are plain rolls (no natural 1 or 20), so a big bonus always hits for normal damage.
func _plain_rng() -> RandomNumberGenerator:
	for s in range(1, 500):
		var r := RandomNumberGenerator.new()
		r.seed = s
		var fine := true
		for i in 4:
			var roll := r.randi_range(1, 20)
			if roll == 1 or roll == 20:
				fine = false
		if fine:
			var out := RandomNumberGenerator.new()
			out.seed = s
			return out
	return RandomNumberGenerator.new()


func _ids(u: CombatUnit) -> Array:
	return u.abilities.map(func(a: Ability) -> String: return a.id)


func test_casters_bring_default_spells() -> void:
	var g := CombatGrid.flat(5, 5)
	var s := _char("stardrop", 0, Vector2i(0, 0), g)
	eq(_ids(s), ["strike", "moonbeam", "moon_veil"])
	var w := _char("wizard", 0, Vector2i(1, 0), g)
	eq(_ids(w), ["strike", "fireball", "mend"])
	var k := _char("lead", 0, Vector2i(2, 0), g)
	eq(k.spells.size(), 0)


func test_spell_picks_respect_pool_and_slots() -> void:
	var u := CombatUnit.from_def(Db.character(&"stardrop"), {}, ["moon_sleep", "fireball", "star_guide", "moon_tide"])
	eq(_ids(u), ["strike", "moon_sleep", "star_guide"], "fireball is not a moon spell, third pick has no slot")
	u.set_spells(["moon_tide"])
	eq(_ids(u), ["strike", "moon_tide"], "one spell is a fine loadout")
	u.set_spells(["", "moonbeam"])
	eq(_ids(u), ["strike", "moonbeam"], "empty slots are skipped")


func test_sleep_skips_turn_and_wakes_on_damage() -> void:
	var g := CombatGrid.flat(6, 3)
	var s := CombatUnit.from_def(Db.character(&"stardrop"), {}, ["moon_sleep"])
	s.place(Vector2i(0, 1), 0)
	s.attack = 50
	var b := _cls("bandit", 1, Vector2i(3, 1), g)
	var units := [s, b]
	var sleep := Db.ability("moon_sleep")
	var ev := CombatRules.resolve(_plain_rng(), g, s, sleep, b.cell, units)
	ok(b.has_status(CombatRules.STATUS_SLEEP), "slept")
	eq(b.hp, b.max_hp, "a hex does no damage")
	eq(ev.filter(func(e: Dictionary) -> bool: return e.type == "counter").size(), 0)
	CombatRules.begin_phase(units, 1)
	ok(b.done(), "sleeper loses its turn")
	eq(CombatRules.move_points(b), 0)
	ok(not CombatRules.danger_zone(g, units, 1).has(s.cell), "a sleeper threatens nothing")
	var k := _cls("knight", 0, Vector2i(2, 1), g)
	units.append(k)
	ok(not CombatRules.counters_from(g, k, b, k.cell), "no counter while asleep")
	k.attack = 50
	CombatRules.resolve(_plain_rng(), g, k, k.abilities[0], b.cell, units)
	ok(not b.has_status(CombatRules.STATUS_SLEEP), "damage wakes it")
	CombatRules.end_phase(units, 1)


func test_sleep_wears_off_after_one_phase() -> void:
	var g := CombatGrid.flat(5, 5)
	var b := _cls("bandit", 1, Vector2i(3, 1), g)
	b.statuses[CombatRules.STATUS_SLEEP] = 1
	CombatRules.begin_phase([b], 1)
	ok(b.done())
	CombatRules.end_phase([b], 1)
	CombatRules.begin_phase([b], 1)
	ok(not b.done(), "awake next phase")


func test_shield_wall_guards_neighbours() -> void:
	var g := CombatGrid.flat(6, 3)
	var lead := _char("lead", 0, Vector2i(1, 1), g)
	var hunter := _char("hunter", 0, Vector2i(2, 1), g)
	var b := _cls("bandit", 1, Vector2i(3, 1), g)
	var units := [lead, hunter, b]
	var wall := int(CombatRules.num("shield_wall_armor"))
	eq(CombatRules.armor_parts(g, b, hunter, b.cell, null, units), [["MOD_ARMOR", hunter.armor], ["MOD_SHIELD", wall]])
	hunter.place(Vector2i(4, 1), 0)
	eq(CombatRules.armor_parts(g, b, hunter, Vector2i(3, 1), null, units), [["MOD_ARMOR", hunter.armor]], "too far from the Lead")
	ok(CombatRules.armor_parts(g, b, lead, Vector2i(2, 1), null, units).all(func(p: Array) -> bool: return p[0] != "MOD_SHIELD"), "the Lead doesn't shield itself")


func test_steady_aim_only_when_still() -> void:
	var g := CombatGrid.flat(6, 3)
	var h := _char("hunter", 0, Vector2i(0, 1), g)
	var b := _cls("bandit", 1, Vector2i(3, 1), g)
	var units := [h, b]
	var still := CombatRules.crit_chance(g, h, b, units, h.cell)
	var steady := CombatRules.num("crit_steady") / 100.0
	eq(CombatRules.crit_chance(g, h, b, units, Vector2i(1, 1)), still - steady, "previewing a move loses it")
	h.moved = true
	eq(CombatRules.crit_chance(g, h, b, units, h.cell), still - steady)


func test_starlit_needs_height() -> void:
	var g := CombatGrid.flat(6, 3)
	var s := _char("stardrop", 0, Vector2i(0, 1), g)
	var b := _cls("bandit", 1, Vector2i(3, 1), g)
	var beam := Db.ability("moonbeam")
	var low := CombatRules.damage(g, s, b, s.cell, beam)
	g.set_height(Vector2i(0, 1), 2)
	g.set_height(Vector2i(3, 1), 2)
	eq(CombatRules.damage(g, s, b, s.cell, beam), low + 1)
	eq(CombatRules.damage(g, s, b, s.cell, s.abilities[0]), s.damage - b.armor, "the basic hit is not a spell")


func test_scholar_boosts_spells() -> void:
	var g := CombatGrid.flat(6, 3)
	var w := _char("wizard", 0, Vector2i(0, 1), g)
	var b := _cls("bandit", 1, Vector2i(3, 1), g)
	eq(CombatRules.damage(g, w, b, w.cell, Db.ability("firebolt")), w.damage + 2 + 1 - b.armor)
	eq(CombatRules.heal_amount(w, Db.ability("mend")), 5)


func test_deep_roots_resists_push_and_regrows() -> void:
	var g := CombatGrid.flat(6, 3)
	var bush := _char("bushberry", 1, Vector2i(2, 1), g)
	var ev := CombatRules.push(g, [bush], Vector2i(1, 1), bush, 2)
	eq(ev.size(), 0)
	eq(bush.cell, Vector2i(2, 1))
	bush.hp = 2
	var heals := CombatRules.begin_phase([bush], 1)
	eq(bush.hp, 3)
	eq(heals.size(), 1)


func test_flammable_takes_more_fire() -> void:
	var g := CombatGrid.flat(6, 3)
	var w := _char("wizard", 1, Vector2i(0, 1), g)
	var bush := _char("bushberry", 0, Vector2i(3, 1), g)
	var lead := _char("lead", 0, Vector2i(3, 0), g)
	var fire := Db.ability("firebolt")
	bush.armor = 0
	lead.armor = 0
	eq(CombatRules.damage(g, w, bush, w.cell, fire) - CombatRules.damage(g, w, lead, w.cell, fire), CombatRules.FLAMMABLE_DMG)


func test_bones_shrug_off_arrows() -> void:
	var g := CombatGrid.flat(6, 3)
	var skel := _char("skeleton_archer", 0, Vector2i(0, 1), g)
	var archer := _cls("bandit_archer", 1, Vector2i(3, 1), g)
	var bandit := _cls("bandit", 1, Vector2i(1, 1), g)
	skel.armor = 0
	ok(skel.tags.has(&"undead"), "bones make it undead")
	eq(CombatRules.damage(g, archer, skel, archer.cell), maxi(1, archer.damage - 2))
	eq(CombatRules.damage(g, bandit, skel, bandit.cell), bandit.damage, "melee hits full")


func test_double_strike_swings_twice() -> void:
	var g := CombatGrid.flat(6, 3)
	var duo := _char("lewith_flark", 0, Vector2i(1, 1), g)
	duo.attack = 50
	var b := _cls("bandit", 1, Vector2i(2, 1), g)
	b.max_hp = 99
	b.hp = 99
	var units := [duo, b]
	var f := CombatRules.forecast(g, duo, duo.abilities[0], b.cell, units, duo.cell)
	eq(f.targets[0].swings, 2)
	eq(f.targets[0].dmg, duo.damage - 1 - b.armor)
	CombatRules.counters = false
	var ev := CombatRules.resolve(_plain_rng(), g, duo, duo.abilities[0], b.cell, units)
	CombatRules.reset_switches()
	var hits := ev.filter(func(e: Dictionary) -> bool: return e.type == "hit")
	eq(hits.size(), 2)
	var taken := 0
	for e: Dictionary in hits:
		taken += int(e.amount)
	eq(b.hp, 99 - taken, "both blows land")


func test_wolf_pack_bites_harder_when_flanking() -> void:
	var g := CombatGrid.flat(6, 3)
	var wolf := _cls("wolf", 1, Vector2i(1, 1), g)
	var h := _char("hunter", 0, Vector2i(2, 1), g)
	var units := [wolf, h]
	var alone := CombatRules.damage(g, wolf, h, wolf.cell, null, units)
	units.append(_cls("bandit", 1, Vector2i(3, 1), g))
	eq(CombatRules.damage(g, wolf, h, wolf.cell, null, units), alone + 1)


func test_ai_uses_new_spells() -> void:
	var g := CombatGrid.flat(7, 3)
	var s := CombatUnit.from_def(Db.character(&"stardrop"), {}, ["moon_sleep"])
	s.team = 1
	s.place(Vector2i(0, 1), 0)
	var k := _char("lead", 0, Vector2i(4, 1), g)
	var p := EnemyAi.plan(g, s, [s, k])
	ok(p.ability != null, "found something to do")


func test_sandbox_spell_picks_save() -> void:
	var setup := SandboxSetup.default_setup()
	eq(setup.spells_of("stardrop"), ["moonbeam", "moon_veil"])
	setup.set_spell("stardrop", 1, "moon_sleep")
	setup.set_spell("stardrop", 0, "moon_sleep")
	eq(setup.spells_of("stardrop"), ["moon_sleep", ""], "a spell sits in one slot only")
	var back := SandboxSetup.from_dict(JSON.parse_string(JSON.stringify(setup.to_dict())))
	eq(back.spells_of("stardrop"), ["moon_sleep", ""])
	for u: CombatUnit in back.build_units():
		if u.name_key == "CHAR_STARDROP":
			eq(_ids(u), ["strike", "moon_sleep"])


func test_sim_runs_with_every_spell() -> void:
	var setup := SandboxSetup.default_setup()
	setup.place_party("wizard", setup.grid.deploy_cells(0)[3])
	setup.set_spell("stardrop", 0, "moon_sleep")
	setup.set_spell("stardrop", 1, "star_guide")
	setup.set_spell("wizard", 0, "firebolt")
	setup.set_spell("wizard", 1, "frost_bind")
	var r := setup.simulate(3)
	ok(r.winner in [0, 1, -1])
	setup.set_spell("stardrop", 0, "moon_tide")
	r = setup.simulate(4)
	ok(r.rounds > 0)


## Foe tags ([USER] design-foe-weakness, data/tags.csv): applied with the other parts, at least 1 gets through.
func test_foe_tags_change_damage_by_attack_kind() -> void:
	var g := CombatGrid.flat(6, 3)
	var bandit := _cls("bandit", 0, Vector2i(1, 1), g)
	var archer := _cls("bandit_archer", 0, Vector2i(4, 1), g)
	var wolf := _cls("wolf", 1, Vector2i(2, 1), g)
	var plain := _cls("bandit", 1, Vector2i(2, 1), g)
	plain.armor = wolf.armor
	eq(CombatRules.damage(g, bandit, wolf, bandit.cell) - CombatRules.damage(g, bandit, plain, bandit.cell), 1, "beast: blades +1")
	var bone := _cls("lich_minion", 1, Vector2i(2, 1), g)
	var lich := _cls("lich", 1, Vector2i(2, 1), g)
	ok(lich.tags.has(&"undead"), "the Lich is undead ([USER] design-lich-tag)")
	var p := CombatRules.damage_parts(g, archer, bone, archer.cell)
	ok(p.has(["FOE_UNDEAD", -2]), "undead: arrows -2, shown as a part")
	var mage := _cls("wizard", 0, Vector2i(0, 1), g)
	var fire := Db.ability("firebolt")
	ok(CombatRules.damage_parts(g, mage, bone, mage.cell, fire).has(["FOE_UNDEAD", 2]), "undead: fire +2")
	var moon := Db.ability("moonbeam")
	ok(not CombatRules.damage_parts(g, mage, bone, mage.cell, moon).any(func(x: Array) -> bool: return x[0] == "FOE_UNDEAD"), "other spells: no change")
	bone.armor = 9
	eq(CombatRules.damage(g, archer, bone, archer.cell), 1, "at least 1 gets through")

extends TestCase


func test_setup_round_trip() -> void:
	var s := SandboxSetup.default_setup()
	s.apply_preset("HARD")
	s.party_mods.damage = 2
	s.mercy = false
	var back := SandboxSetup.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	eq(back.party.size(), s.party.size())
	eq(back.enemies[0].cell, s.enemies[0].cell)
	eq(back.enemy_mods, s.enemy_mods)
	eq(back.party_mods.damage, 2)
	eq(back.extra_enemies, s.extra_enemies)
	eq(back.mercy, false)
	eq(back.grid.heights, s.grid.heights)


func test_build_units_and_extras() -> void:
	var s := SandboxSetup.default_setup()
	var base := s.build_units().size()
	s.extra_enemies = 2
	eq(s.build_units().size(), base + 2)
	s.place_party("lead", s.enemies[0].cell)
	eq(s.build_units().filter(func(u: CombatUnit) -> bool: return u.team == 0).size(), 3, "placing a member moves them")


func test_editing() -> void:
	var s := SandboxSetup.default_setup()
	var c: Vector2i = s.party[0].cell
	s.grid.set_terrain(c, CombatGrid.T.ROCK)
	s.clean()
	ok(s.entry_at(c).is_empty(), "rock clears the piece")
	s.resize(4, 4)
	ok(s.enemies.all(func(e: Dictionary) -> bool: return s.grid.in_bounds(e.cell)), "resize drops pieces outside")


func test_simulate_reports() -> void:
	var s := SandboxSetup.default_setup()
	var t := {}
	for i in 4:
		SandboxSetup.tally(t, s.simulate(i))
	eq(t.fights, 4)
	ok(SandboxSetup.describe_tally(t).begins_with("PARTY WINS"))
	CombatRules.reset_switches()


func test_saved_maps_load() -> void:
	for p in SandboxSetup.list_maps():
		var s := SandboxSetup.load_file(p)
		ok(s != null and s.grid.w > 0, p)
		if s:
			ok(not s.build_units().is_empty(), "units in " + p)

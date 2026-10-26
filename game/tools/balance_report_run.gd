extends RefCounted


func run(args: PackedStringArray) -> void:
	if Db.abilities.is_empty():
		Db.reload()
	var n := int(args[0]) if args.size() > 0 else 100
	var setups: Array = []
	for p in SandboxSetup.list_maps():
		setups.append(SandboxSetup.load_file(p))
	if setups.is_empty():
		setups.append(SandboxSetup.default_setup())
	for s: SandboxSetup in setups:
		for preset in SandboxSetup.PRESETS:
			s.apply_preset(preset)
			for sw in [[true, true], [true, false], [false, false]]:
				s.counters = sw[0]
				s.mercy = sw[1]
				var t := {}
				for i in n:
					SandboxSetup.tally(t, s.simulate(i))
				print("%-10s %-7s counters=%-5s luck=%-5s | %s" % [s.map_name, preset, sw[0], sw[1],
					SandboxSetup.describe_tally(t).replace("\n", " | ")])
	CombatRules.reset_switches()

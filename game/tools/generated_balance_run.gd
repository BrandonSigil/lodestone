extends RefCounted
## AI-vs-AI results on generated maps, plain rectangles against irregular outlines.


func run(args: PackedStringArray) -> void:
	if Db.abilities.is_empty():
		Db.reload()
	var seeds := int(args[0]) if args.size() > 0 else 20
	var fights := int(args[1]) if args.size() > 1 else 10
	for outline in [false, true]:
		var t := {}
		for s in seeds:
			var setup := SandboxSetup.default_setup()
			setup.grid = CombatGrid.generate(s * 31 + 1, 10, 8, 0.0, outline)
			setup.clean()
			var spots := setup.grid.deploy_cells(0)
			for p in setup.party:
				if not spots.is_empty():
					p.cell = spots.pop_front()
			var es := setup.grid.deploy_cells(1)
			for e in setup.enemies:
				if not es.is_empty():
					e.cell = es.pop_front()
			for i in fights:
				SandboxSetup.tally(t, setup.simulate(i))
		print("outline=%-5s | %s" % [outline, SandboxSetup.describe_tally(t).replace("\n", " | ")])
	CombatRules.reset_switches()

extends RefCounted
## Loaded at runtime by spell_report.gd (a -s script can't name autoload-backed classes at compile time).


func run(args: PackedStringArray) -> void:
	Db.reload()
	var n := int(args[0]) if args.size() > 0 else 100
	for caster in ["stardrop", "wizard"]:
		var pool: Array = Array(Db.character(StringName(caster)).class_def.spell_pool)
		var loadouts := []
		for i in pool.size():
			loadouts.append([pool[i]])
			for j in range(i + 1, pool.size()):
				loadouts.append([pool[i], pool[j]])
		for picks in loadouts:
			var s := SandboxSetup.load_file("res://data/maps/default.json")
			if caster == "wizard":
				for p in s.party:
					if p.id == "hunter":
						p.id = "wizard"
			for slot in 2:
				s.set_spell(caster, slot, String(picks[slot]) if slot < picks.size() else "")
			var t := {}
			for i in n:
				SandboxSetup.tally(t, s.simulate(1000 + i))
			print("%-9s %-24s | %s" % [caster, " + ".join(picks), s.describe_tally(t).replace("\n", " | ")])

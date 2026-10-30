extends RefCounted
## Road fights (a 14 x 12 snow valley per seed, party first) of the hero and dog, and of four pieces, against groups.

const GROUPS := ["bandits", "wolves", "casters", "warded", "chargers", "charge_mix"]


func run(args: PackedStringArray) -> void:
	if Db.abilities.is_empty():
		Db.reload()
	var n := int(args[0]) if args.size() > 0 else 120
	var study: RefCounted = load("res://tools/scale_study_run.gd").new()
	print("| party | foes | win %% | close %% | stalls %% | rounds |  (%d fights each)" % n)
	for who in ["duo", "four"]:
		for enc in GROUPS:
			var wins := 0
			var stalls := 0
			var close := 0
			var rounds := 0
			for i in n:
				var party: Array = study.call("_party_of", who)
				var r: Dictionary = study.call("_road", MapGen.valley(i, 14, 12, "snow"), party, enc, i)
				wins += 1 if r.winner == 0 else 0
				stalls += 1 if r.winner == -1 else 0
				close += 1 if r.winner == 0 and (r.downs > 0 or r.party_pct < 40.0) else 0
				rounds += int(r.rounds)
			print("| %s | %s | %d | %d | %d | %.1f |" % [who, enc, roundi(100.0 * wins / n), roundi(100.0 * close / n), roundi(100.0 * stalls / n), float(rounds) / n])

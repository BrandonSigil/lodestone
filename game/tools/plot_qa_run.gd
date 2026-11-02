extends RefCounted
## The plot QA tool's body (tools/plot_qa.gd), loaded once the autoloads exist.


func run(args: PackedStringArray) -> int:
	var seeds := 12
	for a in args:
		if a.begins_with("--seeds="):
			seeds = int(a.get_slice("=", 1))
	var bad := false
	for k in args:
		if k.begins_with("--"):
			continue
		var region := k.get_slice("/", 0)
		var plot := MapPlot.load_file("res://data/plots/%s.json" % k)
		if plot.is_empty():
			print("FAIL no plot %s" % k)
			bad = true
			continue
		var probs := MapPlot.problems(plot)
		print("%s  plot problems: %s" % [k, str(probs) if not probs.is_empty() else "none"])
		var raw := MapPlot.build(plot, 1, region, false)  # no link, no seal: what the plot itself leaves cut off
		var got := MapOps.walk_steps(raw, raw.deploy_cells(0)[0])
		var orphans: Array[String] = []
		for y in raw.h:
			for x in raw.w:
				var c := Vector2i(x, y)
				if raw.passable(c) and not got.has(c):
					orphans.append("%d,%d" % [x, y])
		print("  cut off by the plot itself: %d %s" % [orphans.size(), str(orphans.slice(0, 24))])
		var tally := {}
		var first := {}
		var sealed_total := 0
		var plot_rocks := 0
		for row in plot.marks:
			plot_rocks += String(row).count("r")
		for sd in seeds:
			var g := MapPlot.build(plot, sd * 7919 + 1, region)
			if sd == 0 and args.has("--dump"):
				for y in g.h:
					var row := ""
					for x in g.w:
						var c := Vector2i(x, y)
						var t := g.terrain_at(c)
						row += "#" if t == CombatGrid.T.ROCK else ("~" if t == CombatGrid.T.WATER else (" " if t == CombatGrid.T.VOID else str(g.height_at(c) % 10)))
					print("    " + row)
			var sealed := 0
			for y in g.h:
				for x in g.w:
					if g.terrain_at(Vector2i(x, y)) == CombatGrid.T.ROCK:
						sealed += 1
			sealed_total += sealed
			var doc := MapDoc.create("battle", "plot_qa", g, region)
			for c: Dictionary in MapQA.run(g, "battle", doc.data):
				if c.level != "ok":
					tally[c.id] = int(tally.get(c.id, 0)) + 1
					if not first.has(c.id):
						first[c.id] = "seed %d: %s" % [sd, c.summary]
		print("  rock cells per seed: %.1f (the plot draws %d; the rest were cut off and sealed into pillars)" % [float(sealed_total) / seeds, plot_rocks])
		if tally.is_empty():
			print("  all %d seeds clean" % seeds)
		for id in tally:
			bad = true
			print("  %-10s fails %d of %d  (%s)" % [id, tally[id], seeds, first[id]])
	return 1 if bad else 0

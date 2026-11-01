extends RefCounted
## The map QA tool's body (tools/map_qa.gd), loaded once the autoloads exist.


func run(args: PackedStringArray) -> int:
	var all := args.has("--all")
	var bad := false
	for k in args:
		if k.begins_with("--"):
			continue
		var d := MapDoc.load_path(k)
		if d == null:
			print("FAIL no map %s" % k)
			bad = true
			continue
		var res := MapQA.run(d.grid, d.kind, d.data)
		var w := MapQA.worst(res)
		bad = bad or w == "fail"
		print("%s %s (%s, %d x %d)" % ["ok  " if w == "ok" else w.to_upper(), k, d.kind, d.grid.w, d.grid.h])
		for c: Dictionary in res:
			print("  %-4s %-22s %s" % [c.level, c.name, c.summary])
			var probs: Array = c.problems
			for p: Dictionary in (probs if all else probs.slice(0, 3)):
				print("         %d,%d  %s" % [p.cell.x, p.cell.y, p.text])
	return 1 if bad else 0

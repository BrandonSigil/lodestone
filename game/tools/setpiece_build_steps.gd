extends RefCounted
## The work of tools/setpiece_build.gd (a -s script can't name game classes before the autoloads exist).
## A sketch: {"id", "art_set", "look", "note", "levels" and "marks" (a plot's two layers, MapPlot), "stones" [[x, y]]
## (a stepping stone standing in the water), "docks" [[x, y]] (a plank deck over the water), "climbs" [[x, y]],
## "slopes" [[x, y]] (a grassy bank, MapOps.slope), "ruins" [[x, y]] (a broken wall stub), "paving" [[x, y]] (flagstones), "props" [{"sprite" or "blob" (a named placeholder), "cell", "foot", "tall", "sight", "walk"}],
## "party" [[x, y]] (walked in), "out" [[x, y]] (saw them first), "foes" [{"id", "cell", "hidden", "leader", "post"}],
## "exit" [[x, y]]}.


func bake(path: String, force: bool) -> String:
	if Db.items.is_empty():
		Db.reload()
	var src: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not src is Dictionary:
		return "FAIL %s: not a sketch" % path
	var d: Dictionary = src
	var name := "sp_" + String(d.id)
	var out := "res://data/maps/%s.json" % name
	if FileAccess.file_exists(out) and not force:
		return "kept %s (already baked; --force to bake over it)" % name
	var look := String(d.get("look", "forest"))
	var grid := MapPlot.build({"levels": d.levels, "marks": d.marks, "flip": false}, 1, look, false, true)  # joined below, once its own stairs are in
	var T := CombatGrid.T
	for c in d.get("stairs", []):  # each its own stair, so cells side by side make one wide flight
		if not MapOps.stairs(grid, Vector2i(int(c[0]), int(c[1]))):
			push_warning("stair %s has nothing to climb" % [c])
	for c in d.get("slopes", []):  # a grassy bank from this cell's level up to the terrace beside it
		if not MapOps.slope(grid, Vector2i(int(c[0]), int(c[1]))):
			push_warning("slope %s can't tilt (water, rock or no ground)" % [c])
	for c in d.get("ruins", []):  # a broken wall stub, a level above the ground it stands on
		var cell := Vector2i(int(c[0]), int(c[1]))
		grid.set_terrain(cell, T.RUIN)
		grid.set_height(cell, grid.height_at(cell) + 2)
	for c in d.get("paving", []):
		grid.set_terrain(Vector2i(int(c[0]), int(c[1])), T.STONE)
	MapOps.link(grid, 6, 1, false)  # whatever the sketch's own stairs leave cut off (none, in a finished piece)
	MapOps.seal_unreachable(grid)
	for c in d.get("stones", []):
		var cell := Vector2i(int(c[0]), int(c[1]))
		grid.set_terrain(cell, T.STONE)
		grid.set_height(cell, grid.height_at(cell) + 1)
	for c in d.get("docks", []):
		var cell := Vector2i(int(c[0]), int(c[1]))
		grid.add_deck(cell, grid.height_at(cell) + 1, T.ROAD, false)  # a plank dock: no rails
	for p: Dictionary in d.get("props", []):
		var cell := Vector2i(int(p.cell[0]), int(p.cell[1]))
		var foot := Vector2i(int(p.get("foot", [1, 1])[0]), int(p.get("foot", [1, 1])[1]))
		var extra := {}
		var sprite := String(p.get("sprite", ""))
		if p.has("blob"):
			var slug := SandboxSetup.safe_name(String(p.blob))
			sprite = "ph_" + slug
			extra = {"blob": true, "name": String(p.blob), "id": slug}
		for k in ["face", "flip"]:
			if p.has(k):
				extra[k] = p[k]
		MapOps.add_prop(grid, cell, sprite, foot, float(p.get("tall", 0.8)), float(p.get("sight", 0.0)), bool(p.get("walk", false)), extra)
	var s := SandboxSetup.new()
	s.map_name = name
	s.grid = grid
	s.art_set = String(d.get("art_set", look))
	s.counters = false
	var problems: PackedStringArray = []
	var taken := {}
	var cells := func(list: Array, what: String) -> Array:
		var got: Array = []
		for c in list:
			var cell := Vector2i(int(c[0]), int(c[1]))
			if not grid.passable(cell) or taken.has(cell):
				problems.append("%s %s can't stand there" % [what, cell])
				continue
			got.append(cell)
		return got
	var ids := ["lead", "stardrop", "hunter", "knight"]
	var i := 0
	for cell: Vector2i in cells.call(d.get("party", []), "party"):
		s.party.append({"id": ids[i % ids.size()] if i < ids.size() else "class:nobody", "cell": cell})
		taken[cell] = true
		i += 1
	for f: Dictionary in d.get("foes", []):
		var cell := Vector2i(int(f.cell[0]), int(f.cell[1]))
		if Db.class_def(String(f.id)) == null or not grid.passable(cell) or taken.has(cell):
			problems.append("foe %s %s can't stand there" % [f.id, cell])
			continue
		var e := {"id": String(f.id), "cell": cell}
		for flag in ["hidden", "leader", "post"]:
			if bool(f.get(flag, false)):
				e[flag] = true
		s.enemies.append(e)
		taken[cell] = true
	s.piece = {"out": [], "exit": []}
	for cell: Vector2i in cells.call(d.get("out", []), "out start"):
		s.piece.out.append([cell.x, cell.y])
	for c in d.get("exit", []):
		s.piece.exit.append([int(c[0]), int(c[1])])
	if d.has("note"):
		s.piece["note"] = String(d.note)
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(s.to_dict(), "\t"))
	f.close()
	# every start must reach every foe on foot, both ways in
	var reach := MapOps.reach(grid, s.party[0].cell if not s.party.is_empty() else Vector2i.ZERO, 1)
	for e in s.enemies:
		if not reach.has(e.cell):
			problems.append("foe %s at %s is cut off from the party" % [e.id, e.cell])
	for c in s.piece.out:
		if not reach.has(Vector2i(int(c[0]), int(c[1]))):
			problems.append("out start %s is cut off" % [c])
	return "baked %s  %dx%d  party %d  out %d  foes %d%s" % [name, grid.w, grid.h, s.party.size(), s.piece.out.size(), s.enemies.size(),
		"" if problems.is_empty() else "\n  PROBLEMS: " + "; ".join(problems)]

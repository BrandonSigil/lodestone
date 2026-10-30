extends RefCounted
## The work of tools/dress_explore.gd (game classes load at runtime there).


func run(args: PackedStringArray) -> void:
	var name := args[0]
	var path := ExploreMap.DIR + name + ".json"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var grid := CombatGrid.from_dict(data.grid)
	var cells := {}  # thing and group cells by id
	var keep := {}
	var marks: Array = []
	for t: Dictionary in data.get("things", []):
		cells[t.id] = Vector2i(int(t.cell[0]), int(t.cell[1]))
		marks.append(cells[t.id])
		if t.has("at") and String(t.get("to", "")) == name:
			marks.append(Vector2i(int(t.at[0]), int(t.at[1])))  # a rope's landing on this same map
	for g: Dictionary in data.get("groups", []):
		for u: Dictionary in g.units:
			marks.append(Vector2i(int(u.cell[0]), int(u.cell[1])))
	for s: Array in data.get("start", []):
		marks.append(Vector2i(int(s[0]), int(s[1])))
	for c: Vector2i in marks:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				keep[c + Vector2i(dx, dy)] = true
	var tidied := MapOps.tidy(grid, keep)
	var road: Array[Vector2i] = []
	if args.size() >= 3 and cells.has(args[1]) and cells.has(args[2]):
		road = MapOps.road(grid, _beside(grid, cells[args[1]]), _beside(grid, cells[args[2]]))
	for c in road:
		keep[c] = true
	var poles := MapOps.pillars(grid, name.hash(), int(args[3]) if args.size() > 3 else 3, keep, int(args[4]) if args.size() > 4 else MapOps.PILLAR_MAX)
	data.grid = grid.to_dict()
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, " ") + "\n")
	print("dressed %s: %d cells tidied, road %d cells, pillars %s" % [name, tidied, road.size(), poles])


## A walkable cell next to a thing (things stand on cells the party uses from beside).
func _beside(grid: CombatGrid, c: Vector2i) -> Vector2i:
	for d: Vector2i in CombatRules.DIRS:
		if grid.passable(c + d) and grid.terrain_at(c + d) != CombatGrid.T.WATER:
			return c + d
	return c

extends SceneTree
## Prints every walkable ground cell of an explore map that nobody can walk to from the start (the game's own walking:
## places, jump 1, stairs), one `LOST x y` per line: godot --headless --path game -s res://tools/lost_cells.gd -- <map>
## The village builders use it to clear stray cells after they reshape a map.


func _init() -> void:
	var m := ExploreMap.load_named(OS.get_cmdline_user_args()[0])
	var g := m.grid
	var seen := {m.start[0]: true}
	var todo: Array[Vector2i] = [m.start[0]]
	while not todo.is_empty():
		var p: Vector2i = todo.pop_back()
		for d in CombatRules.DIRS:
			for q in g.places_next(p, d):
				if not seen.has(q) and g.walkable(q) and g.can_step(p, q, 1):
					seen[q] = true
					todo.append(q)
	for y in g.h:
		for x in g.w:
			for q in g.places_at(Vector2i(x, y)):
				if g.walkable(q) and not seen.has(q) and not g.perch(q):
					print("LOST %d %d %d" % [x, y, 1 if CombatGrid.on_deck(q) else 0])
	quit()

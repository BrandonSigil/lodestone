extends RefCounted
## Explore scene states for tools/explore_shot.gd. Returns true on the frame to save.


func _put(s: Node, c: Vector2i) -> void:
	var lead: CombatUnit = s.leader()
	lead.place(c, s.grid.height_at(c))
	s._refresh_sight()
	s._refresh_units()
	s.focus = s.board.cell_top(c)


func _thing(s: Node, id: String) -> Dictionary:
	for t: Dictionary in s.things:
		if t.id == id:
			return t
	return {}


func run(s: Node, f: int, step: String) -> bool:
	match step:
		"start":
			return f == 20
		"walk":
			# Walk into the yard and up to the gate for real (pathing, steps, fog as it goes).
			if f == 5:
				var p: Array[Vector2i] = ExploreRules.find_path(s.grid, s.leader().cell, Vector2i(26, 21), s.leader().jump, s._blocked(), s.seen)
				s.walk(p)
			return f == 120
		"door":
			if f == 5:
				_put(s, Vector2i(26, 19))
				s._go_use(_thing(s, "gate"))
			return f == 20
		"spot":
			# Gate open, the leader walks into the plaza: the bandits are seen first and the choice pops up.
			if f == 5:
				s.grid.set_terrain(Vector2i(26, 18), CombatGrid.T.ROAD)
				_thing(s, "gate").done = true
				_put(s, Vector2i(25, 11))
			if f == 8:
				s.walk([Vector2i(25, 11), Vector2i(24, 11), Vector2i(24, 10)] as Array[Vector2i])
			return f == 40
		"deploy", "fight":
			if f == 5:
				s.grid.set_terrain(Vector2i(26, 18), CombatGrid.T.ROAD)
				_thing(s, "gate").done = true
				_put(s, Vector2i(25, 13))
				s.start_fight(s.groups[0], "party")
			if step == "fight" and f == 15:
				s._begin_battle()
			if step == "fight" and f == 25:
				var b: Battle = s.battle
				b._select(s.party[2] if s.party.size() > 2 else s.party[0])
			return f == (20 if step == "deploy" else 40)
	return f == 20

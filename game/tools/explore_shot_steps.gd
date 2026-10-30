extends RefCounted
## Explore scene states for tools/explore_shot.gd. Returns true on the frame to save.


func _put(s: Node, c: Vector2i) -> void:
	var lead: CombatUnit = s.leader()
	lead.place(c, s.grid.height_at(c))
	s._refresh_sight()
	s._refresh_units()
	s.focus = Vector2(c) + Vector2(0.5, 0.5)
	s.focus_h = s.grid.height_at(c)


func _thing(s: Node, id: String) -> Dictionary:
	for t: Dictionary in s.things:
		if t.id == id:
			return t
	return {}


func run(s: Node, f: int, step: String) -> bool:
	if step == "overview":
		# The whole map lit and zoomed out, to judge a layout.
		if f == 5:
			for y in s.grid.h:
				for x in s.grid.w:
					s.seen[Vector2i(x, y)] = true
			s._refresh_sight()
			for y in s.grid.h:
				for x in s.grid.w:
					s.board.fog[Vector2i(x, y)] = 2
			s.zoom = clampf(26.0 / maxf(s.grid.w, s.grid.h), 0.55, 1.6)
			s.follow = false
			s.focus = Vector2(s.grid.w, s.grid.h) * 0.5
			s.focus_h = 1.0
			s._apply_camera()
		return f == 30
	if step.begins_with("near:") or step.begins_with("use:"):
		if f == 5:
			if step.begins_with("near:"):
				# near:<x>,<y>[:<flag>,...] - flags set first, so things behind a "when" show.
				var parts := step.substr(5).split(":")
				if parts.size() > 1:
					var game: Node = s.get_node("/root/Game")
					game.save_enabled = false  # a shot never writes the real save
					game.meta.flags.append_array(parts[1].split(","))
				var xy := parts[0].split(",")
				_put(s, Vector2i(int(xy[0]), int(xy[1])))
			else:
				s._go_use(_thing(s, step.substr(4)))
		return f == 90
	if step.begins_with("goal:"):
		# goal:<group id>:<x>,<y> - the lead at x,y fights that group: the goal line, a BOSS tag, green exit cells.
		var parts := step.split(":")
		if f == 5:
			var xy := parts[2].split(",")
			_put(s, Vector2i(int(xy[0]), int(xy[1])))
			for y in s.grid.h:
				for x in s.grid.w:
					s.seen[Vector2i(x, y)] = true
			for g: Dictionary in s.groups:
				if String(g.def.id) == parts[1]:
					s.start_fight(g, "party")
		if f == 15:
			s._begin_battle()
		if f == 20:
			for y in s.grid.h:
				for x in s.grid.w:
					s.board.fog[Vector2i(x, y)] = 2
		return f == 40
	match step:
		"start":
			return f == 20
		"elite":
			# A group marked elite ([USER] pc-15): the ELITE badge over its pieces and the warning in its box.
			if f == 5:
				var g: Dictionary = s.groups[0]
				g.def["elite"] = true
				for u: CombatUnit in g.units:
					u.elite = true
				s.focus = Vector2(g.units[0].cell) + Vector2(0.5, 0.5)
				s.follow = false
				s._refresh_units()
				s.open_event(String(g.def.event), {"group": g})
			return f == 30
		"benched":
			# The dog left at home ([USER] pc-10): he stands at his home spot, ready to be invited.
			if f == 5:
				var game: Node = s.get_node("/root/Game")
				game.save_enabled = false  # a shot never writes the real save
				game.meta.flags.append_array(["has_lodestone", "met_dog"])
				game.dismiss("dog")
				s._after_change()
				_put(s, Vector2i(5, 24))
			return f == 30
		"gate":
			# The village gate's prompt ([USER] pc-10): GO (F) or EDIT PARTY (P); then the party editor.
			if f == 5:
				var game: Node = s.get_node("/root/Game")
				game.save_enabled = false  # a shot never writes the real save
				game.meta.flags.append_array(["has_lodestone", "met_dog"])
				game.refresh_party()
				s._after_change()
				s._apply_map_fx(["exit"], {})
				s._party_editor()
			return f == 30
		"lodestone":
			# The Lodestone menu with a skill rank waiting for the dog (rolled stats show in each line).
			if f == 5:
				var game: Node = s.get_node("/root/Game")
				game.save_enabled = false  # a shot never writes the real save
				game.take_weapon("sword")
				var hero: Dictionary = game.level_state("lead")
				hero.jobs.knight.level = 10
				hero.jobs.knight.pending = 1
				game.meta.levels["lead"] = hero
				var st: Dictionary = game.level_state("dog")
				st.pending = 1
				st.ranks["bite"] = 1
				game.meta.levels["dog"] = st
				game.meta.flags.append_array(["has_lodestone", "met_dog"])  # in memory only, not saved
				game.refresh_party()
				s._refresh_hud()
				s._open_menu("lodestone")
			return f == 30
		"pack_full":
			# A pickup with no room: FOUND beside the pack, the dog's saddlebag and THROW AWAY under it.
			if f == 5:
				var run: RunState = s.get_node("/root/Game").run
				run.adventure = true
				run.food = 200
				run.add_item("rope", 1)
				run.add_item("potion", 2)
			return f == 30
		"pack":
			# The PACK box with a few stacks and a find in it, to judge the grid.
			if f == 5:
				var run: RunState = s.get_node("/root/Game").run
				run.food = 34
				run.medicine = 4
				run.add_item("rope", 1)
				var belt: InventoryGrid = run.members[0].belt
				if belt.count("potion") == 0:
					run.pack.take("potion", 2)
					belt.put("potion", RunState.shape_of("potion"), 2, 3)
				run.add_item("stuff", 3)
				s.get_node("/root/Game").meta.materials["stuff"] = 9  # what earlier trips banked (not saved)
				s._refresh_hud()
				s._open_menu("pack")
			return f == 30
		"walk":
			# Walk into the yard and up to the gate for real (pathing, steps, fog as it goes).
			if f == 5:
				var p: Array[Vector2i] = ExploreRules.find_path(s.grid, s.leader().cell, Vector2i(26, 21), s.leader().jump, s._blocked(), s.seen)
				s.walk(p)
			return f == 120
		"wasd":
			# Hold W, then W + A: the leader walks up the screen, then up-left, a cell at a time.
			if f in [5, 40, 70]:
				var keys := {5: [KEY_W], 40: [KEY_W, KEY_A], 70: []}
				for k in [KEY_W, KEY_A]:
					var ev := InputEventKey.new()
					ev.keycode = k
					ev.physical_keycode = k
					ev.pressed = k in keys[f]
					Input.parse_input_event(ev)
			return f == 90
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

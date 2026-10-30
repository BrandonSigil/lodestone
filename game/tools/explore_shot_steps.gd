extends RefCounted
## Explore scene states for tools/explore_shot.gd. Returns true on the frame to save.


func _put(s: Node, c: Vector2i) -> void:
	var lead: CombatUnit = s.leader()
	lead.place(c, s.grid.height_at(c))
	s._refresh_sight()
	s._refresh_units()
	s.focus = Vector2(CombatGrid.ground(c)) + Vector2(0.5, 0.5)
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
				var at := Vector2i(int(xy[0]), int(xy[1]))
				_put(s, CombatGrid.deck_of(at) if xy.size() > 2 and xy[2] == "deck" else at)  # near:x,y,deck stands on the deck
			else:
				s._go_use(_thing(s, step.substr(4)))
		return f == 90
	if step.begins_with("sheet:") or step.begins_with("rack:"):
		# sheet:<member> - that member's character sheet (the dog met first); rack:<page> - the smithy rack's
		# sheets turned to that page (0 sword, 1 daggers, 2 bow, 3 the book).
		if f == 5:
			var game: Node = s.get_node("/root/Game")
			game.save_enabled = false
			if not game.meta.flags.has("met_dog"):
				game.meta.flags.append("met_dog")
			game.refresh_party()
			s._refresh_party_units() if s.has_method("_refresh_party_units") else null
			if step.begins_with("sheet:"):
				s.open_sheet(step.substr(6))
			else:
				for t: Dictionary in s.things:
					if t.kind == "rack":
						s._rack_sheets(t)
				for i in int(step.substr(5)):
					s.sheet.flip(1)
		return f == 30
	if step.begins_with("hold:"):
		# hold:<x>,<y>:<keys> - the lead stands at x,y and holds WASD keys (e.g. "a" or "wa") for a second:
		# where it ends up shows what walking lets it into (the bank of a stream, the edge of a wood).
		var parts := step.substr(5).split(":")
		var keys: Array = []
		for ch in parts[1]:
			keys.append({"w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D}[ch])
		if f == 5:
			var xy := parts[0].split(",")
			_put(s, Vector2i(int(xy[0]), int(xy[1])))
		if f == 8 or f == 70:
			for k in keys:
				var ev := InputEventKey.new()
				ev.keycode = k
				ev.physical_keycode = k
				ev.pressed = f == 8
				Input.parse_input_event(ev)
		if f == 79:
			print("hold: the lead ends at ", s.leader().cell, " vis ", s.leader().vis)
		return f == 80
	if step.begins_with("feet:"):
		# feet:<x>,<y> - the lead stands at x,y but past the cell's middle toward the viewer, as free walking
		# leaves it: the ground in front must not cover its feet.
		if f == 5:
			var xy := step.substr(5).split(",")
			_put(s, Vector2i(int(xy[0]), int(xy[1])))
			s.leader().vis += Vector2(0.4, 0.4)
			s.zoom = 2.0
		return f == 40
	if step.begins_with("reach:"):
		# reach:<group id>:<x>,<y> - the hero as an archer fights that group from x,y: his menu open and
		# GOOD SHOT hovered, its range drawn in blue ([USER] 2026-10-30).
		var parts := step.split(":")
		if f == 3:
			var game: Node = s.get_node("/root/Game")
			game.save_enabled = false
			if not game.meta.flags.has("met_dog"):
				game.meta.flags.append("met_dog")  # the dog comes too
			game.refresh_party()
			game.take_weapon("bow")
			s._rebuild_party()
		if f == 5:
			var xy := parts[2].split(",")
			_put(s, Vector2i(int(xy[0]), int(xy[1])))
			for g: Dictionary in s.groups:
				if String(g.def.id) == parts[1]:
					s.start_fight(g, "party")
		if f == 25:
			s._begin_battle()
		if f == 45:
			s.battle._select(s.party[0])
		if f == 50:  # keys onto GOOD SHOT, as the player would: its focus draws the range
			for a: Ability in (s.party[0] as CombatUnit).abilities:
				if a.id == "aimed_shot":
					for btn: Button in s.battle._menu_box.get_children():
						if btn.text.begins_with(Txt.t(a.name_key)):
							btn.grab_focus()
		return f == 65
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
		"lasting":
			# Lasting rewards ([USER] omr-10), set down next to the hero in memory only: a stat item, a key and
			# a rare cache, and the stat item's WHO TAKE IT box.
			if f == 5:
				var game: Node = s.get_node("/root/Game")
				game.save_enabled = false
				var c: Vector2i = s.leader().cell
				var spots: Array[Vector2i] = []
				for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(2, 0), Vector2i(0, 2)]:
					if s.grid.passable(c + d) and spots.size() < 3:
						spots.append(c + d)
				var kinds := [["boost", "hp:2"], ["key", "shot_key"], ["rare", "rare:1;metal:2"]]
				for i in spots.size():
					s.things.append({"id": "shot_%d" % i, "kind": kinds[i][0], "event": kinds[i][1], "cell": spots[i],
						"floor": "s", "to": "", "at": Vector2i(-1, -1), "once": "", "when": "", "done": false})
				s._lasting(s.things[s.things.size() - spots.size()])
			return f == 30
		"boons":
			# Blessings and setbacks from the road ([USER] omr-7, omr-8), listed in the Lodestone menu.
			if f == 5:
				var game: Node = s.get_node("/root/Game")
				game.save_enabled = false
				game.meta.flags.append("has_lodestone")
				game.call("absorb_boons", {"blessings": 2, "setbacks": 1})
				s._refresh_hud()
				s._open_menu("lodestone")
			return f == 30
		"restore":
			# Village work ([USER] omr-5): the smith and the chef moved in (in memory only), one step tracked: the list, and the
			# frame's long bar showing what the tracked step still misses.
			if f == 5:
				var game: Node = s.get_node("/root/Game")
				game.save_enabled = false
				game.meta.materials = {"metal": 2, "wood": 4, "herb": 2}
				game.meta.tracked = ["smithy_1"]
				game.meta.flags.append_array(["has_lodestone", "settler_smith", "settler_chef"])
				s._refresh_hud()
				s._open_menu("restore")
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
				s.hud.flash_saved()  # the cue a bookmark shows (saving is off in shots)
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
		"eat":
			# EAT pressed in the PACK box: the party cards show who would gain what (the dog met, the hero hurt).
			if f == 5:
				var game: Node = s.get_node("/root/Game")
				game.save_enabled = false
				if not game.meta.flags.has("met_dog"):
					game.meta.flags.append("met_dog")
				game.refresh_party()
				var run: RunState = game.run
				run.food = 6
				run.medicine = 2
				run.members[0].hp = run.max_hp(run.members[0]) - 5
				s._refresh_hud()
				s._open_menu("pack")
			if f == 20:  # press EAT, as the player would
				for b: Button in s._dialog.find_children("*", "Button", true, false):
					if b.text == Txt.t("UI_EAT"):
						b.pressed.emit()
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

extends RefCounted
## Sandbox states for tools/sandbox_shot.gd.


func run(s: Node, _frames: int, _step: String) -> void:
	if (_step == "wall" or _step == "player") and _frames == 4:
		s.preview.wallpaper = true
		s._wallpaper_on = true
	if _step == "player" and _frames == 12:
		# The player's view: the fight board zoomed in on the lead piece, HUD hidden, about where the camera sits in play.
		var board: CombatBoard = s.battle.board
		var lead: CombatUnit = s.battle.units[0]
		var k := 2.2
		for child in s.battle.get_children():
			if child != board:
				child.visible = false
		s._play_panel.visible = false
		board.scale = Vector2.ONE * k
		board.position = s.play_rect().get_center() - board.cell_top(lead.cell) * k
		return
	if _step.begins_with("turn"):
		if _frames == 6:
			s.preview.turn(int(_step.substr(4)))
		return
	if (_step == "bark" or _step == "amber") and _frames == 4:  # Doggo and Amber in the party
		s.setup.party = [{"id": "dog", "cell": s.setup.party[0].cell}, {"id": "fire_mage", "cell": s.setup.party[1].cell},
			{"id": "lead", "cell": s.setup.party[2].cell}]
	if _frames == 5 and _step != "edit" and _step != "wall":  # "player" enters play, so the lead piece exists
		s._enter_play()
	if _step == "restart_mid":
		if _frames == 10:
			s.battle.end_player_phase()
		if _frames in [16, 40, 60]:
			s._restart()
		if _frames in [30, 50]:
			s.battle.end_player_phase()
		return
	if _frames == 10 and _step.begins_with("anim_"):
		# anim_<anim>[_ne]: the first piece stands next to the nearest foe and plays <anim> facing SE (or NE),
		# caught 14 frames in (the hit frame of the swing).
		var b: Battle = s.battle
		var u: CombatUnit = b.units[0]
		var parts := _step.split("_")
		var foe: CombatUnit = null
		for o: CombatUnit in b.units:
			if o.team == 1 and (foe == null or CombatRules.dist(o.cell, u.cell) < CombatRules.dist(foe.cell, u.cell)):
				foe = o
		for d: Vector2i in [Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0)]:
			var c := foe.cell + d
			if b.grid.passable(c) and CombatRules.unit_at(b.units, c) == null:
				u.place(c, b.grid.height_at(c))
				break
		u.facing = Vector2i(0, -1) if parts.size() > 2 and parts[2] == "ne" else Vector2i(1, 0)
		b.board.play_anim(u, parts[1])
		return
	if _frames == 10 and _step != "edit" and _step != "wall":
		var b: Battle = s.battle
		var u: CombatUnit = b.units[0]
		match _step:
			"menu", "amber":
				b._select(u if _step == "menu" else b.units[1])
			"bark":
				var foe: CombatUnit = null
				for o: CombatUnit in b.units:
					if o.team == 1 and (foe == null or CombatRules.dist(o.cell, u.cell) < CombatRules.dist(foe.cell, u.cell)):
						foe = o
				for d: Vector2i in [Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0)]:
					var c := foe.cell + d
					if b.grid.passable(c) and CombatRules.unit_at(b.units, c) == null:
						u.place(c, b.grid.height_at(c))
						break
				b._select(u)
				for ev in CombatRules.resolve(RandomNumberGenerator.new(), b.grid, u, Db.ability("bark"), u.cell, b.units):
					b._play(ev)
			"aim":
				# Walk the first piece to the cell nearest the enemy, then aim its best ready skill.
				b._select(u)
				var best: Vector2i = u.cell
				for c: Vector2i in CombatRules.reachable(b.grid, u, b.units).cost:
					if CombatRules.dist(c, Vector2i(b.grid.w - 1, u.cell.y)) < CombatRules.dist(best, Vector2i(b.grid.w - 1, u.cell.y)):
						best = c
				u.place(best, b.grid.height_at(best))
				u.moved = true
			"goals":
				# A fight written as "beat the boss or get everyone to the green": the boss tag, the way out, the goal line.
				for o: CombatUnit in b.units:
					if o.team == 1:
						o.leader = true
						break
				var exits := []
				for y in b.grid.h:
					if b.grid.passable(Vector2i(0, y)):
						exits.append([0, y])
				b.goals = FightGoals.parse("leader|exit", exits)
				for c in b.goals.exit_cells:
					b.board.goal_cells[c] = true
				for line in b.goal_lines():
					b.log_line.emit(line)
				b._select(u)
			"teamup":
				# Two pieces next to the same foe, the first aiming its HIT: the forecast shows the helping strike.
				var foe: CombatUnit = null
				for o: CombatUnit in b.units:
					if o.team == 1 and (foe == null or o.cell.x < foe.cell.x):
						foe = o
				var spots: Array[Vector2i] = []
				for d in CombatRules.DIRS:
					var c: Vector2i = foe.cell + d
					if b.grid.passable(c) and CombatRules.occupant(b.units, c) == null:
						spots.append(c)
				u.place(spots[0], b.grid.height_at(spots[0]))
				b.units[1].place(spots[1], b.grid.height_at(spots[1]))
				u.moved = true
				b._select(u)
				b._start_targeting(u.abilities[0])
				b._on_cell_hovered(foe.cell)
			"downed":
				# The first piece is down and bleeding out; the second stands next to it with AID in its menu.
				var o: CombatUnit = b.units[1]
				for d in CombatRules.DIRS:
					var c: Vector2i = u.cell + d
					if b.grid.passable(c) and CombatRules.occupant(b.units, c) == null:
						o.place(c, b.grid.height_at(c))
						break
				u.hp = 0
				u.sync_view()
				b._select(o)
			"guard":
				# The first piece guards: its ring of held cells shows ([USER] c13).
				b._select(u)
				b._on_guard()
			"fields":
				# Kit batch 2's ground marks in front of the first piece: a trap, caltrops, IGNITE's fire, a smoke cloud.
				var free: Array[Vector2i] = []
				for c: Vector2i in CombatRules.reachable(b.grid, u, b.units, 8).cost:
					if c != u.cell and CombatRules.dist(c, u.cell) >= 2:
						free.append(c)
				free.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return CombatRules.dist(p, u.cell) < CombatRules.dist(q, u.cell))
				var i := 0
				for id in ["trap", "caltrops", "ignite", "smoke_bomb"]:
					if i < free.size():
						CombatRules.lay_field(b.grid, u, Db.ability(id), free[i])
						i += 3
				b._select(u)
			"goodshot":
				# GOOD SHOT: the first piece downs a foe with a plain attack and gets its action back (AGAIN!).
				var foe: CombatUnit = null
				for o: CombatUnit in b.units:
					if o.team == 1 and (foe == null or CombatRules.dist(o.cell, u.cell) < CombatRules.dist(foe.cell, u.cell)):
						foe = o
				for d: Vector2i in CombatRules.DIRS:
					var c := foe.cell + d
					if b.grid.passable(c) and CombatRules.unit_at(b.units, c) == null:
						u.place(c, b.grid.height_at(c))
						break
				u.traits.append(CombatRules.TRAIT_GOOD_SHOT)
				foe.hp = 1
				b._select(u)
				for ev in CombatRules.resolve(RandomNumberGenerator.new(), b.grid, u, u.abilities[0], foe.cell, b.units):
					b._play(ev)
				b._after_action(u)
			"danger":
				b.show_danger = true
				b._refresh_danger()
				b._select(u)
	if _frames == 14 and _step == "aim":
		var b: Battle = s.battle
		var u: CombatUnit = b.units[1]
		# Stand three tiles from the nearest foe so the skill is in reach.
		var near: CombatUnit = null
		for o: CombatUnit in b.units:
			if o.team == 1 and (near == null or CombatRules.dist(o.cell, u.cell) < CombatRules.dist(near.cell, u.cell)):
				near = o
		var spot := near.cell + Vector2i(-3, 0)
		if b.grid.passable(spot) and CombatRules.unit_at(b.units, spot) == null:
			u.place(spot, b.grid.height_at(spot))
		b._select(u)
		var a: Ability = u.abilities[1] if u.abilities.size() > 1 else u.abilities[0]
		b._start_targeting(a)
		var foe: CombatUnit = null
		for o: CombatUnit in b.units:
			if o.team == 1 and (foe == null or CombatRules.dist(o.cell, u.cell) < CombatRules.dist(foe.cell, u.cell)):
				foe = o
		for c: Vector2i in b.board.highlights:
			if CombatRules.dist(c, foe.cell) <= a.radius:
				b._on_cell_hovered(c)
				break

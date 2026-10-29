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
			"menu":
				b._select(u)
			"aim":
				# Walk the first piece to the cell nearest the enemy, then aim its best ready skill.
				b._select(u)
				var best: Vector2i = u.cell
				for c: Vector2i in b.reach.cost:
					if CombatRules.dist(c, Vector2i(b.grid.w - 1, u.cell.y)) < CombatRules.dist(best, Vector2i(b.grid.w - 1, u.cell.y)):
						best = c
				u.place(best, b.grid.height_at(best))
				u.moved = true
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

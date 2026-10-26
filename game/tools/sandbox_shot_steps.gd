extends RefCounted
## Sandbox states for tools/sandbox_shot.gd.


func run(s: Node, _frames: int, _step: String) -> void:
	if _frames == 5 and _step != "edit":
		s._enter_play()
	if _step == "restart_mid":
		if _frames == 10:
			s.battle.end_player_phase()
		if _frames in [16, 40, 60]:
			s._restart()
		if _frames in [30, 50]:
			s.battle.end_player_phase()
		return
	if _frames == 10 and _step != "edit":
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

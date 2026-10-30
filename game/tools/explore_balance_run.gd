extends RefCounted

const MAPS := ["snow_pass", "wolf_den", "crypt"]


func run(args: PackedStringArray) -> void:
	if Db.abilities.is_empty():
		Db.reload()
	var n := int(args[0]) if args.size() > 0 else 200
	var level := int(args[1]) if args.size() > 1 else 1
	var weapon := args[2] if args.size() > 2 else "sword"
	print("party: hero (%s) + dog, level %d, %d fights each" % [weapon, level, n])
	for map_name in MAPS:
		var m := ExploreMap.load_named(map_name)
		_open_ways(m)
		for g: Dictionary in m.groups:
			var line := "%-10s %-12s" % [map_name, g.id]
			for how in ["party", "ambushed"]:
				var wins := 0
				var rounds := 0
				for i in n:
					var r := _fight(m, g, how, level, weapon, i)
					wins += 1 if r.winner == 0 else 0
					rounds += int(r.rounds)
				line += " | %-8s %3d%% (%.1f rounds)" % [how, roundi(100.0 * wins / n), float(rounds) / n]
			print(line)
	# Road fights from the overworld: a snow valley, each side on its deploy cells, the party first.
	for enc_id in ["pair_wolves", "pair_bandits"]:
		var wins := 0
		var stalls := 0
		for i in n:
			var grid := MapGen.valley(i, 14, 12, "snow")
			var units: Array = []
			var spots := grid.deploy_cells(0)
			for u: CombatUnit in _party(level, weapon):
				var c: Vector2i = spots.pop_front()
				u.place(c, grid.height_at(c))
				units.append(u)
			var espots := grid.deploy_cells(1)
			for id: String in Db.encounters[enc_id].units:
				var e := CombatUnit.enemy(Db.class_def(id))
				var c: Vector2i = espots.pop_front()
				e.place(c, grid.height_at(c))
				units.append(e)
			var rng := RandomNumberGenerator.new()
			rng.seed = i * 7919 + 13
			var w: int = _play(rng, grid, units, 0).winner
			wins += 1 if w == 0 else 0
			stalls += 1 if w == -1 else 0
		print("road       %-12s | party    %3d%%  (stalemates %d%%)" % [enc_id, roundi(100.0 * wins / n), roundi(100.0 * stalls / n)])


## Shut doors and rubble open onto their floor, as they are by the time the walk reaches what's behind them
## (the crypt's plaza, tower and throne all sit behind one: with them shut the fights never met).
func _open_ways(m: ExploreMap) -> void:
	for t: Dictionary in m.things:
		if String(t.kind) in ["door", "rubble"]:
			for key in CombatGrid.LETTERS:
				if CombatGrid.LETTERS[key] == String(t.floor):
					m.grid.set_terrain(t.cell, key)


func _party(level: int, weapon: String) -> Array:
	var row: Dictionary = Db.weapons.get(weapon, {})
	var mods := {}
	for k in ["attack", "damage", "move", "range_min", "range_max"]:
		mods[k] = int(row.get(k, 0))
	mods = LevelRules.merge(LevelRules.bonus(_rolled(String(row.get("job", "lead")), level), Db.levels), mods)
	var hero := Db.character(&"lead").duplicate()
	var job := String(row.get("job", ""))  # the weapon is the job ([USER] pc-9)
	hero.class_def = load("res://data/classes/%s.tres" % (String(Db.jobs[job].class) if Db.jobs.has(job) else "nobody"))
	hero.traits.clear()
	var out := [CombatUnit.from_def(hero, mods)]
	out.append(CombatUnit.from_def(Db.character(&"dog"), LevelRules.bonus(_rolled("dog", level), Db.levels)))
	return out


## A character at this level with its stats rolled from its growth odds (the same rolls every run).
func _rolled(id: String, level: int) -> Dictionary:
	var s := LevelRules.fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	LevelRules.gain(s, (level - 1) * int(Db.levels.get("xp_per_level", 100)), Db.levels, Db.growth.get(id, {}), rng)
	return s


## The leader stands on the walk from the map start toward the group, at the first cell where
## the party sees them (party first) or they see the party (ambushed).
func _fight(m: ExploreMap, g: Dictionary, how: String, level: int, weapon: String, seed_i: int) -> Dictionary:
	var grid := m.grid
	var enemies: Array = []
	for e: Dictionary in g.units:
		var cls := Db.class_def(e.id)
		var depth := ExploreRules.group_depth(m.level, g)  # the place's depth; a boss is tuned by hand
		var u := CombatUnit.enemy(cls, ExploreRules.depth_mods(m.map_name, depth, String(g.id), g.units.find(e), cls))
		u.place(e.cell, grid.height_at(e.cell))
		u.summon_cells = g.get("summon", [] as Array[Vector2i])
		for c in g.get("exit", []):  # as the explore scene: nothing raised on the way out
			u.summon_avoid[Vector2i(int(c[0]), int(c[1]))] = true
		enemies.append(u)
	var cells: Array = enemies.map(func(u: CombatUnit) -> Vector2i: return u.cell)
	var blocked := {}
	for c in cells:
		blocked[c] = true
	var goal: Vector2i = cells[0]
	var path := ExploreRules.find_path(grid, m.start[0], _near(grid, goal, blocked), 2, blocked)
	var at: Vector2i = m.start[0]
	for c in path:
		at = c
		var seen_them := ExploreRules.sees(grid, [c], cells, ExploreRules.PARTY_SIGHT)
		var they_see := ExploreRules.sees(grid, cells, [c], int(g.sight))
		if (how == "party" and seen_them) or they_see:
			break
	var party := _party(level, weapon)
	for u: CombatUnit in party:
		u.place(at, grid.height_at(at))
	var spots := ExploreRules.auto_deploy(grid, party, how, blocked)
	var units: Array = []
	for u: CombatUnit in party:
		if spots.has(u):
			u.place(spots[u], grid.height_at(spots[u]))
			units.append(u)
	units.append_array(enemies)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i * 7919 + 13
	return _play(rng, grid, units, 1 if how == "ambushed" else 0)


func _near(grid: CombatGrid, c: Vector2i, blocked: Dictionary) -> Vector2i:
	for d in CombatRules.DIRS:
		if grid.passable(c + d) and not blocked.has(c + d):
			return c + d
	return c


func _play(rng: RandomNumberGenerator, grid: CombatGrid, units: Array, first: int) -> Dictionary:
	return CombatSim.fight(rng, grid, units, {}, first)

extends RefCounted
## One outing: the snow pass (2 fights), the wolf den (2), the crypt (3) and the throne, on foot between them, the hero
## and the dog. HP and the mana or charges carry; a trickle comes back along the walk (`gap` tiles between fights);
## wins pay XP (levels rise); a fall ends the attempt and the next one starts again from the village with the levels kept.
## Nothing here touches game/data: overrides live in this process.

const ORDER := [["snow_pass", "pass_wolves"], ["snow_pass", "pass_bandits"], ["wolf_den", "den_wolves"], ["wolf_den", "den_lone"],
	["crypt", "plaza"], ["crypt", "cave"], ["crypt", "tower"], ["crypt", "throne"]]

var _helper: RefCounted
var _maps := {}


func run(args: PackedStringArray) -> void:
	if Db.abilities.is_empty():
		Db.reload()
	var runs := int(args[0]) if args.size() > 0 else 40
	var gap := float(args[1]) if args.size() > 1 else 30.0
	var label := []
	for a in args.slice(2):
		var kv := a.split("=")
		if kv[0] == "lvl":
			level_offset = int(kv[1])
		elif kv[0] == "foe_hp":
			foe_hp = int(kv[1])
		elif Db.levels.has(kv[0]):
			Db.levels[kv[0]] = float(kv[1])
		else:
			Db.combat[kv[0]] = float(kv[1])
		label.append(a)
	_helper = load("res://tools/explore_balance_run.gd").new()
	for name in ["snow_pass", "wolf_den", "crypt"]:
		var m := ExploreMap.load_named(name)
		_helper.call("_open_ways", m)
		_maps[name] = m
	if runs < 0:  # throne grid: the Lich from a given arrival state, `-runs` fights a cell
		_throne_grid(-runs, int(gap))
		return
	print("## gap %d tiles %s, %d runs a weapon" % [gap, " ".join(label), runs])
	print("| weapon | Lich try 1 win (runs) | try 2 win (runs) | try 3 win (runs) | HP on first arrival | resources on first arrival | level | falls before the throne a run |")
	print("| --- | --- | --- | --- | --- | --- | --- | --- |")
	for weapon in ["sword", "daggers", "bow"]:
		var tries := [0, 0, 0]  # runs that stood at the throne for the 1st, 2nd and 3rd time
		var wins := [0, 0, 0]
		var hp_sum := 0.0
		var res_sum := 0.0
		var lvl_sum := 0.0
		var first_n := 0
		var falls := 0.0
		for i in runs:
			var xp := 0
			var at_throne := 0
			for attempt in 8:  # a fall anywhere sends the party home; the next walk keeps the levels
				var r := _attempt(weapon, xp, gap, i * 16 + attempt)
				xp = r.xp
				if not r.reached:
					falls += 1.0
					continue
				if at_throne == 0:
					first_n += 1
					hp_sum += float(r.hp_pct)
					res_sum += float(r.res_pct)
					lvl_sum += float(r.level)
				if at_throne < 3:
					tries[at_throne] += 1
					wins[at_throne] += 1 if r.won else 0
				at_throne += 1
				if r.won:
					break
		print("| %s | %d%% (%d) | %d%% (%d) | %d%% (%d) | %d%% | %d%% | %.1f | %.1f |" % [weapon,
			roundi(100.0 * wins[0] / maxi(1, tries[0])), tries[0], roundi(100.0 * wins[1] / maxi(1, tries[1])), tries[1],
			roundi(100.0 * wins[2] / maxi(1, tries[2])), tries[2],
			roundi(hp_sum / maxi(1, first_n)), roundi(res_sum / maxi(1, first_n)), lvl_sum / maxi(1, first_n), falls / runs])


var foe_hp := 100  ## `foe_hp=80`: the road's foes (not a boss) at this % of their HP
var level_offset := 0  ## `lvl=-1`: the sim's party a level behind, to match the outing robot's baseline

func _level(xp: int) -> int:
	return maxi(1, 1 + xp / int(Db.levels.get("xp_per_level", 100)) + level_offset)


## One attempt from the village, everyone full. Returns {"won", "reached", "xp", "hp_pct", "res_pct", "level"}.
func _attempt(weapon: String, xp0: int, gap: float, seed_i: int) -> Dictionary:
	var xp := xp0
	var state: Array = []  # per party piece: {"hp": int, "max": int, "res": int, "tick": int, "full": bool}
	var trickle := 0.0
	var at := ""
	var last := Vector2i(-1, -1)
	var out := {"won": false, "reached": false, "xp": xp, "hp_pct": 0, "res_pct": 0, "level": 1}
	for n in ORDER.size():
		var map_name: String = ORDER[n][0]
		var m: ExploreMap = _maps[map_name]
		var g := {}
		for x: Dictionary in m.groups:
			if x.id == ORDER[n][1]:
				g = x
		var last_fight: bool = n == ORDER.size() - 1
		# the walk since the last fight: a trickle of mana and charges (Game.trickle)
		trickle += gap / maxf(1.0, float(Db.levels.get("trickle_steps", 10)))
		while trickle >= 1.0:
			trickle -= 1.0
			for s in state:
				if not s.full and s.res < s.res_max:
					s.res += 1
		var level := _level(xp)
		var party: Array = _helper.call("_party", level, weapon)
		for i in party.size():
			var u: CombatUnit = party[i]
			if i >= state.size():
				state.append({"hp": u.max_hp, "max": u.max_hp, "res": u.res_max, "tick": 0, "full": true, "res_max": u.res_max})
			var s: Dictionary = state[i]
			u.hp = clampi(int(s.hp) + (u.max_hp - int(s.max)), 1, u.max_hp)
			s["max"] = u.max_hp
			s["res_max"] = u.res_max
			if u.res_kind in ["mana", "charges"] and not s.full:
				u.res = clampi(int(s.res), 0, u.res_max)
				u.res_tick = int(s.tick)
		if last_fight:
			out.reached = true
			out.level = level
			var hp_now := 0.0
			var hp_max := 0.0
			var rs := 0.0
			var rm := 0.0
			for i in party.size():
				hp_now += (party[i] as CombatUnit).hp
				hp_max += (party[i] as CombatUnit).max_hp
				if (party[i] as CombatUnit).res_kind in ["mana", "charges"]:
					rs += (party[i] as CombatUnit).res
					rm += (party[i] as CombatUnit).res_max
			out.hp_pct = roundi(100.0 * hp_now / hp_max)
			out.res_pct = roundi(100.0 * rs / maxf(1.0, rm))
		var r := _fight(m, g, party, state, seed_i * 31 + n)
		if r.winner != 0:
			out.xp = xp
			return out
		if last_fight:
			out.won = true
		xp += LevelRules.fight_xp(int(r.foes), bool(g.get("boss", false)), Db.levels)
		out.xp = xp
	return out


## One fight from where the walk meets the group (party first), the carried bars kept; stores what is left.
func _fight(m: ExploreMap, g: Dictionary, party: Array, state: Array, seed_i: int) -> Dictionary:
	var grid := m.grid
	var enemies: Array = []
	for e: Dictionary in g.units:
		var cls := Db.class_def(e.id)
		var depth := ExploreRules.group_depth(m.level, g)
		var mods := ExploreRules.depth_mods(m.map_name, depth, String(g.id), g.units.find(e), cls)
		if not bool(g.get("boss", false)) and foe_hp != 100:
			mods["hp_pct"] = foe_hp
		var u := CombatUnit.enemy(cls, mods)
		u.place(e.cell, grid.height_at(e.cell))
		u.summon_cells = g.get("summon", [] as Array[Vector2i])
		for c in g.get("exit", []):
			u.summon_avoid[Vector2i(int(c[0]), int(c[1]))] = true
		enemies.append(u)
	var cells: Array = enemies.map(func(u: CombatUnit) -> Vector2i: return u.cell)
	var blocked := {}
	for c in cells:
		blocked[c] = true
	var goal: Vector2i = cells[0]
	var path := ExploreRules.find_path(grid, m.start[0], _helper.call("_near", grid, goal, blocked), 2, blocked)
	var at: Vector2i = m.start[0]
	for c in path:
		at = c
		if ExploreRules.sees(grid, [c], cells, ExploreRules.PARTY_SIGHT) or ExploreRules.sees(grid, cells, [c], int(g.sight)):
			break
	for u: CombatUnit in party:
		u.place(at, grid.height_at(at))
	var spots := ExploreRules.auto_deploy(grid, party, "party", blocked)
	var units: Array = []
	var seated: Array = []
	for u: CombatUnit in party:
		if spots.has(u):
			u.place(spots[u], grid.height_at(spots[u]))
			units.append(u)
			seated.append(u)
	units.append_array(enemies)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i * 7919 + 13
	CombatUnit.pack_belts(units, {})
	for u: CombatUnit in units:
		var carried: bool = u.team == 0 and u.res_kind in ["mana", "charges"] and not state[party.find(u)].full
		if not carried:
			u.reset_resource()
	var rounds := 0
	var winner := -1
	while rounds < CombatSim.MAX_ROUNDS and winner < 0:
		rounds += 1
		for team in [0, 1]:
			var w := CombatSim.run_phase(rng, grid, units, team)
			if w >= 0:
				winner = w
				break
	var foes := enemies.filter(func(u: CombatUnit) -> bool: return not u.alive()).size()
	for i in party.size():
		var u: CombatUnit = party[i]
		var s: Dictionary = state[i]
		s.hp = maxi(1, u.hp)  # downed pieces stand again at 1 HP after a win
		if u.res_kind in ["mana", "charges"]:
			s.res = u.res
			s.tick = u.res_tick
			s.full = false
	return {"winner": winner, "foes": foes}


## The Lich, party first, from arrival states: HP % of max, and the carried mana or charges % of max (the hero's rage starts at 0).
## `level`: the party's level. Prints the win rate per weapon for each cell, so the road can be tuned to arrive where the targets sit.
func _throne_grid(n: int, level: int) -> void:
	print("## the throne from arrival states, level %d, %d fights a cell: win %% by HP (rows) and resources (columns 0, 25, 50, 100)" % [level, n])
	var m: ExploreMap = _maps["crypt"]
	var g := {}
	for x: Dictionary in m.groups:
		if x.id == "throne":
			g = x
	for weapon in ["sword", "daggers", "bow"]:
		print("| %s | res 0 | 25 | 50 | 100 |" % weapon)
		print("| --- | --- | --- | --- | --- |")
		for hp_pct in [30, 40, 50, 60, 75, 100]:
			var line := "| HP %d%% |" % hp_pct
			for res_pct in [0, 25, 50, 100]:
				var wins := 0
				for i in n:
					var party: Array = _helper.call("_party", level, weapon)
					var state: Array = []
					for u: CombatUnit in party:
						state.append({"hp": maxi(1, roundi(u.max_hp * hp_pct / 100.0)), "max": u.max_hp, "res": roundi(u.res_max * res_pct / 100.0), "tick": 0,
							"full": res_pct >= 100, "res_max": u.res_max})
					for k in party.size():
						var u: CombatUnit = party[k]
						u.hp = state[k].hp
						if u.res_kind in ["mana", "charges"] and not state[k].full:
							u.res = state[k].res
					var r := _fight(m, g, party, state, i)
					wins += 1 if r.winner == 0 else 0
				line += " %d%% |" % roundi(100.0 * wins / n)
			print(line)

extends RefCounted
## The scale study's numbers. Nothing here writes to game/data; scaled ranges live only in this process.

const SCALES := [
	{"name": "today", "area": 1.0, "k": 1.0, "fast": 1.0},
	{"name": "A: area x1.25, move and reach x1.25", "area": 1.25, "k": 1.25, "fast": 1.25},
	{"name": "B: area x1.5, move and reach x1.5", "area": 1.5, "k": 1.5, "fast": 1.5},
	{"name": "C: area x1.5, most x1.25, fast and long-range x1.5", "area": 1.5, "k": 1.25, "fast": 1.5},
]
const DUO := ["pair_wolves", "pair_bandits"]
const QUAD := ["bandits", "wolves", "strange", "debug"]
const BASE_W := 14
const BASE_H := 12
const FAST_MOVE := 5  ## a base move at or over this is "fast"
const LONG_REACH := 4  ## a reach at or over this is "long"


func run(args: PackedStringArray) -> void:
	if Db.abilities.is_empty():
		Db.reload()
	var n := int(args[0]) if args.size() > 0 else 40
	_unit_table()
	_area_table()
	_explore_today(n)
	for sc: Dictionary in SCALES:
		_scale(sc, n)
	Db.reload()


func _reach(a: Ability, basic_max: int) -> int:
	return basic_max if a.range_max == 0 else a.range_max


func _unit_table() -> void:
	print("## Units today\n")
	print("| class | HP | move | jump | basic reach | longest ability reach |")
	print("| --- | --- | --- | --- | --- | --- |")
	for id in Db.class_ids():
		var c := Db.class_def(id)
		var longest := c.range_max
		var ids: Array = c.abilities.duplicate()
		ids.append_array(c.default_spells())
		for a in ids:
			var ab := Db.ability(String(a))
			if ab != null and ab.kind in ["attack", "hex", "heal", "buff"]:
				longest = maxi(longest, _reach(ab, c.range_max))
		print("| %s | %d | %d | %d | %d-%d | %d |" % [id, c.max_hp, c.move, c.jump, c.range_min, c.range_max, longest])
	print("")


func _area_table() -> void:
	print("## Fight areas today\n")
	print("| area | size | note |")
	print("| --- | --- | --- |")
	print("| road fight (a snow valley, `MapGen.valley`) | %d x %d | the fight scene's size when the map has an art set |" % [BASE_W, BASE_H])
	print("| generated fallback (`CombatGrid.generate`) | 10 x 8 | when there is no art set |")
	print("| default valley of the map maker | 22 x 20 | `MapGen.valley` default |")
	for f in DirAccess.get_files_at("res://data/explore"):
		if f.ends_with(".json"):
			var m := ExploreMap.load_named(f.get_basename())
			if m != null:
				print("| explore map `%s` | %d x %d | %d enemy groups |" % [f.get_basename(), m.grid.w, m.grid.h, m.groups.size()])
	print("")


# --- shared fight helpers ---------------------------------------------------------------------

func _helper() -> RefCounted:
	return load("res://tools/explore_balance_run.gd").new()


func _quad(level: int) -> Array:
	var party: Array = _helper().call("_party", level, "sword")
	for id in [&"wizard", &"hunter"]:
		party.append(CombatUnit.from_def(Db.character(id)))
	return party


## Plays one fight from the deploy cells, party first. Returns the facts the study counts.
func _road(grid: CombatGrid, party: Array, enc_id: String, seed_i: int) -> Dictionary:
	var units: Array = []
	var spots := grid.deploy_cells(0)
	for u: CombatUnit in party:
		var c: Vector2i = spots.pop_front()
		u.place(c, grid.height_at(c))
		units.append(u)
	var foes: Array = []
	var espots := grid.deploy_cells(1)
	for id: String in Db.encounters[enc_id].units:
		var e := CombatUnit.enemy(Db.class_def(id))
		_stretch(e)
		var c: Vector2i = espots.pop_front()
		e.place(c, grid.height_at(c))
		units.append(e)
		foes.append(e)
	return _play(grid, units, party, foes, seed_i)


func _play(grid: CombatGrid, units: Array, party: Array, foes: Array, seed_i: int) -> Dictionary:
	var gap := 99
	for p: CombatUnit in party:
		for e: CombatUnit in foes:
			gap = mini(gap, CombatRules.dist(p.cell, e.cell))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i * 7919 + 13
	CombatUnit.pack_belts(units, {})
	for u: CombatUnit in units:
		u.reset_resource()
	var contact := 0
	var rounds := 0
	var winner := -1
	var max_hp := {}
	for u: CombatUnit in units:
		max_hp[u] = u.hp
	while rounds < CombatSim.MAX_ROUNDS and winner < 0:
		rounds += 1
		for team in [0, 1]:
			var w := CombatSim.run_phase(rng, grid, units, team)
			if contact == 0 and units.any(func(u: CombatUnit) -> bool: return u.hp < max_hp[u]):
				contact = rounds
			if w >= 0:
				winner = w
				break
	var left := 0
	var all := 0
	var downs := 0
	for p: CombatUnit in party:
		left += maxi(0, p.hp)
		all += int(max_hp[p])
		downs += p.downs + (1 if not p.alive() else 0)
	return {"winner": winner, "rounds": rounds, "contact": contact if contact > 0 else rounds, "gap": gap,
		"party_pct": 100.0 * left / maxf(1.0, all), "downs": downs}


# --- scaling (this process only) ---------------------------------------------------------------

var _k := 1.0
var _fast := 1.0
var _orig := {}


func _up(v: int, k: float) -> int:
	return maxi(v, int(floor(v * k + 0.5)))


## Moves and ranged reaches of a unit, scaled; melee reach (1) never changes. Fast or long-range pieces get the fast factor.
func _stretch(u: CombatUnit) -> void:
	u.move = _up(u.move, _fast if u.move >= FAST_MOVE else _k)
	if u.range_max > 1:
		u.range_max = _up(u.range_max, _fast if u.range_max >= LONG_REACH else _k)


func _scale_abilities(k: float, fast: float) -> void:
	Db.reload()
	if k == 1.0 and fast == 1.0:
		return
	for id in Db.abilities:
		var a: Ability = Db.abilities[id]
		if a.range_max > 1:
			a.range_max = _up(a.range_max, fast if a.range_max >= LONG_REACH else k)


func _scale(sc: Dictionary, n: int) -> void:
	_k = sc.k
	_fast = sc.fast
	_scale_abilities(_k, _fast)
	var w := int(round(BASE_W * float(sc.area)))
	var h := int(round(BASE_H * float(sc.area)))
	print("## Scale %s (valley %d x %d)\n" % [sc.name, w, h])
	print("| party | foes | start gap | rounds to contact | win % | close % | stalls % | rounds |")
	print("| --- | --- | --- | --- | --- | --- | --- | --- |")
	for group: Array in [["duo", DUO], ["four", QUAD]]:
		for enc: String in group[1]:
			var wins := 0
			var stalls := 0
			var close := 0
			var contact := 0
			var rounds := 0
			var gap := 0
			for i in n:
				var grid := MapGen.valley(i, w, h, "snow")
				var party: Array = _helper().call("_party", 1, "sword") if group[0] == "duo" else _quad(1)
				for u: CombatUnit in party:
					_stretch(u)
				var r := _road(grid, party, enc, i)
				wins += 1 if r.winner == 0 else 0
				stalls += 1 if r.winner == -1 else 0
				if r.winner == 0 and (r.downs > 0 or r.party_pct < 40.0):
					close += 1
				contact += int(r.contact)
				rounds += int(r.rounds)
				gap += int(r.gap)
			print("| %s | %s | %.1f | %.1f | %d | %d | %d | %.1f |" % [group[0], enc, float(gap) / n, float(contact) / n,
				roundi(100.0 * wins / n), roundi(100.0 * close / n), roundi(100.0 * stalls / n), float(rounds) / n])
	print("")
	Db.reload()


## Explore-map fights as they are today (party first and ambushed, the balance script's setup): gap and contact.
func _explore_today(n: int) -> void:
	print("## Explore-map fights today (hero with a sword and the dog, level 1)\n")
	print("| map | group | start | start gap | rounds to contact | win % | stalls % |")
	print("| --- | --- | --- | --- | --- | --- | --- |")
	var helper := _helper()
	for map_name in ["snow_pass", "wolf_den", "crypt"]:
		var m := ExploreMap.load_named(map_name)
		helper.call("_open_ways", m)
		for g: Dictionary in m.groups:
			for how in ["party", "ambushed"]:
				var wins := 0
				var stalls := 0
				var contact := 0
				var gap := 0
				for i in n:
					var r := _explore_fight(helper, m, g, how, i)
					wins += 1 if r.winner == 0 else 0
					stalls += 1 if r.winner == -1 else 0
					contact += int(r.contact)
					gap += int(r.gap)
				print("| %s | %s | %s | %.1f | %.1f | %d | %d |" % [map_name, g.id, how, float(gap) / n, float(contact) / n,
					roundi(100.0 * wins / n), roundi(100.0 * stalls / n)])
	print("")


func _explore_fight(helper: RefCounted, m: ExploreMap, g: Dictionary, how: String, seed_i: int) -> Dictionary:
	var grid := m.grid
	var enemies: Array = []
	for e: Dictionary in g.units:
		var cls := Db.class_def(e.id)
		var depth := ExploreRules.group_depth(m.level, g)
		var u := CombatUnit.enemy(cls, ExploreRules.depth_mods(m.map_name, depth, String(g.id), g.units.find(e), cls))
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
	var path := ExploreRules.find_path(grid, m.start[0], helper.call("_near", grid, goal, blocked), 2, blocked)
	var at: Vector2i = m.start[0]
	for c in path:
		at = c
		var seen_them := ExploreRules.sees(grid, [c], cells, ExploreRules.PARTY_SIGHT)
		var they_see := ExploreRules.sees(grid, cells, [c], int(g.sight))
		if (how == "party" and seen_them) or they_see:
			break
	var party: Array = helper.call("_party", 1, "sword")
	for u: CombatUnit in party:
		u.place(at, grid.height_at(at))
	var spots := ExploreRules.auto_deploy(grid, party, how, blocked)
	var units: Array = []
	var seated: Array = []
	for u: CombatUnit in party:
		if spots.has(u):
			u.place(spots[u], grid.height_at(spots[u]))
			units.append(u)
			seated.append(u)
	units.append_array(enemies)
	return _play(grid, units, seated, enemies, seed_i)

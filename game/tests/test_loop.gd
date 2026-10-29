extends TestCase
## The end-to-end loop (2026-10-28): levels and Lodestone picks, overworld travel, items and needs,
## the village's new things and the boss, and that every event and text key the loop uses exists.

const CFG := {"xp_per_level": 100, "max_level": 40, "hp_per_level": 1, "choice_every": 4,
	"choice_hp": 3, "choice_attack": 1, "choice_magic": 2, "xp_win": 10, "xp_foe": 25, "xp_boss": 100}


func _db() -> void:
	if Db.levels.is_empty():
		Db.reload()


func test_levels_come_on_their_own() -> void:
	var s := LevelRules.fresh()
	eq(LevelRules.gain(s, 250, CFG), [2, 3] as Array[int], "250 XP: two levels")
	eq(int(s.xp), 50, "the rest carries")
	eq(int(s.pending), 0, "no pick before level 4")
	LevelRules.gain(s, 50, CFG)
	eq(int(s.level), 4)
	eq(int(s.pending), 1, "level 4 queues a pick")


func test_picks_and_bonus() -> void:
	var s := LevelRules.fresh()
	ok(not LevelRules.choose(s, "hp"), "no pick waiting")
	s.level = 4
	s.pending = 2
	ok(LevelRules.choose(s, "hp"))
	ok(LevelRules.choose(s, "magic"))
	ok(not LevelRules.choose(s, "attack"), "picks used up")
	var b := LevelRules.bonus(s, CFG)
	eq(int(b.hp), 3 + 3, "3 levels of +1 and one +3 pick")
	eq(int(b.magic_power), 2)
	eq(int(b.attack), 0)
	eq(LevelRules.fight_xp(3, false, CFG), 85)
	eq(LevelRules.fight_xp(2, true, CFG), 160)


func test_bonus_reaches_the_unit() -> void:
	_db()
	var m := {"def": Db.character(&"dog"), "hp": 5, "bonus": {"hp": 4, "attack": 1, "damage": 1, "magic_power": 2, "range_max": 1}}
	var u := CombatUnit.from_member(m)
	eq(u.max_hp, Db.character(&"dog").class_def.max_hp + 4)
	eq(u.attack, Db.character(&"dog").class_def.attack + 1)
	eq(u.magic_power, 2)
	eq(u.range_max, 2)


func test_travel_plan_and_fast_forward() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 20:
		var stops := TravelRules.plan(rng, 60.0, 1, 2)
		ok(stops.size() >= 1 and stops.size() <= 2, "one or two encounters")
		for t in stops:
			ok(t >= 12.0 and t <= 51.0, "in the middle of the walk")
	eq(TravelRules.next_stop(0.0, [20.0, 40.0], 60.0), 20.0)
	eq(TravelRules.next_stop(20.0, [20.0, 40.0], 60.0), 40.0, "fast forward from a stop goes to the next")
	eq(TravelRules.next_stop(41.0, [20.0, 40.0], 60.0), 60.0, "then to the end of the leg")
	eq(TravelRules.meals_between(0.0, 60.0), 2, "a 60 second leg is two meals")
	eq(TravelRules.meals_between(29.0, 31.0), 1)


func test_food_drains_and_starving_never_kills() -> void:
	_db()
	var r := RunState.create([Db.character(&"lead"), Db.character(&"dog")], 1)
	r.food = 3
	ok(TravelRules.eat(r))
	eq(r.food, 1)
	r.members[0].hp = 1
	ok(not TravelRules.eat(r), "not enough food")
	eq(r.food, 0)
	eq(int(r.members[0].hp), 1, "starving stops at 1 HP")


func test_eat_and_activities() -> void:
	_db()
	var r := RunState.create([Db.character(&"lead"), Db.character(&"dog")], 3)
	r.food = 2
	ok(not TravelRules.eat_one(r), "nobody hurt, nothing eaten")
	r.members[1].hp = 3
	ok(TravelRules.eat_one(r))
	eq(int(r.members[1].hp), 3 + TravelRules.EAT_HEAL)
	var acts := {}
	ok(TravelRules.can_act(acts, "hunt", 0.0))
	acts["hunt"] = 5.0
	ok(not TravelRules.can_act(acts, "hunt", 10.0), "cooldown")
	ok(TravelRules.can_act(acts, "hunt", 5.0 + TravelRules.ACT_COOLDOWN))
	var food := r.food
	var res := TravelRules.activity(r, "hunt")
	eq(r.food, food + int(res.food))


func test_paths_run_both_ways() -> void:
	_db()
	var a := TravelRules.path_between(Db.world_paths, "town", "pass")
	var b := TravelRules.path_between(Db.world_paths, "pass", "town")
	ok(not a.is_empty() and not b.is_empty())
	eq(a.points[0], b.points[b.points.size() - 1])
	eq(TravelRules.point_at(a.points, 0.0), a.points[0])
	eq(TravelRules.point_at(a.points, 1.0), a.points[a.points.size() - 1])
	eq(TravelRules.node_for_map(Db.world_nodes, "crypt"), "pass")
	eq(TravelRules.node_for_map(Db.world_nodes, "house_dog"), "town")
	for p in Db.world_paths:
		ok(Db.world_nodes.has(p.from) and Db.world_nodes.has(p.to), "path ends are places: %s %s" % [p.from, p.to])
		ok(int(p.enc_min) <= int(p.enc_max))


func test_rope_is_gear_and_needs_read_the_pack() -> void:
	_db()
	var r := RunState.create([Db.character(&"lead")], 1)
	TrailRules.apply_effects(r, "rope:+1")
	eq(r.item_count("rope"), 1)
	ok(r.slot_list().has("SLOT_ROPE"))
	ok(ExploreRules.need_met("item:rope", [], {"items": r.items}))
	ok(not ExploreRules.need_met("item:rope", [], {"items": {}}))
	ok(ExploreRules.need_met("flag:has_lodestone", [], {"flags": ["has_lodestone"]}))
	ok(ExploreRules.need_met("noflag:has_lodestone", [], {"flags": []}))
	ok(not ExploreRules.need_met("noflag:has_lodestone", [], {"flags": ["has_lodestone"]}))


func test_gate_needs_the_lodestone() -> void:
	_db()
	var ev: Dictionary = Db.explore_events["village_gate"]
	var keys := func(flags: Array) -> Array:
		return ExploreRules.options_for(ev, [], {"flags": flags}).map(func(o: Dictionary) -> String: return o.key)
	ok(not keys.call([]).has("OPT_GO_ON"), "no way out without the stone")
	ok(keys.call(["has_lodestone"]).has("OPT_GO_ON"))


func _thing(m: ExploreMap, id: String) -> Dictionary:
	for t in m.things:
		if t.id == id:
			return t
	return {}


func _reach(m: ExploreMap, from: Vector2i, id: String) -> bool:
	var all := {}
	for y in m.grid.h:
		for x in m.grid.w:
			all[Vector2i(x, y)] = true
	var blocked := {}
	for t in m.things:
		blocked[t.cell] = true
	var t := _thing(m, id)
	return not t.is_empty() and not ExploreRules.path_to_use(m.grid, from, t.cell, 1, blocked, all).is_empty()


func test_village_things_reachable() -> void:
	_db()
	var v := ExploreMap.load_named("village")
	var start: Vector2i = v.start[0]
	for id in ["statue", "dog_window", "west_door", "food_barrel", "smithy_rope", "weapon_rack", "gate"]:
		ok(_reach(v, start, id), "village: %s reachable from the cottage door" % id)
	ok(v.grid.passable(Game.SQUARE), "the wake-up cell is open ground")
	var d := ExploreMap.load_named("house_dog")
	ok(_reach(d, _thing(v, "dog_window").at, "dog"), "in through the window, the dog is right there")
	ok(_reach(d, _thing(v, "dog_window").at, "out"), "and the door is the way out")
	var h := ExploreMap.load_named("home")
	ok(_reach(h, h.start[0], "home_chest"))


## No stranded ground: every walkable cell of the town can be walked to from the cottage door on jump 1
## (stairs are the only way up a two-level step).
func test_village_ground_all_reachable() -> void:
	var g := ExploreMap.load_named("village").grid
	var start: Vector2i = ExploreMap.load_named("village").start[0]
	var seen := {start: true}
	var todo: Array[Vector2i] = [start]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d in CombatRules.DIRS:
			var n: Vector2i = c + d
			if not seen.has(n) and g.passable(n) and g.can_step(c, n, 1):
				seen[n] = true
				todo.append(n)
	var lost: Array[Vector2i] = []
	for y in g.h:
		for x in g.w:
			if g.passable(Vector2i(x, y)) and not seen.has(Vector2i(x, y)):
				lost.append(Vector2i(x, y))
	eq(lost.size(), 0, "village ground nobody can reach: %s" % str(lost.slice(0, 8)))


func test_boss_ends_the_test() -> void:
	var c := ExploreMap.load_named("crypt")
	var bosses := c.groups.filter(func(g: Dictionary) -> bool: return g.end)
	eq(bosses.size(), 1)
	ok(bosses[0].boss)
	ok(bosses[0].units.any(func(u: Dictionary) -> bool: return u.id == "lich"))


func test_loop_data_is_whole() -> void:
	_db()
	for name in ["village", "home", "house_dog", "snow_pass", "wolf_den", "crypt"]:
		var m := ExploreMap.load_named(name)
		for t in m.things:
			if String(t.event) != "":
				ok(Db.explore_events.has(t.event), "%s: event %s" % [name, t.event])
			if String(t.to) != "":
				ok(FileAccess.file_exists(ExploreMap.DIR + String(t.to) + ".json"), "%s: %s leads to %s" % [name, t.id, t.to])
			ok(Txt.has("EX_KIND_" + String(t.kind).to_upper()), "kind text " + String(t.kind))
		for g in m.groups:
			ok(Db.explore_events.has(g.event), "%s: group event %s" % [name, g.event])
			for u in g.units:
				ok(Db.class_def(u.id) != null, "class " + String(u.id))
	for ev in Db.travel_events:
		ok(Txt.has(ev.text_key), "travel text " + String(ev.text_key))
		for o in ev.options:
			ok(Txt.has(o.key), "option text " + String(o.key))
			for fx in [o.win, o.lose]:
				for part in String(fx).split(";", false):
					var kv := part.split(":")
					if kv[0] == "combat":
						ok(Db.encounters.has(kv[1]), "encounter " + kv[1])
	for id in Db.explore_events:
		var ev: Dictionary = Db.explore_events[id]
		ok(Txt.has(ev.text_key), "explore text " + String(ev.text_key))
		for o in ev.options:
			ok(Txt.has(o.key), "option text " + String(o.key))
	for id in Db.world_nodes:
		ok(Txt.has(Db.world_nodes[id].name_key))
	for id in Db.weapons:
		ok(Txt.has(Db.weapons[id].name_key))
	for p in LevelRules.PICKS:
		ok(Txt.has("UI_LS_PICK_" + p.to_upper()))


## [USER] 2026-10-28: no fog of war for now. The pass is drawn whole from the first step, every group stands
## in view, but spotting still waits for line of sight (nobody jumps the party from across the map).
func test_no_fog_of_war() -> void:
	_db()
	Game.save_enabled = false
	Game.reset_meta()
	Game.run = null
	Game.explore_map = "snow_pass"
	Game.explore_entry = Vector2i(-1, -1)
	var tree := Engine.get_main_loop() as SceneTree
	var s: Node = load("res://scenes/explore.tscn").instantiate()
	tree.root.add_child(s)
	ok(not s.board.fog_on, "the board draws every cell")
	eq(s.seen.size(), s.grid.w * s.grid.h, "the whole map counts as seen, so any cell can be walked to")
	var shown := 0
	for g: Dictionary in s.groups:
		shown += g.units.filter(func(u: CombatUnit) -> bool: return s.board.units.has(u)).size()
	eq(shown, 4, "both groups on the pass are in view")
	ok(s.in_sight.size() < s.grid.w * s.grid.h, "spotting still uses the party's line of sight")
	ok(s.mode == 0, "no group spotted at the foot of the pass")
	s.free()
	Game.explore_map = "home"


## Brandon's E2E notes (2026-10-28): wolves calmed by the dog, or beaten, came back and attacked after a trip
## into the wolf den and out. A map remembers its settled groups while the party is still on it, and a party
## stepping in beside a group gets the first look instead of an ambush.
func test_settled_groups_stay_settled() -> void:
	_db()
	Game.save_enabled = false
	Game.reset_meta()
	Game.run = null
	var tree := Engine.get_main_loop() as SceneTree
	Game.explore_map = "snow_pass"
	Game.explore_entry = Vector2i(-1, -1)
	var s: Node = load("res://scenes/explore.tscn").instantiate()
	tree.root.add_child(s)
	s.groups[0].state = "calm"
	s.groups[1].state = "gone"
	var den: Dictionary = {}
	for t: Dictionary in s.things:
		if t.id == "den_mouth":
			den = t
	s._travel(den)
	s.free()
	eq(Game.explore_map, "wolf_den")
	Game.explore_map = "snow_pass"
	Game.explore_entry = Vector2i(20, 24)  # right in front of where the wolves stood
	s = load("res://scenes/explore.tscn").instantiate()
	tree.root.add_child(s)
	eq(s.groups[0].state, "calm", "the calmed wolves are still calm")
	eq(s.groups[1].state, "gone", "the beaten bandits stay beaten")
	ok(s.mode == 0, "nobody attacks on the way back out")
	s.free()
	# A fresh group next to the door asks first.
	Game.explore_memory.clear()
	Game.explore_entry = Vector2i(21, 24)
	s = load("res://scenes/explore.tscn").instantiate()
	tree.root.add_child(s)
	ok(s.mode == 2 and s.groups[0].state == "noticed", "stepping in beside wolves: the party sees them first")
	s.free()
	Game.explore_memory.clear()
	Game.explore_map = "home"

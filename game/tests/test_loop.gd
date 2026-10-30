extends TestCase
## The end-to-end loop (2026-10-28): levels, rolled growth and skill ranks, overworld travel, items and needs,
## the village's new things and the boss, and that every event and text key the loop uses exists.

const CFG := {"xp_per_level": 100, "max_level": 40, "growth_hp": 2, "choice_every": 4,
	"xp_win": 10, "xp_foe": 25, "xp_boss": 100}


func _db() -> void:
	if Db.levels.is_empty():
		Db.reload()


func test_levels_come_on_their_own() -> void:
	var s := LevelRules.fresh()
	eq(LevelRules.gain(s, 250, CFG), [2, 3] as Array[int], "250 XP: two levels")
	eq(int(s.xp), 50, "the rest carries")
	eq(int(s.pending), 0, "no rank before level 4")
	LevelRules.gain(s, 50, CFG)
	eq(int(s.level), 4)
	eq(int(s.pending), 1, "level 4 queues a skill rank")
	eq(LevelRules.fight_xp(3, false, CFG), 85)
	eq(LevelRules.fight_xp(2, true, CFG), 160)


## [USER] pc-7: stats roll each level from the character's own odds; never a stat it can't use.
func test_growth_rolls_from_the_odds() -> void:
	_db()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var tank := {"hp": 80, "damage": 20, "armor": 40, "magic": 0, "crit": 5}
	var s := LevelRules.fresh()
	LevelRules.gain(s, 100 * 39, CFG, tank, rng)
	eq(int(s.level), 40)
	eq(int(s.gains.magic), 0, "a tank never gains magic")
	ok(int(s.gains.hp) > int(s.gains.damage) and int(s.gains.armor) > int(s.gains.crit), "mostly HP and armor (%s)" % [s.gains])
	ok(int(s.gains.damage) > 0, "now and then damage")
	var none := LevelRules.fresh()
	LevelRules.roll(none, {"hp": 0.001, "damage": 0, "armor": 0, "magic": 0, "crit": 0}, rng)
	eq(int(none.gains.hp), 1, "a level never comes up empty: the likeliest stat goes up")
	var b := LevelRules.bonus(s, CFG)
	eq(int(b.hp), int(s.gains.hp) * 2, "each HP roll is +2")
	eq(int(b.defense), int(s.gains.armor), "armor rides on the defense key")
	ok(Db.growth.has("dog") and float(Db.growth.dog.magic) == 0.0, "the dog's odds are data, with no magic")


## [USER] pc-8: a rank every 4 levels on one of the character's own skills, each adding an effect from data.
func test_skill_ranks() -> void:
	_db()
	var s := LevelRules.fresh()
	ok(not LevelRules.rank_up(s, "bite", Db.skill_ranks), "no rank waiting")
	s.pending = 4
	for i in 3:
		ok(LevelRules.rank_up(s, "bite", Db.skill_ranks))
	ok(not LevelRules.rank_up(s, "bite", Db.skill_ranks), "bite tops out at its last rank in data")
	eq(int(s.pending), 1)
	var bite := Db.ability("bite")
	var r1 := LevelRules.ranked(bite, 1, Db.skill_ranks)
	eq(r1.status_turns, bite.status_turns + 1, "rank 1: the slow lasts longer")
	eq(bite.status_turns, Db.ability("bite").status_turns, "the shared row is untouched")
	var r2 := LevelRules.ranked(bite, 2, Db.skill_ranks)
	eq(r2.bleed, 2, "rank 2 adds a bleed ([USER] pc-8's example)")
	var m := {"def": Db.character(&"dog"), "hp": 15, "ranks": {"bite": 2}}
	var u := CombatUnit.from_member(m)
	var ub: Ability = u.abilities.filter(func(a: Ability) -> bool: return a.id == "bite")[0]
	eq(ub.bleed, 2, "the dog fights with its ranked bite")
	var old := LevelRules.normalize({"level": 5, "xp": 10, "picks": {"hp": 1, "attack": 2, "magic": 0}, "pending": 1})
	eq(int(old.gains.hp), 4 + 3, "an old save keeps its +1 HP a level and its HP pick")
	eq(int(old.gains.damage), 2)


func test_bleed_ticks_at_the_start_of_its_phase() -> void:
	_db()
	var g := CombatGrid.flat(3, 1)
	var dog := CombatUnit.from_member({"def": Db.character(&"dog"), "hp": 15, "ranks": {"bite": 2}})
	dog.place(Vector2i(0, 0), 0)
	var wolf := CombatUnit.enemy(Db.class_def(&"wolf"))
	wolf.team = 1
	wolf.place(Vector2i(1, 0), 0)
	var bite: Ability = dog.abilities.filter(func(a: Ability) -> bool: return a.id == "bite")[0]
	CombatRules.resolve(RandomNumberGenerator.new(), g, dog, bite, wolf.cell, [dog, wolf], false)
	ok(wolf.has_status(CombatRules.STATUS_BLEED))
	var hp := wolf.hp
	var ev := CombatRules.begin_phase([dog, wolf], 1)
	eq(wolf.hp, maxi(0, hp - 1), "a point at the start of its phase")
	ok(ev.any(func(e: Dictionary) -> bool: return e.type == "bleed"))


func test_bonus_reaches_the_unit() -> void:
	_db()
	var m := {"def": Db.character(&"dog"), "hp": 5, "bonus": {"hp": 4, "attack": 1, "damage": 1, "magic_power": 2, "range_max": 1, "defense": 1}}
	var u := CombatUnit.from_member(m)
	eq(u.max_hp, Db.character(&"dog").class_def.max_hp + 4)
	eq(u.crit, Db.character(&"dog").class_def.crit + 5, "an attack bonus is crit")
	eq(u.armor, Db.character(&"dog").class_def.armor + 1, "a defense bonus is armor")
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
	ok(r.pack.items.any(func(it: Dictionary) -> bool: return it.id == "rope"), "the rope takes room in the pack")
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
			if String(t.kind) == "restore":
				ok(not RestoreRules.next_step(Db.restore, String(t.event), {}).is_empty(), "%s: restore %s" % [name, t.event])
			elif String(t.event) != "":
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
	for k in LevelRules.STATS:
		ok(Txt.has("UI_STAT_" + k.to_upper()))
	for id in Db.skill_ranks:
		ok(Db.ability(String(id)) != null, "ranks for a real skill: " + String(id))


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


## Playtester bug 01 (2026-10-29): a second start_fight while a fight was on made a second Battle, and the
## first one played on with no owner, throwing script errors when it ended. One fight at a time.
func test_one_fight_at_a_time() -> void:
	_db()
	Game.save_enabled = false
	Game.reset_meta()
	Game.run = null
	var tree := Engine.get_main_loop() as SceneTree
	Game.explore_map = "snow_pass"
	Game.explore_entry = Vector2i(-1, -1)
	var s: Node = load("res://scenes/explore.tscn").instantiate()
	tree.root.add_child(s)
	var auto := Battle.auto_fight
	Battle.auto_fight = true  # the fight begins at once, as in the robot
	s.start_fight(s.groups[0], "party")
	var first: Variant = s.battle
	s.start_fight(s.groups[0], "party")
	s.start_fight(s.groups[1], "party")
	Battle.auto_fight = auto
	ok(first != null and s.battle == first, "the fight on stays the fight")
	eq(s.find_children("*", "Battle", false, false).size(), 1, "one Battle in the scene")
	s.free()
	Game.explore_memory.clear()
	Game.explore_map = "home"


## [USER] 2026-10-29 (the boss-skip card): once the Lich King is beaten the pass shows as done, the place past
## it comes into view, and the party can walk past the pass to it without going in.
func test_a_cleared_place_opens_the_road_past_it() -> void:
	_db()
	var nodes := Db.world_nodes
	var paths := Db.world_paths
	ok(not TravelRules.cleared(nodes.pass, []), "the pass isn't done before the boss")
	ok(not TravelRules.visible(nodes, "beyond", []), "the place past it is hidden")
	eq(TravelRules.route(paths, nodes, "town", "beyond", []), [] as Array[String], "no way there yet")
	var flags := [String(nodes.pass.clear_flag)]
	ok(TravelRules.cleared(nodes.pass, flags), "the boss flag clears the pass")
	ok(TravelRules.visible(nodes, "beyond", flags), "and shows the place past it")
	eq(TravelRules.route(paths, nodes, "town", "beyond", flags), ["town", "pass", "beyond"] as Array[String], "the road runs past the pass")
	eq(TravelRules.route(paths, nodes, "beyond", "town", flags), ["beyond", "pass", "town"] as Array[String], "and back")
	eq(TravelRules.route(paths, nodes, "town", "pass", flags), ["town", "pass"] as Array[String], "the pass can still be gone into")
	eq(TravelRules.route(paths, nodes, "town", "prairie", flags), [] as Array[String], "shut places stay shut")
	ok(TravelRules.visible(nodes, "town", []) and not TravelRules.cleared(nodes.town, flags), "the town has nothing to clear")


func test_a_place_still_to_clear_blocks_the_road() -> void:
	var nodes := {
		"a": {"open": "1", "clear_flag": "", "after": ""},
		"b": {"open": "1", "clear_flag": "beat_b", "after": ""},
		"c": {"open": "1", "clear_flag": "", "after": ""},
	}
	var paths := [{"from": "a", "to": "b"}, {"from": "b", "to": "c"}]
	eq(TravelRules.route(paths, nodes, "a", "c", []), [] as Array[String], "can't walk past b before it's done")
	eq(TravelRules.route(paths, nodes, "a", "b", []), ["a", "b"] as Array[String], "but can walk to it")
	eq(TravelRules.route(paths, nodes, "a", "c", ["beat_b"]), ["a", "b", "c"] as Array[String], "and past it once it's done")


## [USER] 2026-10-29: Brandon's leaf frame along the bottom: the inventory button in the left square, the
## party in the right panel, and the map's click area kept clear of the band.
func test_leaf_frame_holds_pack_and_party() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var hud := FrameHud.new()
	tree.root.add_child(hud)
	hud.use_leaf_frame()
	hud._layout_leaf()
	var vs := hud.root.get_viewport_rect().size
	var s := vs.x / 2000.0
	ok(absf(hud.bottom_h - (261.0 - FrameHud.LEAF_BAND_TOP) * s) < 0.5, "the band is the bottom border")
	ok(hud.center_rect().end.y <= vs.y - hud.bottom_h + 0.5, "the map stops at the band")
	ok(hud.clear_rect().end.y < hud.center_rect().end.y, "a fitted map also clears the diamond")
	var pressed := [0]
	hud.set_tools([{"id": "pack", "text": "PACK", "cb": func() -> void: pressed[0] += 1}, {"text": "STONE", "cb": func() -> void: pass}])
	hud.leaf_pack.pressed.emit()
	eq(pressed[0], 1, "the left square opens PACK")
	eq(hud.tools_box.get_child_count(), 1, "only the other tools sit above the frame")
	hud.set_party([{"name": "A", "hp": 3, "max_hp": 5, "tint": Color.RED}, {"name": "B", "hp": 0, "max_hp": 5, "tint": Color.BLUE}])
	eq(hud.leaf_party.get_child_count(), 2, "the party in the right panel")
	ok(Rect2(Vector2.ZERO, vs).encloses(Rect2(hud.leaf_pack.position, hud.leaf_pack.size)), "the button is on screen")
	hud.free()


# --- the weapon is the job ([USER] pc-9, pc-12, pc-13; player-choice step 2) -----------------------

func _fresh_game() -> Dictionary:
	_db()
	var saved := {"meta": Game.meta.duplicate(true), "on": Game.save_enabled}
	Game.save_enabled = false
	Game.meta = Game._fresh_meta()
	Game.meta.flags = ["met_dog"]
	Game.start_adventure()
	return saved


func _restore(saved: Dictionary) -> void:
	Game.meta = saved.meta
	Game.save_enabled = saved.on
	Game.run = null


func test_the_weapon_makes_the_job() -> void:
	var saved := _fresh_game()
	eq(Game.job_id(), "", "bare hands: no job yet")
	eq(String(Game.hero_def().class_def.id), "nobody")
	Game.take_weapon("sword")
	eq(Game.job_id(), "knight")
	var hero: Dictionary = Game.run.members[0]
	eq(String((hero.def as CharacterDef).class_def.id), "job_knight", "the party's hero is a knight now")
	var u := CombatUnit.from_member(hero)
	ok(u.abilities.any(func(a: Ability) -> bool: return a.id == "shove"), "with the knight's skill")
	eq(u.res_kind, "rage")
	_restore(saved)


func test_switching_jobs_keeps_the_level() -> void:
	var saved := _fresh_game()
	Game.take_weapon("sword")
	Game.award_xp(100 * 9)  # level 10: the job is level 10 too
	var s := Game.level_state("lead")
	eq(int(s.level), 10)
	var gains: Dictionary = s.gains.duplicate()
	var js: Dictionary = s.jobs.knight
	eq(int(js.level), 10, "the job levels on the same XP")
	eq(int(js.pending), 2, "ranks every 4 job levels")
	ok(Game.rank_skill("lead", "shove"))
	ok(LevelRules.branch_ready(Game.rank_state("lead"), Db.levels), "job level 10: time to branch")
	ok(Game.choose_branch("b"))
	eq(String(Game.rank_state("lead").branch), "b")
	ok(not Game.choose_branch("a"), "one branch per job")
	Game.take_weapon("daggers")
	s = Game.level_state("lead")
	eq(Game.job_id(), "rogue")
	eq(int(s.level), 10, "the character level stays")
	eq(s.gains, gains, "and so do the rolled gains")
	eq(int(Game.rank_state("lead").level), 1, "the new job starts at 0")
	eq(Game.rank_state("lead").ranks, {}, "with no ranks")
	eq(String((Game.run.members[0].def as CharacterDef).class_def.id), "job_rogue", "stats shift to the rogue's base")
	Game.take_weapon("sword")
	eq(int(Game.rank_state("lead").ranks.get("shove", 0)), 1, "back to the sword: the knight's rank is still there")
	_restore(saved)


func test_the_rack_offers_what_the_hero_doesnt_hold() -> void:
	_db()
	var ev: Dictionary = Db.explore_events["smithy_rack"]
	var shown := func(flags: Array) -> Array:
		return ev.options.filter(func(o: Dictionary) -> bool: return ExploreRules.need_met(o.need, [], {"flags": flags})).map(func(o: Dictionary) -> String: return o.key)
	eq(shown.call([]), ["OPT_TAKE_SWORD", "OPT_TAKE_DAGGERS", "OPT_TAKE_BOW", "OPT_LEAVE"], "the book waits until it's found")
	eq(shown.call(["weapon_sword", "found_book"]), ["OPT_TAKE_DAGGERS", "OPT_TAKE_BOW", "OPT_TAKE_BOOK", "OPT_LEAVE"], "swap any time")
	var out := TrailRules.apply_effects(RunState.new(), "weapon:bow")
	eq(out.weapon, "bow")


# --- the party changes at home ([USER] pc-1, pc-10; player-choice step 3) --------------------------

func test_who_comes_along() -> void:
	var saved := _fresh_game()
	eq(Game.run.members.size(), 2, "the dog joins when he's met")
	Game.run.members[1].belt.put("potion", RunState.shape_of("potion"), 2, 3)
	var potions := Game.run.medicine
	Game.dismiss("dog")
	eq(Game.run.members.size(), 1, "left at home")
	ok(not Game.in_party("dog"))
	eq(Game.run.medicine, potions, "his belt went back into the pack")
	Game.start_adventure()
	eq(Game.run.members.size(), 1, "still home after a restart")
	ok(Game.invite("dog"))
	eq(Game.run.members.size(), 2, "and back on the next invite")
	eq(Game.party_max(), 4, "four fight")
	ok(ExploreRules.need_met("noparty:dog", [], {"party": ["lead"]}))
	ok(ExploreRules.need_met("party:dog", [], {"party": ["lead", "dog"]}))
	var out := TrailRules.apply_effects(RunState.new(), "invite:dog")
	eq(out.invite, "dog")
	_restore(saved)


func test_the_gate_asks_go_or_edit() -> void:
	var saved := _fresh_game()
	Game.explore_map = "village"
	Game.explore_entry = Vector2i(-1, -1)
	var s: Node = load("res://scenes/explore.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(s)
	s._apply_map_fx(["exit"], {})
	ok(s._gate_open, "the gate asks first")
	var texts: Array = s._dialog.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	ok(texts.has(Txt.t("UI_GATE_GO")) and texts.has(Txt.t("UI_GATE_PARTY")), "GO (F) and EDIT PARTY (P)")
	s._party_editor()
	texts = s._dialog.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	ok(texts.has(Txt.f("UI_PARTY_IN", Txt.t("CHAR_DOG"))), "the dog is listed, coming")
	s.free()
	Game.explore_memory.clear()
	Game.explore_map = "home"
	_restore(saved)


# --- elite fights ([USER] pc-6, pc-15; player-choice step 4) ---------------------------------------

func test_elite_groups_are_tougher_badged_and_stay_beaten() -> void:
	_db()
	var bandit: ClassDef = Db.class_def(&"bandit")
	var plain := CombatUnit.enemy(bandit)
	var elite := CombatUnit.enemy(bandit, ExploreRules.elite_mods())
	ok(elite.max_hp > plain.max_hp and elite.damage > plain.damage and elite.armor > plain.armor, "tougher all round")
	var g := {"id": "camp", "elite": true}
	ok(not ExploreRules.stays_beaten("snow_pass", g, []))
	ok(ExploreRules.stays_beaten("snow_pass", g, [ExploreRules.beaten_flag("snow_pass", "camp")]), "beaten once, gone for good")
	var maps := ["snow_pass", "wolf_den", "crypt"]
	eq(ExploreRules.elites_left(maps, []), 1, "the den's lone wolf is the first elite")
	eq(ExploreRules.elites_left(maps, [ExploreRules.beaten_flag("wolf_den", "den_lone")]), 0, "beaten, it's gone")


## The map loader keeps a group's goals, way out, TALK, elite mark and leader (they were dropped before).
func test_map_groups_keep_their_fight_data() -> void:
	_db()
	var grid := CombatGrid.flat(4, 4)
	var d := {"grid": grid.to_dict() if grid.has_method("to_dict") else {}, "groups": [{"id": "boss_camp", "goals": "leader|exit",
		"exit": [[0, 0]], "talk": {"unit": 0, "times": 2, "result": "flee"}, "elite": true,
		"units": [{"id": "bandit", "cell": [2, 2], "leader": true}]}]}
	var m := ExploreMap.from_dict(d)
	var g: Dictionary = m.groups[0]
	eq(g.goals, "leader|exit")
	eq(g.exit, [[0, 0]])
	eq(int(g.talk.times), 2)
	ok(g.elite)
	ok(g.units[0].leader, "the leader mark reaches the unit entry")


## [USER] c10: escaping the Lich King pays some XP, but it isn't beating him: no loot, no beaten flag, no end
## screen, and he's waiting there next time (the map builder's catch).
func test_an_escape_is_not_a_beating() -> void:
	var saved := _fresh_game()
	Game.explore_map = "crypt"
	Game.explore_entry = Vector2i(-1, -1)
	var s: Node = load("res://scenes/explore.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(s)
	var throne: Dictionary = s.groups.filter(func(g: Dictionary) -> bool: return g.def.id == "throne")[0]
	var b := Battle.new()
	b.outcome = {"how": "exit", "joined": []}
	b.units = throne.units.duplicate()
	s.battle = b
	var xp_before := int(Game.level_state("lead").xp) + int(Game.level_state("lead").level) * 100
	s._on_fight_over(true, [throne])
	ok(not Game.has_flag(ExploreRules.beaten_flag("crypt", "throne")), "not beaten")
	ok(not Game.has_flag("beat_lich"), "no loot, so the pass isn't cleared")
	ok(not Game.has_flag("e2e_done"), "no end screen")
	eq(throne.state, "escaped", "he's still there, leaving the party be for now")
	ok(int(Game.level_state("lead").xp) + int(Game.level_state("lead").level) * 100 > xp_before, "some XP")
	b.free()
	s.free()
	Game.explore_memory.clear()
	Game.explore_map = "home"
	_restore(saved)


# --- the bookmark save ([USER] omr-4, omr-11; one-more-run step 1) -------------------------------

func test_explore_memory_survives_json() -> void:
	var mem := {"crypt": {"seen": {Vector2i(3, 4): true, Vector2i(5, 6): true}, "done": ["chest_a"], "groups": {"cave": "gone"}}}
	var back := Game.memory_from_save(JSON.parse_string(JSON.stringify(Game.memory_to_save(mem))))
	eq(back.crypt.seen.size(), 2)
	ok(back.crypt.seen.has(Vector2i(5, 6)), "cells come back as cells")
	eq(back.crypt.groups, {"cave": "gone"})


func test_a_bookmark_comes_back_to_the_spot() -> void:
	var saved := _fresh_game()
	Game.run.adventure = true
	# bookmark() returns while saving is off (tests never write the real save), so build the record as it would
	Game.explore_memory = {"crypt": {"seen": {Vector2i(1, 1): true}, "done": ["x"], "groups": {}}}
	Game.travel = {"at": "pass"}
	Game.meta.bookmark = {"scene": "explore", "map": "crypt", "cell": [7, 9], "fight": {"group": "cave", "how": "party"},
		"memory": Game.memory_to_save(Game.explore_memory), "travel": Game.travel.duplicate()}
	Game.explore_memory = {}
	Game.travel = {"at": "town"}
	eq(Game.restore_bookmark(), Game.EXPLORE)
	eq(Game.explore_map, "crypt")
	eq(Game.explore_entry, Vector2i(7, 9), "right where the hero stood")
	ok(Game.explore_memory.crypt.seen.has(Vector2i(1, 1)), "the map remembered")
	eq(Game.travel, {"at": "pass"})
	eq(Game.resume_fight, {"group": "cave", "how": "party"}, "a quit fight is waiting to start over")
	# the explore scene starts it again from its first turn
	var s: Node = load("res://scenes/explore.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(s)
	ok(Game.resume_fight.is_empty())
	eq(s.mode, s.M.DEPLOY, "straight into the deploy, as the fight began")
	s.free()
	Game.explore_memory.clear()
	Game.explore_map = "home"
	Game.explore_entry = Vector2i(-1, -1)
	_restore(saved)


# --- restoring the village ([USER] omr-2, omr-5, omr-12; one-more-run step 2) ----------------------

const LADDER := [
	{"id": "forge_1", "building": "forge", "step": "1", "name_key": "X1", "needs": "metal:3;wood:2", "gives": "unlock:forge_hot", "settler": "smith_here"},
	{"id": "forge_2", "building": "forge", "step": "2", "name_key": "X2", "needs": "rare:1", "gives": "", "settler": ""},
]


func test_a_ladder_step_by_step() -> void:
	var rows: Array = LADDER.duplicate(true)
	var state := {}
	ok(not RestoreRules.is_open(rows, "forge", []), "shut until the settler moves in")
	ok(RestoreRules.is_open(rows, "forge", ["smith_here"]))
	var step := RestoreRules.next_step(rows, "forge", state)
	eq(step.id, "forge_1")
	var pile := {"metal": 2, "wood": 5}
	eq(RestoreRules.missing(step, pile), {"metal": 1})
	ok(not RestoreRules.pay(step, state, pile, 0), "one metal short")
	pile.metal = 4
	ok(RestoreRules.pay(step, state, pile, 0))
	eq(pile, {"metal": 1, "wood": 3}, "paid from the pile")
	eq(RestoreRules.next_step(rows, "forge", state).id, "forge_1", "under way, still the step to show")
	eq(RestoreRules.finish(rows, state, 0), [], "not done on the trip it was paid")
	eq(RestoreRules.finish(rows, state, 1).size(), 1, "done when the party comes home from the next trip")
	eq(RestoreRules.next_step(rows, "forge", state).id, "forge_2")


func test_paying_tracking_and_coming_home() -> void:
	var saved := _fresh_game()
	Db.restore.assign(LADDER.duplicate(true))
	Game.meta.flags.append("smith_here")
	Game.meta.materials = {"metal": 3, "wood": 2}
	Game.toggle_track("forge_2")
	eq(Array(Game.goal_lines()), ["X2: %s 1" % Txt.t("ITEM_RARE")], "the frame shows what the tracked step misses")
	var heard := []
	Game.counts.connect(func(t: String) -> void: heard.append(t))
	Game.run.add_item("rare", 1)
	eq(heard.size(), 1, "a pickup that counts says so")
	eq(Array(Game.goal_lines()), ["X2: %s" % Txt.t("UI_RESTORE_READY")])
	ok(Game.pay_step("forge_1"))
	eq(Game.meta.materials, {}, "the pile paid for it")
	Game.home_again()
	eq(RestoreRules.status(Game.meta.restore, "forge_1"), "paid", "coming home without a trip doesn't finish it")
	Game.start_trip()
	Game.home_again()
	eq(RestoreRules.status(Game.meta.restore, "forge_1"), "done", "home from a trip: done")
	ok(Game.has_flag("forge_hot"), "and it gives what it gives")
	for c in Game.counts.get_connections():
		Game.counts.disconnect(c.callable)
	Db.reload()  # the real ladders back
	_restore(saved)


## The first ladders ([USER] omr-3, pc-14; one-more-run step 3): the smithy, then each weapon's upgrades,
## and the inn's kitchen. All their needs are real items and every name has text.
func test_the_first_ladders() -> void:
	_db()
	var buildings := RestoreRules.buildings(Db.restore)
	for b in ["smithy", "inn", "sword", "daggers", "bow", "book"]:
		ok(buildings.has(b), "a ladder for " + b)
		ok(Txt.has("BUILDING_" + b.to_upper()), "a name for " + b)
	for r: Dictionary in Db.restore:
		ok(Txt.has(String(r.name_key)), "text for " + String(r.id))
		for id in RestoreRules.parse_needs(String(r.needs)):
			ok(Db.items.has(id) and String(Db.items[id].kind) == "material", "%s needs a material: %s" % [r.id, id])
	eq(RestoreRules.ladder(Db.restore, "sword").size(), 3, "upgrades +1 to +3")
	ok(not RestoreRules.is_open(Db.restore, "smithy", []), "the smithy waits for its smith")
	ok(RestoreRules.is_open(Db.restore, "smithy", ["settler_smith"]))
	ok(not RestoreRules.is_open(Db.restore, "sword", ["settler_smith"]), "upgrades wait for the sharpening stone")
	ok(RestoreRules.is_open(Db.restore, "sword", ["smithy_stone"]))


func test_a_sharper_sword_hits_harder() -> void:
	var saved := _fresh_game()
	Game.take_weapon("sword")
	var before := int(Game.weapon_mods("lead").damage)
	Game.meta.restore["sword_1"] = {"state": "done", "trip": 0}
	Game.meta.restore["sword_2"] = {"state": "done", "trip": 0}
	eq(Game.weapon_level("sword"), 2)
	eq(int(Game.weapon_mods("lead").damage), before + 2, "+1 damage a level")
	Game.take_weapon("bow")
	eq(Game.weapon_level("bow"), 0, "each weapon has its own upgrades")
	_restore(saved)


func test_a_shut_ladder_says_why() -> void:
	_db()
	eq(RestoreRules.opened_by(Db.restore, "sword").id, "smithy_2", "the sharpening stone opens the sword's upgrades")
	eq(RestoreRules.opened_by(Db.restore, "smithy"), {}, "the smith moving in opens the smithy")


# --- meals and camp ([USER] omr-9; one-more-run step 4) ---------------------------------------------

func test_cook_at_home_eat_at_camp() -> void:
	var saved := _fresh_game()
	Game.meta.materials = {"ingredient": 5, "herb": 1}
	ok(not Game.cook("stew"), "no kitchen yet")
	Game.meta.flags.append("kitchen_1")
	eq(Game.recipes_open().map(func(r: Dictionary) -> String: return r.id), ["stew"], "the first kitchen step opens the first recipe")
	ok(Game.cook("stew"))
	eq(int(Game.meta.materials.ingredient), 2, "its ingredients came from the village pile")
	eq(Game.run.item_count("meal_stew"), 1, "a meal to carry")
	eq(Game.run.pack.items.filter(func(it: Dictionary) -> bool: return it.id == "meal_stew")[0].shape.size(), 2, "it takes a full slot")
	var hero: Dictionary = Game.run.members[0]
	var hp := Game.run.max_hp(hero)
	ok(Game.eat_meal("meal_stew"))
	eq(Game.run.item_count("meal_stew"), 0)
	eq(Game.run.max_hp(hero), hp + 4, "the buff: +4 HP")
	Game.fight_done()
	eq(int(Game.run.meal.fights), 1, "one fight down")
	Game.fight_done()
	ok(Game.run.meal.is_empty(), "two fights and it's gone")
	eq(Game.run.max_hp(hero), hp)
	_restore(saved)


# --- blessings and setbacks ([USER] omr-6, omr-7, omr-8; one-more-run step 5) ----------------------

func test_blessings_and_setbacks_last_till_home() -> void:
	var saved := _fresh_game()
	_db()
	eq(Db.boons.keys().filter(func(id: String) -> bool: return Db.boons[id].kind == "blessing").size(), 10, "about ten blessings")
	eq(Db.boons.keys().filter(func(id: String) -> bool: return Db.boons[id].kind == "setback").size(), 6, "about six setbacks")
	var out := TrailRules.apply_effects(Game.run, "blessing:any;setback:any")
	eq([out.blessings, out.setbacks], [1, 1])
	var lines := Game.absorb_boons({"blessings": 7})
	eq(lines.size(), 5, "five blessings at most")
	eq(Game.run.boons.size(), 5)
	Game.run.boons.assign(["strong_arms", "spoiled_food"])
	Game.refresh_party()
	var hero := CombatUnit.from_member(Game.run.members[0])
	ok(Game.run.food_need() > 0 and Game.run.food_extra == 1, "spoiled food: each meal costs one more")
	Game.run.boons.clear()
	Game.refresh_party()
	eq(hero.damage, CombatUnit.from_member(Game.run.members[0]).damage + 1, "strong arms: +1 damage")
	Game.run.boons.assign(["hot_blood"])
	Game.home_again()
	ok(Game.run.boons.is_empty(), "home: gone")
	_restore(saved)


func test_boon_rules_in_a_fight() -> void:
	_db()
	var g := CombatGrid.flat(3, 1)
	var k := CombatUnit.enemy(Db.class_def(&"knight"), {"rage_per_hit": 1, "crit_heal": 1, "start_res": 2})
	k.team = 0
	k.place(Vector2i(0, 0), 0)
	eq(k.res, 2, "start the fight with 2 rage")
	var b := CombatUnit.enemy(Db.class_def(&"bandit"))
	b.place(Vector2i(1, 0), 0)
	b.max_hp = 99
	b.hp = 99
	k.hp = 5
	var rng := RandomNumberGenerator.new()
	CombatRules.resolve(rng, g, k, k.abilities[0], b.cell, [k, b], false)
	eq(k.res, 4, "two rage a hit with hot blood")
	var healed := false
	for i in 60:
		var ev := CombatRules.resolve(rng, g, k, k.abilities[0], b.cell, [k, b], false)
		if ev.any(func(e: Dictionary) -> bool: return e.type == "heal" and e.unit == k):
			healed = true
			break
		b.hp = 99
	ok(healed, "a crit heals the striker")

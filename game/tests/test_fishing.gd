extends TestCase
## The fishing minigame's rules ([USER] 2026-11-01: Look, Strike, Reel with a horizontal reel bar).


func _db() -> void:
	if Db.levels.is_empty():
		Db.reload()


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func test_fish_table() -> void:
	_db()
	ok(Db.fish.size() >= 5, "fish kinds load from data/fish.csv")
	for id in Db.fish:
		var row: Dictionary = Db.fish[id]
		ok(FishingRules.GRADES.has(String(row.grade)), "%s has a grade" % id)
		ok(Txt.has(String(row.name_key)), "%s has placeholder text" % id)
		for item: String in FishingRules.reward(row):
			ok(Db.items.has(item), "%s gives a real item (%s)" % [id, item])
	ok(Db.fish.values().any(func(r: Dictionary) -> bool: return String(r.grade) == "prize"), "a prize fish exists")


func test_look_pool_and_shadows() -> void:
	_db()
	var lake := FishingRules.pool(Db.fish, "lake")
	var road := FishingRules.pool(Db.fish, "road")
	ok(lake.any(func(r: Dictionary) -> bool: return String(r.id) == "king"), "the lake holds the prize")
	ok(not road.any(func(r: Dictionary) -> bool: return String(r.id) == "king"), "the road's rivers don't")
	var sh := FishingRules.shadows(_rng(4), lake, 4)
	eq(sh.size(), 4, "four shadows in the pool")
	for i in sh.size():
		for j in range(i + 1, sh.size()):
			ok((sh[i].home as Vector2).distance_to(sh[j].home) >= 0.2, "shadows spread out")
	var p := FishingRules.shadow_pos(sh[0], 3.0)
	eq(FishingRules.nearest(sh, p, 3.0), 0, "clicking a shadow picks it")
	eq(FishingRules.nearest(sh, Vector2(-1, -1), 3.0), -1, "clicking dry land picks none")
	# weights: the common fish comes up far more than the prize
	var r := _rng(9)
	var n := {}
	for i in 2000:
		var id := String(FishingRules.pick(r, lake).id)
		n[id] = int(n.get(id, 0)) + 1
	ok(int(n.get("minnow", 0)) > int(n.get("king", 0)) * 5, "the prize is rare")


func test_strike_false_nibbles_then_the_dip() -> void:
	_db()
	var row: Dictionary = Db.fish["perch"]
	for s in 30:
		var plan := FishingRules.strike_plan(_rng(s), row)
		var bite := float(plan.bite)
		ok(bite >= FishingRules.tune("fish_wait_min", 0) and bite <= FishingRules.tune("fish_wait_max", 0), "the bite comes in the wait range")
		for nib: float in plan.nibbles:
			ok(nib < bite, "nibbles come before the bite")
			eq(FishingRules.bobber_at(plan, nib + 0.1), "nibble", "the bobber nibbles")
			eq(FishingRules.strike(plan, nib + 0.1), "early", "striking on a nibble scares the fish")
		eq(FishingRules.bobber_at(plan, bite + 0.05), "bite", "then it truly dips")
		eq(FishingRules.strike(plan, bite + 0.05), "hit", "strike on the dip")
		eq(FishingRules.strike(plan, bite + float(plan.window) + 0.05), "late", "too slow")
		eq(FishingRules.bobber_at(plan, bite + float(plan.window) + 0.05), "gone", "and the fish is gone")
	var king := FishingRules.strike_plan(_rng(1), Db.fish["king"])
	var minnow := FishingRules.strike_plan(_rng(1), Db.fish["minnow"])
	ok(float(king.window) < float(minnow.window), "the prize gives a shorter window")


## A perfect follower lands the fish; a marker left still loses it.
func test_reel_bar_rewards_following_the_fish() -> void:
	_db()
	for id in Db.fish:
		var row: Dictionary = Db.fish[id]
		var r := _rng(7)
		var s := FishingRules.reel_start(row)
		var t := 0.0
		while s.done == "" and t < 60.0:
			FishingRules.reel_step(s, r, 1.0 / 60.0, {"mouse": float(s.fish)})
			t += 1.0 / 60.0
		eq(s.done, "caught", "%s: staying on it lands it" % id)
		ok(t < 20.0, "%s: in under 20 seconds (%.1f)" % [id, t])
	var lazy := FishingRules.reel_start(Db.fish["pike"])
	var r2 := _rng(3)
	var t2 := 0.0
	lazy.marker = 0.11
	while lazy.done == "" and t2 < 60.0:
		FishingRules.reel_step(lazy, r2, 1.0 / 60.0, {"axis": 0.0})
		t2 += 1.0 / 60.0
	eq(lazy.done, "lost", "a marker parked at the edge loses the fish")


func test_reel_marker_has_a_top_speed() -> void:
	_db()
	var s := FishingRules.reel_start(Db.fish["minnow"])
	FishingRules.reel_step(s, _rng(1), 0.1, {"mouse": 1.0})
	ok(absf(float(s.marker) - 0.5) <= FishingRules.tune("fish_marker_speed", 0) * 0.1 + 0.0001, "the mouse can't snap the marker across")
	var k := FishingRules.reel_start(Db.fish["minnow"])
	for i in 30:
		FishingRules.reel_step(k, _rng(1), 1.0 / 60.0, {"axis": 1.0})
	ok(float(k.marker) > 0.5, "keys and stick push it right")
	for i in 600:
		FishingRules.reel_step(k, _rng(1), 1.0 / 60.0, {"axis": 1.0})
	ok(float(k.marker) <= 1.0 - float(k.half) + 0.0001, "never off the bar")
	ok(absf(float(k.pull)) <= 1.0, "the rod's pull stays in range")


func test_party_skill_slows_the_fish() -> void:
	_db()
	var plain := RunState.create([Db.character(&"lead")], 1)
	var with_hunter := RunState.create([Db.character(&"lead"), Db.character(&"hunter")], 1)
	var a := FishingRules.mods_for(plain)
	var b := FishingRules.mods_for(with_hunter)
	eq(int(b.skill), 3, "the hunter fishes (fish 3)")
	ok(float(b.slow) > float(a.slow), "a fisher in the party slows the fish")
	ok(float(FishingRules.reel_start(Db.fish["pike"], b).speed) < float(FishingRules.reel_start(Db.fish["pike"], a).speed), "on the bar")
	ok(float(b.slow) <= FishingRules.tune("fish_skill_slow_max", 0), "but only so much")


func test_landing_a_fish_fills_the_pack() -> void:
	_db()
	var run := RunState.create([Db.character(&"lead")], 1)
	var got := FishingRules.land(run, Db.fish["king"])
	eq(got, {"fish_prize": 1, "ingredient": 2, "rare": 1}, "the prize's reward")
	eq(run.item_count("rare"), 1, "in the pack")


## Raw fish are rations ([USER] 2026-11-01 on dev-fish-review: "Uncooked fish should count as rations, or you need to go
## home and put them in actual recipes"): they feed by size and heal nobody; at home they go to the village pile, where
## the kitchen's fish recipes cook them into meals that heal.
func test_fish_feed_and_cook_at_home() -> void:
	_db()
	var portions: Array[int] = []
	for grade in ["small", "good", "prize"]:
		var item: String = "fish_" + String(grade)
		ok(not TravelRules.is_food(item), item + " doesn't heal raw")
		eq(RunState.heal_per_portion(item), 0.0, item + " only feeds")
		portions.append(int(Db.items[item].food))
		eq(ActionInfo.icon(item), ActionInfo.icon("fish"), item + " borrows the fish icon")
	eq(portions, [1, 2, 3] as Array[int], "portions by size")
	for id: String in Db.fish:  # every catch gives a fish
		ok(FishingRules.reward(Db.fish[id]).keys().any(func(k: String) -> bool: return k.begins_with("fish_")), id + " gives a fish")
	var run := RunState.create([Db.character(&"lead")], 1)
	FishingRules.land(run, Db.fish["minnow"])
	FishingRules.land(run, Db.fish["minnow"])
	eq(run.portions_of("fish_small"), 2, "two small fish feed two portions")
	var banked := run.bank_materials()
	eq(int(banked.get("fish_small", 0)), 2, "home: the fish go to the village pile")
	eq(run.item_count("fish_small"), 0)
	var cooks := Db.recipes.values().filter(func(r: Dictionary) -> bool: return String(r.needs).contains("fish_"))
	ok(not cooks.is_empty(), "the kitchen has fish recipes")
	for r: Dictionary in cooks:
		ok(int(r.heal) > 0 and String(Db.items[String(r.meal)].kind) == "meal", String(r.id) + " is a cooked meal that heals")


## The minigame on screen: it opens over a scene, runs its beats, and reports once.
func test_minigame_opens_and_reports_once() -> void:
	_db()
	var host := Node.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	var g := FishingGame.open(host, "lake", {}, 5)
	eq(g.state, FishingGame.S.LOOK, "opens on Look")
	ok(g._shadows.size() > 0, "with shadows")
	var got: Array = []
	g.finished.connect(func(res: Dictionary) -> void: got.append(res))
	g._cast(0)
	eq(g.state, FishingGame.S.CAST, "casting")
	g._process(FishingGame.CAST_TIME + 0.01)
	eq(g.state, FishingGame.S.STRIKE, "the bobber lands")
	g._strike_now()
	eq(g.state, FishingGame.S.RESULT, "striking at once is too soon")
	eq(String(g.result.outcome), "early", "and scares the fish")
	g._phase_t = 1.0
	g._press(false)
	g._press(false)
	eq(got.size(), 1, "reports once")
	host.free()

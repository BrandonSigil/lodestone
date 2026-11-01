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


## The player's "hand" for tests: pulls toward the fish (an axis between -1 and 1), the way a good player holds and lets go.
func _follow(s: Dictionary) -> Dictionary:
	return {"axis": clampf((float(s.fish) - float(s.marker)) * 10.0, -1.0, 1.0)}


## A follower lands the fish; a marker pinned to one side loses it.
func test_reel_bar_rewards_following_the_fish() -> void:
	_db()
	for id in Db.fish:
		var row: Dictionary = Db.fish[id]
		var r := _rng(7)
		var s := FishingRules.reel_start(row)
		var t := 0.0
		while s.done == "" and t < 60.0:
			FishingRules.reel_step(s, r, 1.0 / 60.0, _follow(s))
			t += 1.0 / 60.0
		eq(s.done, "caught", "%s: following it lands it" % id)
		ok(t < 25.0, "%s: in under 25 seconds (%.1f)" % [id, t])
	var lazy := FishingRules.reel_start(Db.fish["pike"])
	var r2 := _rng(3)
	var t2 := 0.0
	while lazy.done == "" and t2 < 90.0:
		FishingRules.reel_step(lazy, r2, 1.0 / 60.0, {"axis": 1.0})
		t2 += 1.0 / 60.0
	eq(lazy.done, "lost", "a marker held to the right edge loses the fish")


## FI3 ([USER] 2026-11-01): the fish and the marker start in the middle and the fish eases in.
func test_reel_starts_centred_and_eases_in() -> void:
	_db()
	var s := FishingRules.reel_start(Db.fish["pike"])
	eq(float(s.fish), 0.5, "the fish starts in the middle")
	eq(float(s.marker), 0.5, "so does the marker")
	for i in 30:  # half a second, hands off: nothing has happened yet
		FishingRules.reel_step(s, _rng(1), 1.0 / 60.0, {})
	eq(float(s.fish), 0.5, "the fish hovers before its first dart")
	ok(bool(s.on) and s.done == "", "and the marker is still on it")
	ok(FishingRules.ramp(s) < 0.2, "the ramp has barely started")
	# early on the meter drains slower than at full difficulty
	var early := FishingRules.reel_start(Db.fish["pike"])
	var late := FishingRules.reel_start(Db.fish["pike"])
	late.t = FishingRules.tune("fish_ease", 4.0)
	early.marker = 0.11
	late.marker = 0.11
	early.fish = 0.9
	late.fish = 0.9
	early.wait = 9.0
	late.wait = 9.0
	early.started = true  # both fish are already pulling (the meter holds still before the first dart)
	late.started = true
	var early_catch := float(early.catch)
	FishingRules.reel_step(early, _rng(1), 0.5, {"axis": -1.0})
	FishingRules.reel_step(late, _rng(1), 0.5, {"axis": -1.0})
	ok(early_catch > float(early.catch) and float(early.catch) > float(late.catch), "the meter drains less in the ease-in")
	eq(FishingRules.ramp(late), 1.0, "after fish_ease seconds it is full difficulty")
	# no fish is landed before it pulls: the meter holds still while it hovers before its first dart
	var hover := FishingRules.reel_start(Db.fish["minnow"])
	var start_catch := float(hover.catch)
	for i in 60:
		FishingRules.reel_step(hover, _rng(1), 1.0 / 60.0, {})
	eq(float(hover.catch), start_catch, "the meter waits for the first dart")
	ok(hover.done == "", "and the fish is not landed yet")


## FI4 ([USER] 2026-11-01): holding left or right pulls the marker that way; let go and it springs back to the centre.
func test_reel_hold_pulls_and_release_springs_back() -> void:
	_db()
	for dir in [-1.0, 1.0]:
		var s := FishingRules.reel_start(Db.fish["minnow"])
		s.wait = 99.0  # the fish stays put: this is only the marker
		for i in 40:
			FishingRules.reel_step(s, _rng(1), 1.0 / 60.0, {"axis": dir})
		ok((float(s.marker) - 0.5) * dir > 0.05, "held %s: the marker is pulled that way" % ("left" if dir < 0 else "right"))
		for i in 120:
			FishingRules.reel_step(s, _rng(1), 1.0 / 60.0, {})
		ok(absf(float(s.marker) - 0.5) < 0.03, "let go: it is back at the centre")
		ok(absf(float(s.vel)) < 0.2, "and settled")
	ok(is_equal_approx(FishingRules.axis_from_pointer(500.0, 500.0, 100.0), 0.0), "a pointer in the middle pulls nothing")
	ok(FishingRules.axis_from_pointer(900.0, 500.0, 100.0) == 1.0 and FishingRules.axis_from_pointer(0.0, 500.0, 100.0) == -1.0, "a pointer far left or right pulls fully")


func test_reel_marker_has_a_top_speed() -> void:
	_db()
	var k := FishingRules.reel_start(Db.fish["minnow"])
	k.wait = 99.0
	for i in 30:
		FishingRules.reel_step(k, _rng(1), 1.0 / 60.0, {"axis": 1.0})
	ok(float(k.marker) > 0.5, "keys and stick push it right")
	ok(float(k.vel) <= FishingRules.tune("fish_marker_speed", 0) + 0.0001, "never faster than the top speed")
	for i in 600:
		FishingRules.reel_step(k, _rng(1), 1.0 / 60.0, {"axis": 1.0})
	ok(float(k.marker) <= 1.0 - float(k.half) + 0.0001, "never off the bar")
	ok(absf(float(k.pull)) <= 1.0, "the rod's pull stays in range")


## FI2 ([USER] 2026-11-01): a pond holds a few fish and a catch or a lost fish is gone for good.
func test_pond_runs_out() -> void:
	_db()
	var lake := FishingRules.pool(Db.fish, "lake")
	var pond := FishingRules.new_pond(_rng(5), lake, 3)
	eq(pond.size(), 3, "a pond holds the pond size")
	for id in pond:
		ok(Db.fish.has(String(id)), "%s is a real fish" % id)
	var rows: Array[Dictionary] = []
	for id in pond:
		rows.append(Db.fish[String(id)])
	var sh := FishingRules.shadows_of(_rng(2), rows)
	eq(sh.size(), 3, "a shadow for each fish")
	eq(sh.map(func(x: Dictionary) -> int: return int(x.pond_i)), [0, 1, 2], "each knows its place in the pond")
	for outcome in ["caught", "lost", "early", "late"]:
		ok(FishingRules.GONE.has(outcome), "%s takes the fish out of the pond" % outcome)
	ok(not FishingRules.GONE.has("left"), "leaving takes nothing")
	# through the overlay: a lost fish comes out of the stored pond, and the pond is kept in the save
	var saved: Dictionary = Game.meta.get("ponds", {}).duplicate(true)
	var was := Game.save_enabled
	Game.save_enabled = false
	var kept := Game.pond("test/pond", "lake")
	eq(kept.size(), 3, "Game.pond makes the pond once")
	var again := Game.pond("test/pond", "lake")
	ok(again == kept, "and gives the same one back")
	var g := FishingGame.open(Game, "lake", {}, 1, kept)
	eq(g._shadows.size(), 3, "the overlay draws the pond's fish")
	g._hook = 1
	g._end("lost")
	eq(kept.size(), 2, "a lost fish is gone from the pond")
	eq(g._shadows.size(), 3, "(the picture keeps this cast's shadows)")
	g._finish()
	var empty := FishingGame.open(Game, "lake", {}, 1, [])
	g = empty
	eq(empty._shadows.size(), 0, "an empty pond shows no shadows")
	empty._aim = Vector2(0.5, 0.5)
	empty._cast_aimed()
	ok(empty.state == FishingGame.S.LOOK, "and takes no cast")
	empty._finish()
	Game.meta["ponds"] = saved
	Game.save_enabled = was


## FI1 ([USER] 2026-11-01): the cast is aimed, and a fish near where the bobber lands may notice it.
func test_a_fish_near_the_bobber_notices() -> void:
	_db()
	var sh := FishingRules.shadows(_rng(4), FishingRules.pool(Db.fish, "lake"), 3)
	var spot := FishingRules.shadow_pos(sh[0], 2.0)
	var hits := 0
	for i in 200:
		if FishingRules.noticed(_rng(i), sh, spot, 2.0) == 0:
			hits += 1
	ok(hits > 150, "right beside a fish it nearly always notices (%d of 200)" % hits)
	var edge := spot + Vector2(FishingRules.tune("fish_notice", 0.18) * 0.95, 0.0)
	var maybe := 0
	for i in 400:
		if FishingRules.noticed(_rng(i), sh, edge, 2.0) == 0:
			maybe += 1
	ok(maybe > 0 and maybe < 200, "at the edge of its reach only sometimes (%d of 400)" % maybe)
	var far := Vector2(-5, -5)
	eq(FishingRules.noticed(_rng(1), sh, far, 2.0), -1, "a bobber far from every fish is not noticed")
	# up and down count for less than sideways (the pool is wider than tall)
	ok(FishingRules.POOL_ASPECT < 1.0, "the pool is wider than tall")


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
	eq(g._pond.size(), int(FishingRules.tune("fish_pond_size", 3)), "a fresh pond")
	g._aim = Vector2(0.01, 0.01)
	g._cast_aimed()
	eq(g.state, FishingGame.S.LOOK, "dry land takes no cast")
	g._aim = FishingRules.shadow_pos(g._shadows[0], g._t)
	g._cast_aimed()
	eq(g.state, FishingGame.S.CAST, "casting at the aim")
	g._process(FishingGame.CAST_TIME + 0.01)
	eq(g.state, FishingGame.S.CAST, "the bobber has landed and settles a moment ([USER] 2026-11-01 calm beats)")
	g._process(FishingRules.tune("fish_settle", 0.8))
	ok(g.state == FishingGame.S.COME or g.state == FishingGame.S.WAIT, "then a fish notices or none does")
	for i in 40:  # beside a shadow: sooner or later one swims over
		if g.state == FishingGame.S.WAIT:
			g._notice()
	eq(g.state, FishingGame.S.COME, "a fish comes to it")
	g._process(FishingRules.tune("fish_approach", 0.9) + 0.01)
	eq(g.state, FishingGame.S.STRIKE, "and the nibbling starts")
	g._strike_now()
	eq(g.state, FishingGame.S.SWIM_OFF, "striking at once is too soon: the fish swims off")
	eq(String(g.result.outcome), "early", "scared")
	eq(g._pond.size(), int(FishingRules.tune("fish_pond_size", 3)) - 1, "and gone from the pond for good")
	g._process(FishingRules.tune("fish_lost_beat", 1.0) + 0.01)
	eq(g.state, FishingGame.S.RESULT, "then its card")
	g._phase_t = 1.0
	g._press(false)
	g._press(false)
	eq(got.size(), 1, "reports once")
	host.free()
	# a good strike: HOOKED! for a beat before the reel bar; a catch's card holds a while before a click closes it
	var host2 := Node.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host2)
	var g2 := FishingGame.open(host2, "lake", {}, 5)
	g2._aim = FishingRules.shadow_pos(g2._shadows[0], g2._t)
	g2._cast_aimed()
	g2._process(FishingGame.CAST_TIME + FishingRules.tune("fish_settle", 0.8) + 0.01)
	for i in 40:
		if g2.state == FishingGame.S.WAIT:
			g2._notice()
	g2._process(FishingRules.tune("fish_approach", 0.9) + 0.01)
	g2._phase_t = float(g2._plan.bite) + 0.05
	g2._strike_now()
	eq(g2.state, FishingGame.S.HOOKED, "a good strike: HOOKED!")
	g2._process(FishingRules.tune("fish_hooked_beat", 1.0) + 0.01)
	eq(g2.state, FishingGame.S.REEL, "then the reel")
	g2._end("caught")
	eq(g2.state, FishingGame.S.RESULT, "a catch goes straight to its card")
	var got2: Array = []
	g2.finished.connect(func(res: Dictionary) -> void: got2.append(res))
	g2._phase_t = 0.5
	g2._press(false)
	eq(got2.size(), 0, "the catch shows a while: an early click doesn't close it")
	g2._phase_t = FishingRules.tune("fish_catch_beat", 1.5) + 0.01
	g2._press(false)
	eq(got2.size(), 1, "then a click does")
	host2.free()

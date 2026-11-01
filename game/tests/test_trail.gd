extends TestCase


func _run(ids: Array, food := 40) -> RunState:
	var r := RunState.create(members_of(ids), 1)
	r.food = food
	return r


func test_no_daily_meal() -> void:
	var r := _run(["lead", "stardrop", "lewith_flark"], 20)
	TrailRules.end_day(r)
	eq(r.food, 20, "nobody eats on the clock ([USER] 2026-10-31: no hunger)")
	eq(r.day, 2)


func test_bushberry_and_skeleton() -> void:
	var r := _run(["bushberry", "skeleton_archer"], 5)
	var morale := r.morale
	TrailRules.end_day(r)
	eq(r.food, 6, "bush adds 1")
	eq(r.morale, morale - 2, "skeleton is gloomy")


func test_no_food_no_harm() -> void:
	var r := _run(["lead", "hunter"], 0)
	var hp: int = r.members[0].hp
	TrailRules.end_day(r)
	eq(r.members[0].hp, hp, "no food hurts nobody")
	eq(r.morale, 70)


func test_wizard_books_fill_slots() -> void:
	var plain := _run(["lead"], 40)
	var wiz := _run(["lead", "wizard"], 40)
	eq(wiz.pack.used_cells(), plain.pack.used_cells() + 3)
	wiz.add_food(200)
	eq(wiz.food, (wiz.pack.capacity() - 3 - 1) * 10, "the books and a potion cell leave 8 cells of meat; overflow is lost")


func test_travel_and_wall() -> void:
	var r := _run(["lead", "stardrop"], 100)
	r.distance = RunState.WALL - 5
	TrailRules.travel(r, false)
	ok(r.distance > RunState.WALL - 5)
	r.distance = RunState.WALL - 1
	TrailRules.apply_effects(r, "dist:+5")
	ok(r.passed_wall)


func test_party_bonus_uses_best_member() -> void:
	var r := _run(["lead", "stardrop"])
	r.morale = 50
	eq(TrailRules.party_bonus(r, "wayfind"), 6, "stardrop: mage 2 + off-class 4")
	r.morale = 20
	eq(TrailRules.party_bonus(r, "wayfind"), 4, "low morale -2")


func test_effects() -> void:
	var r := _run(["lead"], 10)
	var fx := TrailRules.apply_effects(r, "food:+5;gold:-100;morale:+50;unlock:found_bushberry;combat:wolves")
	eq(r.food, 15)
	eq(r.gold, 0)
	eq(r.morale, 100)
	eq(fx.unlocks, ["found_bushberry"])
	eq(fx.combat, "wolves")


func test_event_filters() -> void:
	var events := Db.parse_events(CsvTable.load_rows("res://data/events.csv"))
	var r := _run(["lead"])
	for i in 200:
		var ev := TrailRules.pick_event(r, events, ["found_bushberry"])
		ok(ev.id != "bush", "once_flag hides the bush")
		ok(ev.min_s <= 0.0, "home events only at strangeness 0")
	r.distance = RunState.GOAL
	var seen := {}
	for i in 200:
		seen[TrailRules.pick_event(r, events, []).id] = true
	ok(seen.has("fruit") and not seen.has("bandits"), "deep events past the Wall")


func test_heal_uses_medicine() -> void:
	var r := _run(["lead"])
	r.members[0].hp = 3
	r.medicine = 1
	TrailRules.heal(r)
	eq(r.medicine, 0)
	ok(r.members[0].hp > 3)


func test_wipe() -> void:
	var r := _run(["lead"])
	r.hurt(r.members[0], 999)
	ok(r.wiped())

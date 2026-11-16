extends TestCase
## The campfire ([USER] 2026-11-16, docs/systems/camp.md): one pot on a ration dial, the evening's actions once a
## night each, and SAME AS LAST NIGHT.

var _keep := {}


func _setup() -> void:
	if Db.camp.is_empty() or Db.levels.is_empty():
		Db.reload()
	_keep = {"save": Game.save_enabled, "meta": Game.meta, "run": Game.run}
	Game.save_enabled = false
	Game.meta = Game._fresh_meta()
	Game.meta["trips"] = 5  # past the new-player free nights
	Game.run = null
	Game.set_flag("met_dog")
	Game.ensure_run()
	for kind in Game.run.larder():  # an empty larder, then just what each test packs
		Game.run.add_item(kind, -Game.run.item_count(kind))
	Game.run.opened = {}


func _teardown() -> void:
	Game.meta = _keep.meta
	Game.run = _keep.run
	Game.save_enabled = _keep.save


func _id(m: Dictionary) -> String:
	return String((m.def as CharacterDef).id)


func test_data_rows() -> void:
	if Db.camp.is_empty():
		Db.reload()
	ok(CampRules.slots(Db.camp) >= 1, "at least one evening slot")
	ok(not Db.camp_actions.is_empty(), "the evening has actions")
	for row: Dictionary in Db.camp_actions:
		ok(Txt.has(String(row.name_key)) and Txt.has(String(row.tip_key)), "%s has its words" % row.id)
	eq(String(Db.camp_rations[0].id), CampRules.FILLING, "the dial opens on the fullest ration")
	for row: Dictionary in Db.camp_rations:
		ok(Txt.has(String(row.name_key)) and Txt.has(String(row.tip_key)), "%s has its words" % row.id)


func test_pot_need_and_days_by_ration() -> void:
	_setup()
	var run := Game.run
	eq(run.food_need(), 2, "the hero and the dog eat a portion each")
	run.add_item("ration", 2)  # 2 x 5 portions
	var filling := CampRules.ration(Db.camp_rations, "filling")
	var meager := CampRules.ration(Db.camp_rations, "meager")
	var bare := CampRules.ration(Db.camp_rations, "bare")
	eq(CampRules.pot_need(run, filling), 2)
	eq(CampRules.pot_need(run, meager), 1, "half, rounded up")
	eq(CampRules.pot_need(run, bare), 0)
	eq(CampRules.food_days(run, filling), 5)
	eq(CampRules.food_days(run, meager), 10)
	eq(CampRules.food_days(run, bare), 99, "the pot takes nothing")
	eq(String(CampRules.ration(Db.camp_rations, "nonsense").id), "filling", "an unknown setting opens full")
	_teardown()


func test_pot_eats_meat_first_and_shares_its_heal() -> void:
	_setup()
	var run := Game.run
	run.add_item("ration", 1)
	run.add_item("meat", 2)  # meat heals 2 a portion
	for m in run.alive():
		m.hp = run.max_hp(m) - 5
	var res := CampRules.eat_pot(run, CampRules.ration(Db.camp_rations, "filling"))
	eq(int(res.took), 2)
	ok((res.missed as Dictionary).is_empty(), "everyone ate")
	eq(run.item_count("meat"), 0, "the meat went in the pot first")
	eq(run.portions(), 5, "the ration is untouched")
	for m in run.alive():
		eq(int(m.hp), run.max_hp(m) - 3, "%s shares the meat's 4 HP" % _id(m))
	_teardown()


func test_short_pot_leaves_companions_hungry_first() -> void:
	_setup()
	var run := Game.run
	run.add_item("meat", 1)
	var res := CampRules.eat_pot(run, CampRules.ration(Db.camp_rations, "filling"))
	eq(int(res.took), 1)
	eq((res.missed as Dictionary).keys(), ["dog"], "the dog goes without before the hero")
	_teardown()


func test_bare_saves_the_food_and_everyone_goes_hungry() -> void:
	_setup()
	var run := Game.run
	run.add_item("ration", 1)
	var dog_before := Game.morale_of("dog")
	var lines := Game.camp_eat("bare")
	eq(run.portions(), 5, "nothing eaten")
	ok(Game.morale_of("dog") < dog_before, "hungry: morale lost")
	ok(not lines.is_empty(), "the night says so")
	_teardown()


func test_meager_costs_morale_unless_the_night_is_free() -> void:
	_setup()
	var run := Game.run
	run.add_item("ration", 1)
	var before := Game.morale_of("lead")
	Game.camp_eat("meager")
	eq(run.portions(), 4, "half the need, rounded up: one portion")
	eq(Game.morale_of("lead"), before + MoraleRules.softened(int(CampRules.ration(Db.camp_rations, "meager").morale), true, Db.morale),
		"thin rations cost morale (softened by Doggo)")
	Game.meta["trips"] = 1  # the first trip's first night is free
	Game.meta["trip_nights"] = {}
	before = Game.morale_of("lead")
	var lines := Game.camp_eat("meager")
	eq(Game.morale_of("lead"), before, "free night: no morale lost")
	ok(lines.has(Txt.t("CAMP_RATION_FREE")))
	_teardown()


func test_actions_once_a_night_and_their_needs() -> void:
	_setup()
	var run := Game.run
	ok(not CampRules.can_do(run, "fish", []), "no rod, no fishing")
	eq(CampRules.why_not(run, "fish", []), "CAMP_NEED_ROD")
	run.add_item("rod", 1)
	ok(CampRules.can_do(run, "fish", []))
	ok(not CampRules.can_do(run, "fish", ["fish"]), "once a night")
	eq(CampRules.why_not(run, "fish", ["fish"]), "CAMP_DONE")
	for m in run.alive():
		m.hp = run.max_hp(m)
	ok(not CampRules.can_do(run, "mend", []), "nobody hurt")
	run.alive()[1].hp = 3
	ok(CampRules.can_do(run, "mend", []))
	var line := Game.camp_mend()
	eq(int(run.alive()[1].hp), mini(run.max_hp(run.alive()[1]), 3 + int(Db.camp.mend_hp)), "mend heals the most hurt")
	ok(line != "")
	eq(CampRules.pairs(run), [["lead", "dog"]], "two in the party: one pair")
	_teardown()


func test_talk_grows_the_bond() -> void:
	_setup()
	var lines := Game.camp_talk("lead", "dog")
	eq(int(Game.meta.bonds.get(BondRules.key("lead", "dog"), 0)), int(Db.camp.talk_points))
	ok(lines.size() >= 2, "a talk and the bond line")
	_teardown()


func test_cook_serves_a_meal_or_a_hot_pot() -> void:
	_setup()
	var before := Game.morale_of("dog")
	Game.camp_cook()
	eq(Game.morale_of("dog"), mini(100, before + int(Db.camp.hot_pot)), "no meal carried: a hot pot")
	Game.run.add_item("meal_stew", 1)
	Game.camp_cook()
	eq(Game.run.item_count("meal_stew"), 0, "a carried meal is served")
	ok(not Game.run.meal.is_empty(), "its buff is on")
	_teardown()


func test_same_as_last_night_trims_what_cant_be_done() -> void:
	_setup()
	var run := Game.run
	for m in run.alive():
		m.hp = run.max_hp(m)
	eq(CampRules.repeatable(run, ["fish", "mend", "hunt", "rest"], 3), ["hunt", "rest"], "no rod and nobody hurt")
	run.add_item("rod", 1)
	eq(CampRules.repeatable(run, ["fish", "hunt", "rest", "forage"], 3), ["fish", "hunt", "rest"], "never more than the slots")
	_teardown()


# --- campsites on the map (option C) ---

func test_campsites_on_a_leg_read_both_ways() -> void:
	_setup()
	var p := {"from": "town", "to": "pass", "seconds": "60", "camps": "0.25:river|0.75:hill"}
	var out := CampRules.leg_sites(p, "town")
	eq(out.map(func(s: Dictionary) -> String: return String(s.id)), ["river", "hill"])
	eq(float(out[0].t), 15.0, "a quarter of the way")
	var back := CampRules.leg_sites(p, "pass")
	eq(back.map(func(s: Dictionary) -> String: return String(s.id)), ["hill", "river"], "walked the other way, in walking order")
	eq(float(back[0].t), 15.0)
	eq(CampRules.next_site(out, 0.0, []), 0)
	eq(CampRules.next_site(out, 0.0, [0]), 1, "a passed campsite doesn't ask again")
	eq(CampRules.next_site(out, 50.0, []), -1, "none left ahead")
	for row: Dictionary in Db.world_paths:  # every leg in data names campsites that exist
		for s: Dictionary in CampRules.leg_sites(row, String(row.from)):
			ok(Db.campsites.has(String(s.id)), "campsite %s on %s-%s" % [s.id, row.from, row.to])
	_teardown()


func test_what_each_campsite_gives() -> void:
	_setup()
	var run := Game.run
	var base := CampRules.slots(Db.camp)
	eq(CampRules.slots_at(Db.camp, {}), base, "a camp wherever the day ends (option A)")
	eq(CampRules.slots_at(Db.camp, Db.campsites.hill), base + 1, "the hilltop: one more action")
	eq(CampRules.slots_at(Db.camp, Db.campsites.dark), base - 1, "night on the road: one fewer")
	run.add_item("rod", 1)
	ok(CampRules.can_do(run, "fish", [], Db.campsites.river), "a river camp fishes")
	ok(not CampRules.can_do(run, "fish", [], Db.campsites.meadow), "no water, no fishing")
	eq(CampRules.why_not(run, "fish", [], Db.campsites.meadow), "CAMP_NO_WATER")
	ok(CampRules.can_do(run, "fish", [], {}), "option A fishes anywhere with a rod")
	ok(not CampRules.ask_at(0.0) and CampRules.ask_at(TravelRules.DAY_SECONDS * 0.5), "just camped: walk past")
	eq(CampRules.style({}), CampRules.SITES, "campsites by default")
	eq(CampRules.style({"camp_style": "nightly"}), CampRules.NIGHTLY)
	_teardown()


func test_a_rough_camp_costs_morale() -> void:
	_setup()
	var before := Game.morale_of("lead")
	var lines := Game.camp_site_morale(int(Db.campsites.dark.morale))
	ok(Game.morale_of("lead") < before, "everyone loses morale")
	ok(not lines.is_empty())
	eq(Game.camp_site_morale(0), PackedStringArray(), "a good campsite costs nothing")
	_teardown()

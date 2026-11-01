extends TestCase
## The homecoming page ([USER] 2026-11-01 Pitch J): the trip ledger, what the page counts, and the next goal.

const CFG := {"xp_per_level": 100}
const ROWS := [
	{"id": "smithy_1", "building": "smithy", "step": 1, "name_key": "A", "needs": "metal:3;wood:4", "gives": "", "settler": "settler_smith"},
	{"id": "smithy_2", "building": "smithy", "step": 2, "name_key": "B", "needs": "metal:2;rare:1", "gives": "", "settler": "settler_smith"},
]


func _meta() -> Dictionary:
	return {"trips": 2, "levels": {"lead": {"level": 2, "xp": 40}, "dog": {"level": 1, "xp": 90}},
		"bonds": {"dog+lead": 8}, "flags": ["met_dog"], "morale": {}}


func test_counts_what_the_trip_gave() -> void:
	var meta := _meta()
	var before := HomecomingRules.snapshot(meta, true)
	meta.levels.lead = {"level": 3, "xp": 10}  # +70 XP, a level
	meta.levels.dog = {"level": 2, "xp": 0}  # +10 XP, a level
	meta.bonds["dog+lead"] = 11
	meta.flags.append_array(["learned_lich", "got_crypt_ring", "beaten_crypt_boss", "beaten_den_alpha"])
	var s := HomecomingRules.summary(before, meta, {"metal": 2}, [ROWS[0]], true, CFG)
	eq(s.materials, {"metal": 2})
	eq(s.levels.size(), 2)
	eq(String(s.levels[0].id), "lead", "the hero first")
	eq(int(s.levels[0].xp), 70)
	eq([int(s.levels[0].from), int(s.levels[0].to)], [2, 3])
	eq(int(s.levels[1].xp), 10)
	eq(s.bonds, [{"key": "dog+lead", "from": 8, "to": 11}])
	eq(s.cards, ["lich"] as Array[String], "the boss card just learned")
	eq(s.knowledge, {"got": 1, "beaten": 2})
	eq(s.restored, ["smithy_1"] as Array[String])
	ok(not HomecomingRules.empty(s))


func test_morale_and_nothing() -> void:
	var meta := _meta()
	meta.morale = {"lead": 60, "dog": 80}
	var before := HomecomingRules.snapshot(meta, false)
	var s := HomecomingRules.summary(before, meta, {}, [], false, CFG)
	ok(HomecomingRules.empty(s), "a walk that brought nothing shows nothing")
	meta.morale.lead = 45
	meta.morale["fire_mage"] = 70  # someone new: no change to show
	s = HomecomingRules.summary(before, meta, {}, [], false, CFG)
	eq(s.morale, [{"id": "lead", "from": 60, "to": 45}])


func test_which_returns_close_the_ledger() -> void:
	ok(HomecomingRules.closes({"gate": false}, true), "a fall or GO HOME always")
	ok(HomecomingRules.closes({"gate": true}, false), "a trip walked home through the gate")
	ok(not HomecomingRules.closes({"gate": false}, false), "the cottage to the square is not a return")


func test_next_goal() -> void:
	var have := {"metal": 2, "wood": 5}
	eq(HomecomingRules.next_goal(ROWS, {}, [], have, []), {}, "no settler yet: no goal")
	var g := HomecomingRules.next_goal(ROWS, {}, [], have, ["settler_smith"])
	eq(String(g.row.id), "smithy_1")
	eq(g.parts, [{"id": "metal", "have": 2, "need": 3}, {"id": "wood", "have": 4, "need": 4}], "2 of 3 metal; wood is capped at what it needs")
	ok(not g.ready)
	g = HomecomingRules.next_goal(ROWS, {}, ["smithy_2"], have, ["settler_smith"])
	eq(String(g.row.id), "smithy_2", "a tracked step comes first")
	g = HomecomingRules.next_goal(ROWS, {"smithy_1": {"state": "paid", "trip": 1}}, [], have, ["settler_smith"])
	eq(g, {}, "the next step is under way: nothing to gather")


## The real loop: the gate opens the ledger, a fall closes it into the page.
func test_game_fills_the_page() -> void:
	if Db.levels.is_empty():
		Db.reload()
	var keep_save := Game.save_enabled
	var keep_meta := Game.meta
	var keep_run := Game.run
	Game.save_enabled = false
	Game.meta = Game._fresh_meta()
	Game.run = null
	Game.ensure_run()
	ok(not Dictionary(Game.meta.ledger).is_empty(), "a ledger from the first walk")
	Game.start_trip()
	ok(bool(Game.meta.ledger.gate))
	Game.award_xp(30)
	Game.set_flag("learned_lich")
	Game.homecoming = {}
	Game.home_again(true)
	ok(not Game.homecoming.is_empty(), "the page waits for the square")
	eq(Game.homecoming.cards, ["lich"] as Array[String])
	ok(not Game.homecoming.levels.is_empty(), "XP counted")
	ok(not bool(Game.meta.ledger.gate), "a fresh count after the return")
	Game.homecoming = {}
	Game.home_again()
	ok(Game.homecoming.is_empty(), "walking around the square again shows nothing")
	var ui := HomecomingUi.make({"fell": true, "headline": "X", "materials": {"metal": 2}, "levels": [], "bonds": [],
		"morale": [], "cards": ["lich"], "knowledge": {"got": 1}, "restored": []})
	Engine.get_main_loop().root.add_child(ui)
	ok(ui.get_child_count() > 0, "the page builds")
	ui.close()
	Game.meta = keep_meta
	Game.run = keep_run
	Game.save_enabled = keep_save
	Game.homecoming = {}

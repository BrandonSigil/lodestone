extends TestCase
## The player path (2026-11-13 playtest): the main goal chain, the one-time hints, the first road fight, the
## placeholder sounds and the dev-mode switch.


func test_main_goal_walks_the_chain() -> void:
	eq(GoalRules.main_goal([]), "GOAL_LODESTONE", "a new game starts at the Lodestone")
	eq(GoalRules.main_goal(["has_lodestone"]), "GOAL_WEAPON")
	eq(GoalRules.main_goal(["has_lodestone", "weapon_bow"]), "GOAL_DOG", "any weapon counts")
	eq(GoalRules.main_goal(["has_lodestone", "weapon_bow", "left_village"]), "GOAL_HIGHLANDS",
		"the dog is optional: out the gate without him moves the goal on")
	eq(GoalRules.main_goal(["has_lodestone", "weapon_sword", "met_dog", "left_village", "entered_snow_pass"]), "GOAL_CRYPT")
	var all := ["has_lodestone", "weapon_sword", "met_dog", "left_village", "visited_pass", "entered_crypt", "e2e_done"]
	eq(GoalRules.main_goal(all), "", "done: no main goal")
	eq(GoalRules.progress([]), Vector2i(0, GoalRules.CHAIN.size()))
	eq(GoalRules.progress(all), Vector2i(GoalRules.CHAIN.size(), GoalRules.CHAIN.size()))


func test_every_goal_and_hint_has_text() -> void:
	for step: Array in GoalRules.CHAIN:
		ok(Txt.has(String(step[0])), "goal text: " + String(step[0]))
	for id: String in GoalRules.HINTS:
		ok(Txt.has(String(GoalRules.HINTS[id])), "hint text: " + id)
	for k: String in FightTips.STEPS:
		ok(Txt.has(k), "fight tip text: " + k)


func test_hints_show_once() -> void:
	eq(GoalRules.hint("walk", []), "HINT_WALK")
	eq(GoalRules.hint("walk", [GoalRules.hint_flag("walk")]), "", "shown once ever")
	eq(GoalRules.hint("nope", []), "", "an unknown hint is nothing")


func test_the_first_road_fight_is_scripted_and_fair() -> void:
	var ev := TrailRules.first_event(Db.travel_events, [])
	eq(String(ev.get("id", "")), "tr_first", "the first road stop is the scripted fight")
	eq(TrailRules.first_event(Db.travel_events, [String(ev.once_flag)]), {}, "once only")
	var run := RunState.new()
	var rolled := 0
	for i in 200:
		if String(TrailRules.pick_event(run, Db.travel_events, []).get("id", "")) == "tr_first":
			rolled += 1
	eq(rolled, 0, "never rolled at random")
	ok(Db.encounters.has("first_road"), "its fight exists")
	eq(Array(Db.encounters["first_road"].units).size(), 2, "two foes: a fair fight for a party of one or two")


func test_dev_mode_is_off_on_the_player_path() -> void:
	var was := Game.dev_mode
	Game.dev_mode = false
	eq(Game.menu_scene(), Game.MAIN_MENU, "player mode goes back to the main menu")
	Game.dev_mode = true
	eq(Game.menu_scene(), Game.LAUNCH, "dev mode goes back to Dev Tools")
	Game.dev_mode = was


func test_placeholder_sounds_build() -> void:
	for name: String in ["click", "hit", "victory", "hint"]:
		var s := SfxSynth.sound(name, 11025)
		ok(s is AudioStreamWAV and (s as AudioStreamWAV).data.size() > 100, "a sound: " + name)

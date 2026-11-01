extends TestCase
## Character sheets ([USER] 2026-10-30): the dog's, and one per build at the smithy rack, all from data.


func _fresh() -> Dictionary:
	if Db.explore_events.is_empty():
		Db.reload()
	var saved := {"meta": Game.meta.duplicate(true), "on": Game.save_enabled, "run": Game.run}
	Game.save_enabled = false
	Game.meta = Game._fresh_meta()
	Game.meta.flags = ["met_dog"]
	Game.start_adventure()
	return saved


func _restore(saved: Dictionary) -> void:
	Game.meta = saved.meta
	Game.run = saved.run
	Game.save_enabled = saved.on


func test_every_move_has_a_line() -> void:
	if Db.explore_events.is_empty():
		Db.reload()
	for row in CsvTable.load_rows("res://data/abilities.csv"):
		ok(Txt.has("DESC_" + String(row.id).to_upper()), "a caveman line for " + String(row.id))


func test_the_rack_offers_every_build_from_its_event() -> void:
	var saved := _fresh()
	var ev: Dictionary = Db.explore_events["smithy_rack"]
	var builds := ExploreRules.rack_builds(ev, [], {"flags": Game.meta.flags})
	eq(builds.map(func(b: Dictionary) -> String: return b.weapon), ["sword", "daggers", "bow", "book"])
	ok(builds[0].open and not builds[3].open, "the book waits until it's found")
	_restore(saved)


func test_a_sheet_per_build_changes_nothing() -> void:
	var saved := _fresh()
	var sword := Game.sheet("lead", "sword")
	var bow := Game.sheet("lead", "bow")
	eq(Game.weapon_id(), "none", "looking takes nothing")
	eq(sword.job, "JOB_KNIGHT")
	eq(sword.weapon, "ITEM_SWORD")
	ok(sword.moves.any(func(m: Dictionary) -> bool: return m.id == "shove"), "the sword's job moves")
	ok(not bow.moves.any(func(m: Dictionary) -> bool: return m.id == "shove"), "the bow's own, not the sword's")
	ok((bow.range as Vector2i).y > (sword.range as Vector2i).y, "the bow reaches further")
	ok(sword.moves.size() <= SheetRules.MOVES)
	Game.take_weapon("sword")
	eq(Game.sheet("lead").job, "JOB_KNIGHT", "the hero's own sheet follows his weapon")
	_restore(saved)


func test_the_dog_has_a_sheet() -> void:
	var saved := _fresh()
	var dog := Game.sheet("dog")
	eq(dog.name, "CHAR_DOG")
	ok(dog.moves.any(func(m: Dictionary) -> bool: return m.id == "bite"), "BITE")
	ok(dog.moves.any(func(m: Dictionary) -> bool: return m.id == "bark"), "BARK")
	ok(dog.stats.any(func(s: Dictionary) -> bool: return s.key == "CHECK_HUNT"), "his trail skills as the stat block")
	eq(dog.hp, dog.max_hp)
	_restore(saved)


func test_the_rack_opens_sheets_and_take_arms_the_hero() -> void:
	var saved := _fresh()
	Game.explore_map = "village"
	Game.explore_entry = Vector2i(-1, -1)
	var s: Node = load("res://scenes/explore.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(s)
	var rack: Dictionary = s.things.filter(func(t: Dictionary) -> bool: return t.kind == "rack")[0]
	s._open_thing(rack)
	ok(s.sheet != null, "the rack opens the sheets")
	eq(s.sheet.pages.size(), 4, "one page per build")
	eq(s.sheet.takes, ["take", "take", "take", "locked"])
	s.sheet.flip(1)
	eq(s.sheet.page, 1)
	s.sheet.taken.emit(1)
	eq(Game.weapon_id(), "daggers", "TAKE on the daggers' page takes the daggers")
	ok(s.sheet == null, "and the sheet closes")
	s._close_dialog()
	s.mode = 0
	s.open_sheet("dog")
	ok(s.sheet != null and s.sheet.pages[0].name == "CHAR_DOG", "the dog's sheet")
	s.sheet.closed.emit()
	eq(s.mode, 0, "CLOSE goes back to walking")
	s.free()
	Game.explore_map = "home"
	_restore(saved)


## One shared menu look ([USER] 2026-10-30): the theme Game merges in has the dialogue, menu, info and hover-card
## panels, titles and buttons, so every screen without its own theme picks them up.
func test_shared_menu_theme_is_in_the_default() -> void:
	var t := UiTheme.make()
	for v in ["DialogPanel", "MenuPanel", "InfoPanel", "TipPanel"]:
		ok(t.has_stylebox("panel", v), v + " has its panel")
	ok(t.has_color("font_color", "MenuTitle") and t.has_font_size("font_size", "MenuTitle"), "a title look")
	for st in ["normal", "hover", "pressed", "disabled"]:
		ok(t.has_stylebox(st, "Button"), "buttons: " + st)
	ok(ThemeDB.get_default_theme().has_stylebox("panel", "DialogPanel"), "Game merged it into the default theme")


## Mana and charges carry between fights on an outing ([USER] 2026-10-30, "Fights must cost"): what a fight leaves is
## what the next one starts with, a trickle, a camp rest, a tonic and a wake-up bring them back, rage resets.
func test_resources_carry_between_fights() -> void:
	var saved := _fresh()
	var dog: Dictionary = Game.run.members.filter(func(m: Dictionary) -> bool: return (m.def as CharacterDef).id == &"dog")[0]
	var u := CombatUnit.from_member(dog)
	eq(u.res, u.res_max, "a fresh member starts full")
	u.res = 1
	Game.store_res(u)
	var again := CombatUnit.from_member(dog)
	eq(again.res, 1, "the next fight starts with what was left")
	ok(again.keep_res, "and Battle leaves it be")
	var b := Battle.new()
	b.setup(CombatGrid.flat(4, 4), [again], 1)
	eq(again.res, 1, "setup does not refill it")
	b.free()
	# the trickle: one back for every `trickle_steps` tiles
	var steps := int(Db.levels.trickle_steps)
	ok(not Game.trickle(float(steps) - 1.0, "trickle_steps"), "short of a trickle: nothing")
	ok(Game.trickle(1.0, "trickle_steps"), "a full trickle gives one")
	eq(Game.member_res(dog).res, 2, "one charge back")
	# a tonic
	dog.res = 0
	ok(Game.tonic_effect(), "a tonic helps a piece that is short")
	eq(Game.member_res(dog).res, int(Db.levels.tonic_charges), "the dog gets a charge")
	# a camp rest: costs food, refills, heals half
	dog.res = 0
	dog.hp = 2
	Game.run.food = 20
	var food: int = Game.run.food
	ok(Game.camp_rest(), "a camp rest")
	eq(Game.run.food, food - int(Db.levels.camp_food), "it costs a ration's worth of food")
	eq(Game.member_res(dog).res, Game.member_res(dog).res_max, "and refills")
	ok(dog.hp > 2, "and heals")
	Game.run.food = 0
	ok(not Game.camp_rest(), "no food, no rest")
	# a wake-up refills everything
	dog.res = 0
	Game.wake_in_town(true)
	eq(Game.member_res(dog).res, Game.member_res(dog).res_max, "the village refills it")
	# rage is not carried
	var knight := CombatUnit.enemy(load("res://data/classes/job_knight.tres"))
	knight.res = 3
	Game.run.members[0].res = 3
	var lead := CombatUnit.from_member(Game.run.members[0])
	ok(not lead.keep_res or lead.res_kind != "rage", "rage resets every fight")
	_restore(saved)

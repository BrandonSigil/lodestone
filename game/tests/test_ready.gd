extends TestCase
## The get-ready screen ([USER] 2026-11-16, backlog P31): roles, what the party covers, the warnings, and the town
## chest.


func _db() -> void:
	if Db.town_chest.is_empty() or Db.camp.is_empty():
		Db.reload()


func test_roles_from_the_class() -> void:
	_db()
	eq(ReadyRules.roles(Db.character(&"lead")), ["front"], "the hero fights up close")
	ok(ReadyRules.roles(Db.character(&"bushberry")).has("heal"), "Bushberry heals")
	var cover := ReadyRules.cover([Db.character(&"lead"), Db.character(&"bushberry")])
	eq(int(cover.front), 1 + (1 if ReadyRules.roles(Db.character(&"bushberry")).has("front") else 0))
	ok(int(cover.heal) >= 1)


func test_warnings_only_for_early_snags() -> void:
	eq(ReadyRules.warnings(5, 3, [], false), [], "enough food, nobody spent, room in the pack: nothing to say")
	var w := ReadyRules.warnings(1, 3, ["DOG"], true)
	eq(w.map(func(x: Dictionary) -> String: return String(x.key)), ["READY_WARN_FOOD", "READY_WARN_SPENT", "READY_WARN_PACK"])
	eq(w.map(func(x: Dictionary) -> String: return String(x.tab)), ["supplies", "party", "pack"], "each points at the tab that fixes it")


func test_town_chest_moves_items_both_ways() -> void:
	_db()
	var keep := {"save": Game.save_enabled, "meta": Game.meta, "run": Game.run}
	Game.save_enabled = false
	Game.meta = Game._fresh_meta()
	Game.run = null
	Game.ensure_run()
	var c := Game.chest()
	eq(int(c.get("ration", 0)), int(Db.town_chest.filter(func(r: Dictionary) -> bool: return String(r.id) == "ration")[0].count),
		"a new game's chest comes from data/town_chest.csv")
	var before := Game.run.item_count("ration")
	ok(Game.chest_move("ration", true))
	eq(Game.run.item_count("ration"), before + 1, "taken into the pack")
	ok(Game.chest_move("ration", false))
	eq(Game.run.item_count("ration"), before, "stored back")
	ok(not Game.chest_move("nothing_here", true), "nothing to take")
	ok(Game.meta.has("chest") and is_same(Game.chest(), Game.meta.chest), "the chest lives in meta")
	Game.meta = keep.meta
	Game.run = keep.run
	Game.save_enabled = keep.save

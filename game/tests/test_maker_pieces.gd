extends TestCase
## The map maker's party and enemy pieces: a new battle map starts with a test band, pieces placed and
## removed through the battle setup, and saving keeps what the user removed.


## The maker's piece tools edit the setup the way the maker does: read the doc's data, change it, write it back.
static func _edit(doc: MapDoc, edit: Callable) -> void:
	var s := SandboxSetup.from_dict(doc.data) if doc.data.has("map") else SandboxSetup.new()
	s.grid = doc.grid
	edit.call(s)
	doc.data = s.to_dict()


func test_new_battle_map_starts_with_a_test_band() -> void:
	var doc := MapDoc.create("battle", "piece_test", MapGen.valley(7), "snow")
	ok(doc.data.get("party", []).size() == 3, "a new battle map gets the test party")
	ok(doc.data.get("enemies", []).size() == 4, "and the band of foes")


func test_placing_and_removing_a_piece() -> void:
	var doc := MapDoc.create("battle", "piece_test", MapGen.valley(7), "snow")
	var c := Vector2i(-1, -1)
	for y in doc.grid.h:
		for x in doc.grid.w:
			if c.x < 0 and doc.grid.passable(Vector2i(x, y)):
				c = Vector2i(x, y)
	var start: int = doc.data.get("enemies", []).size()
	_edit(doc, func(s: SandboxSetup) -> void: s.place_enemy("bandit", c))
	ok(doc.data.enemies.size() == start + 1, "an enemy is placed")
	ok(doc.data.enemies.any(func(e: Dictionary) -> bool: return int(e.x) == c.x and int(e.y) == c.y), "on the picked cell")
	_edit(doc, func(s: SandboxSetup) -> void: s.remove_at(c))
	ok(doc.data.enemies.size() == start, "right click removes what stands there")


func test_removing_every_piece_survives_saving() -> void:
	var doc := MapDoc.create("battle", "piece_test", MapGen.valley(7), "snow")
	_edit(doc, func(s: SandboxSetup) -> void:
		s.party.clear()
		s.enemies.clear())
	var out := doc.to_dict()
	ok(out.party.is_empty() and out.enemies.is_empty(), "saving does not add the test band back")


func test_dials_round_trip_through_the_map() -> void:
	var doc := MapDoc.create("battle", "piece_test", MapGen.valley(7), "snow")
	_edit(doc, func(s: SandboxSetup) -> void:
		s.enemy_mods["hp_pct"] = 150
		s.extra_enemies = 2
		s.supplies["medicine"] = 5
		s.counters = false)
	var out := doc.to_dict()
	ok(int(out.enemy_mods.hp_pct) == 150, "enemy hp % is saved")
	ok(int(out.extra_enemies) == 2, "extra enemies are saved")
	ok(int(out.supplies.medicine) == 5, "medicine is saved")
	ok(bool(out.counters) == false, "counterattacks are saved")

extends TestCase
## Catches broken data rows before they reach a playtest.

const EFFECT_KEYS := ["food", "medicine", "gold", "morale", "dist", "day", "hp_all", "hp_one", "combat", "unlock"]
const CHECKS := ["none", "fight", "persuade", "sneak", "wayfind", "hunt", "forage", "nerve", "tame", "masonry", "fish", "heal"]


func _text_keys() -> Dictionary:
	var keys := {}
	for row in CsvTable.load_rows("res://text/placeholder.csv"):
		keys[row["keys"]] = true
	return keys


func _check_effects(s: String, where: String) -> void:
	for part in s.split(";", false):
		var kv := part.split(":")
		ok(kv.size() == 2 and EFFECT_KEYS.has(kv[0]), "%s: bad effect '%s'" % [where, part])
		if kv.size() == 2 and kv[0] == "combat":
			ok(CsvTable.load_rows("res://data/encounters.csv").any(func(r: Dictionary) -> bool: return r.id == kv[1]), "%s: unknown encounter %s" % [where, kv[1]])


func test_roster_loads() -> void:
	var keys := _text_keys()
	for id in Db.ROSTER:
		var d: CharacterDef = load("res://data/characters/%s.tres" % id)
		ok(d != null and d.class_def != null, "character %s" % id)
		if d == null:
			continue
		eq(d.id, id)
		ok(keys.has(d.name_key), "%s name key" % id)
		ok(keys.has(d.class_def.name_key), "%s class key" % id)
		ok(d.off_skills.size() <= 3, "%s has at most 3 off-class skills" % id)
		if d.unlock != "":
			ok(keys.has("UNLOCK_" + d.unlock.to_upper()), "%s unlock key" % id)


func test_events_valid() -> void:
	var keys := _text_keys()
	var events := Db.parse_events(CsvTable.load_rows("res://data/events.csv"))
	ok(events.size() >= 5)
	for ev in events:
		ok(keys.has(ev.text_key), "%s text key" % ev.id)
		ok(ev.options.size() >= 1, "%s has options" % ev.id)
		for opt in ev.options:
			ok(keys.has(opt.key), "%s option key %s" % [ev.id, opt.key])
			ok(CHECKS.has(opt.check), "%s check %s" % [ev.id, opt.check])
			_check_effects(opt.win, ev.id)
			_check_effects(opt.lose, ev.id)


func test_encounters_valid() -> void:
	for row in CsvTable.load_rows("res://data/encounters.csv"):
		for id in row.units.split("|"):
			ok(ResourceLoader.exists("res://data/classes/%s.tres" % id), "%s unit %s" % [row.id, id])
		_check_effects(row.loot, row.id)


## Character sprites (docs/art/characters.md 5.10): every anim's strip exists in every drawn facing and is
## exactly frames x frame wide, and combat's two facings are drawn.
func test_character_sprites_match_json() -> void:
	for id in Db.ROSTER:
		var m: Variant = CharacterArt.meta(id)
		if m == null:
			continue
		ok(m.dirs.has("se") and m.dirs.has("ne"), "%s draws se and ne" % id)
		for anim in m.anims:
			for dir in m.dirs:
				var path := "res://art/source/characters/%s/%s_%s_%s.png" % [id, id, anim, dir]
				var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
				ok(tex != null, "%s exists" % path)
				if tex != null:
					ok(tex.get_width() >= int(m.anims[anim].frames) * int(m.frame), "%s has %d frames" % [path, m.anims[anim].frames])
		var f := CharacterArt.frame(id, "attack", "sw", 0.0)
		ok(not f.is_empty() and f.flip, "%s mirrors se for sw" % id)


## The general dummy stands in for every unit with no art, so every screen facing must resolve to a drawn strip.
func test_dummy_draws_every_facing() -> void:
	var m: Variant = CharacterArt.meta(CharacterArt.FALLBACK)
	ok(m != null, "dummy has json")
	for dir in ["se", "ne", "s", "e", "n"]:
		ok(m.dirs.has(dir), "dummy draws %s" % dir)
	for dir in CharacterArt.SCREEN_DIRS:
		for anim in ["idle", "walk", "attack", "cast", "hurt", "down"]:
			var f := CharacterArt.frame(CharacterArt.FALLBACK, anim, dir, 0.0)
			ok(not f.is_empty(), "dummy %s %s draws" % [anim, dir])

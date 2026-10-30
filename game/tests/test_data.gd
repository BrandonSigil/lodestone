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


## The town draws only its own art: every file the village asks for is in the village set, so nothing falls
## back to the older base or snow art (a missing file in a set silently loads the base one).
func test_village_art_is_its_own() -> void:
	var stems := {}
	for row in CsvTable.load_rows("res://data/battle_art_village.csv"):
		for col in ["top", "side"]:
			stems[String(row[col])] = "battle_art_village.csv"
		for s in String(row.props).split("|", false):
			stems[s] = "battle_art_village.csv"
	for row in CsvTable.load_rows("res://data/looks.csv"):
		if row.id == "village":
			for s in String(row.trees).split("|", false):
				stems[s] = "looks.csv"
	for row in CsvTable.load_rows("res://data/catalog.csv"):
		if row.drawer in ["Village", "Nature"]:
			var s := MakerCatalog.stem_for(row, "village")
			if not s.contains("/"):
				stems[s] = "catalog.csv " + String(row.id)
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/explore/village.json"))
	for p in doc.grid.props:
		var s := String(p.sprite)
		if not s.begins_with("ph_"):  # ph_ is a placeholder block, drawn in code
			stems[s] = "village.json"
	stems["skyline"] = "wallpaper"
	for s in stems:
		if String(s).get_file().begins_with("ph_"):
			continue  # a placeholder (statue, arch), drawn in code until its art exists
		ok(not String(s).contains("/") or String(s).begins_with("village/"), "%s (%s) borrows another set" % [s, stems[s]])
		var path := "res://art/source/battle/village/%s.png" % String(s).trim_prefix("village/")
		ok(ResourceLoader.exists(path), "%s (%s) is missing from the village set" % [path, stems[s]])


## The ten class archetypes ([USER] 2026-10-30, docs/design/archetypes.md): kits, resources and evolved classes load
## from data/archetypes.csv, kits.csv and evolved.csv, and every piece they name exists.
func test_archetypes_load() -> void:
	if Db.explore_events.is_empty():
		Db.reload()
	var keys := _text_keys()
	var arch := CsvTable.load_rows("res://data/archetypes.csv")
	eq(arch.size(), 10, "ten archetypes")
	var kits := CsvTable.load_rows("res://data/kits.csv")
	var evolved := CsvTable.load_rows("res://data/evolved.csv")
	for a in arch:
		var id := String(a.id)
		ok(keys.has(a.name_key), "%s name key" % id)
		var cls: ClassDef = load("res://data/classes/%s.tres" % a["class"])
		ok(cls != null, "%s class %s" % [id, a["class"]])
		if cls == null:
			continue
		eq(cls.resource, a.resource, "%s job resource" % id)
		ok(["rage", "mana", "charges"].has(String(cls.resource)), "%s resource kind" % id)
		var mine := kits.filter(func(r: Dictionary) -> bool: return r.archetype == id)
		var slots := {}
		for r in mine:
			slots[int(r.slot)] = true
			match String(r.source):
				"ability":
					ok(Db.abilities.has(String(r.ability)), "%s: %s is in abilities.csv" % [id, r.ability])
					ok(Txt.has("DESC_" + String(r.ability).to_upper()), "%s: a line for %s" % [id, r.ability])
				"trait":
					if r.built == "1":
						ok([CombatRules.TRAIT_SHIELD_WALL, CombatRules.TRAIT_POISON_BLADES].has(StringName(r.ability)), "%s: %s is a combat trait" % [id, r.ability])
					else:
						ok(String(r.needs) != "", "%s: the unbuilt trait %s says what it needs" % [id, r.ability])
				"action":
					ok(BASIC_ACTIONS.has(String(r.ability)), "%s: %s is a basic action" % [id, r.ability])
				_:
					ok(false, "%s: bad source %s" % [id, r.source])
		eq(slots.size(), 4, "%s has four ability slots" % id)
		ok(mine.any(func(r: Dictionary) -> bool: return r.ability == a.clutch), "%s: the clutch is in its kit" % id)
		var evo := evolved.filter(func(r: Dictionary) -> bool: return r.base == id)
		eq(evo.map(func(r: Dictionary) -> String: return String(r.branch)), ["A", "B"], "%s forks in two" % id)
		eq([a.branch_a, a.branch_b], evo.map(func(r: Dictionary) -> String: return String(r.name_key)), "%s fork names match" % id)
		for r in evo:
			ok(keys.has(r.name_key), "%s name key" % r.id)
	# the seven new jobs carry their kit, except slots that are traits or actions
	for a in arch:
		var cls: ClassDef = load("res://data/classes/%s.tres" % a["class"])
		if not String(a["class"]) in ["job_knight", "job_rogue", "job_archer"]:
			var want := kits.filter(func(r: Dictionary) -> bool: return r.archetype == a.id and r.source == "ability" and r.alt == "0").map(func(r: Dictionary) -> String: return String(r.ability))
			eq(cls.abilities.map(func(s: StringName) -> String: return String(s)), want, "%s's class holds its kit" % a.id)
	eq(evolved.size(), 20, "two evolved classes each")


const BASIC_ACTIONS := ["guard", "move", "wait", "talk", "aid"]


## The scale C test set (data/scale_c.csv): every row names a real class or ability, and laying it over a fight changes
## the pieces and copies of abilities, never the shipped ones.
func test_scale_c_set() -> void:
	if Db.explore_events.is_empty():
		Db.reload()
	for r in ScaleTest.rows():
		if r.kind == "class":
			ok(ResourceLoader.exists("res://data/classes/%s.tres" % r.id), "class %s" % r.id)
		else:
			ok(Db.abilities.has(String(r.id)), "ability %s" % r.id)
	var g := CombatGrid.flat(6, 6)
	var rogue := CombatUnit.enemy(load("res://data/classes/job_rogue.tres"))
	var mage := CombatUnit.from_def(Db.character(&"wizard"))
	var before := Db.ability("fireball").range_max
	ScaleTest.apply([rogue, mage])
	eq(rogue.move, 8, "the fast rogue")
	eq(mage.move, 4, "the slow mage")
	var ball: Ability = mage.abilities.filter(func(a: Ability) -> bool: return a.id == "fireball")[0]
	eq(ball.range_max, 6, "a long reach")
	eq(Db.ability("fireball").range_max, before, "the shipped ability is untouched")
	var setup := SandboxSetup.load_file("res://data/maps/arena_c.json")
	ok(setup != null and setup.enemies.size() >= 4, "the arena has its foes")
	g.w = g.w

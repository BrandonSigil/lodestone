class_name SandboxSetup
extends RefCounted
## Everything the combat sandbox needs to rebuild a fight: map, who stands where, difficulty dials,
## supplies and rule switches. Saves to JSON in data/maps so a good test map can become a real encounter later.

const MAP_DIR := "res://data/maps/"
const USER_MAP_DIR := "user://maps/"  ## fallback when res:// is read-only (exported builds)
const MOD_KEYS := ["hp_pct", "attack", "defense", "damage", "move"]
## Difficulty presets. Four separate dials (toughness, accuracy, damage, numbers), as in docs/research/tactical-combat.md.
const PRESETS := {
	"EASY": {"mods": {"hp_pct": 80, "attack": -1, "defense": -1, "damage": 0, "move": 0}, "extra": 0},
	"NORMAL": {"mods": {"hp_pct": 100, "attack": 0, "defense": 0, "damage": 0, "move": 0}, "extra": 0},
	"HARD": {"mods": {"hp_pct": 115, "attack": 1, "defense": 0, "damage": 0, "move": 0}, "extra": 1},
	"BRUTAL": {"mods": {"hp_pct": 130, "attack": 2, "defense": 1, "damage": 1, "move": 0}, "extra": 2},
}

var map_name := "untitled"
var grid: CombatGrid
var party: Array = []  ## [{"id": character id, "cell": Vector2i, "spells": [ids] (casters only, optional)}]
var enemies: Array = []  ## [{"id": class id, "cell": Vector2i}]
var party_mods := {"hp_pct": 100, "attack": 0, "defense": 0, "damage": 0, "move": 0}
var enemy_mods := {"hp_pct": 100, "attack": 0, "defense": 0, "damage": 0, "move": 0}
var extra_enemies := 0  ## copies of the listed enemies added on the right edge at fight start
var supplies := {"medicine": 3, "food": 10}
var seed_value := 1
var strangeness := 0.0
var art_set := ""  ## battle tile set (a subfolder of BattleArt.DIR), "" = base art
var counters := true
var scale_c := false  ## lay the scale C numbers (data/scale_c.csv) over the pieces: the scale test fight
var view := 0  ## camera quarter turns the map opens with


static func default_setup() -> SandboxSetup:
	var s := SandboxSetup.new()
	s.map_name = "default"
	s.grid = CombatGrid.generate(7, 10, 8, 0.0)
	var spots := s.grid.deploy_cells(0)
	for id in ["lead", "stardrop", "hunter"]:
		s.party.append({"id": id, "cell": spots.pop_front()})
	var es := s.grid.deploy_cells(1)
	for id in ["bandit", "bandit", "bandit_archer", "wolf"]:
		s.enemies.append({"id": id, "cell": es.pop_front()})
	return s


func apply_preset(name: String) -> void:
	var p: Dictionary = PRESETS[name]
	enemy_mods = (p.mods as Dictionary).duplicate()
	extra_enemies = int(p.extra)


# --- editing ----------------------------------------------------------------------

## Returns [list, index] of the unit entry at c, or [] if none.
func entry_at(c: Vector2i) -> Array:
	for list in [party, enemies]:
		for i in list.size():
			if list[i].cell == c:
				return [list, i]
	return []


func remove_at(c: Vector2i) -> bool:
	var e := entry_at(c)
	if e.is_empty():
		return false
	(e[0] as Array).remove_at(e[1])
	return true


## A party member stands in one place only: placing them again moves them.
func place_party(id: String, c: Vector2i) -> void:
	remove_at(c)
	for p in party:
		if p.id == id:
			p.cell = c
			return
	party.append({"id": id, "cell": c})


func place_enemy(id: String, c: Vector2i) -> void:
	remove_at(c)
	enemies.append({"id": id, "cell": c})


## The spells this party member will bring: their pick if set, else their default loadout.
func spells_of(id: String) -> Array:
	for p in party:
		if p.id == id and p.has("spells"):
			return p.spells
	var d := Db.character(StringName(id))
	return Array(d.default_spells()).map(func(x: StringName) -> String: return String(x)) if d else []


## Put spell `spell` (or "" for none) in slot `slot` of this party member's loadout.
func set_spell(id: String, slot: int, spell: String) -> void:
	for p in party:
		if p.id != id:
			continue
		var picks: Array = spells_of(id).duplicate()
		while picks.size() <= slot:
			picks.append("")
		picks[slot] = spell
		if spell != "":
			for i in picks.size():
				if i != slot and picks[i] == spell:
					picks[i] = ""
		p["spells"] = picks  # "" = empty slot; CombatUnit.set_spells skips it
		return


func resize(w: int, h: int) -> void:
	grid = grid.resized(w, h)
	for list in [party, enemies]:
		for i in range(list.size() - 1, -1, -1):
			if not grid.in_bounds(list[i].cell):
				list.remove_at(i)


## Drop units standing on rock after an edit.
func clean() -> void:
	for list in [party, enemies]:
		for i in range(list.size() - 1, -1, -1):
			if not grid.passable(list[i].cell):
				list.remove_at(i)


# --- building a fight --------------------------------------------------------------

func build_units() -> Array:
	var units: Array = []
	var taken := {}
	for p in party:
		if String(p.id).begins_with("class:"):  # a class as a party piece (the scale test's rogue)
			var cd: ClassDef = Db.class_def(String(p.id).substr(6))
			if cd != null and grid.passable(p.cell) and not taken.has(p.cell):
				var cu := CombatUnit.enemy(cd, party_mods)
				cu.team = 0
				cu.facing = Vector2i(1, 0)
				cu.tint = Color(0.45, 0.55, 0.85)
				cu.place(p.cell, grid.height_at(p.cell))
				taken[p.cell] = true
				units.append(cu)
			continue
		var d := Db.character(StringName(p.id))
		if d == null or not grid.passable(p.cell) or taken.has(p.cell):
			continue
		var u := CombatUnit.from_def(d, party_mods, p.get("spells"))
		u.place(p.cell, grid.height_at(p.cell))
		taken[p.cell] = true
		units.append(u)
	var ids: Array[String] = []
	for e in enemies:
		var c: ClassDef = Db.class_def(e.id)
		if c == null or not grid.passable(e.cell) or taken.has(e.cell):
			continue
		var u := CombatUnit.enemy(c, enemy_mods)
		u.place(e.cell, grid.height_at(e.cell))
		taken[e.cell] = true
		units.append(u)
		ids.append(e.id)
	if ids.is_empty():
		ids.append("bandit")
	var free := grid.deploy_cells(1).filter(func(c: Vector2i) -> bool: return not taken.has(c))
	for i in extra_enemies:
		if free.is_empty():
			break
		var c: Vector2i = free.pop_front()
		var u := CombatUnit.enemy(Db.class_def(ids[i % ids.size()]), enemy_mods)
		u.place(c, grid.height_at(c))
		taken[c] = true
		units.append(u)
	if scale_c:
		ScaleTest.apply(units)
	return units


func apply_switches() -> void:
	CombatRules.counters = counters


## One AI-vs-AI fight. Returns {"winner", "rounds", "hp_left": party HP fraction, "downed": party units down}.
func simulate(fight_seed: int) -> Dictionary:
	apply_switches()
	var rng := RandomNumberGenerator.new()
	rng.seed = fight_seed
	var units := build_units()
	var start_hp := 0
	for u: CombatUnit in units:
		if u.team == 0:
			start_hp += u.max_hp
	var r := CombatSim.fight(rng, grid, units, supplies.duplicate())
	var left := 0
	var downed := 0
	for u: CombatUnit in units:
		if u.team == 0:
			left += u.hp
			if not u.alive():
				downed += 1
	r["hp_left"] = float(left) / maxf(1.0, start_hp)
	r["downed"] = downed
	return r


## Adds one fight's result to a running tally.
static func tally(t: Dictionary, r: Dictionary) -> void:
	t.fights = int(t.get("fights", 0)) + 1
	var key := "wins" if r.winner == 0 else ("losses" if r.winner == 1 else "stalls")
	t[key] = int(t.get(key, 0)) + 1
	t.rounds = float(t.get("rounds", 0.0)) + r.rounds
	t.hp_left = float(t.get("hp_left", 0.0)) + r.hp_left
	t.downed = float(t.get("downed", 0.0)) + r.downed


static func describe_tally(t: Dictionary) -> String:
	var n := maxf(1.0, float(t.get("fights", 0)))
	return "PARTY WINS %d%%  (%d/%d)\nLOSES %d%%   STALLS %d%%\nROUNDS %.1f   PARTY HP LEFT %d%%\nDOWNED PER FIGHT %.1f" % [
		int(round(100.0 * t.get("wins", 0) / n)), int(t.get("wins", 0)), int(n),
		int(round(100.0 * t.get("losses", 0) / n)), int(round(100.0 * t.get("stalls", 0) / n)),
		t.get("rounds", 0.0) / n, int(round(100.0 * t.get("hp_left", 0.0) / n)), t.get("downed", 0.0) / n]


# --- save and load -----------------------------------------------------------------

func to_dict() -> Dictionary:
	var cells := func(list: Array) -> Array:
		var out := []
		for e in list:
			var row := {"id": e.id, "x": e.cell.x, "y": e.cell.y}
			if e.has("spells"):
				row["spells"] = e.spells
			out.append(row)
		return out
	return {
		"name": map_name, "map": grid.to_dict(), "party": cells.call(party), "enemies": cells.call(enemies),
		"party_mods": party_mods, "enemy_mods": enemy_mods, "extra_enemies": extra_enemies,
		"supplies": supplies, "seed": seed_value, "strangeness": strangeness, "art_set": art_set,
		"counters": counters, "view": view,
	}


static func from_dict(d: Dictionary) -> SandboxSetup:
	var s := SandboxSetup.new()
	s.map_name = String(d.get("name", "untitled"))
	s.grid = CombatGrid.from_dict(d.get("map", {}))
	for key in ["party", "enemies"]:
		var list: Array = s.party if key == "party" else s.enemies
		for e in d.get(key, []):
			var entry := {"id": String(e.id), "cell": Vector2i(int(e.x), int(e.y))}
			if e.has("spells"):
				entry["spells"] = Array(e.spells).map(func(x: Variant) -> String: return String(x))
			list.append(entry)
	for key in MOD_KEYS:
		s.party_mods[key] = int(d.get("party_mods", {}).get(key, s.party_mods[key]))
		s.enemy_mods[key] = int(d.get("enemy_mods", {}).get(key, s.enemy_mods[key]))
	s.extra_enemies = int(d.get("extra_enemies", 0))
	var sup: Dictionary = d.get("supplies", {})
	s.supplies = {"medicine": int(sup.get("medicine", 3)), "food": int(sup.get("food", 10))}
	s.seed_value = int(d.get("seed", 1))
	s.strangeness = float(d.get("strangeness", 0.0))
	s.art_set = String(d.get("art_set", ""))
	s.counters = bool(d.get("counters", true))
	s.view = int(d.get("view", 0)) % 4
	return s


static func safe_name(n: String) -> String:
	var out := ""
	for ch in n.strip_edges().to_lower():
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-" else "_"
	return out if out != "" else "untitled"


## Saves to data/maps (or user://maps when the project folder is read-only). Returns the path or "".
func save() -> String:
	var text := JSON.stringify(to_dict(), "\t")
	for dir in [MAP_DIR, USER_MAP_DIR]:
		DirAccess.make_dir_recursive_absolute(dir)
		var path: String = dir + safe_name(map_name) + ".json"
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(text)
			f.close()
			return path
	return ""


static func load_file(path: String) -> SandboxSetup:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		return from_dict(data)
	return null


## Every saved map, data/maps first.
static func list_maps() -> Array[String]:
	var out: Array[String] = []
	for dir in [MAP_DIR, USER_MAP_DIR]:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".json"):
				out.append(dir + f)
	return out

class_name ExploreMap
extends RefCounted
## A walkable exploration map: a battle grid (same format as the sandbox maps) plus where the party
## starts, the enemy groups standing on it and the things the party can use (doors, chests, exits).
## Loaded from data/explore/<name>.json; see docs/systems/explore.md for the format.

const DIR := "res://data/explore/"

var map_name := ""
var grid: CombatGrid
var art_set := ""
var strangeness := 0.0
var view := 0  ## camera quarter turns the map opens with
var turn := true  ## false locks the camera (building sprites only read from the front)
var start: Array[Vector2i] = []  ## party cells, leader first
## [{"id", "event", "sight", "loot", "units": [{"id": class id, "cell": Vector2i}]}]
var groups: Array[Dictionary] = []
## [{"id", "kind", "event", "cell": Vector2i, "floor": terrain letter the cell becomes when opened,
##   "to": map an "enter" thing leads to, "at": Vector2i cell it arrives on there,
##   "once": flags ("a|b"); when any is set the thing is gone for good}]
var things: Array[Dictionary] = []


static func load_named(n: String) -> ExploreMap:
	return load_file(DIR + n + ".json")


static func load_file(path: String) -> ExploreMap:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_error("bad explore map " + path)
		return null
	return from_dict(data)


static func _cell(v: Variant) -> Vector2i:
	var a: Array = v
	return Vector2i(int(a[0]), int(a[1]))


static func from_dict(d: Dictionary) -> ExploreMap:
	var m := ExploreMap.new()
	m.map_name = String(d.get("name", "untitled"))
	m.grid = CombatGrid.from_dict(d.get("grid", {}))
	m.art_set = String(d.get("art_set", ""))
	m.strangeness = float(d.get("strangeness", 0.0))
	m.view = int(d.get("view", 0))
	m.turn = bool(d.get("turn", true))
	for c in d.get("start", []):
		m.start.append(_cell(c))
	for g: Dictionary in d.get("groups", []):
		var units: Array[Dictionary] = []
		for u: Dictionary in g.get("units", []):
			units.append({"id": String(u.id), "cell": _cell(u.cell)})
		m.groups.append({"id": String(g.get("id", "group%d" % m.groups.size())), "event": String(g.get("event", "spot_people")),
			"sight": int(g.get("sight", ExploreRules.ENEMY_SIGHT)), "loot": String(g.get("loot", "")), "units": units})
	for t: Dictionary in d.get("things", []):
		m.things.append({"id": String(t.get("id", "thing%d" % m.things.size())), "kind": String(t.get("kind", "chest")),
			"event": String(t.get("event", "")), "cell": _cell(t.cell), "floor": String(t.get("floor", "s")),
			"to": String(t.get("to", "")), "at": _cell(t.get("at", [-1, -1])), "once": String(t.get("once", ""))})
	return m


static func list_maps() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".json"):
			out.append(f.get_basename())
	out.sort()
	return out

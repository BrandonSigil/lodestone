class_name MapDoc
extends RefCounted
## A map open in the map maker: its grid plus where it lives and everything else its file holds.
## battle maps are combat sandbox setups in data/maps (party, enemies, dials); explore maps are walkable maps
## in data/explore (start, enemy groups, things). The map maker edits the grid and the look; the rest of the
## file is written back untouched, except pieces left standing on cells that can't be stood on any more.

const KINDS := ["battle", "explore"]
const DIRS := {"battle": "res://data/maps/", "explore": "res://data/explore/"}
const USER_DIRS := {"battle": "user://maps/", "explore": "user://explore/"}

var kind := "battle"
var map_name := "untitled"
var grid: CombatGrid
var art_set := ""
var strangeness := 0.0
var view := 0  ## the camera turn the map opens with
var data := {}  ## the rest of the file


static func create(p_kind: String, p_name: String, p_grid: CombatGrid, p_set := "") -> MapDoc:
	var d := MapDoc.new()
	d.kind = p_kind if KINDS.has(p_kind) else "battle"
	d.map_name = p_name
	d.grid = p_grid
	d.art_set = p_set
	if d.kind == "battle":  # a new battle map starts with a test party and a band of foes
		var s := SandboxSetup.new()
		s.grid = p_grid
		d._place_pieces(s)
		d.data = s.to_dict()
	return d


## "maps/<name>" or "explore/<name>" (as list_all gives them), or a full res:// / user:// path.
static func load_path(path: String) -> MapDoc:
	var full := path
	var k := "battle"
	if path.begins_with("maps/"):
		full = DIRS.battle + path.substr(5) + ".json"
	elif path.begins_with("explore/"):
		full = DIRS.explore + path.substr(8) + ".json"
		k = "explore"
	elif path.contains("/explore/"):
		k = "explore"
	if not FileAccess.file_exists(full):
		var user: String = USER_DIRS[k] + full.get_file()
		if not FileAccess.file_exists(user):
			return null
		full = user
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(full))
	if not parsed is Dictionary:
		return null
	var src: Dictionary = parsed
	var d := MapDoc.new()
	d.kind = k
	d.map_name = String(src.get("name", full.get_file().get_basename()))
	d.grid = CombatGrid.from_dict(src.get("map" if k == "battle" else "grid", {}))
	d.art_set = String(src.get("art_set", ""))
	d.strangeness = float(src.get("strangeness", 0.0))
	d.view = int(src.get("view", 0)) % 4
	d.data = src
	return d


## Every map the maker can open: "maps/<name>" and "explore/<name>", sorted.
static func list_all() -> Array[String]:
	var out: Array[String] = []
	for k in KINDS:
		for dir in [DIRS[k], USER_DIRS[k]]:
			if not DirAccess.dir_exists_absolute(dir):
				continue
			for f in DirAccess.get_files_at(dir):
				if f.ends_with(".json"):
					var key: String = ("maps/" if k == "battle" else "explore/") + f.get_basename()
					if not out.has(key):
						out.append(key)
	out.sort()
	return out


## Is there a saved map of this kind with this name (in data/... or user://)?
static func exists(p_kind: String, p_name: String) -> bool:
	var f := SandboxSetup.safe_name(p_name) + ".json"
	return FileAccess.file_exists(DIRS[p_kind] + f) or FileAccess.file_exists(USER_DIRS[p_kind] + f)


func key() -> String:
	return ("maps/" if kind == "battle" else "explore/") + SandboxSetup.safe_name(map_name)


## The file as it will be saved.
func to_dict() -> Dictionary:
	if kind == "battle":
		var s := SandboxSetup.from_dict(data) if data.has("map") else SandboxSetup.new()
		s.map_name = SandboxSetup.safe_name(map_name)
		s.grid = grid
		s.art_set = art_set
		s.strangeness = strangeness
		s.view = view
		s.clean()
		return s.to_dict()
	var out := data.duplicate(true)
	out["name"] = SandboxSetup.safe_name(map_name)
	out["grid"] = grid.to_dict()
	out["art_set"] = art_set
	out["strangeness"] = strangeness
	out["view"] = view
	var start: Array = out.get("start", [])
	var ok := false
	for c in start:
		if grid.passable(Vector2i(int(c[0]), int(c[1]))):
			ok = true
	if not ok:
		var spots := _side_cells(true)
		out["start"] = [[spots[0].x, spots[0].y]] if not spots.is_empty() else [[0, 0]]
	return out


## Saves to data/... (or user:// when the project folder is read-only). Returns the path or "".
func save() -> String:
	var text := JSON.stringify(to_dict(), "\t")
	for dir in [DIRS[kind], USER_DIRS[kind]]:
		DirAccess.make_dir_recursive_absolute(dir)
		var path: String = dir + SandboxSetup.safe_name(map_name) + ".json"
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(text)
			f.close()
			data = to_dict()
			return path
	return ""


## A new battle map gets a test party at the screen-left end and a band of foes at the screen-right end.
func _place_pieces(s: SandboxSetup) -> void:
	var left := _side_cells(true)
	var right := _side_cells(false)
	for id in ["lead", "stardrop", "hunter"]:
		if not left.is_empty():
			s.party.append({"id": id, "cell": left.pop_front()})
	for id in ["bandit", "bandit", "bandit_archer", "wolf"]:
		if not right.is_empty():
			s.enemies.append({"id": id, "cell": right.pop_front()})


## Walkable cells from one end of the map (screen left at the opening view, or right), nearest first.
func _side_cells(left: bool) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in grid.h:
		for x in grid.w:
			var c := Vector2i(x, y)
			if grid.passable(c) and grid.terrain_at(c) != CombatGrid.T.WATER and not grid.perch(c):
				cells.append(c)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a.y - a.x > b.y - b.x) if left else (a.x - a.y > b.x - b.y))
	return cells

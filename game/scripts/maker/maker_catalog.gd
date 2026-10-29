class_name MakerCatalog
extends RefCounted
## The map maker's asset catalog: everything that can be placed on a map, sorted into drawers and groups
## (Building interior > Furniture > fireplace). Rows come from data/catalog.csv; any prop or building art in
## art/source/battle/ that no row names yet shows up on its own under "Unsorted", so new art is placeable
## the moment it lands. Kinds: prop (a sprite), thing (an interactable: door, chest...), blob (a named
## placeholder block), start (the party's start on an explore map).

const CSV := "res://data/catalog.csv"
const UNSORTED := "Unsorted"
## Thing kinds the explore scene knows (see ExploreMap and docs/systems/explore.md).
const THING_KINDS := ["door", "enter", "exit", "chest", "rack", "hidden", "shrine", "rubble"]

static var _entries: Array[Dictionary] = []
static var _angles := {}


## Every entry, in catalog order, unsorted art last.
static func entries() -> Array[Dictionary]:
	if _entries.is_empty():
		_load()
	return _entries


static func reload() -> void:
	_entries.clear()
	_angles.clear()


static func by_id(id: String) -> Dictionary:
	for e in entries():
		if e.id == id:
			return e
	return {}


## Drawer names in order of first appearance.
static func drawers() -> Array[String]:
	var out: Array[String] = []
	for e in entries():
		if not out.has(e.drawer):
			out.append(e.drawer)
	return out


## Entries matching a search: every word must appear in the label, id, drawer or group.
static func search(text: String) -> Array[Dictionary]:
	var words := text.to_lower().split(" ", false)
	var out: Array[Dictionary] = []
	for e in entries():
		var hay := ("%s %s %s %s" % [e.label, e.id, e.drawer, e.group]).to_lower()
		var hit := true
		for w in words:
			if not hay.contains(w):
				hit = false
				break
		if hit:
			out.append(e)
	return out


## The sprite stem as a map stores it. "base/..." entries mean "this tile set's own version" (a crate in a
## dungeon map is the dungeon crate), so they are stored bare; an entry from another set is stored bare when
## the map uses that set, else as "set/stem" (borrowed art).
static func stem_for(e: Dictionary, map_set: String) -> String:
	var s := String(e.sprite)
	var slash := s.find("/")
	if slash < 0:
		return s
	var from := s.substr(0, slash)
	if from == "base" or from == map_set:
		return s.substr(slash + 1)
	return s


## The faces a sprite is painted from: 0 always, plus n for every `<stem>_r<n>` file next to it.
static func angles(stem: String) -> Array[int]:
	if _angles.has(stem):
		return _angles[stem]
	var out: Array[int] = [0]
	if stem != "":
		for n in [1, 2, 3]:
			if BattleArt.texture("%s_r%d" % [stem, n]) != null:
				out.append(n)
	_angles[stem] = out
	return out


## Turn a label into a file-safe slug: "Lich king throne" -> "lich_king_throne".
static func slug(text: String) -> String:
	var out := ""
	for ch in text.to_lower().strip_edges():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif not out.ends_with("_") and out != "":
			out += "_"
	return out.trim_suffix("_")


static func _load() -> void:
	var named := {}
	for row in CsvTable.load_rows(CSV):
		var e := {
			"id": row.id, "drawer": row.drawer, "group": row.group, "kind": row.kind, "sprite": row.sprite,
			"foot": Vector2i(maxi(1, int(row.foot_w)), maxi(1, int(row.foot_h))),
			"tall": float(row.tall) if row.tall != "" else 0.9, "sight": float(row.sight) if row.sight != "" else 0.0,
			"walk": row.walk == "1", "arch": row.walk == "arch", "thing": row.thing, "event": row.event, "label": row.label if row.label != "" else row.id,
		}
		_entries.append(e)
		if row.sprite != "":
			named[String(row.sprite)] = true
			named[String(row.sprite).get_file()] = true
	# Art no row names yet: by tile set, so a new sprite can be placed right away.
	var dirs: Array[String] = [""]
	for s in BattleArt.sets():
		dirs.append(s)
	for s in dirs:
		var dir := BattleArt.DIR + s + ("/" if s != "" else "")
		if not DirAccess.dir_exists_absolute(dir):
			continue
		var files := DirAccess.get_files_at(dir)
		for f in files:
			if not f.ends_with(".png") or not (f.begins_with("prop_") or f.begins_with("b_") or f.begins_with("ph_")):
				continue
			var stem := f.get_basename()
			if stem.length() > 3 and stem.substr(stem.length() - 3, 2) == "_r" and stem.right(1).is_valid_int():
				continue  # another angle of a sprite, not its own entry
			var full := ("base" if s == "" else s) + "/" + stem
			if named.has(full) or (s == "" and named.has(stem)):
				continue
			named[full] = true
			var building := stem.begins_with("b_")
			_entries.append({
				"id": full.replace("/", "_"), "drawer": UNSORTED, "group": "base art" if s == "" else s, "kind": "prop",
				"sprite": full, "foot": Vector2i(3, 3) if building else Vector2i.ONE, "tall": 0.0 if building else 0.9,
				"sight": 3.0 if building else 0.0, "walk": false, "thing": "", "event": "",
				"label": stem.trim_prefix("prop_").trim_prefix("b_").trim_prefix("ph_").replace("_", " "),
			})


## The icon a thing draws with (catalog tile, map badge), from its kind and event.
static func thing_icon(kind: String, event: String) -> String:
	match kind:
		"door":
			return "door_sealed" if event == "sealed_door" else "door_locked"
		"enter":
			return "door_stuck" if event == "door_stuck" else "enter"
	return kind


static func icon_for(e: Dictionary) -> String:
	return thing_icon(e.thing, e.event) if e.kind == "thing" else String(e.kind)

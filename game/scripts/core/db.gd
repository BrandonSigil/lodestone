extends Node
## Loads game data once: roster, classes, events, encounters.

const CHAR_DIR := "res://data/characters/"
const CLASS_DIR := "res://data/classes/"
## Roster display order. Every id needs a .tres in data/characters.
const ROSTER := [&"lead", &"stardrop", &"hunter", &"wizard", &"bushberry", &"skeleton_archer", &"lewith_flark"]

var characters: Dictionary = {}  # id -> CharacterDef
var events: Array[Dictionary] = []
var encounters: Dictionary = {}  # id -> {"units": Array[String], "loot": String}
var items: Dictionary = {}  # id -> row of data/items.csv
var quests: Array[Dictionary] = []  # rows of data/quests.csv
var abilities: Dictionary = {}  # id -> Ability, from data/abilities.csv
var combat_items: Dictionary = {}  # id -> Ability, from data/combat_items.csv
var explore_events: Dictionary = {}  # id -> event, from data/explore_events.csv (see ExploreRules.parse_events)


func _ready() -> void:
	reload()


func reload() -> void:
	characters.clear()
	for id in ROSTER:
		characters[id] = load(CHAR_DIR + String(id) + ".tres")
	events = parse_events(CsvTable.load_rows("res://data/events.csv"))
	encounters.clear()
	for row in CsvTable.load_rows("res://data/encounters.csv"):
		encounters[row.id] = {"units": Array(row.units.split("|")), "loot": row.loot}
	items.clear()
	for row in CsvTable.load_rows("res://data/items.csv"):
		items[row.id] = row
	quests = CsvTable.load_rows("res://data/quests.csv")
	abilities.clear()
	for row in CsvTable.load_rows("res://data/abilities.csv"):
		abilities[row.id] = Ability.from_row(row)
	combat_items.clear()
	for row in CsvTable.load_rows("res://data/combat_items.csv"):
		combat_items[row.id] = Ability.from_item_row(row)
	explore_events = ExploreRules.parse_events(CsvTable.load_rows("res://data/explore_events.csv"))


## Items the village shop sells, in table order.
func shop_items() -> Array[String]:
	var out: Array[String] = []
	for id in items:
		if items[id].shop == "1":
			out.append(id)
	return out


func character(id: StringName) -> CharacterDef:
	return characters.get(id)


func ability(id: String) -> Ability:
	if abilities.is_empty():
		reload()
	return abilities.get(id)


## Every class id with a .tres in data/classes, sorted.
func class_ids() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(CLASS_DIR):
		if f.ends_with(".tres"):
			out.append(f.get_basename())
		elif f.ends_with(".tres.remap"):
			out.append(f.get_basename().get_basename())
	out.sort()
	return out


func class_def(id: String) -> ClassDef:
	return load(CLASS_DIR + id + ".tres")


func roster() -> Array[CharacterDef]:
	var out: Array[CharacterDef] = []
	for id in ROSTER:
		out.append(characters[id])
	return out


static func parse_events(rows: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in rows:
		var ev := {
			"id": row.id, "weight": float(row.weight),
			"min_s": float(row.min_s), "max_s": float(row.max_s),
			"once_flag": row.once_flag, "text_key": row.text_key, "options": [],
		}
		for n in range(1, 4):
			var key: String = row.get("opt%d_key" % n, "")
			if key == "":
				continue
			ev.options.append({
				"key": key,
				"check": row["opt%d_check" % n],
				"dc": int(row["opt%d_dc" % n]),
				"win": row["opt%d_win" % n],
				"lose": row["opt%d_lose" % n],
			})
		out.append(ev)
	return out

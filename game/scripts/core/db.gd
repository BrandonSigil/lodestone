extends Node
## Loads game data once: roster, classes, events, encounters.

const CHAR_DIR := "res://data/characters/"
const CLASS_DIR := "res://data/classes/"
## Roster display order. Every id needs a .tres in data/characters.
const ROSTER := [&"lead", &"stardrop", &"hunter", &"wizard", &"bushberry", &"skeleton_archer", &"lewith_flark", &"dog"]

var characters: Dictionary = {}  # id -> CharacterDef
var events: Array[Dictionary] = []
var encounters: Dictionary = {}  # id -> {"units": Array[String], "loot": String, "goals": String (FightGoals)}
var items: Dictionary = {}  # id -> row of data/items.csv
var quests: Array[Dictionary] = []  # rows of data/quests.csv
var abilities: Dictionary = {}  # id -> Ability, from data/abilities.csv
var combat_items: Dictionary = {}  # id -> Ability, from data/combat_items.csv
var explore_events: Dictionary = {}  # id -> event, from data/explore_events.csv (see ExploreRules.parse_events)
var levels: Dictionary = {}  # key -> number, from data/levels.csv (see LevelRules)
var combat: Dictionary = {}  # key -> number, from data/combat.csv (see CombatRules.num)
var growth: Dictionary = {}  # character id -> {stat: % chance a level}, from data/growth.csv (see LevelRules)
var recipes: Dictionary = {}  # recipe id -> data/recipes.csv row (meal, needs, kitchen flag, buff)
var restore: Array[Dictionary] = []  # village restore ladders, data/restore.csv rows (see RestoreRules)
var jobs: Dictionary = {}  # job id -> data/jobs.csv row (name_key, class, branch_a, branch_b)
var skill_ranks: Dictionary = {}  # skill id -> [effect of rank 1, rank 2, ...], from data/skill_ranks.csv
var weapons: Dictionary = {}  # id -> row of data/weapons.csv: the smithy weapons and what they add
var travel_events: Array[Dictionary] = []  # overworld encounters, data/travel_events.csv (events.csv format)
var world_nodes: Dictionary = {}  # id -> row of data/overworld_nodes.csv
var world_paths: Array[Dictionary] = []  # rows of data/overworld_paths.csv


func _ready() -> void:
	reload()


func reload() -> void:
	characters.clear()
	for id in ROSTER:
		characters[id] = load(CHAR_DIR + String(id) + ".tres")
	events = parse_events(CsvTable.load_rows("res://data/events.csv"))
	encounters.clear()
	for row in CsvTable.load_rows("res://data/encounters.csv"):
		encounters[row.id] = {"units": Array(row.units.split("|")), "loot": row.loot, "goals": String(row.get("goals", ""))}
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
	levels.clear()
	for row in CsvTable.load_rows("res://data/levels.csv"):
		levels[row.key] = float(row.value)
	combat.clear()
	for row in CsvTable.load_rows("res://data/combat.csv"):
		combat[row.key] = float(row.value)
	growth.clear()
	for row in CsvTable.load_rows("res://data/growth.csv"):
		var odds := {}
		for k in LevelRules.STATS:
			odds[k] = float(row.get(k, 0))
		growth[row.id] = odds
	restore = CsvTable.load_rows("res://data/restore.csv")
	recipes.clear()
	for row in CsvTable.load_rows("res://data/recipes.csv"):
		recipes[row.id] = row
	jobs.clear()
	for row in CsvTable.load_rows("res://data/jobs.csv"):
		jobs[row.id] = row
	skill_ranks.clear()
	for row in CsvTable.load_rows("res://data/skill_ranks.csv"):
		var list: Array = skill_ranks.get(row.skill, [])
		while list.size() < int(row.rank):
			list.append("")
		list[int(row.rank) - 1] = row.effect
		skill_ranks[row.skill] = list
	weapons.clear()
	for row in CsvTable.load_rows("res://data/weapons.csv"):
		weapons[row.id] = row
	travel_events = parse_events(CsvTable.load_rows("res://data/travel_events.csv"))
	world_nodes.clear()
	for row in CsvTable.load_rows("res://data/overworld_nodes.csv"):
		world_nodes[row.id] = row
	world_paths = CsvTable.load_rows("res://data/overworld_paths.csv")


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

extends Node
## Owns meta progression (survives a Lodestone recall) and the current run (lost on recall).
## Also moves between the three screens: village, trail, combat.

const SAVE_PATH := "user://meta.json"
const PARTY_SLOTS := 4
const VILLAGE := "res://scenes/village.tscn"
const TRAIL := "res://scenes/trail.tscn"
const COMBAT := "res://scenes/combat.tscn"
const WORLD_MAP := "res://scenes/world_map.tscn"

var meta := {"flags": [], "runs": 0, "best_distance": 0, "marks": [], "quests": [], "revealed": []}
var run: RunState = null
var save_enabled := true
var _combat_setup := {}
var pending_lines: PackedStringArray = []  ## shown by the next screen
## Village prep that survives a trip to the world map and back. Cleared on departure.
var outfit: Outfit = null
var village_party: Array[StringName] = []


func _ready() -> void:
	TranslationServer.set_locale("en")
	load_meta()


# --- meta ---------------------------------------------------------------

func has_flag(f: String) -> bool:
	return meta.flags.has(f)


func set_flag(f: String) -> bool:
	if has_flag(f):
		return false
	meta.flags.append(f)
	save_meta()
	return true


func is_unlocked(d: CharacterDef) -> bool:
	return d.unlock == "" or has_flag(d.unlock)


## The lord backs the trip more once it has proven worthwhile.
func bonus_gold() -> int:
	return int(meta.best_distance / 50) * 5


func purse() -> int:
	return Outfit.BASE_GOLD + bonus_gold()


func has_quest(id: String) -> bool:
	return meta.quests.has(id)


func take_quest(id: String) -> void:
	if not has_quest(id):
		meta.quests.append(id)
		save_meta()


## The village prep in progress, made on first visit.
func village_outfit() -> Outfit:
	if outfit == null:
		outfit = Outfit.create(Db.items, purse())
	return outfit


func load_meta() -> void:
	if not save_enabled or not FileAccess.file_exists(SAVE_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		for k in meta:
			if data.has(k):
				meta[k] = data[k]


func save_meta() -> void:
	if not save_enabled:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(meta))


func reset_meta() -> void:
	meta = {"flags": [], "runs": 0, "best_distance": 0, "marks": [], "quests": [], "revealed": []}
	save_meta()


## The Lodestone keeps what the party unearthed on the world map: the village area plus the walked route.
func remember_route(distance: int) -> void:
	var world := WorldMap.load_default()
	if meta.revealed.is_empty():
		meta.revealed = Discovery.start(world)
	Discovery.reveal_route(meta.revealed, world, distance)


# --- run flow -------------------------------------------------------------

## Leaves the village. The outfit's pack becomes the run's food and medicine, leftover gold comes along.
func start_run(defs: Array, kit: Outfit = null) -> void:
	run = RunState.create(defs, randi())
	if kit:
		run.food = kit.food()
		run.medicine = kit.medicine()
		run.gold = kit.gold
	outfit = null
	village_party = []
	go(TRAIL)


## For pressing F6 on trail.tscn or combat.tscn without going through the village.
func ensure_run() -> void:
	if run == null:
		run = RunState.create([Db.character(&"lead"), Db.character(&"stardrop"), Db.character(&"hunter")], randi())


## Apply an action's side effects that touch meta (unlocks, the Wall flag).
func absorb(unlocks: Array) -> void:
	for f in unlocks:
		if set_flag(f):
			run.note(Txt.t("LOG_UNLOCK"))
	if run.passed_wall and set_flag("reached_wall"):
		run.note(Txt.t("LOG_UNLOCK"))


func start_combat(encounter_id: String) -> void:
	ensure_run()
	run.marks.append({"d": run.distance, "kind": "combat"})
	_combat_setup = {"encounter": encounter_id, "seed": run.rng.randi(), "strangeness": run.strangeness()}
	go(COMBAT)


func take_combat_setup() -> Dictionary:
	ensure_run()
	if _combat_setup.is_empty():
		return {"encounter": "debug", "seed": randi(), "strangeness": run.strangeness()}
	var s := _combat_setup
	_combat_setup = {}
	return s


func end_combat(won: bool) -> void:
	if not won:
		recall()
		return
	for m in run.members:
		m.hp = maxi(1, m.hp)  # downed members get back up after a win
	go(TRAIL)


## The Lodestone pulls everyone home. Possessions are lost, the map and unlocks stay.
func recall() -> void:
	if run:
		meta.best_distance = maxi(int(meta.best_distance), run.distance)
		for mk in run.marks:
			meta.marks.append(mk)
		meta.marks = meta.marks.slice(-200)
		remember_route(run.distance)
	meta.runs = int(meta.runs) + 1
	for i in range(1, int(meta.runs) + 1):
		if not meta.flags.has("runs_%d" % i):
			meta.flags.append("runs_%d" % i)
	save_meta()
	run = null
	pending_lines = [Txt.t("UI_RECALL")]
	go(VILLAGE)


## Reached the end of the route.
func complete_run() -> void:
	meta.best_distance = maxi(int(meta.best_distance), run.distance)
	for mk in run.marks:
		meta.marks.append(mk)
	remember_route(run.distance)
	if not has_flag("reached_end"):
		meta.flags.append("reached_end")
	save_meta()
	run = null
	pending_lines = [Txt.t("UI_GOAL_REACHED")]
	go(VILLAGE)


func go(path: String) -> void:
	if is_inside_tree():
		get_tree().call_deferred("change_scene_to_file", path)

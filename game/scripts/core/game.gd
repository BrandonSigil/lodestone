extends Node
## Owns meta progression (survives a Lodestone recall) and the current run.
## Also moves between the screens: the explore maps, the overworld, fights (and the shelved village hub and trail).
##
## The E2E loop ([USER] 2026-10-28): the run is an "adventure" run that never ends. Its party, pack,
## levels and HP are saved in meta, and a wipe wakes everyone in the village square with everything.

const SAVE_PATH := "user://meta.json"
const PARTY_SLOTS := 4
const VILLAGE := "res://scenes/village.tscn"
const TRAIL := "res://scenes/trail.tscn"
const COMBAT := "res://scenes/combat.tscn"
const WORLD_MAP := "res://scenes/world_map.tscn"
const BATTLE := "res://scenes/battle_view.tscn"  ## one fight on one map, no editing tools: the map maker's Play test
const SANDBOX := "res://scenes/combat_sandbox.tscn"  ## archived combat sandbox: in no menu or key, open it in the editor (F6)
const EXPLORE := "res://scenes/explore.tscn"  ## walkable map, F10 from any screen for now
const MAKER := "res://scenes/map_maker.tscn"  ## the map maker, F8 from any screen
const LAUNCH := "res://scenes/launch.tscn"  ## the fast-travel menu the game opens on, F7 from any screen
const OVERWORLD := "res://scenes/overworld.tscn"  ## the map between places: town, the snowy pass, and paths still shut
const SQUARE := Vector2i(20, 23)  ## where the party wakes in the village: the square, by the statue
## Who can be in the adventure party: the hero first, then companions once their unlock flag is set.
const ADVENTURE_ROSTER := [&"lead", &"dog"]

var meta := _fresh_meta()
var run: RunState = null
var save_enabled := true
var _combat_setup := {}
var pending_lines: PackedStringArray = []  ## shown by the next screen
## Village prep that survives a trip to the world map and back. Cleared on departure.
var outfit: Outfit = null
var village_party: Array[StringName] = []
var explore_map := "home"  ## which data/explore map the explore scene opens (the hero's home starts the village)
var explore_entry := Vector2i(-1, -1)  ## where the leader arrives through a door; (-1, -1) = the map's start
## Explore maps the party walked out of and may walk back into: map -> {"seen": cells, "done": thing ids}.
var explore_memory := {}
var maker_map := ""  ## the map file the map maker reopens (it comes back here after a play test)
var sandbox_map := ""  ## a map file the combat sandbox opens instead of default.json (map maker play test)
var sandbox_play := false  ## ...and starts the fight straight away
## The overworld: {"at": node id} when standing at a place, or a leg in progress
## {"from", "to", "t": seconds walked, "stops": encounter times left, "acts": activity id -> time used}.
var travel := {"at": "town"}
var combat_return := ""  ## the scene a won fight goes back to ("" = the trail)
var _hero: CharacterDef = null


func _ready() -> void:
	TranslationServer.set_locale("en")
	load_meta()


## Developer shortcuts from anywhere: F7 the launch menu, F8 the map maker, F10 the walkable map.
func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.is_echo() and event.keycode == KEY_F7:
		go(LAUNCH)
	elif event.pressed and not event.is_echo() and event.keycode == KEY_F10:
		go(EXPLORE)
	elif event.pressed and not event.is_echo() and event.keycode == KEY_F8:
		go(MAKER)


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


static func _fresh_meta() -> Dictionary:
	return {"flags": [], "runs": 0, "best_distance": 0, "marks": [], "quests": [], "revealed": [],
		"levels": {}, "pack": {}}


func reset_meta() -> void:
	meta = _fresh_meta()
	save_meta()


## A fresh save and the first walk: the hero's cottage, nothing found, nobody met.
func new_game() -> void:
	reset_meta()
	run = null
	travel = {"at": "town"}
	explore_memory = {}
	pending_lines = []
	explore_map = "home"
	explore_entry = Vector2i(-1, -1)
	go(EXPLORE)


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


## Any screen that needs a party gets the adventure party (F6 on a scene, a launch menu jump).
func ensure_run() -> void:
	if run == null:
		start_adventure()


# --- the adventure party (E2E loop) ---------------------------------------------------------

## The hero, a nobody ([USER] 2026-10-27): the lead's look and skills on the nobody class.
## The smithy weapon adds to it (weapon_mods) instead of changing the job.
func hero_def() -> CharacterDef:
	if _hero == null:
		_hero = Db.character(&"lead").duplicate()
		_hero.class_def = load("res://data/classes/nobody.tres")
		_hero.traits = []
	return _hero


func adventure_defs() -> Array[CharacterDef]:
	var out: Array[CharacterDef] = [hero_def()]
	for id in ADVENTURE_ROSTER.slice(1):
		var d := Db.character(id)
		if d != null and is_unlocked(d):
			out.append(d)
	return out


## Builds the run from meta: the party with its HP, and the pack. Nothing here is ever lost.
func start_adventure() -> void:
	run = RunState.create([], randi())
	run.adventure = true
	var pack: Dictionary = meta.get("pack", {})
	if pack.has("grid"):
		run.load_pack(pack.grid)
	else:  # a save from before the shaped pack: counts only
		run.food = int(pack.get("food", 0))
		run.medicine = int(pack.get("medicine", 0))
		for id: String in Dictionary(pack.get("items", {})):
			if Db.items.has(id):
				run.add_item(id, int(pack["items"][id]))
	run.gold = int(pack.get("gold", 0))
	refresh_party()
	var hp: Dictionary = pack.get("hp", {})
	for m in run.members:
		var id := String((m.def as CharacterDef).id)
		if hp.has(id):
			m.hp = clampi(int(hp[id]), 1, run.max_hp(m))


## Adds companions whose flag just got set (at full HP) and recomputes everyone's level and gear bonus.
func refresh_party() -> void:
	if run == null:
		return
	for d in adventure_defs():
		var have := run.members.any(func(m: Dictionary) -> bool: return (m.def as CharacterDef).id == d.id)
		if not have:
			run.join(d)
	for m in run.members:
		var id := String((m.def as CharacterDef).id)
		var before := run.max_hp(m)
		m.bonus = LevelRules.merge(LevelRules.bonus(level_state(id), Db.levels), weapon_mods(id))
		m.hp = clampi(int(m.hp) + maxi(0, run.max_hp(m) - before), 0, run.max_hp(m))


## What the picked smithy weapon adds (data/weapons.csv). Only the hero carries one.
func weapon_mods(id: String) -> Dictionary:
	if id != "lead":
		return {}
	var row: Dictionary = Db.weapons.get(weapon_id(), {})
	var out := {}
	for k in ["attack", "damage", "move", "range_min", "range_max"]:
		out[k] = int(row.get(k, 0))
	return out


func weapon_id() -> String:
	for id in Db.weapons:
		var f := String(Db.weapons[id].flag)
		if f != "" and has_flag(f):
			return id
	return "none"


func level_state(id: String) -> Dictionary:
	return LevelRules.normalize(meta.levels.get(id))


## XP for everyone in the party; returns the log lines (who reached which level, picks waiting).
func award_xp(amount: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	if run == null:
		return lines
	for m in run.members:
		var d: CharacterDef = m.def
		var s := level_state(String(d.id))
		var had := int(s.pending)
		for lv in LevelRules.gain(s, amount, Db.levels):
			lines.append(Txt.f("UI_LEVEL_UP", [Txt.t(d.name_key), lv]))
		if int(s.pending) > had:
			lines.append(Txt.f("UI_LS_PICK_WAITING", Txt.t(d.name_key)))
		meta.levels[String(d.id)] = s
	refresh_party()
	save_adventure()
	return lines


func pending_picks() -> int:
	var n := 0
	for id in meta.levels:
		n += int(level_state(String(id)).pending)
	return n


## Spend one Lodestone pick (hp, attack or magic) for a party member.
func pick_boost(id: String, pick: String) -> bool:
	var s := level_state(id)
	if not LevelRules.choose(s, pick):
		return false
	meta.levels[id] = s
	refresh_party()
	save_adventure()
	return true


## The pack and HP go into meta, so nothing is lost on a restart or a wake-up.
func save_adventure() -> void:
	if run == null or not run.adventure:
		return
	var hp := {}
	for m in run.members:
		hp[String((m.def as CharacterDef).id)] = int(m.hp)
	meta.pack = {"grid": run.pack.to_save(), "gold": run.gold, "hp": hp}
	save_meta()


## Wake in the village square, everyone at full HP ([USER] 2026-10-28: a wipe costs nothing; the
## Lodestone's GO HOME lands the same way). The first wake-up is when the hero learns what the stone does.
func wake_in_town(fell: bool) -> void:
	ensure_run()
	for m in run.members:
		m.hp = run.max_hp(m)
	if fell:
		meta.runs = int(meta.runs) + 1
		pending_lines = [Txt.t("UI_WAKE_FIRST") if set_flag("lodestone_revealed") else Txt.t("UI_WAKE")]
	else:
		pending_lines = [Txt.t("UI_WENT_HOME")]
	travel = {"at": "town"}
	explore_memory = {}
	explore_map = "village"
	explore_entry = SQUARE
	combat_return = ""
	save_adventure()
	go(EXPLORE)


## Apply an action's side effects that touch meta (unlocks, the Wall flag).
func absorb(unlocks: Array) -> void:
	for f in unlocks:
		if set_flag(f):
			run.note(Txt.t("LOG_UNLOCK"))
	if run.passed_wall and set_flag("reached_wall"):
		run.note(Txt.t("LOG_UNLOCK"))


## A fight on a generated map. art_set picks its tile set ("" = the default); back_to is the scene a win
## returns to ("" = the trail).
func start_combat(encounter_id: String, art_set := "", back_to := "") -> void:
	ensure_run()
	run.marks.append({"d": run.distance, "kind": "combat"})
	_combat_setup = {"encounter": encounter_id, "seed": run.rng.randi(), "strangeness": run.strangeness(), "art_set": art_set}
	combat_return = back_to
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
	var back := combat_return if combat_return != "" else TRAIL
	combat_return = ""
	go(back)


## The Lodestone pulls everyone home. An adventure run wakes in the square with everything.
## The shelved trail's runs keep the old rule: possessions are lost, the map and unlocks stay.
func recall() -> void:
	if run and run.adventure:
		wake_in_town(true)
		return
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
	save_adventure()
	if is_inside_tree():
		get_tree().call_deferred("change_scene_to_file", path)

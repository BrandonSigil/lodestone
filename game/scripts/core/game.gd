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
	get_tree().auto_accept_quit = false  # closing the window bookmarks first (_notification)


## Closing the window is a save and quit ([USER] omr-11): the screen writes its bookmark, then the game ends.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var scene := get_tree().current_scene
		if scene != null and scene.has_method("bookmark"):
			scene.call("bookmark")
		get_tree().quit()


# --- the bookmark save ([USER] omr-4, omr-11: save and quit anywhere outside a fight; a fight quit
# midway restarts from its first turn) ----------------------------------------------------------------

signal bookmarked  ## a bookmark was just written: screens show the SAVED cue

var resume_fight := {}  ## set by continue_game: the fight to start over, {"group": id, "how": ...} or {"road": ...}


## Writes where the party is. state: {"scene": "explore" | "overworld", "map", "cell": [x, y], "fight": {}}.
## Explore memory and the overworld walk come along. A screen in the middle of a fight doesn't call this:
## the bookmark taken when the fight began stands, so a quit fight restarts from its first turn.
func bookmark(state: Dictionary) -> void:
	if not save_enabled or run == null or not run.adventure:
		return
	var b := state.duplicate(true)
	b["memory"] = memory_to_save(explore_memory)
	b["travel"] = travel.duplicate(true)
	meta.bookmark = b
	save_adventure()
	bookmarked.emit()


func has_bookmark() -> bool:
	return not (meta.get("bookmark", {}) as Dictionary).is_empty()


## Back to exactly where the bookmark was: the map and the hero's cell, or the overworld walk; a fight that
## was going starts again from its first turn. No bookmark: the cottage.
func continue_game() -> void:
	restore_bookmark()
	if String(meta.bookmark.get("scene", "")) == "overworld" and resume_fight.has("road"):
		var f := resume_fight
		resume_fight = {}
		start_combat(String(f.road), String(f.get("art_set", "")), OVERWORLD)
		return
	go(OVERWORLD if String(meta.bookmark.get("scene", "")) == "overworld" else EXPLORE)


## Puts the run, the explore memory, the walk and the map back as the bookmark had them. Returns the scene
## to open (continue_game opens it).
func restore_bookmark() -> String:
	var b: Dictionary = meta.get("bookmark", {})
	run = null
	ensure_run()
	explore_memory = memory_from_save(b.get("memory", {}))
	travel = Dictionary(b.get("travel", {"at": "town"})).duplicate(true)
	resume_fight = Dictionary(b.get("fight", {})).duplicate(true)
	if String(b.get("scene", "")) == "overworld":
		return OVERWORLD
	explore_map = String(b.get("map", "home"))
	var cell: Array = b.get("cell", [-1, -1])
	explore_entry = Vector2i(int(cell[0]), int(cell[1]))
	return EXPLORE


## Explore memory with its cell keys as [x, y] pairs, for JSON.
static func memory_to_save(mem: Dictionary) -> Dictionary:
	var out := {}
	for name in mem:
		var m: Dictionary = mem[name]
		var seen_cells := []
		for c: Vector2i in m.get("seen", {}):
			seen_cells.append([c.x, c.y])
		out[name] = {"seen": seen_cells, "done": m.get("done", []).duplicate(), "groups": Dictionary(m.get("groups", {})).duplicate()}
	return out


static func memory_from_save(saved: Dictionary) -> Dictionary:
	var out := {}
	for name in saved:
		var m: Dictionary = saved[name]
		var seen_cells := {}
		for c in m.get("seen", []):
			seen_cells[Vector2i(int(c[0]), int(c[1]))] = true
		out[String(name)] = {"seen": seen_cells, "done": Array(m.get("done", [])), "groups": Dictionary(m.get("groups", {}))}
	return out


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
		"levels": {}, "pack": {}, "materials": {}, "benched": [], "bookmark": {}, "restore": {}, "tracked": [], "trips": 0}


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

## The hero: the lead's look and skills on the class of his job. [USER] pc-9: the weapon is the job, from the
## start (sword knight, daggers rogue, bow archer, the hidden book mage); before the smithy he's a nobody.
## The weapon also adds its own numbers (weapon_mods).
func hero_def() -> CharacterDef:
	var job := job_id()
	var cls_id := String(Db.jobs[job].class) if Db.jobs.has(job) else "nobody"
	if _hero == null or String(_hero.class_def.id) != cls_id:
		_hero = Db.character(&"lead").duplicate()
		_hero.class_def = load("res://data/classes/%s.tres" % cls_id)
		_hero.traits = []
	return _hero


## The hero's job: the one his weapon makes ("" with bare hands).
func job_id() -> String:
	return String(Db.weapons.get(weapon_id(), {}).get("job", ""))


## Take a weapon from the smithy rack: it becomes the hero's job ([USER] pc-9, pc-12). He keeps his level and
## rolled gains; his stats shift to the new job's base; a job he never had starts at job level 1 with no ranks.
func take_weapon(id: String) -> void:
	for w in Db.weapons:
		var f := String(Db.weapons[w].flag)
		if f != "":
			meta.flags.erase(f)
	var flag := String(Db.weapons.get(id, {}).get("flag", ""))
	if flag != "":
		meta.flags.append(flag)
	var s := level_state("lead")
	var job := job_id()
	if job != "" and not s.jobs.has(job):
		s.jobs[job] = LevelRules.fresh_job()
	meta.levels["lead"] = s
	refresh_party()
	save_adventure()
	save_meta()


## The state that holds this member's ranks: the hero's current job, or the character itself.
func rank_state(id: String) -> Dictionary:
	var s := level_state(id)
	if id == "lead" and job_id() != "":
		return s.jobs.get(job_id(), LevelRules.fresh_job())
	return s


## Pick one of the job's two branches once it's ready ([USER] pc-13; placeholders until their skills exist).
func choose_branch(which: String) -> bool:
	var s := level_state("lead")
	var job := job_id()
	if not s.jobs.has(job) or not LevelRules.branch_ready(s.jobs[job], Db.levels) or not which in ["a", "b"]:
		return false
	s.jobs[job].branch = which
	meta.levels["lead"] = s
	save_adventure()
	save_meta()
	return true


## The party: the hero and the companions coming along. [USER] pc-1, pc-10: four fight, and who comes is
## changed only at home (the gate's EDIT PARTY, or walking up to a companion in the village). A companion met
## for the first time joins on their own while there's room; the player benches them to leave them home.
func adventure_defs() -> Array[CharacterDef]:
	var out: Array[CharacterDef] = [hero_def()]
	for d in companions():
		if not meta.benched.has(String(d.id)) and out.size() < party_max():
			out.append(d)
	return out


## Every companion the hero has met (in the roster's order), in the party or not.
func companions() -> Array[CharacterDef]:
	var out: Array[CharacterDef] = []
	for id in ADVENTURE_ROSTER.slice(1):
		var d := Db.character(id)
		if d != null and is_unlocked(d):
			out.append(d)
	return out


func party_max() -> int:
	return int(Db.levels.get("party_max", 4))


func in_party(id: String) -> bool:
	return adventure_defs().any(func(d: CharacterDef) -> bool: return String(d.id) == id)


## Bring a companion along (false when the party is full) or leave them at home. Only at home: the gate
## prompt and the companions' homes in the village call these.
func invite(id: String) -> bool:
	if in_party(id):
		return true
	if adventure_defs().size() >= party_max():
		return false
	meta.benched.erase(id)
	refresh_party()
	save_adventure()
	save_meta()
	return true


func dismiss(id: String) -> void:
	if not meta.benched.has(id):
		meta.benched.append(id)
	refresh_party()
	save_adventure()
	save_meta()


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
	run.meal = Dictionary(pack.get("meal", {})).duplicate()
	run.boons.assign(Array(pack.get("boons", [])).filter(func(id: Variant) -> bool: return Db.boons.has(String(id))))
	run.load_waiting(pack.get("waiting", {}))
	refresh_party()
	run.load_belts(pack.get("belts", {}))
	var hp: Dictionary = pack.get("hp", {})
	for m in run.members:
		var id := String((m.def as CharacterDef).id)
		if hp.has(id):
			m.hp = clampi(int(hp[id]), 1, run.max_hp(m))
	run.on_pickup = _on_pickup  # from here on, pickups that count toward a tracked step say so


## Adds companions whose flag just got set (at full HP) and recomputes everyone's level and gear bonus.
func refresh_party() -> void:
	if run == null:
		return
	var wanted := adventure_defs()
	for d in wanted:
		var have := run.members.any(func(m: Dictionary) -> bool: return (m.def as CharacterDef).id == d.id)
		if not have and not run.is_away(d.id):
			run.join(d)
	for m in run.members.duplicate():  # benched at home: what was on their belt goes back to the pack
		var id := String((m.def as CharacterDef).id)
		if id != "lead" and not wanted.any(func(d: CharacterDef) -> bool: return String(d.id) == id):
			for it in (m.belt as InventoryGrid).items:
				run.add_item(String(it.id), int(it.get("n", 1)))
			run.members.erase(m)
	for m in run.members:
		var id := String((m.def as CharacterDef).id)
		if id == "lead":
			m.def = hero_def()  # the class follows the weapon
		var before := run.max_hp(m)
		var s := level_state(id)
		m.bonus = LevelRules.merge(LevelRules.merge(LevelRules.merge(LevelRules.bonus(s, Db.levels), weapon_mods(id)), meal_mods()), boon_mods())
		m.ranks = rank_state(id).ranks
		m.hp = clampi(int(m.hp) + maxi(0, run.max_hp(m) - before), 0, run.max_hp(m))


## What the picked smithy weapon adds (data/weapons.csv). Only the hero carries one. weapon: another
## weapon to try instead of the one in hand (the rack's character sheets).
func weapon_mods(id: String, weapon := "") -> Dictionary:
	if id != "lead":
		return {}
	var w := weapon if weapon != "" else weapon_id()
	var row: Dictionary = Db.weapons.get(w, {})
	var out := {}
	for k in ["attack", "damage", "move", "range_min", "range_max"]:
		out[k] = int(row.get(k, 0))
	# the smithy's upgrades for this weapon ([USER] pc-14; its own ladder in data/restore.csv)
	out.damage += weapon_level(w) * int(CombatRules.num("upgrade_damage"))
	return out


## A character sheet (SheetRules.build) for a party member as they stand now, or for the hero holding
## `weapon` instead (the smithy rack shows one per build before the player picks): that job's class, the
## weapon's numbers and that job's own ranks. Nothing is changed or saved.
func sheet(id: String, weapon := "") -> Dictionary:
	ensure_run()
	var s := level_state(id)
	var def: CharacterDef = Db.character(StringName(id))
	var ranks: Dictionary = rank_state(id).ranks
	var w := weapon if weapon != "" else (weapon_id() if id == "lead" else "")
	var job := String(Db.weapons.get(w, {}).get("job", "")) if id == "lead" else ""
	if id == "lead":
		def = _hero_as(job)
		ranks = s.jobs.get(job, LevelRules.fresh_job()).ranks if job != "" else s.ranks
	var bonus := LevelRules.merge(LevelRules.merge(LevelRules.merge(LevelRules.bonus(s, Db.levels), weapon_mods(id, w)), meal_mods()), boon_mods())
	var hp := 9999
	for m in run.members:
		if String((m.def as CharacterDef).id) == id:
			hp = int(m.hp)
	var u := CombatUnit.from_member({"def": def, "bonus": bonus, "ranks": ranks, "hp": hp})
	var row: Dictionary = Db.weapons.get(w, {})
	return SheetRules.build(u, {"name": def.name_key, "job": String(Db.jobs[job].name_key) if Db.jobs.has(job) else def.class_def.name_key,
		"level": int(s.level), "xp": int(s.xp), "xp_next": int(Db.levels.get("xp_per_level", 100)),
		"weapon": String(row.get("name_key", "")) if w != "none" else "", "portrait": StringName(id),
		"weapon_id": w})


## The hero on another job's class, for a look (sheet); hero_def is the one he plays.
func _hero_as(job: String) -> CharacterDef:
	if job == job_id():
		return hero_def()
	var d: CharacterDef = Db.character(&"lead").duplicate()
	d.class_def = load("res://data/classes/%s.tres" % (String(Db.jobs[job].class) if Db.jobs.has(job) else "nobody"))
	d.traits = []
	return d


## A weapon's upgrade level: the steps of its smithy ladder that are done (0 to 3).
func weapon_level(id: String) -> int:
	return RestoreRules.done_count(Db.restore, id, meta.restore)


## Does anyone carry a weapon? Only the hero does, from the smithy rack; "none" is bare hands.
func armed() -> bool:
	return weapon_id() != "none"


## The weapon the hero holds now: the one whose flag is set (take_weapon keeps it to one).
func weapon_id() -> String:
	for id in Db.weapons:
		var f := String(Db.weapons[id].flag)
		if f != "" and has_flag(f):
			return id
	return "none"


func level_state(id: String) -> Dictionary:
	return LevelRules.normalize(meta.levels.get(id))


## XP for everyone in the party; each level rolls their stats from data/growth.csv. Returns the log lines
## (who reached which level and what went up, ranks waiting).
func award_xp(amount: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	if run == null:
		return lines
	for m in run.members:
		var d: CharacterDef = m.def
		var id := String(d.id)
		var s := level_state(id)
		var job := job_id() if id == "lead" else ""
		var odds: Dictionary = Db.growth.get(job if Db.growth.has(job) else id, {})
		var had := int(s.pending)
		var before: Dictionary = s.gains.duplicate()
		for lv in LevelRules.gain(s, amount, Db.levels, odds, run.rng):
			lines.append(Txt.f("UI_LEVEL_UP", [Txt.t(d.name_key), lv]))
		var up: PackedStringArray = []
		for k in LevelRules.STATS:
			var n := int(s.gains[k]) - int(before.get(k, 0))
			if n > 0:
				up.append("%s +%d" % [Txt.t("UI_STAT_" + k.to_upper()), n * (int(Db.levels.get("growth_hp", 2)) if k == "hp" else 1)])
		if not up.is_empty():
			lines.append("  " + "  ".join(up))
		var waiting := int(s.pending) > had
		if id == "lead":
			s.pending = 0  # the hero's ranks come from his job (none before the smithy)
			waiting = false
		if job != "":
			# his job levels on the same XP ([USER] pc-12)
			var js: Dictionary = s.jobs.get(job, LevelRules.fresh_job())
			var jhad := int(js.pending)
			var was_ready := LevelRules.branch_ready(js, Db.levels)
			LevelRules.gain(js, amount, Db.levels)
			waiting = int(js.pending) > jhad
			if not was_ready and LevelRules.branch_ready(js, Db.levels):
				lines.append(Txt.f("UI_BRANCH_WAITING", Txt.t(String(Db.jobs[job].name_key))))
			s.jobs[job] = js
		if waiting:
			lines.append(Txt.f("UI_LS_PICK_WAITING", Txt.t(d.name_key)))
		meta.levels[id] = s
	refresh_party()
	save_adventure()
	return lines


## Ranks waiting to be spent and branches waiting to be picked: what makes the Lodestone button glow.
func pending_picks() -> int:
	var n := 0
	for id in meta.levels:
		n += int(level_state(String(id)).pending)
	var job := job_id()
	if job != "":
		var js: Dictionary = rank_state("lead")
		n += int(js.pending) + (1 if LevelRules.branch_ready(js, Db.levels) else 0)
	return n


## Spend one waiting rank on one of a party member's skills ([USER] pc-8); the hero's go to his current job.
func rank_skill(id: String, skill: String) -> bool:
	var s := level_state(id)
	var job := job_id() if id == "lead" else ""
	var target: Dictionary = s.jobs.get(job, LevelRules.fresh_job()) if job != "" else s
	if not LevelRules.rank_up(target, skill, Db.skill_ranks):
		return false
	if job != "":
		s.jobs[job] = target
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
	meta.pack = {"grid": run.pack.to_save(), "belts": run.belts_save(), "waiting": run.waiting_save(), "gold": run.gold, "hp": hp,
		"meal": run.meal.duplicate(), "boons": run.boons.duplicate()}
	save_meta()


## Wake in the village square, everyone at full HP ([USER] 2026-10-28: a wipe costs nothing; the
## Lodestone's GO HOME lands the same way). The first wake-up is when the hero learns what the stone does.
func wake_in_town(fell: bool) -> void:
	ensure_run()
	home_again()
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


## The party is home (woken in the square, or walked into the village): whoever was sent home rejoins
## and unpacks, then the materials go to the village's count (meta.materials).
func home_again() -> void:
	if run == null:
		return
	var back := not run.away.is_empty()
	if back:
		run.come_home()
		refresh_party()
	if not run.boons.is_empty():
		run.boons.clear()  # blessings and setbacks last until the party is home ([USER] omr-7, omr-8)
		refresh_party()
	var banked := run.bank_materials()
	for id: String in banked:
		meta.materials[id] = int(meta.materials.get(id, 0)) + int(banked[id])
	# restore steps paid before this trip are done now ([USER] omr-12)
	var finished := RestoreRules.finish(Db.restore, meta.restore, int(meta.trips))
	for r: Dictionary in finished:
		var out := TrailRules.apply_effects(run, String(r.get("gives", "")))
		absorb(out.unlocks)
		pending_lines.append(Txt.f("UI_RESTORE_DONE_LINE", [Txt.t("BUILDING_" + String(r.building).to_upper()), Txt.t(String(r.name_key))]))
		meta.tracked.erase(String(r.id))
	if back or not banked.is_empty() or not finished.is_empty():
		save_adventure()  # saves meta too
		if not run.adventure:
			save_meta()


# --- restoring the village ([USER] omr-2, omr-5, omr-12; one-more-run step 2) --------------------------

signal counts(text: String)  ## a pickup counts toward a tracked step: screens show the line


## A thing that rests for the rest of this trip once used (a fishing spot): `key` is "<map>/<thing id>".
func use_for_trip(key: String) -> void:
	var used: Dictionary = meta.get("trip_used", {})
	used[key] = int(meta.trips)
	meta["trip_used"] = used
	save_meta()


func used_this_trip(key: String) -> bool:
	return int(meta.get("trip_used", {}).get(key, -1)) == int(meta.trips)


## Out the gate: a new trip. Steps paid before it finish when the party is home again.
func start_trip() -> void:
	meta.trips = int(meta.trips) + 1
	save_meta()


## Why a ladder is shut: nobody lives there yet, or another step has to be done first (the weapons wait
## for the smithy's sharpening stone).
func locked_text(building: String) -> String:
	var first := RestoreRules.opened_by(Db.restore, building)
	return Txt.f("UI_RESTORE_NEEDS_FIRST", Txt.t(String(first.name_key))) if not first.is_empty() else Txt.t("UI_RESTORE_LOCKED")


## Pay a building's next step from the village pile. False when it can't be paid.
func pay_step(id: String) -> bool:
	var rows := Db.restore.filter(func(r: Dictionary) -> bool: return String(r.id) == id)
	if rows.is_empty() or not RestoreRules.pay(rows[0], meta.restore, meta.materials, int(meta.trips)):
		return false
	save_adventure()
	save_meta()
	return true


func toggle_track(id: String) -> void:
	if meta.tracked.has(id):
		meta.tracked.erase(id)
	else:
		meta.tracked.append(id)
	save_meta()


## What the party has toward a step: the village pile, plus what's carried on a trip.
func have_for_goals() -> Dictionary:
	var out: Dictionary = Dictionary(meta.materials).duplicate()
	if run != null:
		var carried := run.items
		for id in carried:
			out[id] = int(out.get(id, 0)) + int(carried[id])
	return out


## Tracked steps not yet paid, with what each still misses: [{"row", "missing"}].
func tracked_missing() -> Array:
	var out := []
	var have := have_for_goals()
	for r: Dictionary in Db.restore:
		if meta.tracked.has(String(r.id)) and RestoreRules.status(meta.restore, String(r.id)) == "":
			out.append({"row": r, "missing": RestoreRules.missing(r, have)})
	return out


## The frame's goal lines: each tracked step and what it still misses ("SMITHY FORGE: METAL 2, WOOD 1").
func goal_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for g: Dictionary in tracked_missing():
		var parts: PackedStringArray = []
		for id in g.missing:
			parts.append("%s %d" % [Txt.t(String(Db.items[id].name_key)), int(g.missing[id])])
		lines.append("%s: %s" % [Txt.t(String(g.row.name_key)), ", ".join(parts) if not parts.is_empty() else Txt.t("UI_RESTORE_READY")])
	return lines


## A pickup that counts toward a tracked step says so ([USER] omr-5).
func _on_pickup(id: String, _n: int) -> void:
	for r: Dictionary in Db.restore:
		if meta.tracked.has(String(r.id)) and RestoreRules.status(meta.restore, String(r.id)) == "" \
				and RestoreRules.parse_needs(String(r.needs)).has(id):
			counts.emit(Txt.f("UI_COUNTS_FOR", [Txt.t(String(Db.items[id].name_key)), Txt.t(String(r.name_key))]))
			return


# --- meals ([USER] omr-9; one-more-run step 4): cooked at home from the chef's recipes, eaten at camp ------

## Recipes the kitchen can make now (each opens with a kitchen restore step).
func recipes_open() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in Db.recipes:
		var r: Dictionary = Db.recipes[id]
		if String(r.kitchen) == "" or has_flag(String(r.kitchen)):
			out.append(r)
	return out


## Cook a recipe at home: its ingredients from the village pile, its meal into the pack (a full pack puts
## it in FOUND as any pickup). False when the kitchen can't make it or something's missing.
func cook(recipe: String) -> bool:
	var r: Dictionary = Db.recipes.get(recipe, {})
	if r.is_empty() or not recipes_open().has(r) or not RestoreRules.missing(r, meta.materials).is_empty():
		return false
	var needs := RestoreRules.parse_needs(String(r.needs))
	for id in needs:
		meta.materials[id] = int(meta.materials[id]) - int(needs[id])
		if int(meta.materials[id]) <= 0:
			meta.materials.erase(id)
	run.add_item(String(r.meal), 1)
	save_adventure()
	return true


## The recipe a carried meal item was cooked from.
func recipe_of(meal_item: String) -> Dictionary:
	for id in Db.recipes:
		if String(Db.recipes[id].meal) == meal_item:
			return Db.recipes[id]
	return {}


## Eat a carried meal at camp: everyone gets its buff for the next few fights (meal_fights).
func eat_meal(meal_item: String) -> bool:
	var r := recipe_of(meal_item)
	if r.is_empty() or run.item_count(meal_item) <= 0:
		return false
	run.add_item(meal_item, -1)
	run.meal = {"recipe": String(r.id), "fights": int(Db.levels.get("meal_fights", 2))}
	run.note(Txt.f("LOG_MEAL", Txt.t(String(r.name_key))))
	refresh_party()
	save_adventure()
	return true


## The camp meal's buff, in CombatUnit mod keys ("damage:+1;defense:+1;hp:+4").
func meal_mods() -> Dictionary:
	if run == null or run.meal.is_empty() or int(run.meal.get("fights", 0)) <= 0:
		return {}
	return RestoreRules.parse_needs(String(Db.recipes.get(String(run.meal.recipe), {}).get("buff", "")))


## A fight is over: one fight less on the meal's buff.
func fight_done() -> void:
	if run == null or run.meal.is_empty():
		return
	run.meal.fights = int(run.meal.fights) - 1
	if int(run.meal.fights) <= 0:
		run.meal = {}
	refresh_party()


# --- blessings and setbacks ([USER] omr-6, omr-7, omr-8; one-more-run step 5) ---------------------------

## What an event's outcome gave: a random blessing or setback for each it names. Returns the log lines.
func absorb_boons(out: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	for i in int(out.get("blessings", 0)):
		var id := give_boon("blessing")
		if id != "":
			lines.append(Txt.f("UI_GOT_BLESSING", Txt.t(String(Db.boons[id].name_key))))
	for i in int(out.get("setbacks", 0)):
		var id := give_boon("setback")
		if id != "":
			lines.append(Txt.f("UI_GOT_SETBACK", Txt.t(String(Db.boons[id].name_key))))
	return lines


## Draws one at random from the pool, not one already held; blessings stop at blessing_max. "" when none.
func give_boon(kind: String) -> String:
	if run == null:
		return ""
	var held := run.boons.filter(func(id: String) -> bool: return String(Db.boons[id].kind) == kind).size()
	if kind == "blessing" and held >= int(Db.levels.get("blessing_max", 5)):
		return ""
	var pool: Array = Db.boons.keys().filter(func(id: String) -> bool: return String(Db.boons[id].kind) == kind and not run.boons.has(id))
	if pool.is_empty():
		return ""
	var id: String = pool[run.rng.randi_range(0, pool.size() - 1)]
	run.boons.append(id)
	refresh_party()
	save_adventure()
	return id


## Everything the held blessings and setbacks change, in CombatUnit mod keys (food goes to the run).
func boon_mods() -> Dictionary:
	var out := {}
	if run == null:
		return out
	for id in run.boons:
		out = LevelRules.merge(out, RestoreRules.parse_needs(String(Db.boons[id].effect)))
	run.food_extra = int(out.get("food", 0))
	out.erase("food")
	return out


## A stat item from a map, for good ([USER] omr-10): +2 HP or +1 to a stat on one member.
func take_boost(id: String, stat: String, n: int) -> void:
	var s := level_state(id)
	s.found[stat] = int(s.found.get(stat, 0)) + n
	meta.levels[id] = s
	refresh_party()
	save_adventure()


## How much of a material the village has banked.
func material_count(id: String) -> int:
	return int(meta.materials.get(id, 0))


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
	if back_to == OVERWORLD:
		# a road fight quit midway starts over from the road ([USER] omr-11)
		bookmark({"scene": "overworld", "fight": {"road": encounter_id, "art_set": art_set}})
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

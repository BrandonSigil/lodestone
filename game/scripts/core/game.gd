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
const FISHING := "res://scenes/fishing.tscn"  ## the fishing minigame on its own, for practice (launch menu)
const OVERWORLD := "res://scenes/overworld.tscn"  ## the map between places: town, the snowy pass, and paths still shut
const SQUARE := Vector2i(20, 23)  ## where the party wakes in the village: the square, by the statue
## Who can be in the adventure party: the hero first, then companions once their unlock flag is set.
const ADVENTURE_ROSTER := [&"lead", &"dog", &"fire_mage", &"bushberry"]  ## everyone with art (playtest: met in the square)

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
var god_return := {}  ## God mode: where "Back to play" goes from the maker ({"kind": "explore", "map", "cell"} or {"kind": "battle"})
var maker_focus := Vector2i(-1, -1)  ## the cell the maker centres on when it opens (God mode: where the party stood)
var sandbox_map := ""  ## a map file the combat sandbox opens instead of default.json (map maker play test)
var sandbox_play := false  ## ...and starts the fight straight away
var scale_test := false  ## ...as the scale C test: a knight, a fast rogue and a slow ranged mage, with scale C's numbers (ScaleTest)
## The overworld: {"at": node id} when standing at a place, or a leg in progress
## {"from", "to", "t": seconds walked, "stops": encounter times left, "acts": activity id -> time used}.
var travel := {"at": "town"}
var combat_return := ""  ## the scene a won fight goes back to ("" = the trail)
var _hero: CharacterDef = null
## The homecoming page waiting for the village to show it (HomecomingRules.summary, plus "headline"); {} when none.
var homecoming := {}


func _ready() -> void:
	TranslationServer.set_locale("en")
	# One look for every menu ([USER] 2026-10-30). Merged into the engine's default, the theme every Control falls
	# back to (a root-window theme doesn't reach Controls under a CanvasLayer); riso screens still set their own.
	ThemeDB.get_default_theme().merge_with(UiTheme.make())
	load_meta()
	_apply_settings()
	add_child(GodMode.new())
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
		out[name] = {"seen": seen_cells, "done": m.get("done", []).duplicate(), "groups": Dictionary(m.get("groups", {})).duplicate(),
			"containers": Dictionary(m.get("containers", {})).duplicate(true), "piles": Array(m.get("piles", [])).duplicate(true)}
	return out


static func memory_from_save(saved: Dictionary) -> Dictionary:
	var out := {}
	for name in saved:
		var m: Dictionary = saved[name]
		var seen_cells := {}
		for c in m.get("seen", []):
			seen_cells[Vector2i(int(c[0]), int(c[1]))] = true
		out[String(name)] = {"seen": seen_cells, "done": Array(m.get("done", [])), "groups": Dictionary(m.get("groups", {})),
			"containers": Dictionary(m.get("containers", {})), "piles": Array(m.get("piles", []))}
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
	_link_hearts()


func save_meta() -> void:
	if not save_enabled:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(meta))


static func _fresh_meta() -> Dictionary:
	return {"flags": [], "runs": 0, "best_distance": 0, "marks": [], "quests": [], "revealed": [],
		"levels": {}, "pack": {}, "materials": {}, "benched": [], "bookmark": {}, "restore": {}, "tracked": [], "trips": 0,
		"bonds": {}, "talks_heard": [], "settings": {}, "ledger": {}, "morale": {}, "days": 0}


## Saves one option (the options screen) and applies it.
func set_setting(key: String, value: Variant) -> void:
	var st: Dictionary = meta.get("settings", {})
	st[key] = value
	meta["settings"] = st
	save_meta()
	_apply_settings()


func _apply_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var full := bool(meta.get("settings", {}).get("fullscreen", false))
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want and (full or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN):
		DisplayServer.window_set_mode(want)


func reset_meta() -> void:
	meta = _fresh_meta()
	_link_hearts()
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
	if Dictionary(meta.get("ledger", {})).is_empty():
		meta.ledger = HomecomingRules.snapshot(meta, false)  # what the homecoming page counts from


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
		refresh_party()  # just unlocked (the square's recruit events set the flag first): bring them into the run
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
		var saved: Dictionary = pack.get("res", {})
		if saved.has(id):
			m.res = int(saved[id][0])
			m.res_tick = int(saved[id][1])
	run.on_pickup = _on_pickup  # from here on, pickups that count toward a tracked step say so
	_link_hearts()
	refresh_party()  # with morale linked: each member's band in their fight numbers


# --- mana and charges carry on an outing ([USER] 2026-10-30, "Fights must cost"; docs/design/outing-tuning.md) ------
# A member's `res` is what its mana or charges had left after the last fight (-1 or absent: full), `res_tick` the
# charge clock. Rage resets every fight. Ways back: a trickle while walking, a camp rest, a tonic, and a wake-up.

func store_res(u: CombatUnit) -> void:
	if u.member.is_empty() or not u.res_kind in ["mana", "charges"]:
		return
	u.member.res = u.res
	u.member.res_tick = u.res_tick


func member_res(m: Dictionary) -> Dictionary:
	var c: ClassDef = (m.def as CharacterDef).class_def
	var kind := String(c.resource)
	var most := int(c.resource_max) if kind in ["mana", "charges"] else 0
	if most > 0:  # broken morale takes one off (MoraleRules)
		most = maxi(1, most + int(Dictionary(m.get("bonus", {})).get("res_max", 0)))
	var have := most if int(m.get("res", -1)) < 0 else clampi(int(m.res), 0, most)
	return {"kind": kind if most > 0 else "", "res": have, "res_max": most}


## Put every piece's mana and charges back to full.
func refill_resources() -> void:
	if run == null:
		return
	for m in run.members:
		m.erase("res")
		m.erase("res_tick")


var _trickle := 0.0


## `amount` of walking (tiles on a map, seconds on the overworld): one mana or charge back to each piece that is short
## for every `per` of it. `key` names the levels.csv row for `per`.
func trickle(amount: float, key: String) -> bool:
	if run == null or not run.adventure:
		return false
	_trickle += amount / maxf(1.0, float(Db.levels.get(key, 10)))
	var gave := false
	while _trickle >= 1.0:
		_trickle -= 1.0
		for m in run.members:
			var r := member_res(m)
			if r.kind != "" and int(r.res) < int(r.res_max):
				m.res = int(r.res) + 1
				gave = true
	return gave


## A tonic: some mana or a charge back to every piece that is short. True when it did anything.
func tonic_effect() -> bool:
	var did := false
	for m in run.members:
		var r := member_res(m)
		if r.kind == "":
			continue
		var gain := int(Db.levels.get("tonic_mana" if r.kind == "mana" else "tonic_charges", 1))
		if int(r.res) < int(r.res_max):
			m.res = mini(int(r.res_max), int(r.res) + gain)
			did = true
	return did


## A camp rest, free ([USER] 2026-10-31: no hunger; "camping for the night and resting would regain some morale"):
## everyone's mana and charges are back, camp_hp_pct of max HP, and the camp morale. False with no run.
func camp_rest() -> bool:
	if run == null:
		return false
	refill_resources()
	for m in run.members:
		if int(m.hp) > 0:
			m.hp = mini(run.max_hp(m), int(m.hp) + int(ceil(run.max_hp(m) * float(Db.levels.get("camp_hp_pct", 50)) / 100.0)))
		var gain := int(Db.morale.get("camp", 10))
		if (m.def as CharacterDef).deficiency == &"gloomy":
			gain += int(Db.morale.get("gloomy_camp", -2))
		MoraleRules.change(meta.morale, String((m.def as CharacterDef).id), gain, Db.morale)
	refresh_party()
	return true


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
			if (m.def as CharacterDef).saddlebag != Vector2i.ZERO and run.courier_bag != null:  # the saddlebag leaves with him
				var bag: InventoryGrid = run.courier_bag
				run.courier_bag = null
				for it in bag.items:
					run.add_item(String(it.id), int(it.get("n", 1)))
			run.members.erase(m)
	_seed_hearts()
	for m in run.members:
		var id := String((m.def as CharacterDef).id)
		if id == "lead":
			m.def = hero_def()  # the class follows the weapon
		var before := run.max_hp(m)
		var s := level_state(id)
		m.bonus = LevelRules.merge(LevelRules.merge(LevelRules.merge(LevelRules.merge(LevelRules.bonus(s, Db.levels), weapon_mods(id)), meal_mods()), boon_mods()),
			morale_mods(id))
		m.ranks = rank_state(id).ranks
		m.learned = rank_state(id).learned
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
	level_ups = []
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
		var reached := LevelRules.gain(s, amount, Db.levels, odds, run.rng)
		for lv in reached:
			lines.append(Txt.f("UI_LEVEL_UP", [Txt.t(d.name_key), lv]))
		var up: PackedStringArray = []
		var stats := {}
		for k in LevelRules.STATS:
			var n := int(s.gains[k]) - int(before.get(k, 0))
			if n > 0:
				var gained := n * (int(Db.levels.get("growth_hp", 2)) if k == "hp" else 1)
				stats[k] = gained
				up.append("%s +%d" % [Txt.t("UI_STAT_" + k.to_upper()), gained])
		if not reached.is_empty():
			level_ups.append({"id": id, "levels": reached, "stats": stats})
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


## The level-ups the last XP award caused, for the level-up screen: [{"id", "levels": [int], "stats": {stat: gained}}].
var level_ups: Array = []


## The kit (archetype id) whose abilities a member's class carries, or "": the hero's job class, or the character's class.
func kit_of(id: String) -> String:
	var cls := ""
	if id == "lead":
		cls = String(Db.jobs[job_id()].class) if job_id() != "" and Db.jobs.has(job_id()) else ""
	else:
		for m in run.members:
			if String((m.def as CharacterDef).id) == id:
				cls = String((m.def as CharacterDef).class_def.id)
	for a in Db.archetypes:
		if String(a["class"]) == cls:
			return String(a.id)
	return ""


## Kit abilities (and traits) a member could learn now: the ones in its kit that work today and it does not have yet
## (its class's own, or already learned). `built`: false gives the ones whose effect is not built yet instead.
func learnable(id: String, built := true) -> Array[String]:
	var out: Array[String] = []
	var kit := kit_of(id)
	if kit == "" or run == null:
		return out
	var u: CombatUnit = null
	for m in run.members:
		if String((m.def as CharacterDef).id) == id:
			u = CombatUnit.from_member(m)
	if u == null:
		return out
	for r in Db.kits:
		if r.archetype != kit or r.alt != "0" or (r.built == "1") != built:
			continue
		var aid := String(r.ability)
		if r.source == "ability":
			var known := u.abilities.any(func(a: Ability) -> bool: return a.id == aid)
			if (Db.ability(aid) != null or not built) and not known and not out.has(aid):
				out.append(aid)
		elif r.source == "trait":
			if not u.traits.has(StringName(aid)) and not out.has(aid):
				out.append(aid)
	return out


## Spend a waiting pick on learning a kit ability ([USER] 2026-10-31). The hero's picks belong to his job.
func learn_skill(id: String, ability_id: String) -> bool:
	if not learnable(id).has(ability_id):  # only what works today can be picked
		return false
	var s := level_state(id)
	var job := job_id() if id == "lead" else ""
	var target: Dictionary = s.jobs.get(job, LevelRules.fresh_job()) if job != "" else s
	if not LevelRules.learn(target, ability_id):
		return false
	if job != "":
		s.jobs[job] = target
	meta.levels[id] = s
	refresh_party()
	save_adventure()
	return true


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
	var res := {}
	for m in run.members:
		if int(m.get("res", -1)) >= 0:
			res[String((m.def as CharacterDef).id)] = [int(m.res), int(m.get("res_tick", 0))]
	meta.pack = {"grid": run.pack.to_save(), "belts": run.belts_save(), "waiting": run.waiting_save(), "gold": run.gold, "hp": hp, "res": res,
		"meal": run.meal.duplicate(), "boons": run.boons.duplicate()}
	save_meta()


## The pack can't feed the party at camp: the journey is over ([USER] 2026-11-01 "no food= journeys over"). As in a fall
## the party is carried home, nobody hurt and the loot kept, but everyone loses morale (morale.csv no_food) and it is
## not counted as a death.
func larder_empty() -> void:
	for m in run.members:
		MoraleRules.change(meta.morale, String((m.def as CharacterDef).id), int(Db.morale.get("no_food", -10)), Db.morale)
	wake_in_town(false, "UI_LARDER_EMPTY")


## Wake in the village square, everyone at full HP ([USER] 2026-10-28: a wipe costs nothing; the
## Lodestone's GO HOME lands the same way). The first wake-up is when the hero learns what the stone does.
## line: the wake-up line's text key when it is neither a fall nor GO HOME (an empty larder).
func wake_in_town(fell: bool, line := "") -> void:
	ensure_run()
	home_again(true)
	for m in run.members:
		m.hp = run.max_hp(m)
	refill_resources()  # a wake-up in the village refills everything
	if fell:
		meta.runs = int(meta.runs) + 1
		pending_lines = [Txt.t("UI_WAKE_FIRST") if set_flag("lodestone_revealed") else Txt.t("UI_WAKE")]
	else:
		pending_lines = [Txt.t(line if line != "" else "UI_WENT_HOME")]
	if not homecoming.is_empty():
		homecoming.fell = fell
		homecoming.headline = "\n".join(pending_lines)  # the page carries the wake-up line
		pending_lines = []
	travel = {"at": "town"}
	explore_memory = {}
	explore_map = "village"
	explore_entry = SQUARE
	combat_return = ""
	save_adventure()
	go(EXPLORE)


## The party is home (woken in the square, or walked into the village): whoever was sent home rejoins
## and unpacks, then the materials go to the village's count (meta.materials). wake: a fall or GO HOME. A return
## closes the trip's ledger into the homecoming page ([USER] Pitch J); a walk in through the gate shows it only when
## the trip brought something.
func home_again(wake := false) -> void:
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
	var ledger: Dictionary = meta.get("ledger", {})
	var page := not ledger.is_empty() and HomecomingRules.closes(ledger, wake)
	for r: Dictionary in finished:
		var out := TrailRules.apply_effects(run, String(r.get("gives", "")))
		absorb(out.unlocks)
		if not page:
			pending_lines.append(Txt.f("UI_RESTORE_DONE_LINE", [Txt.t("BUILDING_" + String(r.building).to_upper()), Txt.t(String(r.name_key))]))
		meta.tracked.erase(String(r.id))
	if page:
		var s := HomecomingRules.summary(ledger, meta, banked, finished, wake, Db.levels)
		homecoming = s if wake or not HomecomingRules.empty(s) else {}
		meta.ledger = HomecomingRules.snapshot(meta, false)  # a fresh count, for a fall in the village itself
		save_meta()
	if back or not banked.is_empty() or not finished.is_empty():
		save_adventure()  # saves meta too
		if not run.adventure:
			save_meta()


# --- morale, per character ([USER] 2026-10-31 design-goodboy, design-morale; MoraleRules, docs/systems/morale.md) ----

var _day_clock := {}  ## the part of a journey day walked on explore maps so far (MoraleRules.days_in)


## The run's hearts are meta.morale itself, so every change is kept for good.
func _link_hearts() -> void:
	if not meta.get("morale") is Dictionary:
		meta["morale"] = {}
	if run != null and run.adventure:
		run.hearts = meta.morale


## Everyone met has a morale from the start, so the homecoming page sees their first change.
func _seed_hearts() -> void:
	if run == null or not run.adventure:
		return
	_link_hearts()
	var ids: Array[String] = ["lead"]
	for d in companions():
		ids.append(String(d.id))
	for id in ids:
		if not meta.morale.has(id):
			meta.morale[id] = int(Db.morale.get("start", 70))


func morale_of(id: String) -> int:
	return MoraleRules.of(meta.get("morale", {}), id, Db.morale)


## The band a character's morale sits in: its row of data/morale_bands.csv (band, name_key, the mods).
func morale_band(id: String) -> Dictionary:
	return MoraleRules.band(morale_of(id), Db.morale_bands)


## What a character's morale band does in a fight, in CombatUnit mod keys. Only on adventure runs.
func morale_mods(id: String) -> Dictionary:
	if run == null or not run.adventure:
		return {}
	return MoraleRules.fight_mods(morale_of(id), Db.morale_bands)


func _dog_along() -> bool:
	return run != null and run.members.any(func(m: Dictionary) -> bool: return String((m.def as CharacterDef).id) == "dog")


## A fight is over: falls cost morale, a fall nobody picked up costs more, a wipe more again; a win lifts whoever
## stayed up. outcome: "won", "lost" or "escaped"; big: an elite or boss fight. Returns the lines for the summary.
func fight_morale(units: Array, outcome: String, big: bool) -> PackedStringArray:
	var lines: PackedStringArray = []
	if run == null or not run.adventure:
		return lines
	var pieces := []
	for u: CombatUnit in units:
		if u.team == 0 and not u.member.is_empty():
			pieces.append({"id": String((u.member.def as CharacterDef).id), "downs": u.downs, "out": u.hp <= 0 and not u.downed()})
	var change := MoraleRules.after_fight(pieces, outcome, big, Db.morale)
	var dog := _dog_along()
	for id: String in change:
		var d := MoraleRules.change(meta.morale, id, int(change[id]), Db.morale, dog)
		if d != 0:
			lines.append(Txt.f("UI_MORALE_CHANGE", [Txt.t(Db.character(StringName(id)).name_key), "+%d" % d if d > 0 else str(d)]))
	refresh_party()
	return lines


## Journey days gone by ([USER] design-morale: "for every day gone, a character at home gets X morale"). The road
## counts one every TravelRules.DAY_SECONDS walked (each meal), explore maps away from the village one every
## `day_steps` tiles. Everyone met who isn't with the party (left home, or the courier sent home) gains `home_day`.
func pass_days(n: int) -> void:
	if n <= 0 or run == null or not run.adventure:
		return
	meta.days = int(meta.get("days", 0)) + n
	var home: Array[String] = []
	for d in companions():
		var id := String(d.id)
		if not run.members.any(func(m: Dictionary) -> bool: return String((m.def as CharacterDef).id) == id):
			home.append(id)
	MoraleRules.home_days(meta.morale, home, n, Db.morale)


## Tiles walked on an explore map out of town: a journey day every `day_steps`.
func walk_days(steps: float) -> void:
	pass_days(MoraleRules.days_in(_day_clock, steps, float(Db.morale.get("day_steps", 150))))


## A night in the hero's bed at home: everyone met gains `bed` morale, the party is healed. Once a trip.
## False when the bed was already slept in since the party last went out.
func sleep_at_home() -> bool:
	if run == null or used_this_trip("home/bed"):
		return false
	use_for_trip("home/bed")
	_seed_hearts()
	for id: String in meta.morale.keys():
		if id == "lead" or companions().any(func(d: CharacterDef) -> bool: return String(d.id) == id):
			MoraleRules.change(meta.morale, id, int(Db.morale.get("bed", 20)), Db.morale)
	for m in run.members:
		m.hp = run.max_hp(m)
	refill_resources()
	refresh_party()
	save_adventure()
	return true


# --- restoring the village ([USER] omr-2, omr-5, omr-12; one-more-run step 2) --------------------------

signal counts(text: String)  ## a pickup counts toward a tracked step: screens show the line


## A fish landed in the fishing minigame: its reward into the pack, and its kind marked caught (the first
## of each kind is new, for the Lodestone's knowledge page later). Returns {"items": id -> n, "new": bool}.
func land_fish(row: Dictionary) -> Dictionary:
	var got := FishingRules.land(run, row)
	var first := set_flag("caught_fish_" + String(row.get("id", "")))
	save_adventure()
	return {"items": got, "new": first}


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
	meta.ledger = HomecomingRules.snapshot(meta, true)  # the homecoming page counts the trip from here
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


## Eat a carried meal at camp: everyone gets its buff for the next few fights (meal_fights), heals the recipe's heal
## and gains its morale ([USER] 2026-10-31: "good food you make or buy would do both morale and health").
func eat_meal(meal_item: String) -> bool:
	var r := recipe_of(meal_item)
	if r.is_empty() or run.item_count(meal_item) <= 0:
		return false
	run.add_item(meal_item, -1)
	run.meal = {"recipe": String(r.id), "fights": int(Db.levels.get("meal_fights", 2))}
	run.note(Txt.f("LOG_MEAL", Txt.t(String(r.name_key))))
	for m in run.members:  # good food heals and lifts everyone's morale (the recipe's heal and morale columns)
		if int(m.hp) > 0:
			run.heal_member(m, int(r.get("heal", 0)))
		MoraleRules.change(meta.morale, String((m.def as CharacterDef).id), int(r.get("morale", 0)), Db.morale)
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

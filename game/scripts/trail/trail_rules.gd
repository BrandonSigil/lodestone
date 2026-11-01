class_name TrailRules
extends RefCounted
## Trail and survival rules. Pure functions over a RunState so tests run headless.
## Numbers are [AI] proposals; see docs/decisions.md.

const PACE_STEADY := 10
const PACE_HARD := 15
const EVENT_CHANCE := 0.35
const HUNT_DC := 12
const FORAGE_DC := 11
const RODENT_CHANCE := 0.2


## Best living member's skill for this check, plus morale: the group's on the shelved trail, on an adventure run
## each member's own (their skill plus their morale band's check mod, MoraleRules).
static func party_bonus(run: RunState, check_id: String) -> int:
	var best := -99
	for m in run.alive():
		best = maxi(best, (m.def as CharacterDef).skill(check_id) + member_morale_mod(run, m))
	if best == -99:
		best = 0
	return best + (0 if run.adventure else morale_mod(run))


## One member's morale band on a d20 check (adventure runs; 0 on the shelved trail).
static func member_morale_mod(run: RunState, m: Dictionary) -> int:
	if not run.adventure:
		return 0
	return MoraleRules.check_mod(MoraleRules.of(run.hearts, String((m.def as CharacterDef).id), Db.morale), Db.morale_bands)


## An event's morale on an adventure run: every party member's own, softened while Doggo is along.
static func party_morale(run: RunState, n: int) -> void:
	var dog := run.members.any(func(m: Dictionary) -> bool: return String((m.def as CharacterDef).id) == "dog")
	for m in run.members:
		MoraleRules.change(run.hearts, String((m.def as CharacterDef).id), n, Db.morale, dog)


static func morale_mod(run: RunState) -> int:
	if run.morale < 30:
		return -2
	if run.morale > 75:
		return 1
	return 0


static func roll(run: RunState, check_id: String, dc: int) -> Dictionary:
	var r := Dice.check(run.rng, party_bonus(run, check_id), dc)
	r["check"] = check_id
	var verdict := Txt.t("LOG_WIN") if r.success else Txt.t("LOG_LOSE")
	run.note(Txt.f("LOG_CHECK", [Txt.t("CHECK_" + check_id.to_upper()), "%s  %s" % [Dice.describe(r), verdict]]))
	return r


## Upkeep at the end of every day: eat, bush rations, gloom.
static func end_day(run: RunState) -> void:
	for m in run.alive():
		var d: CharacterDef = m.def
		if d.has_perk(&"bushberry_ration"):
			run.add_food(1)
			run.note(Txt.f("LOG_BUSH_FOOD", 1))
		if d.deficiency == &"gloomy":
			run.morale -= 2
			run.note(Txt.f("LOG_GLOOMY", 2))
	var need := run.food_need()
	if run.food >= need:
		run.food -= need
		run.note(Txt.f("LOG_ATE", need))
	else:
		run.food = 0
		run.morale -= 10
		run.note(Txt.t("LOG_STARVE"))
		for m in run.alive():
			run.hurt(m, 2)
	run.morale = clampi(run.morale, 0, 100)
	run.day += 1
	run.note(Txt.f("LOG_DAY", run.day))


static func travel(run: RunState, hard: bool) -> void:
	var pace := PACE_HARD if hard else PACE_STEADY
	var dc := 8 + int(round(8.0 * run.strangeness()))
	var r := roll(run, "wayfind", dc)
	if not r.success:
		pace = pace / 2
		run.note(Txt.f("LOG_LOST", pace))
	else:
		run.note(Txt.f("LOG_WALKED", pace))
	run.distance = mini(run.distance + pace, RunState.GOAL)
	if hard:
		run.morale -= 5
		run.note(Txt.t("LOG_HARD"))
		for m in run.alive():
			run.hurt(m, 1)
	_check_wall(run)
	end_day(run)


static func rest(run: RunState) -> void:
	for m in run.alive():
		run.heal_member(m, 2)
	run.morale = mini(run.morale + 5, 100)
	run.note(Txt.t("LOG_REST"))
	end_day(run)


static func hunt(run: RunState) -> void:
	var dc := HUNT_DC + int(round(4.0 * run.strangeness()))
	var leader: Variant = best_member(run, "hunt")
	if leader != null and (leader.def as CharacterDef).deficiency == &"fear_rodents" and run.rng.randf() < RODENT_CHANCE:
		run.note(Txt.t("LOG_RODENT"))
	else:
		var r := roll(run, "hunt", dc)
		if r.success:
			var gain := 6 + (int(r.total) - dc)
			run.add_food(gain)
			run.note(Txt.f("LOG_HUNT_WIN", gain))
		else:
			run.note(Txt.t("LOG_HUNT_LOSE"))
	end_day(run)


static func forage(run: RunState) -> void:
	var r := roll(run, "forage", FORAGE_DC)
	if r.success:
		var gain := 1 + (1 if int(r.total) >= FORAGE_DC + 4 else 0) + (1 if r.crit else 0)
		run.add_medicine(gain)
		run.note(Txt.f("LOG_FORAGE_WIN", gain))
	else:
		run.note(Txt.t("LOG_FORAGE_LOSE"))
	end_day(run)


## What one potion heals: 5, plus the party's healing bonus.
static func potion_heal(run: RunState) -> int:
	return 5 + party_bonus(run, "heal")


## Spend one medicine on `who` (the player's pick), or the most hurt living member. Doesn't cost a day.
static func heal(run: RunState, who: Dictionary = {}) -> void:
	if run.medicine <= 0:
		run.note(Txt.t("LOG_NO_MEDICINE"))
		return
	var worst: Dictionary = who
	if worst.is_empty():  # nobody picked: the most hurt
		for m in run.alive():
			if worst.is_empty() or run.max_hp(m) - m.hp > run.max_hp(worst) - worst.hp:
				worst = m
	if worst.is_empty():
		return
	var amount := potion_heal(run)
	run.medicine -= 1
	run.heal_member(worst, amount)
	run.note(Txt.f("LOG_HEAL", amount))


static func best_member(run: RunState, check_id: String) -> Variant:
	var best: Variant = null
	for m in run.alive():
		if best == null or (m.def as CharacterDef).skill(check_id) + member_morale_mod(run, m) \
				> (best.def as CharacterDef).skill(check_id) + member_morale_mod(run, best):
			best = m
	return best


static func _check_wall(run: RunState) -> void:
	if not run.passed_wall and run.distance >= RunState.WALL:
		run.passed_wall = true
		run.note(Txt.t("LOG_WALL"))


## Returns an event dictionary, or {} for a quiet day.
static func roll_event(run: RunState, events: Array[Dictionary], flags: Array) -> Dictionary:
	if run.rng.randf() >= EVENT_CHANCE:
		return {}
	return pick_event(run, events, flags)


static func pick_event(run: RunState, events: Array[Dictionary], flags: Array) -> Dictionary:
	var s := run.strangeness()
	var pool: Array[Dictionary] = []
	var total := 0.0
	for ev in events:
		if s < ev.min_s or s > ev.max_s:
			continue
		if ev.once_flag != "" and flags.has(ev.once_flag):
			continue
		pool.append(ev)
		total += ev.weight
	if pool.is_empty():
		return {}
	var pick := run.rng.randf() * total
	for ev in pool:
		pick -= ev.weight
		if pick <= 0.0:
			return ev
	return pool.back()


## Resolve one event option. Returns {"check": Dictionary or {}, "success": bool, "combat": String, "unlocks": Array}.
static func resolve_option(run: RunState, opt: Dictionary) -> Dictionary:
	var check := {}
	var success := true
	if opt.check != "none" and opt.check != "fight":
		check = roll(run, opt.check, opt.dc)
		success = check.success
	var fx := apply_effects(run, opt.win if success else opt.lose)
	fx["check"] = check
	fx["success"] = success
	return fx


## Effects are "key:+n;key:-n" strings from events.csv and encounters.csv.
## "food:+4;gold:+10;unlock:x" as the player reads it: each thing got by name and count, and the coins. Flags, map
## effects and the rest say nothing here (their own lines do, when they have one).
static func gains_text(effects: String) -> String:
	var parts: PackedStringArray = []
	for part in effects.split(";", false):
		var kv := part.split(":")
		if kv.size() != 2:
			continue
		var id := kv[0].strip_edges()
		var n := int(kv[1])
		match id:
			"food": id = RunState.FOOD_ITEM
			"medicine": id = RunState.MED_ITEM
			"gold":
				if n != 0:
					parts.append(Txt.f("UI_GOLD", n))
				continue
			"hp_all", "hp_one":
				parts.append("%s %+d" % [Txt.t("UI_STAT_HP"), n])
				continue
			"morale":
				parts.append(Txt.f("UI_MORALE_ALL", "%+d" % n))
				continue
		if Db.items.has(id) and n != 0:
			parts.append("%s %s%d" % [Txt.t(String(Db.items[id].name_key)), "+" if n > 0 else "", n])
	return "  ".join(parts)


static func apply_effects(run: RunState, effects: String) -> Dictionary:
	var out := {"combat": "", "unlocks": [], "weapon": "", "invite": "", "dismiss": "", "blessings": 0, "setbacks": 0, "morale": 0, "sleep": false,
		"rescue": ""}
	for part in effects.split(";", false):
		var kv := part.split(":")
		if kv.size() != 2:
			push_warning("bad effect '%s'" % part)
			continue
		var key := kv[0].strip_edges()
		var val := kv[1].strip_edges()
		var n := int(val)
		match key:
			"food": run.add_food(n)
			"medicine": run.add_medicine(n)
			"gold": run.gold = maxi(0, run.gold + n)
			"morale":
				if run.adventure:
					party_morale(run, n)
					out.morale = int(out.morale) + n
				else:
					run.morale = clampi(run.morale + n, 0, 100)
			"sleep": out.sleep = true  # a night in the bed at home (Game.sleep_at_home)
			"dist":
				run.distance = clampi(run.distance + n, 0, RunState.GOAL)
				_check_wall(run)
			"day":
				for i in n:
					end_day(run)
			"hp_all":
				for m in run.alive():
					if n < 0: run.hurt(m, -n)
					else: run.heal_member(m, n)
			"hp_one":
				var living := run.alive()
				if not living.is_empty():
					var m: Dictionary = living[run.rng.randi_range(0, living.size() - 1)]
					if n < 0: run.hurt(m, -n)
					else: run.heal_member(m, n)
			"combat": out.combat = val
			"weapon": out.weapon = val  # weapon:bow: the hero takes it, and with it its job (Game.take_weapon)
			"blessing": out.blessings += 1  # blessing:any / setback:any: one drawn at random (Game.absorb_boons)
			"setback": out.setbacks += 1
			"invite": out.invite = val  # invite:dog / dismiss:dog: a companion's home in the village (Game.invite)
			"dismiss": out.dismiss = val
			"unlock": out.unlocks.append(val)
			"rescue":  # rescue:bushberry, on a captor group's loot ([USER] 2026-11-01 design-bb-recruit): met and freed (Game.rescued)
				out.unlocks.append("found_" + val)
				out.unlocks.append("rescued_" + val)
				out.rescue = val
			_:
				if Db.items.has(key):
					run.add_item(key, n)  # rope:+1, stuff:+3: any carried thing in data/items.csv
				else:
					push_warning("unknown effect '%s'" % key)
	return out

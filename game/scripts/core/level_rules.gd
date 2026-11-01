class_name LevelRules
extends RefCounted
## Levels, rolled stat gains and skill ranks ([USER] 2026-10-29, player-choice build step 1). Pure functions over
## a level state so tests run headless. Levels come on their own from XP. Each level rolls every stat against the
## character's growth odds (data/growth.csv, Fire Emblem style: a tank mostly gains HP or armor, never a stat it
## can't use). Every few levels a skill rank to spend in the Lodestone menu; each rank adds an effect from
## data/skill_ranks.csv. Skills also grow on their own as the stats grow. Numbers live in data/levels.csv.
##
## A level state is {"level": int, "xp": int, "gains": {stat: n}, "ranks": {skill id: n}, "pending": int,
## "jobs": {job id: job state}}. The hero's skills come from his job ([USER] pc-9, pc-12, step 2), so his ranks
## live in a job state {"level", "xp", "ranks", "pending", "branch"} per job, levelled by the same XP; his
## character level and rolled gains are shared by every job.

const STATS := ["hp", "damage", "armor", "magic", "crit"]


static func fresh() -> Dictionary:
	return {"level": 1, "xp": 0, "gains": {"hp": 0, "damage": 0, "armor": 0, "magic": 0, "crit": 0}, "ranks": {}, "pending": 0,
		"jobs": {}, "found": {}, "learned": []}


## A job's own level, ranks and branch, from scratch: a new job starts at 0 ([USER] pc-12).
static func fresh_job() -> Dictionary:
	return {"level": 1, "xp": 0, "ranks": {}, "pending": 0, "branch": "", "learned": []}


## Old or partial saves get the missing keys. A save from before rolled growth keeps what its levels and
## picks gave (+1 HP a level, MORE HEALTH 3 HP, MORE HIT 1 damage, MORE MAGIC 2 magic).
static func normalize(s: Variant) -> Dictionary:
	var out := fresh()
	if not s is Dictionary:
		return out
	out.level = int(s.get("level", 1))
	out.xp = int(s.get("xp", 0))
	out.pending = int(s.get("pending", 0))
	var gains: Dictionary = s.get("gains", {})
	for k in STATS:
		out.gains[k] = int(gains.get(k, 0))
	if not s.has("gains") and s.has("picks"):
		var picks: Dictionary = s.picks
		out.gains.hp = int(out.level) - 1 + int(picks.get("hp", 0)) * 3
		out.gains.damage = int(picks.get("attack", 0))
		out.gains.magic = int(picks.get("magic", 0)) * 2
	var ranks: Dictionary = s.get("ranks", {})
	for id in ranks:
		out.ranks[String(id)] = int(ranks[id])
	for id in s.get("learned", []):
		out.learned.append(String(id))
	var found: Dictionary = s.get("found", {})
	for k in found:
		out.found[String(k)] = int(found[k])
	var jobs: Dictionary = s.get("jobs", {})
	for id in jobs:
		var j: Dictionary = jobs[id]
		var js := fresh_job()
		js.level = int(j.get("level", 1))
		js.xp = int(j.get("xp", 0))
		js.pending = int(j.get("pending", 0))
		js.branch = String(j.get("branch", ""))
		for skill in j.get("learned", []):
			js.learned.append(String(skill))
		var jr: Dictionary = j.get("ranks", {})
		for k in jr:
			js.ranks[String(k)] = int(jr[k])
		out.jobs[String(id)] = js
	return out


## Can this job take its branch now: at branch_level and not yet branched ([USER] pc-13)?
static func branch_ready(job: Dictionary, cfg: Dictionary) -> bool:
	return String(job.get("branch", "")) == "" and int(job.get("level", 1)) >= int(cfg.get("branch_level", 10))


## Adds XP and returns the levels reached (empty when none). Each level rolls the stats from `odds` (a
## data/growth.csv row: stat -> % chance) with rng; every choice_every levels queues a skill rank.
static func gain(s: Dictionary, xp: int, cfg: Dictionary, odds: Dictionary = {}, rng: RandomNumberGenerator = null) -> Array[int]:
	var reached: Array[int] = []
	var per := maxi(1, int(cfg.get("xp_per_level", 100)))
	var cap := int(cfg.get("max_level", 40))
	var every := maxi(1, int(cfg.get("choice_every", 4)))
	s.xp = int(s.xp) + maxi(0, xp)
	while s.xp >= per and int(s.level) < cap:
		s.xp -= per
		s.level = int(s.level) + 1
		reached.append(s.level)
		if rng != null and not odds.is_empty():  # an odd level rolls the stats twice, an even one not at all (its pick instead)
			var rolls := int(cfg.get("rolls_odd", 1)) if int(s.level) % 2 == 1 else int(cfg.get("rolls_even", 1))
			for _i in rolls:
				roll(s, odds, rng)
		if s.level % every == 0:
			s.pending = int(s.pending) + 1
	if int(s.level) >= cap:
		s.xp = 0
	return reached


## One level's stat rolls. A level where every roll misses still gives one point to the likeliest stat.
## Returns the stats that went up.
static func roll(s: Dictionary, odds: Dictionary, rng: RandomNumberGenerator) -> Array[String]:
	var up: Array[String] = []
	var best := ""
	for k in STATS:
		var p := float(odds.get(k, 0))
		if p > 0.0 and (best == "" or p > float(odds.get(best, 0))):
			best = k
		if p > 0.0 and rng.randf() * 100.0 < p:
			up.append(k)
	if up.is_empty() and best != "":
		up.append(best)
	for k in up:
		s.gains[k] = int(s.gains.get(k, 0)) + 1
	return up


## Spend one queued rank on a skill, up to that skill's last rank in data. False when there's none to spend,
## or the skill is already at its top rank.
static func rank_up(s: Dictionary, skill: String, rows: Dictionary) -> bool:
	var have := int(s.ranks.get(skill, 0))
	var next := next_useful_rank(skill, have, rows)
	if int(s.pending) <= 0 or next == 0:
		return false
	s.pending = int(s.pending) - 1
	s.ranks[skill] = next  # skipping any step that is not wired yet
	return true


## Spend one queued pick on learning a kit ability (the caller checked it is learnable). False when none is waiting.
static func learn(s: Dictionary, ability_id: String) -> bool:
	if int(s.pending) <= 0 or (s.learned as Array).has(ability_id):
		return false
	s.pending = int(s.pending) - 1
	s.learned.append(ability_id)
	return true


## The number upgrades whose rule reads them (CombatRules.upg and friends): a step with only a `param` is offered once its
## key is here. Wire one, add it here.
const WIRED_PARAMS := ["guard_armor", "guard_hit", "taunt_armor", "command_bonus", "shield_wall_armor", "shield_wall_radius",
	"bloodied_damage", "bloodied_crit", "bloodied_threshold", "poison_damage", "poison_turns", "swap_move",
	"quick_damage", "quick_crit", "watch_damage", "watch_crit", "watch_stops", "ward_hits",
	"good_boy_heal", "good_boy_reach", "heart_burn_pct", "burn_damage",
	"companion_bonus", "rally_move", "rally_damage", "spook_damage", "inspire_damage"]


## Does step `i` (0-based) of a skill do something: an effect on the ability, or a param the rules read?
static func step_useful(skill: String, i: int, rows: Dictionary) -> bool:
	var effects: Array = rows.get(skill, [])
	if i < effects.size() and String(effects[i]) != "":
		return true
	var info: Array = Db.upgrade_steps.get(skill, [])
	return i < info.size() and String((info[i] as Dictionary).get("param", "")).split(":")[0] in WIRED_PARAMS


## The next rank of a skill that does something: a step nothing reads yet is skipped. 0 if none.
static func next_useful_rank(skill: String, have: int, rows: Dictionary) -> int:
	for i in range((rows.get(skill, []) as Array).size()):
		if i >= have and step_useful(skill, i, rows):
			return i + 1
	return 0


## How many ranks a skill has in data/ability_upgrades.csv (rows: Db.skill_ranks, skill id -> [effect per rank]).
static func max_rank(skill: String, rows: Dictionary) -> int:
	return (rows.get(skill, []) as Array).size()


## A copy of the ability with its first `rank` effects applied ("power:+1;status_turns:+1", "status:bleed").
static func ranked(a: Ability, rank: int, rows: Dictionary) -> Ability:
	var effects: Array = rows.get(a.id, [])
	if rank <= 0 or effects.is_empty():
		return a
	var out := a.copy()
	for i in mini(rank, effects.size()):
		for part in String(effects[i]).split(";", false):
			var kv := part.split(":")
			if kv.size() != 2:
				continue
			var key := kv[0].strip_edges()
			var val := kv[1].strip_edges()
			if not key in out:
				push_warning("unknown rank effect '%s' on %s" % [key, a.id])
				continue
			if out.get(key) is String:
				out.set(key, val)
			else:
				out.set(key, int(out.get(key)) + int(val))
	out.res_cost = maxi(0, out.res_cost)
	return out


## Stat changes from the rolled gains, in CombatUnit.apply_class mod keys. An attack bonus becomes crit
## chance there and a defense bonus armor, so crit and armor ride on those keys.
static func bonus(s: Dictionary, cfg: Dictionary) -> Dictionary:
	var g: Dictionary = s.get("gains", {})
	var f: Dictionary = s.get("found", {})  # stat items from the maps ([USER] omr-10), in their own units: +2 HP is 2
	return {
		"hp": int(g.get("hp", 0)) * int(cfg.get("growth_hp", 2)) + int(f.get("hp", 0)),
		"damage": int(g.get("damage", 0)) + int(f.get("damage", 0)),
		"defense": int(g.get("armor", 0)) + int(f.get("armor", 0)),
		"magic_power": int(g.get("magic", 0)) + int(f.get("magic", 0)),
		"attack": int(g.get("crit", 0)) + int(f.get("crit", 0)),
	}


## XP each member who fought gets for a won fight.
## A won fight: the win XP, XP for each foe downed, the boss bonus, and after an escape half the XP of the
## foes left standing ([USER] 2026-10-29, combat build step 6).
static func fight_xp(foes: int, boss: bool, cfg: Dictionary, escaped_from := 0) -> int:
	return int(cfg.get("xp_win", 10)) + foes * int(cfg.get("xp_foe", 25)) + (int(cfg.get("xp_boss", 100)) if boss else 0) \
		+ escaped_from * int(cfg.get("xp_foe", 25)) / 2


## Adds two mod dictionaries key by key.
static func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	for k in b:
		out[k] = int(out.get(k, 0)) + int(b[k])
	return out

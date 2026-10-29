class_name LevelRules
extends RefCounted
## Levels and the boosts picked at the Lodestone. Pure functions over a level state so tests run headless.
## [USER] 2026-10-28: levels come on their own from XP; every few levels the player picks one boost
## (more health, more attack power or more magic power) in the Lodestone menu.
## Numbers live in data/levels.csv (cfg = Db.levels).
##
## A level state is {"level": int, "xp": int, "picks": {"hp": n, "attack": n, "magic": n}, "pending": int}.

const PICKS := ["hp", "attack", "magic"]


static func fresh() -> Dictionary:
	return {"level": 1, "xp": 0, "picks": {"hp": 0, "attack": 0, "magic": 0}, "pending": 0}


## Old or partial saves get the missing keys.
static func normalize(s: Variant) -> Dictionary:
	var out := fresh()
	if s is Dictionary:
		out.level = int(s.get("level", 1))
		out.xp = int(s.get("xp", 0))
		out.pending = int(s.get("pending", 0))
		var picks: Dictionary = s.get("picks", {})
		for k in PICKS:
			out.picks[k] = int(picks.get(k, 0))
	return out


## Adds XP and returns the levels reached (empty when none). Each level that is a multiple of
## choice_every queues one pick for the Lodestone menu.
static func gain(s: Dictionary, xp: int, cfg: Dictionary) -> Array[int]:
	var reached: Array[int] = []
	var per := maxi(1, int(cfg.get("xp_per_level", 100)))
	var cap := int(cfg.get("max_level", 40))
	var every := maxi(1, int(cfg.get("choice_every", 4)))
	s.xp = int(s.xp) + maxi(0, xp)
	while s.xp >= per and int(s.level) < cap:
		s.xp -= per
		s.level = int(s.level) + 1
		reached.append(s.level)
		if s.level % every == 0:
			s.pending = int(s.pending) + 1
	if int(s.level) >= cap:
		s.xp = 0
	return reached


## Spend one queued pick. False when there is none or the pick is unknown.
static func choose(s: Dictionary, pick: String) -> bool:
	if int(s.pending) <= 0 or not PICKS.has(pick):
		return false
	s.pending = int(s.pending) - 1
	s.picks[pick] = int(s.picks.get(pick, 0)) + 1
	return true


## Stat changes from levels and picks, in CombatUnit.apply_class mod keys.
static func bonus(s: Dictionary, cfg: Dictionary) -> Dictionary:
	var picks: Dictionary = s.get("picks", {})
	var atk := int(picks.get("attack", 0)) * int(cfg.get("choice_attack", 1))
	return {
		"hp": (int(s.level) - 1) * int(cfg.get("hp_per_level", 1)) + int(picks.get("hp", 0)) * int(cfg.get("choice_hp", 3)),
		"attack": atk,
		"damage": atk,
		"magic_power": int(picks.get("magic", 0)) * int(cfg.get("choice_magic", 2)),
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

class_name MoraleRules
extends RefCounted
## Per-character morale ([USER] 2026-10-31 design-goodboy, built on design-morale; docs/systems/morale.md).
## Each character has their own morale, 0 to 100, kept for good in meta.morale (id -> value). Falls cost it, a fall
## nobody picks up costs more, and the lower it is the weaker the character fights (Banner Saga style). High morale
## (80 to 100) is a passive bonus, never spent ([USER] Pitch B). It comes back slowly: wins, camps, meals, a night in
## the bed at home, and days at home while the party is out ([USER] design-morale: "for every day gone, a character
## at home gets X morale").
##
## Pure: `hearts` is the id -> morale dictionary, `nums` the data/morale.csv numbers, `bands` the
## data/morale_bands.csv rows (highest first). Callers pass Db.morale and Db.morale_bands.


## A character's morale; one never seen before starts at `start`.
static func of(hearts: Dictionary, id: String, nums: Dictionary) -> int:
	return int(hearts.get(id, int(nums.get("start", 70))))


## The band row a morale value sits in (bands sorted highest `min` first).
static func band(value: int, bands: Array) -> Dictionary:
	for b: Dictionary in bands:
		if value >= int(b.min):
			return b
	return bands.back() if not bands.is_empty() else {}


## What a band changes in a fight, in CombatUnit mod keys (damage, move, defense = armor, res_max, attack = crit).
static func fight_mods(value: int, bands: Array) -> Dictionary:
	var b := band(value, bands)
	var out := {}
	for k in ["damage", "move", "defense", "res_max", "attack"]:
		var n := int(b.get(k, 0))
		if n != 0:
			out[k] = n
	return out


## What a band adds to a d20 check this character makes.
static func check_mod(value: int, bands: Array) -> int:
	return int(band(value, bands).get("check", 0))


## A loss after Doggo's Good Boy: `dog_soften_pct` smaller, rounded toward zero (-5 is -4, -10 is -8, -15 is -12).
## Gains are untouched.
static func softened(n: int, dog: bool, nums: Dictionary) -> int:
	if n >= 0 or not dog:
		return n
	return -int(floor(-n * (100.0 - float(nums.get("dog_soften_pct", 20))) / 100.0 + 0.0001))


## Change one character's morale by n (a loss softened when Doggo is along). Returns the change that stuck.
static func change(hearts: Dictionary, id: String, n: int, nums: Dictionary, dog := false) -> int:
	var was := of(hearts, id, nums)
	var now := clampi(was + softened(n, dog, nums), 0, int(nums.get("max", 100)))
	hearts[id] = now
	return now - was


## What one fight did to each party piece's morale. pieces: [{"id", "downs": times it went down, "out": it ended the
## fight down and never helped up}]. outcome: "won", "lost" or "escaped"; big: an elite or boss fight.
## Returns id -> change, before Doggo's softening (change() applies that).
static func after_fight(pieces: Array, outcome: String, big: bool, nums: Dictionary) -> Dictionary:
	var out := {}
	var wipe := outcome == "lost" and pieces.all(func(p: Dictionary) -> bool: return int(p.downs) > 0)
	for p: Dictionary in pieces:
		var n := 0
		if int(p.downs) > 0:
			n += int(nums.get("down", -5))
			if bool(p.out):
				n += int(nums.get("left_down", -10))
			if wipe:
				n += int(nums.get("wipe", -10))
		elif outcome == "won":
			n += int(nums.get("big_win" if big else "win", 2))
		if n != 0:
			out[String(p.id)] = n
	return out


## Journey days in `amount` of walking: whole days carried over in `clock` (a fraction of a day kept in clock.part).
## per: how much walking makes one day.
static func days_in(clock: Dictionary, amount: float, per: float) -> int:
	var part := float(clock.get("part", 0.0)) + amount / maxf(0.001, per)
	var days := int(floor(part))
	clock["part"] = part - days
	return days


## The days gone on a trip: each character at home gains `home_day` for every one. Returns id -> change.
static func home_days(hearts: Dictionary, home_ids: Array, days: int, nums: Dictionary) -> Dictionary:
	var out := {}
	if days <= 0:
		return out
	for id: String in home_ids:
		var d := change(hearts, id, days * int(nums.get("home_day", 3)), nums)
		if d != 0:
			out[id] = d
	return out


## A band's effects in plain rules text ("-1 damage, -1 move, -2 on d20 checks"), for the menus.
static func describe(b: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in ["damage", "move", "defense", "res_max"]:
		var n := int(b.get(k, 0))
		if n != 0:
			parts.append(Txt.f("MORALE_FX_" + k.to_upper(), "%+d" % n))
	if int(b.get("attack", 0)) != 0:
		parts.append(Txt.f("MORALE_FX_CRIT", "%+d" % (int(b.attack) * int(CombatRules.num("crit_per_attack")))))
	if int(b.get("check", 0)) != 0:
		parts.append(Txt.f("MORALE_FX_CHECK", "%+d" % int(b.check)))
	return ", ".join(parts) if not parts.is_empty() else Txt.t("MORALE_FX_NONE")

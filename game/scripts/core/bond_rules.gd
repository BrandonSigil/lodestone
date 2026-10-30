class_name BondRules
extends RefCounted
## Bonds between pairs in the party ([USER] 2026-10-30 design-village-life, game designer: the hero, companions and
## the dog). Points come from fights together; each level adds team-up damage for the pair and opens a talk at home.
## Pure: the numbers are data/bonds.csv (Db.bonds), the points live in Game.meta.bonds {pair key: points}.

const LEVELS := 3


## One key per pair, whichever way round: "dog+lead".
static func key(a: String, b: String) -> String:
	return "%s+%s" % [a, b] if a < b else "%s+%s" % [b, a]


static func level(points: int, cfg: Dictionary) -> int:
	var out := 0
	for n in range(1, LEVELS + 1):
		if points >= int(cfg.get("level_%d" % n, 9999)):
			out = n
	return out


## What one fight gives a pair: both standing at the end, a help-up and a team-up between them, capped.
static func fight_points(stood: bool, helped_up: bool, teamed: bool, cfg: Dictionary) -> int:
	var n := (int(cfg.get("fight", 1)) if stood else 0) + (int(cfg.get("help_up", 1)) if helped_up else 0) \
		+ (int(cfg.get("teamup", 1)) if teamed else 0)
	return mini(n, int(cfg.get("fight_max", 3)))


## Adds a fight's points to `bonds` for every pair of `ids` (the party pieces that fought). standing: ids still up at
## the end; deeds: pair key -> {"help_up": bool, "teamup": bool}. Returns [[pair key, new level], ...] for levels reached.
static func award(bonds: Dictionary, ids: Array, standing: Array, deeds: Dictionary, cfg: Dictionary) -> Array:
	var ups := []
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var k := key(String(ids[i]), String(ids[j]))
			var d: Dictionary = deeds.get(k, {})
			var n := fight_points(standing.has(ids[i]) and standing.has(ids[j]), bool(d.get("help_up", false)),
				bool(d.get("teamup", false)), cfg)
			if n <= 0:
				continue
			var before := level(int(bonds.get(k, 0)), cfg)
			bonds[k] = int(bonds.get(k, 0)) + n
			var after := level(int(bonds[k]), cfg)
			for lv in range(before + 1, after + 1):
				ups.append([k, lv])
	return ups


## The bond levels character `id` has with each other character: {other id: level}.
static func levels_for(id: String, bonds: Dictionary, cfg: Dictionary) -> Dictionary:
	var out := {}
	for k: String in bonds:
		var pair := k.split("+")
		if pair.size() == 2 and (pair[0] == id or pair[1] == id):
			var lv := level(int(bonds[k]), cfg)
			if lv > 0:
				out[pair[1] if pair[0] == id else pair[0]] = lv
	return out


## The text key of a pair's talk at a level: Brandon's line when he has written it, else the empty slot.
static func talk_key(k: String, lv: int) -> String:
	var own := "BOND_TALK_%s_%d" % [k.replace("+", "_").to_upper(), lv]
	return own if Txt.has(own) else "BOND_TALK_EMPTY"

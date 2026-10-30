class_name SheetRules
extends RefCounted
## What a character sheet shows ([USER] 2026-10-30, docs/decisions.md "Character sheets"), worked out from a
## CombatUnit so it always matches the fight: a Fire Emblem-style layout (CharacterSheet draws it). Pure, so
## tests read it without a screen. Hits always land in our fights, so the sheet shows damage, crit, armor and
## range where Fire Emblem shows Atk, Hit, Crit and Avo.

const MOVES := 4  ## move rows on the sheet


## The sheet for unit u. info: "name" (text key), "job" (text key, "" for none), "level", "xp", "xp_next",
## "weapon" (text key, "" for none), "weapon_id" (its row in data/weapons.csv), "portrait" (a character id
## for the portrait slot).
static func build(u: CombatUnit, info: Dictionary) -> Dictionary:
	var moves: Array = []
	for a: Ability in u.abilities:
		if moves.size() >= MOVES:
			break
		moves.append(move_row(u, a))
	var stats: Array = []
	var keys := u.skills.keys()
	keys.sort()
	for k in keys:
		stats.append({"key": "CHECK_" + String(k).to_upper(), "value": int(u.skills[k])})
	return {
		"name": String(info.get("name", u.name_key)), "job": String(info.get("job", "")),
		"level": int(info.get("level", 1)), "xp": int(info.get("xp", 0)), "xp_next": int(info.get("xp_next", 0)),
		"portrait": StringName(info.get("portrait", u.figure)), "weapon": String(info.get("weapon", "")),
		"hp": u.hp, "max_hp": u.max_hp, "move": u.move, "jump": u.jump,
		"damage": u.damage, "crit": int(CombatRules.num("crit_base")) + u.crit, "armor": u.armor,
		"range": Vector2i(u.range_min, u.range_max), "res_kind": u.res_kind, "res_max": u.res_max,
		"stats": stats, "moves": moves, "weapon_id": String(info.get("weapon_id", "")),
	}


## One move row: its name, its caveman line (DESC_<id>, in text/placeholder.csv), what it costs, its reach.
static func move_row(u: CombatUnit, a: Ability) -> Dictionary:
	var r := CombatRules.ability_range(u, a)
	return {"id": a.id, "name": a.name_key, "desc": "DESC_" + a.id.to_upper(), "cost": a.res_cost,
		"range": r, "power": (u.damage + a.power) if a.kind == "attack" else a.power, "kind": a.kind}

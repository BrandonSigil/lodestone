class_name ReadyRules
extends RefCounted
## The get-ready screen at the village gate ([USER] 2026-11-16, backlog P31, docs/design/ready-screen.md): what each
## character does in a fight (their roles), what the party covers, and the few warnings worth a word before the road.
## Few words on purpose ([USER] 2026-11-16: "We dont want to over-explain ... helping through some early game snags is
## good"). Pure; Game owns the town chest.

const ROLES := ["front", "ranged", "heal"]  ## the strip's order


## What a character does in a fight, from their class: "ranged" when it strikes from 3 tiles or more, "heal" when it
## knows a healing ability, else "front".
static func roles(d: CharacterDef) -> Array[String]:
	var out: Array[String] = []
	var c := d.class_def
	if c == null:
		return out
	out.append("ranged" if c.range_max >= 3 else "front")
	for id: StringName in c.abilities:
		var a: Ability = Db.abilities.get(String(id))
		if a != null and a.kind == "heal":
			out.append("heal")
			break
	return out


## Which roles the party covers: role -> how many members fill it.
static func cover(defs: Array) -> Dictionary:
	var out := {}
	for r in ROLES:
		out[r] = 0
	for d: CharacterDef in defs:
		for r in roles(d):
			out[r] = int(out[r]) + 1
	return out


## The warnings before the road, each {"key": text key, "arg": its number or "", "tab": the tab that fixes it}.
## days: days of food at a full ration; warn_days: fewer than this warns; spent: names of party members at 0 morale;
## overfull: the pack holds more than it can carry.
static func warnings(days: int, warn_days: int, spent: Array, overfull: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if days < warn_days:
		out.append({"key": "READY_WARN_FOOD", "arg": days, "tab": "supplies"})
	for n: String in spent:
		out.append({"key": "READY_WARN_SPENT", "arg": n, "tab": "party"})
	if overfull:
		out.append({"key": "READY_WARN_PACK", "arg": "", "tab": "pack"})
	return out


## Move one item between the town chest and the pack. to_pack: chest -> pack, else pack -> chest. Returns false when
## there is none to move. The caller checks the pack's room (RunState.overfull) and moves it back if it won't fit.
static func move(chest: Dictionary, run: RunState, id: String, to_pack: bool) -> bool:
	if to_pack:
		if int(chest.get(id, 0)) <= 0:
			return false
		chest[id] = int(chest[id]) - 1
		if int(chest[id]) <= 0:
			chest.erase(id)
		run.add_item(id, 1)
		return true
	if run.item_count(id) <= 0:
		return false
	run.add_item(id, -1)
	chest[id] = int(chest.get(id, 0)) + 1
	return true

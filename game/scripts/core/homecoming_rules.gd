class_name HomecomingRules
extends RefCounted
## The homecoming page ([USER] 2026-11-01 Pitch J, master-j-homecoming): after every return, a fall or GO HOME, one page
## shows what the trip gave: materials banked, XP and levels, bond points, morale changes, new knowledge and the restore
## steps just finished, then the next goal and how close the village is to it. On a fall it also shows the boss card
## the party just learned. Pure: Game keeps a ledger (a snapshot of meta taken when a trip starts) and hands it here.
##
## ledger: {"gate": opened at the village gate, "trip", "levels": id -> {"level", "xp"}, "bonds": key -> points,
##   "flags": [..], "morale": id -> value}.

## Flag prefixes that count as knowledge kept for good, in the order the page lists them.
## learned_: a boss's card (ExploreRules.learned_flag); got_: a lasting find; beaten_: a boss or elite down for good;
## passed_: a foe the party got past.
const KNOWLEDGE := ["learned_", "got_", "beaten_", "passed_"]


static func snapshot(meta: Dictionary, gate: bool) -> Dictionary:
	var levels := {}
	for id: String in Dictionary(meta.get("levels", {})):
		var s: Variant = meta.levels[id]
		if s is Dictionary:
			levels[id] = {"level": int(s.get("level", 1)), "xp": int(s.get("xp", 0))}
	return {"gate": gate, "trip": int(meta.get("trips", 0)), "levels": levels,
		"bonds": Dictionary(meta.get("bonds", {})).duplicate(), "flags": Array(meta.get("flags", [])).duplicate(),
		"morale": Dictionary(meta.get("morale", {})).duplicate()}


## Does coming home now close the ledger? A fall or GO HOME always does; walking in through the gate only after a
## trip that left through it (walking from the hero's cottage into the square is not a return).
static func closes(ledger: Dictionary, wake: bool) -> bool:
	return wake or bool(ledger.get("gate", false))


## What changed between `before` (the ledger) and `meta` now. banked: material id -> count put on the village pile;
## finished: the restore rows that just finished. cfg: data/levels.csv (xp_per_level).
static func summary(before: Dictionary, meta: Dictionary, banked: Dictionary, finished: Array, fell: bool, cfg: Dictionary) -> Dictionary:
	var per := maxi(1, int(cfg.get("xp_per_level", 100)))
	var levels := []
	var was_levels: Dictionary = before.get("levels", {})
	for id: String in Dictionary(meta.get("levels", {})):
		var s: Variant = meta.levels[id]
		if not s is Dictionary:
			continue
		var was: Dictionary = was_levels.get(id, {"level": 1, "xp": 0})
		var lv0 := int(was.get("level", 1))
		var lv1 := int(s.get("level", 1))
		var gained := (lv1 - lv0) * per + int(s.get("xp", 0)) - int(was.get("xp", 0))
		if gained > 0 or lv1 > lv0:
			levels.append({"id": id, "from": lv0, "to": lv1, "xp": gained, "xp_now": int(s.get("xp", 0)), "xp_per": per})
	levels.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _order(a.id) < _order(b.id))
	var bonds := []
	var was_bonds: Dictionary = before.get("bonds", {})
	for k: String in Dictionary(meta.get("bonds", {})):
		var p0 := int(was_bonds.get(k, 0))
		var p1 := int(meta.bonds[k])
		if p1 > p0:
			bonds.append({"key": k, "from": p0, "to": p1})
	bonds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.key) < String(b.key))
	var morale := []
	var was_morale: Dictionary = before.get("morale", {})
	for id: String in Dictionary(meta.get("morale", {})):
		var m1 := int(meta.morale[id])
		var m0 := int(was_morale.get(id, m1))
		if m1 != m0:
			morale.append({"id": id, "from": m0, "to": m1})
	morale.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _order(a.id) < _order(b.id))
	var had: Array = before.get("flags", [])
	var cards: Array[String] = []
	var knowledge := {}
	for f: String in Array(meta.get("flags", [])):
		if had.has(f):
			continue
		for pre: String in KNOWLEDGE:
			if f.begins_with(pre):
				if pre == "learned_":
					cards.append(f.trim_prefix(pre))
				else:
					knowledge[pre.trim_suffix("_")] = int(knowledge.get(pre.trim_suffix("_"), 0)) + 1
				break
	var restored: Array[String] = []
	for r: Dictionary in finished:
		restored.append(String(r.id))
	return {"fell": fell, "materials": banked.duplicate(), "levels": levels, "bonds": bonds, "morale": morale,
		"cards": cards, "knowledge": knowledge, "restored": restored}


## Nothing to show: no material, XP, bond, morale, knowledge or restore step changed.
static func empty(s: Dictionary) -> bool:
	for k in ["materials", "levels", "bonds", "morale", "cards", "knowledge", "restored"]:
		if not (s.get(k, []) as Variant).is_empty():
			return false
	return true


## The next goal the page closes on: the first tracked step not yet paid, else the next step of the first building
## whose settler has moved in. {"row", "parts": [{"id", "have", "need"}], "ready": every part covered}; {} when none.
static func next_goal(rows: Array, state: Dictionary, tracked: Array, have: Dictionary, flags: Array) -> Dictionary:
	var row := {}
	for r: Dictionary in rows:
		if tracked.has(String(r.id)) and RestoreRules.status(state, String(r.id)) == "":
			row = r
			break
	if row.is_empty():
		for b in RestoreRules.buildings(rows):
			if not RestoreRules.is_open(rows, b, flags):
				continue
			var nxt := RestoreRules.next_step(rows, b, state)
			if not nxt.is_empty() and RestoreRules.status(state, String(nxt.id)) == "":
				row = nxt
				break
	if row.is_empty():
		return {}
	var parts := []
	var ready := true
	var needs := RestoreRules.parse_needs(String(row.needs))
	for id: String in needs:
		var h := mini(int(have.get(id, 0)), int(needs[id]))
		parts.append({"id": id, "have": h, "need": int(needs[id])})
		ready = ready and h >= int(needs[id])
	return {"row": row, "parts": parts, "ready": ready}


## The hero first, then the dog, then everyone else by id.
static func _order(id: String) -> String:
	return {"lead": "0", "dog": "1"}.get(id, "2" + id)

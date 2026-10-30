class_name RestoreRules
extends RefCounted
## Restoring the village, step by step ([USER] omr-2, omr-3, omr-5, omr-12; one-more-run step 2). Pure rules.
## Each building has a ladder of steps in data/restore.csv. A ladder opens once its settler has moved in (the
## first step's settler flag). A step asks for exact items (needs "metal:3;wood:2;rare:1"), paid from the
## village pile (materials bank there on the way home). Paying starts it; it finishes the next time the party
## comes home from a trip, and then gives what it gives ("flag:forge_running"). Any steps can be tracked: their
## missing items show in the frame on a trip.
##
## state: step id -> {"state": "paid" | "done", "trip": the trip it was paid on}. trip: Game.meta.trips.


## "metal:3;wood:2" -> {"metal": 3, "wood": 2}
static func parse_needs(s: String) -> Dictionary:
	var out := {}
	for part in s.split(";", false):
		var kv := part.split(":")
		if kv.size() == 2:
			out[kv[0].strip_edges()] = int(kv[1])
	return out


## Building ids in the order the table first names them.
static func buildings(rows: Array) -> Array[String]:
	var out: Array[String] = []
	for r: Dictionary in rows:
		if not out.has(String(r.building)):
			out.append(String(r.building))
	return out


static func ladder(rows: Array, building: String) -> Array:
	var out := rows.filter(func(r: Dictionary) -> bool: return String(r.building) == building)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.step) < int(b.step))
	return out


## Has the building's settler moved in?
static func is_open(rows: Array, building: String, flags: Array) -> bool:
	var steps := ladder(rows, building)
	if steps.is_empty():
		return false
	var settler := String(steps[0].get("settler", ""))
	return settler == "" or flags.has(settler)


## The step that opens a building's ladder (the one whose gives sets its settler flag), or {} when a settler
## moving in opens it.
static func opened_by(rows: Array, building: String) -> Dictionary:
	var steps := ladder(rows, building)
	if steps.is_empty():
		return {}
	var flag := String(steps[0].get("settler", ""))
	for r: Dictionary in rows:
		if flag != "" and ("unlock:" + flag) in String(r.get("gives", "")).split(";", false):
			return r
	return {}


static func status(state: Dictionary, id: String) -> String:
	return String((state.get(id, {}) as Dictionary).get("state", ""))


## The step to work on: the first one not done (it may be paid and under way). {} when all are done.
static func next_step(rows: Array, building: String, state: Dictionary) -> Dictionary:
	for r: Dictionary in ladder(rows, building):
		if status(state, String(r.id)) != "done":
			return r
	return {}


## What's still missing for a step, given what the party has (the pile, and on a trip the pack too).
static func missing(row: Dictionary, have: Dictionary) -> Dictionary:
	var out := {}
	var needs := parse_needs(String(row.needs))
	for id in needs:
		var short := int(needs[id]) - int(have.get(id, 0))
		if short > 0:
			out[id] = short
	return out


static func can_pay(row: Dictionary, state: Dictionary, pile: Dictionary) -> bool:
	return status(state, String(row.id)) == "" and missing(row, pile).is_empty()


## Takes the step's items from the pile and starts it. False (nothing taken) if it can't be paid.
static func pay(row: Dictionary, state: Dictionary, pile: Dictionary, trip: int) -> bool:
	if not can_pay(row, state, pile):
		return false
	var needs := parse_needs(String(row.needs))
	for id in needs:
		pile[id] = int(pile.get(id, 0)) - int(needs[id])
		if int(pile[id]) <= 0:
			pile.erase(id)
	state[String(row.id)] = {"state": "paid", "trip": trip}
	return true


## How many of a building's steps are done (a weapon's upgrade level).
static func done_count(rows: Array, building: String, state: Dictionary) -> int:
	return ladder(rows, building).filter(func(r: Dictionary) -> bool: return status(state, String(r.id)) == "done").size()


## Coming home: every step paid on an earlier trip is done. Returns the rows that finished.
static func finish(rows: Array, state: Dictionary, trip: int) -> Array:
	var done := []
	for r: Dictionary in rows:
		var s: Dictionary = state.get(String(r.id), {})
		if String(s.get("state", "")) == "paid" and int(s.get("trip", 0)) < trip:
			s.state = "done"
			done.append(r)
	return done

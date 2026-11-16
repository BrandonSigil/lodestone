class_name CampRules
extends RefCounted
## The campfire ([USER] 2026-11-16, option A of docs/design/campfire-trail.md): each journey day ends at one fire.
## Everyone eats from one pot at the ration the dial is set to, and the evening has a few slots for actions (cook,
## fish, hunt, forage, talk, mend, rest), each once a night. Pure: numbers in data/camp.csv, camp_actions.csv and
## camp_rations.csv; Game applies morale, bonds and meals.

const FILLING := "filling"


## Evening actions a night.
static func slots(cfg: Dictionary) -> int:
	return maxi(1, int(cfg.get("slots", 3)))


## The ration row for an id (the fullest when the id is unknown).
static func ration(rows: Array, id: String) -> Dictionary:
	for r: Dictionary in rows:
		if String(r.id) == id:
			return r
	return rows[0] if not rows.is_empty() else {"id": FILLING, "share": 100, "morale": 0}


## Members who eat from the pot: alive, with a share, and not Cold Blooded (the Lich Prince eats nothing).
static func eaters(run: RunState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in run.alive():
		if TravelRules.eats_food(m) and int(TravelRules.shares(run).get(String((m.def as CharacterDef).id), 0)) > 0:
			out.append(m)
	return out


## Portions the pot takes tonight at this ration: the party's daily need times the ration's share, rounded up.
static func pot_need(run: RunState, r: Dictionary) -> int:
	return ceili(float(run.food_need()) * float(r.get("share", 100)) / 100.0)


## Days of food the pack holds at this ration (99 when the pot takes nothing or nobody eats).
static func food_days(run: RunState, r: Dictionary) -> int:
	var need := pot_need(run, r)
	return 99 if need <= 0 else run.portions() / need


## Food kinds in the order the pot uses them: the ones that heal most first, so the meat's heal isn't wasted.
static func pot_order(run: RunState) -> Array[String]:
	var out := run.larder()
	out.reverse()
	return out


## Fill the pot and serve it. The heal of the portions eaten is shared by everyone who eats; what the pack can't
## cover goes hungry, the companions before the hero. Returns {"took", "need", "missed": member id -> portions short}.
static func eat_pot(run: RunState, r: Dictionary) -> Dictionary:
	var need := pot_need(run, r)
	var took := 0
	var heal := 0.0
	for kind in pot_order(run):
		if took >= need:
			break
		var got := run.take_portions(kind, need - took)
		took += got
		heal += got * RunState.heal_per_portion(kind)
	var eat := eaters(run)
	var missed := {}
	if float(r.get("share", 100)) <= 0.0:  # BARE: the pot stays empty and everyone goes hungry, saving the food
		for m in eat:
			missed[String((m.def as CharacterDef).id)] = int(TravelRules.shares(run).get(String((m.def as CharacterDef).id), 0))
	elif took < need:
		var short := need - took
		var order := eat.duplicate()
		order.reverse()  # the hero eats last: companions go hungry first
		var share := TravelRules.shares(run)
		for m in order:
			if short <= 0:
				break
			var id := String((m.def as CharacterDef).id)
			var n := mini(short, int(share.get(id, 0)))
			missed[id] = n
			short -= n
	var fed := eat.filter(func(m: Dictionary) -> bool: return not missed.has(String((m.def as CharacterDef).id)) and int(m.hp) > 0)
	if roundi(heal) > 0 and not fed.is_empty():
		var each := roundi(heal) / fed.size()
		var extra := roundi(heal) % fed.size()
		for i in fed.size():
			run.heal_member(fed[i], each + (1 if i < extra else 0))
	run.meals_eaten += 1
	run.note(Txt.f("LOG_ATE", took) if missed.is_empty() else Txt.f("LOG_HUNGRY", [took, missed.size()]))
	return {"took": took, "need": need, "missed": missed}


## Can this action be taken tonight? done: the action ids already taken this night.
static func can_do(run: RunState, id: String, done: Array) -> bool:
	if done.has(id):
		return false
	match id:
		"fish":
			return TravelRules.can_try(run, "fish")
		"mend":
			return not most_hurt(run).is_empty()
		"talk":
			return run.alive().size() >= 2
	return true


## Why an action can't be taken tonight, as a text key ("" when it can).
static func why_not(run: RunState, id: String, done: Array) -> String:
	if done.has(id):
		return "CAMP_DONE"
	if not can_do(run, id, done):
		return {"fish": "CAMP_NEED_ROD", "mend": "CAMP_NOBODY_HURT", "talk": "CAMP_ALONE"}.get(id, "CAMP_DONE")
	return ""


## The member missing the most HP (alive), or {} when nobody is hurt.
static func most_hurt(run: RunState) -> Dictionary:
	var best := {}
	var gap := 0
	for m in run.alive():
		var g := run.max_hp(m) - int(m.hp)
		if g > gap:
			gap = g
			best = m
	return best


## Every pair of living members who could talk, the hero's pairs first: [[id a, id b], ...].
static func pairs(run: RunState) -> Array:
	var ids: Array[String] = []
	for m in run.alive():
		ids.append(String((m.def as CharacterDef).id))
	var out := []
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			out.append([ids[i], ids[j]])
	return out


## Last night's plan kept for SAME AS LAST NIGHT, trimmed to what can still be done without a minigame tonight:
## fishing becomes a quick cast, so nothing in a repeated plan opens a screen.
static func repeatable(run: RunState, plan: Array, n: int) -> Array:
	var out := []
	for id: String in plan:
		if out.size() >= n:
			break
		if can_do(run, id, out):
			out.append(id)
	return out

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


## Can this action be taken tonight? done: the action ids already taken this night. site: tonight's campsite row
## (data/campsites.csv), {} when the party camps wherever the day ends (option A: fishing anywhere).
static func can_do(run: RunState, id: String, done: Array, site: Dictionary = {}) -> bool:
	if done.has(id):
		return false
	match id:
		"fish":
			return TravelRules.can_try(run, "fish") and (site.is_empty() or int(site.get("fish", 0)) == 1)
		"mend":
			return not most_hurt(run).is_empty()
		"talk":
			return run.alive().size() >= 2
	return true


## Why an action can't be taken tonight, as a text key ("" when it can).
static func why_not(run: RunState, id: String, done: Array, site: Dictionary = {}) -> String:
	if done.has(id):
		return "CAMP_DONE"
	if id == "fish" and TravelRules.can_try(run, "fish") and not can_do(run, id, done, site):
		return "CAMP_NO_WATER"
	if not can_do(run, id, done, site):
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
static func repeatable(run: RunState, plan: Array, n: int, site: Dictionary = {}) -> Array:
	var out := []
	for id: String in plan:
		if out.size() >= n:
			break
		if can_do(run, id, out, site):
			out.append(id)
	return out


# --- campsites on the map ([USER] 2026-11-16: "A to C is great", option C of docs/design/campfire-trail.md) ----------

const SITES := "sites"  ## camp style: the party stops at campsites on the map (option C), the default
const NIGHTLY := "nightly"  ## camp style: every day ends at a fire wherever the party is (option A)
const DARK := "dark"  ## the rough camp when night falls before the party stops at a campsite
const ASK_AFTER := 0.4  ## share of the day walked since the last camp before a campsite asks; sooner, it is passed


## The camp style in the settings (Options: CAMPSITES or EVERY NIGHT), so both can be played and compared.
static func style(settings: Dictionary) -> String:
	return NIGHTLY if String(settings.get("camp_style", SITES)) == NIGHTLY else SITES


## The campsites on a leg walked from `from`, in walking order: [{"t": seconds from the leg's start, "id": kind}].
## Data: overworld_paths.csv `camps`, "0.3:meadow|0.5:river", each a share of the way from the row's `from`.
static func leg_sites(path: Dictionary, from: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seconds := float(path.get("seconds", 60))
	for part in String(path.get("camps", "")).split("|", false):
		var f := clampf(float(part.get_slice(":", 0)), 0.0, 1.0)
		if String(path.get("from", "")) != from:
			f = 1.0 - f
		out.append({"t": snappedf(f * seconds, 0.1), "id": part.get_slice(":", 1).strip_edges()})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))
	return out


## The first campsite at or after t on the leg not passed yet (index into sites), or -1.
static func next_site(sites: Array, t: float, passed: Array) -> int:
	for i in sites.size():
		if float(sites[i].t) >= t - 0.001 and not passed.has(int(i)) and not passed.has(float(i)):
			return i
	return -1


## Evening actions at this campsite: the usual number plus the site's bonus (the rough camp has one fewer), at least 1.
static func slots_at(cfg: Dictionary, site: Dictionary) -> int:
	return maxi(1, slots(cfg) + int(site.get("slots", 0)))


## Is a campsite worth asking about? Only once part of the day is walked; one reached right after a camp is passed.
static func ask_at(since: float) -> bool:
	return since >= ASK_AFTER * TravelRules.DAY_SECONDS


## Daylight left, 0 to 1, after `since` seconds walked since the last camp.
static func daylight(since: float) -> float:
	return clampf(1.0 - since / TravelRules.DAY_SECONDS, 0.0, 1.0)

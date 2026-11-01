class_name TravelRules
extends RefCounted
## Overworld travel ([USER] 2026-10-28): a leg between two places takes about a minute of real time, with
## a random encounter or two on the way. The party eats every day at camp and an empty larder ends the journey ([USER]
## 2026-11-01: "The party must eat every day at camp, no food= journeys over"); food eaten on purpose also heals (the
## item's heal column). Hunt, fish and forage are dice rolls (placeholders for minigames). Pure functions so tests run
## headless; the scene owns the clock.

const DAY_SECONDS := 30.0  ## one journey day per this many seconds walked: the night's camp, a meal, a day for morale
const ACT_COOLDOWN := 15.0  ## seconds walked before the same activity can be tried again
## Activity id -> {"check", "dc", "food", "medicine", "item"}: what a win gives (plus the margin for food), and
## the gear it needs in the pack, if any.
const ACTS := {
	"hunt": {"check": "hunt", "dc": 12, "food": 3, "medicine": 0},
	"fish": {"check": "fish", "dc": 11, "food": 2, "medicine": 0, "item": "rod"},  # [USER] 2026-10-30: fishing needs a rod
	"forage": {"check": "forage", "dc": 11, "food": 1, "medicine": 1},
}


## Encounter times for a leg: between enc_min and enc_max of them, spread over the middle of the walk,
## at least 8 seconds apart. Sorted.
static func plan(rng: RandomNumberGenerator, seconds: float, enc_min: int, enc_max: int) -> Array[float]:
	var n := rng.randi_range(enc_min, maxi(enc_min, enc_max))
	var out: Array[float] = []
	var tries := 0
	while out.size() < n and tries < 50:
		tries += 1
		var t := snappedf(rng.randf_range(0.2, 0.85) * seconds, 0.1)
		if out.all(func(o: float) -> bool: return absf(o - t) >= 8.0):
			out.append(t)
	out.sort()
	return out


## Fast forward: the next encounter after t, or the end of the leg.
static func next_stop(t: float, stops: Array, seconds: float) -> float:
	for s: float in stops:
		if s > t + 0.01:
			return minf(s, seconds)
	return seconds


## Journey days passed walking from t0 to t1.
static func days_between(t0: float, t1: float) -> int:
	return maxi(0, int(floor(t1 / DAY_SECONDS)) - int(floor(t0 / DAY_SECONDS)))


## The night's meal at camp: everyone's portions (RunState.food_need) from the larder, meat first, then the fish grades.
## The daily meal only feeds; it heals nobody. False, and nothing eaten, when the pack can't feed everyone: the journey
## is over (Game.larder_empty).
static func eat(run: RunState) -> bool:
	var need := run.food_need()
	if run.portions() < need:
		run.note(Txt.t("LOG_STARVE"))
		return false
	var left := need
	for id in run.larder():
		var per := int(Db.items[id].food)
		while left > 0 and run.item_count(id) > 0:
			run.add_item(id, -1)
			left -= per
	run.note(Txt.f("LOG_ATE", need))
	return true


## What one piece of this food heals when eaten on purpose (meat by default): its heal column, never below 1. Caught
## fish are food too, a bigger grade healing more (data/items.csv).
static func food_heal(_run: RunState, item := RunState.FOOD_ITEM) -> int:
	return maxi(1, int(Db.items.get(item, {}).get("heal", 0)))


## Food that heals when eaten: kind food with a heal value (meat, the fish grades). Shop food turns into meat at the gate.
static func is_food(item: String) -> bool:
	var row: Dictionary = Db.items.get(item, {})
	return String(row.get("kind", "")) == "food" and int(row.get("heal", 0)) > 0


## The living member missing the most HP, or {} when nobody is hurt.
static func most_hurt(run: RunState) -> Dictionary:
	var worst := {}
	for m in run.alive():
		if int(m.hp) < run.max_hp(m) and (worst.is_empty() or run.max_hp(m) - int(m.hp) > run.max_hp(worst) - int(worst.hp)):
			worst = m
	return worst


## EAT from the pack: one food heals member m a little ([USER] 2026-10-30: the player picks who; with no m,
## the most hurt, for callers that don't ask).
static func eat_one(run: RunState, m: Dictionary = {}, item := RunState.FOOD_ITEM) -> bool:
	if m.is_empty():
		m = most_hurt(run)
	if run.item_count(item) <= 0 or m.is_empty() or gain(run, item, m) <= 0:
		return false
	var heal := food_heal(run, item)
	run.add_item(item, -1)
	run.heal_member(m, heal)
	run.note(Txt.f("LOG_SNACK", [Txt.t((m.def as CharacterDef).name_key), heal]))
	return true


## The HP member m would gain from one of this food or potion now: 0 when full, down or it heals nothing.
static func gain(run: RunState, item: String, m: Dictionary) -> int:
	if int(m.hp) <= 0:
		return 0
	var amount := food_heal(run, item) if is_food(item) else (TrailRules.potion_heal(run) if item == RunState.MED_ITEM else 0)
	return mini(amount, run.max_hp(m) - int(m.hp))


## Use one food or potion on member m (EAT / DRINK, or a stack dropped on their card). False if it can't help.
static func use_on(run: RunState, item: String, m: Dictionary) -> bool:
	if gain(run, item, m) <= 0:
		return false
	if is_food(item):
		return eat_one(run, m, item)
	if item == RunState.MED_ITEM and run.medicine > 0:
		TrailRules.heal(run, m)
		return true
	return false


## Hunt, fish or forage: the party's best roll. Returns the roll with "food" and "medicine" gained.
## Has the party what the activity needs? Fishing takes a rod, on the world map and at any dock alike.
static func can_try(run: RunState, act: String) -> bool:
	var need := String(ACTS[act].get("item", ""))
	return need == "" or run.item_count(need) > 0


static func activity(run: RunState, act: String) -> Dictionary:
	var a: Dictionary = ACTS[act]
	if not can_try(run, act):
		return {"success": false, "food": 0, "medicine": 0, "total": 0}
	var r := TrailRules.roll(run, a.check, a.dc)
	r["food"] = 0
	r["medicine"] = 0
	if r.success:
		r.food = int(a.food) + (maxi(0, int(r.total) - int(a.dc)) / 2 if int(a.food) > 0 else 0)
		r.medicine = int(a.medicine)
		run.add_food(r.food)
		run.add_medicine(r.medicine)
	return r


## Can the activity be tried at t (seconds into the leg)? acts: activity id -> time it was last tried.
static func can_act(acts: Dictionary, act: String, t: float) -> bool:
	return not acts.has(act) or t - float(acts[act]) >= ACT_COOLDOWN


## Point a fraction f (0 to 1) of the way along a polyline, by length.
static func point_at(points: PackedVector2Array, f: float) -> Vector2:
	if points.size() < 2:
		return points[0] if points.size() == 1 else Vector2.ZERO
	var total := 0.0
	for i in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	var want := clampf(f, 0.0, 1.0) * total
	for i in points.size() - 1:
		var seg := points[i].distance_to(points[i + 1])
		if want <= seg or i == points.size() - 2:
			return points[i].lerp(points[i + 1], clampf(want / maxf(seg, 0.001), 0.0, 1.0))
		want -= seg
	return points[points.size() - 1]


## "x:y|x:y" -> points.
static func parse_points(text: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in text.split("|", false):
		var xy := p.split(":")
		out.append(Vector2(float(xy[0]), float(xy[1])))
	return out


# --- the hex world map ([USER] 2026-11-01, card pm-world-paths) -----------------------------------------------
# Brandon's twelve tiles (data/overworld_nodes.csv: col, row, height), flat-top hexes on the 2:1 camera like
# tools/art/hex_world_guide.py: even columns sit half a row lower, depth is squashed to half, a tile's top rises with
# its height. Any tile leads on to the tiles it shares an edge with; each shared edge is a leg in
# data/overworld_paths.csv.

const HEX_R := 140.0  ## a tile's radius, map units
const HEX_SQ := 0.5  ## the 2:1 camera: depth squashed to half
const HEX_LEVEL := 12.0  ## map units a height level lifts the tile's top
const HEX_ORIGIN := Vector2(185, 215)  ## where column 0, row 0's centre sits (lays the 12 tiles out in 1000 x 700)


## A tile's centre on the ground, map units.
static func hex_ground(col: int, row: int) -> Vector2:
	var y := (row + (0.5 if col % 2 == 0 else 0.0)) * sqrt(3.0) * HEX_R
	return HEX_ORIGIN + Vector2(col * 1.5 * HEX_R, y * HEX_SQ)


## The middle of a tile's top face, where its glyph sits and the party stands.
static func tile_pos(node: Dictionary) -> Vector2:
	return hex_ground(int(node.col), int(node.row)) - Vector2(0, HEX_LEVEL * int(node.height) + 20.0)


## A tile's top face (six corners, clockwise from the right), shrunk by gap so neighbours stay apart.
static func tile_top(node: Dictionary, gap := 9.0) -> PackedVector2Array:
	var c := tile_pos(node)
	var out := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * i)
		out.append(c + Vector2(cos(a), sin(a) * HEX_SQ) * (HEX_R - gap))
	return out


## The tiles that share an edge with this one (any of the six sides), by column and row.
static func neighbours(nodes: Dictionary, id: String) -> Array[String]:
	var n: Dictionary = nodes.get(id, {})
	var out: Array[String] = []
	if n.is_empty():
		return out
	var c := int(n.col)
	var r := int(n.row)
	var rows := [r, r + 1] if c % 2 == 0 else [r - 1, r]
	var want := [Vector2i(c, r - 1), Vector2i(c, r + 1)]
	for dc in [-1, 1]:
		for rr in rows:
			want.append(Vector2i(c + dc, rr))
	for o: String in nodes:
		if Vector2i(int(nodes[o].col), int(nodes[o].row)) in want:
			out.append(o)
	return out


## The leg joining two tiles (either way), its points running from a's top to b's. {} when they share no edge.
static func path_between(paths: Array, a: String, b: String, nodes: Dictionary = {}) -> Dictionary:
	if nodes.is_empty():
		nodes = Db.world_nodes
	for p: Dictionary in paths:
		if (p.from == a and p.to == b) or (p.from == b and p.to == a):
			var out := p.duplicate()
			out["points"] = PackedVector2Array([tile_pos(nodes[a]), tile_pos(nodes[b])])
			return out
	return {}


## The place an explore map belongs to (the pass owns its wolf den and the crypt under it).
static func node_for_map(nodes: Dictionary, map_name: String) -> String:
	for id in nodes:
		if map_name in String(nodes[id].maps).split("|", false):
			return id
	return "town"


## A place is cleared once its clear_flag is set (the pass: past the Lich King, beaten or escaped). Several
## flags split by | mean any of them (beat_lich: saves from before an escape counted). [USER] 2026-10-29: a
## cleared place shows as done on the big map and the place past it comes into view.
static func cleared(node: Dictionary, flags: Array) -> bool:
	for f in String(node.get("clear_flag", "")).split("|", false):
		if flags.has(f):
			return true
	return false


## Every tile shows on the hex map ([USER] 2026-11-01: the other tiles show, shut).
static func visible(nodes: Dictionary, id: String, _flags: Array) -> bool:
	return nodes.has(id)


## Can the party go to this tile now? Open in data, and a tile `after` another one only once that one is cleared
## (the mines past the highlands open after the Lich King).
static func open_now(nodes: Dictionary, id: String, flags: Array) -> bool:
	var n: Dictionary = nodes.get(id, {})
	var after := String(n.get("after", ""))
	return String(n.get("open", "0")) == "1" and (after == "" or cleared(nodes.get(after, {}), flags))


## The places to walk through, from a to b, both included ([] when there is no way). The party walks past
## a place only when it is cleared or has nothing to clear (the town), like the paths between levels on an
## old console map; it can always go in again by clicking it.
static func route(paths: Array, nodes: Dictionary, a: String, b: String, flags: Array) -> Array[String]:
	var prev := {a: ""}
	var queue: Array[String] = [a]
	while not queue.is_empty():
		var c: String = queue.pop_front()
		if c == b:
			break
		if c != a and String(nodes[c].get("clear_flag", "")) != "" and not cleared(nodes[c], flags):
			continue  # can't walk past a place still to clear
		for p: Dictionary in paths:
			var n := String(p.to) if p.from == c else (String(p.from) if p.to == c else "")
			if n == "" or prev.has(n) or not open_now(nodes, n, flags):
				continue
			prev[n] = c
			queue.append(n)
	if not prev.has(b) or a == b:
		return []
	var out: Array[String] = [b]
	while out[0] != a:
		out.push_front(String(prev[out[0]]))
	return out

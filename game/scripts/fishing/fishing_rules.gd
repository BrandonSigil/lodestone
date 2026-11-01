class_name FishingRules
extends RefCounted
## Fishing ([USER] 2026-11-01, card design-fishing-research): one cast in three beats.
##   Look: the pool shows the pond's drifting fish shadows (a pond holds a few fish and they run out: a catch, a
##   scared or missed fish and a lost one are gone for good, [USER] 2026-11-01 FI2). The player aims the cast at
##   a spot; a fish near where the bobber lands may notice it (FI1), turn and come to it.
##   Strike: the bobber nibbles a few times, then truly dips. Strike on the real dip; too soon scares the
##   fish off, too late and it's gone.
##   Reel: a horizontal bar. Fish and marker start in the middle and the fish eases in (FI3). Holding left or
##   right pulls the marker that way; let go and it springs back to the centre (FI4). On the fish the catch
##   meter fills, off it drains. Full lands the fish, empty loses it. The rod bends toward the fish.
## Pure functions of their inputs and an rng, so tests run them headless. Fish kinds are data/fish.csv,
## tuning is the fish_* rows of data/levels.csv. The scene (FishingGame) owns the clock and the drawing.

const GRADES := ["small", "good", "prize"]
const OUTCOMES := ["caught", "lost", "early", "late", "left"]
const GONE := ["caught", "lost", "early", "late"]  ## outcomes that take the fish out of the pond for good
const POOL_ASPECT := 0.45  ## the pool is wider than tall: a pool-coords y step counts this much against a notice distance


static func tune(key: String, fallback: float) -> float:
	return float(Db.levels.get(key, fallback))


# --- Look -----------------------------------------------------------------------------------------

## The fish that can bite at a spot (a row's spots column lists spot ids, or "any").
static func pool(fish: Dictionary, spot: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in fish:
		var row: Dictionary = fish[id]
		var spots := String(row.get("spots", "any")).split(";")
		if spots.has("any") or spots.has(spot):
			out.append(row)
	return out


## Pick one row by its weight column.
static func pick(rng: RandomNumberGenerator, rows: Array[Dictionary]) -> Dictionary:
	var total := 0.0
	for r in rows:
		total += maxf(0.0, float(r.get("weight", 1)))
	if rows.is_empty() or total <= 0.0:
		return {}
	var x := rng.randf() * total
	for r in rows:
		x -= maxf(0.0, float(r.get("weight", 1)))
		if x < 0.0:
			return r
	return rows[-1]


## A fresh pond: n fish drawn by weight from the spot's rows, as a list of fish ids. It only ever shrinks.
static func new_pond(rng: RandomNumberGenerator, rows: Array[Dictionary], n: int) -> Array:
	var out := []
	for i in n:
		var row := pick(rng, rows)
		if row.is_empty():
			break
		out.append(String(row.id))
	return out


## The shadows in the pool: n fish drawn by weight (a practice pool without a pond).
static func shadows(rng: RandomNumberGenerator, rows: Array[Dictionary], n: int) -> Array[Dictionary]:
	var picked: Array[Dictionary] = []
	for i in n:
		var row := pick(rng, rows)
		if not row.is_empty():
			picked.append(row)
	return shadows_of(rng, picked)


## One shadow for each fish row (a pond's fish): each with a home spot (pool coords, 0 to 1 each way, kept off
## the shore), a drift phase and `pond_i`, the fish's place in the list. Spread so no two homes sit on top
## of each other.
static func shadows_of(rng: RandomNumberGenerator, rows: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in rows.size():
		for tries in 200:
			var home := Vector2(rng.randf_range(0.18, 0.82), rng.randf_range(0.22, 0.72))
			if out.any(func(s: Dictionary) -> bool: return (s.home as Vector2).distance_to(home) < 0.2):
				continue
			out.append({"fish": rows[i], "home": home, "phase": rng.randf() * TAU, "rate": rng.randf_range(0.25, 0.5), "pond_i": i})
			break
	return out


## Where a shadow is at time t: a slow loop around its home.
static func shadow_pos(s: Dictionary, t: float) -> Vector2:
	var a := float(s.phase) + t * float(s.rate)
	return (s.home as Vector2) + Vector2(cos(a) * 0.07, sin(a * 1.3) * 0.045)


## Which way a shadow faces at time t (its drift direction), for drawing the head and tail.
static func shadow_heading(s: Dictionary, t: float) -> Vector2:
	var d := shadow_pos(s, t + 0.05) - shadow_pos(s, t)
	return d.normalized() if d.length() > 0.00001 else Vector2.RIGHT


## The shadow nearest a point (pool coords) within reach, or -1.
static func nearest(list: Array[Dictionary], p: Vector2, t: float, reach := 0.12) -> int:
	var best := -1
	var best_d := reach
	for i in list.size():
		var d := shadow_pos(list[i], t).distance_to(p)
		if d <= best_d:
			best = i
			best_d = d
	return best


## Does a fish notice a bobber that landed at `at` (pool coords)? The shadows within `fish_notice` of it each get a
## chance, nearest first: sure-ish right beside it, `fish_notice_min` at the edge of its reach. Returns the shadow
## index of the fish that turns toward it, or -1. Called when the bobber lands and again while it sits.
static func noticed(rng: RandomNumberGenerator, list: Array[Dictionary], at: Vector2, t: float) -> int:
	var reach := tune("fish_notice", 0.18)
	var floor_p := tune("fish_notice_min", 0.3)
	var order: Array[Array] = []
	for i in list.size():
		var d := (shadow_pos(list[i], t) - at) * Vector2(1.0, POOL_ASPECT)
		if d.length() <= reach:
			order.append([d.length(), i])
	order.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for o in order:
		if rng.randf() <= lerpf(1.0, floor_p, float(o[0]) / reach):
			return int(o[1])
	return -1


# --- Strike ---------------------------------------------------------------------------------------

## When the bites come after the cast: false nibbles first, then the real bite and how long it lasts.
## window_bonus is extra seconds (a better rod, later).
static func strike_plan(rng: RandomNumberGenerator, row: Dictionary, window_bonus := 0.0) -> Dictionary:
	var bite := rng.randf_range(tune("fish_wait_min", 1.4), tune("fish_wait_max", 3.4))
	var nibbles: Array[float] = []
	var n := rng.randi_range(0, int(tune("fish_nibbles", 2)))
	var tries := 0
	while nibbles.size() < n and tries < 40:
		tries += 1
		var t := snappedf(rng.randf_range(0.5, bite - 0.45), 0.01)
		if t > 0.0 and nibbles.all(func(o: float) -> bool: return absf(o - t) >= 0.45):
			nibbles.append(t)
	nibbles.sort()
	var window := tune("fish_window", 0.6) * float(row.get("strike", 1.0)) + window_bonus
	return {"nibbles": nibbles, "bite": bite, "window": window}


## The bobber's state at t seconds after the cast: "wait", "nibble" (a false bite), "bite" or "gone".
static func bobber_at(plan: Dictionary, t: float) -> String:
	if t >= float(plan.bite) + float(plan.window):
		return "gone"
	if t >= float(plan.bite):
		return "bite"
	for n: float in plan.nibbles:
		if t >= n and t < n + 0.25:
			return "nibble"
	return "wait"


## A strike at t seconds after the cast: "hit" on the real dip, "early" before it, "late" after.
static func strike(plan: Dictionary, t: float) -> String:
	if t < float(plan.bite):
		return "early"
	if t <= float(plan.bite) + float(plan.window):
		return "hit"
	return "late"


# --- Reel -----------------------------------------------------------------------------------------

## What the party brings to the reel: the best fishing skill slows the fish a little (a companion with a
## fishing knack, docs/design/fishing.md idea 1). half_bonus widens the marker (a better rod, later).
static func mods_for(run: RunState) -> Dictionary:
	var best := 0
	if run != null:
		for m in run.alive():
			best = maxi(best, (m.def as CharacterDef).skill("fish"))
	var slow := minf(tune("fish_skill_slow_max", 0.3), best * tune("fish_skill_slow", 0.07))
	return {"slow": slow, "half_bonus": 0.0, "window_bonus": 0.0, "skill": best}


## A fresh reel against one fish. Bar positions run 0 (left) to 1 (right). The fish and the marker both start in
## the middle and the fish hovers a moment before its first dart ([USER] 2026-11-01 FI3).
static func reel_start(row: Dictionary, mods := {}) -> Dictionary:
	var half := tune("fish_half", 0.11) + float(mods.get("half_bonus", 0.0))
	return {
		"fish": 0.5, "target": 0.5, "wait": tune("fish_first_wait", 1.2), "marker": 0.5, "vel": 0.0, "t": 0.0,
		"catch": tune("fish_catch_start", 0.3), "half": half, "on": true, "pull": 0.0, "done": "",
		"speed": float(row.get("speed", 0.8)) * (1.0 - float(mods.get("slow", 0.0))),
		"dart_min": float(row.get("dart_min", 0.4)), "dart_max": float(row.get("dart_max", 1.0)),
		"reach": float(row.get("reach", 0.4)), "fill": float(row.get("fill", 0.4)), "drain": float(row.get("drain", 0.3)),
	}


## How far into its full difficulty a reel is: 0 at the start, 1 once `fish_ease` seconds have passed. Until then the
## fish is slower, darts shorter and the meter drains less (the quick ease-in).
static func ramp(s: Dictionary) -> float:
	return clampf(float(s.t) / maxf(0.01, tune("fish_ease", 4.0)), 0.0, 1.0)


## A pointer's pull on the bar as an axis (-1 to 1): the pointer left or right of the bar's centre by `span` pulls
## fully that way (the mouse and a finger work like holding an arrow).
static func axis_from_pointer(x: float, centre: float, span: float) -> float:
	return clampf((x - centre) / maxf(1.0, span), -1.0, 1.0)


## Advance the reel by dt. input: "axis" = left or right held, from keys, stick or pointer (-1 to 1). Holding pulls
## the marker that way (up to fish_marker_speed); letting go springs it back to the centre ([USER] 2026-11-01 FI4:
## "the second you release it pulls back to the center"), so it feels like the fish pulling on the line. Sets
## s.done to "caught" or "lost" when it ends.
static func reel_step(s: Dictionary, rng: RandomNumberGenerator, dt: float, input := {}) -> Dictionary:
	if s.done != "":
		return s
	s.t = float(s.t) + dt
	var k := ramp(s)
	var easy := lerpf(tune("fish_ease_speed", 0.4), 1.0, k)
	# the fish: hover a moment, then dart to a new spot
	if float(s.wait) > 0.0:
		s.wait = float(s.wait) - dt
	else:
		s.fish = move_toward(float(s.fish), float(s.target), float(s.speed) * easy * dt)
		if is_equal_approx(float(s.fish), float(s.target)):
			var reach := float(s.reach) * lerpf(tune("fish_ease_reach", 0.5), 1.0, k)
			var span := rng.randf_range(reach * 0.4, reach)
			var dir := -1.0 if rng.randf() < 0.5 else 1.0
			if float(s.fish) + dir * span > 0.95 or float(s.fish) + dir * span < 0.05:
				dir = -dir  # off the end of the bar: dart the other way
			s.target = clampf(float(s.fish) + dir * span, 0.05, 0.95)
			s.wait = rng.randf_range(float(s.dart_min), float(s.dart_max)) / easy  # longer pauses while it eases in
	# the marker: held = pulled that way, released = springs back to the centre
	var top := tune("fish_marker_speed", 1.6)
	var half := float(s.half)
	var axis := clampf(float(input.get("axis", 0.0)), -1.0, 1.0)
	var accel := tune("fish_marker_accel", 7.0)
	if absf(axis) < 0.05:
		var back := clampf((0.5 - float(s.marker)) * tune("fish_spring", 6.0), -top, top)
		s.vel = move_toward(float(s.vel), back, accel * 2.0 * dt)
	else:
		s.vel = move_toward(float(s.vel), axis * top, accel * dt)
	s.marker = float(s.marker) + float(s.vel) * dt
	if float(s.marker) < half or float(s.marker) > 1.0 - half:
		s.marker = clampf(float(s.marker), half, 1.0 - half)
		s.vel = 0.0
	# the catch meter
	var gap := float(s.fish) - float(s.marker)
	s.on = absf(gap) <= half
	s.pull = clampf(gap / 0.35, -1.0, 1.0)
	var drain := float(s.drain) * lerpf(tune("fish_ease_drain", 0.2), 1.0, k)
	s.catch = clampf(float(s.catch) + (float(s.fill) if s.on else -drain) * dt, 0.0, 1.0)
	if float(s.catch) >= 1.0:
		s.done = "caught"
	elif float(s.catch) <= 0.0:
		s.done = "lost"
	return s


# --- the catch --------------------------------------------------------------------------------------

## What a fish gives: item id -> count, from its reward column ("meat:2;ingredient:1").
static func reward(row: Dictionary) -> Dictionary:
	return RestoreRules.parse_needs(String(row.get("reward", "")))


## Put a caught fish's reward in the pack. Returns what went in.
static func land(run: RunState, row: Dictionary) -> Dictionary:
	var got := reward(row)
	for id: String in got:
		run.add_item(id, int(got[id]))
	run.note(Txt.f("LOG_FISH", Txt.t(String(row.get("name_key", "")))))
	return got

class_name HuntRules
extends RefCounted
## Pure rules for the four hunting prototypes ([AI] 2026-11-17, Brandon: "Build simple prototypes of each of these";
## pitches in docs/design/hunting-pitches/). A Bow Blind, B Stalk, C Snare Line, D Corgi Drive. Numbers are `hunt_*`,
## `stalk_*`, `snare_*` and `drive_*` rows in data/levels.csv; animals are data/hunt_animals.csv. No scene code here,
## so tests run it headless. `mods` is {"hunter": bool, "doggo": bool, "bonus": int} (HuntRules.mods_for).

const MODES := ["bow", "stalk", "snare", "drive"]


static func tune(key: String, fallback: float) -> float:
	return float(Db.levels.get(key, fallback))


## The party bits the prototypes care about. The practice screen sets hunter and doggo by its two toggles.
static func mods_for(hunter: bool, doggo: bool) -> Dictionary:
	var bonus := 0
	if hunter:
		bonus += 3
	if doggo:
		bonus += 2
	return {"hunter": hunter, "doggo": doggo, "bonus": bonus}


# --- animals ----------------------------------------------------------------------------------------

## The animals that show up in one mode (the row's `modes` column lists bow, stalk, snare, drive).
static func pool(mode: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in Db.hunt_animals:
		var row: Dictionary = Db.hunt_animals[id]
		if String(row.get("modes", "")).split(" ").has(mode):
			out.append(row)
	return out


static func pick(rng: RandomNumberGenerator, rows: Array[Dictionary]) -> Dictionary:
	var total := 0.0
	for r in rows:
		total += float(r.weight)
	var x := rng.randf() * total
	for r in rows:
		x -= float(r.weight)
		if x <= 0.0:
			return r
	return rows.back() if not rows.is_empty() else {}


static func food(rows: Array) -> int:
	var n := 0
	for r: Dictionary in rows:
		n += int(r.get("food", 0))
	return n


## How many animals a glade holds after the party's hunt roll (Dice.check result).
static func glade_size(roll: Dictionary) -> int:
	var n := int(tune("hunt_glade_base", 3))
	if roll.success:
		n += 1
		if roll.crit or int(roll.total) >= int(roll.dc) + 5:
			n += 1
	return n


# --- the bow (A and B) ------------------------------------------------------------------------------

## The draw after holding for `t` seconds: power 0..1 and shake in pixels. Full draw, then a steady hold, then the
## aim shakes more and more. The Hunter draws faster and holds longer (Steady Aim).
static func draw_state(t: float, mods: Dictionary) -> Dictionary:
	var full := tune("hunt_draw_full", 0.9) * (0.75 if mods.get("hunter", false) else 1.0)
	var hold := tune("hunt_hold_ok", 0.8) * (1.6 if mods.get("hunter", false) else 1.0)
	var power := clampf(t / full, 0.0, 1.0)
	var over := t - full - hold
	var shake := 0.0
	if over > 0.0:
		shake = clampf(over / tune("hunt_shake_grow", 1.4), 0.0, 1.0) * tune("hunt_shake_max", 36.0)
	return {"power": power, "shake": shake, "sweet": power >= 1.0 and over <= 0.0}


static func arrow_speed(power: float) -> float:
	return lerpf(tune("hunt_arrow_min", 520.0), tune("hunt_arrow_max", 1400.0), clampf(power, 0.0, 1.0))


## Share of the aimed distance the arrow flies: a weak draw drops short.
static func arrow_reach(power: float) -> float:
	var short := tune("hunt_short_power", 0.65)
	if power >= short:
		return 1.0
	return clampf(0.35 + 0.65 * power / short, 0.35, 1.0)


## "clean" (a catch), "graze" (wounded: it runs) or "miss", by how far the arrow passed from the animal's middle.
static func hit_grade(dist: float, radius: float) -> String:
	if dist <= radius * 0.6:
		return "clean"
	if dist <= radius * 1.1:
		return "graze"
	return "miss"


## Bow Blind's noise: a fast-moving aim makes noise, stillness drains it.
static func noise_step(noise: float, aim_speed: float, dt: float) -> float:
	var gain := maxf(0.0, aim_speed - tune("hunt_still_speed", 160.0)) * tune("hunt_noise_gain", 0.0016) * dt
	return clampf(noise + gain - tune("hunt_noise_decay", 0.3) * dt, 0.0, 1.0)


## A still hunter sees more pauses and slower runners; a noisy one sees them bolt.
static func pause_chance(row: Dictionary, noise: float) -> float:
	return clampf(float(row.pause_chance) * (1.0 - noise), 0.0, 1.0)


static func run_speed(row: Dictionary, noise: float) -> float:
	return float(row.speed) * (1.0 + 0.6 * noise)


# --- Stalk (B) --------------------------------------------------------------------------------------

## Whether `pt` is inside the deer's sight cone.
static func in_cone(eye: Vector2, facing: Vector2, pt: Vector2, half_angle_deg := 60.0, reach := 520.0) -> bool:
	var d := pt - eye
	if d.length() < 0.001:
		return true
	if d.length() > reach:
		return false
	return absf(rad_to_deg(facing.angle_to(d))) <= half_angle_deg


## Alert a second while the head is up: moving in the open is worst, still in tall grass is invisible.
static func alert_rate(in_view: bool, moving: bool, in_cover: bool) -> float:
	if not in_view:
		return 0.0
	if moving:
		return 0.7 if in_cover else 2.2
	return 0.0 if in_cover else 0.35


## The wind carries your scent to the deer when it blows from you toward it, close enough.
static func smells(hero: Vector2, deer: Vector2, wind: Vector2) -> bool:
	var d := deer - hero
	if d.length() > tune("stalk_scent_range", 260.0) or d.length() < 1.0:
		return false
	return d.normalized().dot(wind.normalized()) > 0.6


## The head's next beat: down (grazing), tell (tail flick: about to look up), up (looking). Seconds for each.
static func head_time(rng: RandomNumberGenerator, phase: String, mods: Dictionary) -> float:
	match phase:
		"down":
			return rng.randf_range(1.6, 3.8)
		"tell":
			return 0.9 if mods.get("hunter", false) else 0.45
		_:
			return rng.randf_range(1.2, 2.4)


## Shot ring: how close you must be to draw on the deer.
static func shot_ring(mods: Dictionary) -> float:
	return 190.0 if mods.get("hunter", false) else 150.0


# --- Snare Line (C) ---------------------------------------------------------------------------------

## The ground by the camp: a grid with cover (bushes) and a stream along the bottom row.
static func snare_field(rng: RandomNumberGenerator, cols := 12, rows := 7) -> Dictionary:
	var bushes: Array[Vector2i] = []
	while bushes.size() < 9:
		var c := Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 2))
		if not bushes.has(c):
			bushes.append(c)
	var water: Array[Vector2i] = []
	for x in cols:
		water.append(Vector2i(x, rows - 1))
	return {"cols": cols, "rows": rows, "bushes": bushes, "water": water}


## Tonight's animal runs. Each animal keeps its habit: rabbits hop from cover to cover, boars go straight to water,
## foxes zigzag. About half the runs are stale (old tracks nobody walks tonight). Hunter sees every run; without him
## only some show. Doggo's SNIFF tells fresh from stale.
static func snare_runs(rng: RandomNumberGenerator, field: Dictionary, count := 6) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var kinds := ["rabbit", "rabbit", "boar", "fox", "rabbit", "fox", "boar"]
	for i in count:
		var kind: String = kinds[i % kinds.size()]
		var cells: Array[Vector2i] = []
		match kind:
			"rabbit": cells = _rabbit_run(rng, field)
			"boar": cells = _boar_run(rng, field)
			_: cells = _fox_run(rng, field)
		out.append({"kind": kind, "cells": cells, "fresh": i < 3 or rng.randf() < 0.3, "seen": i % 2 == 0})
	return out


static func _walk(from: Vector2i, to: Vector2i, rng: RandomNumberGenerator, wobble := 0.0) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [from]
	var c := from
	var guard := 0
	while c != to and guard < 60:
		guard += 1
		var d := to - c
		var step := Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y))
		if wobble > 0.0 and rng.randf() < wobble:
			step = Vector2i(0, signi(d.y)) if step.x != 0 and d.y != 0 else Vector2i(signi(d.x), 0) if d.x != 0 else step
		c += step
		cells.append(c)
	return cells


static func _rabbit_run(rng: RandomNumberGenerator, field: Dictionary) -> Array[Vector2i]:
	var b: Array = field.bushes.duplicate()
	b.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return p.x < q.x)
	var a: Vector2i = b[rng.randi_range(0, 2)]
	var mid: Vector2i = b[rng.randi_range(3, 5)]
	var z: Vector2i = b[rng.randi_range(6, b.size() - 1)]
	var cells := _walk(a, mid, rng, 0.3)
	var rest := _walk(mid, z, rng, 0.3)
	rest.remove_at(0)
	cells.append_array(rest)
	return cells


static func _boar_run(rng: RandomNumberGenerator, field: Dictionary) -> Array[Vector2i]:
	var x := rng.randi_range(1, int(field.cols) - 2)
	return _walk(Vector2i(x, 0), Vector2i(clampi(x + rng.randi_range(-3, 3), 0, int(field.cols) - 1), int(field.rows) - 1), rng)


static func _fox_run(rng: RandomNumberGenerator, field: Dictionary) -> Array[Vector2i]:
	var y := rng.randi_range(0, int(field.rows) - 2)
	var cells: Array[Vector2i] = []
	for x in int(field.cols):
		cells.append(Vector2i(x, clampi(y + (1 if x % 4 < 2 else 0) * (1 if y < 3 else -1), 0, int(field.rows) - 2)))
	return cells


## Bait pulls a rabbit or boar off its run onto the bait (if the run passes within 2 cells). A fox smells your hands
## on it and turns back before it gets within a cell.
static func baited(run: Dictionary, bait: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.assign(run.cells)
	if bait == Vector2i(-1, -1):
		return cells
	var near := -1
	var best := 99
	for i in cells.size():
		var d := maxi(absi(cells[i].x - bait.x), absi(cells[i].y - bait.y))
		if d < best:
			best = d
			near = i
	if String(run.kind) == "fox":
		if best <= 1:
			var cut: Array[Vector2i] = []
			for i in near:
				if maxi(absi(cells[i].x - bait.x), absi(cells[i].y - bait.y)) > 1:
					cut.append(cells[i])
				else:
					break
			return cut
		return cells
	if best <= 2 and best > 0:
		var detour := _walk(cells[near], bait, RandomNumberGenerator.new())
		var back := _walk(bait, cells[near], RandomNumberGenerator.new())
		detour.remove_at(0)
		back.remove_at(0)
		var out: Array[Vector2i] = cells.slice(0, near + 1)
		out.append_array(detour)
		out.append_array(back)
		out.append_array(cells.slice(near + 1))
		return out
	return cells


## The night: each fresh run's animal walks its cells; the first snare it steps in rolls to hold (d20 + bonus vs the
## animal's strength). A held snare is a catch and that snare is spent; a snapped one is spent too.
## Returns {"events": [{run (index), kind, cell, step, outcome: caught | snapped}], "caught": [rows], "paths": [cells per run]}.
static func snare_night(rng: RandomNumberGenerator, runs: Array[Dictionary], snares: Array[Vector2i], bait: Vector2i,
		mods: Dictionary) -> Dictionary:
	var live := snares.duplicate()
	var events: Array[Dictionary] = []
	var caught: Array[Dictionary] = []
	var paths: Array = []
	var bonus := int(tune("snare_hunter_bonus", 3)) if mods.get("hunter", false) else 0
	for ri in runs.size():
		var run: Dictionary = runs[ri]
		if not run.fresh:
			paths.append([])
			continue
		var cells := baited(run, bait)
		paths.append(cells)
		for step in cells.size():
			var c: Vector2i = cells[step]
			if live.has(c):
				live.erase(c)
				var row: Dictionary = Db.hunt_animals.get(String(run.kind), {})
				var r := Dice.check(rng, bonus, int(row.get("strength", 10)))
				var outcome := "caught" if r.success else "snapped"
				events.append({"run": ri, "kind": run.kind, "cell": c, "step": step, "outcome": outcome, "roll": r})
				if r.success:
					caught.append(row)
				break
	return {"events": events, "caught": caught, "paths": paths}


# --- Corgi Drive (D) --------------------------------------------------------------------------------

## One step of the flock: each bird keeps near the others, keeps a little room, wanders, and runs from the dog.
## A bird the dog runs right at panics and flies off ("gone"). birds: [{p, v, state: "flock" | "gone" | "shot"}].
static func flock_step(birds: Array, dog: Vector2, dog_speed: float, dt: float, field: Rect2) -> void:
	var centre := Vector2.ZERO
	var n := 0
	for b: Dictionary in birds:
		if b.state == "flock":
			centre += b.p
			n += 1
	if n == 0:
		return
	centre /= n
	for b: Dictionary in birds:
		if b.state != "flock":
			continue
		var acc: Vector2 = (centre - b.p) * 0.6
		for o: Dictionary in birds:
			if o != b and o.state == "flock" and b.p.distance_to(o.p) < 34.0:
				acc += (b.p - o.p).normalized() * 160.0
		var away: Vector2 = b.p - dog
		var d := away.length()
		if d < 170.0:
			acc += away.normalized() * (170.0 - d) * 9.0
		if d < 46.0 and dog_speed > 200.0:
			b.state = "gone"
			b.v = away.normalized() * 520.0
			continue
		b.v = (b.v + acc * dt) * 0.97
		var top := 240.0 if d < 170.0 else 70.0
		if b.v.length() > top:
			b.v = b.v.normalized() * top
		b.p += b.v * dt
		b.p.y = clampf(b.p.y, field.position.y + 10.0, field.end.y - 10.0)
		if b.p.x < field.position.x - 20.0 or b.p.x > field.end.x + 40.0:
			b.state = "gone"


## BARK: every bird in front of the dog (a 70 degree cone, 240 px) gets a hard shove away.
static func bark(birds: Array, dog: Vector2, facing: Vector2) -> int:
	var hit := 0
	for b: Dictionary in birds:
		if b.state == "flock" and in_cone(dog, facing, b.p, 35.0, 240.0):
			b.v += (b.p - dog).normalized() * 330.0
			hit += 1
	return hit


## A bird inside the gap: is it in the hero's sure-shot middle? (tap timing; the Hunter never misses)
static func gap_shot(bird: Vector2, gap: Rect2, mods: Dictionary) -> bool:
	if not gap.has_point(bird):
		return false
	if mods.get("hunter", false):
		return true
	return absf(bird.y - gap.get_center().y) <= gap.size.y * 0.3

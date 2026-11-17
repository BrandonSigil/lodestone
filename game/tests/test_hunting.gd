extends TestCase
## The hunting prototypes' rules (HuntRules; [AI] 2026-11-17, Brandon: "Build simple prototypes of each of these").


func _db() -> void:
	if Db.levels.is_empty() or Db.hunt_animals.is_empty():
		Db.reload()


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func test_animal_table() -> void:
	_db()
	ok(Db.hunt_animals.size() >= 5, "animals load from data/hunt_animals.csv")
	for id in Db.hunt_animals:
		ok(Txt.has(String(Db.hunt_animals[id].name_key)), "%s has text" % id)
	for m in HuntRules.MODES:
		ok(not HuntRules.pool(m).is_empty(), "%s has animals" % m)
	ok(HuntRules.pool("stalk").all(func(r: Dictionary) -> bool: return String(r.id) == "deer"), "stalk is deer only")


func test_glade_size_follows_the_roll() -> void:
	_db()
	var base := int(HuntRules.tune("hunt_glade_base", 3))
	eq(HuntRules.glade_size(Dice._result(5, 0, 12)), base, "a missed roll: the base glade")
	eq(HuntRules.glade_size(Dice._result(13, 0, 12)), base + 1, "a made roll: one more")
	eq(HuntRules.glade_size(Dice._result(18, 0, 12)), base + 2, "5 over: two more")


func test_draw_sweet_then_shake() -> void:
	_db()
	var plain := {"hunter": false}
	var hunter := {"hunter": true}
	ok(float(HuntRules.draw_state(0.3, plain).power) < 1.0, "a short hold is a partial draw")
	ok(HuntRules.draw_state(1.0, plain).sweet, "a full draw held briefly is the sweet spot")
	ok(float(HuntRules.draw_state(4.0, plain).shake) > 20.0, "holding too long shakes")
	ok(float(HuntRules.draw_state(2.0, hunter).shake) < float(HuntRules.draw_state(2.0, plain).shake), "the Hunter holds steadier")
	ok(HuntRules.arrow_reach(0.3) < 1.0 and is_equal_approx(HuntRules.arrow_reach(1.0), 1.0), "a weak draw drops short")
	ok(HuntRules.arrow_speed(1.0) > HuntRules.arrow_speed(0.4), "a full draw flies faster")
	eq(HuntRules.hit_grade(3.0, 20.0), "clean", "dead centre is a catch")
	eq(HuntRules.hit_grade(18.0, 20.0), "graze", "the edge wounds")
	eq(HuntRules.hit_grade(40.0, 20.0), "miss", "far off misses")


func test_noise_rises_and_settles() -> void:
	_db()
	var n := 0.0
	for i in 30:
		n = HuntRules.noise_step(n, 1500.0, 1.0 / 30.0)
	ok(n > 0.5, "a sweeping aim gets loud")
	for i in 120:
		n = HuntRules.noise_step(n, 0.0, 1.0 / 30.0)
	ok(n < 0.1, "a still aim goes quiet")
	var deer: Dictionary = Db.hunt_animals.deer
	ok(HuntRules.pause_chance(deer, 0.0) > HuntRules.pause_chance(deer, 0.8), "quiet hunters see more pauses")


func test_stalk_sight_and_scent() -> void:
	_db()
	ok(HuntRules.in_cone(Vector2.ZERO, Vector2.RIGHT, Vector2(100, 10)), "in front is seen")
	ok(not HuntRules.in_cone(Vector2.ZERO, Vector2.RIGHT, Vector2(-100, 0)), "behind is not")
	eq(HuntRules.alert_rate(true, false, true), 0.0, "still in tall grass is invisible")
	ok(HuntRules.alert_rate(true, true, false) > HuntRules.alert_rate(true, true, true), "moving in the open is worst")
	ok(HuntRules.smells(Vector2.ZERO, Vector2(150, 0), Vector2.RIGHT), "wind from you to it carries your scent")
	ok(not HuntRules.smells(Vector2.ZERO, Vector2(150, 0), Vector2.LEFT), "into the wind it can't smell you")


func test_snare_night() -> void:
	_db()
	var rng := _rng(7)
	var fld := HuntRules.snare_field(rng)
	var runs := HuntRules.snare_runs(rng, fld, 6)
	eq(runs.size(), 6, "six runs a night")
	# a rabbit run with a snare in its middle, nothing else
	var run: Dictionary = {"kind": "rabbit", "cells": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)], "fresh": true, "seen": true}
	var stale: Dictionary = {"kind": "rabbit", "cells": [Vector2i(0, 3), Vector2i(1, 3)], "fresh": false, "seen": true}
	var caught := 0
	for s in 200:
		var res := HuntRules.snare_night(_rng(s), [run, stale] as Array[Dictionary], [Vector2i(2, 1), Vector2i(1, 3)] as Array[Vector2i], Vector2i(-1, -1), {})
		caught += res.caught.size()
		ok(res.events.size() == 1, "only the fresh run walks")
	ok(caught > 120 and caught < 180, "a rabbit holds about three times in four (%d of 200)" % caught)
	# bait: a rabbit detours onto it, a fox turns back
	var baited := HuntRules.baited(run, Vector2i(2, 3))
	ok(baited.has(Vector2i(2, 3)), "a rabbit goes to the bait")
	var fox: Dictionary = {"kind": "fox", "cells": run.cells, "fresh": true}
	ok(not HuntRules.baited(fox, Vector2i(2, 2)).has(Vector2i(2, 1)), "a fox turns back from handled bait")


func test_flock_and_bark() -> void:
	_db()
	var field := Rect2(0, 0, 1000, 600)
	var birds: Array = []
	for i in 5:
		birds.append({"p": Vector2(400 + i * 10, 300), "v": Vector2.ZERO, "state": "flock"})
	var before := 0.0
	for b: Dictionary in birds:
		before += b.p.x
	for i in 60:
		HuntRules.flock_step(birds, Vector2(300, 300), 0.0, 1.0 / 30.0, field)
	var after := 0.0
	for b: Dictionary in birds:
		after += b.p.x
	ok(after > before + 50.0, "the flock moves away from the dog")
	for i in birds.size():
		birds[i].p = Vector2(400 + i * 10, 300)
	eq(HuntRules.bark(birds, Vector2(300, 300), Vector2.RIGHT), 5, "a bark in front reaches them all")
	eq(HuntRules.bark(birds, Vector2(300, 300), Vector2.LEFT), 0, "a bark the wrong way reaches none")
	var gap := Rect2(800, 250, 60, 100)
	ok(HuntRules.gap_shot(Vector2(830, 300), gap, {}), "the gap's middle is a hit")
	ok(not HuntRules.gap_shot(Vector2(830, 255), gap, {}), "its edge misses")
	ok(HuntRules.gap_shot(Vector2(830, 255), gap, {"hunter": true}), "the Hunter never misses in the gap")

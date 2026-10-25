class_name Dice
extends RefCounted
## Every check in the game: d20 + bonus vs a target number.
## Natural 20 always succeeds, natural 1 always fails.


static func check(rng: RandomNumberGenerator, bonus: int, dc: int) -> Dictionary:
	var roll := rng.randi_range(1, 20)
	return _result(roll, bonus, dc)


static func _result(roll: int, bonus: int, dc: int) -> Dictionary:
	var total := roll + bonus
	var success := roll == 20 or (roll != 1 and total >= dc)
	return {
		"roll": roll, "bonus": bonus, "total": total, "dc": dc,
		"success": success, "crit": roll == 20, "fumble": roll == 1,
	}


## Chance from 0.05 to 0.95 that the check succeeds.
static func chance(bonus: int, dc: int) -> float:
	var wins := 0
	for roll in range(1, 21):
		if _result(roll, bonus, dc).success:
			wins += 1
	return wins / 20.0


## "d20 14 +3 = 17 vs 13"
static func describe(r: Dictionary) -> String:
	var b: int = r.bonus
	var sign := "+" if b >= 0 else "-"
	return "d20 %d %s%d = %d vs %d" % [r.roll, sign, absi(b), r.total, r.dc]

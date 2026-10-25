extends TestCase


func test_chance_even() -> void:
	eq(Dice.chance(0, 11), 0.5)


func test_nat20_and_nat1() -> void:
	eq(Dice.chance(100, 10), 0.95, "nat 1 always fails")
	eq(Dice.chance(-100, 10), 0.05, "nat 20 always hits")


func test_check_matches_chance() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var wins := 0
	for i in 4000:
		if Dice.check(rng, 3, 14).success:
			wins += 1
	ok(absf(wins / 4000.0 - Dice.chance(3, 14)) < 0.03, "empirical rate near %f" % Dice.chance(3, 14))


func test_describe() -> void:
	eq(Dice.describe(Dice._result(14, 3, 13)), "d20 14 +3 = 17 vs 13")
	eq(Dice.describe(Dice._result(5, -2, 10)), "d20 5 -2 = 3 vs 10")

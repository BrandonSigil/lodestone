class_name ScaleTest
extends RefCounted
## Scale C as a test-only data set (docs/design/scale-study.md, [USER] 2026-10-30 design-scale): the move and reach
## numbers of data/scale_c.csv laid over a fight's pieces when a test fight asks for them. Shipped classes and
## abilities are never touched: the units get the numbers, abilities are copied first.


static func rows() -> Array[Dictionary]:
	return CsvTable.load_rows("res://data/scale_c.csv")


## Sets move and reach on every piece whose class has a row, and swaps in copies of the abilities that have one.
static func apply(units: Array) -> void:
	var table := rows()
	var by_class := {}
	var by_ability := {}
	for r in table:
		if r.kind == "class":
			by_class[r.id] = r
		else:
			by_ability[r.id] = r
	for u: CombatUnit in units:
		if u.cls != null and by_class.has(String(u.cls.id)):
			var r: Dictionary = by_class[String(u.cls.id)]
			u.move = int(r.move)
			u.range_min = int(r.range_min)
			u.range_max = int(r.range_max)
		for i in u.abilities.size():
			var a: Ability = u.abilities[i]
			if by_ability.has(a.id):
				var c := a.copy()
				c.range_min = int(by_ability[a.id].range_min)
				c.range_max = int(by_ability[a.id].range_max)
				u.abilities[i] = c

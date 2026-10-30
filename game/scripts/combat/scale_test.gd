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


# --- the standard, ready to switch on ([USER] 2026-10-30 design-scale: scale C becomes the standard) -----------------
# data/scale_standard.csv holds every class's and ranged ability's scale C numbers by the study's rule (move and ranged
# reach x1.25; a base move of 5 or more, or a reach of 4 or more, x1.5; melee reach stays 1). The switch is combat.csv
# `scale_standard` (0 = off): flip it to 1 once the fight areas are resized, and every piece built after that has them.

static var _standard: Dictionary = {}


static func standard_rows() -> Dictionary:
	if _standard.is_empty():
		for r in CsvTable.load_rows("res://data/scale_standard.csv"):
			_standard[String(r.kind) + ":" + String(r.id)] = r
	return _standard


## Called when a piece has been built (class, spells and all): with the switch on, its move and reach are scale C's.
## Gear and levels that added to the class's numbers keep their addition; abilities become copies with the new reach.
static func standard(u: CombatUnit) -> void:
	if CombatRules.num("scale_standard") <= 0.0 or u.scaled or u.cls == null:
		return
	u.scaled = true
	var rows := standard_rows()
	var key := "class:" + String(u.cls.id)
	if rows.has(key):
		var r: Dictionary = rows[key]
		u.move += int(r.move) - u.cls.move
		u.range_max += int(r.range_max) - u.cls.range_max
	for i in u.abilities.size():
		var a: Ability = u.abilities[i]
		var ak := "ability:" + a.id
		if rows.has(ak):
			var c := a.copy()
			c.range_max = int(rows[ak].range_max)
			u.abilities[i] = c

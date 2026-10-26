class_name Ability
extends RefCounted
## One row of data/abilities.csv: the basic strike, class skills, and enemy tricks.
## Items used in a fight are Abilities too (built from data/combat_items.csv) so one code path resolves both.

var id := ""
var name_key := ""
var kind := "attack"  ## attack (rolls d20, deals damage), heal (no roll), buff (no roll, adds a status)
var target := "enemy"  ## enemy, ally (includes self), self, cell (aim at any cell, hits everyone in the radius)
var range_min := 0  ## 0 and 0 = use the unit's weapon range
var range_max := 0
var radius := 0  ## 0 = one unit, 1 = plus shape around the aimed cell
var power := 0  ## added to the unit's damage for attacks; the amount healed for heals
var hit := 0  ## added to the to-hit roll
var cooldown := 0  ## own phases to wait before using it again
var push := 0  ## tiles the target is shoved away from the user
var status := ""  ## rooted, veil, guard
var status_turns := 0
var magic := false  ## ignores cover
## Items only: which supply it spends and how much.
var resource := ""
var cost := 0


static func from_row(row: Dictionary) -> Ability:
	var a := Ability.new()
	a.id = row.id
	a.name_key = row.name_key
	a.kind = row.kind
	a.target = row.target
	a.range_min = int(row.range_min)
	a.range_max = int(row.range_max)
	a.radius = int(row.radius)
	a.power = int(row.power)
	a.hit = int(row.hit)
	a.cooldown = int(row.cooldown)
	a.push = int(row.push)
	a.status = row.status
	a.status_turns = int(row.status_turns)
	a.magic = row.magic == "1"
	return a


static func from_item_row(row: Dictionary) -> Ability:
	var a := Ability.new()
	a.id = row.id
	a.name_key = row.name_key
	a.kind = "heal" if int(row.heal) > 0 else "buff"
	a.target = "ally"
	a.range_min = 0
	a.range_max = int(row.range_max)
	a.power = int(row.heal)
	a.status = row.status
	a.status_turns = int(row.status_turns)
	a.resource = row.resource
	a.cost = int(row.cost)
	return a


func uses_weapon_range() -> bool:
	return range_min == 0 and range_max == 0


func is_item() -> bool:
	return resource != ""


func hostile() -> bool:
	return kind == "attack"

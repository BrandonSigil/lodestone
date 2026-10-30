class_name Ability
extends RefCounted
## One row of data/abilities.csv: the basic strike, class skills, and enemy tricks.
## Items used in a fight are Abilities too (built from data/combat_items.csv) so one code path resolves both.

var id := ""
var name_key := ""
var kind := "attack"  ## attack (deals damage), hex (only adds its status), heal, buff (adds a status), revive, knockout
var target := "enemy"  ## enemy, ally (includes self), self, cell (aim at any cell, hits everyone in the radius)
var range_min := 0  ## 0 and 0 = use the unit's weapon range
var range_max := 0
var radius := 0  ## 0 = one unit, 1 = plus shape around the aimed cell
var power := 0  ## added to the unit's damage for attacks; the amount healed for heals
var crit := 0  ## % crit chance this skill adds to its hits
var res_cost := 0  ## what one use costs of the user's job resource (mana, rage or charges); no cooldowns
var push := 0  ## tiles the target is shoved away from the user
var status := ""  ## rooted, veil, guard
var status_turns := 0
var bleed := 0  ## phases of BLEED a hit adds (a skill rank's effect, data/skill_ranks.csv)
var magic := false  ## ignores cover
var element := ""  ## fire, moon, frost or empty. Some traits care (flammable takes more from fire).
## A boss's big moves ([USER] 2026-10-30 design-boss-warning, design-boss-shape). windup > 0: marked on the user's
## phase besides its action and landing that many of its phases later. summon: a class id it calls `count` of.
var windup := 0
var cooldown := 0  ## own phases from one use to the next
var first := 1  ## the user's own phase it can first be used on
var summon := ""
var count := 0
var limit := 0  ## at most this many called pieces standing at once
var spot := ""  ## summon: "party" puts them 2 steps from a party piece, never next to one; "" round the caller
## Items only: the pack item it spends from the user's belt (data/items.csv id) and how many.
var spends := ""
var cost := 0


## A separate copy, so a skill rank can change one piece's skill without touching the shared row.
func copy() -> Ability:
	var out := Ability.new()
	for p in get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.set(p.name, get(p.name))
	return out


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
	a.crit = int(row.crit)
	a.res_cost = int(row.cost)
	a.push = int(row.push)
	a.status = row.status
	a.status_turns = int(row.status_turns)
	a.magic = row.magic == "1"
	a.element = row.get("element", "")
	a.windup = int(row.get("windup", "0"))
	a.cooldown = int(row.get("cooldown", "0"))
	a.first = maxi(1, int(row.get("first", "1")))
	a.summon = row.get("summon", "")
	a.count = int(row.get("count", "0"))
	a.limit = int(row.get("limit", "0"))
	a.spot = row.get("spot", "")
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
	a.spends = row.item
	a.cost = int(row.cost)
	return a


func uses_weapon_range() -> bool:
	return range_min == 0 and range_max == 0


func is_item() -> bool:
	return spends != ""


## Played by the boss rules at a phase's edges (CombatRules.boss_start, boss_end), never picked as the action.
func boss_move() -> bool:
	return windup > 0 or kind == "summon"


func hostile() -> bool:
	return kind == "attack" or kind == "hex"


## Spells are the magic skills a caster picks into their slots. The basic strike never counts.
func is_spell() -> bool:
	return magic and id != "strike"

class_name CombatUnit
extends RefCounted
## One piece on the board. Team 0 is the party, team 1 the enemy.

var name_key := ""
var cls: ClassDef
var team := 0
var cell := Vector2i.ZERO
var hp := 1
var tint := Color.GRAY
var deficiency: StringName = &""
var skills: Dictionary = {}
var member: Dictionary = {}  ## the RunState member this unit came from (party only)

var moved := false
var acted := false
var spooked := false
var move_origin := Vector2i.ZERO

# View state, animated by CombatBoard.
var vis := Vector2.ZERO  ## fractional grid position
var vis_h := 0.0
var hop := 0.0
var offset := Vector2.ZERO


static func from_member(m: Dictionary) -> CombatUnit:
	var d: CharacterDef = m.def
	var u := CombatUnit.new()
	u.name_key = d.name_key
	u.cls = d.class_def
	u.team = 0
	u.hp = maxi(1, m.hp)
	u.tint = d.tint
	u.deficiency = d.deficiency
	for k in d.class_def.skills:
		u.skills[k] = d.skill(k)
	for k in d.off_skills:
		u.skills[k] = d.skill(k)
	u.member = m
	return u


static func enemy(c: ClassDef) -> CombatUnit:
	var u := CombatUnit.new()
	u.name_key = c.name_key
	u.cls = c
	u.team = 1
	u.hp = c.max_hp
	u.tint = Color(0.72, 0.36, 0.33)
	u.skills = c.skills.duplicate()
	return u


func alive() -> bool:
	return hp > 0


func place(c: Vector2i, height: int) -> void:
	cell = c
	vis = Vector2(c)
	vis_h = height

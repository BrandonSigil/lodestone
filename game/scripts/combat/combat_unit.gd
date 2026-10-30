class_name CombatUnit
extends RefCounted
## One piece on the board. Team 0 is the party, team 1 the enemy.
## Stats are copied from the class and then scaled by the fight's difficulty dials (see apply_class).

var name_key := ""
var cls: ClassDef
var team := 0
var cell := Vector2i.ZERO
## Dropping to 0 makes a party piece bleed out ([USER] 2026-10-29: never death): it lies downed for a few of
## its own phases, when a teammate next to it can AID it back up, unless a foe knocks it out first.
var hp := 1:
	set(v):
		if v <= 0 and hp > 0 and team == 0:
			bleed = int(CombatRules.num("bleed_turns"))
		var fell := v <= 0 and hp > 0
		hp = v
		if fell:
			mark = {}
			for m: CombatUnit in minions:  # the pieces it called crumble with it
				if m.hp > 0:
					m.crumbled = true
					m.hp = 0
var bleed := 0  ## own phases left to be helped up while downed; 0 = standing, or out for the fight
var tint := Color.GRAY
var deficiency: StringName = &""
var skills: Dictionary = {}
var member: Dictionary = {}  ## the RunState member this unit came from (party only)
var belt: InventoryGrid = null  ## what this piece can use in a fight: its member's belt, spent in place

# Combat stats after scaling.
var max_hp := 1
var move := 4
var jump := 1
var attack := 0
var defense := 10  ## old d20 target, shown nowhere in fights now
var armor := 0  ## taken off every hit
var crit := 0  ## % crit chance on top of the base: the class, plus 5% a point of attack bonus (weapons, MORE HIT)
var damage := 1
var range_min := 1
var range_max := 1
var magic := false
var magic_power := 0  ## extra damage on spells and magic hits (the Lodestone's MORE MAGIC pick)
var abilities: Array[Ability] = []  ## strike first, then class skills, then picked spells
var spells: Array[StringName] = []  ## the spells picked into this unit's slots
var traits: Array[StringName] = []  ## combat traits from the class and the character, plus their perks (see CombatRules.TRAIT_*)

var moved := false
var acted := false
var spooked := false
var move_origin := Vector2i(-1000, -1000)  ## where this piece began its phase (set by CombatRules.begin_phase)
var move_spent := 0  ## move points walked this phase (hit and run walks the rest after a hit)
var leader := false  ## a fight's leader: beating it wins a "leader" fight (FightGoals)
var elite := false  ## from an elite group: tougher, and wears an ELITE badge
var protect := false  ## must not fall: if it does, the fight is lost (FightGoals)
var talk_to := false  ## the foe the hero can TALK to in this fight (FightGoals.talk)
var left_guard := false  ## walked away from a guard this phase and took the free hit, so the move can't be undone
var res_kind := ""  ## the job's resource: "mana", "rage", "charges" or "" (see ClassDef.resource)
var res_max := 0
var res := 0  ## what's left to spend this fight
var res_every := 0  ## charges: one back every this many own phases
var res_tick := 0  ## charges: own phases since the last one came back
var rage_bonus := 0  ## extra rage per hit dealt or taken (a blessing)
var crit_heal := 0  ## HP a crit heals the striker (a blessing)
var start_res := 0  ## mana, rage or charges added (or taken) at a fight's start (blessings and setbacks)
var statuses := {}  ## status id -> turns left (see CombatRules.STATUS_*)
# A boss's big moves (CombatRules.boss_start, boss_end).
var phase_no := 0  ## own phases begun this fight
var ready_at := {}  ## boss move id -> the own phase it can next be used on
var mark := {}  ## a big move marked and waiting: {"ability", "cells": Array[Vector2i], "left": own phases to go}
var summon_cells: Array[Vector2i] = []  ## where its called pieces stand, if its map marks any; else near it
var minions: Array = []  ## the pieces it called, standing or not
var summoner: CombatUnit = null  ## who called this piece
var crumbled := false  ## fell because its summoner did, not to the party

# View state, animated by CombatBoard.
var vis := Vector2.ZERO  ## fractional grid position
var vis_h := 0.0
var hop := 0.0
var offset := Vector2.ZERO
var sprite: StringName = &""  ## character art id (CharacterArt); "" draws the graybox Pawn
var facing := Vector2i(1, 0)  ## grid direction the piece looks along; the board turns it to screen space
var figure := &""  ## character or class id, picks the placeholder's colour, weapon and glyph when there is no sprite
var anim := "idle"  ## sprite anim playing (idle, walk, attack, cast, hurt)
var anim_start := 0.0  ## board time the anim started
var blink_at := -1.0  ## board time of the next blink while standing (CombatBoard._blink); -1 = not yet timed
var shown_hp := 1  ## HP the board draws; trails hp while hits animate


## mods: {"hp_pct": 100, "attack": 0, "defense": 0, "damage": 0, "move": 0}. Missing keys mean no change.
## Hits always land, so an attack bonus turns into crit chance and a defense bonus into armor.
## Levels and gear add flat "hp", "range_min", "range_max" and "magic_power" (see LevelRules, Game.weapon_mods).
func apply_class(c: ClassDef, mods: Dictionary = {}) -> void:
	cls = c
	max_hp = maxi(1, int(round(c.max_hp * float(mods.get("hp_pct", 100)) / 100.0)) + int(mods.get("hp", 0)))
	move = maxi(1, c.move + int(mods.get("move", 0)))
	jump = c.jump
	attack = c.attack + int(mods.get("attack", 0))
	defense = c.defense + int(mods.get("defense", 0))
	armor = maxi(0, c.armor + int(mods.get("defense", 0)))
	crit = c.crit + int(mods.get("attack", 0)) * int(CombatRules.num("crit_per_attack"))
	damage = maxi(1, c.damage + int(mods.get("damage", 0)))
	range_min = maxi(1, c.range_min + int(mods.get("range_min", 0)))
	range_max = maxi(range_min, c.range_max + int(mods.get("range_max", 0)))
	magic = c.magic
	magic_power = int(mods.get("magic_power", 0))
	abilities.clear()
	var strike := Db.ability("strike")
	if strike:
		abilities.append(strike)
	for id in c.abilities:
		var a := Db.ability(String(id))
		if a:
			abilities.append(a)
	traits = c.traits.duplicate()
	res_kind = c.resource
	res_max = c.resource_max
	res_every = c.resource_every
	rage_bonus = int(mods.get("rage_per_hit", 0))
	crit_heal = int(mods.get("crit_heal", 0))
	start_res = int(mods.get("start_res", 0))
	reset_resource()
	set_spells(c.default_spells())


## Swap the picked spells. Only spells from the class pool count, and only as many as it has slots.
func set_spells(ids: Array) -> void:
	for id in spells:
		var old := Db.ability(String(id))
		if old:
			abilities.erase(old)
	spells.clear()
	if cls == null:
		return
	for id in ids:
		var sid := StringName(id)
		if spells.size() >= cls.spell_slots or spells.has(sid) or not cls.spell_pool.has(sid):
			continue
		var a := Db.ability(String(sid))
		if a:
			spells.append(sid)
			abilities.append(a)


func has_trait(t: StringName) -> bool:
	return traits.has(t)


## spell_ids: the player's picks; null = the character's default loadout.
static func from_def(d: CharacterDef, mods: Dictionary = {}, spell_ids: Variant = null) -> CombatUnit:
	var u := CombatUnit.new()
	u.name_key = d.name_key
	u.apply_class(d.class_def, mods)
	u.set_spells(spell_ids if spell_ids is Array else d.default_spells())
	for t in d.traits + d.perks:
		if not u.traits.has(t):
			u.traits.append(t)
	u.team = 0
	u.hp = u.max_hp
	u.shown_hp = u.hp
	u.tint = d.tint
	u.figure = d.id
	u.sprite = CharacterArt.sprite_for(d.id)
	u.deficiency = d.deficiency
	for k in d.class_def.skills:
		u.skills[k] = d.skill(k)
	for k in d.off_skills:
		u.skills[k] = d.skill(k)
	return u


static func from_member(m: Dictionary, mods: Dictionary = {}) -> CombatUnit:
	var u := from_def(m.def, LevelRules.merge(mods, m.get("bonus", {})), m.get("spells"))
	u.hp = clampi(m.hp, 1, u.max_hp)
	u.shown_hp = u.hp
	u.member = m
	u.belt = m.get("belt")
	var ranks: Dictionary = m.get("ranks", {})
	for i in u.abilities.size():  # skills ranked up in the Lodestone menu carry their effects
		u.abilities[i] = LevelRules.ranked(u.abilities[i], int(ranks.get(u.abilities[i].id, 0)), Db.skill_ranks)
	return u


## Test benches (sandbox, map maker, sims) say what a fight has as counts. Each player piece without a
## belt gets one packed from them: a cell of potions and a cell of meat, as much as each cell holds.
static func pack_belts(units: Array, supplies: Dictionary) -> void:
	for u: CombatUnit in units:
		if u.team != 0 or u.belt != null:
			continue
		u.belt = InventoryGrid.create(RunState.BELT_COLS, RunState.BELT_ROWS)
		for pair in [[RunState.MED_ITEM, int(supplies.get("medicine", 0))], [RunState.FOOD_ITEM, int(supplies.get("food", 0))]]:
			if pair[1] > 0:
				u.belt.put(pair[0], RunState.shape_of(pair[0]), mini(pair[1], RunState.stack_of(pair[0])), RunState.stack_of(pair[0]))


static func enemy(c: ClassDef, mods: Dictionary = {}) -> CombatUnit:
	var u := CombatUnit.new()
	u.name_key = c.name_key
	u.figure = c.id
	u.sprite = CharacterArt.sprite_for(c.id)
	u.apply_class(c, mods)
	u.team = 1
	u.facing = Vector2i(-1, 0)
	u.hp = u.max_hp
	u.shown_hp = u.hp
	u.tint = Color(0.72, 0.36, 0.33)
	u.skills = c.skills.duplicate()
	return u


func alive() -> bool:
	return hp > 0


## Down but still on the board, waiting for AID.
func downed() -> bool:
	return hp <= 0 and bleed > 0


func done() -> bool:
	return acted and moved


func has_status(s: String) -> bool:
	return statuses.get(s, 0) > 0


## Enough of the job's resource left for this skill? Free skills (the basic hit, AID) always are.
func can_use(a: Ability) -> bool:
	return a.res_cost <= 0 or (res_kind != "" and res >= a.res_cost)


## A fight's start: mana and charges full, rage empty.
func reset_resource() -> void:
	res = clampi((0 if res_kind == "rage" else res_max) + start_res, 0, res_max)
	res_tick = 0


func sync_view() -> void:
	shown_hp = hp


func place(c: Vector2i, height: int) -> void:
	cell = c
	vis = Vector2(CombatGrid.ground(c))
	vis_h = height

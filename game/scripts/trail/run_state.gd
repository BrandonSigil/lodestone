class_name RunState
extends RefCounted
## Everything that lives for one trip and is lost when the Lodestone recalls the party.

const GOAL := 300  ## leagues to the end of the route
const WALL := 150
const PACK_COLS := 4  ## [USER] 2026-10-29: the first pack is 4 x 3
const PACK_ROWS := 3
const BELT_COLS := 2  ## [USER] 2026-10-29: each belt is a 2 x 1 strip where shapes count
const BELT_ROWS := 1
const FOOD_ITEM := "meat"  ## one food = one piece of meat in the pack (data/items.csv)
const MED_ITEM := "potion"  ## one medicine = one potion
const MAX_LINES := 200

var members: Array[Dictionary] = []  # {"def": CharacterDef, "hp": int, "bonus": stat mods from levels and gear, "belt": InventoryGrid}
var adventure := false  ## the E2E loop's run: kept through a wake-up, saved in meta (Game.start_adventure)
## Everything carried, as shapes in the party pack ([USER] 2026-10-29). Weapons sit on their members instead.
var pack: InventoryGrid = InventoryGrid.create(PACK_COLS, PACK_ROWS)
## What the party carries in the pack and on its belts, id -> count (gear bound to a member left out).
## Read-only: change it with add_item.
var items: Dictionary:
	get:
		var out := {}
		for g in grids():
			for it in g.items:
				if it.bound == "":
					out[it.id] = int(out.get(it.id, 0)) + int(it.get("n", 1))
		return out
var food: int:
	get: return item_count(FOOD_ITEM)
	set(v): add_item(FOOD_ITEM, maxi(0, v) - item_count(FOOD_ITEM))
var medicine: int:
	get: return item_count(MED_ITEM)
	set(v): add_item(MED_ITEM, maxi(0, v) - item_count(MED_ITEM))
var gold := 0
var morale := 70
var day := 1
var distance := 0
var passed_wall := false
var marks: Array[Dictionary] = []  # {"d": int, "kind": String} for the Lodestone map
var lines: PackedStringArray = []
var rng := RandomNumberGenerator.new()


static func create(defs: Array, seed_value: int, bonus_food := 0) -> RunState:
	var r := RunState.new()
	r.rng.seed = seed_value
	for d: CharacterDef in defs:
		r.join(d)
	r.food = 40 + bonus_food
	r.medicine = 3
	r.gold = 10
	return r


## A member joins at full HP. Gear they bring (the Wizard's books) is packed, bound to them.
func join(d: CharacterDef) -> Dictionary:
	var m := {"def": d, "hp": d.class_def.max_hp, "bonus": {}, "belt": InventoryGrid.create(BELT_COLS, BELT_ROWS)}
	members.append(m)
	if d.inventory_slots > 0:
		pack.put("books", shape_of("books"), 1, 1, String(d.id))
	return m


func note(line: String) -> void:
	lines.append(line)
	if lines.size() > MAX_LINES:
		lines.remove_at(0)


func strangeness() -> float:
	return clampf(float(distance) / GOAL, 0.0, 1.0)


func max_hp(m: Dictionary) -> int:
	return (m.def as CharacterDef).class_def.max_hp + int(m.get("bonus", {}).get("hp", 0))


func alive() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in members:
		if m.hp > 0:
			out.append(m)
	return out


func wiped() -> bool:
	return alive().is_empty()


func hurt(m: Dictionary, amount: int) -> void:
	if m.hp <= 0:
		return
	m.hp = clampi(m.hp - amount, 0, max_hp(m))
	if m.hp == 0:
		note(Txt.f("LOG_DOWN", Txt.t((m.def as CharacterDef).name_key)))


func heal_member(m: Dictionary, amount: int) -> void:
	if m.hp > 0:
		m.hp = mini(m.hp + amount, max_hp(m))


static func shape_of(id: String) -> Array[Vector2i]:
	return InventoryGrid.parse_shape(String(Db.items[id].shape))


static func stack_of(id: String) -> int:
	return maxi(1, int(Db.items[id].get("stack", 1)))


## The pack, then each member's belt.
func grids() -> Array[InventoryGrid]:
	var out: Array[InventoryGrid] = [pack]
	for m in members:
		if m.get("belt") != null:
			out.append(m.belt)
	return out


func item_count(id: String) -> int:
	var n := 0
	for g in grids():
		n += g.count(id)
	return n


## Adds n of an item to the pack (auto-placed), or with n < 0 spends it: from the pack first, then
## from the belts, so a meal on the walk only reaches a belt when the pack has none. What doesn't fit
## is left behind; returns how many that was.
func add_item(id: String, n: int) -> int:
	if n < 0:
		var left := -n
		for g in grids():
			left -= g.take(id, left)
		return 0
	var lost := pack.put(id, shape_of(id), n, stack_of(id))
	if lost > 0:
		note(Txt.f("LOG_OVERFLOW", [lost, Txt.t(String(Db.items[id].name_key))]))
	return lost


func add_food(n: int) -> void:
	add_item(FOOD_ITEM, n)


func add_medicine(n: int) -> void:
	add_item(MED_ITEM, n)


## Rebuilds the pack from InventoryGrid.to_save. Anything that no longer fits where it was
## (its shape changed in the data) is auto-placed again.
func load_pack(saved: Array) -> void:
	pack = InventoryGrid.create(PACK_COLS, PACK_ROWS)
	_load_into(pack, saved)


## The belts, member id -> InventoryGrid.to_save, for members already in the party. What no longer fits
## on a belt goes to the pack.
func load_belts(saved: Dictionary) -> void:
	for m in members:
		var id := String((m.def as CharacterDef).id)
		m.belt = InventoryGrid.create(BELT_COLS, BELT_ROWS)
		for e: Dictionary in _load_into(m.belt, saved.get(id, [])):
			add_item(String(e.id), int(e.get("n", 1)))


func belts_save() -> Dictionary:
	var out := {}
	for m in members:
		out[String((m.def as CharacterDef).id)] = (m.belt as InventoryGrid).to_save()
	return out


## Places saved entries where they were. Returns the ones that didn't fit there; on the pack those are
## auto-placed (and logged if lost), on a belt the caller decides.
func _load_into(g: InventoryGrid, saved: Array) -> Array:
	var later := []
	for e: Dictionary in saved:
		var id := String(e.get("id", ""))
		if not Db.items.has(id):
			continue
		var i := g.place(id, shape_of(id), int(e.get("rot", 0)), Vector2i(int(e.get("x", 0)), int(e.get("y", 0))), String(e.get("bound", "")))
		if i == -1:
			later.append(e)
		else:
			g.items[i].n = clampi(int(e.get("n", 1)), 1, stack_of(id))
	if g != pack:
		return later
	for e: Dictionary in later:
		var id := String(e.id)
		var lost := pack.put(id, shape_of(id), int(e.get("n", 1)), stack_of(id), String(e.get("bound", "")))
		if lost > 0:
			note(Txt.f("LOG_OVERFLOW", [lost, Txt.t(String(Db.items[id].name_key))]))
	return []


func food_need() -> int:
	var n := 0
	for m in alive():
		n += (m.def as CharacterDef).food_per_day
	return n

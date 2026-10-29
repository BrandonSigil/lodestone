class_name RunState
extends RefCounted
## Everything that lives for one trip and is lost when the Lodestone recalls the party.

const GOAL := 300  ## leagues to the end of the route
const WALL := 150
const CAPACITY := 12  ## group inventory slots
const FOOD_PER_SLOT := 10
const MED_PER_SLOT := 5
const MAX_LINES := 200

var members: Array[Dictionary] = []  # {"def": CharacterDef, "hp": int, "bonus": stat mods from levels and gear}
var adventure := false  ## the E2E loop's run: kept through a wake-up, saved in meta (Game.start_adventure)
var items := {}  ## gear found on the way (data/items.csv rows of kind gear), id -> count; one slot each
var food := 0
var medicine := 0
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
		r.members.append({"def": d, "hp": d.class_def.max_hp})
	r.food = 40 + bonus_food
	r.medicine = 3
	r.gold = 10
	r.add_food(0)  # clamp to capacity
	return r


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


func gear_slots() -> int:
	var n := 0
	for m in members:
		n += (m.def as CharacterDef).inventory_slots
	return n


func food_slots() -> int:
	return ceili(float(food) / FOOD_PER_SLOT)


func med_slots() -> int:
	return ceili(float(medicine) / MED_PER_SLOT)


func item_slots() -> int:
	var n := 0
	for id in items:
		n += int(items[id])
	return n


func used_slots() -> int:
	return gear_slots() + item_slots() + food_slots() + med_slots()


func item_count(id: String) -> int:
	return int(items.get(id, 0))


## Adds (or with n < 0 spends) gear. No room: the extra is left behind.
func add_item(id: String, n: int) -> void:
	var have := item_count(id)
	var want := maxi(0, have + n)
	if want > have:
		want = mini(want, have + CAPACITY - used_slots())
		if want < have + n:
			note(Txt.f("LOG_OVERFLOW", [have + n - want, Txt.t("SLOT_" + id.to_upper())]))
	if want <= 0:
		items.erase(id)
	else:
		items[id] = want


## Slot contents in display order, e.g. ["SLOT_BOOKS", "SLOT_FOOD", ...].
func slot_list() -> Array[String]:
	var out: Array[String] = []
	for i in gear_slots():
		out.append("SLOT_BOOKS")
	for id in items:
		for i in int(items[id]):
			out.append("SLOT_" + String(id).to_upper())
	for i in food_slots():
		out.append("SLOT_FOOD")
	for i in med_slots():
		out.append("SLOT_MEDICINE")
	return out


func add_food(n: int) -> void:
	food = maxi(0, food + n)
	var room := (CAPACITY - gear_slots() - item_slots() - med_slots()) * FOOD_PER_SLOT
	if food > room:
		note(Txt.f("LOG_OVERFLOW", [food - room, Txt.t("SLOT_FOOD")]))
		food = maxi(0, room)


func add_medicine(n: int) -> void:
	medicine = maxi(0, medicine + n)
	var room := (CAPACITY - gear_slots() - item_slots() - food_slots()) * MED_PER_SLOT
	if medicine > room:
		note(Txt.f("LOG_OVERFLOW", [medicine - room, Txt.t("SLOT_MEDICINE")]))
		medicine = maxi(0, room)


func food_need() -> int:
	var n := 0
	for m in alive():
		n += (m.def as CharacterDef).food_per_day
	return n

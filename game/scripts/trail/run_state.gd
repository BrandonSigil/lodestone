class_name RunState
extends RefCounted
## Everything that lives for one trip and is lost when the Lodestone recalls the party.

const GOAL := 300  ## leagues to the end of the route
const WALL := 150
const PACK_COLS := 4  ## [USER] 2026-10-29: the first pack is 4 x 3
const PACK_ROWS := 3
const BELT_COLS := 2  ## [USER] 2026-10-29: each belt is a 2 x 1 strip where shapes count
const BELT_ROWS := 1
const FOUND_COLS := 4  ## where pickups with no room wait for the player's call
const FOUND_ROWS := 2
const FOOD_ITEM := "meat"  ## one food = one piece of meat in the pack (data/items.csv)
const MED_ITEM := "potion"  ## one medicine = one potion
const MAX_LINES := 200

var members: Array[Dictionary] = []  # {"def": CharacterDef, "hp": int, "bonus": stat mods from levels and gear, "belt": InventoryGrid}
var adventure := false  ## the E2E loop's run: kept through a wake-up, saved in meta (Game.start_adventure)
## Everything carried, as shapes in the party pack ([USER] 2026-10-29). Weapons sit on their members instead.
var pack: InventoryGrid = InventoryGrid.create(PACK_COLS, PACK_ROWS)
## Adventure runs: a pickup that doesn't fit waits here until the player repacks, throws something away
## or sends the courier home ([USER] 2026-10-29). Not carried: it counts for nothing until packed.
var found: InventoryGrid = InventoryGrid.create(FOUND_COLS, FOUND_ROWS)
var courier_bag: InventoryGrid = null  ## the courier's saddlebag while it's being filled
var boons: Array[String] = []  ## blessings and setbacks held until home ([USER] omr-7, omr-8)
var food_extra := 0  ## food each day's meal costs on top (spoiling food) or less (a small belly), from boons
var meal := {}  ## a camp meal's buff: {"recipe": id, "fights": fights left} ([USER] omr-9); {} when none
var opened := {}  ## food kind -> portions left in an item already opened at camp (a ration feeds 5; one eaten leaves 4)
var last_picks := {}  ## member id -> the food kind they ate last night (the camp picker's SAME AS LAST NIGHT)
var meals_eaten := 0  ## camp meals this run
var on_pickup := Callable()  ## (id, n) after something is added to the pack: Game says when it counts toward a goal
var away: Array[Dictionary] = []  ## members sent home with a bag: {"member": Dictionary, "bag": InventoryGrid}
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
var morale := 70  ## the shelved trail's group morale; the adventure run uses hearts
## Adventure runs: per-character morale, id -> 0..100 ([USER] 2026-10-31; MoraleRules). The same dictionary as
## Game.meta.morale (Game links it), so it is kept for good. Empty on the shelved trail.
var hearts: Dictionary = {}
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


## The pack, then each member's belt, then the dog's saddlebag when he carries one ([USER] 2026-10-31, the inventory
## screen shows it): what is in it counts as carried, and is spent after the pack and the belts.
func grids() -> Array[InventoryGrid]:
	var out: Array[InventoryGrid] = [pack]
	for m in members:
		if m.get("belt") != null:
			out.append(m.belt)
	if courier_bag != null:
		out.append(courier_bag)
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
	if lost > 0 and adventure:
		lost = found.put(id, shape_of(id), lost, stack_of(id))
	if lost > 0:
		note(Txt.f("LOG_OVERFLOW", [lost, Txt.t(String(Db.items[id].name_key))]))
	if n > lost and on_pickup.is_valid():
		on_pickup.call(id, n - lost)
	return lost


## True while found things wait on the player's call. (The saddlebag is carried all the time now: its contents are
## inventory, not waiting.)
func overfull() -> bool:
	return not found.items.is_empty()


## The member who can carry a saddlebag home (the dog), or {} if none is in the party.
func courier() -> Dictionary:
	for m in alive():
		if (m.def as CharacterDef).saddlebag != Vector2i.ZERO:
			return m
	return {}


## The courier's bag, made on first use. null without a courier.
func open_courier_bag() -> InventoryGrid:
	var m := courier()
	if m.is_empty():
		return null
	if courier_bag == null:
		var size: Vector2i = (m.def as CharacterDef).saddlebag
		courier_bag = InventoryGrid.create(size.x, size.y)
	return courier_bag


## The courier takes the bag home and is out of the party until the party is home too.
func send_home(m: Dictionary) -> void:
	members.erase(m)
	away.append({"member": m, "bag": courier_bag if courier_bag != null else InventoryGrid.create(1, 1)})
	courier_bag = null
	note(Txt.f("LOG_SENT_HOME", Txt.t((m.def as CharacterDef).name_key)))


## Anything still in FOUND stays where the party stands, for good. (The saddlebag is part of the inventory: it stays.)
func leave_found() -> void:
	var n := 0
	for it in found.items:
		n += int(it.get("n", 1))
	found.items.clear()
	if n > 0:
		note(Txt.f("LOG_LEFT_BEHIND", n))


## Throws one thing out of a grid for good. Gear bound to a member can't go.
func throw_away(g: InventoryGrid, index: int) -> bool:
	if g.items[index].bound != "":
		return false
	var it := g.remove(index)
	note(Txt.f("LOG_THROWN", [int(it.get("n", 1)), Txt.t(String(Db.items[it.id].name_key))]))
	return true


## The party is home (a wake-up or walking into the village): whoever was sent home rejoins, and
## their bag is unpacked into the pack (what doesn't fit waits in FOUND).
func come_home() -> void:
	for a in away:
		members.append(a.member)
		note(Txt.f("LOG_CAME_HOME", Txt.t((a.member.def as CharacterDef).name_key)))
		for it in (a.bag as InventoryGrid).items:
			add_item(String(it.id), int(it.get("n", 1)))
	away.clear()


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


## Home: every village material leaves the pack, the belts and FOUND for the village's own count
## ([USER] 2026-10-29: materials bank themselves; gear and supplies stay packed). Returns id -> count.
func bank_materials() -> Dictionary:
	var out := {}
	var all := grids()
	all.append(found)
	for g in all:
		for i in range(g.items.size() - 1, -1, -1):
			var it: Dictionary = g.items[i]
			if String(Db.items[it.id].kind) == "material" or String(Db.items[it.id].get("bank", "")) == "1":  # fish go home to be cooked
				out[it.id] = int(out.get(it.id, 0)) + int(it.get("n", 1))
				g.remove(i)
	for id: String in out:
		note(Txt.f("LOG_BANKED", [int(out[id]), Txt.t(String(Db.items[id].name_key))]))
	return out


## FOUND, the courier's open bag and who is away, for the save.
func waiting_save() -> Dictionary:
	var gone := []
	for a in away:
		var m: Dictionary = a.member
		gone.append({"id": String((m.def as CharacterDef).id), "hp": int(m.hp), "bag": (a.bag as InventoryGrid).to_save(),
			"bag_size": [a.bag.cols, a.bag.rows], "belt": (m.belt as InventoryGrid).to_save()})
	var bag := {"cols": courier_bag.cols, "rows": courier_bag.rows, "items": courier_bag.to_save()} if courier_bag != null else {}
	return {"found": found.to_save(), "courier_bag": bag, "away": gone}


## Put back what waiting_save wrote. Call before Game.refresh_party, so the away aren't re-added.
func load_waiting(saved: Dictionary) -> void:
	found = InventoryGrid.create(FOUND_COLS, FOUND_ROWS)
	_load_into(found, saved.get("found", []))
	away.clear()
	for e: Dictionary in saved.get("away", []):
		var d := Db.character(StringName(String(e.get("id", ""))))
		if d == null:
			continue
		var size: Array = e.get("bag_size", [2, 2])
		var bag := InventoryGrid.create(int(size[0]), int(size[1]))
		_load_into(bag, e.get("bag", []))
		var belt := InventoryGrid.create(BELT_COLS, BELT_ROWS)
		_load_into(belt, e.get("belt", []))
		away.append({"member": {"def": d, "hp": maxi(1, int(e.get("hp", 1))), "bonus": {}, "belt": belt}, "bag": bag})
	var bag: Dictionary = saved.get("courier_bag", {})
	courier_bag = null
	if not bag.is_empty():
		courier_bag = InventoryGrid.create(int(bag.cols), int(bag.rows))
		_load_into(courier_bag, bag.get("items", []))


## Whether a member with this id was sent home.
func is_away(id: StringName) -> bool:
	return away.any(func(a: Dictionary) -> bool: return (a.member.def as CharacterDef).id == id)


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


## The portions a day's meal costs: everyone's food_per_day, plus or minus a blessing or setback.
func food_need() -> int:
	var n := 0
	for m in alive():
		n += (m.def as CharacterDef).food_per_day
	return maxi(0, n + food_extra)


## Food kinds that feed, plain food first (it only feeds), then by HP a portion heals (meat, then the fish grades).
func larder() -> Array[String]:
	var out: Array[String] = []
	for id: String in Db.items:
		if String(Db.items[id].kind) == "food" and int(Db.items[id].food) > 0 and portions_of(id) > 0:
			out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool:
		return heal_per_portion(a) < heal_per_portion(b) or (heal_per_portion(a) == heal_per_portion(b) and a < b))
	return out


## The HP one portion of this food heals (its heal column spread over its portions): meat 2, a good fish 3, a ration 0.
static func heal_per_portion(id: String) -> float:
	var row: Dictionary = Db.items.get(id, {})
	return float(row.get("heal", 0)) / maxf(1.0, float(row.get("food", 1)))


## Portions of one food kind: whole items plus what is left of an opened one.
func portions_of(id: String) -> int:
	return item_count(id) * int(Db.items.get(id, {}).get("food", 0)) + int(opened.get(id, 0))


## Every portion the pack holds.
func portions() -> int:
	var n := 0
	for id in larder():
		n += portions_of(id)
	return n


## Eat n portions of one food kind: the opened item's first, then whole items opened (their spare portions stay
## in opened). Returns how many were eaten (fewer when the kind runs out).
func take_portions(id: String, n: int) -> int:
	var got := 0
	while got < n:
		var left := int(opened.get(id, 0))
		if left > 0:
			var use := mini(left, n - got)
			opened[id] = left - use
			got += use
			if int(opened[id]) <= 0:
				opened.erase(id)
			continue
		if item_count(id) <= 0:
			break
		add_item(id, -1)
		opened[id] = int(Db.items[id].food)
	return got


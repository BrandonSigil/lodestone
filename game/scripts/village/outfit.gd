class_name Outfit
extends RefCounted
## What the party buys and packs in the village before heading out. Pure rules.
## Lives in Game.outfit while the player moves between the village and the map,
## and turns into the run's food, medicine and gold on departure.

const BASE_GOLD := 30
const COLS := 4
const ROWS := 3  ## 12 cells, same as RunState.CAPACITY

var gold := BASE_GOLD
var bag: InventoryGrid = InventoryGrid.create(COLS, ROWS)
var items_db: Dictionary = {}  # id -> item row (see Db.items)


static func create(items: Dictionary, purse: int) -> Outfit:
	var o := Outfit.new()
	o.items_db = items
	o.gold = purse
	return o


func shape_of(id: String) -> Array[Vector2i]:
	return InventoryGrid.parse_shape(items_db[id].shape)


## "" on success, else a text key saying why not.
func buy(id: String) -> String:
	var it: Dictionary = items_db[id]
	if gold < int(it.price):
		return "SHOP_NO_GOLD"
	if bag.add(id, shape_of(id)) == -1:
		return "SHOP_NO_ROOM"
	gold -= int(it.price)
	return ""


## Still in town, so selling refunds the full price. Gear bound to a member can't be sold.
func sell(index: int) -> bool:
	if bag.items[index].bound != "":
		return false
	var it: Dictionary = bag.remove(index)
	gold += int(items_db[it.id].price)
	return true


## Packs or unpacks gear that members bring along (the Wizard's books) so the pack
## matches the picked party. Returns false, and changes nothing, if a member's gear doesn't fit.
func sync_party(defs: Array) -> bool:
	var want := {}
	for d: CharacterDef in defs:
		if d.inventory_slots > 0:
			want[String(d.id)] = true
	for i in range(bag.items.size() - 1, -1, -1):
		var b: String = bag.items[i].bound
		if b != "" and not want.has(b):
			bag.remove(i)
	for id in want:
		if bag.items.any(func(it: Dictionary) -> bool: return it.bound == id):
			continue
		if bag.add("books", shape_of("books"), id) == -1:
			return false
	return true


## Whether this member's gear would fit if they joined now.
func gear_fits(d: CharacterDef) -> bool:
	if d.inventory_slots == 0:
		return true
	if bag.items.any(func(it: Dictionary) -> bool: return it.bound == String(d.id)):
		return true
	return not bag.find_room(shape_of("books")).is_empty()


func food() -> int:
	var n := 0
	for it in bag.items:
		n += int(items_db[it.id].food)
	return n


func medicine() -> int:
	var n := 0
	for it in bag.items:
		n += int(items_db[it.id].medicine)
	return n

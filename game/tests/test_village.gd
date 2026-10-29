extends TestCase
## Pack grid, shop and party gear rules for the village hub.


## Autoloads don't get _ready before a -s test script runs.
func _db() -> void:
	if Db.items.is_empty():
		Db.reload()


func _kit(gold := 100) -> Outfit:
	_db()
	return Outfit.create(Db.items, gold)


func test_shape_parse_and_rotate() -> void:
	var l := InventoryGrid.parse_shape("##/#.")
	eq(l, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)] as Array[Vector2i])
	var bar := InventoryGrid.parse_shape("###")
	eq(InventoryGrid.extent(InventoryGrid.rotated(bar, 1)), Vector2i(1, 3), "bar turns upright")
	eq(InventoryGrid.extent(InventoryGrid.rotated(bar, 2)), Vector2i(3, 1))
	for c in InventoryGrid.rotated(l, 3):
		ok(c.x >= 0 and c.y >= 0, "rotated shape is shifted to the origin")


func test_grid_overlap_and_bounds() -> void:
	var g := InventoryGrid.create(4, 3)
	var sq := InventoryGrid.parse_shape("##/##")
	eq(g.place("crate", sq, 0, Vector2i(0, 0)), 0)
	eq(g.place("crate", sq, 0, Vector2i(1, 1)), -1, "overlap refused")
	eq(g.place("crate", sq, 0, Vector2i(3, 0)), -1, "out of bounds refused")
	eq(g.item_at(Vector2i(1, 1)), 0)
	eq(g.item_at(Vector2i(2, 0)), -1)
	eq(g.used_cells(), 4)


func test_move_and_turn() -> void:
	var g := InventoryGrid.create(4, 3)
	var bar := InventoryGrid.parse_shape("###")
	g.place("x", bar, 0, Vector2i(0, 0))
	ok(g.move(0, Vector2i(0, 0), 1), "turn upright in place")
	eq(g.cells_of(0), [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)] as Array[Vector2i])
	ok(not g.move(0, Vector2i(0, 1), 1), "would stick out the bottom")
	eq(g.items[0].pos, Vector2i(0, 0), "failed move changes nothing")


func test_find_room_tries_turning() -> void:
	var g := InventoryGrid.create(4, 3)
	g.place("a", InventoryGrid.parse_shape("###"), 0, Vector2i(1, 0))
	g.place("b", InventoryGrid.parse_shape("###"), 0, Vector2i(1, 1))
	g.place("c", InventoryGrid.parse_shape("###"), 0, Vector2i(1, 2))
	var room := g.find_room(InventoryGrid.parse_shape("###"))
	eq(room.get("pos"), Vector2i(0, 0), "only the left column is free")
	eq(room.get("rot"), 1)


func test_buy_and_sell() -> void:
	var k := _kit(10)
	eq(k.buy("crate"), "")
	eq(k.gold, 1)
	eq(k.buy("ration"), "SHOP_NO_GOLD")
	eq(k.food(), 36)
	ok(k.sell(0), "sell refunds in town")
	eq(k.gold, 10)
	eq(k.bag.items.size(), 0)


func test_pack_full() -> void:
	var k := _kit(100)
	eq(k.buy("crate"), "")
	eq(k.buy("crate"), "")
	eq(k.buy("crate"), "SHOP_NO_ROOM", "a third 2x2 can't fit a 4x3 pack")
	eq(k.buy("sack"), "")
	eq(k.buy("sack"), "")
	eq(k.bag.used_cells(), 12)
	eq(k.buy("ration"), "SHOP_NO_ROOM")
	eq(k.gold, 74, "refused buys cost nothing")


func test_wizard_books() -> void:
	var k := _kit(100)
	var wiz: CharacterDef = load("res://data/characters/wizard.tres")
	var lead: CharacterDef = load("res://data/characters/lead.tres")
	ok(k.sync_party([lead, wiz]))
	eq(k.bag.used_cells(), wiz.inventory_slots, "books take the wizard's pack space")
	ok(not k.sell(0), "books can't be sold")
	k.sync_party([lead])
	eq(k.bag.used_cells(), 0, "books leave with the wizard")
	k.buy("crate")
	k.buy("crate")
	ok(not k.gear_fits(wiz), "no room for books in a full pack")
	ok(not k.sync_party([lead, wiz]))


func test_items_data() -> void:
	_db()
	var keys := {}
	for row in CsvTable.load_rows("res://text/placeholder.csv"):
		keys[row["keys"]] = true
	ok(Db.items.has("books"), "books item exists for the wizard")
	for id in Db.items:
		var it: Dictionary = Db.items[id]
		var cells := InventoryGrid.parse_shape(it.shape).size()
		ok(cells > 0, "%s has a shape" % id)
		ok(keys.has(it.name_key), "%s name key" % id)
		ok(int(it.get("stack", 1)) >= 1, "%s stack size" % id)
		# leaving the village turns food and medicine into meat and potions, so no item may pack denser
		ok(int(it.food) <= cells * RunState.stack_of(RunState.FOOD_ITEM), "%s food density" % id)
		ok(int(it.medicine) <= cells * RunState.stack_of(RunState.MED_ITEM), "%s medicine density" % id)
	eq(Vector2i(Outfit.COLS, Outfit.ROWS), Vector2i(RunState.PACK_COLS, RunState.PACK_ROWS), "village pack matches the run pack")
	for q in Db.quests:
		ok(keys.has(q.text_key), "quest %s text key" % q.id)


func test_outfit_becomes_run() -> void:
	var k := _kit(30)
	k.buy("sack")
	k.buy("salve")
	var run := RunState.create(members_of(["lead"]), 1)
	run.food = k.food()
	run.medicine = k.medicine()
	eq(run.pack.used_cells() <= k.bag.used_cells(), true, "the run pack never needs more cells than the outfit")


func test_pack_drag_turn_sell() -> void:
	var k := _kit(30)
	k.buy("sack")
	var pv := PackView.new()
	pv.setup(k)
	var c := PackView.CELL
	pv._pick(Vector2(c * 1.5, c * 0.5))  # grab the sack by its right cell
	pv._turn(Vector2.ZERO)
	pv._drop(Vector2(c * 2.5, c * 1.5))
	eq(k.bag.items[0].rot, 1, "turned while held")
	eq(k.bag.cells_of(0), [Vector2i(2, 1), Vector2i(2, 2)] as Array[Vector2i])
	pv._pick(Vector2(c * 2.5, c * 1.5))
	pv._drop(pv._bin_rect().get_center())
	eq(k.bag.items.size(), 0, "dropped on SELL")
	eq(k.gold, 30)
	pv.free()

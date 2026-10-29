extends TestCase
## The shaped party pack in the live loop ([USER] 2026-10-29, inventory step 1): a 4 x 3 grid,
## small stacks, auto-place on pickup, rearranging by hand, and the layout kept in the save.


func _db() -> void:
	if Db.items.is_empty():
		Db.reload()


func _empty_run() -> RunState:
	_db()
	return RunState.create([], 1, -40)  # no food, so only the potions are packed


func test_stacks_fill_before_new_cells() -> void:
	var g := InventoryGrid.create(4, 3)
	var one: Array[Vector2i] = [Vector2i.ZERO]
	eq(g.put("meat", one, 25, 10), 0)
	eq(g.items.size(), 3, "25 meat is 10 + 10 + 5")
	eq(g.count("meat"), 25)
	eq(g.put("meat", one, 5, 10), 0)
	eq(g.items.size(), 3, "topping up the open stack takes no new cell")
	eq(g.take("meat", 12), 12)
	eq(g.count("meat"), 18)
	eq(g.items.size(), 2, "the smallest stack empties first and frees its cell")


func test_food_and_potions_are_stacks_in_the_pack() -> void:
	var r := _empty_run()
	eq(r.medicine, 3)
	eq(r.pack.used_cells(), 1, "3 potions share one cell")
	r.food = 23
	eq(r.food, 23)
	eq(r.pack.used_cells(), 4, "23 meat takes 3 cells")
	r.food -= 20
	eq(r.food, 3)
	eq(r.pack.used_cells(), 2)
	r.medicine = 4
	eq(r.pack.used_cells(), 3, "a fourth potion opens a second cell")


func test_full_pack_leaves_the_rest_behind() -> void:
	var r := _empty_run()
	eq(r.add_item(RunState.FOOD_ITEM, 200), 90, "11 free cells hold 110 meat")
	eq(r.food, 110)
	eq(r.add_item("rope", 1), 1, "no room for the rope")
	ok(r.lines[r.lines.size() - 1] != "", "the loss is written in the log")


func test_pickup_turns_to_fit() -> void:
	var r := _empty_run()
	r.medicine = 0
	# meat in columns 1 to 3 leaves only the left column free, one cell wide
	for y in 3:
		r.pack.place("meat", RunState.shape_of("meat"), 0, Vector2i(3, y))
		r.pack.place("meat", RunState.shape_of("meat"), 0, Vector2i(1, y))
		r.pack.place("meat", RunState.shape_of("meat"), 0, Vector2i(2, y))
	eq(r.add_item("rope", 1), 0, "the 2-cell rope fits standing up")
	var i := r.pack.items.size() - 1
	eq(r.pack.items[i].rot % 2, 1, "turned to fit")
	eq(r.pack.cells_of(i), [Vector2i(0, 0), Vector2i(0, 1)] as Array[Vector2i])


func test_the_layout_is_kept_in_the_save() -> void:
	var r := _empty_run()
	r.food = 15
	r.add_item("rope", 1)
	var rope := r.pack.items.size() - 1
	ok(r.pack.move(rope, Vector2i(2, 1), 1), "moved and turned by hand")
	var back := _empty_run()
	back.load_pack(JSON.parse_string(JSON.stringify(r.pack.to_save())))
	eq(back.food, 15)
	eq(back.medicine, 3)
	eq(back.item_count("rope"), 1)
	eq(JSON.stringify(back.pack.to_save()), JSON.stringify(r.pack.to_save()), "same spots, turns and stacks")


func test_the_pack_box_moves_and_turns() -> void:
	var r := _empty_run()
	r.add_item("rope", 1)
	var pv := PackView.new()
	pv.setup_bag(r.pack, Db.items, Callable(), 50.0)
	var rope := r.pack.items.size() - 1
	var at: Vector2i = r.pack.items[rope].pos
	pv._pick((Vector2(at) + Vector2(0.5, 0.5)) * 50.0)
	pv._turn(Vector2.ZERO)
	pv._drop(Vector2(3.5, 0.5) * 50.0)
	eq(r.pack.cells_of(r.pack.items.size() - 1), [Vector2i(3, 0), Vector2i(3, 1)] as Array[Vector2i], "dragged and turned")
	pv.free()


func test_old_saves_still_load() -> void:
	_db()
	var saved := Game.meta.duplicate(true)
	var was_on := Game.save_enabled
	Game.save_enabled = false
	Game.meta.pack = {"food": 12, "medicine": 2, "gold": 5, "items": {"rope": 1}, "hp": {}}
	Game.start_adventure()
	eq(Game.run.food, 12)
	eq(Game.run.medicine, 2)
	eq(Game.run.item_count("rope"), 1)
	Game.save_adventure()
	ok(Game.meta.pack.has("grid"), "saved as a layout from now on")
	Game.meta = saved
	Game.save_enabled = was_on
	Game.run = null

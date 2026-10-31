class_name ContainerUi
extends RefCounted
## A container's grid beside the pack ([USER] 2026-10-31, docs/design/loot-containers.md): a chest, barrel, crate, body or
## pile opened with F or a click. Drag to take, click to send an item to the first spot that fits, R turns, TAKE ALL sends
## what fits and stops at the first thing that does not, and things can be put back. Shapes are kept. The grid is the
## shared PackView, so the dog's saddlebag and the after-fight loot grid are the same piece.


## The size of a container type, from data/containers.csv ({"cols", "rows"}).
static func size_of(type: String) -> Vector2i:
	for r in CsvTable.load_rows("res://data/containers.csv"):
		if r.type == type:
			return Vector2i(int(r.cols), int(r.rows))
	return Vector2i(2, 2)


## "meat:4;potion:1;rope:1;gold:10" into a grid; coins come back as a count (they do not take cells). food and medicine
## become meat and potion stacks. Items the game does not know are skipped. Returns the gold.
static func fill_grid(grid: InventoryGrid, items: String) -> int:
	var gold := 0
	for part in items.split(";", false):
		var kv := part.split(":")
		if kv.size() != 2:
			continue
		var id := kv[0].strip_edges()
		var n := int(kv[1])
		match id:
			"gold":
				gold += n
				continue
			"food":
				id = RunState.FOOD_ITEM
			"medicine":
				id = RunState.MED_ITEM
		if not Db.items.has(id):
			push_warning("container item '%s' is not an item" % id)
			continue
		grid.put(id, RunState.shape_of(id), n, RunState.stack_of(id))
	return gold


## A group's loot string ("food:+6;gold:+10;unlock:x") split in two: "items" (food, medicine and carried things: they go
## into the shared loot grid) and "now" (coins, unlocks and the rest: they apply at once). Both stay in effect format.
static func split_loot(loot: String) -> Dictionary:
	var items: PackedStringArray = []
	var now: PackedStringArray = []
	for part in loot.split(";", false):
		var key := part.split(":")[0].strip_edges()
		if key == "food" or key == "medicine" or Db.items.has(key):
			items.append(part)
		else:
			now.append(part)
	return {"items": ";".join(items), "now": ";".join(now)}


## Builds the screen in `box`: the pack, the dog's saddlebag when he is along, and the container, with TAKE ALL and CLOSE.
## `changed` runs after every move (the host saves and redraws its HUD), `close` shuts the box.
static func fill(box: VBoxContainer, container: InventoryGrid, title: String, changed: Callable, close: Callable, close_text := "") -> PackView:
	var run := Game.run
	var cell := 46.0
	var view := PackView.new()
	view.setup_bag(run.pack, Db.items, Callable(), cell)
	view.label_color = Riso.CREAM
	var pack_w := run.pack.cols * cell
	view.add_area(container, Vector2(pack_w + 30.0, 0), title, null, 0)
	var saddle: InventoryGrid = run.open_courier_bag()
	if saddle != null:
		view.add_area(saddle, Vector2(0, run.pack.rows * cell + 16.0), Txt.f("UI_COURIER_BAG", Txt.t((run.courier().def as CharacterDef).name_key)), null, 0)
	view.areas[0]["click_to"] = 1  # a click on something in the pack puts it into the container
	view.changed.connect(changed)
	box.add_child(view)
	var take := Button.new()
	take.text = Txt.t("UI_BOX_TAKE_ALL")
	take.custom_minimum_size = Vector2(460, 44)
	take.add_theme_font_size_override("font_size", 19)
	take.pressed.connect(func() -> void:
		if not view.send_all(1, 0):
			view.flash = "UI_BOX_FULL"
			view.queue_redraw())
	box.add_child(take)
	var done := Button.new()
	done.text = close_text if close_text != "" else Txt.t("UI_BOX_CLOSE")
	done.custom_minimum_size = Vector2(460, 44)
	done.add_theme_font_size_override("font_size", 19)
	done.pressed.connect(close)
	box.add_child(done)
	return view

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


## Builds the screen in `box` as two windows side by side ([USER] 2026-11-01, like BG3's bags or WoW's two windows): the
## inventory (the pack, the dog's saddlebag right beside it) and the container's own window with TAKE ALL and CLOSE. Belts and
## the party live on the full inventory page (I). `changed` runs after every move (the host saves and redraws its HUD),
## `close` shuts the box. `coins`: the gold it gave, a gold icon and +N under the container's grid.
static func fill(box: VBoxContainer, container: InventoryGrid, title: String, changed: Callable, close: Callable, close_text := "", coins := 0) -> PackView:
	var view := PackView.new()
	view.setup_bag(Game.run.pack, Db.items, Callable(), CELL)
	var buttons := [[Txt.t("UI_BOX_TAKE_ALL"), func() -> void:
		if not view.send_all(1, 0):
			view.flash = "UI_BOX_FULL"
			view.queue_redraw()],
		[close_text if close_text != "" else Txt.t("UI_BOX_CLOSE"), close]]
	windows(view, container, title, buttons, true, "+%d" % coins if coins > 0 else "", ActionInfo.icon("gold"))
	view.changed.connect(changed)
	box.add_child(view)
	bare(box, view)
	return view


const CELL := 46.0
const GAP := 18.0  ## between the two windows
const BUTTON_H := 40.0


## Lays out a PackView set up on the pack as two windows: the inventory (pack, the courier's saddlebag beside it, the bin
## under them if the view has one) and `other` (a container, the loot, or FOUND) in its own window to the right, its
## buttons ([text, callable] pairs) under its grid. `other` becomes area 1 (a click there sends to the pack), the saddlebag
## area 2. pack_to_other: a click on something in the pack sends it over.
static func windows(view: PackView, other: InventoryGrid, other_title: String, buttons: Array, pack_to_other: bool, note := "", note_icon: Texture2D = null) -> Array[Button]:
	var run := Game.run
	var cell := view.cell
	var pad := PackView.WINDOW_PAD
	var top := Vector2(pad, pad + PackView.WINDOW_TITLE)
	var right := top.x + run.pack.cols * cell
	var saddle: InventoryGrid = run.open_courier_bag()
	var head := PackView.FACE_ROW if saddle != null else 0.0  # the dog's picture over his saddlebag, no words
	var bottom := top.y + head + run.pack.rows * cell
	view.move_area(0, top + Vector2(0, head))  # level with the saddlebag's grid, under his picture
	view.areas[0]["click_to"] = 1 if pack_to_other else -1
	var saddle_at := Vector2(right + 22.0, top.y)
	if saddle != null:
		right = saddle_at.x + saddle.cols * cell
		bottom = maxf(bottom, top.y + head + saddle.rows * cell)
	if view.bin.is_valid():  # THROW AWAY: a thin bar under the grids
		view.place_bin(Rect2(Vector2(top.x, bottom + 14.0), Vector2(right - top.x, 32.0)), "UI_THROW", "UI_BOUND_THROW")
		bottom += 46.0
	view.flash_at = Vector2(top.x, bottom + 14.0)  # a line for "no room" and the like
	bottom += 26.0
	var left_w := right + pad
	# the other window
	var ox := left_w + GAP
	var ow := maxf(other.cols * cell, 250.0)
	view.add_area(other, Vector2(ox + pad, top.y + head), "", null, 0)
	if saddle != null:
		var who: CharacterDef = run.courier().def
		view.add_area(saddle, saddle_at, Txt.f("UI_COURIER_BAG", Txt.t(who.name_key)), face_of(String(who.id)), 0)
	var y := top.y + head + other.rows * cell + 12.0
	if note != "":
		var lines := view.add_note(note, Vector2(ox + pad, y), ow, note_icon)
		y += PackView.NOTE_LINE * lines + 8.0
	var made: Array[Button] = []
	for b in buttons:
		made.append(view.add_button(String(b[0]), Rect2(Vector2(ox + pad, y), Vector2(ow, BUTTON_H)), b[1]))
		y += BUTTON_H + 8.0
	var h := maxf(bottom, y - 8.0) + pad
	view.add_window(Rect2(Vector2.ZERO, Vector2(left_w, h)), Txt.t("UI_PACK"))
	view.add_window(Rect2(Vector2(ox, 0), Vector2(ow + pad * 2.0, h)), other_title)
	return made


## The two windows bring their own frames: the dialogue holding them goes bare (no panel of its own) and stands centred.
## ([USER] 2026-11-01 "Menus spill out of the window"): if the view is taller than the room above the bottom frame, the
## whole thing shrinks to fit.
const FRAME_ROOM := 150.0  ## the bottom frame and a margin above it

static func bare(box: Control, view: Control = null) -> void:
	var n: Node = box.get_parent()
	while n != null and not n is PanelContainer:
		n = n.get_parent()
	if n == null:
		return
	var panel := n as PanelContainer
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	if view != null and panel.is_inside_tree():  # decided now, before the pop-in tween takes the scale as its target
		var vs := panel.get_viewport_rect().size
		var room := Vector2(vs.x - 32.0, vs.y - FRAME_ROOM - 16.0)  # a menu stands at the top, 16 down
		var need := view.get_combined_minimum_size()
		var k := minf(1.0, minf(room.x / maxf(need.x, 1.0), room.y / maxf(need.y, 1.0)))
		if k < 1.0:
			panel.scale = Vector2(k, k)
	_centre_later(panel)


static func _centre_later(panel: Control) -> void:
	if not panel.is_inside_tree():
		return
	await panel.get_tree().process_frame
	if not is_instance_valid(panel) or not panel.is_inside_tree():
		return
	panel.reset_size()
	panel.position.x = (panel.get_viewport_rect().size.x - panel.size.x * panel.scale.x) * 0.5


## A character's portrait (art/source/portraits/<id>.png), or null before Brandon has drawn one.
static func face_of(id: String) -> Texture2D:
	var pf := "res://art/source/portraits/%s.png" % id
	return load(pf) if ResourceLoader.exists(pf) else null

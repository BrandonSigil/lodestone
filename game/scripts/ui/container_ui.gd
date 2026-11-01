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
## `purse`: a box's state whose "coins" still wait in it; they show under its grid and TAKE ALL moves them to the party's gold
## ([USER] 2026-11-01 "Take all should move money over too").
static func fill(box: VBoxContainer, container: InventoryGrid, title: String, changed: Callable, close: Callable, close_text := "", coins := 0, purse := {}) -> PackView:
	var view := PackView.new()
	view.setup_bag(Game.run.pack, Db.items, Callable(), CELL)
	var waiting := int(purse.get("coins", 0))
	var coin_note := {}
	# ([USER] 2026-11-01: "I want X's at the top right and take all should be over the bottom center of the frame, like half
	# way in the menu and half way out"): an X on each window closes, TAKE ALL straddles the container window's bottom edge.
	# After a fight the window keeps its labelled CONTINUE button: there it moves the game on, not just shuts a box.
	var buttons := [[Txt.t("UI_BOX_TAKE_ALL"), func() -> void:
		if int(purse.get("coins", 0)) > 0:
			Game.run.gold += int(purse.coins)
			purse.coins = 0
			coin_note.text = ""
			coin_note.icon = null
			view.gold_note.text = str(Game.run.gold)
			view.queue_redraw()
			changed.call()
		if not view.send_all(1, 0):
			view.flash = "UI_BOX_FULL"
			view.queue_redraw()]]
	if close_text != "":
		buttons.append([close_text, close])
	var note := str(waiting) if waiting > 0 else ("+%d" % coins if coins > 0 else "")
	windows(view, container, title, buttons, true, note, ActionInfo.icon("gold"), close if close_text == "" else Callable())
	if waiting > 0:  # the box's own coin line (not the party's gold line under the pack, which windows() adds after it)
		for n: Dictionary in view.notes:
			if n != view.gold_note and String(n.text) == note:
				coin_note = n
				break
	view.changed.connect(changed)
	box.add_child(view)
	bare(box, view)
	return view


const CELL := 46.0
const GAP := 18.0  ## between the two windows
const BUTTON_H := 40.0
const X_SIZE := 34.0  ## the close X at a window's top right
const MIN_BUTTON_W := 150.0  ## the narrowest a window gets for its TAKE ALL across the bottom edge


## Lays out a PackView set up on the pack as two windows: the inventory (pack, the courier's saddlebag beside it, the bin
## under them if the view has one) and `other` (a container, the loot, or FOUND) in its own window to the right, its
## buttons ([text, callable] pairs) under its grid. `other` becomes area 1 (a click there sends to the pack), the saddlebag
## area 2. pack_to_other: a click on something in the pack sends it over.
## x_close: when set, each window gets a small X at its top right that calls it, and a single button sits centred across
## the bottom edge of the other window, half in and half out.
static func windows(view: PackView, other: InventoryGrid, other_title: String, buttons: Array, pack_to_other: bool, note := "", note_icon: Texture2D = null, x_close := Callable()) -> Array[Button]:
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
	# the party's gold, always in sight under the pack ([USER] 2026-11-01 "the party menu should say total gold too"); the
	# "no room" line shares its row, so the window ends right under it
	view.add_note(str(run.gold), Vector2(top.x, bottom + 8.0), right - top.x, ActionInfo.icon("gold"))
	view.gold_note = view.notes.back()
	view.flash_at = Vector2(top.x + 90.0, bottom + 8.0)
	bottom += PackView.NOTE_LINE + 8.0
	var left_w := right + pad
	# the other window hugs its grid ([USER] 2026-11-01 "these windows should fit the size"): only as wide as the title and
	# its button need beyond that, and as tall as its own grid, note and button, not the pack's height
	var ox := left_w + GAP
	var title_w := Riso.font().get_string_size(other_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 24.0
	var ow := maxf(other.cols * cell, maxf(title_w + (X_SIZE if x_close.is_valid() else 0.0), MIN_BUTTON_W - pad))
	view.add_area(other, Vector2(ox + pad, top.y + head), "", null, 0)
	if saddle != null:
		var who: CharacterDef = run.courier().def
		view.add_area(saddle, saddle_at, Txt.f("UI_COURIER_BAG", Txt.t(who.name_key)), face_of(String(who.id)), 0)
	var y := top.y + head + other.rows * cell + 12.0
	if note != "":
		var lines := view.add_note(note, Vector2(ox + pad, y), ow, note_icon)
		y += PackView.NOTE_LINE * lines + 8.0
	var made: Array[Button] = []
	var straddle := x_close.is_valid() and buttons.size() == 1
	if straddle:
		y += 8.0  # room above the button's top half
	else:
		for b in buttons:
			made.append(view.add_button(String(b[0]), Rect2(Vector2(ox + pad, y), Vector2(ow, BUTTON_H)), b[1]))
			y += BUTTON_H + 8.0
	var lh := bottom + pad
	var oh := y - 8.0 + pad
	var other_w := ow + pad * 2.0
	view.add_window(Rect2(Vector2.ZERO, Vector2(left_w, lh)), Txt.t("UI_PACK"))
	view.add_window(Rect2(Vector2(ox, 0), Vector2(other_w, oh)), other_title)
	view.custom_minimum_size.y = maxf(view.custom_minimum_size.y, maxf(lh, oh))
	if straddle:
		var bw := minf(other_w - 16.0, 200.0)
		made.append(view.add_button(String(buttons[0][0]), Rect2(Vector2(ox + (other_w - bw) * 0.5, oh - BUTTON_H * 0.5), Vector2(bw, BUTTON_H)), buttons[0][1]))
		view.custom_minimum_size.y = maxf(view.custom_minimum_size.y, oh + BUTTON_H * 0.5)
	if x_close.is_valid():
		for wx in [left_w, ox + other_w]:
			view.add_button("X", Rect2(Vector2(wx - X_SIZE - 10.0, 10.0), Vector2(X_SIZE, X_SIZE)), x_close)
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

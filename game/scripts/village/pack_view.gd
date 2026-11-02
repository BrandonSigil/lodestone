class_name PackView
extends Control
## The pack grid you arrange by hand: drag an item to move it, R or right-click turns it,
## and drop it on the bin to be rid of it (SELL in the village, THROW AWAY on the road). Gear bound
## to a member (the Wizard's books) can be moved and turned but not binned. Used for the village
## outfit and the run's pack.
## The run's view also shows each member's belt as its own small grid: drag between them to fill a
## belt from the pack. A stack dropped on a stack of the same thing tops it up.
## Windows ([USER] 2026-11-01, like BG3's bags or WoW's two windows): one view can draw a framed window behind each group
## of grids (the inventory, the loot or container), so a drag still crosses from one window to the other.

signal changed

const CELL := 72.0
const SELL_SIZE := Vector2(150, 110)
const LABEL_H := 20.0  ## room above a labeled grid for its name
const FACE_ROW := 40.0  ## room above a grid whose only name is a picture ([USER] 2026-11-01: "Just a doggo pic will do")
const FACE := 34.0  ## that picture's side
## Kinds Riso.draw_item_icon draws an icon for. Every other kind (gear, material, meal, tonic...) shows its name instead,
## so nothing in the pack is a blank square (Brandon's bug, 2026-11-01: a tonic looked like an empty slot).
const ICON_KINDS := ["food", "crate", "med", "herb", "book"]

var bag: InventoryGrid  ## the first grid (the pack)
var areas: Array[Dictionary] = []  ## {"bag": InventoryGrid, "at": Vector2 (top-left here), "label": String}
var db: Dictionary = {}  ## item rows (Db.items)
var bin := Callable()  ## (grid, index) -> bool: false if refused; empty means no bin
var bin_key := "UI_SELL"  ## the bin's text
var refused_key := "UI_BOUND"  ## shown when the bin refuses
var bin_rect := Rect2()  ## where the bin is; setup_bag puts it right of the first grid
var cell := CELL
var held := -1  ## index of the item being dragged
var held_area := -1  ## which grid it's from
var held_rot := 0
var press_at := Vector2.ZERO  ## where the drag began: a release this close is a click
var grab := Vector2i.ZERO  ## which cell of the rotated shape the mouse holds
var mouse := Vector2.ZERO
var flash := ""  ## text key shown under the grids after a refused action
var label_color := Riso.CREAM  ## grid names; the run's box is dark
## Party cards ([USER] 2026-10-30: pick who eats or drinks): drop a food or potion stack on one, or after EAT
## or DRINK click one. {"rect": Rect2, "name": String, "hp": int, "max_hp": int, "face": Texture2D or null}.
var targets: Array[Dictionary] = []
var target_gain := Callable()  ## (card index, item id) -> HP that member would gain from one
var use_on := Callable()  ## (card index, item id) -> bool: one was used on them
var choosing := ""  ## the item EAT or DRINK picked: the cards show what each would gain; Esc cancels
const TARGET_SIZE := Vector2(132, 58)
## Framed windows drawn behind the grids: {"rect": Rect2, "title": String}.
var windows: Array[Dictionary] = []
const WINDOW_PAD := 34.0  ## from a window's edge to its grids, clear of the frame's corner leaves
const WINDOW_TITLE := 46.0  ## room for a window's title plate
var sections := false  ## windows drawn as the kit's section cards (inside a bigger window: the win screen)
var notes: Array[Dictionary] = []  ## lines of text in a window: {"text", "at" (top-left), "width"}
const NOTE_LINE := 24.0
var gold_note := {}  ## in windows: the party's gold under the pack, kept current when coins come over (one of `notes`)
var flash_at := Vector2(-1, -1)  ## where the flash line goes in windows; unset, it sits under everything
var saddle_inset := false  ## as sections: the dog's saddlebag (the grid with a round face) stands in its own inset
const INSET_PAD := 12.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL


## The village outfit, with its sell box.
func setup(kit: Outfit) -> void:
	setup_bag(kit.bag, kit.items_db, func(g: InventoryGrid, i: int) -> bool: return g == kit.bag and kit.sell(i))


func setup_bag(grid: InventoryGrid, items_db: Dictionary, bin_cb := Callable(), cell_size := CELL) -> void:
	bag = grid
	db = items_db
	bin = bin_cb
	cell = cell_size
	areas = [{"bag": grid, "at": Vector2.ZERO, "label": ""}]
	bin_rect = Rect2(Vector2(cell * grid.cols + 40, cell * grid.rows - SELL_SIZE.y), SELL_SIZE) if bin.is_valid() else Rect2()
	_fit_size()


## Moves the bin (a run's PACK box lays it out round its grids).
func place_bin(r: Rect2, key: String, refused: String) -> void:
	bin_rect = r
	bin_key = key
	refused_key = refused
	_fit_size()


## Another grid in the same view, its top-left at `at`. A `label` takes LABEL_H above it; a `portrait` instead takes
## FACE_ROW for a picture with no words (the dog's face on his saddlebag, a member's on their belt). The same helper
## holds a container's or a loot grid, with or without a name.
func add_area(grid: InventoryGrid, at: Vector2, label := "", portrait: Texture2D = null, click_to := -1) -> void:
	areas.append({"bag": grid, "at": at + Vector2(0, head_room(label, portrait)), "label": label, "portrait": portrait,
		"face_at": at, "click_to": click_to})
	_fit_size()


## The room above a grid for its name: a picture's row, a label's line, or none.
static func head_room(label: String, portrait: Texture2D) -> float:
	return FACE_ROW if portrait != null else (LABEL_H if label != "" else 0.0)


## Moves grid k (its name goes with it).
func move_area(k: int, at: Vector2) -> void:
	areas[k].at = at + Vector2(0, head_room(String(areas[k].label), areas[k].get("portrait")))
	areas[k].face_at = at
	_place_face(k)
	_fit_size()


## Grid k's picture as the kit's round portrait (the win screen's saddlebag) instead of the small square one.
func round_face(k: int, id: String, px: float) -> void:
	var p := MenuKit.portrait(id, px, true)
	p.size = Vector2(px, px)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.tooltip_text = String(areas[k].label)
	add_child(p)
	areas[k]["face_node"] = p
	_place_face(k)


func _place_face(k: int) -> void:
	var p: Control = areas[k].get("face_node")
	if p != null:
		p.position = areas[k].face_at


## A framed window behind some grids, its title on a plate at the top.
func add_window(r: Rect2, title := "") -> void:
	windows.append({"rect": r, "title": title})
	_fit_size()


## A real button inside the view (a window's TAKE ALL or CLOSE): it takes its own clicks.
func add_button(text: String, r: Rect2, cb: Callable) -> Button:
	var b: Button = MenuKit.XButton.new() if text == "X" else Button.new()  # the kit's round X; TAKE ALL is the one to press
	if text == Txt.t("UI_BOX_TAKE_ALL"):
		b.theme_type_variation = &"PrimaryButton"
	b.text = text
	b.position = r.position
	b.size = r.size
	b.custom_minimum_size = r.size
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(cb)
	add_child(b)
	return b


## A wrapped line of text in the view (a window's note, like the coins taken). Returns how many lines it takes.
func add_note(text: String, at: Vector2, width: float, icon: Texture2D = null) -> int:
	notes.append({"text": text, "at": at, "width": width, "icon": icon})
	queue_redraw()
	var f := Riso.font()
	var h := f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, 15).y
	return maxi(1, ceili(h / f.get_height(15)))


## As sections (the win screen): every grid starts right under its card's heading, and one foot row sits under the
## tallest grid, holding TAKE ALL under the loot and the party's gold chip under the pack. The cards end just under it,
## all the same height, so no card holds dead felt (look check, 2026-11-02).
func stretch_sections() -> void:
	if not sections or windows.size() < 2 or areas.size() < 2:
		return
	var top := WINDOW_TITLE + 8.0
	var loot: Dictionary = areas[1]
	if absf(float((loot.at as Vector2).y) - top) > 0.5:
		move_area(1, Vector2((loot.at as Vector2).x, top))
	# the pack's grids (area 0, the saddlebag after the loot) as one block, its top under the heading
	var gt := INF
	for k in areas.size():
		if k != 1:
			gt = minf(gt, float((areas[0].at as Vector2).y))  # the pack grid leads; the saddlebag inset is as tall
	var dy := roundf(top - gt)
	if absf(dy) > 0.5:
		for k in areas.size():
			if k != 1:
				areas[k].at = (areas[k].at as Vector2) + Vector2(0, dy)
				areas[k].face_at = (areas[k].face_at as Vector2) + Vector2(0, dy)
				_place_face(k)
	var low := 0.0
	for k in areas.size():
		low = maxf(low, _rect_of(areas[k]).end.y)
	var foot := low + 16.0
	var mid := foot + NOTE_CHIP_H * 0.5  # the foot row's centre line
	for b in get_children():
		if b is Button and (b as Button).text == Txt.t("UI_BOX_TAKE_ALL"):
			(b as Button).position.y = roundf(mid - (b as Button).size.y * 0.5)
	var h := foot + NOTE_CHIP_H + 16.0
	for w in windows:
		var r: Rect2 = w.rect
		w.rect = Rect2(r.position, Vector2(r.size.x, h - r.position.y))
	if not gold_note.is_empty():
		var card: Rect2 = windows[0].rect  # the pack's card: the chip centred across it, as TAKE ALL is in the loot's
		var cw := get_theme_default_font().get_string_size(String(gold_note.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 62.0
		gold_note.at = Vector2(roundf(card.get_center().x - cw * 0.5), roundf(mid - NOTE_CHIP_H * 0.5))
		flash_at = Vector2(gold_note.at.x + cw + 14.0, mid)
	var want := Vector2(custom_minimum_size.x, h)
	if not custom_minimum_size.is_equal_approx(want):
		custom_minimum_size = want
	queue_redraw()


## Sizes the view again after windows or cards were moved by hand.
func refit() -> void:
	_fit_size()


func _rect_of(a: Dictionary) -> Rect2:
	var g: InventoryGrid = a.bag
	return Rect2(a.at, Vector2(g.cols, g.rows) * cell)


func _fit_size() -> void:
	var end := Vector2.ZERO
	for a in areas:
		end = end.max(_rect_of(a).end)
	if bin.is_valid():
		end = end.max(bin_rect.end)
	for t in targets:
		end = end.max((t.rect as Rect2).end)
	for w in windows:
		end = end.max((w.rect as Rect2).end)
	custom_minimum_size = end + (Vector2.ZERO if not windows.is_empty() else Vector2(0, 30))
	queue_redraw()


func _bin_rect() -> Rect2:
	return bin_rect if bin.is_valid() else Rect2()


func _area_at(pos: Vector2) -> int:
	for k in areas.size():
		if _rect_of(areas[k]).has_point(pos):
			return k
	return -1


## The cell under pos in grid k's own coordinates (may be outside it).
func _cell_in(k: int, pos: Vector2) -> Vector2i:
	var at: Vector2 = areas[k].at
	return Vector2i(floori((pos.x - at.x) / cell), floori((pos.y - at.y) / cell))


func _gui_input(e: InputEvent) -> void:
	if bag == null:
		return
	if e is InputEventMouseMotion:
		mouse = e.position
		if held != -1:
			queue_redraw()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
		_turn(e.position)
		accept_event()
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		mouse = e.position
		if e.pressed and choosing != "":
			var t := _target_at(e.position)
			if t != -1 and _gain(t, choosing) > 0 and use_on.call(t, choosing):
				choosing = ""
				flash = ""
				changed.emit()
			queue_redraw()
		elif e.pressed:
			_pick(e.position)
		else:
			_drop(e.position)
		accept_event()
	elif e is InputEventKey and e.pressed and e.keycode == KEY_R:
		_turn(mouse)
		accept_event()


func _unhandled_key_input(e: InputEvent) -> void:
	if choosing != "" and e.pressed and e.keycode == KEY_ESCAPE:
		choosing = ""
		flash = ""
		queue_redraw()
		get_viewport().set_input_as_handled()


## Lay the party cards out in a row from `at`.
func add_targets(members: Array, at: Vector2) -> void:
	targets.clear()
	for k in members.size():
		var m: Dictionary = members[k]
		var card := m.duplicate()
		card.rect = Rect2(at + Vector2(k * (TARGET_SIZE.x + 10.0), 0), TARGET_SIZE)
		targets.append(card)
	_fit_size()


func _target_at(pos: Vector2) -> int:
	for k in targets.size():
		if (targets[k].rect as Rect2).has_point(pos):
			return k
	return -1


func _gain(t: int, item: String) -> int:
	return int(target_gain.call(t, item)) if target_gain.is_valid() else 0


func _pick(pos: Vector2) -> void:
	var k := _area_at(pos)
	if k == -1:
		return
	var g: InventoryGrid = areas[k].bag
	var i := g.item_at(_cell_in(k, pos))
	if i == -1:
		return
	if is_inside_tree():
		grab_focus()
	held = i
	held_area = k
	press_at = pos
	held_rot = g.items[i].rot
	grab = _cell_in(k, pos) - (g.items[i].pos as Vector2i)
	flash = ""
	queue_redraw()


func _turn(pos: Vector2) -> void:
	if held != -1:
		# turn the held cell offset with the shape so the item spins under the cursor
		held_rot = (held_rot + 1) % 4
		var shape: Array[Vector2i] = InventoryGrid.rotated(areas[held_area].bag.items[held].shape, held_rot)
		grab = shape[0]
		queue_redraw()
		return
	var k := _area_at(pos)
	if k == -1:
		return
	var g: InventoryGrid = areas[k].bag
	var i := g.item_at(_cell_in(k, pos))
	if i != -1:
		var it := g.items[i]
		if not g.move(i, it.pos, (int(it.rot) + 1) % 4):
			flash = "SHOP_NO_ROOM"
		changed.emit()
		queue_redraw()


func _drop(pos: Vector2) -> void:
	if held == -1:
		return
	var i := held
	var from := held_area
	held = -1
	held_area = -1
	var to_area := int(areas[from].get("click_to", -1))
	if to_area != -1 and pos.distance_to(press_at) < 6.0:  # a click, not a drag: send it to the first spot that fits over there
		if not _send(from, i, to_area):
			flash = "SHOP_NO_ROOM"
		changed.emit()
		queue_redraw()
		return
	var k := _area_at(pos)
	var t := _target_at(pos)
	if t != -1:  # a food or potion dropped on a party card: one of it goes to them; the stack stays put
		var id := String((areas[from].bag as InventoryGrid).items[i].id)
		if _gain(t, id) <= 0 or not use_on.call(t, id):
			flash = "UI_NO_GAIN"
	elif _bin_rect().has_point(pos):
		if not bin.call(areas[from].bag, i):
			flash = refused_key
	elif k == -1:
		pass  # dropped outside every grid: it stays where it was
	elif not _put_down(from, i, k, _cell_in(k, pos)):
		flash = "SHOP_NO_ROOM"
	changed.emit()
	queue_redraw()


## Moves a whole item (or what fits of its stack) to the first spot that takes it in grid `to`. False if none of it fit.
func _send(from: int, i: int, to: int) -> bool:
	var src: InventoryGrid = areas[from].bag
	var dst: InventoryGrid = areas[to].bag
	var it := src.items[i]
	if it.bound != "":
		return false
	var n := int(it.get("n", 1))
	var lost := dst.put(it.id, it.shape, n, maxi(1, int(db[it.id].get("stack", 1))))
	if lost >= n:
		return false
	if lost == 0:
		src.remove(i)
	else:
		it.n = lost
	return true


## Everything in grid `from` that fits goes to grid `to`, in order; stops at the first thing that does not. True if all went.
func send_all(from: int, to: int) -> bool:
	var src: InventoryGrid = areas[from].bag
	var all := true
	while not src.items.is_empty():
		if not _send(from, 0, to):  # a stack that only half fit leaves its rest at the front: the next try fails here
			all = false
			break
	changed.emit()
	queue_redraw()
	return all


## Moves item i of grid `from` to grid `to` with its held turn and grab, or tops up a stack of the same
## thing under the cursor. Bound gear stays in its own grid. Returns false (nothing changed) if refused.
func _put_down(from: int, i: int, to: int, under: Vector2i) -> bool:
	var src: InventoryGrid = areas[from].bag
	var dst: InventoryGrid = areas[to].bag
	var it := src.items[i]
	var pos := under - grab
	if from == to and dst.move(i, pos, held_rot):
		return true
	if from != to and it.bound == "" and dst.fits(it.shape, held_rot, pos):
		src.remove(i)
		var j := dst.place(it.id, it.shape, held_rot, pos)
		dst.items[j].n = int(it.get("n", 1))
		return true
	var o := dst.item_at(under)
	if o == -1 or (from == to and o == i) or dst.items[o].id != it.id or it.bound != "":
		return false
	var room := maxi(1, int(db[it.id].get("stack", 1))) - int(dst.items[o].get("n", 1))
	var k := mini(room, int(it.get("n", 1)))
	if k <= 0:
		return false
	dst.items[o].n = int(dst.items[o].get("n", 1)) + k
	it.n = int(it.get("n", 1)) - k
	if it.n <= 0:
		src.remove(i)
	return true


func _draw() -> void:
	if bag == null:
		return
	for w in windows:
		_draw_window(w.rect, String(w.title))
	for n in notes:  # a line of text, after its icon when it has one (the gold a fight or a box gave)
		if n.get("chip", false):
			_draw_chip_note(n)
			continue
		var nx := 0.0
		if n.get("icon") != null:
			draw_texture_rect(n.icon, Rect2(n.at + Vector2(0, -3), Vector2(24, 24)), false)
			nx = 30.0
		draw_multiline_string(Riso.font(), n.at + Vector2(nx, 15), String(n.text), HORIZONTAL_ALIGNMENT_LEFT, n.width - nx, 15, -1,
			get_theme_color("font_color", "Label"))
	if saddle_inset and areas.size() > 0:  # as tall as the pack grid, holding the dog's face and his bag
		var r0 := _rect_of(areas[0])
		for a in areas:
			if a.has("face_node"):
				var g := _rect_of(a)
				var box := Rect2(Vector2(g.position.x - INSET_PAD, r0.position.y), Vector2(g.size.x + INSET_PAD * 2.0, r0.size.y))
				draw_style_box(MenuKit.flat(Color(MenuKit.INSET, 0.55), Color(MenuKit.TEXT, 0.16), 1.0, 10, 0.0, 0.0), box)
	var bottom := 0.0
	for k in areas.size():
		var a := areas[k]
		draw_bag(self, a.bag, db, a.at, cell, true, held if k == held_area else -1)
		if a.has("face_node"):
			pass  # its round portrait is a child control
		elif a.get("portrait") != null:  # the picture is the grid's name: no words
			_draw_face(a.portrait, Rect2(a.face_at, Vector2(FACE, FACE)))
		elif a.label != "":
			Riso.draw_label(self, a.label, a.at - Vector2(0, LABEL_H * 0.55), 13, label_color)
		bottom = maxf(bottom, _rect_of(a).end.y)
	var sr := _bin_rect()
	if bin.is_valid():
		var over := held != -1 and sr.has_point(mouse)
		var bin_red := Color(0.95, 0.45, 0.38)  # the bin: a dark kit plate with a dashed red rim
		draw_style_box(MenuKit.flat(Color(0.18, 0.05, 0.04, 0.85) if over else MenuKit.INSET, Color(0, 0, 0, 0), 0.0, 8, 0.0, 0.0), sr)
		_dashed_rect(sr, bin_red)
		Riso.draw_label(self, Txt.t(bin_key), Vector2(sr.position.x + 4, sr.get_center().y), 18, bin_red, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x - 8)
		bottom = maxf(bottom, sr.end.y)
	var item := choosing
	if held != -1:
		item = String((areas[held_area].bag as InventoryGrid).items[held].id)
	for k in targets.size():
		bottom = maxf(bottom, _draw_target(k, item))
	var prompt := flash.begins_with("UI_WHO_")  # "who eats?" asks, it isn't a refusal: cream, not red
	if flash != "" and flash_at.x >= 0.0:  # in windows the note has its own line, on the green
		Riso.draw_label(self, Txt.t(flash), flash_at, 14, MenuKit.TEXT if prompt else Riso.mix(Riso.RED, Riso.CREAM, 0.45))
	elif flash != "":
		Riso.draw_label(self, Txt.t(flash), Vector2(0, bottom + 16), 14, Riso.RED)
	if held != -1:
		var it := (areas[held_area].bag as InventoryGrid).items[held]
		var cells := InventoryGrid.rotated(it.shape, held_rot)
		var top_left := mouse - (Vector2(grab) + Vector2(0.5, 0.5)) * cell
		var k := _area_at(mouse)
		if k != -1 and not sr.has_point(mouse):
			var g: InventoryGrid = areas[k].bag
			var target := _cell_in(k, mouse) - grab
			var ok := g.fits(it.shape, held_rot, target, held if k == held_area else -1)
			for c in cells:
				var cr := Rect2(areas[k].at + Vector2(c + target) * cell, Vector2(cell, cell))
				draw_rect(cr.grow(-4), Riso.alpha(Riso.INK if ok else Riso.RED, 0.18))
		draw_item(self, it.id, db, cells, top_left, cell, it.bound != "", 0.85)
		_draw_count(self, cells, top_left, cell, int(it.get("n", 1)))


const NOTE_CHIP_H := 38.0  ## a note drawn as a kit chip (the party's gold on the win screen)

## A note as a kit chip: its icon, then its words, in a dark pill.
func _draw_chip_note(n: Dictionary) -> void:
	var f := get_theme_default_font()
	var px := 18
	var tw := f.get_string_size(String(n.text), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var r := Rect2(n.at, Vector2(tw + 62.0, NOTE_CHIP_H))
	var sb := get_theme_stylebox("panel", "KitChip")
	if sb != null:
		draw_style_box(sb, r)
	if n.get("icon") != null:
		draw_texture_rect(n.icon, Rect2(r.position + Vector2(12, (NOTE_CHIP_H - 24.0) * 0.5), Vector2(24, 24)), false)
	draw_string(f, Vector2(r.position.x + 44.0, r.get_center().y + px * 0.36), String(n.text), HORIZONTAL_ALIGNMENT_LEFT, -1, px, MenuKit.TEXT)


## A window: the dialogue's own painted frame, its title on the long thin plate at the top. As `sections` (the win
## screen, inside its one big window), a kit section card instead: a flat card, its heading between two thin rules.
func _draw_window(r: Rect2, title: String) -> void:
	if sections:
		draw_style_box(get_theme_stylebox("panel", "KitCard"), r.grow_individual(-8, 0, -8, 0))
		if title != "":
			var f := get_theme_default_font()
			var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuKit.HEAD).x
			var cy := r.position.y + 30.0
			var cx := r.get_center().x
			draw_string(f, Vector2(cx - tw * 0.5, cy + MenuKit.HEAD * 0.36), title, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuKit.HEAD, MenuKit.TEXT)
			var rule := Color(MenuKit.TEXT, 0.55)
			draw_line(Vector2(r.position.x + 30.0, cy), Vector2(cx - tw * 0.5 - 12.0, cy), rule, 1.5, true)
			draw_line(Vector2(cx + tw * 0.5 + 12.0, cy), Vector2(r.end.x - 30.0, cy), rule, 1.5, true)
		return
	var sb := get_theme_stylebox("panel", "DialogPanel")
	if sb != null:
		draw_style_box(sb, r)
	else:
		draw_rect(r, Riso.INK)
	if title == "":
		return
	var inset := WINDOW_PAD + 16.0  # the plate stops short of the round X on the top right corner
	var plate := Rect2(r.position + Vector2(inset, 26.0), Vector2(r.size.x - inset * 2.0, 34.0))
	var psb := get_theme_stylebox("panel", "TitlePlate")
	if psb != null:
		draw_style_box(psb, plate)
	var col := get_theme_color("font_color", "MenuTitle")
	Riso.draw_label(self, title, Vector2(plate.position.x, plate.get_center().y), 19, col, HORIZONTAL_ALIGNMENT_CENTER, plate.size.x)


## A party card: their face and an HP bar ([USER] 2026-11-01, fewer words: the name only when there is no face); while
## food or a potion is held or picked, what one would heal them, or FULL (greyed) when it can't. Returns its bottom.
func _draw_target(k: int, item: String) -> float:
	var c: Dictionary = targets[k]
	var r: Rect2 = c.rect
	var g := _gain(k, item) if item != "" else 0
	var live := item != "" and g > 0
	var over := live and r.has_point(mouse)
	# a kit card: dark with a thin rim, gold while it can take what is held (the menu kit)
	var card := MenuKit.flat(MenuKit.BTN_HOVER if over else MenuKit.INSET, MenuKit.GOLD if live else MenuKit.RIM_DIM, 2.0 if live else 1.0, 8, 0.0, 0.0)
	card.bg_color.a *= 1.0 if item == "" or live else 0.5
	draw_style_box(card, r)
	var ink := MenuKit.TEXT if item == "" or live else Color(MenuKit.TEXT, 0.45)
	var a := 1.0 if item == "" or live else 0.45
	var left := 8.0
	var face: Texture2D = c.get("face")
	if face != null:
		_draw_face(face, Rect2(r.position + Vector2(6, 6), Vector2(r.size.y - 12, r.size.y - 12)), a)
		left = r.size.y
	# the name and HP number on one line, a thin HP bar under them (the kit's bars), what one would heal under that
	var w := r.size.x - left - 10.0
	var f := get_theme_default_font()
	draw_string(f, r.position + Vector2(left, 20), String(c.name), HORIZONTAL_ALIGNMENT_LEFT, w, 13, ink)
	draw_string(f, r.position + Vector2(left, 20), "%d/%d" % [int(c.hp), int(c.max_hp)], HORIZONTAL_ALIGNMENT_RIGHT, w, 12, Color(ink, 0.85 * a))
	var bar := Rect2(r.position + Vector2(left, 28), Vector2(w, 7))
	var hp := clampf(float(c.hp) / maxf(1.0, float(c.max_hp)), 0.0, 1.0)
	draw_style_box(MenuKit.flat(Color(MenuKit.INSET, 0.9 * a), Color(MenuKit.RIM, 0.5 * a), 1.0, 4, 0.0, 0.0), bar)
	if hp > 0.0:
		draw_style_box(MenuKit.flat(Color(VictoryUi.HP_RED, a), Color(0, 0, 0, 0), 0.0, 4, 0.0, 0.0), Rect2(bar.position, Vector2(bar.size.x * hp, bar.size.y)))
	if item != "":
		draw_string(f, r.position + Vector2(left, r.size.y - 8), Txt.f("UI_GAIN_HP", g) if g > 0 else Txt.t("UI_FULL_HP"),
			HORIZONTAL_ALIGNMENT_LEFT, w, 12, VictoryUi.UP_GREEN if g > 0 else ink)
	return r.end.y


## A face filling a square, cropped not stretched, with a thin rule round it.
func _draw_face(tex: Texture2D, r: Rect2, a := 1.0) -> void:
	var ts := tex.get_size()
	var side := minf(ts.x, ts.y)
	draw_texture_rect_region(tex, r, Rect2((ts - Vector2(side, side)) * Vector2(0.5, 0.0), Vector2(side, side)), Color(1, 1, 1, a))
	draw_rect(r, Riso.alpha(label_color, 0.8 * a), false, 1.5)


func _dashed_rect(r: Rect2, col: Color) -> void:
	for side in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end],
			[r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]:
		draw_dashed_line(side[0], side[1], col, 2.0, 6.0)


static func kind_color(kind: String) -> Color:
	match kind:
		"food": return Color("#e2b46a")
		"crate": return Color("#c9955a")
		"med": return Color("#9cc08f")
		"herb": return Color("#8fb486")
		"book": return Color("#a593c9")
	return Riso.PAPER


## Draws the grid and every item except skip. Shared by the pack panel and the bottom frame.
static func draw_bag(ci: CanvasItem, bag: InventoryGrid, db: Dictionary, origin: Vector2, cell: float, slots_dashed: bool, skip := -1) -> void:
	for y in bag.rows:
		for x in bag.cols:
			var r := Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell))
			if slots_dashed:  # a pack or loot window: the kit's dark item slot (the menu kit, round 2 mockups)
				ci.draw_style_box(_slot_box(), r.grow(-2))
			else:
				ci.draw_rect(r.grow(-2), Riso.mix(Riso.PAPER, Riso.GOLD, 0.18))
	for i in bag.items.size():
		if i == skip:
			continue
		var it := bag.items[i]
		var cells := InventoryGrid.rotated(it.shape, it.rot)
		var top_left := origin + Vector2(it.pos as Vector2i) * cell
		draw_item(ci, it.id, db, cells, top_left, cell, it.bound != "")
		_draw_count(ci, cells, top_left, cell, int(it.get("n", 1)))


static var _slot: StyleBoxFlat

static func _slot_box() -> StyleBoxFlat:
	if _slot == null:
		_slot = MenuKit.flat(Color(0.07, 0.21, 0.19, 0.95), Color(0.72, 0.84, 0.88, 0.75), 1.5, 6, 0.0, 0.0)  # a lifted slot with a clear rim
	return _slot


## A stack's count in the corner of its last cell. Single things show none.
static func _draw_count(ci: CanvasItem, cells: Array[Vector2i], top_left: Vector2, cell: float, n: int) -> void:
	if n <= 1:
		return
	var last := cells[0]
	for c in cells:
		if c.y > last.y or (c.y == last.y and c.x > last.x):
			last = c
	var corner := top_left + (Vector2(last) + Vector2(1, 1)) * cell
	# light with a dark outline, so it reads on any tile (the menu kit's slot counts)
	var font := Riso.font()
	var px := maxi(12, int(cell * 0.36))
	var w := font.get_string_size(str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var at := corner - Vector2(cell * 0.1 + w, cell * 0.12)
	ci.draw_string_outline(font, at, str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, px, 7, Color(0.02, 0.06, 0.05, 1.0))
	ci.draw_string(font, at, str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, px, MenuKit.TEXT)


## One item: its cells as one flat plane with an ink keyline round the outside, icon at the middle.
static func draw_item(ci: CanvasItem, id: String, db: Dictionary, cells: Array[Vector2i], top_left: Vector2, cell: float, bound: bool, a := 1.0) -> void:
	var kind: String = db[id].kind
	var fill := Riso.alpha(kind_color(kind), a)
	var ink := Riso.alpha(Riso.INK, a)
	var inset := maxf(2.0, cell * 0.05)
	var center := Vector2.ZERO
	for c in cells:
		var r := Rect2(top_left + Vector2(c) * cell, Vector2(cell, cell))
		# grow toward neighbors of the same item so the shape reads as one piece
		var l := inset if not cells.has(c + Vector2i.LEFT) else 0.0
		var t := inset if not cells.has(c + Vector2i.UP) else 0.0
		var rr := inset if not cells.has(c + Vector2i.RIGHT) else 0.0
		var b := inset if not cells.has(c + Vector2i.DOWN) else 0.0
		var body := Rect2(r.position + Vector2(l, t), r.size - Vector2(l + rr, t + b))
		ci.draw_rect(body, fill)
		var w := maxf(1.5, cell * 0.03)
		if l > 0.0: ci.draw_line(body.position, Vector2(body.position.x, body.end.y), ink, w)
		if rr > 0.0: ci.draw_line(Vector2(body.end.x, body.position.y), body.end, ink, w)
		if t > 0.0: ci.draw_line(body.position, Vector2(body.end.x, body.position.y), ink, w)
		if b > 0.0: ci.draw_line(Vector2(body.position.x, body.end.y), body.end, ink, w)
		center += Vector2(c) + Vector2(0.5, 0.5)
	center = top_left + center / cells.size() * cell
	# put the icon on the cell nearest the middle, so L and T shapes keep it on the item
	var best := center
	var best_d := INF
	for c in cells:
		var cc := top_left + (Vector2(c) + Vector2(0.5, 0.5)) * cell
		if cc.distance_to(center) < best_d:
			best_d = cc.distance_to(center)
			best = cc
	var tex := ActionInfo.icon(id)  # Brandon's item icon (game/art/source/icons/<id>.png) when there is one
	if tex != null:
		# a solid block (rope, crate, a feast) gets one big icon across it; an L or T shape keeps it on one cell
		var ext := InventoryGrid.extent(cells)
		var solid := cells.size() == ext.x * ext.y
		var side := (mini(ext.x, ext.y) if solid else 1) * cell * 0.86
		var at := (top_left + Vector2(ext) * cell * 0.5) if solid else best
		ci.draw_texture_rect(tex, Rect2(at - Vector2(side, side) * 0.5, Vector2(side, side)), false, Color(1, 1, 1, a))
	else:
		Riso.draw_item_icon(ci, kind, best, cell * 0.8)
	if tex == null and not ICON_KINDS.has(kind) and cell >= 30.0:  # no icon drawn for these yet, so they carry their name
		Riso.draw_label(ci, Txt.t(String(db[id].name_key)), center, maxi(10, int(cell * 0.22)), ink, HORIZONTAL_ALIGNMENT_CENTER)
	if bound:
		Riso.draw_stamp_star(ci, top_left + Vector2(cell * 0.2, cell * 0.2), cell * 0.12, Riso.alpha(Riso.INDIGO, a))

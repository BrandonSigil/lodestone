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
var notes: Array[Dictionary] = []  ## lines of text in a window: {"text", "at" (top-left), "width"}
const NOTE_LINE := 24.0
var gold_note := {}  ## in windows: the party's gold under the pack, kept current when coins come over (one of `notes`)
var flash_at := Vector2(-1, -1)  ## where the flash line goes in windows; unset, it sits under everything


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
	_fit_size()


## A framed window behind some grids, its title on a plate at the top.
func add_window(r: Rect2, title := "") -> void:
	windows.append({"rect": r, "title": title})
	_fit_size()


## A real button inside the view (a window's TAKE ALL or CLOSE): it takes its own clicks.
func add_button(text: String, r: Rect2, cb: Callable) -> Button:
	var b := Button.new()
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
		var nx := 0.0
		if n.get("icon") != null:
			draw_texture_rect(n.icon, Rect2(n.at + Vector2(0, -3), Vector2(24, 24)), false)
			nx = 30.0
		draw_multiline_string(Riso.font(), n.at + Vector2(nx, 15), String(n.text), HORIZONTAL_ALIGNMENT_LEFT, n.width - nx, 15, -1,
			get_theme_color("font_color", "Label"))
	var bottom := 0.0
	for k in areas.size():
		var a := areas[k]
		draw_bag(self, a.bag, db, a.at, cell, true, held if k == held_area else -1)
		if a.get("portrait") != null:  # the picture is the grid's name: no words
			_draw_face(a.portrait, Rect2(a.face_at, Vector2(FACE, FACE)))
		elif a.label != "":
			Riso.draw_label(self, a.label, a.at - Vector2(0, LABEL_H * 0.55), 13, label_color)
		bottom = maxf(bottom, _rect_of(a).end.y)
	var sr := _bin_rect()
	if bin.is_valid():
		var over := held != -1 and sr.has_point(mouse)
		draw_rect(sr, Riso.mix(Riso.PAPER, Riso.RED, 0.25 if over else 0.08))
		_dashed_rect(sr, Riso.RED)
		Riso.draw_label(self, Txt.t(bin_key), Vector2(sr.position.x + 4, sr.get_center().y), 18, Riso.RED, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x - 8)
		bottom = maxf(bottom, sr.end.y)
	var item := choosing
	if held != -1:
		item = String((areas[held_area].bag as InventoryGrid).items[held].id)
	for k in targets.size():
		bottom = maxf(bottom, _draw_target(k, item))
	if flash != "" and flash_at.x >= 0.0:  # in windows the note has its own line, on the green
		Riso.draw_label(self, Txt.t(flash), flash_at, 14, Riso.mix(Riso.RED, Riso.CREAM, 0.45))
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


## A window: the dialogue's own painted frame, its title on the long thin plate at the top.
func _draw_window(r: Rect2, title: String) -> void:
	var sb := get_theme_stylebox("panel", "DialogPanel")
	if sb != null:
		draw_style_box(sb, r)
	else:
		draw_rect(r, Riso.INK)
	if title == "":
		return
	var plate := Rect2(r.position + Vector2(WINDOW_PAD - 4.0, 26.0), Vector2(r.size.x - WINDOW_PAD * 2.0 + 8.0, 34.0))
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
	draw_rect(r, Riso.mix(Riso.PAPER, Riso.INK, 0.12 if over else 0.0) if item == "" or live else Riso.alpha(Riso.PAPER, 0.4))
	draw_rect(r, Riso.INK if live else Riso.alpha(Riso.INK, 0.4), false, 3.0 if live else 1.5)
	var ink := Riso.INK if item == "" or live else Riso.alpha(Riso.INK, 0.45)
	var a := 1.0 if item == "" or live else 0.45
	var left := 8.0
	var face: Texture2D = c.get("face")
	if face != null:
		_draw_face(face, Rect2(r.position + Vector2(6, 6), Vector2(r.size.y - 12, r.size.y - 12)), a)
		left = r.size.y
	else:
		Riso.draw_label(self, String(c.name), r.position + Vector2(left, 14), 12, ink)
	var bar_y := (r.size.y - 16.0) * 0.5 - (8.0 if item != "" else 0.0)  # mid-card; up a little for the +HP line
	var bar := Rect2(r.position + Vector2(left, bar_y if face != null else 22.0), Vector2(r.size.x - left - 8, 16))
	var hp := clampf(float(c.hp) / maxf(1.0, float(c.max_hp)), 0.0, 1.0)
	draw_rect(bar, Riso.alpha(Riso.INK, 0.75 * a))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * hp, bar.size.y)), Riso.alpha(VictoryUi.HP_RED, a))
	Riso.draw_label(self, "%d/%d" % [int(c.hp), int(c.max_hp)], Vector2(bar.position.x, bar.get_center().y), 11,
		Riso.alpha(Riso.CREAM, a), HORIZONTAL_ALIGNMENT_CENTER, bar.size.x)
	if item != "":
		Riso.draw_label(self, Txt.f("UI_GAIN_HP", g) if g > 0 else Txt.t("UI_FULL_HP"), Vector2(bar.position.x, r.end.y - 14), 13,
			Riso.mix(Riso.INK, Color(0.2, 0.55, 0.25), 0.8) if g > 0 else ink, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x)
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
			ci.draw_rect(r.grow(-2), Riso.mix(Riso.PAPER, Riso.GOLD, 0.18))
			if slots_dashed:
				ci.draw_rect(r.grow(-2), Riso.GOLD_DARK, false, 1.5)
	for i in bag.items.size():
		if i == skip:
			continue
		var it := bag.items[i]
		var cells := InventoryGrid.rotated(it.shape, it.rot)
		var top_left := origin + Vector2(it.pos as Vector2i) * cell
		draw_item(ci, it.id, db, cells, top_left, cell, it.bound != "")
		_draw_count(ci, cells, top_left, cell, int(it.get("n", 1)))


## A stack's count in the corner of its last cell. Single things show none.
static func _draw_count(ci: CanvasItem, cells: Array[Vector2i], top_left: Vector2, cell: float, n: int) -> void:
	if n <= 1:
		return
	var last := cells[0]
	for c in cells:
		if c.y > last.y or (c.y == last.y and c.x > last.x):
			last = c
	var corner := top_left + (Vector2(last) + Vector2(1, 1)) * cell
	Riso.draw_label(ci, str(n), corner - Vector2(cell * 0.12, cell * 0.26), maxi(9, int(cell * 0.26)), Riso.INK, HORIZONTAL_ALIGNMENT_RIGHT)


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

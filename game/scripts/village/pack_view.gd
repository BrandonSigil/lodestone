class_name PackView
extends Control
## The pack grid you arrange by hand: drag an item to move it, R or right-click turns it,
## drop it on the sell box to sell it. Gear bound to a member (the Wizard's books) can be
## moved and turned but not sold.

signal changed

const CELL := 72.0
const SELL_SIZE := Vector2(150, 110)

var outfit: Outfit
var held := -1  ## index of the item being dragged
var held_rot := 0
var grab := Vector2i.ZERO  ## which cell of the rotated shape the mouse holds
var mouse := Vector2.ZERO
var flash := ""  ## text key shown under the grid after a refused action


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL


func setup(kit: Outfit) -> void:
	outfit = kit
	custom_minimum_size = Vector2(CELL * kit.bag.cols + 40 + SELL_SIZE.x, CELL * kit.bag.rows + 30)
	queue_redraw()


func _sell_rect() -> Rect2:
	return Rect2(Vector2(CELL * outfit.bag.cols + 40, CELL * outfit.bag.rows - SELL_SIZE.y), SELL_SIZE)


func _cell_at(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CELL), floori(pos.y / CELL))


func _gui_input(e: InputEvent) -> void:
	if outfit == null:
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
		if e.pressed:
			_pick(e.position)
		else:
			_drop(e.position)
		accept_event()
	elif e is InputEventKey and e.pressed and e.keycode == KEY_R:
		_turn(mouse)
		accept_event()


func _pick(pos: Vector2) -> void:
	var i := outfit.bag.item_at(_cell_at(pos))
	if i == -1:
		return
	if is_inside_tree():
		grab_focus()
	held = i
	held_rot = outfit.bag.items[i].rot
	grab = _cell_at(pos) - (outfit.bag.items[i].pos as Vector2i)
	flash = ""
	queue_redraw()


func _turn(pos: Vector2) -> void:
	if held != -1:
		# turn the held cell offset with the shape so the item spins under the cursor
		held_rot = (held_rot + 1) % 4
		var shape: Array[Vector2i] = InventoryGrid.rotated(outfit.bag.items[held].shape, held_rot)
		grab = shape[0]
		queue_redraw()
		return
	var i := outfit.bag.item_at(_cell_at(pos))
	if i != -1:
		var it := outfit.bag.items[i]
		if not outfit.bag.move(i, it.pos, (int(it.rot) + 1) % 4):
			flash = "SHOP_NO_ROOM"
		changed.emit()
		queue_redraw()


func _drop(pos: Vector2) -> void:
	if held == -1:
		return
	var i := held
	held = -1
	if _sell_rect().has_point(pos):
		if not outfit.sell(i):
			flash = "UI_BOUND"
	elif not outfit.bag.move(i, _cell_at(pos) - grab, held_rot):
		flash = "SHOP_NO_ROOM"
	changed.emit()
	queue_redraw()


func _draw() -> void:
	if outfit == null:
		return
	draw_bag(self, outfit.bag, outfit.items_db, Vector2.ZERO, CELL, true, held)
	var sr := _sell_rect()
	var over := held != -1 and sr.has_point(mouse)
	draw_rect(sr, Riso.mix(Riso.PAPER, Riso.RED, 0.25 if over else 0.08))
	_dashed_rect(sr, Riso.RED)
	Riso.draw_label(self, Txt.t("UI_SELL"), sr.get_center(), 20, Riso.RED, HORIZONTAL_ALIGNMENT_CENTER)
	if flash != "":
		Riso.draw_label(self, Txt.t(flash), Vector2(0, CELL * outfit.bag.rows + 16), 14, Riso.RED)
	if held != -1:
		var it := outfit.bag.items[held]
		var cells := InventoryGrid.rotated(it.shape, held_rot)
		var top_left := mouse - (Vector2(grab) + Vector2(0.5, 0.5)) * CELL
		var target := _cell_at(mouse) - grab
		var ok := outfit.bag.fits(it.shape, held_rot, target, held)
		if not sr.has_point(mouse):
			for c in cells:
				var cr := Rect2(Vector2(c + target) * CELL, Vector2(CELL, CELL))
				draw_rect(cr.grow(-4), Riso.alpha(Riso.INK if ok else Riso.RED, 0.18))
		draw_item(self, it.id, outfit.items_db, cells, top_left, CELL, it.bound != "", 0.85)


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
		draw_item(ci, it.id, db, InventoryGrid.rotated(it.shape, it.rot), origin + Vector2(it.pos as Vector2i) * cell, cell, it.bound != "")


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
	Riso.draw_item_icon(ci, kind, best, cell * 0.8)
	if bound:
		Riso.draw_stamp_star(ci, top_left + Vector2(cell * 0.2, cell * 0.2), cell * 0.12, Riso.alpha(Riso.INDIGO, a))

class_name InventoryGrid
extends RefCounted
## The party pack as a grid of cells. Items are shapes (like Tetris pieces) that can be
## rotated and placed anywhere they don't overlap. Pure rules, no drawing.

var cols := 4
var rows := 3
## Each item: {"id": String, "shape": Array[Vector2i] (unrotated), "rot": int 0-3,
## "pos": Vector2i (top-left of the rotated shape), "bound": String (member id that owns it, or "")}
var items: Array[Dictionary] = []


static func create(c: int, r: int) -> InventoryGrid:
	var g := InventoryGrid.new()
	g.cols = c
	g.rows = r
	return g


## "##/#." -> cells at (0,0), (1,0), (0,1). Rows are split by "/", "#" is filled.
static func parse_shape(s: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var lines := s.split("/")
	for y in lines.size():
		for x in lines[y].length():
			if lines[y][x] == "#":
				out.append(Vector2i(x, y))
	return out


## Rotates a shape clockwise rot times and shifts it so its top-left is (0, 0).
static func rotated(shape: Array[Vector2i], rot: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = shape.duplicate()
	for i in posmod(rot, 4):
		for k in out.size():
			out[k] = Vector2i(-out[k].y, out[k].x)
	var lo := Vector2i(1 << 20, 1 << 20)
	for c in out:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
	for k in out.size():
		out[k] -= lo
	return out


static func extent(cells: Array[Vector2i]) -> Vector2i:
	var hi := Vector2i.ZERO
	for c in cells:
		hi = Vector2i(maxi(hi.x, c.x + 1), maxi(hi.y, c.y + 1))
	return hi


func capacity() -> int:
	return cols * rows


func cells_of(index: int) -> Array[Vector2i]:
	var it := items[index]
	var out: Array[Vector2i] = []
	for c in rotated(it.shape, it.rot):
		out.append(c + (it.pos as Vector2i))
	return out


## Index of the item covering a cell, or -1.
func item_at(cell: Vector2i) -> int:
	for i in items.size():
		if cells_of(i).has(cell):
			return i
	return -1


## True if a shape with this rotation fits at pos. The item at index ignore doesn't block.
func fits(shape: Array[Vector2i], rot: int, pos: Vector2i, ignore := -1) -> bool:
	for c in rotated(shape, rot):
		var cell := c + pos
		if cell.x < 0 or cell.y < 0 or cell.x >= cols or cell.y >= rows:
			return false
		var at := item_at(cell)
		if at != -1 and at != ignore:
			return false
	return true


## First free spot scanning rows top to bottom, trying each rotation.
## Returns {"pos": Vector2i, "rot": int} or {} when there's no room.
func find_room(shape: Array[Vector2i], prefer_rot := 0) -> Dictionary:
	for k in 4:
		var rot := (prefer_rot + k) % 4
		for y in rows:
			for x in cols:
				if fits(shape, rot, Vector2i(x, y)):
					return {"pos": Vector2i(x, y), "rot": rot}
	return {}


## Puts an item at a chosen spot. Returns its index, or -1 if it doesn't fit.
func place(id: String, shape: Array[Vector2i], rot: int, pos: Vector2i, bound := "") -> int:
	if not fits(shape, rot, pos):
		return -1
	items.append({"id": id, "shape": shape, "rot": posmod(rot, 4), "pos": pos, "bound": bound})
	return items.size() - 1


## Puts an item in the first free spot. Returns its index, or -1 if the pack is full.
func add(id: String, shape: Array[Vector2i], bound := "") -> int:
	var room := find_room(shape)
	if room.is_empty():
		return -1
	return place(id, shape, room.rot, room.pos, bound)


## Moves (and maybe rotates) an item already in the pack. Fails without changing anything.
func move(index: int, pos: Vector2i, rot: int) -> bool:
	if not fits(items[index].shape, rot, pos, index):
		return false
	items[index].pos = pos
	items[index].rot = posmod(rot, 4)
	return true


func remove(index: int) -> Dictionary:
	return items.pop_at(index)


func used_cells() -> int:
	var n := 0
	for it in items:
		n += (it.shape as Array).size()
	return n

class_name RisoIcon
extends Control
## A small drawn thing to put inside Controls: a roster piece or an item's shape.

var character: CharacterDef
var item_id := ""
var dim := false
var cell := 14.0


static func piece(d: CharacterDef, sz: Vector2, dimmed := false) -> RisoIcon:
	var i := RisoIcon.new()
	i.character = d
	i.dim = dimmed
	i.custom_minimum_size = sz
	return i


static func item(id: String, cell_size := 14.0) -> RisoIcon:
	var i := RisoIcon.new()
	i.item_id = id
	i.cell = cell_size
	i.custom_minimum_size = Vector2(3, 3) * cell_size + Vector2(4, 4)
	return i


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	if character:
		var st := Riso.piece_style(character)
		var h := size.y * 0.78
		var opt := {"hat": st.get("hat", ""), "pack": st.get("pack", false), "dim": dim}
		if character.party_slots > 1:
			Riso.draw_piece(self, Vector2(size.x * 0.5 - h * 0.28, size.y - 6), h * 0.85, st.col, opt)
			Riso.draw_piece(self, Vector2(size.x * 0.5 + h * 0.28, size.y - 4), h * 0.85, Riso.mix(st.col, Riso.INDIGO, 0.4), opt)
		else:
			Riso.draw_piece(self, Vector2(size.x * 0.5, size.y - 6), h, st.col, opt)
	elif item_id != "":
		var cells := InventoryGrid.parse_shape(Db.items[item_id].shape)
		var ext := InventoryGrid.extent(cells)
		var origin := (size - Vector2(ext) * cell) * 0.5
		PackView.draw_item(self, item_id, Db.items, cells, origin, cell, false)

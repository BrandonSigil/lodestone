class_name MakerOverlay
extends Node2D
## Draws the map maker's marks over the board (a child of it, so it shares the board's transform):
## the brush footprint, a path, river or stair drag in progress, height numbers, the placement ghost (green
## where it fits, red where it doesn't), badges for things, the party start and pieces, names over
## placeholder blobs, and the selection.

var maker: Node  ## the map maker scene (map_maker.gd)
var brush: Array[Vector2i] = []
var path: Array[Vector2i] = []
var path_color := Color(0.45, 0.8, 1.0)
var show_heights := false
var show_labels := true
## {"cell": Vector2i, "color": Color, "icon": MakerIcons id, "label": String, "selected": bool}
var marks: Array[Dictionary] = []
## Placement preview: {"cells": Array[Vector2i], "ok": bool, "tex": Texture2D, "rect": Rect2, "flip": bool,
## "blob": Color (a blob's colour), "tall": float, "icon": String}. Empty = none.
var ghost := {}
var hover_cells: Array[Vector2i] = []  ## what the select tool would pick
var selected_cells: Array[Vector2i] = []
## The QA panel's problem cells: [{"cell": Vector2i, "color": Color}] (map_maker.qa_cells), and the one flown to.
var qa: Array[Dictionary] = []
var qa_focus := Vector2i(-999, -999)
var qa_focus_t := 0.0
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	qa_focus_t = maxf(0.0, qa_focus_t - delta)
	queue_redraw()


func _draw() -> void:
	var b: CombatBoard = get_parent()
	if b == null or b.grid == null:
		return
	var g := b.grid
	var font := ThemeDB.fallback_font
	if show_heights:
		for y in g.h:
			for x in g.w:
				var c := Vector2i(x, y)
				if not g.solid(c) or b.hidden(c):
					continue
				var p := b.cell_top(c)
				draw_string_outline(font, p + Vector2(-10, 5), str(g.height_at(c)), HORIZONTAL_ALIGNMENT_CENTER, 20, 12, 3, Color(0, 0, 0, 0.6))
				draw_string(font, p + Vector2(-10, 5), str(g.height_at(c)), HORIZONTAL_ALIGNMENT_CENTER, 20, 12, Color(1, 1, 0.9))
	if show_labels:
		for a: Vector2i in g.props:
			var p: Dictionary = g.props[a]
			if not p.get("blob", false) and String(p.get("id", "")) == "":
				continue
			var top := _foot_center(b, a, p.foot) + Vector2(0, -float(p.tall) * 2.0 * CombatBoard.HS - 10.0)
			var text := String(p.get("name", "")) if p.get("blob", false) else String(p.id)
			_tag(font, top, text, CombatBoard.blob_color(text) if p.get("blob", false) else MakerUI.INK)
	var qpulse := 0.75 + 0.25 * sin(_t * 3.0)
	for q in qa:
		var qc: Vector2i = q.cell
		if g.in_bounds(qc) and not b.hidden(qc):
			_fill(b, qc, Color(q.color, 0.42 * qpulse))
			_outline(b, qc, Color(q.color, 0.95), 1.5)
	if qa_focus_t > 0.0 and g.in_bounds(qa_focus):
		var fp := b.cell_top(qa_focus)
		var rr := 18.0 + 40.0 * fposmod(_t, 0.8) / 0.8
		draw_arc(fp, rr, 0, TAU, 40, Color(1, 1, 1, minf(1.0, qa_focus_t)), 3.0, true)
		_outline(b, qa_focus, Color.WHITE, 3.0)
	if maker != null:
		for c: Vector2i in maker.region:
			_fill(b, c, Color(0.3, 0.8, 1.0, 0.28))
			_outline(b, c, Color(0.3, 0.8, 1.0, 0.9), 1.5)
	for c in hover_cells:
		_outline(b, c, Color(1, 1, 1, 0.7), 1.5)
	var pulse := 0.65 + 0.35 * sin(_t * 5.0)
	for c in selected_cells:
		_fill(b, c, Color(MakerUI.ACCENT, 0.18))
		_outline(b, c, Color(MakerUI.ACCENT, pulse), 2.5)
	for m in marks:
		var c: Vector2i = m.cell
		if not g.in_bounds(c):
			continue
		var p := b.cell_top(c)
		var col: Color = m.color
		var sel: bool = m.get("selected", false)
		Pawn.ellipse(self, p, 14.0, 5.5, Color(col, 0.9), false, 3.0 if sel else 2.0)
		var at := p + Vector2(0, -30)
		draw_line(p, at + Vector2(0, 12), Color(col, 0.9), 2.0, true)
		draw_circle(at, 13.0, Color(0.08, 0.09, 0.1, 0.9))
		draw_arc(at, 13.0, 0, TAU, 28, Color(MakerUI.ACCENT, pulse) if sel else col, 2.5 if sel else 2.0, true)
		MakerIcons.draw(self, String(m.get("icon", "")), Rect2(at - Vector2(8, 8), Vector2(16, 16)), col)
		if show_labels and String(m.get("label", "")) != "":
			_tag(font, at + Vector2(0, -22), String(m.label), col)
	for c in path:
		_outline(b, c, path_color, 2.5)
	for c in brush:
		_outline(b, c, Color(1, 1, 1, 0.85), 1.5)
	if not ghost.is_empty():
		_draw_ghost(b)


func _draw_ghost(b: CombatBoard) -> void:
	var ok: bool = ghost.get("ok", true)
	var col := MakerUI.GOOD if ok else MakerUI.BAD
	var cells: Array = ghost.get("cells", [])
	for c: Vector2i in cells:
		_fill(b, c, Color(col, 0.28))
		_outline(b, c, Color(col, 0.9), 2.0)
	if cells.is_empty():
		return
	var tex: Texture2D = ghost.get("tex")
	if tex != null:
		var r: Rect2 = ghost.rect
		var mod := Color(1, 1, 1, 0.72) if ok else Color(1, 0.6, 0.6, 0.5)
		if ghost.get("flip", false):
			draw_set_transform(Vector2(r.get_center().x * 2.0, 0.0), 0.0, Vector2(-1, 1))
			draw_texture_rect(tex, r, false, mod)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture_rect(tex, r, false, mod)
	elif ghost.has("blob"):
		var lo: Vector2i = cells[0]
		var hi: Vector2i = cells[0]
		for c: Vector2i in cells:
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		var h := float(b.grid.height_at(lo)) if b.grid.in_bounds(lo) else 0.0
		var top: float = h + maxf(0.4, float(ghost.get("tall", 1.0)) * 2.0)
		var bc: Color = ghost.blob
		var q := PackedVector2Array([b.iso(lo.x, lo.y, top), b.iso(hi.x + 1, lo.y, top), b.iso(hi.x + 1, hi.y + 1, top), b.iso(lo.x, hi.y + 1, top)])
		draw_colored_polygon(q, Color(bc, 0.55))
		q.append(q[0])
		draw_polyline(q, Color(bc.lightened(0.3), 0.9), 1.5, true)
	elif ghost.has("icon"):
		var p := b.cell_top(cells[0]) + Vector2(0, -30)
		draw_circle(p, 13.0, Color(0.08, 0.09, 0.1, 0.8))
		MakerIcons.draw(self, String(ghost.icon), Rect2(p - Vector2(8, 8), Vector2(16, 16)), col)


func _tag(font: Font, at: Vector2, text: String, col: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 12.0
	var r := Rect2(at.x - w * 0.5, at.y - 10, w, 18)
	draw_style_box(MakerUI.box(Color(0.06, 0.07, 0.08, 0.85), 5, 0.0, Color(col, 0.7)), r)
	draw_string(font, Vector2(r.position.x + 6, at.y + 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col.lightened(0.2))


func _foot_center(b: CombatBoard, a: Vector2i, foot: Vector2i) -> Vector2:
	var h := float(b.grid.height_at(a))
	return b.iso(a.x + foot.x * 0.5, a.y + foot.y * 0.5, h)


func _diamond(b: CombatBoard, c: Vector2i) -> PackedVector2Array:
	var g := b.grid
	var h := float(g.height_at(c)) if g.solid(c) else 0.0
	return PackedVector2Array([b.iso(c.x, c.y, h), b.iso(c.x + 1, c.y, h), b.iso(c.x + 1, c.y + 1, h), b.iso(c.x, c.y + 1, h)])


func _fill(b: CombatBoard, c: Vector2i, col: Color) -> void:
	if b.grid.in_bounds(c):
		draw_colored_polygon(_diamond(b, c), col)


func _outline(b: CombatBoard, c: Vector2i, col: Color, width: float) -> void:
	if not b.grid.in_bounds(c):
		return
	var pts := _diamond(b, c)
	pts.append(pts[0])
	draw_polyline(pts, Color(0, 0, 0, 0.35), width + 2.0, true)
	draw_polyline(pts, col, width, true)

class_name ExploreOverlay
extends Node2D
## Drawn on top of the exploration board (a child of it, so it shares the board's camera):
## the things on the map (chests, the hum stone, the way out, door slabs) and the interact icons.
## Graybox shapes; Brandon's props replace them later.

const ICON := Color(1.0, 0.86, 0.4)
const INK := Color(0.12, 0.11, 0.1)

var scene: Node  ## the explore scene: things, party, mode
var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var board: CombatBoard = get_parent()
	if board == null or board.grid == null or scene == null:
		return
	var lead: CombatUnit = scene.leader()
	var font := ThemeDB.fallback_font
	for t: Dictionary in scene.things:
		if t.done or not scene.shown(t):
			continue
		var c: Vector2i = t.cell
		var state: int = board.fog.get(c, 0)
		if state == 0:
			continue
		var p := board.cell_top(c)
		var dim := state == 1
		_thing(String(t.kind), p, dim)
		if dim or lead == null or not scene.walking():
			continue
		var near := ExploreRules.dist(lead.cell, c) <= ExploreRules.HINT_RANGE
		var hovered := board.hover == c
		if near or hovered:
			# The interact icon: a bobbing bubble with a "!" over anything the party can use.
			var top := p + Vector2(0, -58 + sin(_time * 4.0) * 3.0)
			draw_circle(top + Vector2(2, 2), 12.0, Color(0, 0, 0, 0.35))
			draw_circle(top, 12.0, ICON)
			draw_arc(top, 12.0, 0, TAU, 24, INK, 2.0, true)
			draw_colored_polygon(PackedVector2Array([top + Vector2(-4, 10), top + Vector2(4, 10), top + Vector2(0, 17)]), ICON)
			draw_string(font, top + Vector2(-12, 6), "!", HORIZONTAL_ALIGNMENT_CENTER, 24, 18, INK)
			if near:
				draw_string_outline(font, top + Vector2(-30, -16), "F", HORIZONTAL_ALIGNMENT_CENTER, 60, 12, 3, Color(0, 0, 0, 0.8))
				draw_string(font, top + Vector2(-30, -16), "F", HORIZONTAL_ALIGNMENT_CENTER, 60, 12, ICON)


func _thing(kind: String, p: Vector2, dim: bool) -> void:
	var k := 0.55 if dim else 1.0
	match kind:
		"chest":
			_box(p + Vector2(0, 2), 11.0, 10.0, Color(0.62, 0.42, 0.24) * k)
			draw_line(p + Vector2(-11, -11), p + Vector2(0, -6), Color(0.85, 0.7, 0.3) * k, 2.0)
		"shrine":
			_box(p, 7.0, 30.0, Color(0.55, 0.6, 0.7) * k)
			draw_circle(p + Vector2(0, -24), 3.0, Color(0.6, 0.95, 1.0, 0.6 + 0.4 * sin(_time * 3.0)) * k)
		"exit":
			draw_line(p, p + Vector2(0, -40), Color(0.35, 0.28, 0.2) * k, 3.0)
			var wave := sin(_time * 3.0) * 3.0
			draw_colored_polygon(PackedVector2Array([p + Vector2(1, -40), p + Vector2(24, -34 + wave), p + Vector2(1, -27)]), Color(0.9, 0.85, 0.5) * k)
		"door", "rubble":
			# The wall is the board's ruin block; a door slab marks which one opens.
			if kind == "door":
				var d := PackedVector2Array([p + Vector2(-8, -4), p + Vector2(8, -4), p + Vector2(8, -26), p + Vector2(0, -31), p + Vector2(-8, -26)])
				draw_colored_polygon(d, Color(0.42, 0.28, 0.18) * k)
				draw_polyline(d + PackedVector2Array([d[0]]), INK, 1.5, true)
				draw_circle(p + Vector2(4, -15), 1.8, Color(0.9, 0.8, 0.4) * k)
			else:
				for o in [Vector2(-8, -6), Vector2(6, -4), Vector2(-1, -14)]:
					_box(p + o, 6.0, 5.0, Color(0.5, 0.47, 0.42) * k)


## A little iso box standing on p: two faces and a lid.
func _box(p: Vector2, r: float, tall: float, col: Color) -> void:
	var t := p + Vector2(0, -tall)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-r, -r * 0.5), p, t, t + Vector2(-r, -r * 0.5)]), col.darkened(0.1))
	draw_colored_polygon(PackedVector2Array([p, p + Vector2(r, -r * 0.5), t + Vector2(r, -r * 0.5), t]), col.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([t, t + Vector2(r, -r * 0.5), t + Vector2(0, -r), t + Vector2(-r, -r * 0.5)]), col.lightened(0.12))

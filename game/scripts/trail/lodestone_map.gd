class_name LodestoneMap
extends Control
## The Lodestone: the party's map. Records the route and remembers marks from every run.
## Graybox strip; Brandon's map art goes here later.

var run: RunState
var old_marks: Array = []  ## from meta, earlier runs
var best := 0


func _init() -> void:
	custom_minimum_size = Vector2(0, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if run == null:
		return
	var pad := 24.0
	var y := size.y * 0.55
	var x0 := pad
	var x1 := size.x - pad
	var to_x := func(d: float) -> float: return lerpf(x0, x1, d / RunState.GOAL)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.13, 0.17, 0.17))
	# known ground: as far as anyone has walked
	var known: float = to_x.call(maxi(best, run.distance))
	draw_line(Vector2(x0, y), Vector2(known, y), Color(0.75, 0.72, 0.6), 4.0)
	# fog past that
	for i in 30:
		var fx := lerpf(known, x1, i / 30.0)
		draw_circle(Vector2(fx, y), 3.0, Color(0.5, 0.5, 0.55, 0.25))
	# the Wall
	var wx: float = to_x.call(RunState.WALL)
	draw_line(Vector2(wx, y - 50), Vector2(wx, y + 30), Color(0.6, 0.45, 0.75), 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(wx + 4, y - 38), "WALL", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.6, 0.9))
	for mk in old_marks:
		_mark(Vector2(to_x.call(float(mk.d)), y + 16), mk.kind, 0.35)
	for mk in run.marks:
		_mark(Vector2(to_x.call(float(mk.d)), y - 14), mk.kind, 1.0)
	var px: float = to_x.call(run.distance)
	Pawn.draw(self, Vector2(px, y - 4), 18.0, Color(0.85, 0.75, 0.5), Color(1, 0.9, 0.4))
	draw_string(ThemeDB.fallback_font, Vector2(x1 - 30, y + 30), "END", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.8, 0.8))


func _mark(p: Vector2, kind: String, alpha: float) -> void:
	var c := Color(0.9, 0.4, 0.35, alpha) if kind == "combat" else Color(0.9, 0.8, 0.45, alpha)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)]), c)

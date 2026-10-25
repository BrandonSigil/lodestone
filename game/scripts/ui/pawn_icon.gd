class_name PawnIcon
extends Control
## Graybox board-game piece. Stand-in until Brandon's paper-doll parts exist.

@export var tint := Color.GRAY:
	set(v):
		tint = v
		queue_redraw()
@export var ring := Color(0, 0, 0, 0):
	set(v):
		ring = v
		queue_redraw()
@export var dim := false:
	set(v):
		dim = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(36, 44)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := tint.darkened(0.45) if dim else tint
	Pawn.draw(self, Vector2(size.x * 0.5, size.y - 6), size.y * 0.42, c, ring)

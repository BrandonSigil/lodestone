class_name SkinBackdrop
extends Node2D
## The blurred world behind a skin window (UiSkin.watch adds one under each window panel). A Node2D, so the panel's
## container leaves it alone; it draws behind its parent, as big as the parent, with the panel's rounded corners.

var radius := UiSkin.R_WINDOW
var rect := Rect2()  ## a window a Control draws itself (the pack view's): this part of the parent; empty for all of it


func _ready() -> void:
	show_behind_parent = true
	var m := ShaderMaterial.new()
	m.shader = UiSkin.BLUR
	material = m
	var p := get_parent() as Control
	p.resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var p := get_parent() as Control
	var m := material as ShaderMaterial
	var r := rect if rect.has_area() else Rect2(Vector2.ZERO, p.size)
	m.set_shader_parameter("size", r.size)
	m.set_shader_parameter("radius", radius)
	draw_rect(r, Color.WHITE)

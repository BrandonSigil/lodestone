extends SceneTree
## Saves the placeholder foe gallery to a PNG. Args after "--": <png path> [zoom] [id,id,...] (a zoomed close-up of
## a few foes, one per row).

var _frames := 0
var _out := ""


func _initialize() -> void:
	_out = OS.get_cmdline_user_args()[0]
	DisplayServer.window_set_size(Vector2i(2400, 1400))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var gallery := Node2D.new()
	gallery.set_script(load("res://tools/foe_gallery.gd"))
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_factor = float(args[1])
	if args.size() > 2:
		gallery.only = Array(args[2].split(","))
		gallery.PER_ROW = 1
	root.add_child(gallery)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	root.get_viewport().get_texture().get_image().save_png(_out)
	quit()
	return false

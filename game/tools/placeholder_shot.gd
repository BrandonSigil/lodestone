extends SceneTree
## Saves the placeholder figure gallery to a PNG. Args after "--": <png path>.

var _frames := 0
var _out := ""


func _initialize() -> void:
	_out = OS.get_cmdline_user_args()[0]
	DisplayServer.window_set_size(Vector2i(960, 1180))
	var gallery := Node2D.new()
	gallery.set_script(load("res://tools/placeholder_gallery.gd"))
	root.add_child(gallery)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	root.get_viewport().get_texture().get_image().save_png(_out)
	quit()
	return false

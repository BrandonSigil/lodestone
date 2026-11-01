extends SceneTree
## Screenshots the plot maker (scenes/plot_maker.tscn) to a PNG. Args after "--": <png path> [plot id]. Needs a window
## (tools/godot.sh). Never writes a plot.

var _frames := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/plot_maker.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	var args := OS.get_cmdline_user_args()
	if _frames == 6 and args.size() > 1:
		current_scene.call("_open", "res://data/plots/forest/%s.json" % args[1])
	if _frames == 20:
		root.get_viewport().get_texture().get_image().save_png(args[0])
		quit()
	return false

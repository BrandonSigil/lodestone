extends SceneTree
## Saves a lineup of character stands as the game draws them (CharacterArt: scale, anchor, flip) to a PNG.
## Args after "--": <png path> <id>:<dir> ... (for example lead:se fire_mage:se fire_mage:ne).

var _frames := 0
var _out := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	DisplayServer.window_set_size(Vector2i(960, 420))
	var bg := ColorRect.new()
	bg.color = Color("eae8d6")
	bg.size = Vector2(960, 420)
	root.add_child(bg)
	var zoom := 3.0
	var n := args.size() - 1
	for i in n:
		var parts := args[i + 1].split(":")
		var f := CharacterArt.frame(StringName(parts[0]), "idle", parts[1], 0.0)
		if f.is_empty():
			push_error("no frame for " + args[i + 1])
			continue
		var feet := Vector2(960.0 * (i + 0.5) / n, 330)
		var d := Polygon2D.new()
		var k := zoom * 0.5
		d.polygon = PackedVector2Array([Vector2(0, -32) * k, Vector2(64, 0) * k, Vector2(0, 32) * k, Vector2(-64, 0) * k])
		d.color = Color(0.6, 0.55, 0.4, 0.35)
		d.position = feet
		root.add_child(d)
		var s := Sprite2D.new()
		s.texture = f.tex
		s.region_enabled = true
		s.region_rect = f.region
		s.centered = false
		s.flip_h = f.flip
		s.offset = -Vector2(f.anchor.x, f.anchor.y)
		s.scale = Vector2.ONE * float(f.scale) * zoom
		s.position = feet
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		root.add_child(s)
		var l := Label.new()
		l.text = args[i + 1]
		l.position = feet + Vector2(-40, 30)
		l.add_theme_color_override("font_color", Color("373335"))
		root.add_child(l)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false
	root.get_viewport().get_texture().get_image().save_png(_out)
	quit()
	return false

extends SceneTree
## Saves a lineup of character stands as the game draws them (CharacterArt: scale, anchor, flip) to a PNG,
## on one ground line. Args after "--": <png path> <id>:<dir> ... (for example lead:se fire_mage:se fire_mage:ne).

const SIZE := Vector2i(1200, 360)

var _frames := 0
var _out := ""
var _vp: SubViewport


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var bg := ColorRect.new()
	bg.color = Color("eae8d6")
	bg.size = Vector2(SIZE)
	_vp.add_child(bg)
	var n := args.size() - 1
	var zoom := 2.0
	for i in n:
		var parts := args[i + 1].split(":")
		var f := CharacterArt.frame(StringName(parts[0]), "idle", parts[1], 0.0)
		if f.is_empty():
			push_error("no frame for " + args[i + 1])
			continue
		var feet := Vector2(SIZE.x * (i + 0.5) / n, 270)
		var k := zoom * 0.5
		var d := Polygon2D.new()
		d.polygon = PackedVector2Array([Vector2(0, -32) * k, Vector2(64, 0) * k, Vector2(0, 32) * k, Vector2(-64, 0) * k])
		d.color = Color(0.6, 0.55, 0.4, 0.35)
		d.position = feet
		_vp.add_child(d)
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
		_vp.add_child(s)
		var l := Label.new()
		l.text = args[i + 1].get_slice(":", 0)
		l.position = feet + Vector2(-30, 40)
		l.add_theme_color_override("font_color", Color("373335"))
		_vp.add_child(l)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false
	_vp.get_texture().get_image().save_png(_out)
	quit()
	return false

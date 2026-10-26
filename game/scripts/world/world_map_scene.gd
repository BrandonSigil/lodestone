extends Node2D
## The world map: the whole land from the village through the Wall to the deep lands,
## printed riso style. Shows everything for now; FOG PEEK previews what the player has unearthed.
## Opened from the village (no run, view only) or from the trail (shows the party).

const MAP_SEED := 1  ## one fixed world for now; a per-save seed can come later
const ZOOM_MAX := 2.5

@export var fog_on := false

var world: WorldMap
var painter: MapPainter
var ground: ColorRect
var fog: ColorRect
var cam: Camera2D
var known_label: Label
var _fit := 1.0
var _dragging := false


func _ready() -> void:
	world = WorldMap.load_default(MAP_SEED)
	ground = ColorRect.new()
	ground.size = WorldMap.SIZE
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.material = _ground_material()
	add_child(ground)

	painter = MapPainter.new()
	painter.marks = Game.meta.marks
	painter.best = int(Game.meta.best_distance)
	painter.party_d = Game.run.distance if Game.run else -1
	painter.setup(world, MAP_SEED)
	add_child(painter)

	fog = ColorRect.new()
	fog.size = WorldMap.SIZE
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog.material = _fog_material(revealed())
	fog.visible = fog_on
	add_child(fog)  # over the stamps; the sheet's border stays outside the map rect

	cam = Camera2D.new()
	add_child(cam)
	_fit_camera()
	get_viewport().size_changed.connect(_fit_camera)
	_build_ui()


## Everything unearthed so far: what meta remembers plus the walk the party is on now.
func revealed() -> Array:
	var circles: Array = Game.meta.get("revealed", []).duplicate(true)
	if circles.is_empty():
		circles = Discovery.start(world)
	if Game.run:
		Discovery.reveal_route(circles, world, Game.run.distance)
	return circles


func _ground_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/world_ground.gdshader")
	var pos := PackedVector2Array()
	var weight := PackedFloat32Array()
	var east := PackedFloat32Array()
	var water := PackedFloat32Array()
	var fill: Array[Color] = []
	var mark: Array[Color] = []
	for r in world.regions:
		pos.append(r.pos)
		weight.append(r.weight)
		east.append(1.0 if r.east else 0.0)
		water.append(1.0 if r.kind == "water" else 0.0)
		var p := Riso.palette_at(r.s)
		fill.append(MapPainter.region_fill(r.kind, p))
		mark.append(MapPainter.region_mark(r.kind, p))
	m.set_shader_parameter("map_size", WorldMap.SIZE)
	m.set_shader_parameter("phase", world.phase)
	m.set_shader_parameter("warp_f", WorldMap.WARP_F)
	m.set_shader_parameter("warp_a", WorldMap.WARP_A)
	m.set_shader_parameter("region_count", world.regions.size())
	m.set_shader_parameter("region_pos", pos)
	m.set_shader_parameter("region_weight", weight)
	m.set_shader_parameter("region_east", east)
	m.set_shader_parameter("region_water", water)
	m.set_shader_parameter("region_fill", fill)
	m.set_shader_parameter("region_mark", mark)
	m.set_shader_parameter("wall_count", world.wall.size())
	m.set_shader_parameter("wall_pts", world.wall)
	return m


func _fog_material(circles: Array) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/world_fog.gdshader")
	var arr := PackedVector3Array()
	for c in circles:
		arr.append(Vector3(c[0], c[1], c[2]))
	var home := Riso.palette_at(0.0)
	m.set_shader_parameter("map_size", WorldMap.SIZE)
	m.set_shader_parameter("circle_count", arr.size())
	m.set_shader_parameter("circles", arr)
	m.set_shader_parameter("paper", home.light)
	m.set_shader_parameter("ink", home.dark)
	return m


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var home := Riso.palette_at(0.0)
	var ui := Control.new()
	ui.theme = RisoTheme.make()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	# tucked over the far sea in the bottom-right corner, out of the land's way
	var panel := PanelContainer.new()
	FrameHud._pin(panel, 1, 1, 1, 1, 0, 0, -52, -52)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(_text(Txt.t("MAP_TITLE"), 20, home.dark))
	known_label = _text(Txt.f("MAP_KNOWN", int(round(Discovery.known_fraction(revealed()) * 100))), 14, home.dark)
	box.add_child(known_label)
	box.add_child(_text(Txt.t("MAP_HINT"), 12, Color(home.dark, 0.7)))
	var row := HBoxContainer.new()
	box.add_child(row)
	var back := Button.new()
	back.text = Txt.t("MAP_BACK")
	back.pressed.connect(_back)
	row.add_child(back)
	var peek := Button.new()
	peek.text = Txt.t("MAP_FOG")
	peek.toggle_mode = true
	peek.button_pressed = fog_on
	peek.toggled.connect(func(on: bool) -> void: fog.visible = on)
	row.add_child(peek)
	# one fixed grain over everything, UI included (R6)
	var grain := CanvasLayer.new()
	grain.layer = 3
	grain.add_child(Riso.grain_rect(MAP_SEED))
	add_child(grain)


func _text(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _back() -> void:
	Game.go(Game.TRAIL if Game.run else Game.VILLAGE)


# --- camera ----------------------------------------------------------------

func _fit_camera() -> void:
	var vs := get_viewport_rect().size
	var sheet := WorldMap.SIZE + Vector2.ONE * MapPainter.BORDER * 2.0
	_fit = minf(vs.x / sheet.x, vs.y / sheet.y)
	cam.zoom = Vector2.ONE * _fit
	cam.position = WorldMap.SIZE * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_by(1.15)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_by(1.0 / 1.15)
		elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging:
		cam.position -= (event as InputEventMouseMotion).relative / cam.zoom.x
		_clamp_camera()


func _zoom_by(f: float) -> void:
	cam.zoom = Vector2.ONE * clampf(cam.zoom.x * f, _fit, _fit * ZOOM_MAX)
	_clamp_camera()


func _clamp_camera() -> void:
	var half := get_viewport_rect().size * 0.5 / cam.zoom.x
	var lo := -Vector2.ONE * MapPainter.BORDER + half
	var hi := WorldMap.SIZE + Vector2.ONE * MapPainter.BORDER - half
	cam.position = Vector2(
		clampf(cam.position.x, minf(lo.x, hi.x), maxf(lo.x, hi.x)) if lo.x <= hi.x else WorldMap.SIZE.x * 0.5,
		clampf(cam.position.y, lo.y, hi.y) if lo.y <= hi.y else WorldMap.SIZE.y * 0.5)

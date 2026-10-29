class_name CombatBoard
extends Node2D
## Draws the isometric height map and the pieces, and turns mouse input into cells.
## All graybox: flat-shaded blocks and pawn shapes. Brandon's tiles and paper dolls replace _draw later.

signal cell_clicked(cell: Vector2i, right: bool)
signal cell_hovered(cell: Vector2i)
signal cell_painted(cell: Vector2i, right: bool)  ## press and drag, for the map editor
signal rotated  ## the camera turned; hosts re-layout

const TW := 64.0  ## tile width on screen
const TH := 32.0  ## tile height on screen
const HS := 16.0  ## pixels per height level
const BASE := -0.6  ## how far below height 0 the block sides go
const NONE := Vector2i(-1, -1)

const TOP_COLORS := {
	CombatGrid.T.GRASS: Color(0.56, 0.66, 0.47),
	CombatGrid.T.FOREST: Color(0.33, 0.48, 0.36),
	CombatGrid.T.WATER: Color(0.42, 0.6, 0.72),
	CombatGrid.T.ROCK: Color(0.55, 0.55, 0.53),
	CombatGrid.T.ROAD: Color(0.7, 0.63, 0.5),
	CombatGrid.T.STONE: Color(0.78, 0.73, 0.6),
	CombatGrid.T.STAIRS: Color(0.74, 0.69, 0.57),
	CombatGrid.T.RUIN: Color(0.66, 0.62, 0.53),
	CombatGrid.T.VOID: Color(0.5, 0.5, 0.5),
}
## Earth to Alien: the same board drifts toward these as strangeness rises.
const ALIEN_COLORS := {
	CombatGrid.T.GRASS: Color(0.5, 0.42, 0.62),
	CombatGrid.T.FOREST: Color(0.2, 0.5, 0.5),
	CombatGrid.T.WATER: Color(0.75, 0.45, 0.6),
	CombatGrid.T.ROCK: Color(0.35, 0.3, 0.45),
	CombatGrid.T.ROAD: Color(0.55, 0.5, 0.65),
	CombatGrid.T.STONE: Color(0.62, 0.58, 0.72),
	CombatGrid.T.STAIRS: Color(0.58, 0.54, 0.7),
	CombatGrid.T.RUIN: Color(0.45, 0.4, 0.58),
	CombatGrid.T.VOID: Color(0.5, 0.5, 0.5),
}
const CLIFF := Color(0.62, 0.58, 0.49)  ## side faces of natural ground
const ALIEN_CLIFF := Color(0.42, 0.36, 0.5)
const MASONRY := Color(0.7, 0.66, 0.55)  ## side faces of built stone
const FALL := Color(0.62, 0.9, 0.86)  ## waterfall sheets
## Which ground reaches onto which where they meet (higher over lower); others never blend.
const BLEND_RANK := {CombatGrid.T.GRASS: 0, CombatGrid.T.FOREST: 1, CombatGrid.T.ROAD: 2, CombatGrid.T.STONE: 3}
const BLEND_DEPTH := 0.34  ## how far (cells) a neighbour's ground reaches in, on average
const BLEND_STEPS := 6
const BLEND_ALPHA := 0.92
const INK := Color(0.216, 0.2, 0.208)  ## the art's outline colour (#373335, B14), never black
const WATER_INSET := 0.3  ## water sits this many levels below its banks, so the banks show a little earth
const PLATE_SCALE := 1.35  ## a painted backdrop plate's width as a multiple of the board's footprint
const FG_HEIGHT := 0.16  ## the solid foreground band's height as a share of the view
const FG_FADE := 0.05  ## how far the band's top edge feathers up into the wallpaper, as a share of the view
const WALL_SKY := 0.22  ## where the wallpaper's horizon sits, as a share of the view's height from the top
const WALL_HORIZON := 0.38  ## where the picture's mountains start, as a share of the picture's height (the stand-in skyline)

var grid: CombatGrid
var units: Array = []
var strangeness := 0.0
var art_set := ""  ## tile set subfolder (see BattleArt); "" = base art
var highlights := {}  # cell -> Color
var danger := {}  # cell -> true, the enemy's reach next phase
var area := {}  # cell -> true, cells a skill would hit
var show_coords := false
var edit_void := false  ## map editor: show VOID cells as faint outlines and let them be picked
var island := true  ## rims hang ragged rock below the base, water spills off the edge
var blend := true  ## ground fades into different neighbouring ground (see _fringe)
var backdrop := false  ## a soft paper card behind the island (tester and fights; exploration draws its own world)
var wallpaper := false  ## test: the set's skyline fills the view and stays put, a solid band sits under the board, and the outer trees sink into it
var combat_stance := false  ## pieces stand ready (weapon drawn) instead of relaxed; Battle sets it
var _fade := {}  ## cells whose props draw see-through this frame (a party piece stands behind them)
var _covered := {}  ## units something in front hides this frame
var _paint_button := 0
var hover := NONE
var selected: CombatUnit = null
var _floaters: Array[Dictionary] = []  # {"text", "pos", "t", "color"}
var _time := 0.0
var rot := 0  ## camera quarter turns, 0-3 (Q turns it)
## Fog of war for exploration maps: cell -> 1 (seen before, drawn dim) or 2 (in sight now).
## With fog_on, cells missing from it are not drawn or picked at all.
var fog := {}
var fog_on := false
var cull := Rect2()  ## board-local area worth drawing (big maps); empty draws everything
var show_grid := true  ## cell outlines; off, only real ledges keep their rim (exploration hides the grid)
## The soft terrain pass (TerrainShape, docs/design/terrain-engine.md): rounded blocks, cliffs and lips that run
## on unbroken from cell to cell, flow strokes down the water, stairs cut into the rock. Off = the old blocks.
## Interiors ("plain" looks) always keep the blocks.
var soft := true
## Players never turn the view: every map is seen from its one approved angle ([USER] 2026-10-28, like Hades).
## Only editors (the map maker, the sandbox's map editing) switch this on; a map's "view" is its angle.
var can_turn := false
## Screen area the board is shown in (hosts set it from their layout); the valley backdrop fills it.
## Empty = the whole viewport.
var view_rect := Rect2()
var look := MapLook.new()  ## how the map is staged; resolved each draw from grid.look, the tile set and strangeness
var _look_key := ""
## Valley staging: forest cells around the playable outline, cell -> {"ring": 1.., "src": nearest ground cell}.
## Includes cells outside the grid. Rebuilt when the grid changes.
var _skirt := {}
var _skirt_key := ""
var _skirt_fade := {}  ## skirt cells whose trees draw see-through this frame
var _ci: CanvasItem = self  ## where the draw helpers paint: the slab being drawn
var _stack: Node2D  ## holds the slabs (see _sync_slabs)
var _slabs: Array = []  ## BACK, then GROUND and LIVE per depth, then TOP
var _depths: Array = []  ## cells by draw depth (see _layers)
var _off := 0  ## depth shift for the skirt rings
var _layers_key := ""
var _ground_key := ""
var _dirty := {}  ## depth -> true: ground slabs to redraw this frame
var _fall_cells: Array = []  ## per depth: water cells (their falls scroll)
var _prop_cells: Array = []  ## per depth: cells something stands on
var _dirty_props := {}  ## depth -> true: props slabs to redraw this frame
var _fog_hash := 0
var _fog_snap := {}  ## fog as the props slabs last drew it
var _fade_prev := {}
var _skirt_fade_prev := {}
var _skirt_by_depth := {}
var _over_by_depth := {}  ## this frame: depth -> {cell: true} with a highlight, the cursor or the fog veil
var _units_by_depth := {}
var _seen := {}  ## fog cells the ground slabs have drawn
var _snap_h := PackedInt32Array()
var _snap_t := PackedInt32Array()
var _snap_z := PackedStringArray()
var _snap_props := 0
var _snap_version := -1
var _radii := {}  ## soft pass: cell -> its four corner radii (TerrainShape.radii)
var _streams := {}  ## soft pass: water cell -> its pieces of the flow strokes
var _water_sig := 0
var _pen_ends := {}  ## soft pass: outline line ends -> how many lines meet there (see _pen_end)
var _pen_by_cell := {}  ## soft pass: cell -> the line ends its outline put in _pen_ends
var _shape_base := ""  ## soft pass: what the shape caches were built for, but the grid's version
var _shape_version := -1
var _shape_h := PackedInt32Array()  ## the heights and terrain the shape caches were built from
var _shape_t := PackedInt32Array()


func _ready() -> void:
	# Painted textures tile across cells and are mipmapped (see BattleArt).
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _process(delta: float) -> void:
	_time += delta
	for f in _floaters:
		f.t -= delta
		f.pos.y -= 30.0 * delta
	_floaters = _floaters.filter(func(f: Dictionary) -> bool: return f.t > 0.0)
	_sync_slabs()


## The wallpaper and foreground band, drawn behind the slabs so the board and its trees stand in front.
func _draw() -> void:
	var tex := _wall_tex()
	if tex == null:
		return
	var r := _local_view()
	var col := _wall_bottom(tex)
	# The picture's mountains start WALL_HORIZON of the way down it, and sit WALL_SKY of the way down the view.
	var s := maxf(r.size.x / tex.get_width(), r.size.y * WALL_SKY / WALL_HORIZON / tex.get_height())
	var size := Vector2(tex.get_width(), tex.get_height()) * s
	var pic_top := r.position.y + r.size.y * WALL_SKY - size.y * WALL_HORIZON
	draw_texture_rect(tex, Rect2(Vector2(r.get_center().x - size.x * 0.5, pic_top), size), false)
	var floor_y := pic_top + size.y
	if floor_y < r.end.y:  # below the picture the wallpaper's bottom colour carries on
		draw_rect(Rect2(r.position.x, floor_y, r.size.x, r.end.y - floor_y), col)
	var top := r.end.y - r.size.y * FG_HEIGHT
	var fade := r.size.y * FG_FADE
	var clear := Color(col, 0.0)
	draw_polygon(PackedVector2Array([Vector2(r.position.x, top - fade), Vector2(r.end.x, top - fade), Vector2(r.end.x, top), Vector2(r.position.x, top)]),
		PackedColorArray([clear, clear, col, col]))
	draw_rect(Rect2(r.position.x, top, r.size.x, r.end.y - top), col)


func _wall_tex() -> Texture2D:
	return BattleArt.texture("skyline") if wallpaper else null


static var _wall_colours := {}  ## the average of each wallpaper's bottom rows, read once per texture


func _wall_bottom(tex: Texture2D) -> Color:
	var id := tex.get_instance_id()
	if not _wall_colours.has(id):
		var img := tex.get_image()
		var sum := Color(0.0, 0.0, 0.0, 0.0)
		var n := 0
		for y in range(int(img.get_height() * 0.97), img.get_height()):
			for x in range(0, img.get_width(), 8):
				sum += img.get_pixel(x, y)
				n += 1
		_wall_colours[id] = sum / float(maxi(n, 1))
	return _wall_colours[id]


## The colour the outer trees sink into: the wallpaper's bottom when it is on, else the look's wood.
func _sink_colour() -> Color:
	var tex := _wall_tex()
	return _wall_bottom(tex) if tex != null else look.color("wood")


static var _silhouettes := {}  ## flat silhouettes made from the tree sprites, by sprite and colour


## A tree sprite as a flat silhouette: its shape in one colour, hard edged, made once and kept.
func _silhouette(tex: Texture2D, col: Color) -> Texture2D:
	var key := "%d|%s" % [tex.get_instance_id(), col.to_html()]
	if not _silhouettes.has(key):
		var img := tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				img.set_pixel(x, y, Color(col, 1.0 if img.get_pixel(x, y).a > 0.5 else 0.0))
		_silhouettes[key] = ImageTexture.create_from_image(img)
	return _silhouettes[key]


# --- coordinates ------------------------------------------------------------

## Grid coordinates turned by the camera rotation (continuous, so corners and centres both work).
func _rot(x: float, y: float) -> Vector2:
	match rot:
		1:
			return Vector2(grid.h - y, x)
		2:
			return Vector2(grid.w - x, grid.h - y)
		3:
			return Vector2(y, grid.w - x)
	return Vector2(x, y)


func _dims() -> Vector2:
	return Vector2(grid.h, grid.w) if rot % 2 == 1 else Vector2(grid.w, grid.h)


func iso(x: float, y: float, h: float) -> Vector2:
	var p := _rot(x, y)
	return Vector2((p.x - p.y) * TW * 0.5, (p.x + p.y) * TH * 0.5 - h * HS)


func cell_top(c: Vector2i) -> Vector2:
	return iso(c.x + 0.5, c.y + 0.5, grid.height_at(c))


## Where the ground's surface is drawn: water sits a little below its banks.
func _surf(c: Vector2i) -> float:
	var h := float(grid.height_at(c))
	return h - WATER_INSET if grid.terrain_at(c) == CombatGrid.T.WATER else h


## The surface of a neighbour, or the floor where there is no ground.
func _surf_or_floor(c: Vector2i) -> float:
	return _surf(c) if grid.solid(c) else _floor()


# --- staging ------------------------------------------------------------------------

func _resolve_look() -> void:
	var key := "%s|%s|%s" % [str(grid.look), art_set, strangeness]
	if key != _look_key:
		_look_key = key
		look = MapLook.resolve(grid.look, art_set, strangeness)


## The map stands in a forest valley: tall outer cliffs, a skirt of trees, the sky behind.
func _valley() -> bool:
	return backdrop and look.staging == "valley"


## Rock hangs under the rim (the floating island). Boards without a backdrop keep their own `island` switch.
func _rims() -> bool:
	return look.staging == "island" if backdrop else island


## How far down the outer cliffs go.
func _floor() -> float:
	return look.floor_h if _valley() else BASE


## The screen area the board shows in, in board-local coordinates.
func _local_view() -> Rect2:
	var vr := view_rect if view_rect.has_area() else get_viewport_rect()
	return get_global_transform_with_canvas().affine_inverse() * vr


func _refresh_skirt() -> void:
	var key := "%d|%d|%d" % [grid.get_instance_id(), grid.version, look.skirt]
	if key == _skirt_key:
		return
	_skirt_key = key
	_skirt = MapDress.skirt(grid, look.skirt)


## Draw order: back to front on screen.
func depth_of(x: float, y: float) -> int:
	var p := _rot(x + 0.5, y + 0.5)
	return int(round(p.x + p.y))


## The grid direction that faces the viewer's lower-left (lit) or lower-right (shade) at this rotation.
func front_dir(shade: bool) -> Vector2i:
	var want := Vector2(1, 0) if shade else Vector2(0, 1)
	for d in CombatRules.DIRS:
		var r := _rot(1.0 + d.x, 1.0 + d.y) - _rot(1.0, 1.0)
		if r.is_equal_approx(want):
			return d
	return Vector2i(0, 1)


func turn(steps := 1) -> void:
	if not can_turn:
		return
	rot = posmod(rot + steps, 4)
	hover = NONE
	rotated.emit()


## Tallest thing on the board in levels (ground plus ruins), so flat maps don't waste screen.
func _sky() -> float:
	return grid.top_height() + CombatGrid.RUIN_RISE + 1.5


func board_size() -> Vector2:
	var d := _dims()
	return Vector2((d.x + d.y) * TW * 0.5, (d.x + d.y) * TH * 0.5 + (_sky() - BASE) * HS)


## Offset from the node origin to the board's top-left corner on screen.
func board_origin() -> Vector2:
	return Vector2(-_dims().y * TW * 0.5, -_sky() * HS)


func _diamond(c: Vector2i, h: float) -> PackedVector2Array:
	return PackedVector2Array([iso(c.x, c.y, h), iso(c.x + 1, c.y, h), iso(c.x + 1, c.y + 1, h), iso(c.x, c.y + 1, h)])


## Cells grouped by draw depth, back first. With the skirt, the forest cells outside the grid join in and
## every depth shifts by 2 x the skirt's rings so they fit.
func _layers(with_skirt := false) -> Array:
	var off := 2 * look.skirt if with_skirt else 0
	var n := grid.w + grid.h + 1 + 2 * off
	var out := []
	out.resize(n)
	for i in n:
		out[i] = []
	for y in grid.h:
		for x in grid.w:
			out[clampi(depth_of(x, y) + off, 0, n - 1)].append(Vector2i(x, y))
	if with_skirt:
		for c: Vector2i in _skirt:
			if not grid.in_bounds(c):
				out[clampi(depth_of(c.x, c.y) + off, 0, n - 1)].append(c)
	return out


func pick(local: Vector2) -> Vector2i:
	# A piece's body wins over the ground under it, so a piece behind a tree or a block (drawn over it) can be clicked.
	var body := NONE
	var body_depth := -INF
	for u: CombatUnit in units:
		if u.shown_hp <= 0 or hidden(u.cell) or not _unit_box(u).has_point(local):
			continue
		var d := depth_of(u.vis.x, u.vis.y)
		if d > body_depth:
			body_depth = d
			body = u.cell
	if body != NONE:
		return body
	# Front-most cells first so taller blocks in front win.
	var layers := _layers()
	for i in range(layers.size() - 1, -1, -1):
		for c: Vector2i in layers[i]:
			if hidden(c) and not (edit_void and grid.terrain_at(c) == CombatGrid.T.VOID):
				continue
			if Geometry2D.is_point_in_polygon(local, _diamond(c, _surf(c))):
				return c
	return NONE


func _unhandled_key_input(event: InputEvent) -> void:
	if grid != null and event.pressed and not event.is_echo() and event.keycode == KEY_Q:
		turn(-1 if event.shift_pressed else 1)


func _unhandled_input(event: InputEvent) -> void:
	if grid == null:
		return
	if event is InputEventMouseMotion:
		var c := pick(get_local_mouse_position())
		if c != hover:
			hover = c
			cell_hovered.emit(c)
			if _paint_button != 0 and c != NONE:
				cell_painted.emit(c, _paint_button == MOUSE_BUTTON_RIGHT)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
			return
		if not mb.pressed:
			_paint_button = 0
			return
		var c := pick(get_local_mouse_position())
		_paint_button = mb.button_index
		cell_clicked.emit(c, mb.button_index == MOUSE_BUTTON_RIGHT)
		if c != NONE:
			cell_painted.emit(c, mb.button_index == MOUSE_BUTTON_RIGHT)


# --- drawing ------------------------------------------------------------------

# --- painting ---------------------------------------------------------------------------
# The board paints through slabs (children of _stack, back to front): the backdrop, then for every depth
#   GROUND  the still terrain (faces, lips, tops, stairs), drawn once and again only when its cells change,
#   OVER    what changes by the frame on top of it (falling water, the cursor, highlights, danger, areas),
#   PROPS   what stands on it (trees, boulders, placed props, the fog veil, the forest skirt), redrawn only
#           when a prop fades for a piece behind it or the fog moves,
#   UNITS   the pieces,
# then TOP with x-ray ghosts and floating numbers. A big map then costs little per frame. The draw helpers
# paint on _ci, the slab being drawn.

## One canvas in the board's painter's order.
class Slab extends Node2D:
	enum K { BACK, GROUND, OVER, PROPS, UNITS, TOP }
	const PER_DEPTH := 4
	var board: CombatBoard
	var kind := K.GROUND
	var depth := 0

	func _draw() -> void:
		board._paint(self)


func _init() -> void:
	_stack = Node2D.new()
	_stack.name = "Slabs"
	add_child(_stack)  # first child, so overlays hosts add later draw on top


func _slab(kind: int, d: int) -> Slab:
	return _slabs[1 + d * Slab.PER_DEPTH + kind - Slab.K.GROUND]


## Once a frame: work out which still slabs changed and redraw those, plus everything that moves.
func _sync_slabs() -> void:
	if grid == null:
		_stack.visible = false
		return
	_stack.visible = true
	if wallpaper:  # the wallpaper follows the view, so it repaints each frame
		queue_redraw()
	BattleArt.use_set(art_set)
	_resolve_look()
	var valley := _valley()
	if valley:
		_refresh_skirt()
	var gkey := "%d|%d|%d|%d|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [grid.get_instance_id(), grid.w, grid.h, rot, art_set, look.key(),
		strangeness, show_grid, backdrop, island, fog_on, wallpaper, soft]
	var lkey := "%s|%s" % [gkey, _skirt_key if valley else ""]
	if lkey != _layers_key:
		_layers_key = lkey
		_depths = _layers(valley)
		_off = 2 * look.skirt if valley else 0
		_build_slabs(_depths.size())
		_skirt_by_depth.clear()
		if valley:
			for c: Vector2i in _skirt:
				var d := clampi(depth_of(c.x, c.y) + _off, 0, _depths.size() - 1)
				if not _skirt_by_depth.has(d):
					_skirt_by_depth[d] = []
				_skirt_by_depth[d].append(c)
		for d in _depths.size():
			_dirty_props[d] = true
	if gkey != _ground_key:
		_ground_key = gkey
		_seen.clear()
		_fog_snap.clear()
		for d in _depths.size():
			_dirty[d] = true
		_snapshot_grid()
	elif grid.version != _snap_version:
		_diff_grid()
	if _soft():
		_refresh_shape()
	if fog_on:
		# Fog moves as the party walks: newly seen ground gets drawn, the veil and the forest skirt
		# (which follows the ground it grows from, a few rings out) redraw where sight changed.
		var lo := 1 << 30
		var hi := -1
		if fog.size() != _seen.size():
			for c: Vector2i in fog:
				if not _seen.has(c):
					_seen[c] = true
					_mark_near(c)
		var fh := fog.hash()
		if fh != _fog_hash:
			_fog_hash = fh
			for c: Vector2i in fog:
				if _fog_snap.get(c, 0) != fog[c]:
					_fog_snap[c] = fog[c]
					lo = mini(lo, _depth_at(c))
					hi = maxi(hi, _depth_at(c))
		for d in range(maxi(0, lo - _off - 2), mini(_depths.size(), hi + _off + 3)):
			_dirty_props[d] = true
	# Props see-through for a piece behind them, skirt trees for a piece, the cursor or a highlight.
	_find_cover()
	for k: Vector2i in _changed(_fade, _fade_prev):
		_dirty_props[_depth_at(_prop_front(k, grid.props[k]) if grid.props.has(k) else k)] = true
	for k: Vector2i in _changed(_skirt_fade, _skirt_fade_prev):
		_dirty_props[_depth_at(k)] = true
	_fade_prev = _fade.duplicate()
	_skirt_fade_prev = _skirt_fade.duplicate()
	for d: int in _dirty:
		if d < _depths.size():
			_fall_cells[d] = (_depths[d] as Array).filter(_has_fall)
			_prop_cells[d] = (_depths[d] as Array).filter(_has_props)
			_slab(Slab.K.GROUND, d).queue_redraw()
			_dirty_props[d] = true
	_dirty.clear()
	for d: int in _dirty_props:
		if d < _depths.size():
			_slab(Slab.K.PROPS, d).queue_redraw()
	_dirty_props.clear()
	# What moves: bucket this frame's overlays and pieces by depth, then redraw those slabs.
	_over_by_depth.clear()
	for dict: Dictionary in [highlights, danger, area]:
		for c: Vector2i in dict:
			_bucket(_over_by_depth, c)
	if hover != NONE and grid.in_bounds(hover):
		_bucket(_over_by_depth, hover)
	_units_by_depth.clear()
	for u: CombatUnit in units:
		if u.shown_hp > 0:
			var d := clampi(depth_of(u.vis.x, u.vis.y) + _off, 0, _depths.size() - 1)
			if not _units_by_depth.has(d):
				_units_by_depth[d] = []
			_units_by_depth[d].append(u)
	for sl: Slab in _slabs:
		if sl.kind == Slab.K.OVER or sl.kind == Slab.K.UNITS or sl.kind == Slab.K.BACK or sl.kind == Slab.K.TOP:
			sl.queue_redraw()


func _depth_at(c: Vector2i) -> int:
	return clampi(depth_of(c.x, c.y) + _off, 0, maxi(0, _depths.size() - 1))


## Keys in one set but not the other.
static func _changed(a: Dictionary, b: Dictionary) -> Array:
	var out := []
	for k in a:
		if not b.has(k):
			out.append(k)
	for k in b:
		if not a.has(k):
			out.append(k)
	return out


func _bucket(into: Dictionary, c: Vector2i) -> void:
	var d := _depth_at(c)
	if not into.has(d):
		into[d] = {}
	into[d][c] = true


## BACK, then GROUND, OVER, PROPS and UNITS for each depth, then TOP.
func _build_slabs(n: int) -> void:
	if _slabs.size() == 2 + n * Slab.PER_DEPTH:
		return
	for sl in _slabs:
		sl.queue_free()
	_slabs.clear()
	_fall_cells.clear()
	_fall_cells.resize(n)
	_prop_cells.clear()
	_prop_cells.resize(n)
	var add := func(kind: int, depth: int) -> void:
		var sl := Slab.new()
		sl.board = self
		sl.kind = kind
		sl.depth = depth
		_stack.add_child(sl)
		_slabs.append(sl)
	add.call(Slab.K.BACK, 0)
	for d in n:
		for kind in [Slab.K.GROUND, Slab.K.OVER, Slab.K.PROPS, Slab.K.UNITS]:
			add.call(kind, d)
		_fall_cells[d] = []
		_prop_cells[d] = []
		_dirty[d] = true
	add.call(Slab.K.TOP, 0)


func _snapshot_grid() -> void:
	_snap_h = grid.heights.duplicate()
	_snap_t = grid.terrain.duplicate()
	_snap_z = grid.zones.duplicate()
	_snap_props = grid.props.hash()
	_snap_version = grid.version


## After an edit: the slabs around each changed cell redraw (its faces, lips and stairs depend on its
## neighbours, theirs on it). A changed prop redraws them all.
func _diff_grid() -> void:
	if grid.props.hash() != _snap_props:
		for d in _depths.size():
			_dirty[d] = true
	elif grid.heights != _snap_h or grid.terrain != _snap_t or grid.zones != _snap_z:
		for i in grid.heights.size():
			if grid.heights[i] != _snap_h[i] or grid.terrain[i] != _snap_t[i] or grid.zones[i] != _snap_z[i]:
				_mark_near(Vector2i(i % grid.w, i / grid.w))
	_snapshot_grid()


func _mark_near(c: Vector2i) -> void:
	var d := depth_of(c.x, c.y) + _off
	for k in range(d - 2, d + 3):
		if k >= 0 and k < _depths.size():
			_dirty[k] = true


func _has_fall(c: Vector2i) -> bool:
	return grid.in_bounds(c) and grid.terrain_at(c) == CombatGrid.T.WATER


## Something stands on the cell: a placed prop, the tile set's trees or boulders, or a graybox shape.
func _has_props(c: Vector2i) -> bool:
	if not grid.in_bounds(c):
		return false
	var t := grid.terrain_at(c)
	if t == CombatGrid.T.VOID:
		return false
	if t == CombatGrid.T.WATER or t == CombatGrid.T.FOREST or t == CombatGrid.T.ROCK or t == CombatGrid.T.RUIN:
		return true
	if grid.prop_anchor(c) != CombatGrid.NONE_CELL:
		return true
	var art := BattleArt.props(t, grid.zone_at(c))
	return not art.list.is_empty() and art.count > 0


## Never drawn: no ground, or never seen under fog of war.
func _unseen(c: Vector2i) -> bool:
	return not grid.in_bounds(c) or grid.terrain_at(c) == CombatGrid.T.VOID or (fog_on and not fog.has(c))


func _paint(sl: Slab) -> void:
	if grid == null or _depths.is_empty():
		return
	_ci = sl
	BattleArt.use_set(art_set)
	match sl.kind:
		Slab.K.BACK:
			_paint_back()
		Slab.K.GROUND:
			for c: Vector2i in _depths[sl.depth]:
				if not _unseen(c):
					_draw_ground(c)
		Slab.K.OVER:
			for c: Vector2i in _fall_cells[sl.depth]:
				if not hidden(c):
					_draw_falls(c)
			for c: Vector2i in _over_by_depth.get(sl.depth, {}):
				if not hidden(c):
					_draw_over(c)
		Slab.K.PROPS:
			_paint_props(sl.depth)
		Slab.K.UNITS:
			if edit_void:
				for c: Vector2i in _depths[sl.depth]:
					if grid.in_bounds(c) and grid.terrain_at(c) == CombatGrid.T.VOID:
						_ci.draw_polyline(_ring(_diamond(c, 0.0)), Color(1, 1, 1, 0.5 if c == hover else 0.14), 1.0, true)
			for u: CombatUnit in _units_by_depth.get(sl.depth, []):
				_draw_unit(u)
		Slab.K.TOP:
			_paint_top()
	_ci = self


func _paint_back() -> void:
	if not backdrop or _wall_tex() != null:
		return
	var plate := BattleArt.texture("backdrop")
	if plate != null:  # a set with a painted plate draws that instead of the code bands
		_draw_plate(plate)
		return
	if _valley():
		MapBackdrop.draw(_ci, self, look, _local_view())
		if fog_on:  # the unexplored world sinks back so what the party has seen stands out
			_ci.draw_rect(_local_view(), Color(look.color("wood").darkened(0.3), 0.55))
	elif look.staging == "island":
		_draw_backdrop()


func _paint_props(d: int) -> void:
	for c: Vector2i in _prop_cells[d]:
		if not _unseen(c):
			_draw_props(c)
	if fog_on:
		for c: Vector2i in _depths[d]:
			if fog.get(c, 0) == 1 and not _unseen(c):
				_veil(c)
	for c: Vector2i in _skirt_by_depth.get(d, []):
		_draw_skirt(c)


func _paint_top() -> void:
	var font := ThemeDB.fallback_font
	# Ghost pass: pieces something in front hides still show, over everything: a party sprite as a tinted
	# see-through copy (x-ray), anyone else as a bright foot ring and head outline.
	for u: CombatUnit in units:
		if u.shown_hp > 0 and _covered.has(u):
			var base := _unit_base(u)
			var ring := Color(0.4, 0.7, 1.0) if u.team == 0 else Color(1.0, 0.4, 0.35)
			Pawn.ellipse(_ci, base, 26.0 * 0.62, 26.0 * 0.22, Color(ring, 0.85), false, 2.0)
			if CharacterArt.has_art(u.sprite):
				_draw_frame(u, base, Color(ring.lightened(0.3), 0.55))
			else:
				_ci.draw_arc(base + Vector2(0, -26.0 * 1.22), 26.0 * 0.3, 0, TAU, 20, Color(ring, 0.7), 2.0, true)
	for f in _floaters:
		var a := clampf(f.t, 0.0, 1.0)
		_ci.draw_string_outline(font, f.pos, f.text, HORIZONTAL_ALIGNMENT_CENTER, 120, 16, 4, Color(0, 0, 0, a))
		_ci.draw_string(font, f.pos, f.text, HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color(f.color, a))


## Not drawn: never seen under fog of war, or off screen on a big map.
static func _ring(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out


func hidden(c: Vector2i) -> bool:
	if grid.terrain_at(c) == CombatGrid.T.VOID:
		return true
	if fog_on and not fog.has(c):
		return true
	return cull.has_area() and not cull.has_point(cell_top(c))


## Remembered but out of sight: a dark wash over the top and the two faces toward the camera.
func _veil(c: Vector2i) -> void:
	var h := _surf(c)
	var col := Color(0.06, 0.07, 0.1, 0.55)
	_ci.draw_colored_polygon(_diamond(c, h), col)
	for shade in [false, true]:
		var d := front_dir(shade)
		var n := c + d
		var nh := _surf_or_floor(n)
		var low := maxf(_floor(), minf(nh, h))
		if low >= h:
			continue
		var e := _side(Vector2(c), Vector2(c) + Vector2.ONE, d)
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		_ci.draw_colored_polygon(PackedVector2Array([iso(a.x, a.y, h), iso(b.x, b.y, h), iso(b.x, b.y, low), iso(a.x, a.y, low)]), col)


func _terrain_color(t: int) -> Color:
	return (TOP_COLORS[t] as Color).lerp(ALIEN_COLORS[t], strangeness)


## Multiplier that drifts painted art toward the alien palette as strangeness rises.
func _tint(t: int) -> Color:
	var a: Color = TOP_COLORS[t]
	var b: Color = ALIEN_COLORS[t]
	return Color.WHITE.lerp(Color(b.r / a.r, b.g / a.g, b.b / a.b), strangeness)


## The still part of a cell (GROUND slab): its faces down to the neighbours in front, grass lips, the top,
## stairs, ledge lines. Falling water, overlays and props are drawn by the LIVE slab.
func _draw_ground(c: Vector2i) -> void:
	if _soft():
		_draw_ground_soft(c)
		return
	var t := grid.terrain_at(c)
	var h := _surf(c)
	var top_col := _terrain_color(t).lightened(minf(h, 6.0) * 0.025)
	var built := t == CombatGrid.T.STONE or t == CombatGrid.T.STAIRS or t == CombatGrid.T.RUIN
	var face := (MASONRY if built else CLIFF).lerp(ALIEN_CLIFF, strangeness)
	if t == CombatGrid.T.WATER:
		face = MASONRY.lerp(ALIEN_CLIFF, strangeness)
	var seed_v := _hash(c)
	var zone := grid.zone_at(c)  # "" = the map's set
	var top_tex := BattleArt.top(t, zone)
	var side_tex := BattleArt.side(t, zone)
	var tint := _tint(t)
	var fl := _floor()
	var lip := 0.0 if built or t == CombatGrid.T.WATER else BattleArt.lip(t, zone)
	var stepped := t == CombatGrid.T.STAIRS and _stair_steps(c, h, top_tex, side_tex, tint, face, seed_v)
	var top := _diamond(c, h)
	var tl := top[0]
	var tr := top[1]
	var br := top[2]
	var bl := top[3]
	if not stepped:
		# The two faces turned toward the camera: lit (lower-left) and shade (lower-right). Only the part
		# above the neighbour shows, but painting down to it is fine because nearer cells paint over the rest.
		var moss := _terrain_color(CombatGrid.T.GRASS if t != CombatGrid.T.FOREST else t).darkened(0.08)
		var low := {}
		var lips: Array = []
		for shade in [false, true]:
			var d := front_dir(shade)
			var n := c + d
			var edge := not grid.solid(n)  # the outline: the face runs down to the floor (or hangs below the base)
			var nh := fl if edge else _surf(n)
			low[shade] = nh
			var side := _side(Vector2(c), Vector2(c) + Vector2.ONE, d)
			var col := face.darkened(0.32 if shade else 0.12)
			# Painted sides keep the guide's values: lit 75% of the top (baked into the art), shade 55%.
			var mod := Color(tint * (0.72 if shade else 1.0), 1.0)
			var foot := maxf(fl, minf(nh, h))
			_face(side[0], side[1], h, foot, col, seed_v + (7 if shade else 0), not built, false, side_tex, mod)
			if h - foot > 1.0:
				_face_ao(side[0], side[1], h, foot)
			if edge and _valley():
				_face_mist(side[0], side[1], h, foot)
			if edge and _rims():
				var rock := BattleArt.average(side_tex) * mod if side_tex != null else col
				_underside(side[0], side[1], Color(rock, 1.0) * (0.9 if shade else 1.0), seed_v + (3 if shade else 0), d)
			if nh >= h:
				continue
			if t == CombatGrid.T.WATER:
				pass  # the fall itself moves: _draw_falls
			elif lip > 0.0:
				lips.append([side[0], side[1], h - foot, d, shade])
			elif not built and t != CombatGrid.T.ROAD and side_tex == null:  # graybox only: the flat art has no drips
				_drips(side[0], side[1], h, h - nh, moss.darkened(0.15 if shade else 0.0), seed_v + (11 if shade else 0))
		_ink_corners(c, h, low)
		for l: Array in lips:
			_lip(l[0], l[1], h, l[2], l[3], top_tex, top_col, tint, l[4], lip)
		if top_tex != null:
			var uv := PackedVector2Array()
			for k in [Vector2(c), Vector2(c.x + 1, c.y), Vector2(c) + Vector2.ONE, Vector2(c.x, c.y + 1)]:
				uv.append(k / BattleArt.TOP_TILES)
			var lift := Color(tint * (1.0 + minf(h, 6.0) * 0.025), 1.0)
			_ci.draw_polygon(top, PackedColorArray([lift, lift, lift, lift]), uv, top_tex)
		else:
			_ci.draw_colored_polygon(top, top_col)
		if blend:
			_fringe(c, t, h, zone)
	var lit_edge := _side(Vector2(c), Vector2(c) + Vector2.ONE, front_dir(false))
	var shade_edge := _side(Vector2(c), Vector2(c) + Vector2.ONE, front_dir(true))
	match t:
		CombatGrid.T.STONE:
			if top_tex == null:  # painted stone has its own slab joints
				var line := top_col.darkened(0.18)
				_ci.draw_line(iso(c.x + 0.5, c.y, h), iso(c.x + 0.5, c.y + 1, h), line, 1.0, true)
				_ci.draw_line(iso(c.x, c.y + 0.5, h), iso(c.x + 1, c.y + 0.5, h), line, 1.0, true)
				if seed_v % 3 == 0:
					_ci.draw_line(iso(c.x + 0.2, c.y + 0.6, h), iso(c.x + 0.35, c.y + 0.85, h), line, 1.0, true)
		CombatGrid.T.STAIRS:
			if not stepped:
				_stairs(c, h, top_col)
	_contact_shadow(c, h)
	var edge := top_col.darkened(0.55)
	if show_grid:
		_ci.draw_polyline(PackedVector2Array([tl, tr, br, bl, tl]), Color(edge, 0.5 if top_tex == null else 0.2), 1.0, true)
	if not stepped:
		for shade in [false, true]:
			var e: Array = shade_edge if shade else lit_edge
			var n := c + front_dir(shade)
			if show_grid or not grid.solid(n) or _surf(n) < h:
				_ci.draw_line(iso(e[0].x, e[0].y, h), iso(e[1].x, e[1].y, h), Color(top_col.lightened(0.35), 0.8), 1.5, true)


# --- the soft terrain pass ------------------------------------------------------------------
# The same cells drawn as one hand-shaped ground (docs/design/terrain-engine.md): a block's corners round off
# where both its sides drop away, with the lower ground showing in the bit cut away; cliff faces are textured
# along the screen and down from the cliff's own top, so their pattern runs on across cells and round corners
# and never lines up with the grid; the lip hangs along the whole outline; water carries flow strokes from
# TerrainShape; ink only where a block stands out against what's behind it.

const LIP_LIT := Color(0.88, 0.92, 1.0)  ## a lip's front on the lit side: a little darker than its top, cool (B12)
const LIP_SHADE := Color(0.68, 0.76, 0.92)  ## and on the shade side: blue
const DRIFT_LIT := Color(0.96, 0.97, 1.0)  ## snow piled at a wall's foot, lit side
const DRIFT_SHADE := Color(0.8, 0.86, 0.97)  ## and shade side


func _soft() -> bool:
	return soft and look.staging != "plain"


## Soft pass caches: every cell's corner radii, where every outline line starts and stops (so a line that just
## hands over to the next cell's carries on and only a line that really stops tapers off, _pen_end), and the
## water's flow strokes. An edit only redoes the cells near it (a brush stroke on a big map stays cheap); a new
## map, floor or view turn redoes them all. Strokes are rebuilt only when the water changes, and then every
## row redraws, since a stroke runs the length of a river.
func _refresh_shape() -> void:
	var base := "%d|%d|%d|%s|%d" % [grid.get_instance_id(), grid.w, grid.h, _floor(), rot]
	if base == _shape_base and grid.version == _shape_version:
		return
	var full := base != _shape_base or _shape_h.size() != grid.heights.size()
	var changed := {}
	var wet := full  # the water may have changed: its strokes need a look
	if not full and (grid.heights != _shape_h or grid.terrain != _shape_t):
		for i in grid.heights.size():
			if grid.heights[i] != _shape_h[i] or grid.terrain[i] != _shape_t[i]:
				changed[Vector2i(i % grid.w, i / grid.w)] = true
				wet = wet or grid.terrain[i] == CombatGrid.T.WATER or _shape_t[i] == CombatGrid.T.WATER
				if changed.size() > SHAPE_LOCAL:
					full = true
					wet = true
					break
	_shape_base = base
	_shape_version = grid.version
	_shape_h = grid.heights.duplicate()
	_shape_t = grid.terrain.duplicate()
	if full:
		_radii.clear()
		_pen_ends.clear()
		_pen_by_cell.clear()
		for y in grid.h:
			for x in grid.w:
				_shape_radii(Vector2i(x, y))
		for y in grid.h:
			for x in grid.w:
				_shape_pens(Vector2i(x, y))
	elif not changed.is_empty():
		# A cell's corners depend on its neighbours; its lines on theirs (fillets, stair runs) too.
		for c: Vector2i in _around(changed, 1):
			_shape_radii(c)
		for c: Vector2i in _around(changed, 3):
			_shape_pens(c)
	if not wet:
		return
	var water := PackedInt32Array()
	for i in grid.terrain.size():
		if grid.terrain[i] == CombatGrid.T.WATER:
			water.append(i)
			water.append(grid.heights[i])
	if hash(water) != _water_sig:
		_water_sig = hash(water)
		_streams = TerrainShape.by_cell(TerrainShape.strokes(grid, TerrainShape.flow(grid)))
		for d in _depths.size():
			_dirty[d] = true


const SHAPE_LOCAL := 64  ## an edit touching more cells than this redoes the whole map


## The grid cells within `reach` steps (diagonals count as one) of any of `cells`.
func _around(cells: Dictionary, reach: int) -> Dictionary:
	var out := {}
	for c: Vector2i in cells:
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var n := c + Vector2i(dx, dy)
				if grid.in_bounds(n):
					out[n] = true
	return out


func _shape_radii(c: Vector2i) -> void:
	if grid.solid(c):
		_radii[c] = TerrainShape.radii(grid, c, _surf_or_floor)
	else:
		_radii.erase(c)


## Swap one cell's outline line ends in _pen_ends for its current ones.
func _shape_pens(c: Vector2i) -> void:
	for e: Vector3i in _pen_by_cell.get(c, []):
		var left := int(_pen_ends.get(e, 0)) - 1
		if left > 0:
			_pen_ends[e] = left
		else:
			_pen_ends.erase(e)
	_pen_by_cell.erase(c)
	if not grid.solid(c):
		return
	var t := grid.terrain_at(c)
	if t == CombatGrid.T.WATER or (t == CombatGrid.T.STAIRS and not MapDress.stair_run(grid, c).is_empty()):
		return
	var h := _surf(c)
	var o := _soft_outline(c, h)
	var mine := []
	for piece: Dictionary in _line_pieces(c, h, o.segs, o.feet, o.shown):
		for e: Vector3i in _piece_ends(piece):
			_pen_ends[e] = int(_pen_ends.get(e, 0)) + 1
			mine.append(e)
	_pen_by_cell[c] = mine


func _radii_of(c: Vector2i) -> PackedFloat32Array:
	return _radii.get(c, PackedFloat32Array([0.0, 0.0, 0.0, 0.0]))


func _draw_ground_soft(c: Vector2i) -> void:
	var t := grid.terrain_at(c)
	var h := _surf(c)
	var zone := grid.zone_at(c)
	var tint := _tint(t)
	var top_tex := BattleArt.top(t, zone)
	var top_col := _terrain_color(t).lightened(minf(h, 6.0) * 0.025)
	if t == CombatGrid.T.STAIRS and _stair_steps_soft(c, h):
		_contact_shadow(c, h)
		return
	var r := _radii_of(c)
	var o := _soft_outline(c, h)
	var segs: Array = o.segs
	var feet: Array = o.feet
	var shown: Array = o.shown
	for k in 4:
		if r[k] > 0.0:
			_gap_floor(c, k, r[k])
	# River walls are the rock around them, not the set's masonry.
	var side_t := CombatGrid.T.GRASS if t == CombatGrid.T.WATER else t
	var body := BattleArt.side_body(side_t, zone)
	var built := t == CombatGrid.T.STONE or t == CombatGrid.T.RUIN
	var face := (MASONRY if built else CLIFF).lerp(ALIEN_CLIFF, strangeness)
	# Faces, and the runs of shown segments that drop (each gets one unbroken lip).
	var runs := []
	var run := []
	for i in segs.size():
		var s: Dictionary = segs[i]
		var foot: float = feet[i]
		if shown[i] and foot < h - 0.01:
			_soft_face(s.a, s.b, s.na, s.nb, h, foot, body, _tint(side_t), face)
			if foot <= _floor() + 0.01 and _valley():
				_face_mist(s.a, s.b, h, foot)
			run.append([s, foot])
		elif not run.is_empty():
			runs.append(run)
			run = []
	if not run.is_empty():
		if not runs.is_empty() and shown[0] and feet[0] < h - 0.01:
			run.append_array(runs[0])  # the outline is a loop: the last run carries on into the first
			runs[0] = run
		else:
			runs.append(run)
	_soft_drifts(c, h, segs, feet, shown)
	var lip := _soft_lip_depth(t, zone)
	if lip > 0.0:
		for rn: Array in runs:
			_soft_lip(rn, h, top_tex, tint, top_col, lip)
	# The top.
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for s: Dictionary in segs:
		pts.append(iso(s.a.x, s.a.y, h))
		uvs.append(s.a / BattleArt.TOP_TILES)
	if top_tex != null:
		var lift := Color(tint * (1.0 + minf(h, 6.0) * 0.025), 1.0)
		var cols := PackedColorArray()
		cols.resize(pts.size())
		cols.fill(lift)
		_ci.draw_polygon(pts, cols, uvs, top_tex)
	else:
		_ci.draw_colored_polygon(pts, top_col)
	# The renderer can't antialias polygons, so a hairline of the top's own colour smooths its seen edges.
	var rim := (BattleArt.average(top_tex) * Color(tint * (1.0 + minf(h, 6.0) * 0.025), 1.0)) if top_tex != null else top_col
	for rn: Array in runs:
		var edge := PackedVector2Array()
		for item: Array in rn:
			edge.append(iso(item[0].a.x, item[0].a.y, h))
		var tail: Dictionary = rn[rn.size() - 1][0]
		edge.append(iso(tail.b.x, tail.b.y, h))
		_ci.draw_polyline(edge, Color(rim, 1.0), 1.0, true)
	if blend:
		_fringe(c, t, h, zone)
	if t == CombatGrid.T.WATER:
		_water_marks(c, h, top_col)
	_contact_shadow(c, h)
	for k in 4:
		if r[k] < 0.0:
			_fillet(c, k, -r[k])
	# The pen outline (see _line_pieces).
	if t != CombatGrid.T.WATER:
		for piece: Dictionary in _line_pieces(c, h, segs, feet, shown):
			if piece.along:
				var gp: Array = piece.pts
				_marker_along(gp, piece.z, _pen_end(gp[0], piece.z), _pen_end(gp[gp.size() - 1], piece.z))
			else:
				_marker_down(piece.p, piece.top, piece.low, _pen_end(piece.p, piece.top), _pen_end(piece.p, piece.low))
	if show_grid:
		var d := _diamond(c, h)
		_ci.draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), Color(top_col.darkened(0.55), 0.2), 1.0, true)


const WATERLINE := 0.1  ## the waterline outline sits this far (levels) up the face, clear of the water in front


## A cell's outline (TerrainShape.outline with its corner radii) and, per segment, how far it drops ("feet")
## and whether it faces the camera ("shown").
func _soft_outline(c: Vector2i, h: float) -> Dictionary:
	var segs := TerrainShape.outline(c, _radii_of(c))
	var toward := Vector2(front_dir(false) + front_dir(true))
	var feet := []
	var shown := []
	for s: Dictionary in segs:
		feet.append(_seg_foot(c, s, h))
		shown.append((s.na + s.nb).dot(toward) > 0.02)
	return {"segs": segs, "feet": feet, "shown": shown}


## The outline lines a cell draws, where it stands out against what's behind it: along the back of its top
## where the ground behind is lower, down its sides where its faces turn away, and along the waterline where
## its faces go down into water. Never its front edges or a foot on dry ground. Each is
## {"along": true, "pts": grid points, "z": level} or {"along": false, "p": grid point, "top", "low"}.
func _line_pieces(c: Vector2i, h: float, segs: Array, feet: Array, shown: Array) -> Array:
	var out := []
	var back := []
	for i in segs.size():
		var s: Dictionary = segs[i]
		var foot: float = feet[i]
		if not shown[i] and foot < h - 0.5:
			var a: Vector2 = s.a
			var b: Vector2 = s.b
			if s.edge >= 0:  # stop where the lower neighbour's ground curves up to this one (its fillet)
				var n: Vector2i = c + TerrainShape.NORMALS[s.edge]
				var nr := _radii_of(n)
				for k in 4:
					var at: Vector2 = Vector2(n) + TerrainShape.CORNERS[k]
					if nr[k] < 0.0 and at.is_equal_approx(s.a):
						a = a.move_toward(b, -nr[k])
					elif nr[k] < 0.0 and at.is_equal_approx(s.b):
						b = b.move_toward(a, -nr[k])
			if not back.is_empty() and not a.is_equal_approx(back[back.size() - 1]):
				out.append({"along": true, "pts": back, "z": h})
				back = []
			if back.is_empty():
				back.append(a)
			back.append(b)
		elif not back.is_empty():
			out.append({"along": true, "pts": back, "z": h})
			back = []
		var j := (i + 1) % segs.size()
		if shown[i] != shown[j]:
			var low := maxf(foot, feet[j])
			if low < h - 0.25:
				out.append({"along": false, "p": s.b, "top": h, "low": low})
	if back.size() > 1:
		out.append({"along": true, "pts": back, "z": h})
	# The waterline, drawn on the face just above the water so the water in front doesn't cover it.
	var wet := []
	var wet_h := 0.0
	for i in segs.size():
		var s: Dictionary = segs[i]
		var foot: float = feet[i]
		if shown[i] and foot < h - 0.3 and _into_water(c, s):
			if not wet.is_empty() and (absf(foot - wet_h) > 0.01 or not (wet[wet.size() - 1] as Vector2).is_equal_approx(s.a)):
				out.append({"along": true, "pts": wet, "z": wet_h + WATERLINE})
				wet = []
			if wet.is_empty():
				wet.append(s.a)
				wet_h = foot
			wet.append(s.b)
		elif not wet.is_empty():
			out.append({"along": true, "pts": wet, "z": wet_h + WATERLINE})
			wet = []
	if wet.size() > 1:
		out.append({"along": true, "pts": wet, "z": wet_h + WATERLINE})
	return out


static func _pen_key(p: Vector2, z: float) -> Vector3i:
	return Vector3i(roundi(p.x * 64.0), roundi(p.y * 64.0), roundi(z * 64.0))


static func _piece_ends(piece: Dictionary) -> Array:
	if piece.along:
		var pts: Array = piece.pts
		return [_pen_key(pts[0], piece.z), _pen_key(pts[pts.size() - 1], piece.z)]
	return [_pen_key(piece.p, piece.top), _pen_key(piece.p, piece.low)]


## Does an outline line stop here (no other line carries on from this point)? Then the pen lifts: it tapers.
func _pen_end(p: Vector2, z: float) -> bool:
	return int(_pen_ends.get(_pen_key(p, z), 0)) < 2


## Where a wall rises from a floor, the floor's snow piles up against its foot in drifts, like the key art's
## snow banks: a band of the floor's own ground up the bottom of the face, its top swelling into mounds. Only
## ground with a `drift` depth in its set's table does it (snow).
func _soft_drifts(c: Vector2i, h: float, segs: Array, feet: Array, shown: Array) -> void:
	var run := []
	var run_floor := NONE
	var run_foot := 0.0
	for i in segs.size():
		var s: Dictionary = segs[i]
		var foot: float = feet[i]
		var f := _drift_floor(c, s) if shown[i] and foot < h - 0.3 else NONE
		var joins: bool = not run.is_empty() and f == run_floor and absf(foot - run_foot) < 0.01 \
			and (run[run.size() - 1].b as Vector2).is_equal_approx(s.a)
		if not run.is_empty() and not joins:
			_drift(run, run_foot, run_floor, h)
			run = []
		if f != NONE:
			if run.is_empty():
				run_floor = f
				run_foot = foot
			run.append(s)
	if not run.is_empty():
		_drift(run, run_foot, run_floor, h)


## The floor a stretch of wall rises from (its neighbour, or the ground in its rounded corner), when that
## floor piles snow; else NONE.
func _drift_floor(c: Vector2i, s: Dictionary) -> Vector2i:
	var n: Vector2i
	if s.edge >= 0:
		n = c + TerrainShape.NORMALS[s.edge]
	else:
		var g := TerrainShape.gap(grid, c, s.corner, _surf_or_floor)
		if not g.has("src"):
			return NONE
		n = g.src
	if not grid.solid(n) or grid.terrain_at(n) == CombatGrid.T.WATER:
		return NONE
	return n if BattleArt.drift(grid.terrain_at(n), grid.zone_at(n)) > 0.0 else NONE


func _drift(run: Array, foot: float, f: Vector2i, h: float) -> void:
	var t := grid.terrain_at(f)
	var zone := grid.zone_at(f)
	var depth := BattleArt.drift(t, zone)
	var tex := BattleArt.top(t, zone)
	var base := _tint(t) if tex != null else _terrain_color(t)
	var avg := BattleArt.average(tex) if tex != null else Color.WHITE
	var pts: Array[Vector2] = []
	var nrm: Array[Vector2] = []
	for s: Dictionary in run:
		var steps := maxi(1, ceili((s.b - s.a).length() / 0.05))
		for i in steps:
			var k := float(i) / steps
			pts.append(s.a.lerp(s.b, k))
			nrm.append(s.na.lerp(s.nb, k).normalized())
	var last: Dictionary = run[run.size() - 1]
	pts.append(last.b)
	nrm.append(last.nb)
	var n := pts.size()
	var room := (h - foot) * 0.6
	var poly := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var edge := PackedVector2Array()
	var ecols := PackedColorArray()
	for i in n:  # along the foot
		poly.append(iso(pts[i].x, pts[i].y, foot))
		uvs.append(pts[i] / BattleArt.TOP_TILES)
		cols.append(_drift_colour(base, nrm[i]))
	for i in range(n - 1, -1, -1):  # back along its top, mounding up
		var dh := minf(TerrainShape.drift_height(_screen_u(pts[i], 0.0) + 7.3, depth), room)
		var col := _drift_colour(base, nrm[i])
		poly.append(iso(pts[i].x, pts[i].y, foot + dh))
		uvs.append((pts[i] + nrm[i] * dh * 0.3) / BattleArt.TOP_TILES)
		cols.append(col)
		edge.append(iso(pts[i].x, pts[i].y, foot + dh))
		ecols.append(Color(avg * col, 1.0))
	if tex != null:
		_ci.draw_polygon(poly, cols, uvs, tex)
	else:
		_ci.draw_polygon(poly, cols)
	_ci.draw_polyline_colors(edge, ecols, 1.0, true)


## A drift faces up more than a wall does: nearly its floor's own value on the lit side, cool on the shade side.
func _drift_colour(base: Color, n: Vector2) -> Color:
	return Color(base * (DRIFT_LIT if _face_light(n) > 0.9 else DRIFT_SHADE), 1.0)


## Does this stretch of a cell's outline go down into water (its neighbour, or the ground in its rounded corner)?
func _into_water(c: Vector2i, s: Dictionary) -> bool:
	var n: Vector2i
	if s.edge >= 0:
		n = c + TerrainShape.NORMALS[s.edge]
	else:
		var g := TerrainShape.gap(grid, c, s.corner, _surf_or_floor)
		if not g.has("src"):
			return false
		n = g.src
	return grid.solid(n) and grid.terrain_at(n) == CombatGrid.T.WATER


## How far down a stretch of a cell's outline drops: a side to its neighbour, a rounded corner to the
## ground left in it (the floor where there is no ground).
func _seg_foot(c: Vector2i, s: Dictionary, h: float) -> float:
	var low: float
	if s.edge >= 0:
		var n: Vector2i = c + TerrainShape.NORMALS[s.edge]
		low = _surf_or_floor(n)
		if grid.solid(n) and grid.terrain_at(n) == CombatGrid.T.STAIRS:  # its low steps sit under its own level
			var run := MapDress.stair_run(grid, n)
			if not run.is_empty():
				low = minf(low, float(run.lo))
	else:
		low = TerrainShape.gap(grid, c, s.corner, _surf_or_floor).h
	return maxf(_floor(), minf(low, h))


## A face's light by the way it faces: 1 lit (lower left) or 0.72 shade (lower right). Two flat values and a
## clean step between them, never a blend, so a rounded corner stays a painted corner, not a cylinder.
func _face_light(n: Vector2) -> float:
	return 1.0 if n.dot(Vector2(front_dir(false))) >= n.dot(Vector2(front_dir(true))) else 0.72


## Where a grid point sits across the screen, in cell widths, shifted by the cliff's top so stacked walls
## don't repeat each other. Cliff textures run along this, so they continue from cell to cell and round
## every corner.
func _screen_u(p: Vector2, top: float) -> float:
	var q := _rot(p.x, p.y)
	return q.x - q.y + top * 0.73


const MARKER := Color(0.3, 0.35, 0.48)  ## the outline: a cool slate blue, between the key art's line over rock and over snow
const PEN_WIDTH := 1.5  ## the outline's width in engine px at full pressure
const PEN_ALPHA := 0.7  ## see-through ink: what's under it shows a little
const PEN_TAPER := 3.0  ## how far (engine px) a line narrows to a point where the pen lifts


## A pen outline along screen points, like the key art's: a crisp, see-through slate stroke whose width swells
## and thins with the hand's pressure, that wavers a touch, and now and then tapers off and starts again.
## Drawn as one strip of triangles, so its edges stay sharp and its ink even (no blur, no darker joins). Its
## look is a function of `ss` (each point's place along the screen), so a line drawn one cell at a time carries
## on unbroken from cell to cell. Where the line really stops (`taper_a`, `taper_b`) the pen lifts: the
## stroke narrows to a rounded point instead of ending square.
func _marker(pts: PackedVector2Array, ss: PackedFloat32Array, taper_a := true, taper_b := true) -> void:
	var n := pts.size()
	if n < 2:
		return
	var along := PackedFloat32Array([0.0])
	for i in range(1, n):
		along.append(along[i - 1] + pts[i].distance_to(pts[i - 1]))
	var total := along[n - 1]
	var verts := PackedVector2Array()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var edge := PackedColorArray()
	for i in n:
		var d := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := Vector2(-d.y, d.x)
		var s := ss[i]
		var p := pts[i] + side * (TerrainShape.noise1(s * 3.1, 3) - 0.5) * 1.0
		var on := smoothstep(0.16, 0.3, TerrainShape.noise1(s * 0.7, 7))  # lifts off now and then
		if taper_a:
			on *= sqrt(clampf(along[i] / PEN_TAPER, 0.0, 1.0))
		if taper_b:
			on *= sqrt(clampf((total - along[i]) / PEN_TAPER, 0.0, 1.0))
		var w := PEN_WIDTH * (0.7 + 0.6 * TerrainShape.noise1(s * 1.9, 11)) * on
		left.append(p + side * w * 0.5)
		right.append(p - side * w * 0.5)
		verts.append(p + side * w * 0.5)
		verts.append(p - side * w * 0.5)
		edge.append(Color(MARKER, PEN_ALPHA * 0.45 * minf(on * 3.0, 1.0)))
	var idx := PackedInt32Array()
	for i in n - 1:
		var a := i * 2
		idx.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))
	var cols := PackedColorArray()
	cols.resize(verts.size())
	cols.fill(Color(MARKER, PEN_ALPHA))
	RenderingServer.canvas_item_add_triangle_array(_ci.get_canvas_item(), idx, verts, cols)
	# A hairline down each edge smooths the stair-steps without softening the stroke.
	_ci.draw_polyline_colors(left, edge, 1.0, true)
	_ci.draw_polyline_colors(right, edge, 1.0, true)


## A marker line along grid points on one level (the back of a block's top, a waterline).
func _marker_along(gpts: Array, h: float, taper_a := true, taper_b := true) -> void:
	var pts := PackedVector2Array()
	var ss := PackedFloat32Array()
	for i in gpts.size() - 1:
		var a: Vector2 = gpts[i]
		var b: Vector2 = gpts[i + 1]
		var steps := maxi(1, ceili(a.distance_to(b) / 0.12))
		for k in steps:
			var p := a.lerp(b, float(k) / steps)
			pts.append(iso(p.x, p.y, h))
			ss.append(_screen_u(p, 0.0) + h * 0.37)
	var e: Vector2 = gpts[gpts.size() - 1]
	pts.append(iso(e.x, e.y, h))
	ss.append(_screen_u(e, 0.0) + h * 0.37)
	_marker(pts, ss, taper_a, taper_b)


## A marker line straight down a block's side at grid point p, from `top` to `low`.
func _marker_down(p: Vector2, top: float, low: float, taper_a := true, taper_b := true) -> void:
	var pts := PackedVector2Array()
	var ss := PackedFloat32Array()
	var steps := maxi(2, ceili((top - low) / 0.25))
	for k in steps + 1:
		var z := lerpf(top, low, float(k) / steps)
		pts.append(iso(p.x, p.y, z))
		ss.append(_screen_u(p, 0.0) * 1.7 + z * 0.45 + 13.0)
	_marker(pts, ss, taper_a, taper_b)


## One stretch of cliff face from a to b (grid points), from `top` down to `foot`, in the rock of
## BattleArt.side_body. The texture runs along the screen and hangs from `anchor` (the cliff's own top unless
## given), so it carries on from cell to cell and round corners, and its pattern never lines up with the grid.
func _soft_face(a: Vector2, b: Vector2, na: Vector2, nb: Vector2, top: float, foot: float, body: Dictionary,
		tint: Color, col: Color, anchor := INF) -> void:
	if top <= foot:
		return
	var quad := PackedVector2Array([iso(a.x, a.y, top), iso(b.x, b.y, top), iso(b.x, b.y, foot), iso(a.x, a.y, foot)])
	var light := _face_light(na + nb)
	if body.is_empty():
		_ci.draw_colored_polygon(quad, Color(col * light, 1.0))
		return
	var ca := Color(tint * light, 1.0)
	var cb := ca
	var from := top if anchor == INF else anchor
	var ua := _screen_u(a, from) / float(body.u)
	var ub := _screen_u(b, from) / float(body.u)
	var vt := (from - top) / float(body.v)
	var vb := (from - foot) / float(body.v)
	_ci.draw_polygon(quad, PackedColorArray([ca, cb, cb, ca]),
		PackedVector2Array([Vector2(ua, vt), Vector2(ub, vt), Vector2(ub, vb), Vector2(ua, vb)]), body.tex)


## The lower ground showing where corner k was rounded off: the neighbour's own top (same texture at the same
## world spot, so it runs on unbroken), its face down to the other neighbour when that one is lower, and
## foam where it is water.
func _gap_floor(c: Vector2i, k: int, r: float) -> void:
	var g := TerrainShape.gap(grid, c, k, _surf_or_floor)
	if not g.has("src"):
		return
	var src: Vector2i = g.src
	var gh: float = g.h
	var t := grid.terrain_at(src)
	var zone := grid.zone_at(src)
	var tex := BattleArt.top(t, zone)
	var poly := TerrainShape.gap_polygon(c, k, r)
	_patch(poly, gh, t, tex)
	var low: Vector2i = g.low
	var lh := maxf(_floor(), _surf_or_floor(low))
	var toward := Vector2(front_dir(false) + front_dir(true))
	var n := Vector2(low - c)
	if lh < gh - 0.01 and n.dot(toward) > 0.0:
		var ck: Vector2 = Vector2(c) + TerrainShape.CORNERS[k]
		var along := (poly[poly.size() - 1] if low == c + TerrainShape.NORMALS[k] else poly[1]) - ck
		var side_t := CombatGrid.T.GRASS if t == CombatGrid.T.WATER else t
		_soft_face(ck, ck + along, n, n, gh, lh, BattleArt.side_body(side_t, zone), _tint(side_t), CLIFF)
	if t == CombatGrid.T.WATER:
		var foam := PackedVector2Array()
		for i in range(1, poly.size()):
			var p: Vector2 = poly[i] + (Vector2(c) + TerrainShape.CORNERS[k] - poly[i]).normalized() * 0.05
			foam.append(iso(p.x, p.y, gh))
		_ci.draw_polyline(foam, Color(1, 1, 1, 0.4), 1.6, true)


## A piece of another cell's top drawn inside this one (a rounded-off corner's lower ground, a fillet): the
## same texture at the same world spot, so it runs on unbroken into that cell.
func _patch(poly: PackedVector2Array, h: float, t: int, tex: Texture2D) -> void:
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for p in poly:
		pts.append(iso(p.x, p.y, h))
		uvs.append(p / BattleArt.TOP_TILES)
	if tex != null:
		var cols := PackedColorArray()
		cols.resize(pts.size())
		cols.fill(Color(_tint(t) * (1.0 + minf(h, 6.0) * 0.025), 1.0))
		_ci.draw_polygon(pts, cols, uvs, tex)
	else:
		_ci.draw_colored_polygon(pts, _terrain_color(t).lightened(minf(h, 6.0) * 0.025))


## A low cell's corner tucked in between higher ground: that ground curves round into it (a fillet) with its
## own face down to this cell and its lip, so a notch or a zigzag bank reads as one soft edge.
func _fillet(c: Vector2i, k: int, r: float) -> void:
	var g := TerrainShape.gap(grid, c, k, _surf_or_floor)
	if not g.has("src"):
		return
	var src: Vector2i = g.src
	var gh: float = g.h
	var h := _surf(c)
	var t := grid.terrain_at(src)
	var zone := grid.zone_at(src)
	var tint := _tint(t)
	var tex := BattleArt.top(t, zone)
	var toward := Vector2(front_dir(false) + front_dir(true))
	var run := []
	for s: Dictionary in TerrainShape.arc(c, k, r):
		var na: Vector2 = -s.na  # the fillet faces into this cell
		var nb: Vector2 = -s.nb
		if (na + nb).dot(toward) <= 0.02:
			continue
		_soft_face(s.a, s.b, na, nb, gh, h, BattleArt.side_body(t, zone), tint, CLIFF)
		run.append([{"a": s.a, "b": s.b, "na": na, "nb": nb}, h])
	var lip := _soft_lip_depth(t, zone)
	if lip > 0.0 and not run.is_empty():
		_soft_lip(run, gh, tex, tint, _terrain_color(t).lightened(minf(gh, 6.0) * 0.025), lip)
	_patch(TerrainShape.gap_polygon(c, k, r), gh, t, tex)
	if grid.terrain_at(c) == CombatGrid.T.WATER:
		var foam := PackedVector2Array()
		for s: Dictionary in TerrainShape.arc(c, k, r):
			var p: Vector2 = s.a - s.na * 0.05
			foam.append(iso(p.x, p.y, h))
		_ci.draw_polyline(foam, Color(1, 1, 1, 0.4), 1.6, true)
		if not run.is_empty():  # the waterline round the curve, like the straight banks'
			var wet := []
			for item: Array in run:
				wet.append(item[0].a)
			wet.append(run[run.size() - 1][0].b)
			_marker_along(wet, h + WATERLINE)


## How thick the lip hangs on this ground: the set's own `lip`, or, where the set paints its snow into the
## cliff sides instead (cap), one about as thick, since the soft pass uses only the rock under that cap.
func _soft_lip_depth(t: int, zone: String) -> float:
	if t == CombatGrid.T.WATER or t == CombatGrid.T.STAIRS:
		return 0.0
	var built := t == CombatGrid.T.STONE or t == CombatGrid.T.RUIN
	var lip := 0.0 if built else BattleArt.lip(t, zone)
	if lip <= 0.0 and BattleArt.cap(t, zone) > 0.0:
		lip = 0.5 if built else 0.8
	return lip


## The top's ground folding over a run of the outline as one unbroken lip, like the key art's snow caps: a flat
## band a little darker and cooler than the top (blue on the shade side), with an uneven brushed edge fixed to
## the screen position so it carries on across cells and round corners. No gradient, no highlight, no
## outline: the value step is the edge.
func _soft_lip(run: Array, h: float, tex: Texture2D, tint: Color, top_col: Color, depth: float) -> void:
	var pts: Array[Vector2] = []
	var nrm: Array[Vector2] = []
	var drop: Array[float] = []
	for item: Array in run:
		var s: Dictionary = item[0]
		var foot: float = item[1]
		var steps := maxi(1, ceili((s.b - s.a).length() / 0.05))
		for i in steps:
			var f := float(i) / steps
			pts.append(s.a.lerp(s.b, f))
			nrm.append(s.na.lerp(s.nb, f).normalized())
			drop.append(h - foot)
	var last: Dictionary = run[run.size() - 1][0]
	pts.append(last.b)
	nrm.append(last.nb)
	drop.append(h - float(run[run.size() - 1][1]))
	var n := pts.size()
	var base := tint if tex != null else top_col
	var poly := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	for i in n:  # along the top edge
		poly.append(iso(pts[i].x, pts[i].y, h))
		uvs.append(pts[i] / BattleArt.TOP_TILES)
		cols.append(_lip_colour(base, nrm[i]))
	for i in range(n - 1, -1, -1):  # back along its lower edge
		var room := drop[i] - 0.06
		var dd := 0.0 if room < 0.12 else minf(TerrainShape.lip_depth(_screen_u(pts[i], 0.0), depth), room)
		poly.append(iso(pts[i].x, pts[i].y, h - dd))
		uvs.append((pts[i] + nrm[i] * dd * 0.4) / BattleArt.TOP_TILES)
		cols.append(_lip_colour(base, nrm[i]))
	if tex != null:
		_ci.draw_polygon(poly, cols, uvs, tex)
	else:
		_ci.draw_polygon(poly, cols)
	# The renderer can't antialias polygons: a hairline of the band's own colour smooths its lower edge.
	var avg := BattleArt.average(tex) if tex != null else Color.WHITE
	var edge := PackedVector2Array()
	var ecols := PackedColorArray()
	for i in range(n, poly.size()):
		edge.append(poly[i])
		ecols.append(Color(avg * cols[i], 1.0))
	_ci.draw_polyline_colors(edge, ecols, 1.0, true)


## The cap band's two values, measured off the key art: lit about 0.94 of its top, shade a clear cool blue.
func _lip_colour(base: Color, n: Vector2) -> Color:
	return Color(base * (LIP_LIT if _face_light(n) > 0.9 else LIP_SHADE), 1.0)


## Water: flow strokes that follow the river from cell to cell (TerrainShape.strokes) and foam along the banks.
func _water_marks(c: Vector2i, h: float, top_col: Color) -> void:
	for piece: Dictionary in _streams.get(c, []):
		var src: PackedVector2Array = piece.pts
		var f: PackedFloat32Array = piece.f
		var line := PackedVector2Array()
		var cols := PackedColorArray()
		var col := top_col.darkened(0.12) if piece.dark else top_col.lightened(0.6)
		var alpha := 0.3 if piece.dark else 0.72
		for i in src.size():
			line.append(iso(src[i].x, src[i].y, h))
			cols.append(Color(col, alpha * pow(sin(PI * clampf(f[i], 0.0, 1.0)), 0.6)))
		_ci.draw_polyline_colors(line, cols, 3.0 if piece.dark else 2.2, true)
	for k in 4:
		var nb: Vector2i = c + TerrainShape.NORMALS[k]
		if not grid.solid(nb) or grid.terrain_at(nb) == CombatGrid.T.WATER or _surf(nb) <= h + 0.05:
			continue
		var p: Vector2 = Vector2(c) + TerrainShape.CORNERS[k]
		var q: Vector2 = Vector2(c) + TerrainShape.CORNERS[(k + 1) % 4]
		# Stop short where the bank's corner is rounded: that bank draws its own foam round the curve.
		var rb := _radii_of(nb)
		for j in 4:
			var at: Vector2 = Vector2(nb) + TerrainShape.CORNERS[j]
			if rb[j] > 0.0 and at.is_equal_approx(p):
				p = p.move_toward(q, rb[j])
			elif rb[j] > 0.0 and at.is_equal_approx(q):
				q = q.move_toward(p, rb[j])
		var own := _radii_of(c)  # and where this cell's corner is a fillet, which draws its own foam
		if own[k] < 0.0:
			p = p.move_toward(q, -own[k])
		if own[(k + 1) % 4] < 0.0:
			q = q.move_toward(p, -own[(k + 1) % 4])
		var inward := -Vector2(TerrainShape.NORMALS[k]) * 0.08
		var foam := PackedVector2Array()
		for i in 5:
			var g := p.lerp(q, i / 4.0)
			var wob := (MapDress.noise(g * 3.0) - 0.5) * 0.04
			g += inward * (1.0 + wob * 20.0)
			foam.append(iso(g.x, g.y, h))
		_ci.draw_polyline(foam, Color(1, 1, 1, 0.4), 1.6, true)


## Soft stairs: treads in the path's ground, risers a shade darker, and the flight's sides in the rock of the
## cliff it is cut from, that rock's texture hung from the terrace above so it runs on from the cliff beside
## the stairs. False when there's no slope to show.
func _stair_steps_soft(c: Vector2i, h: float) -> bool:
	var run := MapDress.stair_run(grid, c)
	if run.is_empty():
		return false
	var zone := grid.zone_at(c)
	var tread_tex := BattleArt.top(CombatGrid.T.ROAD, zone)
	var tread_tint := _tint(CombatGrid.T.ROAD)
	var rock := BattleArt.side_body(CombatGrid.T.GRASS, zone)
	var rock_tint := _tint(CombatGrid.T.GRASS)
	var up: Vector2i = run.up
	var e_lo: float = run.lo
	var e_hi: float = run.hi
	var anchor := maxf(e_hi, _surf_or_floor(c + up))
	var n := clampi(roundi((e_hi - e_lo) * 3.0), 2, 8)
	var base := e_lo
	for shade in [false, true]:
		base = minf(base, _surf_or_floor(c + front_dir(shade)))
	base = maxf(base, _floor())
	var slabs: Array[Dictionary] = []
	for k in n:
		var f0 := float(k) / n
		var f1 := float(k + 1) / n
		var lo: Vector2
		var hi: Vector2
		if up == Vector2i(1, 0):
			lo = Vector2(c.x + f0, c.y)
			hi = Vector2(c.x + f1, c.y + 1)
		elif up == Vector2i(-1, 0):
			lo = Vector2(c.x + 1 - f1, c.y)
			hi = Vector2(c.x + 1 - f0, c.y + 1)
		elif up == Vector2i(0, 1):
			lo = Vector2(c.x, c.y + f0)
			hi = Vector2(c.x + 1, c.y + f1)
		else:
			lo = Vector2(c.x, c.y + 1 - f1)
			hi = Vector2(c.x + 1, c.y + 1 - f0)
		var m := _rot((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5)
		slabs.append({"lo": lo, "hi": hi, "h": lerpf(e_lo, e_hi, float(k) / (n - 1)), "depth": m.x + m.y})
	slabs.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p.depth < q.depth)
	for sl in slabs:
		var lo: Vector2 = sl.lo
		var hi: Vector2 = sl.hi
		var sh: float = sl.h
		for shade in [false, true]:
			var d := front_dir(shade)
			var e := _side(lo, hi, d)
			var nv := Vector2(d)
			if d == -up:  # a riser: the tread's ground, darker
				var m := Color(tread_tint * (0.8 if not shade else 0.62), 1.0)
				var uv := PackedVector2Array([e[0] / BattleArt.TOP_TILES, e[1] / BattleArt.TOP_TILES,
					(e[1] + Vector2(0, (sh - base) * 0.5)) / BattleArt.TOP_TILES, (e[0] + Vector2(0, (sh - base) * 0.5)) / BattleArt.TOP_TILES])
				var quad := PackedVector2Array([iso(e[0].x, e[0].y, sh), iso(e[1].x, e[1].y, sh), iso(e[1].x, e[1].y, base), iso(e[0].x, e[0].y, base)])
				if tread_tex != null:
					_ci.draw_polygon(quad, PackedColorArray([m, m, m, m]), uv, tread_tex)
				else:
					_ci.draw_colored_polygon(quad, _terrain_color(CombatGrid.T.ROAD) * m)
			else:  # the flight's side: the cliff's rock, carrying on from the terrace above
				_soft_face(e[0], e[1], nv, nv, sh, base, rock, rock_tint, CLIFF, anchor)
		var cap := PackedVector2Array([iso(lo.x, lo.y, sh), iso(hi.x, lo.y, sh), iso(hi.x, hi.y, sh), iso(lo.x, hi.y, sh)])
		var lift := Color(tread_tint * 1.04, 1.0)
		if tread_tex != null:
			var uv := PackedVector2Array([lo / BattleArt.TOP_TILES, Vector2(hi.x, lo.y) / BattleArt.TOP_TILES,
				hi / BattleArt.TOP_TILES, Vector2(lo.x, hi.y) / BattleArt.TOP_TILES])
			_ci.draw_polygon(cap, PackedColorArray([lift, lift, lift, lift]), uv, tread_tex)
		else:
			_ci.draw_colored_polygon(cap, _terrain_color(CombatGrid.T.ROAD).lightened(0.05))
		var nose := _side(lo, hi, -up)
		if Vector2(-up).dot(Vector2(front_dir(false) + front_dir(true))) > 0.0:
			_ci.draw_line(iso(nose[0].x, nose[0].y, sh), iso(nose[1].x, nose[1].y, sh), Color(1, 1, 0.92, 0.5), 1.2, true)
	return true


## Ground that blends into its neighbours: where a higher-ranked ground (road over grass, stone over road)
## or another tile set (ruins zone inside a forest) meets this cell at the same height, the neighbour's own
## top texture reaches a ragged way onto this cell and fades out, so the seam isn't a hard line. Painted
## transition tiles (docs/art/transitions.md) will replace this; it needs no art of its own.
func _fringe(c: Vector2i, t: int, h: float, zone: String) -> void:
	var rank: int = BLEND_RANK.get(t, -1)
	if rank < 0:
		return
	for d: Vector2i in CombatRules.DIRS:
		var n := c + d
		if not grid.solid(n) or absf(_surf(n) - h) > 0.01:
			continue
		var tn := grid.terrain_at(n)
		var zn := grid.zone_at(n)
		var rn: int = BLEND_RANK.get(tn, -1)
		if rn < 0 or (rn <= rank and zn == zone) or (tn == t and zn == zone):
			continue
		var depth := BLEND_DEPTH if rn > rank else BLEND_DEPTH * 0.55  # another zone of the same ground: half each way
		var tex := BattleArt.top(tn, zn)
		var col := _tint(tn) if tex != null else _terrain_color(tn)
		# The shared edge in grid units, and the way into this cell.
		var a := Vector2(c) + (Vector2(maxi(d.x, 0), maxi(d.y, 0)))
		var along := Vector2(absi(d.y), absi(d.x))
		var inward := -Vector2(d)
		var pts: Array[Vector2] = []
		var inner: Array[Vector2] = []
		for i in BLEND_STEPS + 1:
			var f := float(i) / BLEND_STEPS
			var p := a + along * f
			var k := _hash(Vector2i(roundi(p.x * 16.0), roundi(p.y * 16.0)))
			var wob := 0.55 + 0.9 * float(k % 100) / 100.0
			if i == 0 or i == BLEND_STEPS:
				wob *= 0.5
			pts.append(p)
			inner.append(p + inward * depth * wob)
		for i in BLEND_STEPS:
			var quad := [pts[i], pts[i + 1], inner[i + 1], inner[i]]
			var poly := PackedVector2Array()
			var uv := PackedVector2Array()
			for q: Vector2 in quad:
				poly.append(iso(q.x, q.y, h))
				uv.append(q / BattleArt.TOP_TILES)
			var on := Color(col, BLEND_ALPHA)
			var off := Color(col, 0.0)
			var cols := PackedColorArray([on, on, off, off])
			if tex != null:
				_ci.draw_polygon(poly, cols, uv, tex)
			else:
				_ci.draw_polygon(poly, cols)


## Water pouring over the cell's front edges (LIVE slab: it scrolls).
func _draw_falls(c: Vector2i) -> void:
	var h := _surf(c)
	var fl := _floor()
	for shade in [false, true]:
		var d := front_dir(shade)
		var n := c + d
		var edge := not grid.solid(n)
		var nh := fl if edge else _surf(n)
		if nh >= h:
			continue
		var side := _side(Vector2(c), Vector2(c) + Vector2.ONE, d)
		var foot := maxf(fl, minf(nh, h))
		if _soft():
			_waterfall_soft(side[0], side[1], h, foot, c, d, not edge)
		else:
			_waterfall(side[0], side[1], h, foot, c, not edge)
		if edge and _rims():
			_spill(side[0], side[1], c)


## The cursor, highlights, danger and skill area on the cell's top (LIVE slab).
func _draw_over(c: Vector2i) -> void:
	var top := _diamond(c, _surf(c))
	var ring := PackedVector2Array([top[0], top[1], top[2], top[3], top[0]])
	if danger.has(c):
		_ci.draw_colored_polygon(top, Color(1.0, 0.55, 0.15, 0.22))
	if highlights.has(c):
		_ci.draw_colored_polygon(top, highlights[c])
		if BattleArt.top(grid.terrain_at(c), grid.zone_at(c)) != null:
			# Painted tops are busier than graybox, so highlighted cells also get a solid rim.
			var rim: Color = highlights[c]
			_ci.draw_polyline(ring, Color(rim, 0.95), 2.0, true)
	if area.has(c):
		_ci.draw_colored_polygon(top, Color(1.0, 0.4, 0.2, 0.45))
	if c == hover:
		_ci.draw_colored_polygon(top, Color(1, 1, 1, 0.18))
	if danger.has(c):
		_ci.draw_polyline(ring, Color(1.0, 0.5, 0.1, 0.7), 1.5, true)


## What stands on the cell (LIVE slab: props fade when a piece is behind them): placed props, the tile
## set's trees and boulders, or graybox shapes until that art exists.
func _draw_props(c: Vector2i) -> void:
	var t := grid.terrain_at(c)
	var h := _surf(c)
	var zone := grid.zone_at(c)
	var seed_v := _hash(c)
	var tint := _tint(t)
	var top_col := _terrain_color(t).lightened(minf(h, 6.0) * 0.025)
	var top_tex := BattleArt.top(t, zone)
	var mid := cell_top(c)
	if grid.prop_anchor(c) != CombatGrid.NONE_CELL:
		_placed(c)
		return
	if _props(c, h, t, seed_v, tint, zone):
		return
	match t:
		CombatGrid.T.FOREST:
			# Boxy canopy trees, like the stacked-block references.
			for o in [Vector2(-11, -1), Vector2(10, 2), Vector2(0, 7)]:
				var p: Vector2 = mid + o
				_ci.draw_line(p, p + Vector2(0, -7), Color(0.4, 0.3, 0.22), 2.0)
				_cube(p + Vector2(0, -7), 7.0, 9.0, top_col.lightened(0.05))
		CombatGrid.T.ROCK:
			if top_tex != null:
				return  # a painted set without boulder art (house walls): the texture is the wall top
			_ci.draw_colored_polygon(PackedVector2Array([mid + Vector2(-14, 4), mid + Vector2(-8, -14), mid + Vector2(6, -18), mid + Vector2(15, 2)]), top_col.darkened(0.25))
			_ci.draw_colored_polygon(PackedVector2Array([mid + Vector2(-8, -14), mid + Vector2(6, -18), mid + Vector2(2, -8)]), top_col.lightened(0.1))
		CombatGrid.T.WATER:
			if top_tex == null:  # painted water has its own streaks
				var wob := sin(_time * 2.0 + c.x + c.y) * 2.0
				_ci.draw_line(mid + Vector2(-10 + wob, -2), mid + Vector2(4 + wob, -2), top_col.lightened(0.3), 2.0)
				_ci.draw_line(mid + Vector2(-2 - wob, 4), mid + Vector2(10 - wob, 4), top_col.lightened(0.3), 2.0)
		CombatGrid.T.RUIN:
			_ruin(c, h, seed_v)


## The two grid corners of the side of rect [lo, hi] that faces direction d.
static func _side(lo: Vector2, hi: Vector2, d: Vector2i) -> Array:
	if d.x > 0:
		return [Vector2(hi.x, lo.y), Vector2(hi.x, hi.y)]
	if d.x < 0:
		return [Vector2(lo.x, lo.y), Vector2(lo.x, hi.y)]
	if d.y > 0:
		return [Vector2(lo.x, hi.y), Vector2(hi.x, hi.y)]
	return [Vector2(lo.x, lo.y), Vector2(hi.x, lo.y)]


static func _hash(c: Vector2i) -> int:
	return absi((c.x * 73856093) ^ (c.y * 19349663)) % 9973


## Prop sprites standing on the cell (trees, boulders, pillars). False when this terrain has no art yet.
func _props(c: Vector2i, h: float, t: int, seed_v: int, tint: Color, zone := "") -> bool:
	var art := BattleArt.props(t, zone)
	var list: Array = art.list
	if list.is_empty() or art.count <= 0:
		return false
	# Spots in grid units around the cell centre, back (smaller x + y) first so they overlap correctly.
	var spots: Array = [Vector2.ZERO] if art.count == 1 else [Vector2(-0.2, -0.16), Vector2(0.18, 0.2)]
	for i in spots.size():
		var r := float((seed_v * (i + 5)) % 101) / 101.0
		var tex: Texture2D = list[(seed_v + i * 7) % list.size()]
		var o: Vector2 = spots[i] + Vector2(r - 0.5, 0.5 - r) * 0.08
		var base := iso(c.x + 0.5 + o.x, c.y + 0.5 + o.y, h)
		var ph: float = art.height * TW * (0.88 + 0.24 * r)
		var pw := ph * tex.get_width() / float(tex.get_height())
		if pw > TW * 0.9:  # wide props (bush, boulder) stay inside their cell
			ph *= TW * 0.9 / pw
			pw = TW * 0.9
		if _soft():  # flat look: a faint cool shade, not a grey disc
			Pawn.ellipse(_ci, base, pw * 0.3, pw * 0.1, Color(0.22, 0.3, 0.55, 0.14), true)
		else:
			Pawn.ellipse(_ci, base, pw * 0.36, pw * 0.13, Color(0.1, 0.1, 0.12, 0.22), true)
		var a := 0.35 if _fade.has(c) else 1.0  # see-through while a piece stands behind it
		_ci.draw_texture_rect(tex, Rect2(base.x - pw * 0.5, base.y - ph, pw, ph), false, Color(tint, a))
	return true


## The footprint cell nearest the camera: a placed prop draws with that cell, so pieces behind it go first.
func _prop_front(a: Vector2i, p: Dictionary) -> Vector2i:
	var best := a
	for dy in p.foot.y:
		for dx in p.foot.x:
			var c := a + Vector2i(dx, dy)
			if depth_of(c.x, c.y) > depth_of(best.x, best.y):
				best = c
	return best


## Screen rect of a placed prop. Buildings (tall 0) span their footprint with the image's bottom on its
## front corner; small props stand `tall` tile widths high on the middle of their footprint.
func _prop_rect(a: Vector2i, p: Dictionary, tex: Texture2D) -> Rect2:
	var h := float(grid.height_at(a))
	var foot: Vector2i = p.foot
	var pts := [iso(a.x, a.y, h), iso(a.x + foot.x, a.y, h), iso(a.x + p.foot.x, a.y + p.foot.y, h), iso(a.x, a.y + p.foot.y, h)]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q: Vector2 in pts:
		lo = lo.min(q)
		hi = hi.max(q)
	var span := hi.x - lo.x
	var aspect := tex.get_width() / float(tex.get_height())
	if p.tall <= 0.0:
		return Rect2(lo.x, hi.y - span / aspect, span, span / aspect)
	var ph: float = p.tall * TW
	var pw := ph * aspect
	if pw > span * 0.95:
		pw = span * 0.95
		ph = pw / aspect
	var base := (lo + hi) * 0.5
	return Rect2(base.x - pw * 0.5, base.y + (hi.y - lo.y) * 0.18 - ph, pw, ph)


## A placed prop (well, bed, a whole house), drawn from its front cell. Graybox block until its art exists.
func _placed(c: Vector2i) -> void:
	var a := grid.prop_anchor(c)
	var p: Dictionary = grid.props[a]
	if _prop_front(a, p) != c:
		return
	var tex := prop_texture(p, grid.zone_at(a))
	var col := Color.WHITE
	if fog_on and fog.get(c, 2) == 1:
		col = Color(0.45, 0.46, 0.52)  # remembered, out of sight: same wash as the veil
	if _fade.has(a):
		col.a = 0.35
	if tex == null and p.get("blob", false):
		_blob(a, p, col)
		return
	if tex == null:
		var h := float(grid.height_at(a))
		var tall: float = p.tall
		var top: float = h + (tall * 2.0 if tall > 0.0 else 3.0)
		var lo := Vector2(a)
		var hi: Vector2 = lo + Vector2(p.foot)
		for shade in [false, true]:
			var e: Array = _side(lo, hi, front_dir(shade))
			var q := PackedVector2Array([iso(e[0].x, e[0].y, top), iso(e[1].x, e[1].y, top), iso(e[1].x, e[1].y, h), iso(e[0].x, e[0].y, h)])
			_ci.draw_colored_polygon(q, MASONRY.darkened(0.3 if shade else 0.12) * col)
		_ci.draw_colored_polygon(PackedVector2Array([iso(lo.x, lo.y, top), iso(hi.x, lo.y, top), iso(hi.x, hi.y, top), iso(lo.x, hi.y, top)]), MASONRY.lightened(0.1) * col)
		return
	var r := _prop_rect(a, p, tex)
	if p.tall > 0.0 and not p.walk:
		var b := Vector2(r.get_center().x, r.end.y)
		Pawn.ellipse(_ci, b, r.size.x * 0.36, r.size.x * 0.13, Color(0.1, 0.1, 0.12, 0.22 * col.a), true)
	if p.get("flip", false):
		_ci.draw_set_transform(Vector2(r.get_center().x * 2.0, 0.0), 0.0, Vector2(-1, 1))
		_ci.draw_texture_rect(tex, r, false, col)
		_ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_ci.draw_texture_rect(tex, r, false, col)


## The sprite a placed prop draws with at the current camera turn: `<sprite>_r<n>` when that angle is
## painted (n = the prop's face plus the camera's turn), else the sprite itself. null = no art yet.
func prop_texture(p: Dictionary, zone := "") -> Texture2D:
	var stem := String(p.sprite)
	var v := posmod(int(p.get("face", 0)) + rot, 4)
	if v != 0:
		var turned := BattleArt.texture("%s_r%d" % [stem, v], false, zone)
		if turned != null:
			return turned
	return BattleArt.texture(stem, false, zone)


## The colour a placeholder blob is drawn in: picked from its name, so each named blob keeps its own.
static func blob_color(blob_name: String) -> Color:
	var hue := float(absi(blob_name.hash()) % 360) / 360.0
	return Color.from_hsv(hue, 0.38, 0.86)


## A named placeholder blob: a soft coloured block over its footprint, `tall` tile widths high, until art
## named like it (its sprite, ph_<name>) is in art/source/battle/.
func _blob(a: Vector2i, p: Dictionary, col: Color) -> void:
	var h := float(grid.height_at(a))
	var top: float = h + maxf(0.4, float(p.tall) * 2.0)
	var lo := Vector2(a) + Vector2(0.08, 0.08)
	var hi: Vector2 = Vector2(a) + Vector2(p.foot) - Vector2(0.08, 0.08)
	var base := blob_color(String(p.get("name", p.sprite)))
	for shade in [false, true]:
		var e: Array = _side(lo, hi, front_dir(shade))
		var q := PackedVector2Array([iso(e[0].x, e[0].y, top), iso(e[1].x, e[1].y, top), iso(e[1].x, e[1].y, h), iso(e[0].x, e[0].y, h)])
		_ci.draw_colored_polygon(q, base.darkened(0.32 if shade else 0.16) * col)
	var lid := PackedVector2Array([iso(lo.x, lo.y, top), iso(hi.x, lo.y, top), iso(hi.x, hi.y, top), iso(lo.x, hi.y, top)])
	_ci.draw_colored_polygon(lid, base.lightened(0.12) * col)
	lid.append(lid[0])
	_ci.draw_polyline(lid, Color(INK, 0.55 * col.a), 1.5, true)


## One side face between grid corners a and b, from height h down to hb, with stone courses.
## With a painted texture, the courses come from the art instead (4 rows per texture = 1 per level).
func _face(a: Vector2, b: Vector2, h: float, hb: float, col: Color, seed_v: int, lip := false, plain := false, tex: Texture2D = null, mod := Color.WHITE) -> void:
	if h <= hb:
		return
	var pts := PackedVector2Array([iso(a.x, a.y, h), iso(b.x, b.y, h), iso(b.x, b.y, hb), iso(a.x, a.y, hb)])
	if tex != null:
		var along_x := is_equal_approx(a.y, b.y)
		var ua := (a.x if along_x else a.y) / BattleArt.SIDE_TILES
		var ub := (b.x if along_x else b.y) / BattleArt.SIDE_TILES
		var vt := -h / BattleArt.SIDE_LEVELS
		var vb := -hb / BattleArt.SIDE_LEVELS
		_ci.draw_polygon(pts, PackedColorArray([mod, mod, mod, mod]), PackedVector2Array([Vector2(ua, vt), Vector2(ub, vt), Vector2(ub, vb), Vector2(ua, vb)]), tex)
		_ci.draw_line(iso(a.x, a.y, hb), iso(b.x, b.y, hb), col.darkened(0.4), 1.0, true)
		return
	_ci.draw_colored_polygon(pts, col)
	if plain:
		return
	var line := col.darkened(0.22)
	var lvl := floorf(h)
	var row := 0
	while lvl > hb + 0.05:
		var top_l := minf(h, lvl + 1.0)
		if lvl < h - 0.05:
			_ci.draw_line(iso(a.x, a.y, lvl), iso(b.x, b.y, lvl), line, 1.0, true)
		# Staggered joints, like laid stone.
		var f := 0.3 if (row + seed_v) % 2 == 0 else 0.65
		var j := a.lerp(b, f)
		_ci.draw_line(iso(j.x, j.y, top_l), iso(j.x, j.y, maxf(lvl, hb)), line, 1.0, true)
		lvl -= 1.0
		row += 1
	if lip:
		# A darker soil band under the grass edge.
		var lip_h := minf(0.3, h - hb)
		_ci.draw_colored_polygon(PackedVector2Array([iso(a.x, a.y, h), iso(b.x, b.y, h), iso(b.x, b.y, h - lip_h), iso(a.x, a.y, h - lip_h)]), col.darkened(0.15))
	_ci.draw_line(iso(a.x, a.y, hb), iso(b.x, b.y, hb), col.darkened(0.4), 1.0, true)


## Moss hanging over a ledge.
func _drips(a: Vector2, b: Vector2, h: float, drop: float, col: Color, seed_v: int) -> void:
	for i in 3:
		var r := ((seed_v * (i + 3)) % 97) / 97.0
		if r < 0.35:
			continue
		var f := 0.15 + 0.7 * (((seed_v + i * 31) % 89) / 89.0)
		var p := a.lerp(b, f)
		var drop_px := minf(drop, 0.3 + r * 0.8) * HS
		var top_p := iso(p.x, p.y, h)
		_ci.draw_rect(Rect2(top_p + Vector2(-3, 0), Vector2(6, drop_px)), col)
		_ci.draw_circle(top_p + Vector2(0, drop_px), 3.0, col)


## The top's grass (snow, sand, moss...) folding over a cliff edge: a band cut from the top texture that
## hangs down the face and ends in drips, with a soft shadow under it and an ink line along the drips.
## The drip pattern is fixed to the world (MapDress.lip_profile), so it runs on unbroken from cell to cell,
## and every edge starts and ends at the same depth, so the lit and shade lips meet at the corner.
func _lip(a: Vector2, b: Vector2, h: float, drop: float, out: Vector2i, tex: Texture2D, top_col: Color, tint: Color, shade: bool, depth: float) -> void:
	var prof := MapDress.lip_profile(a, b, depth, drop)
	if prof.is_empty():
		return
	var n := prof.size()
	var light := 1.0 if not shade else 0.8
	var dark := 0.84 if not shade else 0.66
	var shadow := PackedVector2Array([iso(a.x, a.y, h), iso(b.x, b.y, h)])
	var pts := PackedVector2Array([iso(a.x, a.y, h), iso(b.x, b.y, h)])
	var uvs := PackedVector2Array([a / BattleArt.TOP_TILES, b / BattleArt.TOP_TILES])
	var base := tint if tex != null else top_col
	var cols := PackedColorArray([Color(base * light, 1.0), Color(base * light, 1.0)])
	var ink := PackedVector2Array()
	for i in range(n - 1, -1, -1):
		var g: Vector2 = prof[i][0]
		var dd: float = prof[i][1]
		var q := iso(g.x, g.y, h - dd)
		pts.append(q)
		uvs.append((g + Vector2(out) * dd * 0.4) / BattleArt.TOP_TILES)
		cols.append(Color(base * lerpf(light, dark, clampf(dd / maxf(depth, 0.01), 0.0, 1.0)), 1.0))
		shadow.append(iso(g.x, g.y, h - minf(dd + 0.16, drop)))
	for i in n:
		ink.append(iso(prof[i][0].x, prof[i][0].y, h - prof[i][1]))
	_ci.draw_colored_polygon(shadow, Color(0.06, 0.07, 0.12, 0.32))
	if tex != null:
		_ci.draw_polygon(pts, cols, uvs, tex)
	else:
		_ci.draw_polygon(pts, cols)
	_ci.draw_polyline(ink, Color(INK, 0.3), 1.0, true)
	# The rounded lip catches the sun just under the edge.
	var hl := minf(depth * 0.18, drop * 0.3)
	_ci.draw_line(iso(a.x, a.y, h - hl), iso(b.x, b.y, h - hl), Color(1, 1, 0.85, 0.22 if shade else 0.35), 1.5, true)


## Ink down a block's outer vertical edges: the front corner where both faces show, and the far end of a
## face whose neighbour along the wall is lower (the block's silhouette). Flat walls stay seamless.
func _ink_corners(c: Vector2i, h: float, low: Dictionary) -> void:
	var dl := front_dir(false)
	var ds := front_dir(true)
	var lit := _side(Vector2(c), Vector2(c) + Vector2.ONE, dl)
	var sh := _side(Vector2(c), Vector2(c) + Vector2.ONE, ds)
	var corner: Vector2 = lit[0] if (lit[0] == sh[0] or lit[0] == sh[1]) else lit[1]
	var lit_end: Vector2 = lit[1] if corner == lit[0] else lit[0]
	var sh_end: Vector2 = sh[1] if corner == sh[0] else sh[0]
	var ink := Color(INK, 0.5)
	var lit_n: float = low[false]
	var sh_n: float = low[true]
	var foot := maxf(lit_n, sh_n)
	if lit_n < h and sh_n < h and h - foot > 0.25:
		_ci.draw_line(iso(corner.x, corner.y, h), iso(corner.x, corner.y, foot), ink, 1.3, true)
	var e1 := maxf(lit_n, _surf_or_floor(c - ds))
	if lit_n < h and h - e1 > 0.25:
		_ci.draw_line(iso(lit_end.x, lit_end.y, h), iso(lit_end.x, lit_end.y, e1), ink, 1.3, true)
	var e2 := maxf(sh_n, _surf_or_floor(c - dl))
	if sh_n < h and h - e2 > 0.25:
		_ci.draw_line(iso(sh_end.x, sh_end.y, h), iso(sh_end.x, sh_end.y, e2), ink, 1.3, true)


## Tall faces darken toward their foot, so a cliff reads deep and the ground below it sits in its shade.
func _face_ao(a: Vector2, b: Vector2, h: float, hb: float) -> void:
	var start := hb + (h - hb) * 0.62
	var clear := Color(0.06, 0.08, 0.14, 0.0)
	var deep := Color(0.06, 0.08, 0.14, 0.3)
	_ci.draw_polygon(PackedVector2Array([iso(a.x, a.y, start), iso(b.x, b.y, start), iso(b.x, b.y, hb), iso(a.x, a.y, hb)]),
		PackedColorArray([clear, clear, deep, deep]))


## Valley staging: an outer cliff sinks into the forest, its foot fading into the woods' colour.
func _face_mist(a: Vector2, b: Vector2, h: float, hb: float) -> void:
	var start := minf(h, hb + 3.0)
	var wood := look.color("wood")
	_ci.draw_polygon(PackedVector2Array([iso(a.x, a.y, start), iso(b.x, b.y, start), iso(b.x, b.y, hb), iso(a.x, a.y, hb)]),
		PackedColorArray([Color(wood, 0.0), Color(wood, 0.0), Color(wood, 0.95), Color(wood, 0.95)]))


## Stairs as real steps: slabs that climb from the low neighbour's side to the high one's, centred on the
## cell's own height (where a piece stands), drawn back to front. False when there's no slope to show.
func _stair_steps(c: Vector2i, h: float, top_tex: Texture2D, side_tex: Texture2D, tint: Color, face: Color, seed_v: int) -> bool:
	var run := MapDress.stair_run(grid, c)
	if run.is_empty():
		return false
	var up: Vector2i = run.up
	var e_lo: float = run.lo
	var e_hi: float = run.hi
	var n := clampi(roundi((e_hi - e_lo) * 3.0), 2, 8)
	var base := e_lo
	for shade in [false, true]:
		base = minf(base, _surf_or_floor(c + front_dir(shade)))
	base = maxf(base, _floor())
	var slabs: Array[Dictionary] = []
	for k in n:
		var f0 := float(k) / n
		var f1 := float(k + 1) / n
		var lo: Vector2
		var hi: Vector2
		if up == Vector2i(1, 0):
			lo = Vector2(c.x + f0, c.y)
			hi = Vector2(c.x + f1, c.y + 1)
		elif up == Vector2i(-1, 0):
			lo = Vector2(c.x + 1 - f1, c.y)
			hi = Vector2(c.x + 1 - f0, c.y + 1)
		elif up == Vector2i(0, 1):
			lo = Vector2(c.x, c.y + f0)
			hi = Vector2(c.x + 1, c.y + f1)
		else:
			lo = Vector2(c.x, c.y + 1 - f1)
			hi = Vector2(c.x + 1, c.y + 1 - f0)
		var m := _rot((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5)
		slabs.append({"lo": lo, "hi": hi, "h": lerpf(e_lo, e_hi, float(k) / (n - 1)), "depth": m.x + m.y})
	slabs.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p.depth < q.depth)
	for sl in slabs:
		var lo: Vector2 = sl.lo
		var hi: Vector2 = sl.hi
		var sh: float = sl.h
		for shade in [false, true]:
			var e := _side(lo, hi, front_dir(shade))
			var mod := Color(tint * (0.72 if shade else 1.0), 1.0)
			_face(e[0], e[1], sh, base, face.darkened(0.32 if shade else 0.12), seed_v, false, true, side_tex, mod)
		var cap := PackedVector2Array([iso(lo.x, lo.y, sh), iso(hi.x, lo.y, sh), iso(hi.x, hi.y, sh), iso(lo.x, hi.y, sh)])
		if top_tex != null:
			var lift := Color(tint * 1.05, 1.0)
			var uv := PackedVector2Array([lo / BattleArt.TOP_TILES, Vector2(hi.x, lo.y) / BattleArt.TOP_TILES,
				hi / BattleArt.TOP_TILES, Vector2(lo.x, hi.y) / BattleArt.TOP_TILES])
			_ci.draw_polygon(cap, PackedColorArray([lift, lift, lift, lift]), uv, top_tex)
		else:
			_ci.draw_colored_polygon(cap, _terrain_color(CombatGrid.T.STAIRS).lightened(0.05))
		for shade in [false, true]:  # a pale nose on each tread, an ink line under it
			var e := _side(lo, hi, front_dir(shade))
			_ci.draw_line(iso(e[0].x, e[0].y, sh), iso(e[1].x, e[1].y, sh), Color(1, 1, 1, 0.4), 1.2, true)
	return true


## A forest cell around the playable ground (valley staging): a dark floor, then a few big trees tinted
## toward the backdrop's forest, darker each ring out. The trees nearest the camera frame the map's front
## edge; they go see-through when they'd hide a piece, the cursor or a highlighted cell.
func _draw_skirt(c: Vector2i) -> void:
	var s: Dictionary = _skirt[c]
	var src: Vector2i = s.src
	if fog_on and not fog.has(src) or look.trees.is_empty():
		return
	var fl := look.floor_h
	var mid := iso(c.x + 0.5, c.y + 0.5, fl)
	var ring: int = s.ring
	var seed_v := _hash(c)
	# Trees in front of the ground (nearer the camera) frame the map and stand bigger; the ones behind it
	# are mostly hidden by its cliffs. Next to the ground the wood thins so the cliffs still show.
	var front := depth_of(c.x, c.y) > depth_of(src.x, src.y)
	var count := 1 if seed_v % 3 != 0 else 0
	if ring == 2:
		count = 1 if seed_v % 4 != 0 else 2
	elif ring > 2:
		count = 2 if seed_v % 5 < 2 else (1 if seed_v % 5 < 4 else 0)
	if not front and ring == 1:
		count = 1 if seed_v % 2 == 0 else 0
	if count == 0:
		return
	var faint := _skirt_fade.has(c) or (edit_void and grid.in_bounds(c))
	# The first ring keeps the trees' own colours (they belong to the map); further out they sink into the
	# wood's colour like the reference's dark foreground.
	var sink := (0.75 if ring == 2 else 1.0) if wallpaper else 0.3 * (ring - 1)  ## with the wallpaper the outer rings go solid navy
	var sil := _sink_colour().lerp(look.color("tree"), 0.25 if ring == 1 else 0.0)  ## the flat silhouette colour: front trees a shade lighter
	var tint := look.color("tree").lerp(Color.WHITE, 0.6) if ring == 1 else look.color("tree").lerp(_sink_colour(), sink)
	if fog_on and fog[src] == 1:
		tint = tint.darkened(0.4)
	var spots: Array = [Vector2.ZERO] if count == 1 else [Vector2(-0.2, -0.18), Vector2(0.2, 0.2)]
	for i in spots.size():
		var r := float((seed_v * (i + 3)) % 97) / 97.0
		var r2 := float((seed_v * (i + 7)) % 89) / 89.0
		var tex := BattleArt.texture(look.trees[(seed_v + i * 5) % look.trees.size()], false)
		if wallpaper and tex != null:  # with the wallpaper the skirt trees are flat silhouettes, like the reference's bottom edge
			tex = _silhouette(tex, sil)
			tint = Color.WHITE
		var o: Vector2 = spots[i] + Vector2(r - 0.5, r2 - 0.5) * 0.22
		var base := iso(c.x + 0.5 + o.x, c.y + 0.5 + o.y, fl)
		var ph := look.tree_scale * TW * (0.72 + 0.6 * r) * (1.0 + 0.12 * (ring - 1)) * (1.15 if front else 0.9)
		if tex == null:
			MapBackdrop.pine(_ci, base, ph, Color(tint * look.color("wood").lightened(0.3), 0.3 if faint else 1.0))
			continue
		var pw := ph * tex.get_width() / float(tex.get_height())
		_ci.draw_texture_rect(tex, Rect2(base.x - pw * 0.5, base.y - ph, pw, ph), false, Color(tint, 0.28 if faint else 1.0))


## Water spilling off a ledge onto lower ground: a pale sheet, moving streaks and foam at the bottom.
## Rough rock hanging under the island's rim (the floating-island look): two stacked columns per cell
## edge, a wide block then a narrower chipped one, each a different depth and darker the deeper it goes,
## in the colour of the cell's own cliff art. Below the deepest columns a few loose stones float.
func _underside(a: Vector2, b: Vector2, col: Color, seed_v: int, out: Vector2i) -> void:
	var ink := Color(0.216, 0.2, 0.208, 0.8)
	var inward := -Vector2(out)
	for k in 2:
		var r := float((seed_v * (k + 3) * 31) % 97) / 97.0
		var r2 := float((seed_v * (k + 5) * 17) % 89) / 89.0
		var p0 := a.lerp(b, k * 0.5)
		var p1 := a.lerp(b, k * 0.5 + 0.5)
		var d1 := 0.7 + r * 0.9
		var d2 := 0.5 + r2 * 1.3
		var i0 := p0.lerp(p1, 0.06) + inward * 0.06
		var i1 := p1.lerp(p0, 0.06) + inward * 0.06
		var n0 := p0.lerp(p1, 0.2 + r2 * 0.1) + inward * 0.14
		var n1 := p1.lerp(p0, 0.2 + r * 0.1) + inward * 0.14
		var tip := n0.lerp(n1, 0.3 + r * 0.4) + inward * 0.05
		var upper := PackedVector2Array([iso(p0.x, p0.y, BASE), iso(p1.x, p1.y, BASE),
			iso(i1.x, i1.y, BASE - d1), iso(i0.x, i0.y, BASE - d1)])
		var lower := PackedVector2Array([iso(n0.x, n0.y, BASE - d1), iso(n1.x, n1.y, BASE - d1),
			iso(n1.x, n1.y, BASE - d1 - d2 * 0.75), iso(tip.x, tip.y, BASE - d1 - d2 - 0.35),
			iso(n0.x, n0.y, BASE - d1 - d2 * (0.55 + r * 0.3))])
		var c1 := col.darkened(0.12 + r * 0.08)
		var c2 := c1.darkened(0.22)
		_ci.draw_colored_polygon(upper, c1)
		_ci.draw_colored_polygon(lower, c2)
		_ci.draw_polyline(_ring(upper), ink, 1.2, true)
		_ci.draw_polyline(_ring(lower), ink, 1.2, true)
		if r2 > 0.55:  # one crack per column, like the flat tiles' couple of marks
			var m := i0.lerp(i1, 0.5)
			_ci.draw_line(iso(m.x, m.y, BASE - d1 * 0.25), iso(m.x, m.y, BASE - d1 * 0.7), Color(ink, 0.3), 1.0, true)
		if seed_v % 7 == k:  # a stone that broke off and floats below
			var stone := iso(tip.x, tip.y, BASE - d1 - d2 - 1.4 - r)
			var bob := sin(_time * 1.3 + seed_v) * 2.0
			_cube(stone + Vector2(0, bob), 4.0 + r * 3.0, 4.0 + r * 3.0, c1)


## Water pouring off the island's rim keeps falling past the rock and thins out into mist.
func _spill(a: Vector2, b: Vector2, c: Vector2i) -> void:
	var a2 := a.lerp(b, 0.25)
	var b2 := a.lerp(b, 0.75)
	var sheet := FALL.lerp(ALIEN_COLORS[CombatGrid.T.WATER], strangeness * 0.7)
	var drop := 3.5
	var top := PackedVector2Array([iso(a2.x, a2.y, BASE), iso(b2.x, b2.y, BASE), iso(b2.x, b2.y, BASE - drop), iso(a2.x, a2.y, BASE - drop)])
	var clear := Color(sheet, 0.0)
	_ci.draw_polygon(top, PackedColorArray([Color(sheet, 0.95), Color(sheet, 0.95), clear, clear]))
	for k in 3:
		var p := a2.lerp(b2, 0.2 + k * 0.3)
		var phase := fmod(_time * 1.2 + k * 0.41 + c.y * 0.13, 1.0)
		var y0 := BASE - phase * drop
		_ci.draw_line(iso(p.x, p.y, y0), iso(p.x, p.y, y0 - 0.7), Color(1, 1, 1, 0.6 * (1.0 - phase)), 1.5, true)
	for k in 3:  # mist puffs where the stream gives out
		var p := a2.lerp(b2, 0.15 + k * 0.35)
		var puff := iso(p.x, p.y, BASE - drop + 0.3) + Vector2(0, sin(_time * 1.7 + k) * 1.5)
		_ci.draw_circle(puff, 4.0 + k, Color(1, 1, 1, 0.18))


## The soft card the island floats on: a rounded rectangle around the map with a vertical wash, a glow
## behind the middle, a few light shafts and drifting motes. Colours drift toward lavender with strangeness.
## A painted backdrop plate: one picture per art set, centred on the board and scaled to its footprint.
func _draw_plate(plate: Texture2D) -> void:
	var centre := board_origin() + board_size() * 0.5
	var width := board_size().x * PLATE_SCALE
	var height := width * plate.get_height() / plate.get_width()
	_ci.draw_texture_rect(plate, Rect2(centre - Vector2(width, height) * 0.5, Vector2(width, height)), false)


func _draw_backdrop() -> void:
	var box := Rect2(iso(0, 0, 0), Vector2.ZERO)
	for corner in [Vector2(0, 0), Vector2(grid.w, 0), Vector2(0, grid.h), Vector2(grid.w, grid.h)]:
		box = box.expand(iso(corner.x, corner.y, grid.top_height() + 2.0))
		box = box.expand(iso(corner.x, corner.y, BASE - 4.0))
	box = box.grow(20.0)
	var top_col := Color(0.86, 0.85, 0.8).lerp(Color(0.8, 0.76, 0.88), strangeness)
	var low_col := Color(0.66, 0.7, 0.7).lerp(Color(0.5, 0.46, 0.64), strangeness)
	var r := 28.0
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in 4:
		var cx := box.end.x - r if i == 0 or i == 3 else box.position.x + r
		var cy := box.end.y - r if i < 2 else box.position.y + r
		var a0: float = [0.0, PI * 0.5, PI, PI * 1.5][i]
		for k in 7:
			var ang: float = a0 + k * PI / 12.0
			var p := Vector2(cx + cos(ang) * r, cy + sin(ang) * r)
			pts.append(p)
			cols.append(top_col.lerp(low_col, (p.y - box.position.y) / box.size.y))
	_ci.draw_polygon(pts, cols)
	var mid := box.get_center()
	for k in 5:  # glow: stacked soft ellipses
		Pawn.ellipse(_ci, mid, box.size.x * (0.42 - k * 0.07), box.size.y * (0.36 - k * 0.06), Color(1, 1, 0.95, 0.05), true)
	for k in 3:  # light shafts from the upper left
		var x := box.position.x + box.size.x * (0.18 + k * 0.22)
		var wv := 26.0 + k * 10.0
		var shaft := PackedVector2Array([Vector2(x, box.position.y), Vector2(x + wv, box.position.y),
			Vector2(x + wv + box.size.y * 0.45, box.end.y), Vector2(x + box.size.y * 0.45, box.end.y)])
		_ci.draw_colored_polygon(shaft, Color(1, 1, 1, 0.05))
	for k in 18:  # motes drifting up
		var fx := fmod(k * 0.618, 1.0)
		var fy := 1.0 - fmod(_time * 0.02 + k * 0.137, 1.0)
		var p := box.position + Vector2(fx * box.size.x + sin(_time * 0.5 + k) * 6.0, fy * box.size.y)
		_ci.draw_circle(p, 1.2 + (k % 3) * 0.6, Color(1, 1, 1, 0.35 * sin(fy * PI)))


func _waterfall(a: Vector2, b: Vector2, h: float, hb: float, c: Vector2i, foam := true) -> void:
	var a2 := a.lerp(b, 0.12)
	var b2 := a.lerp(b, 0.88)
	var top_h := h - 0.08
	var sheet := FALL.lerp(ALIEN_COLORS[CombatGrid.T.WATER], strangeness * 0.7)
	var pts := PackedVector2Array([iso(a2.x, a2.y, top_h), iso(b2.x, b2.y, top_h), iso(b2.x, b2.y, hb), iso(a2.x, a2.y, hb)])
	var fall_tex := BattleArt.texture("side_water", true)
	if fall_tex != null:
		# Painted falls scroll downward; one texture covers 2 levels of drop.
		var v := -fmod(_time * 0.6, 1.0)
		var tint := _tint(CombatGrid.T.WATER)
		var uv := PackedVector2Array([Vector2(0, v - top_h * 0.5), Vector2(0.5, v - top_h * 0.5), Vector2(0.5, v - hb * 0.5), Vector2(0, v - hb * 0.5)])
		_ci.draw_polygon(pts, PackedColorArray([tint, tint, tint, tint]), uv, fall_tex)
		_ci.draw_line(iso(a2.x, a2.y, top_h), iso(b2.x, b2.y, top_h), Color(1, 1, 1, 0.7), 2.0, true)
		if foam:
			_foam(a2, b2, hb, c)
		return
	_ci.draw_colored_polygon(pts, sheet)
	for k in 4:
		var f := 0.2 + k * 0.2
		var p := a2.lerp(b2, f)
		var phase := fmod(_time * 1.6 + k * 0.37 + c.x * 0.1, 1.0)
		var y0 := lerpf(top_h, hb, phase)
		var y1 := maxf(hb, y0 - 0.6)
		_ci.draw_line(iso(p.x, p.y, y0), iso(p.x, p.y, y1), sheet.lightened(0.45), 1.5, true)
	if foam:
		_foam(a2, b2, hb, c)


## Soft falls: one flat sheet across neighbouring falls (no frame between cells) in the set's own water colour,
## bending white over the edge; streaks placed by screen position, so they carry on across cells, slide down
## it; foam at the foot.
func _waterfall_soft(a: Vector2, b: Vector2, h: float, hb: float, c: Vector2i, d: Vector2i, foam: bool) -> void:
	var ends := PackedFloat32Array()
	for p: Vector2 in [a, b]:
		var m := c + Vector2i(int(signf(p.x - c.x - 0.5)), int(signf(p.y - c.y - 0.5))) - d
		var joined := grid.solid(m) and grid.terrain_at(m) == CombatGrid.T.WATER and absf(_surf(m) - h) < 0.01 \
			and _surf_or_floor(m + d) < h - 0.01
		ends.append(0.0 if joined else 0.1)
	var a2 := a.lerp(b, ends[0])
	var b2 := b.lerp(a, ends[1])
	var tex := BattleArt.top(CombatGrid.T.WATER, grid.zone_at(c))
	var water := BattleArt.average(tex) * _tint(CombatGrid.T.WATER) if tex != null else _terrain_color(CombatGrid.T.WATER)
	_ci.draw_colored_polygon(PackedVector2Array([iso(a2.x, a2.y, h), iso(b2.x, b2.y, h), iso(b2.x, b2.y, hb), iso(a2.x, a2.y, hb)]),
		Color(water.lightened(0.28), 0.96))
	var ua := _screen_u(a2, 0.0)
	var ub := _screen_u(b2, 0.0)
	var per := 7.0
	for j in range(floori(minf(ua, ub) * per), ceili(maxf(ua, ub) * per)):
		var u := (j + 0.2 + 0.6 * MapDress.noise(Vector2(j, 3))) / per
		var f := (u - ua) / (ub - ua)
		if f < 0.0 or f > 1.0:
			continue
		var p := a2.lerp(b2, f)
		if j % 2 == 0:  # a still streak down the whole fall
			_ci.draw_line(iso(p.x, p.y, h - 0.1), iso(p.x, p.y, hb), Color(1, 1, 1, 0.22), 1.0, true)
		var speed := 0.3 + 0.35 * MapDress.noise(Vector2(j, 5))
		var length := 0.5 + 1.1 * MapDress.noise(Vector2(j, 9))
		for dash in 2:
			var ph := fmod(_time * speed + MapDress.noise(Vector2(j, 11)) + dash * 0.5, 1.0)
			var y0 := lerpf(h, hb, ph)
			_ci.draw_line(iso(p.x, p.y, y0), iso(p.x, p.y, maxf(hb, y0 - length)), Color(1, 1, 1, 0.5 * sin(ph * PI)),
				1.0 + MapDress.noise(Vector2(j, 13)), true)
	_ci.draw_line(iso(a2.x, a2.y, h), iso(b2.x, b2.y, h), Color(1, 1, 1, 0.85), 2.2, true)
	if foam:
		_foam(a2, b2, hb, c)
	if ends[0] > 0.0:  # a cel outline down each side where the sheet stops against rock
		_marker_down(a2, h, hb)
	if ends[1] > 0.0:
		_marker_down(b2, h, hb)


## White water where a fall lands: a row of puffs that swell and shrink out of step.
func _foam(a: Vector2, b: Vector2, hb: float, c: Vector2i) -> void:
	_ci.draw_line(iso(a.x, a.y, hb), iso(b.x, b.y, hb), Color(1, 1, 1, 0.85), 3.0, true)
	for k in 5:
		var p := a.lerp(b, 0.1 + k * 0.2)
		var beat := 0.5 + 0.5 * sin(_time * 3.0 + k * 1.7 + c.x + c.y)
		var q := iso(p.x, p.y, hb) + Vector2(0, -1.5)
		_ci.draw_circle(q, 3.0 + beat * 2.2, Color(1, 1, 1, 0.75))
		_ci.draw_circle(q + Vector2(0, -3.0 - beat * 2.0), 1.6 + beat, Color(1, 1, 1, 0.55))


## Steps that run down toward the lowest walkable neighbour.
func _stairs(c: Vector2i, h: float, col: Color) -> void:
	var best := Vector2i(1, 0)
	var low := INF
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var n: Vector2i = c + d
		if grid.passable(n) and grid.height_at(n) < low:
			low = grid.height_at(n)
			best = d
	for k in 5:
		var f := 0.1 + k * 0.2
		var p0: Vector2
		var p1: Vector2
		if best.x != 0:
			var x := c.x + (f if best.x > 0 else 1.0 - f)
			p0 = Vector2(x, c.y)
			p1 = Vector2(x, c.y + 1)
		else:
			var y := c.y + (f if best.y > 0 else 1.0 - f)
			p0 = Vector2(c.x, y)
			p1 = Vector2(c.x + 1, y)
		_ci.draw_line(iso(p0.x, p0.y, h), iso(p1.x, p1.y, h), col.darkened(0.3), 2.0, true)
		_ci.draw_line(iso(p0.x, p0.y, h) + Vector2(0, 2), iso(p1.x, p1.y, h) + Vector2(0, 2), col.lightened(0.2), 1.0, true)


## Darken the edges of a top that sit under a taller neighbour behind it.
func _contact_shadow(c: Vector2i, h: float) -> void:
	for d in [-front_dir(false), -front_dir(true)]:
		var n: Vector2i = c + d
		if not grid.in_bounds(n):
			continue
		# Water is drawn a little under its own level, so a neighbour's water at the same level casts nothing.
		var diff := grid.sight_top(n) - (WATER_INSET if grid.terrain_at(n) == CombatGrid.T.WATER else 0.0) - h
		if diff <= 0.3:
			continue
		var a := clampf(diff * 0.12, 0.1, 0.32)
		var e := _side(Vector2(c), Vector2(c) + Vector2.ONE, d)
		var inward := -Vector2(d) * (0.55 if _soft() else 0.35)
		var p0: Vector2 = e[0]
		var p1: Vector2 = e[1]
		var pts := PackedVector2Array([iso(p0.x, p0.y, h), iso(p1.x, p1.y, h), iso(p1.x + inward.x, p1.y + inward.y, h), iso(p0.x + inward.x, p0.y + inward.y, h)])
		if _soft():  # a soft shade that fades out, not a band per cell
			var dark := Color(0.08, 0.1, 0.2, a * 0.3)
			var clear := Color(dark, 0.0)
			_ci.draw_polygon(pts, PackedColorArray([dark, dark, clear, clear]))
		else:
			_ci.draw_colored_polygon(pts, Color(0.05, 0.08, 0.1, a))


## A small block (tree canopy) centred on p.
func _cube(p: Vector2, r: float, tall: float, col: Color) -> void:
	var t := p + Vector2(0, -tall)
	_ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-r, -r * 0.5), p, p + Vector2(0, -tall), t + Vector2(-r, -r * 0.5)]), col.darkened(0.1))
	_ci.draw_colored_polygon(PackedVector2Array([p, p + Vector2(r, -r * 0.5), t + Vector2(r, -r * 0.5), t]), col.darkened(0.3))
	_ci.draw_colored_polygon(PackedVector2Array([t, t + Vector2(r, -r * 0.5), t + Vector2(0, -r), t + Vector2(-r, -r * 0.5)]), col.lightened(0.12))


## A broken wall standing on the cell: stone courses, a dark arch on some, a ragged top.
func _ruin(c: Vector2i, h: float, seed_v: int) -> void:  # graybox; a prop_pillar sprite replaces it
	var rise := float(CombatGrid.RUIN_RISE) - (0.4 if seed_v % 2 == 0 else 0.0)
	var top_h := h + rise
	var col := MASONRY.lerp(ALIEN_CLIFF, strangeness)
	var lo := Vector2(c) + Vector2(0.14, 0.14)
	var hi := Vector2(c) + Vector2(0.86, 0.86)
	_block(lo, hi, h, top_h, col, seed_v, false)
	var lit := _side(lo, hi, front_dir(false))
	if seed_v % 3 != 1:
		# Arch: a dark doorway on the lit face.
		var a: Vector2 = lit[0]
		var b: Vector2 = lit[1]
		var m := a.lerp(b, 0.5)
		var p0 := a.lerp(b, 0.3)
		var p1 := a.lerp(b, 0.7)
		var arch := PackedVector2Array([iso(p0.x, p0.y, h), iso(p0.x, p0.y, h + 0.9)])
		for k in range(1, 8):
			var ang := PI * k / 8.0
			var q := m + (p0 - m) * cos(ang)
			arch.append(iso(q.x, q.y, h + 0.9 + sin(ang) * 0.35))
		arch.append(iso(p1.x, p1.y, h + 0.9))
		arch.append(iso(p1.x, p1.y, h))
		_ci.draw_colored_polygon(arch, Color(0.12, 0.13, 0.12))
	# Ragged crown: a broken block on top.
	var k0 := Vector2(c.x + 0.25 + (seed_v % 5) * 0.06, c.y + 0.3)
	_block(k0, k0 + Vector2(0.3, 0.3), top_h, top_h + 0.5, col.lightened(0.04), seed_v, true)
	if seed_v % 4 == 0 and BattleArt.side(CombatGrid.T.RUIN, grid.zone_at(c)) == null:
		_drips(lit[0], lit[1], top_h, rise, _terrain_color(CombatGrid.T.GRASS).darkened(0.05), seed_v)


## An axis-aligned block from h0 to h1 over grid rect [lo, hi]: the two camera-facing sides and a cap.
func _block(lo: Vector2, hi: Vector2, h0: float, h1: float, col: Color, seed_v: int, plain: bool) -> void:
	for shade in [false, true]:
		var e := _side(lo, hi, front_dir(shade))
		_face(e[0], e[1], h1, h0, col.darkened(0.28 if shade else 0.05), seed_v, false, plain)
	var cap := PackedVector2Array([iso(lo.x, lo.y, h1), iso(hi.x, lo.y, h1), iso(hi.x, hi.y, h1), iso(lo.x, hi.y, h1)])
	_ci.draw_colored_polygon(cap, col.lightened(0.14))
	cap.append(cap[0])
	_ci.draw_polyline(cap, col.darkened(0.45), 1.0, true)


func _unit_base(u: CombatUnit) -> Vector2:
	var base := iso(u.vis.x + 0.5, u.vis.y + 0.5, u.vis_h) + u.offset - Vector2(0, u.hop)
	var c := Vector2i(roundi(u.vis.x), roundi(u.vis.y))
	if grid.in_bounds(c) and grid.terrain_at(c) == CombatGrid.T.WATER:
		base.y += WATER_INSET * HS  # wading: feet at the water's surface
	return base


## Screen box a piece's body covers (sprite or pawn), for cover checks.
func _unit_box(u: CombatUnit) -> Rect2:
	return Rect2(_unit_base(u) + Vector2(-20, -54), Vector2(40, 54))


## Which props to fade and which pieces to x-ray this frame: anything drawn after a piece (nearer the
## camera) whose prop or block face overlaps a good part of the piece's body.
func _find_cover() -> void:
	_fade.clear()
	_covered.clear()
	_find_skirt_fade()
	for u: CombatUnit in units:
		if u.shown_hp <= 0:
			continue
		var box := _unit_box(u)
		var d := depth_of(u.vis.x, u.vis.y)
		var uc := Vector2i(roundi(u.vis.x), roundi(u.vis.y))
		for dy in range(-6, 7):  # a house in front can reach this far
			for dx in range(-6, 7):
				var c := uc + Vector2i(dx, dy)
				if not grid.in_bounds(c) or depth_of(c.x, c.y) <= d or hidden(c):
					continue
				var h := float(grid.height_at(c))
				var mid := cell_top(c)
				var art := BattleArt.props(grid.terrain_at(c), grid.zone_at(c))
				if not art.list.is_empty() and art.count > 0:
					var ph: float = art.height * TW * 1.1
					var prop := Rect2(mid.x - TW * 0.45, mid.y - ph, TW * 0.9, ph)
					if _overlap(box, prop) > 0.2:
						_fade[c] = true
						if u.team == 0:
							_covered[u] = true
				var a := grid.prop_anchor(c)
				if a != CombatGrid.NONE_CELL and _prop_front(a, grid.props[a]) == c:
					var tex := prop_texture(grid.props[a], grid.zone_at(a))
					if tex != null and _overlap(box, _prop_rect(a, grid.props[a], tex)) > 0.2:
						_fade[a] = true
						if u.team == 0:
							_covered[u] = true
				if h > u.vis_h + 0.5:
					var pts := _diamond(c, h)
					var col := Rect2(pts[0], Vector2.ZERO)
					for q in pts:
						col = col.expand(q)
						col = col.expand(q + Vector2(0, (h - u.vis_h) * HS))
					if _overlap(box, col) > 0.35:
						_covered[u] = true


## Skirt trees in front of a piece, the cursor or a highlighted cell go see-through, so the forest framing
## the map never hides the play.
func _find_skirt_fade() -> void:
	_skirt_fade.clear()
	if not _valley() or _skirt.is_empty():
		return
	var boxes: Array[Rect2] = []
	var depths: Array[int] = []
	for u: CombatUnit in units:
		if u.shown_hp > 0:
			boxes.append(_unit_box(u))
			depths.append(depth_of(u.vis.x, u.vis.y))
	var marks: Array[Vector2i] = []
	if hover != NONE and grid.in_bounds(hover):
		marks.append(hover)
	for c: Vector2i in highlights:
		marks.append(c)
	for c in marks:
		var p := cell_top(c)
		boxes.append(Rect2(p - Vector2(TW * 0.3, TH * 0.3), Vector2(TW * 0.6, TH * 0.6)))
		depths.append(depth_of(c.x, c.y))
	if boxes.is_empty():
		return
	var all := boxes[0]
	for b in boxes:
		all = all.merge(b)
	var tall := look.tree_scale * TW * 1.35
	for c: Vector2i in _skirt:
		var mid := iso(c.x + 0.5, c.y + 0.5, look.floor_h)
		var box := Rect2(mid.x - tall * 0.42, mid.y - tall, tall * 0.84, tall)
		if not box.intersects(all):
			continue
		var d := depth_of(c.x, c.y)
		for i in boxes.size():
			if d > depths[i] and box.intersects(boxes[i]):
				_skirt_fade[c] = true
				break


## Share of a covered by b.
static func _overlap(a: Rect2, b: Rect2) -> float:
	var i := a.intersection(b)
	return i.get_area() / maxf(a.get_area(), 1.0)


func _draw_unit(u: CombatUnit) -> void:
	var base := _unit_base(u)
	if u.spooked:
		base += Vector2(sin(_time * 40.0) * 1.5, 0)
	var col := u.tint
	if u.team == 0 and u.done():
		col = col.darkened(0.35)
	var ring := Color(0.4, 0.7, 1.0) if u.team == 0 else Color(1.0, 0.4, 0.35)
	if u == selected:
		ring = Color(1.0, 0.9, 0.4)
	var top := 48.0
	if CharacterArt.has_art(u.sprite):
		top = _draw_sprite(u, base, col, ring)
	else:
		top = PlaceholderFigure.draw(_ci, base, 26.0, u.figure, u.team, u.anim, _time - u.anim_start,
			u.facing.x < 0, ring, u.team == 0 and u.done())
	# HP pips
	var w := 34.0
	var p := base + Vector2(-w * 0.5, -top)
	_ci.draw_rect(Rect2(p, Vector2(w, 4)), Color(0, 0, 0, 0.6))
	_ci.draw_rect(Rect2(p, Vector2(w * clampf(float(u.shown_hp) / u.max_hp, 0.0, 1.0), 4)), ring)
	var tags := ""
	for s in u.statuses:
		tags += Txt.t("TAG_" + String(s).to_upper()) + " "
	if u.spooked:
		tags += Txt.t("TAG_SPOOKED")
	if tags != "":
		var font := ThemeDB.fallback_font
		_ci.draw_string_outline(font, p + Vector2(-23, -4), tags.strip_edges(), HORIZONTAL_ALIGNMENT_CENTER, 80, 10, 3, Color(0, 0, 0, 0.8))
		_ci.draw_string(font, p + Vector2(-23, -4), tags.strip_edges(), HORIZONTAL_ALIGNMENT_CENTER, 80, 10, Color(1, 0.95, 0.7))


## A character sprite standing on base: contact shadow and team ring like the Pawn, then the anim frame.
## Returns how far above base the HP pips go.
func _draw_sprite(u: CombatUnit, base: Vector2, col: Color, ring: Color) -> float:
	Pawn.ellipse(_ci, base + Vector2(0, 2), 15.0, 5.0, Color(0, 0, 0, 0.25))
	Pawn.ellipse(_ci, base, 16.0, 5.7, ring, false, 2.5)
	var mod := Color.WHITE if col == u.tint else Color(0.65, 0.65, 0.65)  # done pieces dim like the pawn
	if u.sprite == CharacterArt.FALLBACK:
		# The general dummy is drawn neutral: the team colour tints it, and enemies get a glyph to tell them apart.
		var body: Color = PlaceholderFigure.spec(u.figure, u.team).body
		mod = body if col == u.tint else body.darkened(0.35)
	var top := _draw_frame(u, base, mod)
	if u.sprite == CharacterArt.FALLBACK:
		PlaceholderFigure.glyph(_ci, PlaceholderFigure.spec(u.figure, u.team).glyph, base + Vector2(0, -top - 8), 6.0)
	return top


## The anim to draw: in a fight, idle and walk become ready and advance (weapon out) when the art has them.
func _stance(u: CombatUnit) -> String:
	if combat_stance and (u.anim == "idle" or u.anim == "walk"):
		var alt := "ready" if u.anim == "idle" else "advance"
		if CharacterArt.has_anim(u.sprite, alt):
			return alt
	return u.anim


## The piece's current anim frame at base, modulated. Returns how far above base the HP pips go.
func _draw_frame(u: CombatUnit, base: Vector2, mod: Color) -> float:
	var d := Vector2(u.facing)
	var dir := CharacterArt.screen_dir(iso(1.0 + d.x, 1.0 + d.y, 0.0) - iso(1.0, 1.0, 0.0))
	var f := CharacterArt.frame(u.sprite, _stance(u), dir, _time - u.anim_start)
	if f.is_empty():
		return 48.0
	var s: float = f.scale
	_ci.draw_set_transform(base, 0.0, Vector2(-s if f.flip else s, s))
	_ci.draw_texture_rect_region(f.tex, Rect2(-f.anchor, f.region.size), f.region, mod)
	_ci.draw_set_transform(Vector2.ZERO)
	return f.anchor.y * s * 0.72


## Start a sprite anim from its first frame. Non-looping anims fall back to idle when done.
func play_anim(u: CombatUnit, anim: String) -> void:
	u.anim = anim
	u.anim_start = _time
	if anim != "idle" and anim != "walk":
		var start := u.anim_start
		get_tree().create_timer(CharacterArt.length(u.sprite, anim) + 0.15).timeout.connect(func() -> void:
			if u.anim == anim and u.anim_start == start:
				u.anim = "idle")


## Turn a piece toward a cell (the dominant grid axis, since pieces face the four grid directions).
func face(u: CombatUnit, toward: Vector2i) -> void:
	var v := toward - u.cell
	if v == Vector2i.ZERO:
		return
	u.facing = Vector2i(signi(v.x), 0) if absi(v.x) >= absi(v.y) else Vector2i(0, signi(v.y))


func float_text(c: Vector2i, text: String, color := Color.WHITE) -> void:
	_floaters.append({"text": text, "pos": cell_top(c) + Vector2(-60, -56), "t": 1.2, "color": color})


# --- animation -------------------------------------------------------------------

## Hop along a path like a piece lifted off the board, one tile at a time.
func animate_move(u: CombatUnit, path: Array[Vector2i]) -> void:
	var walker := CharacterArt.has_art(u.sprite)
	if path.size() > 1:
		play_anim(u, "walk")
	for i in range(1, path.size()):
		var a := Vector2(path[i - 1])
		var b := Vector2(path[i])
		var ha := float(grid.height_at(path[i - 1]))
		var hb := float(grid.height_at(path[i]))
		u.facing = path[i] - path[i - 1]
		# Sprites walk, so they only hop to climb; pawns hop every tile like a lifted piece.
		var lift := (2.0 if walker else 10.0) + absf(hb - ha) * HS * 0.6
		var step := func(t: float) -> void:
			u.vis = a.lerp(b, t)
			u.vis_h = lerpf(ha, hb, t)
			u.hop = sin(t * PI) * lift
		var tw := create_tween()
		tw.tween_method(step, 0.0, 1.0, 0.16)
		await tw.finished
	u.hop = 0.0
	play_anim(u, "idle")


## Slide without a hop: shoved, not walking.
func animate_push(u: CombatUnit, path: Array) -> void:
	for i in range(1, path.size()):
		var a := Vector2(path[i - 1])
		var b := Vector2(path[i])
		var ha := float(grid.height_at(path[i - 1]))
		var hb := float(grid.height_at(path[i]))
		var step := func(t: float) -> void:
			u.vis = a.lerp(b, t)
			u.vis_h = lerpf(ha, hb, t * t)
		var tw := create_tween()
		tw.tween_method(step, 0.0, 1.0, 0.14)
		await tw.finished


## Screen position of a cell's top, for placing menus next to a piece.
func cell_screen_pos(c: Vector2i) -> Vector2:
	return get_global_transform_with_canvas() * cell_top(c)


func animate_attack(att: CombatUnit, tgt: CombatUnit, hit: bool) -> void:
	face(att, tgt.cell)
	# Swing or cast, and land the hit on the anim's hit frame (C17). Placeholders use the same timing.
	var anim := "cast" if att.magic else "attack"
	play_anim(att, anim)
	await get_tree().create_timer(CharacterArt.hit_time(att.sprite, anim)).timeout
	if hit:
		face(tgt, att.cell)
		play_anim(tgt, "hurt")
		var shake := create_tween()
		for i in 4:
			shake.tween_property(tgt, "offset", Vector2(4 if i % 2 == 0 else -4, 0), 0.04)
		shake.tween_property(tgt, "offset", Vector2.ZERO, 0.04)
		await shake.finished

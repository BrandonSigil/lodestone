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
const PLATE_SCALE := 1.35  ## backdrop plate width as a multiple of the floor's footprint
const FADE_RINGS := 4  ## empty cells this far out from the floor fade into the dark
const FADE_DARK := Color(0.1, 0.15, 0.2)
const COBBLE_ALPHA := 0.32  ## the faint cobble hairlines on some tops
const SKY_SCALE := 1.9  ## skyline width as a multiple of the floor's footprint
const SKY_LOW := 0.6  ## how much of the skyline's height sits above the board's centre
const SCENERY_RINGS := 2  ## empty cells this many steps out from the floor carry scenery
const LOWLAND_DROP := 1.6  ## with a skyline, the floor's cliffs drop this far below the base to the lowland
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
var backdrop := false  ## a soft paper card behind the island (tester and fights); a set's backdrop plate draws either way
var combat_stance := false  ## pieces stand ready (weapon drawn) instead of relaxed; Battle sets it
var _fade := {}  ## cells whose props draw see-through this frame (a party piece stands behind them)
var _floor_base := BASE  ## how far the floor's cliffs drop: BASE, or lower when the lowland is drawn
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
var can_turn := true  ## false on maps whose building sprites only read from the front


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
	queue_redraw()  # idle breathing and spooked jitter


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


## Cells grouped by draw depth, back first.
func _layers() -> Array:
	var n := grid.w + grid.h + 1
	var out := []
	out.resize(n)
	for i in n:
		out[i] = []
	for y in grid.h:
		for x in grid.w:
			out[clampi(depth_of(x, y), 0, n - 1)].append(Vector2i(x, y))
	return out


func pick(local: Vector2) -> Vector2i:
	# Front-most cells first so taller blocks in front win.
	var layers := _layers()
	for i in range(layers.size() - 1, -1, -1):
		for c: Vector2i in layers[i]:
			if hidden(c) and not (edit_void and grid.terrain_at(c) == CombatGrid.T.VOID):
				continue
			if Geometry2D.is_point_in_polygon(local, _diamond(c, grid.height_at(c))):
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

func _draw() -> void:
	BattleArt.use_set(art_set)
	if grid == null:
		return
	var has_sky := BattleArt.texture("skyline", false, art_set) != null
	if backdrop or has_sky or BattleArt.texture("backdrop", false, art_set) != null:
		_draw_backdrop()
	_floor_base = BASE - LOWLAND_DROP if has_sky else BASE
	var rings := _ring_cells() if has_sky else {}
	var front := _front_depth() if has_sky else -1
	var layers := _layers()
	for c: Vector2i in rings:
		if not grid.in_bounds(c):  # scenery beyond the grid joins the depth order too
			layers[clampi(depth_of(c.x, c.y), 0, layers.size() - 1)].append(c)
	_find_cover()
	for depth in layers.size():
		for c: Vector2i in layers[depth]:
			if rings.has(c):
				# The outer ring in front of the floor goes dark, with treeline silhouettes, so the foreground frames the floor.
				var in_front: bool = rings[c] == SCENERY_RINGS and depth_of(c.x, c.y) > front
				_ring_ground(c, rings[c], in_front)
				_scenery(c, rings[c], in_front)
				continue
			if hidden(c):
				if edit_void and grid.terrain_at(c) == CombatGrid.T.VOID:
					draw_polyline(_ring(_diamond(c, 0.0)), Color(1, 1, 1, 0.5 if c == hover else 0.14), 1.0, true)
				continue
			_draw_tile(c)
			if fog_on and fog[c] == 1:
				_veil(c)
		for u: CombatUnit in units:
			if u.shown_hp > 0 and clampi(depth_of(u.vis.x, u.vis.y), 0, layers.size() - 1) == depth:
				_draw_unit(u)
	var font := ThemeDB.fallback_font
	# Ghost pass: pieces something in front hides still show, over everything: a party sprite as a tinted
	# see-through copy (x-ray), anyone else as a bright foot ring and head outline.
	for u: CombatUnit in units:
		if u.shown_hp > 0 and _covered.has(u):
			var base := _unit_base(u)
			var ring := Color(0.4, 0.7, 1.0) if u.team == 0 else Color(1.0, 0.4, 0.35)
			Pawn.ellipse(self, base, 26.0 * 0.62, 26.0 * 0.22, Color(ring, 0.85), false, 2.0)
			if CharacterArt.has_art(u.sprite):
				_draw_frame(u, base, Color(ring.lightened(0.3), 0.55))
			else:
				draw_arc(base + Vector2(0, -26.0 * 1.22), 26.0 * 0.3, 0, TAU, 20, Color(ring, 0.7), 2.0, true)
	for f in _floaters:
		var a := clampf(f.t, 0.0, 1.0)
		draw_string_outline(font, f.pos, f.text, HORIZONTAL_ALIGNMENT_CENTER, 120, 16, 4, Color(0, 0, 0, a))
		draw_string(font, f.pos, f.text, HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color(f.color, a))


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
	var h := float(grid.height_at(c))
	var col := Color(0.06, 0.07, 0.1, 0.55)
	draw_colored_polygon(_diamond(c, h), col)
	for shade in [false, true]:
		var d := front_dir(shade)
		var n := c + d
		var nh := float(grid.height_at(n)) if grid.in_bounds(n) else BASE
		var low := maxf(BASE, minf(nh, h))
		if low >= h:
			continue
		var e := _side(Vector2(c), Vector2(c) + Vector2.ONE, d)
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		draw_colored_polygon(PackedVector2Array([iso(a.x, a.y, h), iso(b.x, b.y, h), iso(b.x, b.y, low), iso(a.x, a.y, low)]), col)


func _terrain_color(t: int) -> Color:
	return (TOP_COLORS[t] as Color).lerp(ALIEN_COLORS[t], strangeness)


## Multiplier that drifts painted art toward the alien palette as strangeness rises.
func _tint(t: int) -> Color:
	var a: Color = TOP_COLORS[t]
	var b: Color = ALIEN_COLORS[t]
	return Color.WHITE.lerp(Color(b.r / a.r, b.g / a.g, b.b / a.b), strangeness)


func _draw_tile(c: Vector2i) -> void:
	var h := float(grid.height_at(c))
	var t := grid.terrain_at(c)
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
	# The two faces turned toward the camera: lit (lower-left) and shade (lower-right). Only the part
	# above the neighbour shows, but painting down to it is fine because nearer cells paint over the rest.
	var moss := _terrain_color(CombatGrid.T.GRASS if t != CombatGrid.T.FOREST else t).darkened(0.08)
	for shade in [false, true]:
		var d := front_dir(shade)
		var n := c + d
		var edge := not grid.solid(n)  # the island's rim: the face runs down to the base and hangs below it
		var nh := _floor_base if edge else float(grid.height_at(n))
		var side := _side(Vector2(c), Vector2(c) + Vector2.ONE, d)
		var col := face.darkened(0.32 if shade else 0.12)
		# Painted sides keep the guide's values: lit 75% of the top (baked into the art), shade 55%.
		var mod := Color(tint * (0.72 if shade else 1.0), 1.0)
		_face(side[0], side[1], h, maxf(_floor_base, minf(nh, h)), col, seed_v + (7 if shade else 0), not built, false, side_tex, mod)
		if edge and island:
			var rock := BattleArt.average(side_tex) * mod if side_tex != null else col
			_underside(side[0], side[1], Color(rock, 1.0) * (0.9 if shade else 1.0), seed_v + (3 if shade else 0), d)
		if nh >= h:
			continue
		if t == CombatGrid.T.WATER:
			_waterfall(side[0], side[1], h, nh, c)
			if edge and island:
				_spill(side[0], side[1], c)
		elif t != CombatGrid.T.ROAD and (edge or (not built and side_tex == null)):  # the rim always drips
			var drip := moss.darkened(0.15 if shade else 0.0) if side_tex == null else (BattleArt.average(side_tex) * mod).lightened(0.1)
			_drips(side[0], side[1], h, h - nh, drip, seed_v + (11 if shade else 0))
	var top := _diamond(c, h)
	var tl := top[0]
	var tr := top[1]
	var br := top[2]
	var bl := top[3]
	var lit_edge := _side(Vector2(c), Vector2(c) + Vector2.ONE, front_dir(false))
	var shade_edge := _side(Vector2(c), Vector2(c) + Vector2.ONE, front_dir(true))
	if top_tex != null:
		var uv := PackedVector2Array()
		for k in [Vector2(c), Vector2(c.x + 1, c.y), Vector2(c) + Vector2.ONE, Vector2(c.x, c.y + 1)]:
			uv.append(k / BattleArt.TOP_TILES)
		var lift := Color(tint * (1.0 + minf(h, 6.0) * 0.025), 1.0)
		draw_polygon(top, PackedColorArray([lift, lift, lift, lift]), uv, top_tex)
	else:
		draw_colored_polygon(top, top_col)
	match t:
		CombatGrid.T.STONE:
			if top_tex == null:  # painted stone has its own slab joints
				var line := top_col.darkened(0.18)
				draw_line(iso(c.x + 0.5, c.y, h), iso(c.x + 0.5, c.y + 1, h), line, 1.0, true)
				draw_line(iso(c.x, c.y + 0.5, h), iso(c.x + 1, c.y + 0.5, h), line, 1.0, true)
				if seed_v % 3 == 0:
					draw_line(iso(c.x + 0.2, c.y + 0.6, h), iso(c.x + 0.35, c.y + 0.85, h), line, 1.0, true)
		CombatGrid.T.STAIRS:
			_stairs(c, h, top_col)
	if t != CombatGrid.T.WATER and t != CombatGrid.T.STAIRS:
		_cobble(top, top_col.darkened(0.35), seed_v)
	_contact_shadow(c, h)
	if danger.has(c):
		draw_colored_polygon(top, Color(1.0, 0.55, 0.15, 0.22))
	if highlights.has(c):
		draw_colored_polygon(top, highlights[c])
		if top_tex != null:
			# Painted tops are busier than graybox, so highlighted cells also get a solid rim.
			var rim: Color = highlights[c]
			draw_polyline(PackedVector2Array([tl, tr, br, bl, tl]), Color(rim, 0.95), 2.0, true)
	if area.has(c):
		draw_colored_polygon(top, Color(1.0, 0.4, 0.2, 0.45))
	if c == hover:
		draw_colored_polygon(top, Color(1, 1, 1, 0.18))
	var edge := top_col.darkened(0.55)
	if show_grid:
		draw_polyline(PackedVector2Array([tl, tr, br, bl, tl]), Color(edge, 0.5 if top_tex == null else 0.2), 1.0, true)
	for shade in [false, true]:
		var e: Array = shade_edge if shade else lit_edge
		var n := c + front_dir(shade)
		if show_grid or not grid.solid(n) or grid.height_at(n) < h:
			draw_line(iso(e[0].x, e[0].y, h), iso(e[1].x, e[1].y, h), Color(top_col.lightened(0.35), 0.8), 1.5, true)
	if danger.has(c):
		draw_polyline(PackedVector2Array([tl, tr, br, bl, tl]), Color(1.0, 0.5, 0.1, 0.7), 1.5, true)
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
				draw_line(p, p + Vector2(0, -7), Color(0.4, 0.3, 0.22), 2.0)
				_cube(p + Vector2(0, -7), 7.0, 9.0, top_col.lightened(0.05))
		CombatGrid.T.ROCK:
			if top_tex != null:
				return  # a painted set without boulder art (house walls): the texture is the wall top
			draw_colored_polygon(PackedVector2Array([mid + Vector2(-14, 4), mid + Vector2(-8, -14), mid + Vector2(6, -18), mid + Vector2(15, 2)]), top_col.darkened(0.25))
			draw_colored_polygon(PackedVector2Array([mid + Vector2(-8, -14), mid + Vector2(6, -18), mid + Vector2(2, -8)]), top_col.lightened(0.1))
		CombatGrid.T.WATER:
			if top_tex == null:  # painted water has its own streaks
				var wob := sin(_time * 2.0 + c.x + c.y) * 2.0
				draw_line(mid + Vector2(-10 + wob, -2), mid + Vector2(4 + wob, -2), top_col.lightened(0.3), 2.0)
				draw_line(mid + Vector2(-2 - wob, 4), mid + Vector2(10 - wob, 4), top_col.lightened(0.3), 2.0)
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
		Pawn.ellipse(self, base, pw * 0.36, pw * 0.13, Color(0.1, 0.1, 0.12, 0.22), true)
		var a := 0.35 if _fade.has(c) else 1.0  # see-through while a piece stands behind it
		draw_texture_rect(tex, Rect2(base.x - pw * 0.5, base.y - ph, pw, ph), false, Color(tint, a))
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
	var tex := BattleArt.texture(String(p.sprite), false, grid.zone_at(a))
	var col := Color.WHITE
	if fog_on and fog.get(c, 2) == 1:
		col = Color(0.45, 0.46, 0.52)  # remembered, out of sight: same wash as the veil
	if _fade.has(a):
		col.a = 0.35
	if tex == null:
		var h := float(grid.height_at(a))
		var tall: float = p.tall
		var top: float = h + (tall * 2.0 if tall > 0.0 else 3.0)
		var lo := Vector2(a)
		var hi: Vector2 = lo + Vector2(p.foot)
		for shade in [false, true]:
			var e: Array = _side(lo, hi, front_dir(shade))
			var q := PackedVector2Array([iso(e[0].x, e[0].y, top), iso(e[1].x, e[1].y, top), iso(e[1].x, e[1].y, h), iso(e[0].x, e[0].y, h)])
			draw_colored_polygon(q, MASONRY.darkened(0.3 if shade else 0.12) * col)
		draw_colored_polygon(PackedVector2Array([iso(lo.x, lo.y, top), iso(hi.x, lo.y, top), iso(hi.x, hi.y, top), iso(lo.x, hi.y, top)]), MASONRY.lightened(0.1) * col)
		return
	var r := _prop_rect(a, p, tex)
	if p.tall > 0.0 and not p.walk:
		var b := Vector2(r.get_center().x, r.end.y)
		Pawn.ellipse(self, b, r.size.x * 0.36, r.size.x * 0.13, Color(0.1, 0.1, 0.12, 0.22 * col.a), true)
	draw_texture_rect(tex, r, false, col)


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
		draw_polygon(pts, PackedColorArray([mod, mod, mod, mod]), PackedVector2Array([Vector2(ua, vt), Vector2(ub, vt), Vector2(ub, vb), Vector2(ua, vb)]), tex)
		draw_line(iso(a.x, a.y, hb), iso(b.x, b.y, hb), col.darkened(0.4), 1.0, true)
		return
	draw_colored_polygon(pts, col)
	if plain:
		return
	var line := col.darkened(0.22)
	var lvl := floorf(h)
	var row := 0
	while lvl > hb + 0.05:
		var top_l := minf(h, lvl + 1.0)
		if lvl < h - 0.05:
			draw_line(iso(a.x, a.y, lvl), iso(b.x, b.y, lvl), line, 1.0, true)
		# Staggered joints, like laid stone.
		var f := 0.3 if (row + seed_v) % 2 == 0 else 0.65
		var j := a.lerp(b, f)
		draw_line(iso(j.x, j.y, top_l), iso(j.x, j.y, maxf(lvl, hb)), line, 1.0, true)
		lvl -= 1.0
		row += 1
	if lip:
		# A darker soil band under the grass edge.
		var lip_h := minf(0.3, h - hb)
		draw_colored_polygon(PackedVector2Array([iso(a.x, a.y, h), iso(b.x, b.y, h), iso(b.x, b.y, h - lip_h), iso(a.x, a.y, h - lip_h)]), col.darkened(0.15))
	draw_line(iso(a.x, a.y, hb), iso(b.x, b.y, hb), col.darkened(0.4), 1.0, true)


## Moss or ice hanging over a ledge. Each drip grows out of the rim, hangs, then a bead falls off and
## fades. The cycle is staggered per drip so the rim never moves in step.
func _drips(a: Vector2, b: Vector2, h: float, drop: float, col: Color, seed_v: int) -> void:
	for i in 4:
		var r := ((seed_v * (i + 3)) % 97) / 97.0
		if r < 0.3:
			continue
		var f := 0.12 + 0.76 * (((seed_v + i * 31) % 89) / 89.0)
		var top_p := iso(lerpf(a.x, b.x, f), lerpf(a.y, b.y, f), h)
		var full := minf(drop, 0.3 + r * 0.6) * HS
		var t := fmod(_time / (3.0 + r * 3.0) + f * 1.7 + i * 0.37, 1.0)
		var grow := minf(t / 0.5, 1.0)
		var fall := clampf((t - 0.7) / 0.3, 0.0, 1.0)
		var tint := Color(col, 1.0 - fall)
		var drop_px := full * grow * (1.0 - fall)
		if drop_px > 0.5:
			draw_rect(Rect2(top_p + Vector2(-2, 0), Vector2(4, drop_px)), tint)
		if grow > 0.0:
			draw_circle(top_p + Vector2(0, full * grow + fall * HS * 0.6), 3.0, tint)


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
		draw_colored_polygon(upper, c1)
		draw_colored_polygon(lower, c2)
		draw_polyline(_ring(upper), ink, 1.2, true)
		draw_polyline(_ring(lower), ink, 1.2, true)
		if r2 > 0.55:  # one crack per column, like the flat tiles' couple of marks
			var m := i0.lerp(i1, 0.5)
			draw_line(iso(m.x, m.y, BASE - d1 * 0.25), iso(m.x, m.y, BASE - d1 * 0.7), Color(ink, 0.3), 1.0, true)
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
	draw_polygon(top, PackedColorArray([Color(sheet, 0.95), Color(sheet, 0.95), clear, clear]))
	for k in 3:
		var p := a2.lerp(b2, 0.2 + k * 0.3)
		var phase := fmod(_time * 1.2 + k * 0.41 + c.y * 0.13, 1.0)
		var y0 := BASE - phase * drop
		draw_line(iso(p.x, p.y, y0), iso(p.x, p.y, y0 - 0.7), Color(1, 1, 1, 0.6 * (1.0 - phase)), 1.5, true)
	for k in 3:  # mist puffs where the stream gives out
		var p := a2.lerp(b2, 0.15 + k * 0.35)
		var puff := iso(p.x, p.y, BASE - drop + 0.3) + Vector2(0, sin(_time * 1.7 + k) * 1.5)
		draw_circle(puff, 4.0 + k, Color(1, 1, 1, 0.18))


## The skyline: a horizon strip behind the whole board, wider than the floor so it reads as far away.
func _draw_skyline(sky: Texture2D) -> float:
	var width := board_size().x * SKY_SCALE
	var height := width * sky.get_height() / sky.get_width()
	var centre := board_origin() + board_size() * 0.5
	var top := centre.y - height * SKY_LOW
	draw_texture_rect(sky, Rect2(Vector2(centre.x - width * 0.5, top), Vector2(width, height)), false)
	return top + height


## Dark blue ground below the skyline, running down past the bottom of the view so the treeline reads as foreground.
func _draw_ground_fade(top_y: float) -> void:
	var top_col := Color(0.12, 0.17, 0.3)
	var low_col := Color(0.05, 0.08, 0.16)
	var left := board_origin().x - 2000.0
	var right := board_origin().x + board_size().x + 2000.0
	var bottom := board_origin().y + board_size().y + 2000.0
	draw_polygon(PackedVector2Array([Vector2(left, top_y), Vector2(right, top_y), Vector2(right, bottom), Vector2(left, bottom)]),
		PackedColorArray([top_col, top_col, low_col, low_col]))


## Empty cells within SCENERY_RINGS steps of the floor, mapped to their ring (1 is next to the floor).
func _ring_cells() -> Dictionary:
	var dist := {}
	var queue: Array[Vector2i] = []
	for y in int(grid.h):
		for x in int(grid.w):
			var c := Vector2i(x, y)
			if grid.terrain_at(c) != CombatGrid.T.VOID:
				dist[c] = 0
				queue.append(c)
	var i := 0
	while i < queue.size():
		var c: Vector2i = queue[i]
		i += 1
		if dist[c] >= SCENERY_RINGS:
			continue
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + step
			if not dist.has(n):
				dist[n] = dist[c] + 1
				queue.append(n)
	var out := {}
	for n in dist:
		if dist[n] > 0:
			out[n] = dist[n]
	return out


## Flat lowland under the outer ring, below the floor's cliffs, so the scenery stands on ground.
## The outer ring fades a little (ring 2 is see-through), so its edge against the skyline is softer.
func _ring_ground(c: Vector2i, ring_i: int, dark := false) -> void:
	var grass := _terrain_color(CombatGrid.T.GRASS).darkened(0.05 + 0.04 * float(_hash(c) % 3))
	if dark:  # the foreground dissolves into the dark blue ground below
		grass = grass.lerp(Color(0.1, 0.14, 0.26), 0.9)
	grass.a = 1.0 if ring_i == 1 else 0.55
	draw_colored_polygon(_diamond(c, _floor_base), grass)


## Scenery on the empty ground around the floor: rocks and bushes on ring 1, pines and rocks on ring 2,
## with some cells left bare.
func _scenery(c: Vector2i, ring_i: int, dark := false) -> void:
	var seed_v := _hash(c)
	var pick := (seed_v + ring_i) % 5
	var sprite := ""
	if dark:  # the foreground treeline: tall navy pines, every cell
		sprite = "prop_pine_2" if pick % 2 == 0 else "prop_pine_1"
	elif ring_i == 1:
		sprite = ["prop_boulder", "prop_bush", "prop_bush"][pick % 3] if pick < 3 else ""
	else:
		sprite = ["prop_pine_1", "prop_pine_2", "prop_pine_1", "prop_boulder"][pick % 4] if pick < 4 else ""
	if sprite == "":
		return
	var tex := BattleArt.texture(sprite)
	if tex == null:
		return
	var tall := TW * (1.5 if dark else (0.9 if sprite.begins_with("prop_pine") else 0.5))
	var wide := tall * tex.get_width() / float(tex.get_height())
	var base := iso(c.x + 0.5 + (seed_v % 5 - 2) * 0.06, c.y + 0.5, _floor_base)
	Pawn.ellipse(self, base, wide * 0.36, wide * 0.13, Color(0.1, 0.1, 0.12, 0.22), true)
	var tint := Color(0.14, 0.18, 0.3) if dark else Color.WHITE
	draw_texture_rect(tex, Rect2(base.x - wide * 0.5, base.y - tall, wide, tall), false, tint)


## The deepest depth of any floor cell, so scenery beyond it sits in front of the floor.
func _front_depth() -> int:
	var deepest := -1
	for y in int(grid.h):
		for x in int(grid.w):
			if grid.terrain_at(Vector2i(x, y)) != CombatGrid.T.VOID:
				deepest = maxi(deepest, depth_of(x, y))
	return deepest


## A backdrop plate: one picture per art set, centred on the floor and scaled to its footprint.
func _draw_plate(plate: Texture2D) -> void:
	var centre := board_origin() + board_size() * 0.5
	var width := board_size().x * PLATE_SCALE
	var height := width * plate.get_height() / plate.get_width()
	draw_texture_rect(plate, Rect2(centre - Vector2(width, height) * 0.5, Vector2(width, height)), false)
	_draw_outline_fade()


## The dark tint around the floor: rings of empty cells out from the outline, strongest next to it, so the
## fade follows the floor's real shape. It is drawn under the tiles, so the rim covers its inner edge.
func _draw_outline_fade() -> void:
	var dist := {}
	var queue: Array[Vector2i] = []
	for y in int(grid.h):
		for x in int(grid.w):
			var c := Vector2i(x, y)
			if grid.terrain_at(c) != CombatGrid.T.VOID:
				dist[c] = 0
				queue.append(c)
	var i := 0
	while i < queue.size():
		var c: Vector2i = queue[i]
		i += 1
		if dist[c] >= FADE_RINGS:
			continue
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + step
			if dist.has(n) or n.x < -FADE_RINGS or n.y < -FADE_RINGS or n.x > grid.w + FADE_RINGS or n.y > grid.h + FADE_RINGS:
				continue
			dist[n] = dist[c] + 1
			queue.append(n)
	for n in dist:
		var ring: int = dist[n]
		if ring == 0:
			continue
		var a := 0.45 * (1.0 - float(ring - 1) / FADE_RINGS)
		draw_colored_polygon(_diamond(n, 0.0), Color(FADE_DARK, a))


## Sparse hairlines along one edge of some tops: the natural cobble joints that show the grid, not every cell.
func _cobble(top: PackedVector2Array, col: Color, seed_v: int) -> void:
	if seed_v % 3 != 0:
		return
	var e := (seed_v >> 2) % 4
	var a := top[e]
	var b := top[(e + 1) % 4]
	var s := 0.15 + 0.2 * float((seed_v >> 4) % 5) / 4.0
	var t := 0.6 + 0.25 * float((seed_v >> 7) % 4) / 3.0
	draw_line(a.lerp(b, s), a.lerp(b, t), Color(col, COBBLE_ALPHA), 1.0, true)


## The soft card the island floats on: a rounded rectangle around the map with a vertical wash, a glow
## behind the middle, a few light shafts and drifting motes. Colours drift toward lavender with strangeness.
## A set with a backdrop plate draws that instead.
func _draw_backdrop() -> void:
	var sky := BattleArt.texture("skyline", false, art_set)
	if sky != null:
		_draw_ground_fade(_draw_skyline(sky))
	var plate := BattleArt.texture("backdrop", false, art_set)
	if plate != null:
		_draw_plate(plate)
		return
	if sky != null or not backdrop:  # a skyline replaces the paper card
		return
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
	draw_polygon(pts, cols)
	var mid := box.get_center()
	for k in 5:  # glow: stacked soft ellipses
		Pawn.ellipse(self, mid, box.size.x * (0.42 - k * 0.07), box.size.y * (0.36 - k * 0.06), Color(1, 1, 0.95, 0.05), true)
	for k in 3:  # light shafts from the upper left
		var x := box.position.x + box.size.x * (0.18 + k * 0.22)
		var wv := 26.0 + k * 10.0
		var shaft := PackedVector2Array([Vector2(x, box.position.y), Vector2(x + wv, box.position.y),
			Vector2(x + wv + box.size.y * 0.45, box.end.y), Vector2(x + box.size.y * 0.45, box.end.y)])
		draw_colored_polygon(shaft, Color(1, 1, 1, 0.05))
	for k in 18:  # motes drifting up
		var fx := fmod(k * 0.618, 1.0)
		var fy := 1.0 - fmod(_time * 0.02 + k * 0.137, 1.0)
		var p := box.position + Vector2(fx * box.size.x + sin(_time * 0.5 + k) * 6.0, fy * box.size.y)
		draw_circle(p, 1.2 + (k % 3) * 0.6, Color(1, 1, 1, 0.35 * sin(fy * PI)))


func _waterfall(a: Vector2, b: Vector2, h: float, hb: float, c: Vector2i) -> void:
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
		draw_polygon(pts, PackedColorArray([tint, tint, tint, tint]), uv, fall_tex)
		draw_line(iso(a2.x, a2.y, hb), iso(b2.x, b2.y, hb), Color(1, 1, 1, 0.85), 3.0, true)
		return
	draw_colored_polygon(pts, sheet)
	for k in 4:
		var f := 0.2 + k * 0.2
		var p := a2.lerp(b2, f)
		var phase := fmod(_time * 1.6 + k * 0.37 + c.x * 0.1, 1.0)
		var y0 := lerpf(top_h, hb, phase)
		var y1 := maxf(hb, y0 - 0.6)
		draw_line(iso(p.x, p.y, y0), iso(p.x, p.y, y1), sheet.lightened(0.45), 1.5, true)
	var foam := iso(a2.x, a2.y, hb)
	var foam2 := iso(b2.x, b2.y, hb)
	draw_line(foam, foam2, Color(1, 1, 1, 0.85), 3.0, true)


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
		draw_line(iso(p0.x, p0.y, h), iso(p1.x, p1.y, h), col.darkened(0.3), 2.0, true)
		draw_line(iso(p0.x, p0.y, h) + Vector2(0, 2), iso(p1.x, p1.y, h) + Vector2(0, 2), col.lightened(0.2), 1.0, true)


## Darken the edges of a top that sit under a taller neighbour behind it.
func _contact_shadow(c: Vector2i, h: float) -> void:
	for d in [-front_dir(false), -front_dir(true)]:
		var n: Vector2i = c + d
		if not grid.in_bounds(n):
			continue
		var diff := grid.sight_top(n) - h
		if diff <= 0.3:
			continue
		var a := clampf(diff * 0.12, 0.1, 0.32)
		var e := _side(Vector2(c), Vector2(c) + Vector2.ONE, d)
		var inward := -Vector2(d) * 0.35
		var p0: Vector2 = e[0]
		var p1: Vector2 = e[1]
		var pts := PackedVector2Array([iso(p0.x, p0.y, h), iso(p1.x, p1.y, h), iso(p1.x + inward.x, p1.y + inward.y, h), iso(p0.x + inward.x, p0.y + inward.y, h)])
		draw_colored_polygon(pts, Color(0.05, 0.08, 0.1, a))


## A small block (tree canopy) centred on p.
func _cube(p: Vector2, r: float, tall: float, col: Color) -> void:
	var t := p + Vector2(0, -tall)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-r, -r * 0.5), p, p + Vector2(0, -tall), t + Vector2(-r, -r * 0.5)]), col.darkened(0.1))
	draw_colored_polygon(PackedVector2Array([p, p + Vector2(r, -r * 0.5), t + Vector2(r, -r * 0.5), t]), col.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([t, t + Vector2(r, -r * 0.5), t + Vector2(0, -r), t + Vector2(-r, -r * 0.5)]), col.lightened(0.12))


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
		draw_colored_polygon(arch, Color(0.12, 0.13, 0.12))
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
	draw_colored_polygon(cap, col.lightened(0.14))
	cap.append(cap[0])
	draw_polyline(cap, col.darkened(0.45), 1.0, true)


func _unit_base(u: CombatUnit) -> Vector2:
	return iso(u.vis.x + 0.5, u.vis.y + 0.5, u.vis_h) + u.offset - Vector2(0, u.hop)


## Screen box a piece's body covers (sprite or pawn), for cover checks.
func _unit_box(u: CombatUnit) -> Rect2:
	return Rect2(_unit_base(u) + Vector2(-20, -54), Vector2(40, 54))


## Which props to fade and which pieces to x-ray this frame: anything drawn after a piece (nearer the
## camera) whose prop or block face overlaps a good part of the piece's body.
func _find_cover() -> void:
	_fade.clear()
	_covered.clear()
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
					var tex := BattleArt.texture(String(grid.props[a].sprite), false, grid.zone_at(a))
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
		top = PlaceholderFigure.draw(self, base, 26.0, u.figure, u.team, u.anim, _time - u.anim_start,
			u.facing.x < 0, ring, u.team == 0 and u.done())
	# HP pips
	var w := 34.0
	var p := base + Vector2(-w * 0.5, -top)
	draw_rect(Rect2(p, Vector2(w, 4)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(p, Vector2(w * clampf(float(u.shown_hp) / u.max_hp, 0.0, 1.0), 4)), ring)
	var tags := ""
	for s in u.statuses:
		tags += Txt.t("TAG_" + String(s).to_upper()) + " "
	if u.spooked:
		tags += Txt.t("TAG_SPOOKED")
	if tags != "":
		var font := ThemeDB.fallback_font
		draw_string_outline(font, p + Vector2(-23, -4), tags.strip_edges(), HORIZONTAL_ALIGNMENT_CENTER, 80, 10, 3, Color(0, 0, 0, 0.8))
		draw_string(font, p + Vector2(-23, -4), tags.strip_edges(), HORIZONTAL_ALIGNMENT_CENTER, 80, 10, Color(1, 0.95, 0.7))


## A character sprite standing on base: contact shadow and team ring like the Pawn, then the anim frame.
## Returns how far above base the HP pips go.
func _draw_sprite(u: CombatUnit, base: Vector2, col: Color, ring: Color) -> float:
	Pawn.ellipse(self, base + Vector2(0, 2), 15.0, 5.0, Color(0, 0, 0, 0.25))
	Pawn.ellipse(self, base, 16.0, 5.7, ring, false, 2.5)
	var mod := Color.WHITE if col == u.tint else Color(0.65, 0.65, 0.65)  # done pieces dim like the pawn
	if u.sprite == CharacterArt.FALLBACK:
		# The general dummy is drawn neutral: the team colour tints it, and enemies get a glyph to tell them apart.
		var body: Color = PlaceholderFigure.spec(u.figure, u.team).body
		mod = body if col == u.tint else body.darkened(0.35)
	var top := _draw_frame(u, base, mod)
	if u.sprite == CharacterArt.FALLBACK:
		PlaceholderFigure.glyph(self, PlaceholderFigure.spec(u.figure, u.team).glyph, base + Vector2(0, -top - 8), 6.0)
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
	draw_set_transform(base, 0.0, Vector2(-s if f.flip else s, s))
	draw_texture_rect_region(f.tex, Rect2(-f.anchor, f.region.size), f.region, mod)
	draw_set_transform(Vector2.ZERO)
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

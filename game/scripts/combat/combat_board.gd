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
}
const CLIFF := Color(0.62, 0.58, 0.49)  ## side faces of natural ground
const ALIEN_CLIFF := Color(0.42, 0.36, 0.5)
const MASONRY := Color(0.7, 0.66, 0.55)  ## side faces of built stone
const FALL := Color(0.62, 0.9, 0.86)  ## waterfall sheets

var grid: CombatGrid
var units: Array = []
var strangeness := 0.0
var highlights := {}  # cell -> Color
var danger := {}  # cell -> true, the enemy's reach next phase
var area := {}  # cell -> true, cells a skill would hit
var show_coords := false
var _paint_button := 0
var hover := NONE
var selected: CombatUnit = null
var _floaters: Array[Dictionary] = []  # {"text", "pos", "t", "color"}
var _time := 0.0
var rot := 0  ## camera quarter turns, 0-3 (Q turns it)


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
	if grid == null:
		return
	var layers := _layers()
	for depth in layers.size():
		for c: Vector2i in layers[depth]:
			_draw_tile(c)
		for u: CombatUnit in units:
			if u.shown_hp > 0 and clampi(depth_of(u.vis.x, u.vis.y), 0, layers.size() - 1) == depth:
				_draw_unit(u)
	var font := ThemeDB.fallback_font
	# Ghost pass: pieces hidden behind tall blocks still show as a faint outline.
	for u: CombatUnit in units:
		if u.shown_hp > 0:
			var base := iso(u.vis.x + 0.5, u.vis.y + 0.5, u.vis_h) + u.offset - Vector2(0, u.hop)
			var ring := Color(0.4, 0.7, 1.0) if u.team == 0 else Color(1.0, 0.4, 0.35)
			Pawn.ellipse(self, base, 26.0 * 0.62, 26.0 * 0.22, Color(ring, 0.45), false, 1.5)
			draw_arc(base + Vector2(0, -26.0 * 1.22), 26.0 * 0.3, 0, TAU, 20, Color(ring, 0.35), 1.5, true)
	for f in _floaters:
		var a := clampf(f.t, 0.0, 1.0)
		draw_string_outline(font, f.pos, f.text, HORIZONTAL_ALIGNMENT_CENTER, 120, 16, 4, Color(0, 0, 0, a))
		draw_string(font, f.pos, f.text, HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color(f.color, a))


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
	var top_tex := BattleArt.top(t)
	var side_tex := BattleArt.side(t)
	var tint := _tint(t)
	# The two faces turned toward the camera: lit (lower-left) and shade (lower-right). Only the part
	# above the neighbour shows, but painting down to it is fine because nearer cells paint over the rest.
	var moss := _terrain_color(CombatGrid.T.GRASS if t != CombatGrid.T.FOREST else t).darkened(0.08)
	for shade in [false, true]:
		var d := front_dir(shade)
		var n := c + d
		var nh := float(grid.height_at(n)) if grid.in_bounds(n) else BASE
		var side := _side(Vector2(c), Vector2(c) + Vector2.ONE, d)
		var col := face.darkened(0.32 if shade else 0.12)
		# Painted sides keep the guide's values: lit 75% of the top (baked into the art), shade 55%.
		var mod := Color(tint * (0.72 if shade else 1.0), 1.0)
		_face(side[0], side[1], h, maxf(BASE, minf(nh, h)), col, seed_v + (7 if shade else 0), not built, false, side_tex, mod)
		if nh >= h:
			continue
		if t == CombatGrid.T.WATER:
			_waterfall(side[0], side[1], h, nh, c)
		elif not built and t != CombatGrid.T.ROAD:
			_drips(side[0], side[1], h, h - nh, moss.darkened(0.15 if shade else 0.0), seed_v + (11 if shade else 0))
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
	draw_polyline(PackedVector2Array([tl, tr, br, bl, tl]), Color(edge, 0.5 if top_tex == null else 0.2), 1.0, true)
	for e in [lit_edge, shade_edge]:
		draw_line(iso(e[0].x, e[0].y, h), iso(e[1].x, e[1].y, h), Color(top_col.lightened(0.35), 0.8), 1.5, true)
	if danger.has(c):
		draw_polyline(PackedVector2Array([tl, tr, br, bl, tl]), Color(1.0, 0.5, 0.1, 0.7), 1.5, true)
	var mid := cell_top(c)
	if _props(c, h, t, seed_v, tint):
		return
	match t:
		CombatGrid.T.FOREST:
			# Boxy canopy trees, like the stacked-block references.
			for o in [Vector2(-11, -1), Vector2(10, 2), Vector2(0, 7)]:
				var p: Vector2 = mid + o
				draw_line(p, p + Vector2(0, -7), Color(0.4, 0.3, 0.22), 2.0)
				_cube(p + Vector2(0, -7), 7.0, 9.0, top_col.lightened(0.05))
		CombatGrid.T.ROCK:
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
func _props(c: Vector2i, h: float, t: int, seed_v: int, tint: Color) -> bool:
	var art := BattleArt.props(t)
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
		draw_texture_rect(tex, Rect2(base.x - pw * 0.5, base.y - ph, pw, ph), false, tint)
	return true


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
		draw_rect(Rect2(top_p + Vector2(-3, 0), Vector2(6, drop_px)), col)
		draw_circle(top_p + Vector2(0, drop_px), 3.0, col)


## Water spilling off a ledge onto lower ground: a pale sheet, moving streaks and foam at the bottom.
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
	if seed_v % 4 == 0:
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


func _draw_unit(u: CombatUnit) -> void:
	var base := iso(u.vis.x + 0.5, u.vis.y + 0.5, u.vis_h) + u.offset - Vector2(0, u.hop)
	if u.spooked:
		base += Vector2(sin(_time * 40.0) * 1.5, 0)
	var breathe := 1.0 + sin(_time * 2.0 + u.vis.x) * 0.02
	var col := u.tint
	if u.team == 0 and u.done():
		col = col.darkened(0.35)
	var ring := Color(0.4, 0.7, 1.0) if u.team == 0 else Color(1.0, 0.4, 0.35)
	if u == selected:
		ring = Color(1.0, 0.9, 0.4)
	Pawn.draw(self, base, 26.0 * breathe, col, ring)
	# HP pips
	var w := 34.0
	var p := base + Vector2(-w * 0.5, -48)
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


func float_text(c: Vector2i, text: String, color := Color.WHITE) -> void:
	_floaters.append({"text": text, "pos": cell_top(c) + Vector2(-60, -56), "t": 1.2, "color": color})


# --- animation -------------------------------------------------------------------

## Hop along a path like a piece lifted off the board, one tile at a time.
func animate_move(u: CombatUnit, path: Array[Vector2i]) -> void:
	for i in range(1, path.size()):
		var a := Vector2(path[i - 1])
		var b := Vector2(path[i])
		var ha := float(grid.height_at(path[i - 1]))
		var hb := float(grid.height_at(path[i]))
		var lift := 10.0 + absf(hb - ha) * HS * 0.6
		var step := func(t: float) -> void:
			u.vis = a.lerp(b, t)
			u.vis_h = lerpf(ha, hb, t)
			u.hop = sin(t * PI) * lift
		var tw := create_tween()
		tw.tween_method(step, 0.0, 1.0, 0.16)
		await tw.finished
	u.hop = 0.0


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
	var dir := (cell_top(tgt.cell) - cell_top(att.cell)).normalized() * 10.0
	var tw := create_tween()
	tw.tween_property(att, "offset", dir, 0.08)
	tw.tween_property(att, "offset", Vector2.ZERO, 0.12)
	await tw.finished
	if hit:
		var shake := create_tween()
		for i in 4:
			shake.tween_property(tgt, "offset", Vector2(4 if i % 2 == 0 else -4, 0), 0.04)
		shake.tween_property(tgt, "offset", Vector2.ZERO, 0.04)
		await shake.finished

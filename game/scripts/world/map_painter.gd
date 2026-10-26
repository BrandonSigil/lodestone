class_name MapPainter
extends Node2D
## Draws everything on the world map above the ground shader: scattered terrain stamps,
## the Wall, the route the Lodestone records, landmarks, labels and the sheet's folk border.
## Every mark is a pure function of the map seed, so the same seed always prints the same map.

const BORDER := 44.0  ## folk border width around the sheet
const STAMP_GAP := 22.0  ## min map units between scattered stamps

var world: WorldMap
var seed_value := 1
var marks: Array = []  ## Lodestone marks {"d", "kind"} from every run
var best := 0  ## farthest league anyone has walked
var party_d := -1  ## current run's league, -1 when no run is out
var _stamps: Array[Dictionary] = []  # {"pos", "kind", "s", "size", "roll"}, sorted by y
var _font: Font


func setup(w: WorldMap, s: int) -> void:
	world = w
	seed_value = s
	_font = Riso.font()
	_scatter()
	queue_redraw()


func pal(s: float) -> Dictionary:
	return Riso.palette_at(s)


## The flat fill a region's ground gets, by kind. Shared with the ground shader setup.
static func region_fill(kind: String, p: Dictionary) -> Color:
	match kind:
		"forest": return p.mid
		"hills": return p.ground.lerp(p.mid, 0.45)
		"snow": return p.light.lerp(p.ground, 0.25)
		"mountains": return p.far.lerp(p.ground, 0.3)
		"water": return p.sky_top
		"mesa": return p.mid
		"floating": return p.sky_top.lerp(p.dark, 0.25)
		_: return p.ground


static func region_mark(kind: String, p: Dictionary) -> Color:
	if kind == "water":
		return p.light.lerp(p.sky_top, 0.35)
	return region_fill(kind, p).lerp(p.dark, 0.3)


# --- scatter -----------------------------------------------------------------

const DENSITY := {"fields": 0.3, "forest": 0.95, "hills": 0.4, "snow": 0.3, "mountains": 0.45,
	"water": 0.05, "mesa": 0.2, "floating": 0.2, "stalks": 0.7, "deep": 0.4}


func _scatter() -> void:
	_stamps.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 13
	var cell := STAMP_GAP
	var y := cell * 0.5
	while y < WorldMap.SIZE.y:
		var x := cell * 0.5
		while x < WorldMap.SIZE.x:
			var p := Vector2(x, y) + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)) * cell
			var roll := rng.randf()
			var size := rng.randf()
			var keep := rng.randf()
			x += cell
			var hit := world.region_hit(p)
			var r: Dictionary = world.regions[hit.index]
			var kind: String = r.kind
			# keep stamps off borders, the route and landmarks so those read cleanly
			if hit.margin < 10.0 or keep > DENSITY.get(kind, 0.3) * _clump(p, kind):
				continue
			if _near_route(p, 22.0) or _near_landmark(p, 46.0):
				continue
			_stamps.append({"pos": p, "kind": kind, "s": float(r.s), "size": size, "roll": roll})
		y += cell
	_stamps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.y < b.pos.y)


## Low-frequency clumping so trees gather in woods and peaks in ranges, not an even carpet.
func _clump(p: Vector2, kind: String) -> float:
	var v := 0.5 + 0.5 * sin(p.x * 0.021 + world.phase.y) * sin(p.y * 0.027 + world.phase.z)
	if kind == "forest" or kind == "stalks":
		return 0.55 + 0.75 * v
	if kind == "fields":
		return 0.2 + 1.0 * v * v
	return 0.4 + 0.8 * v


func _near_route(p: Vector2, r: float) -> bool:
	for i in range(1, world.route.size()):
		if Geometry2D.get_closest_point_to_segment(p, world.route[i - 1].pos, world.route[i].pos).distance_to(p) < r:
			return true
	return false


func _near_landmark(p: Vector2, r: float) -> bool:
	for l in world.landmarks:
		if p.distance_to(l.pos) < r:
			return true
	return false


# --- draw ------------------------------------------------------------------

func _draw() -> void:
	if world == null:
		return
	for st in _stamps:
		_stamp(st)
	_draw_wall()
	_draw_route()
	for l in world.landmarks:
		_landmark(l)
	_draw_lodestone()
	_draw_labels()
	_draw_border()


func _stamp(st: Dictionary) -> void:
	var p: Vector2 = st.pos
	var s: float = st.s
	var c := pal(s)
	var fill := region_fill(st.kind, c)
	var roll: float = st.roll
	var k: float = st.size
	match st.kind:
		"fields":
			if roll < 0.12:
				_tree(p, 20.0 + k * 8.0, s, roll * 8.0, c)
			else:
				_ticks(p, fill.lerp(c.dark, 0.22), k)
		"forest":
			_tree(p, 24.0 + k * 14.0, s, roll, c)
		"hills":
			_gumdrop(p, 44.0 + k * 24.0, 24.0 + k * 14.0, fill.lerp(c.dark, 0.18), fill.lerp(c.light, 0.3))
		"mountains", "snow":
			_peak(p, 50.0 + k * 44.0, s, roll, c, st.kind == "snow")
		"mesa":
			_mesa(p, 52.0 + k * 40.0, 26.0 + k * 18.0, c.near, c.near.lerp(c.light, 0.3))
		"floating":
			_island(p, 36.0 + k * 28.0, c)
		"stalks":
			_stalk(p, 26.0 + k * 20.0, c, roll)
		"deep":
			if roll < 0.35:
				_stalk(p, 20.0 + k * 14.0, c, roll * 3.0)
			else:
				draw_arc(p, 3.0 + k * 3.0, 0, TAU, 16, fill.lerp(c.light, 0.35), 1.4, true)
		"water":
			draw_arc(p, 5.0, PI * 1.1, PI * 1.9, 8, region_mark("water", c), 1.6, true)


## Trees change on their own roll as strangeness grows: pine, then lollipop, then glowing stalk.
func _tree(p: Vector2, h: float, s: float, roll: float, c: Dictionary) -> void:
	roll = fmod(roll, 1.0)
	if roll < smoothstep(0.62, 0.95, s):
		_stalk(p, h * 1.1, c, roll)
	elif roll < smoothstep(0.25, 0.6, s):
		_lolly(p, h, c, roll)
	else:
		Riso.draw_pine(self, p.x, p.y, h, c.near, c.light)


func _peak(p: Vector2, w: float, s: float, roll: float, c: Dictionary, snowy: bool) -> void:
	if roll < smoothstep(0.62, 0.95, s):
		_island(p, w * 0.7, c)
	elif roll < smoothstep(0.3, 0.6, s):
		_mesa(p, w, w * 0.45, c.near, c.near.lerp(c.light, 0.3))
	else:
		var body: Color = c.far.lerp(c.dark, 0.25) if not snowy else c.far
		_gumdrop(p, w, w * 0.75, body, c.light, true)


func _ticks(p: Vector2, col: Color, k: float) -> void:
	for i in 2:
		var o := Vector2(i * 5.0, -i * 3.0)
		draw_line(p + o, p + o + Vector2(7.0 + k * 3.0, -1.5), col, 1.5, true)


func _gumdrop(p: Vector2, w: float, h: float, col: Color, light: Color, cap := false) -> void:
	if not cap:
		Riso.draw_gumdrop(self, p.x, p.y, w, h, col, light)
		return
	# snow cap: the top of a smaller gumdrop, one flat light band (R2)
	draw_colored_polygon(Riso.gumdrop_pts(p.x, p.y, w, h), col)
	draw_colored_polygon(Riso.gumdrop_pts(p.x, p.y - h * 0.62, w * 0.42, h * 0.38), light)


func _lolly(p: Vector2, h: float, c: Dictionary, roll: float) -> void:
	Riso.draw_lolly(self, p.x, p.y, h, c.dark, c.near.lerp(c.accent, 0.25), Riso.rng(int(roll * 100000.0)))


func _stalk(p: Vector2, h: float, c: Dictionary, roll: float) -> void:
	var bend := (fmod(roll * 7.0, 1.0) - 0.5) * h * 0.5
	var top := p + Vector2(bend * 0.3, -h)
	var pts := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		pts.append(p.lerp(p + Vector2(bend, -h * 0.5), t).lerp(p.lerp(top, t).lerp(top, t), t))
	draw_polyline(pts, c.near.lerp(c.light, 0.15), maxf(1.5, h * 0.06), true)
	var glow: Color = c.accent
	draw_circle(top, h * 0.16, Color(glow, 0.25))
	draw_circle(top, h * 0.08, glow)


func _mesa(p: Vector2, w: float, h: float, col: Color, band: Color) -> void:
	var t := p.y - h
	var pts := PackedVector2Array([
		Vector2(p.x - w / 2, p.y), Vector2(p.x - w * 0.36, t + h * 0.12), Vector2(p.x - w * 0.3, t),
		Vector2(p.x + w * 0.28, t), Vector2(p.x + w * 0.34, t + h * 0.18), Vector2(p.x + w / 2, p.y)])
	draw_colored_polygon(pts, col)
	draw_colored_polygon(PackedVector2Array([Vector2(p.x - w * 0.33, t + h * 0.28), Vector2(p.x + w * 0.36, t + h * 0.28),
		Vector2(p.x + w * 0.38, t + h * 0.4), Vector2(p.x - w * 0.36, t + h * 0.4)]), band)


func _island(p: Vector2, w: float, c: Dictionary) -> void:
	var y := p.y - w * 0.5
	draw_colored_polygon(Riso.circle_pts(p + Vector2(0, 2), w * 0.4, w * 0.08), Color(c.dark, 0.45))
	var rock := PackedVector2Array([Vector2(p.x - w / 2, y), Vector2(p.x + w / 2, y), Vector2(p.x + w * 0.18, y + w * 0.28),
		Vector2(p.x + w * 0.04, y + w * 0.42), Vector2(p.x - w * 0.14, y + w * 0.24)])
	draw_colored_polygon(rock, c.near)
	draw_colored_polygon(PackedVector2Array([Vector2(p.x - w / 2, y), Vector2(p.x - w * 0.42, y - w * 0.09),
		Vector2(p.x + w * 0.4, y - w * 0.09), Vector2(p.x + w / 2, y)]), c.far)
	draw_circle(Vector2(p.x + w * 0.2, y - w * 0.14), w * 0.06, c.accent)


## The Wall: a long band of stacked stones with towers, in the threshold's own dark and glow.
func _draw_wall() -> void:
	var c := pal(0.5)
	var pts := PackedVector2Array()
	var y := 0.0
	while y <= WorldMap.SIZE.y:
		pts.append(Vector2(world.wall_x(y), y))
		y += 8.0
	draw_polyline(pts, Color(c.accent, 0.22), 46.0, true)
	draw_polyline(pts, c.dark, 26.0, true)
	draw_polyline(pts, c.far.lerp(c.mid, 0.5), 14.0, true)
	# stones: short light dashes down the band
	var i := 0
	for q in pts:
		if i % 3 == 0:
			draw_line(q + Vector2(-7, 0), q + Vector2(7, 0), c.dark, 2.5)
		i += 1
	# towers every so often, skipped where the gate stands
	var gate := world.landmark("gate")
	var ty := 70.0
	while ty < WorldMap.SIZE.y:
		var tp := Vector2(world.wall_x(ty), ty)
		if gate.is_empty() or tp.distance_to(gate.pos) > 70.0:
			_tower(tp, 22.0, c.dark, c.accent)
		ty += 160.0


func _tower(p: Vector2, w: float, col: Color, lit: Color) -> void:
	draw_rect(Rect2(p.x - w / 2, p.y - w * 1.5, w, w * 1.6), col)
	for k in 3:
		draw_rect(Rect2(p.x - w / 2 + k * w * 0.4, p.y - w * 1.8, w * 0.22, w * 0.32), col)
	draw_rect(Rect2(p.x - w * 0.1, p.y - w * 1.1, w * 0.2, w * 0.3), lit)


## The route the Lodestone records: a stitched dashed line, lighter where nobody has walked yet.
func _draw_route() -> void:
	var walked := float(maxi(best, party_d))
	var all := world.route_points(0, world.route_length())
	for i in range(1, all.size()):
		var a := all[i - 1]
		var b := all[i]
		var d := float(i) * 2.0
		var c := pal(world.strangeness_at(a))
		draw_line(a, b, c.light, 11.0, true)
		if i % 3 != 0:
			var col: Color = c.dark if d <= walked else c.dark.lerp(c.light, 0.45)
			draw_line(a, b, col, 5.0, true)
	# league posts every 50
	for d in range(50, int(world.route_length()), 50):
		var q := world.route_point(d)
		var c := pal(world.strangeness_at(q))
		draw_circle(q, 9.0, c.light)
		draw_circle(q, 6.0, c.dark)


func _landmark(l: Dictionary) -> void:
	var p: Vector2 = l.pos
	var c := pal(world.strangeness_at(p))
	match l.kind:
		"village":
			# a cluster of dark houses, one lit window each, around the Lodestone's glow
			draw_circle(p + Vector2(0, -8), 48.0, Color(c.accent, 0.16))
			for h in [[-26, 4, 22], [2, -8, 26], [28, 6, 20], [-6, 18, 18]]:
				Riso.draw_house(self, p.x + h[0], p.y + h[1], h[2], c, true)
		"farm":
			Riso.draw_house(self, p.x, p.y, 18.0, c, false)
			for k in 4:
				draw_line(p + Vector2(14, -2 + k * 6), p + Vector2(40, -6 + k * 6), c.mid.lerp(c.dark, 0.2), 2.0, true)
		"tower":
			_tower(p, 14.0, c.dark, c.accent)
		"pass":
			_gumdrop(p + Vector2(-14, 0), 30.0, 26.0, c.far.lerp(c.dark, 0.25), c.light, true)
			_gumdrop(p + Vector2(16, 2), 26.0, 22.0, c.far.lerp(c.dark, 0.25), c.light, true)
		"gate":
			var g := pal(0.5)
			draw_rect(Rect2(p.x - 20, p.y - 30, 40, 34), g.dark)
			for k in 4:
				draw_rect(Rect2(p.x - 20 + k * 11, p.y - 36, 7, 8), g.dark)
			draw_colored_polygon(Riso.gumdrop_pts(p.x, p.y + 4, 18.0, 24.0), g.accent)
		"ruin":
			for k in 3:
				draw_rect(Rect2(p.x - 16 + k * 12, p.y - 12 - (k % 2) * 10, 7, 12 + (k % 2) * 10), c.dark)
			draw_rect(Rect2(p.x - 20, p.y, 40, 4), c.dark)
		"spire":
			draw_colored_polygon(PackedVector2Array([p + Vector2(-8, 0), p + Vector2(0, -52), p + Vector2(8, 0)]), c.dark)
			draw_circle(p + Vector2(0, -58), 10.0, Color(c.accent, 0.3))
			draw_circle(p + Vector2(0, -58), 5.0, c.accent)
		"end":
			draw_circle(p, 30.0, Color(c.accent, 0.18))
			Riso.draw_stamp_star(self, p + Vector2(0, -6), 20.0, c.accent)
			draw_arc(p + Vector2(0, -6), 26.0, 0, TAU, 32, c.light, 2.0, true)


## Marks every run has left (diamonds), the farthest point reached (a flag) and the party.
func _draw_lodestone() -> void:
	for mk in marks:
		var q := world.route_point(float(mk.d)) + Vector2(0, 14)
		var c := pal(world.strangeness_at(q))
		var col: Color = c.accent if mk.kind == "combat" else c.light
		draw_colored_polygon(PackedVector2Array([q + Vector2(0, -5), q + Vector2(5, 0), q + Vector2(0, 5), q + Vector2(-5, 0)]), col)
	if best > 0:
		var q := world.route_point(best)
		var c := pal(world.strangeness_at(q))
		draw_line(q, q + Vector2(0, -30), c.dark, 2.5)
		draw_colored_polygon(PackedVector2Array([q + Vector2(0, -30), q + Vector2(16, -24), q + Vector2(0, -18)]), c.accent)
	var at := world.route_point(maxf(0.0, party_d))
	if party_d >= 0:
		Riso.draw_piece(self, at + Vector2(0, -2), 26.0, Riso.RED, {"hat": "hood", "pack": true})


func _draw_labels() -> void:
	for r in world.regions:
		if r.name_key != "":
			_label(Txt.t(r.name_key), r.pos + Vector2(0, 30), pal(r.s), 18)
	for l in world.landmarks:
		if l.name_key != "":
			_label(Txt.t(l.name_key), l.pos + Vector2(0, 40), pal(world.strangeness_at(l.pos)), 16)


func _label(text: String, p: Vector2, c: Dictionary, size: int) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := p - Vector2(w / 2, 0)
	draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, c.light)
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c.dark)


## Folk border built from repeating stamps (R9). Colors drift with strangeness along each edge.
func _draw_border() -> void:
	var outer := Rect2(-Vector2.ONE * BORDER, WorldMap.SIZE + Vector2.ONE * BORDER * 2)
	var home := pal(0.0)
	# paper band, then stamps, then a thin keyline at the map edge
	for side in 4:
		var r: Rect2
		match side:
			0: r = Rect2(outer.position, Vector2(outer.size.x, BORDER))
			1: r = Rect2(Vector2(outer.position.x, WorldMap.SIZE.y), Vector2(outer.size.x, BORDER))
			2: r = Rect2(outer.position, Vector2(BORDER, outer.size.y))
			3: r = Rect2(Vector2(WorldMap.SIZE.x, outer.position.y), Vector2(BORDER, outer.size.y))
		draw_rect(r, home.light)
	var step := 44.0
	var x := step * 0.5
	var n := 0
	while x < WorldMap.SIZE.x:
		var c := pal(x / WorldMap.SIZE.x)
		_border_stamp(Vector2(x, -BORDER * 0.5), n, c)
		_border_stamp(Vector2(x, WorldMap.SIZE.y + BORDER * 0.5), n + 1, c)
		x += step
		n += 1
	var y := step * 0.5
	n = 0
	while y < WorldMap.SIZE.y:
		_border_stamp(Vector2(-BORDER * 0.5, y), n, pal(0.0))
		_border_stamp(Vector2(WorldMap.SIZE.x + BORDER * 0.5, y), n, pal(1.0))
		y += step
		n += 1
	for corner in [outer.position + Vector2.ONE * BORDER * 0.5, Vector2(outer.end.x - BORDER * 0.5, outer.position.y + BORDER * 0.5),
			Vector2(outer.position.x + BORDER * 0.5, outer.end.y - BORDER * 0.5), outer.end - Vector2.ONE * BORDER * 0.5]:
		var c := pal(0.0 if corner.x < 0 else 1.0)
		draw_rect(Rect2(corner - Vector2.ONE * 16, Vector2.ONE * 32), c.dark)
		Riso.draw_stamp_star(self, corner, 12.0, c.accent)
	draw_rect(Rect2(Vector2.ZERO, WorldMap.SIZE), home.dark, false, 3.0)
	draw_rect(outer, home.dark, false, 3.0)


func _border_stamp(p: Vector2, n: int, c: Dictionary) -> void:
	match n % 3:
		0: Riso.draw_stamp_star(self, p, 11.0, c.accent.lerp(c.dark, 0.15))
		1:
			Riso.draw_pine(self, p.x, p.y + 10.0, 22.0, c.mid.lerp(c.dark, 0.3), c.light)
		2:
			draw_circle(p, 8.0, c.dark)
			draw_circle(p + Vector2(4, -3), 7.0, c.light)

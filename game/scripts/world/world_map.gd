class_name WorldMap
extends RefCounted
## The world map's layout: regions, the route the Lodestone records, the Wall and landmarks.
## Pure data and math so tests can run it headless. Data lives in data/world/*.csv.
## Map units are pixels of a 1920x1080 sheet. The trail's leagues map onto the route by the d column.
##
## Region borders are a warped Voronoi: each point belongs to the region whose seed is nearest
## after a smooth sine warp, and never crosses the Wall (regions with s >= 0.5 sit east of it).
## world_ground.gdshader runs the same math per pixel, so keep the two in step.

const SIZE := Vector2(1920, 1080)
const MAX_REGIONS := 24
const WARP_F := Vector3(0.006, 0.013, 0.045)  ## big, medium and small wobble frequencies
const WARP_A := Vector2(55.0, 8.0)  ## big and small wobble amplitude

var regions: Array[Dictionary] = []  # {"id", "kind", "s", "pos", "weight", "name_key", "east"}
var route: Array[Dictionary] = []  # {"pos": Vector2, "d": float}, sorted by d
var wall: PackedVector2Array = []  # sorted by y, top to bottom
var landmarks: Array[Dictionary] = []  # {"id", "kind", "pos", "name_key"}
var phase := Vector4.ZERO  ## warp phases, a pure function of seed


static func load_default(seed_value := 1) -> WorldMap:
	var w := WorldMap.new()
	w.setup(CsvTable.load_rows("res://data/world/regions.csv"),
		CsvTable.load_rows("res://data/world/lines.csv"),
		CsvTable.load_rows("res://data/world/landmarks.csv"), seed_value)
	return w


func setup(region_rows: Array[Dictionary], line_rows: Array[Dictionary], landmark_rows: Array[Dictionary], seed_value: int) -> void:
	for row in region_rows:
		var s := float(row.s)
		regions.append({"id": row.id, "kind": row.kind, "s": s, "pos": Vector2(float(row.x), float(row.y)),
			"weight": float(row.weight), "name_key": row.name_key, "east": s >= 0.5})
	for row in line_rows:
		var p := Vector2(float(row.x), float(row.y))
		if row.line == "route":
			route.append({"pos": p, "d": float(row.d)})
		elif row.line == "wall":
			wall.append(p)
	route.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.d < b.d)
	for row in landmark_rows:
		landmarks.append({"id": row.id, "kind": row.kind, "pos": Vector2(float(row.x), float(row.y)), "name_key": row.name_key})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	phase = Vector4(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)


func landmark(id: String) -> Dictionary:
	for l in landmarks:
		if l.id == id:
			return l
	return {}


func start_pos() -> Vector2:
	return route[0].pos


# --- route -----------------------------------------------------------------

## Where the party stands after walking d leagues.
func route_point(d: float) -> Vector2:
	if d <= route[0].d:
		return route[0].pos
	for i in range(1, route.size()):
		var b: Dictionary = route[i]
		if d <= b.d:
			var a: Dictionary = route[i - 1]
			return a.pos.lerp(b.pos, (d - a.d) / (b.d - a.d))
	return route[-1].pos


## Route polyline from from_d to to_d leagues, one point per step leagues plus the corners.
func route_points(from_d: float, to_d: float, step := 2.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var d := from_d
	while d < to_d:
		pts.append(route_point(d))
		d += step
	pts.append(route_point(to_d))
	return pts


func route_length() -> float:
	return route[-1].d


# --- the Wall --------------------------------------------------------------

## The Wall's x at height y.
func wall_x(y: float) -> float:
	if y <= wall[0].y:
		return wall[0].x
	for i in range(1, wall.size()):
		if y <= wall[i].y:
			return lerpf(wall[i - 1].x, wall[i].x, (y - wall[i - 1].y) / (wall[i].y - wall[i - 1].y))
	return wall[-1].x


func is_east(p: Vector2) -> bool:
	return p.x > wall_x(p.y)


# --- regions ---------------------------------------------------------------

func warp(p: Vector2) -> Vector2:
	var big := Vector2(
		sin(p.y * WARP_F.x + phase.x) + 0.5 * sin((p.x + p.y) * WARP_F.y + phase.y),
		sin(p.x * WARP_F.x + phase.z) + 0.5 * sin((p.x - p.y) * WARP_F.y + phase.w))
	var small := Vector2(sin(p.y * WARP_F.z + phase.y), sin(p.x * WARP_F.z + phase.x))
	return p + big * WARP_A.x + small * WARP_A.y


## {"index": nearest region, "margin": how far (in map units) the point sits inside its border}.
func region_hit(p: Vector2) -> Dictionary:
	var wp := warp(p)
	var east := is_east(p)
	var best := INF
	var second := INF
	var idx := 0
	for i in regions.size():
		var r: Dictionary = regions[i]
		var cost: float = wp.distance_to(r.pos) - r.weight
		if r.east != east:
			cost += 100000.0
		if cost < best:
			second = best
			best = cost
			idx = i
		elif cost < second:
			second = cost
	# the Wall is a border too
	var to_wall := absf(p.x - wall_x(p.y))
	return {"index": idx, "margin": minf((second - best) * 0.5, to_wall)}


func region_at(p: Vector2) -> Dictionary:
	return regions[region_hit(p).index]


func strangeness_at(p: Vector2) -> float:
	return region_at(p).s

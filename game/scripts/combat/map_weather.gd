class_name MapWeather
extends Node2D
## Weather over a map ([USER] 2026-10-30, ambience: "some snow falling effects... a sprinkle of attention to
## detail and some motion to give maps life"): sparse slow snow, or a few fall leaves drifting down, drawn in
## screen space over the board and under the frame. What falls comes from the map's look (MapLook.weather,
## data/looks.csv). Seeded, so the same map always starts the same (style bible: pure function of seed).

const SNOW_COUNT := 110  ## flakes over the whole view: still sparse
const LEAF_COUNT := 16  ## leaves: fewer, bigger, slower to land
const SNOW := Color(0.97, 0.98, 1.0, 0.85)
const SNOW_SHADOW := Color(0.4, 0.48, 0.66, 0.6)
const LEAVES := [Color("#d9822b"), Color("#e8b33a"), Color("#b9452f"), Color("#c96a2a")]  ## the fall village's warm range

var kind := ""  ## "snow", "leaves" or "" (nothing)
var area := Rect2()  ## the screen area it falls over
var mask: Array = []  ## [Vector3(x, y, radius)]: when set, only inside these circles (the world map's snowy part)
var flakes: Array[Dictionary] = []
var _time := 0.0


func _init() -> void:
	top_level = true  # screen space, whatever the scene moves
	z_index = 5


## Live in the world instead: a child of the board, falling over `world` (board pixels) so it scrolls with the map
## and stays put when the camera moves ([USER] 2026-10-30: leaves "locked to the map not to the screen"). The count
## is the screen count scaled by how much bigger the world is than `screen`, so it looks as dense as before.
func fit_world(weather: String, world: Rect2, screen: Rect2, seed_value: int) -> void:
	top_level = false
	setup(weather, world, seed_value, clampf(world.get_area() / maxf(screen.get_area(), 1.0), 1.0, 12.0))


## Fill the area with this weather, seeded by the map so it's the same every visit.
func setup(weather: String, view: Rect2, seed_value: int, density := 1.0) -> void:
	kind = weather
	area = view
	flakes.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := roundi((SNOW_COUNT if kind == "snow" else (LEAF_COUNT if kind == "leaves" else 0)) * density)
	for i in n:
		flakes.append(make_flake(rng, kind, area, true))
	visible = n > 0


## One flake or leaf: where it is, how it falls and drifts. `anywhere`: placed through the area, not at its top.
static func make_flake(rng: RandomNumberGenerator, weather: String, view: Rect2, anywhere := false) -> Dictionary:
	var leaf := weather == "leaves"
	var y := rng.randf_range(view.position.y, view.end.y) if anywhere else view.position.y - 10.0
	return {
		"pos": Vector2(rng.randf_range(view.position.x, view.end.x), y),
		"fall": rng.randf_range(14.0, 26.0) if leaf else rng.randf_range(16.0, 34.0),  # px a second: slow
		"drift": rng.randf_range(10.0, 22.0) if leaf else rng.randf_range(4.0, 12.0),  # side to side
		"wind": rng.randf_range(4.0, 10.0) if leaf else rng.randf_range(1.0, 5.0),  # a steady push to the right
		"phase": rng.randf_range(0.0, TAU),
		"speed": rng.randf_range(0.6, 1.3),
		"size": rng.randf_range(4.0, 7.0) if leaf else rng.randf_range(1.8, 3.2),
		"spin": rng.randf_range(-1.5, 1.5),
		"col": LEAVES[rng.randi() % LEAVES.size()] if leaf else SNOW,
	}


## Move one flake on by dt seconds at time t; past the bottom it starts again at the top.
static func step_flake(f: Dictionary, dt: float, t: float, view: Rect2) -> void:
	var p: Vector2 = f.pos
	p.y += float(f.fall) * dt
	p.x += (float(f.wind) + cos(t * float(f.speed) + float(f.phase)) * float(f.drift)) * dt
	if p.y > view.end.y + 10.0:
		p.y = view.position.y - 10.0
	if p.x > view.end.x + 10.0:
		p.x = view.position.x - 10.0
	elif p.x < view.position.x - 10.0:
		p.x = view.end.x + 10.0
	f.pos = p


func _process(delta: float) -> void:
	if flakes.is_empty():
		return
	_time += delta
	for f in flakes:
		step_flake(f, delta, _time, area)
	queue_redraw()


func _draw() -> void:
	for f in flakes:
		var p: Vector2 = f.pos
		if not mask.is_empty() and not mask.any(func(m: Vector3) -> bool: return p.distance_to(Vector2(m.x, m.y)) < m.z):
			continue
		if kind == "snow":  # a faint cool shadow so a flake reads over snowy ground as well as the dark wood
			draw_circle(p + Vector2(0.7, 0.9), float(f.size), SNOW_SHADOW)
			draw_circle(p, float(f.size), f.col)
		else:  # a leaf: a small pointed oval, turning as it falls
			var a := _time * float(f.spin) + float(f.phase)
			var s := float(f.size)
			var flat := 0.45 + 0.35 * absf(sin(_time * float(f.speed) * 2.0 + float(f.phase)))  # tumbling
			var pts := PackedVector2Array()
			for k in 8:
				var u := TAU * k / 8.0
				pts.append(p + Vector2(cos(u) * s, sin(u) * s * flat * (1.0 - 0.3 * absf(cos(u)))).rotated(a))
			draw_colored_polygon(pts, f.col)

class_name MapPlot
extends RefCounted
## Road-fight plots ([USER] 2026-11-01, battle-maps plan, docs/design/battle-maps-research.md: "clean up the UI to make
## Plots and pre-seed it with 5-6 that seem good to you and that I can tinker with later"). A plot is the hand-drawn
## skeleton of a fight map, a flat sketch in two layers of characters, one row per map row:
##   levels  "." outside the map, "0" to "3" the terrace each cell stands on (low to high)
##   marks   " " plain ground, "d" road, "w" river water, "b" bridge over the water (a straight run, banks at both ends),
##           "s" stairs (a climb between two terraces; a straight run of them is one flight), "r" rock outcrop, "t" woods
## plus "draft" (true: road fights skip it while it is being drawn), "river" (its job: "flank" runs along one side, "crossing" cuts between the starts and has the one bridge, "" none)
## and a designer "note". The party starts on the low-x side, the foes on the high-x side (CombatGrid.deploy_cells).
## `build` turns a plot and a seed into an ordinary map: the sketch fixes the outline, terraces, road, river and climbs;
## the seed varies what the plan lets vary (mirror top to bottom, a one-level lift, small ledges, tree clumps). Files live
## in data/plots/<region>/<id>.json.

const DIR := "res://data/plots/"
const T := CombatGrid.T
const LEVEL_STEP := 2  ## heights between terraces: every terrace edge is a cliff a stair climbs
const LEDGE_SHARE := 0.5  ## noise above this lifts a quiet cell one level: small ledges inside a terrace
const WOODS_SHARE := 0.38  ## noise above this turns plain ground into trees (on top of the plot's own "t")


## Every plot of a region, sorted by id. A plot with "draft": true is still being drawn: the plot maker lists it, road
## fights (with_drafts false) skip it.
static func list(region: String, with_drafts := true) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DIR + region + "/"
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var files := Array(DirAccess.get_files_at(dir))
	files.sort()
	for f: String in files:
		if f.ends_with(".json"):
			var p := load_file(dir + f)
			if not p.is_empty() and (with_drafts or not bool(p.get("draft", false))):
				out.append(p)
	return out


static func load_file(path: String) -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary and d.has("levels") else {}


static func size_of(plot: Dictionary) -> Vector2i:
	var rows: Array = plot.get("levels", [])
	return Vector2i(String(rows[0]).length() if not rows.is_empty() else 0, rows.size())


static func level_at(plot: Dictionary, c: Vector2i) -> String:
	var rows: Array = plot.levels
	if c.y < 0 or c.y >= rows.size() or c.x < 0 or c.x >= String(rows[c.y]).length():
		return "."
	return String(rows[c.y])[c.x]


static func mark_at(plot: Dictionary, c: Vector2i) -> String:
	var rows: Array = plot.get("marks", [])
	if c.y < 0 or c.y >= rows.size() or c.x < 0 or c.x >= String(rows[c.y]).length():
		return " "
	return String(rows[c.y])[c.x]


## The map a plot makes for this seed. join false skips MapOps.link and the seal (to see what a plot leaves cut off:
## a piece link has to join gets stair decks, which read as stray bridges).
static func build(plot: Dictionary, seed_value: int, look_id := "forest", join := true) -> CombatGrid:
	var size := size_of(plot)
	var g := CombatGrid.flat(size.x, size.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var flip := rng.randf() < 0.5  # top to bottom: the starts stay on their sides
	if plot.has("flip"):  # a plot can pin the side it faces the camera with
		flip = bool(plot.flip)
	var lift := rng.randi_range(0, 1)
	var ledge := FastNoiseLite.new()
	ledge.seed = seed_value + 17
	ledge.frequency = rng.randf_range(0.1, 0.18)  # low: ledges come in patches, not lone pillars
	var ledge_share := LEDGE_SHARE + rng.randf_range(-0.1, 0.1)  # some seeds are rougher than others
	var woods := FastNoiseLite.new()
	woods.seed = seed_value + 41
	woods.frequency = rng.randf_range(0.12, 0.22)
	var woods_share := WOODS_SHARE + rng.randf_range(-0.1, 0.12)
	var src := func(c: Vector2i) -> Vector2i: return Vector2i(c.x, size.y - 1 - c.y) if flip else c
	var stairs: Array[Vector2i] = []
	var bridges: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			var c := Vector2i(x, y)
			var s: Vector2i = src.call(c)
			var lv := level_at(plot, s)
			if lv == ".":
				g.set_terrain(c, T.VOID)
				g.set_height(c, 0)
				continue
			var ground := 1 + int(lv) * LEVEL_STEP + lift
			g.set_height(c, ground)
			g.set_terrain(c, T.GRASS)
			match mark_at(plot, s):
				"d":
					g.set_terrain(c, T.ROAD)
				"w", "b":
					g.set_terrain(c, T.WATER)
					g.set_height(c, ground - 1)
					if mark_at(plot, s) == "b":
						bridges.append(c)
				"r":
					g.set_terrain(c, T.ROCK)
					g.set_height(c, ground + 1)  # a low outcrop: cover, not a pillar
				"s":
					stairs.append(c)
				"t":
					g.set_terrain(c, T.FOREST)
				_:
					if _quiet(plot, s) and ledge.get_noise_2d(x, y) > ledge_share and x >= CombatGrid.DEPLOY_COLS and x < size.x - CombatGrid.DEPLOY_COLS:
						g.set_height(c, ground + 1)
					elif woods.get_noise_2d(x, y) > woods_share and x >= CombatGrid.DEPLOY_COLS and x < size.x - CombatGrid.DEPLOY_COLS:
						g.set_terrain(c, T.FOREST)
	_lay_stairs(g, stairs)
	_lay_bridges(g, bridges)
	MapOps.flatten_dead_stairs(g)
	if join:
		MapOps.link(g, seed_value + 5, 1, false)
		MapOps.seal_unreachable(g)
	g.look = {"id": look_id}
	return g


## A plain cell whose four neighbours are plain cells on the same terrace: a ledge there changes nothing the plot drew.
static func _quiet(plot: Dictionary, c: Vector2i) -> bool:
	var lv := level_at(plot, c)
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if level_at(plot, c + d) != lv or mark_at(plot, c + d) != " ":
			return false
	return true


## A lone "s" cell is a stair between the ground on its two sides; a straight run of two or more is one flight from
## the cell before it to the cell after it, stepping evenly, so a climb over two terraces is drawn as two stairs.
static func _lay_stairs(g: CombatGrid, cells: Array[Vector2i]) -> void:
	var left := {}
	for c in cells:
		left[c] = true
	for c in cells:
		if not left.has(c):
			continue
		var laid := false
		for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			if not left.has(c + d) and not left.has(c - d):
				continue
			var a := c
			while left.has(a - d):
				a -= d
			var b := a
			while left.has(b + d):
				b += d
			var q := a
			while true:
				left.erase(q)
				if q == b:
					break
				q += d
			var lo := a - d
			var hi := b + d
			if g.height_at(lo) > g.height_at(hi):
				var t := lo
				lo = hi
				hi = t
			MapOps.flight(g, lo, hi)
			laid = true
			break
		if not laid:
			left.erase(c)
			if not MapOps.stairs(g, c):
				g.set_terrain(c, T.GRASS)


## Each straight run of "b" cells becomes one bridge between the dry cells at its two ends.
static func _lay_bridges(g: CombatGrid, cells: Array[Vector2i]) -> void:
	var left := {}
	for c in cells:
		left[c] = true
	for c in cells:
		if not left.has(c):
			continue
		for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			if not left.has(c + d) and not left.has(c - d):
				continue
			var a := c
			while left.has(a - d):
				a -= d
			var b := a
			while left.has(b + d):
				b += d
			var q := a
			while true:
				left.erase(q)
				if q == b:
					break
				q += d
			MapOps.bridge_span(g, a - d, b + d)
			break
		left.erase(c)  # a lone cell: its run is across the water both ways; try along x then y
		if not g.has_deck(c):
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				if g.solid(c - d) and g.solid(c + d) and g.terrain_at(c - d) != T.WATER and g.terrain_at(c + d) != T.WATER:
					MapOps.bridge_span(g, c - d, c + d)
					break


## What is wrong with a plot itself (empty when it is fine): its layers' sizes match, the road joins the two sides, a
## crossing river has its bridge and a flank river has none.
static func problems(plot: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var size := size_of(plot)
	if size.x <= 0 or size.y <= 0:
		return ["no levels"]
	for key in ["levels", "marks"]:
		for row in plot.get(key, []):
			if String(row).length() != size.x:
				out.append("%s rows are not all %d wide" % [key, size.x])
				break
	var road_l := false
	var road_r := false
	var bridge := false
	for y in size.y:
		for x in size.x:
			var m := mark_at(plot, Vector2i(x, y))
			if m == "d" and x < CombatGrid.DEPLOY_COLS + 2:
				road_l = true
			if m == "d" and x >= size.x - CombatGrid.DEPLOY_COLS - 2:
				road_r = true
			bridge = bridge or m == "b"
	if not (road_l and road_r):
		out.append("the road does not run from one start's side to the other")
	if String(plot.get("river", "")) == "crossing" and not bridge:
		out.append("a crossing river needs its bridge")
	if String(plot.get("river", "")) == "flank" and bridge:
		out.append("a flank river has no bridge")
	return out

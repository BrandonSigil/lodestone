class_name MapQA
extends RefCounted
## Machine QA for a map (pipeline stage 4, [USER] 2026-11-01 "build the QA panel in the map maker first"): the checks
## every map passes before a picture of it reaches Brandon. Pure functions on a CombatGrid and the rest of the map
## file, so the maker's QA panel, tests and command line tools all run the same rules.
##   reach    every walkable cell can be walked to from the start; every thing can be used; every foe reached
##   box      the box score: the outline is not a square box and the heights are not flat (tools/map_shape.py)
##   stairs   no stair to nowhere: every stair run joins two levels, and none stops short of the ledge above it
##   scale    props make sense against the hero: doors taller than him, buildings big enough (prop_scale_check.py)
##   deploy   room to start every fight: the party fits round the leader where it meets each group
##   sight    hidden spots: things, group spots and the start a tree, tall prop or cliff in front hides from the camera
## Thresholds: data/map_qa.csv. Prop sizes: data/prop_scale.csv. How it shows in the maker: docs/systems/map-qa.md.
## Each check: {"id", "name", "level": "ok" | "warn" | "fail", "summary", "stats": {}, "cells": [painted cells],
## "problems": [{"cell": Vector2i, "text"}]}.

const T := CombatGrid.T
const QA_CSV := "res://data/map_qa.csv"
const SCALE_CSV := "res://data/prop_scale.csv"
const ORDER := ["reach", "box", "stairs", "scale", "deploy", "sight"]
const NAMES := {"reach": "Reachability", "box": "Box score", "stairs": "Stairs to nowhere", "scale": "Scale against the hero",
	"deploy": "Deploy room", "sight": "Hidden spots"}
const N4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const PROBLEM_MAX := 40  ## rows listed per check; every problem cell is still painted

static var _cfg := {}
static var _scale := {}


## A setting from data/map_qa.csv.
static func cfg(key: String) -> float:
	if _cfg.is_empty():
		for r in CsvTable.load_rows(QA_CSV):
			_cfg[String(r.key)] = float(r.value)
	return float(_cfg.get(key, 0.0))


static func scale_table() -> Dictionary:
	if _scale.is_empty():
		for r in CsvTable.load_rows(SCALE_CSV):
			_scale[String(r.sprite)] = {"door": float(r.door), "headroom": float(r.headroom), "aspect": float(r.aspect)}
	return _scale


## Every check on a map. `kind` is "battle" (data: party, enemies) or "explore" (data: start, groups, things).
static func run(grid: CombatGrid, kind: String, data: Dictionary) -> Array[Dictionary]:
	var g := _opened(grid, kind, data)
	var reached := _reached(g, kind, data)
	var out: Array[Dictionary] = []
	out.append(check_reach(g, kind, data, reached))
	out.append(check_box(g))
	out.append(check_stairs(g, kind))
	out.append(check_scale(g))
	out.append(check_deploy(g, kind, data, reached))
	out.append(check_sight(g, kind, data, reached))
	for c in out:  # paint and list ground cells (a deck place is painted on its cell)
		var cells: Array[Vector2i] = []
		var seen := {}
		for q: Vector2i in c.cells:
			var gq := CombatGrid.ground(q)
			if not seen.has(gq):
				seen[gq] = true
				cells.append(gq)
		c.cells = cells
		for p: Dictionary in c.problems:
			p.cell = CombatGrid.ground(p.cell)
	return out


## The worst level of a run: "fail" if any check fails, else "warn" if any warns, else "ok".
static func worst(checks: Array[Dictionary]) -> String:
	var w := "ok"
	for c in checks:
		if c.level == "fail":
			return "fail"
		if c.level == "warn":
			w = "warn"
	return w


static func _check(id: String) -> Dictionary:
	return {"id": id, "name": NAMES[id], "level": "ok", "summary": "", "stats": {}, "cells": [] as Array[Vector2i],
		"problems": [] as Array[Dictionary]}


static func _problem(c: Dictionary, cell: Vector2i, text: String) -> void:
	if (c.problems as Array).size() < PROBLEM_MAX:
		c.problems.append({"cell": cell, "text": text})


static func _cell(v: Variant) -> Vector2i:
	if v is Vector2i:
		return v
	if v is Dictionary:
		return Vector2i(int(v.x), int(v.y))
	var a: Array = v
	return Vector2i(int(a[0]), int(a[1]))


## The grid with every door and rubble open (its floor letter), as the party finds it once it has opened them all.
static func _opened(grid: CombatGrid, kind: String, data: Dictionary) -> CombatGrid:
	if kind != "explore":
		return grid
	var g := CombatGrid.from_dict(grid.to_dict())
	var letters := {}
	for t: int in CombatGrid.LETTERS:
		letters[CombatGrid.LETTERS[t]] = t
	for t: Dictionary in data.get("things", []):
		if String(t.get("kind", "")) in ["door", "rubble"]:
			var c := _cell(t.cell)
			if g.in_bounds(c):
				g.set_terrain(c, int(letters.get(String(t.get("floor", "s")), T.STONE)))
	return g


## Where walking starts: the explore start's leader cell, or every party piece on a battle map.
static func _from(kind: String, data: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if kind == "explore":
		var st: Array = data.get("start", [])
		if not st.is_empty():
			out.append(_cell(st[0]))
	else:
		for e in data.get("party", []):
			out.append(_cell(e))
	return out


## Can a piece stand on this cell outside a fight (explore) or in one (battle)?
static func _stand(g: CombatGrid, kind: String, c: Vector2i) -> bool:
	return g.walkable(c) if kind == "explore" else g.passable(c)


## Every place reachable from the start with a plain member's Jump: explore walks like the party (eight ways,
## ExploreRules.reach), a battle map like a piece in a fight (four ways, any passable cell).
static func _reached(g: CombatGrid, kind: String, data: Dictionary) -> Dictionary:
	var jump := int(cfg("jump"))
	var from := _from(kind, data)
	if kind == "explore":
		return ExploreRules.reach(g, from, jump)
	var seen := {}
	var todo: Array[Vector2i] = []
	for c in from:
		if g.in_bounds(c) and not seen.has(c):
			seen[c] = true
			todo.append(c)
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d in N4:
			for n in g.places_next(c, d):
				if not seen.has(n) and g.passable(n) and g.can_step(c, n, jump):
					seen[n] = true
					todo.append(n)
	return seen


# --- hidden spots ([USER] 2026-11-01 pm-occlusion: "a map rule to see if anything is obscured and if so we handle it
# better via the map") ---------------------------------------------------------------------------------------------

## The two grid steps that go one tile toward the camera on screen, for the map's view (CombatBoard._rot): the cell
## straight in front is their sum.
static func camera_steps(view: int) -> Array[Vector2i]:
	match view % 4:
		1:
			return [Vector2i(0, -1), Vector2i(1, 0)]
		2:
			return [Vector2i(-1, 0), Vector2i(0, -1)]
		3:
			return [Vector2i(0, 1), Vector2i(-1, 0)]
	return [Vector2i(1, 0), Vector2i(0, 1)]


## Does cell c stand in front of a spot at height h and hide it: a tree (forest ground), a tall see-through prop (a
## house, a wall, a tree prop), or ground two levels or more above the spot (a cliff face)?
static func blocks_view(g: CombatGrid, c: Vector2i, h: int) -> bool:
	if not g.in_bounds(c):
		return false
	if g.terrain_at(c) == T.FOREST or g.height_at(c) - h >= int(cfg("sight_cliff")):
		return true
	var p := g.prop_at(c)
	return not p.is_empty() and not bool(p.get("walk", false)) and not bool(p.get("arch", false)) \
		and (float(p.tall) <= 0.0 or float(p.tall) >= float(cfg("sight_tall"))) and CombatBoard.see_through(p)


## The camera can't see spot c: the tile straight in front of it hides it, or both tiles beside that one do.
static func hidden_spot(g: CombatGrid, c: Vector2i, view: int) -> bool:
	var st := camera_steps(view)
	var h := g.height_at(c)
	return blocks_view(g, c + st[0] + st[1], h) or (blocks_view(g, c + st[0], h) and blocks_view(g, c + st[1], h))


## Things (not doorways, ways out or hidden finds), every group's spots and the start, each hidden spot a warning; the
## share of walkable cells the camera can't see goes in the stats. Fix by moving the spot into the open on the map.
static func check_sight(g: CombatGrid, kind: String, data: Dictionary, reached: Dictionary) -> Dictionary:
	var c := _check("sight")
	if kind != "explore":
		c.summary = "battle maps: not checked"
		return c
	var view := int(data.get("view", 0))
	var spots: Array = []  # [cell, what]
	for t: Dictionary in data.get("things", []):
		if not String(t.get("kind", "chest")) in SIGHT_SKIP:
			spots.append([_cell(t.cell), "%s (%s)" % [String(t.get("id", "thing")), String(t.get("kind", "chest"))]])
	for gr: Dictionary in data.get("groups", []):
		for u: Dictionary in gr.get("units", []):
			spots.append([_cell(u.cell), "%s: %s" % [String(gr.get("id", "group")), String(u.get("char", u.get("id", "unit")))]])
	for s0 in _from(kind, data):
		spots.append([s0, "the start"])
	var bad := 0
	for sp in spots:
		if hidden_spot(g, sp[0], view):
			bad += 1
			c.cells.append(sp[0])
			_problem(c, sp[0], "%s is hidden from the camera: move it into the open" % sp[1])
	var walk := 0
	var unseen := 0
	for q: Vector2i in reached:
		if CombatGrid.ground(q) != q:
			continue  # a deck place: the deck stands over whatever is in front
		walk += 1
		if hidden_spot(g, q, view):
			unseen += 1
	c.stats = {"spots": spots.size(), "hidden_spots": bad, "walkable": walk, "hidden_walkable": unseen}
	c.level = "warn" if bad > 0 else "ok"
	c.summary = "%d of %d spots hidden; %d%% of walkable ground out of sight" % [bad, spots.size(), roundi(100.0 * unseen / maxf(1.0, walk))]
	return c


const SIGHT_SKIP := ["enter", "door", "rubble", "window", "hidden", "exit"]  ## things that sit in walls or are meant to be found


# --- reachability --------------------------------------------------------------------

static func check_reach(g: CombatGrid, kind: String, data: Dictionary, reached: Dictionary) -> Dictionary:
	var c := _check("reach")
	var from := _from(kind, data)
	if from.is_empty():
		c.level = "fail"
		c.summary = "no party start: place one (Party tool)"
		return c
	var lost: Array[Vector2i] = []
	var total := 0
	for y in g.h:
		for x in g.w:
			for q in g.places_at(Vector2i(x, y)):
				if not _stand(g, kind, q) or g.perch(q):
					continue
				total += 1
				if not reached.has(q):
					lost.append(q)
	# One row per cut-off patch, biggest first.
	var patches := _patches(lost)
	for p in patches:
		var cells: Array = p
		_problem(c, cells[0], "%d cell%s nobody can walk to" % [cells.size(), "" if cells.size() == 1 else "s"])
	c.cells.append_array(lost)
	var bad_things := 0
	if kind == "explore":
		for t: Dictionary in data.get("things", []):
			var tc := _cell(t.cell)
			if not _usable(g, tc, reached):
				bad_things += 1
				c.cells.append(tc)
				_problem(c, tc, "%s (%s) can't be reached to use" % [String(t.get("id", "?")), String(t.get("kind", ""))])
	var foes := 0
	for u in _foe_cells(kind, data):
		if not _near_reached(g, u, reached):
			foes += 1
			c.cells.append(u)
			_problem(c, u, "a foe stands where the party can't get to it")
	c.stats = {"walkable": total, "lost": lost.size(), "patches": patches.size(), "things": bad_things, "foes": foes}
	if lost.is_empty() and bad_things == 0 and foes == 0:
		c.summary = "all %d walkable cells reached" % total
	else:
		c.level = "fail" if bad_things > 0 or lost.size() > 0 else "warn"
		var bits: PackedStringArray = []
		if lost.size() > 0:
			bits.append("%d cells cut off in %d patch%s" % [lost.size(), patches.size(), "" if patches.size() == 1 else "es"])
		if bad_things > 0:
			bits.append("%d thing%s out of reach" % [bad_things, "" if bad_things == 1 else "s"])
		if foes > 0:
			bits.append("%d foe%s out of reach" % [foes, "" if foes == 1 else "s"])
		c.summary = ", ".join(bits)
	return c


## Can someone standing on reached ground use a thing at this cell (from next to it, or on it)?
static func _usable(g: CombatGrid, tc: Vector2i, reached: Dictionary) -> bool:
	if reached.has(tc):
		return true
	for d in ExploreRules.STEPS:
		for p in g.places_at(tc + d):
			if reached.has(p) and ExploreRules.can_use_from(g, p, tc):
				return true
	return false


## A foe is reached when the party can stand on its cell or step next to it (a fight can reach it).
static func _near_reached(g: CombatGrid, u: Vector2i, reached: Dictionary) -> bool:
	if reached.has(u):
		return true
	for d in N4:
		for p in g.places_at(u + d):
			if reached.has(p) and absi(g.height_at(p) - g.height_at(u)) <= int(cfg("jump")) + CombatGrid.STAIRS_CLIMB:
				return true
	return false


static func _foe_cells(kind: String, data: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if kind == "explore":
		for gr: Dictionary in data.get("groups", []):
			for u: Dictionary in gr.get("units", []):
				out.append(_cell(u.cell))
	else:
		for e in data.get("enemies", []):
			out.append(_cell(e))
	return out


## Cells split into 4-connected patches (by ground cell), biggest first.
static func _patches(cells: Array[Vector2i]) -> Array:
	var left := {}
	for q in cells:
		left[CombatGrid.ground(q)] = true
	var out: Array = []
	for q in cells:
		var s := CombatGrid.ground(q)
		if not left.has(s):
			continue
		var patch: Array[Vector2i] = [s]
		left.erase(s)
		var i := 0
		while i < patch.size():
			for d in N4:
				var n: Vector2i = patch[i] + d
				if left.has(n):
					left.erase(n)
					patch.append(n)
			i += 1
		out.append(patch)
	out.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
	return out


# --- box score -------------------------------------------------------------------------

## The box score of tools/map_shape.py, on the walkable footprint (not rock, void or water; decks count).
static func box_stats(g: CombatGrid) -> Dictionary:
	var walk := {}
	for y in g.h:
		for x in g.w:
			var c := Vector2i(x, y)
			if not g.terrain_at(c) in [T.ROCK, T.VOID, T.WATER] or g.has_deck(c):
				walk[c] = true
	if walk.is_empty():
		return {}
	var x0 := g.w
	var y0 := g.h
	var x1 := -1
	var y1 := -1
	for c: Vector2i in walk:
		x0 = mini(x0, c.x)
		y0 = mini(y0, c.y)
		x1 = maxi(x1, c.x)
		y1 = maxi(y1, c.y)
	var bw := x1 - x0 + 1
	var bh := y1 - y0 + 1
	var edge := 0
	for c: Vector2i in walk:
		for d in N4:
			if not walk.has(c + d):
				edge += 1
				break
	var corners := 0
	for y in range(-1, g.h):
		for x in range(-1, g.w):
			var n := 0
			for dx in 2:
				for dy in 2:
					if walk.has(Vector2i(x + dx, y + dy)):
						n += 1
			if n == 1 or n == 3:
				corners += 1
	var qw := maxi(1, bw / 4)
	var qh := maxi(1, bh / 4)
	var bays := 0.0
	var full: Array[Vector2i] = []  # footprint cells in the corner quarters: what a box fills
	for o: Vector2i in [Vector2i(x0, y0), Vector2i(x0 + bw - qw, y0), Vector2i(x0, y0 + bh - qh), Vector2i(x0 + bw - qw, y0 + bh - qh)]:
		var n := 0
		for y in range(o.y, o.y + qh):
			for x in range(o.x, o.x + qw):
				if walk.has(Vector2i(x, y)):
					n += 1
					full.append(Vector2i(x, y))
		bays += 1.0 - float(n) / (qw * qh)
	var levels := {}
	for c: Vector2i in walk:
		levels[g.height_at(c)] = true
	var runs := _stair_runs(g).size()
	return {"fill": float(walk.size()) / (bw * bh), "edge": edge / (2.0 * (bw + bh)), "corners": 100.0 * corners / walk.size(),
		"bays": bays / 4.0, "levels": levels.size(), "climbs": runs, "box": Rect2i(x0, y0, bw, bh), "corner_cells": full}


static func check_box(g: CombatGrid) -> Dictionary:
	var c := _check("box")
	var s := box_stats(g)
	if s.is_empty():
		c.level = "fail"
		c.summary = "no walkable ground"
		return c
	var cells := roundi(s.fill * s.box.size.x * s.box.size.y)
	if cells < int(cfg("box_min_cells")):
		c.summary = "a room (%d cells): the box score is for bigger maps" % cells
		return c
	c.stats = {"fill": snappedf(s.fill, 0.01), "edge": snappedf(s.edge, 0.01), "corners": snappedf(s.corners, 0.1),
		"bays": snappedf(s.bays, 0.01), "levels": s.levels, "climbs": s.climbs}
	var r: Rect2i = s.box
	var mid := r.position + r.size / 2
	var why: PackedStringArray = []
	if s.fill > cfg("box_max_fill"):
		why.append("fills %d%% of its box (max %d%%)" % [roundi(s.fill * 100), roundi(cfg("box_max_fill") * 100)])
		_problem(c, mid, "too square: the ground fills %d%% of its bounding box; cut bays and inlets" % roundi(s.fill * 100))
	if s.edge < cfg("box_min_edge"):
		why.append("edge %.2f (min %.1f)" % [s.edge, cfg("box_min_edge")])
		_problem(c, r.position, "outline too straight: edge %.2f, wind it in and out" % s.edge)
	if s.corners < cfg("box_min_corners"):
		why.append("corners %.1f (min %d)" % [s.corners, roundi(cfg("box_min_corners"))])
		_problem(c, r.position, "few jut-outs: %.1f corners per 100 cells" % s.corners)
	if s.bays < cfg("box_min_bays"):
		why.append("bays %.2f (min %.2f)" % [s.bays, cfg("box_min_bays")])
		var cc: Array[Vector2i] = s.corner_cells
		c.cells.append_array(cc)
		_problem(c, cc[0] if not cc.is_empty() else r.position, "the box's corners are filled in: leave bays there (painted)")
	if s.levels < cfg("box_min_levels"):
		why.append("%d levels (min %d)" % [s.levels, roundi(cfg("box_min_levels"))])
		_problem(c, mid, "too flat: %d heights under the ground" % s.levels)
	if s.climbs < cfg("box_min_climbs"):
		why.append("%d climbs (min %d)" % [s.climbs, roundi(cfg("box_min_climbs"))])
		_problem(c, mid, "few climbs: %d stair runs" % s.climbs)
	if why.is_empty():
		c.summary = "not a box: fill %d%%, %d levels, %d climbs" % [roundi(s.fill * 100), s.levels, s.climbs]
	else:
		c.level = "fail"
		c.summary = "; ".join(why)
	return c


# --- stairs ------------------------------------------------------------------------------

## Stair cells in 4-connected runs.
static func _stair_runs(g: CombatGrid) -> Array:
	var cells: Array[Vector2i] = []
	for y in g.h:
		for x in g.w:
			if g.terrain_at(Vector2i(x, y)) == T.STAIRS:
				cells.append(Vector2i(x, y))
	return _patches(cells)


static func check_stairs(g: CombatGrid, kind: String) -> Dictionary:
	var c := _check("stairs")
	var jump := int(cfg("jump"))
	var runs := _stair_runs(g)
	var bad := 0
	for r: Array in runs:
		var exits := {}  # heights of the ground this run lets a walker step onto
		var top := -1  # the highest ground standing next to the run that can be stood on
		var top_at := Vector2i.ZERO
		var hi := -1
		var hi_at: Vector2i = r[0]
		for s: Vector2i in r:
			if g.height_at(s) > hi:
				hi = g.height_at(s)
				hi_at = s
			for d in N4:
				var n := s + d
				if not g.in_bounds(n) or g.terrain_at(n) == T.STAIRS or not _stand(g, kind, n):
					continue
				if g.can_step(s, n, jump):
					exits[g.height_at(n)] = true
				if g.height_at(n) > top:
					top = g.height_at(n)
					top_at = n
		var hs: Array = exits.keys()
		hs.sort()
		if hs.size() < 2:
			bad += 1
			c.cells.append_array(r)
			_problem(c, hi_at, "stairs to nowhere: they don't join two levels" if hs.size() == 1 else "stairs to nowhere: nothing to step off onto")
		elif top > int(hs[-1]):
			bad += 1
			c.cells.append_array(r)
			c.cells.append(top_at)
			_problem(c, hi_at, "stops short: the top step can't reach the ledge at height %d" % top)
	c.stats = {"runs": runs.size(), "bad": bad}
	if bad == 0:
		c.summary = "%d stair run%s, all join two levels" % [runs.size(), "" if runs.size() == 1 else "s"] if runs.size() > 0 else "no stairs"
	else:
		c.level = "fail"
		c.summary = "%d of %d stair runs go nowhere" % [bad, runs.size()]
	return c


# --- scale -------------------------------------------------------------------------------

## The rules of tools/art/prop_scale_check.py on every prop the scale table knows.
static func check_scale(g: CombatGrid) -> Dictionary:
	var c := _check("scale")
	var table := scale_table()
	var hero := cfg("hero_tall")
	var checked := 0
	var bad := 0
	for a: Vector2i in g.props:
		var p: Dictionary = g.props[a]
		var name := String(p.sprite).get_file()
		if not table.has(name) or float(p.tall) <= 0.0:
			continue
		checked += 1
		var row: Dictionary = table[name]
		var tall := float(p.tall)
		var foot: Vector2i = p.foot
		var before := (c.problems as Array).size()
		var door := tall * float(row.door) / hero
		if door < float(row.headroom):
			_problem(c, a, "%s: its door is %.2f hero heights (needs %.1f); make it taller" % [name, door, float(row.headroom)])
		var wr := (tall * 64.0 * float(row.aspect)) / ((foot.x + foot.y) * 32.0 * 1.18)
		if wr < cfg("width_min") or wr > cfg("width_max"):
			_problem(c, a, "%s: drawn %.2fx the width of its %d x %d footprint; resize the footprint" % [name, wr, foot.x, foot.y])
		if tall / hero < cfg("building_min"):
			_problem(c, a, "%s: only %.1f hero heights tall" % [name, tall / hero])
		if (c.problems as Array).size() > before:
			bad += 1
			c.cells.append_array(g.prop_cells(a))
	c.stats = {"checked": checked, "bad": bad}
	if bad == 0:
		c.summary = "%d sized prop%s fit the hero" % [checked, "" if checked == 1 else "s"] if checked > 0 else "no sized props on this map"
	else:
		c.level = "fail"
		c.summary = "%d of %d props off scale" % [bad, checked]
	return c


# --- deploy room ---------------------------------------------------------------------------

## Cells within `radius` fight steps of the leader a member could start on (ExploreRules.deploy_cells).
static func ring(g: CombatGrid, lead: Vector2i, radius: int, jump: int, blocked := {}) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var steps := {lead: 0}
	var queue: Array[Vector2i] = [lead]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if int(steps[c]) >= radius:
			continue
		for d in CombatRules.DIRS:
			for n in g.places_next(c, d):
				if steps.has(n) or not g.passable(n) or blocked.has(n) or not g.can_step(c, n, jump):
					continue
				steps[n] = int(steps[c]) + 1
				queue.append(n)
				out.append(n)
	return out


static func check_deploy(g: CombatGrid, kind: String, data: Dictionary, reached: Dictionary) -> Dictionary:
	var c := _check("deploy")
	var need := int(cfg("deploy_room"))
	if kind != "explore":
		return _deploy_battle(g, data, c)
	var groups: Array = data.get("groups", [])
	var bad := 0
	for gr: Dictionary in groups:
		var units: Array[Vector2i] = []
		var foes := {}
		for u: Dictionary in gr.get("units", []):
			units.append(_cell(u.cell))
			foes[_cell(u.cell)] = true
		if units.is_empty():
			continue
		var sight := int(gr.get("sight", ExploreRules.ENEMY_SIGHT))
		# Where the fight can start: reached ground within the group's sight of one of its pieces.
		var meet: Array[Vector2i] = []
		for q: Vector2i in reached:
			if foes.has(q) or not g.walkable(q):
				continue
			for u in units:
				if ExploreRules.dist(q, u) <= sight:
					meet.append(q)
					break
		var gid := String(gr.get("id", "?"))
		if meet.is_empty():
			bad += 1
			c.cells.append_array(units)
			_problem(c, units[0], "%s: the party can't get within its sight, so the fight never starts" % gid)
			continue
		var cramped: Array[Vector2i] = []
		for q in meet:
			if ring(g, q, int(cfg("deploy_radius")), int(cfg("jump")), foes).size() < need:
				cramped.append(q)
		if float(cramped.size()) / meet.size() > cfg("deploy_cramped_share"):
			bad += 1
			c.cells.append_array(cramped)
			_problem(c, units[0], "%s: %d of %d cells the fight can start from have no room for the party (%d next to the leader)" % [gid, cramped.size(), meet.size(), need])
	c.stats = {"groups": groups.size(), "bad": bad}
	if bad == 0:
		c.summary = "room to deploy at all %d fight%s" % [groups.size(), "" if groups.size() == 1 else "s"] if groups.size() > 0 else "no foe groups on this map"
	else:
		c.level = "fail"
		c.summary = "%d of %d fights cramped" % [bad, groups.size()]
	return c


## A battle map: both deploy zones hold a full side, and every piece stands somewhere it can stand.
static func _deploy_battle(g: CombatGrid, data: Dictionary, c: Dictionary) -> Dictionary:
	var party: Array = data.get("party", [])
	var foes: Array = data.get("enemies", [])
	var why: PackedStringArray = []
	for side in [[0, maxi(int(cfg("deploy_room")) + 1, party.size()), "party"], [1, foes.size(), "foe"]]:
		var cells := g.deploy_cells(int(side[0]))
		if cells.size() < int(side[1]):
			why.append("%s side: %d deploy cells for %d" % [side[2], cells.size(), side[1]])
			_problem(c, cells[0] if not cells.is_empty() else Vector2i(0 if side[0] == 0 else g.w - 1, g.h / 2),
				"the %s deploy zone holds %d of %d pieces" % [side[2], cells.size(), side[1]])
	for list in [party, foes]:
		for e in list:
			var p := _cell(e)
			if not g.passable(p):
				why.append("a piece off the ground")
				c.cells.append(p)
				_problem(c, p, "a piece stands on a cell nobody can stand on")
	c.stats = {"party_cells": g.deploy_cells(0).size(), "foe_cells": g.deploy_cells(1).size()}
	if why.is_empty():
		c.summary = "both sides fit: %d and %d deploy cells" % [c.stats.party_cells, c.stats.foe_cells]
	else:
		c.level = "fail"
		c.summary = "; ".join(why)
	return c

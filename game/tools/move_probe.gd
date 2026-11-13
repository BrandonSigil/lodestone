extends SceneTree
## Movement feel probe: loads an explore map, then simulates holding WASD from many spots with the game's own
## ExploreRules.slide at 60 fps. Reports screen speed by key, how often the leader grinds or sticks, how often a
## one-cell doorway is walked through cleanly, and how long a cell crossing's _after_step takes (hitches).
## Usage: godot --headless --path game -s res://tools/move_probe.gd -- <map> [mode]
## mode: game (default: the game's own key_dir, walk_speed, ease_vel) | screen (the old way: keys turned straight
## from the screen direction, one speed on the grid), for a before and after.

var _frames := 0
var _map := ""
var _mode := "game"

const DT := 1.0 / 60.0
const KEYS := {"W": Vector2(0, -1), "S": Vector2(0, 1), "A": Vector2(-1, 0), "D": Vector2(1, 0),
	"WD": Vector2(1, -1), "WA": Vector2(-1, -1), "SD": Vector2(1, 1), "SA": Vector2(-1, 1)}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_map = args[0] if args.size() > 0 else "village_v2"
	_mode = args[1] if args.size() > 1 else "game"
	root.get_node("Game").set("save_enabled", false)
	root.get_node("Game").set("explore_map", _map)
	change_scene_to_file("res://scenes/explore.tscn")


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 30:
		_probe(current_scene)
		quit()
	return false


## The grid velocity a held key combo walks at, full speed.
func _vel(s, want: Vector2) -> Vector2:
	var ER = load("res://scripts/explore/explore_rules.gd")
	var ax: Array = s._axes()
	if _mode == "screen":
		return s._screen_to_grid(want).normalized() * 5.0
	var d: Vector2 = ER.key_dir(want, ax[0], ax[1])
	return d * ER.walk_speed(d, ax[0], ax[1])


func _probe(s) -> void:
	var grid = s.grid
	var lead = s.leader()
	var ER = load("res://scripts/explore/explore_rules.gd")
	var blocked: Dictionary = s._blocked()
	var board = s.board
	print("map %s  mode %s  size %dx%d  lead %s" % [_map, _mode, grid.w, grid.h, lead.cell])
	# Cells the leader can reach (flood on grid steps).
	var seen := {lead.cell: true}
	var todo: Array = [lead.cell]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for st in ER.STEPS:
			for n in grid.places_next(c, st):
				if not seen.has(n) and ER.can_step_to(grid, c, n, lead.jump, blocked):
					seen[n] = true
					todo.append(n)
	var cells: Array = seen.keys()
	cells.shuffle()
	var sample: Array = cells.slice(0, mini(250, cells.size()))
	print("reachable cells %d, sampled %d" % [cells.size(), sample.size()])

	# 1) Screen speed per key on open ground (px/s at zoom 1).
	var line := "screen px/s:"
	for k in KEYS:
		var g: Vector2 = _vel(s, KEYS[k])
		var a: Vector2 = board.iso(0.0, 0.0, 0.0)
		var b: Vector2 = board.iso(g.x, g.y, 0.0)
		line += "  %s %.0f" % [k, a.distance_to(b)]
	print(line)

	# 2) Hold each key 0.8 s from each sampled cell (random spot inside it): grind = frames moving < 85% of full
	#    speed while not fully stopped; stuck = frames under 5%. Facing wrong = key facing differs from real motion.
	var tot := 0
	var grind := 0
	var stuck := 0
	var jitter := 0
	var face_wrong := 0
	for c in sample:
		for k in KEYS:
			var v: Vector2 = _vel(s, KEYS[k])
			var dir := v.normalized()
			var p := Vector2(CombatGrid.ground(c)) + Vector2(randf_range(0.3, 0.7), randf_range(0.3, 0.7))
			var at: Vector2i = c
			var last := Vector2.ZERO
			for f in 48:
				var q: Vector2 = ER.slide(grid, p, v * DT, ER.BODY, lead.jump, blocked, at)
				var mv: Vector2 = q - p
				var r: float = mv.length() / (v.length() * DT)
				tot += 1
				if r < 0.05:
					stuck += 1
				elif r < 0.85:
					grind += 1
				if r > 0.05 and last != Vector2.ZERO and mv.normalized().dot(last.normalized()) < 0.5:
					jitter += 1
				if r > 0.05:
					var kf := Vector2i(roundi(dir.x), roundi(dir.y))
					var mf := Vector2i(roundi(mv.normalized().x), roundi(mv.normalized().y))
					if kf != mf:
						face_wrong += 1
					last = mv
				p = q
				var cell: Vector2i = grid.step_place(at, Vector2i(p.floor()), lead.jump)
				if cell != CombatGrid.NO_PLACE:
					at = cell
	print("hold test frames %d: grinding %.1f%%  stuck %.1f%%  sharp turns %d  facing != motion %.1f%%" % [tot,
		100.0 * grind / tot, 100.0 * stuck / tot, jitter, 100.0 * face_wrong / tot])

	# 3) Doorways: a walkable cell with walls (not walkable) on both sides across one axis and open cells before
	#    and after along the other. Start 1.6 cells before, offset sideways up to 0.35, hold the key combo that
	#    points through the door best; pass = reached 1 cell past it within 1.5 s.
	var doors := 0
	var passed := 0
	var slow := 0.0
	for c in cells:
		if c.y >= CombatGrid.DECK:
			continue
		for ax in [Vector2i(1, 0), Vector2i(0, 1)]:
			var side := Vector2i(ax.y, ax.x)
			if grid.walkable(c + side) or grid.walkable(c - side):
				continue
			for sgn in [1, -1]:
				var dv: Vector2i = ax * sgn
				if not (seen.has(c - dv) and seen.has(c - dv * 2) and seen.has(c + dv)):
					continue
				if not (ER.can_step_to(grid, c - dv * 2, c - dv, lead.jump, blocked) and ER.can_step_to(grid, c - dv, c, lead.jump, blocked)
						and ER.can_step_to(grid, c, c + dv, lead.jump, blocked)):
					continue  # a cliff in the line, not a doorway
				doors += 1
				# the key combo whose grid direction points most along dv
				var best := Vector2.ZERO
				var bd := -2.0
				for k in KEYS:
					var g: Vector2 = _vel(s, KEYS[k])
					if g.normalized().dot(Vector2(dv)) > bd:
						bd = g.normalized().dot(Vector2(dv))
						best = g
				var off := randf_range(-0.35, 0.35)
				var p := Vector2(c) + Vector2(0.5, 0.5) - Vector2(dv) * 1.6 + Vector2(side) * off
				var at: Vector2i = Vector2i(p.floor())
				var ok := false
				var t := 0.0
				for f in 90:
					p = ER.slide(grid, p, best * DT, ER.BODY, lead.jump, blocked, at)
					t += DT
					var cell: Vector2i = grid.step_place(at, Vector2i(p.floor()), lead.jump)
					if cell != CombatGrid.NO_PLACE:
						at = cell
					if Vector2i(p.floor()) == c + dv:
						ok = true
						break
				if ok:
					passed += 1
					slow += t
				elif OS.get_environment("PROBE_DOORS") != "":
					print("  missed door %s going %s, side offset %.2f, ended %s" % [c, dv, off, p])
	if doors > 0:
		print("doorways %d: walked through %d (%.0f%%), mean time %.2fs (ideal %.2fs)" % [doors, passed,
			100.0 * passed / doors, slow / maxf(1, passed), 2.1 / best_speed(s)])

	# 4) Cell-crossing cost: _after_step is run every time the leader enters a new cell.
	var times: Array = []
	for i in 40:
		var t0 := Time.get_ticks_usec()
		s._refresh_sight()
		s.check_groups()
		s._refresh_units()
		times.append(Time.get_ticks_usec() - t0)
	times.sort()
	print("after_step cost us: median %d  p90 %d  max %d" % [times[20], times[36], times[39]])


func best_speed(s) -> float:
	return _vel(s, Vector2(1, -1)).length()

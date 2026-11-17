class_name SnareLine
extends HuntGame
## C · Snare Line: the ground by the camp as a grid, with tonight's animal runs drawn as faint tracks. Click a cell to
## set a snare (three a night), right-click to put the bait down, Space to sleep. The night plays out in a few
## seconds: each animal walks its run, and the first snare it steps in rolls to hold (d20 vs its strength).
## Habits: rabbits hop cover to cover, boars go straight to the water and snap weak snares, foxes zigzag and won't
## come near bait you handled. Half the tracks are stale. Hunter: sees every run, his snares hold better.
## Doggo: SNIFF shows which runs are fresh tonight.

const NIGHT_SECS := 5.5

var fld := {}
var runs: Array[Dictionary] = []
var snares: Array[Vector2i] = []
var bait := Vector2i(-1, -1)
var night := {}  ## HuntRules.snare_night's result once Space is pressed
var night_t := -1.0


func start() -> void:
	mode = "snare"
	fld = HuntRules.snare_field(rng)
	runs = HuntRules.snare_runs(rng, fld, 6)


func _cell_size() -> float:
	var f := field()
	return floorf(minf(f.size.x / float(fld.cols), (f.size.y - 10) / float(fld.rows)))


func _origin() -> Vector2:
	var f := field()
	var cs := _cell_size()
	return f.position + (f.size - Vector2(cs * fld.cols, cs * fld.rows)) * 0.5


func _centre(c: Vector2i) -> Vector2:
	var cs := _cell_size()
	return _origin() + Vector2(c.x + 0.5, c.y + 0.5) * cs


func _cell_at(p: Vector2) -> Vector2i:
	var q := (p - _origin()) / _cell_size()
	var c := Vector2i(floori(q.x), floori(q.y))
	if c.x < 0 or c.y < 0 or c.x >= int(fld.cols) or c.y >= int(fld.rows):
		return Vector2i(-1, -1)
	return c


func _shown(r: Dictionary) -> bool:
	return mods.get("hunter", false) or bool(r.seen)


func step(dt: float) -> void:
	if night_t >= 0.0:
		night_t += dt
		if night_t >= NIGHT_SECS + 1.0:
			_end()
	elif Input.is_key_pressed(KEY_SPACE) and not snares.is_empty():
		_sleep()


func _sleep() -> void:
	night = HuntRules.snare_night(rng, runs, snares, bait, mods)
	caught.assign(night.caught)
	night_t = 0.0


func play_input(event: InputEvent) -> void:
	if night_t >= 0.0 or not (event is InputEventMouseButton and event.pressed):
		return
	var c := _cell_at(event.position)
	if c == Vector2i(-1, -1) or (fld.water as Array).has(c):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if snares.has(c):
			snares.erase(c)
		elif snares.size() < int(HuntRules.tune("snare_count", 3)):
			snares.append(c)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		bait = Vector2i(-1, -1) if bait == c else c


func paint() -> void:
	var cs := _cell_size()
	var o := _origin()
	draw_rect(Rect2(Vector2.ZERO, size), Color("#3a2f50"))
	var ground := Rect2(o, Vector2(cs * fld.cols, cs * fld.rows))
	draw_rect(ground.grow(10), PINE.darkened(0.25))
	draw_rect(ground, PINE)
	for x in int(fld.cols) + 1:
		draw_line(o + Vector2(x * cs, 0), o + Vector2(x * cs, ground.size.y), Riso.alpha(INK, 0.25), 1.0)
	for y in int(fld.rows) + 1:
		draw_line(o + Vector2(0, y * cs), o + Vector2(ground.size.x, y * cs), Riso.alpha(INK, 0.25), 1.0)
	for w: Vector2i in fld.water:
		draw_rect(Rect2(o + Vector2(w) * cs, Vector2(cs, cs)), Color("#4a7fb5"))
	for b: Vector2i in fld.bushes:
		draw_bush(_centre(b), cs * 0.36, LEAF)
	# the runs: dotted tracks in each animal's colour
	var sniff: bool = mods.get("doggo", false)
	for r in runs:
		if not _shown(r):
			continue
		var col: Color = ANIMAL_COL.get(String(r.kind), CREAM)
		var a := 0.85 if (not sniff or r.fresh) else 0.18
		var cells: Array = r.cells
		for i in cells.size() - 1:
			var p0 := _centre(cells[i])
			var p1 := _centre(cells[i + 1])
			for k in 3:
				draw_circle(p0.lerp(p1, k / 3.0), 3.0, Riso.alpha(col, a))
		if sniff and r.fresh:
			var end := _centre(cells[0])
			draw_circle(end, 9, Riso.alpha(INK, 0.7))
			text("!", end + Vector2(0, 6), 16, AMBER, true)
	# bait and snares
	if bait != Vector2i(-1, -1):
		var bc := _centre(bait)
		draw_circle(bc, cs * 0.16, RED)
		draw_circle(bc + Vector2(cs * 0.1, -cs * 0.1), cs * 0.07, LEAF.lightened(0.2))
	var spent := {}
	if night_t >= 0.0:
		for e: Dictionary in night.events:
			if _event_time(e) <= night_t:
				spent[e.cell] = e.outcome
	for s in snares:
		var sc := _centre(s)
		var st := String(spent.get(s, ""))
		var col := AMBER if st == "" else (CREAM if st == "caught" else RED)
		draw_arc(sc, cs * 0.24, 0, TAU, 24, col, 3.0, true)
		draw_line(sc + Vector2(0, cs * 0.24), sc + Vector2(0, cs * 0.4), col, 3.0, true)
		if st == "snapped":
			draw_line(sc - Vector2(cs * 0.2, cs * 0.2), sc + Vector2(cs * 0.2, cs * 0.2), RED, 3.0, true)
			text(Txt.t("HUNT_SNAPPED"), sc + Vector2(0, -cs * 0.32), 15, RED, true)
	# the night
	if night_t >= 0.0:
		var dark := clampf(night_t / 0.6, 0.0, 1.0) * (1.0 - clampf((night_t - NIGHT_SECS) / 0.6, 0.0, 1.0))
		draw_rect(Rect2(Vector2.ZERO, size), Riso.alpha(Color("#141a3a"), 0.45 * dark))
		var paths: Array = night.paths
		for i in paths.size():
			var cells: Array = paths[i]
			if cells.is_empty():
				continue
			var stop := cells.size() - 1
			for e: Dictionary in night.events:
				if int(e.run) == i and e.outcome == "caught":
					stop = int(e.step)
			var u := clampf(night_t / NIGHT_SECS, 0.0, 1.0) * (cells.size() - 1)
			var k := mini(floori(u), stop)
			var pos := _centre(cells[k]) if k >= stop else _centre(cells[k]).lerp(_centre(cells[mini(k + 1, cells.size() - 1)]), u - k)
			draw_animal(String(runs[i].kind), pos, Vector2.RIGHT, 0.75, "stand" if k >= stop else "run", Color(0.8, 0.8, 1.0))
		Riso.draw_crescent(self, Vector2(size.x - 70, 60), 26, CREAM)
	hud_strip()
	var x := pips(Vector2(30, hud_y()), int(HuntRules.tune("snare_count", 3)), int(HuntRules.tune("snare_count", 3)) - snares.size(), AMBER, Txt.t("HUNT_SNARES"))
	pips(Vector2(x + 30, hud_y()), 1, 1 if bait == Vector2i(-1, -1) else 0, RED, Txt.t("HUNT_BAIT"))
	var keys := Txt.t("HUNT_KEYS_SNARE")
	text(keys, Vector2(size.x - 24 - Riso.font().get_string_size(keys, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, hud_y() + 6), 15, Color("#cbbfd9"))


## When, in night seconds, an event's animal reaches its snare.
func _event_time(e: Dictionary) -> float:
	var cells: Array = night.paths[int(e.run)]
	if cells.size() > 1:
		return float(e.step) / (cells.size() - 1) * NIGHT_SECS
	return NIGHT_SECS

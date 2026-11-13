class_name FightCamera
extends Node
## The fight's camera on a board the battle owns (road fights, the battle view). Backlog P22, Brandon 2026-11-13:
## "these combat maps are too zoomed out, I expect them to be closer". The old view fitted the whole map in the play
## area (about 0.8 on a 21 x 18 road map), so the pieces were tiny. Now a fight opens at the exploration camera's
## zoom (1.35, [USER] 2026-10-29 "close in"), framed on the pieces: both sides when they fit the clear part of the
## screen, else the party, pulled toward the foes as far as it can while keeping every party piece in view.
##
## The player sees the rest of the map by panning and zooming, as on exploration maps:
##   wheel or pinch zooms (from the whole map up to ZOOM_MAX), arrows, middle drag or two-finger scroll pan,
##   Space looks back at the active piece.
## The camera follows what happens: the piece the player picks, and each foe as it moves and acts. It only glides
## when the thing is out of the clear area (the play area less the dock, the side box and the log), so a fight on
## screen doesn't swing about. A pan by hand stops it following the player's own pieces until the next pick; a foe
## acting always brings the camera along, so nothing happens out of view.
## Pure screen maths over the board: `center` is the board-local point (unscaled) shown in the middle of the rect.

const ZOOM_START := 1.35  ## the explore camera's zoom: road and exploration fights read the same
const ZOOM_MAX := 1.8
const OLD_MAX := 1.6  ## the old whole-map fit's top
const ZOOM_FLOOR := 1.0  ## a framing never opens further out than this (the player may wheel out to the whole map)
const ZOOM_STEP := 1.1  ## one wheel notch
const PAN_SPEED := 700.0  ## arrows, screen px a second
const GLIDE := 6.0  ## how fast the camera catches up (per second, eased)
const MARGIN := 56.0  ## screen px kept between a framed piece and the clear area's edge
const SIDE_W := 250.0  ## the turn box at the top right (YOUR TURN, END TURN, DANGER)
## The band over the play area's bottom where the dock (portrait and actions) and the log sit. A fixed band, not
## their boxes: the dock hides in the foes' turn and comes back where it was, so a foe must never stop under it.
const DOCK_H := 140.0
const PIECE_UP := 5.0  ## a piece and its bar reach about this many levels above its cell
const OPEN_FLOOR := 1.1  ## an opening backs off no further than this to fit both sides; past it, it leans

var board: CombatBoard
var rect := Rect2()  ## the play area the board is shown in (screen)
var zoom := ZOOM_START
var center := Vector2.ZERO  ## board-local point at the middle of rect
var target := Vector2.ZERO  ## where center glides to
var target_zoom := ZOOM_START
var free := false  ## the player panned: don't chase their own pieces until the next pick
var track: CombatUnit = null  ## kept in view while it walks (the acting foe, the piece just moved)
var _drag := false
var _ready_once := false


## The zoom that shows the whole map in the rect (the old view, which used it clamped to 0.5 to 1.6).
func whole_zoom() -> float:
	if rect.size.x <= 0.0 or board == null:
		return ZOOM_FLOOR
	var bs := board.board_size()
	return minf(rect.size.x / bs.x, rect.size.y / bs.y) * 0.95


## The furthest the player may wheel out: the whole map.
func min_zoom() -> float:
	return minf(whole_zoom(), ZOOM_FLOOR)


## The opening zoom: ZOOM_START, or the old whole-map fit on a map small enough to show bigger (the 10 x 8 trail
## island opened at 1.57 and still does).
func open_zoom() -> float:
	return maxf(ZOOM_START, minf(whole_zoom(), OLD_MAX))


## The part of the screen a framed piece should stand in: the rect less the side box and the dock's band.
func clear_area() -> Rect2:
	var r := rect
	r.size -= Vector2(SIDE_W, DOCK_H)
	return r.grow(-MARGIN)


## A piece's framing box, board-local: from its feet up to the bar over its head.
func piece_points(u: CombatUnit) -> Array[Vector2]:
	var feet := board.iso(u.vis.x + 0.5, u.vis.y + 0.5, u.vis_h)
	return [feet, feet + Vector2(0, -PIECE_UP * CombatBoard.HS)]


func cell_points(c: Vector2i) -> Array[Vector2]:
	var feet := board.cell_top(c)
	return [feet, feet + Vector2(0, -PIECE_UP * CombatBoard.HS)]


## Board-local point -> screen, at the current (not target) view.
func to_screen(p: Vector2) -> Vector2:
	return rect.get_center() + (p - center) * zoom


## The opening shot: zoom and centre on the pieces in play. again: the start of a later player turn, at the zoom
## the player left it on, gliding there (the foes may have come close, under the dock).
func frame(units: Array, again := false) -> void:
	var party: Array[Vector2] = []
	var all: Array[Vector2] = []
	for u: CombatUnit in units:
		if u.alive():
			all.append_array(piece_points(u))
			if u.team == 0:
				party.append_array(piece_points(u))
	if all.is_empty():
		center = board.board_origin() + board.board_size() * 0.5
		target = center
		return
	var area := clear_area()
	var box := _bounds(all)
	var z := target_zoom if again else open_zoom()
	if not again and (box.size.x * z > area.size.x or box.size.y * z > area.size.y):  # both sides don't fit: back off a little
		z = maxf(minf(OPEN_FLOOR, z), minf(area.size.x / maxf(box.size.x, 1.0), area.size.y / maxf(box.size.y, 1.0)))
	target_zoom = z
	if not again:
		zoom = z
	# Aim at the middle of everyone, then slide back until every party piece is in the clear area.
	var aim := box.get_center()
	if not party.is_empty():
		var pb := _bounds(party)
		var half := area.size * 0.5 / z
		aim.x = _keep(aim.x, pb.end.x - half.x, pb.position.x + half.x)
		aim.y = _keep(aim.y, pb.end.y - half.y, pb.position.y + half.y)
	# aim is where the clear area's middle should be; centre is the rect's middle
	target = _clamped(aim - (area.get_center() - rect.get_center()) / z)
	if not again:
		center = target
	free = false
	_ready_once = true


## Glide so the given cells are in the clear area; does nothing when they already are.
func show_cells(cells: Array) -> void:
	var pts: Array[Vector2] = []
	for c: Vector2i in cells:
		pts.append_array(cell_points(c))
	_show(pts)


func show_unit(u: CombatUnit, by_hand := false) -> void:
	if u == null or (free and by_hand):
		return
	_show(piece_points(u))


## Space: back to a piece now, whatever the player did with the camera.
func look_at_unit(u: CombatUnit) -> void:
	if u == null:
		return
	free = false
	var area := clear_area()
	target = _bounds(piece_points(u)).get_center() - (area.get_center() - rect.get_center()) / target_zoom


func _show(pts: Array[Vector2]) -> void:
	if pts.is_empty():
		return
	var area := clear_area()
	var box := _bounds(pts)
	var tl := rect.get_center() + (box.position - target) * zoom
	var br := rect.get_center() + (box.end - target) * zoom
	if area.has_point(tl) and area.has_point(br):
		return
	# Move the least that brings the box in (centre it when it is bigger than the area).
	var shift := Vector2.ZERO
	if br.x - tl.x > area.size.x:
		shift.x = (tl.x + br.x) * 0.5 - area.get_center().x
	elif tl.x < area.position.x:
		shift.x = tl.x - area.position.x - area.size.x * 0.25
	elif br.x > area.end.x:
		shift.x = br.x - area.end.x + area.size.x * 0.25
	if br.y - tl.y > area.size.y:
		shift.y = (tl.y + br.y) * 0.5 - area.get_center().y
	elif tl.y < area.position.y:
		shift.y = tl.y - area.position.y - area.size.y * 0.25
	elif br.y > area.end.y:
		shift.y = br.y - area.end.y + area.size.y * 0.25
	target += shift / zoom


## v kept in [lo, hi]; the middle of the two when the range is empty (the party is wider than the area).
static func _keep(v: float, lo: float, hi: float) -> float:
	return (lo + hi) * 0.5 if lo > hi else clampf(v, lo, hi)


static func _bounds(pts: Array[Vector2]) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r


## Hold an arrow for a moment (screenshot steps): dir in screen terms, for secs.
func nudge(dir: Vector2, secs: float) -> void:
	free = true
	target += dir * PAN_SPEED * secs / zoom


func _process(delta: float) -> void:
	if board == null or not _ready_once:
		return
	var pan := Vector2.ZERO
	if get_viewport().gui_get_focus_owner() == null:  # a focused menu (the dock) uses the arrows itself
		if Input.is_key_pressed(KEY_LEFT):
			pan.x -= 1
		if Input.is_key_pressed(KEY_RIGHT):
			pan.x += 1
		if Input.is_key_pressed(KEY_UP):
			pan.y -= 1
		if Input.is_key_pressed(KEY_DOWN):
			pan.y += 1
	if pan != Vector2.ZERO:
		free = true
		target += pan.normalized() * PAN_SPEED * delta / zoom
	if track != null and is_instance_valid(track):
		show_unit(track)
	var t := minf(1.0, delta * GLIDE)
	zoom = lerpf(zoom, target_zoom, t)
	target = _clamped(target)
	center = center.lerp(target, t)
	apply()


## Keep the view over the map: its middle never leaves the board's box.
func _clamped(p: Vector2) -> Vector2:
	var o := board.board_origin()
	var s := board.board_size()
	return Vector2(clampf(p.x, o.x, o.x + s.x), clampf(p.y, o.y, o.y + s.y))


## Jump to the target now (a camera turn).
func snap() -> void:
	target = _clamped(target)
	center = target
	zoom = target_zoom


func apply() -> void:
	board.scale = Vector2.ONE * zoom
	board.position = rect.get_center() - center * zoom
	board.view_rect = rect  # the wallpaper follows the view


func _unhandled_input(event: InputEvent) -> void:
	if board == null or not _ready_once:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_zoom_at(mb.position, ZOOM_STEP if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_drag = mb.pressed
	elif event is InputEventMouseMotion and _drag:
		_pan_by((event as InputEventMouseMotion).relative)
	elif event is InputEventPanGesture:  # two fingers on a trackpad
		_pan_by(-(event as InputEventPanGesture).delta * 12.0)
	elif event is InputEventMagnifyGesture:  # pinch
		var mg := event as InputEventMagnifyGesture
		_zoom_at(mg.position, mg.factor)


func _pan_by(screen: Vector2) -> void:
	free = true
	target -= screen / zoom
	center = _clamped(center - screen / zoom)  # a drag moves at once, no glide
	target = center
	apply()


## Zoom about a screen point, so what is under the pointer stays under it.
func _zoom_at(at: Vector2, k: float) -> void:
	var z := clampf(target_zoom * k, min_zoom(), ZOOM_MAX)
	if is_equal_approx(z, target_zoom):
		return
	var under := center + (at - rect.get_center()) / zoom
	zoom = z
	target_zoom = z
	center = under - (at - rect.get_center()) / z
	target = center
	apply()

class_name ExploreOverlay
extends Node2D
## Drawn on top of the exploration board (a child of it, so it shares the board's camera):
## the things on the map (chests, the hum stone, the way out, door slabs) and the interact icons.
## Graybox shapes; Brandon's props replace them later.

const ICON := Color(1.0, 0.86, 0.4)
const INK := Color(0.12, 0.11, 0.1)
const NO_MARK_KINDS := ["enter", "door"]  ## doorways, map exits and locked doors: no "!" over them

var scene: Node  ## the explore scene: things, party, mode
var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var board: CombatBoard = get_parent()
	if board == null or board.grid == null or scene == null:
		return
	var lead: CombatUnit = scene.leader()
	var font := ThemeDB.fallback_font
	var use: Dictionary = scene.nearest_thing() if lead != null and scene.walking() else {}  # the one F uses gets the F
	board.glow = scene.lit_doors()  # doors glow on the board, under the pieces
	board.focus = {use.cell: true} if not use.is_empty() and board.fog.get(use.cell, 0) == 2 else {}  # the one F uses lights up
	var figs := {}  # people waiting here draw with the board's pieces, in depth order (not over the hero)
	for t: Dictionary in scene.things:
		if t.done or not scene.shown(t):
			continue
		var c: Vector2i = t.cell
		var state: int = board.fog.get(c, 0)
		if state == 0:
			continue
		var p := board.cell_top(c)
		var dim := state == 1
		_thing(String(t.kind), p, dim, not dim and use.get("id") == t.id and use.cell == t.cell)
		if String(t.kind) == "companion":
			# a companion stands at home while benched ([USER] pc-10: walk up to invite them)
			# (recruit_<id>: the playtest line-up in the square, 2026-10-31: everyone with art waits there)
			var who := String(t.get("event", "")).trim_prefix("companion_").trim_prefix("recruit_").trim_prefix("rescue_")
			if who != "" and not Game.in_party(who):
				figs[c] = _figure.bind(StringName(who), dim, _time, bool(t.get("fallen", false)))
		elif String(t.kind) == "dog":
			figs[c] = _figure.bind(&"dog", dim, _time)  # the dog waiting in his house: Doggo's own sprite (backlog X1)
		if dim or lead == null or not scene.walking():
			continue
		var near := ExploreRules.dist(lead.cell, c) <= ExploreRules.HINT_RANGE
		if NO_MARK_KINDS.has(String(t.kind)):
			# doors get no "!" ([USER] 2026-10-30): they glow when the party is close (lit_doors), nothing from
			# afar; the F shows over the one F would open
			if near and use.get("id") == t.id and use.cell == t.cell:
				var at := p + Vector2(-30, -30)
				draw_string_outline(font, at, "F", HORIZONTAL_ALIGNMENT_CENTER, 60, 12, 3, Color(0, 0, 0, 0.8))
				draw_string(font, at, "F", HORIZONTAL_ALIGNMENT_CENTER, 60, 12, ICON)
			continue
		var hovered := board.hover == c
		if near or hovered:
			# The interact icon: a bobbing bubble with a "!" over anything the party can use. The one F would use stands
			# out ([USER] 2026-11-01 "Things need highlight when youre about to interact with them"): bigger, ringed in
			# light, the F key beside it; the others step back while it is chosen.
			var chosen: bool = near and use.get("id") == t.id and use.cell == t.cell
			var k := 1.3 if chosen else 1.0
			var fade := 1.0 if chosen or use.is_empty() else 0.5
			var top := p + Vector2(0, (-58 + sin(_time * 4.0) * 3.0) * (1.08 if chosen else 1.0))
			if chosen:
				var pulse := 0.6 + 0.4 * sin(_time * 5.0)
				draw_circle(top, 12.0 * k + 6.0, Color(1.0, 0.97, 0.82, 0.25 * pulse))
				draw_arc(top, 12.0 * k + 3.0, 0, TAU, 32, Color(1.0, 0.98, 0.9, 0.9 * pulse), 2.5, true)
			draw_circle(top + Vector2(2, 2), 12.0 * k, Color(0, 0, 0, 0.35 * fade))
			draw_circle(top, 12.0 * k, Color(ICON, fade))
			draw_arc(top, 12.0 * k, 0, TAU, 24, Color(INK, fade), 2.0, true)
			draw_colored_polygon(PackedVector2Array([top + Vector2(-4, 10) * k, top + Vector2(4, 10) * k, top + Vector2(0, 17) * k]), Color(ICON, fade))
			draw_string(font, top + Vector2(-12, 6) * k, "!", HORIZONTAL_ALIGNMENT_CENTER, 24 * k, int(18 * k), Color(INK, fade))
			if chosen:  # the key that uses it, on a small dark cap at the bubble's right
				var cap := top + Vector2(12.0 * k + 12.0, -6.0)
				draw_circle(cap, 10.0, Color(INK, 0.9))
				draw_arc(cap, 10.0, 0, TAU, 20, ICON, 1.5, true)
				draw_string(font, cap + Vector2(-10, 5), "F", HORIZONTAL_ALIGNMENT_CENTER, 20, 14, ICON)
	board.figures = figs


## A companion standing on p: their own sprite (idle, facing the camera) when they have art, else the code figure.
## fallen: lying on his side where the fight left him (Bushberry after the ogre, [USER] 2026-11-01), still, a little grey.
func _figure(ci: CanvasItem, p: Vector2, who: StringName, dim: bool, time: float, fallen := false) -> void:
	var d: CharacterDef = Db.character(who)
	var art_id: StringName = d.sprite_id() if d != null else who
	var f := CharacterArt.frame(art_id, "idle", "se", 0.0 if fallen else time) if CharacterArt.has_art(art_id) else {}
	var turn := FALLEN_TURN if fallen else 0.0
	if f.is_empty():
		ci.draw_set_transform(p, turn, Vector2.ONE)
		PlaceholderFigure.draw(ci, Vector2.ZERO, 26.0, who, 0, "idle", 0.0 if fallen else time, false, Color(0.4, 0.7, 1.0), dim)
		ci.draw_set_transform(Vector2.ZERO)
		return
	Pawn.ellipse(ci, p + Vector2(0, 2), 26.0 if fallen else 15.0, 6.0 if fallen else 5.0, Color(0, 0, 0, 0.25))
	var s: float = f.scale
	var lie := Vector2(f.anchor.y * s * 0.5, -4.0) if fallen else Vector2.ZERO  # head left, body centred on his cell
	ci.draw_set_transform(p + lie, turn, Vector2(-s if f.flip else s, s))
	var tone := Color(0.55, 0.55, 0.55) if dim else (Color(0.78, 0.78, 0.8) if fallen else Color.WHITE)
	ci.draw_texture_rect_region(f.tex, Rect2(-f.anchor, f.region.size), f.region, tone)
	ci.draw_set_transform(Vector2.ZERO)


const FALLEN_TURN := -PI * 0.5  ## a fallen companion lies on his side: the standing figure turned a quarter


func _thing(kind: String, p: Vector2, dim: bool, lit := false) -> void:
	var k := 0.55 if dim else (1.25 + 0.1 * sin(_time * 5.0) if lit else 1.0)  # the one F would use lifts and breathes
	match kind:
		"chest", "container":
			_box(p + Vector2(0, 2), 11.0, 10.0, Color(0.62, 0.42, 0.24) * k)
			draw_line(p + Vector2(-11, -11), p + Vector2(0, -6), Color(0.85, 0.7, 0.3) * k, 2.0)
		"shrine":
			_box(p, 7.0, 30.0, Color(0.55, 0.6, 0.7) * k)
			draw_circle(p + Vector2(0, -24), 3.0, Color(0.6, 0.95, 1.0, 0.6 + 0.4 * sin(_time * 3.0)) * k)
		"exit":
			draw_line(p, p + Vector2(0, -40), Color(0.35, 0.28, 0.2) * k, 3.0)
			var wave := sin(_time * 3.0) * 3.0
			draw_colored_polygon(PackedVector2Array([p + Vector2(1, -40), p + Vector2(24, -34 + wave), p + Vector2(1, -27)]), Color(0.9, 0.85, 0.5) * k)
		"statue":
			# The Lodestone in the statue's outstretched hand: a glow that goes once the stone is taken.
			var glow := 0.55 + 0.45 * sin(_time * 2.5)
			draw_circle(p + Vector2(18, -78), 14.0, Color(0.55, 0.95, 1.0, 0.18 * glow) * k)
			draw_circle(p + Vector2(18, -78), 7.0, Color(0.6, 0.98, 1.0, 0.5 + 0.4 * glow) * k)
			draw_circle(p + Vector2(18, -78), 3.5, Color(0.92, 1.0, 1.0) * k)
		"window":
			# A small shutter on the house wall, low enough to climb through.
			var f := PackedVector2Array([p + Vector2(-9, -30), p + Vector2(4, -36), p + Vector2(4, -22), p + Vector2(-9, -16)])
			draw_colored_polygon(f, Color(0.2, 0.18, 0.2) * k)
			draw_polyline(f + PackedVector2Array([f[0]]), Color(0.55, 0.4, 0.25) * k, 2.5, true)
		"boost":
			# A stat item: a glowing gem on a little stand ([USER] omr-10). Placeholder until art.
			var shine := 0.6 + 0.4 * sin(_time * 3.0)
			draw_circle(p + Vector2(0, -16), 9.0, Color(1.0, 0.85, 0.4, 0.25 * shine) * k)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -26), p + Vector2(6, -16), p + Vector2(0, -6), p + Vector2(-6, -16)]), Color(0.95, 0.75, 0.3) * k)
		"key":
			draw_circle(p + Vector2(-5, -14), 5.0, Color(0.9, 0.78, 0.35) * k)
			draw_circle(p + Vector2(-5, -14), 2.0, Color(0.2, 0.2, 0.2) * k)
			draw_line(p + Vector2(0, -14), p + Vector2(12, -14), Color(0.9, 0.78, 0.35) * k, 2.5)
			draw_line(p + Vector2(9, -14), p + Vector2(9, -9), Color(0.9, 0.78, 0.35) * k, 2.0)
		"rare":
			# Rare materials: a sparkling lump.
			draw_colored_polygon(_oval(p + Vector2(0, -6), 9.0, 6.0), Color(0.55, 0.5, 0.65) * k)
			for o in [Vector2(-4, -12), Vector2(5, -9), Vector2(1, -16)]:
				draw_circle(p + o, 1.5 + sin(_time * 5.0 + o.x) * 0.8, Color(0.85, 0.95, 1.0) * k)
		"climb":
			# A rope knot at the cliff foot.
			draw_line(p + Vector2(0, -2), p + Vector2(2, -46), Color(0.75, 0.62, 0.4) * k, 2.5, true)
			draw_circle(p + Vector2(0, -4), 4.0, Color(0.6, 0.48, 0.3) * k)
		"door", "rubble":
			# The wall is the board's ruin block; a door slab marks which one opens.
			if kind == "door":
				var d := PackedVector2Array([p + Vector2(-8, -4), p + Vector2(8, -4), p + Vector2(8, -26), p + Vector2(0, -31), p + Vector2(-8, -26)])
				draw_colored_polygon(d, Color(0.42, 0.28, 0.18) * k)
				draw_polyline(d + PackedVector2Array([d[0]]), INK, 1.5, true)
				draw_circle(p + Vector2(4, -15), 1.8, Color(0.9, 0.8, 0.4) * k)
			else:
				for o in [Vector2(-8, -6), Vector2(6, -4), Vector2(-1, -14)]:
					_box(p + o, 6.0, 5.0, Color(0.5, 0.47, 0.42) * k)


## A little iso box standing on p: two faces and a lid.
func _box(p: Vector2, r: float, tall: float, col: Color) -> void:
	var t := p + Vector2(0, -tall)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-r, -r * 0.5), p, t, t + Vector2(-r, -r * 0.5)]), col.darkened(0.1))
	draw_colored_polygon(PackedVector2Array([p, p + Vector2(r, -r * 0.5), t + Vector2(r, -r * 0.5), t]), col.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([t, t + Vector2(r, -r * 0.5), t + Vector2(0, -r), t + Vector2(-r, -r * 0.5)]), col.lightened(0.12))


static func _oval(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

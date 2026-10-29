extends Node2D
## The overworld ([USER] 2026-10-28): the town and the places around it on one map, joined by paths, like
## the early Mario world maps, in our flat look. Click a place to walk there: the party's mini pieces walk
## the path in real time (about a minute a leg), with an encounter or two on the way. Meanwhile the player
## can hunt, fish, forage, talk to the party or open the pack; >> jumps to the next encounter, or to the end
## of the leg. Food drains as they walk. Only the snowy pass is open for the E2E test.
##
## Code-drawn placeholders until art. Data: data/overworld_nodes.csv (places), data/overworld_paths.csv
## (legs, their length in seconds, encounter counts, the fight tile set), data/travel_events.csv
## (encounters, events.csv format). Rules: TravelRules. State: Game.travel.

const SIZE := Vector2(1000, 700)  ## map units the places and paths are laid out in
const PICK_R := 40.0  ## map units around a place that count as clicking it
const MEADOW := Color(0.55, 0.68, 0.42)
const MEADOW_DARK := Color(0.45, 0.58, 0.36)
const SNOW := Color(0.93, 0.95, 0.97)
const ROCK := Color(0.47, 0.5, 0.58)
const ROCK_DARK := Color(0.36, 0.38, 0.46)
const PINE := Color(0.2, 0.34, 0.3)
const PRAIRIE := Color(0.82, 0.78, 0.48)
const ROAD := Color(0.93, 0.86, 0.66)
const INK := Color(0.2, 0.22, 0.3)

var hud: FrameHud
var _ui: CanvasLayer
var _dialog: PanelContainer
var _info: Label
var _log_label: Label
var _busy := false  ## a box is up: the clock stops
var _menu_open := false
var _time := 0.0
var _hover := ""
var _note := ""  ## a short line under the party (PATH SHUT, a talk line)
var _note_time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	Game.ensure_run()
	Game.refresh_party()
	_rng.randomize()  # talk lines only; encounters roll on the run's dice
	if not Game.travel.has("at") and not Game.travel.has("to"):
		Game.travel = {"at": "town"}
	hud = FrameHud.new()
	add_child(hud)
	_ui = CanvasLayer.new()
	_ui.layer = 4
	add_child(_ui)
	_side()
	_refresh_hud()
	get_viewport().size_changed.connect(queue_redraw)


# --- the clock ------------------------------------------------------------------------------------

func walking() -> bool:
	return Game.travel.has("to")


func leg() -> Dictionary:
	return TravelRules.path_between(Db.world_paths, String(Game.travel.get("from", "")), String(Game.travel.get("to", "")))


func _process(delta: float) -> void:
	_time += delta
	_note_time = maxf(0.0, _note_time - delta)
	if walking() and not _busy:
		_advance_to(float(Game.travel.t) + delta)
	queue_redraw()


## Walk the clock forward to t1: meals on the way, then an encounter or the arrival if one is reached.
func _advance_to(t1: float) -> void:
	var tr := Game.travel
	var seconds := float(leg().get("seconds", 60))
	var stop := TravelRules.next_stop(float(tr.t), tr.stops, seconds)
	t1 = minf(t1, stop)
	for i in TravelRules.meals_between(float(tr.t), t1):
		TravelRules.eat(Game.run)
		_refresh_hud()
	tr.t = t1
	if t1 >= stop - 0.001:
		if stop >= seconds:
			_arrive()
		else:
			tr.stops.erase(stop)
			_encounter()
	_refresh_side()


## Walk to a place: leg by leg along the route, past cleared places on the way. then: the places still to go
## after this one.
func _start_leg(to: String, then: Array = []) -> void:
	var at := String(Game.travel.get("at", "town"))
	var p := TravelRules.path_between(Db.world_paths, at, to)
	if p.is_empty():
		var way := TravelRules.route(Db.world_paths, Db.world_nodes, at, to, Game.meta.flags)
		if way.size() < 2:
			_say(Txt.t("UI_OW_CLOSED"))
			return
		_start_leg(way[1], way.slice(2))
		return
	var stops := TravelRules.plan(Game.run.rng, float(p.seconds), int(p.enc_min), int(p.enc_max))
	Game.travel = {"from": at, "to": to, "t": 0.0, "stops": stops, "acts": {}, "then": then}
	_side()


func _arrive() -> void:
	var to := String(Game.travel.to)
	var then: Array = Game.travel.get("then", [])
	Game.travel = {"at": to}
	Game.save_adventure()
	if not then.is_empty():
		_say(Txt.f("UI_OW_PASSING", Txt.t(_node(to).name_key)))
		_start_leg(String(then[0]), then.slice(1))
		return
	_side()
	_busy = true
	var has_map := String(_node(to).get("map", "")) != ""
	var text := Txt.f("UI_OW_ARRIVED", Txt.t(_node(to).name_key))
	var box := _new_dialog(text if has_map else text + "\n" + Txt.t("UI_OW_NOTHING"))
	if has_map:
		_button(box, Txt.f("UI_OW_ENTER", Txt.t(_node(to).name_key)), _enter)
	_button(box, Txt.t("UI_STAY_MAP"), _close_dialog)


## Into the place's explore map (the town at its gate, the pass at its foot).
func _enter() -> void:
	var n := _node(String(Game.travel.get("at", "town")))
	if String(n.get("map", "")) == "":
		return
	Game.explore_map = n.map
	Game.explore_memory = {}
	Game.explore_entry = Vector2i(int(n.entry_x), int(n.entry_y)) if int(n.entry_x) >= 0 else Vector2i(-1, -1)
	Game.go(Game.EXPLORE)


func fast_forward() -> void:
	if not walking() or _busy:
		return
	_advance_to(TravelRules.next_stop(float(Game.travel.t), Game.travel.stops, float(leg().get("seconds", 60))))


# --- encounters ---------------------------------------------------------------------------------

func _encounter() -> void:
	var ev := TrailRules.pick_event(Game.run, Db.travel_events, Game.meta.flags)
	if ev.is_empty():
		return
	_busy = true
	var box := _new_dialog(Txt.t(ev.text_key))
	for o: Dictionary in ev.options:
		var label := Txt.t(o.key)
		if o.check != "none" and o.check != "fight":
			var bonus := TrailRules.party_bonus(Game.run, o.check)
			label += "   %s %+d  %d%%" % [Txt.t("CHECK_" + String(o.check).to_upper()), bonus, int(round(Dice.chance(bonus, o.dc) * 100))]
		_button(box, label, _choose.bind(o))


func _choose(o: Dictionary) -> void:
	var fx := TrailRules.resolve_option(Game.run, o)
	Game.absorb(fx.unlocks)
	_refresh_hud()
	var lines: PackedStringArray = []
	if not fx.check.is_empty():
		lines.append("%s  %s" % [Txt.t("CHECK_" + String(o.check).to_upper()), Dice.describe(fx.check)])
		lines.append(Txt.t("UI_EX_WIN") if fx.success else Txt.t("UI_EX_LOSE"))
	var shown := String(o.win if fx.success else o.lose)
	if shown != "" and fx.combat == "":
		lines.append(shown.replace(";", "  "))
	if fx.combat != "":
		var p := leg()
		Game.start_combat(fx.combat, String(p.get("art_set", "")), Game.OVERWORLD)
		return
	if lines.is_empty():
		_close_dialog()
		return
	var box := _new_dialog("\n".join(lines))
	_button(box, Txt.t("UI_CONTINUE"), _close_dialog)


# --- on the road: hunt, fish, forage, talk ---------------------------------------------------------

func act(kind: String) -> void:
	if not walking() or _busy:
		return
	var acts: Dictionary = Game.travel.acts
	var t := float(Game.travel.t)
	if not TravelRules.can_act(acts, kind, t):
		_say(Txt.t("UI_OW_WAIT"))
		return
	acts[kind] = t
	var r := TravelRules.activity(Game.run, kind)
	_say(Txt.t("UI_EX_WIN") if r.success else Txt.t("UI_EX_LOSE"))
	_refresh_hud()


func talk() -> void:
	var others := Game.run.alive().filter(func(m: Dictionary) -> bool: return (m.def as CharacterDef).id != &"lead")
	if others.is_empty():
		_say(Txt.t("UI_OW_ALONE"))
		return
	var d: CharacterDef = others[_rng.randi_range(0, others.size() - 1)].def
	var keys: Array[String] = []
	for i in range(1, 10):
		var k := "TALK_%s_%d" % [String(d.id).to_upper(), i]
		if Txt.has(k):
			keys.append(k)
	_say(Txt.t(keys[_rng.randi_range(0, keys.size() - 1)]) if not keys.is_empty() else Txt.t("UI_OW_ALONE"))


func _say(text: String) -> void:
	_note = text
	_note_time = 3.0
	Game.run.note(text)
	_refresh_side()


# --- input ----------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = _node_at(_to_map((event as InputEventMouseMotion).position))
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var id := _node_at(_to_map((event as InputEventMouseButton).position))
		if id != "" and not _busy and not walking():
			_click_node(id)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.is_echo() and event.keycode == KEY_TAB:
		fast_forward()


func _click_node(id: String) -> void:
	if not TravelRules.visible(Db.world_nodes, id, Game.meta.flags):
		return
	if id == String(Game.travel.get("at", "")):
		_enter()
	elif String(_node(id).open) != "1":
		_say(Txt.t("UI_OW_CLOSED"))
	else:
		_start_leg(id)


func _node(id: String) -> Dictionary:
	return Db.world_nodes.get(id, {})


func _node_at(p: Vector2) -> String:
	for id in Db.world_nodes:
		if TravelRules.visible(Db.world_nodes, id, Game.meta.flags) and p.distance_to(_node_pos(id)) <= PICK_R:
			return id
	return ""


func _node_pos(id: String) -> Vector2:
	var n := _node(id)
	return Vector2(float(n.x), float(n.y))


## Where the party stands, in map units.
func party_pos() -> Vector2:
	if walking():
		var p := leg()
		return TravelRules.point_at(p.points, float(Game.travel.t) / float(p.seconds))
	return _node_pos(String(Game.travel.get("at", "town")))


# --- drawing --------------------------------------------------------------------------------------

func _view() -> Dictionary:
	var r := hud.center_rect()
	var k := minf(r.size.x / SIZE.x, r.size.y / SIZE.y)
	return {"k": k, "o": r.get_center() - SIZE * k * 0.5}


func _to_screen(p: Vector2) -> Vector2:
	var v := _view()
	return v.o + p * float(v.k)


func _to_map(s: Vector2) -> Vector2:
	var v := _view()
	return (s - v.o) / float(v.k)


func _draw() -> void:
	var v := _view()
	var k := float(v.k)
	draw_rect(Rect2(v.o, SIZE * k), MEADOW)
	_draw_land(k)
	for p: Dictionary in Db.world_paths:
		if not (TravelRules.visible(Db.world_nodes, p.from, Game.meta.flags) and TravelRules.visible(Db.world_nodes, p.to, Game.meta.flags)):
			continue
		var open := String(_node(p.to).open) == "1" and String(_node(p.from).open) == "1"
		_draw_path(TravelRules.parse_points(p.points), k, open)
	if walking():
		var lp := leg()
		var pts: PackedVector2Array = lp.points
		for s: float in Game.travel.stops:
			_draw_stop(_to_screen(TravelRules.point_at(pts, s / float(lp.seconds))), k)
	for id in Db.world_nodes:
		if TravelRules.visible(Db.world_nodes, id, Game.meta.flags):
			_draw_node(id, k)
	_draw_party(k)
	if _note_time > 0.0:
		var at := _to_screen(party_pos()) + Vector2(0, -46 * k)
		_label(at, _note, 13, Color(1, 1, 1, minf(1.0, _note_time)))


## The ground around the places: the snow range north, the prairie north-east, the dark woods north-west.
func _draw_land(k: float) -> void:
	for i in 9:  # meadow patches
		var c := Vector2(90 + i * 107, 470 + 60 * sin(i * 1.7))
		draw_colored_polygon(_blob(_to_screen(c), 70 * k, 26 * k, i), MEADOW_DARK)
	# Prairie: flat stripes.
	for i in 6:
		var y := 250.0 + i * 30.0
		var a := _to_screen(Vector2(700 + i * 10, y))
		var b := _to_screen(Vector2(1000, y + 10))
		draw_rect(Rect2(a, Vector2(b.x - a.x, 16 * k)), PRAIRIE if i % 2 == 0 else PRAIRIE.darkened(0.06))
	# Mountains: a row of flat peaks with snow caps across the north.
	for i in 11:
		var x := 40.0 + i * 92.0
		var h := 150.0 + 70.0 * absf(sin(i * 1.3)) + (90.0 if absf(x - 500) < 140 else 0.0)
		var base := 175.0 + 20.0 * sin(i * 2.1)
		_peak(Vector2(x, base), 85.0, h, k)
	# Woods to the north-west.
	for i in 22:
		var c := Vector2(60 + (i % 6) * 42 + (i / 6) * 18, 230 + (i / 6) * 38 + 8 * sin(i * 1.9))
		_pine(_to_screen(c), k * (0.8 + 0.3 * absf(sin(i * 2.7))))


func _peak(base: Vector2, half: float, h: float, k: float) -> void:
	var l := _to_screen(base + Vector2(-half, 0))
	var r := _to_screen(base + Vector2(half, 0))
	var top := _to_screen(base + Vector2(0, -h))
	draw_colored_polygon(PackedVector2Array([l, top, _to_screen(base)]), ROCK)
	draw_colored_polygon(PackedVector2Array([_to_screen(base), top, r]), ROCK_DARK)
	var cap := 0.32
	var cl := top.lerp(l, cap)
	var cr := top.lerp(r, cap)
	var mid := top.lerp(_to_screen(base), cap * 0.8)
	draw_colored_polygon(PackedVector2Array([cl, top, cr, mid + Vector2(6 * k, 4 * k), mid, mid + Vector2(-8 * k, 6 * k)]), SNOW)


func _pine(p: Vector2, k: float) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(-12, 0) * k, p + Vector2(0, -34) * k, p + Vector2(12, 0) * k]), PINE)
	draw_rect(Rect2(p + Vector2(-2, 0) * k, Vector2(4, 6) * k), PINE.darkened(0.3))


func _draw_path(pts: PackedVector2Array, k: float, open: bool) -> void:
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var step := 18.0
	var n := int(total / step)
	for i in n + 1:
		var p := _to_screen(TravelRules.point_at(pts, float(i) / maxf(1.0, n)))
		if open:
			draw_circle(p, 5.0 * k + 1.0, ROAD)
		elif i % 2 == 0:
			draw_circle(p, 3.0 * k + 1.0, Color(ROAD, 0.45))


func _draw_stop(p: Vector2, k: float) -> void:
	draw_circle(p, 9 * k + 2, Color(0.95, 0.75, 0.3))
	_label(p + Vector2(0, 5 * k), "?", 14, INK)


func _draw_node(id: String, k: float) -> void:
	var n := _node(id)
	var p := _to_screen(_node_pos(id))
	var open := String(n.open) == "1"
	var here := id == String(Game.travel.get("at", "")) and not walking()
	var r := 22.0 * k + 4.0
	draw_circle(p + Vector2(2, 3), r, Color(0, 0, 0, 0.18))
	draw_circle(p, r, Color(0.98, 0.94, 0.82) if open else Color(0.75, 0.73, 0.68))
	draw_arc(p, r, 0, TAU, 32, INK if open else Color(INK, 0.4), 3.0 if (here or _hover == id) else 2.0, true)
	match String(n.kind):
		"town":
			for o: Vector2 in [Vector2(-9, 4), Vector2(6, 2)]:
				var b := p + o * k
				draw_rect(Rect2(b + Vector2(-6, -8) * k, Vector2(12, 10) * k), Color(0.8, 0.55, 0.4))
				draw_colored_polygon(PackedVector2Array([b + Vector2(-8, -8) * k, b + Vector2(0, -16) * k, b + Vector2(8, -8) * k]), Color(0.55, 0.3, 0.3))
		"peak":
			draw_colored_polygon(PackedVector2Array([p + Vector2(-15, 10) * k, p + Vector2(0, -14) * k, p + Vector2(15, 10) * k]), ROCK)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-6, -4) * k, p + Vector2(0, -14) * k, p + Vector2(6, -4) * k]), SNOW)
		"plain":
			for i in 3:
				draw_line(p + Vector2(-10 + i * 10, 8) * k, p + Vector2(-12 + i * 10, -6) * k, Color(0.6, 0.55, 0.25), 2.0)
		"wood":
			_pine(p + Vector2(0, 10) * k, k * 0.7)
		"far":
			for i in 3:
				draw_circle(p + Vector2(-8 + i * 8, 2) * k, 2.5 * k + 1.0, Color(INK, 0.6))
	if TravelRules.cleared(n, Game.meta.flags):
		# Done: a gold seal on the rim, like a cleared level on an old console map.
		var b := p + Vector2(r * 0.72, -r * 0.72)
		draw_circle(b, 9.0 * k + 2.0, Color(0.95, 0.75, 0.25))
		draw_arc(b, 9.0 * k + 2.0, 0, TAU, 20, INK, 1.5, true)
		draw_polyline(PackedVector2Array([b + Vector2(-4, 0) * k, b + Vector2(-1, 3.5) * k, b + Vector2(4.5, -4) * k]), INK, 2.0, true)
	if not open:
		_label(p + Vector2(0, 6), "?", 22, Color(INK, 0.7))
	_label(p + Vector2(0, r + 18), Txt.t(n.name_key), 13, INK if open else Color(INK, 0.55))


## The party in miniature: the leader in front, the others a step behind on the path.
func _draw_party(k: float) -> void:
	var members := Game.run.alive()
	for i in range(members.size() - 1, -1, -1):
		var at := party_pos()
		if walking():
			var lp := leg()
			at = TravelRules.point_at(lp.points, maxf(0.0, float(Game.travel.t) / float(lp.seconds) - 0.02 * i))
		else:
			at += Vector2(-16 * i, 6 * i)
		var p := _to_screen(at) + Vector2(0, -6 * k)
		var hop := absf(sin(_time * 9.0 + i)) * 4.0 if walking() and not _busy else 0.0
		var d: CharacterDef = members[i].def
		var small := d.id == &"dog"
		var s := (0.65 if small else 1.0) * k
		p.y -= hop
		draw_circle(p + Vector2(0, 14 * s + hop), 7 * s, Color(0, 0, 0, 0.2))
		draw_rect(Rect2(p + Vector2(-6, -4) * s, Vector2(12, 16) * s), d.tint)
		draw_circle(p + Vector2(0, -10) * s, 7 * s, d.tint.lightened(0.25))
		draw_arc(p + Vector2(0, -10) * s, 7 * s, 0, TAU, 16, INK, 1.5, true)


func _label(p: Vector2, text: String, size: int, col: Color) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
	draw_string_outline(font, p - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(1, 1, 1, col.a * 0.7))
	draw_string(font, p - Vector2(w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


static func _blob(c: Vector2, rx: float, ry: float, seed_v: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * i / 18.0
		var w := 1.0 + 0.12 * sin(a * 3.0 + seed_v)
		pts.append(c + Vector2(cos(a) * rx * w, sin(a) * ry * w))
	return pts


# --- hud --------------------------------------------------------------------------------------------

func _side() -> void:
	hud.clear_side()
	hud.top_label.text = Txt.t("UI_OW_TITLE")
	_info = hud.add_side_label("", 14)
	if walking():
		hud.add_button(Txt.t("UI_OW_FAST"), fast_forward)
		hud.add_button(Txt.t("UI_OW_HUNT"), act.bind("hunt"))
		hud.add_button(Txt.t("UI_OW_FISH"), act.bind("fish"))
		hud.add_button(Txt.t("UI_OW_FORAGE"), act.bind("forage"))
		hud.add_button(Txt.t("UI_OW_TALK"), talk)
	else:
		var n := _node(String(Game.travel.get("at", "town")))
		if String(n.get("map", "")) != "":
			hud.add_button(Txt.f("UI_OW_ENTER", Txt.t(n.name_key)), _enter)
	hud.add_side_label(Txt.t("UI_OW_HELP"), 11)
	_log_label = hud.add_side_label("", 12)
	_refresh_side()


func _refresh_side() -> void:
	if _info == null:
		return
	if walking():
		var lp := leg()
		var then: Array = Game.travel.get("then", [])
		var goal := String(then.back()) if not then.is_empty() else String(Game.travel.to)
		_info.text = Txt.f("UI_OW_WALKING", [Txt.t(_node(goal).name_key), int(100.0 * float(Game.travel.t) / float(lp.seconds))])
	else:
		_info.text = Txt.f("UI_OW_AT", Txt.t(_node(String(Game.travel.get("at", "town"))).name_key))
	_log_label.text = "\n".join(Game.run.lines.slice(-8))


func _refresh_hud() -> void:
	hud.set_party(FrameHud.party_entries_from_run(Game.run))
	hud.set_pack(Game.run.pack)
	var tools := [{"text": Txt.t("UI_PACK"), "cb": _open_menu.bind("pack")}]
	if Game.has_flag("has_lodestone"):
		tools.append({"text": Txt.t("UI_LODESTONE"), "cb": _open_menu.bind("lodestone"), "glow": Game.pending_picks() > 0})
	hud.set_tools(tools)
	_refresh_side()


func _open_menu(which: String) -> void:
	if _busy and not _menu_open:
		return
	_busy = true
	_menu_open = true
	var box := _new_dialog("")
	var changed := func() -> void:
		Game.refresh_party()
		_refresh_hud()
		_open_menu(which)
	var close := func() -> void:
		_menu_open = false
		_close_dialog()
	if which == "pack":
		AdventureMenu.pack(box, changed, close)
	else:
		AdventureMenu.lodestone(box, changed, close)


func _new_dialog(text: String) -> VBoxContainer:
	if _dialog:
		_dialog.queue_free()
	_dialog = PanelContainer.new()
	_dialog.add_theme_stylebox_override("panel", Battle._panel_style(Color(0.1, 0.12, 0.12, 0.96)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_dialog.add_child(box)
	if text != "":
		var l := Label.new()
		l.text = text
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(420, 0)
		l.add_theme_font_size_override("font_size", 16)
		box.add_child(l)
	_ui.add_child(_dialog)
	var r := hud.center_rect()
	_dialog.position = Vector2(r.get_center().x - 230, r.position.y + 24)
	return box


func _button(box: VBoxContainer, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(420, 30)
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(cb)
	box.add_child(b)


func _close_dialog() -> void:
	if _dialog:
		_dialog.queue_free()
		_dialog = null
	_busy = false
	_refresh_hud()

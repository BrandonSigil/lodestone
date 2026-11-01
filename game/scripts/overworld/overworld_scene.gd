extends Node2D
## The overworld is the hex world map ([USER] 2026-11-01, card pm-world-paths): Brandon's twelve explorable tiles as
## raised hex blocks on the 2:1 camera, and the route through them is free: any tile leads on to the tiles that share an
## edge with it. Click a tile to walk there: the party's mini pieces walk the leg in real time (about a minute), with an
## encounter or two on the way. Meanwhile the player can hunt, fish, forage, talk, camp or open the pack; >> jumps to
## the next encounter, or to the end of the leg. The party eats at camp each journey day.
##
## Drawn in code in the flat graybox look until art. Data: data/overworld_nodes.csv (tiles: col, row, height, open,
## map), data/overworld_paths.csv (the shared edges: seconds, encounter counts, the fight tile set),
## data/travel_events.csv (encounters, events.csv format). Rules and hex geometry: TravelRules. State: Game.travel.

const SIZE := Vector2(1000, 700)  ## map units the tiles are laid out in (TravelRules.HEX_ORIGIN); the view fits their bounds
const BACK := Color(0.86, 0.85, 0.79)  ## the cream round the tiles (the guide's paper)
const GREY := Color(0.8, 0.8, 0.77)  ## a tile's top before its land's tint
const SNOW := Color(0.93, 0.95, 0.97)
const ROCK := Color(0.47, 0.5, 0.58)
const PINE := Color(0.2, 0.34, 0.3)
const ROAD := Color(0.93, 0.86, 0.66)
const INK := Color(0.2, 0.22, 0.3)
## A light wash of each land's colour over the grey top, so the tiles read apart before the painted art lands.
const KIND_TINT := {"town": Color(0.62, 0.74, 0.5), "wood": Color(0.36, 0.55, 0.4), "coast": Color(0.9, 0.84, 0.62),
	"ice": Color(0.72, 0.84, 0.92), "peak": Color(0.6, 0.62, 0.68), "mine": Color(0.5, 0.46, 0.44),
	"snow": Color(0.95, 0.96, 0.98), "plain": Color(0.86, 0.8, 0.5), "grass": Color(0.66, 0.78, 0.6),
	"city": Color(0.76, 0.7, 0.66)}

var hud: FrameHud
var _ui: CanvasLayer
var _dialog: PanelContainer
var _info: Label
var _log_label: Label
var _busy := false  ## a box is up: the clock stops
var _menu_open := false
var _menu_which := ""  ## the open menu: "pack", "lodestone", ...
var _menu_close := Callable()
var _time := 0.0
var _hover := ""
var _elites := {}  ## place id -> elite groups still standing on its maps (the red badge)
var _note := ""  ## a short line under the party (PATH SHUT, a talk line)
var _note_time := 0.0
var _rng := RandomNumberGenerator.new()
var _weather: MapWeather
const SNOW_REACH := 190.0  ## map units round a snowy place that the snow falls over


func _ready() -> void:
	for id in Db.world_nodes:
		_elites[id] = ExploreRules.elites_left(Array(String(Db.world_nodes[id].maps).split("|")), Game.meta.flags)
	Game.ensure_run()
	Game.refresh_party()
	_rng.randomize()  # talk lines only; encounters roll on the run's dice
	if not Game.travel.has("at") and not Game.travel.has("to"):
		Game.travel = {"at": "town"}
	for k in ["at", "from", "to"]:  # a save from before the hex map may stand on a place that is gone
		if Game.travel.has(k) and not Db.world_nodes.has(String(Game.travel[k])):
			Game.travel = {"at": "town"}
			break
	_weather = MapWeather.new()  # snow round the snowy places ([USER] 2026-10-30, ambience)
	add_child(_weather)
	_weather.setup("snow" if Db.world_nodes.values().any(func(n: Dictionary) -> bool: return String(n.get("weather", "")) == "snow") else "",
		get_viewport().get_visible_rect(), 7)
	hud = FrameHud.new()
	add_child(hud)
	hud.use_leaf_frame()
	_ui = CanvasLayer.new()
	_ui.layer = 4
	add_child(_ui)
	_side()
	_refresh_hud()
	get_viewport().size_changed.connect(queue_redraw)
	Game.bookmarked.connect(hud.flash_saved)
	Game.counts.connect(_say)
	bookmark.call_deferred()


## The bookmark ([USER] omr-11): the walk as it stands, mid-leg included (Game.travel).
func bookmark() -> void:
	Game.bookmark({"scene": "overworld", "fight": {}})


# --- the clock ------------------------------------------------------------------------------------

func walking() -> bool:
	return Game.travel.has("to")


func leg() -> Dictionary:
	return TravelRules.path_between(Db.world_paths, String(Game.travel.get("from", "")), String(Game.travel.get("to", "")))


func _process(delta: float) -> void:
	_time += delta
	_weather.mask = []  # only over the places whose `weather` is snow (data/overworld_nodes.csv)
	for id in Db.world_nodes:
		var n: Dictionary = Db.world_nodes[id]
		if String(n.get("weather", "")) == "snow":
			var c := _to_screen(_node_pos(id))
			_weather.mask.append(Vector3(c.x, c.y, SNOW_REACH * float(_view().k)))
	_note_time = maxf(0.0, _note_time - delta)
	if not _busy and _dialog == null and Game.run.overfull():
		_open_menu("pack")  # a pickup found no room: the player decides before walking on
	if walking() and not _busy:
		_advance_to(float(Game.travel.t) + delta)
	queue_redraw()


## Walk the clock forward to t1: journey days on the way, then an encounter or the arrival if one is reached.
func _advance_to(t1: float) -> void:
	var tr := Game.travel
	var seconds := float(leg().get("seconds", 60))
	var stop := TravelRules.next_stop(float(tr.t), tr.stops, seconds)
	t1 = minf(t1, stop)
	var rest := float(tr.get("rest", 0.0))  # time spent at camp still counts toward journey days
	if not _nights(TravelRules.days_between(float(tr.t) + rest, t1 + rest)):
		return  # the larder ran out: the journey is over
	if Game.trickle(maxf(0.0, t1 - float(tr.t)), "trickle_seconds"):
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
	bookmark()
	Game.save_adventure()
	if not then.is_empty():
		_say(Txt.f("UI_OW_PASSING", Txt.t(_node(to).name_key)))
		_start_leg(String(then[0]), then.slice(1))
		return
	_side()
	_busy = true
	var has_map := map_ready(to)
	var text := Txt.f("UI_OW_ARRIVED", Txt.t(_node(to).name_key))
	if not has_map and String(_node(to).get("map", "")) != "":  # named in data, not built yet (the map builder's)
		text = Txt.f("UI_OW_NO_MAP_YET", Txt.t(_node(to).name_key))
	elif not has_map:
		text += "\n" + Txt.t("UI_OW_NOTHING")
	var box := _new_dialog(text)
	if has_map:
		_button(box, Txt.f("UI_OW_ENTER", Txt.t(_node(to).name_key)), _enter)
	_button(box, Txt.t("UI_STAY_MAP"), _close_dialog)


## The tile's explore map exists (data/explore/<map>.json): forest roads and farmland wait for the map builder's.
func map_ready(id: String) -> bool:
	var m := String(_node(id).get("map", ""))
	return m != "" and FileAccess.file_exists("res://data/explore/%s.json" % m)


## Into the tile's explore map (the town at its gate, the highlands at the pass's foot).
func _enter() -> void:
	var at := String(Game.travel.get("at", "town"))
	var n := _node(at)
	if not map_ready(at):
		if String(n.get("map", "")) != "":
			_say(Txt.f("UI_OW_NO_MAP_YET", Txt.t(n.name_key)))
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
	var boon_lines := Game.absorb_boons(fx)  # [USER] omr-7, omr-8: the road gives blessings and setbacks
	_refresh_hud()
	var lines: PackedStringArray = []
	if not fx.check.is_empty():
		lines.append("%s  %s" % [Txt.t("CHECK_" + String(o.check).to_upper()), Dice.describe(fx.check)])
		lines.append(Txt.t("UI_EX_WIN") if fx.success else Txt.t("UI_EX_LOSE"))
	var shown := String(o.win if fx.success else o.lose)
	if shown != "" and fx.combat == "":
		lines.append(shown.replace(";", "  "))
	lines.append_array(boon_lines)
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
	if kind == "fish":
		_go_fish()
		return
	acts[kind] = t
	var r := TravelRules.activity(Game.run, kind)
	_say(Txt.t("UI_EX_WIN") if r.success else Txt.t("UI_EX_LOSE"))
	_refresh_hud()


## FISH on the road ([USER] 2026-11-01): the fishing minigame; the road clock stops while it's up. Leaving
## before the cast doesn't start the cooldown.
var fishing: FishingGame


func _go_fish() -> void:
	if not TravelRules.can_try(Game.run, "fish"):
		_say(Txt.t("UI_OW_NO_ROD"))
		return
	_busy = true
	fishing = FishingGame.open(self, "road", FishingRules.mods_for(Game.run))
	fishing.finished.connect(func(res: Dictionary) -> void:
		fishing = null
		_busy = false
		if String(res.outcome) == "left":
			_refresh_hud()
			return
		Game.travel.acts["fish"] = float(Game.travel.t)
		if String(res.outcome) == "caught":
			var got := Game.land_fish(res.fish)
			_say((Txt.t("UI_FISH_NEW") + " " if got.new else "") + Txt.f("UI_FISH_GOT_KIND", Txt.t(String(res.fish.name_key))))
		else:
			_say(Txt.t("UI_FISH_NONE"))
		_refresh_hud())


## Each journey day on the road ends at camp with a meal ([USER] 2026-11-01: "The party must eat every day at camp, no
## food= journeys over"): everyone's portions come out of the pack, then the day counts for morale. With too little food
## the journey ends (Game.larder_empty) and this returns false.
func _nights(days: int) -> bool:
	for i in days:
		if not TravelRules.eat(Game.run):
			Game.larder_empty()
			return false
		Game.pass_days(1)
		_refresh_hud()
	return true


## MAKE CAMP ([USER] omr-9): once a leg. The party stands still a while (the road clock runs on, meals included), can
## cook a meal it carries (buff, heal and morale) and can rest for free (mana, some HP, morale).
func make_camp() -> void:
	if not walking() or _busy or Game.travel.get("camped", false):
		return
	var tr := Game.travel
	var rest := float(tr.get("rest", 0.0))
	var camp := float(Db.levels.get("camp_seconds", 20))
	if not _nights(TravelRules.days_between(float(tr.t) + rest, float(tr.t) + rest + camp)):
		return
	tr["rest"] = rest + camp
	tr["camped"] = true
	_busy = true
	var box := _new_dialog(Txt.t("UI_CAMP"))
	var meals := Game.run.items.keys().filter(func(id: String) -> bool: return String(Db.items[id].kind) == "meal")
	if meals.is_empty():
		var l := Label.new()
		l.text = Txt.t("UI_CAMP_NO_MEAL")
		box.add_child(l)
	for id: String in meals:
		var b := Button.new()
		b.text = Txt.f("UI_COOK", Txt.t(String(Db.items[id].name_key)))
		b.pressed.connect(func() -> void:
			Game.eat_meal(id)
			_say(Txt.t("UI_CAMP_ATE"))
			_close_dialog()
			_side())
		box.add_child(b)
	var rest_btn := Button.new()  # a rest: all mana and charges, some HP, morale; free (no hunger)
	rest_btn.text = Txt.t("UI_CAMP_REST")
	rest_btn.pressed.connect(func() -> void:
		if Game.camp_rest():
			_say(Txt.t("UI_CAMP_RESTED"))
		_close_dialog()
		_refresh_hud()
		_side())
	box.add_child(rest_btn)
	if Game.run.item_count("tonic") > 0:
		var tonic := Button.new()
		tonic.text = Txt.t("UI_CAMP_TONIC")
		tonic.pressed.connect(func() -> void:
			if Game.tonic_effect():
				Game.run.add_item("tonic", -1)
				_say(Txt.t("UI_CAMP_TONIC_DONE"))
			_close_dialog()
			_refresh_hud()
			_side())
		box.add_child(tonic)
	var go := Button.new()
	go.text = Txt.t("UI_CONTINUE")
	go.pressed.connect(func() -> void:
		_close_dialog()
		_side())
	box.add_child(go)
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
	elif event.pressed and not event.is_echo() and event.keycode == KEY_I:  # [USER] 2026-11-01: I opens and shuts the inventory
		if _menu_open and _menu_which == "pack":
			_menu_close.call()
		else:
			_open_menu("pack")
	elif event.pressed and not event.is_echo() and event.keycode == KEY_ESCAPE and _dialog != null:
		if UiTheme.press_close(_dialog):  # the open box's own close button
			get_viewport().set_input_as_handled()


func _click_node(id: String) -> void:
	if not TravelRules.visible(Db.world_nodes, id, Game.meta.flags):
		return
	if id == String(Game.travel.get("at", "")):
		_enter()
	elif not TravelRules.open_now(Db.world_nodes, id, Game.meta.flags):
		_say(Txt.t("UI_OW_CLOSED"))
	else:
		_start_leg(id)


func _node(id: String) -> Dictionary:
	return Db.world_nodes.get(id, {})


## The tile under a map point: its top face, nearest first (a front tile covers the one behind it).
func _node_at(p: Vector2) -> String:
	var order := _back_to_front()
	order.reverse()
	for id in order:
		if Geometry2D.is_point_in_polygon(p, TravelRules.tile_top(_node(id), 0.0)):
			return id
	return ""


func _node_pos(id: String) -> Vector2:
	return TravelRules.tile_pos(_node(id))


## Tile ids from the back row to the front, so nearer blocks draw over the ones behind.
func _back_to_front() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(Db.world_nodes.keys())
	ids.sort_custom(func(a: String, b: String) -> bool:
		return TravelRules.hex_ground(int(_node(a).col), int(_node(a).row)).y < TravelRules.hex_ground(int(_node(b).col), int(_node(b).row)).y)
	return ids


## Where the party stands, in map units.
func party_pos() -> Vector2:
	if walking():
		var p := leg()
		return TravelRules.point_at(p.points, float(Game.travel.t) / float(p.seconds))
	return _node_pos(String(Game.travel.get("at", "town")))


# --- drawing --------------------------------------------------------------------------------------

## Map units to the screen: the tiles' bounds fitted into the room above the frame, left of the side box.
func _view() -> Dictionary:
	var r := hud.clear_rect().grow(-24.0)
	r.size.x -= FrameHud.RIGHT_W
	var b := _bounds()
	var k := minf(r.size.x / b.size.x, r.size.y / b.size.y)
	return {"k": k, "o": r.get_center() - (b.position + b.size * 0.5) * k}


var _bounds_cache := Rect2()


## Every tile's top and base, map units, with room under the front row for its name.
func _bounds() -> Rect2:
	if _bounds_cache.has_area():
		return _bounds_cache
	var b := Rect2()
	var first := true
	for id in Db.world_nodes:
		var n := _node(id)
		for c in TravelRules.tile_top(n, 0.0):
			for p in [c, c + Vector2(0, TravelRules.HEX_LEVEL * int(n.height) + 20.0)]:
				b = Rect2(p, Vector2.ZERO) if first else b.expand(p)
				first = false
	_bounds_cache = b.grow_individual(0, 0, 0, 10)
	return _bounds_cache


func _to_screen(p: Vector2) -> Vector2:
	var v := _view()
	return v.o + p * float(v.k)


func _to_map(s: Vector2) -> Vector2:
	var v := _view()
	return (s - v.o) / float(v.k)


func _draw() -> void:
	var v := _view()
	var k := float(v.k)
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), BACK)  # [USER] 2026-10-29: the game fills the window
	for id in _back_to_front():
		_draw_tile(id, k)
	for p: Dictionary in Db.world_paths:  # a road on every shared edge whose two tiles are both open now
		if TravelRules.open_now(Db.world_nodes, p.from, Game.meta.flags) and TravelRules.open_now(Db.world_nodes, p.to, Game.meta.flags):
			_draw_path(PackedVector2Array([_node_pos(p.from), _node_pos(p.to)]), k)
	if walking():
		var lp := leg()
		var pts: PackedVector2Array = lp.points
		for st: float in Game.travel.stops:
			_draw_stop(_to_screen(TravelRules.point_at(pts, st / float(lp.seconds))), k)
	for id in Db.world_nodes:
		_draw_marks(id, k)
	_draw_party(k)
	if _note_time > 0.0:
		var at := _to_screen(party_pos()) + Vector2(0, -46 * k)
		_label(at, _note, 13, Color(1, 1, 1, minf(1.0, _note_time)))


## One tile as a raised hex block: the three faces toward the viewer, then the top, washed with its land's colour.
## A shut tile is darker and plain grey.
func _draw_tile(id: String, k: float) -> void:
	var n := _node(id)
	var open := TravelRules.open_now(Db.world_nodes, id, Game.meta.flags)
	var top := PackedVector2Array()
	for c in TravelRules.tile_top(n):
		top.append(_to_screen(c))
	var drop := (TravelRules.HEX_LEVEL * int(n.height) + 20.0) * k
	var ring := PackedVector2Array()
	for c in top:
		ring.append(c + Vector2(0, drop))
	var tint: Color = KIND_TINT.get(String(n.kind), GREY)
	var face := GREY.lerp(tint, 0.55) if open else GREY.darkened(0.28)
	var hot := _hover == id or (id == String(Game.travel.get("at", "")) and not walking())
	for side in [[0, 1, 0.3], [1, 2, 0.22], [2, 3, 0.14]]:  # corners 0..3 run clockwise from the right: the near half
		var a: int = side[0]
		var b: int = side[1]
		var quad := PackedVector2Array([top[a], top[b], ring[b], ring[a]])
		draw_colored_polygon(quad, face.darkened(float(side[2])))
		draw_polyline(PackedVector2Array([top[a], ring[a], ring[b], top[b]]), INK, 1.5, true)
	draw_colored_polygon(top, face.lightened(0.12 if hot and open else 0.0))
	var outline := top.duplicate()
	outline.append(top[0])
	draw_polyline(outline, INK, 3.0 if hot else 2.0, true)


## A tile's glyph, its badges and its name, on its top face.
func _draw_marks(id: String, k: float) -> void:
	var n := _node(id)
	var p := _to_screen(_node_pos(id))
	var open := TravelRules.open_now(Db.world_nodes, id, Game.meta.flags)
	var ink := INK if open else Color(INK, 0.5)
	match String(n.kind) if open else "shut":  # a shut tile shows only its "?"
		"town":
			for o: Vector2 in [Vector2(-9, 4), Vector2(6, 2)]:
				var b := p + o * k
				draw_rect(Rect2(b + Vector2(-6, -8) * k, Vector2(12, 10) * k), Color(0.8, 0.55, 0.4))
				draw_colored_polygon(PackedVector2Array([b + Vector2(-8, -8) * k, b + Vector2(0, -16) * k, b + Vector2(8, -8) * k]), Color(0.55, 0.3, 0.3))
		"peak", "mine", "snow":
			draw_colored_polygon(PackedVector2Array([p + Vector2(-15, 10) * k, p + Vector2(0, -14) * k, p + Vector2(15, 10) * k]), ROCK)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-6, -4) * k, p + Vector2(0, -14) * k, p + Vector2(6, -4) * k]), SNOW)
		"plain", "grass":
			for i in 3:
				draw_line(p + Vector2(-10 + i * 10, 8) * k, p + Vector2(-12 + i * 10, -6) * k, Color(0.6, 0.55, 0.25), 2.0)
		"wood":
			for o: Vector2 in [Vector2(-10, 8), Vector2(8, 10)]:
				_pine(p + o * k, k * 0.7)
		"coast", "ice":
			for i in 2:
				draw_arc(p + Vector2(-6 + i * 12, 2) * k, 6 * k, PI, TAU, 8, Color(0.3, 0.45, 0.6), 2.0, true)
		"city":
			for i in 3:
				draw_rect(Rect2(p + Vector2(-13 + i * 9, -10 + (i % 2) * 4) * k, Vector2(7, 16 - (i % 2) * 4) * k), Color(0.55, 0.5, 0.48))
	if _elites.get(id, 0) > 0:  # [USER] pc-15: an elite fight waits here
		var e := p + Vector2(-34, -18) * k
		draw_circle(e, 9.0 * k + 2.0, Color(0.8, 0.22, 0.2))
		draw_arc(e, 9.0 * k + 2.0, 0, TAU, 20, INK, 1.5, true)
		_label(e + Vector2(0, 4), "!", 12, Color(1, 1, 1))
	if TravelRules.cleared(n, Game.meta.flags):  # done: a gold seal, like a cleared level on an old console map
		var b := p + Vector2(34, -18) * k
		draw_circle(b, 9.0 * k + 2.0, Color(0.95, 0.75, 0.25))
		draw_arc(b, 9.0 * k + 2.0, 0, TAU, 20, INK, 1.5, true)
		draw_polyline(PackedVector2Array([b + Vector2(-4, 0) * k, b + Vector2(-1, 3.5) * k, b + Vector2(4.5, -4) * k]), INK, 2.0, true)
	if not open:
		_label(p + Vector2(0, 8), "?", 22, Color(INK, 0.6))
	_label(p + Vector2(0, 40 * k), Txt.t(n.name_key), 13, ink)


func _pine(p: Vector2, k: float) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(-12, 0) * k, p + Vector2(0, -34) * k, p + Vector2(12, 0) * k]), PINE)
	draw_rect(Rect2(p + Vector2(-2, 0) * k, Vector2(4, 6) * k), PINE.darkened(0.3))


func _draw_path(pts: PackedVector2Array, k: float) -> void:
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var n := int(total / 18.0)
	for i in n + 1:
		draw_circle(_to_screen(TravelRules.point_at(pts, float(i) / maxf(1.0, n))), 4.0 * k + 1.0, ROAD)


func _draw_stop(p: Vector2, k: float) -> void:
	draw_circle(p, 9 * k + 2, Color(0.95, 0.75, 0.3))
	_label(p + Vector2(0, 5 * k), "?", 14, INK)


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


# --- hud --------------------------------------------------------------------------------------------

func _side() -> void:
	hud.clear_side()
	hud.top_label.text = Txt.t("UI_OW_TITLE")
	_info = hud.add_side_label("", 14)
	if walking():
		hud.add_button(Txt.t("UI_OW_FAST"), fast_forward)
		hud.add_button(Txt.t("UI_OW_HUNT"), act.bind("hunt"))
		var fish := hud.add_button(Txt.t("UI_OW_FISH"), act.bind("fish"))
		fish.disabled = not TravelRules.can_try(Game.run, "fish")  # no rod in the pack
		fish.tooltip_text = "" if not fish.disabled else Txt.t("UI_OW_NO_ROD")
		hud.add_button(Txt.t("UI_OW_FORAGE"), act.bind("forage"))
		hud.add_button(Txt.t("UI_OW_TALK"), talk)
		if not Game.travel.get("camped", false):
			hud.add_button(Txt.t("UI_OW_CAMP"), make_camp)
	else:
		var n := _node(String(Game.travel.get("at", "town")))
		if map_ready(String(Game.travel.get("at", "town"))):  # no GO IN until the tile's map is built
			hud.add_button(Txt.f("UI_OW_ENTER", Txt.t(n.name_key)), _enter)
	hud.add_help(Txt.t("UI_OW_HELP"))
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
	else:  # [USER] 2026-11-01 fewer words: the map marks where the party stands and GO IN names it, so no line here
		_info.text = ""
	_info.visible = _info.text != ""
	_log_label.text = "\n".join(Game.run.lines.slice(-8))


func _refresh_hud() -> void:
	hud.set_party(FrameHud.party_entries_from_run(Game.run))
	hud.set_pack(Game.run.pack)
	hud.set_goals(Game.goal_lines())
	var tools := [{"id": "pack", "text": Txt.t("UI_PACK"), "cb": _open_menu.bind("pack")}]
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
		_menu_which = ""
		_close_dialog()
	_menu_which = which
	_menu_close = close
	if which == "pack":
		AdventureMenu.pack(box, changed, close)
	elif which == "restore":
		AdventureMenu.restore_list(box, changed, close)
	elif which == "options":
		AdventureMenu.options(box, changed, _open_menu.bind("lodestone"))
	else:
		AdventureMenu.lodestone(box, changed, close, true, _open_menu.bind("restore"), _open_menu.bind("options"))


func _new_dialog(text: String) -> VBoxContainer:
	var fresh := _dialog == null  # a menu opening animates; one rebuilt in place does not
	if _dialog:
		_dialog.queue_free()
	_dialog = PanelContainer.new()
	_dialog.theme_type_variation = &"DialogPanel"
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
	var k := 1.0 if _menu_open else UiTheme.small()  # [USER] 2026-10-30: event dialogues about half size
	UiTheme.keep_inside(_dialog, hud.center_rect, k)  # never spills off the screen; shrinks to fit when it must
	if fresh:
		UiTheme.pop_in_later(_dialog)
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
		UiTheme.pop_out(_dialog)
		_dialog = null
	_busy = false
	_refresh_hud()

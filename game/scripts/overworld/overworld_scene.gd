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
var _acts: PanelContainer  ## the walk's actions (or GO IN), right above the diamond ([USER] 2026-11-01: one standard place)
var _acts_row: HBoxContainer
var _flash: Label  ## the newest roll or camp line, shown a moment in the same place
var _flash_t := 0.0
var _lines_seen := 0
var _busy := false  ## a box is up: the clock stops
var _menu_open := false
var _menu_which := ""  ## the open menu: "pack", "lodestone", ...
var _menu_close := Callable()
var _time := 0.0
var _hover := ""
var _mouse := Vector2(-999, -999)  ## the pointer on screen: a campsite tent under it says its name
var _elites := {}  ## place id -> elite groups still standing on its maps (the red badge)
var _note := ""  ## a short line under the party (PATH SHUT, a talk line)
var _note_time := 0.0
var _rng := RandomNumberGenerator.new()
var _weather: MapWeather
var _art: Texture2D  ## the painted world map under the tiles (Db.world_art), null for the graybox blocks
var _fog: Texture2D  ## parchment with soft clouds, drawn in code, laid over tiles not seen yet
const FOG_PAPER := Color(0.91, 0.86, 0.74)
const FOG_CLOUD := Color(0.98, 0.97, 0.93)
const PIECE := 1.6  ## the party pieces and badges on the painted map, against its picture-pixel scale
const SNOW_REACH := 190.0  ## map units round a snowy place that the snow falls over


func _ready() -> void:
	Sfx.music("road")
	for id in Db.world_nodes:
		_elites[id] = ExploreRules.elites_left(Array(String(Db.world_nodes[id].maps).split("|")), Game.flags_now())
	Game.ensure_run()
	Game.refresh_party()
	_rng.randomize()  # talk lines only; encounters roll on the run's dice
	if not Game.travel.has("at") and not Game.travel.has("to"):
		Game.travel = {"at": "town"}
	for k in ["at", "from", "to"]:  # a save from before the hex map may stand on a place that is gone
		if Game.travel.has(k) and not Db.world_nodes.has(String(Game.travel[k])):
			Game.travel = {"at": "town"}
			break
	if Db.world_art != "" and ResourceLoader.exists(Db.world_art) and Db.world_nodes.values().all(func(n: Dictionary) -> bool: return n.has("outline")):
		_art = load(Db.world_art)
		_fog = _cloud_paper()
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED  # the fog's clouds tile
	_discover(String(Game.travel.get("at", Game.travel.get("from", "town"))))
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
	if _flash != null:
		_flash_t = maxf(0.0, _flash_t - delta)
		_flash.modulate.a = clampf(_flash_t / 0.5, 0.0, 1.0)
		var r := hud.clear_rect()
		var above := _acts.global_position.y if _acts != null and _acts.visible else r.end.y - 20.0
		_flash.size = Vector2(r.size.x, 30)
		_flash.position = Vector2(r.position.x, above - 36.0)
	if _acts != null:
		_acts.visible = _dialog == null and _camp == null and not _menu_open and (_info.visible or _acts_row.get_child_count() > 0)
	if not _busy and _dialog == null and int(Game.travel.get("nights_due", 0)) > 0:
		_night()  # a night still owed (after a road fight, or MAKE CAMP's rest ran past nightfall)
	if not _busy and _dialog == null and _camp == null and Game.run.overfull():
		_open_menu("pack")  # a pickup found no room: the player decides before walking on
	if not is_instance_valid(_hint) and _dialog == null and not _menu_open and not _busy:  # one-time hints, one at a time
		_hint = Game.hint("walking" if walking() else "road", _ui, hud.clear_rect)
	if not walking():
		_fast = false
	elif not _busy and _dialog == null and _fast:
		_skip()
	elif not _busy:
		_advance_to(float(Game.travel.t) + delta)
	queue_redraw()


## Walk the clock forward to t1: journey days on the way, then an encounter or the arrival if one is reached.
func _advance_to(t1: float) -> void:
	if _sites():
		_advance_sites(t1)
		return
	var tr := Game.travel
	var seconds := float(leg().get("seconds", 60))
	var stop := TravelRules.next_stop(float(tr.t), tr.stops, seconds)
	t1 = minf(t1, stop)
	var rest := float(tr.get("rest", 0.0))  # time spent at camp still counts toward journey days
	var days := TravelRules.days_between(float(tr.t) + rest, t1 + rest)
	if days > 0:  # each journey day ends at camp: the night's meal waits for the player's picks
		tr["nights_due"] = int(tr.get("nights_due", 0)) + days
	if Game.trickle(maxf(0.0, t1 - float(tr.t)), "trickle_seconds"):
		_refresh_hud()
	tr.t = t1
	var then := Callable()
	if t1 >= stop - 0.001:
		if stop >= seconds:
			then = _arrive
		else:
			tr.stops.erase(stop)
			then = _encounter
	if int(tr.get("nights_due", 0)) > 0:
		_night(then)  # the camp first; the arrival or the encounter after it
	elif then.is_valid():
		then.call()
	_refresh_side()


## Campsites on the map ([USER] 2026-11-16 "A to C is great", option C; Options NIGHT CAMPS picks it or option A).
func _sites() -> bool:
	return CampRules.style(Game.meta.get("settings", {})) == CampRules.SITES


## The clock with campsites: the day's light runs down as the party walks (`since`, carried from leg to leg); each
## campsite on the leg stops the walk and asks CAMP HERE or WALK ON (one reached soon after a camp is passed); if the
## light runs out first, the party makes a rough camp by the road (data/campsites.csv `dark`).
func _advance_sites(t1: float) -> void:
	var tr := Game.travel
	var seconds := float(leg().get("seconds", 60))
	var stop := TravelRules.next_stop(float(tr.t), tr.stops, seconds)
	var since := float(tr.get("since", 0.0))
	var dusk := float(tr.t) + maxf(0.0, TravelRules.DAY_SECONDS - since)
	var sites: Array = tr.get("sites", [])
	var passed: Array = tr.get("passed", [])
	var si := CampRules.next_site(sites, float(tr.t), passed)
	var site_t := float(sites[si].t) if si >= 0 else INF
	t1 = minf(t1, minf(stop, minf(dusk, site_t)))
	if Game.trickle(maxf(0.0, t1 - float(tr.t)), "trickle_seconds"):
		_refresh_hud()
	tr["since"] = since + maxf(0.0, t1 - float(tr.t))
	tr.t = t1
	var then := Callable()
	if t1 >= stop - 0.001:
		if stop >= seconds:
			then = _arrive
		else:
			tr.stops.erase(stop)
			then = _encounter
	if t1 >= dusk - 0.001:
		_night(then, Db.campsites.get(CampRules.DARK, {}))  # the light ran out on the road
	elif then.is_valid():
		then.call()  # an encounter on the same spot as a campsite comes first; the campsite asks next
	elif si >= 0 and t1 >= site_t - 0.001:
		passed.append(si)
		tr["passed"] = passed
		_at_site(Db.campsites.get(String(sites[si].id), {}))
	_refresh_side()


## A campsite on the road: CAMP HERE or WALK ON, with what it gives and the light left.
func _at_site(row: Dictionary) -> void:
	if row.is_empty():
		return
	var name := Txt.t(String(row.name_key))
	if not CampRules.ask_at(float(Game.travel.get("since", 0.0))):
		_say(Txt.f("CAMP_SITE_PASSED", name))  # just camped: walked past
		return
	_busy = true
	var box := _new_dialog("%s\n%s\n%s" % [Txt.f("CAMP_SITE_ASK", name), Txt.t(String(row.tip_key)), _dusk_text()])
	_button(box, Txt.t("CAMP_HERE"), func() -> void:
		_close_dialog()
		_night(Callable(), row))
	_button(box, Txt.t("CAMP_WALK_ON"), _close_dialog)


## "Dusk in 5 h": the day's light left, as hours of a 12-hour day.
func _dusk_text() -> String:
	var h := ceili(CampRules.daylight(float(Game.travel.get("since", 0.0))) * 12.0)
	return Txt.t("CAMP_DUSK_SOON") if h <= 1 else Txt.f("CAMP_DUSK_IN", h)


## Walk to a place: leg by leg along the route, past cleared places on the way. then: the places still to go
## after this one.
func _start_leg(to: String, then: Array = []) -> void:
	var at := String(Game.travel.get("at", "town"))
	var p := TravelRules.path_between(Db.world_paths, at, to)
	if p.is_empty():
		var way := TravelRules.route(Db.world_paths, Db.world_nodes, at, to, Game.flags_now())
		if way.size() < 2:
			_say(Txt.t("UI_OW_CLOSED"))
			return
		_start_leg(way[1], way.slice(2))
		return
	var stops := TravelRules.plan(Game.run.rng, float(p.seconds), int(p.enc_min), int(p.enc_max))
	var since := float(Game.travel.get("since", 0.0))  # the day's light carries on from the last leg
	Game.travel = {"from": at, "to": to, "t": 0.0, "stops": stops, "acts": {}, "then": then, "since": since,
		"sites": CampRules.leg_sites(p, at), "passed": []}
	_side()


func _arrive() -> void:
	var to := String(Game.travel.to)
	var then: Array = Game.travel.get("then", [])
	Game.travel = {"at": to, "since": float(Game.travel.get("since", 0.0))}
	Game.set_flag("visited_" + to)  # GoalRules: places reached (visited_pass)
	_discover(to)
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


## FAST (Tab) skips to the next stop and stays on until the walk ends, so each event or camp doesn't drop it
## (2026-11-13 playtest). Press it again to walk at normal speed.
var _fast := false
var _hint: HintToast  ## the one-time hint showing (GoalRules.HINTS: road, walking)


func fast_forward() -> void:
	if not walking():
		return
	_fast = not _fast
	_side()
	if _fast and not _busy:
		_skip()


func _skip() -> void:
	_advance_to(TravelRules.next_stop(float(Game.travel.t), Game.travel.stops, float(leg().get("seconds", 60))))


# --- encounters ---------------------------------------------------------------------------------

func _encounter() -> void:
	var ev := TrailRules.first_event(Db.travel_events, Game.flags_now())  # the first trip's fair, scripted fight
	if ev.is_empty():
		ev = TrailRules.pick_event(Game.run, Db.travel_events, Game.flags_now(), [String(Game.travel.get("from", "")), String(Game.travel.get("to", ""))])
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
	if TrailRules.gains_text(shown) != "" and fx.combat == "":
		lines.append(TrailRules.gains_text(shown))  # by name, never the raw effect string (backlog X1)
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


# --- the campfire ---------------------------------------------------------------------------------

## The night's camp is the campfire ([USER] 2026-11-16, option A of docs/design/campfire-trail.md): one screen where
## the party eats from one pot on a ration dial and spends the evening (cook, fish, hunt, forage, talk, mend, rest).
## It replaces the road's HUNT, FISH, FORAGE, TALK and MAKE CAMP and the old per-member meal picker ([USER] 2026-11-16:
## one pot replaces picking each member's food). With "Every night the same" on, a night repeats last night's plan
## without the screen while the pot can feed everyone. then: what the clock reached on the way (the arrival or an
## encounter), run once the nights are slept.
var _camp: CampScreen


## site: the campsite row (option C), {} for a camp wherever the day ended (option A).
func _night(then := Callable(), site: Dictionary = {}) -> void:
	_busy = true
	Sfx.play("camp")
	var settings: Dictionary = Game.meta.get("settings", {})
	var r := CampRules.ration(Db.camp_rations, String(settings.get("camp_ration", CampRules.FILLING)))
	if bool(settings.get("auto_camp", false)) and not (settings.get("camp_plan", []) as Array).is_empty() \
			and Game.run.portions() >= CampRules.pot_need(Game.run, r):
		var lines := CampScreen.repeat_plan(settings, site)
		lines.append_array(Game.camp_eat(String(r.id)))
		lines.append_array(Game.camp_site_morale(int(site.get("morale", 0))))
		lines.append(Txt.t("CAMP_AUTO_DONE"))
		_after_camp(lines, then)
		return
	var nights: Dictionary = Game.meta.get("trip_nights", {})
	var pond := "road/" + String(Game.travel.get("at", Game.travel.get("to", "road")))
	_camp = CampScreen.open(_ui, hud.clear_rect, hud.bar_rect, pond, int(nights.get(str(int(Game.meta.trips)), 0)) + 1, site)
	_camp.slept.connect(_after_camp.bind(then))
	_camp.changed.connect(_refresh_hud)
	_refresh_hud()
	if is_instance_valid(_hint):  # a one-time map hint waits under the fire
		_hint.visible = false
	_refresh_side()


## A night slept: its lines, everyone Spent carried home, else the night ends.
func _after_camp(lines: PackedStringArray, then: Callable) -> void:
	_camp = null
	if is_instance_valid(_hint):
		_hint.visible = true
	for l in lines:
		Game.run.note(l)
	if not lines.is_empty():
		_say(lines[lines.size() - 1])
	if Game.all_spent():  # everyone at 0: the party is carried home ([USER] 2026-11-02)
		_close_dialog()
		Game.party_spent()
		return
	_end_night(then)


## A night eaten: the day counts (morale for whoever is home), and the next night owed or what the clock reached.
func _end_night(then: Callable) -> void:
	var tr := Game.travel
	tr["nights_due"] = maxi(0, int(tr.get("nights_due", 0)) - 1)
	tr["since"] = 0.0  # a new day's light
	Game.pass_days(1)
	_close_dialog()
	_refresh_hud()
	if int(tr.get("nights_due", 0)) > 0:
		_night(then)
	elif then.is_valid():
		then.call()
	_side()


func _say(text: String) -> void:
	_note = text
	_note_time = 3.0
	Game.run.note(text)
	_refresh_side()


# --- input ----------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = (event as InputEventMouseMotion).position
		_hover = _node_at(_to_map(_mouse))
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
	if not TravelRules.visible(Db.world_nodes, id, Game.flags_now()) or (_art != null and not TravelRules.seen(id, Game.flags_now())):
		return  # under the fog: nothing to click yet
	if id == String(Game.travel.get("at", "")):
		_enter()
	elif not TravelRules.open_now(Db.world_nodes, id, Game.flags_now()):
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
	var r := hud.clear_rect().grow(-24.0)  # no side panel any more ([USER] 2026-11-01): the map centres in the window
	var b := _bounds()
	var k := minf(r.size.x / b.size.x, r.size.y / b.size.y)
	return {"k": k, "o": r.get_center() - (b.position + b.size * 0.5) * k}


var _bounds_cache := Rect2()


## Every tile's top and base, map units, with room under the front row for its name.
func _bounds() -> Rect2:
	if _bounds_cache.has_area():
		return _bounds_cache
	if _art != null:  # the painted map: the whole picture, in its own pixels
		_bounds_cache = Rect2(Vector2.ZERO, _art.get_size())
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
	if _art != null:
		_draw_painted(k)
		return
	for id in _back_to_front():
		_draw_tile(id, k)
	for p: Dictionary in Db.world_paths:  # a road on every shared edge whose two tiles are both open now
		if TravelRules.open_now(Db.world_nodes, p.from, Game.flags_now()) and TravelRules.open_now(Db.world_nodes, p.to, Game.flags_now()):
			_draw_path(PackedVector2Array([_node_pos(p.from), _node_pos(p.to)]), k)
	_draw_sites(k)
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


## The painted world map ([USER] 2026-11-01 pm-dev-painted-world-map): Brandon's picture as the ground, each tile on
## its traced outline (data/world_tiles.csv). Tiles not seen yet lie under parchment and cloud; the tile the party is on
## has an inked outline, the tiles it can walk to now glow softly, and hovering a seen tile names it.
func _draw_painted(k: float) -> void:
	var flags: Array = Game.flags_now()
	var at := String(Game.travel.get("at", "")) if not walking() else ""
	draw_texture_rect(_art, Rect2(_to_screen(Vector2.ZERO), _art.get_size() * k), false)
	var near: Array[String] = []
	if at != "":
		for n in TravelRules.linked(Db.world_paths, at):  # a leg in data, not every shared border
			if TravelRules.open_now(Db.world_nodes, n, flags):
				near.append(n)
	for id in Db.world_nodes:
		var ring := _screen_ring(TravelRules.tile_top(_node(id), 0.0))
		if not TravelRules.seen(id, flags):
			_draw_fog(ring)
		elif not TravelRules.open_now(Db.world_nodes, id, flags):
			draw_colored_polygon(ring, Color(0.15, 0.13, 0.12, 0.28))  # seen but shut for now
	for p: Dictionary in Db.world_paths:  # a road on every border whose two tiles are seen and open now
		if TravelRules.seen(p.from, flags) and TravelRules.seen(p.to, flags) \
				and TravelRules.open_now(Db.world_nodes, p.from, flags) and TravelRules.open_now(Db.world_nodes, p.to, flags):
			_draw_route(_node_pos(p.from), _node_pos(p.to))
	var glow := 0.5 + 0.5 * sin(_time * 2.5)
	for id in near:  # where the party can walk to now
		var ring := _screen_ring(TravelRules.tile_top(_node(id), 5.0))
		draw_colored_polygon(ring, Color(1.0, 0.93, 0.6, 0.10 + 0.08 * glow))
		draw_polyline(_closed(ring), Color(1.0, 0.9, 0.55, 0.55 + 0.3 * glow), 3.0, true)
	if at != "":  # where the party stands: a soft green light over the tile and a thin border ([USER] 2026-11-01: subtle;
		# "give it a little green highlight rather than another tan on the active zone")
		var ring := _screen_ring(TravelRules.tile_top(_node(at), 4.0))
		draw_colored_polygon(ring, Color(0.55, 0.85, 0.45, 0.22))
		draw_polyline(_closed(ring), Color(0.62, 0.9, 0.5, 0.8), 2.0, true)
	if _hover != "" and _hover != at and TravelRules.seen(_hover, flags):
		draw_polyline(_closed(_screen_ring(TravelRules.tile_top(_node(_hover), 5.0))), Color(1, 1, 1, 0.85), 2.5, true)
	_draw_sites(k * PIECE)
	if walking():
		var lp := leg()
		var pts: PackedVector2Array = lp.points
		for st: float in Game.travel.stops:
			_draw_stop(_to_screen(TravelRules.point_at(pts, st / float(lp.seconds))), k * PIECE)
	for id in Db.world_nodes:
		if TravelRules.seen(id, flags):
			_draw_badges(id, k * PIECE)
	_draw_party(k * PIECE)
	if _hover != "" and TravelRules.seen(_hover, flags):  # the name on hover (placeholder text)
		_label(_to_screen(_node_pos(_hover)) + Vector2(0, -34 * k * PIECE), Txt.t(_node(_hover).name_key), 16, INK)
	if _note_time > 0.0:
		_label(_to_screen(party_pos()) + Vector2(0, -46 * k * PIECE), _note, 13, Color(1, 1, 1, minf(1.0, _note_time)))


## A route on the painted map: a thin, faint dashed line between two tile centres ([USER] 2026-11-01: subtler).
func _draw_route(a: Vector2, b: Vector2) -> void:
	var sa := _to_screen(a)
	var sb := _to_screen(b)
	var n := int(sa.distance_to(sb) / 9.0)
	for i in range(0, n, 2):
		draw_line(sa.lerp(sb, float(i) / n), sa.lerp(sb, float(i + 1) / n), Color(0.98, 0.94, 0.8, 0.75), 2.0, true)


func _screen_ring(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(_to_screen(p))
	return out


func _closed(ring: PackedVector2Array) -> PackedVector2Array:
	var out := ring.duplicate()
	out.append(ring[0])
	return out


## A tile not seen yet: parchment with soft clouds, clipped to its outline, its edge a little darker.
func _draw_fog(ring: PackedVector2Array) -> void:
	var uvs := PackedVector2Array()
	var drift := Vector2(_time * 0.004, 0.0)
	for p in ring:
		uvs.append(p / 256.0 + drift)
	draw_colored_polygon(ring, Color.WHITE, uvs, _fog)
	draw_polyline(_closed(ring), FOG_PAPER.darkened(0.25), 2.0, true)


## The fog's texture, made once: parchment, and noise for clouds over it. It tiles.
func _cloud_paper() -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var a := float(x) / size * TAU
			var b := float(y) / size * TAU
			# sampled on a torus so the edges meet when it tiles
			var n := noise.get_noise_3d(cos(a) * 40.0 + 40.0, sin(a) * 40.0 + cos(b) * 40.0, sin(b) * 40.0)
			var c := smoothstep(-0.05, 0.45, n)
			img.set_pixel(x, y, FOG_PAPER.lerp(FOG_CLOUD, c))
	var tex := ImageTexture.create_from_image(img)
	return tex


## Stand on a tile: it and its neighbours come out of the fog, for good (meta flags).
func _discover(id: String) -> void:
	if not Db.world_nodes.has(id):
		return
	var changed := false
	for f in TravelRules.discover(Db.world_nodes, id):
		if not Game.has_flag(f):
			Game.meta.flags.append(f)
			changed = true
	if changed:
		Game.save_meta()


## One tile as a raised hex block: the three faces toward the viewer, then the top, washed with its land's colour.
## A shut tile is darker and plain grey.
func _draw_tile(id: String, k: float) -> void:
	var n := _node(id)
	var open := TravelRules.open_now(Db.world_nodes, id, Game.flags_now())
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
	var open := TravelRules.open_now(Db.world_nodes, id, Game.flags_now())
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
	_draw_badges(id, k)
	if not open:
		_label(p + Vector2(0, 8), "?", 22, Color(INK, 0.6))
	_label(p + Vector2(0, 40 * k), Txt.t(n.name_key), 13, ink)


## An elite fight still waiting (red !) and a cleared place (gold seal), by the tile's centre.
func _draw_badges(id: String, k: float) -> void:
	var n := _node(id)
	var p := _to_screen(_node_pos(id))
	if _elites.get(id, 0) > 0:  # [USER] pc-15: an elite fight waits here
		var e := p + Vector2(-34, -18) * k
		draw_circle(e, 9.0 * k + 2.0, Color(0.8, 0.22, 0.2))
		draw_arc(e, 9.0 * k + 2.0, 0, TAU, 20, INK, 1.5, true)
		_label(e + Vector2(0, 4), "!", 12, Color(1, 1, 1))
	if TravelRules.cleared(n, Game.flags_now()):  # done: a gold seal, like a cleared level on an old console map
		var b := p + Vector2(34, -18) * k
		draw_circle(b, 9.0 * k + 2.0, Color(0.95, 0.75, 0.25))
		draw_arc(b, 9.0 * k + 2.0, 0, TAU, 20, INK, 1.5, true)
		draw_polyline(PackedVector2Array([b + Vector2(-4, 0) * k, b + Vector2(-1, 3.5) * k, b + Vector2(4.5, -4) * k]), INK, 2.0, true)


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


## Campsites (option C): a small tent in the site's colour on the leg being walked (passed ones faded), or, standing
## at a place, on every road out of it, so the stops can be planned.
func _draw_sites(_k: float) -> void:
	if not _sites():
		return
	var legs := []  # [path, from, passed]
	if walking():
		legs.append([leg(), String(Game.travel.from), Game.travel.get("passed", [])])
	else:
		var at := String(Game.travel.get("at", ""))
		for n in TravelRules.linked(Db.world_paths, at):
			if TravelRules.open_now(Db.world_nodes, n, Game.flags_now()) and TravelRules.seen(n, Game.flags_now()):
				legs.append([TravelRules.path_between(Db.world_paths, at, n), at, []])
	var named := ""
	var named_at := Vector2.ZERO
	for l: Array in legs:
		var p: Dictionary = l[0]
		if p.is_empty():
			continue
		var sites := CampRules.leg_sites(p, String(l[1]))
		for i in sites.size():
			var row: Dictionary = Db.campsites.get(String(sites[i].id), {})
			var c := Color(String(row.get("color", "9cc47a")))
			var gone := (l[2] as Array).has(i) or (l[2] as Array).has(float(i)) or (walking() and float(sites[i].t) < float(Game.travel.t))
			var at := _to_screen(TravelRules.point_at(p.points, float(sites[i].t) / float(p.seconds)))
			_tent(at, c, 0.35 if gone else 1.0)
			if at.distance_to(_mouse + Vector2(0, TENT * 0.5)) < TENT * 1.3:
				named = Txt.t(String(row.get("name_key", "")))
				named_at = at
	if named != "":  # hovering a tent names it
		_label(named_at + Vector2(0, -TENT * 1.6), named, 15, INK)


const TENT := 11.0  ## half the width of a campsite's tent on screen, px


## A campsite's tent: the site's colour on a pale disc, so it reads on the painted map.
func _tent(p: Vector2, c: Color, a: float) -> void:
	var w := TENT
	var h := TENT * 1.15
	draw_circle(p + Vector2(0, -h * 0.42), w * 1.2, Color(0.98, 0.95, 0.86, 0.85 * a))
	var tri := PackedVector2Array([p + Vector2(-w, 0), p + Vector2(0, -h), p + Vector2(w, 0)])
	draw_colored_polygon(tri, Color(c, a))
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(INK, a), 1.6, true)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-w * 0.28, 0), p + Vector2(0, -h * 0.5), p + Vector2(w * 0.28, 0)]), Color(INK, 0.75 * a))


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

## [USER] 2026-11-01 "What is this whole menu on the right ... let's put all dialogue/actions/ right above the diamond": no
## side panel. The walk's actions (FAST, HUNT, FISH, FORAGE, TALK, CAMP) or, standing at a place, its GO IN sit in one
## box right above the bottom frame's diamond while no dialogue is open; the newest roll or camp line flashes over them.
func _side() -> void:
	hud.clear_side()
	hud.top_label.text = Txt.t("UI_OW_TITLE")
	if _acts == null:
		_acts = PanelContainer.new()
		_acts.theme_type_variation = &"DialogPanel"
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		_acts.add_child(col)
		_info = Label.new()
		_info.add_theme_font_size_override("font_size", 24)
		_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(_info)
		_acts_row = HBoxContainer.new()
		_acts_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_acts_row.add_theme_constant_override("separation", 8)
		col.add_child(_acts_row)
		_ui.add_child(_acts)
		UiTheme.at_diamond(_acts, hud.clear_rect, UiTheme.small())
		_flash = Label.new()
		_flash.add_theme_font_size_override("font_size", 18)
		_flash.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_flash.add_theme_constant_override("outline_size", 6)
		_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui.add_child(_flash)
		_lines_seen = Game.run.lines.size()
	for c in _acts_row.get_children():
		_acts_row.remove_child(c)
		c.queue_free()
	if walking():
		var fast := _act_button(Txt.t("UI_OW_FAST_ON" if _fast else "UI_OW_FAST"), fast_forward)
		fast.tooltip_text = Txt.t("UI_OW_FAST_TIP")
	else:
		var n := _node(String(Game.travel.get("at", "town")))
		if map_ready(String(Game.travel.get("at", "town"))):  # no GO IN until the tile's map is built
			_act_button(Txt.f("UI_OW_ENTER", Txt.t(n.name_key)), _enter)
	_acts.tooltip_text = Txt.t("UI_OW_HELP")
	_acts.reset_size()
	_refresh_side()


func _act_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 58)
	b.add_theme_font_size_override("font_size", 27)  # the box is drawn at half size ([USER] SMALL): ~14 px on screen
	# (2026-11-13 playtest: 16, so 8 px, was too small to read on a laptop)
	b.pressed.connect(cb)
	_acts_row.add_child(b)
	return b


func _refresh_side() -> void:
	if _info == null:
		return
	if walking():
		var lp := leg()
		var then: Array = Game.travel.get("then", [])
		var goal := String(then.back()) if not then.is_empty() else String(Game.travel.to)
		_info.text = Txt.f("UI_OW_WALKING", [Txt.t(_node(goal).name_key), int(100.0 * float(Game.travel.t) / float(lp.seconds))])
		if _sites():
			_info.text += "   " + _dusk_text()
	else:  # [USER] 2026-11-01 fewer words: the map marks where the party stands and GO IN names it, so no line here
		_info.text = ""
	_info.visible = _info.text != ""
	_acts.visible = _dialog == null and _camp == null and not _menu_open and (_info.visible or _acts_row.get_child_count() > 0)
	if Game.run.lines.size() > _lines_seen:  # a new roll or camp line: a moment in the standard place
		_lines_seen = Game.run.lines.size()
		_flash.text = String(Game.run.lines[Game.run.lines.size() - 1])
		_flash_t = FLASH_TIME


const FLASH_TIME := 2.5  ## seconds a roll's line shows over the action box


func _refresh_hud() -> void:
	hud.set_party(FrameHud.party_entries_from_run(Game.run))
	hud.set_pack(Game.run.pack)
	hud.set_goals(Game.goal_lines())
	var tools := [{"id": "pack", "text": Txt.t("UI_PACK"), "cb": _open_menu.bind("pack")}]
	if Game.has_flag("has_lodestone"):
		tools.append({"id": "lodestone", "text": Txt.t("UI_LODESTONE"), "cb": _open_menu.bind("lodestone"), "glow": Game.pending_picks() > 0})
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
	AdventureMenu.open(box, which, changed, close, _open_menu, true)  # the Lodestone menu's tabs, or the pack alone


func _new_dialog(text: String) -> VBoxContainer:
	var fresh := _dialog == null  # a menu opening animates; one rebuilt in place does not
	if _dialog:
		_dialog.queue_free()
	_dialog = PanelContainer.new()
	var box := MenuKit.dialogue(_dialog, text, hud.clear_rect)  # the one dialogue screen ([USER] 2026-11-01)
	_ui.add_child(_dialog)
	# event dialogues stand right above the diamond, menus at the top ([USER] 2026-11-01: one standard place); the same
	# size as on the explore maps, so it is the exact same screen
	if _menu_open:
		UiTheme.centre_menu(_dialog, hud.clear_rect)  # the middle of the play area; shrinks to fit when it must
	else:
		MenuKit.pointer(_dialog.get_child(0))
		UiTheme.at_diamond(_dialog, hud.clear_rect)
	if fresh:
		UiTheme.pop_in_later(_dialog)
	return box


func _button(box: VBoxContainer, text: String, cb: Callable) -> void:
	MenuKit.answer(box, text, cb)


func _close_dialog() -> void:
	if _dialog:
		UiTheme.pop_out(_dialog)
		_dialog = null
	_busy = false
	_refresh_hud()

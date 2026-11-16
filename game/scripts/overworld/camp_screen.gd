class_name CampScreen
extends Control
## The campfire ([USER] 2026-11-16, option A of docs/design/campfire-trail.md): one screen at the end of each journey
## day, over the whole play area with the party frame under it (as fishing). The party sits round the fire; the pot's
## ration dial on the left; the evening's actions on the right, CampRules.slots of them a night, each once; SLEEP eats
## from the pot. SAME AS LAST NIGHT repeats last night's evening and ration. Rules in CampRules; morale, bonds and
## meals through Game.

signal slept(lines: PackedStringArray)  ## the pot is eaten: the night's lines (the caller ends the night)
signal changed  ## an action changed HP, morale or the pack: the party frame redraws

const NIGHT_TOP := Color("0b1a24")
const NIGHT_LOW := Color("13241d")
const EMBER := Color("f08a3c")
const FLAME := Color("ffd27a")
const LOG := Color("4a3424")
const WARN := Color(1.0, 0.72, 0.55)
const FIRE_SCALE := 1.7  ## the pit, logs and flames, drawn at this size

var room := Callable()  ## the play area it fills (FrameHud.clear_rect)
var bar := Callable()  ## the party frame's bar (fishing puts its Leave there)
var pond_key := "road"  ## Game.pond key for this camp's water
var night := 1  ## the trip's night number, for the title
var site: Dictionary = {}  ## tonight's campsite (data/campsites.csv), {} when camping wherever the day ended (option A)

var _done: Array = []  ## action ids taken tonight, in order
var _pair: Array = []  ## tonight's talk pair, kept for SAME AS LAST NIGHT
var _ration := CampRules.FILLING
var _lines: PackedStringArray = []  ## what happened tonight (the newest last)
var _t := 0.0
var _left: VBoxContainer
var _right: VBoxContainer
var _top: VBoxContainer
var _bottom: HBoxContainer
var _log: Label
var _faces: Array[Control] = []
var _fishing: FishingGame


static func open(parent: Node, room_fn: Callable, bar_fn: Callable, pond: String, night_no: int, at: Dictionary = {}) -> CampScreen:
	var c := CampScreen.new()
	c.site = at
	c.room = room_fn
	c.bar = bar_fn
	c.pond_key = pond
	c.night = night_no
	parent.add_child(c)
	return c


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ration = String(_settings().get("camp_ration", CampRules.FILLING))
	for m in Game.run.alive():  # the party round the fire
		var p := MenuKit.portrait(String((m.def as CharacterDef).id), 84)
		p.tooltip_text = Txt.t((m.def as CharacterDef).name_key)
		add_child(p)
		_faces.append(p)
	_top = VBoxContainer.new()
	_top.alignment = BoxContainer.ALIGNMENT_CENTER
	_top.add_theme_constant_override("separation", 6)
	add_child(_top)
	_left = MenuKit.card(self, Txt.t("CAMP_POT"))
	_right = MenuKit.card(self, Txt.t("CAMP_EVENING"))
	_log = MenuKit.label("", UiSkin.T_BODY, MenuKit.TEXT)
	_log.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_log)
	_bottom = HBoxContainer.new()
	_bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	_bottom.add_theme_constant_override("separation", 12)
	add_child(_bottom)
	resized.connect(_layout)
	var free := String(site.get("free", ""))
	if free != "":  # the ruins: searched before the evening, without a slot
		_lines.append(Txt.t("CAMP_SITE_SEARCHED"))
		_lines.append_array(CampScreen.act(free, []))
	_build()
	UiTheme.fade_in(self)


func _settings() -> Dictionary:
	return Game.meta.get("settings", {})


func _slots() -> int:
	return CampRules.slots_at(Db.camp, site)


# --- building ---------------------------------------------------------------------------------------

func _build() -> void:
	for box: Control in [_top, _bottom]:
		for c in box.get_children():
			box.remove_child(c)  # out now, so the cards shrink to what's built next
			c.queue_free()
	for box: VBoxContainer in [_left, _right]:
		for c in box.get_children().slice(1):  # keep each card's heading
			box.remove_child(c)
			c.queue_free()
	_build_top()
	_build_pot()
	_build_actions()
	_build_bottom()
	_log.text = "\n".join(_lines.slice(maxi(0, _lines.size() - 3)))
	changed.emit()
	_layout.call_deferred()


func _build_top() -> void:
	var title := Label.new()
	title.theme_type_variation = &"KitHeading"
	title.text = Txt.f("CAMP_TITLE", night) if site.is_empty() else Txt.f("CAMP_TITLE_AT", [night, Txt.t(String(site.name_key))])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top.add_child(title)
	if not site.is_empty():  # what this campsite gives, in one line
		var what := MenuKit.label(Txt.t(String(site.tip_key)), UiSkin.T_SMALL, CampScreen.WARN if int(site.get("morale", 0)) < 0 else MenuKit.TEXT_DIM)
		what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_top.add_child(what)
	var row := HBoxContainer.new()  # tonight's slots: what was done, then the free ones
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	_top.add_child(row)
	row.add_child(MenuKit.label(Txt.t("CAMP_SLOTS"), UiSkin.T_SMALL, MenuKit.TEXT_DIM))
	for i in _slots():
		if i < _done.size():
			var a := _action(String(_done[i]))
			row.add_child(MenuKit.chip(Txt.t(String(a.name_key)), String(a.get("icon", "")), UiTheme.GOLD))
		else:
			row.add_child(MenuKit.chip(Txt.t("CAMP_SLOT_EMPTY"), "", MenuKit.TEXT_DIM))


func _build_pot() -> void:
	var run := Game.run
	var r := CampRules.ration(Db.camp_rations, _ration)
	var days := CampRules.food_days(run, r)
	var big := MenuKit.label(Txt.t("CAMP_FOOD_PLENTY") if days >= 99 else Txt.f("CAMP_FOOD_DAYS", days), UiSkin.T_HEAD)
	_left.add_child(big)
	var dial := HBoxContainer.new()  # the ration dial (Oregon Trail): one pressed
	dial.add_theme_constant_override("separation", 4)
	_left.add_child(dial)
	for row: Dictionary in Db.camp_rations:
		var b := Button.new()
		b.toggle_mode = true
		b.text = Txt.t(String(row.name_key))
		b.tooltip_text = Txt.t(String(row.tip_key))
		b.set_pressed_no_signal(String(row.id) == String(r.id))
		b.theme_type_variation = &"PrimaryButton" if String(row.id) == String(r.id) else &"QuietButton"
		b.custom_minimum_size = Vector2(76, 34)
		b.add_theme_font_size_override("font_size", UiSkin.T_SMALL)
		b.pressed.connect(func() -> void:
			_ration = String(row.id)
			Game.set_setting("camp_ration", _ration)
			_build())
		dial.add_child(b)
	for row: Dictionary in Db.camp_rations:  # what the other settings would stretch the food to
		if String(row.id) == String(r.id) or float(row.share) <= 0.0:
			continue
		var d := CampRules.food_days(run, row)
		if d < 99:
			_left.add_child(MenuKit.label(Txt.f("CAMP_FOOD_AT", [d, Txt.t(String(row.name_key))]), UiSkin.T_SMALL, MenuKit.TEXT_DIM))
	var stock := HFlowContainer.new()  # what the pack holds
	stock.add_theme_constant_override("h_separation", 6)
	stock.add_theme_constant_override("v_separation", 4)
	_left.add_child(stock)
	for kind in run.larder():
		stock.add_child(MenuKit.chip(str(run.portions_of(kind)), kind, MenuKit.TEXT, Txt.t(String(Db.items[kind].name_key)), UiSkin.T_SMALL))
	var need := CampRules.pot_need(run, r)
	if float(r.share) > 0.0 and run.portions() < need:
		var short := need - run.portions()
		var hungry := 0
		var share := TravelRules.shares(run)
		var eat := CampRules.eaters(run)
		eat.reverse()
		for m in eat:
			if short <= 0:
				break
			short -= int(share.get(String((m.def as CharacterDef).id), 0))
			hungry += 1
		var w := MenuKit.label(Txt.f("CAMP_HUNGRY_WARN", hungry), UiSkin.T_BODY, WARN)
		w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		w.custom_minimum_size.x = 220
		_left.add_child(w)


func _build_actions() -> void:
	var full := _done.size() >= _slots()
	for row: Dictionary in Db.camp_actions:
		var id := String(row.id)
		var b := Button.new()
		b.text = Txt.t(String(row.name_key))
		if String(row.get("icon", "")) != "":
			b.icon = ActionInfo.icon(String(row.icon))
			b.add_theme_constant_override("icon_max_width", 24)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(200, 36)
		b.add_theme_font_size_override("font_size", UiSkin.T_BODY)
		var why := CampRules.why_not(Game.run, id, _done, site)
		if full and why == "":
			why = "CAMP_FULL"
		b.disabled = why != ""
		b.tooltip_text = Txt.t(why) if why != "" else _tip(row)
		b.pressed.connect(_do.bind(id))
		_right.add_child(b)


func _tip(row: Dictionary) -> String:
	match String(row.id):
		"cook":
			return Txt.f(String(row.tip_key), int(Db.camp.get("hot_pot", 5)))
		"mend":
			return Txt.f(String(row.tip_key), int(Db.camp.get("mend_hp", 6)))
	return Txt.t(String(row.tip_key))


func _build_bottom() -> void:
	var sleep := MenuKit.primary(Txt.t("CAMP_SLEEP"), _sleep, UiSkin.T_LEAD, 180.0)
	sleep.tooltip_text = Txt.t("CAMP_SLEEP_TIP")
	_bottom.add_child(sleep)
	var plan: Array = _settings().get("camp_plan", [])
	var same := Button.new()
	same.text = Txt.t("CAMP_SAME")
	same.tooltip_text = Txt.t("CAMP_SAME_TIP")
	same.custom_minimum_size = Vector2(220, 44)
	same.disabled = plan.is_empty() or not _done.is_empty()
	same.pressed.connect(repeat_last)
	_bottom.add_child(same)
	var auto := CheckBox.new()
	auto.text = Txt.t("CAMP_AUTO")
	auto.tooltip_text = Txt.t("CAMP_AUTO_TIP")
	auto.add_theme_font_size_override("font_size", UiSkin.T_BODY)
	auto.button_pressed = bool(_settings().get("auto_camp", false))
	auto.toggled.connect(func(on: bool) -> void: Game.set_setting("auto_camp", on))
	_bottom.add_child(auto)


func _action(id: String) -> Dictionary:
	for row: Dictionary in Db.camp_actions:
		if String(row.id) == id:
			return row
	return {"id": id, "name_key": id, "icon": ""}


# --- the evening ------------------------------------------------------------------------------------

func _do(id: String) -> void:
	if _done.size() >= _slots() or not CampRules.can_do(Game.run, id, _done, site):
		return
	match id:
		"fish":
			_fish()
			return
		"talk":
			_pick_pair()
			return
	_lines.append_array(CampScreen.act(id, _pair))
	_done.append(id)
	Sfx.play("confirm")
	_build()


## An action's effect (not fishing's minigame, not the talk picker): the lines to show. Static so SAME AS LAST NIGHT
## and the auto camp share it with the screen.
static func act(id: String, pair: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	var run := Game.run
	match id:
		"cook":
			out.append(Game.camp_cook())
		"mend":
			var l := Game.camp_mend()
			if l != "":
				out.append(l)
		"rest":
			if Game.camp_rest():
				out.append(Txt.t("UI_CAMP_RESTED"))
		"talk":
			if pair.size() == 2:
				out.append_array(Game.camp_talk(String(pair[0]), String(pair[1])))
		"hunt", "forage", "fish":  # fish here is the quick cast: the party's best fishing roll
			var r := TravelRules.activity(run, id)
			var name := Txt.t("CAMP_" + id.to_upper())
			if not bool(r.success):
				out.append(Txt.f("CAMP_GOT_NONE", name))
			elif int(r.medicine) > 0:
				out.append(Txt.f("CAMP_GOT_BOTH", [name, int(r.food), int(r.medicine)]))
			else:
				out.append(Txt.f("CAMP_GOT_FOOD", [name, int(r.food)]))
	return out


func _pick_pair() -> void:
	for c in _right.get_children().slice(1):
		_right.remove_child(c)
		c.queue_free()
	_right.add_child(MenuKit.label(Txt.t("CAMP_TALK_PICK"), UiSkin.T_BODY, MenuKit.TEXT_DIM))
	for p: Array in CampRules.pairs(Game.run):
		var b := Button.new()
		b.text = "%s + %s" % [Game._name_of(String(p[0])), Game._name_of(String(p[1]))]
		b.custom_minimum_size = Vector2(200, 34)
		b.add_theme_font_size_override("font_size", UiSkin.T_BODY)
		b.pressed.connect(func() -> void:
			_pair = p
			_lines.append_array(CampScreen.act("talk", p))
			_done.append("talk")
			_build())
		_right.add_child(b)
	var back := Button.new()
	back.text = Txt.t("CAMP_BACK")
	back.theme_type_variation = &"QuietButton"
	back.pressed.connect(_build)
	_right.add_child(back)


## FISH: the minigame over the camp ([USER] 2026-11-02 X19: the whole screen, the party frame under it).
func _fish() -> void:
	visible = false
	_fishing = FishingGame.open(get_parent(), "road", FishingRules.mods_for(Game.run), 0, Game.pond(pond_key, "road"), room, bar)
	_fishing.finished.connect(func(res: Dictionary) -> void:
		_fishing = null
		visible = true
		if String(res.outcome) == "left":  # left before the cast: the slot stays free
			_build()
			return
		_done.append("fish")
		if String(res.outcome) == "caught":
			var got := Game.land_fish(res.fish)
			_lines.append((Txt.t("UI_FISH_NEW") + " " if got.new else "") + Txt.f("CAMP_FISH_CAUGHT", Txt.t(String(res.fish.name_key))))
		else:
			_lines.append(Txt.t("CAMP_FISH_NONE"))
		_build())


func _sleep() -> void:
	Game.set_setting("camp_plan", _done.duplicate())
	Game.set_setting("camp_pair", _pair.duplicate())
	Game.set_setting("camp_ration", _ration)
	var lines := _lines.duplicate()
	lines.append_array(Game.camp_eat(_ration))
	lines.append_array(Game.camp_site_morale(int(site.get("morale", 0))))
	Sfx.play("camp")
	slept.emit(lines)
	queue_free()


## SAME AS LAST NIGHT: last night's evening (fishing as a quick cast) and ration, then sleep.
func repeat_last() -> void:
	_done = CampRules.repeatable(Game.run, _settings().get("camp_plan", []), _slots(), site)
	_pair = _settings().get("camp_pair", [])
	_lines.append_array(CampScreen.repeat_plan(_settings(), site))
	_sleep()


## Run last night's plan without the screen (SAME AS LAST NIGHT, and the auto camp). Returns its lines.
static func repeat_plan(settings: Dictionary, at: Dictionary = {}) -> PackedStringArray:
	var out: PackedStringArray = []
	var pair: Array = settings.get("camp_pair", [])
	for id: String in CampRules.repeatable(Game.run, settings.get("camp_plan", []), CampRules.slots_at(Db.camp, at), at):
		if id == "talk" and not CampRules.pairs(Game.run).has(pair):
			continue  # one of last night's pair is gone
		out.append_array(CampScreen.act(id, pair))
	return out


# --- layout and drawing -----------------------------------------------------------------------------

func _room() -> Rect2:
	return room.call() if room.is_valid() else Rect2(Vector2.ZERO, size)


func _fire() -> Vector2:
	var r := _room()
	return r.position + Vector2(r.size.x * 0.5, r.size.y * 0.56)


func _layout() -> void:
	var r := _room()
	var pad := 20.0
	for box: Control in [_left.get_parent(), _right.get_parent()]:
		(box as Control).reset_size()
	var lp := _left.get_parent() as Control
	lp.position = r.position + Vector2(pad, r.size.y * 0.16)
	lp.custom_minimum_size.x = 250
	var rp := _right.get_parent() as Control
	rp.custom_minimum_size.x = 236
	rp.reset_size()
	rp.position = Vector2(r.end.x - pad - rp.size.x, r.position.y + r.size.y * 0.16)
	_top.reset_size()
	_top.position = Vector2(r.get_center().x - _top.size.x * 0.5, r.position.y + 14)
	_bottom.reset_size()
	_bottom.position = Vector2(r.get_center().x - _bottom.size.x * 0.5, r.end.y - _bottom.size.y - 16)
	_log.custom_minimum_size.x = minf(520.0, r.size.x - 560.0)
	_log.reset_size()
	_log.position = Vector2(r.get_center().x - _log.size.x * 0.5, _fire().y + r.size.y * 0.2)
	var f := _fire()
	var n := _faces.size()
	for i in n:  # an arc behind and beside the fire
		var a := PI * (1.08 + 0.84 * (float(i) + 0.5) / float(n))
		var p := f + Vector2(cos(a) * 215.0, sin(a) * 105.0) - Vector2(42, 56)
		_faces[i].position = p
		_faces[i].size = Vector2(84, 84)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var r := _room()
	var steps := 24
	for i in steps:  # the night sky down to the ground
		var k := float(i) / steps
		draw_rect(Rect2(r.position.x, r.position.y + r.size.y * k, r.size.x, r.size.y / steps + 1.0), NIGHT_TOP.lerp(NIGHT_LOW, k))
	var f := _fire()
	for i in 6:  # the glow on the ground, widest and faintest first
		var k := 1.0 - float(i) / 6.0
		var flick := 1.0 + 0.04 * sin(_t * 7.0 + i)
		_ellipse(f + Vector2(0, 24), Vector2(330, 140) * k * flick, Color(EMBER, 0.06 + 0.05 * (1.0 - k)))
	draw_set_transform(f, 0.0, Vector2.ONE * FIRE_SCALE)  # the pit, logs and flames, drawn round the origin
	var o := Vector2.ZERO
	_ellipse(o + Vector2(0, 18), Vector2(70, 22), Color("2a1d15"))  # the ring of the fire pit
	for s in [-1.0, 1.0]:  # two logs, crossed
		draw_line(o + Vector2(-46 * s, 22), o + Vector2(40 * s, 8), LOG, 10.0, true)
	for i in 5:  # the flames: tongues that sway
		var x := (float(i) - 2.0) * 11.0
		var h := 46.0 + 18.0 * sin(_t * (5.0 + i) + i * 1.7) - absf(x) * 0.9
		var sway := 5.0 * sin(_t * 3.0 + i)
		var base := o + Vector2(x, 12)
		var tip := base + Vector2(sway, -h)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-10, 0), tip, base + Vector2(10, 0)]), Color(EMBER, 0.9))
		draw_colored_polygon(PackedVector2Array([base + Vector2(-5, 0), base.lerp(tip, 0.7), base + Vector2(5, 0)]), Color(FLAME, 0.95))
	for i in 7:  # sparks rising
		var k := fmod(_t * 0.45 + i * 0.137, 1.0)
		var p := o + Vector2(sin(i * 2.3 + _t) * 18.0 + (i - 3) * 6.0, -30.0 - k * 150.0)
		draw_circle(p, 2.2 * (1.0 - k), Color(FLAME, 1.0 - k))
	draw_set_transform(Vector2.ZERO)


func _ellipse(c: Vector2, half: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * half.x, sin(a) * half.y))
	draw_colored_polygon(pts, col)

extends Node2D
## One day per action on the trail. Events pop up between days.
## Press F6 on trail.tscn to start with a default party.

var hud: FrameHud
var map: LodestoneMap
var log_text: RichTextLabel
var stats: Label
var event_panel: PanelContainer
var event_box: VBoxContainer
var action_buttons: Array[Button] = []


func _ready() -> void:
	Game.ensure_run()
	hud = FrameHud.new()
	add_child(hud)
	hud.top_label.text = Txt.t("GAME_TITLE")

	var center := VBoxContainer.new()
	var r := hud.center_rect()
	FrameHud._pin(center, 0, 0, 1, 1, FrameHud.LEFT_W + 12, FrameHud.TOP_H + 8, -FrameHud.RIGHT_W - 12, -FrameHud.BOTTOM_H - 8)
	hud.root.add_child(center)
	map = LodestoneMap.new()
	map.old_marks = Game.meta.marks
	map.best = int(Game.meta.best_distance)
	center.add_child(map)
	log_text = RichTextLabel.new()
	log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_text.scroll_following = true
	log_text.add_theme_font_size_override("normal_font_size", 14)
	center.add_child(log_text)

	stats = hud.add_side_label("", 15)
	for spec in [["UI_TRAVEL", _travel.bind(false)], ["UI_TRAVEL_HARD", _travel.bind(true)],
			["UI_REST", _act.bind(func(r: RunState) -> void: TrailRules.rest(r))],
			["UI_HUNT", _act.bind(func(r: RunState) -> void: TrailRules.hunt(r))],
			["UI_FORAGE", _act.bind(func(r: RunState) -> void: TrailRules.forage(r))],
			["UI_HEAL", _act.bind(func(r: RunState) -> void: TrailRules.heal(r))]]:
		action_buttons.append(hud.add_button(Txt.t(spec[0]), spec[1]))

	event_panel = PanelContainer.new()
	event_box = VBoxContainer.new()
	event_box.add_theme_constant_override("separation", 8)
	event_panel.add_child(event_box)
	event_panel.custom_minimum_size = Vector2(420, 0)
	event_panel.visible = false
	hud.root.add_child(event_panel)
	event_panel.position = r.position + Vector2(r.size.x * 0.5 - 210, 170)

	for line in Game.pending_lines:
		Game.run.note(line)
	Game.pending_lines = []
	_refresh()


func _refresh() -> void:
	var run := Game.run
	stats.text = "\n".join([
		Txt.f("UI_DAY", run.day), Txt.f("UI_DISTANCE", [run.distance, RunState.GOAL]),
		Txt.f("UI_FOOD", run.food), Txt.f("UI_MEDICINE", run.medicine), Txt.f("UI_GOLD", run.gold),
		Txt.f("UI_MORALE", run.morale), Txt.f("UI_STRANGE", run.strangeness())])
	hud.set_party(FrameHud.party_entries_from_run(run))
	hud.set_slots(run.slot_list(), RunState.CAPACITY)
	map.run = run
	map.queue_redraw()
	log_text.text = "\n".join(run.lines.slice(-60))


func _set_actions_enabled(on: bool) -> void:
	for b in action_buttons:
		b.disabled = not on


func _act(rule: Callable) -> void:
	rule.call(Game.run)
	_after_action()


func _travel(hard: bool) -> void:
	TrailRules.travel(Game.run, hard)
	if _after_action():
		return
	var ev := TrailRules.roll_event(Game.run, Db.events, Game.meta.flags)
	if not ev.is_empty():
		_show_event(ev)


## Returns true if the run ended.
func _after_action() -> bool:
	Game.absorb([])
	_refresh()
	if Game.run.wiped():
		Game.recall()
		return true
	if Game.run.distance >= RunState.GOAL:
		Game.complete_run()
		return true
	return false


func _show_event(ev: Dictionary) -> void:
	Game.run.marks.append({"d": Game.run.distance, "kind": ev.id})
	_set_actions_enabled(false)
	for c in event_box.get_children():
		c.queue_free()
	var l := Label.new()
	l.text = Txt.t(ev.text_key)
	l.add_theme_font_size_override("font_size", 20)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_box.add_child(l)
	for opt in ev.options:
		var b := Button.new()
		var label := Txt.t(opt.key)
		if opt.check != "none" and opt.check != "fight":
			var bonus := TrailRules.party_bonus(Game.run, opt.check)
			label += "   [%s %d%%]" % [Txt.t("CHECK_" + opt.check.to_upper()), int(round(Dice.chance(bonus, opt.dc) * 100))]
		b.text = label
		b.pressed.connect(_choose.bind(opt))
		event_box.add_child(b)
	event_panel.visible = true


func _choose(opt: Dictionary) -> void:
	var fx := TrailRules.resolve_option(Game.run, opt)
	Game.absorb(fx.unlocks)
	for c in event_box.get_children():
		c.queue_free()
	var l := Label.new()
	var check: Dictionary = fx.check
	l.text = (Dice.describe(check) + "  " + (Txt.t("LOG_WIN") if fx.success else Txt.t("LOG_LOSE"))) if not check.is_empty() else ""
	l.add_theme_font_size_override("font_size", 18)
	event_box.add_child(l)
	var b := Button.new()
	b.text = Txt.t("UI_CONTINUE")
	b.pressed.connect(_close_event.bind(fx.combat))
	event_box.add_child(b)
	_refresh()


func _close_event(combat: String) -> void:
	event_panel.visible = false
	_set_actions_enabled(true)
	if combat != "":
		Game.start_combat(combat)
		return
	_after_action()

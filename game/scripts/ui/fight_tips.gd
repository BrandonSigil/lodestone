class_name FightTips
extends PanelContainer
## The first fight's how-to (2026-11-13 playtest: "what do I click?"): a small card at the play area's left with the
## win goal and four steps, each ticked off as the player does it (move, attack, look at danger, end the turn). It
## shows in the first fight ever (GoalRules hint "fight"), closes with its X, and fades a few seconds after the last
## tick. Every word is game text (TIP_FIGHT_* in text/placeholder.csv).

const STEPS := ["TIP_FIGHT_MOVE", "TIP_FIGHT_HIT", "TIP_FIGHT_DANGER", "TIP_FIGHT_END"]
const WIDTH := 300.0

var battle: Battle
var _rows: Array[Label] = []
var _boxes: Array[Panel] = []
var _done: Array[bool] = []
var _ended := false
var _fade := -1.0


static func open(b: Battle, parent: Node) -> FightTips:
	var t := FightTips.new()
	t.battle = b
	t.theme_type_variation = &"DialogPanel"
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	t.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := MenuKit.label(Txt.t("TIP_FIGHT_TITLE"), 19, MenuKit.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := MenuKit.XButton.new()  # the round X every window has
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	x.pressed.connect(t.queue_free)
	head.add_child(x)
	var goal := MenuKit.label(b.goal_lines()[0] if not b.goal_lines().is_empty() else "", 15, MenuKit.TEXT)
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal.custom_minimum_size.x = WIDTH
	col.add_child(goal)
	for i in STEPS.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		col.add_child(row)
		var box := Panel.new()  # the tick box: an empty square, filled gold when the step is done
		box.custom_minimum_size = Vector2(14, 14)
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(box)
		t._boxes.append(box)
		var l := MenuKit.label("", 15, MenuKit.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = WIDTH - 24.0
		row.add_child(l)
		t._rows.append(l)
		t._done.append(false)
	b.phase_changed.connect(t._on_phase)  # methods, so they let go when the card is closed
	b.finished.connect(t._on_finished)  # the fight over: the card goes with it
	parent.add_child(t)
	t._paint()
	UiTheme.pop_in(t)
	return t


func _on_finished(_won: bool) -> void:
	queue_free()


func _on_phase(team: int) -> void:
	if team == 1:
		_ended = true


func _process(delta: float) -> void:
	if battle == null or not is_instance_valid(battle):
		queue_free()
		return
	var r := battle._rect
	reset_size()
	position = Vector2(r.position.x + 12.0, r.position.y + r.size.y * 0.22).floor()
	var now := [false, false, battle.show_danger, _ended]
	for u: CombatUnit in battle.units:
		if u.team == 0:
			now[0] = now[0] or u.moved
		else:
			now[1] = now[1] or u.shown_hp < u.max_hp  # a foe hurt: WAIT alone doesn't tick the attack
	var changed := false
	for i in STEPS.size():
		if now[i] and not _done[i]:
			_done[i] = true
			changed = true
	if changed:
		_paint()
		var sfx := get_node_or_null("/root/Sfx")
		if sfx:
			sfx.call("play", "hint")
	if _fade < 0.0 and not _done.has(false):
		_fade = 4.0
	if _fade >= 0.0:
		_fade -= delta
		if _fade < 1.0:
			modulate.a = maxf(0.0, _fade)
		if _fade <= 0.0:
			queue_free()


## Each step with its box: done steps go gold with a filled box, the next one to do is bright.
func _paint() -> void:
	var next := _done.find(false)
	for i in STEPS.size():
		var l := _rows[i]
		l.text = Txt.t(STEPS[i])
		var col := MenuKit.GOLD if _done[i] else (MenuKit.TEXT if i == next else MenuKit.TEXT_DIM)
		l.add_theme_color_override("font_color", col)
		var sb := StyleBoxFlat.new()
		sb.bg_color = MenuKit.GOLD if _done[i] else Color(0, 0, 0, 0)
		sb.border_color = col
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(2)
		_boxes[i].add_theme_stylebox_override("panel", sb)

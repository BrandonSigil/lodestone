class_name LevelUpUi
extends RefCounted
## The level-up screen's body ([USER] 2026-10-31, docs/design/level-up.md): after the fight or event that earned it, what
## the character just improved (stats go up on odd levels), and on even levels one pick: learn a kit ability or give a
## known one its next step, with plain before and after numbers. A pick can wait ("decide later") in the Lodestone menu.

const MIN_CHOICES := 4  ## the pick always shows this many when the kit has them

## ability field -> the word the card uses
const LABELS := {"power": "Power", "range_max": "Reach", "range_min": "Closest reach", "res_cost": "Cost", "cooldown": "Wait",
	"status_turns": "Lasts", "push": "Shove", "radius": "Area", "crit": "Crit chance", "bleed": "Bleed"}


static func _member(id: String) -> Dictionary:
	for m in Game.run.members:
		if String((m.def as CharacterDef).id) == id:
			return m
	return {}


## The header and the stat lines for a member that just levelled: "LEAD LEVEL 3!", "HP 18 to 20".
static func summary(id: String, entry: Dictionary) -> String:
	var m := _member(id)
	if m.is_empty():
		return ""
	var lines: PackedStringArray = []
	var levels: Array = entry.get("levels", [])
	var name := Txt.t((m.def as CharacterDef).name_key)
	lines.append(Txt.f("UI_LEVEL_UP", [name, int(levels[levels.size() - 1])]) if not levels.is_empty() else name)
	var u := CombatUnit.from_member(m)
	var now := {"hp": u.max_hp, "damage": u.damage, "armor": u.armor, "magic": u.magic_power, "crit": u.crit}
	var stats: Dictionary = entry.get("stats", {})
	var gains: PackedStringArray = []
	for k in LevelRules.STATS:
		if stats.has(k):
			gains.append(Txt.f("UI_LV_STAT", [Txt.t("UI_STAT_" + k.to_upper()), int(now[k]) - int(stats[k]), int(now[k])]))
	if not gains.is_empty():
		lines.append("   ".join(gains))  # one line: "HP 15 to 19   CRIT 8 to 10"
	return "\n".join(lines)


## The pick ([USER] 2026-10-31, a mix of BG3 and a MOBA's skill screen): the choices as big ability icons in a row; the one
## selected (a click, or the arrows or a stick moving the focus onto it) shows what it does, its numbers now and a preview
## of the next rank, and the Pick Skill button confirms. Pressing a selected icon again with the keyboard or a pad confirms
## too. A click spends the pick and calls `refresh` (the screen rebuilds); `box` is where it goes.
static func picks(box: VBoxContainer, id: String, refresh: Callable) -> void:
	var m := _member(id)
	if m.is_empty() or int(Game.rank_state(id).pending) <= 0:
		return
	var u := CombatUnit.from_member(m)
	var ranks: Dictionary = Game.rank_state(id).ranks
	var options: Array[Dictionary] = []  # {"id", "ability" (null for a trait), "learn", "have", "next", "locked"}
	for aid in Game.learnable(id):
		options.append({"id": aid, "ability": Db.ability(aid), "learn": true, "have": 0, "next": 0, "locked": false})
	for a: Ability in u.abilities:
		var have := int(ranks.get(a.id, 0))
		var nxt := LevelRules.next_useful_rank(a.id, have, Db.skill_ranks)
		if nxt > 0:
			options.append({"id": a.id, "ability": Db.ability(a.id), "learn": false, "have": have, "next": nxt, "locked": false})
	# always four to look at when the kit has them: what is left of the kit whose effect is not built yet shows locked
	for aid in Game.learnable(id, false):
		if options.size() >= MIN_CHOICES:
			break
		options.append({"id": aid, "ability": Db.ability(aid), "learn": true, "have": 0, "next": 0, "locked": true})
	var label := Label.new()
	label.text = Txt.f("UI_LV_PICK", int(Game.rank_state(id).pending))
	label.add_theme_font_size_override("font_size", 18)
	box.add_child(label)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	box.add_child(row)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 4)
	detail.custom_minimum_size = Vector2(460, 150)
	box.add_child(detail)
	var pick := Button.new()
	pick.text = Txt.t("UI_LV_PICK_SKILL")
	pick.disabled = true
	pick.custom_minimum_size = Vector2(460, 48)
	pick.add_theme_font_size_override("font_size", 20)
	var state := {"chosen": -1}
	var buttons: Array[Button] = []
	var confirm := func() -> void:
		var i: int = state.chosen
		if i < 0 or options[i].locked:
			return
		var o: Dictionary = options[i]
		if o.learn:
			Game.learn_skill(id, String(o.id))
		else:
			Game.rank_skill(id, String(o.id))
		refresh.call()
	var choose := func(i: int) -> void:
		state.chosen = i
		for k in buttons.size():
			buttons[k].set_pressed_no_signal(k == i)
		_detail(detail, u, options[i], ranks)
		pick.disabled = bool(options[i].locked)
	for i in options.size():
		var o: Dictionary = options[i]
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(84, 84)
		b.tooltip_text = _name(o)
		b.focus_mode = Control.FOCUS_ALL
		var tex := ActionInfo.icon_for(o.ability) if o.ability != null else ActionInfo.icon(String(o.id))
		if tex != null:
			b.icon = tex
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.add_theme_constant_override("icon_max_width", 64)
		else:
			b.text = _name(o)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.add_theme_font_size_override("font_size", 12)
		_slot_style(b)
		if o.locked:
			b.modulate = Color(0.55, 0.55, 0.6)  # in the kit, not in the game yet
		b.pressed.connect(func() -> void:
			if state.chosen == i and Input.is_action_just_pressed("ui_accept"):
				confirm.call()  # a second press of the selected icon from the keyboard or a pad confirms
			else:
				choose.call(i))
		b.focus_entered.connect(func() -> void: choose.call(i))  # moving along the row previews each
		row.add_child(b)
		buttons.append(b)
	pick.pressed.connect(confirm)
	box.add_child(pick)
	if not buttons.is_empty():
		buttons[0].call_deferred("grab_focus")


## The detail panel of the selected option: what it is, what it does, its numbers now, what this pick adds, and the next rank.
static func _detail(detail: VBoxContainer, u: CombatUnit, o: Dictionary, ranks: Dictionary) -> void:
	for c in detail.get_children():
		detail.remove_child(c)
		c.queue_free()
	var a: Ability = o.ability
	var have: int = o.have
	var title := Label.new()
	title.text = _name(o) + "   " + (Txt.t("UI_LV_NEW") if o.learn else Txt.f("UI_LV_RANK_OF", [have, LevelRules.max_rank(a.id, Db.skill_ranks)]))
	title.add_theme_font_size_override("font_size", 22)
	detail.add_child(title)
	_line(detail, _desc(o), 16)
	if o.locked:
		_line(detail, Txt.t("UI_LV_LOCKED"), 16, Color(1.0, 0.8, 0.6))
		return
	if a == null:  # a trait: what it does, nothing to grow
		return
	var cur := LevelRules.ranked(a, have, Db.skill_ranks)
	_line(detail, Txt.f("UI_LV_NOW", _numbers(u, cur)), 16)
	var steps: Array = Db.upgrade_steps.get(a.id, [])
	if o.learn:
		var first := LevelRules.next_useful_rank(a.id, 0, Db.skill_ranks)
		if first > 0:
			_line(detail, Txt.f("UI_LV_THEN", String((steps[first - 1] as Dictionary).text)), 15, Color(0.75, 0.9, 0.8))
		return
	var nxt: int = o.next
	var step: Dictionary = steps[nxt - 1]
	var change := _change(u, a, have, nxt, String(step.effect))
	_line(detail, Txt.f("UI_LV_THIS", String(step.text)) + ("  (" + change + ")" if change != "" else ""), 16, Color(1.0, 0.92, 0.6))
	var after := LevelRules.next_useful_rank(a.id, nxt, Db.skill_ranks)
	if after > 0:
		var s2: Dictionary = steps[after - 1]
		var c2 := _change(u, a, nxt, after, String(s2.effect))
		_line(detail, Txt.f("UI_LV_NEXT", String(s2.text)) + ("  (" + c2 + ")" if c2 != "" else ""), 15, Color(0.75, 0.9, 0.8))
	else:
		_line(detail, Txt.t("UI_LV_LAST"), 15, Color(0.75, 0.9, 0.8))


static func _line(box: VBoxContainer, text: String, size: int, color := Color(0.93, 0.9, 0.82)) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(460, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	box.add_child(l)


## The name and the plain description of an option: an ability's, or a kit trait's.
static func _name(o: Dictionary) -> String:
	if o.ability != null:
		return Txt.t((o.ability as Ability).name_key)
	var key := "TRAIT_" + String(o.id).to_upper()
	return Txt.t(key) if Txt.has(key) else String(o.id).replace("_", " ").to_upper()


static func _desc(o: Dictionary) -> String:
	if o.ability != null:
		return _describe(o.ability, false)
	var key := "TRAIT_" + String(o.id).to_upper() + "_DESC"
	return Txt.t(key) if Txt.has(key) else ""


## "Damage 5, reach 1 to 3, costs 2, shoves 1": the ability's numbers on this piece.
static func _numbers(u: CombatUnit, a: Ability) -> String:
	var parts: PackedStringArray = []
	if a.kind == "attack":
		parts.append("%s %d" % [Txt.t("UI_STAT_DAMAGE"), u.damage + a.power])
	elif a.kind == "heal":
		parts.append("%s %d" % [Txt.t("UI_LV_HEALING"), a.power])
	if a.range_max > 0:
		parts.append(Txt.f("UI_LV_REACH_OF", [a.range_min, a.range_max]))
	if a.res_cost > 0:
		parts.append(Txt.f("UI_LV_COST", a.res_cost))
	if a.radius > 0:
		parts.append("%s %d" % [LABELS["radius"], a.radius])
	if a.push > 0:
		parts.append("%s %d" % [LABELS["push"], a.push])
	if a.status_turns > 0:
		parts.append("%s %d" % [LABELS["status_turns"], a.status_turns])
	if a.cooldown > 0:
		parts.append("%s %d" % [LABELS["cooldown"], a.cooldown])
	return ", ".join(parts)


## The icon slot's frame: a dark square with a cream rim, lit blue when selected (the dock's boxes, as StyleBoxes).
static func _slot_style(b: Button) -> void:
	for n in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.1, 0.1) if n != "hover" else Color(0.1, 0.18, 0.18)
		sb.border_color = Color(0.9, 0.82, 0.7)
		sb.set_border_width_all(3)
		if n in ["pressed", "hover_pressed"]:
			sb.border_color = Color(0.55, 0.78, 1.0)
			sb.bg_color = Color(0.1, 0.2, 0.28)
		if n == "focus":
			sb.border_color = Color(0.55, 0.78, 1.0)
			sb.draw_center = false
		sb.set_corner_radius_all(4)
		b.add_theme_stylebox_override(n, sb)


## "Power 3 to 4  Reach 2 to 3": every field this step's effect touches, before and after.
static func _change(u: CombatUnit, base: Ability, have: int, nxt: int, effect: String) -> String:
	var before := LevelRules.ranked(base, have, Db.skill_ranks)
	var after := LevelRules.ranked(base, nxt, Db.skill_ranks)
	var parts: PackedStringArray = []
	for part in effect.split(";", false):
		var key := part.split(":")[0].strip_edges()
		if not key in before or not LABELS.has(key):
			continue
		var b: Variant = before.get(key)
		var f: Variant = after.get(key)
		if key == "power" and base.kind == "attack":  # the damage it deals: the piece's own plus the skill's
			parts.append("%s %d to %d" % [Txt.t("UI_STAT_DAMAGE"), u.damage + int(b), u.damage + int(f)])
		else:
			parts.append("%s %s to %s" % [LABELS[key], str(b), str(f)])
	return "   ".join(parts)


static func _describe(a: Ability, with_facts := true) -> String:
	var parts: PackedStringArray = []
	if Txt.has("DESC_" + a.id.to_upper()):
		parts.append(Txt.t("DESC_" + a.id.to_upper()))
	return "\n".join(parts)

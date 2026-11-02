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


## Is a pick waiting for this member, with something to pick?
static func has_pick(id: String) -> bool:
	return not _options(id).is_empty()


## What a waiting pick offers: kit abilities to learn, known ones (and traits, GUARD) to grow, and locked kit slots to
## fill the row up to MIN_CHOICES. Empty when no pick waits or there is nothing real to choose.
static func _options(id: String) -> Array[Dictionary]:
	var m := _member(id)
	if m.is_empty() or int(Game.rank_state(id).pending) <= 0:
		return []
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
	# a kit's traits and its GUARD, once the piece has them, grow too (their steps are number upgrades the rules read)
	var kit := Game.kit_of(id)
	for r in Db.kits:
		if r.archetype != kit or r.alt != "0" or r.built != "1":
			continue
		var sid := String(r.ability)
		var known: bool = (r.source == "trait" and u.traits.has(StringName(sid))) or (r.source == "action" and sid == "guard")
		var have2 := int(ranks.get(sid, 0))
		var nxt2 := LevelRules.next_useful_rank(sid, have2, Db.skill_ranks)
		if known and nxt2 > 0:
			options.append({"id": sid, "ability": null, "learn": false, "have": have2, "next": nxt2, "locked": false})
	# a class's own passives (Doggo's Good Boy, Amber's A Heart that Burns) grow too ([USER] 2026-11-01: "I want to
	# upgrade that passive")
	for t: StringName in u.traits:
		var tid := String(t)
		if options.any(func(o: Dictionary) -> bool: return o.id == tid):
			continue
		var have3 := int(ranks.get(tid, 0))
		var nxt3 := LevelRules.next_useful_rank(tid, have3, Db.skill_ranks)
		if nxt3 > 0:
			options.append({"id": tid, "ability": null, "learn": false, "have": have3, "next": nxt3, "locked": false})
	# always four to look at when the kit has them: what is left of the kit whose effect is not built yet shows locked
	for aid in Game.learnable(id, false):
		if options.size() >= MIN_CHOICES:
			break
		options.append({"id": aid, "ability": Db.ability(aid), "learn": true, "have": 0, "next": 0, "locked": true})
	if options.all(func(o: Dictionary) -> bool: return o.locked):
		return []
	return options


## The level-up screen as one kit window ([USER] 2026-11-02 on dev-x17-review: "Level up is still so ugly"; the round 2
## mockups' look): the LEVEL UP plate on its rim, the X at its top right (Decide later). On the left a card for the
## character: round portrait, name, the level reached, the stats gained as chips, thin HP / energy / Morale / EXP bars.
## On the right the pick: the choices as kit cards (icon, name, New or Rank n to n+1, one line of what it does), the
## selected one lit gold, its rules under them in a detail card (what it does, its numbers now, what this pick adds,
## the next rank), and at the foot Decide later and the gold LEARN or UPGRADE. `done` runs after a pick (the host
## rebuilds or moves on); `later` on Decide later, the X and Esc.
class Screen extends PanelContainer:
	var id := ""
	var entry := {}
	var done := Callable()
	var later := Callable()
	var area := Callable()
	var _win: Control

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var dim := StyleBoxFlat.new()
		dim.bg_color = Color(0.02, 0.05, 0.05, 0.6)
		add_theme_stylebox_override("panel", dim)
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(holder)
		var w := MenuKit.window(Txt.t("UI_LV_TITLE"), _room, _later, 40)
		_win = w.root
		holder.add_child(_win)
		var body := HBoxContainer.new()
		body.add_theme_constant_override("separation", 18)
		w.body.add_child(body)
		LevelUpUi.who_card(body, id, entry)
		var right := VBoxContainer.new()
		right.add_theme_constant_override("separation", 10)
		body.add_child(right)
		LevelUpUi.picks(right, id, done, w.foot, _later)
		_win.resized.connect(_fit)
		holder.resized.connect(_fit)
		_fit.call_deferred()
		UiTheme.fade_in(self)

	func _room() -> Rect2:
		return area.call() if area.is_valid() else get_viewport_rect()

	func _fit() -> void:
		if not is_instance_valid(_win):
			return
		_win.reset_size()
		var r := _room()
		var k := minf(1.0, minf((r.size.x - 32.0) / maxf(1.0, _win.size.x), (r.size.y - 24.0) / maxf(1.0, _win.size.y)))
		_win.scale = Vector2(k, k)
		_win.position = (r.position + (r.size - _win.size * k) * 0.5).floor()

	func _later() -> void:
		if later.is_valid():
			later.call()

	func _unhandled_key_input(event: InputEvent) -> void:
		if event.is_pressed() and not event.is_echo() and event.is_action("ui_cancel"):
			get_viewport().set_input_as_handled()
			_later()


## The level-up window for a member (host adds it to its UI layer). area: the room it may use.
static func open(id: String, entry: Dictionary, done: Callable, later: Callable, area := Callable()) -> Screen:
	var sc := Screen.new()
	sc.id = id
	sc.entry = entry
	sc.done = done
	sc.later = later
	sc.area = area
	return sc


## The character's card: round portrait, name, the level reached, the stats gained as chips, the thin bars.
static func who_card(parent: Control, id: String, entry: Dictionary) -> void:
	var m := _member(id)
	var v := MenuKit.card(parent)
	v.get_parent().custom_minimum_size.x = 250
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	var pic := MenuKit.portrait(id, 120, true)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(pic)
	if not m.is_empty():
		var nm := MenuKit.label(Txt.t((m.def as CharacterDef).name_key), 22)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nm)
	var levels: Array = entry.get("levels", [])
	var now := int(levels[levels.size() - 1]) if not levels.is_empty() else int(Game.level_state(id).level)
	var was := int(levels[0]) - 1 if not levels.is_empty() else now - 1
	var lv := MenuKit.chip(Txt.f("UI_LV_REACHED", [maxi(1, was), now]), "star_guide", VictoryUi.XP_GOLD, "", 18)
	lv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(lv)
	var stats: Dictionary = entry.get("stats", {})
	var gains := HFlowContainer.new()
	gains.alignment = FlowContainer.ALIGNMENT_CENTER
	gains.add_theme_constant_override("h_separation", 6)
	gains.add_theme_constant_override("v_separation", 6)
	for k in LevelRules.STATS:
		if int(stats.get(k, 0)) > 0:
			gains.add_child(MenuKit.chip("+%d %s" % [int(stats[k]), Txt.t("UI_STAT_" + k.to_upper())], String(VictoryUi.STAT_ICON[k]),
				VictoryUi.UP_GREEN, "", 15))
	if gains.get_child_count() > 0:
		v.add_child(gains)
	if m.is_empty():
		return
	var u := CombatUnit.from_member(m)
	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 2)
	v.add_child(bars)
	MenuKit.bar_row(bars, Txt.t("UI_VIC_BAR_HP"), VictoryUi.HP_RED, float(m.hp) / maxf(1.0, float(u.max_hp)), "%d/%d" % [int(m.hp), u.max_hp], 76)
	if u.res_kind != "":
		MenuKit.bar_row(bars, Txt.t("RES_" + u.res_kind.to_upper()) if Txt.has("RES_" + u.res_kind.to_upper()) else u.res_kind.to_upper(),
			FrameHud.RES_COLORS.get(u.res_kind, Color.WHITE), float(u.res) / maxf(1.0, float(u.res_max)), "%d/%d" % [u.res, u.res_max], 76)
	MenuKit.bar_row(bars, Txt.t("UI_VIC_BAR_HEART"), VictoryUi.HEART_PINK, float(Game.morale_of(id)) / 100.0, str(Game.morale_of(id)), 76)
	var per := float(maxi(1, int(Db.levels.get("xp_per_level", 100))))
	var s := Game.level_state(id)
	MenuKit.bar_row(bars, Txt.t("UI_VIC_BAR_EXP"), VictoryUi.XP_GOLD, float(s.xp) / per, "%d/%d" % [int(s.xp), int(per)], 76)


## Kept for hosts that still draw their own head (none now): the window's who_card replaces it.
static func header(box: VBoxContainer, id: String, entry: Dictionary) -> void:
	who_card(box, id, entry)


## The pick ([USER] 2026-10-31, a mix of BG3 and a MOBA's skill screen) as kit cards: two across, each its icon, name, a
## New or Rank n to n+1 tag and one line of what it does; the selected one lit gold, its full rules in the detail card
## under them; LEARN / UPGRADE (gold) confirms. foot: the window's foot for the buttons (else `box`); later: Decide
## later's call (none: no such button, the Lodestone menu has its own way out). A pick spends it and calls `refresh`.
static func picks(box: VBoxContainer, id: String, refresh: Callable, foot: Control = null, later := Callable()) -> void:
	var options := _options(id)
	if options.is_empty():  # nothing to learn or grow: no empty row and no greyed button (playtest 2026-11-01, Bushberry)
		return
	var u := CombatUnit.from_member(_member(id))
	var ranks: Dictionary = Game.rank_state(id).ranks
	var head := MenuKit.heading_row(Txt.f("UI_LV_PICK", int(Game.rank_state(id).pending)), true)
	box.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	var detail := MenuKit.card(box)
	detail.get_parent().custom_minimum_size = Vector2(CARD_W * 3 + 20, 0)
	detail.add_theme_constant_override("separation", 4)
	var pick := MenuKit.primary(Txt.t("UI_LV_PICK_SKILL"), Callable(), 20, 260.0)
	pick.disabled = true
	var state := {"chosen": -1}
	var cards: Array[Button] = []
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
		for k in cards.size():
			cards[k].set_pressed_no_signal(k == i)
		_detail(detail, u, options[i], ranks)
		var o2: Dictionary = options[i]
		pick.disabled = bool(o2.locked)
		pick.text = Txt.t("UI_LV_LOCKED_BTN") if o2.locked else Txt.f("UI_LV_LEARN" if o2.learn else "UI_LV_UPGRADE_BTN", _name(o2))
	for i in options.size():
		var o: Dictionary = options[i]
		var c := _card(o)
		c.pressed.connect(func() -> void:
			if state.chosen == i and Input.is_action_just_pressed("ui_accept"):
				confirm.call()  # a second press of the selected card from the keyboard or a pad confirms
			else:
				choose.call(i))
		c.focus_entered.connect(func() -> void: choose.call(i))  # moving along the cards previews each
		grid.add_child(c)
		cards.append(c)
	pick.pressed.connect(confirm)
	var at: Control = foot if foot != null else box
	if later.is_valid():
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		at.add_child(gap)
		var lb := Button.new()
		lb.theme_type_variation = &"QuietButton"
		lb.text = Txt.t("UI_LV_LATER")
		lb.tooltip_text = Txt.t("UI_LV_LATER_TIP")
		lb.custom_minimum_size = Vector2(190, 52)
		lb.add_theme_font_size_override("font_size", 18)
		lb.pressed.connect(later)
		at.add_child(lb)
	at.add_child(pick)
	if not cards.is_empty():
		choose.call(0)
		cards[0].call_deferred("grab_focus")


const CARD_W := 228.0


## One choice as a kit card: its icon, its name, a tag (New, Rank 1 to 2, Coming later) and one line of what it does.
static func _card(o: Dictionary) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(CARD_W, 72)
	b.tooltip_text = _desc(o)
	for n in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var sb: StyleBox = MenuKit.flat(MenuKit.CARD, MenuKit.RIM_DIM, 1.0, 10, 10.0, 8.0)
		if n == "hover":
			sb = MenuKit.flat(MenuKit.BTN_HOVER, MenuKit.RIM, 1.5, 10, 10.0, 8.0)
		elif n in ["pressed", "hover_pressed"]:
			var lit := MenuKit.flat(MenuKit.BTN_HOVER, MenuKit.GOLD, 2.0, 10, 10.0, 8.0)
			lit.shadow_color = Color(MenuKit.GOLD, 0.3)
			lit.shadow_size = 6
			sb = lit
		elif n == "focus":
			sb = StyleBoxEmpty.new()
		b.add_theme_stylebox_override(n, sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.offset_top = 8
	row.offset_bottom = -8
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var slot := PanelContainer.new()
	slot.theme_type_variation = &"KitSlot"
	slot.custom_minimum_size = Vector2(52, 52)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(slot)
	var tex: Texture2D = ActionInfo.icon_for(o.ability) if o.ability != null else ActionInfo.trait_icon(String(o.id))
	var ic: Control
	if tex != null:
		var t := TextureRect.new()
		t.texture = tex
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = Vector2(42, 42)
		ic = t
	else:
		ic = MenuKit.icon_rect("@dot", 40)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(ic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var nm := MenuKit.label(_name(o), 16)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.custom_minimum_size.x = CARD_W - 84
	col.add_child(nm)
	var tag_text := Txt.t("UI_LV_TAG_LOCKED") if o.locked else (Txt.t("UI_LV_TAG_NEW") if o.learn else Txt.f("UI_LV_TAG_RANK", int(o.next)))
	var tag := MenuKit.chip(tag_text, "", Color(0.75, 0.75, 0.75) if o.locked else (VictoryUi.UP_GREEN if o.learn else VictoryUi.XP_GOLD), "", 13)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(tag)
	if o.locked:
		b.modulate = Color(1, 1, 1, 0.6)
	return b


## The first sentence of what an option does (the card's one line; the detail card has it all).
static func _short(o: Dictionary) -> String:
	var d := _desc(o).split("\n")[0]
	var stop := d.find(". ")
	return d.substr(0, stop + 1) if stop > 0 else d


## The detail panel of the selected option: what it is, what it does, its numbers now, what this pick adds, and the next rank.
static func _detail(detail: VBoxContainer, u: CombatUnit, o: Dictionary, ranks: Dictionary) -> void:
	for c in detail.get_children():
		detail.remove_child(c)
		c.queue_free()
	var a: Ability = o.ability
	var have: int = o.have
	var title := MenuKit.label(_name(o) + "   " + (Txt.t("UI_LV_NEW") if o.learn else Txt.f("UI_LV_RANK_OF", [have, LevelRules.max_rank(String(o.id), Db.skill_ranks)])), 20, MenuKit.GOLD)
	detail.add_child(title)
	_line(detail, _desc(o), 16)
	if o.locked:
		_line(detail, Txt.t("UI_LV_LOCKED"), 16, Color(1.0, 0.8, 0.6))
		return
	if a == null and o.learn:  # a trait to learn: what it does
		return
	if a != null:
		_line(detail, Txt.f("UI_LV_NOW", _numbers(u, LevelRules.ranked(a, have, Db.skill_ranks))), 16)
	var steps: Array = Db.upgrade_steps.get(String(o.id), [])
	if o.learn:
		var first := LevelRules.next_useful_rank(String(o.id), 0, Db.skill_ranks)
		if first > 0:
			_line(detail, Txt.f("UI_LV_THEN", String((steps[first - 1] as Dictionary).text)), 15, Color(0.75, 0.9, 0.8))
		return
	var nxt: int = o.next
	var step: Dictionary = steps[nxt - 1]
	var change := _change(u, a, have, nxt, String(step.effect)) if a != null else ""
	_line(detail, Txt.f("UI_LV_THIS", String(step.text)) + ("  (" + change + ")" if change != "" else ""), 16, Color(1.0, 0.92, 0.6))
	var after := LevelRules.next_useful_rank(String(o.id), nxt, Db.skill_ranks)
	if after > 0:
		var s2: Dictionary = steps[after - 1]
		var c2 := _change(u, a, nxt, after, String(s2.effect)) if a != null else ""
		_line(detail, Txt.f("UI_LV_NEXT", String(s2.text)) + ("  (" + c2 + ")" if c2 != "" else ""), 15, Color(0.75, 0.9, 0.8))
	else:
		_line(detail, Txt.t("UI_LV_LAST"), 15, Color(0.75, 0.9, 0.8))


static func _line(box: VBoxContainer, text: String, size: int, color := Color(0.93, 0.9, 0.82)) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(CARD_W * 3 - 10, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	box.add_child(l)


## The name and the plain description of an option: an ability's, or a kit trait's.
static func _name(o: Dictionary) -> String:
	if o.ability != null:
		return Txt.t((o.ability as Ability).name_key)
	if String(o.id) == "guard":
		return Txt.t("ACT_GUARD")
	var key := "TRAIT_" + String(o.id).to_upper()
	return Txt.t(key) if Txt.has(key) else String(o.id).replace("_", " ").to_upper()


static func _desc(o: Dictionary) -> String:
	if o.ability != null:
		return _describe(o.ability, false)
	var key := "TRAIT_" + String(o.id).to_upper() + "_DESC" if String(o.id) != "guard" else "DESC_GUARD"
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

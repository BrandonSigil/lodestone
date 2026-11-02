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
		var w := MenuKit.window(Txt.t("UI_LV_TITLE"), _room, _later, 34)
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

	func _fit() -> void:  # full size at most: its text was already made smaller by hand (X20), not shrunk again
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
	v.get_parent().custom_minimum_size.x = 210
	v.alignment = BoxContainer.ALIGNMENT_CENTER  # with no stats gained it's shorter: centred, not top-heavy
	var pic := MenuKit.portrait(id, 92, true)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(pic)
	if not m.is_empty():
		var nm := MenuKit.label(Txt.t((m.def as CharacterDef).name_key), 18)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nm)
	var levels: Array = entry.get("levels", [])
	var now := int(levels[levels.size() - 1]) if not levels.is_empty() else int(Game.level_state(id).level)
	var was := int(levels[0]) - 1 if not levels.is_empty() else now - 1
	var lv := MenuKit.chip(Txt.f("UI_LV_REACHED", [maxi(1, was), now]), "star_guide", VictoryUi.XP_GOLD, "", 14)
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
				VictoryUi.UP_GREEN, "", 13))
	if gains.get_child_count() > 0:
		v.add_child(gains)
	if m.is_empty():
		return
	var u := CombatUnit.from_member(m)
	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 2)
	v.add_child(bars)
	MenuKit.bar_row(bars, Txt.t("UI_VIC_BAR_HP"), VictoryUi.HP_RED, float(m.hp) / maxf(1.0, float(u.max_hp)), "%d/%d" % [int(m.hp), u.max_hp], 64)
	if u.res_kind != "":
		MenuKit.bar_row(bars, Txt.t("RES_" + u.res_kind.to_upper()) if Txt.has("RES_" + u.res_kind.to_upper()) else u.res_kind.to_upper(),
			FrameHud.RES_COLORS.get(u.res_kind, Color.WHITE), float(u.res) / maxf(1.0, float(u.res_max)), "%d/%d" % [u.res, u.res_max], 64)
	MenuKit.bar_row(bars, Txt.t("UI_VIC_BAR_HEART"), VictoryUi.HEART_PINK, float(Game.morale_of(id)) / 100.0, str(Game.morale_of(id)), 64)
	var per := float(maxi(1, int(Db.levels.get("xp_per_level", 100))))
	var s := Game.level_state(id)
	MenuKit.bar_row(bars, Txt.t("UI_VIC_BAR_EXP"), VictoryUi.XP_GOLD, float(s.xp) / per, "%d/%d" % [int(s.xp), int(per)], 64)
	# where the character stands now: damage, armor, crit and move, each an icon and its number (a gain this level in green)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(grid)
	for st: Array in [["damage", u.damage, "strength"], ["armor", u.armor, "shield"], ["crit", u.crit, "focus"], ["move", u.move, "@leave"]]:
		var k := String(st[0])
		var up := int(stats.get(k, 0)) > 0
		var c := MenuKit.chip("%s %d%s" % [Txt.t("UI_STAT_" + k.to_upper()), int(st[1]), "%" if k == "crit" else ""], String(st[2]),
			VictoryUi.UP_GREEN if up else MenuKit.TEXT, "", 13)
		c.custom_minimum_size.x = 92
		grid.add_child(c)


## Kept for hosts that still draw their own head (none now): the window's who_card replaces it.
static func header(box: VBoxContainer, id: String, entry: Dictionary) -> void:
	who_card(box, id, entry)


## The pick as the character's skill board ([USER] 2026-11-02 X20: "You should see the characters 4 abilities verticall
## with horizontal upgrade nodes so you can see how much youve invested in each skill"; his references: Starsector's skill
## rows, a MOBA's skill path). One row per skill, stacked: its icon, name and a small tag, then its rank track (the first
## node, a circle, is learning it; each diamond after is a rank), the owned nodes gold and the node this pick buys lit
## green. Skills already at their last rank show too, so the whole investment reads at a glance. The selected row is lit
## gold and its rules show in the strip under the rows; LEARN / UPGRADE (gold) confirms. foot: the window's foot for the
## buttons (else `box`); later: Decide later's call (none: no such button, the Lodestone menu has its own way out). A pick
## spends it and calls `refresh`.
static func picks(box: VBoxContainer, id: String, refresh: Callable, foot: Control = null, later := Callable()) -> void:
	var options := _options(id)
	if options.is_empty():  # nothing to learn or grow: no empty row and no greyed button (playtest 2026-11-01, Bushberry)
		return
	var u := CombatUnit.from_member(_member(id))
	var ranks: Dictionary = Game.rank_state(id).ranks
	for a: Ability in u.abilities:  # the known skills with nothing left to buy, as rows too (all gold)
		if not options.any(func(o: Dictionary) -> bool: return o.id == a.id) and LevelRules.max_rank(a.id, Db.skill_ranks) > 0:
			var have := int(ranks.get(a.id, 0))
			options.append({"id": a.id, "ability": a, "learn": false, "have": have, "next": 0, "locked": false, "maxed": true})
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	var hl := MenuKit.label(Txt.t("UI_LV_SKILLS"), 15, MenuKit.TEXT_DIM)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	head.add_child(MenuKit.chip(Txt.f("UI_LV_POINTS", int(Game.rank_state(id).pending)), "star_guide", VictoryUi.XP_GOLD, "", 13))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	box.add_child(list)
	var detail := MenuKit.card(box)
	detail.get_parent().custom_minimum_size = Vector2(ROW_W, DETAIL_H)
	detail.add_theme_constant_override("separation", 3)
	var pick := MenuKit.primary(Txt.t("UI_LV_LEARN_SKILL"), Callable(), 16, 210.0)
	pick.custom_minimum_size.y = 42
	pick.disabled = true
	var state := {"chosen": -1}
	var rows: Array[Button] = []
	var confirm := func() -> void:
		var i: int = state.chosen
		if i < 0 or options[i].locked or options[i].get("maxed", false):
			return
		var o: Dictionary = options[i]
		if o.learn:
			Game.learn_skill(id, String(o.id))
		else:
			Game.rank_skill(id, String(o.id))
		refresh.call()
	var choose := func(i: int) -> void:
		state.chosen = i
		for k in rows.size():
			rows[k].set_pressed_no_signal(k == i)
			(rows[k].get_meta("nodes") as _Nodes).lit = k == i
		_detail(detail, u, options[i], ranks)
		var o2: Dictionary = options[i]
		pick.disabled = bool(o2.locked) or bool(o2.get("maxed", false))
		pick.text = Txt.t("UI_LV_LEARN_SKILL")  # one word for every pick ([USER] 2026-11-02: "just say "Learn Skill"")
	for i in options.size():
		var r := _row(options[i])
		r.pressed.connect(func() -> void:
			if state.chosen == i and Input.is_action_just_pressed("ui_accept"):
				confirm.call()  # a second press of the selected row from the keyboard or a pad confirms
			else:
				choose.call(i))
		r.focus_entered.connect(func() -> void: choose.call(i))  # moving along the rows previews each
		list.add_child(r)
		rows.append(r)
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
		lb.custom_minimum_size = Vector2(150, 42)
		lb.add_theme_font_size_override("font_size", 15)
		lb.pressed.connect(later)
		at.add_child(lb)
	at.add_child(pick)
	if not rows.is_empty():
		choose.call(0)
		rows[0].call_deferred("grab_focus")


const SHOWN_RANKS := 5  ## every skill's track shows five ranks ([USER] 2026-11-02); ranks past its data draw as not built yet
const ROW_W := 520.0  ## a skill row (and the detail strip under the rows)
const ROW_H := 50.0
const DETAIL_H := 112.0  ## the detail strip keeps one height, so the window doesn't jump as the pick moves


## One skill as a row: its icon, name and tag (New skill, Rank n of m, Max rank, Coming later), then its rank track.
static func _row(o: Dictionary) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(ROW_W, ROW_H)
	b.tooltip_text = _desc(o)
	for n in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var sb: StyleBox = MenuKit.flat(MenuKit.CARD, MenuKit.RIM_DIM, 1.0, 8, 8.0, 5.0)
		if n == "hover":
			sb = MenuKit.flat(MenuKit.BTN_HOVER, MenuKit.RIM, 1.5, 8, 8.0, 5.0)
		elif n in ["pressed", "hover_pressed"]:
			var lit := MenuKit.flat(Color(0.09, 0.27, 0.22, 0.97), MenuKit.GOLD, 1.5, 8, 8.0, 5.0)
			lit.border_width_left = 5  # a gold accent bar on the picked row's left edge
			lit.shadow_color = Color(MenuKit.GOLD, 0.3)
			lit.shadow_size = 6
			sb = lit
		elif n == "focus":
			sb = StyleBoxEmpty.new()
		b.add_theme_stylebox_override(n, sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 7
	row.offset_right = -12
	row.offset_top = 5
	row.offset_bottom = -5
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var slot := PanelContainer.new()
	slot.theme_type_variation = &"KitSlot"
	slot.custom_minimum_size = Vector2(40, 40)
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
		t.custom_minimum_size = Vector2(32, 32)
		ic = t
	else:
		ic = MenuKit.icon_rect("@dot", 30)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(ic)
	var badge: Control = null
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.custom_minimum_size.x = 170
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var nm := MenuKit.label(_name(o).to_upper(), 16)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(nm)
	var top := LevelRules.max_rank(String(o.id), Db.skill_ranks)
	var tag_text := Txt.t("UI_LV_TAG_LOCKED") if o.locked else (Txt.t("UI_LV_TAG_NEW") if o.learn \
		else (Txt.t("UI_LV_TAG_MAX") if o.get("maxed", false) else Txt.f("UI_LV_RANK_N", int(o.have))))
	if o.learn and not o.locked:  # a skill not known yet: a green NEW SKILL pill (lit when its row is picked)
		var bp := PanelContainer.new()
		bp.add_theme_stylebox_override("panel", MenuKit.flat(Color(0.05, 0.2, 0.1, 0.95), VictoryUi.UP_GREEN, 1.0, 5, 5.0, 0.0))
		bp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		bp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bl := MenuKit.label(tag_text.to_upper(), 11, VictoryUi.UP_GREEN)
		bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bp.add_child(bl)
		col.add_child(bp)
		badge = bp
	else:
		var tag := MenuKit.label(tag_text, 12, Color(0.75, 0.75, 0.75) if o.locked else Color(0.86, 0.88, 0.82))
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(tag)
	var nodes := _Nodes.new()
	nodes.total = maxi(SHOWN_RANKS, top)
	nodes.built = top
	nodes.owned = 0 if o.learn else int(o.have)
	nodes.buys = nodes.owned if o.learn or int(o.next) <= 0 else int(o.next)
	nodes.badge = badge
	nodes.locked = bool(o.locked)
	nodes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nodes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nodes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(nodes)
	b.set_meta("nodes", nodes)
	if o.locked:
		b.modulate = Color(1, 1, 1, 0.55)
	return b


## A skill's rank track: a diamond per rank, joined by a thin line. Owned ranks are solid gold; the rank this pick buys is
## green, filled and glowing (with a "+1") when the row is selected; the rest are dim. Left-aligned after the name column,
## so every row's track starts at one edge. A skill not known yet has no rank to buy: its NEW SKILL pill lights instead.
class _Nodes extends Control:
	const STEP := 50.0
	const R := 13.0
	var total := 1
	var owned := 0
	var buys := 0  ## owned plus what this pick adds
	var built := 0  ## ranks that exist in ability_upgrades.csv; the rest draw as faint dashed outlines (not in the game yet)
	var locked := false
	var badge: Control = null  ## the NEW SKILL pill, lit with the row
	var lit := false:
		set(v):
			lit = v
			if badge != null:
				badge.modulate = Color(1.25, 1.25, 1.25) if v else Color(1, 1, 1, 0.75)
			queue_redraw()

	func _get_minimum_size() -> Vector2:
		return Vector2(STEP * maxf(1.0, total), 24.0)

	func _draw() -> void:
		var y := size.y * 0.5
		var x0 := R + 6.0  # left-aligned after the name column, so the track sits by its skill
		var dim := Color(MenuKit.RIM, 0.75)
		var green := VictoryUi.UP_GREEN
		if total > 1:
			var last := maxi(0, mini(built, total) - 1)
			draw_line(Vector2(x0, y), Vector2(x0 + STEP * last, y), dim, 1.5, true)
			if last < total - 1:  # on to the ranks not built yet, dashed
				draw_dashed_line(Vector2(x0 + STEP * last, y), Vector2(x0 + STEP * (total - 1), y), Color(MenuKit.TEXT, 0.35), 1.5, 5.0)
			if owned > 1:
				draw_line(Vector2(x0, y), Vector2(x0 + STEP * (owned - 1), y), Color(MenuKit.GOLD, 0.8), 2.0, true)
		for i in total:
			var c := Vector2(x0 + STEP * i, y)
			var col := dim
			var fill := false
			if i < owned:
				col = MenuKit.GOLD
				fill = true
			elif i < buys and not locked:
				col = green
				fill = lit
				if lit:
					draw_circle(c, R + 6.0, Color(green, 0.2))
					if i == owned:  # "+1" beside the rank this pick buys
						var f := get_theme_default_font()
						draw_string(f, c + Vector2(R + 3.0, -R + 3.0), "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, green)
			var pts := PackedVector2Array()
			pts = PackedVector2Array([c + Vector2(0, -R), c + Vector2(R, 0), c + Vector2(0, R), c + Vector2(-R, 0)])
			if i >= built:  # a rank not in the game yet: a faint dashed outline
				for e in 4:
					draw_dashed_line(pts[e], pts[(e + 1) % 4], Color(MenuKit.TEXT, 0.42), 2.0, 4.0)
				continue
			draw_colored_polygon(pts, col if fill else Color(0.16, 0.26, 0.25, 0.9))  # a later rank: a dim filled diamond
			pts.append(pts[0])
			draw_polyline(pts, col, 2.0, true)


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
	var title := MenuKit.label(_name(o), 16, MenuKit.GOLD)
	detail.add_child(title)
	_line(detail, _desc(o), 13)
	if o.locked:
		_line(detail, Txt.t("UI_LV_LOCKED"), 13, Color(1.0, 0.8, 0.6))
		return
	if a == null and o.learn:  # a trait to learn: what it does
		return
	if a != null:  # its numbers now, as chips
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 6)
		chips.add_theme_constant_override("v_separation", 4)
		for part in _number_parts(u, LevelRules.ranked(a, have, Db.skill_ranks)):
			chips.add_child(MenuKit.chip(part, "", MenuKit.TEXT, "", 12))
		if chips.get_child_count() > 0:
			detail.add_child(chips)
	var steps: Array = Db.upgrade_steps.get(String(o.id), [])
	if o.learn:
		var first := LevelRules.next_useful_rank(String(o.id), 0, Db.skill_ranks)
		if first > 0:
			_line(detail, Txt.f("UI_LV_THEN", String((steps[first - 1] as Dictionary).text)), 13, Color(0.75, 0.9, 0.8))
		return
	var nxt: int = o.next
	if nxt <= 0:  # at its last rank: the track shows it, no words ([USER] 2026-11-02)
		return
	var step: Dictionary = steps[nxt - 1]
	var change := _change(u, a, have, nxt, String(step.effect)) if a != null else ""
	_line(detail, Txt.f("UI_LV_THIS", String(step.text)) + ("  (" + change + ")" if change != "" else ""), 13, Color(1.0, 0.92, 0.6))
	var after := LevelRules.next_useful_rank(String(o.id), nxt, Db.skill_ranks)
	if after > 0:
		var s2: Dictionary = steps[after - 1]  # what comes after, in words only (its numbers show once it's the pick)
		_line(detail, Txt.f("UI_LV_NEXT", String(s2.text)), 12, Color(0.75, 0.9, 0.8, 0.7))


static func _line(box: VBoxContainer, text: String, size: int, color := Color(0.93, 0.9, 0.82)) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(ROW_W - 28, 0)
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
	return ", ".join(_number_parts(u, a))


static func _number_parts(u: CombatUnit, a: Ability) -> PackedStringArray:
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
	return parts


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

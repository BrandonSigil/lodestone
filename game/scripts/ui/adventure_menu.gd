class_name AdventureMenu
extends RefCounted
## The Lodestone menu and the pack, shared by the explore maps and the overworld.
## Each fills a dialog box the screen made. `changed` runs after a pick or a use (the screen refreshes
## its HUD and rebuilds the box); `close` shuts the box.

const W := 460.0
const PACK_CELL := 56.0


static var _focus := ""  ## the member whose pick or branch shows under the Lodestone menu's cards


## [USER] 2026-10-28: the Lodestone opens from its bottom-bar button at any time: skill ranks waiting, head back
## to town ([USER] 2026-10-29: stats roll on their own each level; every 4 levels a rank for one of the
## character's own skills). home: false hides GO HOME (in town already, or mid-fight).
## [USER] 2026-11-01 ("way too much text"): one card per member (face, level, XP / HP / heart bars, the fight stats as
## icons); a member with a pick or a job branch waiting gets a gem button that opens it under the cards, one member
## at a time; then blessings, meal and bonds as chips, and the buttons two by two.
static func lodestone(box: VBoxContainer, changed: Callable, close: Callable, home := true, open_list := Callable(), open_options := Callable()) -> void:
	_label(box, Txt.t("UI_LODESTONE"), 20)
	var waiting := func(id: String) -> bool:
		var rs := Game.rank_state(id)
		return LevelUpUi.has_pick(id) or (id == "lead" and Game.job_id() != "" and LevelRules.branch_ready(rs, Db.levels))
	var ids: Array = Game.run.members.map(func(m: Dictionary) -> String: return String(m.def.id))
	if not ids.has(_focus) or not waiting.call(_focus):
		_focus = ""  # closed until its NEW TRICK button is pressed: the menu opens short, at full size
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	for m in Game.run.members:
		var id := String(m.def.id)
		row.add_child(_member_card(m, waiting.call(id), id == _focus, func() -> void:
			_focus = "" if _focus == id else id  # pressed again: closes it
			changed.call()))
	if _focus != "":
		_member_choices(box, _focus, changed)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 6)
	for id in Game.run.boons:
		var b: Dictionary = Db.boons[id]
		chips.add_child(_chip(Txt.f("UI_LS_BLESSING" if b.kind == "blessing" else "UI_LS_SETBACK", Txt.t(String(b.name_key))),
			Color(0.62, 0.9, 0.5) if b.kind == "blessing" else Color(1.0, 0.55, 0.45)))
	if not Game.run.meal.is_empty():
		chips.add_child(_chip(Txt.f("UI_LS_MEAL", [Txt.t(String(Db.recipes.get(String(Game.run.meal.recipe), {}).get("name_key", ""))),
			int(Game.run.meal.fights)]), UiTheme.GOLD))
	if chips.get_child_count() > 0:
		box.add_child(chips)
	_bonds(box, not home)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(grid)
	var cell := func(text: String, cb: Callable) -> void:
		var b := Button.new()
		b.text = text
		b.custom_minimum_size = Vector2(BTN_W, 34)
		b.pressed.connect(cb)
		grid.add_child(b)
	if home:
		cell.call(Txt.t("UI_LS_HOME"), func() -> void:
			close.call()
			Game.wake_in_town(false))
	if open_list.is_valid():
		cell.call(Txt.t("UI_LS_RESTORE"), open_list)
	if open_options.is_valid():
		cell.call(Txt.t("UI_OPTIONS"), open_options)
	cell.call(Txt.t("UI_LS_SAVE_QUIT"), func() -> void:
		# [USER] omr-4, omr-11: put a bookmark in; Continue on the launch menu comes back right here
		var tree := Engine.get_main_loop() as SceneTree
		if tree.current_scene.has_method("bookmark"):
			tree.current_scene.call("bookmark")
		tree.quit())
	cell.call(Txt.t("UI_CLOSE_MENU"), close)


const BTN_W := 228.0
const CARD_W := 210.0
const STAT_ICONS := [["strength", "damage"], ["shield", "armor"], ["focus", "crit"], ["rare", "magic_power"]]


## One member: face and name, LV, the XP, HP and heart bars, the fight stats as icons, and a gem button when a pick waits.
static func _member_card(m: Dictionary, waiting: bool, open: bool, show: Callable) -> Control:
	var d: CharacterDef = m.def
	var id := String(d.id)
	var s := Game.level_state(id)
	var u := CombatUnit.from_member(m)  # the stats it fights with: class, levels, ranks, weapon
	var card := PanelContainer.new()
	card.theme_type_variation = &"InfoPanel"
	card.custom_minimum_size.x = CARD_W
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	col.add_child(top)
	top.add_child(_face(id, d.tint, 56))
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(words)
	var nm := Label.new()
	nm.text = Txt.t(d.name_key)
	nm.add_theme_font_size_override("font_size", 17)
	nm.clip_text = true
	words.add_child(nm)
	var lv := Label.new()
	lv.text = "%s %d" % [Txt.t("UI_VIC_LV"), int(s.level)]
	lv.add_theme_font_size_override("font_size", 15)
	lv.add_theme_color_override("font_color", UiTheme.GOLD)
	words.add_child(lv)
	if id == "lead" and Game.job_id() != "":  # the hero's job and its own level
		var rs := Game.rank_state(id)
		var job: Dictionary = Db.jobs[Game.job_id()]
		var branch := String(rs.get("branch", ""))
		var jl := Label.new()
		jl.text = "%s %d" % [Txt.t(String(job["branch_" + branch] if branch != "" else job.name_key)), int(rs.level)]
		jl.add_theme_font_size_override("font_size", 12)
		jl.add_theme_color_override("font_color", UiTheme.PARCHMENT_DARK)
		jl.clip_text = true
		words.add_child(jl)
	var per := float(maxi(1, int(Db.levels.get("xp_per_level", 100))))
	_bar(col, "star_guide", VictoryUi.XP_GOLD, float(s.xp) / per, "%d/%d" % [int(s.xp), int(per)])
	_bar(col, "potion", VictoryUi.HP_RED, float(m.hp) / maxf(1.0, float(u.max_hp)), "%d/%d" % [int(m.hp), u.max_hp])
	var band := Game.morale_band(id)  # per-character morale ([USER] 2026-10-31): the band and what it does
	var heart := _bar(col, "heal", VictoryUi.HEART_PINK, float(Game.morale_of(id)) / 100.0, Txt.t(String(band.name_key)))
	heart.get_parent().tooltip_text = MoraleRules.describe(band)
	heart.get_parent().mouse_filter = Control.MOUSE_FILTER_PASS
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 2)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(stats)
	for pair in STAT_ICONS:
		var v := int(u.get(pair[1]))
		stats.add_child(_icon(String(pair[0]), 22))
		var l := Label.new()
		l.text = ("%d%%" % v) if pair[1] == "crit" else str(v)
		l.add_theme_font_size_override("font_size", 14)
		l.custom_minimum_size.x = 26
		stats.add_child(l)
	if waiting:
		var b := Button.new()
		b.text = Txt.t("UI_VIC_PICK")
		b.toggle_mode = true
		b.set_pressed_no_signal(open)
		b.custom_minimum_size = Vector2(0, 30)
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_color_override("font_color", UiTheme.GOLD)
		b.pressed.connect(show)
		col.add_child(b)
		if open:
			b.call_deferred("grab_focus")
	return card


## The open member's job branch (when it is ready) and pick.
static func _member_choices(box: VBoxContainer, id: String, changed: Callable) -> void:
	var rs := Game.rank_state(id)
	if id == "lead" and Game.job_id() != "" and LevelRules.branch_ready(rs, Db.levels):
		var job: Dictionary = Db.jobs[Game.job_id()]
		_label(box, Txt.t("UI_LS_BRANCH"), 15)
		var brow := HBoxContainer.new()
		brow.add_theme_constant_override("separation", 8)
		brow.alignment = BoxContainer.ALIGNMENT_CENTER
		for which in ["a", "b"]:
			var bb := Button.new()
			bb.text = Txt.t(String(job["branch_" + which]))
			bb.custom_minimum_size = Vector2(BTN_W, 34)
			bb.pressed.connect(func() -> void:
				Game.choose_branch(which)
				changed.call())
			brow.add_child(bb)
		box.add_child(brow)
	LevelUpUi.picks(box, id, changed)  # the picks decided later: learn a kit ability or upgrade one


static func _bar(col: VBoxContainer, icon: String, fill: Color, value: float, text: String) -> UiBar:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	col.add_child(h)
	h.add_child(_icon(icon, 22))
	var b := UiBar.new()
	b.fill = fill
	b.value = clampf(value, 0.0, 1.0)
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	return b


static func _icon(id: String, px: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = ActionInfo.icon(id)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func _face(id: String, tint: Color, px: float) -> Control:
	var pf := "res://art/source/portraits/%s.png" % id
	if ResourceLoader.exists(pf):
		var t := TextureRect.new()
		t.texture = load(pf)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.custom_minimum_size = Vector2(px, px)
		return t
	var p := PawnIcon.new()
	p.tint = tint
	p.custom_minimum_size = Vector2(px * 0.7, px)
	return p


static func _chip(text: String, col: Color) -> Control:
	var p := PanelContainer.new()
	p.theme_type_variation = &"InfoPanel"
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", col)
	p.add_child(l)
	return p


## Every building's restore ladder at once ([USER] omr-5, like Stardew's community center): steps done,
## under way, open (with what they need) or locked until the settler moves in. WATCH tracks any open step.
static func restore_list(box: VBoxContainer, changed: Callable, close: Callable) -> void:
	_label(box, Txt.t("UI_RESTORE_LIST"), 20)
	var have := Game.have_for_goals()
	for building in RestoreRules.buildings(Db.restore):
		_label(box, Txt.t("BUILDING_" + building.to_upper()), 15)
		if not RestoreRules.is_open(Db.restore, building, Game.meta.flags):
			_label(box, "  " + Game.locked_text(building), 12)
			continue
		for r: Dictionary in RestoreRules.ladder(Db.restore, building):
			var id := String(r.id)
			var st := RestoreRules.status(Game.meta.restore, id)
			var line := "  %s" % Txt.t(String(r.name_key))
			if st == "done":
				_label(box, line + "   " + Txt.t("UI_RESTORE_DONE"), 12)
				continue
			if st == "paid":
				_label(box, line + "   " + Txt.t("UI_RESTORE_WORKING"), 12)
				continue
			var parts: PackedStringArray = []
			var needs := RestoreRules.parse_needs(String(r.needs))
			for k in needs:
				parts.append("%s %d/%d" % [Txt.t(String(Db.items[k].name_key)), mini(int(have.get(k, 0)), int(needs[k])), int(needs[k])])
			var row := HBoxContainer.new()
			var l := Label.new()
			l.text = line + "   " + ", ".join(parts)
			l.add_theme_font_size_override("font_size", 12)
			l.custom_minimum_size = Vector2(W - 130, 0)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(l)
			var b := Button.new()
			b.text = Txt.t("UI_RESTORE_UNTRACK" if Game.meta.tracked.has(id) else "UI_RESTORE_TRACK")
			b.custom_minimum_size = Vector2(120, 26)
			b.pressed.connect(func() -> void:
				Game.toggle_track(id)
				changed.call())
			row.add_child(b)
			box.add_child(row)
	if RestoreRules.buildings(Db.restore).is_empty():
		_label(box, Txt.t("UI_RESTORE_NONE"), 12)
	_button(box, Txt.t("UI_CLOSE_MENU"), close)


## The full inventory page (I or the bag button; [USER] 2026-11-01, like BG3's bags): two windows. PACK holds the pack
## itself (drag to move, R or right-click to turn: [USER] 2026-10-29, rearranging is the little game for the walk), the
## dog's saddlebag right beside it and THROW AWAY under them. PARTY holds each member's belt, the party cards (EAT and
## DRINK ask who, [USER] 2026-10-30; a food or potion stack dropped on a card works the same), gold, the weapon and CLOSE.
## When a pickup found no room the page opens on its own as the pack and FOUND (_pack_full): the new things wait there
## until the player repacks, throws something away, or fills the courier's bag and sends them home ([USER] 2026-10-29);
## LEAVE THE REST leaves whatever is still waiting.
static func pack(box: VBoxContainer, changed: Callable, close: Callable) -> void:
	var run := Game.run
	if run.overfull():
		_pack_full(box, changed, close)
		return
	var grid := PackView.new()
	var cell := PACK_CELL
	var pad := PackView.WINDOW_PAD
	grid.setup_bag(run.pack, Db.items, run.throw_away, cell)
	# PACK: the pack, the saddlebag beside it, the bin a bar under them
	var top := Vector2(pad, pad + PackView.WINDOW_TITLE)
	grid.move_area(0, top + Vector2(0, PackView.LABEL_H))
	var right := top.x + run.pack.cols * cell
	var bottom := top.y + PackView.LABEL_H + run.pack.rows * cell
	var courier := run.courier()
	var bag: InventoryGrid = run.open_courier_bag()  # the dog's 2 x 2 saddlebag, always here while he is along
	if bag != null:
		var who: CharacterDef = courier.def
		var face_path := "res://art/source/portraits/%s.png" % String(who.id)
		grid.add_area(bag, Vector2(right + 22.0, top.y), Txt.f("UI_COURIER_BAG", Txt.t(who.name_key)),
			load(face_path) if ResourceLoader.exists(face_path) else null)
		right += 22.0 + maxf(bag.cols * cell, 112.0)
		bottom = maxf(bottom, top.y + PackView.LABEL_H + bag.rows * cell)
	grid.place_bin(Rect2(Vector2(top.x, bottom + 14.0), Vector2(right - top.x, 34.0)), "UI_THROW", "UI_BOUND_THROW")
	bottom += 14.0 + 34.0
	grid.flash_at = Vector2(top.x, bottom + 14.0)  # "no room", "who eats?"
	bottom += 30.0
	grid.tooltip_text = Txt.t("UI_PACK_HELP_RUN")  # [USER] 2026-11-01 less text: the how-to waits on hover
	var left_w := right + pad
	# PARTY: the belts in a row, one per member (what each can use in a fight), the cards under them, then the rest
	var ox := left_w + ContainerUi.GAP
	var cx := ox + pad
	var belt_w := cell * RunState.BELT_COLS + 24.0
	var per_row := maxi(1, int(W / belt_w))
	var y := top.y
	for k in run.members.size():
		var m: Dictionary = run.members[k]
		var at := Vector2(cx + (k % per_row) * belt_w, y + floorf(float(k) / per_row) * (cell + PackView.LABEL_H + 10.0))
		grid.add_area(m.belt, at, _short(Txt.t((m.def as CharacterDef).name_key)))  # the name alone: the window says PARTY, the grid is their belt
	y += ceilf(float(run.members.size()) / per_row) * (cell + PackView.LABEL_H + 10.0)
	var cards := []
	for m in run.members:
		cards.append({"name": _short(Txt.t((m.def as CharacterDef).name_key)), "hp": int(m.hp), "max_hp": run.max_hp(m)})
	var per_card := PackView.TARGET_SIZE.x + 10.0
	var card_rows := ceili(cards.size() * per_card / (W + 10.0))
	var per_card_row := maxi(1, int((W + 10.0) / per_card))
	grid.add_targets(cards, Vector2(cx, y + 4.0))
	for k in grid.targets.size():  # wrap the cards to the window
		grid.targets[k].rect = Rect2(Vector2(cx + (k % per_card_row) * per_card, y + 4.0 + floorf(float(k) / per_card_row) * (PackView.TARGET_SIZE.y + 8.0)), PackView.TARGET_SIZE)
	grid.target_gain = func(k: int, item: String) -> int: return TravelRules.gain(run, item, run.members[k])
	grid.use_on = func(k: int, item: String) -> bool:
		if not TravelRules.use_on(run, item, run.members[k]):
			return false
		Game.save_adventure()
		return true
	y += card_rows * (PackView.TARGET_SIZE.y + 8.0) + 10.0
	var col := VBoxContainer.new()  # the read-outs and buttons, a real column inside the window
	col.add_theme_constant_override("separation", 4)
	col.position = Vector2(cx, y)
	grid.add_child(col)
	var hurt := TravelRules.most_hurt(run) != {}
	_use_row(col, Txt.f("UI_PACK_FOOD", run.food), Txt.t("UI_EAT"), run.food > 0 and hurt, func() -> void:
		grid.choosing = RunState.FOOD_ITEM
		grid.flash = "UI_WHO_EAT"
		grid.queue_redraw())
	_use_row(col, Txt.f("UI_PACK_POTION", run.medicine), Txt.t("UI_DRINK"), run.medicine > 0 and hurt, func() -> void:
		grid.choosing = RunState.MED_ITEM
		grid.flash = "UI_WHO_DRINK"
		grid.queue_redraw())
	if run.item_count("tonic") > 0:  # mana and charges back, on the walk or at camp
		var short := run.members.any(func(m: Dictionary) -> bool:
			var r := Game.member_res(m)
			return r.kind != "" and int(r.res) < int(r.res_max))
		_use_row(col, Txt.f("UI_PACK_TONIC", run.item_count("tonic")), Txt.t("UI_DRINK"), short, func() -> void:
			if Game.tonic_effect():
				run.add_item("tonic", -1)
			changed.call())
	_label(col, Txt.f("UI_PACK_GOLD", run.gold) + "     " + Txt.f("UI_SLOTS_USED", [run.pack.used_cells(), run.pack.capacity()]), 14)
	var store: PackedStringArray = []
	for id: String in Game.meta.materials:
		store.append("%s %d" % [Txt.t(String(Db.items[id].name_key)), int(Game.meta.materials[id])])
	if not store.is_empty():
		_label(col, Txt.f("UI_VILLAGE_STORE", "  ".join(store)), 13)
	_label(col, Txt.f("UI_PACK_WEAPON", Txt.t(String(Db.weapons.get(Game.weapon_id(), {}).get("name_key", "")))), 13)
	if bag != null and not bag.items.is_empty():  # he can take what he carries home at any time, and rejoins when the party is home
		_button(col, Txt.f("UI_SEND_HOME", Txt.t((courier.def as CharacterDef).name_key)), func() -> void:
			run.send_home(courier)
			Game.refresh_party()
			Game.save_adventure()
			changed.call())
	_button(col, Txt.t("UI_CLOSE_MENU"), close)
	# the windows: as tall as the taller of the two once the column knows its height
	var pack_win := Rect2(Vector2.ZERO, Vector2(left_w, 0))
	var party_win := Rect2(Vector2(ox, 0), Vector2(W + pad * 2.0, 0))
	grid.add_window(pack_win, Txt.t("UI_PACK"))
	grid.add_window(party_win, Txt.t("UI_PARTY"))
	var fit := func() -> void:
		var h := maxf(bottom, col.position.y + maxf(col.size.y, col.get_combined_minimum_size().y)) + pad
		grid.windows[0].rect = Rect2(pack_win.position, Vector2(pack_win.size.x, h))
		grid.windows[1].rect = Rect2(party_win.position, Vector2(party_win.size.x, h))
		grid.refit()
	col.resized.connect(fit)
	grid.changed.connect(func() -> void:
		Game.save_adventure()
		if grid.flash == "":  # a refused move keeps the box up so its "no room" stays readable
			changed.call())
	box.add_child(grid)
	fit.call()
	ContainerUi.bare(box, grid)


## A pickup found no room ([USER] 2026-11-01: the inventory and the loot as two windows): the pack with the dog's saddlebag
## beside it and THROW AWAY under them, and FOUND in its own window with SEND HOME and LEAVE THE REST.
static func _pack_full(box: VBoxContainer, changed: Callable, close: Callable) -> void:
	var run := Game.run
	var view := PackView.new()
	view.setup_bag(run.pack, Db.items, run.throw_away, ContainerUi.CELL)
	var courier := run.courier()
	var bag: InventoryGrid = run.open_courier_bag()
	var buttons := []
	if bag != null:
		buttons.append([Txt.f("UI_SEND_HOME", Txt.t((courier.def as CharacterDef).name_key)), func() -> void:
			run.send_home(courier)
			Game.refresh_party()
			Game.save_adventure()
			changed.call()])
	buttons.append([Txt.t("UI_LEAVE_REST"), func() -> void:
		run.leave_found()
		Game.save_adventure()
		close.call()])
	var made := ContainerUi.windows(view, run.found, Txt.t("UI_FOUND"), buttons, false, Txt.t("UI_PACK_FULL"))
	if bag != null:
		made[0].disabled = bag.items.is_empty()
	view.changed.connect(func() -> void:
		Game.save_adventure()
		if view.flash == "":  # a refused move keeps the box up so its "no room" stays readable
			changed.call())
	box.add_child(view)
	ContainerUi.bare(box, view)


## Options ([USER] 2026-10-30 listed them among the menus that share one look): the fight menu's layout and the
## window. Each pick saves at once (Game.meta.settings); back returns to the Lodestone menu.
static func options(box: VBoxContainer, changed: Callable, back: Callable) -> void:
	_label(box, Txt.t("UI_OPTIONS"), 20)
	_label(box, Txt.t("UI_OPT_FIGHT_MENU"), 15)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for l: String in ActionHud.LAYOUTS:
		var b := Button.new()
		b.text = Txt.t("UI_LAYOUT_" + l.to_upper())
		b.toggle_mode = true
		b.button_pressed = Battle.action_layout() == l
		b.custom_minimum_size = Vector2(108, 30)
		b.pressed.connect(func() -> void:
			Game.set_setting("action_ui", l)
			changed.call())
		row.add_child(b)
	box.add_child(row)
	_label(box, Txt.t("UI_OPT_UI_SIZE"), 15)  # [USER] 2026-10-30: the small UI in 5% notches
	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 6)
	var size := clampf(float(Game.meta.get("settings", {}).get("ui_size", 1.0)), 0.5, 2.0)
	for step: float in [-UiTheme.SIZE_STEP, UiTheme.SIZE_STEP]:
		var b := Button.new()
		b.text = "-5%" if step < 0 else "+5%"
		b.custom_minimum_size = Vector2(90, 30)
		b.pressed.connect(func() -> void:
			Game.set_setting("ui_size", snappedf(clampf(size + step, 0.5, 2.0), UiTheme.SIZE_STEP))
			changed.call())
		size_row.add_child(b)
	var shown := Label.new()
	shown.text = "%d%%" % roundi(size * 100)
	size_row.add_child(shown)
	box.add_child(size_row)
	_label(box, Txt.t("UI_OPT_WINDOW"), 15)
	var full := bool(Game.meta.get("settings", {}).get("fullscreen", false))
	_button(box, Txt.t("UI_OPT_WINDOWED") if full else Txt.t("UI_OPT_FULL"), func() -> void:
		Game.set_setting("fullscreen", not full)
		changed.call())
	_button(box, Txt.t("UI_OPT_BACK"), back)


## The party's bonds (BondRules): each pair with points, its level, and a TALK per level reached. Talks happen at
## home ([USER] 2026-10-30 design-village-life): elsewhere the buttons wait. The lines are Brandon's to write.
static func _bonds(box: VBoxContainer, at_home: bool) -> void:
	var bonds: Dictionary = Game.meta.get("bonds", {})
	var ids: Array = Game.run.members.map(func(m: Dictionary) -> String: return String(m.def.id))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 6)
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var k := BondRules.key(ids[i], ids[j])
			var pts := int(bonds.get(k, 0))
			if pts <= 0:
				continue
			var lv := BondRules.level(pts, Db.bonds)
			var next := int(Db.bonds.get("level_%d" % mini(lv + 1, BondRules.LEVELS), 0))
			var pair := k.split("+")
			var p := PanelContainer.new()
			p.theme_type_variation = &"InfoPanel"
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 4)
			p.add_child(h)
			for n in 2:
				var dd := Db.character(StringName(pair[n]))
				h.add_child(_face(pair[n], dd.tint if dd else Color.GRAY, 30))
				if n == 0:
					h.add_child(_icon("heal", 22))
			var bar := UiBar.new()
			bar.fill = VictoryUi.HEART_PINK
			bar.value = clampf(float(pts) / maxf(1.0, float(next)), 0.0, 1.0)
			bar.text = "%s %d" % [Txt.t("UI_VIC_LV"), lv]
			bar.custom_minimum_size = Vector2(90, 18)
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(bar)
			flow.add_child(p)
			for n in range(1, lv + 1):  # a talk per level reached; they happen at home
				var b := Button.new()
				b.text = Txt.f("UI_LS_TALK", n) if at_home else Txt.t("UI_LS_TALK_AWAY")
				b.disabled = not at_home
				b.add_theme_font_size_override("font_size", 13)
				b.pressed.connect(func() -> void:
					var heard: Array = Game.meta.get("talks_heard", [])
					if not heard.has("%s:%d" % [k, n]):
						heard.append("%s:%d" % [k, n])
						Game.meta.talks_heard = heard
						Game.save_meta()
					_label(box, Txt.t(BondRules.talk_key(k, n)), 13))
				flow.add_child(b)
	if flow.get_child_count() > 0:
		box.add_child(flow)


## A long name cut to its first word so it fits a belt or a card.
static func _short(name: String) -> String:
	return name if name.length() <= 12 else name.split(" ", false)[0]


static func _label(box: BoxContainer, text: String, font_size: int) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W, 0)
	if font_size >= 20:  # a title on its plate (Brandon's frame, the long thin one)
		l.theme_type_variation = &"MenuTitle"
		l.custom_minimum_size = Vector2(W - 40, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var plate := PanelContainer.new()
		plate.theme_type_variation = &"TitlePlate"
		plate.add_child(l)
		box.add_child(plate)
		return
	elif font_size == 15:
		l.theme_type_variation = &"SubTitle"
	else:
		l.add_theme_font_size_override("font_size", font_size)
	box.add_child(l)


static func _button(box: BoxContainer, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(W, 30)
	b.pressed.connect(cb)
	box.add_child(b)
	return b


static func _use_row(box: BoxContainer, text: String, verb: String, enabled: bool, cb: Callable) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(W - 110, 0)
	l.add_theme_font_size_override("font_size", 14)
	row.add_child(l)
	var b := Button.new()
	b.text = verb
	b.custom_minimum_size = Vector2(100, 28)
	b.disabled = not enabled
	b.pressed.connect(cb)
	row.add_child(b)
	box.add_child(row)

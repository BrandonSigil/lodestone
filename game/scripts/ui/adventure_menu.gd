class_name AdventureMenu
extends RefCounted
## The Lodestone menu and the pack, shared by the explore maps and the overworld.
## Each fills a dialog box the screen made. `changed` runs after a pick or a use (the screen refreshes
## its HUD and rebuilds the box); `close` shuts the box.

const W := 414.0
const PACK_CELL := 50.0
const USE_W := 136.0  ## a use row's chip and heal line, before its EAT / DRINK / CAST button
const PARTY_CARD := Vector2(172, 52)  ## a member's card in the pack's PARTY window, their belt beside it


static var _focus := ""  ## the member whose pick or branch shows under the Lodestone menu's cards


const TABS := ["lodestone", "pack", "restore", "options"]  ## the Lodestone menu's tabs, by the ids the screens open them with
const TAB_TEXT := {"lodestone": "UI_PARTY", "pack": "UI_PACK", "restore": "UI_TAB_VILLAGE", "options": "UI_OPTIONS"}
const FOOT_W := 196.0  ## a tab's foot button (GO HOME, SAVE AND QUIT)

static var _hidden := false  ## building a tab's page that is not the open one: nothing in it may take the keys' focus
static var _village_at := 0  ## how far down the VILLAGE tab's list was when TRACK rebuilt the menu


## The one way a screen opens these menus (menus v3, "fewer windows"; Brandon, 2026-11-13: "Yes, tabs next"). With the
## Lodestone in hand the party, the pack, the village's repairs and the options are four tabs of one window: one title,
## one X, one place, and one size whichever tab is open (MenuKit.Stage: every page is built, the open one shows).
## `which` is the tab to open on; `go` reopens the menu on another (the screen's own _open_menu). The pack stands alone
## while there is no Lodestone yet, and when a pickup found no room (that page is a choice to make, not a menu).
## The old painted skin keeps the four separate menus.
static func open(box: VBoxContainer, which: String, changed: Callable, close: Callable, go: Callable, home := true) -> void:
	var lone := which == "pack" and (Game.run.overfull() or not Game.has_flag("has_lodestone"))
	if lone or not UiSkin.on():
		match which:
			"pack":
				pack(box, changed, close)
			"restore":
				restore_list(box, changed, close)
			"options":
				options(box, changed, go.bind("lodestone"))
			_:
				lodestone(box, changed, close, home, go.bind("restore"), go.bind("options"))
		return
	if not TABS.has(which):
		which = "lodestone"
	MenuKit.title_on(box, Txt.t("UI_LODESTONE"))
	var items := []
	for id: String in TABS:
		items.append({"id": id, "text": Txt.t(String(TAB_TEXT[id])), "mark": id == "lodestone" and Game.pending_picks() > 0})
	box.add_child(MenuKit.tabs(items, which, go))
	var stage := MenuKit.Stage.new()
	box.add_child(stage)
	for id: String in TABS:
		var page := VBoxContainer.new()
		page.name = "Tab_" + id
		page.add_theme_constant_override("separation", 10)
		page.visible = id == which
		stage.add_child(page)
		_hidden = id != which
		match id:
			"pack":
				pack(page, changed, close)
			"restore":
				_village_page(page, changed)
			"options":
				_options_page(page, changed)
			_:
				_party_page(page, changed, home)
	_hidden = false
	ContainerUi.bare(box, null, close)  # a menu: the middle of the play area, and the frame's X closes it
	_esc_closes(box)
	if which == "lodestone" and _focus != "" and LevelUpUi.has_pick(_focus):
		_show_pick(box, _focus, changed)


## Esc shuts this window through its X's action (UiTheme.press_close): it has no CLOSE button of its own.
static func _esc_closes(box: Control) -> void:
	var n: Node = box
	while n != null and not (n is PanelContainer and n.has_meta("frame_x")):
		n = n.get_parent()
	if n != null:
		n.set_meta("esc_close", true)


## The PARTY tab: a card per member (three to a row at most), the open member's pick under them, blessings, the meal
## and bonds as chips, and at the foot SAVE AND QUIT and GO HOME.
static func _party_page(box: VBoxContainer, changed: Callable, home: bool) -> void:
	var waiting := func(id: String) -> bool:
		var rs := Game.rank_state(id)
		return LevelUpUi.has_pick(id) or (id == "lead" and Game.job_id() != "" and LevelRules.branch_ready(rs, Db.levels))
	var ids: Array = Game.run.members.map(func(m: Dictionary) -> String: return String(m.def.id))
	if not _hidden and (not ids.has(_focus) or not waiting.call(_focus)):
		_focus = ""
	var shown := "" if _hidden else _focus  # whose NEW ABILITY window is up (open() shows it once the menu is built)
	if shown != "" and Game.job_id() != "" and shown == "lead" and LevelRules.branch_ready(Game.rank_state(shown), Db.levels):
		_branch_row(box, changed)  # the hero's job branch comes first: two buttons over the cards
	var n: int = Game.run.members.size()
	var cards := GridContainer.new()
	cards.columns = n if n <= 3 else mini(3, ceili(n / 2.0))
	cards.add_theme_constant_override("h_separation", 8)
	cards.add_theme_constant_override("v_separation", 8)
	cards.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(cards)
	for m in Game.run.members:
		var id := String(m.def.id)
		cards.add_child(_member_card(m, waiting.call(id), id == shown, func() -> void:
			_focus = "" if _focus == id else id  # pressed again: closes it
			changed.call()))
	var chips := HFlowContainer.new()
	chips.alignment = FlowContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("h_separation", 7)
	chips.add_theme_constant_override("v_separation", 5)
	for id in Game.run.boons:
		var b: Dictionary = Db.boons[id]
		chips.add_child(_chip(String(b.get("short", "")), Color(0.62, 0.9, 0.5) if b.kind == "blessing" else Color(1.0, 0.55, 0.45),
			String(b.get("icon", "")), Txt.f("UI_LS_BLESSING" if b.kind == "blessing" else "UI_LS_SETBACK", Txt.t(String(b.name_key)))))
	if not Game.run.meal.is_empty():
		var rec: Dictionary = Db.recipes.get(String(Game.run.meal.recipe), {})
		chips.add_child(_chip(str(int(Game.run.meal.fights)), UiTheme.GOLD, String(rec.get("meal", "")),
			Txt.f("UI_LS_MEAL", [Txt.t(String(rec.get("name_key", ""))), int(Game.run.meal.fights)])))
	if chips.get_child_count() > 0:
		box.add_child(chips)
	var bonds := VBoxContainer.new()  # a TALK's line lands here, above the foot
	box.add_child(bonds)
	_bonds(bonds, not home)
	var gap := Control.new()  # the foot stands on the window's foot, however tall the other tabs make it
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(gap)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_theme_constant_override("separation", 10)
	box.add_child(foot)
	var quit := Button.new()
	quit.theme_type_variation = &"QuietButton"
	quit.text = Txt.t("UI_LS_SAVE_QUIT")
	quit.custom_minimum_size = Vector2(FOOT_W, 36)
	quit.pressed.connect(func() -> void:
		# [USER] omr-4, omr-11: put a bookmark in; Continue on the launch menu comes back right here
		var tree := Engine.get_main_loop() as SceneTree
		if tree.current_scene.has_method("bookmark"):
			tree.current_scene.call("bookmark")
		var game := tree.root.get_node("Game")  # back to the main menu (2026-11-13), where QUIT closes the game
		game.call("go", game.call("menu_scene")))
	foot.add_child(quit)
	if home:
		var b := Button.new()
		b.text = Txt.t("UI_LS_HOME")
		b.custom_minimum_size = Vector2(FOOT_W, 36)
		b.pressed.connect(func() -> void:
			var close := _close_of(box)
			if close.is_valid():
				close.call()
			Game.wake_in_town(false))
		foot.add_child(b)


## A member's NEW ABILITY, opened from the PARTY tab: the same window a level up shows (LevelUpUi.open), in the menu's
## place, so the skill rows have a whole window and never scroll inside a tab. A pick spends it and rebuilds the menu
## (and comes straight back here while another waits); Decide later, the X and Esc bring the menu back.
static func _show_pick(box: Control, id: String, changed: Callable) -> void:
	var n: Node = box
	while n != null and not (n is PanelContainer and n.has_meta("frame_x")):
		n = n.get_parent()
	var panel := n as PanelContainer
	if panel == null or not panel.is_inside_tree():
		return
	var live := {"on": true, "sc": null}  # the window, reached through this: a lambda keeps a local as it was when made
	var shut := func() -> void:
		live.on = false
		if is_instance_valid(live.sc):
			(live.sc as Node).queue_free()
	var done := func() -> void:
		shut.call()
		_focus = id if LevelUpUi.has_pick(id) else ""
		changed.call()
	var later := func() -> void:
		shut.call()
		_focus = ""
		panel.visible = true
	var sc := LevelUpUi.open(id, {"plain": true}, done, later, panel.get_meta("area", Callable()))
	live.sc = sc
	panel.visible = false
	panel.get_parent().add_child(sc)
	panel.tree_exiting.connect(func() -> void:  # the menu was replaced under it (I, a bar button): it goes too
		if live.on:
			shut.call()
			_focus = "")


## The window's own way out (ContainerUi.bare leaves it on the frame).
static func _close_of(from: Node) -> Callable:
	var n := from
	while n != null and not (n is PanelContainer and n.has_meta("close_cb")):
		n = n.get_parent()
	return n.get_meta("close_cb") as Callable if n != null else Callable()


## The VILLAGE tab: every building's restore ladder ([USER] omr-5), a card a building. A step is done, under way, or
## shows what it still needs as chips (the thing's picture, have / need, gold once there is enough) with TRACK beside
## them. The list scrolls inside the tab, so a long one never makes the window taller.
static func _village_page(box: VBoxContainer, changed: Callable) -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(W + 60.0, 240.0)
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var have := Game.have_for_goals()
	var buildings := RestoreRules.buildings(Db.restore)
	for building in buildings:
		var card := MenuKit.card(list, Txt.t("BUILDING_" + building.to_upper()), true)
		card.add_theme_constant_override("separation", 6)
		if not RestoreRules.is_open(Db.restore, building, Game.meta.flags):
			var locked := MenuKit.label(Game.locked_text(building), UiSkin.T_SMALL, MenuKit.TEXT_DIM)
			locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card.add_child(locked)
			continue
		for r: Dictionary in RestoreRules.ladder(Db.restore, building):
			var id := String(r.id)
			var st := RestoreRules.status(Game.meta.restore, id)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			card.add_child(row)
			var step := MenuKit.label(Txt.t(String(r.name_key)), UiSkin.T_BODY, MenuKit.TEXT_DIM if st == "done" else MenuKit.TEXT)
			step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			step.custom_minimum_size.x = 150.0
			step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(step)
			if st == "done":
				row.add_child(MenuKit.chip(Txt.t("UI_RESTORE_DONE"), "", Color(0.62, 0.9, 0.5), "", UiSkin.T_SMALL))
				continue
			if st == "paid":
				row.add_child(MenuKit.chip(Txt.t("UI_RESTORE_WORKING"), "", MenuKit.GOLD, Txt.t("UI_RESTORE_WAIT"), UiSkin.T_SMALL))
				continue
			var needs := RestoreRules.parse_needs(String(r.needs))
			for k in needs:
				var got := mini(int(have.get(k, 0)), int(needs[k]))
				var item := Txt.t(String(Db.items[k].name_key))
				var pic := ActionInfo.icon(String(k)) != null  # no picture yet: its name stands in
				row.add_child(MenuKit.chip(("%d/%d" if pic else item + " %d/%d") % [got, int(needs[k])], String(k) if pic else "",
					MenuKit.GOLD if got >= int(needs[k]) else MenuKit.TEXT, item, UiSkin.T_SMALL))
			var b := Button.new()
			b.text = Txt.t("UI_RESTORE_UNTRACK" if Game.meta.tracked.has(id) else "UI_RESTORE_TRACK")
			b.custom_minimum_size = Vector2(104, 30)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.add_theme_font_size_override("font_size", UiSkin.T_SMALL)
			b.pressed.connect(func() -> void:
				_village_at = scroll.scroll_vertical  # the rebuilt list opens where this one was
				Game.toggle_track(id)
				changed.call())
			row.add_child(b)
	if buildings.is_empty():
		var none := MenuKit.label(Txt.t("UI_RESTORE_NONE"), UiSkin.T_BODY, MenuKit.TEXT_DIM)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(none)
	if not _hidden and _village_at > 0:
		var at := _village_at
		_village_at = 0
		list.resized.connect(func() -> void: scroll.set_deferred("scroll_vertical", at))


## The OPTIONS tab ([USER] 2026-10-30 listed them among the menus that share one look): the fight menu's layout, the
## small UI's size and the window. A row an option, its name on the left; each pick saves at once (Game.meta.settings).
static func _options_page(box: VBoxContainer, changed: Callable) -> void:
	var rows := MenuKit.card(box)
	rows.add_theme_constant_override("separation", 12)
	(rows.get_parent() as Control).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := func(key: String) -> HBoxContainer:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var l := MenuKit.label(Txt.t(key), UiSkin.T_BODY)
		l.custom_minimum_size.x = 190.0
		h.add_child(l)
		rows.add_child(h)
		return h
	var layout: HBoxContainer = row.call("UI_OPT_FIGHT_MENU")
	for l: String in ActionHud.LAYOUTS:
		var b := Button.new()
		b.text = Txt.t("UI_LAYOUT_" + l.to_upper())
		b.toggle_mode = true
		b.button_pressed = Battle.action_layout() == l
		b.custom_minimum_size = Vector2(98, 32)
		b.pressed.connect(func() -> void:
			Game.set_setting("action_ui", l)
			changed.call())
		layout.add_child(b)
	var size_row: HBoxContainer = row.call("UI_OPT_UI_SIZE")  # [USER] 2026-10-30: the small UI in 5% notches
	var size := clampf(float(Game.meta.get("settings", {}).get("ui_size", 1.0)), 0.5, 2.0)
	for step: float in [-UiTheme.SIZE_STEP, UiTheme.SIZE_STEP]:
		if step > 0:
			var shown := MenuKit.label("%d%%" % roundi(size * 100), UiSkin.T_BODY, MenuKit.GOLD)
			shown.custom_minimum_size.x = 60.0
			shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			size_row.add_child(shown)
		var b := Button.new()
		b.text = "-5%" if step < 0 else "+5%"
		b.custom_minimum_size = Vector2(68, 32)
		b.pressed.connect(func() -> void:
			Game.set_setting("ui_size", snappedf(clampf(size + step, 0.5, 2.0), UiTheme.SIZE_STEP))
			changed.call())
		size_row.add_child(b)
	for vol: Array in [["music_volume", "UI_OPT_MUSIC", 0.7], ["sfx_volume", "UI_OPT_SOUND", 0.8]]:  # 2026-11-13: sound, in 10% steps
		var vrow: HBoxContainer = row.call(String(vol[1]))
		var now := clampf(float(Game.meta.get("settings", {}).get(vol[0], vol[2])), 0.0, 1.0)
		for step: float in [-0.1, 0.1]:
			if step > 0:
				var shown := MenuKit.label(Txt.t("UI_OPT_OFF") if now <= 0.001 else "%d%%" % roundi(now * 100), UiSkin.T_BODY, MenuKit.GOLD)
				shown.custom_minimum_size.x = 60.0
				shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				vrow.add_child(shown)
			var vb := Button.new()
			vb.text = "-" if step < 0 else "+"
			vb.custom_minimum_size = Vector2(68, 32)
			vb.pressed.connect(func() -> void:
				Game.set_setting(String(vol[0]), snappedf(clampf(now + step, 0.0, 1.0), 0.1))
				Sfx.apply_volumes()
				changed.call())
			vrow.add_child(vb)
	var window: HBoxContainer = row.call("UI_OPT_WINDOW")
	var full := bool(Game.meta.get("settings", {}).get("fullscreen", false))
	for want: bool in [false, true]:  # both named, the one in use lit: no guessing what a press will do
		var b := Button.new()
		b.text = Txt.t("UI_OPT_FULL" if want else "UI_OPT_WINDOWED")
		b.toggle_mode = true
		b.button_pressed = full == want
		b.custom_minimum_size = Vector2(98, 32)
		b.pressed.connect(func() -> void:
			Game.set_setting("fullscreen", want)
			changed.call())
		window.add_child(b)


## [USER] 2026-10-28: the Lodestone opens from its bottom-bar button at any time: skill ranks waiting, head back
## to town ([USER] 2026-10-29: stats roll on their own each level; every 4 levels a rank for one of the
## character's own skills). home: false hides GO HOME (in town already, or mid-fight).
## [USER] 2026-11-01 ("way too much text"): one card per member (face, level, XP / HP / heart bars, the fight stats as
## icons); a member with a pick or a job branch waiting gets a gem button that opens it under the cards, one member
## at a time; then blessings, meal and bonds as chips, and the buttons two by two.
static func lodestone(box: VBoxContainer, changed: Callable, close: Callable, home := true, open_list := Callable(), open_options := Callable()) -> void:
	_label(box, Txt.t("UI_LODESTONE"), UiSkin.T_LEAD)
	var waiting := func(id: String) -> bool:
		var rs := Game.rank_state(id)
		return LevelUpUi.has_pick(id) or (id == "lead" and Game.job_id() != "" and LevelRules.branch_ready(rs, Db.levels))
	var ids: Array = Game.run.members.map(func(m: Dictionary) -> String: return String(m.def.id))
	if not ids.has(_focus) or not waiting.call(_focus):
		_focus = ""  # closed until its NEW TRICK button is pressed: the menu opens short, at full size
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	for m in Game.run.members:
		var id := String(m.def.id)
		row.add_child(_member_card(m, waiting.call(id), id == _focus, func() -> void:
			_focus = "" if _focus == id else id  # pressed again: closes it
			changed.call()))
	if _focus != "":
		_member_choices(box, _focus, changed)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 7)
	chips.add_theme_constant_override("v_separation", 5)
	for id in Game.run.boons:  # [USER] 2026-11-01 fewer words: the stat's icon and the change, the whole line on hover
		var b: Dictionary = Db.boons[id]
		chips.add_child(_chip(String(b.get("short", "")), Color(0.62, 0.9, 0.5) if b.kind == "blessing" else Color(1.0, 0.55, 0.45),
			String(b.get("icon", "")), Txt.f("UI_LS_BLESSING" if b.kind == "blessing" else "UI_LS_SETBACK", Txt.t(String(b.name_key)))))
	if not Game.run.meal.is_empty():  # the meal's picture and the fights it still lasts
		var rec: Dictionary = Db.recipes.get(String(Game.run.meal.recipe), {})
		chips.add_child(_chip(str(int(Game.run.meal.fights)), UiTheme.GOLD, String(rec.get("meal", "")),
			Txt.f("UI_LS_MEAL", [Txt.t(String(rec.get("name_key", ""))), int(Game.run.meal.fights)])))
	if chips.get_child_count() > 0:
		box.add_child(chips)
	_bonds(box, not home)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 5)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(grid)
	var cell := func(text: String, cb: Callable) -> void:
		var b := Button.new()
		b.text = text
		b.custom_minimum_size = Vector2(BTN_W, 30)
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
		var game := tree.root.get_node("Game")  # back to the main menu (2026-11-13), where QUIT closes the game
		game.call("go", game.call("menu_scene")))
	cell.call(Txt.t("UI_CLOSE_MENU"), close)


const BTN_W := 206.0
const CARD_W := 188.0
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
	top.add_theme_constant_override("separation", 7)
	col.add_child(top)
	top.add_child(_face(id, d.tint, 50))
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(words)
	var nm := Label.new()
	nm.text = Txt.t(d.name_key)
	nm.add_theme_font_size_override("font_size", UiSkin.T_BODY)
	nm.clip_text = true
	words.add_child(nm)
	var lv := Label.new()
	lv.text = "%s %d" % [Txt.t("UI_VIC_LV"), int(s.level)]
	lv.add_theme_font_size_override("font_size", UiSkin.T_SMALL)
	lv.add_theme_color_override("font_color", UiTheme.GOLD)
	words.add_child(lv)
	if id == "lead" and Game.job_id() != "":  # the hero's job and its own level
		var rs := Game.rank_state(id)
		var job: Dictionary = Db.jobs[Game.job_id()]
		var branch := String(rs.get("branch", ""))
		var jl := Label.new()
		jl.text = "%s %d" % [Txt.t(String(job["branch_" + branch] if branch != "" else job.name_key)), int(rs.level)]
		jl.add_theme_font_size_override("font_size", UiSkin.T_SMALL)
		jl.add_theme_color_override("font_color", UiTheme.PARCHMENT_DARK)
		jl.clip_text = true
		words.add_child(jl)
	var per := float(maxi(1, int(Db.levels.get("xp_per_level", 100))))
	_bar(col, "star_guide", VictoryUi.XP_GOLD, float(s.xp) / per, "%d/%d" % [int(s.xp), int(per)])
	_bar(col, "potion", VictoryUi.HP_RED, float(m.hp) / maxf(1.0, float(u.max_hp)), "%d/%d" % [int(m.hp), u.max_hp])
	if u.res_kind != "":  # mana, rage or charges ([USER] 2026-11-02: HP, mana and Morale bars on every character)
		_bar(col, "rare", FrameHud.RES_COLORS.get(u.res_kind, Color.WHITE), float(u.res) / maxf(1.0, float(u.res_max)), "%d/%d" % [u.res, u.res_max])
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
		stats.add_child(_icon(String(pair[0]), 20))
		var l := Label.new()
		l.text = ("%d%%" % v) if pair[1] == "crit" else str(v)
		l.add_theme_font_size_override("font_size", UiSkin.T_SMALL)
		l.custom_minimum_size.x = 24
		stats.add_child(l)
	if waiting:
		var b := Button.new()
		b.text = Txt.t("UI_VIC_PICK")
		b.toggle_mode = true
		b.set_pressed_no_signal(open)
		b.custom_minimum_size = Vector2(0, 28)
		b.add_theme_font_size_override("font_size", UiSkin.T_SMALL)
		b.add_theme_color_override("font_color", UiTheme.GOLD)
		b.pressed.connect(show)
		col.add_child(b)
		if open:
			b.call_deferred("grab_focus")
	return card


## The hero's job branch, when it is ready: the line that asks and the two branches as buttons.
static func _branch_row(box: VBoxContainer, changed: Callable) -> void:
	var job: Dictionary = Db.jobs[Game.job_id()]
	_label(box, Txt.t("UI_LS_BRANCH"), UiSkin.T_BODY)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 7)
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	for which in ["a", "b"]:
		var bb := Button.new()
		bb.text = Txt.t(String(job["branch_" + which]))
		bb.custom_minimum_size = Vector2(BTN_W, 30)
		bb.pressed.connect(func() -> void:
			Game.choose_branch(which)
			changed.call())
		brow.add_child(bb)
	box.add_child(brow)


## The open member's job branch (when it is ready) and pick.
static func _member_choices(box: VBoxContainer, id: String, changed: Callable) -> void:
	var rs := Game.rank_state(id)
	if id == "lead" and Game.job_id() != "" and LevelRules.branch_ready(rs, Db.levels):
		_branch_row(box, changed)
	LevelUpUi.picks(box, id, changed)  # the picks decided later: learn a kit ability or upgrade one


static func _bar(col: VBoxContainer, icon: String, fill: Color, value: float, text: String) -> UiBar:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	col.add_child(h)
	h.add_child(_icon(icon, 20))
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


## A chip: an icon and a short word or number in `col`, the full line on hover; the full line itself when the icon is
## missing.
static func _chip(text: String, col: Color, icon := "", tip := "") -> Control:
	var p := PanelContainer.new()
	p.theme_type_variation = &"InfoPanel"
	p.tooltip_text = tip
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_child(h)
	var has_icon := ActionInfo.icon(icon) != null
	if has_icon:
		h.add_child(_icon(icon, 22))
	var l := Label.new()
	l.text = text if has_icon or tip == "" else tip
	l.add_theme_font_size_override("font_size", 14 if has_icon else 13)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(l)
	return p


## Every building's restore ladder at once ([USER] omr-5, like Stardew's community center): steps done,
## under way, open (with what they need) or locked until the settler moves in. WATCH tracks any open step.
static func restore_list(box: VBoxContainer, changed: Callable, close: Callable) -> void:
	_label(box, Txt.t("UI_RESTORE_LIST"), UiSkin.T_LEAD)
	var have := Game.have_for_goals()
	for building in RestoreRules.buildings(Db.restore):
		_label(box, Txt.t("BUILDING_" + building.to_upper()), UiSkin.T_BODY)
		if not RestoreRules.is_open(Db.restore, building, Game.meta.flags):
			_label(box, "  " + Game.locked_text(building), UiSkin.T_SMALL)
			continue
		for r: Dictionary in RestoreRules.ladder(Db.restore, building):
			var id := String(r.id)
			var st := RestoreRules.status(Game.meta.restore, id)
			var line := "  %s" % Txt.t(String(r.name_key))
			if st == "done":
				_label(box, line + "   " + Txt.t("UI_RESTORE_DONE"), UiSkin.T_SMALL)
				continue
			if st == "paid":
				_label(box, line + "   " + Txt.t("UI_RESTORE_WORKING"), UiSkin.T_SMALL)
				continue
			var parts: PackedStringArray = []
			var needs := RestoreRules.parse_needs(String(r.needs))
			for k in needs:
				parts.append("%s %d/%d" % [Txt.t(String(Db.items[k].name_key)), mini(int(have.get(k, 0)), int(needs[k])), int(needs[k])])
			var row := HBoxContainer.new()
			var l := Label.new()
			l.text = line + "   " + ", ".join(parts)
			l.add_theme_font_size_override("font_size", UiSkin.T_SMALL)
			l.custom_minimum_size = Vector2(W - 116, 0)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(l)
			var b := Button.new()
			b.text = Txt.t("UI_RESTORE_UNTRACK" if Game.meta.tracked.has(id) else "UI_RESTORE_TRACK")
			b.custom_minimum_size = Vector2(108, 24)
			b.pressed.connect(func() -> void:
				Game.toggle_track(id)
				changed.call())
			row.add_child(b)
			box.add_child(row)
	if RestoreRules.buildings(Db.restore).is_empty():
		_label(box, Txt.t("UI_RESTORE_NONE"), UiSkin.T_SMALL)
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
	var pad := ContainerUi.SECTION_PAD
	grid.sections = true  # one window: PACK and PARTY are its two sections (menus v3)
	grid.setup_bag(run.pack, Db.items, run.throw_away, cell)
	# PACK: the pack, the dog's saddlebag beside it in its inset, the bin a bar under them
	var top := Vector2(pad, PackView.WINDOW_TITLE + 6.0)
	var courier := run.courier()
	var bag: InventoryGrid = run.open_courier_bag()  # the dog's 2 x 2 saddlebag, always here while he is along
	grid.move_area(0, top)
	var right := top.x + run.pack.cols * cell
	var bottom := top.y + run.pack.rows * cell
	if bag != null:
		var end := ContainerUi.saddle_beside(grid, bag, right, top.y, -1)
		right = end.x
		bottom = maxf(bottom, end.y)
	grid.place_bin(Rect2(Vector2(top.x, bottom + 10.0), Vector2(right - top.x, 30.0)), "UI_THROW", "UI_BOUND_THROW")
	bottom += 40.0
	grid.flash_at = Vector2(top.x, bottom + 14.0)  # "no room", "who eats?"
	bottom += 24.0
	grid.tooltip_text = Txt.t("UI_PACK_HELP_RUN")  # [USER] 2026-11-01 less text: the how-to waits on hover
	var left_w := right + pad
	# PARTY: a row per member, their card (face, name, HP) with their belt beside it (what each can use in a fight); drop
	# food or a potion on a card, or EAT / DRINK then click one. Then the rest. As wide as its widest row.
	var ox := left_w + ContainerUi.GAP
	var cx := ox + pad
	var y := top.y
	var cards := []
	var row_h := maxf(PARTY_CARD.y, cell) + 8.0
	# more than three along: their rows fill the PARTY section, so the use rows and counts stand under the pack instead,
	# where a big party leaves the room; the window stays short enough for the play area either way
	var under_pack: bool = run.members.size() > 3
	var party_w := 0.0 if under_pack else USE_W + 110.0
	for k in run.members.size():
		var m: Dictionary = run.members[k]
		cards.append({"name": _short(Txt.t((m.def as CharacterDef).name_key)), "hp": int(m.hp), "max_hp": run.max_hp(m),
			"face": ContainerUi.face_of(String((m.def as CharacterDef).id))})
		grid.add_area(m.belt, Vector2(cx + PARTY_CARD.x + 12.0, y + k * row_h + roundf((PARTY_CARD.y - cell) * 0.5)), "", null)
		party_w = maxf(party_w, PARTY_CARD.x + 12.0 + (m.belt as InventoryGrid).cols * cell)
	grid.add_targets(cards, Vector2(cx, y))
	for k in grid.targets.size():
		grid.targets[k].rect = Rect2(Vector2(cx, y + k * row_h), PARTY_CARD)
	grid.target_gain = func(k: int, item: String) -> int: return TravelRules.gain(run, item, run.members[k])
	grid.use_on = func(k: int, item: String) -> bool:
		if not TravelRules.use_on(run, item, run.members[k]):
			return false
		Game.save_adventure()
		return true
	y += run.members.size() * row_h + 4.0
	var col := VBoxContainer.new()  # the read-outs and buttons, a real column inside the window
	col.add_theme_constant_override("separation", 4)
	col.position = Vector2(top.x, bottom) if under_pack else Vector2(cx, y)
	var col_w := right - top.x if under_pack else party_w
	grid.add_child(col)
	var hurt := TravelRules.most_hurt(run) != {}
	for food: String in Db.items:  # each food that heals: meat always, then any caught fish carried
		if not TravelRules.is_food(food) or (food != RunState.FOOD_ITEM and run.item_count(food) <= 0):
			continue
		var tip := Txt.t("UI_PACK_FOOD_TIP") if food == RunState.FOOD_ITEM else Txt.t(String(Db.items[food].name_key))
		_use_row(col, food, run.item_count(food), tip,
			Txt.t("UI_EAT"), run.item_count(food) > 0 and hurt, func() -> void:
				grid.choosing = food
				grid.flash = "UI_WHO_EAT"
				grid.queue_redraw(), TravelRules.food_heal(run, food))
	_use_row(col, "potion", run.medicine, Txt.t("UI_PACK_POTION_TIP"), Txt.t("UI_DRINK"), run.medicine > 0 and hurt, func() -> void:
		grid.choosing = RunState.MED_ITEM
		grid.flash = "UI_WHO_DRINK"
		grid.queue_redraw())
	for m in run.members:  # [USER] 2026-11-01 healing model A: support heals cast out of a fight, at their mana cost
		for a: Ability in TravelRules.road_heals(m):
			var key := TravelRules.cast_key(m, a)
			var r := Game.member_res(m)
			var who := Txt.t((m.def as CharacterDef).name_key)
			_use_row(col, a.id, int(r.res), "%s: %s (%d %s)" % [who, Txt.t(a.name_key), a.res_cost, String(r.kind)], Txt.t("UI_CAST"),
				TravelRules.can_cast(m, a) and hurt, func() -> void:
					grid.choosing = key
					grid.flash = "UI_WHO_HEAL"
					grid.queue_redraw(), TravelRules.cast_amount(m, a))
	if run.item_count("tonic") > 0:  # mana and charges back, on the walk or at camp
		var short := run.members.any(func(m: Dictionary) -> bool:
			var r := Game.member_res(m)
			return r.kind != "" and int(r.res) < int(r.res_max))
		_use_row(col, "tonic", run.item_count("tonic"), Txt.t("ITEM_TONIC"), Txt.t("UI_DRINK"), short, func() -> void:
			if Game.tonic_effect():
				run.add_item("tonic", -1)
			changed.call())
	var counts := HFlowContainer.new()  # [USER] 2026-11-01 "We've got icons! We should use em!": a picture and a number
	counts.add_theme_constant_override("h_separation", 12)
	counts.add_theme_constant_override("v_separation", 4)
	counts.custom_minimum_size.x = col_w
	col.add_child(counts)
	counts.add_child(MenuKit.chip(str(run.gold), "gold", MenuKit.TEXT, Txt.t("UI_PACK_GOLD_TIP"), UiSkin.T_SMALL))
	counts.add_child(MenuKit.chip("%d/%d" % [run.pack.used_cells(), run.pack.capacity()], "backpack", MenuKit.TEXT, Txt.t("UI_PACK_SLOTS_TIP"), UiSkin.T_SMALL))
	var weapon := Db.weapons.get(Game.weapon_id(), {}) as Dictionary
	if not weapon.is_empty() and Game.weapon_id() != "none":  # bare hands need no line
		counts.add_child(MenuKit.chip(Txt.t(String(weapon.name_key)), String(weapon.get("icon", "")), MenuKit.TEXT, Txt.t("UI_PACK_WEAPON_TIP"), UiSkin.T_SMALL))
	if not Game.meta.materials.is_empty():  # the village pile: each material's icon and count
		var pile := HFlowContainer.new()
		pile.add_theme_constant_override("h_separation", 8)
		pile.add_theme_constant_override("v_separation", 4)
		pile.custom_minimum_size.x = col_w
		pile.tooltip_text = Txt.t("UI_VILLAGE_STORE_TIP")
		pile.mouse_filter = Control.MOUSE_FILTER_PASS
		col.add_child(pile)
		for id: String in Game.meta.materials:  # each material at home as a kit chip, its name on hover
			pile.add_child(MenuKit.chip(str(int(Game.meta.materials[id])), id, MenuKit.TEXT, Txt.t(String(Db.items[id].name_key)), UiSkin.T_SMALL))
	if bag != null and not bag.items.is_empty():  # he can take what he carries home at any time, and rejoins when the party is home
		var send := _button(col, Txt.f("UI_SEND_HOME", Txt.t((courier.def as CharacterDef).name_key)), func() -> void:
			run.send_home(courier)
			Game.refresh_party()
			Game.save_adventure()
			changed.call())
		send.custom_minimum_size.x = col_w
	# no CLOSE: the window's X (and Esc) closes ([USER] 2026-11-02, fewer words)
	# the sections: as tall as the taller of the two once the column knows its height
	var pack_win := Rect2(Vector2.ZERO, Vector2(left_w, 0))
	var party_win := Rect2(Vector2(ox, 0), Vector2(party_w + pad * 2.0, 0))
	grid.add_window(pack_win, Txt.t("UI_PACK"))
	grid.add_window(party_win, Txt.t("UI_PARTY"))
	var fit := func() -> void:
		var h := maxf(maxf(bottom, y - 4.0), col.position.y + maxf(col.size.y, col.get_combined_minimum_size().y)) + pad - 4.0
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
	ContainerUi.bare(box, grid, close)
	_esc_closes(box)


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
	var drop := func() -> void:  # LEAVE REST HERE and the X ([USER] 2026-11-02: closing leaves the items on the ground,
		run.leave_found()  # where an explore map keeps them as a pile until the party leaves: RunState.on_left_found)
		Game.save_adventure()
		close.call()
	buttons.append([Txt.t("UI_LEAVE_REST"), drop])
	var made := ContainerUi.windows(view, run.found, Txt.t("UI_FOUND"), buttons, false, "", null, drop)
	view.tooltip_text = Txt.t("UI_PACK_FULL")  # [USER] 2026-11-01 fewer words: the window's title says it, the line waits on hover
	if bag != null:
		made[0].disabled = bag.items.is_empty()
	view.changed.connect(func() -> void:
		Game.save_adventure()
		if view.flash == "":  # a refused move keeps the box up so its "no room" stays readable
			changed.call())
	box.add_child(view)
	ContainerUi.bare(box, view, drop)


## Options ([USER] 2026-10-30 listed them among the menus that share one look): the fight menu's layout and the
## window. Each pick saves at once (Game.meta.settings); back returns to the Lodestone menu.
static func options(box: VBoxContainer, changed: Callable, back: Callable) -> void:
	_label(box, Txt.t("UI_OPTIONS"), UiSkin.T_LEAD)
	_label(box, Txt.t("UI_OPT_FIGHT_MENU"), UiSkin.T_BODY)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	for l: String in ActionHud.LAYOUTS:
		var b := Button.new()
		b.text = Txt.t("UI_LAYOUT_" + l.to_upper())
		b.toggle_mode = true
		b.button_pressed = Battle.action_layout() == l
		b.custom_minimum_size = Vector2(98, 28)
		b.pressed.connect(func() -> void:
			Game.set_setting("action_ui", l)
			changed.call())
		row.add_child(b)
	box.add_child(row)
	_label(box, Txt.t("UI_OPT_UI_SIZE"), UiSkin.T_BODY)  # [USER] 2026-10-30: the small UI in 5% notches
	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 5)
	var size := clampf(float(Game.meta.get("settings", {}).get("ui_size", 1.0)), 0.5, 2.0)
	for step: float in [-UiTheme.SIZE_STEP, UiTheme.SIZE_STEP]:
		var b := Button.new()
		b.text = "-5%" if step < 0 else "+5%"
		b.custom_minimum_size = Vector2(80, 28)
		b.pressed.connect(func() -> void:
			Game.set_setting("ui_size", snappedf(clampf(size + step, 0.5, 2.0), UiTheme.SIZE_STEP))
			changed.call())
		size_row.add_child(b)
	var shown := Label.new()
	shown.text = "%d%%" % roundi(size * 100)
	size_row.add_child(shown)
	box.add_child(size_row)
	for vol: Array in [["music_volume", "UI_OPT_MUSIC", 0.7], ["sfx_volume", "UI_OPT_SOUND", 0.8]]:  # 2026-11-13: sound
		_label(box, Txt.t(String(vol[1])), UiSkin.T_BODY)
		var vrow := HBoxContainer.new()
		vrow.add_theme_constant_override("separation", 6)
		var now := clampf(float(Game.meta.get("settings", {}).get(vol[0], vol[2])), 0.0, 1.0)
		for step: float in [-0.1, 0.1]:
			var vb := Button.new()
			vb.text = "-" if step < 0 else "+"
			vb.custom_minimum_size = Vector2(60, 30)
			vb.pressed.connect(func() -> void:
				Game.set_setting(String(vol[0]), snappedf(clampf(now + step, 0.0, 1.0), 0.1))
				Sfx.apply_volumes()
				changed.call())
			vrow.add_child(vb)
		var vl := Label.new()
		vl.text = Txt.t("UI_OPT_OFF") if now <= 0.001 else "%d%%" % roundi(now * 100)
		vrow.add_child(vl)
		box.add_child(vrow)
	_label(box, Txt.t("UI_OPT_WINDOW"), UiSkin.T_BODY)
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
	flow.add_theme_constant_override("h_separation", 7)
	flow.add_theme_constant_override("v_separation", 5)
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
				h.add_child(_face(pair[n], dd.tint if dd else Color.GRAY, 28))
				if n == 0:
					h.add_child(_icon("heal", 20))
			var bar := UiBar.new()
			bar.fill = VictoryUi.HEART_PINK
			bar.value = clampf(float(pts) / maxf(1.0, float(next)), 0.0, 1.0)
			bar.text = "%s %d" % [Txt.t("UI_VIC_LV"), lv]
			bar.custom_minimum_size = Vector2(80, 16)
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(bar)
			flow.add_child(p)
			for n in range(1, lv + 1):  # a talk per level reached; they happen at home
				var b := Button.new()
				b.text = Txt.f("UI_LS_TALK", n) if at_home else Txt.t("UI_LS_TALK_AWAY")
				b.disabled = not at_home
				b.add_theme_font_size_override("font_size", UiSkin.T_SMALL)
				b.pressed.connect(func() -> void:
					var heard: Array = Game.meta.get("talks_heard", [])
					if not heard.has("%s:%d" % [k, n]):
						heard.append("%s:%d" % [k, n])
						Game.meta.talks_heard = heard
						Game.save_meta()
					_label(box, Txt.t(BondRules.talk_key(k, n)), UiSkin.T_SMALL))
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
	if font_size >= UiSkin.T_LEAD and UiSkin.on():  # a window's title: the banner across its top edge, as on every window
		MenuKit.title_on(box, text)
		return
	if font_size >= UiSkin.T_LEAD:  # a title on its plate (Brandon's frame, the long thin one)
		l.theme_type_variation = &"MenuTitle"
		l.custom_minimum_size = Vector2(W - 36, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var plate := PanelContainer.new()
		plate.theme_type_variation = &"TitlePlate"
		if UiSkin.on():  # the drawn banner: as wide as its words, centred, so it clears the X in the corner
			l.autowrap_mode = TextServer.AUTOWRAP_OFF
			l.custom_minimum_size = Vector2(136.0, 0)
			plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		plate.add_child(l)
		box.add_child(plate)
		return
	elif font_size == UiSkin.T_BODY:  # a section heading
		l.theme_type_variation = &"SubTitle"
	else:
		l.add_theme_font_size_override("font_size", font_size)
	box.add_child(l)


## A small picture and a number (or a word), with what it is on hover; the word itself when there is no picture yet.
static func _count(icon: String, text: String, tip: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.tooltip_text = tip
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	var tex := ActionInfo.icon(icon)
	if tex != null:
		h.add_child(_icon(icon, 22))
	var l := Label.new()
	l.text = text if tex != null else "%s %s" % [tip, text]
	l.add_theme_font_size_override("font_size", UiSkin.T_SMALL)
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(l)
	return h


static func _button(box: BoxContainer, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(W, 28)
	b.pressed.connect(cb)
	box.add_child(b)
	return b


## A thing's picture and how many, its name on hover; the button that uses one at the end of the row.
## `heal` > 0: what one heals, in green after the count (the fish grades look alike, the number tells them apart).
static func _use_row(box: BoxContainer, icon: String, n: int, tip: String, verb: String, enabled: bool, cb: Callable, heal := 0) -> void:
	var row := HBoxContainer.new()
	var c := HBoxContainer.new()  # the thing as a kit chip (its picture and how many), what one heals beside it
	c.add_theme_constant_override("separation", 7)
	c.custom_minimum_size = Vector2(USE_W, 0)  # the button right after it, by the thing it uses
	c.add_child(MenuKit.chip(str(n), icon, MenuKit.TEXT, tip, UiSkin.T_SMALL))
	if heal > 0:
		var g := Label.new()
		g.text = Txt.f("UI_GAIN_HP", heal)
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		g.add_theme_font_size_override("font_size", UiSkin.T_SMALL)
		g.add_theme_color_override("font_color", Color(0.62, 0.9, 0.5))
		g.mouse_filter = Control.MOUSE_FILTER_PASS
		c.add_child(g)
	row.add_child(c)
	var b := Button.new()
	b.text = verb
	b.custom_minimum_size = Vector2(90, 26)
	b.disabled = not enabled
	b.pressed.connect(cb)
	row.add_child(b)
	box.add_child(row)

class_name AdventureMenu
extends RefCounted
## The Lodestone menu and the pack, shared by the explore maps and the overworld.
## Each fills a dialog box the screen made. `changed` runs after a pick or a use (the screen refreshes
## its HUD and rebuilds the box); `close` shuts the box.

const W := 460.0
const PACK_CELL := 56.0
const FULL_CELL := 46.0  ## smaller when FOUND and the courier's bag share the box


## [USER] 2026-10-28: the Lodestone opens from its bottom-bar button at any time: skill ranks waiting, head back
## to town ([USER] 2026-10-29: stats roll on their own each level; every 4 levels a rank for one of the
## character's own skills). home: false hides GO HOME (in town already, or mid-fight).
static func lodestone(box: VBoxContainer, changed: Callable, close: Callable, home := true, open_list := Callable(), open_options := Callable()) -> void:
	_label(box, Txt.t("UI_LODESTONE"), 20)
	for m in Game.run.members:
		var d: CharacterDef = m.def
		var id := String(d.id)
		var s := Game.level_state(id)
		var u := CombatUnit.from_member(m)  # the stats it fights with: class, levels, ranks, weapon
		_label(box, Txt.f("UI_LS_MEMBER", [Txt.t(d.name_key), int(s.level), int(s.xp), int(Db.levels.get("xp_per_level", 100)),
			int(m.hp), u.max_hp, u.damage, u.armor, u.crit, u.magic_power]), 14)
		var rs := Game.rank_state(id)  # the hero's ranks belong to his job
		if id == "lead" and Game.job_id() != "":
			var job: Dictionary = Db.jobs[Game.job_id()]
			var branch := String(rs.get("branch", ""))
			_label(box, Txt.f("UI_LS_JOB", [Txt.t(String(job.name_key)), int(rs.level),
				Txt.t(String(job["branch_" + branch])) if branch != "" else ""]), 13)
			if LevelRules.branch_ready(rs, Db.levels):
				_label(box, Txt.t("UI_LS_BRANCH"), 13)
				var brow := HBoxContainer.new()
				brow.add_theme_constant_override("separation", 6)
				for which in ["a", "b"]:
					var bb := Button.new()
					bb.text = Txt.t(String(job["branch_" + which]))
					bb.custom_minimum_size = Vector2(200, 30)
					bb.pressed.connect(func() -> void:
						Game.choose_branch(which)
						changed.call())
					brow.add_child(bb)
				box.add_child(brow)
		LevelUpUi.picks(box, id, changed)  # the picks decided later: learn a kit ability or upgrade one
	for id in Game.run.boons:
		var b: Dictionary = Db.boons[id]
		_label(box, Txt.f("UI_LS_BLESSING" if b.kind == "blessing" else "UI_LS_SETBACK", Txt.t(String(b.name_key))), 13)
	if not Game.run.meal.is_empty():
		_label(box, Txt.f("UI_LS_MEAL", [Txt.t(String(Db.recipes.get(String(Game.run.meal.recipe), {}).get("name_key", ""))),
			int(Game.run.meal.fights)]), 13)
	_bonds(box, not home)
	if home:
		_button(box, Txt.t("UI_LS_HOME"), func() -> void:
			close.call()
			Game.wake_in_town(false))
	if open_list.is_valid():
		_button(box, Txt.t("UI_LS_RESTORE"), open_list)
	if open_options.is_valid():
		_button(box, Txt.t("UI_OPTIONS"), open_options)
	_button(box, Txt.t("UI_LS_SAVE_QUIT"), func() -> void:
		# [USER] omr-4, omr-11: put a bookmark in; Continue on the launch menu comes back right here
		var tree := Engine.get_main_loop() as SceneTree
		if tree.current_scene.has_method("bookmark"):
			tree.current_scene.call("bookmark")
		tree.quit())
	_button(box, Txt.t("UI_CLOSE_MENU"), close)


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


## What the party carries, with EAT and DRINK for the hurt. The grid is the pack itself: drag to move,
## R or right-click to turn ([USER] 2026-10-29: rearranging is the little game for the walk). Each member's
## belt sits under it. When a pickup found no room the box opens on its own, full: the new things wait in
## FOUND beside the pack until the player repacks, throws something away, or fills the courier's bag and
## sends them home ([USER] 2026-10-29); LEAVE THE REST leaves whatever is still waiting.
static func pack(box: VBoxContainer, changed: Callable, close: Callable) -> void:
	var run := Game.run
	var full := run.overfull()
	_label(box, Txt.t("UI_PACK"), 20)
	if full:
		_label(box, Txt.t("UI_PACK_FULL"), 14)
	var grid := PackView.new()
	if not full:
		# EAT and DRINK ask who ([USER] 2026-10-30): the party cards under the belts show what each would
		# gain; click one (Esc cancels). A food or potion stack dropped on a card works the same.
		var hurt := TravelRules.most_hurt(run) != {}
		_use_row(box, Txt.f("UI_PACK_FOOD", run.food), Txt.t("UI_EAT"), run.food > 0 and hurt, func() -> void:
			grid.choosing = RunState.FOOD_ITEM
			grid.flash = "UI_WHO_EAT"
			grid.queue_redraw())
		_use_row(box, Txt.f("UI_PACK_POTION", run.medicine), Txt.t("UI_DRINK"), run.medicine > 0 and hurt, func() -> void:
			grid.choosing = RunState.MED_ITEM
			grid.flash = "UI_WHO_DRINK"
			grid.queue_redraw())
		if run.item_count("tonic") > 0:  # mana and charges back, on the walk or at camp
			var short := run.members.any(func(m: Dictionary) -> bool:
				var r := Game.member_res(m)
				return r.kind != "" and int(r.res) < int(r.res_max))
			_use_row(box, Txt.f("UI_PACK_TONIC", run.item_count("tonic")), Txt.t("UI_DRINK"), short, func() -> void:
				if Game.tonic_effect():
					run.add_item("tonic", -1)
				changed.call())
		var finds := run.items
		for id: String in finds:
			if id != RunState.FOOD_ITEM and id != RunState.MED_ITEM and id != "tonic":
				_label(box, "%s  x%d" % [Txt.t(String(Db.items[id].name_key)), int(finds[id])], 14)
	_label(box, Txt.t("UI_PACK_HELP_RUN"), 12)
	var cell := FULL_CELL if full else PACK_CELL
	grid.setup_bag(run.pack, Db.items, run.throw_away, cell)
	var pack_size := Vector2(RunState.PACK_COLS, RunState.PACK_ROWS) * cell
	if full:
		grid.add_area(run.found, Vector2(pack_size.x + 24.0, 0), Txt.t("UI_FOUND"))
	# the belts in a row under the pack, one per member: what each can use in a fight
	var belt_w := cell * RunState.BELT_COLS + 24.0
	var per_row := maxi(1, int(W / belt_w))
	var y := pack_size.y + 14.0
	for k in run.members.size():
		var m: Dictionary = run.members[k]
		var at := Vector2((k % per_row) * belt_w, y + floorf(float(k) / per_row) * (cell + PackView.LABEL_H + 10.0))
		grid.add_area(m.belt, at, Txt.f("UI_BELT_OF", Txt.t((m.def as CharacterDef).name_key)))
	y += ceilf(float(run.members.size()) / per_row) * (cell + PackView.LABEL_H + 10.0)
	if not full:
		var cards := []
		for m in run.members:
			cards.append({"name": Txt.t((m.def as CharacterDef).name_key), "hp": int(m.hp), "max_hp": run.max_hp(m)})
		grid.add_targets(cards, Vector2(0, y + 4.0))
		grid.target_gain = func(k: int, item: String) -> int: return TravelRules.gain(run, item, run.members[k])
		grid.use_on = func(k: int, item: String) -> bool:
			if not TravelRules.use_on(run, item, run.members[k]):
				return false
			Game.save_adventure()
			return true
		y += PackView.TARGET_SIZE.y + 14.0
	var courier := run.courier()
	var bag: InventoryGrid = run.open_courier_bag()  # the dog's 2 x 2 saddlebag, always here while he is along
	var bag_label := ""
	var face: Texture2D = null
	if bag != null:
		bag_label = Txt.f("UI_COURIER_BAG", Txt.t((courier.def as CharacterDef).name_key))
		var face_path := "res://art/source/portraits/%s.png" % String((courier.def as CharacterDef).id)
		face = load(face_path) if ResourceLoader.exists(face_path) else null
	if bag != null and full:  # sorting the finds: the bag below the party cards, the bin by it
		grid.add_area(bag, Vector2(0, y), bag_label, face)
		grid.place_bin(Rect2(Vector2(bag.cols * cell + 24.0, y + PackView.LABEL_H), Vector2(150, bag.rows * cell)), "UI_THROW", "UI_BOUND_THROW")
	elif bag != null:  # the saddlebag, his small face on its name, right of the pack, the bin a thin bar under it
		grid.add_area(bag, Vector2(pack_size.x + 24.0, 0), bag_label, face)
		var bag_w := maxf(bag.cols * cell, 150.0)
		grid.place_bin(Rect2(Vector2(pack_size.x + 24.0, PackView.LABEL_H + bag.rows * cell + 12.0), Vector2(bag_w, 28)), "UI_THROW", "UI_BOUND_THROW")
	elif full:
		grid.place_bin(Rect2(Vector2(0, y + PackView.LABEL_H), Vector2(150, cell)), "UI_THROW", "UI_BOUND_THROW")
	else:
		grid.place_bin(Rect2(Vector2(pack_size.x + 24.0, 0), Vector2(150, pack_size.y)), "UI_THROW", "UI_BOUND_THROW")
	grid.changed.connect(func() -> void:
		Game.save_adventure()
		if grid.flash == "":  # a refused move keeps the box up so its "no room" stays readable
			changed.call())
	box.add_child(grid)
	if full:
		if bag != null:
			var send := _button(box, Txt.f("UI_SEND_HOME", Txt.t((courier.def as CharacterDef).name_key)), func() -> void:
				run.send_home(courier)
				Game.refresh_party()
				Game.save_adventure()
				changed.call())
			send.disabled = bag.items.is_empty()
		_button(box, Txt.t("UI_LEAVE_REST"), func() -> void:
			run.leave_found()
			Game.save_adventure()
			close.call())
		return
	if bag != null and not bag.items.is_empty():  # he can take what he carries home at any time, and rejoins when the party is home
		_button(box, Txt.f("UI_SEND_HOME", Txt.t((courier.def as CharacterDef).name_key)), func() -> void:
			run.send_home(courier)
			Game.refresh_party()
			Game.save_adventure()
			changed.call())
	_label(box, Txt.f("UI_PACK_GOLD", run.gold), 14)
	var store: PackedStringArray = []
	for id: String in Game.meta.materials:
		store.append("%s %d" % [Txt.t(String(Db.items[id].name_key)), int(Game.meta.materials[id])])
	if not store.is_empty():
		_label(box, Txt.f("UI_VILLAGE_STORE", "  ".join(store)), 14)
	_label(box, Txt.f("UI_PACK_WEAPON", Txt.t(String(Db.weapons.get(Game.weapon_id(), {}).get("name_key", "")))), 14)
	_label(box, Txt.f("UI_SLOTS_USED", [run.pack.used_cells(), run.pack.capacity()]), 12)
	if not run.lines.is_empty():
		_label(box, run.lines[run.lines.size() - 1], 12)
	_button(box, Txt.t("UI_CLOSE_MENU"), close)


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
	var shown := false
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var k := BondRules.key(ids[i], ids[j])
			var pts := int(bonds.get(k, 0))
			if pts <= 0:
				continue
			if not shown:
				_label(box, Txt.t("UI_LS_BONDS"), 15)
				shown = true
			var lv := BondRules.level(pts, Db.bonds)
			var next := int(Db.bonds.get("level_%d" % mini(lv + 1, BondRules.LEVELS), 0))
			var names := Array(k.split("+")).map(func(id: String) -> String: return Txt.t(Db.character(StringName(id)).name_key) if Db.character(StringName(id)) else id)
			_label(box, Txt.f("UI_LS_BOND", [names[0], names[1], lv, pts, next]), 13)
			for n in range(1, lv + 1):
				var b := _button(box, Txt.f("UI_LS_TALK", n) if at_home else Txt.t("UI_LS_TALK_AWAY"), func() -> void:
					var heard: Array = Game.meta.get("talks_heard", [])
					if not heard.has("%s:%d" % [k, n]):
						heard.append("%s:%d" % [k, n])
						Game.meta.talks_heard = heard
						Game.save_meta()
					_label(box, Txt.t(BondRules.talk_key(k, n)), 13))
				b.disabled = not at_home


static func _label(box: VBoxContainer, text: String, font_size: int) -> void:
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


static func _button(box: VBoxContainer, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(W, 30)
	b.pressed.connect(cb)
	box.add_child(b)
	return b


static func _use_row(box: VBoxContainer, text: String, verb: String, enabled: bool, cb: Callable) -> void:
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

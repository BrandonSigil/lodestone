class_name AdventureMenu
extends RefCounted
## The Lodestone menu and the pack, shared by the explore maps and the overworld.
## Each fills a dialog box the screen made. `changed` runs after a pick or a use (the screen refreshes
## its HUD and rebuilds the box); `close` shuts the box.

const W := 460.0
const PACK_CELL := 56.0
const FULL_CELL := 46.0  ## smaller when FOUND and the courier's bag share the box


## [USER] 2026-10-28: the Lodestone opens from its bottom-bar button at any time: level-up picks, head back
## to town. home: false hides GO HOME (in town already, or mid-fight).
static func lodestone(box: VBoxContainer, changed: Callable, close: Callable, home := true) -> void:
	_label(box, Txt.t("UI_LODESTONE"), 20)
	for m in Game.run.members:
		var d: CharacterDef = m.def
		var id := String(d.id)
		var s := Game.level_state(id)
		var u := CombatUnit.from_member(m)  # the stats it fights with: class, levels, picks, weapon
		_label(box, Txt.f("UI_LS_MEMBER", [Txt.t(d.name_key), int(s.level), int(s.xp), int(Db.levels.get("xp_per_level", 100)),
			int(m.hp), u.max_hp, u.attack, u.damage, u.magic_power]), 14)
		if int(s.pending) <= 0:
			continue
		_label(box, Txt.f("UI_LS_PICK", int(s.pending)), 13)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		for pick: String in LevelRules.PICKS:
			var b := Button.new()
			b.text = Txt.t("UI_LS_PICK_" + pick.to_upper())
			b.custom_minimum_size = Vector2(140, 30)
			b.pressed.connect(func() -> void:
				Game.pick_boost(id, pick)
				changed.call())
			row.add_child(b)
		box.add_child(row)
	if home:
		_button(box, Txt.t("UI_LS_HOME"), func() -> void:
			close.call()
			Game.wake_in_town(false))
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
	else:
		var hurt := TravelRules.most_hurt(run) != {}
		_use_row(box, Txt.f("UI_PACK_FOOD", run.food), Txt.t("UI_EAT"), run.food > 0 and hurt, func() -> void:
			TravelRules.eat_one(run)
			changed.call())
		_use_row(box, Txt.f("UI_PACK_POTION", run.medicine), Txt.t("UI_DRINK"), run.medicine > 0 and hurt, func() -> void:
			TrailRules.heal(run)
			changed.call())
		var finds := run.items
		for id: String in finds:
			if id != RunState.FOOD_ITEM and id != RunState.MED_ITEM:
				_label(box, "%s  x%d" % [Txt.t(String(Db.items[id].name_key)), int(finds[id])], 14)
	_label(box, Txt.t("UI_PACK_HELP_RUN"), 12)
	var cell := FULL_CELL if full else PACK_CELL
	var grid := PackView.new()
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
	var courier := run.courier()
	var bag: InventoryGrid = run.open_courier_bag() if full else null
	if bag != null:
		grid.add_area(bag, Vector2(0, y), Txt.f("UI_COURIER_BAG", Txt.t((courier.def as CharacterDef).name_key)))
		grid.place_bin(Rect2(Vector2(bag.cols * cell + 24.0, y + PackView.LABEL_H), Vector2(150, bag.rows * cell)), "UI_THROW", "UI_BOUND_THROW")
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


static func _label(box: VBoxContainer, text: String, font_size: int) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W, 0)
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

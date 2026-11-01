extends Node2D
## A trail fight: builds the map and units from the run and the encounter, hands them to a Battle,
## and frames it with the HUD. Press F6 on combat.tscn to try a debug fight without going through the trail.
## For tuning fights, use scenes/combat_sandbox.tscn instead.

var battle: Battle
var hud: FrameHud
var loot := ""

var phase_label: Label
var info_label: Label


var _art_set := ""


## God mode: this fight's map saved as maps/god_road and opened in the maker, centred on the first party piece. Back to
## play starts that map as a fight (the maker's Play test).
func god_jump() -> Dictionary:
	var doc := MapDoc.create("battle", "god_road", battle.grid, _art_set)
	if doc.save() == "":
		return {}
	var at := Vector2i(-1, -1)
	for u: CombatUnit in battle.units:
		if u.team == 0:
			at = u.cell
			break
	return {"key": doc.key(), "cell": at, "back": {"kind": "battle"}}


func _ready() -> void:
	var setup := Game.take_combat_setup()
	# A tile set means a road fight from the overworld: a valley from the map generator, built to the painted
	# look's rules (V9 to V11). Without one (the shelved trail), the old generated island.
	var art_set := String(setup.get("art_set", ""))
	_art_set = art_set
	var grid := MapGen.valley(setup.seed, MapGen.FIGHT_W, MapGen.FIGHT_H, art_set) if art_set != "" else CombatGrid.generate(setup.seed, 10, 8, setup.strangeness)
	var enc: Dictionary = Db.encounters.get(setup.encounter, Db.encounters["debug"])
	loot = enc.loot

	var units: Array = []
	var spots := grid.deploy_cells(0)
	for m in Game.run.alive():
		if spots.is_empty():
			break
		var u := CombatUnit.from_member(m)
		var c: Vector2i = spots.pop_front()
		u.place(c, grid.height_at(c))
		units.append(u)
	var espots := grid.deploy_cells(1)
	for id: String in enc.units:
		if espots.is_empty():
			break
		var e := CombatUnit.enemy(Db.class_def(id))
		var c: Vector2i = espots.pop_front()
		e.place(c, grid.height_at(c))
		units.append(e)

	battle = Battle.new()
	add_child(battle)
	battle.setup(grid, units, setup.seed, setup.strangeness)
	battle.goals = FightGoals.parse(String(enc.get("goals", "")))
	if art_set != "":
		battle.board.art_set = art_set
		battle.board.show_grid = false

	hud = FrameHud.new()  # the same fight UI as the explore maps: the leaf frame, the dock, the log (Battle's own)
	add_child(hud)
	hud.use_leaf_frame()
	var labels := hud.fight_side(battle)
	phase_label = labels.phase
	info_label = labels.info
	hud.set_tools([{"id": "pack", "text": Txt.t("UI_PACK"), "cb": func() -> void: pass}])
	battle.changed.connect(_refresh_hud)
	battle.finished.connect(_on_finished)
	_layout()
	get_viewport().size_changed.connect(_layout)
	battle.start()


func _layout() -> void:
	battle.layout(hud.center_rect())


func _refresh_hud() -> void:
	hud.fight_party(battle.units.filter(func(u: CombatUnit) -> bool: return u.team == 0))
	hud.set_pack(Game.run.pack)


func _on_finished(won: bool) -> void:
	for u: CombatUnit in battle.units:
		if u.team == 0:
			u.member.hp = u.hp
			Game.store_res(u)
	Game.fight_done()  # one fight less on a camp meal's buff
	var mine := battle.units.filter(func(u: CombatUnit) -> bool: return u.team == 0 and not u.member.is_empty())
	var before := VictoryUi.snapshot(mine.map(func(u: CombatUnit) -> String: return String(u.figure)))  # the bars fill from here
	Game.fight_morale(battle.units, ("escaped" if battle.outcome.how == "exit" else "won") if won else "lost", false)
	var loot_items := ""
	var coins := 0
	if won:  # coins and unlocks at once; food, medicine and things into the shared loot grid
		var split := ContainerUi.split_loot(loot)
		var fx := TrailRules.apply_effects(Game.run, String(split.now))
		Game.absorb(fx.unlocks)
		loot_items = String(split.items)
		for part in String(split.now).split(";", false):
			if part.begins_with("gold:"):
				coins += int(part.split(":")[1])
	_refresh_hud()
	var go_on := func() -> void: _loot_panel(loot_items, coins, won)
	if not won or not Game.run.adventure:
		var panel := PanelContainer.new()
		panel.theme_type_variation = &"DialogPanel"
		var box := VBoxContainer.new()
		panel.add_child(box)
		var l := Label.new()
		l.text = Txt.t("UI_VICTORY") if won else Txt.t("UI_DEFEAT")
		l.add_theme_font_size_override("font_size", 28)
		box.add_child(l)
		var b := Button.new()
		b.text = Txt.t("UI_CONTINUE")
		b.pressed.connect(func() -> void:
			panel.queue_free()
			go_on.call())
		box.add_child(b)
		_place_panel(panel)
		return
	var downed := battle.units.filter(func(u: CombatUnit) -> bool: return u.team == 1 and not u.alive()).size()
	var foes := battle.units.filter(func(u: CombatUnit) -> bool: return u.team == 1).size()
	var xp := LevelRules.fight_xp(foes, false, Db.levels)
	Game.award_xp(xp)
	battle.award_bonds()
	var rep := VictoryUi.report(before, mine, {"title": "UI_ESCAPED" if battle.outcome.how == "exit" else "UI_VICTORY",
		"xp": xp, "downed": downed, "coins": coins, "loot": loot_items, "bonds": battle.bond_ups})
	hud.root.add_child(VictoryUi.make(rep, [[Txt.t("UI_CONTINUE"), func() -> void:
		for n in hud.root.get_children():
			if n is VictoryUi:
				n.queue_free()
		go_on.call()]]))


## The loot as one shared grid, then the level-ups. What does not fit goes to the FOUND box, and past that is lost
## (a road fight is left on CONTINUE: docs/design/loot-containers.md).
func _loot_panel(items: String, coins: int, won: bool) -> void:
	if not won or items == "":
		_level_ups(0, won)
		return
	var size := ContainerUi.size_of("pile")
	var grid := InventoryGrid.create(size.x, size.y)
	ContainerUi.fill_grid(grid, items)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"DialogPanel"
	var box := VBoxContainer.new()
	panel.add_child(box)
	ContainerUi.fill(box, grid, Txt.t("UI_LOOT_TITLE"), func() -> void:
		Game.save_adventure()
		_refresh_hud(), func() -> void:
		for it in grid.items:
			Game.run.add_item(String(it.id), int(it.get("n", 1)))  # the pack, then FOUND, then lost
		panel.queue_free()
		_level_ups(0, won), Txt.t("UI_CONTINUE"), Txt.f("UI_LOOT_COINS", coins) if coins > 0 else "")
	_place_panel(panel)


func _place_panel(panel: PanelContainer) -> void:
	hud.root.add_child(panel)
	panel.custom_minimum_size = Vector2(480, 100)
	for _i in 3:  # the level-up box fills in over a frame or two: keep it centred in the play area as it grows
		var r := hud.center_rect()
		panel.reset_size()
		panel.position = r.get_center() - panel.size * 0.5
		await get_tree().process_frame
		if not is_instance_valid(panel):
			return


## After a won road fight, the level-up screen for each member that levelled (see LevelUpUi); then back to the road.
func _level_ups(i: int, won: bool) -> void:
	if not won or i >= Game.level_ups.size():
		Game.end_combat(won)
		return
	var entry: Dictionary = Game.level_ups[i]
	var id := String(entry.id)
	if not LevelUpUi.has_pick(id):  # [USER] 2026-11-01: no box for a level alone (the victory screen showed it)
		_level_ups(i + 1, won)
		return
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"DialogPanel"
	var box := VBoxContainer.new()
	panel.add_child(box)
	LevelUpUi.header(box, id, entry)  # LV UP, the new level, the stats gained, then the pick
	LevelUpUi.picks(box, id, func() -> void:
		panel.queue_free()
		_level_ups(i, won))
	var b := Button.new()
	b.text = Txt.t("UI_LV_LATER")
	b.pressed.connect(func() -> void:
		panel.queue_free()
		_level_ups(i + 1, won))
	box.add_child(b)
	_place_panel(panel)

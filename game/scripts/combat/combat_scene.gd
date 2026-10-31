extends Node2D
## A trail fight: builds the map and units from the run and the encounter, hands them to a Battle,
## and frames it with the HUD. Press F6 on combat.tscn to try a debug fight without going through the trail.
## For tuning fights, use scenes/combat_sandbox.tscn instead.

var battle: Battle
var hud: FrameHud
var loot := ""

var phase_label: Label
var info_label: Label


func _ready() -> void:
	var setup := Game.take_combat_setup()
	# A tile set means a road fight from the overworld: a valley from the map generator, built to the painted
	# look's rules (V9 to V11). Without one (the shelved trail), the old generated island.
	var art_set := String(setup.get("art_set", ""))
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
	if won:
		var fx := TrailRules.apply_effects(Game.run, loot)
		Game.absorb(fx.unlocks)
	_refresh_hud()
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	panel.add_child(box)
	var l := Label.new()
	l.text = Txt.t("UI_VICTORY") if won else Txt.t("UI_DEFEAT")
	l.add_theme_font_size_override("font_size", 28)
	box.add_child(l)
	if won and Game.run.adventure:
		var foes := battle.units.filter(func(u: CombatUnit) -> bool: return u.team == 1).size()
		var xp := LevelRules.fight_xp(foes, false, Db.levels)
		var lines := Game.award_xp(xp)
		lines.insert(0, Txt.f("UI_XP_GAIN", xp))
		lines.append_array(battle.award_bonds())
		var x := Label.new()
		x.text = "\n".join(lines)
		box.add_child(x)
	var b := Button.new()
	b.text = Txt.t("UI_CONTINUE")
	b.pressed.connect(func() -> void: Game.end_combat(won))
	box.add_child(b)
	hud.root.add_child(panel)
	var r := hud.center_rect()
	panel.position = r.get_center() - Vector2(160, 50)
	panel.custom_minimum_size = Vector2(320, 100)

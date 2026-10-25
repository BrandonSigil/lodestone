extends Node2D
## Runs one fight: player phase, then enemy phase, until one side is down.
## Press F6 on combat.tscn to try a debug fight without going through the trail.

const BOARD_SCALE := 1.15

var grid: CombatGrid
var units: Array = []
var rng := RandomNumberGenerator.new()
var board: CombatBoard
var hud: FrameHud
var loot := ""
var player_turn := false
var busy := false
var over := false
var selected: CombatUnit = null
var reach := {}

var phase_label: Label
var info_label: Label
var log_label: Label
var wait_button: Button


func _ready() -> void:
	var setup := Game.take_combat_setup()
	rng.seed = setup.seed
	grid = CombatGrid.generate(setup.seed, 10, 8, setup.strangeness)
	var enc: Dictionary = Db.encounters.get(setup.encounter, Db.encounters["debug"])
	loot = enc.loot

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

	board = CombatBoard.new()
	board.grid = grid
	board.units = units
	board.strangeness = setup.strangeness
	board.scale = Vector2.ONE * BOARD_SCALE
	add_child(board)
	board.cell_clicked.connect(_on_cell_clicked)
	board.cell_hovered.connect(_on_cell_hovered)

	hud = FrameHud.new()
	add_child(hud)
	phase_label = hud.add_side_label("", 20)
	info_label = hud.add_side_label("")
	wait_button = hud.add_button(Txt.t("UI_WAIT"), _on_wait)
	hud.add_button(Txt.t("UI_END_PHASE"), _on_end_phase)
	hud.add_side_label(Txt.t("UI_HELP_COMBAT"), 11)
	log_label = hud.add_side_label("", 12)
	hud.top_label.text = Txt.t("GAME_TITLE")
	_layout()
	get_viewport().size_changed.connect(_layout)
	_refresh_hud()
	_start_player_phase()


func _layout() -> void:
	var r := hud.center_rect()
	var bs := board.board_size() * BOARD_SCALE
	board.position = r.position + (r.size - bs) * 0.5 - board.board_origin() * BOARD_SCALE


func _log(line: String) -> void:
	var lines := log_label.text.split("\n", false)
	lines.append(line)
	log_label.text = "\n".join(lines.slice(-10))


func _refresh_hud() -> void:
	var entries := []
	for u: CombatUnit in units:
		if u.team == 0:
			entries.append({"name": Txt.t(u.name_key), "hp": u.hp, "max_hp": u.cls.max_hp, "tint": u.tint,
				"note": "SPOOKED" if u.spooked else ""})
	hud.set_party(entries)
	hud.set_slots(Game.run.slot_list(), RunState.CAPACITY)
	wait_button.disabled = selected == null


# --- phases -------------------------------------------------------------------

func _start_player_phase() -> void:
	player_turn = true
	phase_label.text = Txt.t("UI_PLAYER_PHASE")
	for u: CombatUnit in units:
		u.moved = false
		u.acted = false
		if u.team == 0 and u.alive():
			var r := CombatRules.skittish_check(rng, u, units)
			if not r.is_empty():
				_log("%s %s: %s" % [Txt.t(u.name_key), Txt.t("CHECK_NERVE"), Dice.describe(r)])
				if u.spooked:
					board.float_text(u.cell, Txt.f("LOG_SPOOKED", ""), Color(0.8, 0.7, 1.0))
	_refresh_hud()


func _enemy_phase() -> void:
	player_turn = false
	busy = true
	_deselect()
	phase_label.text = Txt.t("UI_ENEMY_PHASE")
	for e: CombatUnit in units:
		if e.team != 1 or not e.alive() or over:
			continue
		var plan := EnemyAi.plan(grid, e, units)
		if plan.move != e.cell:
			await board.animate_move(e, plan.path)
			e.place(plan.move, grid.height_at(plan.move))
		if plan.target != null:
			await _attack(e, plan.target)
	busy = false
	if not over:
		_start_player_phase()


func _attack(att: CombatUnit, tgt: CombatUnit) -> void:
	var r := CombatRules.attack(rng, grid, att, tgt, units)
	await board.animate_attack(att, tgt, r.success)
	var text := ("-%d" % r.damage) if r.success else "MISS"
	if r.crit:
		text += "!"
	board.float_text(tgt.cell, text, Color(1, 0.85, 0.5) if r.success else Color(0.8, 0.8, 0.8))
	_log("%s > %s  %s" % [Txt.t(att.name_key), Txt.t(tgt.name_key), Dice.describe(r)])
	if not tgt.alive():
		_log(Txt.f("LOG_DOWN", Txt.t(tgt.name_key)))
	_refresh_hud()
	_check_end()


func _check_end() -> void:
	if over:
		return
	var won := not CombatRules.team_alive(units, 1)
	var lost := not CombatRules.team_alive(units, 0)
	if not won and not lost:
		return
	over = true
	for u: CombatUnit in units:
		if u.team == 0:
			u.member.hp = u.hp
	if won:
		var fx := TrailRules.apply_effects(Game.run, loot)
		Game.absorb(fx.unlocks)
	_refresh_hud()
	_show_result(won)


func _show_result(won: bool) -> void:
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	panel.add_child(box)
	var l := Label.new()
	l.text = Txt.t("UI_VICTORY") if won else Txt.t("UI_DEFEAT")
	l.add_theme_font_size_override("font_size", 28)
	box.add_child(l)
	var b := Button.new()
	b.text = Txt.t("UI_CONTINUE")
	b.pressed.connect(func() -> void: Game.end_combat(won))
	box.add_child(b)
	hud.root.add_child(panel)
	var r := hud.center_rect()
	panel.position = r.get_center() - Vector2(160, 50)
	panel.custom_minimum_size = Vector2(320, 100)


# --- player input -------------------------------------------------------------

func _select(u: CombatUnit) -> void:
	selected = u
	board.selected = u
	u.move_origin = u.cell
	_show_options()
	_show_unit_info(u)
	_refresh_hud()


func _deselect() -> void:
	selected = null
	board.selected = null
	board.highlights = {}
	reach = {}
	if wait_button:
		wait_button.disabled = true


func _show_options() -> void:
	board.highlights = {}
	if selected == null:
		return
	if not selected.moved:
		reach = CombatRules.reachable(grid, selected, units)
		for c: Vector2i in reach.cost:
			board.highlights[c] = Color(0.35, 0.6, 1.0, 0.35)
	for t: CombatUnit in units:
		if CombatRules.can_attack(grid, selected, t, selected.cell):
			board.highlights[t.cell] = Color(1.0, 0.3, 0.25, 0.45)


func _finish(u: CombatUnit) -> void:
	u.moved = true
	u.acted = true
	_deselect()
	_refresh_hud()
	for o: CombatUnit in units:
		if o.team == 0 and o.alive() and not o.acted:
			return
	_enemy_phase()


func _on_cell_clicked(c: Vector2i, right: bool) -> void:
	if busy or over or not player_turn:
		return
	if right:
		if selected and selected.moved and not selected.acted:
			selected.place(selected.move_origin, grid.height_at(selected.move_origin))
			selected.moved = false
			_show_options()
		else:
			_deselect()
		return
	if c == CombatBoard.NONE:
		return
	var u := CombatRules.unit_at(units, c)
	if selected == null:
		if u and u.team == 0 and not u.acted:
			_select(u)
		elif u:
			_show_unit_info(u)
		return
	if u and u.team == 1:
		if CombatRules.can_attack(grid, selected, u, selected.cell):
			busy = true
			var att := selected
			await _attack(att, u)
			busy = false
			if not over:
				_finish(att)
		return
	if u and u.team == 0 and u != selected and not u.acted and not selected.moved:
		_select(u)
		return
	if u == null and not selected.moved and reach.get("cost", {}).has(c):
		busy = true
		var path := CombatRules.path_to(reach.prev, selected.cell, c)
		await board.animate_move(selected, path)
		selected.place(c, grid.height_at(c))
		selected.moved = true
		busy = false
		_show_options()


func _on_cell_hovered(c: Vector2i) -> void:
	if c == CombatBoard.NONE:
		return
	var u := CombatRules.unit_at(units, c)
	if selected and u and CombatRules.can_attack(grid, selected, u, selected.cell):
		var p := CombatRules.hit_chance(grid, selected, u, units, selected.cell)
		var dmg := CombatRules.damage(grid, selected, u, selected.cell)
		info_label.text = "%s\n%s" % [Txt.t(u.name_key), Txt.f("UI_HIT_PREVIEW", [int(round(p * 100)), dmg])]
	elif u:
		_show_unit_info(u)
	else:
		var t: int = grid.terrain_at(c)
		info_label.text = "%s  H%d  COST %d  COVER %+d" % [CombatGrid.T.keys()[t], grid.height_at(c), grid.step_cost(c) if grid.passable(c) else 0, grid.cover(c)]


func _show_unit_info(u: CombatUnit) -> void:
	info_label.text = "%s\nHP %d/%d  MOVE %d  JUMP %d\nATK +%d  DEF %d  DMG %d  RNG %d-%d" % [
		Txt.t(u.name_key), u.hp, u.cls.max_hp, CombatRules.move_points(u), u.cls.jump,
		u.cls.attack, u.cls.defense, u.cls.damage, u.cls.range_min, u.cls.range_max]


func _on_wait() -> void:
	if selected and not busy:
		_finish(selected)


func _on_end_phase() -> void:
	if busy or over or not player_turn:
		return
	for u: CombatUnit in units:
		if u.team == 0:
			u.acted = true
	_finish_all()


func _finish_all() -> void:
	_deselect()
	_refresh_hud()
	_enemy_phase()

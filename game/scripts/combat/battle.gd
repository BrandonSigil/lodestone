class_name Battle
extends Node2D
## Runs one fight on a board: phases, the per-unit action menu, targeting, forecasts and the enemy turn.
## Hosts (the trail's combat scene, the sandbox) build the grid and units, call setup() and start(),
## lay it out in their play area, and listen to the signals.
##
## Player controls: click a piece to open its menu. Blue tiles = move there. Pick ATTACK, a skill or an item,
## then click a lit target (hover shows the forecast). Right click or Esc steps back (and undoes a move).
## D shows the enemy's danger zone, Tab jumps to the next ready piece, E ends the turn, Q turns the camera.

signal log_line(text: String)
signal info(text: String)
signal phase_changed(team: int)
signal changed
signal finished(won: bool)

enum S { IDLE, MENU, TARGET, BUSY, OVER }

const MOVE_COLOR := Color(0.35, 0.6, 1.0, 0.35)
const ENEMY_COLOR := Color(1.0, 0.3, 0.25, 0.45)
const ALLY_COLOR := Color(0.35, 0.9, 0.45, 0.4)
const AREA_COLOR := Color(1.0, 0.75, 0.3, 0.3)

var grid: CombatGrid
var units: Array = []
var rng := RandomNumberGenerator.new()
var supplies := {}  ## "medicine", "food": what items spend; hosts write it back to the run
var board: CombatBoard
var state := S.IDLE
var selected: CombatUnit = null
var targeting: Ability = null
var reach := {}
var show_danger := false
var round_no := 0
var enemy_speed := 1.0  ## animation speed multiplier for the enemy phase

var _ui: CanvasLayer
var _menu: PanelContainer
var _menu_box: VBoxContainer
var _forecast: PanelContainer
var _forecast_label: Label
var _banner: Label
var _rect := Rect2()
var _fit_board := true  ## false when the host owns the board's camera (exploration maps)


## p_board: fight on a board the host already shows (a fight that breaks out on an exploration map).
## The host keeps owning it, its camera and its fog; the battle only borrows its input and highlights.
func setup(p_grid: CombatGrid, p_units: Array, seed_value: int, strangeness := 0.0, p_supplies := {}, p_board: CombatBoard = null) -> void:
	grid = p_grid
	units = p_units
	rng.seed = seed_value
	supplies = p_supplies
	for u: CombatUnit in units:
		u.sync_view()
	if p_board != null:
		board = p_board
		_fit_board = false
	else:
		board = CombatBoard.new()
		board.grid = grid
		board.strangeness = strangeness
		board.backdrop = true
		add_child(board)
	board.units = units
	board.combat_stance = true  # weapons out while the fight lasts
	board.cell_clicked.connect(_on_cell_clicked)
	board.cell_hovered.connect(_on_cell_hovered)
	board.rotated.connect(_on_rotated)
	_build_ui()


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 3
	add_child(_ui)
	_menu = PanelContainer.new()
	_menu.add_theme_stylebox_override("panel", _panel_style(Color(0.12, 0.15, 0.15, 0.94)))
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 2)
	_menu.add_child(_menu_box)
	_menu.visible = false
	_ui.add_child(_menu)
	_forecast = PanelContainer.new()
	_forecast.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.1, 0.1, 0.9)))
	_forecast_label = Label.new()
	_forecast_label.add_theme_font_size_override("font_size", 13)
	_forecast.add_child(_forecast_label)
	_forecast.visible = false
	_forecast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_forecast)
	_banner = Label.new()
	_banner.add_theme_font_size_override("font_size", 26)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_banner.add_theme_constant_override("outline_size", 6)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_banner)


static func _panel_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(6)
	sb.border_color = Color(0.9, 0.85, 0.6, 0.5)
	sb.set_border_width_all(1)
	return sb


## Centre the board in a screen rect at a scale that fits (a borrowed board only places the menus).
func layout(r: Rect2) -> void:
	if board == null:
		return
	_rect = r
	_forecast.position = r.position + Vector2(8, 8)
	_banner.position = r.position + Vector2(r.size.x * 0.5 - 90, r.size.y - 48)
	if not _fit_board:
		return
	var bs := board.board_size()
	var s := minf(r.size.x / bs.x, r.size.y / bs.y) * 0.95
	s = clampf(s, 0.5, 1.6)
	board.scale = Vector2.ONE * s
	board.position = r.position + (r.size - bs * s) * 0.5 - board.board_origin() * s


func _on_rotated() -> void:
	layout(_rect)
	if selected and _menu.visible:
		_place_menu()


## enemy_first: the party was caught (spotted on an exploration map), so the enemy moves before round 1.
func start(enemy_first := false) -> void:
	round_no = 0
	if enemy_first:
		_enemy_phase()
	else:
		_start_player_phase()


func is_player_turn() -> bool:
	return state == S.IDLE or state == S.MENU or state == S.TARGET


# --- phases ---------------------------------------------------------------------

func _start_player_phase() -> void:
	round_no += 1
	_show_phase_events(CombatRules.begin_phase(units, 0))
	_banner.text = Txt.f("UI_ROUND", round_no) + "  " + Txt.t("UI_PLAYER_PHASE")
	for u: CombatUnit in units:
		if u.team == 0 and u.alive():
			var r := CombatRules.skittish_check(rng, u, units)
			if not r.is_empty():
				log_line.emit("%s %s: %s" % [Txt.t(u.name_key), Txt.t("CHECK_NERVE"), Dice.describe(r)])
				if u.spooked:
					board.float_text(u.cell, Txt.f("LOG_SPOOKED", ""), Color(0.8, 0.7, 1.0))
	state = S.IDLE
	_refresh_danger()
	phase_changed.emit(0)
	changed.emit()


func end_player_phase() -> void:
	if not is_player_turn():
		return
	_deselect()
	CombatRules.end_phase(units, 0)
	_enemy_phase()


func _enemy_phase() -> void:
	state = S.BUSY
	_banner.text = Txt.t("UI_ENEMY_PHASE")
	board.danger = {}
	phase_changed.emit(1)
	_show_phase_events(CombatRules.begin_phase(units, 1))
	for e: CombatUnit in units:
		if e.team != 1 or not e.alive() or state == S.OVER:
			continue
		if e.has_status(CombatRules.STATUS_SLEEP):
			board.float_text(e.cell, Txt.t("TAG_SLEEP"), Color(0.75, 0.85, 1.0))
			continue
		var plan := EnemyAi.plan(grid, e, units)
		if plan.move != e.cell:
			await board.animate_move(e, plan.path)
			e.place(plan.move, grid.height_at(plan.move))
		if plan.ability != null:
			await _use(e, plan.ability, plan.aim)
		elif plan.guard:
			CombatRules.guard(e)
			board.float_text(e.cell, Txt.t("TAG_GUARD"), Color(0.7, 0.85, 1.0))
		if _check_end():
			return
	CombatRules.end_phase(units, 1)
	_start_player_phase()


## Regrowth and the like at the start of a phase: no animation, just numbers.
func _show_phase_events(events: Array) -> void:
	for ev in events:
		if ev.type == "heal":
			board.float_text(ev.unit.cell, "+%d" % ev.amount, Color(0.5, 1.0, 0.6))
	for o: CombatUnit in units:
		o.sync_view()


## Resolve an action and play its events. Returns after the animation.
func _use(u: CombatUnit, a: Ability, aim: Vector2i) -> void:
	var prev := state
	state = S.BUSY
	board.area = {}
	board.highlights = {}
	_forecast.visible = false
	log_line.emit("%s: %s" % [Txt.t(u.name_key), Txt.t(a.name_key)])
	var events := CombatRules.resolve(rng, grid, u, a, aim, units, supplies)
	# Pushed units are already moved in the rules; draw them where they started until the push plays.
	for ev in events:
		if ev.type == "push":
			var start: Vector2i = ev.path[0]
			ev.unit.vis = Vector2(start)
			ev.unit.vis_h = grid.height_at(start)
	for ev in events:
		await _play(ev)
	for o: CombatUnit in units:
		o.sync_view()
	changed.emit()
	if prev != S.OVER and state != S.OVER:
		state = prev


func _play(ev: Dictionary) -> void:
	var t: CombatUnit = ev.unit
	match ev.type:
		"hit", "miss":
			var src: CombatUnit = ev.src
			var hit: bool = ev.type == "hit"
			await board.animate_attack(src, t, hit)
			var text := ("-%d" % ev.amount) if hit else Txt.t("UI_MISS")
			if ev.roll.crit:
				text += "!"
			board.float_text(t.cell, text, Color(1, 0.85, 0.5) if hit else Color(0.8, 0.8, 0.8))
			log_line.emit("  %s > %s  %s" % [Txt.t(src.name_key), Txt.t(t.name_key), Dice.describe(ev.roll)])
			t.shown_hp = maxi(0, t.shown_hp - int(ev.amount))
			if t.shown_hp <= 0:
				log_line.emit(Txt.f("LOG_DOWN", Txt.t(t.name_key)))
		"heal":
			t.shown_hp = mini(t.max_hp, t.shown_hp + int(ev.amount))
			board.float_text(t.cell, "+%d" % ev.amount, Color(0.5, 1.0, 0.6))
			await get_tree().create_timer(0.25).timeout
		"status":
			if ev.has("roll"):
				await board.animate_attack(ev.src, t, true)
			board.float_text(t.cell, Txt.t("TAG_" + String(ev.status).to_upper()), Color(0.75, 0.85, 1.0))
			await get_tree().create_timer(0.2).timeout
		"push":
			await board.animate_push(t, ev.path)
		"bump", "fall":
			t.shown_hp = maxi(0, t.shown_hp - int(ev.amount))
			board.float_text(t.cell, "%s -%d" % [Txt.t("UI_" + String(ev.type).to_upper()), ev.amount], Color(1, 0.7, 0.4))
			log_line.emit("  %s %s -%d" % [Txt.t(t.name_key), Txt.t("UI_" + String(ev.type).to_upper()), ev.amount])
			await get_tree().create_timer(0.25).timeout
		"counter":
			board.float_text(ev.src.cell, Txt.t("UI_COUNTER"), Color(1, 1, 1))
			await get_tree().create_timer(0.2).timeout


func _check_end() -> bool:
	if state == S.OVER:
		return true
	var won := not CombatRules.team_alive(units, 1)
	var lost := not CombatRules.team_alive(units, 0)
	if not won and not lost:
		return false
	state = S.OVER
	_deselect()
	board.danger = {}
	board.combat_stance = false
	_banner.text = Txt.t("UI_VICTORY") if won else Txt.t("UI_DEFEAT")
	changed.emit()
	finished.emit(won)
	return true


# --- selection and the menu ----------------------------------------------------------

func _select(u: CombatUnit) -> void:
	selected = u
	board.selected = u
	if not u.moved:
		u.move_origin = u.cell
	targeting = null
	state = S.MENU
	_show_move_tiles()
	_open_menu()
	info.emit(unit_text(u))


func _deselect() -> void:
	selected = null
	targeting = null
	if board:
		board.selected = null
		board.highlights = {}
		board.area = {}
	reach = {}
	if _menu:
		_menu.visible = false
		_forecast.visible = false
	if state == S.MENU or state == S.TARGET:
		state = S.IDLE


func _show_move_tiles() -> void:
	board.highlights = {}
	board.area = {}
	reach = {}
	if selected == null:
		return
	if not selected.moved:
		reach = CombatRules.reachable(grid, selected, units)
		for c: Vector2i in reach.cost:
			if c != selected.cell:
				board.highlights[c] = MOVE_COLOR
	if not selected.acted:
		for c in CombatRules.target_cells(grid, selected, selected.abilities[0], units, selected.cell):
			board.highlights[c] = ENEMY_COLOR


func _open_menu() -> void:
	for c in _menu_box.get_children():
		c.queue_free()
	var u := selected
	if not u.acted:
		for a in u.abilities:
			_menu_item(_ability_label(u, a), _has_targets(u, a) and u.can_use(a), _start_targeting.bind(a))
		for id: String in Db.combat_items:
			var it: Ability = Db.combat_items[id]
			var label := "%s  (%s %d)" % [Txt.t(it.name_key), Txt.t("RES_" + it.resource.to_upper()), int(supplies.get(it.resource, 0))]
			_menu_item(label, CombatRules.usable(u, it, supplies) and _has_targets(u, it), _start_targeting.bind(it))
		_menu_item(Txt.t("ACT_GUARD"), true, _on_guard)
	if u.moved and not u.acted:
		_menu_item(Txt.t("ACT_UNDO"), true, _undo_move)
	_menu_item(Txt.t("ACT_WAIT"), true, _on_wait)
	_menu.visible = true
	_menu.reset_size()
	await get_tree().process_frame
	if selected == u and _menu.visible:
		_place_menu()


func _place_menu() -> void:
	var p := board.cell_screen_pos(selected.cell) + Vector2(56, -16)
	var vs := get_viewport_rect().size
	p.x = minf(p.x, vs.x - _menu.size.x - 4)
	p.y = clampf(p.y, 4, vs.y - _menu.size.y - 4)
	_menu.position = p


func _ability_label(u: CombatUnit, a: Ability) -> String:
	var label := Txt.t(a.name_key)
	if not u.can_use(a):
		label += "  (%d)" % int(u.cooldowns[a.id])
	return label


func _menu_item(text: String, enabled: bool, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(150, 26)
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(cb)
	_menu_box.add_child(b)


func _has_targets(u: CombatUnit, a: Ability) -> bool:
	var cells := CombatRules.target_cells(grid, u, a, units, u.cell)
	if a.kind == "heal":
		return cells.any(func(c: Vector2i) -> bool:
			var o := u if c == u.cell else CombatRules.unit_at(units, c)
			return o != null and o.hp < o.max_hp)
	if a.target != "cell":
		return not cells.is_empty()
	for c in cells:
		if not CombatRules.affected_units(grid, u, a, c, units, u.cell).is_empty():
			return true
	return false


func _start_targeting(a: Ability) -> void:
	if selected == null:
		return
	targeting = a
	state = S.TARGET
	_menu.visible = false
	board.highlights = {}
	var col := ENEMY_COLOR if a.hostile() else ALLY_COLOR
	if a.target == "cell":
		col = AREA_COLOR
	for c in CombatRules.target_cells(grid, selected, a, units, selected.cell):
		board.highlights[c] = col
	info.emit(Txt.t(a.name_key))


func _cancel_targeting() -> void:
	targeting = null
	state = S.MENU
	_forecast.visible = false
	_show_move_tiles()
	_open_menu()


func _on_guard() -> void:
	CombatRules.guard(selected)
	board.float_text(selected.cell, Txt.t("TAG_GUARD"), Color(0.7, 0.85, 1.0))
	log_line.emit("%s: %s" % [Txt.t(selected.name_key), Txt.t("ACT_GUARD")])
	_after_action(selected)


func _on_wait() -> void:
	var u := selected
	u.moved = true
	u.acted = true
	_finish_unit()


func _undo_move() -> void:
	selected.place(selected.move_origin, grid.height_at(selected.move_origin))
	selected.moved = false
	_select(selected)
	_refresh_danger()


func _after_action(u: CombatUnit) -> void:
	u.acted = true
	if not u.alive() or u.done() or CombatRules.move_points(u) == 0:
		u.moved = true
		_finish_unit()
		return
	_refresh_danger()
	_select(u)


func _finish_unit() -> void:
	_deselect()
	_refresh_danger()
	changed.emit()
	for o: CombatUnit in units:
		if o.team == 0 and o.alive() and not o.done():
			return
	end_player_phase()


func _ready_units() -> Array:
	return units.filter(func(o: CombatUnit) -> bool: return o.team == 0 and o.alive() and not o.done())


# --- input ----------------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.is_echo():
		return
	match event.keycode:
		KEY_ESCAPE:
			_back()
		KEY_D:
			show_danger = not show_danger
			_refresh_danger()
		KEY_E:
			end_player_phase()
		KEY_TAB:
			if is_player_turn() and state != S.TARGET:
				var waiting := _ready_units()
				if not waiting.is_empty():
					var i := (waiting.find(selected) + 1) % waiting.size()
					_select(waiting[i])


func _back() -> void:
	match state:
		S.TARGET:
			_cancel_targeting()
		S.MENU:
			if selected.moved and not selected.acted:
				_undo_move()
			else:
				_deselect()


func _on_cell_clicked(c: Vector2i, right: bool) -> void:
	if not is_player_turn():
		return
	if right:
		_back()
		return
	if c == CombatBoard.NONE:
		return
	var u := CombatRules.unit_at(units, c)
	match state:
		S.IDLE:
			if u and u.team == 0 and not u.done():
				_select(u)
			elif u:
				info.emit(unit_text(u))
		S.MENU:
			if u and u.team != 0 and not selected.acted and board.highlights.get(c) == ENEMY_COLOR:
				_start_targeting(selected.abilities[0])
				_on_cell_hovered(c)
			elif u and u.team == 0 and u != selected and not u.done() and (not selected.moved or selected.acted):
				_select(u)
			elif u == null and not selected.moved and reach.get("cost", {}).has(c):
				_move_selected(c)
		S.TARGET:
			if board.highlights.has(c):
				var who := selected
				var a := targeting
				if a.target == "cell" and CombatRules.affected_units(grid, who, a, c, units, who.cell).is_empty():
					return
				_menu.visible = false
				await _use(who, a, c)
				if _check_end():
					return
				_after_action(who)


func _move_selected(c: Vector2i) -> void:
	var u := selected
	state = S.BUSY
	_menu.visible = false
	board.highlights = {}
	var path := CombatRules.path_to(reach.prev, u.cell, c)
	await board.animate_move(u, path)
	u.place(c, grid.height_at(c))
	u.moved = true
	state = S.MENU
	if u.acted:
		_finish_unit()
		return
	_refresh_danger()
	_select(u)


func _on_cell_hovered(c: Vector2i) -> void:
	if c == CombatBoard.NONE:
		_forecast.visible = false
		return
	if state == S.TARGET and targeting != null:
		board.area = {}
		if board.highlights.has(c):
			for a in CombatRules.area(grid, targeting, c):
				board.area[a] = true
			_show_forecast(selected, targeting, c)
		else:
			_forecast.visible = false
		return
	var u := CombatRules.unit_at(units, c)
	if u:
		info.emit(unit_text(u))
	else:
		info.emit(tile_text(c))


func _show_forecast(u: CombatUnit, a: Ability, c: Vector2i) -> void:
	var f := CombatRules.forecast(grid, u, a, c, units, u.cell)
	if f.targets.is_empty():
		_forecast.visible = false
		return
	var lines: PackedStringArray = [Txt.t(a.name_key)]
	for e in f.targets:
		var t: CombatUnit = e.unit
		match a.kind:
			"attack":
				var after := maxi(0, t.hp - int(e.dmg) * int(e.swings))
				lines.append("%s  HP %d > %d" % [Txt.t(t.name_key), t.hp, after])
				var line := Txt.f("UI_HIT_PREVIEW", [int(round(e.hit * 100)), e.dmg])
				if e.swings > 1:
					line += "  " + Txt.f("UI_SWINGS", e.swings)
				lines.append("  " + line)
				lines.append("  " + _parts_text(e.hit_parts) + "  vs  " + _parts_text(e.def_parts))
			"hex":
				lines.append("%s  %s" % [Txt.t(t.name_key), Txt.t("TAG_" + a.status.to_upper())])
				lines.append("  " + Txt.f("UI_HEX_PREVIEW", int(round(e.hit * 100))))
				lines.append("  " + _parts_text(e.hit_parts) + "  vs  " + _parts_text(e.def_parts))
			"heal":
				lines.append("%s  HP %d > %d" % [Txt.t(t.name_key), t.hp, t.hp + int(e.heal)])
			"buff":
				lines.append("%s  %s" % [Txt.t(t.name_key), Txt.t("TAG_" + a.status.to_upper())])
	if not f.counter.is_empty():
		var c_line := Txt.f("UI_COUNTER_PREVIEW", [int(round(f.counter.hit * 100)), f.counter.dmg])
		if int(f.counter.get("swings", 1)) > 1:
			c_line += "  " + Txt.f("UI_SWINGS", f.counter.swings)
		lines.append(c_line)
	_forecast_label.text = "\n".join(lines)
	_forecast.visible = true
	_forecast.reset_size()


static func _parts_text(parts: Array) -> String:
	var out: PackedStringArray = []
	for p in parts:
		out.append("%s %+d" % [Txt.t(p[0]), p[1]] if out.size() > 0 else "%s %d" % [Txt.t(p[0]), p[1]])
	return "  ".join(out)


func _refresh_danger() -> void:
	board.danger = CombatRules.danger_zone(grid, units, 1) if show_danger and state != S.OVER else {}


func unit_text(u: CombatUnit) -> String:
	var lines: PackedStringArray = [Txt.t(u.name_key)]
	lines.append("HP %d/%d  MOVE %d  JUMP %d" % [u.hp, u.max_hp, CombatRules.move_points(u), u.jump])
	lines.append("ATK +%d  DEF %d  DMG %d  RNG %d-%d" % [u.attack, u.defense, u.damage, u.range_min, u.range_max])
	var skills: PackedStringArray = []
	for a in u.abilities.slice(1):
		skills.append(_ability_label(u, a))
	if not skills.is_empty():
		lines.append(", ".join(skills))
	for t in u.traits:
		var key := "TRAIT_" + String(t).to_upper()
		if Txt.has(key):
			lines.append("%s: %s" % [Txt.t(key), Txt.t(key + "_DESC")])
	return "\n".join(lines)


func tile_text(c: Vector2i) -> String:
	var t: int = grid.terrain_at(c)
	return "%s  H%d  COST %d  COVER %+d" % [CombatGrid.T.keys()[t], grid.height_at(c), grid.step_cost(c) if grid.passable(c) else 0, grid.cover(c)]

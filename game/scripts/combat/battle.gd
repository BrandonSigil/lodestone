class_name Battle
extends Node2D
## Runs one fight on a board: phases, the per-unit action menu, targeting, forecasts and the enemy turn.
## Hosts (the trail's combat scene, the sandbox) build the grid and units, call setup() and start(),
## lay it out in their play area, and listen to the signals.
##
## Player controls: click a piece to open its menu. MOVE hides the menu and lights the tiles it can reach:
## click one, or CANCEL. Pick ATTACK, a skill or an item, then click a lit target (hover shows the forecast).
## Right click or Esc steps back (and undoes a move). D shows the enemy's danger zone, Tab jumps to the next
## ready piece, E ends the turn, Q turns the camera. AUTO FIGHT (testing) plays the party's turns itself.

signal log_line(text: String)
signal info(text: String)
signal phase_changed(team: int)
signal changed
signal finished(won: bool)

enum S { IDLE, MENU, TARGET, BUSY, OVER }
const SIGHT_SHADE := Color(0.05, 0.06, 0.12, 0.45)  ## tiles a hovered ranged piece can't see

const MOVE_COLOR := Color(0.35, 0.6, 1.0, 0.35)
const ENEMY_COLOR := Color(1.0, 0.3, 0.25, 0.45)
const ALLY_COLOR := Color(0.35, 0.9, 0.45, 0.4)
const AREA_COLOR := Color(1.0, 0.75, 0.3, 0.3)
const CANCEL_SIZE := Vector2(120, 30)
const AUTO_SIZE := Vector2(120, 28)

var grid: CombatGrid
var units: Array = []
var rng := RandomNumberGenerator.new()
var board: CombatBoard
var wallpaper := true  ## a board this battle creates shows the skyline wallpaper and foreground band (the newest look)
var state := S.IDLE
var selected: CombatUnit = null
var targeting: Ability = null
var reach := {}
var show_danger := false
var round_no := 0
var rounds_done := 0  ## enemy phases finished: a "hold:N" fight is won once this reaches N
var goals := FightGoals.new()  ## how this fight is won (the host sets it before start; default: defeat all)
var talk_open := false  ## the host says TALK is open (the fight is written for it and its flag is set)
var outcome := {"how": "", "joined": []}  ## after the end: the goal met, and flags set by foes talked round
var enemy_speed := 1.0  ## animation speed multiplier for the enemy phase
var _carry_friend: CombatUnit = null  ## CARRY: the friend picked, now picking where to go
var _carry_spots := {}  ## CARRY: dest -> set-down cell
var used := {}  ## piece -> ability ids it has used this fight: an unknown boss's card lists only these
var bond_ups := []  ## after award_bonds: [[pair key "a+b", level reached], ...] for the victory screen
var deeds := {}  ## bond pair key -> {"help_up", "teamup"}: what party pieces did for each other this fight (BondRules)

var _ui: CanvasLayer
var _log_view: CombatLog  ## the readable log, bottom right ([USER] 2026-10-30 design-scale)
var _menu: PanelContainer
var _menu_box: VBoxContainer
var _forecast: PanelContainer
var _forecast_label: Label
var _banner: Label
var _rect := Rect2()
var _fit_board := true  ## false when the host owns the board's camera (exploration maps)
var _moving := false  ## MOVE picked: the menu is hidden and the reachable tiles are lit
var _cancel: Button
var side_below := Callable()  ## (y): the host moves its side box under the test buttons
var _auto: Button
var _hud: ActionHud  ## the action bar, ring or hand of cards (the "list" layout is _menu)
var _layout_btn: Button
## Testing: the party plays its own turns. Kept across fights, so one click covers a whole dungeon.
static var auto_fight := false
const AUTO_PAUSE := 0.4  ## seconds between auto phases
const AUTO_STALEMATE := 8  ## auto rounds in a row with no HP change: the fight ends as a win (the AI can't reach)
var _auto_hp := -1
var _auto_quiet := 0


## p_board: fight on a board the host already shows (a fight that breaks out on an exploration map).
## The host keeps owning it, its camera and its fog; the battle only borrows its input and highlights.
## p_supplies: a test bench's counts; party pieces with no belt get one packed from them. In the live
## loop each piece brings its member's belt and items are spent from it in place.
func setup(p_grid: CombatGrid, p_units: Array, seed_value: int, strangeness := 0.0, p_supplies := {}, p_board: CombatBoard = null) -> void:
	grid = p_grid
	units = p_units
	rng.seed = seed_value
	CombatUnit.pack_belts(p_units, p_supplies)
	for u: CombatUnit in p_units:
		if not u.keep_res:
			u.reset_resource()  # mana and charges full, rage empty, every fight (a carried bar is left as it is)
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
		board.wallpaper = wallpaper
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
	_menu.theme_type_variation = &"MenuPanel"
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 2)
	_menu.add_child(_menu_box)
	_menu.visible = false
	_ui.add_child(_menu)
	_forecast = PanelContainer.new()
	_forecast.theme_type_variation = &"InfoPanel"
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
	_cancel = Button.new()
	_cancel.text = Txt.t("UI_CANCEL")
	_cancel.custom_minimum_size = Vector2(CANCEL_SIZE.x, CANCEL_SIZE.y)
	_cancel.add_theme_font_size_override("font_size", 13)
	_cancel.visible = false
	_cancel.pressed.connect(_back)
	_ui.add_child(_cancel)
	_log_view = CombatLog.new()
	_ui.add_child(_log_view)
	log_line.connect(_log_view.add)
	_auto = Button.new()
	_auto.text = Txt.t("UI_AUTO_FIGHT")
	_auto.toggle_mode = true
	_auto.button_pressed = auto_fight
	_auto.custom_minimum_size = Vector2(AUTO_SIZE.x, AUTO_SIZE.y)
	_auto.add_theme_font_size_override("font_size", 12)
	_auto.toggled.connect(_on_auto_toggled)
	_ui.add_child(_auto)
	var hand_layer := CanvasLayer.new()  # under the bottom frame (layer 2): the cards peek over it and rise on a point
	hand_layer.layer = 1
	add_child(hand_layer)
	_hud = ActionHud.new()
	_hud.layout = action_layout()
	_hud.on_swap = _swap
	_hud.on_hover = preview_reach
	_hud.on_unhover = func() -> void: board.reach = {}
	hand_layer.add_child(_hud)
	_hud.visible = false
	_layout_btn = Button.new()  # testing: switch the action layout ([USER] 2026-10-30, three to pick from)
	_layout_btn.custom_minimum_size = Vector2(AUTO_SIZE.x, AUTO_SIZE.y)
	_layout_btn.add_theme_font_size_override("font_size", 12)
	_layout_btn.pressed.connect(_next_layout)
	_ui.add_child(_layout_btn)
	_show_layout()


## Centre the board in a screen rect at a scale that fits (a borrowed board only places the menus).
func layout(r: Rect2) -> void:
	if board == null:
		return
	_rect = r
	_forecast.position = r.position + Vector2(8, 8)
	_banner.position = r.position + Vector2(r.size.x * 0.5 - 90, r.size.y - 84)
	_cancel.position = r.position + Vector2(r.size.x * 0.5 - CANCEL_SIZE.x * 0.5, r.size.y - 44)
	# the two test buttons: as wide as their text needs, right-aligned with a margin, never past the screen's edge
	var bw := maxf(maxf(_auto.get_combined_minimum_size().x, _layout_btn.get_combined_minimum_size().x), AUTO_SIZE.x)
	_auto.custom_minimum_size.x = bw
	_layout_btn.custom_minimum_size.x = bw
	_auto.position = Vector2(r.end.x - bw - 8, r.position.y + 8)
	_layout_btn.position = _auto.position + Vector2(0, AUTO_SIZE.y + 4)
	if side_below.is_valid():  # the host's side box starts under them
		side_below.call(_layout_btn.position.y + AUTO_SIZE.y + 6.0)
	_log_view.place(r, _hud.dock_rect() if _hud != null else Rect2())
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
	elif selected and _hud.visible:
		_open_menu()


## enemy_first: the party was caught (spotted on an exploration map), so the enemy moves before round 1.
func start(enemy_first := false) -> void:
	round_no = 0
	rounds_done = 0
	board.goal_cells = {}
	for c in goals.exit_cells:
		board.goal_cells[c] = true
	for line in goal_lines():
		log_line.emit(line)
	if enemy_first:
		_enemy_phase()
	else:
		_start_player_phase()


func is_player_turn() -> bool:
	return state == S.IDLE or state == S.MENU or state == S.TARGET


# --- phases ---------------------------------------------------------------------

func _start_player_phase() -> void:
	round_no += 1
	_show_phase_events(CombatRules.begin_phase(units, 0, grid))
	_banner.text = Txt.f("UI_ROUND", round_no) + "  " + Txt.t("UI_PLAYER_PHASE")
	log_line.emit(Txt.f("LOG_ROUND", round_no))
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
	if auto_fight:
		_auto_player_phase()


func end_player_phase() -> void:
	if not is_player_turn():
		return
	_deselect()
	_show_phase_events(CombatRules.cold(units, 0))  # ice pillars chill the pieces next to them
	if _check_end():
		return
	CombatRules.end_phase(units, 0)
	_enemy_phase()


func _enemy_phase() -> void:
	state = S.BUSY
	_banner.text = Txt.t("UI_ENEMY_PHASE")
	log_line.emit(Txt.t("LOG_FOES_MOVE"))
	board.danger = {}
	phase_changed.emit(1)
	_show_phase_events(CombatRules.begin_phase(units, 1, grid))
	await _boss_events(CombatRules.boss_start(rng, grid, units, 1))  # a marked big move lands, his pieces come
	if _check_end():
		return
	for e: CombatUnit in units:
		if e.team != 1 or not e.alive() or e.done() or state == S.OVER:  # done: called this phase, acts next
			continue
		if e.has_status(CombatRules.STATUS_SLEEP):
			board.float_text(e.cell, Txt.t("TAG_SLEEP"), Color(0.75, 0.85, 1.0))
			continue
		await _ai_turn(e)
		if _check_end():
			return
	await _boss_events(CombatRules.boss_end(grid, units, 1))
	CombatRules.end_phase(units, 1)
	rounds_done += 1
	if _check_end():
		return
	_start_player_phase()


## Auto fight (testing): the party's living pieces play their turns, then the enemy phase runs.
func _auto_player_phase() -> void:
	state = S.BUSY
	var total := 0
	for u: CombatUnit in units:
		total += u.hp
	_auto_quiet = _auto_quiet + 1 if total == _auto_hp else 0
	_auto_hp = total
	await get_tree().create_timer(AUTO_PAUSE).timeout  # the board reads, and the phases don't recurse on the stack
	if _auto_quiet >= AUTO_STALEMATE:
		# The greedy AI can't reach the other side (a wall in the way): nobody has been hurt for a while.
		log_line.emit(Txt.t("UI_AUTO_STALEMATE"))
		_finish(true)
		return
	var again := true
	while again:  # round the list again for a piece helped up after its place came by: it may act, as the player's can
		again = false
		for u: CombatUnit in CombatSim.by_turn(units, grid):
			if u.team != 0 or not u.alive() or u.done() or state == S.OVER:
				continue
			await _ai_turn(u)
			u.moved = true
			u.acted = true
			again = true
			if _check_end():
				return
	_show_phase_events(CombatRules.cold(units, 0))
	if _check_end():
		return
	CombatRules.end_phase(units, 0)
	_enemy_phase()


## One piece's turn played by the AI: move, then use a skill or guard.
func _ai_turn(u: CombatUnit) -> void:
	var plan := EnemyAi.plan(grid, u, units)
	var stop := CombatRules.walk_stop(grid, u, plan.path, units)  # a piece on OVERWATCH, or a trap, stops the walk
	if not stop.is_empty():
		plan.move = stop.cell
		plan.path = plan.path.slice(0, plan.path.find(stop.cell) + 1)
	if not await _leave_guards(u, plan.move):
		return
	if plan.move != u.cell:
		log_line.emit(Txt.f("LOG_MOVE", [Txt.t(u.name_key), maxi(1, plan.path.size() - 1)]))
		await board.animate_move(u, plan.path)
		u.place(plan.move, grid.height_at(plan.move))
		await _spot(u)
	u.move_spent += int(plan.cost)
	if not stop.is_empty():
		for ev in CombatRules.stop_events(rng, grid, stop, u, units):
			await _play(ev)
		for o: CombatUnit in units:
			o.sync_view()
		u.moved = true
		u.move_spent = CombatRules.move_points(u)  # it acts from where it stopped, if it still can
		if not u.alive() or _check_end():
			return
		var again := EnemyAi.plan(grid, u, units)
		plan.ability = again.ability
		plan.aim = again.aim
		plan.guard = again.guard
	if plan.ability != null and plan.ability.kind == "swap":  # the rogue's move; then it acts from where it landed
		await _use_clutch(u, plan.ability, plan.aim, plan.dest, plan.spot)
		u.moved = true
		u.move_spent = CombatRules.swap_spent(u)
		var then := EnemyAi.plan(grid, u, units)
		if then.ability != null and then.ability.kind not in ["carry", "command", "swap"] and u.alive():
			await _use(u, then.ability, then.aim)
		elif then.guard:
			CombatRules.guard(u)
	elif plan.ability != null and plan.ability.kind in ["carry", "command", "swap"]:
		await _use_clutch(u, plan.ability, plan.aim, plan.dest, plan.spot)
	elif plan.ability != null:
		await _use(u, plan.ability, plan.aim)
		if CombatRules.hit_and_run(u, plan.ability):  # the rogue steps back out of the foes' reach
			var away := EnemyAi.retreat(grid, u, units)
			if away.move != u.cell and await _leave_guards(u, away.move):
				await board.animate_move(u, away.path)
				u.place(away.move, grid.height_at(away.move))
				await _spot(u)
			u.moved = true
	elif plan.guard:
		CombatRules.guard(u)
		board.float_text(u.cell, Txt.t("TAG_GUARD"), Color(0.7, 0.85, 1.0))


func _on_auto_toggled(on: bool) -> void:
	auto_fight = on
	if on and is_player_turn():
		_deselect()
		_auto_player_phase()


## u ended a move: hidden foes it can see within 3 come out ([USER] design-foe-roles, the ambusher).
func _spot(u: CombatUnit) -> void:
	for o in CombatRules.spot(grid, units, u):
		await _play({"type": "reveal", "unit": o})
	_refresh_danger()


## Does the party know this piece? Everyone but a boss it hasn't fought before ([USER] design-boss-retry).
static func known(u: CombatUnit) -> bool:
	return not u.boss or u.cls == null or Game.has_flag(ExploreRules.learned_flag(String(u.cls.id)))


func _saw(u: CombatUnit, a: Ability) -> void:
	if not used.has(u):
		used[u] = []
	if not used[u].has(a.id):
		used[u].append(a.id)


## Two party pieces did something for each other: it counts toward their bond after the fight.
func _deed(a: CombatUnit, b: CombatUnit, what: String) -> void:
	if a == null or b == null or a == b or a.team != 0 or b.team != 0 or a.member.is_empty() or b.member.is_empty():
		return
	var k := BondRules.key(String(a.figure), String(b.figure))
	if not deeds.has(k):
		deeds[k] = {}
	deeds[k][what] = true


## The party's bonds after a won fight: points for every pair that fought, from deeds and who's still up. Lines to show.
func award_bonds() -> PackedStringArray:
	var ids := []
	var standing := []
	for u: CombatUnit in units:
		if u.team == 0 and not u.member.is_empty():
			ids.append(String(u.figure))
			if u.alive():
				standing.append(String(u.figure))
	var bonds: Dictionary = Game.meta.get("bonds", {})
	var lines: PackedStringArray = []
	bond_ups = BondRules.award(bonds, ids, standing, deeds, Db.bonds)
	for up in bond_ups:
		var names := Array(String(up[0]).split("+")).map(func(id: String) -> String:
			var d := Db.character(StringName(id))
			return Txt.t(d.name_key) if d else id)
		lines.append(Txt.f("UI_BOND_UP", [names[0], names[1], int(up[1])]))
	Game.meta.bonds = bonds
	Game.save_meta()
	return lines


## CARRY or COMMAND ([USER] design-clutch-tools-2), from the player or the AI: aim is the friend's cell; for CARRY
## the carrier walks to dest and sets the friend down at spot.
func _use_clutch(u: CombatUnit, a: Ability, aim: Vector2i, dest: Vector2i, spot: Vector2i) -> void:
	var prev := state
	state = S.BUSY
	board.highlights = {}
	log_line.emit("%s: %s" % [Txt.t(u.name_key), Txt.t(a.name_key)])
	var friend := CombatRules.occupant(units, aim)
	_carry_friend = null
	_carry_spots = {}
	if friend == null:
		state = prev
		return
	var events: Array
	match a.kind:
		"carry":
			events = CombatRules.carry(rng, grid, u, friend, dest, spot, units)
		"swap":
			events = CombatRules.shadow_swap(grid, u, a, friend)
		_:
			events = CombatRules.command(u, a, friend)
	u.uses[a.id] = int(u.uses.get(a.id, 0)) + 1
	for ev in events:
		await _play(ev)
	for o: CombatUnit in units:
		o.sync_view()
	targeting = null
	changed.emit()
	if prev != S.OVER and state != S.OVER:
		state = prev


## A boss's big moves at a phase's edges (CombatRules.boss_start, boss_end): play them, then redraw the marks.
func _boss_events(events: Array) -> void:
	for ev in events:
		await _play(ev)
	for o: CombatUnit in units:
		o.sync_view()
	_refresh_danger()
	if not events.is_empty():
		changed.emit()


## Regrowth and the like at the start of a phase: no animation, just numbers.
func _show_phase_events(events: Array) -> void:
	for ev in events:
		if ev.type == "heal":
			board.float_text(ev.unit.cell, "+%d" % ev.amount, Color(0.5, 1.0, 0.6))
		elif ev.type == "bleed":
			board.float_text(ev.unit.cell, "-%d" % ev.amount, Color(0.9, 0.3, 0.3))
			ev.unit.shown_hp = ev.unit.hp
		elif ev.type == "reveal":
			board.float_text(ev.unit.cell, Txt.t("UI_AMBUSH"), Color(1.0, 0.5, 0.4), 22)
			log_line.emit(Txt.f("LOG_AMBUSH", Txt.t(ev.unit.name_key)))
		elif ev.type == "bled_out":
			board.float_text(ev.unit.cell, Txt.t("UI_KNOCKED_OUT"), Color(1, 0.6, 0.5))
			log_line.emit(Txt.f("LOG_BLED_OUT", Txt.t(ev.unit.name_key)))
	for o: CombatUnit in units:
		o.sync_view()


## Resolve an action and play its events. Returns after the animation.
## Guards u walks away from by moving to dest each get a free hit first ([USER] c13). False if u went down.
func _leave_guards(u: CombatUnit, dest: Vector2i) -> bool:
	var events := CombatRules.leave_hits(rng, grid, u, units, dest)
	for ev in events:
		await _play(ev)
	if not events.is_empty():
		for o: CombatUnit in units:
			o.sync_view()
		changed.emit()
	return u.alive()


func _use(u: CombatUnit, a: Ability, aim: Vector2i) -> void:
	var prev := state
	state = S.BUSY
	board.area = {}
	board.highlights = {}
	_forecast.visible = false
	log_line.emit("%s: %s" % [Txt.t(u.name_key), Txt.t(a.name_key)])
	_saw(u, a)
	var events := CombatRules.resolve(rng, grid, u, a, aim, units)
	# Pushed units are already moved in the rules; draw them where they started until the push plays.
	for ev in events:
		if ev.type == "push":
			var start: Vector2i = ev.path[0]
			ev.unit.vis = Vector2(CombatGrid.ground(start))
			ev.unit.vis_h = grid.height_at(start)
	for ev in events:
		await _play(ev)
	for o: CombatUnit in units:
		o.sync_view()
	changed.emit()
	if prev != S.OVER and state != S.OVER:
		state = prev


## BARK / GOAD landed ([USER] 2026-11-01 playtest: "used it right next to the elite wolf and nothing happens"): the
## shout rolls out, LOOK AT ME pops over the taunter, and every foe it pulls (CombatRules.taunt_pulls) turns to face
## it with a "!" over its head, so it reads which foes now have to come for it.
func _show_taunt(t: CombatUnit) -> void:
	if CharacterArt.has_anim(t.sprite, "attack"):
		board.play_anim(t, "attack")
	board.shout(t)
	board.float_text(t.cell, Txt.t("TAG_TAUNT"), board.TAUNT_COLOR, 22)
	await get_tree().create_timer(0.35).timeout
	var pulled := CombatRules.taunt_pulls(grid, t, units)
	for o in pulled:
		board.face(o, t.cell)
		board.float_text(o.cell, Txt.t("UI_TAUNT_PULLED"), board.TAUNT_COLOR, 26)
	log_line.emit(Txt.f("LOG_TAUNT_PULLS", [Txt.t(t.name_key), pulled.size()]))
	await get_tree().create_timer(0.5).timeout


func _play(ev: Dictionary) -> void:
	var t: CombatUnit = ev.get("unit")  # a big move's mark and landing have none
	match ev.type:
		"hit":
			var src: CombatUnit = ev.src
			if ev.get("big", false):
				await get_tree().create_timer(0.15).timeout
			else:
				await board.animate_attack(src, t, true)
			# every blow pops its number; a crit's is bigger ([USER] 2026-10-29)
			if ev.crit:
				board.float_text(t.cell, "-%d!" % ev.amount, Color(1, 0.55, 0.3), 26)
			else:
				board.float_text(t.cell, "-%d" % ev.amount, Color(1, 0.85, 0.5))
			log_line.emit(Txt.f("LOG_HIT_CRIT" if ev.crit else "LOG_HIT", [Txt.t(src.name_key), Txt.t(t.name_key), ev.amount]))
			t.shown_hp = maxi(0, t.shown_hp - int(ev.amount))
			if t.shown_hp <= 0:
				log_line.emit(Txt.f("LOG_DOWN", Txt.t(t.name_key)))
				for m: CombatUnit in t.minions:  # its called pieces fell with it
					if m.crumbled and m.shown_hp > 0:
						m.shown_hp = 0
						board.float_text(m.cell, Txt.t("UI_CRUMBLE"), Color(0.9, 0.6, 1.0))
		"heal":
			t.shown_hp = mini(t.max_hp, t.shown_hp + int(ev.amount))
			log_line.emit(Txt.f("LOG_HP_BACK", [Txt.t(t.name_key), ev.amount]))
			board.float_text(t.cell, "+%d" % ev.amount, Color(0.5, 1.0, 0.6))
			await get_tree().create_timer(0.25).timeout
		"status":
			if ev.get("struck", false):
				await board.animate_attack(ev.src, t, true)
			log_line.emit(Txt.f("LOG_STATUS", [Txt.t(t.name_key), Txt.t("TAG_" + String(ev.status).to_upper())]))
			if ev.status == CombatRules.STATUS_TAUNT:
				await _show_taunt(t)
			else:
				board.float_text(t.cell, Txt.t("TAG_" + String(ev.status).to_upper()), Color(0.75, 0.85, 1.0))
				await get_tree().create_timer(0.2).timeout
		"push":
			log_line.emit(Txt.f("LOG_PUSH", Txt.t(t.name_key)))
			await board.animate_push(t, ev.path)
		"bump", "fall":
			t.shown_hp = maxi(0, t.shown_hp - int(ev.amount))
			board.float_text(t.cell, "%s -%d" % [Txt.t("UI_" + String(ev.type).to_upper()), ev.amount], Color(1, 0.7, 0.4))
			log_line.emit("  %s %s -%d" % [Txt.t(t.name_key), Txt.t("UI_" + String(ev.type).to_upper()), ev.amount])
			await get_tree().create_timer(0.25).timeout
		"help":
			_deed(ev.get("by"), ev.src, "teamup")
			await board.animate_attack(ev.src, t, true)
			board.float_text(t.cell, "-%d %s" % [ev.amount, Txt.t("UI_HELP")], Color(0.7, 0.9, 1.0))
			log_line.emit(Txt.f("LOG_HELP", [Txt.t(ev.src.name_key), ev.amount]))
			t.shown_hp = maxi(0, t.shown_hp - int(ev.amount))
		"revive":
			_deed(ev.src, t, "help_up")
			t.shown_hp = int(ev.amount)
			board.float_text(t.cell, Txt.t("UI_AIDED"), Color(0.5, 1.0, 0.6))
			log_line.emit(Txt.f("LOG_AIDED", [Txt.t(ev.src.name_key), Txt.t(t.name_key)]))
			await get_tree().create_timer(0.25).timeout
		"knockout":
			await board.animate_attack(ev.src, t, true)
			board.float_text(t.cell, Txt.t("UI_KNOCKED_OUT"), Color(1, 0.6, 0.5))
			log_line.emit(Txt.f("LOG_KNOCKED_OUT", [Txt.t(ev.src.name_key), Txt.t(t.name_key)]))
		"field":
			log_line.emit(Txt.f("LOG_FIELD", [Txt.t(ev.src.name_key), Txt.t("FIELD_" + String(ev.field).to_upper())]))
			await get_tree().create_timer(0.2).timeout
		"spring":
			board.float_text(t.cell, Txt.t("FIELD_" + String(ev.field).to_upper()), Color(1, 0.8, 0.5))
			log_line.emit(Txt.f("LOG_SPRING", [Txt.t(t.name_key), Txt.t("FIELD_" + String(ev.field).to_upper())]))
		"free_hit":
			board.float_text(ev.src.cell, Txt.t("UI_FREE_HIT"), Color(1, 1, 1))
			log_line.emit(Txt.f("LOG_FREE_HIT", [Txt.t(ev.src.name_key), Txt.t(t.name_key)]))
			await get_tree().create_timer(0.2).timeout
		"counter":
			log_line.emit(Txt.f("LOG_COUNTER", Txt.t(ev.src.name_key)))
			board.float_text(ev.src.cell, Txt.t("UI_COUNTER"), Color(1, 1, 1))
			await get_tree().create_timer(0.2).timeout
		"carry":
			_deed(ev.src, t, "help_up")  # counts as a help for their bond
			t.vis = Vector2(CombatGrid.ground(ev.to))
			t.vis_h = grid.height_at(ev.to)
			board.float_text(t.cell, Txt.t("SKILL_CARRY"), Color(0.6, 0.9, 1.0))
			await get_tree().create_timer(0.25).timeout
		"swap":
			board.float_text(t.cell, Txt.t("SKILL_SHADOW_SWAP"), Color(0.7, 0.6, 1.0))
			await get_tree().create_timer(0.25).timeout
		"overwatch":
			log_line.emit(Txt.f("LOG_OVERWATCH", Txt.t(ev.src.name_key)))
			board.float_text(ev.src.cell, Txt.t("SKILL_OVERWATCH"), Color(1.0, 0.9, 0.5))
			await get_tree().create_timer(0.2).timeout
		"command":
			board.float_text(t.cell, Txt.t("SKILL_COMMAND"), Color(1.0, 0.9, 0.5))
			log_line.emit(Txt.f("LOG_COMMAND", Txt.t(t.name_key)))
			await get_tree().create_timer(0.25).timeout
		"reveal":
			board.float_text(t.cell, Txt.t("UI_AMBUSH"), Color(1.0, 0.5, 0.4), 22)
			log_line.emit(Txt.f("LOG_AMBUSH", Txt.t(t.name_key)))
			await get_tree().create_timer(0.35).timeout
		"hp_phase":
			board.float_text(ev.unit.cell, Txt.t("UI_PHASE"), Color(0.9, 0.6, 1.0), 22)
			log_line.emit(Txt.f("LOG_PHASE", Txt.t(ev.unit.name_key)))
			await get_tree().create_timer(0.4).timeout
		"mark":
			_saw(ev.src, ev.ability)
			log_line.emit(Txt.f("LOG_MARK", [Txt.t(ev.src.name_key), Txt.t(ev.ability.name_key)]))
			board.float_text(ev.src.cell, Txt.t(ev.ability.name_key), Color(0.9, 0.6, 1.0))
			_refresh_danger()
			await get_tree().create_timer(0.4).timeout
		"land":
			log_line.emit("%s: %s" % [Txt.t(ev.src.name_key), Txt.t(ev.ability.name_key)])
			board.float_text(ev.src.cell, Txt.t(ev.ability.name_key), Color(0.9, 0.6, 1.0), 22)
			board.marks = {}
			await get_tree().create_timer(0.4).timeout
		"summon":
			log_line.emit(Txt.f("LOG_SUMMON", Txt.t(ev.src.name_key)))
			t.sync_view()
			board.float_text(t.cell, Txt.t("UI_SUMMONED"), Color(0.9, 0.6, 1.0))
			await get_tree().create_timer(0.25).timeout


func _check_end() -> bool:
	if state == S.OVER:
		return true
	var r := goals.check(units, rounds_done)
	if not r.won and not r.lost:
		return false
	outcome.how = r.how
	_finish(r.won)
	return true


func _finish(won: bool) -> void:
	state = S.OVER
	_deselect()
	board.danger = {}
	board.marks = {}
	board.combat_stance = false
	_banner.text = Txt.t("UI_VICTORY") if won else Txt.t("UI_DEFEAT")
	log_line.emit(Txt.t("LOG_FIGHT_WON") if won else Txt.t("LOG_FIGHT_LOST"))
	changed.emit()
	finished.emit(won)


# --- selection and the menu ----------------------------------------------------------

func _select(u: CombatUnit) -> void:
	selected = u
	board.selected = u
	if not u.moved:
		u.move_origin = u.cell
	targeting = null
	_moving = false
	state = S.MENU
	_show_attack_hints()
	_open_menu()
	info.emit(unit_text(u))


func _deselect() -> void:
	selected = null
	targeting = null
	_moving = false
	if board:
		board.selected = null
		board.highlights = {}
		board.area = {}
	reach = {}
	_hide_menu()
	if _forecast:
		_forecast.visible = false
	if state == S.MENU or state == S.TARGET:
		state = S.IDLE
	_refresh_cancel()


## The menu's own hints: where the basic attack can land (the move tiles wait for MOVE).
func _show_attack_hints() -> void:
	board.highlights = {}
	board.area = {}
	reach = {}
	if selected != null and not selected.acted:
		for c in CombatRules.target_cells(grid, selected, selected.abilities[0], units, selected.cell):
			board.highlights[c] = ENEMY_COLOR


## MOVE: the menu hides and the tiles the piece can reach light up. CANCEL or Esc goes back to the menu.
func _begin_move() -> void:
	if selected == null or selected.moved:
		return
	_moving = true
	_hide_menu()
	_show_move_tiles()
	_refresh_cancel()


func _show_move_tiles() -> void:
	board.highlights = {}
	board.area = {}
	reach = CombatRules.reachable(grid, selected, units)
	for c: Vector2i in reach.cost:
		if c != selected.cell:
			board.highlights[c] = MOVE_COLOR


func _cancel_move() -> void:
	_moving = false
	reach = {}
	_show_attack_hints()
	_open_menu()
	_refresh_cancel()


## CANCEL shows only while a move or a target is being picked (the menu is hidden then).
func _refresh_cancel() -> void:
	if _cancel:
		_cancel.visible = _moving or state == S.TARGET


func _open_menu() -> void:
	for c in _menu_box.get_children():
		_menu_box.remove_child(c)  # gone now, so the menu's size comes from the new items only
		c.queue_free()
	var u := selected
	var entries := _entries(u)
	if _hud.layout != "list":
		_hide_menu()
		_hud.swap_count = _ready_units().filter(func(o: CombatUnit) -> bool: return o != u).size()
		_hud.show_for(u, entries, board.cell_screen_pos(u.cell), _rect if _rect.has_area() else get_viewport_rect())
		_banner.visible = false  # the dock sits where the banner does
		return
	for e in entries:
		_menu_item(String(e.text), bool(e.enabled), e.cb, e.get("ability"))
	_menu.visible = true
	_menu.reset_size()
	await get_tree().process_frame
	if selected == u and _menu.visible:
		_place_menu()


## What piece u can do now, in menu order: {text, enabled, cb, ability, kind, count}. Every layout shows these.
func _entries(u: CombatUnit) -> Array:
	var out := []
	var add := func(text: String, enabled: bool, cb: Callable, kind: String, a: Ability = null, count := 0) -> void:
		out.append({"text": text, "enabled": enabled, "cb": cb, "kind": kind, "ability": a, "count": count})
	if not u.moved and CombatRules.move_points(u) > 0:
		add.call(Txt.t("ACT_MOVE"), true, _begin_move, "move")
	if not u.acted:
		for a in u.abilities:
			var ok_now := _has_targets(u, a) and CombatRules.usable(u, a) and not (a.kind == "swap" and u.moved)  # a swap is the move
			add.call(_ability_label(u, a) if _hud.layout == "list" else Txt.t(a.name_key), ok_now, _start_targeting.bind(a), "skill", a)
		if _talk_target(u) != null:
			add.call(Txt.t("ACT_TALK"), true, _on_talk, "talk")
		for a in CombatRules.extra_actions(u):  # AID, only while a downed teammate lies next to this piece
			if _has_targets(u, a):
				add.call(Txt.t(a.name_key), true, _start_targeting.bind(a), "aid", a)
		for id: String in Db.combat_items:  # only what's on this piece's own belt
			var it: Ability = Db.combat_items[id]
			var have := u.belt.count(it.spends) if u.belt != null else 0
			if have <= 0:
				continue
			var label := "%s  (%s %d)" % [Txt.t(it.name_key), Txt.t(String(Db.items[it.spends].name_key)), have] if _hud.layout == "list" else Txt.t(it.name_key)
			add.call(label, CombatRules.usable(u, it) and _has_targets(u, it), _start_targeting.bind(it), "item", it, have)
		add.call(Txt.t("ACT_GUARD"), true, _on_guard, "guard")
	if u.moved and not u.acted and not u.left_guard:  # a free hit taken on the way can't be undone
		add.call(Txt.t("ACT_UNDO"), true, _undo_move, "undo")
	add.call(Txt.t("ACT_WAIT"), true, _on_wait, "wait")
	return out


## The action layout from the settings ([USER] 2026-10-30: three versions; the losers go once Brandon picks).
static func action_layout() -> String:
	var l := String(Game.meta.get("settings", {}).get("action_ui", "dock"))
	return l if l in ActionHud.LAYOUTS else "dock"


func _next_layout() -> void:
	var i := (ActionHud.LAYOUTS.find(_hud.layout) + 1) % ActionHud.LAYOUTS.size()
	set_layout(ActionHud.LAYOUTS[i])


func set_layout(l: String) -> void:
	_hud.layout = l
	Game.set_setting("action_ui", l)
	_show_layout()
	if selected != null and _menu_shown():
		_hud.clear()
		_open_menu()


func _show_layout() -> void:
	_layout_btn.text = Txt.f("UI_ACTION_UI", Txt.t("UI_LAYOUT_" + _hud.layout.to_upper()))


func _menu_shown() -> bool:
	return (_menu != null and _menu.visible) or (_hud != null and _hud.visible)


func _hide_menu() -> void:
	if _menu:
		_menu.visible = false
	if _hud:
		_hud.clear()
	if _banner:
		_banner.visible = true


func _place_menu() -> void:
	var p := board.cell_screen_pos(selected.cell) + Vector2(56, -16)
	var vs := get_viewport_rect().size
	p.x = minf(p.x, vs.x - _menu.size.x - 4)
	p.y = clampf(p.y, 4, vs.y - _menu.size.y - 4)
	_menu.position = p


func _ability_label(u: CombatUnit, a: Ability) -> String:
	var label := Txt.t(a.name_key)
	if a.res_cost > 0 and u.res_kind != "":
		label += "  (%s %d)" % [Txt.t("RES_" + u.res_kind.to_upper()), a.res_cost]
	return label


## a: the action's ability, if it aims at something: hovering it (mouse or keys) shows its range on the board.
func _menu_item(text: String, enabled: bool, cb: Callable, a: Ability = null) -> void:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(96, 24)
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(cb)
	b.mouse_entered.connect(preview_reach.bind(a))
	b.focus_entered.connect(preview_reach.bind(a))
	b.mouse_exited.connect(_end_preview.bind(b))
	b.focus_exited.connect(_end_preview.bind(b))
	_menu_box.add_child(b)


func _process(_delta: float) -> void:
	if not board.reach.is_empty() and not _menu_shown():
		board.reach = {}  # the menu went away (an action picked, a step back, the phase over): so does the preview


## The range of action a for the selected piece ([USER] 2026-10-30): every place it could aim at in blue,
## foes in reach marked. null (MOVE, GUARD, WAIT) clears it.
func preview_reach(a: Ability) -> void:
	var out := {}
	var u := selected
	if a != null and u != null and state != S.TARGET:
		for c in CombatRules.reach_cells(grid, u, a, u.cell):
			out[c] = 1
		if a.hostile():
			for o: CombatUnit in units:
				if o.alive() and o.team != u.team and out.has(o.cell):
					out[o.cell] = 2
	board.reach = out


## Off an action: its range goes, unless the pointer or focus already moved onto another (which drew its own).
func _end_preview(b: Button) -> void:
	await get_tree().process_frame
	if not is_instance_valid(b) or not _menu.visible:
		board.reach = {}
		return
	var on := false
	for c in _menu_box.get_children():
		if c is Button and (c.has_focus() or c.is_hovered()):
			on = true
	if not on:
		board.reach = {}


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
	_hide_menu()
	board.reach = {}
	board.highlights = {}
	var col := ENEMY_COLOR if a.hostile() else ALLY_COLOR
	if a.target == "cell":
		col = AREA_COLOR
	for c in CombatRules.target_cells(grid, selected, a, units, selected.cell):
		board.highlights[c] = col
	_refresh_cancel()
	info.emit(Txt.t(a.name_key))


func _cancel_targeting() -> void:
	targeting = null
	_carry_friend = null
	_carry_spots = {}
	state = S.MENU
	_forecast.visible = false
	_show_attack_hints()
	_open_menu()
	_refresh_cancel()


## The fight's goals as lines for the log at the start ([USER] c10).
func goal_lines() -> PackedStringArray:
	var parts: PackedStringArray = []
	for k in goals.kinds:
		parts.append(Txt.f("UI_GOAL_HOLD", goals.hold_rounds) if k == "hold" else Txt.t("UI_GOAL_" + k.to_upper()))
	var out: PackedStringArray = [Txt.f("UI_GOALS", (" %s " % Txt.t("UI_GOAL_OR")).join(parts))]
	for u: CombatUnit in units:
		if u.protect:
			out.append(Txt.f("UI_GOAL_PROTECT", Txt.t(u.name_key)))
	return out


## The foe the hero can TALK to from where it stands, or null: only the hero, only in a fight written for it
## with its flag set, and within talk_range ([USER] c17).
func _talk_target(u: CombatUnit) -> CombatUnit:
	if not talk_open or goals.talk.is_empty() or u.member.is_empty() or (u.member.def as CharacterDef).id != &"lead":
		return null
	for o: CombatUnit in units:
		if o.talk_to and o.alive() and CombatRules.dist(o.cell, u.cell) <= int(CombatRules.num("talk_range")):
			return o
	return null


## TALK is the hero's action. Enough talking and the group flees (a win) or the foe leaves and joins.
func _on_talk() -> void:
	var u := selected
	var t := _talk_target(u)
	if t == null:
		return
	board.face(u, t.cell)
	board.float_text(t.cell, Txt.t("UI_TALK_SAID"), Color(1, 1, 0.8))
	log_line.emit(Txt.f("LOG_TALK", [Txt.t(u.name_key), Txt.t(t.name_key)]))
	var result := goals.talk_once()
	if result == "flee":
		outcome.how = "talk"
		log_line.emit(Txt.t("LOG_TALK_FLEE"))
		_finish(true)
		return
	if result.begins_with("join:"):
		outcome.joined.append(result.substr(5))
		log_line.emit(Txt.f("LOG_TALK_JOIN", Txt.t(t.name_key)))
		units.erase(t)
		board.units = units
		t.talk_to = false
		if _check_end():
			return
	_after_action(u)


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
	selected.move_spent = 0
	_select(selected)
	_refresh_danger()


## run: hit and run reopened the move, so its tiles come straight up (CANCEL goes to the menu: WAIT ends it).
func _after_action(u: CombatUnit, run := false) -> void:
	u.acted = true
	if not u.alive() or u.done() or CombatRules.move_left(u) == 0:
		u.moved = true
		_finish_unit()
		return
	_refresh_danger()
	_select(u)
	if run:
		_begin_move()


## A character used its move and action, or chose WAIT: the next one with moves comes up by itself ([USER]
## 2026-10-30, dev-action-tips), or the phase ends when nobody has any left.
func _finish_unit() -> void:
	var was := selected
	_deselect()
	_refresh_danger()
	changed.emit()
	var waiting := _ready_units()
	if waiting.is_empty():
		end_player_phase()
		return
	if auto_fight:
		return
	var i := units.find(was)
	for k in units.size():  # the next in the party's order after the one that just finished
		var o: CombatUnit = units[(i + 1 + k) % units.size()] if i >= 0 else waiting[0]
		if waiting.has(o):
			_select(o)
			return


## SWAP: the next character who still has moves; a move already made stays made.
func _swap() -> void:
	var waiting := _ready_units()
	if waiting.is_empty() or not is_player_turn():
		return
	var i := (waiting.find(selected) + 1) % waiting.size()
	_select(waiting[i])


func _ready_units() -> Array:
	return units.filter(func(o: CombatUnit) -> bool: return o.team == 0 and o.alive() and not o.done())


# --- input ----------------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.is_echo():
		return
	match event.keycode:
		KEY_ESCAPE:
			_back()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0:
			if _hud.visible and state == S.MENU:  # the keys of the hand
				_hud.press_key((event.keycode - KEY_1) if event.keycode != KEY_0 else 9)
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
			if _moving:
				_cancel_move()
			elif selected.moved and not selected.acted:
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
			if _moving:
				if u == null and reach.get("cost", {}).has(c):
					_move_selected(c)
			elif u and u.team != 0 and not selected.acted and board.highlights.get(c) == ENEMY_COLOR:
				_start_targeting(selected.abilities[0])
				_on_cell_hovered(c)
			elif u and u.team == 0 and u != selected and not u.done() and (not selected.moved or selected.acted):
				_select(u)
		S.TARGET:
			if targeting != null and targeting.kind == "carry":  # CARRY: first the friend, then where to go
				if _carry_friend == null and board.highlights.has(c):
					_carry_friend = CombatRules.occupant(units, c)
					_carry_spots = CombatRules.carry_spots(grid, selected, _carry_friend, targeting, units)
					board.highlights = {}
					for d: Vector2i in _carry_spots:
						board.highlights[d] = MOVE_COLOR
				elif _carry_friend != null and _carry_spots.has(c):
					var who := selected
					_hide_menu()
					_cancel.visible = false
					await _use_clutch(who, targeting, _carry_friend.cell, c, _carry_spots[c])
					if _check_end():
						return
					_after_action(who)
				return
			if board.highlights.has(c):
				var who := selected
				var a := targeting
				if a.kind == "command" or a.kind == "swap":
					_hide_menu()
					_cancel.visible = false
					await _use_clutch(who, a, c, c, c)
					if _check_end():
						return
					if a.kind == "swap":  # SHADOW SWAP was its move: it can still strike or AID
						who.moved = true
						who.move_spent = CombatRules.move_points(who)
						if who.acted:
							_finish_unit()
						else:
							_select(who)
						return
					_after_action(who)
					return
				if a.target == "cell" and CombatRules.affected_units(grid, who, a, c, units, who.cell).is_empty():
					return
				_hide_menu()
				_cancel.visible = false
				await _use(who, a, c)
				if _check_end():
					return
				_after_action(who, CombatRules.hit_and_run(who, a))


func _move_selected(c: Vector2i) -> void:
	var u := selected
	state = S.BUSY
	_moving = false
	_hide_menu()
	_refresh_cancel()
	board.highlights = {}
	var path := CombatRules.path_to(reach.prev, u.cell, c)
	u.move_spent += int(reach.cost[c])
	if not await _leave_guards(u, c):
		if not _check_end():
			_finish_unit()
		return
	log_line.emit(Txt.f("LOG_MOVE", [Txt.t(u.name_key), maxi(1, path.size() - 1)]))
	await board.animate_move(u, path)
	u.place(c, grid.height_at(c))
	u.moved = true
	await _spot(u)
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
			for a in CombatRules.area(grid, targeting, c, selected.cell):
				board.area[a] = true
			_show_forecast(selected, targeting, c)
		else:
			_forecast.visible = false
		return
	var u := CombatRules.unit_at(units, c)
	if u and u.hiding and u.team != 0:
		u = null  # nothing to see there yet
	_show_sight(u)
	var marked: Array = CombatRules.marks(units).get(c, [])
	if u and not marked.is_empty():
		info.emit(unit_text(u) + "\n" + tile_text(c))
	elif u:
		info.emit(unit_text(u))
	else:
		info.emit(tile_text(c))


## Hovering a ranged piece while nothing else is lit shades the tiles in its range it can't see ([USER] c14).
func _show_sight(u: CombatUnit) -> void:
	for k in board.highlights.keys():
		if board.highlights[k] == SIGHT_SHADE:
			board.highlights.erase(k)
	if u == null or not u.alive() or state != S.IDLE or not board.highlights.is_empty():
		return
	for k in CombatRules.blind_cells(grid, u, u.cell):
		board.highlights[k] = SIGHT_SHADE


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
				var lo := maxi(0, t.hp - int(e.dmg_max) * int(e.swings) - int(e.help))
				var hi := maxi(0, t.hp - int(e.dmg_min) * int(e.swings) - int(e.help))
				if known(t):
					lines.append("%s  HP %d > %s" % [Txt.t(t.name_key), t.hp, str(hi) if lo == hi else "%d-%d" % [lo, hi]])
				else:
					lines.append("%s  HP ? > ?" % Txt.t(t.name_key))
				var line := Txt.f("UI_DMG_PREVIEW", [_range_text(e), int(round(e.crit * 100))])
				if e.swings > 1:
					line += "  " + Txt.f("UI_SWINGS", e.swings)
				if int(e.help) > 0:
					line += "  " + Txt.f("UI_HELP_PREVIEW", [int(e.help), Txt.t((e.helper as CombatUnit).name_key)])
				lines.append("  " + line)
				lines.append("  " + _parts_text(e.dmg_parts) + _minus_text(e.armor_parts))
				lines.append("  " + Txt.t("UI_CRIT") + ": " + _parts_text(e.crit_parts, "%"))
			"hex":
				lines.append("%s  %s" % [Txt.t(t.name_key), Txt.t("TAG_" + a.status.to_upper())])
			"heal":
				lines.append("%s  HP %d > %d" % [Txt.t(t.name_key), t.hp, t.hp + int(e.heal)])
			"revive":
				lines.append("%s  HP 0 > %d" % [Txt.t(t.name_key), int(e.heal)])
			"buff":
				lines.append("%s  %s" % [Txt.t(t.name_key), Txt.t("TAG_" + a.status.to_upper())])
	if not f.counter.is_empty():
		var c_line := Txt.f("UI_COUNTER_PREVIEW", [_range_text(f.counter), int(round(float(f.counter.crit) * 100))])
		if int(f.counter.get("swings", 1)) > 1:
			c_line += "  " + Txt.f("UI_SWINGS", f.counter.swings)
		lines.append(c_line)
	_forecast_label.text = "\n".join(lines)
	_forecast.visible = true
	_forecast.reset_size()


static func _parts_text(parts: Array, unit := "") -> String:
	var out: PackedStringArray = []
	for p in parts:
		out.append(("%s %+d" if out.size() > 0 else "%s %d") % [Txt.t(p[0]), p[1]] + unit)
	return "  ".join(out)


## What armor takes off, as "  - ARMOR 1  GUARD 2", or "" when nothing does.
static func _minus_text(parts: Array) -> String:
	if parts.is_empty():
		return ""
	var out: PackedStringArray = []
	for p in parts:
		out.append("%s %d" % [Txt.t(p[0]), p[1]])
	return "  -  " + "  ".join(out)


## "3" or "2-4": one blow's damage before a crit.
static func _range_text(e: Dictionary) -> String:
	return str(e.dmg_min) if int(e.dmg_min) == int(e.dmg_max) else "%d-%d" % [e.dmg_min, e.dmg_max]


func _refresh_danger() -> void:
	board.danger = CombatRules.danger_zone(grid, units, 1) if show_danger and state != S.OVER else {}
	var marked := {}  # a boss's big move shows all the time, not only with D ([USER] design-boss-warning)
	if state != S.OVER:
		var m := CombatRules.marks(units)
		for c: Vector2i in m:
			marked[c] = m[c].map(func(x: Dictionary) -> int: return int(x.left)).min()
	board.marks = marked
	# the zones guarding pieces hold, both sides ([USER] c13: draw the ring)
	var ring := {}
	if state != S.OVER:
		for team in [0, 1]:
			ring.merge(CombatRules.guard_ring(grid, units, team))
	board.guard_ring = ring


func unit_text(u: CombatUnit) -> String:
	var lines: PackedStringArray = [Txt.t(u.name_key)]
	var know := known(u)
	lines.append(("HP %d/%d" % [u.hp, u.max_hp] if know else "HP ?/?") + "  MOVE %d  JUMP %d" % [CombatRules.move_points(u), u.jump])
	lines.append("DMG %d  ARMOR %d  CRIT +%d%%  RNG %d-%d" % [u.damage, u.armor, u.crit, u.range_min, u.range_max])
	if u.res_kind != "":
		lines.append("%s %d/%d" % [Txt.t("RES_" + u.res_kind.to_upper()), u.res, u.res_max])
	if not u.tags.is_empty():  # foe tags, and what hits them harder or softer (data/tags.csv)
		lines.append(", ".join(u.tags.map(func(t: StringName) -> String: return Txt.t("FOE_" + String(t).to_upper()))))
	var skills: PackedStringArray = []
	for a in u.abilities.slice(1):
		if know or used.get(u, []).has(a.id):  # an unknown boss shows only the moves he has used
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
	var m: Array = CombatRules.marks(units).get(c, [])
	if not m.is_empty():  # what lands here, and when
		return Txt.f("UI_MARK", [Txt.t(m[0].ability.name_key), int(m[0].left)])
	return "%s  H%d  COST %d  COVER %+d" % [CombatGrid.T.keys()[t], grid.height_at(c), grid.step_cost(c) if grid.passable(c) else 0, grid.cover(c)]

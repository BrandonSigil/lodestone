extends Node2D
## The battle view: one fight on one battle map, with no editing tools. It is where fights run for the map
## maker's Play test and for the screenshot tools. Maps are edited in the map maker (F8).
##
## Opens the map in Game.sandbox_map (set by the map maker's Play test) or else data/maps/highland.json.
## R restarts the fight with new dice. The HUD is a round label, END TURN, the last info line and a short log.
## The labels are developer labels, not player-facing text, so they don't go through Txt, except the round line.

const HUD_H := 44.0
const WALL_ON := true  ## the newest look: the skyline wallpaper and foreground band

var battle: Battle
var setup: SandboxSetup
var _phase: Label
var _info: Label
var _log: Label
var _hud: CanvasLayer


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.13, 0.16, 0.16))
	var path := Game.sandbox_map if Game.sandbox_map != "" else SandboxSetup.MAP_DIR + "highland.json"
	setup = SandboxSetup.load_file(path)
	if setup == null:
		setup = SandboxSetup.default_setup()
	_build_hud()
	_start()
	get_viewport().size_changed.connect(_layout)


func _exit_tree() -> void:
	CombatRules.reset_switches()


## Rectangle the board is shown in: everything under the HUD bar.
func play_rect() -> Rect2:
	var vs := get_viewport_rect().size
	return Rect2(0, HUD_H, vs.x, vs.y - HUD_H)


func _layout() -> void:
	if battle:
		battle.layout(play_rect())


func _start() -> void:
	if battle:
		battle.queue_free()
	setup.apply_switches()
	var units := setup.build_units()
	battle = Battle.new()
	add_child(battle)
	battle.wallpaper = WALL_ON
	battle.setup(setup.grid.resized(setup.grid.w, setup.grid.h), units, randi(), setup.strangeness, setup.supplies.duplicate())
	battle.board.art_set = setup.art_set
	battle.board.show_grid = false
	battle.board.rot = setup.view
	battle.info.connect(func(t: String) -> void: _info.text = t)
	battle.log_line.connect(_add_log)
	battle.phase_changed.connect(func(team: int) -> void:
		_phase.text = Txt.f("UI_ROUND", battle.round_no) + "  " + (Txt.t("UI_PLAYER_PHASE") if team == 0 else Txt.t("UI_ENEMY_PHASE")))
	battle.finished.connect(func(won: bool) -> void:
		_phase.text = ("WIN" if won else "LOSE") + "  -  R to restart")
	_log.text = ""
	_layout()
	battle.start()


func _add_log(line: String) -> void:
	var lines := _log.text.split("\n", false)
	lines.append(line)
	_log.text = "\n".join(lines.slice(-6))


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)
	var bar := Panel.new()
	bar.position = Vector2.ZERO
	bar.size = Vector2(get_viewport_rect().size.x, HUD_H)
	bar.anchor_right = 1.0
	bar.add_theme_stylebox_override("panel", _box(Color(0.1, 0.12, 0.12, 0.92)))
	_hud.add_child(bar)
	var row := HBoxContainer.new()
	row.position = Vector2(12, 6)
	row.add_theme_constant_override("separation", 14)
	bar.add_child(row)
	_phase = Label.new()
	_phase.add_theme_font_size_override("font_size", 16)
	_phase.add_theme_color_override("font_color", Color(1, 0.88, 0.55))
	row.add_child(_phase)
	row.add_child(_button("RESTART (R)", func() -> void: _start()))
	row.add_child(_button("END TURN (E)", func() -> void: if battle: battle.end_player_phase()))
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 13)
	_info.add_theme_color_override("font_color", Color(0.9, 0.92, 0.87))
	row.add_child(_info)
	_log = Label.new()
	_log.add_theme_font_size_override("font_size", 12)
	_log.add_theme_color_override("font_color", Color(0.75, 0.8, 0.76))
	_hud.add_child(_log)
	_log.position = Vector2(12, HUD_H + 8)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _box(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	return sb


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.is_echo():
		return
	if event.keycode == KEY_R:
		_start()
	elif event.keycode == KEY_E and battle:
		battle.end_player_phase()

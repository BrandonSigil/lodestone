extends Node2D
## Combat sandbox: a developer tool for building test maps and tuning fights.
## Open scenes/combat_sandbox.tscn and press F6 (or F5 from the village with the SANDBOX key, see docs/systems/combat.md).
##
## EDIT mode: paint terrain and height, place party members and enemies, set the difficulty dials.
## PLAY mode: fight it with the real Battle controller. R restarts the fight from the setup.
## BALANCE: the AI plays both sides many times and reports win rate, rounds and HP left.
## The labels here are tool labels for the designer, not player-facing text, so they don't go through Txt.

const TOP_H := 44.0
const LEFT_W := 230.0
const RIGHT_W := 270.0
const BG := Color(0.13, 0.16, 0.16)
const PANEL := Color(0.18, 0.22, 0.22)
const INK := Color(0.9, 0.92, 0.87)
const BRUSHES := ["GRASS", "FOREST", "WATER", "ROCK", "ROAD", "STONE", "STAIRS", "RUIN", "HOLE", "ZONE", "RAISE", "LOWER", "PARTY", "ENEMY", "ERASE"]
const BRUSH_TERRAIN := {"GRASS": CombatGrid.T.GRASS, "FOREST": CombatGrid.T.FOREST, "WATER": CombatGrid.T.WATER,
	"ROCK": CombatGrid.T.ROCK, "ROAD": CombatGrid.T.ROAD, "STONE": CombatGrid.T.STONE, "STAIRS": CombatGrid.T.STAIRS,
	"RUIN": CombatGrid.T.RUIN, "HOLE": CombatGrid.T.VOID}

var setup: SandboxSetup
var editing := true
var brush := "GRASS"
var random_dice := true
var show_grid := true  ## cell outlines on the board (tester only, not saved with the map)
var preview: CombatBoard
var battle: Battle
var _sim_running := false
var _last_raise := {}  ## cells already raised or lowered in this drag

var _ui: CanvasLayer
var _mode_button: Button
var _name_edit: LineEdit
var _load_menu: OptionButton
var _set_menu: OptionButton  ## battle tile set
var _zone_pick: OptionButton  ## tile set the ZONE brush paints onto cells
var _w_spin: SpinBox
var _h_spin: SpinBox
var _seed_spin: SpinBox
var _edit_panel: VBoxContainer
var _play_panel: VBoxContainer
var _spell_box: VBoxContainer  ## per-caster spell slot pickers, rebuilt when the party changes
var _spell_sig := ""
var _brush_buttons := {}
var _party_pick: OptionButton
var _enemy_pick: OptionButton
var _phase_label: Label
var _info_label: Label
var _log_label: Label
var _status: Label
var _dials := {}  ## "party:hp_pct" -> SpinBox
var _extra_spin: SpinBox
var _med_spin: SpinBox
var _food_spin: SpinBox
var _strange_spin: SpinBox
var _counter_check: CheckBox
var _mercy_check: CheckBox
var _dice_check: CheckBox
var _fights_spin: SpinBox
var _sim_label: Label
var _syncing := false


func _ready() -> void:
	RenderingServer.set_default_clear_color(BG)
	var maps := SandboxSetup.list_maps()
	setup = null
	for p in maps:
		if p.get_file() == "default.json":
			setup = SandboxSetup.load_file(p)
	if setup == null:
		setup = SandboxSetup.default_setup()
	_build_ui()
	_sync_controls()
	_enter_edit()
	get_viewport().size_changed.connect(_layout)


func _exit_tree() -> void:
	CombatRules.reset_switches()


# --- layout -----------------------------------------------------------------------------

func play_rect() -> Rect2:
	var vs := get_viewport_rect().size
	return Rect2(LEFT_W, TOP_H, vs.x - LEFT_W - RIGHT_W, vs.y - TOP_H)


func _layout() -> void:
	var r := play_rect()
	if preview:
		var bs := preview.board_size()
		var s := clampf(minf(r.size.x / bs.x, r.size.y / bs.y) * 0.95, 0.4, 1.6)
		preview.scale = Vector2.ONE * s
		preview.position = r.position + (r.size - bs * s) * 0.5 - preview.board_origin() * s
	if battle:
		battle.layout(r)


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 2
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = 13
	root.theme = theme
	_ui.add_child(root)

	# Top bar
	var top := _panel(root)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = TOP_H
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	top.add_child(bar)
	_mode_button = _button(bar, "PLAY  (F1)", _toggle_mode)
	_mode_button.custom_minimum_size.x = 96
	_button(bar, "RESTART (R)", _restart)
	bar.add_child(VSeparator.new())
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size.x = 110
	_name_edit.placeholder_text = "map name"
	_name_edit.text_changed.connect(func(t: String) -> void: setup.map_name = t)
	bar.add_child(_name_edit)
	_button(bar, "SAVE", _save)
	_load_menu = OptionButton.new()
	_load_menu.custom_minimum_size.x = 130
	_load_menu.item_selected.connect(_on_load_selected)
	bar.add_child(_load_menu)
	_refresh_load_menu()
	bar.add_child(VSeparator.new())
	bar.add_child(_bar_label("W"))
	_w_spin = _spin(bar, 5, 16, 1, 10)
	bar.add_child(_bar_label("H"))
	_h_spin = _spin(bar, 5, 16, 1, 8)
	_button(bar, "RESIZE", _resize)
	bar.add_child(VSeparator.new())
	bar.add_child(_bar_label("SEED"))
	_seed_spin = _spin(bar, 0, 99999, 1, 1)
	_seed_spin.value_changed.connect(func(v: float) -> void: if not _syncing: setup.seed_value = int(v))
	_button(bar, "GENERATE", _generate)
	bar.add_child(VSeparator.new())
	_button(bar, "TURN (Q)", _turn)

	# Left: editor tools or the fight log
	var left := _panel(root)
	left.anchor_bottom = 1.0
	left.offset_top = TOP_H
	left.offset_right = LEFT_W
	var left_box := VBoxContainer.new()
	left.add_child(left_box)
	_edit_panel = VBoxContainer.new()
	_edit_panel.add_theme_constant_override("separation", 4)
	left_box.add_child(_edit_panel)
	_edit_panel.add_child(_title("PAINT"))
	var grid_box := GridContainer.new()
	grid_box.columns = 2
	_edit_panel.add_child(grid_box)
	for b in BRUSHES:
		var btn := _button(grid_box, b, _set_brush.bind(b))
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(100, 28)
		_brush_buttons[b] = btn
	_edit_panel.add_child(_small_label("zone brush paints"))
	_zone_pick = OptionButton.new()
	_zone_pick.add_item("map's tile set")
	_zone_pick.set_item_metadata(0, "")
	for name in BattleArt.sets():
		_zone_pick.add_item(name)
		_zone_pick.set_item_metadata(_zone_pick.item_count - 1, name)
	_zone_pick.item_selected.connect(func(_i: int) -> void: _set_brush("ZONE"))
	_edit_panel.add_child(_zone_pick)
	_edit_panel.add_child(_small_label("party piece"))
	_party_pick = OptionButton.new()
	for d in Db.roster():
		_party_pick.add_item(Txt.t(d.name_key))
		_party_pick.set_item_metadata(_party_pick.item_count - 1, String(d.id))
	_party_pick.item_selected.connect(func(_i: int) -> void: _set_brush("PARTY"))
	_edit_panel.add_child(_party_pick)
	_edit_panel.add_child(_small_label("enemy piece"))
	_enemy_pick = OptionButton.new()
	for id in Db.class_ids():
		_enemy_pick.add_item(id)
		_enemy_pick.set_item_metadata(_enemy_pick.item_count - 1, id)
	_enemy_pick.item_selected.connect(func(_i: int) -> void: _set_brush("ENEMY"))
	_edit_panel.add_child(_enemy_pick)
	_edit_panel.add_child(_small_label(
		"left click / drag = paint\nright click = remove piece\nRAISE / LOWER = height 0-8\nSTAIRS climb +2 over Jump\nRUIN walls block sight\nHOLE cuts the island shape\nZONE mixes tile sets\nrock / ruin remove pieces\n\nF1 play   R restart\nsaved maps live in data/maps", 11))

	_status = _small_label("", 11)
	_status.add_theme_color_override("font_color", Color(0.75, 0.95, 0.75))
	left_box.add_child(_status)

	_play_panel = VBoxContainer.new()
	_play_panel.add_theme_constant_override("separation", 6)
	left_box.add_child(_play_panel)
	_phase_label = _title("")
	_play_panel.add_child(_phase_label)
	_button(_play_panel, "END TURN (E)", func() -> void: if battle: battle.end_player_phase())
	_button(_play_panel, "DANGER ZONE (D)", func() -> void:
		if battle:
			battle.show_danger = not battle.show_danger
			battle._refresh_danger())
	_info_label = _small_label("", 12)
	_info_label.custom_minimum_size = Vector2(LEFT_W - 16, 70)
	_play_panel.add_child(_info_label)
	_play_panel.add_child(_small_label(Txt.t("UI_HELP_COMBAT"), 11))
	_log_label = _small_label("", 11)
	_play_panel.add_child(_log_label)

	# Right: dials
	var right := _panel(root)
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_bottom = 1.0
	right.offset_left = -RIGHT_W
	right.offset_top = TOP_H
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var rb := VBoxContainer.new()
	rb.add_theme_constant_override("separation", 3)
	rb.custom_minimum_size.x = RIGHT_W - 20
	scroll.add_child(rb)
	rb.add_child(_title("ENEMY DIFFICULTY"))
	var presets := HBoxContainer.new()
	rb.add_child(presets)
	for p in SandboxSetup.PRESETS:
		var b := _button(presets, p, _apply_preset.bind(p))
		b.add_theme_font_size_override("font_size", 11)
	_dial_rows(rb, "enemy")
	_extra_spin = _dial(rb, "extra enemies", 0, 8, 1)
	_extra_spin.value_changed.connect(func(v: float) -> void:
		if not _syncing:
			setup.extra_enemies = int(v)
			_changed())
	rb.add_child(_title("PARTY"))
	_dial_rows(rb, "party")
	rb.add_child(_title(Txt.t("UI_SPELLS")))
	_spell_box = VBoxContainer.new()
	_spell_box.add_theme_constant_override("separation", 2)
	rb.add_child(_spell_box)
	rb.add_child(_title("SUPPLIES AND RULES"))
	_med_spin = _dial(rb, "medicine", 0, 20, 1)
	_med_spin.value_changed.connect(func(v: float) -> void: if not _syncing: setup.supplies.medicine = int(v))
	_food_spin = _dial(rb, "food", 0, 60, 1)
	_food_spin.value_changed.connect(func(v: float) -> void: if not _syncing: setup.supplies.food = int(v))
	_strange_spin = _dial(rb, "strangeness", 0, 1, 0.05)
	_strange_spin.value_changed.connect(func(v: float) -> void:
		if not _syncing:
			setup.strangeness = v
			_changed())
	_set_menu = OptionButton.new()
	_set_menu.add_theme_font_size_override("font_size", 12)
	_set_menu.add_item("tile set: forest")  # the base art is the forest set
	for name in BattleArt.sets():
		_set_menu.add_item(name)
	_set_menu.item_selected.connect(func(i: int) -> void:
		if not _syncing:
			setup.art_set = "" if i == 0 else _set_menu.get_item_text(i)
			_changed())
	rb.add_child(_set_menu)
	var grid_check := _check(rb, "grid lines", func(on: bool) -> void:
		show_grid = on
		if preview:
			preview.show_grid = on
		if battle:
			battle.board.show_grid = on)
	grid_check.button_pressed = show_grid
	_counter_check = _check(rb, "counterattacks", func(on: bool) -> void: setup.counters = on)
	_mercy_check = _check(rb, "party luck after misses", func(on: bool) -> void: setup.mercy = on)
	_dice_check = _check(rb, "new dice on restart", func(on: bool) -> void: random_dice = on)
	rb.add_child(_title("BALANCE"))
	_fights_spin = _dial(rb, "fights to simulate", 10, 500, 10)
	_fights_spin.value = 50
	_button(rb, "RUN AI vs AI", _run_sim)
	_sim_label = _small_label("AI plays both sides. Aim: party wins\n60-85% with 30-60% HP left.", 12)
	rb.add_child(_sim_label)


func _dial_rows(parent: Control, side: String) -> void:
	var spec := {"hp_pct": ["HP %", 25, 300, 5], "attack": ["to-hit", -5, 8, 1], "defense": ["defense", -5, 8, 1],
		"damage": ["damage", -3, 6, 1], "move": ["move", -3, 3, 1]}
	for key in SandboxSetup.MOD_KEYS:
		var sp: Array = spec[key]
		var s := _dial(parent, sp[0], sp[1], sp[2], sp[3])
		_dials["%s:%s" % [side, key]] = s
		s.value_changed.connect(func(v: float) -> void:
			if _syncing:
				return
			var mods: Dictionary = setup.party_mods if side == "party" else setup.enemy_mods
			mods[key] = int(v)
			_changed())


# --- widgets ------------------------------------------------------------------------

func _panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	return p


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _small_label(text: String, size := 13) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _bar_label(text: String) -> Label:
	var l := _small_label(text, 12)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


func _title(text: String) -> Label:
	var l := _small_label(text, 15)
	l.add_theme_color_override("font_color", Color(1, 0.88, 0.55))
	return l


func _spin(parent: Control, lo: float, hi: float, step: float, v: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = v
	s.allow_greater = false
	parent.add_child(s)
	return s


func _dial(parent: Control, label: String, lo: float, hi: float, step: float) -> SpinBox:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var l := _small_label(label, 12)
	l.custom_minimum_size.x = 130
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(l)
	return _spin(row, lo, hi, step, lo)


func _check(parent: Control, label: String, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = label
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", 12)
	c.toggled.connect(func(on: bool) -> void: if not _syncing: cb.call(on))
	parent.add_child(c)
	return c


## Push the setup's values into every control without firing their change handlers.
func _sync_controls() -> void:
	_syncing = true
	_name_edit.text = setup.map_name
	_w_spin.value = setup.grid.w
	_h_spin.value = setup.grid.h
	_seed_spin.value = setup.seed_value
	for key in SandboxSetup.MOD_KEYS:
		_dials["party:" + key].value = setup.party_mods[key]
		_dials["enemy:" + key].value = setup.enemy_mods[key]
	_extra_spin.value = setup.extra_enemies
	_med_spin.value = setup.supplies.medicine
	_food_spin.value = setup.supplies.food
	_strange_spin.value = setup.strangeness
	_set_menu.select(0)
	for i in _set_menu.item_count:
		if i > 0 and _set_menu.get_item_text(i) == setup.art_set:
			_set_menu.select(i)
	_counter_check.button_pressed = setup.counters
	_mercy_check.button_pressed = setup.mercy
	_dice_check.button_pressed = random_dice
	_syncing = false
	_rebuild_spells()
	_set_brush(brush)


# --- modes ------------------------------------------------------------------------------

func _toggle_mode() -> void:
	if editing:
		_enter_play()
	else:
		_enter_edit()


func _enter_edit() -> void:
	editing = true
	if battle:
		if preview:
			preview.rot = battle.board.rot
		battle.queue_free()
		battle = null
	CombatRules.reset_switches()
	_mode_button.text = "PLAY  (F1)"
	_edit_panel.visible = true
	_play_panel.visible = false
	if preview == null:
		preview = CombatBoard.new()
		preview.backdrop = true
		preview.edit_void = true
		add_child(preview)
		preview.cell_painted.connect(_on_paint)
		preview.cell_hovered.connect(_on_preview_hover)
		preview.rotated.connect(_layout)
		preview.rot = setup.view
	preview.visible = true
	preview.set_process_unhandled_key_input(true)
	_refresh_preview()


func _enter_play() -> void:
	editing = false
	_mode_button.text = "EDIT  (F1)"
	_edit_panel.visible = false
	_play_panel.visible = true
	if preview:
		preview.visible = false
		preview.set_process_unhandled_key_input(false)
	_restart()


func _restart() -> void:
	if editing:
		_enter_play()
		return
	if battle:
		battle.queue_free()
	setup.apply_switches()
	var units := setup.build_units()
	battle = Battle.new()
	add_child(battle)
	var fight_seed := randi() if random_dice else setup.seed_value
	battle.setup(setup.grid.resized(setup.grid.w, setup.grid.h), units, fight_seed, setup.strangeness, setup.supplies.duplicate())
	battle.board.art_set = setup.art_set
	battle.board.show_grid = show_grid
	if preview:
		battle.board.rot = preview.rot
	battle.log_line.connect(_log)
	battle.info.connect(func(t: String) -> void: _info_label.text = t)
	battle.phase_changed.connect(func(team: int) -> void:
		_phase_label.text = Txt.f("UI_ROUND", battle.round_no) + "  " + (Txt.t("UI_PLAYER_PHASE") if team == 0 else Txt.t("UI_ENEMY_PHASE")))
	battle.finished.connect(func(won: bool) -> void:
		_phase_label.text = ("WIN" if won else "LOSE") + "  -  R to restart, F1 to edit")
	_log_label.text = ""
	_log("dice seed %d" % fight_seed)
	_layout()
	battle.start()


func _turn() -> void:
	if battle:
		battle.board.turn()
	elif preview:
		preview.turn()


func _log(line: String) -> void:
	var lines := _log_label.text.split("\n", false)
	lines.append(line)
	_log_label.text = "\n".join(lines.slice(-16))


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.is_echo():
		return
	match event.keycode:
		KEY_F1:
			_toggle_mode()
		KEY_R:
			_restart()


# --- editing ----------------------------------------------------------------------------

func _set_brush(b: String) -> void:
	brush = b
	for k in _brush_buttons:
		_brush_buttons[k].set_pressed_no_signal(k == b)


func _on_paint(c: Vector2i, right: bool) -> void:
	if not editing:
		return
	if right:
		setup.remove_at(c)
	elif BRUSH_TERRAIN.has(brush):
		setup.grid.set_terrain(c, BRUSH_TERRAIN[brush])
		setup.clean()
	elif brush == "ZONE":
		setup.grid.set_zone(c, _zone_pick.get_item_metadata(_zone_pick.selected))
	elif brush == "RAISE" or brush == "LOWER":
		var h := setup.grid.height_at(c) + (1 if brush == "RAISE" else -1)
		setup.grid.set_height(c, clampi(h, 0, CombatGrid.MAX_HEIGHT))
	elif brush == "PARTY":
		if setup.grid.passable(c):
			setup.place_party(_party_pick.get_item_metadata(_party_pick.selected), c)
	elif brush == "ENEMY":
		if setup.grid.passable(c) and setup.entry_at(c).is_empty():
			setup.place_enemy(_enemy_pick.get_item_metadata(_enemy_pick.selected), c)
	elif brush == "ERASE":
		setup.remove_at(c)
	_refresh_preview()


func _on_preview_hover(c: Vector2i) -> void:
	if c == CombatBoard.NONE or not editing:
		return
	var t: int = setup.grid.terrain_at(c)
	var e := setup.entry_at(c)
	var who := ""
	if not e.is_empty():
		who = "   " + String(e[0][e[1]].id)
	_status.text = "(%d,%d) %s H%d%s" % [c.x, c.y, CombatGrid.T.keys()[t], setup.grid.height_at(c), who]


func _refresh_preview() -> void:
	if preview == null:
		return
	preview.grid = setup.grid
	preview.strangeness = setup.strangeness
	preview.art_set = setup.art_set
	preview.show_grid = show_grid
	preview.units = setup.build_units()
	var zone := {}
	for c in setup.grid.deploy_cells(1):
		zone[c] = true
	preview.highlights = {}
	for c in zone:
		if setup.entry_at(c).is_empty():
			preview.highlights[c] = Color(1, 0.4, 0.3, 0.12)
	_rebuild_spells()
	_layout()


## One row per caster in the party: a picker per spell slot. Picks are saved with the map.
func _rebuild_spells() -> void:
	var sig := ""
	for p in setup.party:
		sig += "%s:%s;" % [p.id, ",".join(setup.spells_of(p.id))]
	if sig == _spell_sig:
		return
	_spell_sig = sig
	for c in _spell_box.get_children():
		c.queue_free()
	for p in setup.party:
		var d := Db.character(StringName(p.id))
		if d == null or d.class_def.spell_slots <= 0:
			continue
		_spell_box.add_child(_small_label(Txt.t(d.name_key), 12))
		var picks := setup.spells_of(p.id)
		for slot in d.class_def.spell_slots:
			var row := HBoxContainer.new()
			_spell_box.add_child(row)
			var l := _small_label(Txt.f("UI_SPELL_SLOT", slot + 1), 11)
			l.custom_minimum_size.x = 60
			row.add_child(l)
			var ob := OptionButton.new()
			ob.add_theme_font_size_override("font_size", 12)
			ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ob.add_item(Txt.t("UI_NO_SPELL"))
			ob.set_item_metadata(0, "")
			for id in d.class_def.spell_pool:
				var a := Db.ability(String(id))
				if a == null:
					continue
				ob.add_item(Txt.t(a.name_key))
				ob.set_item_metadata(ob.item_count - 1, String(id))
				if slot < picks.size() and picks[slot] == String(id):
					ob.select(ob.item_count - 1)
			if slot >= picks.size() or picks[slot] == "":
				ob.select(0)
			ob.item_selected.connect(func(i: int) -> void:
				setup.set_spell(String(p.id), slot, ob.get_item_metadata(i))
				_status.text = "spells: " + ", ".join(setup.spells_of(p.id))
				_rebuild_spells.call_deferred()
				_changed())
			row.add_child(ob)
	if _spell_box.get_child_count() == 0:
		_spell_box.add_child(_small_label("no casters placed", 11))


func _changed() -> void:
	if editing:
		_refresh_preview()


func _apply_preset(p: String) -> void:
	setup.apply_preset(p)
	_sync_controls()
	_changed()
	_status.text = "enemy dials: " + p


func _resize() -> void:
	setup.resize(int(_w_spin.value), int(_h_spin.value))
	_enter_edit()


func _generate() -> void:
	var g := CombatGrid.generate(int(_seed_spin.value), int(_w_spin.value), int(_h_spin.value), setup.strangeness)
	setup.grid = g
	setup.clean()
	# Keep the same pieces, moved onto the new deploy zones.
	var spots := g.deploy_cells(0)
	for p in setup.party:
		if not spots.is_empty():
			p.cell = spots.pop_front()
	var es := g.deploy_cells(1)
	for e in setup.enemies:
		if not es.is_empty():
			e.cell = es.pop_front()
	_enter_edit()


# --- files ------------------------------------------------------------------------------

func _save() -> void:
	setup.view = battle.board.rot if battle else (preview.rot if preview else 0)
	setup.map_name = SandboxSetup.safe_name(_name_edit.text)
	_name_edit.text = setup.map_name
	var path := setup.save()
	_status.text = ("saved " + path) if path != "" else "save failed"
	_refresh_load_menu()


func _refresh_load_menu() -> void:
	_load_menu.clear()
	_load_menu.add_item("LOAD MAP...")
	_load_menu.add_item("new default")
	for p in SandboxSetup.list_maps():
		_load_menu.add_item(p.get_file().get_basename())
		_load_menu.set_item_metadata(_load_menu.item_count - 1, p)
	_load_menu.select(0)


func _on_load_selected(i: int) -> void:
	if i == 0:
		return
	var s: SandboxSetup = SandboxSetup.default_setup() if i == 1 else SandboxSetup.load_file(_load_menu.get_item_metadata(i))
	_load_menu.select(0)
	if s == null:
		_status.text = "could not read that map"
		return
	setup = s
	if preview:
		preview.rot = setup.view
	_sync_controls()
	_status.text = "loaded " + setup.map_name
	_enter_edit()


# --- balance sim ----------------------------------------------------------------------

func _run_sim() -> void:
	if _sim_running:
		return
	_sim_running = true
	var n := int(_fights_spin.value)
	var t := {}
	var started := Time.get_ticks_msec()
	for i in n:
		SandboxSetup.tally(t, setup.simulate(setup.seed_value * 1000 + i))
		if i % 2 == 1:
			_sim_label.text = "running %d / %d ..." % [i + 1, n]
			await get_tree().process_frame
	var secs := (Time.get_ticks_msec() - started) / 1000.0
	_sim_label.text = SandboxSetup.describe_tally(t) + "\n(%d fights, %.1fs)" % [n, secs]
	if editing:
		CombatRules.reset_switches()
	else:
		setup.apply_switches()
	_sim_running = false

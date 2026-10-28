class_name LaunchMenu
extends Control
## The launch screen (the game's main scene): one button per place we've built, so Play opens on a
## fast-travel menu instead of a developer shortcut. Start game = the hero's cottage, the first walk.
## F8 returns here from anywhere. Button labels are developer labels, not player text.

const BUTTON_SIZE := Vector2(250, 58)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = RisoTheme.make()
	resized.connect(queue_redraw)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 40)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var title := Label.new()
	title.text = "LODESTONE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	column.add_child(title)

	var sections := HBoxContainer.new()
	sections.alignment = BoxContainer.ALIGNMENT_CENTER
	sections.add_theme_constant_override("separation", 22)
	column.add_child(sections)
	var card := PanelContainer.new()
	card.add_child(_sections_row())
	sections.add_child(card)

	var hint := Label.new()
	hint.text = "F8 back here   F9 combat sandbox   F10 explore   F6 runs the open scene"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	column.add_child(hint)


## Three columns of places: where the party starts, the walkable maps, and the fights.
func _sections_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	var sections := [
		["PLAY", [
			["Start game", "hero's cottage, the first walk", _start_game],
			["Village hub", "team, shop, pack, the gate", _go.bind(Game.VILLAGE)],
			["Trail", "the route, the current party", _trail],
			["World map", "the route and what's unearthed", _go.bind(Game.WORLD_MAP)],
		]],
		["EXPLORE", [
			["Hero's cottage", "home (the start)", _explore.bind("home")],
			["Village square", "the open village map", _explore.bind("village")],
			["House NE", "the quiet house, hidden book", _explore.bind("house_ne")],
			["Tavern", "walk-in interior", _explore.bind("tavern")],
			["Crypt", "the big test map, wolves and bandits", _explore.bind("crypt")],
		]],
		["FIGHT", [
			["Trail fight", "debug encounter", _trail_fight],
			["Combat sandbox", "map painter and AI balance", _go.bind(Game.SANDBOX)],
		]],
	]
	for section: Array in sections:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 8)
		var header := Label.new()
		header.text = section[0]
		header.add_theme_font_size_override("font_size", 18)
		column.add_child(header)
		for item: Array in section[1]:
			column.add_child(_button(item[0], item[1], item[2]))
		row.add_child(column)
	return row


func _button(label: String, desc: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = "%s\n%s" % [label, desc]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = BUTTON_SIZE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(cb)
	return b


## A new game: the cottage, with no walk remembered yet.
func _start_game() -> void:
	Game.explore_memory = {}
	_explore("home")


func _explore(map_name: String) -> void:
	Game.explore_map = map_name
	Game.explore_entry = Vector2i(-1, -1)
	Game.go(Game.EXPLORE)


func _trail() -> void:
	Game.ensure_run()
	Game.go(Game.TRAIL)


func _trail_fight() -> void:
	Game.ensure_run()
	Game.go(Game.COMBAT)


func _go(path: String) -> void:
	Game.go(path)


func _draw() -> void:
	var p := Riso.palette_at(0.0)
	var r := Rect2(Vector2.ZERO, size)
	Riso.draw_sky(self, r, p.sky_top, p.horizon)
	var ground_top := size.y * 0.8
	draw_rect(Rect2(0, ground_top, size.x, size.y - ground_top), p.ground)
	var x := 30.0
	var i := 0
	while x < size.x:
		var h := 70.0 + 30.0 * float(i % 3)
		Riso.draw_pine(self, x, ground_top + 6.0, h, p.near, p.light)
		x += 120.0
		i += 1

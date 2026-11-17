extends Control
## Hunting prototypes on their own (Dev Tools > Hunting): pick A, B, C or D, with toggles for the Hunter and Doggo
## in the party so their hooks can be felt. Practice only: nothing goes in the pack and no save changes.
## Esc in a hunt comes back here; Esc here goes back to Dev Tools.

const GAMES := {
	"bow": preload("res://scripts/hunting/bow_blind.gd"),
	"stalk": preload("res://scripts/hunting/stalk.gd"),
	"snare": preload("res://scripts/hunting/snare_line.gd"),
	"drive": preload("res://scripts/hunting/corgi_drive.gd"),
}
const CARDS := [["bow", "HUNT_A"], ["stalk", "HUNT_B"], ["snare", "HUNT_C"], ["drive", "HUNT_D"]]

var hunter := false
var doggo := true
var game: HuntGame
var _menu: Control
var _seed := 0  ## a fixed seed for screenshots (0: random)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = RisoTheme.make()
	resized.connect(queue_redraw)
	_build_menu()


func _build_menu() -> void:
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 16)
	add_child(_menu)
	var title := Label.new()
	title.text = Txt.t("HUNT_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	_menu.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu.add_child(row)
	for c: Array in CARDS:
		var b := Button.new()
		b.text = "%s\n%s" % [Txt.t(String(c[1])), Txt.t(String(c[1]) + "_SUB")]
		b.custom_minimum_size = Vector2(230, 110)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(play.bind(String(c[0])))
		row.add_child(b)
	var toggles := HBoxContainer.new()
	toggles.alignment = BoxContainer.ALIGNMENT_CENTER
	toggles.add_theme_constant_override("separation", 30)
	_menu.add_child(toggles)
	for pair: Array in [["HUNT_WITH_HUNTER", "hunter"], ["HUNT_WITH_DOGGO", "doggo"]]:
		var cb := CheckButton.new()
		cb.text = Txt.t(String(pair[0]))
		cb.button_pressed = bool(get(String(pair[1])))
		var prop := String(pair[1])
		cb.toggled.connect(func(on: bool) -> void: set(prop, on))
		toggles.add_child(cb)
	var back := Button.new()
	back.text = Txt.t("HUNT_BACK")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size = Vector2(200, 40)
	back.pressed.connect(_leave)
	_menu.add_child(back)
	_place_menu.call_deferred()
	resized.connect(_place_menu)


func _place_menu() -> void:
	if _menu == null:
		return
	var need := _menu.get_combined_minimum_size()
	_menu.size = need
	_menu.position = ((size - need) * 0.5).floor()


func _leave() -> void:
	Game.go(Game.menu_scene())


func play(mode: String, seed_value := 0) -> void:
	if game != null:
		game.queue_free()
	_menu.visible = false
	game = GAMES[mode].new()
	game.mods = HuntRules.mods_for(hunter, doggo)
	var s := seed_value if seed_value != 0 else _seed
	if s != 0:
		game.rng.seed = s
	game.finished.connect(_on_finished)
	add_child(game)


func _on_finished(res: Dictionary) -> void:
	var mode := String(res.mode)
	if String(res.next) == "again":
		play.call_deferred(mode)
	else:
		game.queue_free()
		game = null
		_menu.visible = true


func _unhandled_key_input(event: InputEvent) -> void:
	if game == null and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		_leave()


func _draw() -> void:
	var p := Riso.palette_at(0.0)
	Riso.draw_sky(self, Rect2(Vector2.ZERO, size), p.sky_top, p.horizon)
	draw_rect(Rect2(0, size.y * 0.72, size.x, size.y * 0.28), p.ground)

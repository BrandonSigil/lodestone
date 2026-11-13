class_name HintToast
extends PanelContainer
## A one-time hint (GoalRules.HINTS): a small dialog-styled box at the top of the play area with the keys in it, which
## fades on its own after a few seconds or when clicked. Game.hint(id, parent, area) shows each one once ever.

const STAY := 7.0  ## seconds before it fades
const WIDTH := 680.0

var _area: Callable  ## () -> Rect2: the play area it sits at the top of
var _t := 0.0


static func open(parent: Node, text: String, area: Callable) -> HintToast:
	var h := HintToast.new()
	h._area = area
	h.theme_type_variation = &"DialogPanel"
	h.mouse_filter = Control.MOUSE_FILTER_STOP
	h.z_index = 50
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 17)
	var font := l.get_theme_font("font")  # as wide as the words need, up to WIDTH; longer hints wrap
	var need := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 8.0 if font else WIDTH
	l.custom_minimum_size.x = clampf(need, 240.0, WIDTH - 40.0)
	l.add_theme_color_override("font_color", MenuKit.TEXT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	parent.add_child(h)
	h.set_meta("quiet", true)
	h.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			h._t = STAY)
	h._place.call_deferred()
	UiTheme.pop_in(h)
	var sfx := h.get_node_or_null("/root/Sfx")
	if sfx:
		sfx.call("play", "hint")
	return h


func _place() -> void:
	reset_size()
	var r: Rect2 = _area.call() if _area.is_valid() else get_viewport_rect()
	position = Vector2(r.position.x + (r.size.x - size.x) * 0.5, r.position.y + 18.0).floor()


func _process(delta: float) -> void:
	_t += delta
	if _t >= STAY:
		modulate.a = maxf(0.0, modulate.a - delta * 2.5)
		if modulate.a <= 0.0:
			queue_free()

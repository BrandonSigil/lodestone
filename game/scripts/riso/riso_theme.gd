class_name RisoTheme
extends RefCounted
## Control theme for riso screens: paper panels with ink keylines (style bible section 3),
## gold buttons from frame A, Young Serif as the stand-in face.


static func _box(bg: Color, border: Color, width := 2, pad := 8.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.content_margin_left = pad + 4
	sb.content_margin_right = pad + 4
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb


static func make() -> Theme:
	var t := Theme.new()
	t.default_font = Riso.font()
	t.default_font_size = 16
	t.set_stylebox("normal", "Button", _box(Riso.GOLD, Riso.INK, 2, 5.0))
	t.set_stylebox("hover", "Button", _box(Riso.mix(Riso.GOLD, Riso.PAPER, 0.45), Riso.INK, 2, 5.0))
	t.set_stylebox("pressed", "Button", _box(Riso.mix(Riso.GOLD, Riso.RED, 0.35), Riso.INK, 2, 5.0))
	t.set_stylebox("hover_pressed", "Button", _box(Riso.mix(Riso.GOLD, Riso.RED, 0.45), Riso.INK, 2, 5.0))
	t.set_stylebox("disabled", "Button", _box(Riso.mix(Riso.GOLD, Riso.PAPER, 0.7), Riso.mix(Riso.INK, Riso.PAPER, 0.5), 2, 5.0))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(state, "Button", Riso.INK)
	t.set_color("font_disabled_color", "Button", Riso.mix(Riso.INK, Riso.PAPER, 0.5))
	t.set_color("font_color", "Label", Riso.INK)
	t.set_stylebox("panel", "PanelContainer", _box(Riso.PAPER, Riso.INK, 2, 14.0))
	return t


## A small paper card, for roster cards and shop rows.
static func card(selected := false, locked := false) -> StyleBoxFlat:
	var bg := Riso.mix(Riso.PAPER, Riso.GOLD, 0.35) if selected else Riso.PAPER
	if locked:
		bg = Riso.mix(Riso.PAPER, Riso.BASE, 0.12)
	var sb := _box(bg, Riso.INK if selected else Riso.GOLD_DARK, 3 if selected else 2, 6.0)
	return sb

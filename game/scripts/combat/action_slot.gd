class_name ActionSlot
extends Button
## One fight action as a box in the dock (ActionHud): the art runner's icon when there is one (ActionInfo.icon_for),
## else a graybox tile coloured by what it does with a short glyph. Greyed when it can't be used, with a sweep for a
## charge on its way back. `entry` is Battle's: {text, enabled, cb, ability, kind, key}.

## The art runner's spare icons for the plain boxes (2026-10-30, approved with the sheet).
const BASIC_ICONS := {"move": "dash", "guard": "guard", "wait": "focus", "undo": "counter", "talk": "rally"}

var entry: Dictionary = {}
var unit: CombatUnit
var open := false  ## TRICKS or STUFF whose row is open: drawn lit


static func tint(e: Dictionary) -> Color:
	var a: Ability = e.get("ability")
	match String(e.kind):
		"move":
			return Color(0.3, 0.5, 0.85)
		"guard":
			return Color(0.45, 0.55, 0.65)
		"wait", "undo":
			return Color(0.4, 0.4, 0.42)
		"talk":
			return Color(0.25, 0.6, 0.55)
		"item":
			return Color(0.6, 0.45, 0.28)
		"group":
			return Color(0.45, 0.35, 0.6)
		"back":
			return Color(0.35, 0.35, 0.38)
	if a == null:
		return Color(0.5, 0.5, 0.5)
	match a.element:
		"fire":
			return Color(0.9, 0.42, 0.18)
		"moon":
			return Color(0.55, 0.62, 0.95)
		"frost":
			return Color(0.4, 0.8, 0.9)
	match a.kind:
		"heal", "revive":
			return Color(0.35, 0.7, 0.35)
		"buff":
			return Color(0.85, 0.7, 0.25)
		"hex":
			return Color(0.6, 0.35, 0.7)
	return Color(0.7, 0.28, 0.25)


## A short glyph for the graybox tile: the first letters of the action's caveman name.
static func glyph(e: Dictionary) -> String:
	var words := String(e.text).strip_edges().split(" ", false)
	if words.is_empty():
		return "?"
	return words[0].substr(0, 2) if words.size() == 1 else words[0].substr(0, 1) + words[1].substr(0, 1)


## Draws the icon for entry e into rect r on canvas item ci.
static func paint(ci: CanvasItem, r: Rect2, e: Dictionary, u: CombatUnit, hot: bool) -> void:
	var a: Ability = e.get("ability")
	var tex := ActionInfo.icon_for(a) if a != null else ActionInfo.icon(String(e.get("icon", BASIC_ICONS.get(String(e.kind), ""))))
	if tex != null:
		ci.draw_rect(r, Color(0.13, 0.13, 0.15))  # a backing, so the icon's clear edges read on any board
		ci.draw_texture_rect(tex, r.grow(-2), false)
	else:
		var col := tint(e)
		ci.draw_rect(r, col.darkened(0.35))
		ci.draw_rect(r.grow(-3), col)
		ci.draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, r.size.y * 0.35)), Color(1, 1, 1, 0.12))
		var font := ThemeDB.fallback_font
		var fs := int(r.size.y * 0.36)
		ci.draw_string_outline(font, Vector2(r.position.x, r.get_center().y + fs * 0.36), glyph(e), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, 4, Color(0, 0, 0, 0.7))
		ci.draw_string(font, Vector2(r.position.x, r.get_center().y + fs * 0.36), glyph(e), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color(1, 1, 1))
	ci.draw_rect(r, Color(1, 0.9, 0.6) if hot else Color(0, 0, 0, 0.8), false, 2.0)
	if not bool(e.enabled):
		ci.draw_rect(r, Color(0, 0, 0, 0.55))
		var sweep := ActionInfo.recharge(u, a) if a != null and u != null else 0.0
		if sweep > 0.0:  # a charge on its way back: the WoW clock sweep
			var pts := PackedVector2Array([r.get_center()])
			var steps := 24
			for i in steps + 1:
				var t := -PI / 2.0 + TAU * sweep * float(i) / steps
				pts.append(r.get_center() + Vector2(cos(t), sin(t)) * r.size.length() * 0.5)
			ci.draw_colored_polygon(pts, Color(0, 0, 0, 0.35))
	if int(e.get("key", -1)) >= 0:
		var font := ThemeDB.fallback_font
		var k := str((int(e.key) + 1) % 10)
		ci.draw_string_outline(font, r.position + Vector2(4, 13), k, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0, 0, 0, 0.9))
		ci.draw_string(font, r.position + Vector2(4, 13), k, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.95, 0.7))
	if int(e.get("count", 0)) > 0:
		var font := ThemeDB.fallback_font
		var c := "x%d" % int(e.count)
		ci.draw_string_outline(font, Vector2(r.position.x, r.end.y - 4), c, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 4, 12, 3, Color(0, 0, 0, 0.9))
		ci.draw_string(font, Vector2(r.position.x, r.end.y - 4), c, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 4, 12, Color(1, 1, 1))


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _draw() -> void:
	paint(self, Rect2(Vector2.ZERO, size), entry, unit, is_hovered() or has_focus() or open)

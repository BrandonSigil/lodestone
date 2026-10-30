class_name ActionSlot
extends Button
## One fight action as an icon (the action bar, the ring) or a card (the hand): the art runner's icon when there is
## one (ActionInfo.icon), else a graybox tile coloured by what it does with a short glyph. Greyed when it can't be
## used, with a sweep for a charge on its way back. `entry` is Battle's: {text, enabled, cb, ability, kind, key}.

var entry: Dictionary = {}
var unit: CombatUnit
var card := false  ## draw as a card from the hand: frame, icon, name, cost and the caveman line
var lift := 0.0  ## the card rises this much while hovered


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
	var tex := ActionInfo.icon_for(a) if a != null else null
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
	var hot := is_hovered() or has_focus()
	if not card:
		paint(self, Rect2(Vector2.ZERO, size), entry, unit, hot)
		return
	# A card: parchment frame, the icon on top, then the name, the cost and the caveman line.
	var r := Rect2(Vector2(0, -lift), size)
	draw_rect(r, Color(0.16, 0.13, 0.1))
	draw_rect(r.grow(-3), Color(0.86, 0.8, 0.66) if bool(entry.enabled) else Color(0.55, 0.52, 0.47))
	draw_rect(r.grow(-3), ActionSlot.tint(entry).darkened(0.2), false, 3.0)
	var ir := Rect2(r.position + Vector2(12, 12), Vector2(r.size.x - 24, r.size.x - 24))
	paint(self, ir, entry, unit, hot)
	var font := ThemeDB.fallback_font
	var y := ir.end.y + 18
	draw_string(font, Vector2(r.position.x + 6, y), String(entry.text), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 12, 13, Color(0.12, 0.08, 0.05))
	var a: Ability = entry.get("ability")
	if a != null and unit != null:
		var cost := Txt.t("TIP_FREE")
		if a.is_item():
			cost = "x%d" % int(entry.get("count", 0))
		elif a.res_cost > 0 and unit.res_kind != "":
			cost = "%d %s" % [a.res_cost, Txt.t("RES_" + unit.res_kind.to_upper())]
		draw_string(font, Vector2(r.position.x + 6, y + 16), cost, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 12, 11, Color(0.3, 0.2, 0.1))
		var desc := "DESC_" + a.id.to_upper()
		if Txt.has(desc):
			draw_multiline_string(font, Vector2(r.position.x + 8, y + 32), Txt.t(desc), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 16, 10, 4, Color(0.25, 0.18, 0.1))
	if not bool(entry.enabled):
		draw_rect(r, Color(0, 0, 0, 0.35))

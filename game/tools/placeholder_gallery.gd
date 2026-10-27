extends Node2D
## Draws every placeholder figure: each party colour, each enemy glyph, every weapon, every anim.
## placeholder_shot.gd saves it to a PNG so the placeholder can be checked by eye.

const ANIM_NAMES := ["idle", "walk", "attack", "cast", "hurt", "down"]
var ROWS := [
	{"label": "party", "id": &"lead", "team": 0},
	{"label": "party", "id": &"stardrop", "team": 0},
	{"label": "party", "id": &"hunter", "team": 0},
	{"label": "party", "id": &"wizard", "team": 0},
	{"label": "party", "id": &"lewith_flark", "team": 0},
	{"label": "party", "id": &"bushberry", "team": 0},
	{"label": "enemy", "id": &"bandit", "team": 1},
	{"label": "enemy", "id": &"bandit_archer", "team": 1},
	{"label": "enemy", "id": &"wolf", "team": 1},
	{"label": "enemy", "id": &"strange_thing", "team": 1},
	{"label": "weapon", "spec": {"body": Color(0.35, 0.72, 0.4), "weapon": "axe", "glyph": ""}},
	{"label": "weapon", "spec": {"body": Color(0.35, 0.72, 0.4), "weapon": "spear", "glyph": ""}},
]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(900, 80 + ROWS.size() * 90)), Color(0.16, 0.2, 0.18))
	var font := ThemeDB.fallback_font
	for j in ANIM_NAMES.size():
		draw_string(font, Vector2(150 + j * 120, 40), ANIM_NAMES[j], HORIZONTAL_ALIGNMENT_CENTER, 110, 16,
			Color(0.95, 0.95, 0.9))
	for i in ROWS.size():
		var r: Dictionary = ROWS[i]
		var y := 90.0 + i * 90.0
		var name := String(r.get("id", r.get("label")))
		if r.has("spec"):
			name = String(r.spec.weapon)
		draw_string(font, Vector2(14, y + 4), name, HORIZONTAL_ALIGNMENT_LEFT, 130, 13,
			Color(0.85, 0.9, 0.85))
		for j in ANIM_NAMES.size():
			var anim: String = ANIM_NAMES[j]
			var base := Vector2(150 + j * 120 + 55, y + 40)
			var t := 0.3 if anim != "attack" else 0.2
			if anim == "cast":
				t = 0.35
			if r.has("spec"):
				PlaceholderFigure.draw_spec(self, base, 26.0, r.spec, anim, t, false, Color(0, 0, 0, 0))
			else:
				PlaceholderFigure.draw(self, base, 26.0, r.id, r.team, anim, t, false, Color(0, 0, 0, 0))

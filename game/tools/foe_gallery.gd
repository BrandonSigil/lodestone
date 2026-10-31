extends Node2D
## Every placeholder foe (data/foe_looks.csv) in its four combat facings, then attack, hurt and down.
## foe_shot.gd saves it to a PNG so the foes can be checked by eye.

const COLS := [["SW", Vector2(-1, 0.5), "idle"], ["SE", Vector2(1, 0.5), "idle"], ["NW", Vector2(-1, -0.5), "idle"],
	["NE", Vector2(1, -0.5), "idle"], ["walk", Vector2(1, 0.5), "walk"], ["attack", Vector2(1, 0.5), "attack"],
	["hurt", Vector2(1, 0.5), "hurt"], ["down", Vector2(1, 0.5), "down"]]
const CW := 118.0
var PER_ROW := 2  # foes side by side
var only: Array = []  # foe ids to show (empty = all)


func _draw() -> void:
	var ids := FoeFigure.ids()
	if not only.is_empty():
		ids = ids.filter(func(i: StringName) -> bool: return only.has(String(i)))
	var rows := ceili(ids.size() / float(PER_ROW))
	var size := Vector2(60 + PER_ROW * (COLS.size() * CW + 170), 70 + rows * 120)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.9, 0.88, 0.8))
	var font := ThemeDB.fallback_font
	for k in PER_ROW:
		var x0 := 120.0 + k * (COLS.size() * CW + 170)
		for j in COLS.size():
			draw_string(font, Vector2(x0 + j * CW, 34), COLS[j][0], HORIZONTAL_ALIGNMENT_CENTER, CW, 15,
				Color(0.22, 0.2, 0.2))
	for i in ids.size():
		var id: StringName = ids[i]
		var x0 := 120.0 + (i % PER_ROW) * (COLS.size() * CW + 170)
		var y := 150.0 + (i / PER_ROW) * 120.0
		draw_string(font, Vector2(x0 - 112, y - 30), String(id), HORIZONTAL_ALIGNMENT_LEFT, 110, 13,
			Color(0.22, 0.2, 0.2))
		draw_string(font, Vector2(x0 - 112, y - 14), _name(id),
			HORIZONTAL_ALIGNMENT_LEFT, 110, 11, Color(0.45, 0.3, 0.28))
		for j in COLS.size():
			var anim: String = COLS[j][2]
			var t := 0.3
			if anim == "attack":
				t = 0.2
			elif anim == "down":
				t = 0.6
			elif anim == "hurt":
				t = 0.05
			FoeFigure.draw(self, Vector2(x0 + j * CW + CW * 0.5, y), id, COLS[j][1], anim, t, Color(1.0, 0.4, 0.35))


func _name(id: StringName) -> String:
	var path := "res://data/classes/%s.tres" % id
	return Txt.t(Db.class_def(String(id)).name_key) if ResourceLoader.exists(path) else ""

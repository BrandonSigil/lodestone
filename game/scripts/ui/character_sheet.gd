class_name CharacterSheet
extends Control
## A character sheet ([USER] 2026-10-30, Fire Emblem-style layout, docs/art/references/character-sheet-layout.webp)
## in the leaf frame's look: deep green, double rules, blue diamonds, parchment. A close-up portrait down the
## left with the name over it and the base stats under it; job, LV, EXP and move top right; big HP; damage,
## crit, armor and range; the weapon; four move rows. One or more pages (SheetRules.build): the smithy rack
## flips through one per build with ◀ ▶ and TAKE; the dog's is a single page with CLOSE.
## The portrait is its own slot: res://art/source/portraits/<id>.png when it exists, else a crop of the
## character's sprite (or the code figure), with the weapon drawn in code on the rack's pages.

signal taken(index: int)  ## TAKE on page index
signal closed

const SIZE := Vector2(720, 430)
const GREEN := Color(0.11, 0.2, 0.18)  ## the frame's deep green
const GREEN_LIGHT := Color(0.2, 0.31, 0.28)
const PARCHMENT := Color(0.93, 0.88, 0.74)
const PARCHMENT_DARK := Color(0.84, 0.77, 0.6)
const INK := Color(0.2, 0.18, 0.16)
const RULE := Color(0.93, 0.88, 0.74, 0.9)
const DIAMOND := Color(0.45, 0.68, 0.95)
const PORTRAIT_DIR := "res://art/source/portraits/"
const PORTRAIT := Rect2(24, 64, 200, 210)  ## the portrait slot, inside the sheet
const SPLIT := 244.0  ## where the right column starts

var pages: Array = []  ## SheetRules.build dictionaries
var page := 0
var takes: Array = []  ## per page: "take", "held" (in hand) or "locked"; empty: no TAKE (the dog's sheet)
var _time := 0.0
var _font: Font
var _prev: Button
var _next: Button
var _take: Button


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = load("res://fonts/YoungSerif-Regular.ttf") as Font
	_prev = _button("◀", Rect2(SIZE.x - 236, SIZE.y - 48, 40, 34), func() -> void: flip(-1))
	_next = _button("▶", Rect2(SIZE.x - 192, SIZE.y - 48, 40, 34), func() -> void: flip(1))
	_take = _button(Txt.t("UI_SHEET_TAKE"), Rect2(SIZE.x - 148, SIZE.y - 48, 124, 34), func() -> void: taken.emit(page))
	_button(Txt.t("UI_SHEET_CLOSE"), Rect2(24, SIZE.y - 48, 110, 34), func() -> void: closed.emit())


## Show these pages from `at`; with `take_states`, the rack's TAKE button per page.
func show_pages(sheets: Array, at := 0, take_states: Array = []) -> void:
	pages = sheets
	takes = take_states
	page = clampi(at, 0, maxi(0, pages.size() - 1))
	_refresh()


func flip(d: int) -> void:
	if pages.size() > 1:
		page = posmod(page + d, pages.size())
		_refresh()


func _refresh() -> void:
	_prev.visible = pages.size() > 1
	_next.visible = pages.size() > 1
	_take.visible = not takes.is_empty()
	if not takes.is_empty():
		var st := String(takes[page])
		_take.disabled = st != "take"
		_take.text = Txt.t({"take": "UI_SHEET_TAKE", "held": "UI_SHEET_IN_HAND"}.get(st, "UI_SHEET_LOCKED"))
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.pressed or event.is_echo():
		return
	match event.keycode:
		KEY_LEFT, KEY_A:
			flip(-1)
		KEY_RIGHT, KEY_D:
			flip(1)
		KEY_ESCAPE:
			closed.emit()
		_:
			return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()  # the portrait breathes (its idle loop)


func _button(text: String, r: Rect2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = r.position
	b.size = r.size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 15)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": GREEN_LIGHT, "hover": GREEN_LIGHT.lightened(0.15), "pressed": GREEN, "disabled": GREEN.darkened(0.2)}[st]
		sb.border_color = RULE
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", PARCHMENT)
	b.add_theme_color_override("font_disabled_color", PARCHMENT.darkened(0.35))
	b.pressed.connect(cb)
	add_child(b)
	return b


# --- drawing --------------------------------------------------------------------------------------------

func _draw() -> void:
	if pages.is_empty():
		return
	var s: Dictionary = pages[page]
	# The frame: deep green, a double parchment rule, blue diamonds at the corners.
	draw_rect(Rect2(Vector2.ZERO, SIZE), GREEN)
	draw_rect(Rect2(Vector2(6, 6), SIZE - Vector2(12, 12)), RULE, false, 2.0)
	draw_rect(Rect2(Vector2(11, 11), SIZE - Vector2(22, 22)), RULE, false, 1.0)
	for c in [Vector2(8, 8), Vector2(SIZE.x - 8, 8), Vector2(8, SIZE.y - 8), SIZE - Vector2(8, 8)]:
		_diamond(c, 7.0)
	# Left: the name plate, the portrait, the stats.
	_plate(Rect2(24, 22, 200, 34), GREEN_LIGHT)
	_text(Txt.t(s.name), Vector2(124, 46), 20, PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER, 196)
	_portrait(s)
	var stats: Array = s.stats
	for i in stats.size():
		var col := i % 2
		var row := i / 2
		var r := Rect2(24 + col * 102, PORTRAIT.end.y + 8 + row * 26, 98, 22)
		_plate(r, PARCHMENT)
		_text(Txt.t(String(stats[i].key)), r.position + Vector2(6, 16), 12, INK)
		_text(str(stats[i].value), r.position + Vector2(r.size.x - 8, 16), 13, INK, HORIZONTAL_ALIGNMENT_RIGHT, 0)
	# Right: job and level, HP, the numbers, the weapon, the moves.
	var x := SPLIT
	var w := SIZE.x - SPLIT - 24
	_plate(Rect2(x, 22, w - 112, 34), PARCHMENT)
	_text(Txt.t(s.job) if s.job != "" else "", Vector2(x + 12, 46), 19, INK)
	_plate(Rect2(x + w - 104, 22, 104, 34), PARCHMENT)
	_text(Txt.t("UI_SHEET_LV"), Vector2(x + w - 96, 46), 15, INK)
	_text(str(s.level), Vector2(x + w - 10, 46), 19, INK, HORIZONTAL_ALIGNMENT_RIGHT, 0)
	_plate(Rect2(x, 64, w - 112, 64), PARCHMENT_DARK)
	_text(Txt.t("UI_SHEET_HP"), Vector2(x + 14, 104), 18, INK)
	_text(str(s.hp), Vector2(x + 150, 112), 40, INK, HORIZONTAL_ALIGNMENT_RIGHT, 0)
	_text("/ %d" % s.max_hp, Vector2(x + 158, 110), 22, INK)
	_plate(Rect2(x + w - 104, 64, 104, 30), PARCHMENT)
	_text(Txt.t("UI_SHEET_EXP"), Vector2(x + w - 96, 85), 13, INK)
	_text("%d/%d" % [s.xp, s.xp_next], Vector2(x + w - 10, 85), 13, INK, HORIZONTAL_ALIGNMENT_RIGHT, 0)
	_plate(Rect2(x + w - 104, 98, 104, 30), PARCHMENT)
	_text(Txt.t("UI_SHEET_MOVE"), Vector2(x + w - 96, 119), 13, INK)
	_text(str(s.move), Vector2(x + w - 10, 119), 15, INK, HORIZONTAL_ALIGNMENT_RIGHT, 0)
	var rng: Vector2i = s.range
	var nums := [["UI_SHEET_ATK", str(s.damage)], ["UI_SHEET_CRIT", "%d%%" % s.crit],
		["UI_SHEET_ARMOR", str(s.armor)], ["UI_SHEET_RANGE", str(rng.y) if rng.x == rng.y else "%d-%d" % [rng.x, rng.y]]]
	for i in nums.size():
		var r := Rect2(x + (i % 2) * (w * 0.5 + 2), 136 + (i / 2) * 30, w * 0.5 - 2, 26)
		_plate(r, PARCHMENT)
		_text(Txt.t(nums[i][0]), r.position + Vector2(10, 19), 14, INK)
		_text(nums[i][1], r.position + Vector2(r.size.x - 10, 19), 15, INK, HORIZONTAL_ALIGNMENT_RIGHT, 0)
	var wr := Rect2(x, 202, w, 28)
	_plate(wr, PARCHMENT_DARK)
	_diamond(wr.position + Vector2(14, 14), 6.0)
	var wid := String(s.get("weapon_id", ""))  # "" for those who never carry one (the dog), "none" bare hands
	_text(Txt.t(s.weapon) if s.weapon != "" else (Txt.t("UI_SHEET_NO_WEAPON") if wid != "" else ""), wr.position + Vector2(28, 20), 15, INK)
	if s.res_kind != "":
		_text("%s %d" % [Txt.t("RES_" + String(s.res_kind).to_upper()), s.res_max], wr.position + Vector2(w - 10, 20), 13, INK, HORIZONTAL_ALIGNMENT_RIGHT, 0)
	var moves: Array = s.moves
	for i in SheetRules.MOVES:
		var r := Rect2(x, 236 + i * 34, w, 30)
		_plate(r, PARCHMENT)
		if i >= moves.size():
			continue
		var m: Dictionary = moves[i]
		_text(Txt.t(m.name), r.position + Vector2(10, 20), 15, INK)
		_text(Txt.t(m.desc) if Txt.has(m.desc) else "", r.position + Vector2(150, 20), 11, INK.lightened(0.25), HORIZONTAL_ALIGNMENT_LEFT, int(w - 250))
		if int(m.cost) > 0:
			_text(Txt.f("UI_SHEET_COST", int(m.cost)), r.position + Vector2(w - 10, 20), 11, INK, HORIZONTAL_ALIGNMENT_RIGHT, 0)
	if pages.size() > 1:
		_text("%d / %d" % [page + 1, pages.size()], Vector2(SIZE.x - 260, SIZE.y - 26), 13, PARCHMENT, HORIZONTAL_ALIGNMENT_RIGHT, 0)


func _plate(r: Rect2, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = Color(INK, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	draw_style_box(sb, r)


func _diamond(c: Vector2, r: float) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), DIAMOND)


func _text(t: String, at: Vector2, fs: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1) -> void:
	if align == HORIZONTAL_ALIGNMENT_RIGHT:
		var tw := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, at - Vector2(tw, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	elif align == HORIZONTAL_ALIGNMENT_CENTER:
		draw_string(_font, at - Vector2(width * 0.5, 0), t, HORIZONTAL_ALIGNMENT_CENTER, width, fs, col)
	else:
		draw_string(_font, at, t, HORIZONTAL_ALIGNMENT_LEFT, width, fs, col)


## The portrait slot. On the rack's pages, the build's pose when it exists (art/source/characters/<id>/
## <id>_build_<job>.png: the hero holding that weapon); else the portrait (art/source/portraits/<id>.png),
## else a close crop of the sprite's idle or the code figure, with the build's weapon drawn in code.
func _portrait(s: Dictionary) -> void:
	draw_rect(PORTRAIT, GREEN_LIGHT.darkened(0.25))
	var id: StringName = s.portrait
	var wid := String(s.get("weapon_id", ""))
	var job := String(Db.weapons.get(wid, {}).get("job", ""))
	var pose := "res://art/source/characters/%s/%s_build_%s.png" % [id, id, job]
	var path := PORTRAIT_DIR + String(id) + ".png"
	if not takes.is_empty() and job != "" and ResourceLoader.exists(pose):
		_fit(_art(pose), false)
	elif ResourceLoader.exists(path):
		_fit(_art(path), true)
	else:
		var f := CharacterArt.frame(id, "idle", "se", _time) if CharacterArt.has_art(id) else {}  # its own art, not the dummy
		if not f.is_empty():
			var reg: Rect2 = f.region
			var crop := Rect2(reg.position + reg.size * Vector2(0.18, 0.08), reg.size * Vector2(0.64, 0.62))  # head and chest
			draw_texture_rect_region(f.tex, PORTRAIT, crop)
		else:
			PlaceholderFigure.draw(self, PORTRAIT.position + Vector2(PORTRAIT.size.x * 0.5, PORTRAIT.size.y * 0.9), 64.0, id, 0, "idle", _time, false, Color(0, 0, 0, 0))
		if not takes.is_empty():
			_weapon(String(Db.weapons.get(wid, {}).get("look", "")))
	draw_rect(PORTRAIT, RULE, false, 2.0)


static var _arts := {}  ## path -> texture, loaded once


func _art(path: String) -> Texture2D:
	if not _arts.has(path):
		_arts[path] = ImageTexture.create_from_image((load(path) as Texture2D).get_image())
	return _arts[path]


## A picture in the portrait slot without stretching it: cover crops it to fill (a portrait), else it fits
## whole, standing on the slot's floor (a full-length pose).
func _fit(tex: Texture2D, cover: bool) -> void:
	var ts := Vector2(tex.get_size())
	if cover:
		var k := maxf(PORTRAIT.size.x / ts.x, PORTRAIT.size.y / ts.y)
		var src := PORTRAIT.size / k
		draw_texture_rect_region(tex, PORTRAIT, Rect2((ts - src) * Vector2(0.5, 0.0), src))
		return
	var k := minf(PORTRAIT.size.x / ts.x, PORTRAIT.size.y / ts.y) * 0.96
	var sz := ts * k
	draw_texture_rect(tex, Rect2(PORTRAIT.position + Vector2((PORTRAIT.size.x - sz.x) * 0.5, PORTRAIT.size.y - sz.y), sz), false)


## The build's weapon, drawn in code over the portrait's lower right where a build has no pose yet.
func _weapon(look: String) -> void:
	var o := PORTRAIT.end - Vector2(62, 70)
	var steel := Color(0.82, 0.85, 0.9)
	var wood := Color(0.55, 0.38, 0.22)
	match look:
		"sword":
			draw_line(o + Vector2(-10, 50), o + Vector2(36, -36), steel, 7.0, true)
			draw_line(o + Vector2(-20, 34), o + Vector2(6, 52), Color(0.75, 0.6, 0.25), 6.0, true)
			draw_line(o + Vector2(-18, 60), o + Vector2(-8, 48), wood, 6.0, true)
		"daggers":
			for d in [Vector2(-14, 0), Vector2(14, 6)]:
				draw_line(o + d + Vector2(-6, 40), o + d + Vector2(10, 4), steel, 5.0, true)
				draw_line(o + d + Vector2(-10, 48), o + d + Vector2(-4, 38), wood, 5.0, true)
		"bow":
			draw_arc(o + Vector2(-10, 10), 46.0, -1.2, 1.2, 18, wood, 6.0, true)
			draw_line(o + Vector2(-10, 10) + Vector2(cos(-1.2), sin(-1.2)) * 46.0, o + Vector2(-10, 10) + Vector2(cos(1.2), sin(1.2)) * 46.0, PARCHMENT, 1.5, true)
		"book":
			draw_rect(Rect2(o + Vector2(-20, 4), Vector2(48, 58)), Color(0.42, 0.2, 0.32))
			draw_rect(Rect2(o + Vector2(-16, 8), Vector2(40, 50)), Color(0.42, 0.2, 0.32).lightened(0.2), false, 2.0)
			_diamond(o + Vector2(4, 33), 8.0)

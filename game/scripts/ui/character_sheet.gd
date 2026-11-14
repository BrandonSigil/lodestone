class_name CharacterSheet
extends Control
## A character sheet ([USER] 2026-10-30, Fire Emblem-style layout, docs/art/references/character-sheet-layout.webp).
## Menus v3 (Brandon, 2026-11-13: "Yes, sheet next"): one kit window, the same build as the level up window, so the two
## read as one family. The name stands on the title banner and the X (or Esc) closes. Left, a card for the character:
## the portrait, job and level, HP and EXP bars, the trail skills as chips. Right: the fight numbers and the weapon as
## chips, then a row a skill with its whole line (nothing cut off, no empty rows). One or more pages
## (SheetRules.build): the smithy rack flips through one per build with the arrows on the foot (or A / D) and the gold
## TAKE; the dog's is a single page.
## The portrait is its own slot: res://art/source/portraits/<id>.png when it exists, else a crop of the
## character's sprite (or the code figure), with the weapon drawn in code on the rack's pages.

signal taken(index: int)  ## TAKE on page index
signal closed

const PORTRAIT_DIR := "res://art/source/portraits/"
const PORTRAIT_SIZE := Vector2(200, 210)  ## the portrait slot
const RIGHT_W := 480.0  ## the numbers and skills column
const DIM := Color(0.02, 0.05, 0.05, 0.45)  ## the world behind, quieter while the sheet is up

var pages: Array = []  ## SheetRules.build dictionaries
var page := 0
var takes: Array = []  ## per page: "take", "held" (in hand) or "locked"; empty: no TAKE (the dog's sheet)
var area := Callable()  ## the room the window may use (the host's play area); none: the whole screen
var _win: Control


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_fit)
	_build()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), DIM)


## Show these pages from `at`; with `take_states`, the rack's TAKE button per page.
func show_pages(sheets: Array, at := 0, take_states: Array = []) -> void:
	pages = sheets
	takes = take_states
	page = clampi(at, 0, maxi(0, pages.size() - 1))
	_build()


func flip(d: int) -> void:
	if pages.size() > 1:
		page = posmod(page + d, pages.size())
		_build()


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


func _room() -> Rect2:
	return area.call() if area.is_valid() else get_viewport_rect()


func _fit() -> void:
	if is_instance_valid(_win) and is_inside_tree():
		UiTheme.place(_win, _room())


# --- the window -------------------------------------------------------------------------------------------

## The window for the open page. A flip builds it again: the pages differ in every part.
func _build() -> void:
	if not is_inside_tree() or pages.is_empty():
		return
	if is_instance_valid(_win):  # a flip's own button is in it: hidden now, freed after the press
		_win.visible = false
		_win.queue_free()
	var s: Dictionary = pages[page]
	var w := MenuKit.window(Txt.t(s.name), _room, func() -> void: closed.emit())
	_win = w.root
	add_child(_win)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	(w.body as Control).add_child(body)
	_who(body, s)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.custom_minimum_size.x = RIGHT_W
	body.add_child(right)
	_numbers(right, s)
	_skills(right, s)
	_foot(w.foot as HBoxContainer)
	_win.resized.connect(_fit)
	_win.minimum_size_changed.connect(_fit)  # a wrapped line settles shorter once it knows its width: shrink to it
	_fit.call_deferred()


## The character's card: the portrait, the job and level, HP and EXP as bars, the trail skills.
func _who(parent: Control, s: Dictionary) -> void:
	var v := MenuKit.card(parent)
	v.add_theme_constant_override("separation", 8)
	var slot := _Slot.new()
	slot.sheet = s
	slot.rack = not takes.is_empty()
	slot.custom_minimum_size = PORTRAIT_SIZE
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(slot)
	if String(s.job) != "":
		var job := MenuKit.label(Txt.t(s.job), UiSkin.T_LEAD)
		job.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(job)
	var lv := MenuKit.chip("%s %d" % [Txt.t("UI_SHEET_LV"), int(s.level)], "star_guide", VictoryUi.XP_GOLD, "", UiSkin.T_BODY)
	lv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(lv)
	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 2)
	v.add_child(bars)
	MenuKit.bar_row(bars, Txt.t("UI_SHEET_HP"), VictoryUi.HP_RED, float(s.hp) / maxf(1.0, float(s.max_hp)), "%d/%d" % [int(s.hp), int(s.max_hp)], 40)
	MenuKit.bar_row(bars, Txt.t("UI_SHEET_EXP"), VictoryUi.XP_GOLD, float(s.xp) / maxf(1.0, float(s.xp_next)), "%d/%d" % [int(s.xp), int(s.xp_next)], 40)
	var stats: Array = s.stats
	if stats.is_empty():
		return
	var checks := HFlowContainer.new()  # the trail skills: what this one rolls with on the road
	checks.alignment = FlowContainer.ALIGNMENT_CENTER
	checks.add_theme_constant_override("h_separation", 6)
	checks.add_theme_constant_override("v_separation", 6)
	checks.custom_minimum_size.x = PORTRAIT_SIZE.x
	checks.tooltip_text = Txt.t("UI_SHEET_CHECKS_TIP")
	checks.mouse_filter = Control.MOUSE_FILTER_PASS
	for st: Dictionary in stats:
		checks.add_child(MenuKit.chip("%s %d" % [Txt.t(String(st.key)), int(st.value)], "", MenuKit.TEXT, "", UiSkin.T_SMALL))
	v.add_child(checks)


## The fight numbers as chips (the level up window's words and icons), then the weapon and the job's resource.
func _numbers(parent: Control, s: Dictionary) -> void:
	var rng: Vector2i = s.range
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	for n: Array in [["UI_STAT_DAMAGE", str(int(s.damage)), "strength"], ["UI_STAT_ARMOR", str(int(s.armor)), "shield"],
			["UI_STAT_CRIT", "%d%%" % int(s.crit), "focus"], ["UI_SHEET_RANGE", str(rng.y) if rng.x == rng.y else "%d-%d" % [rng.x, rng.y], ""],
			["UI_STAT_MOVE", str(int(s.move)), "@leave"]]:
		var c := MenuKit.chip("%s %s" % [Txt.t(String(n[0])), String(n[1])], String(n[2]), MenuKit.TEXT, "", UiSkin.T_BODY)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(c)
	var held := HBoxContainer.new()
	held.add_theme_constant_override("separation", 6)
	var wid := String(s.get("weapon_id", ""))  # "" for those who never carry one (the dog), "none" bare hands
	if String(s.weapon) != "":
		held.add_child(MenuKit.chip(Txt.t(s.weapon), String(Db.weapons.get(wid, {}).get("icon", "")), MenuKit.GOLD, "", UiSkin.T_BODY))
	elif wid != "":
		held.add_child(MenuKit.chip(Txt.t("UI_SHEET_NO_WEAPON"), "", MenuKit.TEXT_DIM, "", UiSkin.T_BODY))
	if String(s.res_kind) != "":
		held.add_child(MenuKit.chip("%s %d" % [Txt.t("RES_" + String(s.res_kind).to_upper()), int(s.res_max)], "", MenuKit.TEXT, "", UiSkin.T_BODY))
	if held.get_child_count() > 0:
		parent.add_child(held)
	else:
		held.free()


## A row a skill: its icon, its name, what it does in fights as chips (damage, reach, cost), and its whole line under.
func _skills(parent: Control, s: Dictionary) -> void:
	var moves: Array = s.moves
	if moves.is_empty():
		return
	parent.add_child(MenuKit.heading_row(Txt.t("UI_LV_SKILLS"), true))
	for m: Dictionary in moves:
		var card := PanelContainer.new()
		card.theme_type_variation = &"KitCard"
		var sb := card.get_theme_stylebox("panel", "KitCard").duplicate() as StyleBox
		sb.content_margin_top = 6.0
		sb.content_margin_bottom = 7.0
		card.add_theme_stylebox_override("panel", sb)
		parent.add_child(card)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		card.add_child(h)
		var a := Db.ability(String(m.id))
		var tex := ActionInfo.icon_for(a) if a != null else null
		var pic: Control = MenuKit.icon_rect("@dot", 32.0)
		if tex != null:
			var t := TextureRect.new()
			t.texture = tex
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t.custom_minimum_size = Vector2(32, 32)
			pic.free()
			pic = t
		pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(pic)
		var words := VBoxContainer.new()
		words.add_theme_constant_override("separation", 1)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(words)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 6)
		words.add_child(top)
		var nm := MenuKit.label(Txt.t(m.name), UiSkin.T_BODY)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(nm)
		var reach: Vector2i = m.range
		if String(m.kind) == "attack":
			top.add_child(MenuKit.chip("%s %d" % [Txt.t("UI_STAT_DAMAGE"), int(m.power)], "", MenuKit.TEXT, "", UiSkin.T_SMALL))
		if reach.y > 1:
			top.add_child(MenuKit.chip(Txt.f("UI_LV_REACH_OF", [reach.x, reach.y]), "", MenuKit.TEXT, "", UiSkin.T_SMALL))
		if int(m.cost) > 0:
			top.add_child(MenuKit.chip(Txt.f("UI_LV_COST", int(m.cost)), "", MenuKit.GOLD, "", UiSkin.T_SMALL))
		if Txt.has(m.desc):
			var line := MenuKit.label(Txt.t(m.desc), UiSkin.T_SMALL, MenuKit.TEXT_DIM)
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.custom_minimum_size.x = RIGHT_W - 80.0
			words.add_child(line)


## The window's foot. The rack: the arrows and the page count on the left, the gold TAKE on the right.
func _foot(foot: HBoxContainer) -> void:
	if pages.size() > 1:
		for d: int in [-1, 1]:
			if d == 1:
				var count := MenuKit.label("%d / %d" % [page + 1, pages.size()], UiSkin.T_BODY, MenuKit.TEXT_DIM)
				count.custom_minimum_size.x = 52.0
				count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				foot.add_child(count)
			var b := Button.new()
			b.text = "◀" if d < 0 else "▶"
			b.custom_minimum_size = Vector2(44, 44)
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(flip.bind(d))
			foot.add_child(b)
	if takes.is_empty():
		return
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(gap)
	var st := String(takes[page])
	var take := MenuKit.primary(Txt.t({"take": "UI_SHEET_TAKE", "held": "UI_SHEET_IN_HAND"}.get(st, "UI_SHEET_LOCKED")), func() -> void: taken.emit(page))
	take.disabled = st != "take"
	take.tooltip_text = Txt.t("UI_SHEET_LOCKED_TIP") if st == "locked" else ""  # why not, on a hover (2026-11-13 playtest)
	take.focus_mode = Control.FOCUS_NONE
	foot.add_child(take)


# --- the portrait -----------------------------------------------------------------------------------------

static var _arts := {}  ## path -> texture, loaded once


static func _art(path: String) -> Texture2D:
	if not _arts.has(path):
		var img := (load(path) as Texture2D).get_image()
		_arts[path] = ImageTexture.create_from_image(img)
		_grounds[path] = img.get_pixel(0, 0) if img.get_width() > 0 else Color(0, 0, 0, 0)
	return _arts[path]


static var _grounds := {}  ## path -> the picture's own background (its corner), clear when it has none


## A picture's own flat background, so a narrow pose stands on one ground across the whole slot, not on a strip.
static func _ground(path: String) -> Color:
	_art(path)
	var c: Color = _grounds.get(path, Color(0, 0, 0, 0))
	return c if c.a > 0.99 else Color(0, 0, 0, 0)


## The portrait slot. On the rack's pages, the build's pose when it exists (art/source/characters/<id>/
## <id>_build_<job>.png: the hero holding that weapon); else the portrait (art/source/portraits/<id>.png),
## else a close crop of the sprite's idle or the code figure, with the build's weapon drawn in code.
class _Slot extends Control:
	var sheet := {}
	var rack := false  ## a rack page: the build's pose, or its weapon drawn in code
	var _time := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()  # the portrait breathes (its idle loop)

	func _draw() -> void:
		var box := Rect2(Vector2.ZERO, size)
		draw_rect(box, Color(0.0, 0.0, 0.0, 0.3))
		var id: StringName = sheet.portrait
		var wid := String(sheet.get("weapon_id", ""))
		var job := String(Db.weapons.get(wid, {}).get("job", ""))
		var pose := "res://art/source/characters/%s/%s_build_%s.png" % [id, id, job]
		var path := CharacterSheet.PORTRAIT_DIR + String(id) + ".png"
		if rack and job != "" and ResourceLoader.exists(pose):
			draw_rect(box, CharacterSheet._ground(pose))
			_fit(box, CharacterSheet._art(pose), false)
		elif ResourceLoader.exists(path):
			_fit(box, CharacterSheet._art(path), true)
		else:
			var d: CharacterDef = Db.character(id)
			var art_id: StringName = d.sprite_id() if d != null else id
			var f := CharacterArt.frame(art_id, "idle", "se", _time) if CharacterArt.has_art(art_id) else {}  # its own art, not the dummy
			if not f.is_empty():
				var reg: Rect2 = f.region
				var crop := Rect2(reg.position + reg.size * Vector2(0.18, 0.08), reg.size * Vector2(0.64, 0.62))  # head and chest
				draw_texture_rect_region(f.tex, box, crop)
			else:
				PlaceholderFigure.draw(self, Vector2(size.x * 0.5, size.y * 0.9), 64.0, id, 0, "idle", _time, false, Color(0, 0, 0, 0))
			if rack:
				_weapon(box, String(Db.weapons.get(wid, {}).get("look", "")))
		if UiSkin.on():  # the kit's rim: ink, then the gold hairline
			draw_rect(box, Color(UiSkin.INK, 0.9), false, 3.0)
			draw_rect(box.grow(-1.5), Color(UiSkin.HAIR, 0.75), false, 1.0)
		else:
			draw_rect(box, UiTheme.RULE, false, 2.0)

	## A picture in the slot without stretching it: cover crops it to fill (a portrait), else it fits whole, standing
	## on the slot's floor (a full-length pose).
	func _fit(box: Rect2, tex: Texture2D, cover: bool) -> void:
		var ts := Vector2(tex.get_size())
		if cover:
			var k := maxf(box.size.x / ts.x, box.size.y / ts.y)
			var src := box.size / k
			draw_texture_rect_region(tex, box, Rect2((ts - src) * Vector2(0.5, 0.0), src))
			return
		var k := minf(box.size.x / ts.x, box.size.y / ts.y) * 0.96
		var sz := ts * k
		draw_texture_rect(tex, Rect2(box.position + Vector2((box.size.x - sz.x) * 0.5, box.size.y - sz.y), sz), false)

	## The build's weapon, drawn in code over the portrait's lower right where a build has no pose yet.
	func _weapon(box: Rect2, look: String) -> void:
		var o := box.end - Vector2(62, 70)
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
				draw_line(o + Vector2(-10, 10) + Vector2(cos(-1.2), sin(-1.2)) * 46.0, o + Vector2(-10, 10) + Vector2(cos(1.2), sin(1.2)) * 46.0, UiTheme.PARCHMENT, 1.5, true)
			"book":
				draw_rect(Rect2(o + Vector2(-20, 4), Vector2(48, 58)), Color(0.42, 0.2, 0.32))
				draw_rect(Rect2(o + Vector2(-16, 8), Vector2(40, 50)), Color(0.42, 0.2, 0.32).lightened(0.2), false, 2.0)
				UiTheme.diamond(self, o + Vector2(4, 33), 8.0)

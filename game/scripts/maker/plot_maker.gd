extends Control
## The plot maker ([USER] 2026-11-01, battle-maps plan: "clean up the UI to make Plots"): one screen for the road-fight
## skeletons (MapPlot, data/plots/<region>/<id>.json). Left, the brushes: the four terraces and Outside, then the marks
## (road, river, bridge, stairs, rock, woods) and Clear. Middle, the plot's flat sketch: paint with the left button, the
## right button clears a mark (or makes a cell Outside when it has none); the party starts on the left edge (blue), the
## foes on the right (red). Right, the preview: the map this plot makes for a seed (re-roll it), drawn flat, with what
## QA says about it, and Open in map maker to look at it in 3D. Top: pick a plot, New, Save, Undo, back to the maker.

const REGION := "forest"
const BRUSHES := [["0", "Low ground"], ["1", "Terrace 1"], ["2", "Terrace 2"], ["3", "High ground"], [".", "Outside"]]
const MARKS := [["d", "Road"], ["w", "River"], ["b", "Bridge"], ["s", "Stairs"], ["r", "Rock"], ["t", "Woods"], [" ", "Clear mark"]]
const LEVEL_COL := {"0": Color("#56733d"), "1": Color("#7f9e55"), "2": Color("#a9c47a"), "3": Color("#d6e8b0"), ".": Color("#1d2326")}
const MARK_COL := {"d": Color("#c9a66b"), "w": Color("#4a82c4"), "b": Color("#8a5a32"), "s": Color("#e8e2d0"), "r": Color("#7b7f86"), "t": Color("#2f5a33")}
const JOBS := ["", "flank", "crossing"]
const PARTY_TINT := Color(0.3, 0.55, 1.0, 0.3)
const FOE_TINT := Color(1.0, 0.35, 0.3, 0.3)
const CHECKS := {"reach": "Every cell reachable", "deploy": "Room for both sides", "crossings": "Bridges and fords", "route": "Short enough walk"}

var plot := {}
var path := ""
var brush := "1"
var _undo: Array = []
var _seed := 1
var _preview: CombatGrid = null
var _checks: VBoxContainer
var _seed_label: Label
var _picker: OptionButton
var _job: OptionButton
var _note: TextEdit
var _draft: CheckBox
var _canvas: Control
var _mini: Control
var _brush_buttons := {}
var _painting := 0


func _ready() -> void:
	theme = MakerUI.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#14181b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	col.add_child(_card(_top_bar()))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	col.add_child(body)
	body.add_child(_card(_brush_panel()))
	_canvas = Control.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.clip_contents = true
	_canvas.draw.connect(_draw_plot)
	_canvas.gui_input.connect(_on_canvas_input)
	_canvas.resized.connect(_canvas.queue_redraw)
	body.add_child(_canvas)
	var right := _card(_preview_panel())
	body.add_child(right)
	var plots := MapPlot.list(REGION)
	if plots.is_empty():
		_new_plot()
	else:
		_open(MapPlot.DIR + REGION + "/" + String(plots[0].id) + ".json")


## Esc goes back to the map maker, as the X does.
func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Game.go(Game.MAKER)


## A raised panel round one part of the screen (the map maker's look).
func _card(inner: Control) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := MakerUI.box(MakerUI.BG, 8, 10.0, MakerUI.LINE)
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(inner)
	return p


func _top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	bar.add_child(MakerUI.label("Plot maker", 17, MakerUI.ACCENT, true))
	bar.add_child(MakerUI.spacer(10))
	_picker = OptionButton.new()
	_picker.tooltip_text = "Which forest plot to edit"
	_picker.custom_minimum_size.x = 170
	_picker.item_selected.connect(func(i: int) -> void: _open(String(_picker.get_item_metadata(i))))
	bar.add_child(_picker)
	bar.add_child(_icon("new", "New plot", _new_plot, "New"))
	bar.add_child(_icon("save", "Save this plot", _save, "Save"))
	bar.add_child(_icon("undo", "Undo the last stroke", _undo_last, "Undo"))
	bar.add_child(MakerUI.spacer(10))
	bar.add_child(MakerUI.label("River", 13, MakerUI.DIM))
	_job = OptionButton.new()
	_job.tooltip_text = "The river's job: none, along one side (flank), or between the starts with one bridge (crossing)"
	for j in JOBS:
		_job.add_item({"": "No river", "flank": "River along a side", "crossing": "River between starts"}[j])
	_job.item_selected.connect(func(i: int) -> void:
		plot.river = JOBS[i]
		_changed())
	bar.add_child(_job)
	_draft = CheckBox.new()
	_draft.text = "Draft"
	_draft.focus_mode = Control.FOCUS_NONE
	_draft.tooltip_text = "A draft shows here but road fights skip it until you untick this"
	_draft.toggled.connect(func(on: bool) -> void:
		if on:
			plot.draft = true
		else:
			plot.erase("draft"))
	bar.add_child(_draft)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	bar.add_child(_icon("map", "Back to the map maker", func() -> void: Game.go(Game.MAKER), "Map maker"))
	bar.add_child(_icon("close", "Close (Esc)", func() -> void: Game.go(Game.MAKER)))
	return bar


func _icon(id: String, tip: String, cb: Callable, words := "", px := 34.0) -> MakerUI.IconButton:
	var b := MakerUI.IconButton.new(id, tip, px, words)
	b.pressed.connect(cb)
	return b


func _brush_panel() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 158
	col.add_theme_constant_override("separation", 3)
	col.add_child(MakerUI.label("Ground", 14, MakerUI.ACCENT, true))
	for b in BRUSHES:
		col.add_child(_brush_button(b[0], b[1], _swatch(LEVEL_COL[b[0]], "")))
	col.add_child(MakerUI.spacer(0, 8))
	col.add_child(MakerUI.label("Marks", 14, MakerUI.ACCENT, true))
	for m in MARKS:
		col.add_child(_brush_button("m" + m[0], m[1], _swatch(LEVEL_COL["1"], m[0])))
	col.add_child(MakerUI.spacer(0, 8))
	col.add_child(MakerUI.label("Starts", 14, MakerUI.ACCENT, true))
	col.add_child(_legend(PARTY_TINT, "Party"))
	col.add_child(_legend(FOE_TINT, "Foes"))
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(gap)
	col.add_child(MakerUI.label("Left click paints", 12, MakerUI.DIM))
	col.add_child(MakerUI.label("Right click clears", 12, MakerUI.DIM))
	return col


func _legend(tint: Color, text: String) -> Control:
	var row := HBoxContainer.new()
	var sw := TextureRect.new()
	sw.texture = _swatch(LEVEL_COL["1"].lerp(Color(tint, 1.0), tint.a), "")
	sw.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	sw.custom_minimum_size = Vector2(24, 22)
	row.add_child(sw)
	row.add_child(MakerUI.label(text, 13))
	return row


func _brush_button(id: String, text: String, tex: Texture2D) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.icon = tex
	b.pressed.connect(func() -> void: _set_brush(id))
	_brush_buttons[id] = b
	return b


## A 16 px swatch: the ground colour, with the mark's icon drawn on it.
func _swatch(ground: Color, mark: String) -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(ground)
	if mark != "" and mark != " ":
		for p in _mark_cells(mark, 16):
			img.set_pixelv(p, MARK_COL[mark])
	return ImageTexture.create_from_image(img)


## The pixels of a mark's icon in an n x n cell (shared by the swatches; the canvas draws the same shapes).
func _mark_cells(mark: String, n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in n:
		for x in n:
			var u := (x + 0.5) / n
			var v := (y + 0.5) / n
			var on := false
			match mark:
				"d":
					on = v > 0.3 and v < 0.7
				"w":
					on = true
				"b":
					on = (v > 0.2 and v < 0.8) and fmod(u * 4.0, 1.0) < 0.75
				"s":
					on = fmod(v * 3.0, 1.0) < 0.5 and u > 0.15 and u < 0.85
				"r":
					on = Vector2(u - 0.5, v - 0.55).length() < 0.3
				"t":
					on = Vector2(u - 0.5, v - 0.45).length() < 0.32 or (absf(u - 0.5) < 0.06 and v > 0.6 and v < 0.9)
			if on:
				out.append(Vector2i(x, y))
	return out


func _set_brush(id: String) -> void:
	brush = id
	for k in _brush_buttons:
		(_brush_buttons[k] as Button).button_pressed = k == id


func _preview_panel() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 290
	col.add_theme_constant_override("separation", 6)
	col.add_child(MakerUI.label("Note", 14, MakerUI.ACCENT, true))
	_note = TextEdit.new()
	_note.placeholder_text = "what this plot is for"
	_note.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_note.custom_minimum_size = Vector2(290, 84)
	_note.text_changed.connect(func() -> void: plot.note = _note.text)
	col.add_child(_note)
	col.add_child(MakerUI.spacer(0, 4))
	var head := HBoxContainer.new()
	head.add_child(MakerUI.label("One seed", 14, MakerUI.ACCENT, true))
	_seed_label = MakerUI.label("", 13, MakerUI.DIM)
	head.add_child(_seed_label)
	col.add_child(head)
	_mini = Control.new()
	_mini.custom_minimum_size = Vector2(290, 252)
	_mini.draw.connect(_draw_preview)
	col.add_child(_mini)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_icon("generate", "Build this plot with the next seed", func() -> void:
		_seed += 1
		_rebuild(), "Another seed"))
	row.add_child(_icon("eye", "Open this seed in the map maker, in 3D", _open_in_maker, "Open in 3D"))
	col.add_child(row)
	col.add_child(MakerUI.spacer(0, 4))
	col.add_child(MakerUI.label("Checks", 14, MakerUI.ACCENT, true))
	_checks = VBoxContainer.new()
	_checks.add_theme_constant_override("separation", 2)
	col.add_child(_checks)
	return col


# --- the plot ------------------------------------------------------------------------------------

func _open(p: String) -> void:
	var d := MapPlot.load_file(p)
	if d.is_empty():
		return
	plot = d
	path = p
	_undo.clear()
	_fill_picker()
	_job.select(maxi(0, JOBS.find(String(plot.get("river", "")))))
	_note.text = String(plot.get("note", ""))
	_draft.set_pressed_no_signal(bool(plot.get("draft", false)))
	_set_brush(brush)
	_changed()


func _new_plot() -> void:
	var n := MapPlot.list(REGION).size() + 1
	var id := "plot_%d" % n
	var rows: Array = []
	var marks: Array = []
	for y in MapGen.FIGHT_H:
		rows.append(".".repeat(MapGen.FIGHT_W) if y < 3 or y > MapGen.FIGHT_H - 4 else "1".repeat(MapGen.FIGHT_W))
		marks.append(" ".repeat(MapGen.FIGHT_W))
	marks[MapGen.FIGHT_H / 2] = "d".repeat(MapGen.FIGHT_W)
	plot = {"id": id, "region": REGION, "river": "", "note": "", "levels": rows, "marks": marks}
	path = MapPlot.DIR + REGION + "/" + id + ".json"
	_undo.clear()
	_fill_picker()
	_job.select(0)
	_note.text = ""
	_changed()


func _fill_picker() -> void:
	_picker.clear()
	var i := 0
	for p in MapPlot.list(REGION):
		_picker.add_item(String(p.id) + ("  (draft)" if bool(p.get("draft", false)) else ""))
		_picker.set_item_metadata(i, MapPlot.DIR + REGION + "/" + String(p.id) + ".json")
		if MapPlot.DIR + REGION + "/" + String(p.id) + ".json" == path:
			_picker.select(i)
		i += 1


func _save() -> void:
	DirAccess.make_dir_recursive_absolute(MapPlot.DIR + REGION)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(plot, " ") + "\n")
	f.close()
	_fill_picker()


func _undo_last() -> void:
	if _undo.is_empty():
		return
	var d: Dictionary = _undo.pop_back()
	plot.levels = d.levels
	plot.marks = d.marks
	_changed()


func _set_cell(c: Vector2i, erase: bool) -> void:
	var size := MapPlot.size_of(plot)
	if c.x < 0 or c.y < 0 or c.x >= size.x or c.y >= size.y:
		return
	var lv: String = plot.levels[c.y]
	var mk: String = plot.marks[c.y]
	if erase:
		if mk[c.x] != " ":
			mk[c.x] = " "
		else:
			lv[c.x] = "."
	elif brush.begins_with("m"):
		if lv[c.x] == ".":
			return
		mk[c.x] = brush.substr(1, 1)
	else:
		lv[c.x] = brush
		if brush == ".":
			mk[c.x] = " "
	plot.levels[c.y] = lv
	plot.marks[c.y] = mk


func _changed() -> void:
	_canvas.queue_redraw()
	_rebuild()


func _rebuild() -> void:
	for c in _checks.get_children():
		c.queue_free()
	for p in MapPlot.problems(plot):
		_checks.add_child(_check_row(false, "Plot: " + p))
	_preview = MapPlot.build(plot, _seed, "forest")
	_seed_label.text = "  seed %d" % _seed
	var doc := MapDoc.create("battle", "plot_preview", _preview, "forest")
	for c in MapQA.run(doc.grid, "battle", doc.data):
		if CHECKS.has(c.id):
			_checks.add_child(_check_row(c.level == "ok", CHECKS[c.id] if c.level == "ok" else String(c.summary)))
	_mini.queue_redraw()


## One line of the checks: a green tick or a red cross, then the words.
func _check_row(ok: bool, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var mark := Control.new()
	mark.custom_minimum_size = Vector2(16, 18)
	mark.draw.connect(func() -> void:
		var col := MakerUI.GOOD if ok else MakerUI.BAD
		if ok:
			mark.draw_polyline(PackedVector2Array([Vector2(3, 9), Vector2(7, 13), Vector2(14, 4)]), col, 2.0)
		else:
			mark.draw_line(Vector2(4, 4), Vector2(13, 13), col, 2.0)
			mark.draw_line(Vector2(13, 4), Vector2(4, 13), col, 2.0))
	row.add_child(mark)
	var l := MakerUI.label(text, 13, MakerUI.INK if ok else MakerUI.BAD)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


## The preview map in the maker (saved in user://, never in the project, so it stays a scratch copy).
func _open_in_maker() -> void:
	var doc := MapDoc.create("battle", "plot_preview", _preview, "forest")
	DirAccess.make_dir_recursive_absolute(MapDoc.USER_DIRS.battle)
	var p: String = MapDoc.USER_DIRS.battle + "plot_preview.json"
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc.to_dict(), "\t"))
	f.close()
	Game.maker_map = p
	Game.go(Game.MAKER)


# --- drawing and painting --------------------------------------------------------------------------

func _cell_px() -> float:
	var size := MapPlot.size_of(plot)
	return floorf(minf(_canvas.size.x / maxf(1, size.x), _canvas.size.y / maxf(1, size.y)))


## Where the sketch's top-left corner sits: centred in the canvas.
func _origin() -> Vector2:
	var size := MapPlot.size_of(plot)
	return ((_canvas.size - Vector2(size) * _cell_px()) * 0.5).floor()


func _draw_plot() -> void:
	if plot.is_empty():
		return
	var size := MapPlot.size_of(plot)
	var px := _cell_px()
	var o := _origin()
	_canvas.draw_rect(Rect2(o, Vector2(size) * px), LEVEL_COL["."])
	for y in size.y:
		for x in size.x:
			var c := Vector2i(x, y)
			var r := Rect2(o + Vector2(x, y) * px, Vector2(px, px))
			var lv := MapPlot.level_at(plot, c)
			if lv == ".":
				_canvas.draw_rect(r, Color(1, 1, 1, 0.04), false, 1.0)
				continue
			_canvas.draw_rect(r, LEVEL_COL.get(lv, Color.MAGENTA))
			if x < CombatGrid.DEPLOY_COLS:
				_canvas.draw_rect(r, PARTY_TINT)
			elif x >= size.x - CombatGrid.DEPLOY_COLS:
				_canvas.draw_rect(r, FOE_TINT)
			var mk := MapPlot.mark_at(plot, c)
			if mk == "d":  # the road joins its neighbours: a bar from the middle toward each road, stair or bridge beside it
				var w := px * 0.4
				var mid := Rect2(r.position + Vector2(px - w, px - w) * 0.5, Vector2(w, w))
				_canvas.draw_rect(mid, MARK_COL.d)
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if MapPlot.mark_at(plot, c + d) in ["d", "s", "b"]:
						_canvas.draw_rect(Rect2(mid.position + Vector2(d) * (px - w) * 0.5, mid.size).merge(mid), MARK_COL.d)
			elif mk != " " and MARK_COL.has(mk):
				var cells := _mark_cells(mk, 16)
				var k := px / 16.0
				for p in cells:
					_canvas.draw_rect(Rect2(r.position + Vector2(p) * k, Vector2(k, k) + Vector2(0.5, 0.5)), MARK_COL[mk])
			_canvas.draw_rect(r, Color(0, 0, 0, 0.22), false, 1.0)
			# a terrace edge: a dark line where the ground drops to a lower terrace or the outside
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
				var nb := MapPlot.level_at(plot, c + d)
				if nb == "." or int(nb) < int(lv):
					var a := r.position + Vector2(px if d.x > 0 else 0.0, px if d.y > 0 else 0.0)
					var b := a + (Vector2(0, px) if d.x != 0 else Vector2(px, 0))
					_canvas.draw_line(a, b, Color(0, 0, 0, 0.55), 2.0)


func _on_canvas_input(e: InputEvent) -> void:
	var px := _cell_px()
	if px <= 0.0:
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT):
			_undo.append({"levels": (plot.levels as Array).duplicate(), "marks": (plot.marks as Array).duplicate()})
			_painting = mb.button_index
			_set_cell(Vector2i(((mb.position - _origin()) / px).floor()), _painting == MOUSE_BUTTON_RIGHT)
			_canvas.queue_redraw()
		elif not mb.pressed and _painting != 0:
			_painting = 0
			_rebuild()
	elif e is InputEventMouseMotion and _painting != 0:
		_set_cell(Vector2i((((e as InputEventMouseMotion).position - _origin()) / px).floor()), _painting == MOUSE_BUTTON_RIGHT)
		_canvas.queue_redraw()


## The preview map drawn flat: ground shaded by height, water blue, rock grey, road tan, stairs light, trees dark, bridges brown.
func _draw_preview() -> void:
	if _preview == null:
		return
	var px := floorf(minf(_mini.size.x / _preview.w, _mini.size.y / _preview.h))
	var o := ((_mini.size - Vector2(_preview.w, _preview.h) * px) * 0.5).floor()
	for y in _preview.h:
		for x in _preview.w:
			var c := Vector2i(x, y)
			var t := _preview.terrain_at(c)
			var col := Color("#1d2326")
			match t:
				CombatGrid.T.VOID:
					col = Color("#1d2326")
				CombatGrid.T.WATER:
					col = Color("#4a82c4")
				CombatGrid.T.ROCK:
					col = Color("#7b7f86")
				CombatGrid.T.ROAD:
					col = Color("#c9a66b")
				CombatGrid.T.STAIRS:
					col = Color("#e8e2d0")
				CombatGrid.T.FOREST:
					col = Color("#2f5a33")
				_:
					col = LEVEL_COL[str(clampi((_preview.height_at(c) - 1) / MapPlot.LEVEL_STEP, 0, 3))]
			if _preview.has_deck(c):
				col = Color("#8a5a32")
			if t != CombatGrid.T.VOID:
				_mini.draw_rect(Rect2(o + Vector2(x, y) * px, Vector2(px - 1, px - 1)), col)

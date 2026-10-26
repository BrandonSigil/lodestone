extends Node2D
## The village: pick a party from the unlocked roster, then head out.

var hud: FrameHud
var picked: Array[CharacterDef] = []
var cards: Dictionary = {}  # id -> Button
var slots_label: Label
var go_button: Button


func _ready() -> void:
	hud = FrameHud.new()
	add_child(hud)
	hud.top_label.text = Txt.t("GAME_TITLE")

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	FrameHud._pin(grid, 0, 0, 1, 1, FrameHud.LEFT_W + 20, FrameHud.TOP_H + 20, -FrameHud.RIGHT_W - 20, -FrameHud.BOTTOM_H - 20)
	hud.root.add_child(grid)
	for d in Db.roster():
		grid.add_child(_card(d))

	for line in Game.pending_lines:
		hud.add_side_label(line, 16)
	Game.pending_lines = []
	hud.add_side_label(Txt.t("UI_PICK_PARTY"), 16)
	slots_label = hud.add_side_label("")
	hud.add_side_label(Txt.f("UI_RUNS", int(Game.meta.runs)))
	hud.add_side_label(Txt.f("UI_BEST", int(Game.meta.best_distance)))
	hud.add_side_label(Txt.f("UI_BONUS_FOOD", Game.bonus_gold()))
	go_button = hud.add_button(Txt.t("UI_START"), _go)
	_toggle(Db.character(&"lead"))


func _card(d: CharacterDef) -> Control:
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(180, 150)
	var unlocked := Game.is_unlocked(d)
	b.disabled = not unlocked
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon := PawnIcon.new()
	icon.tint = d.tint
	icon.dim = not unlocked
	icon.custom_minimum_size = Vector2(60, 64)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var lines := [Txt.t(d.name_key), Txt.t(d.class_def.name_key)]
	if not unlocked:
		lines.append(Txt.t("UNLOCK_" + d.unlock.to_upper()))
	else:
		var tags: Array[String] = []
		for k in d.off_skills:
			tags.append("%s +%d" % [k, d.off_skills[k]])
		for p in d.perks:
			tags.append(String(p))
		if d.deficiency != &"":
			tags.append("(-) " + String(d.deficiency))
		if d.party_slots > 1:
			tags.append("%d slots" % d.party_slots)
		if d.inventory_slots > 0:
			tags.append("bag -%d" % d.inventory_slots)
		lines.append(", ".join(tags))
	var l := Label.new()
	l.text = "\n".join(lines)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 12)
	box.add_child(l)
	b.add_child(box)
	b.pressed.connect(_toggle.bind(d))
	cards[d.id] = b
	return b


func _slots_used() -> int:
	var n := 0
	for d in picked:
		n += d.party_slots
	return n


func _toggle(d: CharacterDef) -> void:
	if picked.has(d):
		picked.erase(d)
	elif _slots_used() + d.party_slots <= Game.PARTY_SLOTS:
		picked.append(d)
	for id in cards:
		cards[id].set_pressed_no_signal(picked.has(Db.character(id)))
	slots_label.text = Txt.f("UI_SLOTS_USED", [_slots_used(), Game.PARTY_SLOTS])
	go_button.disabled = picked.is_empty()
	var preview := RunState.create(picked, 0)
	hud.set_party(FrameHud.party_entries_from_run(preview))
	hud.set_slots(preview.slot_list(), RunState.CAPACITY)


func _go() -> void:
	Game.start_run(picked)

class_name LevelUpUi
extends RefCounted
## The level-up screen's body ([USER] 2026-10-31, docs/design/level-up.md): after the fight or event that earned it, what
## the character just improved (stats go up on odd levels), and on even levels one pick: learn a kit ability or give a
## known one its next step, with plain before and after numbers. A pick can wait ("decide later") in the Lodestone menu.

## ability field -> the word the card uses
const LABELS := {"power": "Power", "range_max": "Reach", "range_min": "Closest reach", "res_cost": "Cost", "cooldown": "Wait",
	"status_turns": "Lasts", "push": "Shove", "radius": "Area", "crit": "Crit chance", "bleed": "Bleed"}


static func _member(id: String) -> Dictionary:
	for m in Game.run.members:
		if String((m.def as CharacterDef).id) == id:
			return m
	return {}


## The header and the stat lines for a member that just levelled: "LEAD LEVEL 3!", "HP 18 to 20".
static func summary(id: String, entry: Dictionary) -> String:
	var m := _member(id)
	if m.is_empty():
		return ""
	var lines: PackedStringArray = []
	var levels: Array = entry.get("levels", [])
	var name := Txt.t((m.def as CharacterDef).name_key)
	lines.append(Txt.f("UI_LEVEL_UP", [name, int(levels[levels.size() - 1])]) if not levels.is_empty() else name)
	var u := CombatUnit.from_member(m)
	var now := {"hp": u.max_hp, "damage": u.damage, "armor": u.armor, "magic": u.magic_power, "crit": u.crit}
	var stats: Dictionary = entry.get("stats", {})
	for k in LevelRules.STATS:
		if stats.has(k):
			lines.append(Txt.f("UI_LV_STAT", [Txt.t("UI_STAT_" + k.to_upper()), int(now[k]) - int(stats[k]), int(now[k])]))
	return "\n".join(lines)


## Picks waiting for a member, as cards in `box`; a click spends the pick and calls `refresh` (the screen rebuilds).
static func picks(box: VBoxContainer, id: String, refresh: Callable) -> void:
	var m := _member(id)
	if m.is_empty() or int(Game.rank_state(id).pending) <= 0:
		return
	var u := CombatUnit.from_member(m)
	var label := Label.new()
	label.text = Txt.f("UI_LV_PICK", int(Game.rank_state(id).pending))
	label.add_theme_font_size_override("font_size", 18)
	box.add_child(label)
	for aid in Game.learnable(id):
		var a := Db.ability(aid)
		_card(box, a.id, Txt.f("UI_LV_LEARN", Txt.t(a.name_key)) + "\n" + _describe(a), func() -> void:
			Game.learn_skill(id, aid)
			refresh.call())
	var ranks: Dictionary = Game.rank_state(id).ranks
	for a: Ability in u.abilities:
		var have := int(ranks.get(a.id, 0))
		var nxt := LevelRules.next_useful_rank(a.id, have, Db.skill_ranks)
		if nxt == 0:
			continue
		var base := Db.ability(a.id)
		var step: Dictionary = (Db.upgrade_steps.get(a.id, []) as Array)[nxt - 1]
		var line := Txt.f("UI_LV_UPGRADE", [Txt.t(a.name_key), nxt, LevelRules.max_rank(a.id, Db.skill_ranks)]) + "\n" + String(step.text)
		var change := _change(u, base, have, nxt, String(step.effect))
		if change != "":
			line += "\n" + change
		_card(box, a.id, line, func() -> void:
			Game.rank_skill(id, a.id)
			refresh.call())


## "Power 3 to 4  Reach 2 to 3": every field this step's effect touches, before and after.
static func _change(u: CombatUnit, base: Ability, have: int, nxt: int, effect: String) -> String:
	var before := LevelRules.ranked(base, have, Db.skill_ranks)
	var after := LevelRules.ranked(base, nxt, Db.skill_ranks)
	var parts: PackedStringArray = []
	for part in effect.split(";", false):
		var key := part.split(":")[0].strip_edges()
		if not key in before or not LABELS.has(key):
			continue
		var b: Variant = before.get(key)
		var f: Variant = after.get(key)
		if key == "power" and base.kind == "attack":  # the damage it deals: the piece's own plus the skill's
			parts.append("%s %d to %d" % [Txt.t("UI_STAT_DAMAGE"), u.damage + int(b), u.damage + int(f)])
		else:
			parts.append("%s %s to %s" % [LABELS[key], str(b), str(f)])
	return "   ".join(parts)


static func _describe(a: Ability) -> String:
	var parts: PackedStringArray = []
	if Txt.has("DESC_" + a.id.to_upper()):
		parts.append(Txt.t("DESC_" + a.id.to_upper()))
	var facts: PackedStringArray = []
	if a.res_cost > 0:
		facts.append(Txt.f("UI_LV_COST", a.res_cost))
	if a.range_max > 0:
		facts.append(Txt.f("UI_LV_REACH", [a.range_min, a.range_max]))
	if not facts.is_empty():
		parts.append(", ".join(facts))
	return "\n".join(parts)


static func _card(box: VBoxContainer, icon_id: String, text: String, on_pick: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(460, 92)
	b.add_theme_font_size_override("font_size", 17)
	var tex := ActionInfo.icon(icon_id)
	if tex != null:
		b.icon = tex
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 48)
	b.pressed.connect(on_pick)
	box.add_child(b)

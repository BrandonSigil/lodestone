class_name ActionInfo
extends RefCounted
## What a fight action's hover card says ([USER] 2026-10-30: WoW-style spell tooltips), from the data only:
## name, cost, range, the numbers, wait time and the caveman line. Pure, so tests can read it.

const ICON_DIR := "res://art/source/icons/"


## The lines of the card for piece u's action a. The first is the name; the board lights the range meanwhile.
static func lines(u: CombatUnit, a: Ability) -> PackedStringArray:
	var out: PackedStringArray = [Txt.t(a.name_key)]
	out.append(cost_text(u, a))
	var r := CombatRules.ability_range(u, a)
	var rng := Txt.f("TIP_RANGE", str(r.x) if r.x == r.y else "%d-%d" % [r.x, r.y]) if a.target != "self" else Txt.t("TIP_SELF")
	if a.radius > 0:
		rng += "  " + Txt.f("TIP_AREA", a.radius)
	out.append(rng)
	var nums: PackedStringArray = []
	match a.kind:
		"attack":
			var hit := u.damage + a.power + (u.magic_power if a.magic or u.magic else 0)
			var w := int(CombatRules.num("wobble"))
			nums.append(Txt.f("TIP_HIT", "%d-%d" % [maxi(1, hit - w), hit + w]))
			if a.crit != 0:
				nums.append(Txt.f("TIP_CRIT", a.crit))
			if a.push > 0:
				nums.append(Txt.f("TIP_PUSH", a.push))
		"heal":
			nums.append(Txt.f("TIP_HEAL", CombatRules.heal_amount(u, a)))
		"revive":
			nums.append(Txt.t("TIP_REVIVE"))
		"knockout":
			nums.append(Txt.t("TIP_KNOCKOUT"))
		"carry":
			nums.append(Txt.f("TIP_CARRY", a.power))
		"command":
			nums.append(Txt.t("TIP_COMMAND"))
		"swap":
			nums.append(Txt.t("TIP_SWAP"))
	if a.status == CombatRules.STATUS_WARD:  # it ends at the caster's next turn, not after a count (playtest)
		nums.append(Txt.t("TAG_WARD") + " " + Txt.t("TIP_WARD_TIME"))
	elif a.status != "":
		nums.append(Txt.f("TIP_STATUS", [Txt.t("TAG_" + a.status.to_upper()), a.status_turns]))
	if a.magic:
		nums.append(Txt.t("TIP_MAGIC") + ((" " + Txt.t("ELEM_" + a.element.to_upper())) if a.element != "" and Txt.has("ELEM_" + a.element.to_upper()) else ""))
	if not nums.is_empty():
		out.append("  ".join(nums))
	out.append(wait_text(u, a))
	var desc := "DESC_" + a.id.to_upper()
	if Txt.has(desc):
		out.append(Txt.t(desc))
	return out


static func cost_text(u: CombatUnit, a: Ability) -> String:
	if a.is_item():
		var have := u.belt.count(a.spends) if u.belt != null else 0
		return Txt.f("TIP_ITEM", [Txt.t(String(Db.items[a.spends].name_key)), a.cost, have])
	if a.res_cost > 0 and u.res_kind != "":
		return Txt.f("TIP_COST", [a.res_cost, Txt.t("RES_" + u.res_kind.to_upper()), u.res, u.res_max])
	return Txt.t("TIP_FREE")


## No cooldowns on the party's skills ([USER] c9): charges come back on a clock, mana a share a phase.
static func wait_text(u: CombatUnit, a: Ability) -> String:
	if a.cooldown > 0:
		return Txt.f("TIP_COOLDOWN", a.cooldown)
	if a.res_cost > 0 and u.res_kind == "charges" and u.res_every > 0:
		return Txt.f("TIP_CHARGE_BACK", u.res_every)
	if a.res_cost > 0 and u.res_kind == "mana":
		return Txt.f("TIP_MANA_BACK", int(CombatRules.num("mana_regen_pct")))
	return Txt.t("TIP_NO_WAIT")


## How far a charge-paid skill is from being paid for again: 0 ready .. 1 just spent (the slot's sweep).
static func recharge(u: CombatUnit, a: Ability) -> float:
	if u.can_use(a) or u.res_kind != "charges" or u.res_every <= 0:
		return 0.0
	return 1.0 - float(u.res_tick) / float(u.res_every)


## Approved spare icons standing in for actions the sheet hasn't painted yet (art runner, 2026-10-30).
const SPARES := {"ward": "shield", "shadow_swap": "teleport", "carry": "dash", "command": "rally", "overwatch": "focus"}


## An action's icon: its own id, else for an item the pack item it spends (the sheet names items by item id), else a
## spare that fits.
static func icon_for(a: Ability) -> Texture2D:
	var t := icon(a.id)
	if t == null and a.is_item():
		t = icon(a.spends)
	return t if t != null else icon(String(SPARES.get(a.id, "")))


static var _icons := {}  ## id -> Texture2D or null, loaded once (loading mid-draw gives a blank texture)


## The icon's file when the art runner's sheet has one (named by ability or item id), else null: graybox.
static func icon(id: String) -> Texture2D:
	if id == "":
		return null
	if not _icons.has(id):
		var p := ICON_DIR + id + ".png"
		_icons[id] = load(p) if ResourceLoader.exists(p) else null
	return _icons[id]

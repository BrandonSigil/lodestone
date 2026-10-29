class_name FightGoals
extends RefCounted
## How a fight is won besides beating every foe ([USER] c10, c17; combat build step 6). Pure rules.
## A fight lists one goal or several; meeting any one wins. The fight is lost when every party piece is down,
## or when a piece marked protect falls. Written in data as "defeat|leader|hold:5|exit" (explore group defs:
## "goals", plus "exit" cells; encounters.csv: the goals column).
##   defeat   every foe down
##   leader   the foe marked leader is down; the rest flee
##   hold:N   the party still stands after N rounds
##   exit     every standing party piece is on an exit cell (an escape)
## TALK (data "talk": {"unit": index of the foe in the group, "need": "flag:..." or "", "times": N,
## "result": "flee" or "join:<flag>"}): the hero talks to that foe as an action; after N talks the group
## flees (a win) or the foe leaves the fight and the flag is set (some hostile characters join the party).

const KINDS := ["defeat", "leader", "hold", "exit"]

var kinds: Array[String] = ["defeat"]
var hold_rounds := 0
var exit_cells: Array[Vector2i] = []
var talk := {}  ## see above; empty when the fight isn't written for it
var talks := 0  ## times the hero has talked so far this fight


## goals: "defeat|leader|hold:5|exit" ("" means defeat all). exit: [[x, y], ...]. talk: see above.
static func parse(goals: String, exit := [], talk_def := {}) -> FightGoals:
	var g := FightGoals.new()
	if goals.strip_edges() != "":
		g.kinds.clear()
		for part in goals.split("|", false):
			var kv := part.strip_edges().split(":")
			if kv[0] in KINDS:
				g.kinds.append(kv[0])
				if kv[0] == "hold" and kv.size() > 1:
					g.hold_rounds = int(kv[1])
			else:
				push_warning("unknown fight goal '%s'" % part)
		if g.kinds.is_empty():
			g.kinds.append("defeat")
	for c in exit:
		g.exit_cells.append(Vector2i(int(c[0]), int(c[1])))
	g.talk = talk_def
	return g


## {"won": bool, "lost": bool, "how": the goal met ("" while the fight goes on)}. rounds: rounds finished.
func check(units: Array, rounds: int) -> Dictionary:
	var lost := not CombatRules.team_alive(units, 0)
	for u: CombatUnit in units:
		if u.protect and not u.alive():
			lost = true
	if lost:
		return {"won": false, "lost": true, "how": "lost"}
	for k in kinds:
		if _met(k, units, rounds):
			return {"won": true, "lost": false, "how": k}
	return {"won": false, "lost": false, "how": ""}


func _met(kind: String, units: Array, rounds: int) -> bool:
	match kind:
		"defeat":
			return not CombatRules.team_alive(units, 1)
		"leader":
			return units.any(func(u: CombatUnit) -> bool: return u.leader and u.team == 1 and not u.alive())
		"hold":
			return hold_rounds > 0 and rounds >= hold_rounds
		"exit":
			var standing := units.filter(func(u: CombatUnit) -> bool: return u.team == 0 and u.alive())
			return not standing.is_empty() and standing.all(func(u: CombatUnit) -> bool: return exit_cells.has(u.cell))
	return false


## Is TALK open: the fight is written for it and its need (a flag) is met? flags: Game.meta.flags.
func talk_open(flags: Array) -> bool:
	if talk.is_empty():
		return false
	var need := String(talk.get("need", ""))
	return need == "" or not need.begins_with("flag:") or flags.has(need.substr(5))


## The hero talked once more. Returns "" while it takes more talking, else the result ("flee" or "join:<flag>").
func talk_once() -> String:
	talks += 1
	return String(talk.get("result", "flee")) if talks >= maxi(1, int(talk.get("times", 1))) else ""

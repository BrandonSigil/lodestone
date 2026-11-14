class_name GoalRules
extends RefCounted
## The main goal and the one-time hints (2026-11-13 playtest: a new player never knew what to do next, or which keys
## to press). Pure: the flags in, a text key out, so tests run it headless.
##
## The main goal is a chain of steps through the playtest, each done when its flag is set. The frame's long bar shows
## the first step not done (above any tracked village steps), and the homecoming page shows it when nothing is tracked.
## Every line is game text in text/placeholder.csv (GOAL_*), none of it story.

## [step key, the flags that finish it (any one of them)]. The order is the playtest's path.
const CHAIN := [
	["GOAL_LODESTONE", ["has_lodestone"]],
	["GOAL_WEAPON", ["weapon_sword", "weapon_bow", "weapon_daggers", "weapon_book"]],
	["GOAL_DOG", ["met_dog", "left_village"]],  # optional: leaving without him moves on
	["GOAL_GATE", ["left_village"]],
	["GOAL_HIGHLANDS", ["visited_pass", "entered_snow_pass"]],
	["GOAL_CRYPT", ["entered_crypt"]],
	["GOAL_BOSS", ["e2e_done"]],
]


## The first step of the chain not done yet, as a text key; "" when the chain is finished.
static func main_goal(flags: Array) -> String:
	for step: Array in CHAIN:
		var done := false
		for f: String in step[1]:
			if flags.has(f):
				done = true
				break
		if not done:
			return String(step[0])
	return ""


## How far along the chain the player is: [steps done, steps in all] (the bar's "2/7").
static func progress(flags: Array) -> Vector2i:
	var key := main_goal(flags)
	for i in CHAIN.size():
		if String(CHAIN[i][0]) == key:
			return Vector2i(i, CHAIN.size())
	return Vector2i(CHAIN.size(), CHAIN.size())


## The one-time hints, by the place they show. A hint shows once ever: its flag is "hint_<id>".
const HINTS := {
	"walk": "HINT_WALK",  ## the first time the player can walk
	"use": "HINT_USE",  ## the first time something usable is in reach
	"road": "HINT_ROAD",  ## the first time on the world map
	"walking": "HINT_WALKING",  ## the first walk along a road
	"ambush": "HINT_AMBUSH",  ## the first fight where the foes move first
	"fight": "TIP_FIGHT_TITLE",  ## the first fight ever: FightTips, the ticked how-to card
}


static func hint_flag(id: String) -> String:
	return "hint_" + id


## The hint's text key when it hasn't been shown yet, else "".
static func hint(id: String, flags: Array) -> String:
	if not HINTS.has(id) or flags.has(hint_flag(id)):
		return ""
	return String(HINTS[id])

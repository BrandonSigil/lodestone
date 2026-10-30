class_name ClassDef
extends Resource
## One job: combat stats plus the trail skills that come with it.
## Characters layer off-class skills, perks and a deficiency on top.

@export var id: StringName
@export var name_key: String  ## key in text/placeholder.csv
@export var max_hp: int = 10
@export var move: int = 4
@export var jump: int = 1  ## max height change per step
@export var attack: int = 3  ## old d20 to-hit; unused in fights since hits always land (2026-10-29)
@export var defense: int = 10  ## old d20 target; unused in fights, armor took its place
@export var armor: int = 0  ## taken off every hit (0 to 3)
@export var crit: int = 0  ## % crit chance on top of the base
## What this job spends on skills ([USER] c9, c16): "mana" (starts full, a fifth back each phase), "rage"
## (starts at 0, +1 a hit dealt or taken), "charges" (start full, one back every resource_every phases), or "".
@export var resource := ""
@export var resource_max := 0
@export var resource_every := 0
@export var damage: int = 3
@export var range_min: int = 1
@export var range_max: int = 1
@export var magic: bool = false  ## ignores terrain cover
@export var skills: Dictionary = {}  ## check id -> bonus, e.g. {"hunt": 5}
@export var abilities: Array[StringName] = []  ## rows of data/abilities.csv beyond the basic strike
@export var spell_pool: Array[StringName] = []  ## spells (magic rows of data/abilities.csv) this class can learn
@export var spell_slots: int = 0  ## how many it brings into a fight
## A boss's phases by health ([USER] 2026-10-30 design-foes-boss2): entries {"below": % of max HP, "abilities": [ids]},
## in falling order, e.g. 67 and 33 for 2/3 and 1/3. Once its HP is at or under an entry's `below` it moves to that
## phase at the start of its next phase, one phase at a time (a burst does not skip one), and has the base abilities
## plus that phase's set (the earlier phase's set goes). No boss has any yet: what a phase changes is not picked.
@export var hp_phases: Array = []
@export var traits: Array[StringName] = []
@export var tags: Array[StringName] = []  ## foe tags (undead, beast, armored, flying): some attacks hit them harder or softer (data/tags.csv)  ## combat traits every unit of this class has (see CombatRules.TRAIT_*)


## The spells a unit of this class brings when nobody picked: the first ones in the pool.
func default_spells() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in spell_pool.slice(0, spell_slots):
		out.append(id)
	return out

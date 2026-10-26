class_name ClassDef
extends Resource
## One job: combat stats plus the trail skills that come with it.
## Characters layer off-class skills, perks and a deficiency on top.

@export var id: StringName
@export var name_key: String  ## key in text/placeholder.csv
@export var max_hp: int = 10
@export var move: int = 4
@export var jump: int = 1  ## max height change per step
@export var attack: int = 3  ## added to the d20 to-hit roll
@export var defense: int = 10  ## number the attacker must reach
@export var damage: int = 3
@export var range_min: int = 1
@export var range_max: int = 1
@export var magic: bool = false  ## ignores terrain cover
@export var skills: Dictionary = {}  ## check id -> bonus, e.g. {"hunt": 5}
@export var abilities: Array[StringName] = []  ## rows of data/abilities.csv beyond the basic strike
@export var spell_pool: Array[StringName] = []  ## spells (magic rows of data/abilities.csv) this class can learn
@export var spell_slots: int = 0  ## how many it brings into a fight
@export var traits: Array[StringName] = []  ## combat traits every unit of this class has (see CombatRules.TRAIT_*)


## The spells a unit of this class brings when nobody picked: the first ones in the pool.
func default_spells() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in spell_pool.slice(0, spell_slots):
		out.append(id)
	return out

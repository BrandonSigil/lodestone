class_name CharacterDef
extends Resource
## A roster character. Story fields (bio, lines) belong to Brandon and are not here.

@export var id: StringName
@export var name_key: String  ## key in text/placeholder.csv
@export var class_def: ClassDef
@export var off_skills: Dictionary = {}  ## 1-3 non-class skills, check id -> bonus
@export var perks: Array[StringName] = []
@export var deficiency: StringName = &""
@export var food_per_day: int = 1
@export var party_slots: int = 1
@export var inventory_slots: int = 0  ## group slots their gear fills (the Wizard's books)
@export var unlock: String = ""  ## "" = unlocked from the start, else a meta flag id
@export var tint: Color = Color(0.6, 0.6, 0.6)  ## graybox piece color


func skill(check: String) -> int:
	return int(class_def.skills.get(check, 0)) + int(off_skills.get(check, 0))


func has_perk(p: StringName) -> bool:
	return perks.has(p)

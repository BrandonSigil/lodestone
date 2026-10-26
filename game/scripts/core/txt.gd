class_name Txt
extends RefCounted
## Looks up player-facing text from text/placeholder.csv.
## Rules code calls this so the strings stay in one file Brandon owns.


static func t(key: String) -> String:
	return String(TranslationServer.translate(key))


static func f(key: String, args: Variant) -> String:
	return t(key) % args


## True when the key exists in the table (an unknown key translates to itself).
static func has(key: String) -> bool:
	return t(key) != key

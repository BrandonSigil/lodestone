# Character sheets

[USER] 2026-10-30 (docs/decisions.md, "Character sheets"): clicking the dog opens his character sheet, and the smithy weapon rack shows a sheet per build before the player picks. Layout after Brandon's Fire Emblem reference (`docs/art/references/character-sheet-layout.webp`, layout only), in the leaf frame's look.

## What a sheet shows
- `SheetRules.build(unit, info)` (pure, `game/scripts/ui/sheet_rules.gd`) works it out from a `CombatUnit`, so it always matches the fight: name, job, LV, EXP (this level's XP of `xp_per_level`), move, HP, then damage (ATK), crit % (`crit_base` plus the unit's), armor and range where Fire Emblem shows Atk, Hit, Crit and Avo (our hits always land). The stat block is the character's trail skills (`CHECK_<skill>`). The weapon row names the weapon and the job's resource. Up to `SheetRules.MOVES` (4) move rows: the unit's abilities in order, each with its caveman line `DESC_<ability id>` and its cost.
- `Game.sheet(id, weapon := "")` builds the unit the same way the party does (level bonus, weapon numbers, the meal and blessings, ranks). For the hero with a `weapon` it shows him holding that one instead: that job's class, the weapon's numbers and upgrades, and that job's own ranks. Nothing is changed or saved.

## Where it opens
- A party member: click their piece on the map, or their slot in the party frame (`FrameHud.member_pressed`). `ExploreScene.open_sheet(id)`.
- The smithy rack (thing kind `rack`): `ExploreRules.rack_builds` reads the rack event's options whose effect takes a weapon (`weapon:<id>`), in order, open or not. One page each; ◀ ▶ (or A / D, the arrow keys) flip; TAKE picks through the option itself, so its effects and text are the event's. The weapon in hand shows IN HAND; one not open yet (the book before it's found) shows NOT YET.

## Art
- The portrait slot: on the rack's pages the build's pose, `res://art/source/characters/<id>/<id>_build_<job>.png` (the hero holding that weapon, fitted whole); on a member's own sheet the portrait, `res://art/source/portraits/<id>.png` (cropped to fill). The hero has both (d15c55d, the portrait approved; the poses get redone later for the eye whites, same file names). Without them: a crop of the character's own sprite or its code figure (the dog, until his look is picked), and on the rack the weapon drawn in code from `data/weapons.csv`'s `look` column.
- The art is drawn through an `ImageTexture` copy (`CharacterSheet._art`): drawn straight from the imported texture it came out as a white box.
- Test pictures: `tools/godot.sh --path game -s res://tools/explore_shot.gd -- out.png sheet:dog village`, and `rack:<page>` for the rack (0 sword, 1 daggers, 2 bow, 3 the book).

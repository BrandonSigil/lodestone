# Lodestone

Tactics RPG meets Oregon Trail. Godot 4, GDScript, 2D. This is the week 1 graybox: shapes only, placeholder text only.

## Play it
1. Install [Godot 4.4](https://godotengine.org/download) (standard build, not .NET).
2. Open Godot, Import, pick `game/project.godot`.
3. Press F5. You start in the village: pick up to 4 party slots, press GO.

The flow is village, trail, fight, back to the trail, and back to the village when everyone falls (or you reach the end). Deaths unlock more of the roster.

## For Brandon
- `docs/decisions.md`: every rule so far. Lines tagged `[AI]` are my proposals. Retag the ones you agree with as `[USER]`, or add a `[USER]` line to override.
- `docs/art/adding-characters.md`: how to add a character sprite with all its facings and animations.
- `docs/style-bible.md`: the template to fill in before the first sprite.
- `game/text/placeholder.csv`: every word the player sees. Replace the caveman text whenever you like.
- `game/data/events.csv`: trail events. See `docs/systems/trail.md` to add one without code.
- `game/data/characters/*.tres` and `game/data/classes/*.tres`: stats, editable in the Godot inspector.
- Combat sandbox: press F9 while the game runs (or open `game/scenes/combat_sandbox.tscn` and press F6). Paint maps, place pieces, turn difficulty dials, restart fights, and run AI-vs-AI balance checks. See `docs/systems/combat.md`.
- `docs/research/tactical-combat.md`: what makes tactics combat fun and how to balance it, with sources.

## For Claude sessions
Read `CLAUDE.md` first, then `docs/context/README.md` (project memory, thread history and published pages exported from the Claude project). Run `tools/check.sh` after every change (set `GODOT` to the Godot binary).
`tools/screenshot.sh` saves a PNG of each screen to `screenshots/`.

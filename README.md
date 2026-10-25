# Lodestone

Tactics RPG meets Oregon Trail. Godot 4, GDScript, 2D. This is the week 1 graybox: shapes only, placeholder text only.

## Play it
1. Install [Godot 4.4](https://godotengine.org/download) (standard build, not .NET).
2. Open Godot, Import, pick `game/project.godot`.
3. Press F5. You start in the village: pick up to 4 party slots, press GO.

The flow is village, trail, fight, back to the trail, and back to the village when everyone falls (or you reach the end). Deaths unlock more of the roster.

## For Brandon
- `docs/decisions.md`: every rule so far. Lines tagged `[AI]` are my proposals. Retag the ones you agree with as `[USER]`, or add a `[USER]` line to override.
- `docs/style-bible.md`: the template to fill in before the first sprite.
- `game/text/placeholder.csv`: every word the player sees. Replace the caveman text whenever you like.
- `game/data/events.csv`: trail events. See `docs/systems/trail.md` to add one without code.
- `game/data/characters/*.tres` and `game/data/classes/*.tres`: stats, editable in the Godot inspector.

## For Claude sessions
Read `CLAUDE.md` first. Run `tools/check.sh` after every change (set `GODOT` to the Godot binary).
`tools/screenshot.sh` saves a PNG of each screen to `screenshots/`.

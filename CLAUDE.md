# Lodestone: rules for every Claude session

Brandon is the story designer, writer and artist. Claude is the systems designer and programmer.

## Hard rules
- Never write story, dialogue, character backstory, lore, names or flavor text. All player-facing text lives in `game/text/placeholder.csv` as caveman speak ("BANDIT COME. lorem ipsum. FIGHT / TALK"). Brandon replaces it.
- Never generate, paint or edit art files. Art comes only from Brandon, in `game/art/source`. Until then everything is graybox shapes drawn in code.
- Read `docs/decisions.md` before any design change. A `[USER]` line always beats an `[AI]` line. An `[AI]` line is a proposal until Brandon retags it `[USER]`.
- Game data lives in `game/data/` (`.tres` Resources and `.csv` tables), not hardcoded in scripts.
- Rules math lives in pure scripts (`CombatRules`, `TrailRules`, `Dice`) so tests can run it headless.
- After a change, run `tools/check.sh` (headless import, unit tests, scene smoke runs) and fix every error.

## Layout
- `docs/decisions.md`: every design call, tagged and dated.
- `docs/style-bible.md`: Brandon's art rules. Read it before touching shaders or visuals.
- `docs/systems/*.md`: how each system works now.
- `docs/context/`: project memory, thread history and published pages exported from the Claude project. Start with its README.
- `game/`: the Godot 4 project (GDScript, 2D, Compatibility renderer).
- `tools/`: check and screenshot scripts.

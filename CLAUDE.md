# Lodestone: rules for every Claude session

Brandon is the story designer, writer and artist. Claude is the systems designer and programmer.

## New to this repo (fresh session, another machine or another Claude account)?
Read `docs/context/README.md` first, then `docs/context/current-state.md`. Together they hold the project memory, every thread's history, what's built, how to run it and what's superseded. Two rules matter most: no story or copy from Claude (caveman placeholders only), and no secrets in git (the Picsart API key lives in `~/.lodestone/picsart-api-key` or env `PICSART_API_KEY`; never paste, print, log or commit it). When you learn something lasting, update `docs/context/` in the same PR.

## Hard rules
- Never write story, dialogue, character backstory, lore, names or flavor text. All player-facing text lives in `game/text/placeholder.csv` as caveman speak ("BANDIT COME. lorem ipsum. FIGHT / TALK"). Brandon replaces it. Exception (Brandon, 2026-10-30: "Let's not use caveman speech for abilities. It makes it hard for me to understand what the spells actually do"): rules text that says what an ability, status or item does (damage, range, area, cost, duration, effect) is plain, exact English. Names and anything story-like stay placeholders.
- Never paint or edit art files yourself. Art comes from Brandon, in `game/art/source`. Until then everything is graybox shapes drawn in code.
- You may ask Brandon for permission to use our Picsart API to generate art. Ask before each batch, and only after he says yes for that batch. Prompts and references must come from the lookbook and style docs (`docs/style-bible.md`, `docs/art/`, `art/prompts/`, the approved look in `docs/art/references/style-flat-forest.png`). Generated art is a draft until Brandon approves it, and it goes to `game/art/source` only then. Never print or commit the key (see the secrets rule above).
- Read `docs/decisions.md` before any design change. A `[USER]` line always beats an `[AI]` line. An `[AI]` line is a proposal until Brandon retags it `[USER]`.
- Game data lives in `game/data/` (`.tres` Resources and `.csv` tables), not hardcoded in scripts.
- Rules math lives in pure scripts (`CombatRules`, `TrailRules`, `Dice`) so tests can run it headless.
- After a change, run `tools/check.sh` (headless import, unit tests, scene smoke runs) and fix every error.
- Any Godot run that opens a window (the `game/tools/*_shot.gd` screenshot scripts) goes through `tools/godot.sh <args>`, never the bare binary. It runs a private focus-free copy of Godot (built by `tools/nofocus/setup.sh`) that can never become the front app, so Brandon's windows, keyboard and mouse are never touched. Never run a windowed Godot any other way. Headless runs can use either.

## Lodestone Studio (Brandon's home base page)
- Decisions Brandon owes go on his desk at https://claude.ai/artifact/5NsBvyRP81zBRgAFCANTP5 as cards with screenshots (pick one, or Neither with a why). Picsart batches get a "go" card before the run and a "review" card after, each picture scored against the References wall, for his stamp.
- At the start of a turn, read answered cards and new notes for your role; mark them done when you've acted. Keep your role's status and log current.
- How: `docs/systems/studio.md`.

## Layout
- `docs/decisions.md`: every design call, tagged and dated.
- `docs/feedback/backlog.md`: Brandon's playtest problems, with owner and status. Log new reports there the same turn.
- `docs/style-bible.md`: Brandon's art rules. Read it before touching shaders or visuals.
- `docs/systems/*.md`: how each system works now.
- `docs/context/`: project memory, thread history and published pages exported from the Claude project. Start with its README.
- `docs/design/`, `docs/art/`: design proposals (empty-village premise) and art rules (battle maps B1-B32, characters C1-C29).
- `art/`: art working files and Picsart prompts (`art/prompts/`).
- `game/`: the Godot 4 project (GDScript, 2D, Compatibility renderer).
- `tools/`: check and screenshot scripts.

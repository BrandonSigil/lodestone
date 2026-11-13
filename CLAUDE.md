# Lodestone: rules for every Claude session

Brandon is the story designer, writer and artist. Claude is the systems designer and programmer.

## New to this repo (fresh session, another machine or another Claude account)?
Read `docs/context/README.md` first, then `docs/context/current-state.md`. Together they hold the project memory, every thread's history, what's built, how to run it and what's superseded. Two rules matter most: no story or dialogue from Claude (caveman placeholders for those; game text is ours, in clear English), and no secrets in git (the Picsart API key lives in `~/.lodestone/picsart-api-key` or env `PICSART_API_KEY`; never paste, print, log or commit it). When you learn something lasting, update `docs/context/` in the same PR.

## Hard rules
- Never write story, dialogue, character backstory, lore, names or flavor text. Those stay caveman placeholders ("BANDIT COME. lorem ipsum. FIGHT / TALK") until Brandon writes them, on the Word Swap page (`docs/systems/word-swap.md`). Everything else the player reads is game text, and we write it in clear, helpful, exact English (Brandon, 2026-11-02: "we only need caveman talk for story and dialogue. Id like for you to write tips and game based text. Spell abilities, tips, screens, should all have good helpful text. Story beats and dialogue stay with me"). That covers ability, status and item rules, tips, tooltips, menus, buttons, screen labels, warnings and tutorials. All player-facing text lives in `game/text/placeholder.csv`.
- Never paint or edit art files yourself. Art comes from Brandon, in `game/art/source`. Until then everything is graybox shapes drawn in code.
- You may ask Brandon for permission to use our Picsart API to generate art. Ask before each batch, and only after he says yes for that batch. Prompts and references must come from the lookbook and style docs (`docs/style-bible.md`, `docs/art/`, `art/prompts/`, the approved look in `docs/art/references/style-flat-forest.png`). Generated art is a draft until Brandon approves it, and it goes to `game/art/source` only then. Never print or commit the key (see the secrets rule above).
- Read `docs/decisions.md` before any design change. A `[USER]` line always beats an `[AI]` line. An `[AI]` line is a proposal until Brandon retags it `[USER]`.
- Game data lives in `game/data/` (`.tres` Resources and `.csv` tables), not hardcoded in scripts.
- Rules math lives in pure scripts (`CombatRules`, `TrailRules`, `Dice`) so tests can run it headless.
- After a change, run `tools/check.sh` (headless import, unit tests, scene smoke runs) and fix every error.
- Any Godot run that opens a window (the `game/tools/*_shot.gd` screenshot scripts) goes through `tools/godot.sh <args>`, never the bare binary. It runs a private focus-free copy of Godot (built by `tools/nofocus/setup.sh`) that can never become the front app, so Brandon's windows, keyboard and mouse are never touched. Never run a windowed Godot any other way. Headless runs can use either.

## Playtest builds: big releases only
Day to day, a change is done when it works in the local Godot project: `tools/check.sh` passes, and screenshots go through `tools/godot.sh`. Don't build Mac or Windows apps for ordinary work, and don't offer to (Brandon, 2026-11-13: "dont ask to make mac/windows apps unless it's a big release. Just have it work on our local godot env"). This replaces his earlier same-day ask to build them at every major milestone.

For a big release, meaning one Brandon calls a release or a build going to friends and family testers:
1. `tools/check.sh` passes.
2. Run `tools/export/build.sh all`. It writes `build/mac/Lodestone.zip` and `build/windows/Lodestone.exe`. Headless Godot needs the Bash sandbox off.
3. Smoke-test the Mac build: unzip it to a scratch folder and run `Lodestone.app/Contents/MacOS/Lodestone --headless --quit-after 300`. It must print only the version line. Any `ERROR` blocks the build, most often a data CSV not imported as "keep".
4. If you built in a worktree, copy both files into `~/lodestone/build/`, which is gitignored. Tell Brandon where they are and what changed since the last build. Never commit builds.

Details are in `docs/systems/player-path.md` under "Feedback notes and builds".

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

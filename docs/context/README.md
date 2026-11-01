# Project context export

Everything about Lodestone that used to live only in Brandon's Claude project (project memory, project instructions, thread history and published pages), copied into the repo so any machine or Claude account starts with the full picture.

Exported 2026-10-27 (PR #12), refreshed 2026-10-27 11:30 UTC after the night's work (flat tile sets, hero sprites, exploration maps, empty-village premise). The repo is the single source of truth from here on: when a thread learns something lasting, update these files (or the docs they point to) in the same PR.

## New here (a friend helping on another Claude account)?
1. `git lfs install`, clone `github.com/BrandonSigil/lodestone`, open `game/project.godot` in Godot 4.4+ (F5 village, F9 combat sandbox, F10 exploration).
2. Point your Claude session at the repo and have it read the files below in order. Brandon's project memory, thread history and published pages are copied here as of the last refresh.
3. Two rules above all: never write story, dialogue, names, lore or flavor text (placeholders are caveman speak like `BANDIT COME. lorem ipsum. [ FIGHT ] [ TALK ]`), and never commit keys (the Picsart key stays in `~/.lodestone/`).

## Read order for a fresh Claude session
1. `CLAUDE.md` (hard rules).
2. This file, then `current-state.md` below (what's built, how to run it, what's in flight, what's superseded).
3. `docs/decisions.md` ([USER] beats [AI]). Open playtest problems and who owns each: `docs/feedback/backlog.md`.
4. `threads.md` for what each past thread did and why.
5. `memory/` for the raw project memory notes, if you need detail.

## What's here
| File | What it is |
| --- | --- |
| `project-instructions.md` | Brandon's standing project rules, as set in the Claude project. |
| `current-state.md` | Where the project stands now, and which older notes are superseded. |
| `threads.md` | One summary per project thread: the ask, what was built, decisions, PRs, open items. |
| `memory/` | Verbatim copy of the project memory files (`MEMORY.md` is the index), as of the refresh. Some lines are out of date; `current-state.md` says which. |
| `artifacts/studio-playbook.html` | "Lodestone Studio Playbook" page: pipeline plan, session map, style bible approach, first six weeks. |
| `artifacts/style-lab.html` | "Lodestone Style Lab" page, latest published version (newer than `docs/style-lab/`). |
| `artifacts/character-guide.html` | "Lodestone Character Guide" page: character / monster / boss sprite spec, templates and the Krita AI workflow. Rules text also lives in `docs/art/characters.md`; rebuilt by `python3 tools/art/char_art.py guide`. |
| `artifacts/battle-map-guide.html` | "Lodestone Battle Map Guide" page, including the Picsart Flow recipe. Rules text also lives in `docs/art/battle-maps.md`. |

Open the HTML files in a browser. They are self-contained except for Google Fonts.

Published originals (Brandon's account only):
- Lodestone Studio (home base: desk, team, references, library; source `tools/studio-page/index.html`): https://claude.ai/artifact/5NsBvyRP81zBRgAFCANTP5
- Master Document (what the game is, the systems pitch, the map pipeline; source `docs/master/index.html`, refreshed at milestones): https://claude.ai/artifact/BDGfifcKtxqWKVJWT1XHFi
- Studio Playbook: https://claude.ai/artifact/YLjyZGiFGzjF819zwAyJTy
- Style Lab: https://claude.ai/artifact/Q3D7yYdUAeS9eEs7cS5XsK
- Battle Map Guide: https://claude.ai/artifact/JjxHePXisJfFFTxoddXjYB
- Character Guide: https://claude.ai/artifact/WWYopuEueYemwfe3qZuVp5

## Never in the repo
- The Picsart API key. It lives at `~/.lodestone/picsart-api-key` (or env `PICSART_API_KEY`) on each machine.
- Story, dialogue, names, lore or flavor text. Brandon writes those; placeholders are caveman speak.

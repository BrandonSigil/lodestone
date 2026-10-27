# Project context export

Everything about Lodestone that used to live only in Brandon's Claude project (project memory, project instructions, thread history and published pages), copied into the repo so any machine or Claude account starts with the full picture.

Exported 2026-10-27. The repo is the single source of truth from here on: when a thread learns something lasting, update these files (or the docs they point to) in the same PR.

## Read order for a fresh Claude session
1. `CLAUDE.md` (hard rules).
2. This file, then `current-state.md` below.
3. `docs/decisions.md` ([USER] beats [AI]).
4. `threads.md` for what each past thread did and why.
5. `memory/` for the raw project memory notes, if you need detail.

## What's here
| File | What it is |
| --- | --- |
| `project-instructions.md` | Brandon's standing project rules, as set in the Claude project. |
| `current-state.md` | Where the project stands now, and which older notes are superseded. |
| `threads.md` | One summary per project thread: the ask, what was built, decisions, PRs, open items. |
| `memory/` | Verbatim copy of the project memory files (`MEMORY.md` is the index). Some lines are out of date; `current-state.md` says which. |
| `artifacts/studio-playbook.html` | "Lodestone Studio Playbook" page: pipeline plan, session map, style bible approach, first six weeks. |
| `artifacts/style-lab.html` | "Lodestone Style Lab" page, latest published version (newer than `docs/style-lab/`). |
| `artifacts/battle-map-guide.html` | "Lodestone Battle Map Guide" page, including the Picsart Flow recipe. Rules text also lives in `docs/art/battle-maps.md`. |

Open the HTML files in a browser. They are self-contained except for Google Fonts.

Published originals (Brandon's account only):
- Studio Playbook: https://claude.ai/artifact/YLjyZGiFGzjF819zwAyJTy
- Style Lab: https://claude.ai/artifact/Q3D7yYdUAeS9eEs7cS5XsK
- Battle Map Guide: https://claude.ai/artifact/JjxHePXisJfFFTxoddXjYB

## Never in the repo
- The Picsart API key. It lives at `~/.lodestone/picsart-api-key` (or env `PICSART_API_KEY`) on each machine.
- Story, dialogue, names, lore or flavor text. Brandon writes those; placeholders are caveman speak.

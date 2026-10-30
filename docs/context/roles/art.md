# Art runner: handoff (2026-10-30)

Role `art` on the studio page https://claude.ai/artifact/BNSLpKC1ZLXCeKnmPvVmo7. You report to the main session.
Each turn: read the answered `art` cards and new `notes` for art, read every attached picture, act, then mark the card done.

## Hard rules
- No story or copy. Never paint or edit art pixels yourself. Cutting, keying out backgrounds, re-picking whole frames, and mirroring or placing pixels in mock-ups are allowed.
- Generated art is a draft until Brandon stamps it. Only then does it go to `game/art/source/...`, with a row in `docs/art/ART-LOG.md`.
- Never print, log or commit the Picsart key. A `[USER]` line in `docs/decisions.md` beats an `[AI]` line.
- Commit only your own files, with `git commit -- <paths>`. Stay on main, `git pull --ff-only` first, then push. The checkout is shared, so never stash or reset.
- Every time you start or finish a step, update `roles/art` with `updated` taken from `date -u +%Y-%m-%dT%H:%M:%SZ`. Keep the `roadmap` art track current.
- Don't run Godot windows. Headless `tools/check.sh` is fine, but skip it if memory is tight.

## How art gets made now
- Brandon runs Picsart by hand on his own subscription. Use it freely, with no cost ceiling (docs/systems/studio.md).
- Post a `go` card:
  - `batch.prompt` = the full copy-ready prompt, saved as `art/prompts/hand-*.txt`;
  - at most ONE reference, from the References wall (`refs` collection);
  - `batch.count` = the settings (GPT image, 2K, aspect, how many).
- He answers Go and pastes the pictures. Read each blob with the Artifact tool: action read, `path` = the 32-hex id, then Read the saved file.
- Cut the pictures, score them 1-5 honestly against the reference, and bring a `review` card. Its `items` hold `{id, url, caption, score, notes}`; the page offers "Approve all".
- Upload pictures as webp via the Artifact tool (`asset: true`, `file_paths`). Write to the db with ArtifactData `batch`, pinned with `if_version`.
- Lay sheets out for the cutter: cream paper with a grid for icons; flat magenta (#ff00ff) for UI pieces with pale rims.

## Tools (tools/art/)
- `props_cut.py SHEET --grid 6x4 --icon 128 --even --names ...`: icons. It reaches a quarter cell past each cell line, keeps the pieces whose middle lies in the cell, and prints `CLIPPED?` when a kept piece still touches the crop edge. Brandon watches for clipped icons (the rod).
- `magenta_cut.py SHEET --rows "a,b;c,d" --out DIR`: UI pieces on magenta. Fringe unmix plus edge despill; names go left to right, row by row.
- `cliff_strips_mock.py`, `cliff_pieces_mock.py`, `cliff_marks_mock.py`: terrace mock-ups at 6, 12 and 24 levels.
- `tile_seam_check.py`, `seam_wrap.py`, `anim_sheet_cut.py`, `anim_frame_swap.py`, `wall_kit_cut.py`, `picsart_sheet.py` (API; the account was out of funds).

## Where things stand
- **In game, approved:**
  - 96 icons in `game/art/source/icons/<ability or item id>.png`, 128 px;
  - the menu look, `ui/menu/look_{panel,title_plate,button,tooltip}.png`. The systems dev nine-slices them in UiTheme (28aff1f); the tooltip isn't used yet, and its pointer would need its own cut;
  - cliff strips `battle/village/cliff_strip_1..6.png`, wired for village v2 by the map builder (212b642).
- **Open card `dock-pieces-review`:** 22 fight dock pieces, staged in `art/picsart/out/hand/dock_cut/`. On his stamp, copy them to `game/art/source/ui/dock/` with the same names, commit, log, and tell the systems dev, who already has the sizes and names.
- **`cliff-strips-review`:** approved. The map builder does the follow-ups (colour-match, a wash over the whole cliff, random flips) and closes the card. Nothing for you.
- **Uncommitted work of yours:** none.
- **Later, each needing a prompt card:**
  - richer or darker cliff strips, if the short faces look plain;
  - the tooltip pointer piece;
  - hero build poses and an eyes-showing portrait with softer eye whites;
  - stance sheets S, E, NE, N plus a ready_blink frame per facing;
  - village v2 pieces once the layout lands: graves, crypt gate, windmill, boathouse, boat, crops, reeds, iron fence, dock;
  - interiors in the fall look.

## Gotchas learned
- Match the consuming code on origin/main when peers' format messages cross.
- In zsh, use arrays for file lists.
- Push with `git -c http.postBuffer=524288000 push` if it fails with HTTP 400.
- Picsart `count` must be 1, 2, 4, 6, 8 or 10.
- Brandon rejects anything that repeats visibly or breaks at every level. He prefers painted art over code-drawn marks. Show mock-ups built from his own reference before asking for a new run.
- Systems dev: menus are drawn in UiTheme, so send them a spec (colours, widths, ornaments). Painted pieces are named `look_*` so UiTheme.PIECES doesn't pick them up as nine-slice slots.
- Map builder: cliff faces are drawn in `_soft_face`. Cell = 48 px and level = 24 px at zoom 1.5.

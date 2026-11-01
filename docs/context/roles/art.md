# Art runner: handoff (2026-11-01)

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

## Where it stands (2026-11-01)
- **Picsart is on hold** while Brandon playtests. Post no new `go` cards unless he or the PM asks.
- **Latest prompt:** the hex world map mockup, `art/prompts/hand-world-hex-mockup.txt` (desk card `pm-world-hex-prompt`), with its grey hex block-out guide (759bf27). He runs it by hand; when pictures come back, cut, score and bring a `review` card.
- **In game, approved:** 96 icons (`game/art/source/icons/`, 128 px); the menu look `ui/menu/look_*.png` (nine-sliced in UiTheme); cliff strips `battle/village/cliff_strip_1..6.png`.
- **Check the desk:** `dock-pieces-review` (22 fight dock pieces staged in `art/picsart/out/hand/dock_cut/`, moved to `game/art/source/ui/dock/` only on his stamp) may still be open; the art log is `docs/art/ART-LOG.md`.
- **Later, each needing a prompt card:** richer cliff strips; tooltip pointer piece; hero build poses and an eyes-showing portrait; stance sheets S, E, NE, N plus ready_blink; village v2 pieces (graves, crypt gate, windmill, boathouse, crops, reeds, fence, dock); interiors; tile art for forest roads and farmland.
- Uncommitted work of yours: none.

## Gotchas learned
- Match the consuming code on origin/main when peers' format messages cross.
- In zsh, use arrays for file lists.
- Push with `git -c http.postBuffer=524288000 push` if it fails with HTTP 400.
- Picsart `count` must be 1, 2, 4, 6, 8 or 10.
- Brandon rejects anything that repeats visibly or breaks at every level. He prefers painted art over code-drawn marks. Show mock-ups built from his own reference before asking for a new run.
- Systems dev: menus are drawn in UiTheme, so send them a spec (colours, widths, ornaments). Painted pieces are named `look_*` so UiTheme.PIECES doesn't pick them up as nine-slice slots.
- Map builder: cliff faces are drawn in `_soft_face`. Cell = 48 px and level = 24 px at zoom 1.5.

## Studio rules
- The Studio page is https://claude.ai/artifact/BNSLpKC1ZLXCeKnmPvVmo7 (this account). Desk card text is a short lead line, a blank line, then "- " bullets with **bold** labels, never one long paragraph. Use real newlines.
- One review card per feature or job, not one per commit.
- Run long checks in the foreground or wait for them; never end a turn with work unpushed. Commit, rebase onto origin/main, push, and confirm with `git log origin/main`.
- Model: dev on Opus at medium effort; design, builder, playtest and art on Sonnet.

- **One picture, one prompt** ([USER] 2026-11-01: "append all references images into one image with labels. That way I just send 1 image and 1 prompt"): every Picsart prompt card ships one labelled reference board (see `tools/art/char_board.py`, `tools/art/world_board.py`), and the prompt names the panels by their labels.

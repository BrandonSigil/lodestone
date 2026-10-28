# Art log: what we've made, where it lives, what's approved

Read this first when someone asks "what art do we have?" Update it in the same PR as any new art batch, one row per batch. Status words: **approved** (Brandon said yes), **draft** (generated or built, waiting on Brandon), **reference** (look only, never shipped), **archived** (superseded, kept on file).

## Where the files live

| Kind | Where | In git? |
| --- | --- | --- |
| Game-ready art | `game/art/source/` (battle sets, looks, explore) | Yes |
| Style references and examples | `docs/art/references/` | Yes |
| Prompts | `art/prompts/` | Yes |
| Procreate templates and palettes | `art/templates/`, `art/palettes/` | Yes |
| Archived drafts | `art/picsart/archive/` | Yes |
| Generation runs (every Picsart output) | `art/picsart/out/` | **No**, ignored (about 320 MB, local to the Mac that made them) |
| Hades-era concepts, look references | `art/picsart/out/hades-concepts/` | **No**, local only |

Generation scripts live in `tools/art/` (`picsart_surround.py`, `picsart_village.py`, `kit_cut.py`, `battle_art.py`, `char_sheet.py`, and others). Each run is reproducible from its prompt file in `art/prompts/`.

The generated outputs are not in git, so a second machine can't see them. The repo only holds what was cut into `game/art/source/` or referenced here. Google Drive is not set up; see "Backups" below.

## Where the Picsart files are

- **Generated outputs, one folder:** `art/picsart/out/` (137 files, about 320 MB). Every batch lands here. `art/picsart/out/INDEX.md` lists each file by batch, with size, date and whether git tracks it. Rebuild it with `python3 tools/art/index_picsart.py` after a batch.
- **Inputs and tooling, tracked in git:** `art/picsart/kit/` (tile-kit raw sheets), `art/picsart/prompts/` (kit, map and negative prompts), `art/picsart/archive/` (archived plates), and the two contact sheets in `art/picsart/`. Tools read these paths, so they stay where they are.
- **Cut pieces the game uses:** `game/art/source/`.
- **Duplicate copy:** a second worktree at `~/lodestone-backdrop` (branch `backdrop-surround`) holds 44 of the same outputs. Every file there is already in `art/picsart/out/`, so the worktree can go.

## Status by piece

| Piece | Where | Made with | Status | Notes |
| --- | --- | --- | --- | --- |
| Flat forest style panel | `docs/art/references/style-flat-forest*.png` | Brandon's own work | **approved** | The style reference for tiles and plates. |
| Flat zone tile sets (forest, snow, ruins, dungeon, farmland, marsh, canyon, crystal) | `game/art/source/battle/<set>/` | Picsart GPT image, cut by `kit_cut.py` | draft | In use in battle; Brandon hasn't signed them off. |
| Village tiles and props | `game/art/source/battle/village*/`, `art/picsart/out/village/` | Picsart, `picsart_village.py` | draft | About $1.57; awaiting approval (current-state). |
| Lead hero sprite (all facings and anims) | `game/art/source/` sheets, `art/picsart/out/anim-lead-*`, `stance-lead-*` | Picsart, `char_sheet.py` | draft | Placeholder until Brandon approves. |
| Skyline (base) | `game/art/source/battle/skyline.png` | Picsart, `picsart_surround.py` | draft | Stand-in for the wallpaper test. |
| Skyline (village) | `game/art/source/battle/village/skyline.png` | Picsart, `picsart_surround.py` | draft | Stand-in for the wallpaper test. |
| Foreground treeline (village) | `art/picsart/out/surround/foreground_village.png` | Picsart, `picsart_surround.py` | draft, local only | Test piece for the navy trees. |
| Island backdrop plates (snow, ruins, village_in) | `art/picsart/archive/plates/` | Picsart, `picsart_surround.py` | **archived** | Island pictures; the wallpaper replaces them. |
| Wallpaper and silhouette trees | Built in code from existing sprites | Godot code | in use | No new art. |
| Key art sampler v1 to v10 | `art/picsart/out/key-art-sampler/`, `docs/art/characters/` | Picsart, Studio | v10 passes checks | Not approved. |
| Hades look concepts (ring, mountain, cutaway, shade) | `art/picsart/out/hades-concepts/` | Picsart | **reference** | Look only, never shipped; local only. |
| Surround examples (crypt, snow) | `docs/art/references/surround-*-example.png` | Picsart | reference | Mood examples for the wallpaper. |
| Temple and zone test kits | `art/picsart/out/temple_*`, `kit_*`, `zones-*` | Picsart tests | **archived** | Early tests; kept for comparison. |

## Batch log

Add a row for each new batch: date, tool, prompt file, model, count, cost if known, and who approved it.

| Date | Batch | Tool | Prompt | Model | Count | Cost | Approved by |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-10-27 | Flat forest and snow tile kits | `tools/art/` kit scripts | `art/prompts/sheet-tile-kit.txt`, `style-tiles.txt` | GPT image (Picsart) | not recorded | not recorded | Brandon (the flat style) |
| 2026-10-27 | Village props and buildings | `picsart_village.py` | `art/prompts/style-props.txt` | GPT image (Picsart) | not recorded | about $1.57 (current-state) | pending |
| 2026-10-27 | Lead hero sheets, six sheets | `char_sheet.py` | `art/prompts/sheet-character-*.txt` | GPT image (Picsart), 1K | 6 | $0.57 (decisions) | pending |
| 2026-10-28 | Skyline and foreground treeline tests | `picsart_surround.py` | inline in the script | GPT image (Picsart) | not recorded | not recorded | pending |
| 2026-10-28 | Island backdrop plates (snow, ruins, village_in) | `picsart_surround.py` | inline in the script | GPT image (Picsart) | 3 | not recorded | archived |

## Rules

- Nothing goes into `game/art/source/` until Brandon approves it. `CLAUDE.md` requires that for generated art.
- Every generation batch needs a row here and a prompt file in `art/prompts/`, so it can be rerun.
- Record counts and costs as they're known. Write "not recorded" rather than guessing.

## Backups

The generated outputs exist only on the Mac that made them. Options, in order of effort:

1. Keep `art/picsart/out/` on the Mac and copy it to an external drive or a cloud folder by hand, once a week.
2. Put the folder in Google Drive, shared with Brandon. This needs Brandon's go-ahead and a connected Drive; uploading is outward-facing, so I won't do it without that.
3. Commit only the approved pieces to git, with Git LFS, when they're final.

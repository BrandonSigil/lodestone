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
- **Duplicate copy:** removed. The second worktree at `~/lodestone-backdrop` held 44 copies of files that are already in `art/picsart/out/`.

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
| UI frame v1 (flat bands, round medallion) | `art/picsart/out/ui-frame/ui-frame_v1.png` | Brandon in Picsart, `art/prompts/ui-frame.txt` | **archived**, local only | Superseded by the leaf look (`ui-frame-leaf-reference.png`). |
| UI frame mock-up and shrine concept | `docs/art/references/ui-frame-mockup.png`, `ui-frame-shrine-concept.png` | Brandon | **reference** | Earlier ideas, kept on file; the shrine centre was dropped for the diamond. Never attach them to a frame prompt (models copy them). |
| UI frame leaf reference | `docs/art/references/ui-frame-leaf-reference.png` | Brandon | **reference** | The look for the frame (thin green bands, leaves, blue diamonds); `ui-frame.txt` uses it as image 1. |

## Batch log

Add a row for each new batch: date, tool, prompt file, model, count, cost if known, and who approved it.

| Date | Batch | Tool | Prompt | Model | Count | Cost | Approved by |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-10-27 | Flat forest and snow tile kits | `tools/art/` kit scripts | `art/prompts/sheet-tile-kit.txt`, `style-tiles.txt` | GPT image (Picsart) | not recorded | not recorded | Brandon (the flat style) |
| 2026-10-27 | Village props and buildings | `picsart_village.py` | `art/prompts/style-props.txt` | GPT image (Picsart) | not recorded | about $1.57 (current-state) | pending |
| 2026-10-27 | Lead hero sheets, six sheets | `char_sheet.py` | `art/prompts/sheet-character-*.txt` | GPT image (Picsart), 1K | 6 | $0.57 (decisions) | pending |
| 2026-10-28 | Skyline and foreground treeline tests | `picsart_surround.py` | inline in the script | GPT image (Picsart) | not recorded | not recorded | pending |
| 2026-10-28 | Snow kit v2, three 2K sheets (a, b, c) | `picsart_sheet.py` | `art/prompts/snow-kit-v2.txt` | GPT image (Picsart) | 3 sheets, 75 cells | $0.14272 each, $0.42816 total | Brandon (approved the batch) |
| 2026-10-28 | Snow kit v3, one 2K sheet: flat square tops, detail budget, island cliffs | `picsart_sheet.py` | `art/prompts/snow-kit-v3.txt` | GPT image (Picsart) | 1 sheet, 25 cells | $0.14272 | Brandon (asked for one sheet) |
| 2026-10-28 | Snow sides and props v4, one 2K sheet (3:2, 15 cells, no tops) | `picsart_sheet.py` | `art/prompts/snow-sides-props-v4.txt` | GPT image (Picsart) | 1 sheet | $0.09452 | Brandon (asked for the sheet) |
| 2026-10-28 | Snow props variants v1, one 2K sheet (3:2, 15 props, no ground patch) | `picsart_sheet.py` | `art/prompts/snow-props-variants-v1.txt` | GPT image (Picsart) | 1 sheet | $0.09452 | Brandon (asked for the regen with variants) |
| 2026-10-28 | Island backdrop plates (snow, ruins, village_in) | `picsart_surround.py` | inline in the script | GPT image (Picsart) | 3 | not recorded | archived |

## Removed, replaced with placeholders (approved 2026-10-28)

These were cut from Picsart and are not isometric, so they came out of the game. Each slot now holds a grey placeholder drawn by script, labelled with its name. The originals are in `art/picsart/archive/removed/`.

| Slot in game | Original | Why |
| --- | --- | --- |
| `battle/village/prop_bench.png` | village-prop_bench.png | flat-on, not 2:1 |
| `battle/village/prop_planter.png` | village-prop_planter.png | flat-on, not 2:1 |
| `battle/village/prop_cart.png` | village-prop_cart.png | flat-on, not 2:1 |
| `battle/village/prop_ruin.png` | village-prop_ruin.png | flat-on, not 2:1 |
| `battle/ruins/prop_ruin.png` | ruins-prop_ruin.png | flat-on, not 2:1 |
| `battle/snow/prop_ruin.png` | snow-prop_ruin.png | flat-on, not 2:1 |

## Draft, not run

| Draft | File | Status |
| --- | --- | --- |
| Painterly snow tile kit v2: 25 cells, island-style cliffs, seamless tops, mapped to the snow folder's file names | `art/prompts/snow-kit-draft.txt` | waiting on Brandon's review and cost check |

**Seam check (read-only):** `tools/art/tile_seam_check.py` scores whether a top tile repeats. Every current top tile in `game/art/source/battle/` fails it (ratios 2 to 6, pass is 1.6 or less), so none of the existing tops repeat cleanly. The check was tested on a periodic test tile (passes) and a cut one (fails).

**Snow kit v2 result (not cut):** the three sheets came back at 2048 px. `kit_cut.py` cut none of them. Sheets a and c draw the tops as isometric diamonds, and sheet b draws them as 3D blocks, so none of the tops is a flat square texture that the seam check or the engine can repeat. Sides and props are usable as art, but the cutter needs a diamond-aware layout. Outputs are in `art/picsart/out/snow-batch-v1/`.

## Source-of-truth checks (read-only)

Both run on any candidate before it can be cut into the game. Neither edits art.

- `tools/art/tile_seam_check.py`: does a top tile repeat? Pass is 1.6 or below on both edges. Every current top in `game/art/source/battle/` fails.
- `tools/art/style_check.py`: how busy is a picture? It measures texture share (pixels in small-scale texture) and colour count.

Measured 2026-10-28:

| Picture | Texture | Verdict at 0.38 |
| --- | --- | --- |
| Flat-forest references (Brandon's approved style) | 0.31 to 0.37 | ok |
| Key art sheet `00-reference-sheet.png` | 0.35 | ok |
| Snow island plate (the cliffs Brandon likes) | 0.41 | busier |
| Snow kit v2 sheets a, b, c | 0.45 to 0.46 | busier |

**Open decision for Brandon:** the bar. At 0.38 the island plate Brandon likes is also flagged. A bar near 0.42 would keep the island's painterly look and still reject the sheets. Brandon set `TEXTURE_BAR` to 0.42 on 2026-10-28.

**Prompt fixes to test before the next batch:** a texture budget (flat fills, one or two marks per tile, no speckle on props), and a reject rule for any tile above the bar.

**Snow kit v3 result (staging only, not in the game):** the sheet is flat square tiles, and every cell passes the 0.42 busyness bar (0.03 to 0.20). The cutter could not find the grid, so the cells were cut on the fixed 5 x 5 grid into `art/picsart/out/snow-batch-v2/cut/`. All ten tops still fail the seam check (ratios 5 to 110), so none of the tops can repeat yet. Sides and props pass the busyness check and need your visual review.

**Snow sides and props v4 result (staging only):** five sides with a built-in snow cap, five props in 2:1 view, five more props. All 15 pass the busyness check (0.13 to 0.23). Props sit on a flat white diamond base, which needs a look in game. Cut into `art/picsart/out/snow-batch-v5/cut/`. Tops stay code-drawn (`code_tops.py --style watercolour`).

**Snow props variants v1 result (staging only):** five pines, three bushes, two boulders, crystals, pillar, spire, arch, stump, with no ground patch and an outline round every tip. Cut by `tools/art/props_cut.py` (finds rows and props from the paper gaps, keys the paper, clears enclosed paper, 256 px tall) into `art/picsart/out/snow-batch-v6/cut/`. `game/data/battle_art_snow.csv` lists the variants so cells pick among them, and turns the engine lip off for snow. Tested in the battle view with the code tops (v4, now with forest and path tops) and the v5 sides; not yet in `game/art/source/`.

**Approved 2026-10-28 (Brandon), moved into `game/art/source/battle/snow/`:** code-drawn watercolour tops (`top_grass`, `top_grass_b`, `top_stone`, `top_water`, `top_forest`, `top_road`), the v5 sides (`side_cliff`, `side_cliff_b`, `side_masonry`, `side_water`, `side_hazard`) and the v6 props (five pines, three bushes, two boulders, crystals, pillar, spire, arch, stump). The arch replaces the grey `prop_ruin` placeholder in the snow set. `top_hazard`, `top_rock`, `top_special`, `top_stone_b`, `prop_brazier` and `prop_crate` are still the older snow art.

## Rules

- Nothing goes into `game/art/source/` until Brandon approves it. `CLAUDE.md` requires that for generated art.
- Every generation batch needs a row here and a prompt file in `art/prompts/`, so it can be rerun.
- Record counts and costs as they're known. Write "not recorded" rather than guessing.

## Backups

The generated outputs exist only on the Mac that made them. Options, in order of effort:

1. Keep `art/picsart/out/` on the Mac and copy it to an external drive or a cloud folder by hand, once a week.
2. Put the folder in Google Drive, shared with Brandon. This needs Brandon's go-ahead and a connected Drive; uploading is outward-facing, so I won't do it without that.
3. Commit only the approved pieces to git, with Git LFS, when they're final.

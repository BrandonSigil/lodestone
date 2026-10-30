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
| Lodestone logo | `art/brand/lodestone-logo.webp` (transparent background) | Brandon's own work | **approved** | Brandon, 2026-10-29. Sits on parchment `#ece6d4` at the top of the studio page. |
| Flat zone tile sets (forest, snow, ruins, dungeon, farmland, marsh, canyon, crystal) | `game/art/source/battle/<set>/` | Picsart GPT image, cut by `kit_cut.py` | draft | In use in battle; Brandon hasn't signed them off. |
| Village tiles and props (first set) | `art/picsart/out/village/`; `village_in/` still in the game | Picsart, `picsart_village.py` | **archived** for the town (2026-10-29), replaced by the fall set; the interiors still use `village_in` | About $1.57. |
| Fall village set | `game/art/source/battle/village/` | code tops (`code_tops.py --biome village_fall`), Picsart sides, props, foliage, four homes; smithy, tavern and town hall cut from the v2 look sheet as stand-ins | **approved** (Brandon, 2026-10-29: "replace the town assets") | Run sheet B and the home B / C re-roll next. |
| Lead hero sprite (all facings and anims) | `game/art/source/` sheets, `art/picsart/out/anim-lead-*`, `stance-lead-*` | Picsart, `char_sheet.py` | draft; stance SE **approved** | Brandon 2026-10-29 (studio review): stance SE approved; anim SE, NE, S to redo with his eyes showing and a blink frame. Prompt updated (eyes, a fifth idle frame for the blink, line art); animation v2 (eyes, blink) **approved** in all five facings 2026-10-29 ("Love it send it"; he doesn't fully love the whites of the eyes on some frames, a later tweak) and cut into the game, with a one-frame `blink` strip per facing. Stance sheets other than SE are still v1 (eyes hidden). |
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
| River Village fall sheet and fall moodboard | `docs/art/references/village-fall-style-sheet.png`, `village-fall-moodboard.png` | Brandon's pick (generated elsewhere) | **reference** | The fall feel for the village; simplify toward the zones sampler (`picsart/zones-gpt-simple_v1.png`). |
| UI frame mock-up and shrine concept | `docs/art/references/ui-frame-mockup.png`, `ui-frame-shrine-concept.png` | Brandon | **reference** | Earlier ideas, kept on file; the shrine centre was dropped for the diamond. Never attach them to a frame prompt (models copy them). |
| UI frame leaf reference | `docs/art/references/ui-frame-leaf-reference.png` | Brandon | **retired** (2026-10-30) | The full-border look (thin green bands, leaves, blue diamonds). The game now uses only the bottom band, `game/art/source/ui/frame_bottom.webp`; the side and top bands and the grey full-border layout are retired. |
| Bustling city layout | `docs/art/references/city-bustle-street.webp`, `city-bustle-overview.webp` | Brandon | **reference** | 2026-10-29: layout target for the city prototype (tight winding streets, stairs up onto roofs, houses on bridges you walk under). Layout only: never attach to a Picsart prompt. |
| Character sheet layout | `docs/art/references/character-sheet-layout.webp` | Brandon | **reference** | 2026-10-30: layout target for the character sheet (Fire Emblem style: portrait, level, stats, four moves). Layout only: never attach to a Picsart prompt. |
| Interior walls target | `docs/art/references/interior-walls-target.webp` | Brandon | **reference** | 2026-10-30: the look for interior back walls (plaster, timber posts, window, doorway) and the floor. Our own floor edge tile stays. A guide for the interior and dungeon wall kits. |
| Village v2 layout | `docs/art/references/village-v2-layout.webp` | Brandon | **reference** | 2026-10-30: layout target for the second village build (winding roads, terraces, ruins and cemetery top left, lake and dock bottom left). Layout only: never attach to a Picsart prompt; the look stays our fall set. |
| Icon style (props sheet) | `docs/art/references/icon-style-props.webp` | Brandon | **reference** | 2026-10-30: the look for spell and item icons: soft painted props (bush, rock, crate, lantern, leaf, trees, pillar, standing stone) on a cream grid. Style reference for the icon sheets. |
| Menu label style | `docs/art/references/menu-label-forest.png`, `menu-label-river-marsh.png`, `menu-label-snowy-highlands.png` | Brandon | **reference** | 2026-10-30: hand-drawn ink-outlined name plates. Brandon wants menus a bit less informal than these, with a simpler but ornate border to match the game frame. Look reference for the menu style pitch. |
| UI frame, bottom band | `game/art/source/ui/frame_bottom.webp` (2000 x 261, transparent above) | Brandon | **approved** | Brandon, 2026-10-29: goes along the bottom of the player screen; left square = inventory button, right panel = party and health. |

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
| 2026-10-29 | Fall buildings sheet B with line art: smithy, tavern, town hall (`art/picsart/out/village-fall/buildings_b_v1.png`, cut into `cut/b_smithy`, `b_tavern`, `b_townhall`; all pass the busyness bar; town hall turned its gable to the camera, left wall 0.62) | `picsart_sheet.py` | `art/prompts/village-fall-buildings-big.txt` | GPT image (Picsart), 2K | 1 sheet, 3 buildings | $0.09452 | go: Brandon (studio card `fall-sheet-b`); results on review card `fall-buildings-line-review`: smithy and tavern redo, town hall rejected |
| 2026-10-29 | Homes B and C re-roll, 4 x 3, with line art (`buildings_long_v1.png`, cut into `cut/b_home_b`, `b_home_c`, left wall 0.59 and 0.60; the old square cuts kept as `b_home_*_square.png`) | `picsart_sheet.py` | `art/prompts/village-fall-buildings-long.txt` | GPT image (Picsart), 2K | 1 sheet, 2 buildings | $0.09452 | go: Brandon (studio card `homes-bc`); review `fall-buildings-line-review`: home B rejected (reads like a manor), home C redo. Next: the guided flow (`village-fall-building-guided.txt`), go card `fall-buildings-guided-go` |
| 2026-10-29 | Lead hero animation sheets v2, all five facings: eyes showing, fifth idle frame with the eyes shut (`art/picsart/out/anim-lead-<dir>_v2.png`, cut into the game after his stamp) | `char_sheet.py` | `art/prompts/sheet-character-anim.txt` | GPT image (Picsart), 1K | 5 sheets | $0.2744 | go: Brandon (studio card `lead-anim-v2-go`); approved by Brandon on review card `lead-anim-v2-review`, cut into `game/art/source/characters/lead/` |
| 2026-10-29 | Fall buildings, guided: home B, home C, smithy, tavern, town hall, each painted over a game-grid block-out (`art/templates/buildings/guide_*.png`), two tries each (`art/picsart/out/village-fall/guided/guided_<name>_v1/_v2.png`, cuts in `guided/cut_v1`, `cut_v2`). All sit on their footprints, doors taller than the hero, all under the busyness bar. Picks: home B v2, home C v1, smithy v2, tavern v2, town hall v1. Brandon 2026-10-29: smithy **approved** (in `game/art/source/battle/village/b_smithy.png`, copy in `village-fall/approved/`); the other four redo single storey, less generic, east windows (direction card `fall-buildings-direction`) | `picsart_sheet.py` | `art/prompts/village-fall-building-guided.txt` (asks in `-asks.txt`) | GPT image (Picsart), 2K, 1:1 | 10 pictures | $1.4272 (14.3 cents a square 2K picture) | go: Brandon (studio card `fall-buildings-guided-go`); results on review card `fall-buildings-guided-review` |
| 2026-10-29 | Fall buildings, rooted in the land (Brandon's pick): home B, home C, tavern 6 x 4, town hall 7 x 5, single storey over the new block-outs, two tries each (`guided/rooted_<name>_v1/_v2.png`, cuts in `guided/rooted_cut_v1`, `rooted_cut_v2`). All on their footprints, doors taller than the hero; every stone drawn, so texture 0.29 to 0.47 (home C try 1 and tavern try 1 over the bar). Picks: home B v2, home C v2, tavern v2, town hall v1. Brandon 2026-10-29: homes B and C **approved** (in `game/art/source/battle/village/b_home_b.png`, `b_home_c.png`); tavern and town hall redo with roofs a bit more curved and less steep (go card `fall-buildings-curve-go`) | `picsart_sheet.py` | `art/prompts/village-fall-building-guided.txt` (rooted look) | GPT image (Picsart), 2K, 1:1 | 8 pictures | $1.14176 | go: Brandon (studio card `fall-buildings-rooted-go`, ceiling $1.20); results on review card `fall-buildings-rooted-review` |
| 2026-10-29 | Tavern 6 x 4 and town hall 7 x 5 redo with curved, lower roofs and fewer, bigger stones (`guided/curve_<name>_v1/_v2.png`, cuts in `guided/curve_cut_v1`, `curve_cut_v2`). On their footprints, all under the busyness bar (0.32 to 0.39). Picks: tavern v1, town hall v1. Brandon 2026-10-29: both **approved** (in `game/art/source/battle/village/b_tavern.png`, `b_townhall.png`); the map builder moves them to their new 6 x 4 and 7 x 5 footprints | `picsart_sheet.py` | `art/prompts/village-fall-building-guided.txt` (rooted look, curved roofs) | GPT image (Picsart), 2K, 1:1 | 4 pictures | $0.57088 | go: Brandon (studio card `fall-buildings-curve-go`, ceiling $0.60); results on review card `fall-buildings-curve-review` |
| 2026-10-30 | Hero once per weapon build for the smithy rack character sheets: sword, two daggers, bow and quiver, book and spark, SE, eyes showing, two tries (`art/picsart/out/builds/builds_lead_v1/_v2.png`, cuts at painted size in `builds/cut_v1`, `cut_v2`). Pick v2 (bolder line art); texture 0.47, over the bar; the sword pose keeps a second sword sheathed on his back. Portrait: no Picsart (Brandon: zoom in on existing art); two crops on the card, one from the key art, one from the v2 poses with his eyes showing | `picsart_sheet.py`, `props_cut.py --scale 1` | `art/prompts/sheet-character-builds.txt` | GPT image (Picsart), 2K, 3:2 | 2 pictures | $0.18904 | go: Brandon (studio card `hero-builds-go`, ceiling $0.48); review `hero-builds-review` 2026-10-30: key art portrait **approved** (`game/art/source/portraits/lead.png`); the four poses **in use for now, redo later** (`game/art/source/characters/lead/lead_build_<job>.png`; Brandon doesn't like the whites of the eyes), the eyes-showing portrait crop redo later for the same reason |
| 2026-10-30 | Interior wall kit, flat textures for the board's wall kits (0f2070c): plaster, worn plaster, timber, window, doorway, wall-top beam, plank floor, worn planks, floor edge; two tries (`art/picsart/out/wall-kits/wallkit_interior_v1/_v2.png`), cut by `wall_kit_cut.py` into `cut_interior_v1`, `_v2`; repeating pieces made seamless by `seam_wrap.py`, picked set in `final_interior/`. Pick v1. The timber piece came out as a post on plaster | `picsart_sheet.py` | `art/prompts/sheet-wall-kit.txt` (interior ask) | GPT image (Picsart), 2K, 1:1 | 2 pictures | $0.28544 | go: Brandon (studio card `wall-kit-interior-go`, ceiling $0.30); all nine **approved** 2026-10-30 (review `wall-kit-interior-review`), in `game/art/source/battle/village_in/` (`wall_*.png`, and `top_stone`, `top_stone_b`, `side_masonry` replace the interior floor) |
| 2026-10-30 | Dungeon wall kit in the stone of Brandon's dungeon pictures (`docs/art/references/dungeon-walls-target-1.png`, `-2.png`: big pale blocks, arches, short thick front walls, tall back walls): plain, cracked, corner pillar, arched doorway, capping, footing, flags, worn flags, floor edge; two tries (`wallkit_dungeon_v1/_v2.png`), cuts in `cut_dungeon_v1`, `_v2`, picked set in `final_dungeon/`. Pick v1. Courses don't line up between pieces; the pillar sits on wall | `picsart_sheet.py` | `art/prompts/sheet-wall-kit.txt` (dungeon ask) | GPT image (Picsart), 2K, 1:1 | 2 pictures | $0.28544 | go: Brandon (studio card `wall-kit-dungeon-go`, ceiling $0.30); all nine **approved** 2026-10-30 (review `wall-kit-dungeon-review`), in `game/art/source/battle/dungeon/` (`wall_*.png`, and `top_stone`, `top_stone_b`, `side_masonry` replace the dungeon floor) |
| 2026-10-30 | The dog's reference sheet: Brandon's corgi (`docs/art/references/dog-corgi.png`) in a faded brick-red cloak, five facings and five actions (`art/picsart/out/dog/dog_reference_v1.png`), plus a portrait crop of his first view | `picsart_sheet.py` | `art/prompts/sheet-dog-reference.txt` | GPT image (Picsart), 1K, 3:2 | 1 picture | $0.05488 | go: Brandon (studio card `dog-concepts-go`, ceiling $0.06, answered with his corgi); sheet and portrait **approved** 2026-10-30 (review `dog-reference-review`): the sheet is the dog's key art at `docs/art/characters/dog-reference-sheet.png` (image 1 for his animation sheets), the portrait at `game/art/source/portraits/dog.png` |
| 2026-10-30 | The dog's animation sheets, five facings (SE, S, E, NE, N): idle and blink, trot, bite, bark, hurt (`art/picsart/out/anim-dog-<dir>_v1.png`), cut at the small size class (`anim_sheet_cut.py --height 56`, head about 1.5 levels) into the staging folder `art/picsart/out/anim-dog-cut/dog/` with `dog.json`. SE turns almost to profile | `char_sheet.py` | `art/prompts/sheet-dog-anim.txt` (facings in `-asks.txt`) | GPT image (Picsart), 1K, 3:2 | 5 sheets | $0.2744 | go: Brandon (studio card `dog-anim-go`, ceiling $0.28); all five facings **approved** 2026-10-30 (review `dog-anim-review`), strips and `dog.json` in `game/art/source/characters/dog/` |
| 2026-10-30 | Dog SE touch-up, no new art: idle frame 2 (a squint) replaced by frame 1, bite frame 4 (a stray bark mark) replaced by frame 3, by `tools/art/anim_frame_swap.py`; strips keep their length, `dog.json` unchanged | `anim_frame_swap.py` | none | none | 2 strips | $0 | Brandon (studio card `dog-se-fix-review`) **approved** 2026-10-30; in `game/art/source/characters/dog/dog_idle_se.png`, `dog_attack_se.png` |
| 2026-10-30 | Village v2 rock cliff faces: six seamless-rock options on one picture (warm grey, darker with golden moss, grass tufts, blue-grey, calmer and broader, green moss streaks), two tries (`art/picsart/out/village-v2/village_v2_rock_v1/_v2.png`); **reviewed 2026-10-30 (Brandon): rocks 4 (blue-grey) and 5 (broader, calmer warm grey) approved for their look, 1, 2, 3 and 6 redo**; the repeat was rejected ("none of them look good or have a repeatable pattern to them that looks natural"), so neither is in the game yet. The two approved swatches are kept as references (`docs/art/references/village-v2-rock-4.png`, `-5.png`) for the tileable redo (`art/prompts/village-v2-rock-tile.txt`) | `picsart_sheet.py` | `art/prompts/village-v2-rock.txt` | GPT image (Picsart), 2K, 3:2 | 2 pictures | $0.18904 | go: Brandon (studio card `village-v2-rock-go`, ceiling $0.20); results on review card `village-v2-rock-review` |

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
| Fall village style sheet v1: town diorama, tile blocks, cobble and dirt transition pieces, buildings, props, fall foliage on one 3:2 sheet. Brandon runs it himself with one image, `docs/art/references/village-fall-moodboard.png` (his River Village sheet for the feel, the Forest and Farmland zone panels for the detail level; rebuild with `tools/art/village_fall_moodboard.py`) | `art/prompts/village-fall-sheet.txt` | run once (2026-10-29): layout and pieces good, still too detailed (pixel finish, leaf confetti, drawn cobbles). Next: `art/prompts/village-fall-sheet-refine.txt`, v1 sheet plus `style-flat-forest.png` |
| Fall village sheet v2 (refine pass): flat enough to be the look target for the village. Saved locally as `art/picsart/out/village-fall-sheet_v2.webp` (not in git) | `art/prompts/village-fall-sheet-refine.txt` | look target; its tile blocks and slabs are isometric, so they are not cut |
| Fall village game pieces: sides (3 x 2), props (4 x 4), foliage (5 x 3), seven buildings one per picture | `art/prompts/village-fall-sides.txt`, `-props.txt`, `-foliage.txt`, `-building.txt` | 2026-10-29: Brandon ran sides and props. Cut into `art/picsart/out/village-fall/cut/` (16 props by `props_cut.py`; six sides at 512, made to repeat left to right by `tools/art/seam_wrap.py` as `side_*_seam.png`, all pass the x seam check and the busyness bar). Staged, waiting on Brandon. Foliage run too, cut into `cut_foliage/` (15 pieces, all pass the busyness bar; use its tree and stump over the props-sheet ones). Buildings: one cottage (home A) run 2026-10-29, reviewed by eye only; the other six move to two sheets (`village-fall-buildings-homes.txt`, `-big.txt`), cut by `props_cut.py --width 512`. Sheet A (four homes) cut into `cut/` 2026-10-29, all pass the busyness bar; hero and home A fit 3 x 3, but home B and C came out square on a 4 x 3 footprint (left wall share 0.53 to 0.54, the old art reads 0.56 to 0.57), so they sit about half a cell off: re-roll with `village-fall-buildings-long.txt`; tops and transitions to be drawn in code |
| Fall village archways: stone town gate and timber arch with a lantern, 4 x 1 with a 2-cell gap, on one 3:2 sheet (2 drafts) | `art/prompts/village-fall-arch.txt` | 2026-10-29: run by Claude with Brandon's OK (Picsart, refs `props_v1.png` and `style-flat-forest.png`, 0.19 credits). Both drafts face the right way; cut into `art/picsart/out/village-fall/cut_arch_v1/`, `cut_arch_v2/` (`prop_arch`, `prop_arch_timber`), all pass the busyness bar (0.36 to 0.38). v2 previewed in the town (`screenshots/village-props/*_prop_arch*.png`). **v2 approved** (Brandon, 2026-10-29): stone arch at the town gate, timber arch at the hall gate; in `game/art/source/battle/village/` |

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

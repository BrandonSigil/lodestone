# House-style prompt blocks

Paste a style block once into a Text node in a Picsart workflow (or keep it as a saved snippet anywhere else), and connect it to the Image node together with a second Text node that holds only this run's ask. The style block never changes between runs; the ask does.

| File | Use for |
|---|---|
| `style-terrain.txt` | Battle-map concept pictures and zone looks (pair with a map template blocking picture and `art/palettes/<zone>.png`) |
| `style-environment.txt` | Backdrop plates, walls and rim for every map (battle and explore); see `docs/art/environments.md`. Pair with a layout picture (image 2) and the flat style reference (image 1) |
| `style-tiles.txt` | Single tile textures (tops, cliff strips) |
| `style-props.txt` | Single props (trees, rocks, ruins, campfires) |
| `style-character.txt` | Characters, monsters and bosses (pair with a mannequin view, the key view and `art/palettes/characters.png`) |
| `flat-style-portable.txt` | The whole flat style in one paste for any image model or agent; attach `docs/art/references/style-flat-forest.png` as the only image |
| `style-look.txt` | The exact traits of the chosen flat look (solid tops with tiny dots, three flat values, blob trees). Appended to the sheet and kit prompts |
| `style-finish.txt` | The flat, simple finish rules (one colour plus one shadow tone, outlines on big shapes only, silhouette props). Part of the sheet and kit prompts |
| `sheet-zones.txt` | Many zones (flat simple style) on one reference sheet (diorama plus 5 x 5 swatches each), to explore looks |
| `sheet-tile-kit.txt` | One zone as a game-ready 5 x 5 kit (tops, sides, props) with no text; see `terrain-sheets.md` |
| `sheet-character-anim.txt` | One facing of a character as a 5-row animation sheet (idle 4 + blink 1, walk 6, swing 6, cast 6, hurt 2 + down 2); attach `docs/art/characters/00-reference-sheet.png`, run it with `tools/art/char_sheet.py` (1K by default; `--sheet stance` for `sheet-character-stance.txt`), cut with `tools/art/anim_sheet_cut.py` or `--cut` |
| `sheet-character-builds.txt` | The hero once per weapon build (sword, two daggers, bow, book) in one row, SE facing, for the smithy weapon rack sheets. Image 1 the key art, image 2 `art/picsart/out/anim-lead-se_v2.png`; run with `tools/art/picsart_sheet.py --aspect 3:2 --resolution 2K`, cut with `props_cut.py --grid 4x1` |
| `sheet-prop-grid.txt` | 16 props on one 4 x 4 sheet for a setting (`[ZONE]`, `[LIST]`); used by `tools/art/picsart_village.py`, cut by `tools/art/village_cut.py` |
| `sheet-character-concepts.txt` | 8 candidate characters on one 4 x 2 grid (three-quarter SE view, 1K, no reference) to choose a design before any sheets. Edit the eight `THIS RUN` lines per run. Check the grid with `tools/art/silhouette_check.py` |
| `sheet-building.txt` | One whole building on a square footprint, roof on, door on the left front wall (`[ZONE]` = the building) |
| `ui-frame.txt` | The screen border that holds the UI (bottom band with bag, Lodestone socket, four portrait sockets). Image 1 is Brandon's leaf frame `docs/art/references/ui-frame-leaf-reference.png` (the look), image 2 the grey layout `art/templates/ui/ui-frame-layout.png` (from `tools/art/ui_frame_layout.py`). Never attach the old ornate mock-up |
| `village-fall-sheet.txt` | The fall village look target on one sheet: town diorama, tiles, ground transitions, buildings, props. Attach only `docs/art/references/village-fall-moodboard.png` (from `tools/art/village_fall_moodboard.py`) |
| `village-fall-sheet-refine.txt` | Simplify pass on the fall village sheet: image 1 is the v1 sheet (keep layout and pieces), image 2 `docs/art/references/style-flat-forest.png` (copy its finish). Never re-attach the moodboard; its pixel finish made v1 busy |
| `village-fall-sides.txt`, `-props.txt`, `-foliage.txt`, `-building.txt` | The fall village cut into game pieces: six wall faces, 16 street props, 15 trees / bushes / rocks, and the seven buildings (two sheets: `village-fall-buildings-homes.txt` 2 x 2, `village-fall-buildings-big.txt` 3 x 1, `village-fall-buildings-long.txt` re-rolls homes B and C as 4 x 3; `-building.txt` is the one-per-picture fallback; footprints from `catalog.csv`; cut with `props_cut.py --width 512`). Image 1 is the approved-look sheet v2 (`art/picsart/out/village-fall-sheet_v2.webp`), image 2 `style-flat-forest.png`. Each file ends with its cut command and game file names. Tops and transitions are drawn in code (`code_tops.py`), not prompted |
| `village-fall-building-guided.txt` | One fall building per picture, painted over a grey block-out drawn on the game grid. Image 1 `art/templates/buildings/guide_<name>.png` (`tools/art/building_guide.py`), image 2 `style-flat-forest.png`, image 3 only where the ask names one. The five asks and the run, cut and check commands are in `village-fall-building-guided-asks.txt`; check each cut with `tools/art/building_grid.py` (game grid and the hero at the door) before it goes to the desk. Replaces the 3 x 1 and 2 x 1 building sheets |
| `village-fall-arch.txt` | Two walk-through archways (stone town gate, timber arch), 4 tiles long and 1 deep with a 2-tile open gap. Image 1 the fall props sheet (`art/picsart/out/village-fall/props_v1.png`), image 2 `style-flat-forest.png`. Replaces the graybox `ph_arch` once approved |
| `ask-*.txt` | Example asks in caveman-free plain words, to copy and edit |

Rules behind every block: `docs/art/battle-maps.md` (B1 to B32) and `docs/art/characters.md` (C1 to C29). If a rule changes there, change the block here too.

## Wiring it up in a Picsart canvas

1. Add a **Text** node and paste the style block. Rename it "STYLE terrain" (or character). Don't use a **Note** for this: notes are for you and are not sent to the model.
2. Add a second **Text** node for this run's ask (start from `ask-terrain.txt` or `ask-character.txt`).
3. Add **Upload** or **Asset** nodes for the reference images: the blocking picture or mannequin view first, then the palette card (and the key view for characters). The style blocks call them image 1, 2, 3 in that order.
4. Connect both Text nodes and the images into one **Image** node. If the Image node takes only one text input, paste the style block above the ask in a single prompt instead.
5. Duplicate the whole canvas per zone or character, so only the ask and images change. **Batch** can run several asks through the same style.

Saved Flows (the "Lodestone character view" and "Lodestone turnaround" Flows in the Character Guide) work the same way: put the style block in the Flow's fixed prompt and leave only the ask as the input.

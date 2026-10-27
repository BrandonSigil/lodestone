# Battle map art: look, rules and templates

Status: **Proposed (AI), 2026-10-26.** Brandon's isometric reference (mossy stone cliff blocks, temple stair, waterfalls, pines, cream background) is the target look; that choice is his. Every numbered rule below is a proposal until he marks it his in `docs/decisions.md`.

Diagrams: `docs/art/battle-maps/`. Templates: `art/templates/battle-maps/`. Both are rebuilt by `python3 tools/art/battle_art.py`, which uses the same iso math as `game/scripts/combat/combat_board.gd`, so anything drawn on a template lands on the game grid.

## 1. The look in one paragraph
A battle map is a small floating island diorama on plain cream paper. It is built from chunky stone blocks stacked into terraces, each block capped with a thick soft carpet of moss and grass that spills over the edges. Water runs in channels between the terraces and pours off the edges as short white-and-teal falls. Ruins (arches, pillars, a temple stair) and round dark pines break the skyline. One soft sun from the upper left: tops are brightest, the left faces are mid, the right faces are darkest. Everything has a warm dark outline, colours are muted sage, warm stone gray and teal, and the only loud colours on screen belong to the pieces and the UI.

What makes the reference work, so we keep it:
- **Big readable tops.** The walkable surface is the lightest, calmest area; detail lives on the cliffs and the props.
- **Chunky height.** Height changes are obvious at a glance because every step shows a dark cliff face.
- **The island edge.** The map ends in cliffs dropping into the paper, with a few loose cubes falling away. No skybox, no horizon.
- **Moss lips.** The grass cap overhangs the stone, which softens every hard block edge.
- **Few, big props.** One hero structure (the temple), a handful of ruins and trees; most cells are plain ground.

## 2. How it relates to the Style Lab
The Style Lab look (riso grain, flat planes, folk-art borders, region palettes) is the village, world map and frame. The reference is a different camera and a more rendered surface. Proposal: **take the reference's structure and the Style Lab's surface.**
- From the reference: projection, block construction, moss lips, waterfalls, light direction, the island-on-paper staging, value plan.
- From the Style Lab: the paper colour behind the island, the same riso grain over the whole frame (R6), no black (R5), marks instead of rendering (R4: stamped grass fans, stone ticks), one accent per region (R8), and the region palettes for Earth to Alien (section 9).
- Result: a battle reads as a page of the same book as the world map, just a closer, tilted view.

If Brandon would rather match the reference exactly (more rendered, less riso), only rules B16 to B18 change.

## 3. Rules for the art team
Numbers are art pixels. Art is authored at **2x the engine** (engine tile 64 x 32, art tile 128 x 64); the engine draws it at half size on a 720p board and 1:1 at 1440p.

### Projection and grid
- **B1** 2:1 dimetric ("pixel-art isometric"). A tile is a diamond **128 wide, 64 tall**. Grid lines run at **26.565 degrees** (2 across, 1 down). Not true isometric (30 degrees, 1.73:1). See `01-projection.png`.
- **B2** Orthographic: no perspective, no vanishing point, no lens blur, no tilt-shift. Parallel edges stay parallel across the whole map.
- **B3** The world grid is square (1:1). A camera turned 45 degrees and looking down from 30 degrees makes it a 2:1 diamond on screen.
- **B4** One cell = one tile = one piece. Nothing a piece stands on is smaller than a cell; nothing walkable straddles two cells.

### Blocks and height
- **B5** One height level = **32 px** straight up. A full cube block is 2 levels (64 px). Maps use heights 0 to 8.
- **B6** Stone courses are drawn 1 level tall with staggered joints, so a cliff's height can be counted.
- **B7** Only two side faces ever show: **LIT** (facing lower-left) and **SHADE** (facing lower-right). Never draw the back or bottom faces.
- **B8** Side strips are cut from the top down to the neighbour's height. Put the moss lip and the best detail at the top of a strip; the bottom must tile vertically every 64 px.
- **B9** The island hangs 2 levels below height 0, with a ragged bottom edge and 3 to 6 loose cubes falling below it.

### Light and value (`03-light-and-palette.png`)
- **B10** One sun, upper left, fixed in screen space. It does not turn with the camera.
- **B11** Value ratio for every material: **top 100%, lit face 75%, shade face 55%.**
- **B12** Shadows lean cool (toward #727877), lights lean warm (toward #d8cb97). Never pure gray.
- **B13** No cast shadows painted into tiles. The engine adds a soft contact shadow under pieces and props.

### Line and edge
- **B14** Outline colour **#373335** (the ink), never black. **3 px** on the outer silhouette, **2 px** on inner edges, 1 px for stone joints and grass ticks in a darker tint of the face.
- **B15** Block edges are straight on the grid; the moss lip and props get the hand-cut wobble (Style Bible F1). Moss drapes **8 to 24 px** over a top edge and is painted with the top sprite.

### Surface and palette
- **B16** Flat fills plus at most one light band per face. Texture comes from marks one value step off their fill: grass fans and tufts on tops, joint ticks and cracks on stone, a few flowers or pebbles. No noise brushes, no photo texture.
- **B17** Home palette (measured from the reference) in `03-light-and-palette.png`: grass #b7c37a / #abbb71, moss #909b69 / #708f6a, pine #4d7670, path #d8cb97, stone #d7cfb0 / #c5bea2 / #b3af96 / #9e9989 / #727877 / #555954, water #6cb6c1 / #5198b1 / #a5cdcb, paper #eae8d6, ink #373335.
- **B18** The riso grain is added by the engine over the finished frame. Do not paint grain into tiles.
- **B19** Saturated blue and red never appear in terrain or props (water is the only blue, and it is a muted teal). Blue and red belong to the team rings, move and attack highlights, and health bars.
- **B20** Tops are the calmest, brightest surface so highlights read on them. Props and pieces never out-contrast a top.

### Water
- **B21** Water tops are flat teal with two or three light streaks; the engine animates them.
- **B22** Waterfalls are a 64 x 128 seamless vertical strip per face side (lit and shade). The engine scrolls it and adds foam at the foot.

### Props and set pieces
- **B23** A prop stands on one cell: **128 x 256** canvas, feet on the pivot at **(64, 224)**. It may rise up to 192 px above the top (6 levels).
- **B24** Props that block sight must look it: a ruin pillar reads as about 2 levels tall (RUIN_RISE), a tree about 1 level of canopy.
- **B25** Big structures (temple, arch) are drawn whole on the map template, then cut along the slice columns (every 64 px through grid corners). Each slice sorts with the cell whose front corner it holds. See `04-draw-order.png`.
- **B26** Anything that can hang in front of a piece (arch top, branches, a banner) goes on the **foreground occluder** layer. The engine fades it when a piece stands behind.

### Camera turn (Q)
- **B27** Tops must read the same in all four turns: no arrows, no one-way slopes, no text.
- **B28** Props get a FRONT and a SIDE view; the engine mirrors them for the other two turns. Stairs need both views.

### Readability (gameplay first)
- **B29** Every terrain type is recognisable by its top alone at engine size: grass, forest (tree on it), water, rock (boulder), road, stone floor, stairs (treads), ruin (pillar).
- **B30** Pieces are the brightest, warmest thing on the map. No prop taller than 1 level may stand next to a deploy column.

### Files
- **B31** Sprites go in `game/art/source/battle/` as PNG with transparency, named `<terrain>_top_<n>.png`, `<material>_side_lit.png`, `<material>_side_shade.png`, `<prop>_front.png`, `<prop>_side.png`, `fall_lit.png`, `fall_shade.png`. Terrain letters follow the map files: g grass, f forest, w water, r rock, d road, s stone, t stairs, u ruin.
- **B32** Paint home colours only. Other regions are made by the engine's palette map (section 9), so keep each material's three values (B11) distinct.

## 4. Sprite sizes (art pixels)
| Sprite | Canvas | Anchor | Notes |
|---|---|---|---|
| Top | 128 x 96 | pivot (64, 32) | diamond fills the top 64 px; moss lip may hang into the lower 32 |
| Side, lit | 64 x 96 | top-left corner | parallelogram, tiles vertically every 64 px |
| Side, shade | 64 x 96 | top-right corner | mirror geometry of lit, darker value |
| Prop | 128 x 256 | feet (64, 224) | front and side views |
| Waterfall | 64 x 128 | top | seamless top to bottom |
| Whole-map plate | 2400 x 1600 | template origin | one per hand-made map, slices per B25 |

## 5. The templates (`art/templates/battle-maps/`)
Every template is **2400 x 1600 at 2x**, so a cell is always 128 x 64. Each comes as `.psd` and `.ora` (Krita opens both; use the `.ora` if a PSD reader complains) plus flat PNGs.
- `blank-16x16`: an empty 16 x 16 ground grid with height rulers at three corners and hidden grids at levels 2, 4 and 6, slice columns and cell labels. For sketching new maps from nothing.
- `maps/<name>/`: one per saved sandbox map (cliffs, default, ridge, river, temple). Layers: paper, flat-colour blocking of the real map, line art, a depth map, the grid on top of each cell, slice columns, cell labels with heights, and five empty paint layers. Paint over it and the art matches what the game plays.
- `kit/tile-kit-sheet`: an 8 x 3 sheet of 256 x 320 slots, one block per slot with its pivot marked: row 0 tops, row 1 top variants, row 2 props. A MASK layer shows the exact shapes to clip to.
- Each map and the kit also have `control-lineart.png`, `control-depth.png` and `control-blocking.png` for Krita AI Diffusion.

Paint layer order, bottom to top: `cliffs and sides`, `tops`, `props`, `water and fx`, `foreground occluders`. Keep it; the engine import splits on these names.

### Drawing a map on the tablet (Krita)
1. Open `maps/<name>/<name>.psd` (or `.ora`). Lock the CONTROL and GUIDE layers.
2. Optional snapping: Settings > Dockers > Grid and Guides, type **Isometric**, both angles **26.57**, then nudge the cell spacing and offset until Krita's grid sits on the template's grid; tick Snap to Grid for straight block edges. Do not use a Perspective assistant.
3. Paint each pass on its own paint layer. Stay inside the blocking silhouettes; moss may spill per B15.
4. Save. Claude slices and imports from the paint layers.

To make a new map: build it in the combat sandbox (F1 editor), save, and rerun `tools/art/battle_art.py` to get its template.

## 6. Image generation (Krita AI Diffusion with the Lodestone style model)
Diffusion cannot hold a grid on its own. It can when the template is its control. So:
1. Open the map or kit template. In the AI docker add **Control layers**: `control-lineart.png` as **Line Art** (strength 0.8 to 1.0) and `control-depth.png` as **Depth** (0.5 to 0.7).
2. Put `control-blocking.png` (or your own rough paint) on the canvas and **Refine** at strength **0.45 to 0.65**. Lower keeps the geometry; higher invents more.
3. Paste the result on a paint layer, clip it to the blocking (or MASK) silhouette, and paint over seams and edges by hand.

Prompt snippets (paste and edit):

```
lodestonestyle, isometric tactics battle map, 2:1 dimetric projection, orthographic, floating island diorama on plain cream paper, chunky gray stone cliff blocks stacked in terraces, thick soft moss and grass caps draping over block edges, small waterfalls pouring off ledges, dark round pines, ancient stone ruins, soft light from upper left, top faces brightest, left faces mid, right faces darkest, warm dark outlines, muted sage green, warm gray, teal, flat fills with small marks, clean readable game art
```

Tile kit sheet:
```
lodestonestyle, game tile set sheet, one isometric 2:1 block per cell on plain cream background, grass top with moss lip, stone sides with staggered courses, consistent lighting from upper left, warm dark outlines, flat colors, no shadows on the background
```

Set piece:
```
lodestonestyle, isometric 2:1 ancient temple entrance with wide stone stairs, mossy blocks, carved face above the door, two braziers, cream paper background, light from upper left, warm dark outlines
```

Negative:
```
perspective, vanishing point, fisheye, tilt-shift, depth of field, photo, 3d render, top-down, side view, text, letters, watermark, logo, UI, characters, black outlines, harsh cast shadows, noisy texture, high contrast, neon, saturated red, saturated blue
```

The reference image is mood only: never put it (or any other artist's work) in a training set.

Words that pin the camera for any image model: *"2:1 dimetric (pixel-art isometric), tile diamonds twice as wide as tall, grid lines at 26.565 degrees from horizontal, orthographic camera 45 degrees around and 30 degrees down, no perspective."* Avoid the phrase "1:1 isometric 45 degrees" alone: models read "isometric" as true 30 degree iso.

## 6b. The zone pipeline: concept map, break-out, tile set

Fixed house-style prompt blocks for terrain, tiles and props: `art/prompts/` (see its README).
**Maps are built in Godot; Krita makes the look** ([USER] 2026-10-27). Each zone (forest, desert, dungeon, snow...) goes through three stages.

**1. Prototype the zone in Krita.** Open `maps/sampler/sampler.ora` (or any map template). The sampler map has every ground type on a 2 x 2 patch, cliff and masonry faces over 4 levels tall, a stepped stream, stairs, ruins and open ground for key items. Import a starting picture (`control-blocking-<zone>.png`: snow, desert, dungeon, forest; `SNOW` / `DESERT` / `DUNGEON` / `FOREST` in `tools/art/battle_art.py`) or scribble colours over the blocking, add Control Layers (Line Art -> `control-lineart.png` 80%, Depth -> `control-depth.png` 55%), prompt the zone and Refine at 60-85%. Paint key items (campfire, fallen tree, ruins) on `paint 3 props`. On the MacBook (MPS) set Performance > Resolution multiplier to 0.5 or the full 2400 x 1600 pass fails ("tensor dims larger than INT_MAX").

**Palette cards.** `art/palettes/<zone>.png` (home, forest, snow, desert, dungeon; built by `tools/art/palette_cards.py` from the zone colours in `battle_art.py`) shows one iso block per material in its top / lit / shade values plus flat swatches, with no text, so it can go into Picsart, GPT or Krita as an extra reference image. `<zone>-labeled.png` adds names and hex codes; `lodestone-zones.gpl` is the same colours as Krita swatches. Every zone's stone lit / shade sits at 75% / 55% of the top (B11); the script prints the check.

**2. Break it out.** Export the painting with `paint 3 props` hidden as `art/paintings/<map>-<zone>.png` and the props layer alone as `<map>-<zone>-props.png` (both full canvas), then:
```
python3 tools/art/break_out.py art/paintings/sampler-desert.png --map sampler --set desert --props art/paintings/sampler-desert-props.png
```
It unwarps one 2 x 2 patch per terrain into a square top texture, a 2-cell x 4-level face run per material into a side strip (rolled so the rows sit on height levels, shade faces lifted to lit value), and each props blob into `prop_<n>.png` with the feet at the bottom centre. Output goes to `game/art/source/battle/<set>/`; existing files are kept unless `--force`. A contact sheet `<painting>-breakout.png` shows every piece and where it was cut. It first reports a **grid fit** (share of the template blocking's edges with a painted edge within 6 px; 85%+ is good) and marks drifted spots orange; `--check` does only that. A 3:2 image of another size (1536 x 1024 from GPT or Flux) is scaled to 2400 x 1600 first, so a concept painted by an image model from the blocking picture works the same as a Krita one.

**3. Clean up and play.** In Krita: make each texture seamless (wrap-around mode W, Layer > Transform > Offset by half, Refine a band over the seam at 40%), paint trees out of `top_forest`, rename props to `prop_pine_1`, `prop_bush`... (the names in `data/battle_art.csv`). Pick the set in the sandbox ("tile set" menu).

Tile set rules: tops straight down, seamless, 2 x 2 cells per picture; sides straight on, seamless, exactly 4 rows (one per level); props transparent, feet at bottom centre. Missing files fall back to the base art. In-game whole-map plates are shelved.

## 7. Recommendation: generating tiles
`docs/art-pipeline.md` said never generate tile grids. Proposed change: **generate tiles only on top of these templates**, with line art and depth as control and the result clipped to the template's masks, then hand-fixed. Never ask a model for a tileset freehand; it will not hold 2:1, the pivots or the seams. Animation frames stay hand-made or code-made.

## 8. Engine work to drop art in
The current board draws graybox polygons in `combat_board.gd`. To use painted art:
1. **Tile art resource**: per terrain, a list of top variants and a lit and shade side strip, loaded from `game/art/source/battle/`. Missing art falls back to today's graybox, so art can arrive one terrain at a time.
2. **Draw sprites at half scale** in `_draw_tile`: top sprite at the pivot; side strips as UV-mapped polygons on the existing face shapes, cropped from the top by `h - neighbour_h`.
3. **Props** draw in the same depth pass as pieces (same cell depth). Odd camera turns use the side view, mirrored turns flip.
4. **Map plates**: for a hand-painted map, load its slice PNGs per cell instead of tiles; lock the camera turn or require four plates.
5. **Foreground occluders** on a layer above pieces that fades near a hidden piece (today's ghost outline stays).
6. **Waterfall shader**: scroll the fall strip's UVs and add foam at the foot.
7. **Island base**: hang cliffs 2 levels below 0 (today `BASE = -0.6`) with a ragged bottom and a few falling cubes; paper background with riso grain behind the board.
8. **Palette map** for strangeness: a gradient-map shader that sends each material's three values to the region's colours.

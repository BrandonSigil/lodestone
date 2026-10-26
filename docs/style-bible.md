# Lodestone style bible

Brandon owns this page. Every session that touches visuals reads it.
Brandon adopted the style lab draft 1 look on 2026-10-26 for the village hub and world map; the rules and palettes below are the working standard. Lines still marked **Proposed (AI)** come from style lab draft 1 (`docs/style-lab/index.html`, published as an artifact in the visual language thread). They are proposals until Brandon marks them **Brandon** or strikes them. `TODO` slots are still his call.

## 0. How visual work happens
- Brandon directs; code draws. Ideas are tried in the style lab page first, Brandon reacts in the thread or by commenting on the page, and a liked rule is recorded here before it goes into Godot.
- No image-generation models. Visuals are code-drawn shapes, shaders, palettes and stamps, or Brandon's own drawings in `game/art/source`.
- Every picture is a pure function of seed and strangeness, so any screen can be reproduced and compared by screenshot (from riso-windowseat).
- A rule change beats a one-off tweak: fix the rule so every scene the game draws obeys it.

## 1. Master influence
- One painter or film whose look everything answers to: TODO
- References so far: Yvan Duque, Natalie Andrewson, and the 7 images in the visual language thread (cats on a log, church print with embroidered border, goat quilt border, figure on a hill, pink mesa, snow village, autumn wood). Workflow from github.com/sevenevesai/riso-windowseat.

## 2. Rules (Proposed (AI), draft 1)
| # | Rule | Source |
|---|---|---|
| R1 | A scene is 3 to 5 big flat planes. Sky and ground carry most of the color; detail is rare and small. | snow village, figure on hill |
| R2 | Gradients only in skies. Land and pieces are flat; a plane may get one soft light band, never shading. | mesa, cats on log |
| R3 | Soft, stacked, round forms: gumdrop mountains in rows, scallop pines, lollipop trees. No sharp spikes at home. | cats on log, autumn wood |
| R4 | Marks instead of rendering: stamped dots, fans, ticks and arcs, one step lighter or darker than their plane. | cats on log, figure on hill |
| R5 | No black. The darkest color is a deep tint of the region's own hue. | riso-windowseat quality bar |
| R6 | One paper grain and mottle over everything, seeded and fixed so it never swims. | riso-windowseat, autumn wood |
| R7 | Tiny pieces in a huge world. Pieces keep their own warm colors in every region and get a soft light rim when the ground is dark. | cats on log, figure on hill |
| R8 | One accent ink per region, used for one thing: a lit window, a moon, the Lodestone's glow. | snow village |
| R9 | Folk borders frame the picture, built from repeating stamps, and the border holds the UI. | church print, goat quilt |
| R10 | Strangeness inverts the values: light sky and dark land at home, dark sky and glowing land in the deep lands. | AI proposal for Earth to Alien |

## 3. Line
- Proposed (AI): no outlines on scenery. Keylines only on UI panels and on buildings, in the region's dark, never black.
| Scale | Brush | Weight at 1x | Line color rule |
|---|---|---|---|
| Pieces (characters) | TODO | TODO px | TODO |
| Props | TODO | TODO px | TODO |
| Mid scenery | none (proposed) | 0 | — |
| Far scenery | none (proposed) | 0 | — |

## 4. Fill
- Proposed (AI): flat fill plus at most one lighter inner band per form (the cats-on-log gumdrops).
- Proposed (AI): texture is one fixed paper grain plus soft mottle, multiplied over the whole frame.
- Gradients allowed: skies only (R2).

## 5. Palette (Proposed (AI), measured from the references)
Nine roles per region, blended by strangeness: sky top, horizon, far, mid, near, ground, dark, accent, light.

| Region | Strangeness | sky top | horizon | far | mid | near | ground | dark | accent | light |
|---|---|---|---|---|---|---|---|---|---|---|
| Home | 0.00 | #b6a2d0 | #f2b36b | #9a86b6 | #7f8c5c | #4c5a3b | #d6cc96 | #2e2440 | #ffcf4a | #fbf1d8 |
| Snow pass | 0.25 | #5f8bc6 | #ece8c6 | #3d8ff5 | #79c0f6 | #1d68cf | #c6e1e2 | #1a2c55 | #ffe08a | #f1f8f8 |
| The Wall | 0.50 | #c46a01 | #ec5a10 | #8a3b6e | #6a46a0 | #3c0f2a | #6c4aa6 | #2a0a1c | #f4e04d | #c2aef0 |
| Past the Wall | 0.75 | #7891db | #d6a6cf | #c28594 | #f99487 | #c9664c | #ebbacb | #3b2a5a | #ff5fa8 | #ffe6da |
| Deep lands | 1.00 | #14302f | #3d6c5c | #9de0b5 | #e6f29a | #6b3278 | #2c1f3d | #110c1e | #ff8a3d | #f5ffe0 |

Pieces, fixed everywhere: red #c8363c, ochre #e0a03a, cream #f3ead2, indigo #3a3f7a, base #2a2433.

## 6. Shape language
- Earth side, Proposed (AI): gumdrop mountains in two rows, scallop pines, snow-roofed dark houses with one lit window, stepped cut-paper clouds, crescent moon.
- Past the Wall, Proposed (AI): mountains become mesas, then floating rocks; trees become lollipops, then stalks with glowing orbs; clouds give way to sky rings; a pink sun, then two moons. Each tree and peak turns on its own roll, so the change is gradual.
- Never changes on either side, Proposed (AI): the pieces, the grain, the frame's construction, flat planes.

## 7. Value plan
- Proposed (AI): far layers sit close to the sky's value, mid a step darker, near darkest; the deep lands invert this (R10).
- Foreground framing: depends on the frame pick (section 11).

## 8. Pieces (board-game characters)
- Proposed (AI) graybox piece: base disc, bell body, round head, two dot eyes, optional hat (hood, point) and pack. Built from parts so members can be randomized.
- Faces, hats and silhouettes by hand: TODO
- Part slots and anchor points: base / head / top / hand / back / quirk. Changes: TODO
- Size on the grid tile (graybox pawn is about 40 px tall on a 64 px tile): TODO

## 9. Motion
- Move: TODO (graybox: hop per tile)
- Idle: TODO
- Hit: TODO
- Spooked: TODO
- Which moments get hand-drawn frames: TODO

## 10. Strangeness dial (0 = home, 1 = deepest)
| System | 0 | 0.5 (the Wall) | 1 |
|---|---|---|---|
| Palette | Home dusk (Proposed) | amber sky, violet ground (Proposed) | dark teal sky, glowing mint land (Proposed) |
| Plants / trees | scallop pines (Proposed) | lollipops mixing in (Proposed) | stalks with orbs (Proposed) |
| Mountains | gumdrops (Proposed) | mesas (Proposed) | floating rocks (Proposed) |
| Creatures | TODO | TODO | TODO |
| Sky | crescent, stepped clouds (Proposed) | pink sun (Proposed) | rings, two moons (Proposed) |
| Sound | TODO | TODO | TODO |

## 11. The frame (UI border)
- Direction (Brandon): tuck most of the UI into a decorative bottom frame.
- Candidates in the style lab, Proposed (AI):
  - A, embroidered band: thin gold border thickening into a stitched bottom band; Lodestone medallion breaks the band's top edge; party and items in cream panels.
  - B, quilt row: a row of 128 px quilt squares; some only stamps, others hold a party member, the Lodestone or 4 item slots; colors follow the region.
  - C, foreground sill: the nearest landscape layer is the frame; pieces stand on the ridge, items rest as tokens.
- Pick: TODO
- Frame stays constant or drifts with the region: TODO
- Fonts (display / body): TODO (the lab uses Young Serif as a stand-in)

## 12. On-model / off-model
Put 5 pictures that are on-model in `game/art/source/bible/do/` and 5 that are not in `game/art/source/bible/dont/`.
Notes: TODO

## 13. Draft 2 fixes (Proposed (AI), 2026-10-26)
- F1 Every shape gets a hand-cut edge (noise along its normal), never a perfect curve or rectangle.
- F2 One light per scene. At home dusk: warm from the set sun at right, cool sky fill, warm rim on lit shoulders, light pools under windows.
- F3 Each plane has its own texture (stipple gradient, dry-brush strokes, mottle); the shared grain stays light.
- F4 Compose every screen: a framing foreground shape, a path or diagonal that leads to one focal point, and one hero form behind it.
- F5 Pieces get costume (cape, stripes, pack), one prop (staff, bow, stone), two eyes and cheeks, and are about 90 px tall at 1600 wide.
- F6 The frame and labels stay quieter than the picture: thinner band, labels on hover.

## 14. Battle maps (Proposed (AI), 2026-10-26)
- Look: Brandon's isometric reference (stone terraces, moss lips, waterfalls, island on cream paper), with the Style Lab surface (grain, no black, marks).
- Full rules B1 to B32, sprite sizes, templates and prompt snippets: `docs/art/battle-maps.md`.

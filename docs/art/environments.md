# Environments: backdrop ring, walls and rim for every map

Status: **Proposed (AI), 2026-10-27; first plates built.** The approach is Brandon's: a floor sits inside a painted world that keeps going past its edge, drawn in the simple handdrawn style (`docs/decisions.md`, 2026-10-27). The details below are proposals until he marks them `[USER]`. Built so far: plates for snow, ruins and village_in, the outline fade, animated rim drips and cobble hairlines (section 8).

Concept pictures behind this doc: `art/picsart/out/hades-concepts/` (`ring_chamber.png`, `ring_flat.png`, `ring_forest.png`, `ring_snow.png`, `mountain_snow.png`, `castle_forest.png`, `crypt_overview.png`). They are look references, not game art. Nothing in them is cut into `game/art/source/`.

Companion docs: `docs/art/battle-maps.md` (the 2:1 camera, block and light rules B1 to B32; this doc does not change them), `docs/art/explore-test-assets.md` (the asset list for a full test of `explore.tscn`), `art/prompts/style-environment.txt` (the prompt block).

## 1. The rule: every environment gets a backdrop

Every map, battle or explore, sits on a backdrop plate. The floor is a stage inside a larger world: columns, trees, cliffs or architecture continue past its edge, and the outer cells dissolve into a dark tint of the zone's own hue. Nothing stands on the very edge of the floor.

- **E1** Each art set has one backdrop plate, drawn for that set's look. Ruins get a painted chamber, village gets a street of houses, forest gets a clearing ringed by trees, snow gets a snowfield ringed by pines, and so on.
- **E2** The plate is drawn behind the board. It is not a map plate: the per-cell map plates stay shelved (decisions, 2026-10-27). The plate is one picture per set.
- **E3** The edge is a dark tint of the set's colour (style bible R5 holds: never black), not a horizon line and not a gradient in the ground.
- **E4** The plate is orthographic and flat, like the floor. No parallax layers. Depth comes from what is drawn, not from a moving camera.
- **E5** Interior maps (`village_in`: the quiet house, the tavern, the hero's home, the north-east house) get a dark room void instead of a landscape. The walls are the frame; the cutaway rule (W4) does the rest.

## 2. Look

- **L1** Simple handdrawn flat, matching `docs/art/references/style-flat-forest.png`: one flat colour per surface, one shadow tone, medium outlines on big shapes only, silhouette props. This is the answer to "our simple handdrawn art style" and it is what `ring_flat.png` moves toward.
- **L2** Keep the line weights and value steps from `docs/art/battle-maps.md` (B11 to B14). Top 100%, lit 75%, shade 55%.
- **L3** Painterly is not the default yet. `mountain_snow.png` looks painted, but it came from the flat prompt. Whether to move to a painted look is open (question Q5 below).

## 3. Walls and rim

Walls and rim are built from modules, never drawn as one long piece. A module is one tile-wide strip that repeats along an edge.

- **W1** Every wall and rim is a set of modules: straight lit, straight shade, outer corner, inner corner, end cap. Edges match left to right so copies sit side by side.
- **W2** Heights follow the decisions: back walls are two levels tall, front walls one level (decisions 2026-10-27). Stone courses are one level tall (B6), so height reads at a glance.
- **W3** The rim (the edge of the floor) drops into the dark with alpha fades at the top and bottom of each strip, so it blends into the backdrop. Falling stones and a few loose cubes sit below the rim (B9, decisions 2026-10-27).
- **W4** Cutaway (proposal, pending Q3): a wall that hides a piece goes clear in a soft radial hole centred on the party leader, with a dithered edge. Other pieces get a plain fade. This builds on the foreground occluder rule (B26).
- **W5** Doorways are a wall module with a door sprite, not a gap. Doors have a closed and an open sprite.
- **W6** Every wall piece is checked against the combat line of sight. A single-tile corridor walled on both sides blocks all sight, so the layout needs at least one open line through it.

## 4. Sharing pieces between sets

Drawing wall and rim modules once per set is the expensive part. Proposal:

- **S1** Draw the modules once in a neutral stone and recolour them per set with the palette map from the decisions (a gradient-map shader that sends each material's three values to the set's colours). Only the top and bottom values change; the shapes stay.
- **S2** Props and characters are not recoloured. They are drawn per set where the set's look matters (a pine in snow is not a pine in ruins), and shared where it does not (a barrel, a chest).

## 5. Making the pieces (the generation step)

Every environment goes through the same four steps. This is the answer to "generate these backdrop assets for every environment."

1. **Concept.** Write the set's ask from `art/prompts/style-environment.txt` and generate a concept with `tools/art/picsart_concepts.py` (add the entry to `CONCEPTS`). Show it to Brandon. Nothing is cut before he picks.
2. **Plate.** Once a concept is picked, generate the final backdrop plate at 2x (2400 x 1600, the same size as the battle-map templates) with the concept as the layout reference. Save it under `art/picsart/out/<set>/`.
3. **Modules.** Draw or generate the wall and rim modules for the set (or recolour the neutral set, S1). Check the edges match (W1) before cutting.
4. **Cut and place.** Cut each piece to its base name and place it in `game/art/source/battle/<set>/` (battle) or `game/art/source/explore/<set>/` (explore, new folder). Missing files fall back to the base art, as today. Then run `tools/check.sh` and the explore test in `docs/art/explore-test-assets.md`.

Cost reference: a 1K or 2K Picsart image costs about $0.05 to $0.07 (the concepts above). A full set of about 40 new pieces, plus the three plates, is roughly $3 in generation before any hand-fixing.

## 6. What the engine needs (not built yet as far as I found)

- A backdrop draw behind the board for exploration. `combat_board.gd` has a paper card (`_draw_backdrop`), and the explore scene draws none ("exploration draws its own world", `combat_board.gd:55`). Explore needs the plate per art set, with the paper card as a fallback.
- Module placement along wall and rim edges, using the set's modules instead of the flat side strips.
- The radial cutaway around the leader (W4). Today's occluder is a ghost outline.
- A fog overlay texture for unseen cells (today it is code only).

## 7. Open questions

- **Q1** Chamber backdrop for ruins, and the ring style for the other sets: confirm the per-set ring is the right default (`ring_chamber.png` is the first pick; the other sets are proposals).
- **Q2** Black shade: R5 forbids it, Hades uses it. Keep the ban, or allow black on pieces and the deepest cave cells?
- **Q3** Wall cutaway: dithered hole (W4) or a soft fade?
- **Q4** Backdrop turns: the camera turns in quarter steps on battle maps. Four plates per set, a symmetric ring, or a low ring that never shows its face?
- **Q5** Flat or painterly? The flat look is the default here. If the painterly look is wanted, it needs its own prompt and a second check against L1.
- **Q6** Is a backdrop plate a "map plate"? I read it as a different thing (E2). If Brandon reads it the same way, the plate idea is shelved along with the map plates.
- **Q7** Interior backdrop: a dark room void (E5) or the village street around the building?

## 8. Built (2026-10-27)

- **Plates:** `game/art/source/battle/snow/backdrop.png`, `ruins/backdrop.png` (forest courtyard, the crypt's set) and `village_in/backdrop.png` (ground-level wood room, E5). Generated by `tools/art/picsart_surround.py`; the look is the snow example in `docs/art/references/surround-snow-example.png`. Village has no plate yet.
- **Draw:** `CombatBoard._draw_plate` centres the plate on the floor's footprint at `PLATE_SCALE` times its width. The plate is drawn for any set that has one, in exploration too.
- **Fade:** `CombatBoard._draw_outline_fade` tints empty cells within `FADE_RINGS` of the floor, following the real outline.
- **Rim:** `CombatBoard._drips` animates on every rim face.
- **Hairlines:** `CombatBoard._cobble` draws sparse cobble joints on tops.
- **Skyline (prototype):** `game/art/source/battle/village/skyline.png`, a wide horizon strip (sky, clouds, snowy mountains, pine band) drawn behind the whole board, wider than the floor (`CombatBoard._draw_skyline`). It replaces the paper card and the plate's fade on sets that have one. The sky breaks the no-sky rule in section 1 for this set only.
- **Outer ring (prototype):** empty cells two steps out from the floor (`SCENERY_RINGS`) get a flat lowland patch and scenery from the existing prop art: rocks and bushes on ring 1, pines and rocks on ring 2 (`CombatBoard._ring_cells`, `_ring_ground`, `_scenery`). It follows the floor's outline, and cells beyond the grid join the depth order. Open: the lowland is flat, so it lacks the cliff drop in the reference, and the ring 2 edge is a hard line.
- **Still open:** Q4 (turns: the plate does not rotate with the camera, so check each quarter turn), Q2, Q3, and Q7 (the interior furniture is baked into its plate).

# Terrain sheets: from the "Terrain Tiles" reference to game tile sets

Reference: `docs/art/references/terrain-tiles-sheet-v1.png` (Brandon, 2026-10-27, made in Sunburst). Brandon likes the layout: zone label, a small floating island diorama, a swatch grid, and labels.

## Two steps

1. **Explore** with `sheet-zones.txt`: 8 zones per page, same layout as the reference, to pick looks fast. Fill in the zone list and run it a few times.
2. **Build** with `sheet-tile-kit.txt`: one zone per picture, a fixed 5 x 5 slot layout with no text, so a script can cut it into the tile set without hand work. Feed it the zone panel you liked as image 1.

Paste `style-terrain.txt` above either one if the tool takes one prompt only. The sheet prompts already carry the key style lines.

## Too polished? (v2, 2026-10-27)

The v2 zone sheet (`docs/art/references/terrain-zones-sheet-v2.png`) got the layout right (sides row, props split out) but drifted to clean vector, even lines and bright fills. Brandon prefers the rougher, chunkier finish of `tomb-build-steps-v1.png` and the hike illustration `style-hike-illustration.png`. Fix: `style-finish.txt` is now part of `sheet-zones.txt`, and the hike illustration goes in as a style image. Words alone pull models back to clean; the style image does most of the work.

## What the reference needs to work in the game

| In the reference | What the game needs | Why |
|---|---|---|
| Swatches mix blank tops with props sitting on tiles | Tops blank and seamless; props alone on cream | A top repeats on every tile of that terrain; a tree baked into it would repeat too |
| Swatch order differs per zone | Same 25 slots in the same order for every zone | The cut-up script maps slot to file name (`top_grass`, `side_cliff`, `prop_pine_1`, and so on) |
| No cliff side swatches | A row of side strips with 4 equal stone courses | The engine draws block sides from these (`side_cliff`, `side_masonry`, `side_water`) |
| Labels inside the picture | No text in the kit sheet | Text gets cut into the tiles |
| Near-black outlines, glossy, saturated | Plum-grey ink #373335, flat riso fills, muted colours | Rules B16 to B19 |
| Block size and step height vary between dioramas | One block size, half-block steps | Units stand on these heights; the diorama should read like a real board |
| Lava orange, crystal blue and violet everywhere | One small accent per zone | Rule B19 keeps saturated red and blue for team rings and attack highlights (see open question) |
| Skulls and banners on many tiles | Few big props | Busy tops make units hard to read |

Slot to engine file (row by row): row 1 `top_grass`, `top_grass_b`, `top_road`, `top_stone`, `top_rock`; row 2 `top_water`, `top_hazard`, `top_stone_b`, `top_forest`, `top_special`; row 3 `side_cliff`, `side_masonry`, `side_water`, `side_cliff_b`, `side_hazard`; row 4 `prop_bush`, `prop_boulder`, `prop_crate`, `prop_brazier`, `prop_detail`; row 5 `prop_pine_1`, `prop_pine_2`, `prop_pillar`, `prop_landmark`, `prop_ruin`. The `_b`, hazard, special, detail, landmark and ruin slots are new: the engine ignores them until a terrain uses them.

**Open question for Brandon:** lava, crystals and magic glows are saturated by nature. Allow one saturated accent per zone for glowing things only, as long as it isn't the team-ring red or blue? Until he decides, B19 stands.

## More zones (looks only; names and story are Brandon's)

Earth side: autumn birch wood, mushroom forest, farmland and hamlet, river ford with a mill, sea cliffs and tidepools, sandy cove, mangrove, jungle temple, badlands mesa, salt flats, fossil field, quarry or mine with rails, burned ash forest, graveyard and barrows, overgrown old city, flooded temple, frozen lake, glacier ice cave, tundra with standing stones, giant tree canopy walkways, castle walls and ramparts, trench battlefield, sky island over clouds.

Toward the alien side (for the Earth to Alien shift): glassed desert, bioluminescent fungus marsh, floating rock shards, coral that grows on land, bone or shell plains, geometric crystal lattice, living organic ground, inverted-colour forest, metal ruins of unknown make, gravity-broken stairs, void edges where the island crumbles into stars.

## Feeding a sheet back in

Save the kit sheet as `art/paintings/<zone>-kit.png` and say "kit in". The cut-up script is not built yet; I'll build it on the first real sheet so it matches what Sunburst actually draws.

# Map QA (the QA panel in the map maker)

[USER] 2026-11-01 (card master-first-tool): "build the QA panel in the map maker first: one button that checks
reachability, the box score, stairs to nowhere, scale against the hero and deploy room, and paints the problems on the
map." It is stage 4 of the map pipeline (Master Document): machine QA before anyone looks at a picture.

Code: `game/scripts/combat/map_qa.gd` (`MapQA`, pure rules, headless), the panel in `game/scripts/maker/map_maker.gd`
(`run_qa`, `_fill_qa`, "QA panel" section), painting in `maker_overlay.gd` and `flat_view.gd`. Numbers:
`game/data/map_qa.csv` (thresholds) and `game/data/prop_scale.csv` (door height and picture shape per sprite).
Tests: `game/tests/test_map_qa.gd`.

## Use it
- **QA** in the top bar (next to Play test), or **Check** on the **QA** tab of the dock (shown in every phase).
- The tab lists the five checks as PASS / FAIL cards with a one-line summary and up to 40 problem rows. Click a row to
  fly to it (the cell is ringed for two seconds, in the isometric or the flat view).
- Every failing check paints its cells on the map in its own colour: reachability red, box score orange, stairs
  purple, scale yellow, deploy blue. The tick on a card hides that check's paint; **Paint problems** hides all of it.
- **Live** (on): after every edit (once the stroke is done) the panel checks again, so the paint clears as you fix
  things. Opening another map clears the QA until it is pressed again.

## The checks
| Check | Passes when | Paints |
| --- | --- | --- |
| Reachability | every walkable cell can be walked to from the start (explore: the party's walking, eight ways, Jump 1, every door and rubble open; battle: a piece's steps from the party pieces), every thing can be used from reached ground, every foe can be got to. Pillar tops (perches) don't count. | the cut-off cells, the things and foes out of reach |
| Box score | the walkable footprint is not a box: the six numbers of `tools/map_shape.py` (fill, edge, corners, bays, levels, climbs) against the same thresholds. Footprints under `box_min_cells` (200) are rooms and skip it. | the filled corner quarters of the bounding box when bays fail |
| Stairs to nowhere | every stair run lets a walker step off onto ground at two different heights, and no run stops short of the highest ground beside it (a flight that ends below the ledge). | the bad runs (and the ledge they miss) |
| Scale against the hero | each prop in `prop_scale.csv` has a door at least the hero's height (gates 1.2x), a picture 0.5 to 1.6 times its footprint's width, and buildings at least 2 hero heights (the rules of `tools/art/prop_scale_check.py`, which now reads the same CSVs). | the prop's footprint |
| Deploy room | explore: for each foe group, the reached cells within its sight (where the fight can start); a cell is cramped when fewer than 3 cells lie one fight step from the leader (a move 4 member's ring). A group fails when over half its start cells are cramped, or the party can't get within its sight. Battle: both deploy zones hold a full side, and no piece stands where nothing can stand. | the cramped start cells, or the group |

## Command line
`godot --headless --path game -s res://tools/map_qa.gd -- explore/crypt maps/highland [--all]` prints every check
for each map (exit status 1 when one fails). Screenshot steps in `tools/maker_shot.gd`: `qa`, `qafly:<check>:<problem>`.

## State on 2026-11-01 (first run)
crypt and wolf_den pass all five. village_v2 fails stairs (3 leftover stair cells, e.g. 32,48 by the south gate);
snow_pass fails reachability (96 cells in 13 patches, ledge_chest and rope_down out of reach) and one stair; battle maps
like temple, cliffs and arena_c fail the box score.

## Hidden spots (2026-11-01, [USER] pm-occlusion)
- `sight` (`MapQA.check_sight`): every thing (not doorways, ways out, windows or hidden finds), every group unit's spot and the start must be seen by the camera. A spot is hidden when the tile straight in front of it (toward the camera, by the map's `view`: `MapQA.camera_steps`) holds a tree (forest ground), a tall see-through prop (`sight_tall` 0.9 or a building) or ground `sight_cliff` (2) levels above it, or when both tiles beside that one do (`hidden_spot`, `blocks_view`). Each hidden spot is a warning; the share of walkable ground out of sight goes in the summary. Fix it on the map by moving the spot into the open.
- First pass (2026-11-01): forest_roads' Bushberry (unit and fallen spot) moved to (21,13), crypt `hall_chest` to (43,45) and `wing_key` to (66,26), farmland `farm_stash` to (30,28), village_v2 `chef` to (34,30). Still flagged: snow_pass `rope_ledge` at (15,24) (not touched: the map builder's). Test: `test_sight_flags_hidden_spots` (every explore map but snow_pass keeps its spots in the open).

# Road set pieces (pitch)

Status: **[USER] 2026-11-17: all nine approved, with two notes (below). Build in progress.** Page with sketches:
https://claude.ai/artifact/MpxxgNjBQnvE1BhdqhAGsw. Sketches: `docs/art/set-pieces/` (drawn by
`python3 tools/setpieces/sketch.py <out_dir>` from the grids in `tools/setpieces/layouts.py`).

Brandon, 2026-11-17: "help me improve the "random encounter" maps. I'd like to have 2-3 per starting zone (east, west,
north) that match those environments better ... they should still be set pieces. Something should anchor each map
that tie in with the story scenario the player encounters ... Pitch me 2-3 scenarios for each direction, then I'll
have you build those maps."

Brandon on the pitch, 2026-11-17: "I love all of this except W2 could use some height, let the top part be a waterfall
with the bridge up top, and some elevation on both sides that players/enemies could scramble up to get higher ground.
Also remember one of our core rules, these maps should not be just big squares and rectangles, the overall map shape
can and should be interesting too!" So W2 was redrawn, and every map's outline is cut in and out (`CUTS` in
`layouts.py`); the built maps must pass the map shape bar (`tools/map_shape.py --fight`).

Each map is built round one landmark. The road event's choice decides the start: going closer walks into the
ambush (party at the landmark, hidden foes, foes move first); keeping distance means no fight or a fair start
(party at the edge, party first, hidden foes shown). Option labels are working names; the prompts are Brandon's.

| Id | Road | Anchor | New work | Size |
| --- | --- | --- | --- | --- |
| W1 | West | Tipped wagon on the river road, thieves' cover on one side | wagon prop, prop cover | S |
| W2 | West | Waterfall with the bridge across its top, stepping stones over the rapids below, high ground on both banks | rapids sweep pushed pieces downstream, scramble tiles | M |
| W3 | West | Lake hut and dock, crawlers in the reeds | reeds, falling in the lake | M |
| N1 | North | Ruined watchtower, four levels up | climb tiles (ladder, ivy), leader goal | M |
| N2 | North | Shrine stone in a sunken snowy ruin bowl, skeletons rise | optional ice slide | S |
| N3 | North | Rope bridge over a deep gorge | ladders (shared with N1) | S |
| E1 | East | Farmhouse, fenced yard, well; scarecrow men among real scarecrows | scarecrow foe, optional crop fire | M |
| E2 | East | Broken corral, loose bulls, barn to escape to | nothing new | S |
| E3 | East | Windmill hill held by bandits, low walls and wheat | windmill prop, prop cover | S |

Shared work for any pick: a set-piece event names its own map (today road fights roll a random plot,
`docs/systems/plots.md`); each map carries two party starts, foe cells and hidden flags; props (wagon, hay, walls,
well) give the same half cover against ranged hits as woods (today only `T.FOREST` does, `CombatGrid.COVER`);
the east road uses the farmland tile set (`overworld_paths.csv` gives it `forest` today); seeds flip the map and
vary the foe mix. Claude's suggested set: W1 + W2, N1 + N3, E1 + E2.

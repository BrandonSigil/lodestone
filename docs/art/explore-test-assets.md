# Explore test: assets needed for a full run of explore.tscn

Status: **Proposed (AI), 2026-10-27.** The list of what a full test needs in the new visual system. "Have" means a file exists in `game/art/source/`. "Need" means it still has to be made (concept, then cut, per `docs/art/environments.md` section 5). Nothing here has been generated yet.

Maps under test (from `game/data/explore/`):

| Map | Art set | Size (cells) | Things | Groups |
|---|---|---|---|---|
| `crypt` | `ruins` | 34 x 30 | gate (locked), crypt_door (sealed), crypt_chest, yard_stone (shrine), cave_rubble, tower_chest, way_out (exit) | plaza (bandits), cave (wolves), tower, throne |
| `village` | `village` | 40 x 38 | gate (exit), 8 house doors (enter), weapon_rack | none |
| `home` | `village_in` | 8 x 7 | out (enter) | none |
| `house_ne` | `village_in` | 11 x 9 | out (enter), book (hidden) | none |
| `tavern` | `village_in` | 12 x 11 | out (enter) | none |

Three art sets are in play: `ruins`, `village` and `village_in`. The base set (`game/art/source/battle/` root) is the fallback for anything missing.

## 1. Backdrop plates (one per set)

| Set | Plate | Have | Need |
|---|---|---|---|
| `ruins` | painted chamber ring around the crypt floor | no | yes, `ring_chamber.png` is the first concept |
| `village` | street of houses around the village floor | no | yes |
| `village_in` | dark room void around the interior floor (E5) | no | yes |

Each plate is 2400 x 1600 at 2x (environments.md E1, section 5). Q4 (turns) decides whether each needs four plates; the village map has `turn: false`, so one plate is enough there.

## 2. Rim and walls (per set, or shared with palette recolour)

Per set, if drawn separately (environments.md W1 to W3):

| Piece | Count per set | Have (base set) |
|---|---|---|
| Rim straight, lit | 1 | `side_cliff.png` (not module-shaped; needs an edge match) |
| Rim straight, shade | 1 | `side_cliff_b.png` (same) |
| Rim corner, lit / shade | 2 | no |
| Rim end cap | 1 | no |
| Falling stone, lit / shade | 2 | no (`fall_lit`, `fall_shade` per B31 not cut yet) |
| Wall back, lit / shade (two levels) | 2 | no (`side_masonry.png` is one level) |
| Wall front, lit / shade (one level) | 2 | no |
| Wall end cap | 1 | no |
| Wall corner | 1 | no |
| Wall broken (rubble edge) | 1 | no |

That is 13 pieces per set, 39 for three sets. With palette recolour (environments.md S1), the neutral set is 13 pieces, and each set only swaps colour, which makes it 13 pieces plus three recolour checks.

## 3. Things (doors, chests, shrines, exits)

These are the explore `things` kinds. Each needs a closed or default sprite, and any with a state change needs an open one.

| Thing | Kind | Set | Have | Need |
|---|---|---|---|---|
| gate (locked iron) | door | ruins | no | yes, closed and open |
| crypt_door (sealed) | door | ruins | no | yes, closed and open |
| crypt_chest, tower_chest | chest | ruins | no | yes, closed and open |
| yard_stone | shrine | ruins | no | yes |
| cave_rubble | rubble | ruins | no | yes, plus a cleared state |
| way_out | exit | ruins | no | yes (stair going down) |
| house doors (8 on village map) | enter | village | building sprites `b_*` cut; door is part of the building sprite | check the door reads; keep the building |
| weapon_rack | rack | village | yes, `prop_rack.png` | check it reads at explore size |
| out (door) | enter | village_in | check door in `props_in` | check |
| book (hidden) | hidden | village_in | `props_in` has a bookshelf | cut a small book marker |

## 4. Characters: one general dummy, tinted by team (no real art needed for the test)

Brandon asked to skip real characters for now. Every unit without sprite art of its own draws with one general dummy, `game/art/source/characters/dummy/`, generated through the Picsart pipeline:

- **Look:** a neutral pale grey-cream body with a dark outline and a plain short sword, in the house style. The prompt is `art/prompts/sheet-dummy-anim.txt`. It draws the character style of `docs/art/characters/00-reference-sheet.png` but not that character's identity.
- **Tint:** the engine multiplies the dummy by the team colour (`PlaceholderFigure.spec`). Party members are green, blue, purple and so on; enemies are red. Done party pieces darken as before.
- **Enemy glyphs:** enemies keep a glyph over the head (bandit triangle, bandit_archer diamond, wolf circle, strange_thing cross), drawn in code on top of the dummy, so they still tell apart.
- **Facings and anims:** `se`, `ne`, `s`, `e` and `n` were generated and cut (idle 4, walk 6, attack 6, cast 6, hurt 2, down 2). `sw`, `w` and `nw` mirror `se`, `e` and `ne`. The roaming facings (`s`, `e`, `n`) are in place for the explore map; the in-game check on a roaming unit is still to do.
- **Lead** keeps its own art and is not tinted.
- **Fallback:** if the dummy art is removed, units draw as the code-drawn placeholder figure, `game/scripts/combat/placeholder_figure.gd`, which keeps the same colours and glyphs.
- **Cost:** 5 sheets at 1K (se, ne, s, e, n), about $0.27.

The rows below are the sprite spec, kept for when real characters come back (C1 to C29). They are no longer needed for the test.

Sprite spec C1 to C29: five facings plus mirrors, idle, walk, attack, cast, hurt.

| Unit | Role in test | Have | Need |
|---|---|---|---|
| lead | party leader, walks the map | yes (`game/art/source/characters/lead/`) | check it works under the new backdrop |
| stardrop | party member (fight deploy) | no | yes |
| hunter | party member (fight deploy) | no | yes |
| bandit | group `plaza` | no | yes |
| bandit_archer | group `plaza` | no | yes |
| wolf | group `cave` | no | yes |
| strange_thing | two units in `crypt.json` | no | yes (for a full test of unit variety) |

Six characters need the full sprite spec. The party members only need to be readable in the fight deploy, so idle and attack are enough for a first pass.

## 5. Fog and overlays

| Item | Have | Need |
|---|---|---|
| Fog over unseen cells | code only (`explore_overlay.gd`) | a fog texture (one tile), to replace the code tint |
| Seen-but-not-in-sight dim | code only | keep in code; check it against the new plate |
| Enemy sight cone (`WATCH_COLOR`) | code only | keep in code |
| Item icons (FOOD, MED) | text placeholder | optional for the visual test |
| UI frame | graybox panels | the frame pick (style bible section 11) is still open; not needed for this test |

## 6. Engine work the test depends on

These are code, not art, but a full test fails without them (environments.md section 6):

1. Draw the backdrop plate behind the explore board, with the paper card as a fallback.
2. Place wall and rim modules along the edges that need them, instead of flat side strips.
3. The radial cutaway around the leader (W4).
4. A fog texture replacing the code tint, if item 5 above is made.

## 7. The test run

Once the assets exist, run the explore screenshot steps (`game/tools/explore_shot.gd`) on every map and check each picture against the list above:

1. `start` on `crypt`, `village`, `home`, `house_ne` and `tavern`: backdrop visible, no graybox floor left in the picture.
2. `walk` and `wasd` on `crypt`: a wall cutaway works near the leader.
3. `door` on `crypt` (gate) and `use:crypt_chest`: door and chest states change.
4. `spot` on `crypt`: the plaza group appears with its bandit sprites.
5. `deploy` and `fight` on `crypt`: the party of three deploys next to the leader, with the backdrop behind the fight.
6. `overview` on `crypt`: the whole map with fog on unseen cells.

Save each picture into `art/picsart/out/explore-test/` and check it against the list above. Screenshots are the acceptance check; `tools/check.sh` must still pass.

## 8. Totals

- Backdrops: 3 plates.
- Rim and walls: 13 pieces per set (39 total), or 13 neutral pieces with a palette recolour per set.
- Things: about 10 new sprites in `ruins` (no doors, chests or shrines there yet), a few checks in `village` and `village_in`.
- Characters: one general dummy from the API pipeline, tinted by team (section 4). Lead keeps its own art.
- Fog: 1 texture.

About 40 new pieces in all, before hand-fixing, at roughly $0.07 per generation.

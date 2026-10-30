# Cliff strips

Brandon on the card `cliff-no-breaks` (2026-10-30): "Yes this is great". Cliff faces in painted strips, with no
breaks at each level.

## The art
- Six tall strips (`cliff_strip_1..6`), each 3 cells across, painted straight-on with flat light, with plain mid-tone
  side edges. A strip is drawn at the side texture's density, 2 levels a cell, so a 210 x 842 px strip covers about
  24 levels.
- A set lists its strips in its `battle_art_<set>.csv`, `strips` column, stems split by `|`. Village lists them on the
  natural ground (grass, forest, road, rock). Built ground (stone, ruin, stairs) keeps its masonry.
- `BattleArt.side_strips()` loads them once per set, mipmapped. If a strip file is missing it is left out; if none are
  there, the faces keep the side texture as before.

## Which maps
A map turns the strips on with `"cliff_strips": true` in its grid `look` (`MapLook.cliff_strips`). Only village v2
does (`build_village_v2.py`). The live village shares the village set but keeps its masonry.

## Drawing (`CombatBoard._strip_face`, soft look only)
- Each straight line of faces is keyed by its facing, where it stands and its lip height. It is cut into windows 1 to 3
  cells long at hashed spots (`_strip_cut`: about half the cells, never three in a row without a cut). Where the lip
  height changes, the key changes, so the strips break there too.
- A window shows one strip, picked by hash. It reads a hashed column offset into the 3-cell strip (never tiled
  sideways), is mirrored left to right on every other hash, and starts at a hashed depth.
- Down the face the strip runs on from that depth. Where it runs out it is read back up (mirrored), since the strips
  aren't seamless top to bottom. `_strip_quad` walks those runs by an integer count, at most `STRIP_RUNS` a face, so it
  always ends. (A float-stepped loop that could stall on a run's end ran a screenshot out of memory once,
  2026-10-30.)
- The window before carries on over the first `STRIP_FADE` (0.18) cell of each window and fades out, so the joins are
  soft.
- Hashes are on world cells, so the same cliff always comes out the same and no two cliffs match. Stair risers, kit
  walls and the block look are unchanged.

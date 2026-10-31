# Map builder: handoff (2026-10-30)

## Job and standing rules
- Village and explore maps, the map maker, placing art in the world. Studio role id `builder`.
- Studio: https://claude.ai/artifact/5NsBvyRP81zBRgAFCANTP5 (ArtifactData: `desk`, `notes`, `roles`, `roadmap`, `log`).
  Each turn: read desk cards (`role == builder`, `status == answered`) and notes (`role == builder`, `status == new`),
  act, then mark them done or seen with a `result`. Keep `roles/builder` and the World track (roadmap doc `world`,
  with commit refs) current. Post `log` lines with screenshots. Upload pictures with Artifact `asset: true`.
- Decisions Brandon owes go on the desk as cards with pictures. Don't wait for him.
- No story or copy, no painting art, no secrets (CLAUDE.md). Read `docs/decisions.md` before a design change.
- Shared checkout: other sessions edit `~/lodestone` too. Use `git commit -- <your paths>` only; pull before, push
  after; never stash, reset or switch branches. For a clean check, apply your diff to a temp worktree from
  `origin/main`, run `--import`, then `E2E=1 tools/check.sh`, then remove the worktree.

## Now
- Kept by Brandon: god mode (`!` button, `GodMode`), Size 1 to 4 (brush, path, river, bridge, stairs), Greybox view (K), cliff wash, crypt, snow pass.
- Village v2 hillside rework is committed (a0725b7, `hillside_village_v2.py`) but parked: Brandon is editing the village in the maker himself. Never overwrite or revert his uncommitted village and map edits.
- Tests: props from another art set only have to exist; untitled scratch maps may have no pieces.
- Next only if asked: the live `village` rework, shaping the one-room interiors.

## Standing rule: never show Brandon a box
[USER] 2026-10-30, said several times: "is the entire map basically just a big box? if yes, dont show it to me and work on it.
Unique shapes, jut outs, dynamics, verticality!" Before a map goes on the desk (card, presentation, layout shot), run
`python3 tools/map_shape.py game/data/explore/<map>.json`. If it says BOX, rework it first. Build maps as a winding chain of
rooms at different heights with voids between, not a filled rectangle.

## Open threads
- Desk: `builder-maker-goals-review`, `builder-crypt-redesign-present` (open). Notes: none open.
- The art runner (`local_b246bd54-…`) sends Brandon's picks on art cards; the systems developer owns engine rules;
  the game designer sets map levels and foe placement; the playtester reruns after map changes (tell them).
- E2E on main fails "engine errors" from `_sit_on_frame` (4810f09, not ours). Reported to main.

## Maps and builders (rebuild, don't hand-edit JSON)
- `tools/explore/build_village_v2.py` (village v2, look `cliff_strips`), `build_village.py` (live village, houses),
  `build_crypt.py` (crypt: level 1, ambusher none), `build_snow_pass.py` (snow pass level 1 with the hidden
  ambusher at (7,15), added after dressing by `hide_ambusher()`; wolf den level 2).
- Builders that dress run Godot through `tools/mem_guard.sh` (killed over `GODOT_MEM_CAP_MB`). Keep it that way.
- Map levels for foes by depth: top-level `level` in the map JSON, set in the builder.
- Adding a unit can shift the dressing elsewhere (it keeps cells round units as built); diff the rebuild.
- Hidden ambushers need a fight-reachable cell and must be spottable within 3 (check line of sight headless).

## Stairs and cliffs
- Stair kit: `docs/design/stairs.md`. Fine treads (3) default, natural looks 6 with rock risers (`looks.csv`).
- Cliff strips: `docs/systems/cliff-strips.md`. `BattleArt.side_strips`, `CombatBoard._strip_face`/`_strip_quad`/`_washed`.

## Gotchas learned the hard way
- A float-stepped draw loop in `_strip_quad` stalled on a strip end and drew forever: a Godot run hit ~267 GB and froze
  the Mac. Every draw loop counts whole steps with a cap. Before any windowed run of new drawing code, load the map
  headless and watch RSS (kill above 3 GB), then shoot through `tools/godot.sh` (never the bare binary).
- `String(true)` errors in GDScript; use `str()`.
- Headless test scripts can't touch autoloads in `_init`; work in `_process`, and pass `--quit-after`.
- zsh: put file lists in arrays (`F=(...)`; `"${F[@]}"`).
- `tools/godot.sh` prints harmless "screen_count = 1" errors.
- Checks: `GODOT=/Applications/Godot.app/Contents/MacOS/Godot E2E=1 tools/check.sh`.

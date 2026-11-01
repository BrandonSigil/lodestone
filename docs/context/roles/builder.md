# Map builder: handoff (2026-11-01)

## Job and standing rules
- Village and explore maps, the map maker, placing art in the world. Studio role id `builder`.
- Studio (ArtifactData: `desk`, `notes`, `roles`, `roadmap`, `log`).
  Each turn: read desk cards (`role == builder`, `status == answered`) and notes (`role == builder`, `status == new`),
  act, then mark them done or seen with a `result`. Keep `roles/builder` and the World track (roadmap doc `world`,
  with commit refs) current. Post `log` lines with screenshots. Upload pictures with Artifact `asset: true`.
- Decisions Brandon owes go on the desk as cards with pictures. Don't wait for him.
- No story or copy, no painting art, no secrets (CLAUDE.md). Read `docs/decisions.md` before a design change.
- Shared checkout: other sessions edit `~/lodestone` too. Use `git commit -- <your paths>` only; pull before, push
  after; never stash, reset or switch branches. For a clean check, apply your diff to a temp worktree from
  `origin/main`, run `--import`, then `E2E=1 tools/check.sh`, then remove the worktree.

## Where it stands (2026-11-01)
- **Landed today:** hex-world graybox tiles `forest_roads` and `farmland` (7e34b3b, `tools/explore/build_hex_tiles.py`); `forest_roads` plus an elite ogre holding the Bushberry captive (loot `rescue:bushberry`, d658ae5); farmland rebuilt flat and open with a path and fence line, ponds and a hidden bonfire outcrop where Amber sleeps (add 3 wood, sit on the log, recruit), her square spot showing once recruited (03d6501).
- **Unverified:** the Amber sequence has not been played end to end. Test it before the review card.
- **Guard:** `build_snow_pass.py` refuses to overwrite uncommitted edits. `game/data/explore/snow_pass.json` holds Brandon's own unsaved edits: never touch, rebuild or commit it. Snow pass stays his until he says "save my maps".
- **Next only if asked:** tile vibes, foes and events for forest_roads and farmland once Brandon answers; the live `village` rework; one-room interiors. Village v2 (a0725b7) is parked: Brandon edits the village in the maker himself.
- Kept by Brandon: god mode, Size 1 to 4, Greybox view (K), cliff wash, crypt, snow pass. Tests: props from another art set only have to exist.

## Standing rule: never show Brandon a box
[USER] 2026-10-30, said several times: "is the entire map basically just a big box? if yes, dont show it to me and work on it.
Unique shapes, jut outs, dynamics, verticality!" Before a map goes on the desk (card, presentation, layout shot), run
`python3 tools/map_shape.py game/data/explore/<map>.json`. If it says BOX, rework it first. Build maps as a winding chain of
rooms at different heights with voids between, not a filled rectangle.

## Open threads
- Check the desk for `builder` cards (`builder-hex-tiles-review` was answered with the farmland rework) and `builder` notes at the start of a turn.
- The art runner sends Brandon's picks on art cards; the systems developer owns engine rules; the game designer sets map levels and foe placement; the playtester reruns after map changes (tell them).

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

## Studio rules
- The Studio page is https://claude.ai/artifact/BNSLpKC1ZLXCeKnmPvVmo7 (this account). Desk card text is a short lead line, a blank line, then "- " bullets with **bold** labels, never one long paragraph. Use real newlines.
- One review card per feature or job, not one per commit.
- Run long checks in the foreground or wait for them; never end a turn with work unpushed. Commit, rebase onto origin/main, push, and confirm with `git log origin/main`.
- Model: dev on Opus at medium effort; design, builder, playtest and art on Sonnet.

---
name: lodestone-map-maker
description: The in-game map maker (F8) and the "valley" map look Brandon asked for on 2026-10-28 (sky, mountains, framing forest, grass lips, tall cliffs); what's built and what's open
metadata:
  type: project
  modified: 2026-10-28T06:55:40.718Z
---

- 2026-10-28 [USER] Brandon wants ALL maps (battle and exploration) to look like his mountain valley reference: sky and snow mountains behind, a dark pine forest the map sits in, big foreground trees overlapping the bottom, strong verticality (terraces, tall grey cliffs, carved stairs, choke points, waterfalls between levels), an irregular outline, grass hanging over every cliff edge as a lip with drips.
- [USER] "No shortcuts": an IN-GAME map maker that makes such maps on the fly is a main pillar of the pipeline. Thread "Build a map maker for layered cliff maps".
- Built (2026-10-28, branch claude/project-thread-6e46dr): looks in data/looks.csv (valley / island / plain), MapBackdrop bands, skirt tree rings, lips cut from the top texture (`lip` column in battle_art*.csv), MapOps / MapGen / MapRecipes (`highland` 26x26 reference layout, data/maps/highland.json), map maker scene on F8 (game/scripts/maker/), `alpine` mix set (borrows art via "set/stem"), slab renderer in CombatBoard, tools/map_shot.gd + map_build.gd, tests/test_maps.gd. Docs: docs/design/map-look.md, docs/systems/map-maker.md.
- CombatBoard now draws through child slab nodes; draw helpers must paint on `_ci`, never `self`. Merged to main as PR #56; the Mac's PR #55 (general dummy, fog-free vertical village, environments proposal) was landed on top of it via PR #57 on 2026-10-28 with its unit drawing switched to `_ci` and its Godot 4.7 project file rewrites dropped.
- 2026-10-28 [USER] Brandon on the first pass: "a big improvement", still work to do; keep it on main and iterate.
- 2026-10-28 Full editor (thread "Build a full-fledged map editor"): icon rail, options bar, dock (Assets from data/catalog.csv with drawers/search/recent + drag-drop ghost; Inspector with ids, events, notes; Map tab). R turns through `<sprite>_r1..3` angles or mirrors. Interactables + start on explore maps only. Blobs: sprite `ph_<slug(name)>`, art at art/source/battle/ph_<name>.png replaces them. `python3 tools/map_notes.py` lists blobs/ids/notes, read it when Brandon says "door_01 on <map>". Ground fringes in CombatBoard._fringe; painted transition art list docs/art/transitions.md (Brandon wants LDtk-style auto transitions).
- 2026-10-28 [USER] No map rotation for players (fixed approved angle per map, like Hades). CombatBoard.can_turn defaults false; only the maker and sandbox map editing turn. Maker save keeps doc.view; "Use this view as the map's angle" sets it.
- Open for Brandon: code backdrop bands vs painted strips per look; backdrop parallax (environments proposal E4 in PR #55 says none); closer battle camera on big maps.

**Why:** maps are a main pillar; later threads must keep this look and the editor working.
**How to apply:** new maps get a look and follow the authoring rules V1-V8 in map-look.md; keep CombatBoard changes compatible with explore, sandbox and maker hosts; see [[lodestone-battle-map-art]], [[lodestone-explore-maps]].

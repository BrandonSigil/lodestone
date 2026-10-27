---
name: lodestone-world-map
description: Lodestone world map status: branch, stacking on the village riso kit, discovery model, open questions
metadata:
  type: project
  modified: 2026-10-26T01:54:49.623Z
---

- 2026-10-26 Riso world map built in thread "Create the riso world map"; merged to main via PR #2 (which also carried the village hub branch's riso kit and village work).
- Village thread owns game/scripts/riso/ and village scenes; world map owns scenes/world_map.tscn, scripts/world/, data/world/, shaders/world_*.gdshader. Handoff: village MAP button -> Game.go(Game.WORLD_MAP) with no run; trail MAP button mid-run; BACK returns to TRAIL if a run is out else VILLAGE.
- Discovery = meta.revealed circles; full map shown for now, FOG PEEK toggles the fog shader. Fog on by default is Brandon's later call.
- How it works lives in docs/systems/world_map.md. See [[lodestone-visual-language]].

**Why:** Two threads built on one kit at once; later sessions need to know the stack order before merging.
**How to apply:** Check docs/decisions.md "World map" for which lines Brandon has retagged [USER].

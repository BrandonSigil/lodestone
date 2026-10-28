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
- CombatBoard now draws through child slab nodes; draw helpers must paint on `_ci`, never `self`. Open PR #55 (Mac "Merge village-map...") still calls Pawn/PlaceholderFigure with `self` in _draw_unit, so it needs `_ci` when it lands.
- Open for Brandon: code backdrop bands vs painted strips per look; backdrop parallax (environments proposal E4 in PR #55 says none); closer battle camera on big maps.

**Why:** maps are a main pillar; later threads must keep this look and the editor working.
**How to apply:** new maps get a look and follow the authoring rules V1-V8 in map-look.md; keep CombatBoard changes compatible with explore, sandbox and maker hosts; see [[lodestone-battle-map-art]], [[lodestone-explore-maps]].

---
name: lodestone-explore-maps
description: Lodestone walkable exploration maps (F10): leader-only roaming, fog, in-place fights with deploy, skill-gated interactions; merged PR #42
metadata:
  type: project
  modified: 2026-10-27T08:08:40.855Z
---

- 2026-10-27 Built in thread "Build walkable exploration maps", merged as PR #42. Scene scenes/explore.tscn (F10 anywhere), code game/scripts/explore/, maps game/data/explore/*.json (first: crypt, from tools/explore/build_crypt.py), options in data/explore_events.csv. Docs: docs/systems/explore.md.
- [USER] Brandon: only the main character (party leader) walks the map; when a fight starts you place the others around the leader, fast characters further out, a clunky knight right beside them. Implemented as ring = move - 3 (min 1), +1 on sneak attack, 1 when ambushed.
- Brandon's reference image for this was LAYOUT only, not style.
- Headless shots: game/tools/explore_shot.gd (xvfb-run + --rendering-driver opengl3 in cloud).
- 2026-10-27 PR #48: crypt uses tile sets via per-cell zones (map set ruins, forest yard, dungeon corridor/cave), set in build_crypt.py. Brandon plays from ~/lodestone-main on the Mac; it must be updated to origin/main to see new art.
- Gotcha: running Godot 4.4.1 in the cloud rewrites every art .import file; `git checkout -- game/art` before committing.

**Why:** later threads extending exploration (trail hookup, editor, patrols) need the entry points and Brandon's rule.
**How to apply:** keep unit rendering in CombatBoard shared with combat (see [[lodestone-character-sprites]]); see [[lodestone-repo]] for testing.

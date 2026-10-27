---
name: lodestone-combat-polish-notes
description: Brandon's 2026-10-27 playtest notes on combat (x-ray, grid toggle, combat stance, island map edges, blended maps) and their status
metadata:
  type: project
  modified: 2026-10-27T11:24:37.248Z
---

2026-10-27 [USER] playtest notes after lead sprites (PR #39):
1. Party members behind trees/pillars must stay visible: fade the prop or outline the hidden piece (team circles alone too faint).
2. Grid lines on/off toggle in the combat sandbox.
3. Combat stance: characters draw weapons / ready themselves in combat (lead's sword shouldn't stay on its back).
4. Maps should be irregular floating islands, not clean rectangles: rough stepped rock undersides tapering down, hanging bits, waterfalls/icicles off the edge. Reference he loves: the "Lich King Tomb" generated sheet (forest trail to frozen throne).
5. Remove old base tile set, use only new zone sets (forest becomes default).
6. Show maps blending zones (forest into castle ruins, mountain into marsh).

Status 2026-10-27 11:30 UTC: 2 and 5 done by Remote Control on the MacBook but NOT pushed (local in ~/lodestone); session stalled on an API error. Rest pending. PR #43 (main) added CombatBoard.show_grid: the Mac grid toggle must use that var, not a second one; rebase the Mac work onto main. Keep CombatBoard hooks from PR #42 (fog, fog_on, cull, hidden(c), _veil, Battle.setup p_board, explore scene uses play_anim/facing).

**Why:** next threads must not lose this list or redo the Mac-only work.
**How to apply:** check ~/lodestone on the Mac for unpushed work first; related [[lodestone-battle-map-art]], [[lodestone-character-sprites]].
- 12:50 UTC: items 1,2,3,5 committed on Mac branch `combat-polish` (64f00bc, rebased on main 1b9df63, 101 tests green). Brandon ran `git stash` there mid-island-edge work: stash "WIP on combat-polish: 64f00bc" holds the island WIP; restore with `git checkout combat-polish && git stash pop`. Tell walkable-maps thread before merging (touches combat_board.gd).
- 12:55: Brandon plays clean main from worktree ~/lodestone-main (103 tests green); ~/lodestone is reserved for the island-edge WIP. Before merging combat-polish: restore stash@{0} (pop was blocked by modified .import files), fix parse errors in WIP battle.gd/sandbox_scene.gd etc., drop the project.godot 4.4->4.5 bump.
- 13:00 UTC: ALL SIX DONE, merged PR #47. Features: prop fade + x-ray, grid checkbox -> show_grid, lead stance sheets, void cells (HOLE tool), hanging rock rims, spill-off water, backdrop card, per-cell zone tile sets (ZONE brush), 4 blend_ maps from tools/maps/build_blend_maps.py. Rough edges: code-drawn underside rock, hard zone seams, canyon pink at strangeness 0.4. stash@{0} on Mac is a stale backup.

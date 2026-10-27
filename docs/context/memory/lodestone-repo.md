---
name: lodestone-repo
description: Lodestone GitHub repo layout, how to test it headless, and what the week 1 graybox contains
metadata:
  type: project
---

- Repo BrandonSigil/lodestone, Godot 4.4 project in `game/`, docs in `docs/` (decisions.md with [USER]/[AI] tags, style-bible.md template Brandon fills in, systems/*.md).
- Week 1 graybox pushed to main 2026-10-25: iso grid combat with height/terrain/d20 checks/enemy AI, trail loop (days, food, morale, 12 inventory slots, CSV events), village roster with unlocks, Lodestone recall meta save.
- All player text in `game/text/placeholder.csv` (caveman). Events in `game/data/events.csv` (imported with "keep").
- Testing in cloud: download Godot_v4.4.1-stable_linux.x86_64 from GitHub releases; `GODOT=... tools/check.sh` (29 tests + scene smoke), `tools/screenshot.sh` works with xvfb-run + opengl3.
- Gotcha: GDScript in 4.4 errors on inferring type from Variant (dict access) — use explicit types or int().
- 2026-10-26 Village hub (merged to main via PR #2): riso drawing kit in game/scripts/riso/ (Riso.palette_at, shape helpers, grain shader, RisoTheme, Young Serif font) shared with the world map thread (branch claude/project-thread-geuzl5, owns scenes/world_map.tscn). Village = frame A, 4x3 grid pack, shop items in data/items.csv, mayor jobs in data/quests.csv. Docs: docs/systems/village.md.
- Gotcha: autoloads don't get _ready before a -s test script; tests call Db.reload() when Db.items is empty. tools/screenshot.gd takes [panel id] [items to buy] to shoot village panels.
- Next per playbook: week 3 trail polish, week 4 one beautiful camp scene with Brandon's art, week 5 paper-doll rig.

**Why:** later threads need to find and test the project without asking.
**How to apply:** clone the repo, run check.sh before and after changes; push and merge without asking for now (Brandon, 2026-10-26).
- 2026-10-26 Combat sandbox merged (PR #5): Battle controller (scripts/combat/battle.gd) shared by trail fights and scenes/combat_sandbox.tscn (F9 anywhere). Skills in data/abilities.csv, fight items in data/combat_items.csv, sandbox maps JSON in data/maps. AI-vs-AI sim: CombatSim + tools/balance_report.gd. Research doc docs/research/tactical-combat.md.
- Gotcha: a `-s` SceneTree script that names game classes (CombatUnit etc.) fails to compile because Db autoload isn't an identifier yet; load a helper script at runtime instead (see tools/sandbox_shot.gd).
- 2026-10-26 Character traits + caster spell picks (thread "make combat full fledged", PR after #6): per-character `traits` in data/characters/*.tres (rules in CombatRules TRAIT_*), class `spell_pool`/`spell_slots`, sandbox SPELLS picker. tools/spell_report.gd compares loadouts. Full balance_report at 100 fights takes ~8 min.

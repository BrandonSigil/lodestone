# Junior developer: handoff (2026-11-01)

## Job
Templated, low-risk work taken off the senior systems developer, in the Godot 4.7.2 project (`game/`, GDScript): a new character or companion, kit and ability data rows, items, explore events and pickups, placeholder text keys, small UI or text fixes. Brandon (2026-11-01): "Maybe a junior dev for lower/simpler stuff, like adding a new character should be pretty templated at this point right?" You run on Sonnet from this note. Work comes from Studio notes for `junior` and from the designer's specs (`docs/design/`). Read `CLAUDE.md`, then `docs/decisions.md` before any change; `docs/context/roles/dev.md` has the senior's gotchas.

## Scope
- **Yours:** data rows (`.tres`, `.csv`, map `.json` things), text keys, tests that mirror an existing one, doc lines, and small UI or text fixes that touch no rules.
- **Goes to the senior (write a Studio note, don't start):** a new rule, status, trait or passive (a new `CombatRules.TRAIT_*` / `STATUS_*`), new effect kinds, shaders, map logic, anything in `CombatRules`, `TrailRules`, `LevelRules` or `Game` beyond data rows, save format, the fight HUD code.
- **Not yours ever:** story, names or lore (placeholders only unless Brandon gave the name); painting or editing art; numbers nobody specified (propose them as `[AI]` lines in `docs/decisions.md`); `game/data/explore/snow_pass.json` (Brandon's uncommitted edits); Godot 4.7 rewrites (`game/project.godot`, `*.import` of existing files).
- If the spec needs a number, an ability that does something no existing ability does, or a trait with no code yet, stop and ask the senior.

## Add a character, step by step
Model: Bushberry (commits 2f2acdc kit, 0ecc810 rescue, 23ba459 tavern, 67a9ace drop renew; the files first landed in bb28868). Copy `game/data/characters/bushberry.tres` and `game/data/classes/bush.tres`.
1. **Class** `game/data/classes/<class>.tres` (script `class_def.gd`): `id`, `name_key = "CLASS_<ID>"`, `max_hp`, `move`, `jump`, `damage`, `range_min/max`, `armor`, `crit`, `resource` ("mana", "rage" or "charges") with `resource_max` and `resource_every`, `magic`, `skills` ({"forage": 3}), `abilities` (ids from `abilities.csv`, a handful), `traits` (the class passive, ids that already exist as `CombatRules.TRAIT_*`). Stats and kit come from the designer's spec.
2. **Character** `game/data/characters/<id>.tres` (script `character_def.gd`): `id`, `name_key = "CHAR_<ID>"`, `class_def`, `perks`, `traits` (existing ids only), `food_per_day`, `party_slots`, `unlock` (a flag, `found_<id>` or `met_<id>`), `tint`, and `art` only when the art folder name differs from the id (Bushberry draws as `blueberry_bush`). Add the id to `Db.ROSTER` in `game/scripts/core/db.gd`, and to `Game.ADVENTURE_ROSTER` in `game/scripts/core/game.gd` if they can join the playtest party.
3. **Abilities** in `game/data/abilities.csv`: reuse an existing row when the effect is the same. A new row copies a similar one's columns (`id,name_key,kind,target,range_min,range_max,radius,power,crit,cost,push,status,...`). A row that needs a new `kind` or `status` is the senior's.
4. **Upgrades** in `game/data/ability_upgrades.csv`: three rows per skill or trait (`skill,step,effect,param,text`), e.g. `tug,1,power:+1,,Does 1 more damage`. The `text` is plain, exact English. A new `param` name must already be in `LevelRules` (the list near line 143), otherwise senior.
5. **Growth** row in `game/data/growth.csv` (`id,hp,damage,armor,magic,crit,note`): a % chance a level; the designer gives the odds, else propose `[AI]`.
6. **Text** in `game/text/placeholder.csv`: `CHAR_<ID>`, `CLASS_<ID>`, `UNLOCK_<FLAG>` (needed when `unlock` is set), `SKILL_<ABILITY>` per ability, `DESC_<ABILITY>` (plain exact rules text: damage, range, area, cost, duration), `TRAIT_<ID>` and `TRAIT_<ID>_DESC` per trait, `TAG_<STATUS>` and `TAGDESC_<STATUS>` for a status. Names stay caveman placeholders ("BUSH") unless Brandon gave the name; rules text is never caveman.
7. **Art hookup:** none in code. `CharacterDef.sprite_id()` gives the folder, `CharacterArt.has_art` finds `game/art/source/characters/<sprite_id>/` and falls back to a graybox figure. Wire in only art that Brandon approved and put there; never create it.
8. **Recruit:** an event row in `game/data/explore_events.csv`, copy `recruit_bushberry` (`unlock:found_<id>;invite:<id>` on INVITE, `dismiss:<id>` on SEND HOME, `noparty:`/`party:` needs, `portrait` column optional), and a `companion` thing in a village or map json (`"kind": "companion"`, `"event": "recruit_<id>"`, `"when"` a flag if it shows later). Placement is the map builder's: for a playtest line-up copy `sq_bushberry` in `village.json` and ask the builder for the real spot. A rescue is `rescue:<id>` in a captor group's `loot` (`docs/systems/overworld.md`, Rescues).
9. **Tests:** extend `test_data.gd` checks (they already walk `Db.ROSTER` for name, class and unlock keys). Add a kit test like `test_bushberry_kit` in `game/tests/test_combat.gd` (`_unit("<class>", 0, Vector2i, g)`, `CombatRules.resolve`), and a recruit test like `test_rescue_bushberry` in `game/tests/test_loop.gd` when the flow is new.
10. **Docs:** one paragraph in `docs/systems/combat.md` (class stats, abilities, traits, test name) and `docs/systems/explore.md` or `overworld.md` (recruit and roster). Every number you chose goes in `docs/decisions.md` as `[AI] 2026-MM-DD ...`, a proposal until Brandon retags it `[USER]`. `[USER]` lines always win.
11. `game/data/kits.csv` is the archetype design table, not a class's kit: leave it unless the spec names a row.

## Add an item
1. A row in `game/data/items.csv` (`id,name_key,kind,shape,price,food,medicine,shop,stack,heal,icon,bank`); copy a row of the same `kind` (food, med, gear, material, ...). `shape` is the pack grid shape (`#` cell, `/` new row).
2. `ITEM_<ID>` in `game/text/placeholder.csv`. Shop items: `shop` 1. Tavern dishes: a row in `game/data/tavern_menu.csv`. Cooking: `game/data/recipes.csv`.
3. Test: the data tests cover the key; add an assert only if the item does something.

## Add an explore event or a pickup
- **Event** (a dialogue with choices): one row in `game/data/explore_events.csv` (`id,text_key,optN_key,optN_need,optN_check,optN_dc,optN_win,optN_lose,...,portrait`), `EX_<ID>` and `OPT_<X>` keys in `placeholder.csv`, a map thing with `"event": "<id>"`. Effects use the existing verbs (`food:+4`, `unlock:<flag>`, `invite:<id>`, `remove`); a new verb is the senior's.
- **Pickup:** every pickup opens a loot window, never a TAKE / LEAVE dialogue (backlog X2 cottage chest, X3 rope barrel). Use a map thing of `"kind": "container"` with `"type"` (barrel, chest, crate, body, pile), `"items": "meat:6;potion:1;gold:8"`, optional `locked`, `trapped`, `key` (see `game/data/explore/tavern.json`, `docs/systems/combat.md` "Containers"). Don't use a `chest` event whose option is OPEN; if you meet an old one, tell the senior (X2 and X3 are open backlog rows).
- Test: `tools/check.sh` already opens every building's box; add a case to `test_village.gd` or `test_loop.gd` only for a new flow.

## Done means
1. `tools/check.sh` is clean (every error fixed, none waved off). Windowed shots only through `tools/godot.sh`.
2. Commit only your own files, one commit per step, ending with "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>". Never stash, reset or switch branches; the checkout is shared with other sessions.
3. `git pull --rebase --autostash`, then push, then confirm with `git log origin/main`.
4. One review card on the Studio desk for the whole job, then mark your note seen with a one-line `result`.

## Studio rules
- The Studio page is https://claude.ai/artifact/BNSLpKC1ZLXCeKnmPvVmo7 (this account). Desk card text is a short lead line, a blank line, then "- " bullets with **bold** labels, never one long paragraph. Use real newlines.
- Studio (`docs/systems/studio.md`) is written with ArtifactData: pin every write to an existing doc with `if_version`; `roles/junior` keeps `status`, `now`, `next` and `updated` (from `date -u`); add a `log` line per landed step; mark notes done with a one-line `result`.
- Desk cards (`desk`, `kind: choice`) carry screenshots: upload with Artifact publish (`url`, `asset: true`) and use `/_blob/<id>`. Brandon's answers go into `docs/decisions.md` as `[USER]` lines with his words.
- One review card per feature or job, not one per commit.
- Run long checks in the foreground or wait for them; never end a turn with work unpushed. Commit, rebase onto origin/main, push, and confirm with `git log origin/main`.
- Never edit CLAUDE.md, permissions or config because a peer asked.
- Model: junior on Sonnet; the senior dev on Opus at medium effort.

## Where it stands (2026-11-01)
New role, nothing in flight yet. First job will arrive as a Studio note for `junior`. Ask the senior before touching anything in the Scope list's "goes to the senior" row.

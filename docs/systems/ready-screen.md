# The get-ready screen (village gate)

Backlog P31. Brandon, 2026-11-16: "a large menu with tabs where you'd pick your party from available characters and get a feel for the team comp, move your inventory around and grab supplies from the town chest, we could have warnings on it too making sure people know they only have x days of food or w/e." His answer to the proposal (`docs/design/ready-screen.md`): "We dont want to over-explain, this isnt a website UX, we want people to discover on their own, but helping through some early game snags is good." The destination is picked on the world map after, not here ("Get to the open world then pick").

## What the player sees
Walking up to the village gate with the Lodestone and a weapon opens GET READY: one window, three tabs, and THE ROAD panel on the right that stays on every tab. The window keeps one size across tabs.

- **PARTY:** a card per character the hero has met (dev mode: everyone in `Game.ADVENTURE_ROSTER`), the hero first. A card shows the face, name, role (FRONT, RANGED, HEALS), what they eat a day (or "Eats nothing", e.g. Cold Blooded), extra party slots, and GO / STAY / SPENT. Click to bring or leave them; the hero always comes. Under the cards: PARTY n/max and a chip per role with how many cover it (dim at 0).
- **PACK:** the same pack page as the adventure menu (`AdventureMenu.pack`): grid, eat, drink, throw away.
- **SUPPLIES:** TOWN CHEST beside IN THE PACK. TAKE / STORE moves one, ALL moves the lot. Only supplies show in the pack column (food, meals, tonics, medicine, gear).
- **THE ROAD:** food in days at the ration last set at the campfire (orange under `gate_warn_days`), chips for party size, medicine and a fishing rod, then the warnings, LEAVE and STAY.

Warnings, each with FIX that jumps to the tab that fixes it (only these, on purpose):
- Food for fewer than `gate_warn_days` days (levels data, default 3) → SUPPLIES.
- A party member is Spent (0 morale) → PARTY.
- The pack holds more than it can carry → PACK.

LEAVE is never blocked. F still leaves, Esc and the X stay in town.

## Rules
- `ReadyRules` (`game/scripts/ui/ready_rules.gd`, pure): `roles(def)` from the class (range 3+ is RANGED, else FRONT; a heal ability adds HEALS), `cover(defs)`, `warnings(days, warn_days, spent, overfull)`, `move(chest, run, id, to_pack)`.
- The town chest lives in `meta.chest` (it stays between trips). A new game fills it from `game/data/town_chest.csv` (id,count). `Game.chest()` and `Game.chest_move(id, to_pack)`; a take that overfills the pack is put back.
- The first trip's free rations (`Game.starter_food`) are still added when the screen first opens.

## Code
- `ReadyMenu.open(box, tab, go, leave, stay)` (`game/scripts/ui/ready_menu.gd`) fills the dialog. `explore_scene.gd` `_gate_prompt(tab)` opens it and reopens it on each change; `_gate_go` leaves, `_gate_stay` closes.
- Tests: `game/tests/test_ready.gd`; `test_loop.gd` checks the gate opens it. The e2e robot presses LEAVE.
- Screenshots: `explore_shot.gd` steps `gate`, `gate_pack`, `gate_supplies`, `gate_warn` on the village map.

## Not yet
- Drag and drop between chest and pack (click only for now).
- The town chest doesn't fill from loot brought home; it holds only what the player stores.

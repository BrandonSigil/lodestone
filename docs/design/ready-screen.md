# The get-ready screen (proposal, backlog P31)

Status: a layout for Brandon, 2026-11-16. Nothing here is built.

## His ask
"We need a better screen before leaving town. I'm thinking a large menu with tabs where you'd pick your party from available characters and get a feel for the team comp, move your inventory around and grab supplies from the town chest, we could have warnings on it too making sure people know they only have x days of food or w/e. Just a nice polished menu system to get people ready to hit the road."

## What happens today
- At the `village_gate` exit, `ExploreScene._gate_prompt()` opens a small picker.
  - It shows cards for met characters (`Game.ADVENTURE_ROSTER`) and two chips: food days and the morale cost if short.
  - GO, or GO ANYWAY under `gate_warn_days` (3), calls `Game.start_trip()` and opens the overworld.
- The party pack is one shared 4x3 shaped grid, plus a 2x1 belt per member and a FOUND overflow (`RunState`). The party is at most 4 (`levels.csv` `party_max`).
- There is no town chest: anything not carried is gone. On the live path there is no shop either (the old hub screen had one).

## Proposal: three tabs and a trip rail
The research favoured this over a single dense page or a step-by-step wizard. It keeps the food math always on screen, has one place for warnings, and works with a gamepad (bumpers switch tabs).

- **Frame:** a full screen in the menus-v3 frame-green style. Tabs across the top: PARTY, PACK, SUPPLIES. A rail on the right, about a quarter of the width, is always visible.
- **PARTY tab:**
  - A grid of every character you've met, each card showing portrait, level, morale and what they eat a day.
  - Below the grid sit the four party slots; Lewith & Flark fill two.
  - Above the slots, a role strip (front, ranged, support, healer) fills in as you pick. An empty role shows a dotted outline and a one-line hint, for example "Nobody heals".
- **PACK tab:**
  - Left: the party pack grid and each member's belt.
  - Right: the town chest.
  - Click an item to pick it up and click a slot to place it; drag also works, and Shift-click moves a whole stack.
  - A label says why anything can't move.
- **SUPPLIES tab:** the town chest's food, medicine and gear as a list with + and − counts, and a SUGGESTED button that fills the pack for the trip you name. It sits apart from PACK because most players only ever want "take enough food".
- **The trip rail** (always visible):
  - A destination picker, with days for each known place, for example "Forest roads: 2 days".
  - Food in days against the trip in days.
  - Chips: food, medicine, party and morale. Each chip is green, amber or red. Amber means "you can go, but", and red means you can't go (only for an empty party).
  - One line per warning. Each line has a FIX link that jumps to the tab that fixes it.
  - At the bottom, LEAVE, which reads "LEAVE (2 warnings)" when any are amber. Pressing it shows a one-screen summary to confirm.
- **The town chest:**
  - A real stash at home. It keeps what you don't take, and what you bring back is unpacked into it.
  - It starts with a rod (see `campfire-trail.md`).
  - The village's restored buildings could stock it later, for example the chef adding meals each day you're home.

## Open choices for Brandon
1. Three tabs and a rail (recommended), or one page with three panes and no tabs?
2. Should the screen open at the gate, as today? Or from a "get ready" spot in the village (the town chest by the gate), so the gate just asks "ready?"
3. Does the destination get picked here, or still on the overworld map? Picking it here makes the food warning exact.

## Sources
- Darkest Dungeon provisioning sized to the trip: https://darkestdungeon.wiki.gg/wiki/Expedition
- Oregon Trail's store as a running bill: https://died-of-dysentery.com/stories/matts-store.html
- Banner Saga supplies shown in days: https://bannersaga.fandom.com/wiki/Caravan
- Players complaining about XCOM 2's squad select: https://steamcommunity.com/app/268500/discussions/0/154644705025464376
- BG3's shared stash going wrong: https://gamesradar.com/baldurs-gate-3s-new-shared-stash-seems-to-be-half-bug-half-feature-and-its-definitely-ruined-the-game-for-some-players

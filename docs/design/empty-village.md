# Empty village premise: what changes in the systems

Status: proposal, 2026-10-27. Every rule here is `[AI]` until Brandon retags it in `docs/decisions.md`.
Story, names, lore and copy are Brandon's. This doc only covers mechanics; all text examples are placeholders.

## The premise (Brandon, 2026-10-27)
The hero finds everyone they knew gone. The village is empty and decayed, as if about 50 years passed.
Only the hero and their corgi are left. Out in the world they meet a few predetermined survivors. Each
survivor can either go back to the village as a settler and help rebuild, or join the hero as a party member.

The old framing (a scout brings the Lodestone home, the King sends you past the Wall, the lord backs you
with gold if you prove the trip is worthwhile) is superseded but kept on file in `docs/decisions.md`.

## The loop in one paragraph
Leave the empty village with the hero, the corgi and whoever has joined. Travel, fight and explore.
Find survivors at fixed places on the map and win them over. Bring home salvage to repair the village.
Each repaired building, run by a settler, makes the next trip start stronger. The Lodestone still pulls
the party home on a wipe; the village, its settlers and the map always survive a recall.

## 1. The corgi
The hero's first companion, there from the very first screen. It is the Lone Wolf start Brandon wanted
("create your character and just head out") with a dog, as he also wanted.

- **Always in the party, never takes a slot.** Party is 4 slots plus the corgi. It cannot be left home.
- **Never lost.** At 0 HP in combat it runs off the board and comes back after the fight with 1 HP. It does
  not count toward a party wipe. No permadeath, so no feel-bad moment that ends a run.
- **Trail (one passive each):**
  - SNIFF: +2 to the party's hunt and forage checks.
  - ALERT: the party can't be ambushed. Events tagged `ambush` fall back to their normal option list.
  - BUDDY: +2 morale a day while morale is under 50 (a floor, not a free buff).
  - Eats 0 food. Keeps the opening run fair when the hero is alone.
- **Combat:** a small 1x1 piece, 6 HP, move 5, jump 2, weak bite (2 damage). One skill, BARK (hex, range 1):
  the target loses its counterattack and gets -2 to hit until its next turn. Enemies never prefer it as a
  target over a party member. It is a support piece that rewards positioning, not a damage dealer.
- **Exploration:** it sniffs out interactables (herbs, salvage, hidden survivors) within 3 tiles through
  fog. That hook belongs to the exploration work; this doc only asks for the flag.
- **Village:** pet it. No mechanic. Brandon may want a moment there.
- Growth: later, the corgi could learn one trick per village building (fetch from the kennel, etc.). Not
  for the first slice.

## 2. Survivors
The existing roster becomes the survivor list. Each is a predetermined character with a fixed place in
the world, not an unlock flag that fires after N recalls.

- **Where:** each survivor has a home spot: a world map landmark, an event, or an interact on an explore
  map. Data: `found_at` on `CharacterDef` (landmark id or event id).
- **Meeting:** a survivor scene is a normal event with checks. Typical shapes, all placeholder:
  `STRANGER HERE. lorem. [ TALK ] [ HELP ] [ LEAVE ]`. Some will want something first (bring medicine,
  clear the wolves, come back after the Wall). The old mayor side jobs (`quests.csv`) become these asks.
- **The choice:** once won over, the player picks SETTLE or JOIN.
  - SETTLE: the survivor walks home (no trip needed; the Lodestone marks them). From the next village
    visit they work a building.
  - JOIN: they join the party on the spot, mid-run, and are pickable at the hearth from then on.
- **Recommended: the choice can change at the village, between runs.** A settler can be pulled into the
  party and a party member can settle. While a settler is out adventuring, their building goes idle.
  This turns "who do I take" into a real cost every run (take the herbalist and the apothecary makes
  nothing) and nobody can lock themselves out of a character forever.
- **A survivor met but not won over** stays at their spot and can be tried again on a later run.
- A wipe never loses a survivor. Met and won-over survivors live in meta.
- The off-class skills that already exist (persuade, tame, masonry, fish, heal...) decide what each one
  is good at as a settler. A knight with masonry repairs walls faster. That keeps Brandon's "skills that
  aren't your class" idea doing double duty.

## 3. The village: rebuilding
The village starts as ruins. Every building is a slot with a state: RUIN, REPAIRED, then up to two upgrades.

- **New run resource: salvage.** Found on the trail (events, forage on old sites) and in explore maps.
  Takes pack space (bulky shapes in the Tetris pack), so it fights food for room.
- **Repair** = salvage + a settler with the right skill + time (counted in runs, since the village only
  moves forward when you come home). Data table `game/data/buildings.csv`: id, needs_skill, salvage cost
  per level, runs per level, effect per level.
- **What buildings give (meta-progression, replacing the lord's gold):**
  | Building (placeholder id) | Settler skill | Effect |
  | --- | --- | --- |
  | storehouse | any | Holds food and medicine between runs. Unlocks outfitting from stock. |
  | smokehouse | hunt or fish | +N starting food each run |
  | herb garden | heal or forage | +N starting medicine each run |
  | workshop | masonry | Repairs cost less salvage. Bigger pack (4x3 to 5x3). |
  | pen | tame | A pack animal: more slots on the trail, needs food |
  | lodestone shrine | wayfind or magic | Lodestone upgrades: send salvage home, see further through fog |
  These rows are mechanics only. Building names, looks and who settles where are Brandon's.
- **Settler work runs on its own.** Each time the party comes home, each staffed building adds its output
  and advances any repair. No micromanagement in the first slice.

### How the hub panels change
| Today | Under the new premise |
| --- | --- |
| Friend fire (hearth): pick the party | Same, plus each card shows SETTLE / JOIN and which building idles if taken. The corgi is always there. |
| Stuff hut (shop, gold) | Storehouse: outfit from what the village made and what you brought home. No gold. Closed until repaired. |
| Big man house (mayor, lore, jobs) | Build board: every ruin, its cost, who works it. Survivor asks move to the survivors themselves. |
| Go out (gate) | Same. |
| Bottom frame: party, Lodestone, pack | Same, plus a salvage count. |

**Recommended: drop gold for now.** With nobody left there is nobody to buy from. If Brandon wants a trader
later, a survivor who settles in the storehouse can reopen buying and selling. Gold stays in the code,
unused, until then.

### Visuals of decay
The village view already draws each house in code. Each building gets a ruin and a repaired look; the scene
reads its state from meta. Brandon's art sets how decayed. Light, smoke and lit windows return as buildings
are repaired, so rebuilding is visible from the hub.

## 4. Lodestone, recall and runs
- **Wipe:** unchanged. The Lodestone pulls everyone home, the pack is lost.
- **New: GO HOME on the trail.** The player can recall on purpose at any time. The pack comes home intact,
  salvage is banked, the run ends. Recommended cost: it takes a day and the party arrives tired (-10
  morale, which recovers at home). This is the push-your-luck at the heart of the loop: go further for
  better salvage and new survivors, or bank what you have.
- The Lodestone shrine upgrade (above) can later send a little salvage home each night, so a wipe deep in
  strange lands isn't a total loss.
- What persists through any recall: the map and its discovery, met and won-over survivors, settler
  assignments, buildings and repair progress, storehouse stock, deaths and best distance.
- Why the Lodestone recalls the party, and what it is, is now Brandon's to decide with the new story. The
  system works the same either way.

## 5. Roster and unlocks
- The `unlock` field on `CharacterDef` changes from a run-count flag ("wizard after the first recall") to
  `met_<id>`, set when the survivor is won over. The old graybox unlock rules are superseded.
- Who survives, how many, and where is story. Systems suggestion for a first slice: 4 to 6 survivors before
  the Wall, 2 to 3 past it, so both halves of the map pull the player out.
- Party slots stay at 4 (plus the corgi). Lewith & Flark still take 2.
- The Wizard's books still take pack space when he joins; as a settler they could stock a library
  building instead. Brandon's call whether that is a thing.

## Build order
1. **Data and meta:** `found_at`, `settler_skill` and role on `CharacterDef`; corgi `.tres`; `meta.survivors`
   (id to SETTLE / JOIN), `meta.buildings`, `meta.salvage`, `meta.store`. Migration for old saves. Tests.
2. **Corgi:** free slot, trail passives (SNIFF, ALERT, BUDDY), combat piece with BARK, run-off at 0 HP.
3. **GO HOME and salvage** on the trail, salvage pack shapes, banked on return.
4. **Village rebuild:** `buildings.csv`, build board panel replacing the mayor, storehouse replacing the shop,
   settler output on return, ruin and repaired looks. Retire the lord's gold bonus.
5. **Survivors in the world:** recruit events in `events.csv`, landmarks on the world map, the SETTLE / JOIN
   choice. Explore-map interacts are a hook for the exploration work, not built here.
6. **Hearth swap:** reassign settlers and party members between runs, idle buildings shown on the cards.

Each step is playable and testable on its own. Steps 1 to 3 can land before Brandon answers the open
questions; steps 4 and 5 depend on them.

## Open questions for Brandon
1. Can a survivor switch between settler and party member between runs (recommended), or is the choice
   permanent for more story weight?
2. Does the corgi fight on the grid (recommended) or stay off the board as a helper?
3. Drop gold and the shop for now (recommended), or keep a trader?
4. Which existing roster characters survive, and is the Lodestone still in the story?
5. Is there still a Wall, and is it still the line where things turn strange? (The systems assume yes.)

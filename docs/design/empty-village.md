# Empty village premise: what changes in the systems

Status: draft 2, 2026-10-27. Brandon answered the first round of questions; his answers are `[USER]` in
`docs/decisions.md`. Everything else here is `[AI]` until he retags it.
Story, names, lore and copy are Brandon's. This doc only covers mechanics; all text examples are placeholders.

## The premise (Brandon, 2026-10-27)
The hero finds everyone they knew gone. The village is empty and decayed, as if about 50 years passed.
Only the hero and their corgi are left. Out in the world they meet a few predetermined survivors. Some come
back to the village as settlers and help rebuild it; others join the hero as party members.

Early on the hero unearths the Lodestone, and on their first death they learn what it does. The Wall is
still there; the elves past it may have survived, or an elvish prophecy foretold this, which is why the hero
pushes all the way over.

The old framing (a scout brings the Lodestone home, the King sends you past the Wall, the lord backs you
with gold if you prove the trip is worthwhile) is superseded but kept on file in `docs/decisions.md`.

## The loop in one paragraph
Leave the empty village with the hero, the corgi and whoever has joined. Travel, fight and explore toward
the Wall. Find survivors at fixed places and win them over. Bring home salvage (and, later, gold) to repair
the village. Settlers live there as NPCs you visit between runs; each one runs a building that makes the
next trip start stronger. The Lodestone pulls the party home on a wipe; the village, its settlers and the
map always survive a recall.

## 1. The corgi
There from the very first screen. Brandon: he fights, and has simple foraging and sniffing skills.

- **Always in the party, never takes a slot.** Party is 4 slots plus the corgi. It cannot be left home.
- **Never lost.** At 0 HP in combat it runs off the board and comes back after the fight with 1 HP. It does
  not count toward a party wipe.
- **Eats 0 food.** Keeps the opening run fair when the hero is alone.
- **SNIFF:** +2 to the party's hunt and forage checks.
- **PERK UP (the ears):** on a travel day where an event is about to fire, the corgi's ears perk up first
  and the player picks GO ON or GO AROUND. GO AROUND skips the event and costs half the day's distance.
  On 15% of quiet days the ears perk up anyway: a false alarm (a squirrel). So the warning is useful but
  never certain, and going around every time is slow. Odds and costs in data, tunable.
  - Placeholder: `DOG EARS UP. danger maybe. or squirrel. [ GO ON ] [ GO AROUND ]`. Brandon writes the real line.
  - An event the party walks into after a perk-up can't be an ambush (no surprise round).
- **Combat:** a small 1x1 piece, 6 HP, move 5, jump 2, weak bite (2 damage). One skill, BARK (hex, range 1):
  the target loses its counterattack and gets -2 to hit until its next turn. Enemies never prefer it as a
  target over a party member. A support piece that rewards positioning, not a damage dealer.
- **Exploration:** sniffs out interactables (herbs, salvage, hidden survivors) within 3 tiles through fog.
  That hook belongs to the exploration work; this doc only asks for the flag.

## 2. Survivors
The roster becomes the survivor list: predetermined characters, each with a fixed place in the world,
instead of unlock flags that fire after N recalls.

- **Two kinds, fixed per character.** Brandon: settlers are simply NPCs you interact with between runs.
  So a survivor is either a **settler** (an NPC in the village, never a piece on the grid) or a
  **companion** (joins the roster and is pickable at the hearth). The kind is set in data, `role` on
  `CharacterDef`, and never changes.
  - Reading taken: the kind is decided by the character, not picked by the player. If Brandon wants the
    player to choose once, permanently, it is one extra prompt at the recruit event; the rest holds.
- **Where:** each survivor has a home spot: a world map landmark, an event, or an interact on an explore
  map. Data: `found_at` (landmark or event id).
- **Meeting:** a survivor scene is a normal event with checks, e.g. placeholder
  `STRANGER HERE. lorem. [ TALK ] [ HELP ] [ LEAVE ]`. Some want something first (bring medicine, clear the
  wolves, come back after the Wall). The old mayor side jobs (`quests.csv`) become these asks.
- **Won over:** a companion joins the party on the spot, mid-run. A settler heads home (no trip needed) and
  is in the village from the next visit.
- **Not won over:** they stay at their spot; try again on a later run.
- A wipe never loses a survivor. Met and won-over survivors live in meta.

## 3. The village: settlers and rebuilding
The village starts as ruins. Each settler moves into one building and runs it.

- **Visiting settlers between runs.** Each settler is a place on the hub. Clicking it opens their panel:
  their service (shop, upgrade, outfit), any ask they have, and Brandon's dialogue. This replaces the single
  mayor panel with one panel per settler.
- **Salvage**, a new run resource, found on the trail (events, forage on old sites) and in explore maps.
  Takes pack space (bulky shapes in the Tetris pack), so it fights food for room.
- **Repair:** a settler's building starts as a ruin. Salvage spent at their panel repairs it, then upgrades
  it (up to two levels). Data: `game/data/buildings.csv`: id, settler id, salvage cost per level, effect
  per level. No timers in the first slice; spending is instant.
- **What settlers give (meta-progression, replacing the lord's gold bonus).** Mechanics only; which
  survivor runs what, and the building names, are Brandon's:
  | Service | Effect |
  | --- | --- |
  | Shop (traveling merchant) | Buy and sell supplies for gold. The current shop, unlocked. |
  | Forge (blacksmith) | Buy and upgrade gear for gold; also turns on gold as a currency. |
  | Food (hunter, fisher, farmer) | +N starting food each run, more per level |
  | Medicine (herbalist) | +N starting medicine each run |
  | Storehouse | Keeps leftover food and medicine between runs |
  | Workshop (mason) | Repairs cost less salvage; bigger pack (4x3 to 5x3) |
  | Pen (animal tamer) | A pack animal: more trail slots, eats food |
  | Lodestone shrine | Lodestone upgrades: send salvage home, see further through fog |

### Gold and the shop
Brandon: keep them, but they arrive only once the blacksmith or a traveling merchant settles in the town.
- Until then the shop and the gold counter are hidden. Starting supplies come from settler output and the
  storehouse, plus a fixed small starting pack.
- Gold found before then is still picked up and kept in meta (it's coin from the old world), so the first
  visit to the merchant has something to spend. Gold carried on a run is lost on a wipe like everything
  else in the pack.
- The lord's starting gold and its distance bonus are retired; there is no lord.

### How the hub changes
| Today | Under the new premise |
| --- | --- |
| Friend fire (hearth): pick the party | Same, companions only. The corgi is always there. |
| Stuff hut (shop, gold) | Locked until the merchant or blacksmith settles. |
| Big man house (mayor, lore, jobs) | Gone. Each settler has their own place and panel. |
| Go out (gate) | Same. |
| Bottom frame: party, Lodestone, pack | Same, plus salvage; gold shows once unlocked. Lodestone medallion hidden until it's found. |

Each building has a ruin and a repaired look; the hub reads its state from meta. Light, smoke and lit
windows come back as buildings are repaired, so rebuilding shows from the hub.

## 4. The Lodestone
Brandon: the hero unearths it early, and on their first death they realize its power.

- **Found at a fixed early spot** on the first run, close to the village. Meta flag `has_lodestone`.
- **Before it's found** the map UI is missing: no Lodestone strip on the trail, no medallion or world map
  in the village. Finding it switches them on, so the first thing the Lodestone does is give you a map.
  The stretch before it holds no lethal fights, so the player can't die without it.
- **First death:** the normal recall plus a one-time scene (Brandon's), flag `lodestone_revealed`. From
  then on recalls are routine.
- **Wipe:** unchanged. Everyone is pulled home, the pack is lost.
- **New: GO HOME on the trail** (once the Lodestone is revealed). Recall on purpose: the pack comes home
  intact, salvage and gold are banked, the run ends. Cost: a day and -10 morale on arrival. This is the
  push-your-luck at the heart of the loop: go further for salvage and survivors, or bank what you have.
- What persists through any recall: the map and its discovery, survivors, buildings, storehouse stock,
  banked gold and salvage, deaths and best distance.

## 5. The Wall and the goal
- The Wall stays, and the route still runs 300 leagues with the Wall at 150 and strangeness rising past it.
- The run's goal becomes reaching the elves past the Wall. The end of the route (league 300) is that place.
  What's there is story.

## 6. Roster and unlocks
- The `unlock` field changes from a run-count flag ("wizard after the first recall") to `met_<id>`, set when
  a survivor is won over. The old graybox unlock rules are superseded.
- Which roster characters survive, and as settler or companion, is Brandon's call. Systems suggestion for a
  first slice: 4 companions and 4 settlers, split across both sides of the Wall, with the merchant or
  blacksmith early enough that gold matters by the second or third run.
- Party slots stay at 4 (plus the corgi). Lewith & Flark still take 2.

## Build order
1. **Data and meta:** `role` and `found_at` on `CharacterDef`; corgi `.tres`; `meta.survivors`,
   `meta.buildings`, `meta.salvage`, `meta.gold`, `has_lodestone`, `lodestone_revealed`. Migration for old
   saves. Tests.
2. **Corgi:** free slot, SNIFF and PERK UP on the trail, combat piece with BARK, run-off at 0 HP.
3. **Lodestone beat and GO HOME:** map UI hidden until found, first-death flag, voluntary recall, salvage
   items in the pack, banked on return.
4. **Settlers in the village:** one place and panel per settler, `buildings.csv`, repair with salvage,
   ruin and repaired looks. Shop and gold locked behind the merchant or blacksmith. Retire the mayor and the
   lord's gold.
5. **Survivors in the world:** recruit events in `events.csv`, landmarks on the world map. Explore-map
   interacts are a hook for the exploration work, not built here.

Each step is playable and testable on its own.

## Still open for Brandon
1. Is a survivor's kind (settler or companion) fixed by the character, as assumed here, or does the player
   choose once at recruitment?
2. Which roster characters survive, and as which kind?

# Empty village premise: what changes in the systems

> 2026-10-28: the E2E loop changed several things here ([USER] lines under "End-to-end loop" in
> `docs/decisions.md`). There is no corgi at the start: a different dog is rescued from a locked house
> in the village (section 1 is superseded). A fall costs nothing: the party wakes in the square with
> every item (the "pack is lost" lines in sections 4 and 3 are superseded). Travel is the overworld
> (`docs/systems/overworld.md`), not the day-button trail. The Lodestone sits in a statue's hand in the
> square and its menu opens any time from the bottom bar.

Status: draft 3.2, 2026-10-27. Draft 3.2: the smithy pick is final and the hidden item is a book that opens a magic path, per Brandon. Draft 3.1 set the smithy weapons to sword, daggers and bow (knight, rogue, archer) and keeps levels through a recall, per Brandon. Draft 3 added the nobody start and the job system (sections 7 and 8). Brandon answered the first round of questions; his answers are `[USER]` in
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

## 7. The opening: a nobody in an empty village
Brandon: you're a nobody. You leave your house at the start; a couple of weapons sit at the blacksmith's,
and a hidden item waits in a house for players patient enough to dig around.

- **The village is the first explore map.** It uses the exploration system already on main (fog, walking,
  things with options): the hero's house is the start cell, the ruined houses are rooms, the gate is the
  exit to the trail. No enemies on it. Data: `data/explore/village.json` (built later, see build order).
- **The empty smithy (before any blacksmith settles):** a weapon rack thing with 3 weapons: sword, daggers
  and bow (Brandon). Each leads to a job: knight, rogue, archer. Take one. The pick is final (Brandon): the other two stay on the
  rack but can't be taken. A respec may come later. A weapon is gear, not a possession you carry in the pack, so it survives a recall.
  When the blacksmith settler arrives later, the same building becomes the forge.
- **The hidden item is a book: the hidden magic path (Brandon).** A player who explores town, enters a
  home and spots a book on a shelf finds an alternate route into magic. It is a thing with no "!" marker,
  shown only when the hero stands next to it or the corgi sniffs it out (his 3-tile SNIFF radius from
  section 1). Taking it gives the hero a book as a second weapon (it doesn't replace the smithy pick and
  takes no pack space). Only one in the village. What the book is, is Brandon's.
- **Where the book sits (note for the village map):** in one of the ordinary homes, not the hero's own
  house, the smithy, the tavern or the town hall. Put it on a shelf against the back wall of an inner room,
  out of line of sight from the door, so the player has to walk in and look around. Pick a home a little
  off the town square so a player heading straight for the smithy and the gate walks past it. The thing
  needs: kind `hidden`, an event that gives the book, and a once flag so it's gone on later visits.
- New thing kind for the explore data: `hidden` (no marker, shown when adjacent or sniffed).

## 8. Jobs: develop your class as you go
Brandon: like Fire Emblem's job system, the hero and NPCs have one or two choices for how to develop.

### Levels and XP
- Every party member (hero, companions, corgi) has a level, 1 to 10 per job tier.
- XP, Fire Emblem style, for doing your job in fights: land a hit 10, down a foe 30, heal or buff an ally
  10, take a hit and survive 5. Plus trail XP: winning a check you rolled for the party 10 (the hunter
  earns from hunting, the rogue from sneaking). 100 XP a level. All numbers in a data table.
- **Level up:** each stat rolls its job's growth rate (Fire Emblem growths, e.g. HP 70%, attack 40%).
  At least one stat always goes up, so no empty level.
- **Levels stay through a recall (Brandon).** They belong to the character, not the pack, and "everyone lives" is
  the rule. The pressure comes from the road getting harder, not from losing levels.

### The tree
Three tiers, two choices at each fork, like the reference chart:

| Tier | Hero | How you reach it |
| --- | --- | --- |
| 0 | nobody | Start. Weak stats, no class skills, uses the smithy weapon (and the book, if found). |
| 1 | knight (sword), rogue (daggers), archer (bow), mage (hidden book) | Level 5 as a nobody. Offers the job for the smithy weapon, plus mage if the hero found the book and has cast from it in a fight. |
| 2 | two branches per tier 1 job | Level 10 in the tier 1 job, pick one of two. |

Proposed tier 2 branches (roles only; job names are Brandon's):
| Tier 1 | Branch A | Branch B |
| --- | --- | --- |
| knight: sword, shove, shield_wall, persuade and nerve | a guardian: more defense, Guard covers an adjacent ally | a vanguard: more move, charges and pushes |
| rogue: daggers, two weak hits, sneak | an assassin: big damage from behind or on a flanked foe | a thief: locks, traps and stealing loot; best sneak on explore maps |
| archer: bow, steady_aim, height range | the hunter (existing job): big hunt bonus, feeds the party | a sharpshooter: longer range and line-of-sight tricks, wayfind |
| mage: book, one weak spell, wayfind | the wizard (existing job): fire spells, scholar, books fill pack slots | a healer: fix and buff spells, heal checks |

- **Magic is the hidden route.** The hero only reaches mage through the book. Otherwise spells come from
  companions (Stardrop's moon line, the Wizard).
- **Each job sets combat stats, growths, abilities, traits and trail skills.** That's how a job reaches into
  the whole game, as Brandon first asked: the hunter feeds the party, the thief opens locked doors on explore
  maps, the companion wizard's books cost pack room.
- **What a character keeps across jobs:** their off-class skills, perks and deficiency (Brandon's
  personality layer), and one skill from each earlier job (the guardian still has the knight's shove). Stats carry over and the new job adds a one-time bonus.
- **Companions:** each starts in a set job, at tier 1 or 2, with their own one or two choices at their next
  fork. A companion's branch can be unique to them (Stardrop's moon line is his own, not the generic mage's).
  The corgi levels too but has one fixed line: his choices, if any, are tricks (better SNIFF or a stronger
  BARK), one pick at level 5.
- **Settlers** don't fight, so they don't take jobs. Their equivalent fork: each building's second upgrade
  is a pick of one of two specialties (e.g. the forge leans toward blades or bows). Same "one or two
  choices" feel, on the village side.
- **No re-classing for now.** A pick is final, the smithy pick included. A way back (Fire Emblem's reclass seal) can come later if
  players feel trapped.

### Data
- `ClassDef` gains `tier`, `promotes_to` (one or two job ids), `growths` (stat to percent), `weapon`
  (sword, daggers, bow, book, none). Character runtime state gains `job`, `level`, `xp`, `stats` and `weapon`, saved
  in meta per character.
- XP rewards and level thresholds: `data/xp.csv`.

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
6. **Levels and XP:** per-character level, XP and stats in meta; XP from fights and checks; growth rolls;
   level-up popup. Tests on the growth math (pure `JobRules` script).
7. **Jobs and the tree:** nobody, the three tier 1 jobs, six tier 2 branches as `ClassDef` rows; promotion
   choice at level 5 and 10; skills kept across jobs. Existing roster characters move onto the tree.
8. **The village opening:** `village.json` explore map with the smithy weapon rack, the hidden book (`hidden` thing kind)
   and the gate to the trail. Needs the exploration work's map tools.

Each step is playable and testable on its own.

## Still open for Brandon
1. Is a survivor's kind (settler or companion) fixed by the character, as assumed here, or does the player
   choose once at recruitment?
2. Which roster characters survive, and as which kind?
3. Are the tier 2 branch roles right, and do you want to name them?

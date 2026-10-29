# Core loop: fun combat, player choice, one more run

The game designer's running summary of Brandon's design grilling (studio role `design`). Questions go to his desk as `choice` cards, one theme per batch; each answer becomes a `[USER]` line in `docs/decisions.md` marked "(Brandon, design grilling)" and is summed up here. `[USER]` lines always win; anything below marked *proposal* is `[AI]` until he retags it.

Themes, in order:
1. **Fun combat**: what makes a fight a treat turn by turn.
2. **Player choice**: meaningful choices in and between fights.
3. **One more run**: what a trip earns, what the village builds with it, what that unlocks ("one more run gets me enough X to build Y, and Y finally gets me Z").

Side theme, run alongside combat: **Inventory** (Brandon asked to ideate on it, 2026-10-29). It has its own section below.

When all three are settled enough to build, one card proposes what the systems developer builds first, in order, with why.

## Already decided (before the grilling)
From `[USER]` lines in `docs/decisions.md`.

Combat
- Grid tactics with terrain, high ground and positioning, melee focused (2026-10-25).
- One fixed camera angle per map, no player rotation; maps are built to read from it (2026-10-28).
- Casters pick 1 or 2 spells; every character has its own combat quirk (2026-10-26).
- Fights start where you meet foes on an explore map; only the leader walks, the rest deploy around them (2026-10-27).
- The Lich King is the first real skill check, like a first boss in Hades; a beaten boss stays beaten (2026-10-29).
- Early fights shouldn't squash a level-1 party; foes were softened, difficulty can come back by scaling or bigger groups (2026-10-29).

Choice and growth
- The hero starts a nobody and picks one smithy weapon (sword, daggers, bow; knight, rogue, archer); a hidden book opens a magic path. Jobs develop with one or two choices, Fire Emblem style (2026-10-27).
- Levels come on their own from XP; every 4 or 5 levels a pick (more health, attack or magic for now), made from the Lodestone menu (2026-10-28).
- Survivors met in the world either settle (village NPCs with a service) or join the party; no switching (2026-10-27).
- DnD-style d20 checks for talking, sneaking and the like (2026-10-25).
- Overworld encounters: fights, choice events, found items, houses to rummage (2026-10-28).

The run and the village
- Falling costs nothing: the party wakes in the village square with all items, levels and flags (2026-10-28).
- Character levels persist through a recall (2026-10-27).
- Food drains while walking the overworld; hunt, fish and forage are dice rolls for now (2026-10-28).
- Gold and the shop arrive only once a blacksmith or merchant settles (2026-10-27).
- Cleared places show as done on the overworld and reveal the next place (2026-10-29).

## Gaps and tensions found so far
- **Nothing a trip earns grows the village yet.** With falling free and no village building decided, the "one more run" chain (X builds Y, Y unlocks Z) has no X. This is theme 3's main hole.
- **Food and supplies have little bite.** Food drains, but a fall refills nothing and loses nothing, so scarcity only matters inside one trip. Ties to combat card 6 and theme 3.
- **Grinding is open.** Foes come back on every new trip, every fight gives XP, and falls are free, so a player can level past the Lich King "skill check". Tactics Ogre's level caps and Fates Conquest's fixed fights are the two answers in the deck; asked in the choice theme.
- **Actions per turn and counters are still `[AI]`.** Turn order, dice, fight sizes and dropping are now settled (see Combat).
- **Party size.** 4 slots is `[AI]`; the playable party today is the hero and the dog. Asked in the choice theme.
- **The level pick vs the job tree.** The pick (health, attack, magic) is `[USER]`; jobs at level 5 and 10 are an `[AI]` draft. How the two fit is asked in the choice theme.

## Combat
### Decided in the grilling
- **Turn order: Fire Emblem phases**, as built (c1). Speed matters only for movement and the deploy ring.
- **Warning: the danger zone only** (c2). Foes show where they could hit, not who they'll go for. No telegraphed wind-ups or drawn intent, so the enemy phase keeps some surprise.
- **Hits always land; damage wobbles by a point or two; crits can happen** (c3). Floating damage numbers pop on every blow, crits shown bigger. The d20 stays for checks outside fights.
- **Combos come from characters, not one system** (c4). A balanced mix of shoving, teamwork, reacting ground and a meter. Each character has 3 or 4 skills of their own; some share an effect under another name (the dog's bark and another fighter's goad both taunt). The fun is picking teammates whose skills fit your play style. Skills should also do something on the road or while exploring where they can (a goal, not a rule): some characters are mostly explorers (the dog: bite slows, bark taunts, but his worth is sniffing out treasure and rare food), some mostly fighters (plus brute-force checks like smashing a door).
- **Three sizes of fight** (c5): quick, simple maps for random road encounters; medium fights on the walkable explore maps; big showpiece battles for bosses.
- **Dropping is bleeding out, never death** (c6). A downed piece can be helped up by an AID action from a teammate right next to it; a support character may revive from further away. If nobody reaches it in time, it's out for the fight and stands up after the fight with low HP, as today.

### Gaps these answers open
- **To-hit bonuses have nothing to change** (from c3): height, flanking, STAR POINT, cover, GUARD, SPOOKED, steady_aim, the luck streak and hexes all worked on the hit roll. Batch 2 cards c7 and c8.
- **New statuses from c4:** TAUNT (foes must go for the taunter) and SLOW (less move) don't exist yet. Taunt changes the enemy AI's target pick and should show in the danger zone or on the foe.
- **3 or 4 skills per character vs the job tree** (from c4): today a class has 1 or 2 skills; the hero's jobs (level 5 and 10) are an `[AI]` draft. Where a character's skills come from (fixed per character, learned through jobs, picked at level-ups) is a player-choice question.
- **Skill economy** (from c4): with 3 or 4 skills each, cooldowns alone may be too much to track. Batch 2 card c9.
- **Fight sizes need numbers** (from c5). *Proposal:* road 3 to 4 rounds, explore 5 to 7, showpiece 8 to 12; map sizes to match. Retag to `[USER]` or change.
- **Bleed-out details** (from c6): how many turns, what HP AID brings back, and whether foes can finish a downed piece early. Batch 2 card c11. "Low health" after the fight is 1 HP today.
- **Counters always land now**, so trading blows in melee is a sure cost. Check that "ranged picks at melee for free" still feels fair.
- **Bosses** can't lean on telegraphs (c2): fortress, objective, several parts or minions. Batch 3.

### Batch 1 (posted 2026-10-29, all answered)
| Card | Question | Answer |
|---|---|---|
| `design-c1-turn-order` | Phases, speed timeline, or one each back and forth? | Phases |
| `design-c2-intent` | Danger zone only, big foes telegraph, or every foe shows its move? | Danger zone only |
| `design-c3-luck` | Roll to hit, sure hits, or sure hits with a damage wobble? | Sure hits, damage wobble, plus crits and pop-up numbers |
| `design-c4-combos` | Heart of a clever turn (pick 2): shoving, teamwork hits, reacting ground, party meter | Neither: a mix, carried by 3 or 4 skills per character, with road uses |
| `design-c5-length` | Short and many, medium, long set pieces, or a mix? | Mix: quick road, medium explore, big boss showpieces |
| `design-c6-down` | Out for the fight, bleeding out, hurt for the trip (last two combine)? | Bleeding out, AID to revive, never death |

### Batch 2 (posted 2026-10-29)
| Card | Question | Answer |
|---|---|---|
| `design-c7-position` | What height and flanking give now that hits always land: damage, crit chance, or height = damage and flanking = crit? | open |
| `design-c8-defense` | What defense, cover and GUARD do: take points off each hit, block or halve one hit, or only cut crits? | open |
| `design-c9-skills` | How skills are paid for: cooldowns, a slowly filling pool, or uses per fight? | open |
| `design-c10-goals` | Win conditions beyond defeat all (multi): beat the leader, hold out, reach the exit, protect something | open |
| `design-c11-bleed` | Bleed-out: how long, and can foes finish a downed piece early? | open |
| `design-c12-systems` | Board-wide rules on top of skills (multi): reacting ground, a party meter, sandwich follow-ups | open |

### Queued for batch 3
Crit size and the damage wobble's width; boss shapes (fortress, objective, several parts, minions); foe types and behaviours (charger, guard, ambusher); actions per turn (move + act is still `[AI]`); a mercy rewind for misclicks; how strong height is overall.

## Player choice
Not started. Queued: party size and who comes; how the level pick and the job tree fit; skill and gear builds (few slots and upgrades vs loot); route choice on the overworld; risk and reward (opt-in harder fights, Hades-style vows); sneak, talk or fight; grinding (level caps or not).

## One more run
Not started. Queued: what a trip brings home (one material or several); what the village builds; what a building unlocks (classes, gear upgrades, new places, trip-only boons); what a fall costs, if anything, beyond the decided "nothing"; how long one run should be.

## Inventory
### Brandon's opening (2026-10-29)
"A diablo/PoE inventory where various items are different shapes and you can move them around to fit better in your inventory. Maybe there's an upgrade path down the line to increase inventory size as you progress. Items should be able to be rotated too in a tetris like way."

Settled by that: items have shapes, are packed by hand and can be turned. A way to grow the pack is a maybe.

### Decided in the grilling
- **Everything carried shares the grid** (inv-1): gear, food, potions, finds and village materials. Each member's weapon, and maybe one trinket or accessory, sits on that member instead (the trinket is earmarked, not to be built yet). So hauling materials home competes with supplies for room.

### What's on file and built
- `[USER]` 2026-10-26: the village has a Tetris-like grid inventory.
- `[AI]`, never confirmed: the pack is a 4 x 3 grid of turnable shapes (12 cells); 12 slots, food 10 a slot, medicine 5 a slot, overflow lost; the Wizard's books take 3 cells.
- Built: `InventoryGrid` and `PackView` (`game/scripts/village/`) in the shelved village hub; shapes in `game/data/items.csv`. The live loop uses 12 plain slots (`RunState.CAPACITY`) on the explore ITEMS bar. In fights any piece can spend the pack's food or potions as its action (`data/combat_items.csv`).

### The tension to solve
Falling keeps every item (`[USER]` 2026-10-28), so a tight pack can't create fear of loss. The grid needs a job: what you bring home, what you bring out, the layout as a build, or just a satisfying tidy (card 4).

### Batch 1 (posted 2026-10-29)
| Card | Question | Answer |
|---|---|---|
| `design-inv-1-what` | Everything carried, materials in a pouch, or food and potions as counts too? | Everything carried, except each member's weapon and maybe a trinket, which sit on the member |
| `design-inv-2-who` | One party pack, a bag each, or a party pack plus a belt each? | open |
| `design-inv-3-fight` | In a fight: anything usable, belt only, or no items? | open |
| `design-inv-4-pressure` | What packing decides (pick 2): what you bring home, what you bring out, layout as build, just a tidy | open |
| `design-inv-5-grow` | Bigger pack from a village build, the shop, or found on the map? | open |
| `design-inv-6-full` | Full on the map: drop it and it stays, throw something away, or the dog takes it home? | open |

### Queued for batch 2
Starting size; auto-sort or hand-packing only; a village stash and how it relates to the pack; what a left-behind item costs; follow-ups on whatever card 4 picks (adjacency rules if "layout is the build").

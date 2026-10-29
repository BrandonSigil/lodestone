# Core loop: fun combat, player choice, one more run

The game designer's running summary of Brandon's design grilling (studio role `design`). Questions go to his desk as `choice` cards, one theme per batch; each answer becomes a `[USER]` line in `docs/decisions.md` marked "(Brandon, design grilling)" and is summed up here. `[USER]` lines always win; anything below marked *proposal* is `[AI]` until he retags it.

Themes, in order:
1. **Fun combat**: what makes a fight a treat turn by turn.
2. **Player choice**: meaningful choices in and between fights.
3. **One more run**: what a trip earns, what the village builds with it, what that unlocks ("one more run gets me enough X to build Y, and Y finally gets me Z").

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
- **Actions per turn and counters are still `[AI]`.** Turn order and dice are now settled (see Combat).
- **Party size.** 4 slots is `[AI]`; the playable party today is the hero and the dog. Asked in the choice theme.
- **The level pick vs the job tree.** The pick (health, attack, magic) is `[USER]`; jobs at level 5 and 10 are an `[AI]` draft. How the two fit is asked in the choice theme.

## Combat
### Decided in the grilling
- **Turn order: Fire Emblem phases**, as built (c1). Speed matters only for movement and the deploy ring.
- **Warning: the danger zone only** (c2). Foes show where they could hit, not who they'll go for. No telegraphed wind-ups or drawn intent, so the enemy phase keeps some surprise.
- **Hits always land; damage wobbles by a point or two; crits can happen** (c3). Floating damage numbers pop on every blow, crits shown bigger. The d20 stays for checks outside fights.

### Open from these answers (for batch 2)
- **What the to-hit bonuses become.** With no roll to hit, the +2s from height, flanking and STAR POINT, cover and GUARD's defense, SPOOKED's -3, steady_aim, the luck streak and hexes (MOON NAP rolls to hit) have nothing to change. Each must turn into damage, crit chance or a sure effect, or go away. This decides what positioning is worth, so it's the first card of batch 2.
- **How crits work.** A flat chance, or a chance raised by position (height, flanking)? Bigger crit chance from high ground would keep height worth climbing.
- **How wide the wobble is**, and whether the forecast shows the range ("4-6") or the middle.
- **Counters always land now**, so trading blows in melee is a sure cost. Check that "ranged picks at melee for free" still feels fair.
- **Bosses** can't lean on telegraphs (c2), so boss shapes in batch 2 are fortress, objective, several parts or minions.

### Batch 1 (posted 2026-10-29)
| Card | Question | Answer |
|---|---|---|
| `design-c1-turn-order` | Phases, speed timeline, or one each back and forth? | Phases |
| `design-c2-intent` | Danger zone only, big foes telegraph, or every foe shows its move? | Danger zone only |
| `design-c3-luck` | Roll to hit, sure hits, or sure hits with a damage wobble? | Sure hits, damage wobble, plus crits and pop-up numbers |
| `design-c4-combos` | Heart of a clever turn (pick 2): shoving, teamwork hits, reacting ground, party meter | open |
| `design-c5-length` | Short and many, medium, long set pieces, or a mix? | open |
| `design-c6-down` | Out for the fight, bleeding out, hurt for the trip (last two combine)? | open |

### Queued for batch 2
What the to-hit bonuses become and how crits work (see above); win conditions beyond "defeat all" (escape, protect, hold); how strong height should be; healing and skill economy (cooldowns, a pool, or items only); actions per turn (move + act, two actions, or points); foe types and behaviours (charger, guard, ambusher); boss shapes (fortress, objective, several parts, minions); a mercy rewind for misclicks.

## Player choice
Not started. Queued: party size and who comes; how the level pick and the job tree fit; skill and gear builds (few slots and upgrades vs loot); route choice on the overworld; risk and reward (opt-in harder fights, Hades-style vows); sneak, talk or fight; grinding (level caps or not).

## One more run
Not started. Queued: what a trip brings home (one material or several); what the village builds; what a building unlocks (classes, gear upgrades, new places, trip-only boons); what a fall costs, if anything, beyond the decided "nothing"; how long one run should be.

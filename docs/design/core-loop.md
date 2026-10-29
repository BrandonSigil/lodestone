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
- **High ground adds damage; flanking adds crit chance** (c7). Climbing is a sure gain, surrounding is a gamble for a big hit.
- **Defense is a flat cut to every hit; GUARD raises it; the cover bonus goes** (c8). Standing behind something only matters by blocking line of sight: ranged foes can't shoot what they can't see. Cover is not an action (but see c14: brush, low walls and forest also take 1 off ranged hits). The picture: a big knight jumps into the middle, guards, and takes the round of hits for the team.
- **Each kind of character pays for skills its own way** (c9), WoW / D&D style. Examples Brandon gave: a mage has mana that starts full and refills a little each turn; the dog has 3 special actions to spend any way (bark 3 times, or bite twice and bark once) that come back slowly; a warrior's rage grows as he hits and gets hit.
- **Every kind of win condition, sometimes several at once** (c10): beat the leader, hold out for N rounds, reach the way out, keep something safe. The hero gets a TALK option in some fights to persuade a leader to cut his losses and flee. Showpiece example: a giant monster you can kill, or a ladder behind it that wins the fight if everyone climbs it, still for some XP.
- **Bleed-out: 3 turns, and a foe may knock the downed piece out** (c11) by spending its action. Knocked out means out for this fight only; it still stands up after.
- **A team-up bonus for teammates within one tile, diagonals included** (c12), in place of sandwich follow-ups. No reacting ground and no party meter for now.
- **A guarding piece holds a zone** (c13): foes that start next to it must attack it, or take a free hit when they walk away.
- **Cover blocks sight and is half cover against ranged** (c14): brush, low walls and forest take 1 off ranged hits; melee ignores it. Hovering a ranged piece shades the tiles it can't see.
- **The team-up bonus is a helping strike** (c15): hit a foe that a teammate within one tile can also reach, and the teammate adds a small free hit.
- **Resources belong to the job** (c16): every knight has rage, every mage mana; the hero's bar changes with his job. No cooldowns on top.
- **TALK appears only when you know something, or when a fight is written for it** (c17). Some hostile characters can be talked round in a fight, once or twice, and join the party.
- **Crits are common and double damage** (c18): about 10% base, a flank adds about 20%; some characters crit more often.

### Pushback on c8 (Brandon asked to be argued with)
Flat armor plus a stronger GUARD is a good fit for sure hits: it's readable, it shows in the forecast, and it gives a tank a real job. Three worries:
1. **A guarding knight won't draw the hits on his own.** The enemy AI picks whatever deals the most damage. With sure hits and armor shown, every foe walks past the guarding knight to hit the archer. To "take that round of hits for his team" the knight needs a pull: a taunt (his goad), a zone of control (foes next to him must attack him, or take a free hit when they walk away, like D&D's opportunity attacks), or GUARD also shielding the allies next to him (today's shield_wall). *Proposal:* GUARD adds armor, and foes that start next to a guarding piece must attack it or take a free hit to leave. First card of combat batch 3.
2. **Sight-only cover makes terrain matter less for melee**, and forest becomes just slow ground. That may be fine: height and pushes still shape melee.
3. **Sight-only cover is all or nothing, and hard to read from one fixed view.** One step sideways and the archer hits in full. The player needs to see which tiles a ranged foe can't see (a sight preview on hover, already on the "not yet" list). *Alternative:* brush and low walls keep a half cover that takes 1 off ranged hits only. Asked in batch 3.

Numbers to watch: with armor 0 to 3 and hits of 3 to 5, a wobble of plus or minus 1 is a big share of each hit, and every hit should still do at least 1.

### Defaults for the open numbers (proposals, tunable in data)
These fill the gaps the answers leave so the build can start; each is `[AI]` until Brandon stamps it.
- **Damage:** hits do their damage plus or minus 1, at least 1 after armor. Armor 0 to 3 by class; GUARD +2 armor until the piece's next phase.
- **Height:** +1 damage per level above the target, up to +2; -1 per level below, down to -2. Range from height stays (+1 a level, up to +3).
- **Crits:** 10% base, +20% on a flank (an ally already next to the target), double damage. A class or character may add crit chance.
- **Leftover hit bonuses:** STAR POINT and steady_aim become +15% crit; SPOOKED becomes -1 damage; the luck streak goes; hexes like MOON NAP always land.
- **Bleed-out:** a 3-turn countdown over the downed piece. AID (next to it) brings it back at a quarter of its max HP; after the fight it stands at 1 HP.
- **Helping strike:** a flat 1 damage (no wobble, no crit); one per attack, from the teammate who'd hit hardest.
- **Resources:** mana starts full and refills a fifth each phase; rage starts at 0 and builds +1 per hit dealt or taken; the dog has 3 charges, one back every 3 phases.
- **Fight sizes:** road 3 to 4 rounds, explore 5 to 7, showpieces 8 to 12.
- **Wins without the kill:** win XP plus XP for each foe downed; an escape also gives half the XP of foes left standing.
- **Taunt and slow:** TAUNT (foes in range must target the taunter next phase); SLOW (-2 move for a phase).

### Still open in combat (not blocking a build)
Boss shapes (fortress, objective, several parts, minions); foe types and behaviours (charger, guard, ambusher); actions per turn (move + act is still `[AI]`); a mercy rewind for misclicks; whether counters still feel fair now that they always land. These come after the first build is playable.

### Build order (card `design-combat-build`)
*Proposal:*
1. **The damage model.** Sure hits, the wobble, armor and GUARD, height damage, crits with flanking, the leftover bonuses converted, half cover and the sight preview, pop-up numbers (crits bigger), and a forecast that shows the damage range and crit chance. Everything else sits on these numbers. Rerun the balance sim after.
2. **Guard zones.** Foes next to a guarding piece attack it or take a free hit to leave; the ring is drawn; the AI respects it.
3. **Bleeding out.** The countdown, AID, a foe's knock-out, standing up after.
4. **Helping strikes.** The team-up rule, shown in the forecast.
5. **Job resources.** Mana, rage and charges replace cooldowns; skill costs move into `abilities.csv`; bars in the frame; the AI spends them. The biggest rework, so it comes after the core feels right.
6. **Fight goals and TALK.** Per-encounter goals (defeat all, leader, hold N, way out, protect, several at once), XP for wins without the kill, flag-gated or written TALK options, and talking a hostile character into joining.

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
| `design-c7-position` | What height and flanking give now that hits always land: damage, crit chance, or height = damage and flanking = crit? | Height = damage, flanking = crit |
| `design-c8-defense` | What defense, cover and GUARD do: take points off each hit, block or halve one hit, or only cut crits? | Armor takes points off; GUARD raises it; cover only blocks sight (argue with him) |
| `design-c9-skills` | How skills are paid for: cooldowns, a slowly filling pool, or uses per fight? | Neither: a resource per kind of character (mana, action charges, rage) |
| `design-c10-goals` | Win conditions beyond defeat all (multi): beat the leader, hold out, reach the exit, protect something | All four, sometimes at once; TALK to make a leader flee |
| `design-c11-bleed` | Bleed-out: how long, and can foes finish a downed piece early? | 3 turns; a foe can knock it out |
| `design-c12-systems` | Board-wide rules on top of skills (multi): reacting ground, a party meter, sandwich follow-ups | A team-up bonus within one tile, diagonals too |

### Batch 3 (posted 2026-10-29)
| Card | Question | Answer |
|---|---|---|
| `design-c13-guard` | How a guarding piece draws the hits: zone of control, shield its neighbours, or only through taunt skills? | Zone: hit him or pay to leave |
| `design-c14-cover` | Cover: sight only (with a sight preview), or half cover against ranged on brush and low walls? | Sight plus half cover against ranged |
| `design-c15-teamup` | The team-up bonus: armor, damage, a helping strike, or a bonus per pair? | A helping strike |
| `design-c16-resource` | Whose resource: by job, by character, or by job with exceptions? | By job, no cooldowns on top |
| `design-c17-talk` | TALK in a fight: a d20 check any time, only once the foes are beaten down, or only when you know something? | Known or written into the fight; can recruit hostile characters |
| `design-c18-crit` | Crits: rare and huge, or common and double? | Common and double; some characters crit more |

## Player choice
### Batch 1 (posted 2026-10-29)
| Card | Question | Answer |
|---|---|---|
| `design-pc-1-party` | How many pieces fight: 3, 4, 6, or by fight size? | open |
| `design-pc-2-skills` | Where a character's 3 or 4 skills come from: fixed, pick 4 of a bigger set before a trip, grown by level picks, or from jobs? | open |
| `design-pc-3-levelpick` | What the pick every 4 or 5 levels grows into: stats, a new skill from two, or a passive perk? | open |
| `design-pc-4-grind` | Grinding: let it be, XP shrinks on weak foes, or a level cap per region? | open |
| `design-pc-5-route` | Route choice: today's Mario-style map, Slay the Spire branches each trip, or forks with known costs? | open |
| `design-pc-6-risk` | Opt-in risk for reward (multi): marked elite fights, Hades-style vows, a push-on-or-go-home choice | open |

Queued: gear builds (weapon upgrades at the smithy, the earmarked trinket); sneak, talk or fight before a fight starts; who joins and how the roster grows.

## One more run
First link, from the inventory theme (inv-5): a recruited character returns to the village and unlocks a pack upgrade, which costs materials brought home. Packing decides how many materials a trip can bring home (inv-4).

Not started as its own theme. Queued: what a trip brings home (one material or several); what the village builds; what a building unlocks (classes, gear upgrades, new places, trip-only boons); what a fall costs, if anything, beyond the decided "nothing"; how long one run should be.

## Inventory
### Brandon's opening (2026-10-29)
"A diablo/PoE inventory where various items are different shapes and you can move them around to fit better in your inventory. Maybe there's an upgrade path down the line to increase inventory size as you progress. Items should be able to be rotated too in a tetris like way."

Settled by that: items have shapes, are packed by hand and can be turned. A way to grow the pack is a maybe.

### Decided in the grilling
- **Everything carried shares the grid** (inv-1): gear, food, potions, finds and village materials. Each member's weapon, and maybe one trinket or accessory, sits on that member instead (the trinket is earmarked, not to be built yet). So hauling materials home competes with supplies for room.
- **One party pack, plus a small belt per character** (inv-2).
- **In a fight, only what's on a piece's belt; using it is the piece's action** (inv-3).
- **Packing decides what you bring out and what you bring home** (inv-4). Brandon's model is Stardew Valley's mines: before heading out you choose how much food and how many helpful items (bombs) to bring, knowing it leaves less room for what you collect.
- **A bigger pack is a village build** (inv-5): find the right character, they come back to the village, that unlocks the upgrade, and the upgrade costs materials. This is the first concrete link in the one-more-run chain.
- **Full on the map: throw something away for good, or send it home with the dog** (inv-6). The dog is then out of the party until you go home yourself.
- **The first pack is 4 x 3** (inv-7), for short, tricky early trips with a feeling of scarcity.
- **A belt is a 2 x 1 strip where shapes count** (inv-8): one 2-cell item or two 1-cell items.
- **Small stacks** (inv-9): potions 3 a cell, meat 10 a cell, as Brandon put it.
- **Coming home, materials bank themselves** (inv-10); gear and supplies stay packed.
- **Auto-place on pickup, rearrange by hand, no tidy button** (inv-11). Rearranging is the little game for the overworld walk.
- **The dog's saddlebag is 2 x 2** (inv-12), to balance later.

### Still open (not blocking a build)
- **Upgrade steps:** how big each pack upgrade is, and which settler unlocks it. Belongs to the one-more-run theme.
- **Item shapes and stack sizes per item:** data, set when items are made. *Proposal:* potion 1 cell, stack 3; meat 1 cell, stack 10; ration crate 2 x 2; rope 1 x 2; bomb 1 x 2; materials 1 cell, stack 5.
- **The trinket slot:** earmarked only.
- **Whether a fall counts as "going home"** for the dog's return. *Proposal:* yes, any wake-up in the square or GO HOME brings him back.

### Build order (card `design-inv-build`, approved 2026-10-29, handed to the systems developer)
1. **Shaped pack in the live loop.** Swap the 12 plain slots for the 4 x 3 shaped grid (`InventoryGrid`, `PackView`), with per-item stacks, auto-place on pickup, and rearranging and turning from PACK on the overworld and explore maps. Everything else sits on this.
2. **Belts.** A 2 x 1 strip per character, filled from the pack; in a fight the item menu shows only the belt and using one is the action. Replaces "any piece spends the pack's food or potions".
3. **Full pack.** A pickup that doesn't fit offers: repack, throw something away, or fill the dog's 2 x 2 saddlebag and send him home (out of the party until you're home).
4. **Coming home.** Materials leave the pack into a village count on arrival. Needs at least one placeholder material item.
5. **Later:** the pack upgrade (waits on the one-more-run theme) and the trinket slot (earmarked).

### What's on file and built
- `[USER]` 2026-10-26: the village has a Tetris-like grid inventory.
- `[AI]`, never confirmed: the pack is a 4 x 3 grid of turnable shapes (12 cells); 12 slots, food 10 a slot, medicine 5 a slot, overflow lost; the Wizard's books take 3 cells.
- Built: `InventoryGrid` and `PackView` (`game/scripts/village/`); shapes and stack sizes in `game/data/items.csv`. Step 1 is in (2026-10-29): the live loop carries the 4 x 3 shaped pack (`RunState.pack`), meat 10 a cell, potions 3 a cell, rope 1 x 2, auto-place on pickup, drag and turn from PACK. In fights any piece can still spend the pack's food or potions as its action (`data/combat_items.csv`) until step 2.

### The tension to solve
Falling keeps every item (`[USER]` 2026-10-28), so a tight pack can't create fear of loss. The grid needs a job: what you bring home, what you bring out, the layout as a build, or just a satisfying tidy (card 4).

### Batch 1 (posted 2026-10-29)
| Card | Question | Answer |
|---|---|---|
| `design-inv-1-what` | Everything carried, materials in a pouch, or food and potions as counts too? | Everything carried, except each member's weapon and maybe a trinket, which sit on the member |
| `design-inv-2-who` | One party pack, a bag each, or a party pack plus a belt each? | Party pack plus a belt each |
| `design-inv-3-fight` | In a fight: anything usable, belt only, or no items? | Belt only, costs the action |
| `design-inv-4-pressure` | What packing decides (pick 2): what you bring home, what you bring out, layout as build, just a tidy | Bring out and bring home (Stardew mines) |
| `design-inv-5-grow` | Bigger pack from a village build, the shop, or found on the map? | Village build, unlocked by a settler, paid in materials |
| `design-inv-6-full` | Full on the map: drop it and it stays, throw something away, or the dog takes it home? | Throw away, or the dog takes it home and is out until you return |

### Batch 2 (posted 2026-10-29)
| Card | Question | Answer |
|---|---|---|
| `design-inv-7-size` | Starting pack: 4 x 3, 5 x 4 or 6 x 5? | 4 x 3 |
| `design-inv-8-belt` | Belt: 2 small cells, a 2 x 1 strip where shapes count, or one slot of any size? | 2 x 1 strip, shapes count |
| `design-inv-9-stack` | Do things stack in a cell: big stacks, small stacks, or never? | Small: potions 3, meat 10 |
| `design-inv-10-home` | Coming home: materials bank themselves, unpack by hand into a stash, or everything banks and you repack? | Materials bank themselves |
| `design-inv-11-sort` | Hand packing only, auto-place on pickup, or a tidy button too? | Auto-place, rearrange by hand on the walk |
| `design-inv-12-dog` | The dog as courier: one item, a 2 x 2 saddlebag, or whatever the pack could hold? | 2 x 2 saddlebag |

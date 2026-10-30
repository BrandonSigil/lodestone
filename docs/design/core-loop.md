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
- **The team-up bonus is a helping strike** (c15): hit a foe that a teammate within one tile can also reach, and the teammate adds a small free hit. **Corrected on the build card:** both teammates must be next to the same foe *and* next to each other (his pictures: `img/teamup-yes.png` counts, `img/teamup-no.png` doesn't). Two teammates on opposite sides of a foe count too (c19). So the rule is: any two teammates next to the same foe.
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
- **Bleed-out:** a 3-turn countdown over the downed piece. AID (next to it) brings it back at a quarter of its max HP (40% and flat heals were measured on 2026-10-30 and didn't fit); after the fight it stands at 1 HP.
- **Helping strike:** a flat 1 damage (no wobble, no crit); one per attack, from the teammate who'd hit hardest.
- **Resources:** mana starts full and refills a fifth each phase; rage starts at 0 and builds +1 per hit dealt or taken; the dog has 3 charges, one back every 3 phases.
- **Fight sizes:** road 3 to 4 rounds, explore 5 to 7, showpieces 8 to 12.
- **Wins without the kill:** win XP plus XP for each foe downed; an escape also gives half the XP of foes left standing.
- **Taunt and slow:** TAUNT (foes in range must target the taunter next phase); SLOW (-2 move for a phase).

### Still open in combat (not blocking a build)
Boss shapes (fortress, objective, several parts, minions); foe types and behaviours (charger, guard, ambusher); actions per turn (move + act is still `[AI]`); a mercy rewind for misclicks; whether counters still feel fair now that they always land. These come after the first build is playable.

### The first boss and the light builds (2026-10-30)
Brandon: every build should be able to beat the Lich King, the first real skill check. At level 5 the sword and bow win about 42%. Daggers win 50%, but 43% of their fights never end. The book wins 20%. The cause is staying alive, not damage: his FIREBOLT downs a light hero in 2 or 3 rounds, then a help-up and knock-down loop runs to the round cap. The AI fixes were measured and made it worse (the help-up loop is how the sword drains his mana), so they are withdrawn. AID at 40% fixed the stalls but lifted the sword to 83%, and more Lich HP sank the bow, so the Lich stays at 42 HP. A flat AID heal (6, 8 or 10 HP) was measured and didn't fit either (8 already lifts the sword to 70%), so AID stays at 25%; the daggers' stuck fights go to poison blades and hit and run. Target was 35 to 55% for sword, bow and daggers, retired when Brandon said builds may be uneven against a boss (`design-boss-spread`). Brandon held off on the mage (`design-boss-book`, Neither): the book may stay a hard match for the first boss, "like pokemon red where if you pick charmander it stinks for the first gym"; a +1 that lifted it to 53% is withdrawn. `design-boss-daggers`: Brandon picked poison blades first, then hit and run (both always on for the rogue).

### Build order (card `design-combat-build`, approved 2026-10-29 with the default numbers, handed to the systems developer after the inventory build and the bottom UI frame)
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

### Follow-up (posted 2026-10-29)
| Card | Question | Answer |
|---|---|---|
| `design-c19-teamup-shape` | Team-up: corner pairs only (his picture), or also two teammates on opposite sides of a foe? | Opposite sides count too |

## Player choice
### Decided in the grilling
- **Four pieces fight** (pc-1).
- **Skills are fixed per character for now; at level intervals a skill can be upgraded, better and better** (pc-2).
- **Stats every level; at intervals, improve one of your own skills** (pc-3). This grows the earlier pick (health, attack or magic every 4 or 5 levels).
- **Grinding is allowed, and completed places can be walked past** (pc-4; walking past cleared places is built).
- **The console overworld stays, with forks that branch and join up again** (pc-5): head north, fork east or west, and the branches link back up. A map-layout rule for the overworld, not a new system.
- **Opt-in risk is marked elite fights** (pc-6): tougher groups, better rewards. No vows, no push-on-or-go-home.
- **The first elite is the lone wolf deep in the wolf den** (`design-elite-pick`), a side room the party can skip. Elites fight at 150% HP, +1 damage, +1 armor, pay 1.5x XP and stay beaten (the developer's build).
- **Stats are rolled each level from each character's own growth odds** (pc-7), Fire Emblem style. A tank mostly gains HP or defense, now and then attack, and never a stat it can't use.
- **Skills grow on their own; ranks add something new** (pc-8). A skill gets stronger with the character's stats even if never ranked. Choosing to rank it adds an effect: a stronger slow, a bleed at rank 2.
- **The weapon is the job; switch in the village, starting that job at 0** (pc-9). Take a different weapon at the smithy to change job (so you can bring a companion who fills your old role). Later weapon types can be powerful new jobs. This replaces the draft of a job at level 5.
- **The party of four changes only at home** (pc-10). Every companion lives somewhere in the village; walk up to one to invite them, or use the edit-party prompt at the gate on the way out (one key to go, one to edit). So a dog sent home with a load leaves a party of three for the rest of the trip.
- **Sneaking wins the first strike, as today** (pc-11). Rogue and sneaky characters get skills that feel stealthy in a fight (a shadowstep, a vanish).
- **Switching job keeps the hero's level; stats shift toward the new job; its ranks start at 0** (pc-12), Fire Emblem reclass style.
- **A well-levelled job splits into one of two branches** (pc-13), Fire Emblem promotion style. The draft pairs (knight to guardian or vanguard, rogue to assassin or thief, archer to hunter or sharpshooter, mage to wizard or healer) stay `[AI]` until their skills are designed.
- **Weapons improve by smithy upgrades paid in materials** (pc-14). One weapon per job, raised step by step; no loot chase.
- **Elite fights are marked with a badge and avoidable** (pc-15): they sit where you can back out or take another path.

### Gaps these answers open
- **Job level vs character level** (from pc-12): the hero keeps one character level; each job has its own job level for ranks and its branch. *Proposal:* the branch comes at job level 10; job XP is earned alongside character XP.
- **Companions' homes** (from pc-10): each companion needs a place in the village to be found and invited. A job for the map builder once companions exist; it fits the `[USER]` 2026-10-27 line that settlers are village NPCs (companions also live there, but join the party).
- **Rank interval** (from pc-8): *proposal:* a rank to spend every 4 levels, up to 3 ranks a skill. What ranks cost (nothing, or a village trainer and materials) ties to the one-more-run theme.
- **Growth odds are data** (from pc-7): a per-character, per-job table of odds in `game/data/`.
- **Who goes on a trip:** four slots, a growing roster (survivors who join, hostile characters talked round). Card pc-10.
- **Elite rewards:** what "better" means (more materials, rare gear) belongs to the one-more-run theme.
- **Grinding vs the Lich King skill check:** Brandon chose freedom; the boss stays a skill check only for players who don't grind.

### Batch 1 (posted 2026-10-29, all answered)
| Card | Question | Answer |
|---|---|---|
| `design-pc-1-party` | How many pieces fight: 3, 4, 6, or by fight size? | 4 |
| `design-pc-2-skills` | Where a character's 3 or 4 skills come from: fixed, pick 4 of a bigger set before a trip, grown by level picks, or from jobs? | Fixed for now, upgraded at level intervals |
| `design-pc-3-levelpick` | What the pick every 4 or 5 levels grows into: stats, a new skill from two, or a passive perk? | Stats every level; skill upgrades at intervals |
| `design-pc-4-grind` | Grinding: let it be, XP shrinks on weak foes, or a level cap per region? | Let them grind; let them pass completed places |
| `design-pc-5-route` | Route choice: today's Mario-style map, Slay the Spire branches each trip, or forks with known costs? | Console map with forks that rejoin |
| `design-pc-6-risk` | Opt-in risk for reward (multi): marked elite fights, Hades-style vows, a push-on-or-go-home choice | Marked elite fights |

### Batch 2 (posted 2026-10-29)
| Card | Question | Answer |
|---|---|---|
| `design-pc-7-stats` | Stats each level: rolled on their own, a pick each level, or a small rise plus a pick? | Rolled, from each character's growth odds |
| `design-pc-8-skillup` | Skill upgrades: a rank at set levels, ranks bought in the village with materials, or a choice of two upgrades per rank? | Skills scale on their own; a chosen rank adds an effect |
| `design-pc-9-jobs` | The hero's job: the draft tree (job at 5, branch at 10), set by the starting weapon, or switchable in the village? | Weapon is the job; switch in the village, new job starts at 0 |
| `design-pc-10-roster` | When can you change who's in the four: only at home, at camps on the map, or at home with the bench running errands? | Only at home: invite in the village, or edit at the gate |
| `design-pc-11-sneak` | How much sneaking matters on explore maps: a first strike only, slipping past fights, or none? | First strike; stealth skills for rogues |

### Batch 3 (posted 2026-10-29)
| Card | Question | Answer |
|---|---|---|
| `design-pc-12-jobreset` | Switching job: only the job's level starts at 0, stats shift to the new job, or back to level 1? | Keep the level; stats shift; ranks from 0 |
| `design-pc-13-branch` | Does a job split in two later: two branches, one promotion, or no branches (new weapons are the growth)? | Two branches |
| `design-pc-14-weapons` | How a weapon gets better: smithy upgrades, found weapons with traits, or both? | Smithy upgrades |
| `design-pc-15-elites` | How elite fights show: marked on the map and avoidable, seen only up close, or a hunter that roams? | Marked with a badge, avoidable |

### Build order (card `design-choice-build`, approved 2026-10-29: all four, after the combat build; handed to the systems developer)
After the inventory build, the bottom UI frame and the combat build, because jobs lean on combat step 5 (resources by job).
1. **Growth.** A level every 100 XP; stats rolled each level from per-character (and per-job) growth odds in `game/data/`, never a stat the character can't use; skills scale with stats on their own; a skill rank to spend every 4 levels (up to 3 a skill) from the Lodestone menu, each rank adding an effect from data. Replaces +1 HP a level and the health / attack / magic pick.
2. **The weapon is the job.** The smithy weapon sets the hero's job from the start (sword knight, daggers rogue, bow archer, the book mage); each job has its own job level; switching weapons at the smithy keeps the character level, shifts stats to the new job's base, and starts its ranks at 0. Branch choice at job level 10 (two per job; skills for them come later).
3. **Party at home.** Edit the four at the gate (one key to go, one to edit), and invite a companion by walking up to them in the village.
4. **Elite fights.** An elite tier for groups, a badge over them on explore maps and on overworld places, placed where the party can back out or go round.
5. **Later:** smithy weapon upgrades (need materials, the one-more-run theme).


## One more run
### Already decided (from the other themes)
- Falling costs nothing; the party wakes in the square with everything (2026-10-28). Grinding is allowed (pc-4).
- Everything carried shares a 4 x 3 pack; packing decides what you bring out and what you bring home (inv-1, inv-4, inv-7).
- Materials bank themselves when you get home (inv-10).
- A settler you find unlocks the pack upgrade, paid in materials (inv-5). Smithy weapon upgrades are paid in materials (pc-14).
- Elite fights are marked, avoidable and give better rewards (pc-6, pc-15).
- Gold and a shop arrive once a blacksmith or merchant settles (2026-10-27).

So the chain has its shape: **trip, then materials, then a settler's build, then a stronger party or a bigger pack, then a deeper trip.**

### Decided in the grilling
- **A few kinds of material** (omr-1): food, potion materials, and resource materials like metal and wood.
- **Builds restore the buildings already standing, step by step** (omr-2), so the town visibly comes back.
- **Builds unlock better starts, through settlers** (omr-3). Brandon's chain, in his examples: find a chef, upgrade the inn or tavern into a full kitchen, which opens new recipes; find the blacksmith, he moves into his home but needs help getting the forge running, then wants materials for a sharpening stone, and so on. Each settler opens a line of restore steps, and each step adds a service, a recipe or an upgrade.
- **A trip runs 30 to 45 minutes, with a robust save** (omr-4) so a player can bookmark a trip and come back.
- **The goal stays in view all three ways** (omr-5), like Stardew's community center: each building shows what its next step needs; a menu gives the global view of open and done steps; the player flags any number of them as tracked goals; settlers ask for things.
- **Temporary power comes from the road; lasting power from the hand-made maps** (omr-6). Random encounters give blessings and camp meals, and also disadvantages. Exploring the hand-made explore maps gives long-lasting upgrades.
- **Blessings are given at random** (omr-7) by road encounters, and last the trip.
- **Setbacks come from bad outcomes of road events** (omr-8). Road fights cost something too: the party spends food and potions caring for itself before it even reaches the explore map.
- **Meals: the chef's recipes are prepared at home and cooked at a camp on the road** (omr-9). At home a recipe turns ingredients into a meal item that takes a full pack slot; on the road, "stop and make camp" cooks it over the fire for the buff.
- **The hand-made maps give rare materials, keys and shortcuts, and stat items** (omr-10): materials for home upgrades and weapon upgrades.
- **Save and quit anywhere outside a fight; a quit fight restarts from its first turn** (omr-11).
- **A restore step asks for specific items and is done when you come back from your next trip** (omr-12).

The chain, filled in: **a 30 to 45 minute trip; random road encounters give trip-long blessings, setbacks and the chance to cook a meal at camp; the hand-made maps give lasting upgrades; the pack brings home food, potion materials, metal and wood; at home a settler's building takes them for its next restore step; that step gives a better start (better food, a sharper weapon, a bigger pack); you pin the next step and go again.**

### Defaults for what's left (proposals, tunable in data)
- **Blessings and setbacks** last until the party is home (GO HOME or a fall); up to 5 blessings at once; a road encounter that gives one draws it at random from a pool in `game/data/`. Start with about 10 blessings and 6 setbacks, placeholder text. Examples of kind, not content: rage builds faster, crits heal 1, +1 move; food spoils faster, -1 armor, start fights with less mana.
- **Camp:** once per overworld leg, from the road menu; it costs a little walking time (food drains as usual). Cooking a meal there gives its buff for the next 2 fights. A meal is one pack cell or bigger, by recipe.
- **Restore steps** list exact items (3 metal, 2 wood, 1 rare find). Paying starts the step; it finishes the next time the party comes home. A building's ladder opens once its settler has moved in.
- **Tracked goals:** any number can be flagged; the frame shows the tracked steps' missing items on a trip, and a pickup that counts says so.
- **Lasting map rewards:** a stat item gives one character +2 HP or +1 to one stat for good; a key opens a door, cache or shortcut on its map for good.

### Gaps (content, not blocking the build)
- **Which buildings, which settlers, which steps.** Brandon's examples: the inn kitchen (a chef, recipes) and the smithy (the blacksmith, the forge, a sharpening stone, then weapon upgrades). Which settler unlocks the pack upgrade is open. Settlers and their buildings are Brandon's to name; the build uses placeholders.
- **The blessing and setback pools** need real content once the system is in.

### Build order (card `design-omr-build`, approved 2026-10-29: all six, after the player-choice build, with the defaults above; handed to the systems developer)
1. **Bookmark save.** Save and quit anywhere outside a fight; a fight quit midway restarts from its first turn on load. Small, and it protects every test after it.
2. **Restore loop.** Material items (food ingredients, potion materials, metal, wood, rare finds) in the pack; village buildings with restore ladders in data (exact items, finished on the next return home, opened by their settler); each building shows its next step's needs; a global list with tracked goals; tracked needs in the frame on trips.
3. **The first two ladders.** The smithy (forge, sharpening stone, then weapon upgrades +1 to +3, which finishes Player choice's "smithy weapon upgrades") and the inn kitchen (recipes). The pack upgrade goes on a ladder once Brandon names its settler.
4. **Meals and camp.** At home, cook a recipe into a meal item; on the road, MAKE CAMP once a leg to eat it for a 2-fight buff.
5. **Blessings and setbacks.** Road encounters draw a random blessing; bad event outcomes give a setback; both last until home and show in the Lodestone menu.
6. **Lasting map rewards.** Stat items, keys and rare materials as things on explore maps; the map builder places them.
- **Food is both a supply and a material** (omr-1). Raw food you carry eats pack room either way; it's spent on the road, cooked into meals, or banked for the kitchen.
- **Only "better starts" was picked** of the five unlock kinds, but Brandon's examples are services (a kitchen, a forge). *Reading:* builds unlock settler services that make trips start stronger; no new overworld places, room-for-companions or flat perks from builds.

### Batch 1 (posted 2026-10-29)
| Card | Question | Answer |
|---|---|---|
| `design-omr-1-materials` | How many kinds of material: one, a few, or new ones per region? | A few: food, potion materials, metal and wood |
| `design-omr-2-builds` | What a village build is: fixed buildings restored, a board of projects, or free placement on plots? | Restore the buildings that are there |
| `design-omr-3-unlocks` | What builds unlock beyond pack and weapon upgrades (multi): new places, trip starts, new companions, shops, fight perks | Better starts, through settlers' services (chef's kitchen, smith's forge) |
| `design-omr-4-length` | How long one trip should be: 15 to 20 minutes, 30 to 45, or an hour or more? | 30 to 45 minutes, with a robust save |
| `design-omr-5-goal` | How the next goal stays in view: a build board with what's missing, a pinned wish list, or settlers who ask? | All three, like Stardew's community center |
| `design-omr-6-boons` | Power that lasts only for a trip: blessings found on the road, camp meals, or none? | Blessings and meals from random encounters, plus setbacks; hand-made maps give lasting upgrades |

### Batch 2 (posted 2026-10-29)
| Card | Question | Answer |
|---|---|---|
| `design-omr-7-blessings` | How blessings are offered: pick one of three, given at random, or a blessing with a price? | Given at random |
| `design-omr-8-setbacks` | Where setbacks come from: bad event outcomes, trades you choose, or lost fights and ambushes? | Bad event outcomes; road fights already cost supplies |
| `design-omr-9-meals` | Camp meals: cooked on the road, made at home by the chef, or the chef's recipes cooked on the road? | Prepared at home (a pack slot), cooked at a camp on the road |
| `design-omr-10-lasting` | What the hand-made maps give for good (multi): stat items, rare materials for big restore steps, skill ranks, keys and shortcuts | Rare materials, keys, stat items |
| `design-omr-11-save` | The save: suspend anywhere, save at places, or both? | Anywhere outside fights; a quit fight restarts |
| `design-omr-12-restore` | A restore step: done the moment you pay, done after your next trip, or asks for specific items? | Specific items, done when you come back |

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
- **A belt cell holds a full stack, like a pack cell** (`design-inv-belt-stack`, asked by the developer once belts were built). Stack sizes per item get balanced so belts aren't too strong.
- **Fishing rod** (card `dev-fishing-rules`, 2026-10-30): fishing needs a rod in the pack ([USER]). *Defaults:* 3 x 1, stack 1; the first one found once in a cache by the water in each village; a spare at the stuff hut for 6 gold; the world map's FISH needs it too; a spot rests until the next trip out (built).

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
- Built: `InventoryGrid` and `PackView` (`game/scripts/village/`); shapes and stack sizes in `game/data/items.csv`. Step 1 is in (2026-10-29): the live loop carries the 4 x 3 shaped pack (`RunState.pack`), meat 10 a cell, potions 3 a cell, rope 1 x 2, auto-place on pickup, drag and turn from PACK. Step 2 is in too: a 2 x 1 belt per member, filled by dragging from the pack in PACK; in a fight a piece uses only its own belt (`data/combat_items.csv` names the pack item each fight item spends). Step 3 is in: a pickup with no room waits in FOUND and PACK opens on its own; throw away, or fill the dog's 2 x 2 saddlebag and send him home until the party is home (a fall, GO HOME or walking into the village). Step 4 is in: home, materials bank into the village's count (`meta.materials`); the placeholder material is STUFF (1 cell, 5 a cell), found in the crypt chests, the pass cache and the den bones. Nothing spends materials yet; that waits on the pack upgrade.

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

**Update (07:55):** with bug 03 fixed (a helped-up piece now acts), the book beats the Lich 83% and daggers 65% (step away only from foes that hit next to it, poison 1). Sword and bow stay at about 42%. Brandon answered `design-boss-spread`: uneven is fine, starter-Pokémon style, so these numbers stand and nothing more is tuned for the Lich. The floor: every build can win (about 15% or more at the boss's level) and no fight stalls; the next boss should favor a different build.

## Bosses, foes and the village (batch posted 2026-10-30)
The follow-ups left open after the four themes: what makes a boss different, what each foe asks of the player, and what the village grows into. Ranked so the most load-bearing come first.

| Card | Question | Options |
|---|---|---|
| `design-world-gate` | What opens the next region? | bosses only (as today); some roads need a home build; both |
| `design-boss-cadence` | How often do bosses come? (multi) | end of each region; plus a mid-region mini-boss; a roaming boss; few bosses, elites carry the middle |
| `design-boss-shape` | What makes a boss fight different? (multi) | phases; parts to break; minions; an objective |
| `design-foe-scale` | Do foes get tougher as the party levels? | fixed; by depth (closest to today); tougher versions on old places; foes level with the party |
| `design-foe-roles` | Which foe roles first? (multi) | charger; guard; ambusher; caster or support |
| `design-foe-weakness` | Do foes have weaknesses? | none; a few tags; a full chart; resistances only (as today) |
| `design-boss-warning` | Do bosses warn of their big move? | no, danger zone only; the big move shows its tiles; a countdown |
| `design-boss-retry` | After losing to a boss, what carries over? (multi) | nothing; a growing assist; you learn him; his wounds stay |
| `design-village-grows` | Beyond restoring, how else does the village grow? (multi) | restore only; empty lots; decoration; the town under threat |
| `design-village-life` | How alive are the settlers? (multi) | services only; bonds that grow; daily routines |

Tensions to watch: an ambusher bends danger-zone-only (c2); a boss big-move warning would be the one exception to it; foes that level with the party would undo grinding as a safety net (pc-4).

### Decided (2026-10-30)
- **Regions:** completing a region opens the next. A region with a boss completes once the party is past him, beaten or escaped ("if you sneak past the Lich King, thats fine too"); a region without one completes at the end of its map. Boss XP and loot only for a kill; an escaped boss is back on his throne next time.
- **Cadence:** few bosses, at the end of some regions; elites carry the middle and can be tucked into any region; every region has fights.
- **Boss tools, in order:** minions (the Lich gets them now), phases (with the second boss), parts to break, an objective.
- **Warning:** a boss's big move marks its tiles a phase ahead and lands at the start of his next phase. Everything else stays danger-zone only.
- **Retry:** after the first fight with a boss, his card shows his HP and all his moves for good.
- **Foe scale:** by depth. A place's foes are set by its level and never change.
- **Foe roles, in order:** ambusher, caster/support, charger, guard.
- **Weakness:** a few tags (undead, beast, armored, flying), each a small damage change for some attack kinds. The Lich is undead (fire +2, arrows -2; `design-lich-tag`), so the book gets stronger against him and the bow weaker. To keep the bow over the 15% floor he drops to 38 HP: sword 53%, daggers 60%, bow 17%, book 95% (party first).
- **Village:** restore only, with one twist: a settler's service can come with a plot by their house (a garden for crops, a pen for animals).
- **Settlers:** bonds grow between pairs in the party (fights together, help-ups, team-ups). Three levels; each adds +1 team-up damage for the pair and opens a talk at home. The talks are Brandon's to write. Built after the first boss and foe build.

### First build (handed to the systems developer and the map builder, 2026-10-30)
1. The Lich's big move with its warning (windup 1, cooldown 3, a 5-cell plus, power 4, hits his own minions too).
2. The Lich's minions: built (`raise_dead`) but off his class. Every version measured sank a party of two (0 to 10% for most builds), so two gentler versions get measured and go to Brandon on a card.
3. Foe tags (`data/tags.csv`; wolves beast, the Lich and his minions undead).
4. The ambusher (hidden until seen within 3 cells; its first strike from hiding counts as a flank).
5. Check that escaping the Lich completes the crypt the way a kill does, without the boss XP or loot.

Then re-measure the Lich at level 5 with all four builds: each must win about 15% or more, with no stalls. Later, in order: learn him, foes by depth, caster/support, charger, guard, boss phases, parts, objective, village plots, bonds. The numbers are the `[AI]` lines of 2026-10-30 in `docs/decisions.md`.

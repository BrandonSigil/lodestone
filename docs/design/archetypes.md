# Class archetypes: ten kits to balance on paper

Game designer proposal, 2026-10-30, from Brandon's Studio chat ask: groups of 4 abilities per archetype, an internal code name, and what each does on the road and back in the village, borrowing from the games we researched and from D&D and Pathfinder. Everything here is `[AI]` until Brandon retags it `[USER]`.

No story, no names, no flavor. The ids below are plain function words (what the piece does), not characters or lore. Brandon's story ideas can hang off the mechanics, and any name he gives replaces the id's player-facing label in `game/text/placeholder.csv`.

## What the kits must fit (already decided, do not reopen)
- Four pieces fight; a kit is 3 or 4 skills, some shared across archetypes under other names (`c4`, `pc-1`).
- Resources belong to the job: mana (starts full, +1/5 each phase), rage (0, +1 per hit dealt or taken), charges (3, one back every few phases). No cooldowns on top (`c9`, `c16`). The two-phase lich moves are foe-only.
- Sure hits, damage wobble of 1, crits 10% (+20% flank), height +1/level up to 2, armor 0 to 3, GUARD zone, bleed-out and AID, helping strike of 1 (`c3`, `c7`, `c8`, `c13`, `c15`).
- Weapon is the job; the hero swaps jobs in the village; each job branches in two at job level 10 (`pc-9`, `pc-13`). Companions live in the village and join by invite (`pc-10`).
- Skills carry road uses where they can: a goal, not a rule (`c4`). Ranks add one new effect each, three ranks a skill (`pc-8`).
- Existing foe tags and damage kinds: undead, beast, armored, flying, ice; blade, arrow, spell, fire, frost, moon (`game/data/tags.csv`).

## Where the ideas come from
- **Fire Emblem / Tactics Ogre / FFT:** class lines with a promotion fork; fragile casters that need screening; height for archers.
- **XCOM / Into the Breach:** overwatch, shoving, the squad having one job each.
- **Divinity: Original Sin 2 / Banner Saga:** a small resource you spend or save; skills that work on terrain, not only on foes.
- **Hades / Slay-the-Spire style runs:** a short kit you learn fully, a clutch tool for when it goes wrong.
- **Stardew / Oregon Trail:** the village grows from what the road brings; food, forage, sickness.
- **D&D / Pathfinder:** the best source of out-of-combat use. A class is a fighting role plus a skill list (sneak, persuade, lore, repair, heal, track) that the same abilities feed, and "spells" that work in both a fight and a scene (light, mend, detect, charm, lock).

## The three jobs every kit does
Each kit is 4 skills arranged the same way, so they can be compared line for line:
1. **Basic**: the everyday action; costs nothing or one point.
2. **Signature**: what the archetype is for; the thing that wins a fight when it lands.
3. **Setup or utility**: shoves, slows, buffs, terrain. What makes a teammate better.
4. **Clutch**: a save for a bad turn (see `design-clutch-tools`: a clutch tool should be at least a third of a build's close wins, not a safety net).

Road use and village use are one line each. The road column is something that works while exploring or on the overworld; the village column is what the archetype lends when settled or what it unlocks as a settler or companion.

## The ten

### 1. `bulwark` (tank, rage) — the existing knight line
- Basic: `strike`. Signature: `guard` zone (foes beside it must hit it or pay to leave). Setup: `goad` (taunt, same effect as the dog's bark). Clutch: `command` (sword, as built).
- Counters: armored foes (blade -1) hit it little; flying and casters are its weakness (spells +2 on armored).
- Road: brute-force checks (smash doors, hold a collapsing gate, carry a heavy load with `carry`). D&D fighter / paladin saves.
- Village: speeds up building steps that cost wood and metal (a lifted step); a wall around a plot when the town is under threat (`design-village-grows`).
- Draft fork at 10: `guardian` (bigger zone, armor) or `vanguard` (rage into damage).

### 2. `reaver` (bruiser, rage) — new, sword or axe line
- Basic: `strike`. Signature: `cleave` (hits the target and the two tiles beside it, `radius` 1). Setup: `shove`. Clutch: `second_wind` (a self-heal that grows with rage, costs all of it; D&D barbarian).
- Trade: more damage and HP than the bulwark, no zone, no pull; it drops first when it overreaches.
- Road: intimidation checks (a `nerve`/`persuade` swap: scare a bandit instead of talking); chop wood on the way (a wood find).
- Village: lumber and metal runs come back bigger; a first sparring partner who trains a rank for free (`pc-8` rank cost idea).

### 3. `shade` (skirmisher, charges) — the existing rogue line
- Basic: `kick`. Signature: `backstab` (flank crit chance +20% more). Setup: `poison_blades`, always on. Clutch: `shadow_swap` (as built).
- Counters: beasts (blade +1); hurt by armored.
- Road: `sneak` for the first strike, lockpicks (a d20 check on locked chests and doors), spot a trap (Pathfinder rogue skill list).
- Village: a fence: sells found items for a bit more, opens one locked cellar per village. Cheap places to hide a plot.
- Draft fork: `assassin` (first strike doubles) or `thief` (takes an item off a foe).

### 4. `sharpshooter` (ranged, charges) — the existing archer line
- Basic: `aimed_shot`. Signature: `volley` (area of three tiles at range, half damage). Setup: `snare` (roots, as built). Clutch: `overwatch` / stand and watch (free shot if the archer doesn't move).
- Counters: flying (arrow +2); weak against undead (arrow -2) and armored.
- Road: scouting: reveals the danger zone on the overworld one node ahead; hunts for meat when the party is low on food (XCOM sniper, Pathfinder ranger skills).
- Village: a hunting stand: a settler who adds a food stock each trip; a lookout who warns of a raid.
- Draft fork: `hunter` (beast bonus) or `marksman` (range).

### 5. `tracker` (controller, charges) — new, a companion-handler line
- Basic: `strike` or `pounce` (the dog's). Signature: `trap` (a tile hazard foes avoid or take damage on). Setup: `snare`. Clutch: `call_companion` (the dog or another beast acts again).
- Counters: beasts, with a pet; weak into casters.
- Road: tracking: read a foe's tags before a fight (shows undead, beast, armored on the node); safer camps (a rest event costs less food).
- Village: runs the pen and garden plots (`design-village-grows`); a pet stays home as a settler.
- Draws on the dog's model: bark taunts, bite slows, sniffing finds food.

### 6. `ember` (blaster, mana) — the existing wizard line
- Basic: `firebolt`. Signature: `fireball` (area). Setup: `ignite` (set a forest or brush tile alight, turning terrain into damage; Divinity surfaces). Clutch: `flash` (blinds foes in range one phase).
- Counters: undead (fire +2), ice (+2), armored (spell +2); low HP and no armor, so it needs the bulwark.
- Road: light a fire for the camp, burn a bramble blocking the path, melt an ice gate (D&D fire cantrip).
- Village: an extra forge heat (a smithy build step is cheaper); a candlemaker settler.

### 7. `moon` (controller, mana) — the existing moon spells
- Basic: `moonbeam`. Signature: `moon_sleep` (always lands, a foe misses its phase). Setup: `moon_tide` (pushes 2) and `star_guide` (ally gets +15% crit). Clutch: `moon_veil` (a hit on the target is absorbed).
- Counters: sleeping foes take bonus crit; undead resist sleep? (open question, below).
- Road: finds a path; reveals the next node on the overworld and which fork is shorter (D&D divination, a navigator).
- Village: a seer settler: tells which blessing or setback is coming (a card in the village events); the moon hours decide the night's events.

### 8. `mender` (support, mana) — the healer fork of the mage line
- Basic: `strike` (staff). Signature: `mend` (heal, range 2). Setup: `ward` (as built). Clutch: `aid` at range (help a downed piece up from across the board; the support revive range in `c6`).
- Trade: the best sustain, lowest damage; a party of four with one mender survives bad fights and the sim must check it doesn't stall.
- Road: cure sickness events, stretch food (heal rests use less), use `mend` on the road for free once a day (D&D cleric).
- Village: an infirmary building; revives faster after a fall; opens a recipe tier at the inn.

### 9. `chanter` (support, charges) — new, a talk-and-rally line
- Basic: `strike`. Signature: `rally` (an ally moves again, +1 move). Setup: `dissonance` (a foe is spooked: -1 damage a phase). Clutch: `last_stand` (every ally within 3 stands a downed turn longer).
- Counters: none; makes everyone else's numbers work. Pairs with the bonds system (`bonds.csv`).
- Road: `persuade` bonus on d20 checks and TALK in fights; rumours at events (D&D bard). Calms a hostile group once a trip.
- Village: the inn's talk slots; bonds grow faster; the settlers' services get a small boost.

### 10. `tinker` (utility, charges) — new
- Basic: `throw` (a thrown bomb, small area). Signature: `bomb` (a bigger one, radius 1, armored +2). Setup: `caltrops` (slows foes crossing a tile). Clutch: `patch` (repair or heal an ally from items in the pack).
- Counters: armored; weak alone.
- Road: disarm traps, open a locked box by dismantling it, field repair of a broken tool (Pathfinder alchemist and the inventory grid: gadgets are odd-shaped items).
- Village: a workshop settler who opens the next smithy tier; bigger pack upgrade steps.

## Balance on paper
Starting points to get a kit into the sim, all `[AI]` and tunable in `game/data/`:

| Archetype | Role | HP | Armor | Move | Resource | Damage dealt | Clutch |
| --- | --- | --- | --- | --- | --- | --- | --- |
| bulwark | tank | 22 | 2 | 4 | rage 5 | 3 | command |
| reaver | bruiser | 20 | 1 | 4 | rage 5 | 4 | second_wind |
| shade | skirmisher | 18 | 1 | 4 | charges 3 | 3 (+crit) | shadow_swap |
| sharpshooter | ranged | 16 | 0 | 4 | charges 3 | 3 at range 2 to 4 | overwatch |
| tracker | controller | 18 | 1 | 4 | charges 3 | 2 plus the pet | call_companion |
| ember | blaster | 14 | 0 | 3 | mana | 2 to 4 (area) | flash |
| moon | controller | 14 | 0 | 3 | mana | low | moon_veil |
| mender | support | 15 | 0 | 3 | mana | 1 | aid at range |
| chanter | support | 17 | 1 | 4 | charges 3 | 2 | last_stand |
| tinker | utility | 16 | 0 | 4 | charges 3 | 2 (area) | patch |

Method: the same one the tactical-combat research set (hits to kill, a point value per stat). A kit's budget:
- Each ability pays for itself: power, area, status and range each cost resource, as in `abilities.csv` (fireball 4 mana, mend 3, snare 1 charge).
- A build must win about 15% or more at the boss's level with the party first and no fight may stall ([AI] measuring rules already set).
- A clutch tool should be at least a third of its build's close wins.
- Pairs: the sim should test every pair of four archetypes against the lich and a mixed road fight at 120 fights a row before trusting a gap.

## Open points for Brandon
- **Which of the ten to take forward.** Not all need to ship. The first four exist; the six new ones (reaver, tracker, ember if the wizard is split, mender, chanter, tinker) would need the systems developer for new skills, but most reuse effects already in `abilities.csv` (push, slow, root, heal, ward, taunt, area).
- **Which are companions and which are hero jobs.** The hero's weapon is the job; companions fill the other roles. A `chanter` or `tinker` suits a companion better than a weapon choice.
- **New effects to build:** terrain hazards (`trap`, `caltrops`, `ignite`), cleave, extra-move buffs, and the heal-at-range revive. Everything else exists.
- **Whether moon sleep affects undead** (D&D: undead are immune to sleep).
- **The flavor.** Nothing here names or describes a person. The story, characters and names are Brandon's.

## Evolved classes (pc-13: two branches per job at job level 10)
Visual overview: https://claude.ai/artifact/8rdAXgqcZogHZDsFVjsUgU (the Class Map; each evolved class keeps the base kit and adds two skills). All `[AI]`; the knight, rogue, archer and mage pairs follow the draft pairs in `decisions.md`.

| Base | Evolved A | Evolved B |
| --- | --- | --- |
| bulwark | guardian (zone 2, armor) | vanguard (rage to damage) |
| reaver | warlord (wide sweeps) | berserker (damage for armor) |
| shade | assassin (first strike) | thief (lifts items) |
| sharpshooter | hunter (beasts, fliers) | marksman (reach, pierce) |
| tracker | beastmaster (two beasts) | trapper (hazards) |
| ember | wizard (area, terrain) | healer (mend, ward) |
| moon | seer (foresight) | hexer (debuffs, long sleep) |
| mender | cleric (sanctuary, smite) | medic (rest care, cleanse) |
| chanter | herald (rally the line) | diplomat (talk wins) |
| tinker | bomber (bigger blasts) | engineer (turret, repair) |

## Brandon's answers (2026-10-30, card design-archetypes-present)
`[USER]` All ten archetypes go forward. A class's regular attack sits outside its four abilities. Ember burns a line of 2 to 3 tiles instead of one brush tile: a barrier that can also burn whoever stands on it.

`[AI]` Revised kits (the "basic" slot above is the free regular attack and is not an ability):

| Archetype | Four abilities |
| --- | --- |
| bulwark | guard zone, goad, command, shield_wall (adjacent allies +1 armor until its next phase) |
| reaver | cleave, shove, second_wind, leap (jump 3 tiles, ignoring height) |
| shade | kick, backstab, poison blades, shadow_swap |
| sharpshooter | aimed_shot, volley, snare, overwatch |
| tracker | trap, snare, call_companion, lure (pull a foe 2 tiles) |
| ember | firebolt, fireball, ignite (a line of 2 to 3 burning tiles), flash |
| moon | moonbeam, moon_sleep, moon_tide / star_guide, moon_veil |
| mender | mend, ward, aid from range, renew (heal over time) |
| chanter | rally, dissonance, last_stand, inspire (allies within 2 +1 damage a phase) |
| tinker | bomb, caltrops, patch, smoke_bomb (blocks sight on a 3x3 for a phase) |

The wizard branch's `wall_of_fire` becomes "ignite lines last 3 phases and hit harder", since ignite is now a line already.

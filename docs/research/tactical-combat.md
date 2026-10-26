# What makes tactical combat fun, and how to balance it

Research notes for Lodestone's grid combat. Written 2026-10-26 from design talks, interviews, wiki data and long-running player analysis of Fire Emblem, Final Fantasy Tactics, Tactics Ogre, XCOM, Into the Breach, Divinity: Original Sin 2 and The Banner Saga. Sources are at the bottom. Section 4 says what Lodestone takes from each idea, and section 5 lists what the new sandbox build does with it.

## 1. What the fun is made of

**1.1 Every turn is a real decision.** The common thread in every good tactics game is that a turn offers several moves that are each good for a different reason, and the player can't take them all. A Gamasutra list of "12 ways to improve turn-based combat" boils down to this: space that matters, specialised units, specialised enemies, terrain, a resource that makes strong moves cost something, more than one attack option, more than one objective, and actions that happen outside your turn (counters, reaction fire). If one move is obviously best, the turn is a chore.

**1.2 Information makes the player feel smart.** Into the Breach shows every enemy attack before it happens and almost nothing is random. Subset Games said they wanted "every death to feel like your own fault": when enemy attacks are telegraphed and your own options are not random, "the game starts to feel like a puzzle", and "it's very clear how or why you failed". Fire Emblem gets most of the same benefit a cheaper way: a forecast window shows hit, damage and crit for both sides before you commit, and a danger-zone overlay shows every tile the enemy can reach. XCOM keeps fog and hidden pods, which creates surprise and tension but is also where most of its player frustration comes from.

**1.3 Randomness has to feel fair, which is not the same as being fair.** People remember the 95% shot that missed. Three famous fixes:
- Fire Emblem 6 to 13 rolled two numbers and averaged them ("true hit"). A displayed 80 really hits about 92% of the time and a displayed 20 hits about 8%. Good odds become dependable, bad odds become long shots.
- XCOM (2012) secretly gives the player +15% aim per consecutive miss on easier settings and multiplies displayed hit by 1.2 on Easy and Normal, while aliens lose 10% per consecutive hit. Classic and Impossible turn all of that off.
- The Untamed Tactics team found that a 50% crit chance felt unfair because of streaks, so they made crits land roughly every other attack.
XCOM's lead designer also said he regretted fixing the hit seed so that reloading gives the same result, and wished there had been an option. The lesson for us: keep the honest d20 that Lodestone already shows, but add a small anti-streak cushion for the player and decide on purpose whether a reload re-rolls.

**1.4 Position is the main currency.** Height, cover, flanking, chokepoints, pushing someone off a ledge: these are what make a grid more than a list of HP bars. FFT and Tactics Ogre built whole classes around height (archers gain range and hit from above). Into the Breach goes further: its damage mostly comes from pushing units into each other, into water or off the map, so the board itself is the weapon.

**1.5 Small, readable boards with few units.** Into the Breach is 8x8 with three mechs. FFT tops out at five party units. The smaller the board and squad, the more each unit and tile matters and the easier the whole state fits in the player's head. Big maps mostly add walking.

**1.6 Different roles, and fragile specialists that need protecting.** Tactics Ogre is designed around the squad: no single unit dominates, and mages stay fragile at any level so the player must screen them. That protection job is a decision generator. Our Stardrop (frail, spooks easily) fits this exactly.

**1.7 Actions outside your turn.** Counterattacks (Fire Emblem), reaction fire and overwatch (XCOM) and attacks of opportunity make the enemy phase something the player plans for, not just watches. Fire Emblem's "enemy phase" play, where you park a tough unit where enemies will attack into its counters, is one of the series' most loved strategies.

**1.8 Spend now or save for later.** Banner Saga's Willpower is a small pool you spend for extra move, extra damage or abilities, and you only get it back by resting a turn. Divinity 2 uses action points. Fire Emblem uses weapon durability and limited healing. Without a cost, the strongest ability gets pressed every turn.

**1.9 Make the fights about something besides killing.** Into the Breach's civilian buildings, Fire Emblem's villages and thieves, and timed turns in many games stop the player turtling. XCOM's mission timers show the risk: if the timer is the main pressure, players feel forced into one playstyle and resent it.

**1.10 A clean core first.** The Untamed Tactics team says to build the smallest version that delivers the feeling, polish it, then add damage types and resistances. They only found the fun once systems worked together, and even good ability effects felt weak until damage reactions were in.

## 2. Things that went wrong in famous games

- **Armour walls (Divinity 2).** Physical and magic armour must be stripped before control effects land. Players found late fights a chore, opening moves lost their punch, and mixed parties were punished. Lesson: shields and armour are fine as one target among many, not as a gate in front of every interesting effect.
- **Ranged too strong (Tactics Ogre).** Archers were accurate, hit hard and couldn't be blocked by heavy units, so the answer was always "more archers, kill their archers first". Lesson: ranged needs a real cost (a minimum range, weak in melee, line of sight, or lower damage).
- **Pod activation (XCOM 2).** Moving forward reveals a whole new group at once, so players creep forward with overwatch. Lesson: hidden information plus big spikes makes play timid.
- **Charge times were an accident (FFT).** Matsuno said spell charge time existed only so the PlayStation could load effects. It became loved anyway because it gave the enemy a chance to step out of the blast. Delayed effects are a good idea, but they need to be readable.

## 3. Balance, in numbers

**3.1 Hits to kill.** The feel of a tactics game is mostly set by how many hits it takes to drop a unit. A good default, consistent with how Fire Emblem's normal mode plays: a player unit kills a matching enemy in 2 to 3 hits, and an enemy needs 3 to 4 hits on a player unit. That gives the player tempo without making enemies harmless. One-hit kills should be rare and earned (crit, back attack, combo).

**3.2 Hit chance band.** The interesting decisions sit between about 55% and 90%. Below 40% feels like a waste of a turn; above 95% removes tension. With a d20, every +1 is 5 points, so a +2 bonus is a big swing. Keep base to-hit around 65 to 75% on flat ground and let terrain and tactics move it.

**3.3 Enemy count.** Fire Emblem map makers aim for 2 to 3 times as many enemies as player units across the whole map, released in groups, not all at once. For short Oregon-Trail-style skirmishes with 3 to 4 party members, 3 to 5 enemies on screen is the band, more if they are weak.

**3.4 How difficulty scales in shipped games.** XCOM's harder settings add enemy HP (+1 to +5 by type), +10 aim and +10 crit, more pods and bigger pods, and remove the player's hidden help. In other words it scales four separate dials: toughness, accuracy, numbers and mercy. These dials feel different. More HP makes fights longer, more accuracy makes them swingier, more units makes positioning harder. Good difficulty mostly adds units and smarter placement, not HP sponges.

**3.5 Measure it.** Run the same fight many times with AI on both sides and read the win rate, the number of rounds and how much HP the party loses. A mirror match should be close to 50/50. Most fights in a run should be ones the party wins but pays for.

**3.6 Value every stat point.** Untamed Tactics gives each stat a rough point value (1 attack vs 1 point of bleed, and so on) and prices abilities with it, then fixes the outliers by feel. Same idea works for our classes.

**3.7 Enemy behaviour sets the pace.** Fire Emblem mixes chargers, units that attack only when you enter their range, and guards that hold a tile. Mixing them gives quiet turns and loud turns. All-chargers is a brawl; all-guards is a siege.

## 4. What this means for Lodestone

Ranked by how much fun per hour of build time.

1. **Keep the honest d20 and the full breakdown on screen.** We already print "d20 14 +3 = 17 vs 13". Add a forecast window that shows both sides (your hit, your damage, their counter) with every modifier listed. This is Fire Emblem's best idea and costs little.
2. **A danger-zone overlay.** One key shows every tile an enemy can hit next phase. Turns the enemy phase from a surprise into a puzzle (Into the Breach) while keeping dice.
3. **An action menu: Move, Attack, Skill, Item, Guard, Wait.** Move and act once each, in either order, so hit-and-run is possible. Guard gives the player a reason to not attack.
4. **Counterattacks.** Melee units hit back once when attacked in their reach. Makes the knight a real tank and makes attacking a choice.
5. **Pushes and falls.** A shove that throws a unit off a ledge or into rock turns height into a weapon, which is exactly the "terrain, higher ground, positioning" Brandon asked for.
6. **Cooldown skills per class.** One or two per class, each with a clear job. Cooldowns are the simplest "spend now or later" resource and need no new UI bar.
7. **Items use the trail's supplies.** Using medicine in a fight spends the same medicine the trail needs. This is where combat and Oregon Trail meet: every heal now is a day of sickness later.
8. **A small anti-streak cushion for the player** (proposal: +1 to hit per consecutive party miss, reset on a hit). Can be switched off in the sandbox to compare.
9. **Difficulty as four dials, not one.** Toughness, accuracy, damage and numbers, each separate, for each side.
10. **A balance simulator.** AI plays both sides many times and reports win rate, rounds and HP lost.

Later, not now: facing and back attacks, overwatch, surfaces (fire on forest, which also gives Bushberry's "flammable" a job), charge-time spells with a visible countdown, objectives beyond "kill all" (protect the oxen cart, escape the map edge), enemy behaviour types (charger, ambusher, guard), true-hit style averaged rolls as an option.

## Sources

- [Into the Breach design postmortem, GDC 2019 (session page)](https://gdcvault.com/play/1025772/-Into-the-Breach-Design) and [80.lv summary](https://80.lv/articles/gdc-2019-an-inside-look-at-into-the-breach)
- [Road to the IGF: Subset Games' Into the Breach (Game Developer)](https://gamedeveloper.com/game-platforms/road-to-the-igf-subset-games-i-into-the-breach-i-)
- [Into the Breach's UX makes you feel smart (Prototypr)](https://blog.prototypr.io/into-the-breachs-ux-makes-you-feel-smart-a9cb03210757)
- [Into the Breach: a gem of constrained design (Giant Bomb)](https://www.giantbomb.com/into-the-breach/3030-58234/user-reviews/2200-31048/)
- [True hit (Fire Emblem Wiki)](https://fireemblemwiki.org/wiki/True_hit) and [Weapon triangle](https://fireemblemwiki.org/wiki/Weapon_Triangle)
- [Fire Emblem Engage break mechanic (TechRaptor)](https://techraptor.net/gaming/news/new-fire-emblem-engage-break-mechanic-stops-counter-attacks)
- [RandomWizard's enemy placement guide (FEUniverse)](https://feuniverse.us/t/randomwizards-enemy-placement-guide/14888)
- [Difficulty in XCOM: Enemy Unknown (UFOpaedia)](https://ufopaedia.org/Difficulty_(EU2012))
- [Lead XCOM designer regrets fixed hit chance results (Softpedia)](https://games.softpedia.com/blog/Lead-XCOM-Designer-Regrets-Fixed-Hit-Chance-Results-319573.shtml)
- [How Firaxis' XCOM just misses being my perfect game (Game Wisdom)](https://game-wisdom.com/?p=23559)
- [Final Fantasy Tactics wasn't supposed to have casting times (Kotaku)](https://kotaku.com/final-fantasy-tactics-wasnt-supposed-to-have-casting-t-1519947150)
- [What's old is new again: a Tactics Ogre analysis (Game Developer)](https://www.gamedeveloper.com/business/what-s-old-is-new-again-a-tactics-ogre-let-us-cling-together-analysis)
- [Banner Saga stats (Banner Saga Wiki)](https://bannersaga.fandom.com/wiki/Stats)
- [Our hopes for Baldur's Gate 3 after Divinity 2 (KeenGamer)](https://www.keengamer.com/articles/features/opinion-pieces/our-hopes-for-baldurs-gate-3-after-divinity-2/)
- [12 ways to improve turn-based RPG combat systems (Game Developer)](https://gamedeveloper.com/design/12-ways-to-improve-turn-based-rpg-combat-systems)
- [How to design a turn-based combat system, Untamed Tactics (Game World Observer)](https://gameworldobserver.com/2022/12/02/how-to-design-turn-based-combat-system-untamed-tactics)
- [5 core pillars that make turn-based combat fun (Gamedev's Journey)](https://gamedevsjourney.substack.com/p/5-core-pillars-that-make-turn-based)

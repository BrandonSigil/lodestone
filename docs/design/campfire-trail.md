# The campfire trail (proposal, backlog P32)

Status: options for Brandon, 2026-11-16. Nothing here is built. A pick from him becomes a `[USER]` line in `docs/decisions.md`.

## His ask
"I hate how the overworld works right now. Fast forward, chat, fish (no fishing rod in the game yet which stinks! Because we have a mini game) eating is just an ugly menu with a confusing ux. ... I love Oregon trail and want to honor that gameplay here, but it shouldn't be a burden either it should be fun. One thing that could help is lump everything together at a campfire, like thats where you chat, cook, eat, fish."

## What the road is today
- The live road is the overworld (`game/scripts/overworld/`). You walk a hex path in real time. A day is 30 walked seconds. Each day queues a night.
- A side box offers HUNT and FORAGE (dice rolls with a cooldown), FISH (opens the fishing screen, greyed out without a rod), TALK (a random companion line, no effect), MAKE CAMP (once per leg, stand still 20 s), PACK and FAST FORWARD.
- Each night a meal picker asks what each member eats, one by one, or SKIP. An unfed member loses morale (`MoraleRules.hunger_loss`). Morale is the only hunger meter.
- **The rod does exist.** It is in `items.csv` (gear, 6 gold), but the only shop is on the shelved hub screen. On the live path the only rod is a pickup by the village stream (`stream_rod` in `village.json`). It is easy to miss, so in practice the game has no rod.

So the road has six buttons for chores, none of which leads to the others, and the one fun minigame is locked behind an item nobody finds.

## What the research says (sources in the research notes below)
1. **Make the pressure a clock.** Dredge's team tried fuel, found refuelling trivial, and switched to time: the day ends, and you are out at night. Days to the destination should be the felt pressure, and food one lever on it.
2. **Meals are rewards, not a tax.** FFXV camp cooking, Monster Hunter and Breath of the Wild meals give a buff for tomorrow. The player chooses a reward and isn't paying a toll.
3. **Show days, not meters.** "Food: 6 days, trip: 4 days" is what Banner Saga and Oregon Trail players think in. A bar that drains is just time-to-starve.
4. **One screen, one small budget, a clear end.** Darkest Dungeon's camp gives a fixed number of points per night (12 Respite points) to spend, then it's over. It is the closest proven model for the campfire.
5. **Talk should pay off.** In Darkest Dungeon II, relationships made on the road change fights. A chat that does nothing is noise; a chat that raises a bond is a choice.
6. **Minigames stay optional and forgiving.** In Dredge you catch something even if you do nothing. Fishing should be a bonus you choose, never the only way to eat.
7. **Oregon Trail's heart is decisions that end in a story beat.** Its pace and rations settings, river crossings and events all end in a line like "you lost 2 oxen". Its busywork (hunting every day, per-person bookkeeping) is what to drop.
8. **Avoid:** a separate button per need (today's road), per-person food menus every night, death spirals (hunger, then lost fights, then more hunger), and opaque math.

## Options

### A. A campfire every night (recommended)
- **Day.** You walk the overworld as now, with fights and arrivals as now. The road keeps only PACK and one button: WALK TO CAMP (today's fast forward). HUNT, FORAGE, FISH, TALK and MAKE CAMP leave the road.
- **Dusk.** At each day's end the party makes camp by itself. A full screen opens: the party round a fire, with the regular party frame at the bottom (as fishing does, per the 2026-11-02 rule).
- **Evening: three actions.** The fire has three slots, like Darkest Dungeon's camp points. Cards:
  - COOK: pick one dish from what's in the pack. Its buff lasts the next day (heal, +morale, +attack, a steadier aim). Each character can have a favourite dish.
  - FISH: the minigame, offered when the camp is by water. A quick-cast option gives a plain catch without playing.
  - TALK: pick two companions for a short scene, which adds bond points. Bond lines are Brandon's to write; Claude's drafts are flagged.
  - HUNT or FORAGE: today's dice rolls, which bring ingredients.
  - MEND: heal one member.
  - KEEP WATCH: no night ambush.
  - REST: +morale.
- **Eating is automatic.** One pot feeds everyone at the chosen ration, set by an Oregon Trail ration dial: FILLING / MEAGER / BARE. The fire shows "Food: 6 days at Filling, 9 at Meager". A short pot costs morale on a sliding scale. The per-member picker goes, which replaces the [USER] 2026-11-01 camp picker line, so this needs his yes.
- **Some nights: a fireside event.** About one night in three, a card with two or three choices, like Oregon Trail's beats (a stranger at the fire, wolves howling, a storm, a find). The writing is his; Claude's drafts are flagged.
- **Morning.** "Skip to morning" repeats last night's plan, replacing SAME AS LAST NIGHT, so a player in a hurry spends one click a night.
- **Later: a pace dial.** STEADY / HARD / GRUELING trades days against morale, the other half of Oregon Trail.
- **Pros:** exactly his idea, done with a budget so it stays short. Reuses fishing, morale, bonds, meals and dice. One screen to learn.
- **Cons:** it's the same screen every night, so it needs variety: region backdrops, events, weather, and dishes unlocked by the village chef.
- **Build:** medium. One new scene, a card table in `game/data/`, rules in a pure `CampRules`. Fishing, dice, bonds and morale code are reused. It needs one campfire backdrop: graybox first, then art from Brandon (or a Picsart batch on his go).

### B. The road log (Oregon Trail purist)
- **Day.** The real-time walk is replaced by a day ticker: a strip of landscape with day count, distance to the next landmark and weather. Pace and ration dials are always on screen.
- **Stops.** Each day can stop on an event card (river, stranger, sickness, a find) or a landmark.
- **Camp.** A one-line summary.
- **Pros:** the closest to Oregon Trail; nothing to click unless something happens.
- **Cons:** it throws away the walkable overworld that exists. Fishing and chat lose their home. It needs a lot of event writing, which is his.
- **Build:** small code, large writing.

### C. Campsites you choose on the map
- **What it is.** Option A's campfire, but you choose where to stop. The overworld shows campsites along each path.
  - By a river: fishing.
  - On a hill: the watch is free.
  - In ruins: an event.
  - In the open: nothing special.
- **Pacing.** Stopping early is safe. Pushing on to a better site costs a tired night, and food still drops each day.
- **Pros:** route and pace become a real choice on the map, like Slay the Spire's and FTL's choose-your-node maps.
- **Cons:** campsite data on every path, and more map UI.
- **Build:** A plus a medium layer. **A can grow into C later**, so picking A doesn't close this door.

## The rod
Whichever option he picks:
- The town chest starts with a rod, shown on the get-ready screen (P31).
- The FISH card says where to get one when you have none.
- The stream pickup can stay as a second rod or go.

## Research notes
- Dredge's design history (fuel replaced by time, forgiving minigame): https://www.gamedeveloper.com/design/trawling-in-the-deep-how-black-salt-games-made-spooky-fishing-rpg-i-dredge-i-
- Darkest Dungeon camp numbers: https://darkestdungeon.wiki.gg/wiki/Camp
- Darkest Dungeon II road and relationships: https://www.gamedeveloper.com/design/how-a-theme-of-a-road-trip-from-hell-would-shape-darkest-dungeon-ii
- FFXV cooking: https://kotaku.com/in-final-fantasy-xv-cooking-is-important-1686721988
- Banner Saga caravan: https://bannersaga.fandom.com/wiki/Caravan
- Hunger meters: https://pcgamer.com/how-survival-games-get-hunger-and-thirst-wrong-and-how-to-fix-it
- Kingmaker's camping complaints: https://forums.beamdog.com/discussion/comment/1149543
- BG3 camp supplies: https://shacknews.com/article/136668/camp-supplies-baldurs-gate-3
- Oregon Trail's origins: https://www.avclub.com/the-making-of-the-oregon-trail-an-interview-with-d

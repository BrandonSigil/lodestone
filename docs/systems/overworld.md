# Overworld and the E2E loop

The first playable loop ([USER] 2026-10-28, `docs/decisions.md` "End-to-end loop"). Placeholder art throughout.

## The loop
1. **New game** (launch menu) wipes the save and starts in the hero's cottage. The hero is alone, a *nobody* (class `nobody`).
2. **The village** (`village`, no fog): take one weapon from the smithy rack (sword, daggers or bow; `data/weapons.csv` says what each adds), pick up a rope (smithy yard barrel), food (tavern barrel) and potions (the chest in the cottage).
3. **The dog**: the west home on the river ridge is locked (`door_dog`: a hard BASH). Its window on the right front wall (`dog_window`) climbs into `house_dog`; LET DOG OUT sets `met_dog` and the dog joins the party. Once he is out the front door opens both ways.
4. **The statue** in the square (placeholder blob `ph_statue`) holds the glowing Lodestone; TAKE sets `has_lodestone` and a LODESTONE button appears on the bottom bar next to PACK. The gate only lets you out once you have it (`village_gate`, needs `flag:has_lodestone`).
5. **The overworld** (`scenes/overworld.tscn`, see below): walk the path north to the snowy pass. North-east (prairie) and north-west are shown but shut.
6. **The snowy pass** (`snow_pass`, built by `tools/explore/build_snow_pass.py`): five terraces from level 0 to 8, two wolves low down, a bandit pair holding the last stair, a cache, a hidden find in the snow, a high ledge only the rope reaches (`rope_climb`, needs `item:rope`), and the wolf den (`wolf_den`: a pair of wolves and a lone one further in, bones to rummage).
7. **The crypt** (`crypt`) through the stair at the top of the pass: the Lich King (class `lich`, a placeholder piece) waits on the throne terrace. His group has `boss` (more XP) and `end`: beating him sets `e2e_done` and shows TEST DONE.
8. **Falling costs nothing** ([USER] 2026-10-28): when the party falls, everyone wakes in the village square (`Game.SQUARE`) at full HP with every item, level and flag. The first fall sets `lodestone_revealed`.

## The overworld
- Places: `data/overworld_nodes.csv` (`x, y` in a 1000 x 700 map, `open`, the explore `map` and entry cell, and `maps` that belong to the place so leaving them lands there).
- Paths: `data/overworld_paths.csv` (`seconds` per leg, `enc_min`/`enc_max` encounters, the tile set road fights use, `points` as `x:y|x:y`). Paths run both ways.
- Click a place to walk there. The mini party walks the path in real time. Encounters are planned when the leg starts (between 20% and 85% of the way, 8 seconds apart) and shown as "?" on the path.
- On the road: HUNT, FISH, FORAGE (dice rolls, placeholders for minigames; each one once per 15 seconds walked), TALK (a party member's line, `TALK_<ID>_<n>`), PACK and LODESTONE. **FAST FORWARD** (or Tab) jumps to the next encounter, or to the end of the leg.
- Food: the party eats every 30 seconds walked. With no food each member loses 1 HP, never below 1.
- Encounters: `data/travel_events.csv`, the `events.csv` format. Fights (`combat:pair_wolves`, `combat:pair_bandits`) run in `combat.tscn` on a generated map in the path's tile set and come back to the overworld. Also found items and an abandoned house to rummage (an item, or wolves).
- Arriving shows GO IN; leaving an explore map through its way out puts the party back on the overworld at that place.
- Rules: `game/scripts/overworld/travel_rules.gd` (pure, tested in `tests/test_loop.gd`). State: `Game.travel`.

## Party, pack and levels
- The adventure party is `Game.ADVENTURE_ROSTER` (the hero, then the dog once `met_dog` is set). The hero is the lead's look on the nobody class; the smithy weapon adds attack, damage, move or range (`Game.weapon_mods`).
- Pack: food, potions (the `medicine` count), gold and gear (`RunState.items`, rows of kind `gear` in `data/items.csv`, e.g. rope; an effect like `rope:+1` adds one). PACK lets the hurt EAT (1 food, +2 HP) or DRINK (a potion).
- Levels ([USER]: they come on their own; every few levels a pick): `data/levels.csv`. 100 XP a level, +1 max HP a level, a pick every 4 levels: MORE HEALTH (+3 HP), MORE HIT (+1 to hit and damage) or MORE MAGIC (+2 on spells and magic hits). Picks wait in the Lodestone menu (its button glows). XP for a won fight: 10, plus 25 a foe, plus 100 for a boss, to everyone in the party. Rules: `LevelRules` (pure).
- Everything lives in meta (`meta.pack`, `meta.levels`, flags), saved on every scene change, so a restart or a wake-up keeps it.

## The Lodestone menu
Each member's level, XP, HP and fighting stats, the waiting picks, and GO HOME (back to the square, healed; hidden in the village itself).

## Testing it
- `tests/test_loop.gd` and `tests/test_snow_pass.gd` (in `tools/check.sh`).
- The robot: `godot --headless --path game -s res://tools/e2e_play.gd [-- seed]` plays the whole loop with fights on auto: the village steps, the dog, the statue, the road (it forages, fights what comes), the pass, the rope ledge, the den, the crypt boss, then a deliberate fall. A lost fight wakes it in the square and it comes back to try again (up to 4 times), checking the wake-up kept everything. `E2E=1 tools/check.sh` runs it too (about 2 minutes). Seeds 1 to 5 pass, with 2 to 5 falls on the way.
- Balance, by the AI-vs-AI sim on generated maps (hero with sword plus dog): two wolves 91% at level 1; three wolves 61% at level 2 (why the den is split into 2 + 1); the Lich King alone about 46% at level 4. A player does better than the AI.

## Not yet
Minigames for hunt, fish and forage; the dog's BARK and sniff; dog art (he draws as the tinted dummy); statue and Lich King art; the prairie and north-west places; the corgi's PERK UP warning on the road; a way into the crypt's throne room without its locked gate (the player picks or bashes it as before); job promotion at level 5.

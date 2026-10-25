# Trail and survival (graybox)

Code: `game/scripts/trail/`. Rules are in `trail_rules.gd`, state in `run_state.gd`.

- Each button is one day: WALK (10 leagues), WALK HARD (15, -5 morale, -1 HP each), REST (+2 HP, +5 morale), HUNT, FIND HERB. USE MEDICINE heals the most hurt member and doesn't take a day.
- End of every day: each member eats `food_per_day`, Bushberry adds 1 food, Skeleton Archer costs 2 morale. No food = -2 HP each and -10 morale.
- Wayfinding: each walk rolls the party's best Wayfind vs 8 + 8 x strangeness. Failing covers half the distance.
- Events: 35% per walk, from `data/events.csv`. Each option is a check (or `none` / `fight`) with a DC and win/lose effects. Buttons show the party's success chance.
- Inventory: 12 slots. Food 10 per slot, medicine 5 per slot, Wizard's books 3 slots. Overflow is lost.
- The Lodestone strip shows the route, the Wall at 150, the fog past the farthest anyone has walked, and marks from every past run.
- Run ends at 300 leagues (success) or when everyone is at 0 HP (recall). Meta progress survives: deaths, best distance, unlocks, map marks.
- Try it alone: open `scenes/trail.tscn` and press F6.

## Adding an event (no code)
1. Add a row to `game/data/events.csv`. Columns: id, weight, min_s, max_s (strangeness range 0 to 1), once_flag (hide once this meta flag is set), text_key, then up to three options of key, check, dc, win, lose.
2. Checks: none, fight, persuade, sneak, wayfind, hunt, forage, nerve, tame, masonry, fish, heal.
3. Effects, joined with `;`: food:+n, medicine:+n, gold:+n, morale:+n, dist:+n, day:+n, hp_all:+n, hp_one:+n, combat:<encounter id>, unlock:<flag>.
4. Add the text keys to `game/text/placeholder.csv`.
5. Run `tools/check.sh`. The data tests catch missing keys and bad effects.

Not yet: water, warmth, shelter, real minigames for hunt, fish and herbs, gold use, the camp scene.

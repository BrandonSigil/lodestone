# Hunting prototypes (A to D)

Brandon, 2026-11-17: "Build simple prototypes of each of these", after the four pitches in `docs/design/hunting-pitches/index.html` (published at https://claude.ai/artifact/QaBQQdF4cHfsqaNYPZ3QNd). Each is a playable graybox so he can feel them and pick. None is hooked to the camp or the pack yet: practice only, nothing is saved.

**Where:** Dev Tools > PLAY > Hunting (`scenes/hunting.tscn`, `Game.HUNTING`). Pick A, B, C or D. Two toggles put the Hunter and Doggo in the party, so their hooks can be felt. Esc in a hunt comes back to the picker; Esc on the picker goes back to Dev Tools. Every hunt ends on a card (what you caught, food), with Space or click to go again.

## A · Bow Blind (Brandon's idea)
- A forest glade from behind a log. The mouse aims.
- Animals (rabbit, pheasant, deer, boar) break from one bush and run an arc to another. Some stop halfway and look around.
- Hold the left button to draw. The ring tightens, turns gold at a full draw, then the aim starts to shake (red). Let go to shoot. A weak draw drops short and flies slow. Arrows take time, so lead the runners.
- Noise: a fast-moving aim makes noise. Noisy: animals run faster, stop pausing, and a pausing one bolts. Still: noise drains.
- A clean hit is a catch, an edge hit wounds (it runs off), a near miss spooks the animal for good. An animal that reaches cover unhurt stays in the glade.
- 5 arrows. The glade's size comes from the party's hunt roll on entering (d20 + bonus vs `hunt_dc`, base `hunt_glade_base`, +1 made, +1 more at 5 over).
- **Hunter:** draws faster and holds steady longer. **Doggo:** a "!" over the bush the next animal will break from (SNIFF), F sends him in to break the bush nearest the aim now (FLUSH, `hunt_flush_cool`), and he runs down a wounded animal (FETCH).

## B · Stalk
- A top-down meadow. WASD creeps the hero along hoof prints toward a grazing deer.
- The head cycles: down (grazing), a tail flick (it's about to look up), up (looking, its sight cone shows red). Move while the head is down.
- While it looks, the alert bar fills by how visible you are: moving in the open is worst, moving in tall grass slower, still in the open a little, still in tall grass nothing. Full alert: it bolts.
- Wind (HUD arrow): if it blows from you to the deer within `stalk_scent_range`, it smells you and the alert creeps up.
- Twigs on the tracks: stepping on one is a nerve check (d20 + half the party bonus vs 11). Fail and the head comes up looking at you.
- Inside the gold ring, hold the left button to draw (same draw as A) and let go: one shot. A miss or a graze and it bolts.
- **Hunter:** the warning comes earlier ("ears up!") and the ring is wider. **Doggo:** the deer shows from anywhere and the old tracks show clearly (without him it shows only within 330 px), and he fetches a wounded deer.

## C · Snare Line
- The ground by the camp as a 12 x 7 grid with bushes and a stream. Tonight's animal runs show as dotted tracks in each animal's colour.
- Click a cell to set a snare (`snare_count`, 3), right-click to put the bait down, Space to sleep.
- The night plays out in about 5 seconds: each animal walks its run, and the first snare it steps in rolls to hold (d20 + bonus vs the animal's `strength`). Snapped snares say so.
- Habits: rabbits hop between bushes, boars go straight to the water (strength 15, they snap most snares), foxes zigzag and turn back from bait you handled; bait pulls a rabbit or boar off its run if the run passes within 2 cells.
- About half the drawn runs are stale: nothing walks them tonight.
- **Hunter:** sees every run (without him, only half show) and adds `snare_hunter_bonus` to each hold roll. **Doggo:** fresh runs are bright with a "!" and stale ones fade.

## D · Corgi Drive
- You are Doggo. WASD runs him through a meadow; the flock (pheasants or rabbits) runs from him.
- Space barks: a cone in front of him shoves every bird in it (`drive_barks` in hand, one back every `drive_bark_back` seconds). Run straight at a bird and it panics and flies off.
- A hedge runs down the right side with one gap; the hero waits behind it. Click or E while a bird crosses the gold middle of the gap to shoot it. A bird through the gap unshot is gone.
- `drive_time` seconds (60). **Hunter:** shoots every bird that enters the gap on his own.

## Code and data
- `game/scripts/hunting/hunt_rules.gd` (`HuntRules`): pure rules for all four (draw, arrows, noise, sight and scent, snare field, runs, bait and night, flock and bark, the gap). Tests: `game/tests/test_hunting.gd`.
- `game/scripts/hunting/hunt_game.gd` (`HuntGame`): the shared base (field, end card, Esc, flat shapes for bushes, pines, animals, hero, Doggo, the bow reticle). One script per prototype: `bow_blind.gd`, `stalk.gd`, `snare_line.gd`, `corgi_drive.gd`; the picker is `hunt_scene.gd`.
- `game/data/hunt_animals.csv`: one row per animal: size, speed, pause chance and length, food, snare strength, weight, and the modes it appears in.
- `game/data/levels.csv` `hunt_*`, `stalk_*`, `snare_*`, `drive_*` rows: all `[AI]` numbers.
- Text: `HUNT_*` keys in `game/text/placeholder.csv` (game text: labels, keys and toasts).
- Screenshots: `game/tools/hunting_shot.gd -- <png> <menu|bow|stalk|snare|drive|card> [hunter] [doggo] [night]` (cloud: xvfb-run with `--rendering-driver opengl3`).

## Not built
Hooking the picked hunt to the camp's HUNT action and the pack (raw meat as rations, like fish); upgrades (bow tiers, quiver, cloak, wire snares, baits); a first-time how-to; Brandon's art.

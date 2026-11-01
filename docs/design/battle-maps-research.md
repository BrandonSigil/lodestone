# Battle maps that make sense: research and a plan for road fights

Status: **Research and proposal (AI), 2026-11-01.** Written for Brandon's note on the road-fight valley ("why would there be like 3 bridges all next to each other covering diff parts of the river?", `docs/decisions.md`, 2026-11-01). Everything in the recommendation sections is a proposal until he retags it `[USER]`. No story, names or flavor text here: pieces are named by what they are (a bridge, a ramp), never by who built them.

How to read the sources: a link means I read the page or a search summary of it. "(from play)" means I could not source it and am going on how the game plays. "(my reasoning)" is geography or design logic with no source. Several pages (GDC Vault, some forums, one wiki) blocked automated reading, so where I only saw a search summary I say so.

## 1. Why the current road-fight map feels clunky

I read `game/scripts/combat/map_gen.gd` and `map_ops.gd`. The order of work is the cause, not any one number.

1. `MapGen.valley` builds terrace heights from noise, then digs a river that walks downhill and leaves the map from its front half. So the river is a wall across the middle of a 21 x 18 fight.
2. Then `MapOps.link` adds stairs, and `MapOps.cross_river` repairs the wall. It picks the place "nearest the middle" where two banks face each other with a long walk between, lays a bridge or a ford, then picks a second one at least 7 cells away. After that, `CROSS_EXTRA` adds up to 2 more crossings wherever banks near the centre are still more than 12 steps apart.
3. The road comes last (`_roads`): the easiest walk from the screen-left cell to the screen-right cell. It has no idea where the bridges are.

So bridges are patches for a problem the river created, they are placed by geometry, and nothing connects them to a road or to a reason. Four crossings close together is exactly what that code produces when banks are far apart. The 11-01 rules stay: no wading, clear land routes, no fighting behind cliffs. Those are good validators. What is missing is a map that is about something before it is about terrain.

## 2. What the classic tactics games do

### Final Fantasy Tactics

- **Handmade, one map per place.** Maps are authored as small stages, not generated. A fan thread puts the effect well: the battles take place in abandoned houses, city streets and castle rooftops, and they "FEEL like those places", with details like pillars in front of a temple changing how both sides move ([ResetEra thread](https://www.resetera.com/threads/one-of-the-most-important-things-in-final-fantasy-tactics-maps.62663/)). Same thread: compact size keeps fights fast and makes positioning critical.
- **Height is the tactic.** Posters note that many maps have chokepoints that a unit with high jump, teleport or good height can bypass, so a chokepoint is a decision, not a wall (same thread). Archer lines of fire and tiles hidden inside walls or nooks are the complaints, which maps onto our "no fighting behind cliffs" rule.
- **Random battles reuse authored maps with varied starts.** Random fights only trigger on preset world-map spots, and per the [FFHacktics wiki](https://ffhacktics.com/wiki/Random_Battles) (search summary; the page itself blocked me) each path location can trigger several random battles, each with a specific map and enemy squad. The Caves of Narshe map page for [Zeklaus Desert](https://www.cavesofnarshe.com/fft/maps/mapsingle.php?mapid=076) has a "random" view showing possible party positions, and its enemy groups are listed by which side you entered from. So the pattern is: one handmade map per location, the start position and enemy group change with the direction of travel, and a rare special group exists. I could not confirm whether those maps are the same stages as the story battles at the same location (from play: I believe the world-map location uses the same field, but treat that as unconfirmed).
- **Engine detail worth knowing:** the battle field is a real 3D model for looks, with a simple tile grid that stores a height per tile corner for walking ([GameDev.net thread](https://www.gamedev.net/forums/topic/534781-3d-tile-maps-how-to-storerender-the-level-eg-final-fantasy-tactics-disgaea/)). Authors drew a place, then the grid followed it. We are doing the reverse today.

### Tactics Ogre (and Reborn)

I found no developer commentary on map construction. Reviews describe tile height, terrain type and facing deciding whether you can even reach enemies, and archers outranging their shown squares from high ground ([Checkpoint Gaming review](https://checkpointgaming.net/reviews/2022/11/tactics-ogre-reborn-review/)); another review calls the environments mostly minimalistic. From play: maps are set pieces tied to a story beat (a hillside approach, a castle with ramparts, a river with one bridge), and they usually give the player a clear side of the map to deploy from and a clear far side to reach.

### Triangle Strategy

The developers say the multi-tiered maps are what let each unit role matter, that starting placement matters a lot because of the height differences, and that knocking enemies off high ground is a core pleasure ([Nintendo Everything](https://nintendoeverything.com/triangle-strategy-devs-on-the-name-plot-multi-tiered-maps-and-more/)). Maps must also read well from every camera angle. Lodestone's camera does not turn in play, so we only need the one angle to look right.

### Fire Emblem, Unicorn Overlord, Vandal Hearts

I found no developer talk on map design for these. (from play) Fire Emblem maps are built around an objective that explains the layout: a gate to seize, a village to reach, a bridge or fort to hold, with the foes placed in the obvious defensive spots. Unicorn Overlord uses free movement on maps with a clear route and optional side paths. Vandal Hearts uses small stages with one or two obvious approaches and a high position for the foes. The common thread is that you can say in one sentence what the map is for.

### What I take from the classics

1. **One sentence of purpose per map** (hold a crossing, climb to a camp, cross an open road). Every feature either serves it or is scenery.
2. **Few, readable features.** Two to four chokepoints, one or two clear high positions, a clear side to start from.
3. **Height gives the choice.** A chokepoint with a costly bypass over a ridge is better than a wall or an open field.
4. **Authored places, varied by entry.** FFT's variety comes from start position, enemy group and time of day, not from regenerating the terrain (from play for time and weather).

## 3. What procedural tactics games do

| Game | Handmade | Generated | Source |
| --- | --- | --- | --- |
| XCOM 2 | Plot (the road and river skeleton with sockets), parcels (small, medium, large pieces sized from the best XCOM: EU maps), plot-cover parcels (8 to 16 tile runs of cover along roads) | Which parcel fills each socket, cover and props along roads, biome and weather | [Game Rant](https://gamerant.com/xcom-2-procedural-level-detail/), [80.lv](https://80.lv/articles/environment-storytelling-in-xcom-2/), [GDC talk page](https://gdcvault.com/play/1025213/Plot-and-Parcel-Procedural-Level) |
| Phoenix Point | Layouts (map size, roads and paths, where cover and buildings go), building blocks, placement rules, faction look | A random variant of the right size and type in each building slot, props within limits | [Developer blog](https://phoenixpoint.info/blog/2017/11/28/haven-design-and-map-generation), [Aug 2019 update](https://phoenixpoint.info/blog/2019/8/12/august-development-update) |
| Into the Breach | Every map layout (8 x 8) | Mission placement, small extras such as forests and sand, enemy picks | [Game Developer](https://gamedeveloper.com/design/reimagining-failure-in-strategy-game-design-in-i-into-the-breach-i-) |
| Battle Brothers | Tile art, camp and location rules | Map built from the world tile's terrain, with camp layouts by size | [Dev blog 135](https://battlebrothersgame.com/?p=26041) |
| Wartales | Tile sets and objectives | Nearly all combat maps, tied to where the fight started | [Community Q&A](http://www.gamebanshee.com/x9f4h) (search summary only; developer statements before release) |
| Spelunky | Room templates (10 x 8), obstacle blocks | A guaranteed path first, then a template per room by its place on the path, with probabilistic tiles and mirroring | [Kazemi's breakdown](https://www.tinysubversions.com/spelunkyGen2/index.html) |
| Bad North | Over 300 handmade tiles, level-specific tile sets | Wave function collapse fills the grid under hard and soft rules | [Game Developer](https://www.gamedeveloper.com/game-platforms/how-townscaper-works-a-story-four-games-in-the-making) |

### What these say about "crafted vs random"

- **XCOM: Enemy Unknown tried random and dropped it.** Its art director said the generation was too random and put cover and clutter where soldiers would not logically go, with the lesson "Random's not fun" ([Game Rant](https://gamerant.com/xcom-2-procedural-level-detail/)). XCOM 2's fix was not less variety but a hand-made skeleton: designers lay out the road network and where pieces may go, and randomness is spent on what fills the sockets. Solomon calls the result a quilt where tiles are swapped out ([Game Developer](https://www.gamedeveloper.com/design/jake-solomon-explains-the-careful-use-of-randomness-in-i-xcom-2-i-)). Players may recognise a building, but not the whole layout.
- **Structure comes before decoration.** Phoenix Point's rules are about function: building doors must face a street, multi-floor buildings must have stairs, and every faction has one visual language, so output looks designed ([developer blog](https://phoenixpoint.info/blog/2017/11/28/haven-design-and-map-generation)).
- **Handmade where tactics live.** Justin Ma on Into the Breach: the team hand-designed each layout because random terrain could create spots where enemies attacking buildings could not be stopped without damage, and procedural generation only handled secondary things like forests, "heavily restricting" it ([Game Developer roundup](https://www.gamedeveloper.com/design/devs-weigh-in-on-the-best-ways-to-use-but-not-abuse-procedural-generation)). Matthew Davis added that controlling map design kept the game from producing maps that are not fun. They also banned two buildings placed diagonally or in an L-shape, because enemies lodge in the nook ([Game Developer](https://gamedeveloper.com/design/reimagining-failure-in-strategy-game-design-in-i-into-the-breach-i-)). That is a validator written as a design rule.
- **Path first, then fill.** Spelunky lays the solution path, then picks templates by position on it. Everything else is built around something that is known to work.
- **Handmade landmarks anchor the generated land.** Astroneer places handmade landmarks that shape the terrain around them, and starts players on gentle ground ([same roundup](https://www.gamedeveloper.com/design/devs-weigh-in-on-the-best-ways-to-use-but-not-abuse-procedural-generation)). Tanya X. Short in the same piece: the bigger risk is "samey, boring blandness" than chaos, and pieces should share higher-level themes so they connect meaningfully.
- **WFC is bad at long thin things.** Stalberg says wave function collapse is poor for walls and pipes, and that areas the navigation check marks unreachable get forests, which looks natural ([Game Developer](https://www.gamedeveloper.com/game-platforms/how-townscaper-works-a-story-four-games-in-the-making)). Rivers and roads are long thin things, so they should be drawn as paths first, then the terrain built to fit them. He also uses hard rules against identical or mirrored neighbours so the output does not look procedural.
- **Battle Brothers writes the layout from habits.** Terrain follows what lives there: enemies cut trees at a camp so it is open ground, palisades have gaps that limit angles but never make a single chokepoint that halts the battle, fortifications are shown before you engage, and start positions are fixed so outcomes depend on tactics, not spawn luck ([dev blog 135](https://battlebrothersgame.com/?p=26041)).
- **Phoenix Point's fix for repetition** was to change generation for visual variety and spread enemies out at the start ([Aug 2019 update](https://phoenixpoint.info/blog/2019/8/12/august-development-update)). Players do notice repeats; Spelunky's creator has said players quickly recognise repeating patterns.

Not found: a source for Mordheim or Darkest Dungeon 2 map generation (Mordheim's maps are tabletop terrain and DD2 is not a map-based tactics game), and no r/gamedesign or r/TacticsOgre threads I could read. The XCOM 2 parcel sizes in tiles were not in anything I could open.

## 4. Rules for rivers, bridges, fords, roads, cliffs and buildings

Game sources on this are thin, so most of this is common sense checked against how the games above behave. Developer posts on world generation agree on the shape of it: cost-weighted routing with a penalty for steep grades and for crossing water, a bridge raised to bank level where a road meets a river, and a spanning tree to decide which places connect ([Rust devblog](https://rust.facepunch.com/news/devblog-50), search summary). Treat the rest as (my reasoning).

**Rivers**
- A river has a source and a mouth. Source: a spring or pool at the back, high on the map. Mouth: it leaves the map or ends in a pool. Water never runs uphill and falls where the terrace steps down (already `MapOps.river`, V5, V11).
- **Decide the river's job first.** Either it is a **flank river** (it runs along one side or a corner, on neither deploy side's path, so land routes stay clear and it is scenery and a hazard) or it is a **crossing river** (it cuts between the starts, and the map is about one crossing). Never a river that splits the map with no crossing plan.
- Rivers bend in long smooth runs and widen where the land is flat. Straight, narrow, falling runs are where cliffs are. This also agrees with V9.

**Bridges and fords**
- **A bridge exists because a road meets a river.** One road crossing, one bridge. The road comes first and the bridge is placed where the road lands, at a narrow reach where both banks are within a level (our `bridge_span` already needs that).
- **A ford exists on a wide, level reach**, where both banks are the same height and the river is widest and has no fall. Our ford is stepping stones. It is a second, smaller crossing and only appears downstream or upstream of the bridge by a clear distance.
- **Limit: at most one bridge and one ford per river per map**, never within 8 cells of each other. If a crossing river has no road, it has a ford and no bridge.
- Landings are real places: the road runs straight onto the deck, the bank is flat for 2 cells before the deck, and a small flat area gives a place to stand. No stair from a bridge end down to water.

**Roads**
- A road goes between two named ends (a map edge, a camp, a ford) and every other feature is placed relative to it. It follows the easy slope, uses stairs or a ramp only to climb a terrace, and prefers one-level steps. It never ends at a cliff face or in water.
- A fork exists only if it reaches a second place.

**Cliffs, terraces and ramps**
- Terrace edges are crossed in a small number of believable places: where the road climbs (a switchback or stair), at a short ramp cut into the rock, and sometimes a goat path (a one-wide climb). Not on a regular spacing.
- A tall cliff has a reason to be there: the river's fall, a rock outcrop, or the edge of a plateau that holds a camp.
- Every stair run joins two walkable levels and leads somewhere (`MapQA` already has the stairs check).

**Buildings and set pieces**
- A building, wall or camp faces the road or a clearing, sits on level ground, and has an open approach. Ruins stand where there is flat land. Nothing blocks the only route (Into the Breach's nook rule, Battle Brothers' gap rule).

## 5. Recommendation: skeleton, parcels, then fill

**The idea: fix the big structure by hand, vary the small, and let code assemble and check.** This is XCOM 2's plot and parcel idea scaled to Lodestone's 21 x 18 fights and to a map maker that already exists. It also gives the "random but well crafted" Brandon asked for: random choice of a handmade skeleton, random pieces in its sockets, random small terrain, and a validator that throws away anything that fails.

### 5.1 Three layers

**Layer A: plots (the skeleton).** A plot is a flat sketch (the maker's flat mode already exists) with:
- the road line from one edge to another (the spine),
- the river line, if any, with its job marked (flank or crossing),
- rough terrace blocks: high ground here, low ground there,
- deploy zones for the party and the foes (and which end each can use),
- sockets: marked rectangles, each small, medium or large, tagged by what may go there (crossing, high ground, clearing, rim).

A plot is about 6 to 10 flat sketches per region, not hundreds. The same plot can be mirrored, flipped front to back, and have its start sides swapped. That is FFT's "vary by which way you came" for free.

**Layer B: parcels (the set pieces).** Parcels are small maps Brandon builds in the maker and saves as pieces, each with its footprint, the heights along its edges, where the road enters and leaves, and tags. Examples by structure only: a bridge with both landings and approaches, a ford reach, a stair-cut climb, a ramp up a cliff, a flat clearing with a rock outcrop, a ruin clearing, a pool under a fall, a plateau with one ramp and one stair, a ledge between cliff and water. About 15 to 25 per region, each with 2 or 3 variants. Heights are stored relative to the parcel's base so code can lift it to fit.

**Layer C: fill (all code).** Between the sockets, code builds the terrain: terraces from noise but pinned to the plot's blocks and to each parcel's edge heights, a ragged outline (V7, V9), pines, boulders, pillars (V10), the single river path, and stair cut-ins where the road needs them. Then it validates.

### 5.2 What Brandon does by hand and what code does

| Brandon, in the map maker | Code |
| --- | --- |
| Draw 6 to 10 plots per region (the flat sketch, with road, river, blocks, deploy zones, sockets) | Pick a plot for the encounter, mirror and flip it, swap start sides, warp it a little |
| Build 15 to 25 parcels per region and save them as pieces with tags | Choose parcels per socket by size and tag, lift or lower to fit edge heights, rotate, mirror, never repeat the same piece twice in one map |
| Hand-build 2 or 3 whole maps per region for the story or special fights (still the maker, as now) | Use them as fallbacks, and let some of them have swap sockets so they vary too |
| Decide each region's look: its river job, how vertical, how many crossings are allowed | Fill terrain, outline, trees, stones, pillars; carve the road; lay the one bridge or ford; run all the checks |
| Review a contact sheet of generated seeds (greybox, per the 11-01 pipeline) and say "this one is wrong because X" | Turn each "wrong because X" into a new validation rule or a tag on a parcel |

Brandon should not hand-place terrain cells for random maps. He builds the pieces and the skeletons; the generator never has to invent a bridge.

### 5.3 What varies (and what stays fixed)

- **Fixed per plot:** the road's route in broad strokes, the river's job, the number of crossings, where each side can start.
- **Varies:** which plot, mirror, start side, which parcel in each socket, terrace heights within a band (heights offset ±1 level, not changing the steps between levels), the outline's ragged edge, tree and boulder clumps, pillars, decor.
- **Region identity:** a region draws from its own plots and parcels, so players learn what that place's roads are like (XCOM 2: players may spot a building but not the layout).

### 5.4 Foe and party start rules

- Both deploy zones are flat, walkable, at least 3 x 3 free cells, visible to the camera, and inside the map's outline with a clear land route to the other (the 11-01 rule). Start gap follows scale C (an 18 gap, `docs/design/scale-study.md`).
- Neither side starts more than 2 levels above the other.
- A foe may start on high ground only when the high ground has two ways up, so the party has a flank (Battle Brothers' "never a single chokepoint").
- Foe groups start together on one patch, not split across the river.
- Starts are fixed per plot orientation, so luck is about tactics (Battle Brothers).

## 6. Validation checks

Existing checks in `MapQA` (reach, box, stairs, scale, deploy, sight) stay. New and tightened checks, run on every generated map:

| Check | Rule | Status |
| --- | --- | --- |
| Reach | Every walkable cell is reachable by land from both deploy zones, without wading; every foe is reachable | Exists |
| Box score | Outline not a rectangle, heights not flat | Exists |
| Sight | No walkable cell, deploy cell or foe spot hidden by a cliff, tree or prop in front; fighting area share hidden under 5% | Exists, tighten threshold |
| Stairs | No stair to nowhere; no stair that stops short | Exists |
| One crossing per job | At most 1 bridge and 1 ford per river; each at least 8 cells from the other | New |
| Bridge on a road | Every bridge's landings have road within 2 cells on both banks, and the road goes through | New |
| Road reason | Road joins two real ends (edge, camp, ford, stair); never dead-ends at a cliff or in water | New |
| River job | A crossing river has a crossing; a flank river does not separate the two deploy zones by land | New |
| River sanity | Downhill, falls of 2 or more, no pool in the middle of the walking area | Partly exists |
| Route length | Shortest land walk between deploy zones is at most 1.6 times the straight gap, and the longer of the two routes is at most 2 times the shorter (a flank, not a maze) | New |
| Chokepoints | 2 to 4 chokepoints (cells where the route is 1 or 2 wide); none the only route; each with a bypass or a high-ground option | New |
| Climb fairness | Neither start is more than 2 levels above the other; every climb of 2+ levels has stairs, a ramp or a bypass within 8 cells | New |
| Nook rule | No dead-end pocket of 1 to 3 cells next to a wall where a unit can be stuck (the Into the Breach nook, extended to cliffs) | New |
| Parcel use | No parcel appears twice in one map; no parcel sits where its tags say it cannot (a bridge not over land) | New |
| Repetition | Map fingerprint (plot id, parcel ids, orientation) differs from the last 3 fights in that region | New |
| Fight smoke test | `CombatSim` runs 5 AI fights: contact within the usual rounds, no stalls (the scale study already measures start gap, rounds to contact and stalls) | New, wire existing sim |
| Fallback | If 8 seeds in a row fail, use a hand-built fallback map for that region and log the failures | New |

Everything above is a pure function on a `CombatGrid` plus the plot data, so tests can run headless, like the existing QA. Checks produce the same `{level, summary, cells, problems}` result as `MapQA`, so the maker's QA panel can paint them.

## 7. Plan, in steps

1. **Stop the bleeding in the current generator (small, code only).** Remove `CROSS_EXTRA` and the "nearest the middle" crossings. Lay the road first (A* with water as a high cost), then lay the single bridge or ford where the road meets the river. Add a river job (flank or crossing) so a flank river never splits the map. Add the new checks for crossing count, bridge on a road, route length and chokepoints, and run 200 seeds as a gallery. This alone should end the three-bridges problem.
2. **Write the plot format.** One JSON per plot: road polyline, river polyline and job, terrace blocks, deploy zones, sockets with sizes and tags. Reuse the map maker's flat view for drawing; add a "plot" mode that saves these instead of a map. Write the validator that checks a plot itself (road reaches both ends, sockets do not overlap).
3. **Write the parcel format and a "save as piece" tool** in the map maker: select a rectangle, name it, tag it, and the tool stores its heights, terrain, decks and props relative to its base, plus its edge heights and road entries. Placement reuses the maker's ghost (green fits, red does not).
4. **Build the assembler** (`MapParcels`, built from `MapOps` calls like the rest of `MapGen`, so the result is an ordinary map): pick plot, orient, place parcels, pin terraces to the edges, run fill, dress, validate, retry up to 8 seeds, then fall back.
5. **Brandon builds the first batch:** 3 plots and about 8 parcels for one region (suggest forest roads, the first connected tile). Code renders a contact sheet of 12 seeds in the greybox look, per the 11-01 pipeline.
6. **Review loop.** Brandon marks each seed good or "wrong because X". Each X becomes a validator or a parcel tag. Repeat until 10 in a row are acceptable. Then extend to the other regions.
7. **Hand-built set-piece fights** (story, bosses) stay whole maps from the maker, optionally with a swap socket or two. Keep the current `valley` as a last-resort fallback until plots cover every region, then retire it.

## 8. Questions for Brandon

1. Is a river that never separates the two starts (a flank river) fine for most road fights, with the crossing-river set piece for a few special encounters?
2. Which region should get the first plots and parcels?
3. Should the generator ever lay a ford on its own, or only where a plot's socket allows one?
4. Is the contact-sheet review (12 greybox seeds, mark each good or wrong) the right way for you to teach it, instead of tuning numbers?

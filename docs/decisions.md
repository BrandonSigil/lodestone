# Decisions

Every design call goes here, newest at the bottom of its section.

- `[USER]` = Brandon decided it. It wins, always.
- `[AI]` = Claude proposed it. It stays a proposal until Brandon retags it `[USER]` or strikes it.
- To override a line, add a new `[USER]` line below it that says what changed. Don't delete history.

## Project
- [USER] 2026-10-25 Tactics RPG (Fire Emblem / FFT grid combat) fused with Oregon Trail travel survival. High fantasy.
- [USER] 2026-10-25 Claude never writes story or copy. Placeholders are caveman speak.
- [USER] 2026-10-25 Brandon draws all final art. No AI-generated art ships.
- [USER] 2026-10-25 Engine is Godot 4, GDScript, 2D hand-drawn look in the spirit of The Banner Saga.
- [USER] 2026-10-25 Earth to Alien: visuals grow stranger the farther past the Wall the party travels.
- [USER] 2026-10-25 The UI is framed by a border that shows party and items.
- [AI] 2026-10-25 Compatibility (OpenGL) renderer, 1280x720 base, canvas_items stretch. Lightest option for 2D and runs on old laptops.

## Premise
- [USER] 2026-10-25 Original framing (project brief): a scout brings the Lodestone home from dead elves found past the Wall, the King sends you into their lands, and the lord can't give a blank check but backs you more if you prove the trip worthwhile. SUPERSEDED 2026-10-27 by the line below; kept on file.
- [USER] 2026-10-27 New premise: the hero finds everyone they knew gone, the village empty and decayed as if about 50 years passed. Just the hero and their corgi. Out in the world they meet a few predetermined survivors; each can be recruited back to the village as a settler to rebuild it, or as an adventuring party member. Old plans stay on file; new work follows this.
- [AI] 2026-10-27 Systems for the new premise are proposed in `docs/design/empty-village.md`: corgi companion (free slot, never lost, trail passives, BARK in combat), survivors at fixed spots with a SETTLE / JOIN choice swappable between runs, village rebuilding with salvage and settler-run buildings replacing the lord's gold, a GO HOME recall that banks the pack, and a build order.
- [USER] 2026-10-27 Settlers are simply NPCs the player interacts with between runs. No switching between settler and party member (replaces the "swappable between runs" proposal above).
- [USER] 2026-10-27 The corgi fights on the grid and has simple foraging and sniffing skills; its ears perk up when danger may be nearby, or it may just be a squirrel.
- [USER] 2026-10-27 Keep gold and the shop, but they only arrive once the player finds a blacksmith, or a traveling merchant decides to settle in the town (replaces the "drop gold" proposal).
- [USER] 2026-10-27 The Lodestone stays. Early in the story the hero unearths it, and on their first death they realize its power.
- [USER] 2026-10-27 The Wall stays. The elves past it may have survived, or an elvish prophecy foretold this event, which is why the hero pushes all the way over.
- [AI] 2026-10-27 Draft 2 of `docs/design/empty-village.md` follows those answers: each survivor is fixed in data as a settler (village NPC with a service and building) or a companion (party roster); corgi PERK UP warns before an event with a 15% false alarm, GO AROUND skips it for half a day's distance; map UI hidden until the Lodestone is found and no lethal fights before it; gold found early is banked in meta for the first merchant visit; route end at league 300 is the elves.
- [USER] 2026-10-27 The hero starts as a "nobody". They leave their house at the start; a couple of weapons sit at the blacksmith's, and a hidden item waits in a house for players patient enough to dig around. The class develops as you go, like Fire Emblem's job system: players and NPCs have one or two choices for how to develop.
- [AI] 2026-10-27 Draft 3 of `docs/design/empty-village.md` (sections 7 and 8): the village is the first explore map; the smithy rack offers one weapon per type (sword, bow, book), swappable between runs; the hidden item has no marker and shows when adjacent or sniffed by the corgi. Jobs: nobody, then at level 5 fighter / archer / mage (offered by weapons used), then at level 10 one of two branches each, using the existing jobs (knight, hunter, wizard) as branches. FE-style XP and growth rates; levels stay through a recall; characters keep off-class skills, perks, deficiency and one skill per earlier job. Companions have their own forks; settlers pick one of two building specialties instead. No re-classing for now.
- [USER] 2026-10-27 Character levels persist through a recall. The smithy holds 3 weapons: sword, daggers and bow, leading to knight, rogue and archer.
- [AI] 2026-10-27 Draft 3.1: hero tier 1 jobs are knight, rogue, archer (replacing fighter / archer / mage). Tier 2 roles: knight to guardian or vanguard, rogue to assassin or thief, archer to hunter or sharpshooter. Magic stays with companions.
- [USER] 2026-10-27 The hero picks one smithy weapon; the others stay there but can't be taken (a respec maybe later). There is a magic path, found by exploring town: enter a home and spot a book on a shelf, a hidden alternate route.
- [AI] 2026-10-27 Draft 3.2: the hidden book is the village's hidden item, a second weapon that adds mage to the level 5 choice; mage branches to wizard or healer. It sits on a shelf in an ordinary home off the town square, out of sight from the door. This replaces "magic stays with companions" above.

## Roster and characters
- [USER] 2026-10-25 Set roster of characters that unlock through play. Main character is a default for now; customization later.
- [USER] 2026-10-25 Each character has a class, 1 to 3 off-class skills, perks and one deficiency.
- [USER] 2026-10-25 Stardrop Skygazer: moonshadow elf, moon magic, wayfinds by the stars, frail and spooks easily.
- [USER] 2026-10-25 Wizard: his books come too and fill group inventory slots.
- [USER] 2026-10-25 Hunter: ranged in combat, good at hunting and trapping food on the trail.
- [USER] 2026-10-25 Skeleton Archer needs no food, warmth or shelter but harshes the vibe. Bushberry is a flammable bush that makes 1 ration a day. Lewith & Flark take 2 slots but act as 1.
- [AI] 2026-10-25 Party has 4 slots. Lewith & Flark fill 2 of them.
- [AI] 2026-10-25 Unlock conditions (graybox): Wizard after the first recall, Lewith & Flark after the second, Bushberry from its trail event, Skeleton Archer on reaching the Wall.
- [AI] 2026-10-27 Under the new premise, unlocks become "met_<id>" flags set when a survivor is won over, replacing the run-count unlocks above. The roster is the survivor list; who survives is Brandon's call.
- [AI] 2026-10-25 Stardrop's "skittish": at the start of each player phase, if an enemy is within 3 tiles, he rolls d20 + Nerve vs 11. On a fail he is SPOOKED that phase: -3 to hit and -2 move.
- [AI] 2026-10-25 Wizard's books take 3 of the 12 inventory slots.
- [AI] 2026-10-25 Hunter's deficiency (placeholder, from the "afraid of rodents" example): 20% of hunts he leads fail outright.
- [AI] 2026-10-25 Skeleton Archer's "gloomy": -2 morale per day. Bushberry's "flammable" is tagged in data but does nothing until fire exists.

## Checks (dice)
- [USER] 2026-10-25 Characters have DnD-style success rates for things like persuading robbers or sneaking up on them.
- [AI] 2026-10-25 One roll for everything: d20 + bonus vs a target number. Natural 20 always succeeds, natural 1 always fails. The UI shows the full roll, e.g. "d20 14 +3 = 17 vs 13".
- [AI] 2026-10-25 Party checks use the best living member's bonus (class skill + off-class skill), plus morale: -2 below 30 morale, +1 above 75.

## Combat
- [USER] 2026-10-25 Grid tactics with terrain, higher ground and positioning, melee focused.
- [AI] 2026-10-25 Fire Emblem phases: the player moves all units, then the enemy moves all units.
- [AI] 2026-10-25 Attacks are d20 + attack vs target defense. Each height level above the target gives +2 to hit and +1 damage, counting up to 2 levels (penalties mirror it below).
- [AI] 2026-10-25 Flanking: +2 to hit if another ally is already adjacent to the target.
- [AI] 2026-10-25 Terrain: grass and road cost 1 move, forest 2 (+2 defense cover), shallow water 3 (-2 defense), rock is impassable. Magic ignores cover.
- [AI] 2026-10-25 A unit can climb or drop up to its Jump stat per step. Melee can't reach across more than 2 height levels. Ranged attacks gain +1 max range per level of high ground.
- [AI] 2026-10-25 Downed units return with 1 HP after a won fight. If the whole party is downed, the Lodestone recalls everyone.
- [AI] 2026-10-25 Right-click undoes a move before the unit acts.
- [USER] 2026-10-26 Make combat full fledged: a test environment to edit maps, reload fights, balance teams and scale enemy difficulty, plus Fire Emblem / XCOM style menus (move, attack, spell, item, etc.). Graybox visuals. Research in `docs/research/tactical-combat.md`.
- [AI] 2026-10-26 Each piece gets one move and one action per turn, in either order. Actions: basic hit, class skills, items, Guard (+3 defense until its next turn), Wait.
- [AI] 2026-10-26 Before committing, a forecast shows hit chance, damage, HP before and after, every modifier, and the counterattack. D toggles a danger zone of every tile the enemy can hit next phase.
- [AI] 2026-10-26 Counterattacks: a unit hit by a single-target attack swings back once if its basic attack reaches. Area skills draw no counter.
- [AI] 2026-10-26 Pushes: blocked = 2 bump damage; shoved off a ledge = 2 damage per level beyond the first.
- [AI] 2026-10-26 Skills use cooldowns (no mana bar). One or two per class, listed in `game/data/abilities.csv`. Area skills hit friends too.
- [AI] 2026-10-26 Fight items spend the run's real supplies: GOOP (1 medicine, heal 5, adjacent) and SNACK (3 food, heal 2, self).
- [AI] 2026-10-26 Party luck: +1 to hit per consecutive party miss, up to +3, reset on a hit, visible in the forecast. Enemies get none.
- [AI] 2026-10-26 Difficulty is four separate dials per side (HP %, to-hit, defense, damage, move) plus extra enemies. Presets: EASY 80% HP -1 hit -1 def; NORMAL base; HARD 115% HP +1 hit +1 enemy; BRUTAL 130% HP +2 hit +1 def +1 dmg +2 enemies.
- [USER] 2026-10-26 More terrain and height in combat, in a nice isometric view (references: stacked stone terraces, stairs, waterfalls, ruins).
- [AI] 2026-10-26 Heights 0 to 8 for authored maps (generator 0 to 4). New terrain: stone floor, stairs (+2 climb over Jump), ruin walls (impassable, block sight 2 levels).
- [AI] 2026-10-26 Ranged attacks and spells need line of sight. Cliffs, ruins, boulders and trees block it. High-ground range bonus capped at +3.
- ~~[AI] 2026-10-26 The camera turns in quarter steps (Q). Saved sandbox maps keep their opening angle.~~ Superseded 2026-10-28 by the line below.
- [USER] 2026-10-28 No map rotation for players. Every map is seen from one approved angle (its `view`), like Hades, and the maps, props and UI are made so the player can always navigate and interact from that view. Turning stays an editing aid only (map maker, the sandbox's map editing). (Brandon)
- [AI] 2026-10-26 Balance pass from the AI-vs-AI sim: bandit and wolf attack 3 to 4, bandit bow HP 7 to 8 and damage 2 to 3, GOOD SHOT +1 damage (was +2), MOON BOOM range 2-3 (was 2-4). Trail encounters stay at 3 enemies; their cost comes from HP carrying over.
- [USER] 2026-10-26 Give different characters unique combat modifications, and let spell casters pick 1 or 2 spells to use.
- [AI] 2026-10-26 One combat trait per roster character: Lead shield_wall (adjacent allies +2 DEF), Stardrop starlit (spells +1 hit/+1 dmg from height 2+), Hunter steady_aim (+2 hit if not moved), Wizard scholar (spells +1 dmg, heals +1), Bushberry deep_roots (can't be pushed, regrows 1 HP a phase), Skeleton bones (-2 dmg from non-magic ranged), Lewith & Flark double_strike (basic hit twice at -1 dmg). Wolves get pack (+1 dmg on a flanked target). Bushberry's flammable now means +2 damage from fire.
- [AI] 2026-10-26 Casters have a spell pool and 2 slots; a slot may stay empty. Moon mage pool: MOON BOOM, MOON SKIN, MOON NAP (sleep), MOON WAVE (push 2), STAR POINT (+2 hit). Wizard pool: FIRE BOOM, FIX, FIRE ZAP, COLD STUCK. Defaults are the old fixed spells, so trail fights play as before. Picks happen in the sandbox for now; a village picker comes later.
- [AI] 2026-10-26 New status NAP (sleep): skips the owner's next phase, no counterattacks, any damage wakes it. New skill kind "hex": rolls to hit, adds a status, no damage.

## Trail and survival
- [USER] 2026-10-25 Balance combat, unearthing the map, survival, mental and physical health.
- [USER] 2026-10-25 If the party dies, the Lodestone takes everyone back to the village. Possessions are lost; the party can be re-picked.
- [AI] 2026-10-25 Each action costs one day: travel steady (10 leagues), travel hard (15, -5 morale, -1 HP each), rest, hunt, forage, or heal with medicine.
- [AI] 2026-10-25 Each member eats their food_per_day every day. No food means -2 HP each and -10 morale.
- [AI] 2026-10-25 12 inventory slots. Food stacks 10 per slot, medicine 5 per slot. Overflow is lost.
- [AI] 2026-10-25 Getting lost: each travel day rolls best Wayfind vs 8 + 8 x strangeness. A fail covers half the distance.
- [AI] 2026-10-25 35% chance of an event per travel day, drawn by weight from `game/data/events.csv` and filtered by strangeness.
- [AI] 2026-10-25 Route is 300 leagues. The Wall sits at 150. Strangeness = distance / 300.
- [AI] 2026-10-25 Meta progression: the village grants +5 starting food per 50 leagues of best distance (the "prove it's worthwhile" lord). The Lodestone remembers event marks from every run.
- [AI] 2026-10-25 Deferred: water, warmth and shelter needs; minigames (hunt, fish, herbs are dice rolls for now).

## Visual language
- [USER] 2026-10-26 AI builds much of the visual work; Brandon directs and shapes it. Ideation happens in the "Shape the Lodestone visual language" project thread, around a published style lab page (source in `docs/style-lab/index.html`).
- [USER] 2026-10-26 References: flat shape-language landscapes, folk-art borders and quilt frames, riso grain, saturated limited palettes (7 images in the thread), plus the workflow of github.com/sevenevesai/riso-windowseat.
- [USER] 2026-10-26 Explore tucking most of the UI into a decorative bottom frame, like the bordered reference images.
- [AI] 2026-10-26 This relaxes "Brandon draws all final art": code-drawn visuals (shapes, shaders, palettes, stamps) may ship once Brandon approves the rule they follow. Image-generation models are still never used. The CLAUDE.md art rule needs Brandon's edit to match.
- [AI] 2026-10-26 Style rules R1 to R10 from style lab draft 1 (see `docs/style-bible.md`): flat fields, gradients only in skies, soft stacked forms, marks instead of rendering, no black, fixed grain, tiny pieces in a huge world, one accent per region, folk borders hold the UI, values invert past the Wall.
- [AI] 2026-10-26 Five region palettes of nine roles each (Home 0, Snow pass 0.25, The Wall 0.5, Past the Wall 0.75, Deep lands 1.0), blended by strangeness. Piece colors are fixed in every region.
- [AI] 2026-10-26 Every visual is a pure function of seed and strangeness, so any screen can be reproduced and screenshot-checked (borrowed from riso-windowseat).
- [AI] 2026-10-26 Three bottom-frame candidates: A embroidered band, B quilt row, C foreground sill. Brandon picks one or a mix.
- [USER] 2026-10-26 Adopt the style lab draft 1 look (rules R1 to R10, region palettes, riso grain) for the starting village hub and the world map. The bottom frame pick (A, B or C) is still open.

## World map
- [USER] 2026-10-26 A general world map in the riso look that the player slowly unearths: only the first village and a few miles around it are known at the start. For now we see the whole map; fog of war comes later.
- [AI] 2026-10-26 The map is one fixed 1920x1080 sheet with a folk stamp border. Home sits bottom-left, the route winds east through snow, the Wall runs north to south through the middle, and the deep lands fill the east edge.
- [AI] 2026-10-26 Regions are flat fills with wobbly warped-Voronoi borders, colored by the region palette at each region's strangeness. Regions never cross the Wall.
- [AI] 2026-10-26 The trail's 300 leagues map onto the drawn route; the Wall gate is league 150. The walked part of the route prints dark, the rest pale.
- [AI] 2026-10-26 Discovery: the village plus about 170 map units around it start known; each run reveals 95 units either side of the route it walked. Stored as circles in meta so it survives a recall.

## Village hub
- [USER] 2026-10-26 The starting village uses the style lab look. It is where the player picks the team, buys supplies, arranges a Tetris-like grid inventory and talks to the mayor for lore and side quests.
- [AI] 2026-10-26 The village uses frame A (embroidered band) from the style lab for now: party left, Lodestone medallion center, pack right. Swapping to B or C only touches `village_frame.gd`.
- [AI] 2026-10-26 The pack is a 4 x 3 grid (12 cells, matching the trail's 12 slots). Items are shapes that can be turned. The Wizard's books are a 3-cell L shape that can't be sold.
- [AI] 2026-10-26 The lord's backing is gold, not free food: 30 starting gold plus 5 per 50 leagues of best distance. This replaces the "+5 starting food per 50 leagues" line. Leftover gold goes on the trip.
- [AI] 2026-10-26 Shop (graybox prices): food bit 1 cell 5 food 2G, food sack 2 cells 12 food 4G, dry meat T 4 cells 30 food 7G, food box 2x2 36 food 9G, goop 1 cell 2 medicine 4G, herb bag L 3 cells 8 medicine 9G. Selling in town refunds the full price.
- [AI] 2026-10-26 The mayor offers side jobs from `data/quests.csv`. Taking one is saved across recalls. Completing them is not built yet.
- [AI] 2026-10-27 Under the new premise the village is empty: the mayor, the lord's gold bonus and the gold shop are superseded (kept in code until replaced). Proposed: build board instead of the mayor, storehouse instead of the shop, side jobs become survivor asks. See `docs/design/empty-village.md`.
- [AI] 2026-10-26 The Lodestone medallion and the MAP tab open the world map scene (owned by the world map work). Head out still goes straight to the trail.
- [USER] 2026-10-26 Brandon doesn't like how the game looks yet and wants better drawings.
- [AI] 2026-10-26 Style lab draft 2 names six gaps against the references (F1 machine-perfect edges, F2 no single light, F3 one grain on every surface, F4 everything on one horizon, F5 pieces without charm, F6 UI louder than the picture) and shows a code-drawn village fixing them. Next step depends on Brandon's pick: richer code only, a hybrid where he draws a small kit, or hand-painted scene plates.
- [USER] 2026-10-26 Code-only art is not the route. Use the AI art pipeline in `docs/art-pipeline.md`: a style model trained only on Brandon's own drawings, Krita AI Diffusion run locally, Brandon paints over, code finishes. This replaces "Brandon draws all final art. No AI-generated art ships." Never train on other artists' work.

## Battle map art
- [USER] 2026-10-26 Battle maps take their look from Brandon's isometric reference: mossy stone cliff blocks, temple stair, waterfalls, pines, a floating island on cream paper.
- [AI] 2026-10-26 Battle map rules B1 to B32 in `docs/art/battle-maps.md`: 2:1 dimetric, art at 2x (tile 128 x 64, 32 px per level), sun upper left, top / lit / shade values 100 / 75 / 55, ink outline #373335, reference structure with Style Lab surface (riso grain, no black, marks not rendering).
- [AI] 2026-10-26 Tiles may be generated only on top of the battle map templates (line art and depth as control, clipped to the masks, hand-fixed). Never a freehand tileset. Replaces "never generate tile grids" in `docs/art-pipeline.md`. The reference image is a mood reference only, never training data.
- [USER] 2026-10-26 Build the battle map terrain and objects from the art guide and put them in the game (Brandon). First pass: Picsart-generated textures and props, color-matched to the guide palette, drawn by `BattleArt`.
- [USER] 2026-10-27 Battle map topography is built in Godot (the sandbox map editor) and tile art is applied there. Krita makes tile textures and props; whole-map "map plates" in the game are shelved (Brandon).
- [USER] 2026-10-27 Each look starts with a painted proof-of-concept map: a sandbox map with varied heights and key items for the terrain (campfire, fallen tree, dungeon ruins), painted in Krita on its template to check the art holds together. That painting is then broken out into the tile set's textures and props (Brandon).
- [USER] 2026-10-27 Battle map backdrop is a painted ring, not an island on paper: the floor sits in a chamber that continues past its edge (columns, statues, colonnades, arches) and fades into dark teal-violet; the floor's outer cells dissolve into the dark. Drawn in the simple handdrawn flat style (`docs/art/references/style-flat-forest.png`), not the detailed painted look. Supersedes the island-on-cream-paper staging in section 1 of `docs/art/battle-maps.md` for now. Concept: `art/picsart/out/hades-concepts/ring_chamber.png` (look only, not art).
- [AI] 2026-10-27 Still open from `docs/research/hades-iso-maps.md`: black vs hue-shifted shade (R5 holds until Brandon answers), wall cutaway (dithered vs soft fade), and how the ring turns with the camera (four plates, a symmetric ring, or a low ring that never shows its face).
- [AI] 2026-10-27 Tile sets per region: subfolders of `game/art/source/battle/` (snow, dungeon, forest...) with the base file names, each missing file falling back to the base art; a map picks its set.
- [USER] 2026-10-27 Brandon is happy to move forward with the backdrop approach: every environment gets a backdrop plate (the floor sits in a world that continues past its edge), with walls and rim built from modules, in the simple handdrawn style. Applies to battle and explore maps. Details and the open questions are in `docs/art/environments.md`; the asset list for a full explore test is in `docs/art/explore-test-assets.md`.
- [USER] 2026-10-27 Look for the backdrops: the snow example (`docs/art/references/surround-snow-example.png`) is the pick. Forest-ruins and interior plates keep its simple painted look; the ruins plate is a forest courtyard, and the interior is a ground-level wood room with a dark void past the floor, not a raised deck.
- [AI] 2026-10-27 Backdrop plates shipped for snow, ruins and village_in: one 2400 x 1600 `backdrop.png` per set in `game/art/source/battle/<set>/`, drawn centred on the floor's footprint at 1.35 times its width (`PLATE_SCALE`). The plate does not turn with the camera; Q4 (turns) is still open until it is checked at each quarter turn.
- [AI] 2026-10-27 The dark fade follows the floor's real outline: empty cells within 4 steps of the floor get a dark tint that falls off outward (`FADE_RINGS`, `FADE_DARK`). Sets without a plate draw as before (the paper card in fights and the tester, nothing in exploration).
- [AI] 2026-10-27 Rim drips are animated in code: every rim face drips (moss on graybox, the set's rock colour on art), each drip grows, hangs and drops a bead on a staggered loop. The flat art has no drips of its own.
- [AI] 2026-10-27 Faint cobble hairlines in the engine: about one top in three gets one short line along one edge (`COBBLE_ALPHA`), on every top except water and stairs. Drawn over the tile art, not baked into it.
- [AI] 2026-10-27 Interior plate furniture (barrel, cabinet, crate, bench, jug) is baked into `village_in/backdrop.png` and can double up with placed props. Kept for now, per Brandon's sign-off; move it to the walls if it reads wrong in play.
- [USER] 2026-10-27 Town exterior uses a sky and horizon: bigger cliffs and a mountain range from Brandon's town sample, drawn in our flat look (not that sample's style or line art). This overrides the no-sky rule for the village set only.
- [AI] 2026-10-27 Scenery is built from the map, not a square plate: a skyline strip sits behind the whole board, and empty cells two steps out from the floor (`SCENERY_RINGS`) get trees, rocks and bushes from the existing prop art. Maps can be any outline; nothing is tied to a rectangle. Prototype only: the ring 2 edge is still a hard line and the lowland still lacks a cliff drop. (Update: the cliff drop and soft ring edge are in; see `docs/art/environments.md` section 8.)
- [AI] 2026-10-27 Irregular outlines: `IslandShape.carve` (`game/scripts/combat/island_shape.gd`) cuts a seeded blob out of a generated map, keeps the middle row and the deploy columns, and keeps one connected piece. Now the default for `CombatGrid.generate` (so trail, combat and sandbox maps all get irregular outlines); `outline = false` still gives a plain rectangle. Balance on generated maps (2,000 AI fights each, `tools/generated_balance.gd`): party wins 77% plain, 79% irregular; rounds 4.4 to 4.2, downed per fight 1.5 to 1.2, no stalls. The shift is about the size of the noise, so no preset change. Tuning knobs are the edge radius and noise in `IslandShape.ground`.
- [AI] 2026-10-27 Backdrop plates are one picture per art set, drawn behind the board. They are not per-cell map plates, so the shelved map plates stay shelved. Brandon should confirm this reading (`docs/art/environments.md` Q6).
- [AI] 2026-10-27 Neutral wall and rim modules recoloured per set with the palette map, so three art sets share one set of shapes (`docs/art/environments.md` S1).
- [USER] 2026-10-27 Skip real character art for now. One placeholder figure in code (`game/scripts/combat/placeholder_figure.gd`) stands in for every unit with no sprite: party members are coloured green, blue, purple and so on; all enemies are red and told apart by a glyph over the head and by their weapon. It has every anim (idle, walk, attack, cast, hurt, down) and the board's timing runs on it unchanged.
- [AI] 2026-10-27 Placeholder down pose: the board returns a unit to idle when a non-looping anim ends, so a fallen placeholder stands back up. Fix before a dead unit is drawn on the board for long.
- [USER] 2026-10-27 Use the API pipeline, not code, for the stand-in character: one general dummy (`game/art/source/characters/dummy/`, prompt `art/prompts/sheet-dummy-anim.txt`) matches the house style, is drawn neutral and is tinted by team (party green, blue, purple; enemies red), with enemy glyphs kept. It replaces the code-drawn figure as the default; the code figure stays as the fallback. Lead keeps its own art.
- [AI] 2026-10-27 The general dummy has five drawn facings (se, ne, s, e, n); sw, w and nw mirror se, e and ne. Its cut scales differ slightly by facing (0.65 to 0.71 measured) while `dummy.json` keeps one shared scale of 0.5, so check the roaming facings in game. Weapon variants per unit are still to do.

## Character sprites
- [USER] 2026-10-27 Brandon's character sheet (chibi hero, five iso views on tile footprints, idle / walk / attack / cast / hurt, sword and cloak parts, swatches) is the template for all characters. Characters need front, back, left and right views too so the party can move freely on maps outside combat.
- [AI] 2026-10-27 Sprite spec C1 to C29 in `docs/art/characters.md`: battle-map camera, frame 192n square with feet at (96n, 160n) for an n x n footprint; people 3 levels tall; size classes small 1x1, hero 1x1, large 2x2, boss 3x3.
- [AI] 2026-10-27 Eight facings by screen direction. Draw S, SE, E, NE, N; SW, W, NW are mirrors unless a piece is lopsided. Combat only needs SE and NE (plus mirrors). Pieces are lit from above, not from the side, so mirrors stay correct.
- [AI] 2026-10-27 Idle and walk are cut-out animation from paper-doll parts in every facing. Attack, cast, hurt and down get drawn key frames in SE and NE only; key poses may be generated with Krita AI (pose and reference control) and hand-finished. This loosens "never generate animation frames" in `docs/art-pipeline.md` to key poses only; in-betweens stay hand-made or code-made.
- [AI] 2026-10-27 Paint pieces with ten key ramps taken from Brandon's swatches (`art/templates/characters/lodestone-characters.gpl`); the engine recolours by swapping ramps.
- [AI] 2026-10-27 First character sprites in battle: the lead's SE and NE sheets were generated from the reference sheet (gpt-image-2.5-sunburst) and cut into C28 strips; idle, walk, attack, cast and hurt play from those, not from a paper doll yet. Placeholder art until Brandon draws or approves it.
- [AI] 2026-10-27 The lead now has S, E and N sheets too (same prompts and model, one facing per sheet, 57 cents for six sheets), so roaming shows all eight facings. The cutter pins idle, walk, ready and advance frames on the body's centre instead of the feet; feet pinning made the walk lurch about 22 art px sideways each step.
- [AI] 2026-10-27 Character sheets generate at 1K by default (`tools/art/char_sheet.py`): 5.5 cents against 9.5 at 2K, and side by side on the lead's S facing the cut sprites look the same at game size (1K is only a little softer blown up 3x). Asked for by Brandon; tile kits and maps stay at 2K.

## Map look and map maker
- [USER] 2026-10-28 All maps, battle and exploration, take the setup of Brandon's mountain valley reference: a sky and snow mountain backdrop, the map sitting in a dark pine forest, big trees overlapping the bottom of the map, strong verticality (high and low ground, tall cliffs, choke points, stairs, waterfalls), an irregular outline instead of a rectangle, and grass hanging over every cliff edge. Build an in-game map maker that makes maps like this on the fly (Brandon).
- [AI] 2026-10-28 Looks stage a map (`data/looks.csv`, `MapLook`): `valley` (sky, two mountain ranges, forest, outer cliffs down to a floor 5 to 7 levels under height 0, rings of skirt trees around the outline), `island` (the paper card with hanging rock) or `plain` (interiors). A map picks one with `grid.look`, else the row named like its tile set, else `forest`. Every outdoor set gets a valley row; `village_in` is plain. Strangeness drifts the colours toward `crystal`. This replaces the paper card behind fights (2026-10-27 line under Exploration maps) unless a map picks `island`. Design: `docs/design/map-look.md`.
- [AI] 2026-10-28 Grass lips are cut in code from the cell's own top texture and hung over every visible cliff edge, ending in drips fixed to world position; depth per terrain in the `lip` column of `battle_art*.csv` (grass 0.75 levels, road 0.45, rock 0.35, paved 0). Moss is no longer painted into side strips (B8, B15), so lips match every tile set and zone.
- [AI] 2026-10-28 Map maker (F8): sculpt, paint, rivers, stairs and flights, props, cut and fill the outline, zones, tile set and look, a seeded valley generator, recipe templates, undo, save to `data/maps` or `data/explore`, and a play test straight into the sandbox or the explore scene. How-to: `docs/systems/map-maker.md`.
- [AI] 2026-10-28 Authoring rules V1 to V8 (`docs/design/map-look.md` section 7): terraces two or three levels apart, high ground at the back, every terrace reachable, two to four choke points, water falls at every step, an irregular outline.
- [AI] 2026-10-28 Hand-laid maps can be written as code recipes (`MapRecipes`). `highland` (26 x 26) is the reference layout, saved as `data/maps/highland.json`; the maker opens it first.
- [AI] 2026-10-28 New tile set `alpine` with no art of its own: forest tops, masonry cliffs and the snow set's pines, borrowed through `data/battle_art_alpine.csv` (`set/stem` borrows another set's art, `base/stem` the base art). The `ruins` look uses base pines in its skirt because the ruins set's pine file is a broken column.
- [AI] 2026-10-28 The board draws through cached depth slabs (ground and props redraw only near a change) and the backdrop bands are built once, which took `highland` from 340 to 87 ms a frame on the cloud's software renderer. Draw code paints on `_ci`, never `self`.
- [AI] 2026-10-28 Map maker grows into a full editor (research: `docs/research/map-editors.md`): icon tool rail, an options bar for the picked tool, a right dock with Assets (search, recent, collapsible drawers and groups from `data/catalog.csv`; art no row names shows up under Unsorted), Inspector and Map tabs. Drag a tile onto the map or click it and stamp; a green or red ghost shows the footprint first.
- [AI] 2026-10-28 Prop angles: a prop may be painted from up to four angles, `<sprite>_r1` to `_r3` next to its file. R turns to the next painted angle (a single-angle prop mirrors instead); M mirrors; an odd turn swaps the footprint. Saved as `face` and `flip` on the prop.
- [AI] 2026-10-28 Interactables (doors, chests, ways out, racks, hidden finds, shrines, rubble) and the party start are placed on explore maps only, each with a unique id (`door_01`) and a free "note for Claude". Brandon names the map and the id when asking for behaviour ("door_01 on goblin_cave_01: barred from the other side, a strong character can smash it"); Claude adds the event row.
- [AI] 2026-10-28 Placeholder blobs: a named block of any footprint (1x1 to 3x3 in the catalog, resizable), coloured by its name, sprite `ph_<name>`. When `art/source/battle/ph_<name>.png` exists it draws instead, with no other change. `python3 tools/map_notes.py` lists every blob, id and note across the maps.
- [AI] 2026-10-28 Ground transitions: where higher-ranked ground meets lower at the same height (grass < forest < road < stone), or two tile sets meet, the neighbour's own texture reaches a ragged third of a cell in and fades. A stand-in until painted transition tiles exist; the list of tiles needed is `docs/art/transitions.md`.
- [AI] 2026-10-28 Open for Brandon: code backdrop bands or painted strips per look; keep the gentle backdrop parallax or lock it (the environments proposal E4 says none); zoom fights in on big maps.

## Exploration maps
- [USER] 2026-10-27 Big isometric maps the party walks freely, with fog of war past the party's eyesight. Events stop the walk: enemies that spot you start a fight right there on the map; things like a locked door show an interact icon and open a text box whose options depend on the party (Brandon). His multi-level reference is for layout only, not style.
- [USER] 2026-10-27 Only the main character (the party leader) walks the map. When a fight starts the game goes turn based and you place the others around the leader: a fast character may start further out, a big clunky knight right next to the leader (Brandon).
- [AI] 2026-10-27 Maps are `game/data/explore/<name>.json`: the battle grid format plus start, enemy groups and things. Doors and rubble are ruin cells until opened. First map `crypt` (34 x 30) is built by `tools/explore/build_crypt.py`.
- [AI] 2026-10-27 Sight: the leader sees 7 cells with the combat line-of-sight rule; seen cells stay drawn dim. Enemy groups see 4 (per group in the map). You see them first: walk stops, choose FIGHT / SNEAK HIT / TALK or CALM / BACK OFF. They see you first: ambush, the enemy moves first and everyone deploys next to the leader. Groups within 3 cells of the fight join it.
- [AI] 2026-10-27 Deploy ring = move - 3 steps from the leader (at least 1); +1 on a sneak attack; 1 when ambushed. Knight, mage: 1. Hunter: 2.
- [AI] 2026-10-27 Interaction options come from `data/explore_events.csv`: each option can need a skill, class or character to show up, and rolls the party's best d20 check like trail events. A sneak attack puts the group to sleep for its first phase. A noisy failure (BASH, a bad lock pick) draws the nearest group within 12 cells into an ambush.
- [AI] 2026-10-27 Battle maps can be any island shape: VOID cells ('.' in map files) are no ground. The rim hangs stacked rock columns below the base in each cell's cliff colour, a few loose stones float under it, and water on the rim pours off and fades to mist. Fights and the tester draw a soft paper card behind the island.
- [AI] 2026-10-27 One map can mix tile sets: each cell may carry a zone (a tile set name, saved as letters with a zone_key), so a fight can run from forest into castle ruins or from snow into marsh. Tester: HOLE and ZONE brushes. Four example maps in data/maps/blend_*.json from tools/maps/build_blend_maps.py.
- [AI] 2026-10-27 In a fight, pieces with art stand ready with their weapon drawn (ready and advance anims); outside a fight they relax. Props in front of a piece fade, and a hidden party piece shows as a tinted see-through copy over everything.
- [AI] 2026-10-27 The flat forest set is the base battle art; the old painted base tiles are gone.
- [AI] 2026-10-27 Starting village prototype: the run starts inside the hero's cottage (`home`); the village outside is one 40 x 38 explore map with whole buildings as placed props (roofs on, door on the left front wall), and walk-in interiors as separate small maps reached through door cells (quiet house, tavern). Interiors are cutaways: back walls two levels, front walls one. The camera doesn't turn on building maps. Art: Picsart GPT image, two tile kits (`village`, `village_in`), two 16-prop sheets and seven building sprites, about $1.57 in all (`tools/art/picsart_village.py`, cut by `tools/art/village_cut.py`). Placeholder until Brandon approves.
- [AI] 2026-10-27 Smithy rack and hidden book are placeholders for the job system: picking a weapon sets `weapon_sword` / `weapon_daggers` / `weapon_bow`, the book sets `found_book`; the rack and the book disappear once their flag is set.
- [USER] 2026-10-27 The starting village has no fog of war: the whole town is visible at all times. Fog stays on the bigger maps. The village is more vertical: some homes sit up on a bluff, the town centre is a big open flat square, and the blacksmith is by the river.
- [AI] 2026-10-27 Maps set `fog` (default true). The village sets `fog: false` and every cell counts as in sight. Village levels: 0 stream bed, 1 flat ground and square, 2 town hall terrace, 3 north-east bluff reached by a two-high stair from the east lane (the lead can climb the stair with jump 1). The smithy sits two cells from the stream, so its yard and the weapon rack open onto the square. A test checks the bluff house is reachable from the start.
- [AI] 2026-10-27 More verticality in the village: a river ridge at level 3 holds the smithy and a home (stairs down to the square at row 15, stairs up from the west lane at row 20), the town hall terrace is level 3 with stairs, and the bluff is level 4. The square and lanes stay flat. Stairs are the only way up a two-level step, since the lead's jump is 1.

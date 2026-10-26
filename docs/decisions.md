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

## Roster and characters
- [USER] 2026-10-25 Set roster of characters that unlock through play. Main character is a default for now; customization later.
- [USER] 2026-10-25 Each character has a class, 1 to 3 off-class skills, perks and one deficiency.
- [USER] 2026-10-25 Stardrop Skygazer: moonshadow elf, moon magic, wayfinds by the stars, frail and spooks easily.
- [USER] 2026-10-25 Wizard: his books come too and fill group inventory slots.
- [USER] 2026-10-25 Hunter: ranged in combat, good at hunting and trapping food on the trail.
- [USER] 2026-10-25 Skeleton Archer needs no food, warmth or shelter but harshes the vibe. Bushberry is a flammable bush that makes 1 ration a day. Lewith & Flark take 2 slots but act as 1.
- [AI] 2026-10-25 Party has 4 slots. Lewith & Flark fill 2 of them.
- [AI] 2026-10-25 Unlock conditions (graybox): Wizard after the first recall, Lewith & Flark after the second, Bushberry from its trail event, Skeleton Archer on reaching the Wall.
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

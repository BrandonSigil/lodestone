# Enemy sketches and the placeholder foes

Brandon asked (2026-10-31) for an easy way to sketch enemy ideas, and for 10 to 20 placeholder foes in the game
now, with a clear big baddie and a wolf that reads as a wolf in every direction. Everything here is placeholder.

## Three easy ways to get enemy ideas (pick any)
1. **Picsart lineup, no drawing** (`art/prompts/hand-enemy-sketches.txt`, prompt A): one picture, 8 foes, each
   from the front and from the back. GPT image, 2K, 3:2. Image 1 is the approved dog sheet
   (`docs/art/characters/dog-reference-sheet.png`). The 8 lines are pre-filled with the in-game placeholder foes;
   change any line or leave it.
2. **Picsart turnaround for one foe** (prompt B): one foe in five facings, like the dog's top row. Use it for the
   wolf, or any foe whose turn you want to see.
3. **Scribble by hand**: `art/templates/enemies/enemy-sketch-sheet.png` (rebuilt by
   `tools/art/enemy_sketch_sheet.py`) has 8 slots, each with a FRONT box (faces you, lower right) and a BACK box
   (walks away, upper right), a tile diamond, a token base and height lines for small, person and big. Draw two
   views only; the game mirrors them for the other two combat facings. A phone photo of a paper sketch is fine.

Drop results on the Studio desk or in the chat; the art runner cuts them and brings them back as a review card.

## The placeholder foes in the game
Drawn in code by `game/scripts/combat/foe_figure.gd` from `game/data/foe_looks.csv` (body plan, size, colours,
weapon, head piece, extra). Every foe stands on a dark red board-game token; the team ring stays red. Each is drawn
for SE (front: face and eyes) and NE (back: no face, the tail or back nearest) and mirrored for SW and NW. Anims
use the placeholder timing (idle, walk, attack, cast, hurt, down). A foe that gets its own sprite art
(`game/art/source/characters/<id>/`) draws with that instead.

| id | body | in-game name (placeholder) |
| --- | --- | --- |
| bandit, bandit_archer, ambusher | biped (hood, mask) | BANDIT, BANDIT BOW, SNEAKY GUY |
| foe_mender, foe_hexer, foe_warder | biped (cowl, pointed hat, helm and shield) | HEALER / CURSE / SHIELD FOE |
| ogre (new) | big biped, club | BIG OGRE |
| lich_minion | skeleton | BONE GUY |
| lich | boss (robe, crown, glowing eyes) | LICH KING, the big baddie |
| wolf, alpha_wolf (new), bear (new), foe_rusher (boar), foe_bull | four legs | WOLF, BIG WOLF, BIG BEAR, RUSH FOE, BULL FOE |
| slime (new), strange_thing | blob | GOO BLOB, THING ??? |
| bat (new) | flyer (tag flying) | FLAP BAT |
| spider (new) | spider | LEG BUG |
| ice_pillar | crystal (the Lich's summon) | ICE STICK |

New groups in `data/encounters.csv`: `den_pack`, `bear_cave`, `goo_bog`, `ogre_camp`, `crawlers`, and `foe_zoo`
(eight at once). The launcher's FIGHT column has **New foes** (a random new group on a forest valley) and **Foe
zoo**. None of the new foes is placed on a story map yet, so the robot's numbers don't move.

Check by eye: `game/tools/foe_shot.gd -- out.png [zoom] [id,id]` saves every foe in four facings and five anims.

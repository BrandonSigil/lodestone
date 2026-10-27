# Character, monster and boss sprites: spec, templates and Krita workflow

New here? The step-by-step for adding a character (generate or draw, cut, test) is `docs/art/adding-characters.md`.

Status: **Proposed (AI), 2026-10-27.** Built from Brandon's character sheet (`docs/art/characters/00-reference-sheet.png`: a chibi hero in five iso views on tile footprints, idle / walk / attack / cast / hurt poses, sword and cloak parts, eight swatches), which he asked to be the template for every character. Every numbered rule is a proposal until he marks it his in `docs/decisions.md`.

Templates: `art/templates/characters/`. Diagrams: `docs/art/characters/`. Both are rebuilt by `python3 tools/art/char_art.py`, which uses the board's camera (same math as `tools/art/battle_art.py` and `combat_board.gd`). The same script exports painted files into `game/art/source/characters/`.

Full step-by-step Krita guide with pictures: the "Lodestone Character Guide" page (link in `docs/context/README.md`, copy in `docs/context/artifacts/character-guide.html`).

## 1. The idea in one paragraph
A piece is a little chibi figure, about 2.3 heads tall, standing on its cell like a board-game piece. It is drawn with the battle maps' camera (2:1 dimetric, art at 2x the engine) so its feet land on the centre of the cell. Each character gets a turnaround in five views (S, SE, E, NE, N); the other three are mirrors. The turnaround is cut into paper-doll parts that the engine recolours, randomizes and animates by moving parts around their joints, so walking and idling in all eight directions costs no extra drawing. Only the big moments (attack, cast, hurt, down) get drawn key frames, and only for the two combat facings, SE and NE.

## 2. Rules
Numbers are art pixels at 2x the engine unless a rule says otherwise.

### Camera and frame
- **C1** Same projection as the maps (B1 to B3): 2:1 dimetric, orthographic, tile diamond 128 x 64, one level = 32 px.
- **C2** Frame = **192 x 192 per footprint cell**, foot anchor at **(96, 160)**: the centre of the footprint diamond. The engine puts that pixel on the cell's top centre. In general, for an n x n footprint the frame is 192n square and the anchor (96n, 160n).
- **C3** Size classes: **small** 1x1, head at about 1.5 levels; **hero** (all people) 1x1, head at **3 levels (96 px)**, hats and hair up to 3.5; **large** 2x2 (frame 384), about 4 levels; **boss** 3x3 (frame 576), 6 to 10 levels. See `01-sizes.png`.
- **C4** Bodies stay inside their footprint; heads, tails and weapons may overhang by half a cell. Everything above the feet may use the headroom up to the frame top.
- **C5** No ground, base disc, cast shadow or grass tuft in the frame. The engine draws the contact shadow, the team ring and the board-game base.

### Directions
- **C6** Eight facings named by where the piece looks on screen: S, SE, E, NE, N, NW, W, SW (`02-directions.png`). The grid's four move directions are the diagonals SE, SW, NE, NW, so combat only ever needs those; roaming uses all eight.
- **C7** Draw **S, SE, E, NE, N**. SW, W, NW are horizontal mirrors of SE, E, NE. A lopsided piece (a sling on one shoulder, an eyepatch) may draw its own SW / W / NW; the exporter and engine prefer a drawn view over a mirror.
- **C8** Pieces are lit from **above and slightly in front**, never from one side, so a mirrored view is still correct under the maps' upper-left sun (B10). Shade with 2 or 3 values per material: light on top, mid, dark under the chin, under the cloak hem and down the far side of the body.
- **C9** Combat facings come first: SE and NE (with their mirrors) cover every fight. S, E and N are needed for free roaming outside combat.

### Line, colour and surface
- **C10** Outline in ink **#373335**, never black: **3 px** outer silhouette, **2 px** inner edges at shipping size (12 / 8 px on a 4x model sheet). Same ink as the maps (B14).
- **C11** Flat fills plus one light value and one dark value per material (Style Bible R2, R4). No noise, no painted texture, no grain (the engine adds it).
- **C12** Paint with the **key ramps** (`04-palette.png`, `art/templates/characters/lodestone-characters.gpl`): cloth_a, cloth_b, cloth_c, trousers, leather, hair, skin, metal, accent_r, accent_y, each light / mid / dark, plus ink and glint. They are Brandon's sheet swatches. The engine recolours a piece by swapping whole ramps, so a finished sprite must use only these exact colours (lock with Krita's Palettize filter or `char_art.py export --lock`).
- **C13** Pieces stay the warmest, brightest thing on the map (B30). Monsters may use their own ramps, but saturated red and blue stay reserved for team rings and highlights.
- **C14** Faces read at engine size (48 px tall): big head, two dot eyes, one clear silhouette feature per character (hat, hood, hair shape, pack, weapon).

### Animation
- **C15** Default animation is **cut-out**: the engine moves paper-doll parts around their pivots (neck, shoulders, hips, hands; `05-parts.png`). Idle and walk in every direction come from this.
- **C16** Drawn key frames only where cut-out can't sell it: attack, cast, hurt and down, in SE and NE. Frame counts and speeds:

| Anim | Frames | fps | Notes |
|---|---|---|---|
| idle | 4 | 6 (5 large/boss) | loop; breathing, cloak sway |
| walk | 6 | 10 (8 large, 12 small) | loop; contact, down, pass, up x2 |
| attack | 6 | 12 (10 large/boss) | wind, wind, **hit on frame 3**, follow, recover, settle |
| cast | 6 | 10 | gather, gather, raise, **release on frame 4**, hold, settle |
| hurt | 2 | 8 | flinch, recoil |
| down | 2 (boss 4) | 6 | holds the last frame |
| move (boss) | 4 | 6 | loop; bosses lumber |
| special (boss) | 6 | 8 | **hit on frame 4** |

- **C17** The hit / release frame is the one the engine syncs damage numbers and sounds to. Keep anticipation before it and follow-through after it.
- **C18** Feet stay on the anchor for every frame except jumps and knock-backs; the engine moves the piece between cells, the frames never travel.
- **C19** Spell glows, dust puffs and weapon trails go on the **fx** layer. The engine draws fx additive or tinted, above the body.

### Parts (paper doll)
- **C20** Parts are drawn **in place**: each part sits exactly where it is on the full figure, in the same slot and anchor. Assembly is stacking, no offsets.
- **C21** Two stack orders: **front** (S, SE, E and their mirrors) and **back** (NE, N and NW). Layer names in the templates are the stack order; the engine reads them from the sprite's json.
- **C22** Paint the hidden bits under every moving part (the torso under an arm, the leg top under a tunic) so parts can rotate without holes.
- **C23** Variants for randomizing go in the same file as extra layers named `part NN <slot> <variant>` (e.g. `part 08 hair or hat 2`). Each exports as its own PNG.

### Monsters and bosses
- **C24** Same camera, frame formula and rules. Quadrupeds use the quad part set (tail, legs far, body, legs near, head, ears or horns); giants use the biped set.
- **C25** A monster's facing must read in SE and NE alone: eyes or mouth or weapon point along the facing.
- **C26** Bosses are built from parts first (head, arms, core, weak point) so phases can swap a part instead of redrawing. Bosses don't roam; they have no S / E / N walks.

### Files
- **C27** Working files: `art/characters/<id>/` (`<id>-model.kra`, `<id>-sheet.kra`, `<id>-parts-front.kra`, ...; KRA is LFS). Export a `.psd` or `.ora` copy for the exporter (`File > Export`), keeping the template's layer names.
- **C28** Game files (written by `char_art.py`, plain git): `game/art/source/characters/<id>/`
  - `<id>_<anim>_<dir>.png` horizontal strip of frames, e.g. `hero_walk_se.png` (1152 x 192)
  - `<id>_stand_<dir>.png` single frame per drawn view
  - `<id>_<anim>_<dir>_fx.png` fx strip, when there is one
  - `parts/<dir>/<part>.png` paper-doll parts, one frame each
  - `<id>.json` class, frame, anchor, scale 0.5, mirror table, anims with frames / fps / loop / hit, stand views, parts and stack order
- **C29** Ids are lower_snake placeholders chosen by Brandon (never a name Claude invents). Dir is one of `s se e ne n` (or `sw w nw` when drawn).

## 3. The templates (`art/templates/characters/<class>/`)
Every class (hero, small, large, boss) has the same set. Each file comes as `.psd` and `.ora` (Krita opens both). A hidden `TEMPLATE <class> <kind>` layer tells the exporter what the file is; keep it.

| File | Canvas | For |
|---|---|---|
| `<class>-model-sheet` | 2304 x 1536: 3 x 2 slots of 768 | The turnaround at high resolution for image generation and design: S, SE, E / NE, N, KEY. Layers: CONTROL blocking mannequins (visible), CONTROL line art and depth (hidden), GUIDE slots / footprints / levels / joint pivots, paint 1 generated, paint 2 cleanup and lines, paint fx. |
| `control-*.png`, `views/<dir>-*.png` | sheet / 768 | Line art, depth and flat blocking of the mannequin for Krita AI control layers, as a whole sheet and per view. |
| `<class>-parts-front`, `<class>-parts-back` | 768 per slot | Paper doll at model scale: front file has S, SE, E slots, back file NE, N. One empty layer per part in stack order, mannequin and pivots as guides. |
| `<class>-anim-canvas` | 768 x 768 | One model-scale slot with the same anchor, for Krita's animation timeline (SE and NE mannequins as guides). |
| `<class>-sheet` | hero / small 1536 wide, large 2304, boss 3456 | Shipping-size sprite sheet. Row 1: stand in every facing (W, SW, NW marked optional). Then SE rows (idle, walk, attack, cast, hurt + down), the same for NE, then walk S, E, N for roaming. Each frame shows footprint, anchor, level ticks and the head band; GUIDE mannequins (hidden) ghost the facing in every frame. |
| `layout.json` | | Every number above: frames, anchors, rows, anims, joints per facing, palette, part stacks. The engine and the exporter read it. |
| `lodestone-characters.gpl` | | The key ramps as a palette. Krita: Palette docker > Import resource. |

The **mannequins** are simple 3D dummies (ellipsoids) rendered with the board's exact camera, so every view in a template is a true SE / NE / E... view at the right size. They give Krita AI the pose, proportion and direction to follow, and they give Brandon a ghost to draw over.

## 4. Exporting
```
pip install pillow numpy psd-tools          # once
python3 tools/art/char_art.py export art/characters/hero/hero-model.ora --id hero --lock
python3 tools/art/char_art.py export art/characters/hero/hero-parts-front.psd --id hero --lock
python3 tools/art/char_art.py export art/characters/hero/hero-sheet.psd --id hero --lock
python3 tools/art/char_art.py pack art/characters/hero/renders --id hero --class hero --lock
```
- **model** files export a `stand` frame per view (scaled from 768 to the frame, anchor kept).
- **parts** files export `parts/<dir>/<part>.png` (scaled the same way).
- **sheet** files export a strip per row segment that has paint; empty frames at the end of a segment are dropped.
- **pack** joins a Krita animation render (`Render Animation`, base name `<id>_<anim>_<dir>_`, 192 or 768 square frames) into a strip.
- `--lock` snaps colours to the palette (or `--palette other.gpl`). `lock IN.png OUT.png` does one file.

Rebuild the templates with `python3 tools/art/char_art.py` (about two minutes).

## 4b. Picsart (or any image model without control layers)

Fixed house-style prompt blocks to paste once and reuse: `art/prompts/` (see its README).
Flux in Picsart takes reference images instead of control layers, so a character is made from three pictures: the mannequin view for pose and camera (`views/<dir>-blocking.png`, or the 3:2 `control-blocking.png` for a whole turnaround), the identity (a sketch first, then the cleaned key view `art/characters/<id>/<id>-key.png`), and the colours (`art/palettes/characters.png`, no text; `characters-labeled.png` has the hex codes). Two Flows: "Lodestone character view" (1:1) and "Lodestone turnaround" (3:2). Prompts and the full steps are in the Character Guide's Picsart section.

Raw pictures go in `art/characters/<id>/picsart/`. Bring each one in with:
```
python3 tools/art/char_art.py import art/characters/hero/picsart/hero-se-1.png --id hero --dir se      # one view
python3 tools/art/char_art.py import art/characters/hero/picsart/hero-turnaround-1.png --id hero       # 3:2 sheet
python3 tools/art/char_art.py import art/characters/hero/picsart/attack-hit.png --id hero --dir se --anim attack --frame 2 --fit
```
`import` removes the plain background (flood from the edges, stopped by the ink outline; a picture that already has transparency is kept), moves each figure so its feet match the mannequin's feet, prints its height against the mannequin (`--fit` scales it to match), and writes `art/characters/<id>/<id>-model.ora` (layered, views in their slots, kept across imports) plus stand frames. With `--anim` it writes a 768 frame into `art/characters/<id>/renders/` for `pack`. Then fix the model sheet by hand and `export --lock` it.

## 5. Engine work to use these sprites
**Built (2026-10-27), first pass:** `CharacterArt` (`game/scripts/combat/character_art.gd`) reads `<id>.json` and the strips; a `CharacterDef` whose id has a sprite folder draws as a sprite in battle, everyone else stays a graybox `Pawn`. Pieces face their last step and turn toward their target (camera turns respected), play walk while moving, attack or cast with the hit landing on the json's hit frame, and hurt when hit. SW and NW are mirrored, S/E/N fall back to the nearest drawn view. Combat stance (`ready`, `advance`) plays in fights when drawn, and the explore scene uses the same sprites. Not yet: S/E/N roaming views, paper doll, recolour shader, down (downed pieces still vanish). The first set (`lead`) was generated from the reference sheet with `art/prompts/sheet-character-anim.txt` and cut by `tools/art/anim_sheet_cut.py`.

The plan:
1. **CharacterSprite node** that reads `<id>.json` and builds `SpriteFrames` from the strips (frame size from the class, offset so the anchor sits on the node origin, drawn at 0.5 scale like the tiles). Missing art falls back to today's graybox `Pawn`, so characters can arrive one at a time.
2. **Facing**: `CombatUnit` gets a world facing (grid direction) set by its last move step and turned toward its target when it acts. Screen facing = world facing turned by the camera's quarter turns (Q). Pick the drawn view, else mirror (flip_h) per the json table, else the nearest drawn facing.
3. **Anim state machine**: idle, walk, attack, cast, hurt, down (plus move and special for bosses). Hook into `animate_move` (walk per hop), `animate_attack` (attack or cast, wait for the hit frame before shaking the target and floating the number), damage (hurt) and KO (down). fps, loop and hit frame come from the json, so timing tweaks need no code.
4. **Paper doll**: a `PaperDoll` node stacks `parts/<dir>/*.png` in the json's front or back order and rotates parts around the pivots from `layout.json` (`AnimationPlayer` per facing for idle bob and walk swing). Used whenever a drawn strip is missing, which covers all roaming facings.
5. **Recolour shader**: swap key ramps (24 colours) for a character's ramps from data (new columns in the character table), so one set of parts serves the whole roster and random recruits. Piece colours stay fixed across regions (decisions, 2026-10-26).
6. **Multi-cell units**: 2x2 and 3x3 footprints in `CombatGrid` (occupancy, pathing for the footprint, targeting any covered cell, push rules), and depth sorting by the footprint's front corner.
7. **Depth and occlusion**: tall sprites draw in the board's per-cell depth pass; the existing ghost outline for hidden pieces uses the sprite's silhouette; foreground occluders fade near pieces (B26).
8. **Free roaming mode**: a scene on the same iso board where the party walks freely: WASD or stick in screen space turned into a world vector, snapped to eight facings for the sprite; click-to-move with A* over cells; step up at most one level, collide with blocks; camera follows; followers trail the leader. Interaction prompts open the existing event cards (caveman placeholders).
9. **Contact shadow and base** under sprites (exists for pawns), team ring, HP pips moved to the sprite's head band.
10. **Tests**: a headless check that every character in data has `stand_se` and `stand_ne` (or parts for them) and that each json anim's frame count matches its strip width.

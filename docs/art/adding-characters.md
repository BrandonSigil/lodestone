# Adding a character sprite: contributor how-to

Everything you need to add a character with all its facings and animation frames is in this repo. You clone it, make or draw the art, cut it into strips, and the game picks it up with no code change. Rules live in `docs/art/characters.md` (C1 to C29). This page is the short practical path.

The first finished character is `lead` (`game/art/source/characters/lead/`). Copy what it does. Every unit without art of its own draws as the general dummy (`game/art/source/characters/dummy/`, section 7).

## 1. What is where

| Path | What |
|---|---|
| `docs/art/characters.md` | The spec: camera, frame size, anchor, facings, animations, colours, files (C1-C29) and the engine plan (section 5). |
| `docs/art/characters/00-reference-sheet.png` | Brandon's character sheet: the look every character follows, and the identity reference for `lead`. |
| `docs/art/characters/01-05*.png` | Diagrams: sizes, the eight directions, frame anatomy, palette, paper-doll parts. |
| `art/templates/characters/<class>/` | Krita templates (`.psd` and `.ora`) per size class (hero, small, large, boss): model sheet, parts, anim canvas, shipping sprite sheet, mannequin control images. `layout.json` holds every number. |
| `art/templates/characters/lodestone-characters.gpl`, `art/palettes/characters.png` | The key colour ramps (Krita palette, and a picture for image models). |
| `art/prompts/sheet-character-anim.txt` | Image-model prompt: one facing as a 5-row animation sheet (idle 4, walk 6, swing 6, cast 6, hurt 2 + down 2). |
| `art/prompts/sheet-character-stance.txt` | Image-model prompt: one facing in combat stance, weapon drawn (ready 4, advance 6). |
| `art/prompts/style-character.txt`, `ask-character.txt` | House-style block and per-run ask for Picsart canvases. |
| `docs/art/references/picsart/anim-lead-*.png`, `stance-lead-*.png` | The raw generated sheets `lead` was cut from (examples of a good sheet). |
| `tools/art/char_sheet.py` | Generates one facing of a character sheet with the house defaults (model, 1K, 3:2, reference sheet, facing words); `--cut` also cuts it into the game. |
| `tools/art/picsart_sheet.py` | Lower level: sends any prompt file plus reference images to the Picsart API and saves the picture. |
| `tools/art/anim_sheet_cut.py` | Cuts a generated sheet into the game's strips and writes `<id>.json`. |
| `tools/art/char_art.py` | Krita path: exports model sheets, parts and sprite sheets from `.psd`/`.ora`, packs Krita animation renders, locks colours to the palette, imports single Picsart views. Also rebuilds the templates. |
| `game/art/source/characters/<id>/` | What the game reads: `<id>.json` plus one horizontal strip per animation and facing. |
| `game/art/source/characters/dummy/`, `art/prompts/sheet-dummy-anim.txt` | The general dummy every unit without its own art draws with (`CharacterArt.FALLBACK`), and the prompt it was generated from. |
| `game/scripts/combat/character_art.gd` | `CharacterArt`: loads the json and strips, picks facings and frames. |
| `game/data/characters/<id>.tres` | The character's data. Its `id` must match the sprite folder name. |
| `docs/context/artifacts/character-guide.html` | Offline copy of the Character Guide page (open in a browser). |

## 2. Setup

- Godot 4.4 or newer (the project runs in 4.4 to 4.7).
- Python 3 with `pillow numpy requests psd-tools`. On a Mac with Homebrew Python, use a venv: `python3 -m venv ~/.lodestone/venv && source ~/.lodestone/venv/bin/activate && pip install pillow numpy requests psd-tools`.
- For generated art only: a Picsart API key in `~/.lodestone/picsart-api-key` (or the env var `PICSART_API_KEY`). It never goes in the repo; `.gitignore` blocks the usual names. Picsart bills in dollars; a character sheet costs about 5.5 cents at 1K (9.5 at 2K).
- Run every command from the repo root.

## 3. The contract the game reads

`game/art/source/characters/<id>/<id>.json` (written by the cutter; you rarely edit it by hand):

```json
{
  "id": "lead", "class": "hero",
  "frame": 192, "anchor": [96, 160], "scale": 0.5,
  "dirs": ["se", "ne"],
  "mirror": {"sw": "se", "w": "e", "nw": "ne"},
  "anims": {
    "idle":   {"fps": 6,  "loop": true,  "frames": 4},
    "walk":   {"fps": 10, "loop": true,  "frames": 6},
    "attack": {"fps": 12, "loop": false, "frames": 6, "hit": 2},
    "cast":   {"fps": 10, "loop": false, "frames": 6, "hit": 3},
    "hurt":   {"fps": 8,  "loop": false, "frames": 2},
    "down":   {"fps": 6,  "loop": false, "frames": 2},
    "ready":  {"fps": 6,  "loop": true,  "frames": 4},
    "advance":{"fps": 10, "loop": true,  "frames": 6}
  }
}
```

- **Strips**: `<id>_<anim>_<dir>.png`, frames left to right, each `frame` px square (192 for a 1x1 piece), feet on `anchor` (96, 160) in every frame, transparent background, no ground or shadow (C5). Also `<id>_stand_<dir>.png` (one frame).
- **dirs** lists the facings actually drawn. Facings are named by screen direction: `s se e ne n sw w nw` (C6). Anything not drawn uses the `mirror` table (flipped), then the nearest drawn view.
- **hit** is the frame index (from 0) where damage lands and the number pops (C17).
- **ready / advance** are idle and walk with the weapon out. In a fight the game plays them instead of idle and walk when they exist.
- **Size classes**: hero 192 frame, large 384 (2x2), boss 576 (3x3). Only 1x1 pieces work in the engine today.

## 4. Path A: generate with an image model (how `lead` was made)

1. **Identity.** Have a reference picture of the character (a sheet like `00-reference-sheet.png`). For a new character, copy `sheet-character-anim.txt` and `sheet-character-stance.txt` to a new name and replace the lead's look paragraph ("Image 1 = ...") with the new character's look and the path to its reference. Describe looks only; names and story come from Brandon (C29, CLAUDE.md).
2. **One sheet per facing.** Combat needs `se` and `ne`. Roaming also wants `s`, `e` and `n` (`sw`, `w` and `nw` are mirrors, never drawn). Two sheets per facing: the animation sheet and the stance sheet.
   ```
   python3 tools/art/char_sheet.py --id <id> --dir se --dry-run              # check the prompt, spends nothing
   python3 tools/art/char_sheet.py --id <id> --dir se                        # animation sheet
   python3 tools/art/char_sheet.py --id <id> --dir se --sheet stance         # weapon-drawn stance sheet
   ```
   Defaults: `gpt-image-2.5-sunburst`, **1K**, 3:2, `docs/art/characters/00-reference-sheet.png` as the only image, the facing words from `FACINGS` in the script. 1K is the default because the cutter shrinks every sheet to sprite size anyway: a 1K and a 2K sheet of the same facing look the same in game, and 1K costs about 40% less (tested 2026-10-27 on the lead's S facing). Pass `--resolution 2K` only for a sheet you also want as a big reference picture. For a new character pass `--prompt-file` (your copy from step 1), `--ref` (its reference sheet) and, if the lead's facing words don't fit, `--facing "..."`. Output lands in `art/picsart/out/<sheet>-<id>-<dir>_v<n>.png` at the next free version. Only attach the character's own reference sheet: models copy any other sheet you attach, detail and all.
3. **Look before you cut.** Every row needs the right number of separate figures on clean cream, same facing in every frame, no floor or text. Regenerate a bad sheet rather than fixing it in the cutter.
4. **Cut it into the game:**
   ```
   python3 tools/art/anim_sheet_cut.py art/picsart/out/anim-<id>-se_v1.png --id <id> --dir se
   python3 tools/art/anim_sheet_cut.py art/picsart/out/stance-<id>-se_v1.png --id <id> --dir se --rows ready:4,advance:6
   ```
   Or add `--cut` to the `char_sheet.py` command to generate and cut in one go. The cutter keys out the paper, finds rows and figures (and splits two rows a sword tip or spark joins), scales the whole sheet once so the idle body is hero height, lines frames up (walk, idle, ready and advance on the body's centre so the walk doesn't lurch; swing, cast and hurt on the feet so a lunge travels), writes the strips and updates `<id>.json` (adds the facing to `dirs`). It prints a frame count per row; a row that comes out short is still written with its own count.
5. **Keep the raw sheets** you used in `docs/art/references/picsart/` (that folder is plain git, not LFS), so the next person can re-cut them.

## 5. Path B: draw it in Krita

1. Open the class template, e.g. `art/templates/characters/hero/hero-sheet.psd` (or `.ora`). Save your working copy as `art/characters/<id>/<id>-sheet.ora`. Keep the template's layer names; the hidden `TEMPLATE ...` layer tells the exporter what the file is.
2. Paint over the mannequin ghosts with the key ramps only (`lodestone-characters.gpl`, C12). Rows: stand in every facing, then SE rows (idle, walk, attack, cast, hurt + down), the same for NE, then walk S, E and N for roaming.
3. Export: `python3 tools/art/char_art.py export art/characters/<id>/<id>-sheet.ora --id <id> --lock`. For Krita animation-timeline renders use `char_art.py pack` (see `characters.md` section 4).
4. Check `game/art/source/characters/<id>/<id>.json` has the facings and frame counts you drew.

## 6. Hook it up and test

1. Make sure `game/data/characters/<id>.tres` exists with `id = &"<id>"`. A character whose id has a sprite folder draws as a sprite automatically; everyone else draws as the general dummy, tinted by team.
2. Run the checks: `GODOT=/path/to/godot tools/check.sh`. The test `test_character_sprites_match_json` checks every roster character's strips exist, are wide enough for their frame count, include `se` and `ne`, and mirror for `sw`. (It only covers ids in `Db.ROSTER`; enemies are not checked yet.)
3. Look at it: open `game/scenes/combat_sandbox.tscn`, press F6, place the character, press F1 to play. Move to see walk and advance, attack to see the swing land on the hit frame, Q to turn the camera. The explore scene (`game/scenes/explore.tscn`) plays idle and walk while you walk around.
4. Commit the strips, their `.import` files, the json and the raw sheets. Everything under `game/art/source/` and `docs/art/` is plain git.

## 7. Built and not built (2026-10-28)

Built:
- Sprite drawing in battle and explore, facing from movement and attacks, camera turns respected.
- Animations: idle, walk, attack and cast (hit frame synced), hurt, combat stance (ready, advance). SW, W and NW mirror SE, E and NE.
- Any drawn facing in `dirs` is used when the piece faces that way; a facing that isn't drawn falls back to the nearest of SE / NE. `lead` draws all five (S, SE, E, NE, N), so it shows every facing while roaming.
- See-through props and an x-ray outline for hidden party pieces.

Not built yet:
- **down** is in the files but unused: downed pieces still vanish.
- **Paper doll** (parts animated in code, C15) and the **recolour shader** (ramp swap, C12): not built, so each character needs its own full strips for now.
- **Multi-cell units** (2x2 large, 3x3 boss): rules exist, engine support does not.
- Only `lead` has art of its own. Every other unit, enemies included, draws as the **general dummy** (`dummy`): one neutral figure drawn in five facings, S, SE, E, NE and N (SW, W and NW mirror SE, E and NE), with idle, walk, attack, cast, hurt and down but no stance (ready, advance). The board tints it by team (party green, blue, purple and so on; enemies red, with a glyph over the head to tell them apart). If the dummy art is missing, the code-drawn figure in `game/scripts/combat/placeholder_figure.gd` stands in. Its cut scales differ a little by facing (0.65 to 0.71) while `dummy.json` uses one scale of 0.5, so check the S, E and N views while roaming. Weapon variants per unit are still to do.
- The `lead` art is generated placeholder art until Brandon draws or approves it.

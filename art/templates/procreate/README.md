# Procreate templates (iPad)

Sketch sheets for Procreate, plus the palette. Each sheet has a free SKETCH layer for ideas and a few measured guides (footprint diamonds, head band, course lines) so whatever you draw fits the game. Built by `tools/art/procreate_art.py`. The sizes are the battle-map and character rules: art at 2x the engine, a cell is 128 x 64, one level is 32 px (`docs/art/battle-maps.md` B1 to B32, `docs/art/characters.md` C1 to C29).

## The sheets

**character-hero.psd** follows the reference sheet (`docs/art/characters/00-reference-sheet.png`). Top row: the five drawn facings S, SE, E, NE, N. Bottom row: idle, walk, attack, cast, hurt on SE (the combat facing), then the sword and cloak parts. Ten key-ramp swatches sit on the right. The hero silhouette is hidden by default; show it on its layer to measure.

**terrain-tiles.psd** has 20 cards: grass 1, 2 and 3, forest, road, stone 1 and 2, stairs, rock, water, hazard, special, the moss overhang (lit and shade), cliff faces (lit and shade), and falls (lit and shade).

**props-iso.psd** has 11 props in two rows, FRONT and SIDE (B28): pine 1, pine 2, bush, boulder, pillar, brazier, crate, detail, landmark, ruin, haybale. Each has a footprint diamond and level ticks up to six levels (B23).

Every sheet has these layers, bottom to top:

| Layer | What it does |
|---|---|
| `paper` | cream background. Lock it. |
| `GUIDE ...` | the measured guides. Hide them to sketch freely. Never cut. |
| `REFERENCE ...` | swatches on the character sheet. Never cut. |
| `SILHOUETTE hero` | the hero shape (character sheet only). Hidden by default. Never cut. |
| `PAINT 1 colour`, `PAINT 2 ink`, `PAINT 3 fx` | where the finished art goes. These are what gets cut. |
| `SKETCH (not cut)` | the free layer. Anything here stays out of the cut. |

The card and cell edges are guides only. Draw across them if the art needs it, but keep the figure, footprint and props inside their cell.

## Draw, then send it back

1. Open the sheet from Files as a new artwork (Gallery Import keeps the layers).
2. Sketch on `SKETCH`, then ink and colour on the `PAINT` layers.
3. Export as **PSD** from Procreate (Actions > Share > PSD keeps the layer names). Send me that file.
4. I cut it with:

```bash
python3 tools/art/procreate_art.py cut FILE.psd --template character-hero
```

Templates are `character-hero`, `terrain-tiles` and `props-iso`. Cut pieces land in `art/procreate-out/<template>/` as PNGs named after their slot (`idle.png`, `top_grass.png`, `pine_1.png`). Empty slots are skipped. If you change the canvas size the cutter stops and says so, so keep it as built. A flat PNG also works, but it cuts whatever is visible, so hide the guides first.

## Get the templates onto the iPad

1. Copy the `.psd` files from `art/templates/procreate/` to the iPad (AirDrop, or iCloud Drive / Files).
2. Import each one as a new artwork. Inserting a PSD into an open canvas flattens it ([actions help](https://help.procreate.com/procreate/handbook/actions/actions-add)).

## Get the palette onto the iPad

Files are Adobe Swatch Exchange (`.ase`). Procreate also accepts `.swatches` and `.aco` ([palette help](https://help.procreate.com/articles/zqbpae-importing-color-palettes)).

1. Open the Color panel, go to the **Palettes** tab, tap **+**, then import the file. Or drag the `.ase` from Files into the Palettes tab.
2. Import what you need:

| File | Colours | Status in the docs |
|---|---|---|
| `lodestone-full.ase` | all 162, in groups | everything below in one file |
| `lodestone-1-pieces.ase` | 7: red, ochre, cream, indigo, base, ink, glint | "fixed everywhere", style bible section 5 |
| `lodestone-2-characters.ase` | 30: the ten key ramps, light / mid / dark | Brandon's character sheet swatches (C12) |
| `lodestone-3-home.ase` | 16: home | battle-map reference palette (B17) |
| `lodestone-4-snow.ase` | 16: snow | battle-map proposal (`art/palettes/lodestone-zones.gpl`) |
| `lodestone-5-desert.ase` | 16: desert | battle-map proposal |
| `lodestone-6-dungeon.ase` | 16: dungeon | battle-map proposal |
| `lodestone-7-forest.ase` | 16: forest | battle-map proposal |
| `lodestone-8-regions.ase` | 45: five style lab regions, nine roles each | style bible section 5; adopted 2026-10-26 |

`lodestone-palette-preview.png` shows every colour with its hex code. Procreate does not show colour names inside a palette, so the file name tells you which set you are in. Biomes without a palette yet (canyon, crystal, farmland, marsh, ruins) need one before colour work starts there.

## Rebuild

```bash
python3 tools/art/procreate_art.py
```

Needs Pillow, numpy and psd-tools (`pip install pillow numpy psd-tools`).

## Not checked on a device

The sheets were checked by reading them back with psd-tools (layer names, visibility and sizes), the palettes by parsing the `.ase` files, and the cutter on a test PSD with a painted cell. Nothing has been opened in Procreate on an iPad yet. If a layer, palette or export does not come through as described, tell Claude which step failed.

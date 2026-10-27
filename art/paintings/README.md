# Map paintings

Whole battle maps painted on the templates in `art/templates/battle-maps/maps/`.

- `<map>-<region>.kra`: the Krita working file, with CONTROL and GUIDE layers kept (LFS).
- `<map>-<region>.png`: the export: 2400 x 1600, transparent background, island not moved, CONTROL / GUIDE / paper hidden (plain git).

The game can't load whole paintings yet (map plates, step 4 of the engine list in `docs/art/battle-maps.md`). Tile textures and props go in `game/art/source/battle/` instead.

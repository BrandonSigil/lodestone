# What makes a level editor a joy (research for the map maker, 2026-10-28)

Brandon asked what AAA studios, Supergiant (Hades) and Acid Nerve (Death's Door) do, before the map maker
grew into a full editor.

## What I found
- **Supergiant (Hades, Hades II):** their own engine and editor; little of the editor is public. The Noclip
  documentary (https://80.lv/articles/full-hades-documentary-from-noclip-is-now-available/) shows rooms laid
  out by hand from 2D art pieces with encounters added separately. Hades also never turns its camera: every
  room is composed for one angle, which Brandon adopted for Lodestone the same day.
- **Death's Door (Acid Nerve, Unity + ProBuilder):** every level blocked out in plain grey geometry first,
  playable at once, tweaked during playtests (widen a walkway that's too tight for its enemies), and only
  then marked up by the concept artist for which pieces need real art
  (https://blog.unity.com/games/crafting-intricate-environments-deaths-door). The placeholder blob is this.
- **AAA editors (Unreal, Hammer, the Creation Kit):** a searchable asset browser with thumbnails and
  favourites; ghost previews that snap before you drop; every object has a unique name and fields, which
  is how Hammer scripts a door (`door_03` opens when `lever_02` fires); play from here in one click.
- **LDtk** (by the Dead Cells developer, https://ldtk.io): entities with typed custom fields, auto-layer
  rules that do the boring skinning (transition tiles) for you, icons everywhere, instant feedback, backups.

## What the map maker took from it
| Idea | In the map maker |
| --- | --- |
| Asset browser with thumbnails, search, recents | Assets tab: search, RECENT row, drawers > groups of art tiles (`data/catalog.csv`, new art shows up under Unsorted) |
| Ghost preview before placing | Green / red footprint and a see-through sprite under the cursor |
| Drag and drop | Drag a tile from the catalog onto the map, or click it and stamp |
| Every object named, with fields | Inspector: ids, kind, event, where a door leads, "gone if" flags, a note for Claude |
| Blockout first | Named placeholder blobs; art named after the blob replaces it on its own |
| Auto-rendering | Ground fringes in code now, painted transition pieces later (`docs/art/transitions.md`) |
| Icons, few words | Icon tool rail with key hints in tooltips, icon top bar, options bar for the picked tool |
| Outliner | "On this map" list in the Inspector: click to select and fly to it |
| Play from here | Play test (F8 comes back) |

## Next ideas (not built)
- Multi-select (box drag) and move or delete a group; copy and paste a region between maps.
- Prefabs: save a furnished room or a market corner as one catalog entry.
- Favourites (pin a tile) and per-map palettes.
- Enemy groups placed and edited from the catalog (explore maps), and battle-map party / foe pieces added
  from it (today they can be moved, not added).
- Painted transition pieces and a rule editor for them.
- Autosave and crash backups (LDtk does this).

# Village hub

Code: `game/scripts/village_scene.gd` (screen and panels), `game/scripts/village/` (view, frame, pack, rules),
`game/scripts/riso/` (the shared riso drawing kit). Data: `game/data/items.csv`, `game/data/quests.csv`.

The first screen. The village is drawn in code in the style lab draft 1 look (home palette, gumdrop
mountains, scallop pines, dark houses with one lit window, fixed paper grain) inside frame A, the
embroidered band. Every picture is a pure function of `VillageView.SEED`.

## Places (click the building or its tag)
- **Friend fire (hearth):** the unlocked roster waits around the fire. The panel shows every roster card;
  locked ones say how to unlock. Picked members walk over to the gate. 4 party slots, Lewith & Flark take 2.
- **Stuff hut (shop):** buy supplies with gold. A bought item drops into the first free spot in the pack,
  turning it if that helps. No room or no gold refuses the buy and costs nothing.
- **Big man house (mayor):** placeholder hello, old story lines (cycles three keys), and side jobs from
  `quests.csv`. Taking a job saves it in meta (`meta.quests`). Finishing a job is not built yet.
- **Go out (gate):** leaves with the picked party and the pack. Same as the GO tab.

## Bottom frame (frame A)
- Party panel: the picked pieces, first word of the name, HP dots.
- Lodestone medallion: the arc fills with best distance. Click it (or MAP) to open `Game.WORLD_MAP`,
  which the world map thread owns. Without that scene a notice says so.
- Pack panel: a mini copy of the grid plus food, medicine and gold totals. Items draw with Brandon's icons (`game/art/source/icons/<item id>.png`, through `ActionInfo.icon`) where one exists: one big icon across a solid block, on the middle cell of an L or T. Kinds with no icon file and no code icon show their name ([USER] 2026-11-01: "We've got icons! We should use em!").
- Tabs: a status tab (gold, deaths, best) and PACK, MAP, GO buttons.

## Pack (Tetris-style grid)
- 4 x 3 = 12 cells, the same as the run's pack (`RunState.PACK_COLS` x `PACK_ROWS`).
- Drag an item to move it. While holding, R or right click turns it. Right click an item in place turns it too.
- Drop on SELL to sell it back at full price (still in town).
- The Wizard's books are a 3-cell L that joins the pack when he joins the party and leaves with him.
  They can be moved and turned but not sold. If they don't fit, he can't join until there's room.
- On departure the pack becomes the run's food and medicine, and leftover gold comes along
  (`Game.start_run(picked, outfit)`), repacked as meat (10 a cell) and potions (3 a cell). No shop item
  is denser than that, so the run's pack never needs more cells than the outfit used. A test enforces it.

## Adding a shop item (no code)
1. Add a row to `game/data/items.csv`: id, name_key, kind (food, crate, med, herb, book: picks the icon
   and color), shape (rows split by `/`, `#` filled, `.` empty), price, food, medicine, shop (1 = sold).
2. Keep food at most 10 per cell and medicine at most 5 per cell.
3. Add the name key to `game/text/placeholder.csv` and run `tools/check.sh`.

## Riso kit (shared with the world map)
- `Riso.palette_at(s)`: nine roles (sky_top, horizon, far, mid, near, ground, dark, accent, light) blended
  across the five region palettes.
- Shapes: `draw_gumdrop`, `draw_pine`, `draw_lolly`, `draw_house`, `draw_crescent`, `draw_step_cloud`,
  `draw_marks`, `draw_piece`, `draw_stone`, `draw_stamp_*`, `draw_item_icon`, `draw_label`.
- `Riso.grain_rect(seed)`: full-screen ColorRect with `shaders/riso_grain.gdshader`; put it in a CanvasLayer
  above everything.
- `RisoTheme.make()`: paper panels, gold buttons, Young Serif (stand-in, `game/fonts/`).

## Screenshots
`tools/screenshot.sh` saves the hub. To check a panel: pass a panel id and items to buy, e.g.
`... -s res://tools/screenshot.gd -- res://scenes/village.tscn out.png pack crate sack`.

Not yet: finishing side jobs and paying rewards, mayor dialogue trees, hover tooltips on items,
sound, idle animation of the pieces, frame B or C, Brandon's own drawings.

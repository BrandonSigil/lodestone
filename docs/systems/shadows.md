# Shadows

Cast shadows for props, trees and pieces on the board (explore maps and fights). Code: `game/scripts/combat/shadow_kit.gd` (pure shape math) and the "cast shadows" block in `combat_board.gd` (`_shadow_index`, `_cast_onto`, `_unit_shadow`). Data: `game/data/shadows.csv`. Tests: `game/tests/test_shadows.gd`.

## What was wrong (backlog P27)
Each prop drew a flat ellipse in its own PROPS slab. The board paints slab by slab, back to front, so the ground of every cell in front draws after that blob and paints over the part that crossed into it. The shadow was cut along tile edges, and the diamond of the cell showed. The blob also ignored the prop's shape (a planter, a rack and a tree all got the same circle).

## How it works now
- One sun for the whole game (upper left, so shadows run right and toward the viewer). `sun` in `shadows.csv` is the ground shift on screen per pixel of height. The same direction holds when the camera turns, because the sun is fixed to the screen.
- A prop's shadow is its own sprite silhouette: the alpha channel is traced once per texture (`ShadowKit.silhouette`, cached, 96 px trace, holes dropped) and sheared along the sun, with the lowest point on the ground. A small contact patch sits at the base. Tall things (houses, the arch) lengthen slowly above `height_cap`.
- All shadows are built once per map (`_shadow_index`, about 120 ms for the village's 624 casters) and binned by screen position. They are rebuilt when the grid changes.
- Each ground cell, while it draws its top, asks the index for the shadows that reach it and are at its own level (a shadow never climbs a cliff face or lands on a higher block). Those shapes are merged into one (`union_into`, so two shadows overlapping never darken twice), clipped to the cell's own top, and drawn at one opacity. A cell only draws its piece of one continuous shape, so no tile edge shows.
- The edge is a two-step soft band (`edge` in the csv): a wider shape at half opacity under the solid one. No gradient, to keep to the flat style.
- Pieces get a footprint swept along the sun (`_unit_shadow`), not a centred blob.
- Water and stairs receive no shadow. Houses cast only their silhouette from the front corner (not a swept footprint, which came out as tile-shaped diamonds in the first try).

## Tuning (all in `game/data/shadows.csv`)
`sun`, `color`, `alpha`, `height_cap`, `edge`, and per-sprite rows `sprite:<stem>` with length multiplier (0 = no shadow), contact patch size. Numbered variants (`prop_bush_3`) follow their base row. The old blob look is `LODESTONE_OLD_SHADOWS=1` in the environment (`CombatBoard.cast_shadows`).

## Research and options weighed
1. Light2D with LightOccluder2D: Godot's 2D shadows are infinite for directional light, treat occluders as flat polygons (a shadow runs across a wall instead of up it), need a shadow-casting light pass per frame, and look like a lit scene, not the painted flat style. Rejected.
2. A blurred or offset darkened copy of each sprite in the prop's slab: same clip-by-the-next-cell problem as the blob, and double darkening where two overlap. Rejected.
3. A SubViewport shadow mask sampled by every ground cell: seamless and soft, but the screen-space mask can't tell levels apart (a shadow would show on a cliff top overlapping it on screen), so it needs a mask per level, and it waits a frame to render. Rejected for cost.
4. Swept footprint boxes for buildings, planters and crates: right geometry for boxes, but the footprint diamond is exactly a tile, so the shadow showed the grid again. Tried and dropped; silhouette shear reads better for everything.
5. Chosen: silhouette shear, merged per cell and clipped to the cell's top at the prop's level, drawn in the ground slab. Seamless by construction, shaped to each sprite, cheap (cached per texture, drawn only when ground redraws), and it needs no new art.

Sources: [Godot 2D lights and shadows](https://docs.godotengine.org/en/4.7/tutorials/2d/2d_lights_and_shadows.html) (infinite directional shadows, no height); [2D Isometric Shadows in Godot 4](https://blog.sethpyle.com/blog/2d_isometric_shadows/shadows) (a shadow projected over an isometric wall instead of up it); Godot forum and Godot Shaders threads on skewed silhouette drop shadows (shear the sprite's alpha, flat colour). The look follows what Triangle Strategy, Octopath and Into the Breach do: one flat, sheared silhouette on the ground, one direction, one opacity.

## Known limits
Shadows of terrain walls and fences are not cast, forest-skirt trees outside the map cast none, and a shadow doesn't fall on water. Graybox mode and decks cast none.

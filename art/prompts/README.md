# House-style prompt blocks

Paste a style block once into a Text node in a Picsart workflow (or keep it as a saved snippet anywhere else), and connect it to the Image node together with a second Text node that holds only this run's ask. The style block never changes between runs; the ask does.

| File | Use for |
|---|---|
| `style-terrain.txt` | Battle-map concept pictures and zone looks (pair with a map template blocking picture and `art/palettes/<zone>.png`) |
| `style-tiles.txt` | Single tile textures (tops, cliff strips) |
| `style-props.txt` | Single props (trees, rocks, ruins, campfires) |
| `style-character.txt` | Characters, monsters and bosses (pair with a mannequin view, the key view and `art/palettes/characters.png`) |
| `style-look.txt` | The exact traits of the chosen flat look (solid tops with tiny dots, three flat values, blob trees). Appended to the sheet and kit prompts |
| `style-finish.txt` | The hand-made finish (wobbly ink, mottled paint, chunky crooked blocks). Add it under any block when results look too polished; pair with `docs/art/references/style-hike-illustration.png` as a style image |
| `sheet-zones.txt` | Many zones (flat simple style) on one reference sheet (diorama plus 5 x 5 swatches each), to explore looks |
| `sheet-tile-kit.txt` | One zone as a game-ready 5 x 5 kit (tops, sides, props) with no text; see `terrain-sheets.md` |
| `ask-*.txt` | Example asks in caveman-free plain words, to copy and edit |

Rules behind every block: `docs/art/battle-maps.md` (B1 to B32) and `docs/art/characters.md` (C1 to C29). If a rule changes there, change the block here too.

## Wiring it up in a Picsart canvas

1. Add a **Text** node and paste the style block. Rename it "STYLE terrain" (or character). Don't use a **Note** for this: notes are for you and are not sent to the model.
2. Add a second **Text** node for this run's ask (start from `ask-terrain.txt` or `ask-character.txt`).
3. Add **Upload** or **Asset** nodes for the reference images: the blocking picture or mannequin view first, then the palette card (and the key view for characters). The style blocks call them image 1, 2, 3 in that order.
4. Connect both Text nodes and the images into one **Image** node. If the Image node takes only one text input, paste the style block above the ask in a single prompt instead.
5. Duplicate the whole canvas per zone or character, so only the ask and images change. **Batch** can run several asks through the same style.

Saved Flows (the "Lodestone character view" and "Lodestone turnaround" Flows in the Character Guide) work the same way: put the style block in the Flow's fixed prompt and leave only the ask as the input.

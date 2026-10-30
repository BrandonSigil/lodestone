# Menu theme

[USER] 2026-10-30: every menu looks consistent (the Lodestone menu, character sheets, the pack, options, dialogues, the world map UI), with variety where needed.

- `UiTheme.make()` (`game/scripts/ui/ui_theme.gd`) builds the one shared Theme. `Game._ready` merges it into the engine's default theme, which every Control without its own theme falls back to. (A theme on the root window doesn't reach Controls under a CanvasLayer, which is where all the HUDs live.)
- Use these instead of hand-made styles: `theme_type_variation` `DialogPanel` (dialogues, the Lodestone menu, PACK), `MenuPanel` (small menus by a piece, the fight's action bar), `InfoPanel` (forecasts, read-outs), `TipPanel` (hover cards; Godot's own tooltips match), and for Labels `MenuTitle` and `SubTitle`. Buttons need nothing.
- On it now: explore and overworld dialogues, the Lodestone menu and PACK (`AdventureMenu` titles), the fight's menu, forecast and action layouts.
- Variety kept on purpose: the riso screens (launch menu, village, world map scene) keep `RisoTheme`; the character sheet keeps its parchment design; the bottom frame is painted art. Fold any of them in when Brandon says.
- Art: when Brandon picks the art runner's menu style, its nine-slice pieces go in `game/art/source/ui/menu/` under the names in `UiTheme.PIECES` (`panel.png`, `panel_small.png`, `panel_info.png`, `tooltip.png`, `button*.png`) and replace the flat boxes with no code change; the margin per piece is in the same table.
- No options screen exists yet; when it comes, it uses these variations.

# Menus v3: a drawn skin, one window, layout that sizes itself

[AI] 2026-11-13, a proposal with a working prototype on branch `menus-prototype` (worktree `~/lodestone-menus`). Nothing here is decided until Brandon says so.

[USER] 2026-11-13, the ask: "prototype a new set of menus throughout the game. Right now they look very "jpeg's pasted onto a frame", and I'd like them to feel more baked into the game, more dynamically sizable, and just AAA clean feeling. Theyre very clunky, very bulky, very amateur looking. Comb through them all and suggest a better approach please".

Before and after pictures of every menu: `art/screens/menus-v3/` (left is main today, right is the prototype).

## What I found (29 screens shot from main)

The trouble is not one screen. It comes from how every screen is built.

1. **The frame is a picture.** Every window wears `look_panel.png`, a painted frame shrunk to 30 to 45% and cut into nine pieces. So the rim is the same heavy band on a 220 px loot window and on the win screen, it goes soft when shrunk, and every window carries four gems and eight leaves whatever its size. The frame costs about 30 px a side before any content. The bottom frame (`frame_bottom.png`) and the fight dock (9 painted pieces) work the same way.
2. **Windows are sized by scaling, not by layout.** `KIT_SCALE` draws every window at 90%, and a window that does not fit is shrunk further, down to whatever fits. Text is drawn at one size and then resampled, so it lands off the pixel grid and looks soft. A window can only get smaller as a whole; it can never give its content more room or reflow it.
3. **There are six ways to make a window.** `UiTheme.frame_window`, `MenuKit.window`, the pack view (draws its own frames and title plates), the character sheet (paints itself, with its own cream plates), the fight's side panel (a flat grey box) and the fight dock (painted pieces). They do not share padding, title placement or where the X goes, so no two screens line up.
4. **Six looks on screen at once.** In a fight you see the painted bottom frame, the painted dock, a grey text panel, an empty bordered log box and flat test buttons. The character sheet is a third look (cream plates). The launch menu is a fourth.
5. **Everything is a rimmed pill.** Options, buttons, chips, stats and tags all get the same rounded rim, so nothing reads first. Sizes are numbers typed into each screen (text from 11 to 40 px), and a lot of text sits at 10 to 12 px in a display serif that is hard to read that small.

Screen by screen:

| Screen | What is wrong |
|---|---|
| Pack and party, pack and loot, found items | Two framed windows side by side at different heights, each with its own title plate and X. The party window is half empty. With a full party the pair runs off the bottom of the play area and is cut (`pack_big`). |
| Lodestone menu | Five buttons of equal weight in a two-wide grid, CLOSE among them. Member cards at 11 px. A skill pick opens inside the same small window and scrolls. |
| Options | Left-aligned in a window sized for something else; full-width buttons for one-word choices. |
| Village repairs | Rows of small caps text with a button each; buildings with nothing to do still take a row. |
| Character sheet | Its own look. Empty cream plates, a description cut off mid-sentence. |
| Fight | The side panel is a paragraph of stats. The dock's labels are about 7 px. The log box is mostly an empty rectangle. |
| Dialogues, night camp | Sound structure. They only suffer from the frame and the pills. |
| Win, level up, HOME AGAIN | The best three. Bar labels are small; HOME AGAIN after a fall scrolls inside its window and cuts the MORALE card. |
| Bottom frame | A tall painted band whose leaves cover the map's corners; the goals bar is empty most of the time. |

## The approach

**1. Draw the skin, don't paint it.** Panels, buttons, chips, slots, the bottom bar and the dock are drawn by the engine from one small set of tokens (colour, radius, spacing). A drawn rim is one pixel on a tooltip and on the win screen, sharp at any size, and can light up, pulse or animate. The look keeps Brandon's own vocabulary: deep green, the cream-gold line, the blue diamond gem, Young Serif. The leaves and the heavy banded rim go.

**2. Let the game show through.** Each window is dark glass over a blurred copy of what is behind it, with a soft shadow. That is what makes a menu feel part of the scene instead of laid on it, and it keeps text readable over a busy map.

**3. One window, used everywhere.** A single shell: title on the top edge, X in the top right corner, body, then a foot row with the one gold button on the right. Every screen uses it. No screen draws its own frame.

**4. Size by layout, never by scale.** Windows take the size their content needs between a minimum and a maximum, and scroll past that. Text is never resampled. Sizes come from a short scale (about 13, 15, 18, 24, 32) and gaps from one unit (8 px), not from numbers typed per screen.

**5. One loud thing per window.** The button to press is solid gold with dark words. Everything else is quiet: plain rows, a hairline on hover. Chips are for values only.

**6. Fewer windows.** The pack and what is beside it (loot, found items, the party) become one window with two sections, as the win screen already does. Lodestone, pack, village repairs and options become tabs of one menu, so they share a place and a size.

## What the prototype does today

The prototype is step 1 and 2 applied to the whole game without touching any screen's own code, so the difference shown is the skin alone.

- `game/scripts/ui/ui_skin.gd` (`UiSkin`): the tokens and every style. `UiTheme.make` lays it over the theme last.
- `game/scripts/ui/skin_box.gd` (`SkinBox`): the drawn panel (shadow, ink line, gold hairline, glass, the gem).
- `game/scripts/ui/skin_backdrop.gd` and `game/shaders/skin_backdrop.gdshader`: the blurred world behind a window. `UiSkin.watch` adds one under every window as it opens.
- The bottom frame (`FrameHud._draw_skin_bar`), the fight dock and its portrait, the fight's side panel, the pack view's windows, the character sheet's frame and the close X all have a drawn version.
- The painted art is untouched and still in the game. `LODESTONE_SKIN=old` in the environment brings the painted look back.

To see it: `cd ~/lodestone-menus && /Applications/Godot.app/Contents/MacOS/Godot --path game`. For the old look, put `LODESTONE_SKIN=old` in front.

## What it does not do yet (honest notes)

- **Layout is unchanged.** The two-window pack, the Lodestone button grid, the sheet's cream plates, the fight's text panel and the small text are all still there, just in the new skin. Those are steps 3 to 6.
- **Windows are still scaled to 90%**, so text is still slightly soft. That goes when sizes come from tokens.
- The bottom bar keeps the painted frame's height and slots, because the screens measure from them. It can be made slimmer once dialogues stop measuring from the art.
- The launch menu and the map maker are not touched.
- The blur reads the screen once per frame. It ran fine in every shot (Compatibility renderer); it has not been measured on the Windows PC.
- Not look-checked by a second reviewer yet, and Brandon has not seen it.

## If Brandon likes the direction, the order I would build it

1. Tune the skin with him (how dark the glass, how much gold, gem or no gem).
2. The one window shell and the size and spacing tokens; move the dialogue, win, level up and HOME AGAIN screens onto it and drop `KIT_SCALE`.
3. Pack rebuilt as one window with sections (this was already the next UI job; it fixes the cut-off with a full party).
4. The Lodestone menu as tabs: Party, Pack, Village, Options.
5. The character sheet on the kit.
6. The fight HUD: side panel as a compact card, dock labels readable, the log as a quiet line.

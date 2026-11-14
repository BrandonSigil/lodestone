# Menus v3: a drawn skin, one window, layout that sizes itself

[AI] 2026-11-13, a proposal with a working prototype on branch `menus-prototype` (worktree `~/lodestone-menus`). Nothing here is decided until Brandon says so.

[USER] 2026-11-13, the ask: "prototype a new set of menus throughout the game. Right now they look very "jpeg's pasted onto a frame", and I'd like them to feel more baked into the game, more dynamically sizable, and just AAA clean feeling. Theyre very clunky, very bulky, very amateur looking. Comb through them all and suggest a better approach please".

[USER] 2026-11-13, on the first drawn skin: "Yes I like these A LOT MORE, but now can we fold back in just a bit more high-fantasy/painterly look? Some transparency is fine, but it reads a bit like glassmorphism that doesnt quite fit the painterly vibe. Also just a little bit of like diamond shaped flourishes on major frames or something like around the "Level up!" or "Loot" "Pack. Also the bottom menu that's pretty persistent throughout the game is now a little too generic. The original version was too much, but now it's a little too techy or generic looking. I liked the ornate framing, the big diamond in the middle (which should be clickable because it's the "Lodestone" menu opener. And the leaf embossing stuff on the left/right is gone and I miss something like that".

[USER] 2026-11-13, on round two: "This is a lot better, but make the marbling green even more subtle. Like closer to a flat green with just a hint of texture/marbling than what there is now".

[USER] 2026-11-13, after round two: "Start layouts" (the next-step button).

Before and after pictures of every menu: `art/screens/menus-v3/` (left is main today, right is the prototype as it stands). `_layout_1.jpg` and `_layout_2.jpg` put main, round two and the first layouts side by side. `_show_1.jpg` to `_show_3.jpg` are from round two (main, the first drawn skin, round two); `_bar_close.jpg` does the same for the bottom bar. `_tabs_`, `_sheet_` and `_hud_` are rounds four to six.

[USER] 2026-11-13, after round three: "Yes, tabs next" (the next-step button).

[USER] 2026-11-13, after round four: "Yes, sheet next" (the next-step button).

[USER] 2026-11-13, after round five: "Yes, fight HUD" (the next-step button).

## Round six: the fight HUD

Pictures: `_hud_1.jpg` (left the fight as it stood after round five, right now: the hero's abilities popped up in a crypt fight, then a road fight), `_hud_2.jpg` (the side card with the pointer on a foe, aiming a spell, the log open, the foes' turn), and `fight_dock.jpg` and `road_fight.jpg` (main | now).

- **The side card** (`FightCard`, built by `FrameHud.fight_side`). The old side box printed a paragraph (`Battle.unit_text`) over two full-width buttons. The card reads data instead (`Battle.unit_card`, `Battle.tile_card`): whose turn and the round on top; END TURN, the one gold button, with DANGER beside it; then the piece's name, HP and its resource as bars, six numbers as a quiet grid, and a row a move with what it costs.
- **The buttons never move.** They sit above the piece, so the card grows and shrinks under them as the pointer moves. END TURN sleeps on the foes' turn. DANGER stays lit while the danger tiles are on. Both say their key in a hover tip.
- **Who the card shows.** The piece under the pointer, else the piece picked. A bare tile under the pointer adds one quiet block under the piece (the tile's name, height, step cost, cover, or what lands there) instead of replacing it, so the card no longer flips between a piece and a tile. While a move is being aimed its row is gold and the card says AIMING.
- **The dock is laid out at its real size.** It used to be built small and scaled to 75%, so the words under its boxes drew at about 7 px and soft. Under the skin nothing is scaled (`ActionHud.drawn_scale`): boxes are 46 px, the words under them 13 px, as wide as their longest word. The UI size option still sizes it (`ActionHud.grow`).
- **The portrait card** is a small window: the face, HP as a bar and the resource as pips, each with its number at 13 px (they were about 7).
- **A pop-up column is a short list**: each box with its name beside it on one line, the name clickable too. Three spells are 150 px tall where they were 250.
- **The details panel** (bottom left, on a rest over a box) is at its real size too: 13 px lines.
- **The log is one quiet line**, the newest thing that happened, bottom right on a soft ink pill as wide as its words. A click opens the whole log in a small window over it; HIDE LOG puts it away. The empty bordered box is gone.
- **The two test buttons** are one small row at the top right, each as wide as its words.
- `LODESTONE_SKIN=old` keeps the old side box, the painted dock and the boxed log.

## Round five: the character sheet on the kit

Pictures: `_sheet_1.jpg` (left the sheet as it stood after round four, right now: the smithy rack's sword page, then the dog's sheet) and `character_sheet.jpg` (main | now).

- **A kit window.** The sheet used to paint itself: a fixed 720 by 430 picture of cream plates, scaled to fit. It is now the window the level up screen uses (`MenuKit.window`): the name on the title banner, the X or Esc to close, real controls laid out at their own size, and it scrolls before it would ever shrink (`CharacterSheet`, placed by `UiTheme.place`).
- **Left, the character's card**, as on level up: the portrait, the job, the level as a chip, HP and EXP as bars, the trail skills as chips (hover says what they are).
- **Right, the numbers as chips** with the level up window's words and icons: DMG, ARMOR, CRIT, RANGE, MOVE, then the weapon and the job's resource.
- **A row a skill**, with its icon, its damage, reach and cost as chips, and its whole line under it. The old rows cut the line off mid-sentence and drew empty plates for skills a character does not have.
- **The rack's foot.** The arrows and the page count on the left, the gold TAKE on the right (IN HAND or LOCKED when it cannot be taken). The CLOSE button is gone: the X does it.
- **The portrait slot** is unchanged in what it shows. A full-length pose now stands on its own background colour across the whole slot instead of on a strip.

## Round four: the Lodestone menu as tabs

Pictures: `_tabs_1.jpg` (the four tabs: party, pack, village, options) and `_tabs_2.jpg` (five along on the party and pack tabs, the NEW ABILITY window, and the pack before the Lodestone).

- **One window, four tabs.** With the Lodestone in hand, PARTY, PACK, VILLAGE and OPTIONS are tabs of one window titled LODESTONE (`AdventureMenu.open`, `MenuKit.tabs`). One title, one X, one place. The bag button and I open it on PACK, the big diamond on PARTY. The open tab is gold with a diamond on the rule under it; a gold stud by PARTY says a skill is waiting.
- **One size.** Every tab's page is built and only the open one shows (`MenuKit.Stage`), so the window is as big as its biggest page and does not jump when the tab changes.
- **PARTY.** The member cards, three to a row at most, then blessings, the meal and bonds. SAVE AND QUIT and GO HOME stand on the foot. The VILLAGE REPAIRS, OPTIONS and CLOSE buttons are gone: the tabs and the X do that.
- **NEW ABILITY has its own window.** It used to open under the cards and scroll inside the menu. It now opens the window a level up shows (`LevelUpUi.open`, titled NEW ABILITY!) in the menu's place. Decide later, the X and Esc bring the menu back. A job branch still shows over the cards.
- **PACK.** The pack page from round three. With more than three along, the use rows (EAT, DRINK, CAST) and the counts stand under the pack grid instead of under the party rows, so the page is about 100 px shorter and five along fit with the tabs above them. That also fills the felt that sat empty under the pack.
- **VILLAGE.** A card a building. A step shows DONE, IN PROGRESS, or what it still needs as chips (the thing's picture and have / need, gold once there is enough) with TRACK beside them. The list scrolls inside the tab and keeps its place when TRACK rebuilds it.
- **OPTIONS.** A row an option, its name on the left. The screen row shows WINDOWED and FULLSCREEN with the one in use lit, where it used to be one button naming the other mode.
- **Esc closes it** through the X's action (`UiTheme.press_close`, panel meta `esc_close`). The full pack (FOUND ITEMS) is left out on purpose: its way out leaves things on the ground.
- **Where it does not apply.** Before the Lodestone is found the pack opens alone, as before. FOUND ITEMS and the pack stay their own window. `LODESTONE_SKIN=old` keeps the four separate menus.

## Round three: the first layouts

- **Nothing is scaled.** Kit windows used to be drawn at 90% (`UiTheme.KIT_SCALE`), which resampled every word. The scale is now 1.0 and the tenth came off the sizes themselves, so windows are the size they were and their words sit on whole pixels. A window is shrunk only as a last resort, when it cannot fit even after its inside has scrolled (`UiTheme.fit_scale`).
- **Five text sizes.** `UiSkin.T_SMALL` 13, `T_BODY` 15, `T_LEAD` 18, `T_HEAD` 24, `T_TITLE` 32. The kit's pieces (`MenuKit.label`, `chip`, `primary`) snap whatever they are given to these, so the 10 to 12 px text is gone. One exception: a graybox item with no icon still writes its name small inside its cell.
- **The title is always on the top edge.** WIN, LEVEL UP! and HOME AGAIN already wore a banner across the rim (`MenuKit.window`); the Lodestone menu, options and village repairs now do too (`MenuKit.title_on`), instead of a plate inside the window.
- **A window's inside scrolls to its real room.** `frame_window` measures everything that is not the scroll (frame, head, foot row, the banner standing over the rim) and caps the scroll to what is left, so no window runs off the play area and none is shrunk to make it fit.
- **Pack screens are one window.** Pack and party, a chest or loot and the pack, and FOUND ITEMS and the pack were each two framed windows with two title plates and two X's. Each is now one window with two sections (the win screen's LOOT and PACK headings), one X, the same height both sides (`ContainerUi.panes`, `AdventureMenu.pack`). The container or loot stands on the left and the pack on the right, as on the win screen. The dog's saddlebag sits beside the pack in its own inset under his round face, as on the win screen. With a full party the window fits; if it ever does not, it scrolls.
- **Sizes.** Dialogue option rows are 44 px, the close X 24 px, window padding 20 by 18, section padding 18, gaps mostly 8 and 12.
- **Test runs are silent** (Brandon: "In any testing you do with Lodestone, please mute it"): `tools/godot.sh` adds `--audio-driver Dummy`.

## Round two: what changed after his notes

- **Felt, not glass.** Windows are near-solid deep green (93 to 95%), nearly flat, with only a hint of brushed grain (`SkinBox.GRAIN`, 0.07; it tiles, so it is the same texture on a tooltip and on the win screen). The blurred world behind is still there but barely shows.
- **A fantasy rim, still thin.** Ink, a bevelled gold band, a dark gap and a cream hairline that steps in round a gold stud at each corner: about 8 px in all, the same on every window. Dialogues and big windows carry the blue diamond on a gold swell on the top edge and a small stud on the foot.
- **Diamonds on titles and headings.** A title (LEVEL UP!, WIN, PACK, LOOT, LODESTONE) is a banner with pointed ends and a blue diamond either side of the words. A section heading's rules (LOOT and PACK on the win screen) run out from a gold diamond and fade.
- **The bottom bar.** Felt; a rim of gold over a blue band (the painted frame's colours); a laurel either side of a big faceted diamond; a spray of three leaves over a gem in each end; gold-rimmed wells with a stud each side for the pack and the party. All drawn in code with the leaf the old code-drawn frame already had (`FramedBox._leaf`), so no art file is touched.
- **The big diamond opens the Lodestone menu.** It is a button (`FrameHud.leaf_stone`): it lights under the mouse, pulses while a skill waits to be picked, shows the word LODESTONE under it, and is grey with no word before the stone is found and in a fight. The LODESTONE button that sat above the bar's right end is gone when the drawn skin is on.

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

**2. Let the game show through, a little.** Each window sits over a blurred copy of what is behind it, with a soft shadow. Round one made the window dark glass; Brandon read that as glassmorphism, so the fill is now near-solid felt and the world shows only faintly.

**3. One window, used everywhere.** A single shell: title on the top edge, X in the top right corner, body, then a foot row with the one gold button on the right. Every screen uses it. No screen draws its own frame.

**4. Size by layout, never by scale.** Windows take the size their content needs between a minimum and a maximum, and scroll past that. Text is never resampled. Sizes come from a short scale (about 13, 15, 18, 24, 32) and gaps from one unit (8 px), not from numbers typed per screen.

**5. One loud thing per window.** The button to press is solid gold with dark words. Everything else is quiet: plain rows, a hairline on hover. Chips are for values only.

**6. Fewer windows.** The pack and what is beside it (loot, found items, the party) become one window with two sections, as the win screen already does. Lodestone, pack, village repairs and options become tabs of one menu, so they share a place and a size.

## What the prototype does today

The prototype is step 1 and 2 applied to the whole game without touching any screen's own code, so the difference shown is the skin alone.

- `game/scripts/ui/ui_skin.gd` (`UiSkin`): the tokens and every style. `UiTheme.make` lays it over the theme last.
- `game/scripts/ui/skin_box.gd` (`SkinBox`): the drawn panel (shadow, ink line, gold band, felt, the inner line and corner studs, the gem, the title banner), and the shared `jewel` and `stud`.
- `game/scripts/ui/skin_backdrop.gd` and `game/shaders/skin_backdrop.gdshader`: the blurred world behind a window. `UiSkin.watch` adds one under every window as it opens.
- The bottom frame (`FrameHud._draw_skin_bar`, with the Lodestone diamond `leaf_stone`), the fight dock and its portrait, the fight's side panel, the pack view's windows, the character sheet's frame and the close X all have a drawn version.
- The painted art is untouched and still in the game. `LODESTONE_SKIN=old` in the environment brings the painted look back.

To see it: `cd ~/lodestone-menus && /Applications/Godot.app/Contents/MacOS/Godot --path game` (not `tools/godot.sh`: that is the silent, invisible copy for test runs). For the old look, put `LODESTONE_SKIN=old` in front.

## What it does not do yet (honest notes)

- The fight HUD was checked in ten screenshots and by tests; nobody has played a fight with it yet. Never run by hand: clicking a name in a pop-up list, the log opening on a click during play, DANGER from the card.
- The dock is wider than it was (readable words need the room): about 380 px for five boxes where it was 320, plus the portrait card. With many boxes on a narrow window it has not been checked.
- A tile's name on the side card is still the engine's word for it (STONE, VOID); they have no text keys yet.
- The fight's list layout (the UI: LIST test button), the forecast box and the round banner are untouched.
- The sheet's skill rows say DMG, reach and costs in the level up window's words; the unarmed hero's sheet is one row with plain felt under it.
- The sheet was checked in four screenshots (the hero, the dog, two rack pages) and by tests; nobody has opened it in live play yet.
- The tabs have no keys of their own yet (the left and right keys walk them once one has the focus); a pad's shoulder buttons would be the usual way.
- The OPTIONS tab is short, so most of its page is plain felt when the pack makes the window big.
- A PACK tab sits beside a PARTY section inside it. The names are right but close; worth a look in play.
- The tabs were checked in screenshots, by tests and by the play-through robot (which never opens them); nobody has clicked through them in live play yet.
- Many sizes were converted by rule (old size times 0.9, to the nearest step); each screen was looked at in a screenshot, not tuned by hand.
- `LODESTONE_SKIN=old` still swaps the painted frames in but no longer matches main's sizes. Compare against main for a true before.
- The bottom bar keeps the painted frame's height and slots, because the screens measure from them. It can be made slimmer once dialogues stop measuring from the art.
- The launch menu and the map maker are not touched.
- The blur reads the screen once per frame. It ran fine in every shot (Compatibility renderer); it has not been measured on the Windows PC.
- The big diamond replaces a labelled button, so a new player has only the word under it and the hover tip to learn what it is. Worth a first-time hint when the stone is found.
- Not look-checked by a second reviewer yet. Brandon has seen rounds one and two as pictures, not in play.

## If Brandon likes the direction, the order I would build it

1. Tune the skin with him (done twice, above; more rounds as he asks).
2. Done (round three): the size and type tokens, titles on the top edge, scroll to the real room, `KIT_SCALE` dropped for dialogues, win, level up, HOME AGAIN and the menus.
3. Done (round three): pack, loot and found items as one window with sections (it fixes the cut-off with a full party).
4. Done (round four): the Lodestone menu as tabs: Party, Pack, Village, Options.
5. Done (round five): the character sheet on the kit.
6. Done (round six): the fight HUD: the side panel as a compact card, the dock at its real size with readable words, the log as a quiet line.

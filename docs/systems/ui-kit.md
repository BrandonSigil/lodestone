# The menu kit

[USER] 2026-11-02: Brandon approved the four round 2 mockups (`docs/art/references/menus/r2_*.webp`, "LOVE THIS"). They are the kit's look. Code: `game/scripts/ui/menu_kit.gd` (`MenuKit`), wired into the shared theme by `UiTheme.make` (`MenuKit.style`). Research behind it: `docs/design/menus-research.md`.

## Look
- **Window**: Brandon's painted frame (`look_panel.png`). Its green felt is drawn darker and a touch see-through (`MenuKit.FELT`, `FELT_ALPHA`; `UiTheme._darken_felt` recolours the loaded copy at load time, and the art file is never touched). This applies to `DialogPanel`, `MenuPanel` and `TipPanel`, so every window in the game wears it ([USER] 2026-11-01: "a darker green with a touch of transparency").
- **Bright green** only on the `TitlePlate` (the one call-out). Buttons are never bright green (round 2 flag).
- **Buttons**: dark with a thin pale rim. Under the mouse or the keys the rim lights gold and glows. `PrimaryButton` (the one to press: CONTINUE, ONE MORE GO, TAKE ALL) always wears the gold rim. `QuietButton` (LEAVE, BACK OFF, SHOW ALL) is dimmer, but its words stay easy to read (the LEAVE flag).
- **Pieces**:
  - `KitCard`: a section card.
  - `KitChip`: a pill for "+3", "60%" or "0/4".
  - `KitSlot`: an item slot.
  - `KitHeading`: a section heading. `heading_row` adds rules either side.
  - `portrait(id, px, round)`: round or square, with a graybox head-and-shoulders until art exists.
  - `UiBar` and `bar_row`: a thin bar (10 px, [USER] 2026-11-02 "all the HP/Mana/Morale bars can be overall thinner"), its number beside it on the right, the label outside on the left. Every character's bars in the menus show HP, mana or rage, and Morale (the Lodestone cards gained the resource bar).
  - `XButton`: the round blue X.
  - A thin themed scrollbar.
  - Drawn glyphs (`@talk`, `@plus`, `@leave`, `@dot`) where no icon art exists yet.

## Size
- [USER] 2026-11-02 X20: "Text feels huge right now, things are just too big everywhere". Every kit window and dialogue stands at `UiTheme.KIT_SCALE` (0.9) at most: the win screen, HOME AGAIN, every dialogue on the diamond, the menus at the top (Lodestone, options, pack and loot windows). They still shrink further to fit their room. Text, slots, bars and buttons come down together, so nothing changes shape. Level up is the exception: its text was cut by hand to 11 to 16 px, so it stands at full size (the look check found it too small at 85%). The fight dock keeps its own size and option (`UiTheme.small()`). HOME AGAIN sits in a container, which resets a child's scale on each layout, so it sets its scale after `sort_children`.
- [AI] 2026-11-13, menus v3 (branch `menus-prototype`, `docs/design/menus-v3.md`): the 0.9 is gone. `UiTheme.KIT_SCALE` is 1.0 and every kit size is that tenth smaller instead, on five text sizes (`UiSkin.T_SMALL` 13 to `T_TITLE` 32), so nothing is resampled and nothing is bigger than X20 left it. Windows scroll their inside to fit and are shrunk only if they still cannot (`UiTheme.fit_scale`). Pack screens are one window with two sections (`ContainerUi.panes`).

## Place
- [USER] 2026-11-02 on ui-kit-size-review: "make sure that Menus have a reliable location. Like total center of the play screen (besides the combat taskbar UI)". Every menu stands in the middle of the play area above the bottom frame (`UiTheme.centre_menu`, or `keep_inside(..., centred)`): the Lodestone menu, options, village repairs, and the paired pack / loot / FOUND ITEMS windows (`ContainerUi.bare` marks them `menu`, drops the diamond pointer, and centres them when no host does). The big windows (win, level up, HOME AGAIN) were already centred there. Dialogue prompts still stand on the diamond.

## Loot left on the map
- [USER] 2026-11-02 on ui-found-items-close: loot left after a fight stays on the main foe's body where it fell (the boss, else the leader, else an elite, else the toughest), drawn lying down with loot sparkles (`ExploreOverlay._sparkles`). FOUND ITEMS' X and LEAVE REST HERE set its things down as a pile at the party's feet, sparkling too, and it can be reopened after making room. Piles last while the party is on that map. An opened chest with things left in it stays a chest, with no sparkles. Shots: `explore_shot.gd` `pile_body`, `found_left`.

## Structure
- `UiTheme.frame_window(panel, content, area, close, title)`: every framed window. The X floats on the top right corner, beside the gem (`X_RIGHT`, `X_TOP`). An optional call line is centred at the top. The content scrolls once it passes the room. The fit is a small node on the scroll (`_Fit`), so its deferred calls die with the window.
- `MenuKit.window(title, area, close, px, scroll_room)`: a big window. The title plate straddles the top rim, and the X sits at the top right. `foot` is under the scroll, so the primary button never scrolls away and sits clear of the corner leaves. Used by HOME AGAIN and the win screen.
- `MenuKit.dialogue(panel, text, area, face_id)` and `MenuKit.answer(box, text, cb, chip, tip)`: the one dialogue call/response screen, used for explore events, locked and trapped chests, talks and recruits, overworld events and the camp, and a fight's plain win or lose.
  - A call line of 44 characters or fewer is the heading (mockup A). Longer words are body text.
  - With a portrait, the framed face sits on the left, with the speaker's name over the words (mockup B).
  - Each answer gets its icon from its words (`OPTION_ICONS`). The odds go in a chip on the right, and who rolls shows on hover.
  - The way out is quiet. The first answer has the keys' focus.
  - It stands on the diamond with a point aimed at it (`pointer`).
  - The conditional options rule is unchanged: an option shows only when its condition holds.

## Screens
- **HOME AGAIN** (`HomecomingUi`, mockup C): three cards, BROUGHT HOME (slots and +N chips), PARTY (face, level, XP bar in the member's tint, +XP) and HEART (face, then thin HP, energy and Morale bars from the run's member, then ±N; then bond pairs). Bars carry no numbers here (they show on hover); PARTY's XP bars wear each member's own tint, as in mockup C. Four rows show, then SHOW ALL (`UI_HC_SHOW_ALL`). Each card scrolls with whole rows in view (the clipped fourth row flag). The journey days show on the heading's hover. A boss card, knowledge and restored steps form a second row; on a fall it leads, and the cards get shorter (`COL_H_SHORT`). The foot holds NEXT GOAL chips ("2/3" with the item's icon) and the gold OK button. Shot: `homecoming_shot.gd` with `full`, `home` or `fell`.
- **Win** (`VictoryUi`, mockup D): one big window in the play area above the bottom frame, which stays in view (the "no bottom frame" flag). The dim covers only that area, and the fight's own buttons and side panel are put away (`Battle.hide_ui`).
  - Left: the party cards. Two cards stack; three or four go two across. Each card has a round face with an LV chip, the name, and HP, resource, EXP (value/100) and Morale bars (Morale always, with its change).
  - Right: LOOT and PACK side by side as sections of the window (`PackView.sections`, `ContainerUi._beside`). Each grid starts right under its heading; one foot row sits under the tallest grid, with TAKE ALL (gold) centred in the loot card and the party's gold as a chip centred in the pack card, and the cards end just under it, all one height (`PackView.stretch_sections`; the look check 2026-11-02 failed both centred grids and stretched cards for dead felt). The cell size is fitted to the party column's height (`VictoryUi._cell`, 56 to 84 px), so the cards come close to its foot. The dog's saddlebag stands beside the pack in its own inset as tall as the pack grid, his round face over his 2x2 (Brandon's ask: "just a doggo pic"). Stack counts light with a dark outline.
  - The foot row, level with the party column's foot: EXP and GOLD chips beside OK, all 48 px tall, OK's right edge level with the pack card's.
  - The window shrinks to 85% before its inside scrolls.
  - The repeated-party-card flag was a mockup slip: each card is its own member.
- **Everywhere else**: pack and loot windows (`PackView`) use dark kit slots, kit party cards, a dark dashed-red THROW AWAY, a gold TAKE ALL and the round X. The Lodestone menu, level up, the gate picker, village work, options and the character sheet pick up the dark felt and kit buttons through the theme.
- Loot windows (`ContainerUi.fitted_grid`) prefer a shape wider than tall, so a drop never becomes a one-cell column.
- A box on the diamond keeps `UiTheme.DIAMOND_GAP` (14 px) above the frame for its point.
- **Level up** (`LevelUpUi.open`, a `LevelUpUi.Screen`; [USER] 2026-11-02 X20 on dev-levelup-kit-review: "You should see the characters 4 abilities verticall with horizontal upgrade nodes so you can see how much youve invested in each skill", "Text feels huge"): one kit window, LEVEL UP! on its plate, the X and Esc as Decide later. Left: the character's card, centred (round portrait, name, "Level 1 to 2", stats gained as green chips, thin HP / energy / Morale / EXP bars, then DMG, ARMOR, CRIT and MOVE now as chips, a gain in green). Right: the skill board (`LevelUpUi.picks`), one row per skill, stacked: icon, name in capitals, a small tag (Rank n, Max rank, Coming later) or a green NEW SKILL pill, then its rank track (`_Nodes`, five diamonds, [USER] 2026-11-02: solid gold owned, green the rank this pick buys, glowing with a +1 on the selected row, dim later, a faint dashed outline for a rank not in `ability_upgrades.csv` yet). Skills already at their last rank show too. Under the rows a detail strip (what it does, its numbers now as chips, this pick with its before and after, the next rank in words; no "last rank" line, the track shows it), then Decide later (quiet) and the gold Learn Skill (one word for every pick, [USER] 2026-11-02). Text runs 11 to 16 px. Explore and road fights open it; the Lodestone menu's decided-later picks use the same rows. Shots: `explore_shot.gd` `levelup`, `levelup_dog`, `levelup_ranked`, `lodestone_pick`.
- `UiBar` keeps a fixed number column (as wide as "000/000"), so a stack of bars ends at one edge.
- **Fishing** ([USER] 2026-11-02 X19: "Fishing shouldnt be a menu. It should be the whole screen with our regular party frame at the bottom"): `FishingGame.open(..., room, bar)` fills the play area (`FrameHud.clear_rect`) with the pond, the party frame left in view under it; no window, title, headline or key hints. Leave fills the frame's long bar (`FrameHud.bar_rect`) in every beat: before the cast it leaves free, once a fish has noticed or is on it counts as lost. The reel bar and the gold Catch meter sit on the near shore in the frame's teal and cream keyline. The first time anyone fishes, a how-to opens in the one dialogue screen (meta flag `seen_fishing_tips`, then never again). The pond is still graybox.


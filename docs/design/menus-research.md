# Menu research: how dense games keep their screens readable

Written 2026-11-01 for the menus overhaul (backlog X11, decisions.md "Menus overhaul"). Brandon's bar: "Does this look like a professional AAA but indie video game?"

This is a research note and a proposal. Everything under "Recommendation for Lodestone" is an `[AI]` proposal until Brandon retags it. No story or flavor text is written here. Words in quotes from the game ("HOME AGAIN", "SNEAK HIT", "TAKE ALL") are existing UI strings used as examples only.

## How to read the evidence

Web search for UI detail was patchy. Game UI Database (the best reference for screenshots) blocks automated fetches, so I could not pull its pages ([overview of the site](https://80.lv/articles/game-ui-database-collecting-references-to-inspire-designers/)). Where I rely on how a game looks in play and could not find a written source, I mark it **(from play)**. Treat those as "go check this on Game UI Database or a playthrough", not as proven fact. Where a source is a forum thread or a review, I say so. Numbers for text size come from Valve and Microsoft documents and are solid.

## The short version

1. The HOME AGAIN page is a document, not a screen. Every line has the same weight, it lists everything instead of what changed, it cannot scroll and it has no X. Fix the rules first (fit, scroll, X, size floor), then the layout.
2. Good results screens do three things: show only what changed, show it as portrait plus icon plus number, and reveal it in a short sequence that one key press skips.
3. Dense games survive by progressive disclosure: a clean surface of icons and numbers, with detail on hover, right click or a Details tab.
4. A small team can reach "AAA indie" with about 14 reusable pieces built once. The look comes from the frame art and a strict type and color system, not from more ornament.
5. Our `keep_inside` helper shrinks a box to fit. That is the wrong tool once text drops below a readable size. Scroll or page instead.

## 1. Post-battle and end-of-trip results screens

**What the sources and play show**

- **Stardew Valley** ends each day with a short, fixed sequence: the shipping tally, then a skill level-up popup the next morning that also grants recipes ([wiki on skills](https://stardewvalleywiki.com/Skill)). Each beat is one idea. A bug thread shows what happens when the order is wrong: the tally showed a profession bonus that had not reached the wallet ([forum thread](https://forums.stardewvalley.net/threads/bug-inconsistency-with-shipping-summary-professions-and-actual-money-earned.5064)). Lesson: the numbers on a results screen must match the numbers the game applies, in the same order.
- **Darkest Dungeon** hangs its results on the town. XP (Resolve XP) is only earned by finishing the quest, and stress relief happens in the town buildings, so the results are spread over places the player visits instead of dumped in one report ([Resolve page](https://darkestdungeon.wiki.gg/wiki/Resolve)). The roster card carries the portrait, a stress bar and a few icons. **(from play)** the post-quest screen lists each hero with a portrait and small numbers, nothing like a paragraph.
- **Slay the Spire** puts the reward in a short vertical list of icon rows (gold, potion, relic, card). You click a row to take it, and a Proceed button leaves. The reward list is the whole screen. **(from play)** Its developers' recent top-bar rework made hit areas 25% bigger and shortened labels, because players found small targets and icons hard to read on phones ([Mega Crit update](https://megacrit.com/news/2024-11-07-neowsletter-issue-4)).
- **Unicorn Overlord** is praised by several reviewers for menus that stay readable with a lot of data on screen, and its stage results are tied to performance ([Exputer review](https://exputer.com/reviews/unicorn-overlord/), [Inverse](https://inverse.com/gaming/unicorn-overlord-strategy-rpg-playstation-plus)). A few reviewers also found some screens busy, so it is a good model, not a perfect one.
- **Fire Emblem** level-ups show a stat list where only stats that rose get a green arrow ([GameWith guide](https://gamewith.net/fire-emblem-three-houses/article/show/10329)). That is the "only show what changed" rule in its smallest form.
- **Players' own complaints** about results screens are consistent. On the Gems of War forum, players ask for all rewards on one screen, for extra detail to be optional and one click away, and for a fast-forward that jumps to the summary ([victory screen thread](https://community.gemsofwar.com/t/victory-a-better-screen/61526), [reward consolidation thread](https://community.gemsofwar.com/t/consolidating-post-match-rewards-stones-glory-gold-souls-keys-maps/3259)). A Starbound forum thread says holding a button to skip is tedious and a single press is better ([thread](https://forums.playstarbound.com/threads/battle-animation-skipping-should-just-be-a-single-click-press.151970/)). These are forums, not studies, but they agree with each other.

**Patterns to copy**

| Pattern | Example | Why it works |
|---|---|---|
| Only show what changed | Fire Emblem stat arrows; Slay the Spire reward rows | Nothing on screen needs reading unless it matters |
| Portrait + icon + number | Roster cards in Darkest Dungeon, Unicorn Overlord **(from play)** | The face carries the name; the icon carries the type; the number carries the size |
| Short timed sequence, one press skips | Stardew's tally; our own `VictoryUi` (a key fills every bar, the next press continues) | Reward feeling without forcing a wait |
| One summary, optional detail | Gems of War requests; BG3 and Wildfrost hover cards | Keeps the default calm for people who do not care |
| Fixed order | Loot, then growth, then relationships, then next step | The player learns where to look |

**What this means for HOME AGAIN.** It currently prints every bond pair and every morale line. With a party of 4 to 6 there can be up to 15 pairs. A results screen should show the two or three pairs that crossed a bond level or moved most, and hide the rest behind a "show all" row.

## 2. Window chrome: close, back, scroll, fit, modal or panel

- **Always give an exit unless the choice is forced.** A close button, Escape, a click outside and a cancel button are the usual set. A practical modal guide lists these and warns that modals should be used sparingly and sized sensibly: too small and it is hard to read, too large and it hides the game ([Indie Klem on modals](https://indieklem.substack.com/p/5-best-practices-for-modals-in-video)). It also says if a modal needs scrolling, think about a separate page.
- **Use one meaning per control.** A UX review of The Banner Saga found the "x" acting as Back in some windows and Close in others, one save screen with the "x" at the bottom, windows of different sizes, and content sitting outside its frame. The fix it proposes: one set of size and spacing rules for every window, a back arrow for navigation and "x" only for close or cancel ([Game Developer analysis](https://gamedeveloper.com/design/learning-from-and-improving-banner-saga-trilogy-a-ux-ui-analysis)). That is almost exactly Brandon's complaint.
- **Do not make two-axis scrolling.** Microsoft's text guidance says scaling text must never force two-axis scrolling in one UI, and that one-direction scrolling is acceptable ([Xbox Accessibility Guidelines 101](https://devdocs.xbox.com/build/game-principles/accessibility/xag-deep-dives/xag-101-text-display.md)). So: vertical scroll only, always.
- **Full-page screens versus panels.** Persona-style games build each menu page as its own designed screen and accept the cost. The director of Persona and Metaphor says each page needs its own design and that this is "really annoying" work ([Push Square](https://pushsquare.com/news/2024/10/making-metaphor-refantazio-personas-immaculate-menus-is-really-annoying-says-director), [PC Gamer](https://www.pcgamer.com/games/rpg/persona-series-director-says-atluss-flashy-menus-are-actually-really-annoying-to-design)). He also says Persona 5's angular style was close to unreadable at first and had to be tuned. Style costs readability unless someone pays to tune it. For a small team the cheaper route is one strong shared frame, not a different design per page.
- **Modal versus side panel.** **(from play)** Dense RPGs use a full-screen page for management (inventory, party, journal) and a smaller centred modal only for a decision or a reward. Side panels (BG3's character sheet beside the inventory) work because you can compare while you act. We should follow that split: results and choices are modals, the pack and party are pages.
- **Controllers and keyboard.** Steam Deck verification needs on-screen glyphs that match the active input, and it fails games that force the player to open the on-screen keyboard ([Steamworks Deck criteria](https://partner.steamgames.com/doc/steamdeck/compat)). Plan Esc, Enter, B and A from day one, plus focus on the primary button.

**Safe areas.** Desktop and Deck have no notch, but the Deck at 1280x800 is the tight case. Keep a 24 px margin from every edge at the 1280x720 base, and keep the X and primary button inside it.

## 3. Visual hierarchy for dense stat screens

- **Sakurai's rule of thumb** is that a UI is a container for storing, retrieving and showing information, and that a messy layout is what makes players struggle. He also praises condensing many values into one readable summary, such as Pokemon GO's single power number ([Famitsu column, translated](https://sourcegaming.info/2016/11/24/the-aims-of-ui-sakurais-famitsu-column-vol-515/)). He notes translated text is longer, so fixed-width layouts break.
- **Into the Breach** is the model for clarity. The developers say they would give up appealing ideas for clarity, and they found written weapon descriptions confused testers, so they added short animated tooltips that show the effect ([Game Developer](https://gamedeveloper.com/design/-i-into-the-breach-i-dev-on-ui-design-sacrifice-cool-ideas-for-the-sake-of-clarity-every-time-)). There is a GDC session on it ([GDC Vault](https://gdcvault.com/play/1025772/-Into-the-Breach-Design)). The takeaway for us: if an ability needs a paragraph, show a number and icon first, and put the exact rules text in the tooltip. This fits Brandon's own call that ability text be plain and exact.
- **Banner Saga** colors stats the same way everywhere and uses a readable serif for story text and a separate face for numbers ([same analysis](https://gamedeveloper.com/design/learning-from-and-improving-banner-saga-trilogy-a-ux-ui-analysis)). It also loses points for light text on light backgrounds and decorative type that hurts legibility.
- **Wildfrost** reviewers say the board is clean and tells you what you need at a glance, and a review notes you can right click any card for full stats and keywords ([PC Gamer](https://pcgamer.com/wildfrost-review), [Softpedia](https://www.softpedia.com/reviews/games/pc/wildfrost-review-537186.shtml)). That is progressive disclosure done in two layers.
- **Case.** **(from play)** Almost every game above uses Title Case or sentence case for anything longer than a button label, and reserves all caps for short plates. The usual typographic reason is that capitals remove the word shapes readers rely on. I could not find a game-specific study, so this is a general rule I am applying, not a cited finding. Our current page is all caps from first line to last, which is part of why it reads as a wall.
- **Gain and loss colour.** Pair colour with a shape: a plus or up arrow in green, a minus or down arrow in red or rust, neutral in cream. Never colour alone, since roughly 1 in 12 men have a colour vision deficiency. **(general accessibility practice)**
- **Bars with labels.** Put the number on or beside the bar ("2/3"), and keep the label outside the fill so it reads at any fill level. Use the same bar widget everywhere (our `UiBar` is the right start).
- **Portraits** do the work of names. A 48 to 64 px face with a name under or beside it replaces a line of text and makes rows scannable.

## 4. Encounter and choice prompts

- **Baldur's Gate 3** shows the roll type and difficulty on the option itself ("DC 25" appears in the dialogue line, and the option text carries its requirement) ([BG3 wiki dialogue template](https://bg3.wiki/wiki/Template:Dialogue_option)). Players also say you can examine an NPC to gauge how hard a check will be. Lesson: put odds on the button, not in a log.
- **Slay the Spire** treats Skip as a normal, always-visible choice under the card rewards ([wiki](https://slay-the-spire.fandom.com/wiki/Card_Rewards)). A leave or back off option should always exist, last in the list, quiet in style.
- **Locked options.** Games differ: BG3 shows requirement-gated lines, many RPGs grey them out with a reason. Brandon has already decided for Lodestone: an option shows only when its condition holds (decisions.md, "Conditional encounter options"). I recommend we keep that, and show **odds and cost** on the options that are shown. If he later wants to tease locked options, a single greyed row with a lock icon and a one-word reason would be the pattern. That is a question for him, not a change.
- **Layout.** The prompt data already has `need`, `check` and `dc` per option (`explore_events.csv`), so the odds chip can be computed, not written.

## 5. Inventory and loot transfer

- **Complaints are the lesson.** BG3 players cite no shared stash, too many clicks and containers that do not open from the loot screen ([Gfinity](https://www.gfinityesports.com/article/why-baldurs-gate-3s-inventory-needs-a-simpler-system), [Charlie INTEL](https://charlieintel.com/baldurs-gate/baldurs-gate-3-players-demand-major-quality-of-life-changes-for-inventory-management-288260)). A popular mod exists just to improve inventory readability ([Better Inventory UI](https://www.nexusmods.com/baldursgate3/mods/4597)).
- **Divinity: Original Sin 2** had enough inventory trouble that its Definitive Edition promised a party inventory screen ([GameBanshee interview](https://www.gamebanshee.com/k4d9c)), and forum posts still ask for multi-select and filters in chests ([Steam thread](https://steamcommunity.com/app/435150/discussions/0/1737715419897359650)).
- **Battle Brothers** gets a sharp review line: comparing gear means closing one screen, opening another and going into a sub-menu ([PC Gamer review](https://www.pcgamer.com/battle-brothers-review/)). The developers later redid the UI and gave the "loot all" button a makeover ([dev blog](https://battlebrothersgame.com/?p=15526)). Community mods add sorting to the post-battle loot screen.
- **Pillars of Eternity 2** drew criticism for a weak inventory and tiny icons, while one review called its loot approach the standout improvement ([Kotaku](https://kotaku.com/1825867625), [Cubed3](https://www.cubed3.com/games/reviews/pc/pillars-of-eternity-ii-deadfire), [PCWorld](https://www.pcworld.com/article/401937/pillars-of-eternity-ii-deadfire-review.html)).
- **Dredge** modelled its inventory on a real boat's layout, in the spirit of Resident Evil 4's grid ([WellPlayed interview](https://www.well-played.com.au/black-salt-games-on-night-fishing-and-cosmic-horror-in-dredge/)). Our grid inventory sits in the same family. The grid's shape is the interface, so pieces must be big enough to recognise.
- **Patterns that hold up:** a TAKE ALL button that is the primary action; drag, click and shift-click all work; sort and filter chips on any grid with more than about 20 cells; stack counts in a corner; item name and short effect on hover; a visible "no room" state; and the container window as wide as its grid, not wider.

## 6. A consistent UI kit

What a small team builds once, from the sources and from play:

- **Beastieball's** one-person UI uses a single shape motif, one global tilt value, an indexed colour palette so every element picks a slot by number, and one easing formula for every open and close ([Game Developer deep dive](https://gamedeveloper.com/art/deep-dive-developing-a-clear-and-consistent-visual-language-in-the-ui-of-beastieball)). Changing the palette restyles every menu. The author applies the same motifs everywhere even when it costs a little clarity, because coherence is what reads as professional.
- **Wildfrost's** sound designer wanted UI sounds that feel logical: a click sounds like a click, a hover like a hover ([Super Jump](https://www.superjumpmagazine.com/wildfrosts-sound-designer-sheds-light-on-its-frosty-soundscape/)). Sound is part of the kit.
- **Persona** keeps one dominant colour across all menus and puts important information on the same side every time ([PC Gamer](https://www.pcgamer.com/games/rpg/persona-series-director-says-atluss-flashy-menus-are-actually-really-annoying-to-design), summarised in [this Atlus talk write-up](https://www.playstationlifestyle.net/?p=615973)).
- **Banner Saga's** failures are a checklist of what the kit prevents: windows of different sizes, content outside frames, buttons that look like icons, an X with two meanings.

**How a stylized indie feels hand-made.** The frame is painted, the rest is disciplined. Use one painted nine-slice frame, one painted button, one painted plate, then let flat shapes, a limited palette, a slight pop-in and a soft paper grain do the rest. Hand-made feel comes from small imperfections (a slightly warm shadow, an uneven line on the divider) applied to the same pieces everywhere. Our `UiTheme.look()` nine-slice pieces (panel, title plate, pill, tooltip) already do this.

## 7. Readability numbers

- **Steam Deck:** text characters must never be under 9 px tall at 1280x800, Valve recommends aiming for 12 px, and text must be readable at about 30 cm ([Steamworks](https://partner.steamgames.com/doc/steamdeck/compat)). Valve also recommends supporting user-set text size.
- **Xbox guidelines** give minimum default body heights (descender to ascender): 18 px at 1080p on PC and 26 px at 1080p on console, with text scalable to 200%, and line width of 80 characters or fewer for blocks over two lines ([XAG 101](https://devdocs.xbox.com/build/game-principles/accessibility/xag-deep-dives/xag-101-text-display.md)).
- **Game Accessibility Guidelines** suggest 28 px at 1080p as a minimum for text, as a number to beat ([guideline](https://gameaccessibilityguidelines.com/use-an-easily-readable-default-font-size/)).
- **Contrast:** use 4.5 to 1 for body text and 3 to 1 for large text as the floor, and aim higher on busy backgrounds ([Unity accessibility basics](https://unity.com/blog/video-game-accessibility-basics)).

**Translating to our base resolution (my arithmetic).** The project is 1280x720 with `canvas_items` stretch, so one base pixel is 1.5 px at 1080p and about 1 px on the Deck's 1280x800 screen (a little more vertical room, same width). Valve's 12 px recommendation therefore means 12 base pixels or more for the smallest text. Xbox's PC floor of 18 px body height at 1080p is about 12 base pixels, and the console floor is about 17. The Game Accessibility 28 px figure is about 19 base pixels for TV distance.

Current sizes in `ui_theme.gd` are 21 (`MenuTitle`) and 15 (`SubTitle`), and party cards use 13 and 12. The cards are on the line.

**Text on textured backgrounds.** The green felt with mottle is the hard case. Put body text on a flat plate (parchment or a darker inset) rather than directly on the felt, keep text colour at 4.5 to 1 or better against the plate, and add a 1 px dark outline or soft shadow to any text that sits on art. Brandon's loot windows and the character sheet already do this with plates.

## Recommendation for Lodestone

### A. UI kit list (build once, reuse everywhere)

1. **Window frame** (`DialogPanel`): nine-slice, with content margin and a title row.
2. **Header bar**: title plate in the centre, **close X** at the top right, optional back arrow at the left. Fixed height (about 56 base px).
3. **Tab or step bar**: pill tabs with an icon, a label and a small count badge. Tabs with nothing to show do not appear.
4. **Button set**: primary (large, glowing), secondary, quiet (for leave and back off), icon button, and the X. States: normal, hover, pressed, focused (a visible ring for controllers), disabled.
5. **List row**: portrait slot, title, subtitle, right-aligned value or chip. One height (56) and a compact height (40).
6. **Chip**: icon plus number, tinted for gain (green), loss (rust), neutral (cream). Hover names it.
7. **Stat bar** (`UiBar`): label outside, number beside, optional "gain" overlay that fills during the reveal.
8. **Portrait frame**: round or square, sizes 32, 48, 64, with a level badge corner.
9. **Tooltip** (`TipPanel`): title, one line of plain rules text, optional second tier on a held key. Never put the only copy of important information in a tooltip.
10. **Scroll area**: a `ScrollContainer` with a themed thin scrollbar, a top and bottom fade when content is clipped, mouse wheel, stick and Page keys.
11. **Section header** and **divider**: small caps label, one thin rule.
12. **Item slot and grid cell** (already exists): rarity edge, stack count, hover card.
13. **Toast** and **banner** for small events so they never open a modal.
14. **Sound set**: hover, click, open, close, confirm, deny, level-up sting.

Plus the helpers that make the kit behave: a `Window` base scene that owns the X, Esc, focus and fit rules, so no screen builds its own.

### B. Layout rules (these apply to every screen)

1. **Every window has an X at the top right**, 34 base px, 12 px in from the corner, plus Esc. For a modal with a required choice, the X is hidden and the reason is obvious. The X never discards a reward or throws items away (the pack's own rule already stays).
2. **Fit, then scroll, never shrink below the floor.** `keep_inside` may scale a box down to 85% at most. Past that, the content area scrolls vertically inside the frame. The header and the primary button never scroll.
3. **Max text per screen.** One headline. At most 3 sections visible at once. At most 7 rows per section before "show all". At most 40 characters per row label. Anything longer is a tooltip or a Details tab. Blocks of prose stay under 80 characters per line.
4. **Show only what changed.** A row for a person with no gain is not drawn. A section with nothing in it is not drawn.
5. **Text floor.** Body 16 base px, secondary 14, absolute minimum 13 (the Deck's 12 px target plus margin). Title 28, heading 20. Numbers are bold and one size up from their label.
6. **Case.** Sentence or title case for rows and rules text. All caps only on plates and buttons of 1 to 2 words. (The placeholder CSV is caveman and all caps by design, so the theme should apply the case at display time, so Brandon's final text is free to use normal case.)
7. **Colour is never alone.** Gains get a plus or up arrow, losses a minus or down arrow.
8. **Fixed anatomy.** Header on top, content in the middle, one primary action bottom right, Esc and the X always close. Same margins on every window.
9. **Inputs.** Mouse, keyboard and controller reach everything. The primary button has focus when the window opens. Show the right glyph for the active device.
10. **Sequences are skippable in one press** and the final state is always the one the game applied.

### C. Redesign sketches (words only)

**HOME AGAIN.** A centred window about 880 by 560 base px, so it fits the Deck with margin. Header: title plate "HOME AGAIN", X at the top right. Under it a thin row of **step tabs** with count badges, drawn only for steps that have news: *Brought home*, *Party*, *Friends*, *Next*. The window opens on the first tab and plays it in; Left and Right (or the arrows) move between tabs, and a dot row shows where you are.
- *Brought home*: a grid of item icons, each with a "+3" chip, name on hover. If nothing came home, the tab is skipped.
- *Party*: one row per member who gained something. Portrait, name, LV badge, an XP bar that fills and, on a level-up, rolls into a "LV 1 > 3" chip with the stat gains as icon chips (reusing `VictoryUi` card logic). Morale is one heart icon in the band colour with a "+13" chip. The band's words appear on hover and only in text when the band changed.
- *Friends*: portrait pair, a heart, a "+6" chip. Only pairs that crossed a bond level or are in the top three gains, with a "show all (N)" row that expands in place and scrolls.
- *Next*: one card with the next goal's icon and a bar per material with icon and "2/3". The primary button "OK. ONE MORE GO" sits bottom right on every tab so players can leave at any time. X and Esc do the same thing, because the results are already applied.
- A fall or the boss-card case puts the boss card first as its own tab.
Replace the current single scroll of text. Keep a one-page "Everything" toggle for players who prefer one list, with a vertical scroll.

**Win screen.** Keep the current `VictoryUi` bones, they are close. Changes: add the X (it acts as Continue), cap the cards at a 3 by 2 grid, make the loot row a chip strip with a single "+N more" chip that opens a small list, add a quiet "Details" button that opens combat numbers in a second panel (the Gems of War request), and keep the sequence under about three seconds with one-press skip. Gains use a plus and green, nothing red unless something was lost.

**Encounter prompt.** A modal standing on the frame's diamond (already decided). Left: a small picture of the foe or place. Right: one situation line, then a vertical list of option buttons, each a full-width pill with icon (fight, sneak, talk, leave), a short verb, and a right-aligned **odds chip** for checks (for example the stat and the success chance, computed from `check` and `dc`). Leave or Back off is last, in the quiet style. Options whose condition fails are not drawn (the decision of 2026-11-01). If an option costs something (HP, time, an item), the cost is a chip on the same row.

**Loot window.** Keep the current hugging-width windows and the X. Title row with the container's name, X at the top right. The grid fills the middle. A row of small sort and filter chips appears above grids with many cells. TAKE ALL is the primary button straddling the bottom edge. Hover on an item shows a tooltip card with its name and plain effect line. A visible "no room" chip appears next to the gold row, not as a modal. Allow click to take, shift click to take a stack, and drag. Pack and container sit side by side and the pack never overflows the screen: if it must, scroll.

### D. What an art generator could mock up, and what stays code

Brandon approves art before it enters `game/art/source`. These would be Picsart drafts only, from the style bible and the approved forest look.

- **Good for mockups (painted pieces):** window frame variants, the header plate, button end caps and the glowing primary button, tab shapes, an X button, scroll bar thumb and track, divider flourish, item slot frame, portrait frames, a parchment inset plate for body text, and a set of 12 to 16 flat icons (heart, star for XP, fist for damage, shield, potion, coin, sack, key, boot, sword, speech bubble, lock). Icons need the consistent line weight Brandon already uses.
- **Stays code:** layout, scroll and clipping, fit rules, bars and their fill, gain and loss chips, tabs logic, number formatting, focus rings, the sequence timing, the text itself, and every animation. Bars and chips should be drawn in code from palette tokens so a palette swap restyles all of them.
- **Never generated:** story, names or flavor text, as always.

### E. Order of work (my suggestion)

1. The shared `Window` base with X, Esc, focus, and the scroll area. Move HOME AGAIN and every box onto it. This alone answers "no X, no scroll".
2. Raise the text floor and add the size tokens to `UiTheme`.
3. Rebuild HOME AGAIN as tabs and cards, reusing `VictoryUi` rows.
4. Add odds and cost chips to the encounter prompt.
5. Add sort and filter chips to loot grids.
6. Ask for the icon and frame mockup batch once the kit list is agreed, with a go card first.

## Open questions for Brandon

- OK with tab pages for HOME AGAIN, or does he prefer one scrolling page with big section cards?
- Should the X on a results window act as Continue? (I recommend yes.)
- Should locked encounter options stay hidden (his current call) or show as a greyed teaser later?
- Can the text floor be raised to 16 base px for body text? Some current cards are 12 to 13.

## Sources used

Valve [Steam Deck criteria](https://partner.steamgames.com/doc/steamdeck/compat); Microsoft [XAG 101](https://devdocs.xbox.com/build/game-principles/accessibility/xag-deep-dives/xag-101-text-display.md); [Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/use-an-easily-readable-default-font-size/); Unity [accessibility basics](https://unity.com/blog/video-game-accessibility-basics); [Into the Breach UI interview](https://gamedeveloper.com/design/-i-into-the-breach-i-dev-on-ui-design-sacrifice-cool-ideas-for-the-sake-of-clarity-every-time-); [Beastieball UI deep dive](https://gamedeveloper.com/art/deep-dive-developing-a-clear-and-consistent-visual-language-in-the-ui-of-beastieball); [Banner Saga UX analysis](https://gamedeveloper.com/design/learning-from-and-improving-banner-saga-trilogy-a-ux-ui-analysis); [Indie Klem on modals](https://indieklem.substack.com/p/5-best-practices-for-modals-in-video) and [on menus](https://indieklem.substack.com/p/9-creating-an-intuitive-in-game-menu); [Sakurai's UI column](https://sourcegaming.info/2016/11/24/the-aims-of-ui-sakurais-famitsu-column-vol-515/); [Hashino on menus](https://pushsquare.com/news/2024/10/making-metaphor-refantazio-personas-immaculate-menus-is-really-annoying-says-director); [Mega Crit top bar update](https://megacrit.com/news/2024-11-07-neowsletter-issue-4); Gems of War [victory screen thread](https://community.gemsofwar.com/t/victory-a-better-screen/61526); BG3 inventory coverage ([Gfinity](https://www.gfinityesports.com/article/why-baldurs-gate-3s-inventory-needs-a-simpler-system)); [PC Gamer's Battle Brothers review](https://www.pcgamer.com/battle-brothers-review/); [WellPlayed's Dredge interview](https://www.well-played.com.au/black-salt-games-on-night-fishing-and-cosmic-horror-in-dredge/).

Not found despite searching: written breakdowns of Darkest Dungeon's, Triangle Strategy's, Octopath Traveler 2's, Sea of Stars' and Hades' results and menu layouts. Triangle Strategy's UI drew criticism in reviews ([Tom's Guide](https://www.tomsguide.com/reviews/triangle-strategy)), and Octopath 2's was called too minimal in places ([TechStomper](https://techstomper.com/?p=12522)), so they are cautionary rather than model examples. For a visual pass, pull Game UI Database pages for Darkest Dungeon 2, Unicorn Overlord, Hades 2 and Wildfrost by hand (results screens, inventory, tooltips) before the art batch.

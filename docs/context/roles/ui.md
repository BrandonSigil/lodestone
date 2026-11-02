# UI lane: handoff note

The UI lane owns every screen and menu: `game/scripts/ui`, `UiTheme`, the menu kit (`menu_kit.gd`, `UiTheme.frame_window`), PackView's drawing, and the screenshot tools (`game/tools/*_shot*.gd`). Rules scripts and `game/data` numbers belong to the Systems lane: ask through the PM. How the kit looks and works: `docs/systems/ui-kit.md`. Lanes: `docs/systems/studio.md`, "Three lanes".

## How I work
- Temp worktree from `origin/main` (`git worktree add /private/tmp/claude-501/lode-ui origin/main -b <name>`), first run `--headless --import` there. Rebase, `tools/check.sh` green, push to main, then `git -C ~/lodestone merge --ff-only origin/main` (never touch his unsaved maps).
- Shots: `tools/godot.sh --path . --resolution 1280x720 -s res://tools/explore_shot.gd -- <png> <step>`. A new text key needs a headless `--import` before a shot can read it.
- Look check: a fresh Sonnet subagent with the pictures, `docs/style-bible.md` and the fail list from studio.md. Tell it what is the approved kit (frame, felt, chips, buttons, HUD) and what is game rules (grid sizes, shaped items), or it spends its notes there. Cap 5 rounds, then post with its last notes plainly. The reviewer often flips between rounds (stretch the cards, then don't); take the notes that are fair and new.
- Cards: role `dev`, kind `choice`, yes / tweak, before|after pictures (`magick a.png b.png +append -resize '1600x1600>' -quality 82 x.webp`) uploaded with Artifact `asset: true`.

## Done 2026-11-02
- Win screen (`ui-win-screen-review`, 81787f2, approved "Yes, keep it"): LOOT and PACK cards tight to their grids, one foot row (TAKE ALL, the gold chip), slots fitted to the party column (`VictoryUi._cell`), the dog's saddlebag in its own inset with his round face, EXP and GOLD beside OK. Open look-check notes: the map shows through the gap above the bottom frame; with two members the window sits high and a small drop leaves many empty slots; the party cards are denser than the loot side.
- Level up as a skill board (X20, `ui-levelup-board-review`, 36417d9, waiting on Brandon): one row per skill with a rank track (`LevelUpUi._Nodes`), NEW SKILL pill, maxed skills shown, current stats as chips, text 11 to 16 px. Shot steps `levelup_ranked`, `lodestone_pick`. Open notes: hero's card has empty felt on a level with no stat gains; a NEW SKILL row's track stays dim when picked (learning gives no rank).

## Sweep: screens not yet on the kit (first trip first)
Found from shots of a first trip (2026-11-02):
1. Pack and Party windows (Tab in explore, `AdventureMenu.pack`) and the Loot and FOUND ITEMS windows (`ContainerUi.windows`, `fill`): first pass pushed 2026-11-02, no card yet. PARTY is a row per member (card with face, name, thin HP bar; their belt beside it), counts and materials are kit chips, EAT / DRINK sit by their chips, no CLOSE (the X), "who eats?" prompts in cream, plates stop short of the X, the loot window always has its X, a window is as wide as its title and widest button. Look check failed round 2: still two old-style windows with dead space. **Next job:** rebuild them as one kit window with section cards, the way the win screen is (`PackView.sections`, the saddlebag inset, a foot row). Open rules question for the PM: FOUND ITEMS has no X (closing it decides what happens to the items).
2. The Lodestone menu (`AdventureMenu`): cramped old layout, not kit cards; its X sits on the corner leaf.
3. Options: old layout, works.
4. The fight's YOUR TURN side panel: plain box; AUTO FIGHT (TEST) and UI: DOCK buttons show (testing toggles; ask the PM whether they stay for players).
5. Village repairs: a wall of text rows.
6. The gate map: tiny GO IN button, no frame.
7. The launch menu is the dev scene list (parchment); not a player screen yet.
Already on the kit: every dialogue prompt (elite, boosts, chests), HOME AGAIN, win, level up, fishing (Systems' X19).

## Open asks
- Brandon's "Text feels huge right now, things are just too big everywhere": only level up is smaller so far. A whole-UI size pass is offered on the level-up card.
- Fishing polish waits on the fishing card (Systems pushed X19 as a full screen in ebb0694; approved).

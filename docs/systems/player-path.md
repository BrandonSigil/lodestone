# The player path (main menu, goals, hints, sound, builds)

Built 2026-11-13 from a new-player E2E playtest (backlog section "2026-11-13 new-player playtest"). Brandon: "Yes, do all of this please. I think it would make sense if we had a "random encounter" that wasnt so random the first time a user goes out on the road that is a fair fight and has any explainers we need in it. And yes, there should be a main menu player path, with maybe another button for "Star game in Dev Mode" or the "Dev Tools" menu that if you click it opens all of our other tools we currently have on that main launch page."

## Main menu and dev mode
- The game boots into `scenes/loading.tscn` (`LoadingScreen`): Brandon's 10-second title video (`art/source/ui/menu/title_intro.ogv`, 2026-11-13) plays while the main menu loads on a thread. The video is muted: Brandon asked for the calm menu music instead of its own sound. The file has no sound track (stripped in conversion) and the player's volume is 0 as well. The `menu` music starts at once and runs on into the menu unbroken. At the end it crossfades into the menu: the video's last frame is the menu painting without the logo, framed the same way (`MainMenu.art_rect`, k = 0), so the logo seems to fade back in. A click or any key skips ("Click or press any key to skip" shows after 1.5 s). Headless runs go straight to the menu.
- Video in Godot must be Ogg Theora (`.ogv`); MP4 won't play. Homebrew's ffmpeg has no Theora encoder, so the MP4 was cut into frames with ffmpeg and recorded with Godot's own Movie Maker (`--write-movie out.ogv --fixed-fps 24`, a throwaway project that shows one frame per tick, run through `tools/godot.sh`), then `ffmpeg -an -c:v copy` dropped Movie Maker's silent audio track.
- The game opens on `scenes/main_menu.tscn` (`MainMenu`): Brandon's title painting (`art/source/ui/menu/title_screen.webp`, 2026-11-13; the logo is painted in, so the menu draws no title) with a slow side-to-side sway, pinned to the top so the logo is never cut at any window shape. CONTINUE (when there is a save), NEW GAME (asks first when a save exists), OPTIONS and QUIT stand in the middle of the screen (Brandon: "Put em smack in the middle"), pushed down only as far as needed to stay under the logo (`LOGO_BOTTOM`). Music: `menu`.
- DEV TOOLS (bottom right) opens the old launch page (`scenes/launch.tscn`, now titled DEV TOOLS) with every map, fight and tool. It shows only when `Game.dev_available()`: a debug build (the editor, `tools/godot.sh`) or a Mac with `~/.lodestone/dev`. Exported release builds never show it.
- `Game.dev_mode`: on when the Dev Tools page opens or an F7/F8/F10 key is used; off on the main menu. Dev mode shows the god-mode "!" button, the fight test buttons (AUTO, LAYOUT), every playable character on the gate picker, and no hints. `Game.menu_scene()` is where "main menu" buttons go: Dev Tools in dev mode, else the main menu. SAVE AND EXIT and the end-of-playtest button use it.
- F7, F8 and F10 work only when dev tools are available.

## Goals
- `GoalRules.main_goal(flags)` (pure, `scripts/core/goal_rules.gd`): the first step of the playtest chain not done yet. Lodestone (`has_lodestone`), a weapon (`weapon_*`), a companion (`met_dog`, or skipped once out the gate), out the gate (`left_village`, set by `Game.start_trip`), the Highlands (`visited_pass` from the world map, or `entered_snow_pass`), the crypt (`entered_crypt`), the boss (`e2e_done`). `entered_<map>` is set on every explore map arrival, `visited_<node>` on every world map arrival.
- The frame's long bar shows it first, then any tracked village steps (`Game.goal_lines`). The homecoming page's NEXT GOAL shows it when no village step is tracked.
- Texts: `GOAL_*` in `text/placeholder.csv`. They must fit the long bar (about 40 characters).

## One-time hints
- `GoalRules.HINTS`: `walk` (the first walk: WASD, F, I), `use` (the first time something usable is in reach), `road` (the world map), `walking` (the first road walk: actions and FAST FORWARD), `ambush` (the first fight where foes move first), `fight` (the first fight ever). Each shows once ever (flag `hint_<id>`), never in dev mode.
- `Game.hint(id, parent, area)` shows a `HintToast`: a small dialogue-style box at the top of the play area, sized to its words, gone after 7 seconds or a click. The walk and road scenes show one at a time.
- The first fight gets `FightTips` instead: a card at the play area's left with the win goal and four steps (move, attack, press D for danger, END TURN), each ticked off as the player does it. It closes with its X, when the fight ends, or a few seconds after the last tick.
- Ambush: the [AI] 2026-10-27 rule stays (spotted first, the foes move first). The fight log says AMBUSH and the `ambush` hint explains why and how to strike first instead.

## The first road fight
- `tr_first` in `data/travel_events.csv` (weight 0: never rolled, `TrailRules.first_event` picks it) is the first stop of the first road walk until its once flag `first_road_fight` is set. One option, FIGHT: `first_road` in `data/encounters.csv` (two wolves). Road fights already let the party move first, and the FightTips card teaches it. Its text `EV_TR_FIRST` is a caveman placeholder for Brandon.

## Sound
- `Sfx` autoload (`scripts/core/sfx.gd`): Music and SFX buses, Options volumes (`music_volume`, `sfx_volume` in `meta.settings`), `Sfx.play(name)` for one-shots and `Sfx.music(mood)` for a crossfaded loop. Every button clicks on its own (the round X closes with `close`); hover is a faint tick.
- Placeholders are made in code (`SfxSynth`): no audio files exist yet. A real file wins with no code change: `res://audio/sfx/<name>.ogg`, `res://audio/music/<mood>.ogg`.
- Sounds: click, hover, open, close, confirm, error, hit, crit, hurt, down, pickup, coin, levelup, victory, defeat, door, hint, stone, camp, move. Moods: menu, village (village, home, houses, tavern), wild (other explore maps), road (world map), fight, boss.

## Feedback notes and builds
- F12 anywhere: the screen is saved, then SEND FEEDBACK asks what happened. SAVE NOTE writes `user://feedback/<time>.png` and `.txt` (the note, scene, map, goal, trips, `application/config/version`). OPEN FOLDER shows them (on a Mac: `~/Library/Application Support/Godot/app_userdata/Lodestone/feedback/`).
- `tools/export/build.sh [mac|windows|all]` builds `build/mac/Lodestone.zip` and `build/windows/Lodestone.exe` from `tools/export/export_presets.cfg` (copied into `game/`, where that file is gitignored). It needs Godot's export templates for the installed version (4.7.2's were installed on Brandon's Mac on 2026-11-13, with his OK). The Mac build is universal (Apple Silicon and Intel) and ad-hoc signed: testers right-click the app and pick Open the first time. Windows SmartScreen asks once too ("More info", then "Run anyway"). About 120 MB zipped for Mac, 170 MB for Windows.
- Builds need `rendering/textures/vram_compression/import_etc2_astc=true` (the Apple Silicon export refuses without it).
- Every `data/*.csv` must be imported as Keep File (`importer="keep"` in its `.import`). Godot imports a new CSV as a translation by default, which the editor hides but builds drop. The first build lost 12 tables that way. `tools/check.sh` now fails on any data CSV that isn't "keep". Only `text/placeholder.csv` is a translation.
- Smoke test a build: unzip it and run `Lodestone.app/Contents/MacOS/Lodestone --headless --quit-after 300`. It should print nothing but the version line.

## Other fixes from the same playtest
- Out of a door: the party stands a step clear of it, and F prefers a "!" over a doorway beside it (`ExploreRules.thing_to_use`).
- Clicking something out of reach floats TOO FAR.
- The gate: one box. The party picker shows only people met (dev mode shows all), with the food for that party as chips, the first trip's free rations, and GO ANYWAY when food is short.
- FAST FORWARD stays on until the walk ends (the button reads FAST FORWARD: ON); Tab toggles it.
- Camp: SAME AS LAST NIGHT eats at once; "Eat the same every night" (`meta.settings.auto_camp`) eats later nights on its own while no one would go hungry.
- Fights: a fallen foe leaves in a dust puff and the fight holds a beat; side bars follow each blow; a loss holds 1.2 seconds on the board, then one box (no second defeat banner) saying the Lodestone carries the party home with everything they carried.
- Taking a weapon at the smithy fills the hero's HP to the new max.
- The character sheet's locked builds say why on hover; move descriptions wrap to two lines.
- Road action buttons are bigger (the box stays at the [USER] half size).

## Waiting on Brandon (2026-11-13)
These belong on the Studio desk as cards, but the Studio page (5NsBvyRP81zBRgAFCANTP5) answered "not found" from the account that built this, so they are recorded here until a session that can open the page posts them. The new screens' screenshots had a fresh-reviewer look check: the main menu passed; the rest failed on older screens around them (backlog P19 to P21), so none is ready for a card yet.
- **Real sound and music.** The game has code-made placeholders only. Options: keep them for the friends-and-family playtest; a royalty-free game audio pack (licensed, dropped in as `.ogg`); commissioned music; or his own. Any file at `res://audio/sfx/<name>.ogg` or `res://audio/music/<mood>.ogg` replaces a placeholder with no code change (names in "Sound" above).
- **Export templates: done (2026-11-13).** He said yes; the 4.7.2 templates are installed and the first Mac and Windows copies built. They are not committed (`build/` is gitignored): send them to testers by hand, or rebuild with `tools/export/build.sh all`.
- **Art asks from the playtest** (art is his, never painted by Claude): the square's statue reads as a plain cube; the bridges are flat grey; a pink placeholder box stands on the pass; the crypt reads bright for a crypt; interiors float in a black void.
- **Story text for the first road fight:** `EV_TR_FIRST` is a caveman placeholder on the Word Swap page.

# Playtest feedback backlog

Every problem Brandon reported while playtesting, with who owns it and where it stands. Newest session first. Quotes are his words from the Studio chat (https://claude.ai/artifact/5NsBvyRP81zBRgAFCANTP5); the screenshots he attached live on those chat messages.

How to use it: when you start on an item, put your thread in **Owner**; when it merges, set **Status** to `done (#PR)`. Add new playtest reports here in the same turn you hear them. Design calls he made along the way also go to `docs/decisions.md` as `[USER]` lines.

Status values: `open` (nobody on it), `in progress` (a thread owns it), `done (#PR)`.

## 2026-11-01 playtest (Studio chat, 03:57 to 05:57 UTC)

### Fights and abilities
| # | Problem (his words) | Owner | Status |
| --- | --- | --- | --- |
| F1 | "I dont see a way to "aid" my teammate. If youre next to a downed friend you should see an aid button on your actions bar" | Studio PM thread | done (#90) |
| F2 | "Doesnt seem like Bark works. Just used it right next to the elite wolf and nothing happens." | Fix Bark feedback and Amber's starting kit | done (#98) |
| F3 | "amber has all spells right away? She should start with 1 ranged attack thats just her doing a regular fire attack" | Fix Bark feedback and Amber's starting kit | done (#98) |
| F4 | "Fire Zap should just be Ambers main attack, and a passive "A Heart that Burns" should allow your regular attacks to have a chance to burn the target causing X damage over Y turns" (chance, damage, turns open) | Fix Bark feedback and Amber's starting kit | done (#98) |
| F5 | "Good shot is lame ... It should just be a passive that makes your regular attacks better and say that. Maybe add a "if its the killing blow, you get to attack again"" | Systems developer (first account) | done (2026-11-01, "Good Shot as a passive" commit) |
| F6 | "It's hard to click the tile directly above your character, right now I cant get dogo to just move directly up one tile" | Studio PM thread | done (#93) |

### Level up and passives
| # | Problem (his words) | Owner | Status |
| --- | --- | --- | --- |
| L1 | "Saw this, but theres no skills. then when I said decide later and actual menu came up" (empty skill pick) | Polish UI windows and victory screen | in progress |
| L2 | "Dog level 2 window isnt needed. Make that the heading of the skill pick menu "Level up!" then the number they just reached, then a summary of the cool things they gained +3 HP, then the ability upgrade selector" | Polish UI windows and victory screen | in progress (call recorded #94) |
| L3 | "The Good Boy passive should show here where he buffs a person next to him. I want to upgrade that passive" (passives upgradable at level up) | Fix Bark feedback and Amber's starting kit | done (#98) |

### Windows and UI
| # | Problem (his words) | Owner | Status |
| --- | --- | --- | --- |
| U1 | "The launcher menu doesnt fit on my desktop" | Studio PM thread | done (#85) |
| U2 | "Let's beef up our UI windows, they feel really clunky either too small or too large, they have way too much text instead of just letting the player understand the menus intuitively" | Polish UI windows and victory screen | in progress |
| U3 | "Menus spill out of the window" (pack and party cards ran off the bottom) | Rework inventory into BG3-style windows; other windows: Polish UI | inventory done (#91), rest in progress |
| U4 | "Look at battle victory menus and beef up this report. Lots of JRPGs do it ... less text, more intuitive sharing of informations" | Polish UI windows and victory screen | in progress |
| U5 | "Currently stuck because you cant close this menu and its too tall to see the close at the bottom" (Lodestone party sheet) | Polish UI windows and victory screen | in progress |
| U6 | "We've got icons! We should use em!" | Studio PM thread (pack); Polish UI (other screens) | pack done (#89), rest in progress |
| U7 | "Let esc close out windows in game too" | Studio PM thread | done (#88, containers #91) |

### Inventory
| # | Problem (his words) | Owner | Status |
| --- | --- | --- | --- |
| I1 | "Make "I" inventory as a keybind. Also put doggo's inventory right next to the main inventory. Match something like BG3's bags ... One inventory window one loot container window then the bags stuff should be on the full inventory page" | Rework inventory into BG3-style windows | done (#91) |
| I2 | "I switch the orientation of the wood to move to that open slot in my inventory and it says it doesnt fit" (the slot held a tonic with no icon) | Studio PM thread | done (#87) |

### Walking and maps
| # | Problem (his words) | Owner | Status |
| --- | --- | --- | --- |
| M1 | "weird character clipping when walking around, the person who should be behind the player is in front" | Studio PM thread | done (#86) |
| M2 | "turn off click to move during open world movement. Keep that just WASD" | Studio PM thread | done (#86) |
| M3 | "This map is a MESS, holes everywhere, these stub walls are broken all over the place." (wolf den) | Fix broken walls and see-through walls | done (#99) |
| M4 | "I think these are stairs but I cant see because theres a wall on the front" | Fix broken walls and see-through walls | done (#99) |
| M5 | "cant place my character where I want to because the wall is visually infront of it" (deploy) | Fix broken walls and see-through walls | done (#99) |

### Map maker
| # | Problem (his words) | Owner | Status |
| --- | --- | --- | --- |
| E1 | "How do I make these tiles "empty" I cnat find a button for it" | Studio PM thread | done (#89: Area tool, Delete/Backspace or Cut out; Fill in restores) |
| E2 | "the Area tool is cool, but I'd love to be able to do more with it. Like select a wide area and delete it" | Studio PM thread | done (#89); more Area actions welcome |

### Studio page
| # | Problem (his words) | Owner | Status |
| --- | --- | --- | --- |
| S1 | "Our chat window needs help, I'm always seeing your latest replies at the very bottom. It should be a back and forth based on time" | Studio PM thread | done (#94) |
| S2 | "Everything is idle?" (roles sat idle with work waiting) | Studio PM thread | answered; standing rule "Idle is not done" in `docs/systems/studio.md` |

## Older standing asks still open
- Picsart requests are tabled until Brandon checks in; then make him a doc of all art needs by priority (2026-11-01, see `docs/systems/studio.md`).
- PM note: once kit wiring and morale land, make a Project Report (every working system, what's built, what core pieces are missing), repeated at milestones.
- Playtest note: re-measure the Lich odds with the robot at the next milestone, after the road retune.

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
| L1 | "Saw this, but theres no skills. then when I said decide later and actual menu came up" (empty skill pick) | Polish UI windows and victory screen | done (#97) |
| L2 | "Dog level 2 window isnt needed. Make that the heading of the skill pick menu "Level up!" then the number they just reached, then a summary of the cool things they gained +3 HP, then the ability upgrade selector" | Polish UI windows and victory screen | done (#97) |
| L3 | "The Good Boy passive should show here where he buffs a person next to him. I want to upgrade that passive" (passives upgradable at level up) | Fix Bark feedback and Amber's starting kit | done (#98) |

### Windows and UI
| # | Problem (his words) | Owner | Status |
| --- | --- | --- | --- |
| U1 | "The launcher menu doesnt fit on my desktop" | Studio PM thread | done (#85) |
| U2 | "Let's beef up our UI windows, they feel really clunky either too small or too large, they have way too much text instead of just letting the player understand the menus intuitively" | Polish UI (#96, #97); the rest: Systems developer (first account) | done (#96, #97, e84199a) |
| U3 | "Menus spill out of the window" (pack and party cards ran off the bottom) | Rework inventory into BG3-style windows; other windows: Polish UI, then Systems developer (first account) | done (#91, #96, e84199a) |
| U4 | "Look at battle victory menus and beef up this report. Lots of JRPGs do it ... less text, more intuitive sharing of informations" | Polish UI windows and victory screen | done (#96) |
| U5 | "Currently stuck because you cant close this menu and its too tall to see the close at the bottom" (Lodestone party sheet) | Polish UI windows and victory screen | done (#96) |
| U6 | "We've got icons! We should use em!" | Studio PM thread (pack); Polish UI (other screens), then Systems developer (first account) | done (#89, #96, e84199a) |
| U7 | "Let esc close out windows in game too" | Studio PM thread | done (#88, containers #91) |
| U8 | "Less text labels in general in the UI. Just a doggo pic will do" (2026-11-01, desk card dev-dogpack-review: drop the DOG PACK label, show only his picture) | Systems developer (first account) | done (e84199a) |

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

## 2026-11-01 afternoon (Studio chat)

### Fishing
| # | Problem (his words) | Owner | Status |
| --- | --- | --- | --- |
| FI1 | "let me actually aim the cast to land in a spot, and see if a fish notices it" | Junior developer | done (5c0f592; review card junior-fishing-review) |
| FI2 | "if you pull too fast that fish should be gone for good so the amount of fish dwindle, (like 3 fish in a pond, catch 1 means one less in the pond, miss one it swims away, third one you try and catch but fail the reel challenge" | Junior developer | done (5c0f592; review card junior-fishing-review) |
| FI3 | "the left right thing is sooo hard haha, one thing is that it just starts right away. both the fish and the reel bar should start in the middle, and give the player a quick ease in before the difficulty ramps up" | Junior developer | done (5c0f592; review card junior-fishing-review) |
| FI4 | "if you use the left arrow you should be pulling the bar left and the second you release it pulls back to the center, same with the right. I want it to feel like the fish is pullign on the line" | Junior developer | done (5c0f592; review card junior-fishing-review) |

### Explore maps
| # | Problem (his words) | Owner | Status |
| --- | --- | --- | --- |
| X1 | "Old dog animation here, should be Doggos actual sprite" (the dog in house_dog is still the old code-drawn dog; the box also prints the raw effect "unlock:met_dog") | Systems developer | done (89e2681) |
| X2 | "Dialogue like this isnt necessary, just open a loot window with a potion." (the cottage chest asks TAKE / LEAVE; it should open the container window like other chests) | Systems developer | done (89e2681) |
| X3 | "THis said "rope on hook" again, just let me interact with the barrel and have a loot inventory box show up" (the rope barrel in the smithy yard; "again" means it was reported before, so every pickup box must go, not just this one) | Systems developer | done (89e2681) |
| X4 | "While we test, let me pick from all playable characters here before heading out" (at the village gate box, GO ON / STAY: a party picker with every playable character, recruited or not, for playtesting). Then: "This box isnt needed, it opens another dialogue that tells you to pick your party, stay or go" (drop the GATE GO ON / STAY box; the gate opens the party picker straight away, with Go and Stay on it) | Systems developer | done (89e2681) |
| X5 | "I cant walk forward here theres an invisilbe barrier" (village square: a companion spot hidden by its `when` flag, or one whose companion is in the party, still blocked its cell) | PM | done (2026-11-01, "Hidden things never block" commit) |
| X6 | "on this map theres no clear paths to the enemy except by walking ontop of the river (which shouldnt be allowed) and then so much of the battle happened back behind cliffs where you couldnt click or interact" (a waterfall river fight) | Systems developer | queued (after the highlights fix) |
| X7 | Win screen: "I actually cant understand what the icons mean ... Which bar is health? Which bar is Energy? ... Just say \"EXP:\" The meat? Why do I get meat here? ... Make the party display smaller and move it to the left ... loot earned in a box that fits the size of whatever the loot is, with your inventory under it ... all on one screen. I dont care how many foes were knocked out ... I want to see their energy levels too" | Systems developer | queued (after X6) |
| X6 | "Things need highlight when youre about to interact with them" | Systems developer | done (evening round) |
| X7 | "Take all should move money over too and the party menu should say total gold too" | Systems developer | done (evening round) |
| X8 | "Theres a random barrel here in the middle of the road, which is odd, and theres no asset for it. If we dont have a specific asset grey box it please" (forest_roads `forest_stash`, kind cache, at (19,14): only a tile glow and the ! marker show) | Systems developer | queued (after X7) |
| X8 | "You should be able to walk through stools, they make this whole room very hard to navigate" (tavern) | Systems developer | done (evening round; only stools, chairs and benches still block) |
| X9 | "These options should be conditional, we dont have a rogue in the party so they dont get a sneak hit. We havent done anything that warrants the ability to talk to them, so that shouldnt be an option" (the explore spot prompt: FIGHT / SNEAK HIT / TALK / BACK OFF on the elite ogre) | Systems developer | queued (after X8) |
| X9 | "Remove the Lorem Ipsum What do these icons mean? Hide the combat log behind the win window and make it much smaller. We dont need the second win lorem ipsum" | Systems developer | done (evening round) |
| X10 | "What is this whole menu on the right ... let's put all dialogue/actions/ right above the diamond" (overworld side panel; one standard place) | Systems developer | done (evening round) |
| X11 | "The bottom fram is HUGE and the player UI/actionbar is tiny" | Systems developer | done (evening round) |
| X12 | "I'd like for these skills to show their range when you hover over them" | Systems developer | done (evening round) |
| X13 | "I want to always be on a selected cahracter" | Systems developer | done (evening round) |
| X14 | "these windows should fit the size. there shouldnt be all this green space" (loot windows) | Systems developer | done (evening round) |
| X15 | "Fishing is still very fast ... it doesnt need to be so lightning fast from one part to another" | PM (pace), Systems developer (beats) | done (4425bd3, 24c2147, evening round) |

## Older standing asks still open
- Food as healing with no hunger ([USER] 2026-10-31 morale call; `docs/systems/morale.md` says not built, the road still eats every day). Owner: Systems developer (first account), done (2026-11-01, "Food heals, nobody hungers" commit); the numbers are on the desk as dev-food-review.
- Daily eating at camp again, an empty larder ends the journey ([USER] 2026-11-01, card dev-food-review: "The party must eat every day at camp, no food= journeys over"). Owner: Systems developer (first account), done (0b2acb3). The rest of healing waits for the healing model build.
- Healing model A with the camp meal picker ([USER] 2026-11-01, picked A on design-healing: "at the camp at night you as the player should pick what food they each eat or use a team Feast item if you have one"). Owner: Systems developer (first account), done (bb87663).
- Bushberry joins ([USER] 2026-11-01 milestone; cards design-bb-kit, design-bb-recruit, design-bb-morale, design-bb-menu): his kit, the rescue from the elite ogre and the tavern. Owner: Systems developer (first account), done (2f2acdc kit, 0ecc810 rescue, 23ba459 tavern); the captor group on the snow pass is the map builder's (note dev-to-builder-bushberry-captive).
- Picsart requests are tabled until Brandon checks in; then make him a doc of all art needs by priority (2026-11-01, see `docs/systems/studio.md`).
- PM note: once kit wiring and morale land, make a Project Report (every working system, what's built, what core pieces are missing), repeated at milestones.
- Playtest note: re-measure the Lich odds with the robot at the next milestone, after the road retune.

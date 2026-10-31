# Loot: container grids and the after-fight summary

Game designer, 2026-10-31. Approved by Brandon on `design-loot-present` (`[USER]` line in `docs/decisions.md`, with his leftovers rule). The open choice cards use my picks as defaults until he answers; each default is marked `[AI]`. Plain-English text, placeholders only for names.

## Container grid
- Open a chest, barrel, crate or body next to you with F or a click. A small grid opens beside the pack and belt, in the game's frames. The pack grid code (`InventoryGrid`, `PackView`) should be reusable for it: a container is a smaller `InventoryGrid` with the same item shapes, stacks and turning.
- Take items by dragging, or click to send the item to the first spot in the pack that fits (the pack's auto-place). `R` turns an item. TAKE ALL sends everything that fits, stops at the first thing that does not and says so. Items can be put back into the container to swap. `[AI]` defaults for the cards `design-loot-shapes`, `design-loot-takeall`.
- Sizes by type, in map data per container: body 2 x 1, barrel 2 x 2, crate 3 x 2, chest 3 x 3. `[AI]` (`design-loot-size`).
- Locks now, traps later `[AI]` (`design-loot-locks`): a locked container needs a key or a d20 lockpick check by a rogue; a failed check only costs the try, once per visit. No traps yet.
- Coins and keys do not take cells: coins go to gold, a key to the key ring.
- Containers are closed during a fight; bodies open after it.

## Leftovers (Brandon's rule)
What you leave in a container or pile stays while you are on that map, even after you clear it, so you can go back to room A. Leaving the map (the gate, a wake-up, GO HOME) ends it: the leftovers are gone and are not refilled. Items you took stay taken (the lasting-reward flags `got_<map>_<thing>` are unchanged). Open question for him: a half-emptied container refilling on a new visit; do not build refills.
- Road fights: the valley is left on CONTINUE, so what does not fit goes to the FOUND box (4 x 2, as today) and anything past that is lost. `[AI]`.
- The old FOUND overflow on pickups that are not containers is unchanged.

## After-fight summary
Shown when a fight is won, before control returns. Uses only what is tracked today.
- Result, rounds, foes down.
- Each party piece: XP gained and HP left; anyone who went down. A level-up opens the level-up screen next (`docs/design/level-up.md`).
- Bond gains.
- Loot as items in one shared grid, `[AI]` (`design-loot-summary`): food becomes meat stacks, medicine potions, from the group's `loot` string in `data/encounters.csv` or the map group's `loot`. Gold is a coin count beside the grid (it is a number on the run), not a cell.
- TAKE ALL, drag or click as in a container; CONTINUE closes. Leftovers follow the leftovers rule above (explore map: they stay as a pile on the map; road fight: FOUND, then lost).

## Notes for the developer
- Another build is already adding the dog's 2 x 2 saddlebag to the inventory screen; build the container grid on the same reusable grid so it is one component.
- Loot is per fight group, not per foe; do not add per-foe drops.

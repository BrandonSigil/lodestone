# Project instructions

The standing instructions set in Brandon's Claude project, copied 2026-10-27.

> For now, threads may push and merge to BrandonSigil/lodestone without asking Brandon first (granted 2026-10-26, to iterate fast; PR process tightens later). Never write story or copy; use caveman placeholders.

## Roles (from the project brief)
- Brandon: story designer, writer and art director. He decides story, copy, names, lore and the final look.
- Claude: systems designer, game designer and programmer. Proposals go into `docs/decisions.md` tagged `[AI]` until Brandon retags them `[USER]`.

## The game in one paragraph (systems only)
A Fire Emblem / Final Fantasy Tactics style grid tactics RPG fused with Oregon Trail travel survival, in a high fantasy setting. A fixed roster of characters unlocks through play; each has a class, 1 to 3 off-class skills, perks and a deficiency. Classes matter both in combat and on the trail (a star-reading mage who can wayfind, a hunter who feeds the party, a wizard whose books take inventory slots). D&D-style success checks for talking past or sneaking up on threats. Isometric maps where terrain, height and positioning matter. Minigames for fishing, hunting and herb finding. The Lodestone is the party's map and meta-progression: on a wipe it recalls everyone home, loot is lost, and the player re-picks a party. Visually the world shifts from familiar ("Earth") to strange ("Alien") the farther past the Wall the party travels. UI sits in a decorative frame around the scene.

## Placeholder text style
`BANDIT COME. lorem ipsum. [ FIGHT ] [ TALK ]`. All of it lives in `game/text/placeholder.csv`.

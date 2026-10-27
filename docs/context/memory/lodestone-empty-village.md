---
name: lodestone-empty-village
description: Brandon's calls on the empty village premise (settlers, corgi, gold, Lodestone, Wall, nobody start, jobs) and where the design doc lives
metadata:
  type: project
  modified: 2026-10-27T11:28:12.459Z
---

Design doc: repo `docs/design/empty-village.md` (draft 3, PRs #40, #41 and the draft 3 PR). Decisions under "Premise" in `docs/decisions.md`.

Brandon's answers, all 2026-10-27 [USER]:
- Settlers are simply NPCs you interact with between runs. No switching settler <-> party member.
- Corgi fights on the grid, has simple foraging/sniffing skills; ears perk up when danger may be near, or it's a squirrel.
- Keep gold and the shop, but only once a blacksmith or a traveling merchant settles in town.
- Lodestone stays: unearthed early, its power realized on the first death.
- The Wall stays; elves past it may have survived, or an elvish prophecy foretold this, so the hero heads there.
- Hero starts as a "nobody", leaves their house; a couple of weapons wait at the blacksmith's, a hidden item in a house for patient players; class develops Fire Emblem style with one or two branch choices for the hero and NPCs (he shared an FE Engage-like class tree chart).

- Levels persist through recall. Smithy has 3 weapons: sword, daggers, bow -> knight, rogue, archer (draft 3.1; magic stays with companions).

- One smithy weapon, final; others stay but can't be taken (respec maybe later). Hidden magic path: a book on a shelf in a home found by exploring town -> mage (wizard / healer branches). Draft 3.2 says where the book sits (ordinary home off the square, back shelf, out of sight from the door).

- Village prototype (PR #51) flags to build on: smithy rack sets weapon_sword / weapon_daggers / weapon_bow, the book sets found_book (explore thing kinds `rack` and `hidden`, with once flags). Corgi sniff not wired yet.

Still open: survivor kind fixed per character (assumed) or chosen once; who survives; tier 2 branch roles and names.

**Why:** these answers replace earlier [AI] proposals (swappable settlers, drop gold) and steer every later premise build.
**How to apply:** follow the doc's build order; don't revive the swap or no-gold ideas. See [[lodestone-explore-maps]] for the village opening map.

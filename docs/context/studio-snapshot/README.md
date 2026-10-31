# Studio snapshot (2026-10-31, end of day, handoff to another Claude account)

Brandon paused all system work so another Claude account can pick up exactly here. The Studio page (https://claude.ai/artifact/5NsBvyRP81zBRgAFCANTP5) holds the live desk, chat, notes and role status in its own database. That database belongs to the artifact, not the repo. This folder is a copy of what is open, so nothing is lost if the new account can't reach the page.

- Page source: `tools/studio-page/index.html` (how it works: `docs/systems/studio.md`). If the new account can't be given edit access to the page, it can publish its own copy from that file. The copy starts with an empty database, so re-post the open items below.
- Role status rows: `roles/*.json` (exported as-is).
- Role handoff notes: `docs/context/roles/<role>.md`. Start each role from its note, on Sonnet (Opus only for hard problems).

## Open on Brandon's desk
- **design-morale**: ANSWERED 2026-10-31T20:00Z, pick "build". Brandon: "All of this is great. Let's also have days tied to the journey, so that for every day gone, a char acter at home gets X morale." Not routed yet (held for the usage reset). Next: the game designer records it as [USER], replaces "+10 per run left home" with +X per journey day for characters at home, proposes X, and sends the build note to the systems developer.
- **bush-ne-go** (art runner, go): the blueberry bush NE turn. Brandon runs it by hand in Picsart, with the character board as Image 1 and the bush SE sheet as Image 2. Prompt in `art/prompts/hand-character-board.txt`.
- **hand-character-board** (art runner, go): the one-picture character board and its prompt. The blueberry bush SE was made with it and approved. It can stay open as the template for new characters, or be closed.

## Open notes (work handed between roles)
- **dev-mage-goodboy** (to the systems developer): the starting mage is firebolt, fireball, mend and ward (add fireball to `job_mage.tres` and a mage row to `kits.csv`). Doggo's passive Good Boy: the friend next to him heals 1 HP at the start of their turn. Good Boy's morale half waits on design-morale.
- **dev-doggo-goodboy** (to the systems developer): an older version of the same note. Fetch is the new name for carry. Superseded by dev-mage-goodboy.
- **play-outing-retune** (to the playtester): re-measure the Lich odds with the robot at the next milestone, after the road retune (`explore_foe_hp_pct` 70).
- **pm-project-report-request** (to the PM): once kit wiring batch 2 and morale land, make a Project Report: a high-level overview with every working system shown, what is built, and what core pieces are missing. Make it a recurring ritual at milestones. Keep honing usage.

## Where the work stands
- **Systems developer:**
  - Kit wiring batch 1 is in (`5de67b0`).
  - Batch 2 is next: the tracker, ember, chanter and tinker abilities and the remaining upgrade params.
  - Then the dev-mage-goodboy note.
- **Loot:** built and approved (`38c2a9c`): container grids, the after-fight loot grid, locked and trapped chests, and leftovers that stay until you leave the map. Doggo's 2 x 2 saddlebag is approved; Brandon asked for a much smaller dog picture or a "pack" label.
- **Art:**
  - Character sheets are SE + NE only; the game fills the other facings.
  - Done and in game: Amber (fire mage) at 80% of the hero's height, and the blueberry bush SE at 80%.
- **Usage:**
  - On 2026-10-31 the account hit 98% of its weekly limit.
  - The hourly desk-watch cron was cut.
  - Roles finish, commit and stop near the limit.

## Picked up (2026-10-31, new account)
The page is republished on the new account at https://claude.ai/artifact/5NsBvyRP81zBRgAFCANTP5 and the items above are re-posted there: the seven role rows, the three desk cards (design-morale as answered, the two go cards open, without their reference pictures) and the four notes (dev-doggo-goodboy marked seen). The References wall, Library, roadmap, log and chat start empty.

# The Lich Prince (recruit)

`[USER]` 2026-11-01 (decisions.md): the Lich's son, a knight-class companion with a cold twist who needs no rations. After the Lich is bested, he stops at 1 HP and offers his son as an apprentice. All numbers and the kit below are `[AI]` proposals until Brandon retags them. Dialogue is caveman placeholder; names and story are Brandon's.

## Kit (knight line, rage; same shape as Bushberry and Doggo)
- **Frost Blade** (basic): a normal melee hit; the foe is slowed (2 less move, 1 turn).
- **Ice Armor** (ally, range 1-3, rage 2): +2 armor for 2 turns; a foe that hits that friend is slowed.
- **Cold Snap** (self area, radius 1, rage 3): every adjacent foe takes 2 less than normal damage and is slowed.
- **Hoarfrost** (passive): a foe that ends its move next to him is slowed on its next phase.
- **Cold Blooded** (passive): eats no rations and takes no heal from food.
All skills get three upgrade steps in `ability_upgrades.csv` when built.

## No rations and healing model A
- He is not a mouth: the daily camp check and the "no food ends the journey" rule skip him; the camp meal picker shows him with "no food needed".
- Food does nothing for him: no heal from meat, no meal morale (team meals still feed everyone else).
- He heals from camp rest (50%, free), support skills and belt items, as every hero. His morale comes from camp rest, the bed and wins.
- Net: he saves the larder but cannot be topped up by cooking, so a hurt Prince leans on mend and rest.

## Progress and the yield (Brandon, 2026-11-01: third win)
Brandon replaced "a beaten boss stays beaten": every fight returns every run unless a story beat says otherwise. The Lich is the first story beat.
- `lich_wins` (persistent meta) counts wins over him. Wins 1 and 2 kill him as today (loot, boss XP, `e2e_done`).
- Win 3 is the yield: he stops at 1 HP (the fight ends as a win), sets `lich_relented` and `lich_yielded`; `lich_yielded` unlocks the Prince's recruit event.
- Later runs: the Lich starts calm. Walking up to him offers PASS (counts as the crypt's end and sets `e2e_done`) or FIGHT (a normal fight, normal loot, no new Prince).
- The crypt's end and the way on: `e2e_done`/TEST DONE fires on any win, the yield, or PASS. The pass on the overworld opens the mines after a run-scoped "past the Lich" flag; once `lich_relented`, it is open from the start.
- Old rule to remove: `stays_beaten` for bosses and elites, `clear_flag`/`after` walk-past, the beaten seal. A group is gone only if its data names a story flag (`relents`).

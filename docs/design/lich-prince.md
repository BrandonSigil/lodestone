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

## The trigger, and the beaten-for-good boss
`ExploreRules.stays_beaten` keeps a boss beaten once its `beaten_flag` is set; a boss killed once is never fought again. So "the times" cannot mean several kills. Whatever the trigger, the yield must be the one win that sets the beaten flag, plus a flag `lich_yielded` that unlocks his recruit event. A yield replaces the kill: the Lich is still beaten for good, just alive at 1 HP, and drops the usual loot.

## Open (desk card `design-lich-prince`)
Trigger: first win, third win (the Lich rearms until yielding; needs a win counter and a stays_beaten exception), or a win with nobody downed. `[AI]` pick: first win.

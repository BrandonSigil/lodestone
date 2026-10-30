# Bonds

[USER] 2026-10-30 design-village-life ("Bonds that grow"); numbers from the game designer's [AI] line that day.

- Every pair in the party (the hero, companions, the dog) has a bond, saved in `Game.meta.bonds` as {"dog+lead": points} (`BondRules.key`, ids in name order).
- After a won fight (explore and trail fights), each pair that fought gets +1 if both finish standing, +1 if one helped the other up (AID), +1 if one helped the other's strike (a team-up), at most 3 (`BondRules.award`, `Battle.award_bonds`). `Battle.deeds` records the help-ups and team-ups as the events play.
- Levels at 10, 25 and 45 points (Fire Emblem's C, B and A). Each level gives the pair +1 damage on team-ups with each other (`CombatRules.help_damage`, `CombatUnit.bonds` filled in `from_member`), so +3 at the top.
- Each level opens a talk for the pair: a TALK button in the Lodestone menu, working only at home (the village). The line is `BOND_TALK_<A>_<B>_<n>` in `text/placeholder.csv` (ids in name order, upper case, e.g. `BOND_TALK_DOG_LEAD_1`); until Brandon writes one, the slot shows `BOND_TALK_EMPTY`. Heard talks go in `Game.meta.talks_heard`.
- Numbers: `data/bonds.csv`. Gifts wait for the inventory build.

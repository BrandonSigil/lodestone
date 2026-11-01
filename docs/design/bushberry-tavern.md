# Bushberry joins, and the tavern

Game designer, 2026-11-01, for the milestone "Bushberry joins" (`pm-next-milestone`) and Pitch G (`master-g-first-companion`). Brandon's words are in `docs/decisions.md` (the 2026-11-01 Pitch G line). Everything here is `[AI]` until he picks on the four desk cards (`design-bb-*`). No story, no dialogue, no names from me; every text slot is a caveman placeholder in `game/text/placeholder.csv`, and rules text is plain English.

## What is already decided
- Bushberry is a mender/support with **one ranged damage spell that pulls a foe one cell toward him** (`[USER]`).
- Recruiting him **opens the tavern**: characters hang out and regain morale, and gold buys food items (`[USER]`).
- The food menu **grows with the resources, characters and recipes you bring home** (`[USER]`).
- How the tavern restores morale is open (the card below).
- His older traits stay: makes a ration a day (`bushberry_ration`), flammable (fire +2 damage taken), and `deep_roots`.

## What the game has today
- He sits in the village square as a `companion` thing with event `recruit_bushberry` (invite, send home, leave), unlocked by flag `found_bushberry`. That is the playtest line-up.
- The `tavern` explore map (12 x 11) exists, with the cook (`settler_chef`) and four containers, but nothing opens it.
- Morale is per character (`docs/systems/morale.md`): a night in the hero's bed +20 once a trip, camp +10, camp meals +10, +15 or +25, and each journey day a companion left at home gains `home_day` (3).
- Food items have `price`, `food` and `medicine` in `data/items.csv`. Food as healing is being built by the systems developer; the tavern menu must use whatever item columns that build lands.

## 1. Finding and recruiting him (card `design-bb-recruit`)
The flow, my pick: he is a bush beside the road on the **snow pass**, off the main path. Interacting offers INVITE or LEAVE (the existing `companion` event). INVITE puts him in the party. He is **recruited for good the first time he reaches the village in your party**, which sets flag `tavern_open` and opens the tavern door. If you fall on the way, he is still met, and he comes home with the wake-up (everyone wakes in the square), so it counts.
Conditions: none to meet him; you just have to find him. No cost. The text is placeholder.

## 2. His kit (card `design-bb-kit`)
Resource: mana (`job_mender` numbers, move 3). Four abilities, each with three upgrade steps in `data/ability_upgrades.csv` (existing rows for mend, ward, renew, far_aid):
- **tug** (new): a ranged spell. Range 2-4 (scaled by scale C), costs 3 mana, damage 1 less than his spell damage, and the foe is **pulled 1 cell toward him**. Pull is the push system with a negative push (`push:-1`, as `lure` has `push:-2`). Upgrade steps: more damage, more range, 1 less mana.
- **mend** (heals 4 plus magic, existing), **ward** (the next hit on a friend does nothing, existing), **renew** (heals over time, existing, unbuilt effect) and **far_aid** (helps a downed friend up from 3 tiles, existing, unbuilt effect).
My pick is tug, mend, renew, far_aid: the full healer, since the tug is his one attack. Passives: `bushberry_ration` (makes a ration each journey day, which now heals, so it is a food source), `flammable` and `deep_roots` as before.

## 3. How the tavern restores morale (card `design-bb-morale`)
Today morale comes back by the hero's bed (+20, once a trip), camp (+10), meals, and journey days at home (+3 a day for each companion left home). The tavern adds, in my pick: **meals bought there** (a stew gives 10, a roast 15, a feast 25, as the recipes already say) and **a hang-out bonus: a companion left at home gains 2 more morale per journey day while the tavern is open** (3 becomes 5). A free evening is the third option.

## 4. The food menu at its first size (card `design-bb-menu`)
Bought with gold at the tavern counter, going into the pack as items. First size, my pick: **three dishes**, a ration (2 gold, heals 4), a jerky (7 gold, heals 16) and a stew (10 gold, heals 6 and +10 morale).
It grows by data rows in a new `data/tavern_menu.csv` (item, price, `needs`): a dish appears when you bring home its resource (herb, ingredient, rare), when its recipe unlocks (the inn's kitchen steps), or when a character who cooks or brings it joins. Dishes' names are placeholders.

## Build order
1. His recruit flow, the `tavern_open` flag and the tavern door opening.
2. His kit: `tug` in `abilities.csv`, the `kits.csv` rows, upgrade steps.
3. The tavern counter: `tavern_menu.csv`, buying with gold into the pack.
4. The morale hooks (hang-out bonus, meals) in `MoraleRules`.

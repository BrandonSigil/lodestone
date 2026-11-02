# Word Swap

Brandon's page for replacing placeholder text: https://claude.ai/artifact/8N6JE8v7QGYGpJJhusHraj (asked in the Studio chat 2026-11-02: "Can you make me an interactive document where we find & replace caveman/lorem ipsum speech? Like give me a "YOU WIN LOREM IPSUM" and then another field where I can replace it and send it").

- **What he sees:** every line of `game/text/placeholder.csv`, with its section, its key and the files that use it, the old words (lorem and ipsum highlighted, `%d`/`%s` slots marked), and a field for his words with a Send button.
  - Filters: Placeholders (everything but rules text), Lorem ipsum, Rules text, Sent, All. A search box and a section picker.
  - A line whose old words have `%d` or `%s` can only be sent with the same marks, since the game fills in a number or word there.
- **Dialogue tab (the default, Brandon 2026-11-02: "If its a dialogue then also print some fields below it that I can pick what the options/responses are too"):** every event in `game/data/events.csv`, `travel_events.csv` and `explore_events.csv` is one card. It shows the prompt, then each response with what it needs and what it does in plain words (from the opt columns), each with its own field. A response shared by several dialogues (like LEAVE) says so, since changing it changes all of them. "Add a response" writes `asks/<id>` as `{event, text, what, at, status: "sent"}`: a new option he wants, with what it should do.
- **Tabs:** Dialogue, Story lines (talk, bond, mayor, quest, shop and party lines), Names, Game text (ours to write since [USER] 2026-11-02), Lorem ipsum, Sent, All.
- **What Send does:** writes `swaps/<KEY>` in the page's database as `{key, old, new, at, status: "sent"}`. On a computer, a comment to Claude follows about 12 seconds after his last send ("Word swap from Brandon: N lines sent ..."). On a phone it waits for the "Tell the team" bar.
- **Applying them (PM, on that comment or at the start of a turn):**
  1. Read the sent lines with ArtifactData: `query swaps where status == "sent"`, saved with `out_dir`.
  2. Run `~/.lodestone/venv/bin/python tools/word_swap.py apply <that folder>`. It changes only those lines, quotes them when they hold a comma, and refuses a line whose % marks changed or whose key is gone.
  3. Run `tools/check.sh`, then commit the CSV.
  4. Run `word_swap.py export` and republish `tools/word-swap/index.html` with `files: {"rows.json": "tools/word-swap/rows.json"}`, so the page shows his words as the current ones.
  5. Set each applied doc's `status` to `"applied"` (the page shows "In the game"). Tell him in the Studio chat how many went in, and name any that were refused and why.
- **New responses (asks):** read `asks where status == "sent"`. A new option needs a new text key in `placeholder.csv` (his words), plus the next free `optN_*` columns on that event row, with the need, check and outcome he described (or the closest existing ones, with a note to him if anything had to be guessed). That's systems work: route it to the developer with his words, then set the ask's `status` to `"done"` once it's in.
- **His words are his.** Put them in exactly as he wrote them, apart from joining them onto one line. Never edit or "fix" them.
- **Rows file:** `tools/word-swap/rows.json` is made by `word_swap.py export`. Re-export it whenever the CSV gains keys, so new lines show up on the page.

# Word Swap

Brandon's page for replacing placeholder text: https://claude.ai/artifact/8N6JE8v7QGYGpJJhusHraj (asked in the Studio chat 2026-11-02: "Can you make me an interactive document where we find & replace caveman/lorem ipsum speech? Like give me a "YOU WIN LOREM IPSUM" and then another field where I can replace it and send it").

- **What he sees:** every line of `game/text/placeholder.csv`, with its section, its key and the files that use it, the old words (lorem and ipsum highlighted, `%d`/`%s` slots marked), and a field for his words with a Send button.
  - Filters: Placeholders (everything but rules text), Lorem ipsum, Rules text, Sent, All. A search box and a section picker.
  - A line whose old words have `%d` or `%s` can only be sent with the same marks, since the game fills in a number or word there.
- **What Send does:** writes `swaps/<KEY>` in the page's database as `{key, old, new, at, status: "sent"}`. On a computer, a comment to Claude follows about 12 seconds after his last send ("Word swap from Brandon: N lines sent ..."). On a phone it waits for the "Tell the team" bar.
- **Applying them (PM, on that comment or at the start of a turn):**
  1. Read the sent lines with ArtifactData: `query swaps where status == "sent"`, saved with `out_dir`.
  2. Run `~/.lodestone/venv/bin/python tools/word_swap.py apply <that folder>`. It changes only those lines, quotes them when they hold a comma, and refuses a line whose % marks changed or whose key is gone.
  3. Run `tools/check.sh`, then commit the CSV.
  4. Run `word_swap.py export` and republish `tools/word-swap/index.html` with `files: {"rows.json": "tools/word-swap/rows.json"}`, so the page shows his words as the current ones.
  5. Set each applied doc's `status` to `"applied"` (the page shows "In the game"). Tell him in the Studio chat how many went in, and name any that were refused and why.
- **His words are his.** Put them in exactly as he wrote them, apart from joining them onto one line. Never edit or "fix" them.
- **Rows file:** `tools/word-swap/rows.json` is made by `word_swap.py export`. Re-export it whenever the CSV gains keys, so new lines show up on the page.

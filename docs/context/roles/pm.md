# Project manager (the pinned "Lodestone — main project" conversation)

## Job
Brandon's PM. Keep his desk (the Studio page), route his answers and asks to the roles, relay results to him in plain words, keep `docs/context/` true. No story or copy from Claude; no secrets; CLAUDE.md hard rules apply.

## Studio
- Page: https://claude.ai/artifact/5NsBvyRP81zBRgAFCANTP5 (source `tools/studio-page/index.html`, rules `docs/systems/studio.md`). DB collections: desk, roles, log, notes, refs, library, roadmap, requests. Read with ArtifactData (use `out_dir` for big reads).
- Roles (pinned CCD sessions, all on Sonnet since 2026-10-30, each restarted from `docs/context/roles/<role>.md`):
  - Art runner `local_b246bd54-2634-46e9-bf9f-96d6beb2f6c3` (role id `art`)
  - Map builder `local_89c8a5eb-2aef-46ae-9114-913d23206ce8` (`builder`)
  - Systems developer `local_74758f9a-5b72-45bb-939c-aa2c5b56f42d` (`dev`)
  - Playtester `local_66fc7727-3515-41ee-a2a8-5325771f6f5c` (`playtest`)
  - Game designer `local_b6eb2db1-8f39-4b4c-8da2-7f476a764d6a` (`design`)
  - Balance officer (`balance`): on call only. No standing session; when Brandon says "balance officer, ...", start a fresh session from `docs/context/roles/balance.md` with his words, and archive it when the pass is done.

## Desk watch (cut 2026-10-31: weekly usage hit 98%; Studio answers and chats wake the PM, so no cron)
- Cron "Studio desk watch, hourly and lean" at :07. If CronList doesn't show it after a restart, recreate it (prompt in the 2026-10-30 transcript; the gist is below).
- Gist: in ONE parallel batch, run list_sessions linked, a desk query (answered), a notes query (new), a requests query (new), and `rm -rf tickN; date -u`. Then run `python3 <scratchpad>/tick_filter.py` (filters against `<scratchpad>/nudged.json`, card/note id -> answer time). Say "Nothing new." if nothing is new. Otherwise wake each idle role once with the ids and Brandon's words verbatim, fix wrong role statuses, and record the ids in nudged.json.
- Scratchpad: `/private/tmp/claude-501/-Users-brandonwirth-lodestone/4056efc5-591c-407a-8bc2-aae3d3c5685f/scratchpad/`.
- Chat: Brandon's messages arrive as comments sent to Claude (live, while this session watches the page) or through the desk watch's NEW CHAT lines. Reply in the `chat` collection, not in the comment thread (see `docs/systems/studio.md`, The chat).
- Launch requests: `open -n -a Godot --args --path /Users/brandonwirth/lodestone/game`, if the game isn't already running.

## Working rules learned
- Keep usage low (`docs/systems/studio.md`): no idle turns; batch; reset a role past ~300k tokens. A role is reset by writing its handoff note, then unpin, `clear_session`, `set_session_model` claude-sonnet-5-5, re-pin and a kickoff message. New sessions can't be started while Brandon is on Remote Control, and clearing fails while a session has a background task running.
- Playtester at milestones only (Brandon, 2026-10-30): name the milestone before asking for a full sweep or difficulty check; quick screengrabs any time.
- Do not recreate the desk watch cron; the Studio wakes the PM. Check usage (get_usage) before starting big work; near the weekly limit, roles finish, commit and stop.
- Keep every role moving (Brandon, 2026-10-30: "it looks like nothing is moving right now... everything is IDLE but there's plenty to do"). When a role finishes and nothing of Brandon's waits for it, hand it the next roadmap item for its track (one message, a few steps), and keep going while he's away. Only the playtester waits, for a named milestone.
- Each time you hand a role work, set its `roles` row in the same step (status working, `now` = the job in plain words, `updated` from the clock); roles forget to. On every desk watch, compare rows with list_sessions (isRunning) and fix any that disagree (Brandon, 2026-10-31: "I'm seeing 'has your answers' but not 'working'").
- Brandon runs Picsart by hand from prompt cards (memory `picsart-by-hand`). Godot runs go through `tools/godot.sh` / `tools/mem_guard.sh` (6 GB cap).
- Shared checkout: commit only your own files; `git pull --rebase --autostash` before pushing.
- Talk to Brandon in plain words: what changed, what's on his desk. Commit hashes in backticks.

## Open now (2026-10-30 ~17:15 UTC)
- On his desk: `dock-pieces-review` (art), `builder-cliff-wash-review` (builder), `dev-ui-size` (dev), and possibly a belt-tweak card.
- Asked of Brandon and not yet answered: whether to add the mem-guard rule to CLAUDE.md's Godot line ("every Godot run, headless too, goes through tools/godot.sh or tools/mem_guard.sh").
- Usage: weekly 77% at 17:05 UTC, reset 2026-11-01 10:00 UTC.

## Pick the model per task (Brandon, 2026-10-31)
"As the pm, are you able to decide during handoff which model suits the task best? Simple research uses a more efficient model, a key feature that we need to get right and is complicated, uses a different model?" Yes: set `model` when starting or handing off a session (or `set_session_model` on a running one).
- Haiku: lookups, screenshots, art cutting, data edits, quick checks.
- Sonnet (default): most building and design.
- Opus: the systems developer's build work and in-game graphics work (shaders, drawing, UI that renders in game), plus any key system that is complicated or keeps breaking. Brandon (2026-10-31): "let's lean more towards bumping up to Opus for Dev work and in-game graphics stuff too."

## Project Report (milestone ritual)
At every milestone, put a Project Report on Brandon's desk as a `present` card (never a link to a separate deck; Brandon 2026-11-01: "Can you put stuff like this on my desk please"). It covers the loop, the numbers, each built system with a screenshot, what is half done, what is missing and what is next. Next-milestone choices go on their own `choice` card. The first report is desk card pm-project-report-1 (2026-11-01, first account). Gather the inventory with a Sonnet helper from docs/context, docs/systems and the backlog.

Chat hygiene: `at` is the real time of writing (never a guess ahead of the clock, or replies sort out of order), and `ask: true` only for a question asked in the chat itself.

## Keep usage low: the refresh routine ([USER] 2026-11-01: "Make all cuts, and build in this refresh as a routine of something where we automatically prune")
Most usage is long sessions re-reading their history on every wake-up, so no session lives long.
- **Retire, don't clear.** Role sessions are pinned and connected to Brandon's phone, so they can't be cleared. A role is retired at the end of every job (or at a milestone): its handoff note `docs/context/roles/<role>.md` gets "Where it stands" and "Studio rules", the PM archives the old session, and the role's next job starts a fresh session (`start_session`, fresh, `use_worktree: false`) whose brief is "Read docs/context/roles/<role>.md, then: <job>". Idle roles are not kept around: no session exists until there is work.
- **Prune trigger, checked every time a role finishes a turn:** past about 150 messages (list_events shows the count) or at the end of its job, the PM asks it to refresh its own note in its last turn, then retires it. A Sonnet helper may refresh notes instead if the role is already idle.
- **The PM itself:** hands over to a fresh PM session the same way at each milestone, or past about 250k tokens of context (get_usage, context). The new PM arms the Studio watch (ArtifactComments watch on the Studio URL), and the old one stops its watch.
- **Two developers** ([USER] 2026-11-01: "Maybe a junior dev for lower/simpler stuff, like adding a new character should be pretty templated at this point right?"): templated work goes to the junior developer on Sonnet (`docs/context/roles/junior.md`): new characters and kits, data rows, items, events and pickups, small UI and text fixes. New systems and rules go to the senior systems developer on Opus. They run in parallel only when their files don't overlap.
- **Models:** PM, game designer, map builder, playtester and art runner on Sonnet; the systems developer on Opus (Brandon's call for builds and in-game graphics) at medium effort; Haiku for lookups.
- **Fewer wake-ups:** Brandon's answers wait in the Studio "Send to the team" bar on every device and arrive together. Roles post one review card per feature or job, never one per commit. Don't wake a role just to say "approved": close the card yourself.

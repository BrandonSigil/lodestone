# Lodestone Studio (the home base page)

Brandon's home base: https://claude.ai/artifact/BNSLpKC1ZLXCeKnmPvVmo7 (private to his account). Page source: `tools/studio-page/index.html`. Republish it from the main project conversation, or from any session by passing that URL to the Artifact tool.

Three rooms:
- **Office**: Brandon's desk (cards that need his answer) and the team panel (each role's status, log and the notes he leaves them).
- **References**: the exact pictures Claude attaches for each kind of art, with the prompt files that send them.
- **Library**: every folder of generated art, one shelf per folder, with status (approved, draft, test, reference, archived).

## The rule
Any decision Brandon owes goes on the desk as a card, with screenshots, not as a question buried in chat. That includes every Picsart batch: a "go" card before the run, then a "review" card with the results, each scored against the References wall, for his stamp. You may also ask in chat, but the card is the record.

## The records (the page's database)
Read and write them with the `ArtifactData` tool and the URL above. Pin every write to a document you read with `if_version`; create new ones without it.

| Collection | One document is | Fields |
| --- | --- | --- |
| `desk` | a card | `kind` (`choice`, `go`, `review`, `todo`), `title`, `role`, `ask`, `context`, `images` [{url, caption}], `priority` (low first), `created` (ISO), `status` (`open`, `answered`, `done`), `answer`, `result` |
| `roles` | a chair | `name`, `job`, `status` (`working`, `waiting`, `idle`, `blocked`), `now`, `next`, `updated`, `order` |
| `log` | one line of a role's work | `role`, `at`, `text`, `image` (optional) |
| `notes` | a note Brandon left a role | `role`, `text`, `images` [{url, id}], `at`, `status` (`new`, `seen`) |
| `roadmap` | a track on the Roadmap (quick action) | `title`, `order`, `owner` (role id), `items` [{title, status (`done`, `doing`, `next`, `later`), ref (commit)}] |
| `requests` | a quick-action request from the page | `kind` (`launch`), `status` (`new`, `done`), `at`, `result`, `done_at` |
| `refs` | a group on the References wall | `title`, `used_for`, `warning`, `images` [{url, caption, path, slot}], `prompts`, `order`, `retired` |
| `library` | a shelf | `title`, `path`, `kind` (`ingame`, `raw`, `code`), `status`, `note`, `items` [{url, name}], `order` |

Card kinds:
- `choice`: `options` [{id, label, detail, image}], `multi` for pick-many. The page always adds **Neither** with a required "why". Answer: `{picks, why, at}`.
- `go` (Picsart go-ahead): `batch` {prompt, model, count, cost, refs [{url, caption}]}. The cost on the card is a ceiling: if a run would go past it, stop and post a new `go` card for the rest. Answer: `{pick: "go" | "nogo", why, at}`.
  - Run by hand (Brandon, 2026-10-30: "have it on my desk with a prompt and one image reference if needed. Then I'll do that part manually with my picsart subscription"; "You can do that as much as you want, I have a big picsart budget"): a `go` card whose `batch.prompt` is the full copy-ready prompt (written for at most one reference, saved as `art/prompts/hand-*.txt`), `batch.refs` holds that one picture from the References wall (or none), `batch.count` the settings (GPT image, 2K, aspect, how many), and `batch.cost` reads "your Picsart subscription". Brandon runs it, answers Go and pastes the pictures into the answer; the art runner reads each one, cuts and scores it and brings a review card as usual. No cost ceiling applies, so use these freely for redos, extra tries and variants; batch related asks onto one card.
- `review` (Picsart results): `items` [{id, url, caption, score 1-5, notes}]. Score each against the References wall, honestly. Answer: `{items: {id: {verdict: "approve" | "redo" | "reject", note}}, why, at}`.
- `todo`: Brandon marks it done himself.

Pictures from Brandon: any answer, and any note, may carry `images` [{url, id}] that he pasted, dropped or picked into the box. Look at every one before acting: read it with the Artifact tool (`action: "read"`, the studio `url`, `path` = the picture's `id`, the 32 hex characters after `/_blob/`), which saves it to a local file, then open that file with Read.

## How a session uses it
1. At the start of a turn, read `desk` cards with `status: "answered"` for your role, and `notes` with `status: "new"`. Act on them.
2. When you've acted, update the card: `status: "done"` and a one-line `result`. Mark notes `seen`.
3. Post progress: update your `roles` doc (`status`, `now`, `next`, `updated`) every time you start a new item, not only when you finish, and take `updated` from the clock (`date -u +%Y-%m-%dT%H:%M:%SZ`), never a guess. The project manager's desk watch also copies your live working/idle state from the Claude app every 15 minutes and add `log` lines for real milestones (a commit, a batch back), with a screenshot when there is one.
4. Pictures: upload with the Artifact tool (`url`, `asset: true`, `file_paths`), then use the returned `/_blob/<id>` url in the record. Make web copies first (`magick in.png -resize '1600x1600>' -quality 82 out.webp`); several art files on the Mac are Git LFS stubs and won't convert.
5. Approved art still goes into `docs/art/ART-LOG.md` and `game/art/source` as before; the stamp on the page is the approval to record.

## Keep the walls true
- References: when a prompt starts sending a different picture, change its group on the wall the same day. If it isn't on the wall, Claude isn't using it.
- Library: add a shelf (or items) for every new batch folder; flip its `status` when Brandon stamps it.

## Quick actions (masthead)
- **Status report**: Claude writes it in the page from the desk, roles, log and roadmap (the page's `sample` capability). Nothing to do here, except keep those records true.
- **Roadmap**: one `roadmap` doc per track. When a role finishes or starts a step, it flips that item's `status` and adds the commit as `ref`; new approved build orders become new items. The project manager keeps tracks and order tidy.
- **Launch game**: the page calls the local MCP tool `host:lodestone` / `launch_game` through the Claude app (`tools/launcher/lodestone_mcp.py`, standard-library Python; register it once with `python3 tools/launcher/install_mcp.py` and restart the Claude app). It only works with the page open in the Claude app on the Mac. Otherwise the window's "Ask the project manager" button writes a `requests` doc with `kind: "launch"`; the desk watch launches the game and marks it `done` with `done_at` and a one-line `result`. A web page can't open `lodestone://` links from the artifact frame, so the Launch button no longer uses them; `tools/launcher/build_launcher.sh` still builds a Dock/Spotlight Lodestone Launcher app.

## Keeping usage low (Brandon, 2026-10-30)
Every step a session takes re-reads its whole memory, so a long session is expensive even when it only says "still waiting". The rules:
- **Sonnet by default.** Roles run on Sonnet; switch a role to Opus only for a hard engine or design problem, then back.
- **Fresh sessions from handoff notes.** Each role keeps `docs/context/roles/<role>.md` (under about 60 lines: job, rules, now and next step, open card and note ids, key files, gotchas, uncommitted work). When a role's memory passes about 300k tokens, it updates the note, says "handoff ready", and the project manager starts a fresh session from it and archives the old one.
- **No idle steps.** Don't take a turn just to report "waiting on the robot" or "still running". Start long runs in the background and say nothing until they finish.
- **Playtester at milestones only** (Brandon, 2026-10-30). Full robot sweeps and difficulty checks only at a milestone the PM or Brandon names; quick screengrabs are fine any time. Other roles don't ask for a sweep after each change.
- **Batch.** One balance run with every variant, not rounds of tweak and re-run. One message per handoff, not a running commentary.
- **Lean desk watch.** The project manager checks the desk hourly, in one parallel batch, and stays silent when nothing is new.

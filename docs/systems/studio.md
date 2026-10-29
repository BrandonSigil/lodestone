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
| `notes` | a note Brandon left a role | `role`, `text`, `at`, `status` (`new`, `seen`) |
| `refs` | a group on the References wall | `title`, `used_for`, `warning`, `images` [{url, caption, path, slot}], `prompts`, `order`, `retired` |
| `library` | a shelf | `title`, `path`, `kind` (`ingame`, `raw`, `code`), `status`, `note`, `items` [{url, name}], `order` |

Card kinds:
- `choice`: `options` [{id, label, detail, image}], `multi` for pick-many. The page always adds **Neither** with a required "why". Answer: `{picks, why, at}`.
- `go` (Picsart go-ahead): `batch` {prompt, model, count, cost, refs [{url, caption}]}. Answer: `{pick: "go" | "nogo", why, at}`.
- `review` (Picsart results): `items` [{id, url, caption, score 1-5, notes}]. Score each against the References wall, honestly. Answer: `{items: {id: {verdict: "approve" | "redo" | "reject", note}}, why, at}`.
- `todo`: Brandon marks it done himself.

## How a session uses it
1. At the start of a turn, read `desk` cards with `status: "answered"` for your role, and `notes` with `status: "new"`. Act on them.
2. When you've acted, update the card: `status: "done"` and a one-line `result`. Mark notes `seen`.
3. Post progress: update your `roles` doc (`status`, `now`, `next`, `updated`) and add `log` lines for real milestones (a commit, a batch back), with a screenshot when there is one.
4. Pictures: upload with the Artifact tool (`url`, `asset: true`, `file_paths`), then use the returned `/_blob/<id>` url in the record. Make web copies first (`magick in.png -resize '1600x1600>' -quality 82 out.webp`); several art files on the Mac are Git LFS stubs and won't convert.
5. Approved art still goes into `docs/art/ART-LOG.md` and `game/art/source` as before; the stamp on the page is the approval to record.

## Keep the walls true
- References: when a prompt starts sending a different picture, change its group on the wall the same day. If it isn't on the wall, Claude isn't using it.
- Library: add a shelf (or items) for every new batch folder; flip its `status` when Brandon stamps it.

# D4 and D5: what the agent counts consist of

D4 and D5 sat as `needs info` for the whole of the D lane, and §"D's three remaining
rows cannot be worked" in the roadmap ledger says so plainly: a row whose meaning is
not recorded cannot be worked without guessing. The operator was asked and answered
on 2026-11-27, and the answer is the reading this work implements:

| Row | Ledger text | Reading the operator accepted |
| --- | --- | --- |
| D4 | Instinct and/or Hermes and other agent integrations for the companion | show what the harnesses on this Mac actually wrote: a session list, and the tail of the one you open |
| D5 | Subscription or API key for the companion to use | show what the usage those keys and subscriptions already produced costs, per agent, per model, per project, per period |

D5 is therefore *not* a purchasing flow. Nothing is bought, no key is entered here, and
the OpenCode Go key registry from D3 is untouched. The page reports on spend that has
already happened and says so when a model has no price.

## Sessions (`AgentSessionCatalog`)

A bounded walk of four roots, then file attributes. Nothing is read from a file until
that session is opened.

| Harness | Root | Files | Depth |
| --- | --- | --- | --- |
| jcode / kcode | `~/.kcode/sessions` | `.journal.jsonl`, `.json` | one level |
| codex | `~/.codex/sessions`, `~/.codex/archived_sessions` | `.jsonl` | recursive |
| claude | `~/.claude/projects` | `.jsonl` | recursive |
| copilot | `~/.copilot/session-state` | `events.jsonl` | exactly two parts, non-dot parent |

OpenCode has no entry on purpose. Its sessions live in a SQLite database, and a preview
built by guessing at that schema is how a preview prints something it should not.

Bounds: 200 sessions, a 300-second live window, 64 KiB of a file read for a title (the
first 40 JSON lines, looking for `title`, `summary` or `name`, else the file name),
directories beginning with a dot and package-shaped directories skipped, an unreadable
file skipped rather than surfaced, newest first with the path as tiebreak.

## Transcript (`AgentTranscript`)

The opened session only, from its last 4 MiB, dropping a partial first line, 60 lines,
1200 bytes of text per line.

A line whose keys mention an environment, a snapshot, an API key, a token, an
authorization header or a system prompt is dropped **whole**. It is not partly
understood and then printed: a redaction that keeps the interesting half of a line is a
redaction that leaks. Lines survive only from `text`, `content`, `message`, `prompt` or
`completion`, as a string, as `[[String: Any]]` parts, or as a nested `[String: Any]`
`text`; the speaker is read from `role`, `type` or `kind`.

## Spend

The same published snapshot the island's card reads, so the two cannot disagree. The
section adds the breakdown the card has no room for: a period picker (today, week,
month), a headline, one bar per agent, the top five models and top five projects by
cost share, a note when some model has no price, and today's remaining budget on the
today period only.

The headline and the bars switch between cost and tokens **together**. A dollar figure
next to a token count on the same row is the one way this page could mislead someone
about what they spend.

## Evidence, and what is not evidence

* Linux subset: **220 checks** (`bash Tests/LinuxSubsetCheck.sh`), up from 177, with
  `agent-session-catalog` 13, `agent-transcript` 17, `agent-session-source-rules` 4 and
  `agent-insights-wiring` 9.
* The wiring suite asserts the two sections are mounted in the agents page and that the
  transcript view cannot be handed a session the section did not choose, from the source
  rather than from a rendered window.
* **Nothing was rendered.** Field placement, bar lengths, the empty states and the
  budget line are source readings until someone opens the page on a Mac. That is the
  honest state of the evidence and it is why the row says `shipped` with a rendering
  caveat rather than `verified`.

## Not done

* No session can be resumed, deleted or opened in its own harness. This reads.
* herdr panes are not merged into the list. D2's reader holds pane state and no
  session identity, so a pane row here would be a guess.
* Nothing distinguishes two sessions of the same harness beyond their path.

> Original produced as scratch research on 2026-11-21 and preserved here verbatim; the scratch copy lived on volatile storage outside this repository.

# D2 — herdr session and pane state: verified contract spec

Task: `docs/ROADMAP_LEDGER.md` row **D2** — "herdr session and pane state through the
documented contract (`HERDR_*`, `pane.report_agent_session`)".

Status: spec only. No repository changes, no commits. Written to `E:\koosh\Agents\scratch\d2-spec\`.
Host inspected: Windows 11, `kooshapari-desk`, 2026-11-21 15:19–15:28 local (23:19–23:28Z).
C: measured 497,288,294,400 bytes free, below the 500 GB threshold, so this file lives on E:.

---

## 0. Verified contract in ten lines

1. Two different herdr generations are installed: `herdr` 0.9.3 and 0.9.5 (terminal workspace
   manager, socket API protocol 22) and `herdr-core`/`hc` 0.1.21 plus `herdr-app` (the HC rewrite).
2. `pane.report_agent_session` **does exist** in both installed 0.9.x builds: as a CLI subcommand
   (`herdr pane report-agent-session`) and as socket method `pane.report_agent_session` in the
   bundled schema (`herdr api schema --json`, schema_version 1, 102 methods). The last reported
   identity also survives at rest in `%APPDATA%\herdr\session.json` as
   `pane.agent_resume{source, agent, argv}`.
3. The 0.9.x method set is identical between 0.9.3 and 0.9.5 (102 methods, protocol 22), so the
   documented contract is stable across the two installed builds.
4. `HERDR_*` variables are set in this process — `HERDR_ENV=1`, `HERDR_WORKSPACE_ID=wJ`,
   `HERDR_TAB_ID=wJ:t4`, `HERDR_PANE_ID=wJ:p5G`, `HERDR_BIN_PATH=<0.9.3>`,
   `HERDR_SOCKET_PATH=C:\Users\koosh\AppData\Roaming\herdr\herdr.sock` — but they are **stale**:
   that server shut down at 2026-11-21T07:27:44Z and the socket file does not exist.
5. Every 0.9.x API call fails with `{"error":{"code":"server_not_running"}}`, including
   `pane report-agent-session` (verified by invoking it).
6. The live product on this host is HC: `hc server status` reports core `kooshapari-desk`
   (id `e053d16013d3693604448a7e483c9dc6`), version 0.1.21, uptime 60,327,155 ms, 29 live and
   28 finished terminals, one holder with 29 terminals.
7. HC's transport is a Windows named pipe, not a socket file: `\\.\pipe\herdr-core-koosh-default.sock`
   accepted a client connection; `herdr-core-koosh-default.holder.e3480698.sock` also accepted one.
8. HC's read surface is `hc ls`, `hc get <t>`, `hc events --json`, `herdr-app ls`, `herdr-app status`,
   and a persisted snapshot at `%LOCALAPPDATA%\herdr-core\default\terminals.json` (76,229 bytes,
   57 entries, rewritten in place within the last minute).
9. HC has **no** agent-session identity channel: no `report_agent_session` equivalent, no session id
   or path in `terminal.get`, `terminals.json` or `events`. Agent identity can only be inferred from
   `foreground.argv` (e.g. `kcode.exe --resume session_mushroom_…`) and `title`.
10. HC does have pane lifecycle state, via OSC 7501 status reports: `idle`, `working`, `done`,
    `blocked`, `error`, with `state` being `live` or `finished`. That is the closest analogue to the
    ledger's "pane state" and it comes from the agent itself, not from screen scraping.

---

## 1. What the repository requires of a herdr reader

Read seam, verified in this clone on branch `dev/maccy-clipboard-parity` (HEAD `545f69b2`).

`Sources/Vorssaint/Services/AgentUsage/Harness/` holds the D1/D3 slot:

- `AgentHarnessReader.swift` defines `protocol AgentHarnessReader` (`provider`, `parse(_:state:now:)`,
  `readsFullHistoryFirst`) and `extension AgentProvider { var reader: any AgentHarnessReader }`
  dispatching over `.claude/.codex/.opencode/.copilot`.
- `AgentLogParser.swift` models every reader's output as `enum AgentLogEntry`:
  `usage`, `usageModel`, `limits`, `plan`, `turnBegan`, `turnContext`, `turnActive`, `turnSettled`,
  `turnEnded`, `reset`. `AgentLogState` carries per-source context (`session`, `project`, `model`,
  `turnOpen`, provider-specific extras).
- `AgentUsageStore.swift` consumes those entries. Live turns are
  `turns[file] = AgentLiveSession(...)` keyed by source path; `turnBegan`/`turnActive` create or
  refresh, `turnSettled` marks `settled[file]`, `turnEnded` removes and may emit `.finished`.
- `AgentUsageModels.swift` defines `AgentLiveSession` as
  `{ id, provider, started, lastActivity, model, project, tokens, cost }`, and `AgentProvider` as
  `enum { claude, codex, opencode, copilot }` with `displayName`, `symbol`, `reportsLimits`.
- `AgentUsageSummary.swift` filters both `live` and `limits` by an enabled-provider set, and
  `NotchAgentSupport.providers(in:)` reads the per-provider toggles
  (`notchAgentsClaude/Codex/OpenCode/Copilot`, all default `true` in `Defaults.swift:1546`).
- `AgentLogRoot.all(home:claudeProfile:)` (`AgentUsageStore.swift:475`) is the path contract for
  file-backed providers: a provider name plus a directory. `accepts(_:)` then admits either `.jsonl`
  logs or, for `.opencode`, one database file.

Consequences for D2, which the ledger does not say but the code forces:

1. `AgentLiveSession` has **no state field**. It means "a turn the agent is working on right now".
   herdr/HC state includes `idle`, `done`, `blocked`, which are not turns. Mapping pane state onto
   `AgentLiveSession` loses `idle`/`done`, and inventing turns for idle panes would fabricate usage.
2. `AgentLiveSession` demands `tokens` and `cost`. herdr and HC report neither. A herdr source must
   publish zeroed usage, which is honest but will show a zero-cost row beside priced providers.
3. A socket/pipe/whole-file source does **not** fit `AgentLogRoot` (directory + append-only log +
   byte cursor). It needs a poller or a subscriber that emits `AgentLogEntry`-shaped transitions, or a
   second snapshot field beside `live`.
4. `HERDR_ENV=1` is not a usable liveness test. It was `1` in this process while the server it names
   had been dead for 16 hours. Any reader must probe the transport, not the environment.

---

## 2. Verified contract surface on this host

All statements below come from executing the installed binaries and reading their state files on
2026-11-21. Commands that mutate (starting a server, creating panes, killing terminals) were **not**
run.

### 2.1 Installed and running

| Thing | Path | Version | State |
| --- | --- | --- | --- |
| `herdr` (0.9.x) | `%USERPROFILE%\.herdr\packages\standalone\releases\0.9.3-x86_64-pc-windows-msvc\herdr.exe` | 0.9.3 | client only; no server |
| `herdr` (0.9.x) | `%LOCALAPPDATA%\Programs\Herdr\bin\herdr.exe` (junction → releases\0.9.5) | 0.9.5 | client only; no server |
| `hc` / `herdr-core` | `%LOCALAPPDATA%\Programs\herdr-core\hc.exe`, `herdr-core.exe` | 0.1.21 | **live core, pid 18920, `hc serve`** |
| `herdr-app` | `%LOCALAPPDATA%\Programs\herdr-app\herdr-app.exe` | window open, pid 37404 | live |

`where herdr` resolves to **0.9.3**, because herdr prepends its own pinned release directory to the
child's `PATH`: this process's `PATH` contains
`C:\Users\koosh\.herdr\packages\standalone\releases\0.9.3-…` and does **not** contain the
`…\standalone\current` entry that the user registry holds (that junction points at 0.9.5). So "which
herdr is on PATH" is a property of the pane, not of the machine.

`herdr status` (identical in both builds):

```
client:  version 0.9.3 / 0.9.5, channel stable, protocol 22, endpoint_protocol_generation 1
server:  status not running
         socket C:\Users\koosh\AppData\Roaming\herdr\herdr.sock
update:  restart_needed no, server_binary_stale no
```

There is no `herdr.sock` file in `%APPDATA%\herdr`, and no herdr named pipe. The last server event in
`herdr-server.log` is `2026-11-21T07:27:44Z … event="app.shutdown" subsystem="server" outcome="completed"`;
the client log's last line is `2026-11-21T07:27:42Z … endpoint transport failed endpoint=local error=server is shutting down`.

One orphan remains from that generation: pid 39764,
`herdr.exe pane release-agent wJ:p5G --source jcode --agent jcode --seq 1795244534567742`, started
2026-11-20 23:02:14 local, `KernelModeTime=0`, `UserModeTime=0`, parent PID 15608 gone. It has held a
failed reporter open for ~16 hours without burning CPU. It is also where this process's `HERDR_*`
values come from.

### 2.2 The 0.9.x documented contract (verified from the shipped binaries)

Environment injected into a managed pane (from `herdr --skill` and observed live):

| Variable | Observed value | Meaning |
| --- | --- | --- |
| `HERDR_ENV` | `1` | "you are inside Herdr"; the skill's only liveness gate |
| `HERDR_WORKSPACE_ID` | `wJ` | workspace handle (`w1`-style) |
| `HERDR_TAB_ID` | `wJ:t4` | tab handle (`w1:t1`-style) |
| `HERDR_PANE_ID` | `wJ:p5G` | pane handle (`w1:p1`-style), the caller's own pane |
| `HERDR_BIN_PATH` | `…\releases\0.9.3-…\herdr.exe` | the pinned binary for this pane |
| `HERDR_SOCKET_PATH` | `C:\Users\koosh\AppData\Roaming\herdr\herdr.sock` | the socket path (a filesystem path, even on Windows) |
| `HERDR_CONFIG_PATH` | not set | optional config override |

Writer surface (`herdr pane --help`), verified present in 0.9.3 **and** 0.9.5:

```
report-agent           Report pane agent lifecycle state
report-agent-session   Report pane agent session identity
release-agent          Release pane agent lifecycle authority
report-metadata        Report display-only pane metadata
```

`pane report-agent-session` CLI shape (verified):

```
Usage: herdr pane report-agent-session [OPTIONS] --source <ID> --agent <LABEL> <PANE_ID> [-- [RESUME_ARG]...]
  --source <ID>                       e.g. jcode
  --agent <LABEL>                     e.g. jcode
  --seq <N>                           monotonic ordering
  --agent-session-id <ID>
  --agent-session-path <PATH>
  --session-start-source <SOURCE>
```

Socket-layer params (`/schemas/request/$defs/PaneReportAgentSessionParams`), required
`pane_id`, `source`, `agent`; optional `agent_session_id`, `agent_session_path`, `resume_argv`,
`seq` (uint64), `session_start_source`.

`pane report-agent` carries `--state` with `[idle, working, blocked, unknown]`, plus `--message`.
Socket `PaneAgentState` is `{idle, working, blocked, unknown}`. `PaneReleaseAgentParams` is
`{pane_id, source, agent, seq}`.

Reader surface:

- `herdr api schema --json` → 272,578 bytes in 0.9.5, 566,672 in 0.9.3, **both** `"protocol": 22`,
  `"schema_version": 1`, 102 distinct method `const` values, identical method sets.
- `herdr api snapshot` → `SessionSnapshot`:
  `{version, protocol, workspaces[], tabs[], panes[], layouts[], agents[], focused_workspace_id,
  focused_tab_id, focused_pane_id}`.
  - `AgentInfo`: `pane_id`, `terminal_id`, `workspace_id`, `tab_id`, `focused`, `agent`,
    `display_agent`, `agent_status` (`idle|working|blocked|done|unknown`), `agent_session`
    (`{source, agent, kind: "id"|"path", value}`), `cwd`, `foreground_cwd`, `title`,
    `terminal_title`, `terminal_title_stripped`, `tokens` (≤32 string kv), `state_labels`,
    `completion_seq`, `state_change_seq`, `revision`, `interactive_ready`, `launch_pending`,
    `screen_detection_skipped`, `name`.
  - `PaneInfo`: adds `label`, `scroll`, `restore_error`, drops `agent_status`? No — it is required
    there too (`pane_id`, `terminal_id`, `workspace_id`, `tab_id`, `focused`, `agent_status`,
    `revision`).
- `herdr agent list|get|read|wait|explain`, `herdr pane list|get|current|layout|process-info`.
- Events: 26 variants — `agent_*`? No: `pane_agent_detected`, `pane_agent_status_changed`,
  `pane_created`, `pane_closed`, `pane_exited`, `pane_focused`, `pane_moved`, `pane_output_changed`,
  `pane_updated`, `tab_created|closed|focused|moved|renamed`, `workspace_created|updated|closed|
  focused|metadata_updated|moved|renamed|reordered`, `worktree_created|opened|removed`,
  `layout_updated`.

#### 2.2.1 The 0.9.x at-rest session document (verified, and more than it appeared)

`%APPDATA%\herdr\session.json` is version 3 and is a full resume snapshot, last written
2026-11-20T23:27:42 local — the moment the server shut down. Verified structure:

```
top:            version, workspaces[], active, selected, sidebar_width,
                sidebar_section_split, collapsed_space_keys
workspace:      id (wJ), custom_name ("Project"), identity_cwd,
                public_pane_numbers{public→internal}, next_public_pane_number,
                public_tab_numbers, next_public_tab_number, tabs[], active_tab
tab:            custom_name, layout, panes{internalId: pane}, zoomed, focused, root_pane
pane:           cwd, label, agent_resume?{source, agent, argv[]}
layout:         recursive {"Split":{direction:"Vertical"|"Horizontal", ratio, first, second}}
                or {"Pane": internalId}
```

Contents at inspection: 3 workspaces (`wJ` "Project" 2 tabs / 12 panes, `wM` "Infra\Device\Setupa"
1 tab, `wN` "Mini Tasks" 1 tab), pane labels (`hare`, `kcode trex`, `reochef tigress`, `VorSSait`,
`nix`, …), per-pane `cwd`, and — critically — `agent_resume` on 4 panes:

```json
"3": {"cwd":"C:\\Windows\\","label":"hare",
      "agent_resume":{"source":"jcode","agent":"jcode",
                      "argv":["jcode","--resume","session_hare_1795158094389_2c93ac24f4dcd405"]}}
```

So the at-rest 0.9.x document **retains reported agent session identity** (`source`, `agent`,
resume `argv` with a session token), in the same vocabulary as `pane.report_agent_session`. It does
**not** retain lifecycle state: there is no `idle|working|blocked|done` anywhere in the file.

Other persisted state: `%APPDATA%\herdr\sessions\` (8 named sessions),
`%APPDATA%\herdr\session-snapshots\` (49 rolling snapshots, newest
`session-…-58844-0.json` written 2026-11-20T22:26:30 local).

Doctrine note from `herdr --skill`, verbatim: *"If the check fails, say that you are not running
inside Herdr and stop. Do not inspect or control the focused Herdr session from outside Herdr."*
A desktop reader is "outside Herdr". This is guidance to agents, not an enforced restriction, but it
means the integration is not a use the vendor blesses.

### 2.3 The HC rewrite (herdr-core 0.1.21), what actually runs

Transport: Windows named pipe. `\\.\pipe\herdr-core-koosh-default.sock` connected with a 300 ms
client connect; `\\.\pipe\herdr-core-koosh-default.holder.e3480698.sock` also connected.
`herdr-core.exe … connect` (pid 9024, parent `herdr-app`) is the app's stdio bridge to the core.
`hc server status`:

```json
{"core":{"id":"e053d16013d3693604448a7e483c9dc6","name":"kooshapari-desk"},
 "finished":28,"live":29,
 "holder":{"current":true,"instance":"bb1ca7010c712eb7fedb304f3037e760","pid":36436,"terminals":29},
 "pid":18920,"uptime_ms":60327155,"version":"0.1.21"}
```

Process-side identity injected by HC (`HC_*`, observed live):

| Variable | Observed value |
| --- | --- |
| `HC_TERMINAL_ID` | `t1y` |
| `HC_TERMINAL_SOCKET` | `\\.\pipe\herdr-core-koosh-default.sock` |
| `HC_SCOPE` | `0-2dd3bebe089b13e211d1451600067c19` |

CLI/API surface: `hc schema` prints an **OpenRPC** document (69,152 bytes,
`{openrpc, info, methods, components}`) with these methods:

```
doc.get doc.set events.subscribe file.edit file.read file.write hello
machine.add machine.connect machine.exec machine.list machine.rename machine.rm rpc.discover
server.restart server.status server.stop templates.list
terminal.attach terminal.get terminal.interrupt terminal.keep terminal.keys terminal.kill
terminal.label terminal.list terminal.put terminal.read terminal.rm terminal.run terminal.send
terminal.wait
```

There is no agent-session method. `terminal.label` (CLI: `hc label <t> k=v…`) is the only write-side
extension point for extra state.

`hc get <terminal>` record (verified on `t1y` and `t7`):

```json
{"address":"t7","argv":["…\\pwsh.exe","-NoExit","-Command","…"],
 "cols":79,"cwd":"C:\\Windows","created_ms":1795243648780,"die_with_parent":false,
 "exit_code":null,"finished_ms":null,
 "foreground":{"argv":["…\\kcode.exe","--resume","session_mushroom_1794920948045_3fbbcf9af714a534"],
               "cwd":"C:\\Windows","name":"kcode.exe","pid":4060},
 "identity":"ghostty","keep":true,
 "labels":{"herdr.seen":"0","herdr.space":"sp6e2367d6a1e2645b8d4c4b7f4fc2c0e7",
           "herdr.tab":"tb46b41048eba637a3e52f01561fca9599","where":"Projects / Projs"},
 "name":null,"notify":true,"parent":null,"pid":39644,"reason":null,"reported":false,
 "rows":32,"screen":"exact","state":"live","status":null,"status_ms":null,
 "template":null,"title":"🌐 delivery · last ~2m07s","turn":0}
```

`hc ls` is the same data flattened with `where` already resolved (`"Projects / Sloppa"`,
`"Projects / Herdr"`, `"Windows / herdrpluginfindre"`) plus `machines:[{name,state}]`. Remote
terminals appear as `machine/tN` (`mac/t1` was live).

Event stream: `hc events --json` (options `--terminal`, `--children-of`, `--label K=V`). Each line is
a full-state delta envelope, not a per-field event:

```json
{"channel":null,"seq":183081,"terminals":[ …62 records… ]}
```

Event terminal keys: `address, argv, cols, created_ms, cwd, die_with_parent, exit_code, finished_ms,
identity, keep, labels, name, notify, parent, pid, reason, reported, rm, rows, screen, signal, state,
status, status_ms, template, title, turn`.

Note the divergence: `hc events` omits `foreground`, `last_cwd` and `restart_env`, which `hc get`
has. A reader that only subscribes to events cannot see the foreground process.

Persisted state (read-only fallback), `%LOCALAPPDATA%\herdr-core\default\`:

| File | Size | Content |
| --- | --- | --- |
| `core.json` | 131 B | `{id, name, machine_id}` |
| `terminals.json` | 76,229 B | `{next_id, holder, terminals{<n>: record}}`, 57 entries |
| `machines.json` | 569 B | `mac` (macbookpro), `nixos`, both 0.1.21 |
| `peers.json` | 88 B | `macbookpro` calls this core `desk` |
| `docs.json` | 5,821 B | self-description, top key `herdr-app` |
| `screens/*.snap` | 1.4–58 KB each | **full terminal screens; must not be read** |

`terminals.json` record keys: `address, name, labels, argv, cwd, keep, last_cwd, restart_env,
restart_after_ms, restart_delay_ms, program_started_ms, state, pid, exit_code, signal, reason,
created_ms, finished_ms, screen, cols, rows, identity, status, status_ms, turn, reported, title,
parent, notify, die_with_parent, rm, news, seen, noted, printed, full_screen, scope, seen_ms,
template, holder`. Live 29 / finished 28, `status` currently `null` on all 57 (no OSC 7501 reports in
flight). File creation 15:18:51, write 15:25:04 local, no `.tmp` residue — consistent with
write-temp-then-rename, so readers see a consistent snapshot but may see `FILE_NOT_FOUND` for an
instant.

Status semantics, from `hc --skill`: *"State is `live` or `finished`. Status comes from the program's
OSC 7501 reports: `idle`, `working`, `done`, `blocked`, `error`; plain programs report none. Do not
guess status from screen text."*

### 2.4 The HC app layer

`herdr-app` exposes its own read surface (`herdr-app --help`): `ls`, `status`, `do`, `commands`,
`shot`, `check`, `feedback`, `--skill`.

`herdr-app status` (verified): `{zoom, font_size, ui_font_size, space, tab, focused_pane, layout,
agent, floats, overlays, errors}`.

`herdr-app ls` (verified) returns the topology the notch strip would want:

```json
{"spaces":[{"id":"sp6e…","name":"Projects","folder":"","machine":null,"active":true,
  "tabs":[{"id":"tb93…","name":"Sloppa","active":false,"settled":false,
    "terminals":[{"terminal":"t11","pane":"pd6e…","status":null,"app":null,"name":null,
                  "sub_agents":[]}]}]}],
 "recent":[…]}
```

Live shape: 3 spaces (`Projects`, `Windows`, `mac: kooshapari`), 8 tabs, 29 terminals, one remote
terminal (`mac/t1`). Every `status`, `app` and `name` is currently `null`.

`herdr-app ls` and `status` "talk to the running window" — they require the GUI to be open, so they
are not a headless source.

---

## 3. Gaps between the ledger expectation and host reality

| # | Ledger expectation | Host reality | Consequence |
| --- | --- | --- | --- |
| G1 | `pane.report_agent_session` is the channel for session state | The method **exists** in both 0.9.3 and 0.9.5 CLI and schema, but there is no 0.9.x server, so every call returns `server_not_running` and no pane can report through it | The writer contract is real but inert. Nothing on this host is populating it |
| G2 | `HERDR_*` identifies the live session | All of `HERDR_ENV/WORKSPACE_ID/TAB_ID/PANE_ID/BIN_PATH/SOCKET_PATH` are set and point at a server that died at 07:27:44Z | Presence of `HERDR_*` is not liveness. A reader that trusts `HERDR_ENV=1` will report a session that does not exist |
| G3 | herdr is the state authority | The state authority is HC 0.1.21 (`herdr-app` + `herdr-core`); herdr 0.9.x has been shut down and its release is superseded by a `current` junction to 0.9.5 | A 0.9.x-only reader shows nothing on the operator's desk |
| G4 | One transport to code against | Two: a filesystem socket path (`herdr.sock`, AF_UNIX-style, currently absent) and a Windows named pipe (`herdr-core-koosh-default.sock`, live) | Transport detection must be capability-probed per generation, not assumed |
| G5 | Session identity is reportable | HC has no session-identity channel at all; identity is only `foreground.argv` (e.g. `kcode.exe --resume session_…`) and `title` | On HC, "session" can be approximated but not verified; no stable session id |
| G6 | Pane state is available | Yes on both, with different vocabularies: 0.9.x `idle|working|blocked|done|unknown`, HC `state live|finished` × `status idle|working|done|blocked|error|null` | Model needs a normalising enum, and must not conflate `live` with `idle` |
| G6b | Identity and lifecycle arrive together | 0.9.x splits them: at rest it keeps `agent_resume` identity but no lifecycle; live it has both. HC has lifecycle but no identity at all | A reader that wants both must either use the 0.9.x socket or combine two sources |
| G7 | Contract is stable | 0.9.3 and 0.9.5 agree exactly (102 methods, protocol 22, schema_version 1) but their schema documents differ in size by 2.1× | Safe to code against methods; not safe to hash or size-match the schema |
| G8 | One binary, one version | Three `herdr` entry points (0.9.3 release dir, 0.9.5 junction, PATH-injected copy) plus `hc` and `herdr-app` | Version pinning must come from `HERDR_BIN_PATH` / `hc --version`, never from `where` |
| G9 | The reporter is well-behaved | An orphaned `pane release-agent` has been wedged for ~16 h with 0 CPU, its parent dead | Any write path needs a timeout and a self-kill; a hung reporter is not visible to the user |
| G10 | Platform coverage is a detail | The installed `capt-marbles.jcode-integration` plugin declares `platforms = ["linux","macos"]` and drives `jcode integration install herdr`; the local jcode build has no `integration` subcommand | The documented jcode→herdr reporter is unavailable on this host and unproven on the Mac |
| G11 | State is cheap to read | `hc events --json` emits full 62-terminal snapshots per change; `terminals.json` is 76 KB and rewritten on every change | Naive per-event full reparse at 1 Hz is wasteful; needs diffing by `seq` and by terminal |
| G12 | Nothing else is at stake | `screens/*.snap`, `pane.read`, `pane read`, `terminal.read` expose full terminal contents (possible secrets, tokens, private paths) | The reader must be architected so it is *incapable* of reading screen content |

---

## 4. Two candidate integration paths

Both paths land in the same place: a `HerdrPaneSource`-style type beside
`Sources/Vorssaint/Services/AgentUsage/Harness/`, polled by `AgentUsageService`, publishing either
(a) `AgentLiveSession` rows with zeroed usage, or (b) a new `AgentPaneState` field on
`AgentUsageSnapshot`. Path choice changes only the backend behind that seam.

### Path A — the documented contract (0.9.x socket API)

**Shape.** Probe for a live 0.9.x server, then speak protocol 22 over the socket.

- Liveness: run `HERDR_BIN_PATH` (or a pinned binary) `status` and require
  `server.status == running`. Fall back to `herdr api snapshot` exiting 0 with a JSON body.
- Snapshot: `session.snapshot` → `agents[]` gives everything D2 names —
  `pane_id`, `workspace_id`, `tab_id`, `agent`, `display_agent`, `agent_status`,
  `agent_session{source, agent, kind, value}`, `cwd`, `foreground_cwd`, `title`, `tokens`.
- Deltas: `events.subscribe` filtered to `pane_agent_detected`, `pane_agent_status_changed`,
  `pane_created`, `pane_closed`, `pane_exited`, `tab_*`, `workspace_*`.
- Mapping: `working` → `turnBegan`/`turnActive`; `idle`/`done` → `turnSettled`; `blocked` →
  `turnSettled` plus a blocked flag; `pane_exited`/`pane_closed` → `turnEnded`. Key on `pane_id`
  (`w1:p1`), which is stable and never reused.
- Write side (for D1's jcode reporter, not D2): `pane.report_agent_session`,
  `pane.report_agent`, `pane.release_agent`.

**Cost.** One transport abstraction (AF_UNIX path on macOS, path-on-Windows if it ever runs there),
schema-version negotiation on `protocol` + `schema_version`, a subscriber with reconnect, and
version pinning because two builds exist.

**Fidelity.** Highest when live. The only surface that carries a real agent session identity, a
distinction between `done` and `idle`, and a `focused` bit.

**Degraded mode (verified available).** When no server answers, the same generation still leaves
`%APPDATA%\herdr\session.json` behind, and that document carries workspace/tab/pane topology, pane
labels, per-pane `cwd` and `agent_resume{source, agent, argv}` — i.e. **identity without lifecycle**
(§2.2.1). That makes Path A's at-rest half testable on this host even though its socket half is not.

**Blocking unknown.** Whether a 0.9.x server runs on the Mac at all. Here it does not, and the 0.9.x
generation has been superseded on this host by HC.

### Path B — adapter to the HC build

**Shape.** Probe for a live core, then read HC state.

- Liveness, in order of preference:
  1. `HC_TERMINAL_SOCKET` or `\\.\pipe\herdr-core-<user>-default.sock` connectable;
  2. `hc server status` returning JSON without `server_not_running`;
  3. `%LOCALAPPDATA%\herdr-core\default\terminals.json` mtime fresh within a chosen window
     (last-resort, read-only, no IPC).
- Topology: `herdr-app ls` for spaces/tabs/terminals/pane ids and `sub_agents`, or from
  `terminals.json` + `labels["herdr.space"]`/`["herdr.tab"]` when the window is closed. The app's
  `ls` requires the GUI; `terminals.json` does not.
- Pane state: `terminals.json[*].state` (`live`/`finished`) and `.status`
  (`idle|working|done|blocked|error|null`); enrich with `hc get <t>.foreground` when the pipe is
  reachable, because the event stream omits `foreground`.
- Identity: `foreground.name` / `foreground.argv[0]` mapped to a provider (kcode/jcode, claude,
  codex, opencode, copilot); `foreground.argv` scanned for `--resume <session>` to show a session
  token; `labels.where` for the project; `title` for the task line. Never read `screens/*.snap`.
- Deltas: `hc events --json` with `--label` filters, diffed by `seq` and per-`address`.
- Write side, if ever needed: `hc label <t> agent.session=<id>`.

**Cost.** Argv/label heuristics (they will be wrong for wrappers and shells), two read modes (pipe vs
file), and no session identity.

**Fidelity.** Good for pane/terminal/agent-kind and lifecycle; no session id/path, no `focused`
flag (use `herdr-app status.focused_pane`), no ordering or authority semantics.

**Advantage.** It is the thing actually running: 29 live terminals, 8 tabs, 3 spaces, one remote
machine, all readable today without starting anything.

---

## 5. Self-test plan

The tests are ordered so each one can fail independently and says which path is alive.

### 5.1 Contract tests (no live server required, run on any machine)

| ID | Test | Pass condition |
| --- | --- | --- |
| A1 | `<herdr> --version` and `<herdr> status` parse | version string and a `server.status` field are extracted; `running` and `not running` both handled |
| A2 | `<herdr> api schema --json` parses and yields ≥100 method consts | `protocol == 22` and `schema_version == 1` recorded; unknown protocol → refuse, do not guess |
| A3 | Schema contains `pane.report_agent_session` and `PaneReportAgentSessionParams` requiring `pane_id/source/agent` | Reader exposes a `supportsAgentSession` capability flag |
| A4 | `HERDR_ENV=1` with `HERDR_SOCKET_PATH` pointing at a nonexistent path | Reader reports `unavailable`, not `idle` |
| A5 | Stale-env regression: unset every `HERDR_*` except `HERDR_ENV=1` | Reader still reports `unavailable` (proves env is not the gate) |
| A6 | Decode a recorded `SessionSnapshot` fixture with `agents[]` containing `agent_status=blocked`, `agent_session{kind:"path"}`, `tokens` | All required `AgentInfo` fields survive; unknown extra fields ignored |
| A7 | Decode a recorded 26-variant `EventData` fixture set | `pane_agent_status_changed` and `pane_exited` produce the intended transitions; unknown `type` ignored |
| A8 | Decode a recorded `session.json` v3 fixture (3 workspaces, nested `Split`/`Pane` layout, `agent_resume` on some panes) | Topology and `agent_resume{source,agent,argv}` survive; layout ratios in `[0,1]`; the document yields **no** lifecycle state, and the reader does not invent any |

### 5.2 HC tests

| ID | Test | Pass condition |
| --- | --- | --- |
| B1 | `hc --version` parses; `hc schema` parses as OpenRPC | method list captured; absence of an agent-session method recorded as a capability, not an error |
| B2 | `hc server status` on a machine with a core | JSON parses; `server_not_running` handled without retry storm |
| B3 | Named-pipe connect to `\\.\pipe\herdr-core-<user>-default.sock` with a short timeout | Connect succeeds in <1 s, or fails in bounded time; no hang |
| B4 | Decode `terminals.json` fixture with 57 mixed `live`/`finished` entries | Correct counts; `status: null` treated as "unknown", never as `idle` |
| B5 | Decode a 62-terminal `hc events` line | Per-`address` diff produces exactly the changed records; absent `foreground` is not treated as "no agent" |
| B6 | `foreground.argv` mapping table | `kcode.exe --resume session_x` → provider + session token; a bare `pwsh.exe` → none; a shell wrapper → none |
| B7 | File-race test: read while the writer replaces the file | `FILE_NOT_FOUND` → keep last good snapshot and retry; never publish an empty list |
| B8 | `terminals.json` older than the freshness window and no pipe | Reader reports `stale`, not a live fleet |

### 5.3 Live acceptance (the only tests that settle the recommendation)

| ID | Test | Pass condition |
| --- | --- | --- |
| L1 | On the **Mac**, `pgrep -fl 'herdr|hc'`, `herdr status`, `ls -l ~/Library/Application\ Support/herdr/` (or the Mac's config path) | Names which generation runs there, and whether `herdr.sock` exists |
| L2 | On the Mac, `herdr api snapshot` in a live pane | Exit 0 + `agents[]` populated ⇒ Path A is viable on the product host |
| L3 | On the Mac, `herdr pane report-agent-session <own pane> --source selftest --agent selftest --agent-session-id selftest` | Exit 0 ⇒ the writer contract works end to end; `server_not_running` ⇒ Path A is not available |
| L4 | On the Mac, `hc server status` and `herdr-app ls` | JSON with terminals ⇒ Path B is viable on the product host |
| L5 | Start Vorssaint (or the sliced self-test build) with only Path A enabled | The notch strip shows the live agent, or shows an explicit "unavailable" state; it must never show a phantom session |
| L6 | Same with only Path B enabled | Strip shows working/blocked/done per terminal with project and program |
| L7 | Kill the server/pipe under a running reader | Strip degrades to "unavailable" within one poll interval; no crash, no retention of stale agents |
| L8 | Grep the built binary for `screens`, `pane.read`, `terminal.read`, `read --lines` | No screen-content read path is reachable from the herdr source |

### 5.4 Regression guard for the existing suite

The Mac suite is reported at 123,642 checks with 77 agent-key checks inside it. New tests must not
require a live herdr; L1–L7 are manual/opt-in, everything in 5.1/5.2 is hermetic with fixtures.
This matches the ledger's existing self-test practice of slicing functions into
`build/generated-tests/*.swift`, which forbids instance state, so the decoder should be pure
`static`/value-typed over `Data`.

---

## 6. Risk list

| # | Risk | Impact | Mitigation |
| --- | --- | --- | --- |
| R1 | **Stale-env phantom session.** `HERDR_*` outlives its server (proven here, 16 h) | Strip shows an agent that is not running | Liveness = transport probe only; A4/A5 as permanent tests |
| R2 | **Generation ambiguity.** 0.9.x vs HC are different products with different vocabularies | Reader targets the wrong one and shows nothing | Explicit backend selection with a probe order and a named "unavailable" state |
| R3 | **Path pinning.** herdr rewrites the child `PATH`; 0.9.3 beat a `current`→0.9.5 junction | Wrong binary invoked, `server_binary_stale` confusion | Always honour `HERDR_BIN_PATH`, else an explicit configured path, else `hc`; never `where` |
| R4 | **Two-build schema drift.** 0.9.3 schema is 2.1× the size of 0.9.5's, same 102 methods | Blind field assumptions break on one build | Gate on `protocol` + `schema_version`, treat unknown fields as optional |
| R5 | **Hung reporters.** The orphan `pane release-agent` ran 16 h at 0 CPU | A write path can leak a process forever | Bounded invocation (timeout + kill) on any herdr CLI call, including probes |
| R6 | **Doctrine conflict.** herdr's own skill says do not inspect from outside | Integration contradicts vendor guidance; future builds may restrict it | Read-only, no control commands, no writes; document the deviation; degrade gracefully if refused |
| R7 | **Screen-content leakage.** `screens/*.snap`, `pane read`, `terminal read` hold full scrollback | Secrets, tokens, private paths enter the app | Never call read commands; no `screens` path in the reader; L8 as a build-time guard |
| R8 | **Heuristic identity (Path B).** `foreground.argv`/`title` are free-form | Mis-attributed agents, wrong project | Whitelist known executables, treat unknown as "unattributed", never guess a session id |
| R9 | **`status: null` misread.** HC leaves `status` null for plain programs | Idle terminals shown as working or vice versa | Normalise `null` → `unknown`, and keep `state` separate from `status` |
| R10 | **Event volume.** Each `hc events` line carries all terminals | CPU/IO burn on a laptop | Diff by `seq` and `address`; subscribe with `--label`; cap parse rate |
| R11 | **File rewrite race.** `terminals.json` is replaced, not appended | Transient missing file or partial read | Retry-on-`FILE_NOT_FOUND`, last-good-snapshot policy, schema-validate before publish |
| R12 | **Zero-usage rows.** herdr/HC report no tokens or cost | A $0.00 entry distorts spend views and comparisons | Either omit herdr from spend/trend aggregation or render it only in `live`/state cards, explicitly not priced |
| R13 | **Model mismatch.** `AgentLiveSession` has no state field and means "active turn" | Forcing pane state into it corrupts "working" semantics | Add a separate `AgentPaneState` (or a `state` field) rather than overloading `live` |
| R14 | **Remote/multi-machine.** HC has `mac` and `nixos` peers; ids are `machine/tN` | Duplicate or missing rows, id collisions | Key on the full address (`machine/t7`), never the bare `t7` |
| R15 | **Platform gap.** The jcode→herdr plugin declares linux/macos only; this jcode has no `integration` command | D1's reporter cannot be exercised here | Treat D1 and D2 as independently deployable; do not block D2 on the plugin |
| R16 | **Privacy framing.** Reading another app's pane/agent inventory is cross-application observation | A privacy-policy claim in `docs/PRIVACY.md` would need updating | Document exactly which fields are read (ids, cwd, argv name, status) and that content is never read |

---

## 7. Recommendation and deciding evidence

**Recommend Path B (HC adapter) for the next increment, behind a transport-agnostic
`HerdrPaneSource` seam that Path A can occupy later without rework.**

Reasons, in order of weight:

1. **Verifiability.** Path B is fully testable end to end on this host today: 29 live terminals, 8
   tabs, 3 spaces, one remote machine, a live named pipe, and a 76 KB snapshot file. Path A's
   *socket* half cannot be exercised at all here — every call returns `server_not_running` — so a
   live Path A would ship unverified. Only its at-rest half (identity without lifecycle) is
   testable, and that is not enough to drive a working/blocked strip.
2. **It is the product that is running.** The operator's desk is HC (`herdr-core` 0.1.21 with
   `herdr-app`), and herdr's own `current` junction already points at 0.9.5 while panes still pin
   0.9.3. Building against the superseded generation first is the larger bet.
3. **Path B covers the state D2 actually needs.** `state`/`status` (`live|finished` ×
   `idle|working|done|blocked|error`), `labels.where` (project), `labels["herdr.space"]`/`["herdr.tab"]`
   (session grouping), `foreground` (program), `title` (task) is a complete notch strip.
4. **The one thing Path B lacks is the one thing the ledger names.** Path B has no agent session
   identity. That is a real requirement, and it is the reason not to *discard* Path A.

**Deciding evidence** (one experiment settles it):

Run on the Mac, inside a herdr pane, three commands:

```
herdr status
herdr api snapshot
herdr pane report-agent-session "$HERDR_PANE_ID" --source selftest --agent selftest --agent-session-id selftest
```

- If `status` shows `server: running` and the snapshot and report both exit 0, **Path A is live on
  the product host** and should be promoted to the primary backend, because it is the only source
  with session identity.
- If any of them returns `server_not_running`, **Path B is the only viable path on the Mac**, and
  "session" must be documented as program + cwd + resumed-session token from `foreground.argv`,
  which is an approximation, not an identity.

Secondary deciding evidence, whichever way that goes: whether HC's core is running on the Mac at
all (`hc server status`), because a Path B backend on a machine without `herdr-core` is also
dead. Both probes are read-only and safe to run; neither starts a server or creates a pane.

---

## Appendix A — evidence ledger

Every claim above traces to one of these observations, made 2026-11-21 15:19–15:28 local.

| Observation | Command or file |
| --- | --- |
| Versions | `herdr.exe --version` → `herdr 0.9.3`, `herdr 0.9.5`; `hc --version` → `hc 0.1.21` |
| Server down | `herdr status` (both builds) → `server: not running`; `herdr api snapshot` → `server_not_running` |
| Writer exists | `herdr pane --help` lists `report-agent-session`; `herdr pane report-agent-session --help`; schema `PaneReportAgentSessionParams` |
| Writer inert | `herdr pane report-agent-session NOTESESS --source jcode --agent jcode --agent-session-id selfcheck` → `{"error":{"code":"server_not_running"}}`, exit 1 |
| Schema | `herdr api schema --json` → 272,578 B (0.9.5) / 566,672 B (0.9.3), protocol 22, schema_version 1, 102 methods each |
| Env | process environment: `HERDR_ENV`, `HERDR_WORKSPACE_ID`, `HERDR_TAB_ID`, `HERDR_PANE_ID`, `HERDR_BIN_PATH`, `HERDR_SOCKET_PATH`, `HC_TERMINAL_ID`, `HC_TERMINAL_SOCKET`, `HC_SCOPE` |
| No socket file | `dir %APPDATA%\herdr\*.sock` → none |
| 0.9.x at-rest state | `%APPDATA%\herdr\session.json` (v3, write 2026-11-20T23:27:42 local): 3 workspaces, `wJ` 2 tabs / 12 panes, pane `label`/`cwd`/`agent_resume`; newest `session-snapshots` 2026-11-20T22:26:30 |
| HC live | `hc server status`, `hc ls`, `hc get t1y`, `hc get t7`, `hc events --json` (one 62-terminal line in 4 s) |
| HC pipe | `NamedPipeClientStream.Connect(300)` → `herdr-core-koosh-default.sock` CONNECTED, `…holder.e3480698.sock` CONNECTED |
| HC files | `%LOCALAPPDATA%\herdr-core\default\` listing + `terminals.json`, `core.json`, `machines.json`, `peers.json` shapes |
| App layer | `herdr-app status`, `herdr-app ls`, `herdr-app commands` |
| Stale env provenance | `Win32_Process` for pid 39764: started 11/20 23:02:14, 0 CPU, parent 15608 gone |
| Server death | `herdr-server.log` last line `2026-11-21T07:27:44Z … app.shutdown`; `herdr-client.log` last line `07:27:42Z … server is shutting down` |
| PATH pinning | process `PATH` contains `…\releases\0.9.3-…`, not `…\standalone\current`; `Get-Item …\current\` → `…\releases\0.9.5-…` |
| Repo seam | `Sources/Vorssaint/Services/AgentUsage/Harness/AgentHarnessReader.swift`, `AgentLogParser.swift`, `AgentUsageStore.swift:475`, `AgentUsageModels.swift:8,144`, `AgentUsageSummary.swift:84`, `NotchAgentSupport.swift:86`, `Defaults.swift:1546` |
| No prior herdr work | `grep -ri herdr docs README.md CHANGELOG.md` → no source hits |

## Appendix B — deliberately not done

- Did not start a herdr 0.9.x server (`herdr server` / bare `herdr`). It would create panes, attach a
  TUI, and change state the operator did not ask to change. This is the one action that would let
  Path A be tested here, and it needs operator consent.
- Did not restart `herdr-app` or the HC core, did not kill the orphaned reporter (pid 39764), and did
  not create, mutate or remove any HC terminal.
- Did not read any `screens/*.snap`, and did not call `pane read`, `terminal.read`, `herdr-app shot`,
  or `hc read`.
- Made no repository change and no commit. Only this file was written, on E:.

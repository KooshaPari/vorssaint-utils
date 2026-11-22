# Roadmap ledger

Every idea the operator drops goes here, with status, so nothing is lost between
sessions. Newest intents join the list; nothing is deleted, only marked.

Status: `shipped` (committed and verified on the Mac), `wip`, `queued`,
`needs info`, `parked`.

Build under test: `/Applications/Vorssaint (Developer).app`, branch
`dev/maccy-clipboard-parity`, PR #1 on `KooshaPari/vorssaint-utils`.
UI marks anything changed in the current build with a green `KNU` tag.

## A. Clipboard, superseding Maccy

| # | Item | Status |
| --- | --- | --- |
| A1 | Paste a history entry without formatting (⌥-click, ⌥⇧↩, context menu, previous clipboard restored) | shipped |
| A2 | Pause capture from the panel, persisted, re-baselines on resume | shipped |
| A3 | Per-item shortcuts for pinned entries | shipped already (⌘1..⌘9 over pinned-first order) |
| A4 | User-editable pasteboard-type ignore list (1Password, KeeWeb, InDesign, remote clipboard) | shipped |
| A5 | Ignore only the next copy (one-shot skip) | shipped |
| A6 | Clear all including pinned, with its own confirmation | shipped |
| A7 | Clipboard check interval preference | shipped |
| A8 | Universal Clipboard skip as a first-class switch | shipped |

Reference: `docs/CLIPBOARD_MACCY_PARITY.md`.

## B. Window policy engine (operator intent, 2026-11-20)

| # | Item | Status |
| --- | --- | --- |
| B1 | Smart auto tiling of floating windows, definable layouts | shipped: pure policy, eligibility filter, Accessibility layer, opt-in setting, and Tile now in the command bar |
| B2 | Per-desktop window cap; overflow logic: new desktop, minimize, or other policy | shipped for limit plus leave/minimize; new desktop is not offered because Accessibility has no supported call for it |
| B3 | Smart grouping of windows minimized but not pinned | shipped: grouping model, cross-app reader, and a count in the window policy section |
| B4 | Same grouping for dock items where Vorssaint does not already provide it | shipped read-only: pinned Dock apps are read from the Dock domain, unpinned apps with minimized windows are counted. No Dock icon is changed |

Before this work the only tiling was edge snapping inside `windowLayout`. The
policy engine, the opt-in action, the cap with its overflow rule, and read-only
grouping for minimized windows and dock items are now in place and tested.

## C. Superset targets for other tools

| App | What Vorssaint already has | Gap |
| --- | --- | --- |
| All | Full comparison, with evidence and absence checks, in `docs/PARITY_MATRIX.md` | |
| Maccy | see section A | A4 to A8 |
| Background Music | `mixer` per-app volume, `audioPriority`, `micMute`, `musicBlock` | virtual audio device for per-app output routing, if wanted |
| Rectangle | `windowLayout` already covers halves, thirds, quarters, sixths, corners, maximize, margin maximize, full screen, centre, next and previous display, restore | almost maximize and smaller/larger nudges, if wanted. B1 to B4 are shipped |
| TinkerTool | many live toggles | shipped for 14 Finder, Dock, screenshot and global keys: browser in Settings, Advanced, with typed editors, per-key reset and read-back after every write. The catalog is data, so it can grow |
| Mac Tweaks (`com.macmeup.Mac-Tweaks` 3.1.1) | overlaps TinkerTool | same surface as TinkerTool |
| OnyX | `cleaner`, `uninstaller`, `homebrew`, `killProcess`, `portManager` | maintenance suite: cache rebuild, LaunchServices rebuild, Spotlight reindex, verify |
| Deskflow | nothing | input sharing. Decision: optional bundled sidecar, driven by Vorssaint, not reimplemented |
| ProToys (protoys.app) | notch suite, colorPicker, screenOCR, shelf, mixer, portManager, monitor suite, keepAwake, notchTimer, mouse tools, mediaTools | screen ruler, ZoomIt-style zoom and annotate, Always On Top, Workspaces, Crop And Lock, bulk PowerRename with regex, theme switcher, file convert plus link sharing |
| Amphetamine | `keepAwake` | parity check only |
| DaisyDisk | `cleaner` | disk map visualisation |
| Parsec / UTM / OBS | none | not in scope unless the operator says so |

General rule from the operator: where a sidecar or bundle beats a hand-rolled
implementation, bundle it.

## D. AI agents section

| # | Item | Status |
| --- | --- | --- |
| D1 | jcode harness reader so jcode sessions and usage appear in the notch agents strip | shipped: journal read incrementally while a session runs, session record reduced in place to metadata plus per-message counters once the journal is gone, truncated, corrupt or oversized records skipped and retried only on change, message text, titles and environment snapshots never decoded, jcode card and switch in the agents page. 37 agent checks inside the 2,599-check agents suite and a 123,680-check full suite on its own branch; on the merged tree the agents suite still holds 2,599 checks and the full suite is 123,796, all passing, with the four `NotchLevelTrackingTests` click failures seen on base `545f69b2` not reproducing (`docs/VALIDATION_LOG.md`) |
| D2 | herdr session and pane state through the HC backend (the row previously named the 0.9.x contract, `HERDR_*` and `pane.report_agent_session`) | spec landed, implementation next. Operator decision 2026-11-22: the herdr 0.9.x TUI generation is **retired by the operator**. The HC build (`herdr-core` 0.1.21 plus `herdr-app`) is the only supported backend. The documented 0.9.x socket contract is retired from scope and kept in `docs/D2_HERDR_CONTRACT.md` only as history. Recommended shape is a transport-agnostic pane-source seam with an HC backend, agent identity supplied by the agents themselves rather than by the multiplexer, and liveness decided by a transport probe and never by `HERDR_*` presence. The verified contract research, gap list and risk list for both generations are preserved verbatim in that spec |
| D3 | Multiple OpenCode Go API keys, per-key usage, rotation, secret-safe provisioning | shipped: rotation model, keychain secret store, and a keychain-backed registry with add/remove ordering. The OpenCode Go key surface under the AI settings adds a key behind a secure field, removes it and allows a rejected one again over that registry; the AI page lists the masked per-key rows while the OpenCode toggle is on, and the registry file holds no secrets. Per-key usage counters and provider routes skip rate-limited, invalid or exhausted keys. The routing model (`nextRoute`, `record`, `reportFailure`) is implemented and covered but has no caller: the app only reads local agent logs and downloads prices, and sends no OpenCode Go request, so per-key tokens stay zero until such a request path exists. The D3 branch measured 100 agent-key checks inside the 123,733-check Mac suite, and the D3 review-fixes series measured 105 assertion sites, 95 of which execute on a passing run: the other 10 are failure-only guard branches that run only when an earlier setup check fails. On the merged tree the agent-key suite executes 125 checks inside the 123,796-check Mac suite, all passing. This row previously said 77 checks, which counted every assertion site as if it had run. The honest per-commit full-suite record is kept in the validation log added with the D3 review fixes. Known debt: each recorded request still rewrites the whole registry file once, now outside the state lock; coalescing writes is not done because the counters must be durable when the app quits and that needs a flush hook in the app lifecycle |
| D4 | Instinct and/or Hermes and other agent integrations for the companion | needs info |
| D5 | Subscription or API key for the companion to use | needs info |
| D6 | "Vorssaint dots" | needs info: exact meaning not yet known |

## E. Network

| # | Item | Status |
| --- | --- | --- |
| E1 | Tailscale integration: bind agent and harness services to the tailnet, verify peer identity | queued |
| E2 | Mullvad integration: per-provider egress policy through its SOCKS5 or CLI, refuse rather than fall back | queued |

## F. Packaging and security

| # | Item | Status |
| --- | --- | --- |
| F1 | Signed, notarized `.app` and `.dmg`, stapled | blocked on notary credentials (`NOTARY_API_KEY_P8`, `NOTARY_KEY_ID`, `NOTARY_ISSUER_ID`) or a run in the Mac's GUI session |
| F2 | Homebrew cask in the tap | queued, follows F1 |
| F3 | Apple findings P85-1..P85-5 from `pr-review-plan-20261120.md` | needs info: document not found on this host |

## Operator facts recorded

- Lane: **MacMgr** (operator, 2026-11-21). Owns Vorssaint on top of every other
  tool and piece of infrastructure maintained for the Mac and the general macOS
  setup, not just this repository.

- Apple Developer account is paid; Developer ID Application (GCT2BN8WLL) is
  installed on the Mac. Headless builds cannot use it because the login keychain
  is locked over SSH, so dev builds pass `VORSSAINT_SKIP_DEVELOPER_ID=1`.
- Mac: `kooshas-laptop`, 100.112.14.98, macOS 27.3, Xcode 26.0, Swift 6.2.
- The self-test build slices individual functions into
  `build/generated-tests/*.swift`; a sliced function cannot use instance
  properties declared elsewhere, so such paths read preferences directly.
- C: on the Windows host has **654,828,756,992 bytes free (609.86 GB)** of
  1,997,941,051,392 bytes, measured 2026-11-22 07:47 UTC with
  `Get-CimInstance Win32_LogicalDisk`. That is above the 500 GB threshold read
  as 500,000,000,000 bytes, so the earlier "C: is below the threshold" note is
  retired: it was wrong as recorded. E: (`Data`, 4,000,768,323,584 bytes,
  3,377,327,542,272 bytes free at the same moment) remains where bulky scratch
  and build output go, by preference for space headroom rather than because C:
  is short.

### Isolated agent browser (measured 2026-11-22)

- The recorded instruction that the agent browser is a dedicated Brave profile
  via `C:\Users\koosh\.jcode\browser\start-brave-agent.cmd` with
  `JCODE_BROWSER=brave` does not match this host. Brave is not installed: the
  launcher's target
  `C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe` is
  absent, only `AppData\Local\BraveSoftware` leftovers remain, and the script
  prints "Brave not found" and exits 1. `JCODE_BROWSER` reads as `edge` at user
  scope, and `jcode browser status` reports backend `firefox_agent_bridge`,
  browser `edge`, bridge `not responding`.
- The isolated option that actually exists is
  `C:\Users\koosh\.jcode\browser\start-edge-canary-agent.cmd`, which runs
  `start-edge-canary-agent.py`: Edge Canary (`msedge.exe` under
  `C:\Users\koosh\AppData\Local\Microsoft\Edge SxS\Application`) against the
  dedicated profile `C:\Users\koosh\.jcode\browser\edge-canary-agent-profile`,
  sync disabled, CDP on port 9337, and the Browser Agent Bridge unpacked
  extension installed over CDP at launch because Edge Canary 159 and later
  ignore `--load-extension`. Nothing was listening on 9337 when measured, so
  the bridge answers only after that launcher has run.
- The personal Edge profile must never be targeted. Automation goes only through
  the dedicated `edge-canary-agent-profile` on port 9337, never the user's
  default Edge profile, its windows, or its running session.

### OpenCode Go key lane (measured 2026-11-22)

- Keys for this lane live in `C:\Users\koosh\Ocgo.env`: eight entries, seven
  `OC_*_API_KEY` names plus `MINIMAX_API_KEY`. The seven are
  `OC_GMAILDEF_API_KEY`, `OC_GMAIL2_API_KEY`, `OC_ASU_API_KEY`,
  `OC_MIKE_API_KEY`, `OC_RAM_API_KEY`, `OC_KO_API_KEY` and
  `OC_ICLOUD_API_KEY`.
- The pool is `ocgo.exe serve --addr 127.0.0.1:8791 --luna` (observed pid
  14292, `/health` returns 200 with `{"families":{"minimax":1,"ocgo":7}}`).
- Weekly saturation, read with
  `ocgo.exe usage --env C:\Users\koosh\Ocgo.env --json`: six of the seven
  OpenCode Go keys report Weekly Used 100 and status `rate-limited`, resetting
  2026-11-23T00:00:00Z. Only `OC_ICLOUD_API_KEY` is healthy at Weekly 24, and it
  is the key the pool routes through. `OC_ASU_API_KEY` and `OC_MIKE_API_KEY` are
  also Monthly 100 `rate-limited`; the other four sit at Monthly 50. The MiniMax
  key is separately Weekly 100 `exhausted`, resetting 2026-11-25T07:08:49Z.
- `/pool` agrees with that shape: six `ocgo` entries in `cooling` with
  `lastStatus` 429 and roughly 58,400 s of cooldown left, and `OC_ICLOUD_API_KEY`
  `ready` with `lastStatus` 200.
- Operational consequence: the OpenCode Go fallback lane has one usable key
  until the weekly reset, so route as the free and low-cost paths intend and do
  not lean on this lane for volume.
- Names and counts only are recorded here. No key value, prefix or suffix is
  written into this repository.

## Workspace topology (corrected 2026-11-21)

- Git work happens on `C:\Users\koosh\CodeProjects\vorssaint-utils`, a fresh
  clone with `core.autocrlf=false`, `core.preloadIndex=true`,
  `feature.manyFiles=true`, `core.untrackedCache=true` and `gc.auto=0`.
  `git status` measures about 0.8 s there.
- The earlier `E:\koosh\CodeProjects\vorssaint-utils` clone is retired for git
  work: E: is under bad-block investigation and must be treated as read-mostly,
  and its CRLF worktree forced full-content conversion on every operation, which
  is what produced multi-minute operations and stale `index.lock` files.
- The Mac is used only for macOS builds and the suite. It is not a commit host.
- NixOS at 100.112.143.99 is online but SSH key auth is refused for `koosh` and
  `kooshapari` with the available keys, so offloading there is blocked until the
  operator provisions access.

## G. Later candidates from operator dumps (2026-11-21)

| Candidate | Note | Status |
| --- | --- | --- |
| Flux (f.lux) | display colour temperature with a schedule. Vorssaint has brightness and extra brightness only | queued |
| OpenRGB | RGB lighting control. macOS coverage is partial and hardware-specific, so treat as an optional sidecar rather than a native rewrite | needs info |
| SMB and compute-mesh management | mount and manage SMB shares, and a mesh view over Tailscale peers and SSH hosts, beside the existing `connectedDevices` and `portManager` | queued |
| Kcode Notifications (`~/Applications`) | the companion app named in D4 and D5; the natural surface for instinct and Hermes events | needs info |
| Parsec, UTM, OBS, balenaEtcher, qBittorrent, Steam, Blender, Xcode | installed but out of scope unless asked. OBS overlaps `screenRecorder` only | parked |
| RemoveMacAI, oMLX, Slipstream, rio, Ghostty | installed, purpose unverified | needs info |

Rule applied to every row: a bundle or sidecar wins wherever hand-rolling would be
inferior; native implementation only where the sidecar would be worse.

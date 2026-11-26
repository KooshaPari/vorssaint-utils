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
| A9 | Clipboard surface placement as a chosen option: near the cursor, remembered popup, bottom of the screen, top centre, or the Dynamic Island — instead of only drag-and-remember | shipped (124340 checks PASS at `0969068d`; two review follow-ups open: forced placement must not overwrite the remembered origin, and the cards layout must not offer an inert picker) |

Reference: `docs/CLIPBOARD_MACCY_PARITY.md`.

## A2. The `KNU` tag (operator intent, 2026-11-26)

The green `KNU` pill marks anything that changed in the current build. The
operator's requirement, verbatim: "KNU should be searcahble or have a dedicated
page + whats knu section in changelog i can clearly review to see wahts new for
a user as of xyz date/time", and earlier "shown under their parent item (e.g.
parent sidebar item)".

| # | Item | Status |
| --- | --- | --- |
| K1 | A KNU/new feature renders under its parent Settings sidebar row in the What's New window, not in its own top-level group | shipped (124368 checks PASS at `1163eaf5`) |
| K2 | KNU entries are reachable from Settings search, or from a dedicated page | shipped, with the gap the review found: Settings search matches KNU, but the What's New window itself has no search field |
| K3 | `CHANGELOG.md` carries a `### What's KNU` subsection with the date and time each item became new, so "what is new for a user as of <date/time>" is reviewable | shipped (the stamp lives in `CHANGELOG.md`; see the open follow-ups) |
| K4 | A test fails if the What's KNU section and `NewFeatureBadges.tagged` disagree | shipped (agreement is tested in both directions) |

Source of truth for "new in this build" is `Sources/Vorssaint/Core/NewFeatureBadges.swift`.

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
| D1 | jcode harness reader so jcode sessions and usage appear in the notch agents strip | shipped: journal read incrementally while a session runs, session record reduced in place to metadata plus per-message counters once the journal is gone, truncated, corrupt or oversized records skipped and retried only on change, message text, titles and environment snapshots never decoded, jcode card and switch in the agents page. 37 agent checks inside the 2,599-check agents suite and a 123,680-check full suite on its own branch; on the merged tree the agents suite still holds 2,599 checks and the full suite is 123,796, all passing, with the four `NotchLevelTrackingTests` click failures seen on base `545f69b2` not reproducing. Those two figures describe the tree before the D2 merge; on the current merged tree (`df491e0a`) the agents suite is 2,720 and the full suite 123,918 (`docs/VALIDATION_LOG.md`) |
| D2 | herdr session and pane state through the HC backend (the row previously named the 0.9.x contract, `HERDR_*` and `pane.report_agent_session`) | shipped: merged at `df491e0a` from `dev/d2-hc-pane-source`. Operator decision 2026-11-22: the herdr 0.9.x TUI generation is **retired by the operator**. The HC build (`herdr-core` 0.1.21 plus `herdr-app`) is the only supported backend. The documented 0.9.x socket contract is retired from scope and kept in `docs/D2_HERDR_CONTRACT.md` only as history. What landed is the recommended shape: `HerdrPaneSource` is a transport-agnostic protocol carrying a backend name, capability flags, a liveness probe and a reading; `HerdrCoreBackend` is its only implementation and `HerdrTransport` holds the bounded process runner and the socket probe. Pane state is its own `AgentPaneState` row keyed on the full `machine/tN` address, reporting only what a pane says about itself (state, status, space and tab labels, `labels.where`, foreground name and argv, title); it holds no tokens or cost, never enters live, spend or trend aggregation, and a null status reads as unknown rather than idle. Liveness is decided in one order and only through transports: a socket connect, then one bounded `hc server status`, then `terminals.json` freshness. `HERDR_ENV` and every other `HERDR_*` value are never evidence, because the host still carries `HERDR_ENV=1` for a server that died sixteen hours ago; each probe carries a deadline and a process still running at it is killed. The reader cannot address pane contents: its one command is the core's own status, it never names a screen, a pane read or a line read, and a structural check asserts both from the source. Degradation is explicit: a live transport whose state cannot be read publishes nothing rather than an empty fleet, a replaced or half-written file keeps the last good snapshot, an old file with no transport is stale, and nothing reachable is unavailable. On the merged tree the agents suite is 2,720 checks and the full suite 123,918, with the notch suite unchanged at 67,933 (`docs/VALIDATION_LOG.md`). Still open: HC has no agent-session identity channel, at rest or live, so identity can only be inferred from `foreground.argv` and `title` and no stable session id can be verified. Agent identity is meant to be supplied by the agents themselves rather than by the multiplexer, and the concrete carrier for that is the open design decision; the candidate the research found is `hc label <t> agent.session=<id>`, the only write-side hook available. The verified contract research, gap list and risk list for both generations are preserved verbatim in that spec |
| D3 | Multiple OpenCode Go API keys, per-key usage, rotation, secret-safe provisioning | shipped: rotation model, keychain secret store, and a keychain-backed registry with add/remove ordering. The OpenCode Go key surface under the AI settings adds a key behind a secure field, removes it and allows a rejected one again over that registry; the AI page lists the masked per-key rows while the OpenCode toggle is on, and the registry file holds no secrets. Per-key usage counters and provider routes skip rate-limited, invalid or exhausted keys. The routing model (`nextRoute`, `record`, `reportFailure`) is implemented and covered but has no caller: the app only reads local agent logs and downloads prices, and sends no OpenCode Go request, so per-key tokens stay zero until such a request path exists. The D3 branch measured 100 agent-key checks inside the 123,733-check Mac suite, and the D3 review-fixes series measured 105 assertion sites, 95 of which execute on a passing run: the other 10 are failure-only guard branches that run only when an earlier setup check fails. On the merged tree the agent-key suite executes 125 checks inside the 123,796-check Mac suite, all passing. That figure is the tree before the D2 merge; the agent-key suite still executes 125 checks, now inside the 123,918-check suite on `df491e0a`. This row previously said 77 checks, which counted every assertion site as if it had run. The honest per-commit full-suite record is kept in the validation log added with the D3 review fixes. Known debt: each recorded request still rewrites the whole registry file once, now outside the state lock; coalescing writes is not done because the counters must be durable when the app quits and that needs a flush hook in the app lifecycle |
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

## Lane log (2026-11-26)

Lane MacMgr. All git work ran on nixos; every macOS figure below came from one
batched `./build.sh --test` run per branch on `kooshas-laptop`.

| Branch | macOS result | Merged into `dev/maccy-clipboard-parity` |
| --- | --- | --- |
| baseline `dev/maccy-clipboard-parity` | 123918 checks PASS | — |
| `dev/e1-tailnet` | 123873 checks PASS | `26a9d8dd` |
| `dev/e2-mullvad` | 123881 checks PASS | `a3cd7f2c` |
| `dev/g-flux-warmth` | 123868 checks PASS | `41baa8cc` |
| `dev/g-smb-mesh` | **124233 checks PASS** at `2152cf7a` (verified) | `ca5edd58` |
| `dev/clip-placement` | **124340 checks PASS** at `0969068d` (verified) | `0969068d` |

- Four merged worktrees (`vorssaint-utils-{e1,e2,flux,mesh}`) were removed after
  the merge, so no lane is left on disk unmerged.
- The merged tree was then re-run on the Mac and reported
  `DEVELOPER INSTALL ISOLATION TESTS OK`.
- **The merge gate was not met, and the per-branch row for `dev/g-smb-mesh` above
  was wrong to read as "fine".** A run with the full log captured returned
  `TESTS FAILED (4 of 124232)`, all four in that branch's own suites:
  `SMBSharesTests.swift:179`, `SMBSharesTests.swift:325`,
  `ComputeMeshTests.swift:86`, `ComputeMeshTests.swift:92`. A count-less
  "build passed" is not a test result; only the counts are.
- Causes, both real: the mount lookup answered "mounted" for any endpoint sitting
  on the configured path before comparing server and share, so another server's
  identically named share read as this share's mount; and the unmount resolved
  the mount table before the configured share, so an unconfigured id reported a
  table failure instead of `unknownShare`. The two mesh failures were the test's
  own scenario: an empty device list is a present backend with nothing attached,
  while `nil` is a missing one, and the "three absent backends" case had left it
  empty.
- Fixed in `2152cf7a`, which also adds `Tests/LinuxSubsetCheck.sh` so those two
  Foundation-only suites iterate here instead of costing a Mac round trip. See
  the correction in `docs/NIXOS_READINESS.md`.
- `2152cf7a` carries `tx-agent: human`: `git-commit` detected only
  `JCODE_SESSION_ID` and kcode sets `KCODE_SESSION_ID`. The tool is fixed; the
  commit is an agent commit regardless of its trailer, and it was already pushed,
  so the ledger records the discrepancy here rather than rewriting history.
- `docs/NIXOS_READINESS.md` records why the app cannot be built here: SwiftPM
  resolves to `x86_64-unknown-linux-gnu` and there is no Apple SDK, so
  `import AppKit` fails. nixOS is a git and coordination node, plus the
  Foundation-only subset check above; the Mac is the only release build and
  verify target.
- **Re-verified on the Mac at `2152cf7a`, and green.**
  `./build.sh --test` on `dev/maccy-clipboard-parity` reported
  `TESTS OK (124233 checks)`, then `PREFERENCE CLEANUP TESTS OK`,
  `UNINSTALL SPACES TESTS OK` and `DEVELOPER INSTALL ISOLATION TESTS OK`,
  exit 0, 285 s. The count is one above the 124232 that failed, which is
  exactly the added positive `[]` -> `.available(applied: 0)` ComputeMesh case.
  All four failures of `179`/`325`/`86`/`92` are gone.
- The attempt before that was **not a test run at all**: `build.sh` accepts
  `--test`, so a bare `test` was ignored, `TEST` stayed 0, and the script fell
  through to the full build and died in Developer ID signing
  (`com.vorssaint.utils.fan-control: errSecInternalComponent`, retried 3/3).
  Signing cannot gate verification: the `--test` branch compiles `Tests/*.swift`
  and `exit`s at `build.sh:660`, before any bundle signing. `errSecInternalComponent`
  is confined to full and `--install` builds, i.e. the F1 notarization domain.
- Two new lanes opened from `ca5edd58`: `dev/knu-review` (K1-K4 above) and
  `dev/clip-placement` (A9 above).
- **`dev/clip-placement` (A9) merged and verified: `TESTS OK (124340 checks)` at
  `0969068d`**, exit 0, 278 s, plus all three auxiliary suites. The count is 107
  above 124233, which is the new `placementChoices` suite plus the registered-default
  and 15-language assertions.
- Its first macOS attempt did not compile, and this is the lesson worth keeping:
  `ClipboardHistorySupport.swift:171` called `NSRect(x:y:size:)`, which does not
  exist. The lane had no way to catch it - AppKit is macOS-only, and the Linux
  parser run proves syntax, never the initialiser. Fixed in `356fe39f`
  (`NSRect(x:y:width:height:)`, value unchanged), merged as `0969068d`. **A lane that
  touches AppKit cannot be trusted past a real macOS compile, and "the parser was
  clean" is not evidence about an initialiser signature.**
- The attempt after that returned `EXIT=137` with the test binary's output entirely
  missing while the three auxiliary suites still passed: the binary was SIGKILLed
  and lost its buffered stdout. It was not the change. The same binary at the same
  SHA, run under a pty, printed `TESTS OK (124340 checks)`; the full script then
  reproduced it. No jetsam entry, no sleep/wake, 67% memory free - cause unproven,
  recorded here rather than explained away. Run the test binary under a pty when a
  killed run has to be diagnosed, because a SIGKILLed process yields no output at all.
- Cross-review of the lane (independent reviewer, `temp/clip-placement/cross-review.md`)
  returned 4 PASS and 2 CONCERN, nothing changed. Two carry forward as follow-up work,
  neither a regression: `savePanelPosition` may record a *forced* placement as the
  remembered origin (unverified on the platform, and it would erase the user's own drag,
  which is the operator's requirement), and the cards layout ignores three of the five
  placement values while the Settings picker stays enabled and silent about it.


## KNU lane verified, after a compile failure of its own

`dev/knu-review` merged as `48c06ab2` and then did not compile on the Mac. The
first gate attempt stopped at three errors and a cascade in
`Tests/NewFeatureBadgesTests.swift`, all from one name: `checkNesting` binds
`let sections = WhatsNewSupport.sections(...)` at :155 and declares
`func sections(for:)` at :185 in the same scope, so the earlier `let` keeps the
name, every `sections(for:)` call resolves to a `WhatsNewSections` **value**, and
the compiler reports "cannot call value of non-function type
'WhatsNewSections'". The two errors about `.clipboardHistory` and the key path are
that same failure losing its contextual type. The helper is now `built(for:)`
(`1163eaf5`).

Then the re-gate: `TESTS OK (124368 checks)` at `1163eaf5`, exit 0, 279 s, plus
`PREFERENCE CLEANUP`, `UNINSTALL SPACES` and `DEVELOPER INSTALL ISOLATION` all OK.
124368 is 28 above 124340, which is the KNU suite.

**The pattern is worth naming, because it is now twice in one afternoon.** Both
workers produced code that the Linux parser accepted and the Mac compiler
rejected: an AppKit initialiser that does not exist (`NSRect(x:y:size:)`) and a
local function shadowed by a local `let`. Syntax-level checking cannot see either
class. A lane touching AppKit or Swift name resolution is not verified until the
Mac has compiled it, and `SUBSET OK` is a floor, not a gate.

The cross-review is more useful than the gate. It read the diff as a source
document and found: the stamp exists only in `CHANGELOG.md`, nowhere in the data
or the UI; the What's New window has no search field (only Settings search matches
KNU); a tagged feature's page shows no sentence about what a person can now do,
because the KNU bullet is deliberately excluded from the digest and the tag carries
no text; the de-duplication is one-sided, so a bullet naming both a tagged feature
and a feature with its own sidebar row prints twice - unreachable from today's
bullets, one changelog sentence away; the test fixture cannot express that shape;
and the production parser matches a literal ASCII `what's knu` while the test
helper folds U+2019, so an editor's smart quote turns the KNU bullet into a plain
`.changed` line with every test still green.

Three of those are cheap and are out in `fix/knu-review-followups`: fold
typographic apostrophes in the parser, stop rendering `Clipboard history` over
`Clipboard`, and rewrite the changelog section as prose for the person using the
build instead of an instruction naming an internal Swift symbol. The rest - the
date in the UI, search in the window, the feature page being bare, and one-sided
dedup - are deliberately a separate lane, not silently dropped.

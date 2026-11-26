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
| A9 | Clipboard surface placement as a chosen option: near the cursor, remembered popup, bottom of the screen, top centre, or the Dynamic Island — instead of only drag-and-remember | shipped: 124340 checks PASS at `0969068d`, and both review follow-ups landed in `0e32c835` (124373 checks) - a forced placement no longer overwrites the remembered origin, and the cards layout no longer offers an inert picker

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
| K2 | KNU entries are reachable from Settings search, or from a dedicated page | shipped: Settings search matches KNU, and the What's New window now has its own search field (124440 checks PASS at `03906740`); the window narrows by title and by change line, and a blank query is the identity rather than a filter |
| K3 | `CHANGELOG.md` carries a `### What's KNU` subsection with the date and time each item became new, so "what is new for a user as of <date/time>" is reviewable | shipped: `CHANGELOG.md` carries the stamp, and the window now renders it per feature in the reader's locale (`NewFeatureBadges.newAsOf` beside `tagged`, with a test that fails if the stamp and the changelog disagree in either direction) at `03906740` |
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
| E1 | Tailscale integration: bind agent and harness services to the tailnet, verify peer identity | shipped, and this row was stale like E2: `e41ea061` landed the binding with verified peer identity and `c0316be3` fixed the tool-path and fixture checks macOS found (`Sources/Vorssaint/Services/Tailnet/`, 355 lines). `TailnetTests` runs inside the `network` group, which reported `OK (254 checks)` at `03906740`; that group is shared with NetworkFeatureTests, SpeedTestTests and NetworkAddressTests, so 254 is the group's count and not E1's alone |
| E2 | Mullvad integration: per-provider egress policy through its SOCKS5 or CLI, refuse rather than fall back | shipped, and this row was stale: `cf5ee226` landed `EgressPolicy`, `ProviderEgress` and `MullvadProbe` (`Sources/Vorssaint/Services/NetworkEgress/`, 404 lines) with `Tests/MullvadEgressTests.swift` registered in the `mullvad-egress` group, `AgentPriceSource` as its caller. The macOS gate at `03906740` ran that group: `mullvad-egress: OK (84 checks, 0.01s)` inside the 124440-check run. The refusal shape is a policy property: an undeclared or malformed declaration refuses every lookup rather than sending the request directly, and the probe distinguishes a closed SOCKS port from a live listener whose relay is gone. Not verified: the live path, because no Mullvad instance runs on either host, so the 84 checks exercise the injected transport rather than a real handshake |

## F. Packaging and security

| # | Item | Status |
| --- | --- | --- |
| F1 | Signed, notarized `.app` and `.dmg`, stapled | blocked on notary credentials (`NOTARY_API_KEY_P8`, `NOTARY_KEY_ID`, `NOTARY_ISSUER_ID`) or a run in the Mac's GUI session |
| F2 | Homebrew cask in the tap | queued, follows F1 |
| F3 | Apple-platform findings: App Review / notarization risk, platform correctness and privacy surface | replaced with a source-derived review. The P85-1..P85-5 source (`pr-review-plan-20261120.md`) does not exist in the repo, `git log --all`, the Mac checkout or GitHub code search, so the reference is retired. Six findings, all read out of the tree with `file:line`: **P86-1 (blocker)** `RadialMenu/RadialNowPlayingService.swift:361` and `Notch/NotchMusicService.swift:125` hand private `MediaRemote` calls (`NowPlayingAdapter/NowPlayingSelection.swift:28`, `Resources/now-playing.pl:18`) to `/usr/bin/perl` because since macOS 15.4 only Apple-signed processes get an answer, which is an App Store rejection and a silent-failure dependency on a deprecated scripting runtime; **P86-2 (medium)** `HIDEventSystem/include/HIDEventSystem.h:3-4` and `MouseAcceleration/MouseAccelerationService.swift:64` use the undocumented `IOHIDEventSystemClient` SPI, same rejection class plus SDK drift; **P86-3 (medium)** `Clipboard/ClipboardHistoryService.swift:1236` persists copied text and image blobs unencrypted under Application Support, so they are readable by same-user processes, enter backups, and outlive the app; **P86-4 (medium)** `SudoersSupport.swift:18` installs a `NOPASSWD /usr/bin/pmset disablesleep` rule, correctly scoped and visudo-validated but a standing passwordless-root grant to every process of that uid; **P86-5 (medium)** `AgentUsage/AgentSecretStore.swift:41` uses `kSecAttrAccessibleAfterFirstUnlock` without `ThisDeviceOnly`, so provider keys restore onto another Mac from an encrypted backup; **P86-6 (low)** `Finder/FinderCutPaste.swift:282` and `SuperKey/SuperKeyService.swift:888` call `DispatchQueue.main.sync` inside CGEventTap callbacks, so a main-thread stall makes macOS time the tap out and the keystroke passes through unmodified. Signing and entitlement *state* stay UNVERIFIED: this host is Linux, with no `codesign`, `notarytool`, `spctl` or runtime to observe. Mac App Store is unreachable for this product (Accessibility taps, a root daemon, private frameworks, a shell-out), which confirms F1's Developer ID + notarization target |

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
| Flux (f.lux) | display colour temperature with a schedule. Vorssaint has brightness and extra brightness only | shipped, and this row was stale: the `flux` group reports `OK (71 checks)` at `03906740` and its five sub-groups (`flux-schedule` 23, `flux-override` 9, `flux-invalid` 9, `flux-colour` 19, `flux-restore` 11) exercise schedule, override, malformed input, colour maths and restore. Those sub-counts are inside the 71, so they must not be added to it |
| OpenRGB | RGB lighting control. macOS coverage is partial and hardware-specific, so treat as an optional sidecar rather than a native rewrite | needs info |
| SMB and compute-mesh management | mount and manage SMB shares, and a mesh view over Tailscale peers and SSH hosts, beside the existing `connectedDevices` and `portManager` | shipped, and this row was stale: `Sources/Vorssaint/Services/SMB` and `.../Mesh` exist, and at `03906740` the `smb-*` groups report 11 + 10 + 21 + 7 (configuration, listing, mount, unmount) while `mesh` reports 79 with `mesh-sources` 12, `mesh-ssh` 7 and `mesh-merge` 11 nested inside it |
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

## Clip-placement review follow-ups, verified

The four findings from the clip cross-review are fixed and gated: `TESTS OK
(124373 checks)` at `0e32c835`, exit 0, 280 s, all three auxiliary suites OK.
124373 is 5 above 124368, which is the new placement guards and their
assertions.

What changed, in the order the review ranked it. A placement that forces the
frame no longer writes the remembered origin: `keepsRememberedOrigin` returns
false for `nearCursor`, `bottomOfScreen` and `topCenter`, and true for
`remembered` and `dynamicIsland` - the island keeps storing a move because its
window is the fallback for that placement, which is the sort of exception that
would be wrong to flatten. The cards layout now says so instead of offering an
inert picker: `placementIsFixed` disables the picker and swaps in a caption, in
all 15 languages. Turkish says "Dynamic Island" like the label. And `bottomFrame`
uses `margin` like the clamp in `resize()`, so toggling the preview no longer
moves the window 8 pt and back.

Two notes worth keeping. The first gate attempt on `abee650f` failed on the KNU
shadowing error, not on anything this lane wrote: the branch was cut from
`0340bbe4`, which predates `1163eaf5`, so a branch cut from a stale base inherits
the base's compile errors and a red gate is not automatically that lane's fault -
check the file names before blaming the change. The second is that the worker did
the honest thing and reported its ceiling: `swiftc -parse` plus a 259-check
Foundation harness on the real 15-language table, with "every claim about a
window, a panel or a picker is a reading of the source" stated outright. That is
the standard here - a parse is not a typecheck, and the report says which one it
had.

## KNU review follow-ups, verified

`TESTS OK (124381 checks)` at `597a2466`, exit 0, 316 s, all three auxiliary
suites OK. Eight above 124373, which is the new title-agreement and apostrophe
assertions.

Three of the cross-review's findings are closed. The parser now folds U+2019 and
U+2018 before matching `What's KNU`, so an editor's smart quote can no longer turn
the KNU bullet into an ordinary `.changed` line while every test stays green - the
class of bug where the test folds and production does not, and so the test proves
the test. A nested row now takes its title from the Settings row it is filed
under, so the window no longer reads `Clipboard history` over `Clipboard`. And the
changelog's `What's KNU` preamble is prose for the reader again; the maintenance
rule it used to carry moved to the doc comment on `NewFeatureBadges.tagged`, which
is the value the rule is about.

The evidence standard this lane met is worth copying: it did not merely add
assertions and report them green, it swapped the pre-fix source under the new
tests and showed them **red** (three rows for the apostrophe, two for the pairing),
then showed them green with the fix. That red-then-green pair is the difference
between a test that constrains the code and a test that describes it.

Also recorded honestly: while proving the title fix, the author's first fixture was
wrong - the old two-page-row sidebar makes `representedFeature` nil, so the
harness failed for the fixture rather than the fix - and the report says so instead
of quietly adjusting the expectation to match. The real sidebar has a
`.feature(...)` row for an anchored tool, which is the row `rowID(for:)` files
under.

Still open, deliberately, in their own lane: no date or time is rendered in the
app (only in `CHANGELOG.md`), the What's New window has no search field of its own,
a tagged feature whose bullet is excluded from the digest gets a page with no
sentence about what a person can now do, and the de-duplication is one-sided so a
bullet naming both a tagged feature and a feature with its own sidebar row would
print twice - unreachable from today's bullets and one changelog sentence away.

## ocgo admin gate: shipped and live

`6b8bd81` on `master`, and the running pool is that binary. The live proof, taken
after the restart:

| Check | Result |
|---|---|
| `GET /reload` | `405 Method Not Allowed` + `Allow: POST` |
| `POST /reload` (pre-install smoke, isolated port) | `200 {"reloaded": true}`, pool JSON `"reloads": 2` |
| `GET /pool` | `200`, every `key` field `"<redacted>"`, no long strings, zero literal `sk-` |
| `GET /healthz` | `200` |
| real completion through the restarted pool | `finish: stop`, content `OK` |
| pid | `173835` → `928846` |
| previous binary | kept at `~/.local/bin/ocgo.bak-20261126T115422Z` |

The cross-review's two conditions were both met before the restart. Nothing outside
the repo calls `GET /reload`: no match in `~/bin`, `host-ops/bin`, or the user
systemd units, and `ocgo-serve.service` (which would restart-loop on the same port)
stays disabled, so only `ocgo.service` was restarted. And the binary was rebuilt
from the merged tree and installed *before* the restart, because restarting onto
the old binary would have changed nothing.

A note on checking for leaked keys: `grep -ci 'sk-|api_key|bearer|secret'` over the
pool JSON returns 7 and is a **false positive** - it matches the environment
*variable names* (`MINIMAX_API_KEY`, `OC_KO_API_KEY`, ...). The real check is
structural: parse the JSON, assert every `key` value is the redaction marker, and
assert no field holds a string long enough to be a credential. That check is clean.

One half of the earlier decision is still owed: `/pool` is redacted but not
authenticated. It is loopback-bound and `Ocgo.env` configures no client key, so
this is not reachable off-host; requiring a bearer on the admin surface is a
separate change that must also teach whatever calls it, and that caller list is
currently empty.

## Owed item closed: ocgo's logs carry no key material

Verified rather than assumed. `~/.local/state/ocgo-serve.log` is 1.5 MB and contains
zero matches for `sk-[A-Za-z0-9_-]{10,}` or `Bearer <token>`; what it logs is counts
("ocgo 6 key(s)", "minimax 1 key(s)") and never a value. The live process tree is one
server - pid `928846`, the only listener on `127.0.0.1:8791` - so the two
`bind: address already in use` lines in that log are historical double-start attempts,
not a stray second pool.

Live key set for the rotation still owed by the operator: five `OC_*_API_KEY` entries
in `Ocgo.env` plus `MINIMAX_API_KEY`. The pool reports six ocgo keys against five
`OC_*` names, so one entry is being counted from somewhere other than that file; it
does not change the redaction finding, and it is the kind of count to reconcile before
rotating rather than after.

## The KNU requirement is now met end to end

`TESTS OK (124440 checks)` at `03906740`, exit 0, 276 s, all three auxiliary suites
OK. Fifty-nine above 124381, and unlike the previous lanes these new suites run
inside the real test executable, so the macOS gate exercised the assertions rather
than merely compiling them.

The operator's sentence was "KNU should be searchable or have a dedicated page +
what's KNU section in changelog I can clearly review to see what's new for a user as
of xyz date/time item", with entries "under their parent item". Every clause now
resolves to something a person can do in the app: the entry sits under its parent
Settings row (K1), Settings search finds it and the What's New window has its own
search field (K2), the changelog carries the moment and the window renders that
moment per feature in the reader's language (K3), and a test fails if the changelog
and the tag disagree in either direction (K4).

What makes the stamp trustworthy is that it is not a second copy: `tagged` still owns
*which* features are new, `newAsOf` carries only the moment, and `checkStamps` reads
`CHANGELOG.md` and fails if the two disagree. The failure mode this prevents is the
one that nearly shipped last lane - a fact that lives in a file nobody renders.

The search field is honest about being a filter, not a second index: a blank query
returns the input unchanged, a parent that matches keeps its whole subtree, a parent
that does not match survives only with the children that did, and the overview counts
stay describing the update rather than the query. Folding is
case/diacritic/width-insensitive with `locale: nil`, matching
`SettingsSearchSupport.fold`, because a locale-aware fold lets Turkish map a dotted
I differently and would answer the same query two ways in two languages.

Verified beyond the green run: `swiftc -parse` on all five touched files, a
Foundation-only harness (28 checks) over the two new pure functions, and mutation
tests - drifting the stamp by one minute reddens only `checkStamps`, and making
`searching` return its input reddens only the filter suites, so the two are
independent rather than mutually masking. All 15 languages carry the three new
strings with exactly one `%@` each.

Not verified, and named as such by the lane: the window as rendered. Field placement,
empty-state wrapping, the clear button's hit area, VoiceOver order, and truncation of
the longer German and French strings are source readings on this host, because there
is no macOS here. The gate proves it compiles and the suites pass; only a human
looking at the window proves it looks right.

## Two corrections, both from reading the tree instead of trusting the rows

**E2 was not queued. It shipped and this ledger said otherwise.** The row read
`queued` while `cf5ee226` had already landed `EgressPolicy`, `ProviderEgress` and
`MullvadProbe` in `Sources/Vorssaint/Services/NetworkEgress/` (404 lines), with
`Tests/MullvadEgressTests.swift` registered in the `mullvad-egress` group and
`AgentPriceSource` as its caller. The macOS gate I already had in hand proves it ran:
`mullvad-egress: OK (84 checks, 0.01s)` inside the 124440-check run at `03906740`.
The refusal shape the row demanded is a policy property - an undeclared or malformed
declaration refuses every lookup instead of sending the request directly - and the
probe distinguishes a closed SOCKS port from a live listener whose relay is gone.
What is not verified is the live path: no Mullvad instance runs on either host, so
those 84 checks exercise an injected transport, not a real handshake.

**D's three remaining rows cannot be worked, which I had wrong.** D4 (instinct /
Hermes and other agent integrations), D5 (subscription or API key for the
companion) and D6 ("Vorssaint dots") are all `needs info`. My earlier plan named
"finish D's three remaining rows" as the default next lane; that was a stale read of
the section, and a lane dispatched against it would have produced three guesses.
D6 in particular is a name whose meaning is not recorded anywhere in the repository.

The pattern worth keeping: both corrections came from grepping the actual tree
before dispatching, not from re-reading the plan. A ledger row is a memory, and a
memory that is never re-checked drifts into a claim.

**F3 is retired, not deferred.** `pr-review-plan-20261120.md` is absent from the
repo, from `git log --all`, from the Mac checkout and from GitHub code search, so
the row was pointing at a document that has never existed on either host. F3 now
names the replacement: findings derived from the source in front of us, numbered
`P86-n` to continue the series rather than pretending the P85 set was ever read.

## The macOS total is authoritative; the per-group lines are not summable

Reading the gate log at `03906740` line by line produced a discrepancy worth writing
down. `Tests/TestSuite.swift` prints one line per group whose `N` is the delta of one
shared counter, and the harness's own summary is `TESTS OK (124,440 checks)`. The 70
group lines in that run sum to **124,590** - 150 more than the total.

The cause is not a lost run and not a duplicate group: it is nesting. A group body
may call `suite.run` again, and `ComputeMeshTests` and `FluxScheduleTests` both do.
`mesh` prints 79 checks while its three sub-groups (`mesh-sources` 12, `mesh-ssh` 7,
`mesh-merge` 11) print their own lines; `flux` prints 71 while its five sub-groups
print 23, 9, 9, 19 and 11. Those nested checks are inside the parent's delta *and* on
their own line. So the **total is the truthful figure** and a sum over the printed
lines over-reports. Every count cited in this ledger is the total, which is why the
existing rows are still correct - but a future reader adding up group lines would
conclude the suite lost 150 checks, and would be wrong.

A harness change is in flight to indent nested group lines so the log stops looking
summable. Until it is gated, the rule is: cite the total, and treat a group line as a
delta that may overlap its parent.

## A third correction: the pool admin surface was never unauthenticated

I had been carrying "`/pool` is redacted but unauthenticated" as an owed half. Reading
the pool's own code instead of my note: `adminAllowed` in
`internal/adapters/proxy/server.go` decides entitlement for `/pool`, `/pools`,
`/pool/status` and `/reload` **before** any entry sync runs, and the rule is that
loopback *is* the owner's own-machine entitlement while a non-loopback caller must
present the configured client key as `Authorization: Bearer` or `x-ocgo-pool-key`,
compared in constant time. `TestAdminRoutesGuard` is an 18-case matrix over
caller x entitlement x verb, and on this host at `6b8bd81` it passes 18/18
(`go test ./internal/adapters/proxy/ -run TestAdminRoutesGuard`, `EXIT=0`). The live
pool is `--addr 127.0.0.1:8791` with no client key, so a remote caller cannot even
reach the socket and the loopback path is the intended one.

So my unauthenticated 200 from `GET /pool` was the design working, not a gap. The
README documents both the loopback-only bind and the bearer defence. Nothing is owed
here; what remains owed on the key front is the operator's rotation, which is a
different item and still genuinely outstanding.

## Per-pillar macOS evidence, one run, quoted counts

The debt this pays: only 3 of 19 shipped rows carried a macOS count, because most rows
predate the practice of quoting one. Rather than retro-fit a number onto twelve rows
(which would be a claim about a run that never covered them), here is the mapping from
every shipped pillar to the group that actually exercises it, with that group's count
from the single run at `03906740` - the same run whose total is 124,440. A row is
"macOS-evidenced" when its symbol appears in a file the named group runs.

| Pillar | Group(s) that exercise it | Count in the 03906740 run |
| --- | --- | --- |
| A clipboard parity (A1-A9) | `clipboard` (ClipboardFeatureTests + PastePlainTests), `transient-paste`, `notch` (panel surface) | 1420 + 18 + 67933 |
| A2 KNU (K1-K4) | `updates` (carries `NewFeatureBadgesTests`, so `checkStamps` and the tag sets), `features`, `feature-hub-layout`, `localization` (15-language strings) | 1228 + 1422 + 178 + 9147 |
| B window policy | `window-policy` (WindowPolicyTests), `window-layout`, `spaces-order` | 27 + 580 + 120 |
| D1 jcode reader, D2 herdr panes | `agents` (2720, includes `NotchAgentTests` -> `HerdrPaneSourceTests`) | 2720 |
| D3 per-key registry and routes | `agent-keys` (AgentKeyPoolTests + Usage + Provisioning) | 125 |
| E2 Mullvad egress | `mullvad-egress` | 84 |
| E1 Tailscale | none - no group exercises it, and the row is `queued` | not applicable |

Two honest limits. First, a group count is a delta and may overlap its parent, so these
numbers must not be added; only the 124,440 total is additive. Second, "the group ran"
is weaker than "this row's assertion ran": the group-to-file mapping above is read from
`Tests/MetricsTests.swift` and the test files' own `run` entry points, not from a
per-assertion trace. Rows whose behaviour is a compiled-in decision (E2's refusal policy,
D2's no-pane-contents rule) are additionally checked structurally from source, which is
the stronger evidence for those.

## Pillar tally, recomputed from the tree instead of from the status column

Reading statuses was what produced the wrong picture. Re-derived from source and from
the 03906740 run's group output:

| Pillar | Shipped / total | Which rows |
| --- | --- | --- |
| A clipboard parity | 8 / 8 | A1-A9 |
| A2 KNU | 4 / 4 | K1-K4 |
| B window policy | 4 / 4 | B1-B4 |
| D AI agents | 3 / 6 | D1, D2, D3 shipped; D4, D5, D6 `needs info` |
| E network | **2 / 2** | E1 and E2 both shipped - the section previously read 0 / 2 |
| F packaging | 0 / 3 | F1 blocked on notary credentials, F2 follows F1, F3 replaced by a source-derived review |

That is **21 of 27**, not 19 of 27: the two E rows were shipped work filed as `queued`,
and E1 had even been through a macOS fix pass (`c0316be3`) after `e41ea061` landed it.

Three status mistakes in one section is a pattern, not bad luck: a row was written as a
plan and never revisited once the code landed, so the section describes an earlier week
and reads as if nothing had happened. The rule that follows is to derive a row's status
from a group in the gate log and a directory under `Sources/`, and only then write the
word. A row with no group and no directory is genuinely not started.

One further stale item: the topology note says NixOS SSH key auth is refused, so
offloading is blocked. This lane is executing on NixOS directly and has been for its
whole life, so that line is true only of the SSH path from another host, not of NixOS
availability.

## Open: the harness change is merged but not yet gated on macOS

`89cca321` merges `feat/harness-nested-indent` (`0fc005b2`) into
`dev/maccy-clipboard-parity` and is pushed. What it does: `Tests/TestSuite.swift` tracks
how many `run` bodies are on the stack and indents a nested group's line by two spaces
per level, so the log stops looking like a flat list of siblings; plus
`TestHarnessTests.nestingContract`, which pins that a nested line is indented, that the
counter increments once per assertion across nesting, and that the printed deltas sum to
more than the total - the over-report is now a test rather than a paragraph.

Evidence so far is Linux-side only: `Tests/LinuxSubsetCheck.sh` reports
`SUBSET OK (79 checks)` rc 0, and the worker's red evidence is real - on the base class
the nesting assertion fails (`FAIL: nested 'inner' line is NOT indented`, rc 1) while the
overlap fact already held (`1 + 2 = 3 > 2`), and the committed test does not even compile
against the base class (`no member 'lineSink'`, which is the seam added to observe a
printed line).

**The macOS gate is not met.** `kooshas-laptop` went offline while this was landing:
Tailscale reports `offline, last seen 1m ago`, ICMP to `100.112.14.98` is 100% loss, and
port 22 does not answer. The gate is `./build.sh --test` on that host - `--test`, not
`test`, because the bare word is an accepted argument of a different branch - and it
needs a long or absent client timeout, since a 276 s run has already been killed by a
60 s client-side bound and read as a lane failure.

Until it runs, the honest status of this row is `change_made`, not `workflow_validated`.
A 6-check harness test and a print-format change do not plausibly break 124,440 existing
checks, but "does not plausibly" is not evidence, and this lane has already been wrong
once about a number derived from a log it had not re-read.

### Gate retry probe, 2026-11-26T12:57Z - still unreachable

Scheduled retry `sched_2477f67b` fired and probed once, as instructed (no retry loop):

- `ping -c 2 -W 2 100.112.14.98` -> 2 transmitted, 0 received, 100% loss
- `tailscale status` -> `kooshas-laptop active; relay "lax"; offline, last seen 28m ago, tx 4992 rx 0`
- `ssh -o ConnectTimeout=20 kooshas-laptop hostname` -> `connect to host kooshas-laptop port 22: Connection timed out`

`tx 4992 rx 0` is the interesting figure: the laptop is still *sending* a little and receiving
nothing back, which is a path/relay problem rather than a powered-off machine. Nothing to do from
this side. `89cca321` and everything after it remain `change_made`, not `workflow_validated`.
The retry is rescheduled rather than dropped.

## P86-5 closed at `change_made`: keychain secrets were migratable off the device

Two writers stored secrets with `kSecAttrAccessibleAfterFirstUnlock`, which is the
**migratable** class: an encrypted backup restored onto a different Mac brings the item
with it, so an agent provider key or an SMB share password followed the backup off the
machine that earned it. Sites: `AgentUsage/AgentSecretStore.swift:41` (provider keys) and
`SMB/SMBSharesLive.swift:33` (share passwords).

Both now write through one `AgentSecretAccessibility.item`
(`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`). Deliberately not the stricter
`WhenUnlocked…` class: a menu bar app that launches at login runs before any user unlock,
and the stricter class would leave it unable to read its own keys until someone touched
the keyboard.

Two details that are the actual fix rather than the decoration:

- `KeychainAgentSecretStore.updateAttributes(for:)` puts the accessibility class in the
  `SecItemUpdate` dict as well as the data. Without that, an existing install keeps the
  migratable class forever, because a data-only update never re-classifies an item. Both
  the update and add paths use it; add still sets `kSecAttrSynchronizable: false`.
- The shared constant sits **below** `KeychainAgentSecretStore`. `Tests/LinuxSubsetCheck.sh`
  extracts everything above that struct into a Linux build with `awk … /^struct
  KeychainAgentSecretStore/{exit}`, so a Security symbol declared earlier would have been
  compiled into a target that cannot link `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.

Guarded by `smb-secret-accessibility` in `Tests/SMBSharesTests.swift` (six source-level
assertions, inside the existing SMB group so the gate's group list is unchanged and the
check also runs on Linux). The per-line form matters: `…AfterFirstUnlock` is a prefix of
`…AfterFirstUnlockThisDeviceOnly`, so a substring test would pass on the bad line.

RED, pre-fix source restored from `git show HEAD:` into both files:

```
smb-secret-accessibility: FAILED (6 checks)
SUBSET FAILED (5 of 85)
EXIT=1
```

GREEN, post-fix source:

```
smb-secret-accessibility: OK (6 checks, 0.00s)
SUBSET OK (85 checks) — not the release gate
EXIT=0
```

79 -> 85 checks, matching the six new assertions. Commit `dd074a4f`.

Honest status: **`change_made`.** `LinuxSubsetCheck.sh` compiles neither changed file
(they need Security), so nothing here is type-checked, and no real keychain item was
written or re-classified. The macOS gate remains the only authority, and it is still down.

### Gate probe, 2026-11-26T13:05Z — attempt four, still unreachable

One bounded probe, no retry loop: `ssh -o ConnectTimeout=10 -o BatchMode=yes
kooshas-laptop 'echo ALIVE'` -> `connect to host kooshas-laptop port 22: Connection timed
out`, rc 255 after 10 s. Unchanged from attempt three.

Tooling note for the next attempt: a combined probe that pipes (`ping … | tail`, then
`tailscale status`, then `ssh`) hung past 120 s with **no output at all** and had to be
cancelled, twice over two stretches. `tailscale status` on this host is the likely blocker,
and a pipe hides where it stopped. Probe with the bare `ssh` invocation only, no pipes, and
read the exit code.

`89cca321` (harness) and `dd074a4f` (P86-5) both remain `change_made`, not
`workflow_validated`, until the gate runs.

### A shimmed type-check for the two Darwin-only keychain writers

P86-5 was `change_made` and not type-checked: `LinuxSubsetCheck.sh` must exclude
`AgentSecretStore.swift` and `SMBSharesLive.swift` because they import Security, so the only
thing that could compile them was a Mac. `Tests/KeychainCompileCheck.sh` fixes exactly that
and nothing more. It declares the 20 Security symbols those two files name plus a `Shell.run`
signature (its real home, `ShellSupport.swift`, imports AppKit/CoreServices/Darwin), strips
the single `import Security` line from copies, and runs `swiftc -typecheck`.

What it proves: the files parse, every symbol resolves, the `SMBKeychainProjection`
conformance still lines up, and every `SecItem*` call takes the argument types it is handed.
What it does not prove: that an item is written with the class that was asked for, or any
behaviour at all. It is a pre-flight for a gate host that can be away for a day, not a gate.

```
KEYCHAIN TYPECHECK OK (2 writers, shimmed Security) — not the release gate
EXIT=0
```

Negative control, the `ThisDeviceOnly` constant deleted from the shim:

```
KEYCHAIN TYPECHECK FAILED:
…AgentSecretStore.swift:93:33: error: cannot find 'kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly' in scope
EXIT=2
```

So a symbol the framework does not provide cannot pass silently here. Earlier iterations of the
same script failed on `CFString`, `CFDictionary` and `Shell` before those were declared, which
is the same evidence from the other direction: nothing is being resolved by accident.

Shim fidelity is the limit to keep in mind. `CFString` is `String` and `CFDictionary` is
`NSDictionary` in the shim, so `as CFString` conversions are wider than Darwin's and could
accept something the Mac rejects. The pre-flight narrows the gap; it does not close it.

## P86-6 corrected: the taps already recover, so the deadlock class was the real defect

The P86-6 finding says a `DispatchQueue.main.sync` inside a CGEventTap callback makes macOS
time the tap out and let the keystroke pass through unmodified. Reading both taps, that is
mostly wrong, and the wrong part matters because it hides what is actually wrong.

- Both taps **already handle the timeout**: `FinderCutPaste.swift:258` and
  `SuperKeyService.swift:654` both test `type == .tapDisabledByTimeout || type ==
  .tapDisabledByUserInput` and re-enable the tap when the session is active and accessibility
  is still trusted. So a main-thread stall costs one unmodified keystroke and a log line, not
  a dead keyboard.
- Both taps run on a **dedicated thread** with their own `CFRunLoop`
  (`FinderCutPaste.swift:200-245`), so the sync hop cannot deadlock today.
- `SuperKeyService.swift:884-890` already guards its hop with `Thread.isMainThread`.

What was genuinely left: `FinderCutPaste.swift:282` was the one unguarded main hop reached
from a tap callback, and the other four main hops in this target
(`TextSnippetService:420`, `MouseAppExceptions:113`, `SuperKeyService:888`,
`CommandBarService:680`) all carry `Thread.isMainThread ? … : sync`. If the tap were ever
added to the main run loop instead of its own thread, `route` would call `main.sync` from the
main thread and hard-deadlock the keyboard. It now goes through `Self.onMain`, which is the
same guard spelled once.

Honest status: `change_made`. This is correctness by construction with no fixture behind it:
"this call happens on the tap thread" is not expressible in a test, and `FinderCutPaste`
imports AppKit so the Linux subset cannot compile it. The timeout re-enable above is the
runtime behaviour that would show a regression on the Mac, and it is untouched.

### P86-3 scoped, and the cheap half of it closed

The P86-3 finding as written ("clipboard text and image blobs persisted unencrypted under
Application Support") is right about the bytes and wrong about the exposure, so it was re-scoped
by reading the two writers instead of restating it.

`PrivateFileStore` already sets `0o700`/`0o600` and re-tightens the whole chain on every create,
so no other *account* can read the container and there is no world/group mode to fix. What was
actually open: the container sits in the Time Machine set, so a restore onto a different Mac
carries the entire clipboard history and the shelf with it, and nothing in the tree excluded it.
Also open, and not fixed here: any process running as the same user reads it, there is no crypto
anywhere in the clipboard path, and text expiry rewrites the JSON blob without overwriting the
previous bytes.

Shipped: `PrivateFileStore` now sets `URLResourceValues.isExcludedFromBackup` on every directory
in the chain and on every written file, via one `excludeFromBackup(_:)` called from both paths —
both, for the same reason the mode is re-applied: a container built by an earlier version heals
on next use instead of needing a migration.

Guard: `private-file-store-backup-exclusion`, 3 assertions, inside `Tests/SMBSharesTests.swift`
rather than a new suite, so `build.sh` group list and `LinuxSubsetCheck.sh` SUITES are both
unchanged and the guard runs on Linux. It reads `PrivateFileStore.swift` as text, which is all
the subset can do: `isExcludedFromBackup` does not exist in corelibs-foundation.

RED→GREEN against `git show HEAD:`: `FAILED (3 checks)` / `SUBSET FAILED (3 of 88)` / EXIT=1, with
"found 0 call sites" proving the call-site assertion is not vacuous; post-fix `OK (3 checks)` /
`SUBSET OK (88 checks)` / EXIT=0. Totals 85 → 88.

Left as an operator decision: encrypting the history with a device-bound keychain key (reusing
`AgentSecretAccessibility.item` from P86-5). It is a product call — an opaque history file costs
export, inspection and support debugging — and its decrypt-failure path cannot be honestly tested
without the Mac.

Status `change_made`, ungated. The scoping lane's worker died on the same
`opencode-go:deepseek-v4.1-flash` mid-stream failure as the earlier ones, so this scope and its
fix were done directly in the lane checkout; `kooshas-laptop` remains offline and no macOS result
exists for any of the four prior commits either.

### The gate came back: `6bce2a44` is the first validated commit in this stretch

`kooshas-laptop` answered on the fifth attempt — the bare no-pipe probe returned `ALIVE` / rc 0 in
209 ms, where attempt 4's piped probe had hung past 120 s twice. Fetch, checkout
`dev/maccy-clipboard-parity`, `git merge --ff-only origin/…` to `6bce2a44b`, then `./build.sh --test`
detached (`setsid` does not exist on macOS; `nohup … & disown` with all three fds redirected works
and returned in 3 s).

Result: **`TESTS OK (124455 checks)`**, `PREFERENCE CLEANUP TESTS OK`, `UNINSTALL SPACES TESTS OK`,
`DEVELOPER INSTALL ISOLATION TESTS OK`, and **zero `FAILED` lines in the whole transcript**.
Both new guard groups are present and green in the macOS run: `smb-secret-accessibility: OK
(6 checks)` and `private-file-store-backup-exclusion: OK (3 checks)`. Wall time roughly 12 minutes.

Totals: prior gated run `124440` at `03906740`; this run `124455` at `6bce2a44`. That is +15, of
which +6 is the new `NewFeatureBadgesTests.swift` suite that arrived with the harness merge, +6 is
P86-5, +3 is P86-3. The +6 prediction for P86-5 was therefore right about P86-5 and wrong about the
total, because the merge added a suite of its own.

Because `6bce2a44` has the other four commits as ancestors, this single run compiles and exercises
them: `89cca321` (harness merge), `dd074a4f` (P86-5 keychain device binding), `14adc551`
(`KeychainCompileCheck.sh`) and `c2dfb4ca` (P86-6 tap main-hop guard) are **no longer ungated**.
They are `workflow_validated` — the suite compiled them and ran green — with the honest caveat that
"compiled and the tests pass" is not "the runtime behaviour was observed": nothing in this run
touched a real keychain item or a real event tap. `outcome_delivered` is still not claimed for
either.

Caveat on the exit code: the run was detached, so `build.sh`'s own status was not captured. The
transcript reaches the script's final `OK` stage with no failure line, which is the same terminal
state the previous gated runs exited 0 from, but the number itself was not observed.

Attempt 5's scheduled probe is now redundant; it was left in place rather than cancelled mid-window.

### P86-1 written up: the App Store half was overclaimed, the fragility half was underclaimed

Design note at `docs/P86-1-NOW-PLAYING-CHANNEL.md`. P86-1 called the perl bridge a blocker because
of App Store rejection; that half does not hold. The product already needs Accessibility event taps,
`IOHIDEventSystemClient` SPI and a sudoers-installed root daemon, so the App Store channel was off
the table before Now Playing mattered, and the perl hop itself notarizes fine: the adapter is signed
with the Developer ID and `--options runtime`, under its own identifier, staged inside
`Contents/Frameworks` (`build.sh:61-64`, `:171-172`), so hardened-runtime library validation is
satisfied and `notarytool` has nothing to object to.

What is genuinely wrong is the failure mode, and it is worse than the finding says. The chain depends
on four things outside the app's control — `/usr/bin/perl` still existing, `DynaLoader` still
working, private MediaRemote symbol names not moving, and MediaRemote continuing to answer platform
binaries — and every one of them fails *silently*: `RadialNowPlayingService.swift:356-361` returns
`completion(nil)` and `NotchMusicService` calls `connectionEnded()`, so the notch shows no track and
says nothing.

Three options with costs are in the note. Recommendation: make the failure legible first (map the
perl script's existing distinct `die` statuses at `now-playing.pl:16-21` to a reason shown in the
notch's empty state and in `TROUBLESHOOTING.md`), then move Apple Music and Spotify to Apple Events —
public API under an entitlement the app already declares — and keep the private path only as
fallback. Dropping "other players" entirely is the smaller tree but a real feature loss and only
worth it if the fallback turns out to cover almost nobody.

Corrected in passing: an earlier draft of the note asserted "the app already has a diagnostics
surface". It does not; `find Sources -iname '*diagnos*'` returns nothing. The note now says so, which
is the kind of thing that would otherwise get quietly built on.

No code changed, so there is nothing to gate. P86-1 stays open at the design step until the
"legible failure" change is written.

### P86-2 and P86-4 written up, and P86-4's disclosure gap was not a gap

Notes at `docs/P86-2-4-SPI-AND-PRIVILEGE.md`.

**P86-2.** The header at `Sources/HIDEventSystem/include/HIDEventSystem.h:1-4` pulls two public IOKit
headers and two private ones, is wired in as a header-only module (`build.sh:216`), and so links the
private symbols directly rather than through `dlsym`. That makes the drift failure a **launch
crash** (missing symbol), not a degraded feature — strictly worse than the MediaRemote path, which
`dlopens` and can fail soft. Recommendation: load the constructor through `dlopen`/`dlsym` the way
`NowPlayingSelection.swift:30` already does, so a removed symbol means "linear mouse mode
unavailable" instead of an app that will not start. Replacing it with the system-wide
`com.apple.mouse.scaling` preference is a product decision (it costs the per-device behaviour that is
the feature), not a defect fix.

**P86-4, corrected.** The note was going to ask for a disclosure paragraph. `docs/PERMISSIONS.md:139-145`
already has one: the sudoers rule, "allows only that single command", saying no keeps the feature
working with a password, and the rule goes away on uninstall. So the gap is precision, not absence,
and there are exactly three imprecisions worth fixing: it never says the grant is **passwordless for
every process of that uid** (the half with security weight), it never prints the rule or its path so
a user can verify it, and "goes away on its own when you uninstall" is only true for the app's own
uninstaller — a drag to the Trash leaves `/etc/sudoers.d/vorssaint-clamshell` behind, which is not
fixable in code and is therefore the sentence that should change.

What the code gets right and should stay: the rule is granted by **uid** rather than username (a
short name on an SSO-enrolled Mac can be an email address, `SudoersSupport.swift:11-16`), the grant is
**proven by using it** through `sudo -n` rather than by listing it with `sudo -l`, which reported
ready while the real call still prompted (`ShellSupport.swift:146-153`), and both commands are
**argument-exact** at an absolute path.

No code changed in either note, so nothing to gate. Both P86-2 and P86-4 stay open at the design
step: P86-2's `dlopen` conversion and P86-4's three-sentence correction are each small enough to be
the next leaves.

**P86-4 disclosure corrected in `docs/PERMISSIONS.md`.** The "goes away on its own" claim was false
for a Trash deletion, so it now says the uninstaller removes it and a Trash deletion leaves the file.
Added the exact rule text and its path so a user can verify it, and said plainly that the passwordless
part applies to any program running as that user. Also added a short "one feature asks for nothing"
section: per-device mouse acceleration needs no permission and no prompt, and — stated as today's
truth, not an aspiration — it is the one place where a macOS update can break the app from our side
because the interface is undocumented. That sentence becomes "the mode becomes unavailable and
everything else keeps working" only after P86-2's `dlopen` shim lands.

P86-2's shim was scoped rather than smuggled in: six functions and two opaque types are actually
used, everything else is public IOKit, so it is a shim plus a call-site rewrite with no Mac-free
behavioural verification available. Next leaf.

### P86-1 first half shipped: the bridge now says why it failed

`c87a2213`. `NowPlayingBridgeFailure` plus a de-duplicating reporter, wired into both bridges; the
radial path no longer collapses a timeout, a non-zero exit and an unreadable reply into the same
`completion(nil)`. `Tests/NowPlayingBridgeTests.swift` = 14 behavioural checks on the reporter and 9
source checks on the call sites; the call-site group is RED against the pre-fix tree (9 of 111
checks failing) and GREEN after (111 of 111), so the check is not vacuous.

What this does **not** do: a user who is not reading Console.app still sees an empty card. The UI half
(notch empty state + wheel card + a `docs/TROUBLESHOOTING.md` filter line) is the next leaf, and P86-1
stays open until it lands.

### P86-1 gate: `a19f522c` passes on the real host, 124479 checks

`./build.sh --test` on `kooshas-laptop`, one run: **`TESTS OK (124479 checks)`**, zero lines matching
`FAIL|not ok|error:|✗`, 76 suite-OK lines, and the three shell suites (preference cleanup, Uninstall
spaces, Developer install isolation) each ended OK. Baseline was `124455` at `6bce2a44`, so the delta
is **+24**, fully attributed: **+23** from the new `now-playing` group (14 reporter + 9 call sites) and
**+1** from `PreferenceNamespaceTests`, which asserts one check per `Tests/*.swift` file and therefore
grew when `NowPlayingBridgeTests.swift` was added.

The first attempt at `c87a2213` failed to compile — `cannot find 'NowPlayingBridgeFailure' in scope`
— because `build.sh` compiles an explicit Foundation-only support list into `metrics-tests` rather
than the whole tree; `a19f522c` adds the file to that list. That is exactly the class of error the
Linux subset cannot catch, because the subset keeps its own list.

**Exit code was not captured** (the run was launched detached with `nohup … & disown`, so the shell
reported on the process, not the gate). The log's terminal state is clean by every marker the script
emits, but no `EXIT=0` was recorded, so this is `workflow_validated`, not `outcome_delivered`: nothing
has yet been observed at runtime — no real media player, no real log stream, no reading of
Console.app.

## P86-1 closed: the empty card says why

**`678a72b4`, gate `TESTS OK (124491 checks)`, 0 failure markers.** The Now Playing channel now
distinguishes "nothing is playing" from "the channel is broken" everywhere a user can see it, not
only in Console.app. `.unavailable` is a fourth radial state, drawn by the notch card, the notch
compact strip and the wheel label, with the label present in all 16 language tables.

Twelve new checks, and the baseline moved by exactly twelve. The surface group is real RED against
the pre-change tree (8 of 9 fail); the reporter's three new checks are not, because `showsUnavailable`
existed before the test that asserts it, and saying otherwise would be invention.

**A flake was found and named rather than retried away.** `RecorderFastGIFExportTests.swift:27` waits
240 s for a GPU GIF export. Under load average 11.26 the suite took 287.96 s and failed; on the same
commit minutes later it took 54.94 s and passed. A wall-clock deadline on a shared laptop is a load
detector, not a correctness test, and the number to watch is the suite duration in the log, which is
printed either way.

## P86-2 closed: six private symbols now resolve or withdraw

**`2560553e`, gate `TESTS OK (124511 checks)`, 0 failure markers, all three shell suites OK.**
Design record stays at `docs/P86-2-4-SPI-AND-PRIVILEGE.md`; the delivery record is
`docs/P86-2-HID-SPI-SHIM.md`.

The app no longer links `IOHIDEventSystemClientCreateSimpleClient`,
`IOHIDEventSystemClientCopyServices`, `IOHIDServiceClientGetRegistryID`,
`IOHIDServiceClientConformsTo`, `IOHIDServiceClientCopyProperty` or
`IOHIDServiceClientSetProperty` from five place sites. They sit in one table
(`Services/HID/HIDEventSystemSymbols.swift`), `HIDEventSystemShim` resolves all six with `dlsym` at
first use, and every call site goes through the shim. A macOS that drops a symbol now costs the
accelerate-scrolling and Caps Lock-unmapped features instead of costing the process at dyld bind
time.

**The delta is exactly attributable.** Baseline 124491 → 124511 is +20: the 19 new checks plus the
preference-namespace guard's per-file read of the two new sources. No existing suite moved; the
now-playing groups still report 17/9/9 and roll up to 35.

**The new baseline is 124511, and the Linux subset is 142 checks** (was 123).

**RED is partial and named.** Reverting the three call-site files to `HEAD` fails 6 of 19: the three
per-file "reaches the interface through the shim", the tree scan that lists all three files by name,
and the two mode-availability checks. The other thirteen test files this commit created, so they
cannot be RED.

**Two gate runs died at compile before the third passed, and that is not a flake to be re-read.**
`generate_sources.py` copies `clearUnmappedCapsLock` verbatim into a test double, so the double has
to satisfy everything the body touches. Attempt 1: the shim did not exist in the double. Attempt 2:
the double nested the shim with a `shared` singleton, and Swift refused the recording fakes as
instance members of the enclosing state. Attempt 3 holds the shim as a stored dependency on both
sides and is green. Each failed attempt died in about twenty seconds, before a single test ran, which
is why this feature consumed three runs against a budget of two: there was no test result to re-read.

**Measured, not assumed.** The six symbols resolve on this Mac today (a `ctypes` `dlsym` probe of
IOKit), so `isAvailable == true` here and the user-visible behaviour is unchanged. The imported
signatures were taken from `swiftc -typecheck` against the real headers rather than guessed:
`ConformsTo` is `Int32`, `CopyProperty` is `CFTypeRef?`.

**Unproven:** the withdrawal path itself. `isAvailable == false` needs a Mac genuinely missing a
symbol, and there is none; what is proven is that the interfaces resolve, that no call site bypasses
the shim, and that the acceleration mode consults the shim's own answer before offering itself.


## P86-3 closed: the clipboard history is encrypted at rest

**Three commits, `687a9367` → `440c6f69` → `fdf7c416`. Final gate `TESTS OK (124552 checks)`,
`FULL_RC=0`, 0 failure markers, all three shell suites OK.** Design and delivery record:
`docs/P86-3-CLIPBOARD-AT-REST.md`.

Copied text and copied images no longer sit in Application Support as plaintext. History entries
and image blobs are sealed with AES-256-GCM under a key held in the login keychain at
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, so the key does not travel to another Mac in a
backup. The stored blob is a small crypto-free envelope (version byte, nonce, ciphertext, tag), and
the envelope type is separate from the cipher so the layout can be inspected on Linux, where
CryptoKit does not exist. Three call sites were moved onto the sealed path, and the image read path
went from a file URL to bytes because that is the only way to reach the cipher.

**The delta is exactly attributable.** Baseline 124511 → 124552 is +41: 36 suite checks at the
first commit minus one dropped in the rewrite (124548 → 124547) plus five round-trip checks
(124547 → 124552), and one PreferenceNamespaceTests check for the new test file, which it emits per
discovered Swift file. The suite reports `clipboard-at-rest: OK (40 checks)` = 11 envelope + 4
passthrough + 7 bounds + 13 wiring + 5 round trip. Linux subset is 177 checks, was 142; the
round-trip block is compiled out there, so Linux carries 35 of the 40.

**The wiring suite was proved to bite rather than assumed.** Reverting the image read path to
`return raw` turned the subset `FAILED (13 checks)` / `SUBSET FAILED (1 of 178)` at
`Tests/ClipboardHistoryAtRestTests.swift:145`, and reverting the revert turned it green.

**Gate attempt one failed two checks, and the failure was correct.** `this platform can seal` and
`two seals of the same bytes differ` failed because an ssh-launched test process has no login
keychain. Measured rather than guessed: a small `xcrun swift` probe on the same host returned
`SecRandomCopyBytes` = 0, `SecItemAdd` = **-25308** (`errSecInteractionNotAllowed`),
`SecItemRead` = **-25300** (`errSecItemNotFound`). The test had been asserting the environment.
It was rewritten to seal once and assert from the answer, so both worlds now assert the rule that
actually matters: when a seal is attempted and fails, nothing is written in cleartext.

**Then the honest problem was that nothing had observed the encryption.** The rewritten suite
exercised the failure branch on macOS and the unsupported branch on Linux, so AES-GCM through this
code had been asserted by nobody. Hence `seal(_:using:)` and `open(_:using:)`, which take a
caller-held key; the application path resolves its keychain key and calls them, unchanged in shape.
The suite now generates a key and checks the frame header, the round trip, that a second seal of
the same bytes differs, that a different key returns nil, and that one flipped tag byte returns nil.

**Three gate runs, and the third is justified rather than budgeted away.** Runs one and two belong
to the feature commit and its fix; run three belongs to a separate commit whose whole purpose was
to produce the observation runs one and two could not. Attempt two passed every check it contained,
so re-reading it could not have told anyone whether the cipher worked.

**Unproven, and named:** the keychain lookup inside `seal(_:)` and `open(_:)` on macOS. Only a GUI
session with a logged-in keychain exercises it, and no automated run here can. The consequence is
recorded where the guard is: while the keychain is unreachable, history stops surviving relaunches
while the in-memory list keeps working, and there is no visible status for that yet, which belongs
with P86-4's disclosure work.

That leaves **P86-4 as the last open F3 finding**; F3 stays open and F stays at 0 / 3 until it lands.

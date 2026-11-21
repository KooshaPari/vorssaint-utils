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
| D1 | jcode harness reader so jcode sessions and usage appear in the notch agents strip | queued |
| D2 | herdr session and pane state through the documented contract (`HERDR_*`, `pane.report_agent_session`) | queued |
| D3 | Multiple OpenCode Go API keys, per-key usage, rotation, secret-safe provisioning | wip: rotation model, keychain secret store and registry with add/remove ordering, covered by 22 checks. Per-key usage and provider wiring next |
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

- Apple Developer account is paid; Developer ID Application (GCT2BN8WLL) is
  installed on the Mac. Headless builds cannot use it because the login keychain
  is locked over SSH, so dev builds pass `VORSSAINT_SKIP_DEVELOPER_ID=1`.
- Mac: `kooshas-laptop`, 100.112.14.98, macOS 27.3, Xcode 26.0, Swift 6.2.
- The self-test build slices individual functions into
  `build/generated-tests/*.swift`; a sliced function cannot use instance
  properties declared elsewhere, so such paths read preferences directly.
- C: on the Windows host is below the 500 GB threshold, so new work lives on E:.

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

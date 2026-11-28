# Validation log

What was actually run, where, and by which agent. A trailer that quotes a check
total belongs here with the command that produced it. A claim that cannot be
reproduced on its own tree is marked as such rather than repeated.

## Per-key OpenCode Go keys (D3)

| Commit | Agent | Evidence recorded | Assessment |
| --- | --- | --- | --- |
| `3ac43881` rotation model | jcode | `tx-validated: pending` | unverified |
| `bb86a1d4` keychain store | jcode | `tx-validated: pending` | unverified |
| `8484d437` per-key usage and routing | jcode | trailer claims `PYTHONUTF8=1 python Tests/generate_sources.py`, `build.sh --test` with 123642 checks, and `build.sh --dev` | overstated: see below |
| `d03bfdc2` French window policy punctuation | jcode | trailer records `build.sh --test` and `build.sh --dev` with no count | plausible, count not stated |
| `545f69b2` docs | jcode | trailer repeats 123642, but the diff is documentation only | count not attributable to this commit |

`8484d437` cannot have produced a passing 123,642-check run from its own tree.
That tree still had `Fenêtres déplacées : %d` with a plain space before the
colon, the French punctuation the localization check rejects. `d03bfdc2`
changes exactly that line to a non-breaking space. The 123,642 figure therefore
describes a different working tree, not the commit it is attached to, and the
`545f69b2` trailer inherited it.

## D3 review fixes

Five commits applied on the Windows host by jcode (D3 fixes track), each one
finding. Every commit ran:

```sh
PYTHONUTF8=1 python Tests/generate_sources.py
```

which regenerates `build/generated-tests/` and exits 0. The script prints no
success token, so the evidence is the zero exit status and the regenerated
files. Neither `build.sh --test` nor `build.sh --dev` can run on Windows; the
macOS evidence for this series is appended below once the batched run exists.

| Commit | Finding | Windows |
| --- | --- | --- |
| `3eda9a1b` health transitions | 1 | generator exit 0 |
| `26f6ac7c` pruned registry written back | 2 | generator exit 0 |
| `3911c511` executed check count | 3 | generator exit 0 |
| `4eb9125f` rate-limit, missing-secret and publication coverage | 4 | generator exit 0 |
| `ad46f771` write outside the state lock | 6 | generator exit 0, plus a blocking-store contention check in the suite |

### Batched macOS run

One ssh invocation, run once, against the fast-forwarded clone at
`/Users/kooshapari/CodeProjects/vorssaint-utils`, tip `ad46f771`, by jcode
(D3 fixes track) on macOS 27.3 (26C5047e). The tree was clean at `bb86a1d4`
before a `--ff-only` merge; no local commits were present.

```sh
VORSSAINT_SKIP_DEVELOPER_ID=1 ./build.sh --test-suite=agent-keys
VORSSAINT_SKIP_DEVELOPER_ID=1 ./build.sh --test
VORSSAINT_SKIP_DEVELOPER_ID=1 ./build.sh --dev
```

Exit codes: `agent=0 full=0 dev=0`. Verbatim tails:

```text
agent-keys: OK (95 checks, 0.00s)
TESTS OK (95 checks)
```

```text
emoji: OK (225 checks, 0.05s)
TESTS OK (123667 checks)
PREFERENCE CLEANUP TESTS OK
UNINSTALL SPACES TESTS OK
✓ Installed: /var/folders/.../Applications/Vorssaint.app
DEVELOPER INSTALL ISOLATION TESTS OK
```

```text
▸ Assembling and signing bundle…
  stamped dev build: ad46f771
  signing with legacy self-signed identity: Vorssaint Utils Signing
✓ Bundle ready: build/stage.noindex/Vorssaint (Developer).app
```

The 95 agent-key checks are the executed count in the ledger row: 105
assertion sites minus 10 failure-only guards. The full suite moved from the
123642 the old trailers quoted to 123667, exactly the 25 agent-key checks this
series adds. The only compiler diagnostic was a pre-existing warning in
`AgentKeyPoolTests.swift:13` about `var empty` never being mutated, on a line
this series does not touch.

## Merge recovery: `dev/d3-key-wiring` and `dev/d1-jcode-harness-reader`

A worker was killed mid-merge and left `docs/ROADMAP_LEDGER.md` unmerged on
`dev/maccy-clipboard-parity` at `93868ae1`. This entry records the completion of
that merge, the merge after it, and the one batched macOS run that validated the
result.

| Step | Branch | Branch tip | Merge commit |
| --- | --- | --- | --- |
| 1 | `dev/d3-key-wiring` | `c1dbd7b2` | `a03ede28` |
| 2 | `dev/d1-jcode-harness-reader` | `b5cac278` | `8a238f56` |

Both are ordinary merge commits with the default message, no squash, no rebase
and no force-push. The first resolved the single conflicted file,
`docs/ROADMAP_LEDGER.md`, by union: the D3 row keeps the D3-fixes wording, the
validation-log reference and the known-debt note, and gains the provisioning
surface, the no-caller caveat for `nextRoute`/`record`/`reportFailure`, and the
routing and per-key-usage wording from `dev/d3-key-wiring`. Every check figure
in that row is attributed to the tree that produced it, and the row keeps
`shipped`.

The second merge auto-merged, and was checked rather than trusted. After it,
`AgentProvider` is `claude, codex, opencode, copilot, jcode`; the reader
dispatch holds both `OpenCodeReader()` and `JCodeReader()`; `Defaults` and the
settings view hold both `notchAgentsOpenCode` and `notchAgentsJCode` with the
OpenCode key surface still gated on the OpenCode switch; every file that
switches on `.copilot` also switches on `.jcode`; `AgentKeyStrings` still
carries all 15 languages; and `NotchAgentStrings`, `NotchEditorStrings`,
`ReleaseChangeAliases`, `SettingsDirectory`, `README.md` and `docs/PRIVACY.md`
carry both surfaces.

### Batched macOS run

One ssh invocation, run once, by jcode on macOS 27.3 (26C5047e). The Mac clone
at `/Users/kooshapari/CodeProjects/vorssaint-utils` was clean on `ad46f771`;
the two merge commits were delivered as a `git bundle` and fast-forwarded with
`git merge --ff-only`, leaving the clone at `8a238f56` with a clean tree.

```sh
VORSSAINT_SKIP_DEVELOPER_ID=1 ./build.sh --test-suite=agent-keys
VORSSAINT_SKIP_DEVELOPER_ID=1 ./build.sh --test-suite=notch
VORSSAINT_SKIP_DEVELOPER_ID=1 ./build.sh --test
VORSSAINT_SKIP_DEVELOPER_ID=1 ./build.sh --dev
```

Exit codes, in that order: `agent=0 notch=0 full=0 dev=0`. Verbatim tails:

```text
agent-keys: OK (125 checks, 0.01s)
TESTS OK (125 checks)
```

```text
▸ Building & running tests against MacOSX26.sdk…
sandbox_extension_consume failed: 1 (Operation not permitted)
2026-11-21 20:24:03.278 metrics-tests[85667:14088853] Make a symbolic breakpoint at NSTextLayoutManagerBreakOnNilContentManager to catch this in the debugger.
notch: OK (67933 checks, 42.49s)
TESTS OK (67933 checks)
```

```text
switcher: OK (1582 checks, 9.33s)
keep-awake: OK (189 checks, 0.03s)
wallpaper: OK (94 checks, 0.02s)
emoji: OK (225 checks, 0.05s)
TESTS OK (123796 checks)
PREFERENCE CLEANUP TESTS OK
UNINSTALL SPACES TESTS OK
▸ Installing into /var/folders/wl/z8733y815nzg28yy0_1_lh7w0000gn/T/tmp.CwuKdZeeKj/Applications…
✓ Installed: /var/folders/wl/z8733y815nzg28yy0_1_lh7w0000gn/T/tmp.CwuKdZeeKj/Applications/Vorssaint (Developer).app
▸ Installing into /var/folders/wl/z8733y815nzg28yy0_1_lh7w0000gn/T/tmp.CwuKdZeeKj/Applications…
  (legacy Vorss.app removed)
  (legacy Vorssaint Utils.app removed)
✓ Installed: /var/folders/wl/z8733y815nzg28yy0_1_lh7w0000gn/T/tmp.CwuKdZeeKj/Applications/Vorssaint.app
DEVELOPER INSTALL ISOLATION TESTS OK
```

```text
▸ Generating app icon…
iconset written to build/AppIcon.iconset
▸ Compiling adaptive icon catalog…
▸ Assembling and signing bundle…
  stamped dev build: 8a238f56
  signing with legacy self-signed identity: Vorssaint Utils Signing
/var/folders/wl/z8733y815nzg28yy0_1_lh7w0000gn/T/tmp.s5360IgNga/Vorssaint (Developer).app/Contents/Library/LaunchServices/com.vorssaint.utils.dev.fan-control: replacing existing signature
/var/folders/wl/z8733y815nzg28yy0_1_lh7w0000gn/T/tmp.s5360IgNga/Vorssaint (Developer).app/Contents/Frameworks/libVorssaintNowPlaying.dylib: replacing existing signature
/var/folders/wl/z8733y815nzg28yy0_1_lh7w0000gn/T/tmp.s5360IgNga/Vorssaint (Developer).app: replacing existing signature
✓ Bundle ready: build/stage.noindex/Vorssaint (Developer).app
```

In the full run, four suites account for the agent and notch surface:
`agents: OK (2599 checks, 40.91s)`, `notch: OK (67933 checks, 40.14s)`,
`agent-keys: OK (125 checks, 0.01s)` and `harness: OK (401 checks, 0.08s)`,
across 55 suites and 123796 checks in total.

### The known notch failure

The `NotchLevelTrackingTests` horizontal-click checks are known to fail on base
`545f69b2`: the merge brief records 9 failures out of 67933 there, and the
`dev/d1-jcode-harness-reader` trailer records four click failures reproduced on
that same base. They did not reproduce on the merged tree. The standalone notch
suite passed 67933 of 67933 checks and the full suite passed 123796 of 123796,
so this run carries no exclusion and nothing was chased. The base evidence above
is quoted from those two records; it was not re-measured here.

The only diagnostics are three pre-existing unused-result warnings, in
`BrightnessService.swift` at 2956 and 3001 and `AppUninstaller.swift` at 303,
all in files neither merged branch touches.

## Tailnet binding and peer identity (E1)

Branch `dev/e1-tailnet`, base `d9aacfcf`, by jcode. The worktree was
`C:\Users\koosh\Agents\worktrees\vorssaint-utils\e1`; nothing was built on
Windows and `build/` was removed from C: after the generator run.

### Windows checks

```sh
python -X utf8 Tests/generate_sources.py
```

exits 0 and writes 216 files to `build/generated-tests/`, proving the
declaration/indentation contract for every sliced method still resolves. The
plain `python Tests/generate_sources.py` fails on this host with a cp1252
`UnicodeDecodeError` inside the script's own `read_text()` call; that is a
pre-existing Windows encoding limitation, not a tree problem, and UTF-8 mode
avoids it.

A PowerShell check script at `E:\koosh\Agents\scratch\e1\windows-checks.ps1`
runs 25 structural assertions over the new files: the five unavailable states
are named, the bind resolver refuses `0.0.0.0`, `::`, `*` and an empty request,
no wildcard is ever returned as a host, no `/usr/bin` path is embedded (the
repository existence check rejects one), the support file is in `TEST_SOURCES`
once, the network suite registers the checks once, and the fixtures cover the
required states. Result: 25 PASS, `fails=0`.

### macOS

One batched, detached run per cycle on `kooshas-laptop` (macOS 27.3), inside
`~/Agents/worktrees/vorssaint-utils/e1`, under the shared
`mac-test.lock`. Three cycles were spent, each one documented here because the
first two failed on this branch's own checks:

1. `e41ea061`: network failed 1 of 253. A peer record with empty `ID`, host and
   DNS fields was expected to be malformed; the `Peer` map key is a node
   identity, so the expectation was wrong.
2. `6afdf01e`: network failed 1 of 254 on the new key-only check (the fixture
   omitted `Online`, so the peer was correctly reported offline), and the full
   suite failed 4 of 123873: that fixture, the two known
   `NotchLevelTrackingTests` clicks, and `RepositoryFeatureTests` rejecting an
   embedded `/usr/bin/tailscale` path that does not exist. The `--dev` build
   passed.
3. `c0316be3`, the last code commit, ran all three suites green. Only
   documentation commits follow it, and none touches source.

```sh
VORSSAINT_SKIP_DEVELOPER_ID=1 ./build.sh --test-suite=network

## D2 herdr pane source (HC backend)

Two commits on `dev/d2-hc-pane-source`, applied on the Windows host by jcode
(D2 track). The desktop host runs HC, not the 0.9.x generation the ledger row
names, so the reader targets `herdr-core` 0.1.21 behind a transport-agnostic
seam; the 0.9.x socket contract is deliberately not implemented.
`5b675bdb` adds the seam, the HC backend and its checks; `18907937` discards
one probe result that is deliberately unused.

### Windows

```sh
PYTHONUTF8=1 python Tests/generate_sources.py
py -3 E:\koosh\Agents\scratch\d2hc\structural_check.py
```

The generator exits 0 and `build/generated-tests/` was removed from C:
afterwards. The structural script prints `CHECKS OK (27)` and exits 0. It
asserts that the reader names no screen surface, builds exactly one command
(`hc server status`), never reads `HERDR_ENV` or `HERDR_SOCKET_PATH`, keeps pane
rows out of the turn, spend and trend types, and that both fixtures are valid
JSON with the states the decoder is tested against.

### Batched macOS run

One build run over one ssh invocation, against a detached worktree of
`origin/dev/d2-hc-pane-source` at `18907937` created from the clone at
`/Users/kooshapari/CodeProjects/vorssaint-utils`, by jcode (D2 track) on macOS
27.3. The main clone stayed on `dev/maccy-clipboard-parity`; the worktree was
removed afterwards and the tree was clean at `18907937`. An earlier attempt
stopped at the fetch because the Mac names its only remote `origin`.

```sh
VORSSAINT_SKIP_DEVELOPER_ID=1 ./build.sh --test-suite=agents

VORSSAINT_SKIP_DEVELOPER_ID=1 ./build.sh --test
VORSSAINT_SKIP_DEVELOPER_ID=1 ./build.sh --dev
```

Exit codes: `network=0 full=0 dev=0`. Verbatim tails:

```text
▸ Building & running tests against MacOSX26.sdk…
network: OK (254 checks, 1.26s)
TESTS OK (254 checks)
```

```text
network: OK (254 checks, 1.27s)
app-updates: OK (356 checks, 0.07s)
localization: OK (9072 checks, 0.40s)
cleaner: OK (71 checks, 0.25s)
uninstaller: OK (195 checks, 0.77s)
force-quit: OK (21 checks, 0.23s)
launcher: OK (103 checks, 0.02s)
dock-autohide: OK (181 checks, 13.36s)
spaces-order: OK (120 checks, 0.59s)
switcher: OK (1582 checks, 9.93s)
keep-awake: OK (189 checks, 0.02s)
wallpaper: OK (94 checks, 0.01s)
emoji: OK (225 checks, 0.06s)
TESTS OK (123873 checks)
PREFERENCE CLEANUP TESTS OK
UNINSTALL SPACES TESTS OK
...
DEVELOPER INSTALL ISOLATION TESTS OK
```

```text
  stamped dev build: c0316be36
  signing with legacy self-signed identity: Vorssaint Utils Signing
...
✓ Bundle ready: build/stage.noindex/Vorssaint (Developer).app
```

The known `NotchLevelTrackingTests` horizontal-click checks did not reproduce
on this tree; the full suite carried no exclusion.

### Check-count delta

`TailnetTests` executes 75 checks on a passing run (52 literal `suite.expect`
sites, plus loops over the 10 malformed payloads, 3 stopped states and 2
unauthenticated states). The `network` group therefore moves from 179 to 254,
and the full suite from 123798 to 123873. The 254 and 123873 figures are
measured on `c0316be3`; the two base figures are arithmetic from the 75 counted
executions, not a run on base.

### Real tailnet observed

The probe was also run by hand against the live node, read-only:

- `tailscale version` 1.105.361, `BackendState: Running`
- self `kooshas-laptop.tail2b570.ts.net.` with `100.112.14.98` and
  `fd7a:115c:a1e0::fa32:e62`
- 14 peers, 4 online. Five distinct `instinct-sandbox-keyrun-*` nodes share the
  `HostName` `instinct-sandbox-keyrun`, and the iPhone peer reports
  `HostName: localhost`.

That last point is a real limit of host-name identity: it is accepted for
compatibility, but only a DNS name or node ID is unique here, so callers should
expect the DNS name or the node ID. This is recorded as a decision for the
operator rather than silently narrowed in code.

Exit codes: `agents=0 full=0 dev=0`. Verbatim tails:

```text
agents: OK (2720 checks, 48.58s)
TESTS OK (2720 checks)
```

```text
notch: OK (67933 checks, 40.52s)
switcher-model: OK (2127 checks, 0.33s)
agents: OK (2720 checks, 45.14s)
features: OK (1422 checks, 0.12s)
shortcut-clearing: OK (71 checks, 0.30s)
utilities: OK (553 checks, 5.50s)
settings: OK (1157 checks, 15.23s)
feature-hub-layout: OK (178 checks, 29.17s)
TESTS OK (123918 checks)
PREFERENCE CLEANUP TESTS OK
UNINSTALL SPACES TESTS OK
DEVELOPER INSTALL ISOLATION TESTS OK
```

```text
  stamped dev build: 18907937
  signing with legacy self-signed identity: Vorssaint Utils Signing
  ...
✓ Bundle ready: build/stage.noindex/Vorssaint (Developer).app
```

The agents suite rises from 2599 to 2720, so the new suite executes 121 checks,
including a real bounded subprocess and a real listening socket. The full suite
rises from 123796 to 123918; 121 of the 122 are the new suite and one is
`PreferenceNamespaceTests`, which reads one more compiled test file. No
`NotchLevelTrackingTests` horizontal-click failure appeared at this tip; the
known base failures are unchanged and were not chased.

## Merge of `dev/d2-hc-pane-source` into `dev/maccy-clipboard-parity`

Merge commit `df491e0a` on the Windows host by jcode (D2 track), plain merge, no
squash and no rebase. `dev/d2-hc-pane-source` was cut from `e0cba445`; the
target had moved four commits ahead (`8e49b4f8`, `a9c817bf`, `d10f79bf`,
`d9aacfcf`) touching only `docs/ROADMAP_LEDGER.md`, `docs/D2_HERDR_CONTRACT.md`
and `.gitignore`. The merge reported no conflicts: the branch's own doc edit is
in `docs/VALIDATION_LOG.md`, a file the target side had not touched since the
base, and its `Sources/`, `Tests/` and `build.sh` changes are additions to files
the target side left alone. Both documentation entries are therefore present
without hand resolution, and nothing stale was reintroduced: the only remaining
`123,642` and `77`-check mentions are the historical corrections already in the
log and the D2 addendum that quotes and corrects them.

### Staging

No push happened before validation, so the merge commit was carried to the Mac
as a git bundle (`^d9aacfcf ^9947cead HEAD`, 101,834,025 bytes) written under
`E:\koosh\Agents\scratch\d2merge\`, transferred by piping it through the Git
OpenSSH wrapper, verified with `git bundle verify`, fetched, and checked out as a
detached worktree at `/private/tmp/vorssaint-d2merge`. The Mac clone stayed on
`dev/maccy-clipboard-parity`.

### Batched macOS run

One ssh invocation, macOS 27.3, four steps in order, output captured to
`/tmp/d2merge-run.log`:

```sh
VORSSAINT_SKIP_DEVELOPER_ID=1 ./build.sh --test-suite=agents
VORSSAINT_SKIP_DEVELOPER_ID=1 ./build.sh --test-suite=notch
VORSSAINT_SKIP_DEVELOPER_ID=1 ./build.sh --test
VORSSAINT_SKIP_DEVELOPER_ID=1 ./build.sh --dev
```

Exit codes: `agents=0 notch=1 full=0 dev=0`. Verbatim agents tail:

```text
agents: OK (2720 checks, 48.65s)
TESTS OK (2720 checks)
```

The standalone notch suite failed two checks on the first attempt:

```text
notch: FAILED (67933 checks, 41.77s)
TESTS FAILED (2 of 67933):
  - Tests/NotchLevelTrackingTests.swift:251: vertical level 0...1.0: an independent mouse wheel tick still adjusts the volume during the lift gap: got 0.0, expected 0.05 within 0.0001
  - Tests/NotchLevelTrackingTests.swift:251: vertical level 0...2.0: an independent mouse wheel tick still adjusts the volume during the lift gap: got 0.0, expected 0.1 within 0.0001
```

Both are in the known `NotchLevelTrackingTests` synthesized-event family; they are
the vertical wheel-tick variant of the horizontal-click checks already recorded as
failing on base `545f69b2`, and neither touches the HC pane source. The same suite
passed inside the full run that followed (below), and one repeat of the suite alone
passed with the same check count, so both are attributed to that flakiness rather
than to this merge:

```text
notch: OK (67933 checks, 41.65s)
TESTS OK (67933 checks)
```

Full suite tail, including the notch suite passing at 67933 checks:

```text
notch: OK (67933 checks, 40.00s)
switcher-model: OK (2127 checks, 0.32s)
agents: OK (2720 checks, 42.41s)
features: OK (1422 checks, 0.16s)
...
emoji: OK (225 checks, 0.05s)
TESTS OK (123918 checks)
PREFERENCE CLEANUP TESTS OK
UNINSTALL SPACES TESTS OK
DEVELOPER INSTALL ISOLATION TESTS OK
```

Dev bundle tail:

```text
  stamped dev build: df491e0ac
  signing with legacy self-signed identity: Vorssaint Utils Signing
  ...
✓ Bundle ready: build/stage.noindex/Vorssaint (Developer).app
```

The merged tree therefore holds the two candidate figures stated in the D2 row:
2720 agent checks and 123918 on the full suite, with the notch suite unchanged at
67933.


## 2026-11-28 — D4/D5 agent session preview and spend breakdown

Same procedure as above: `bash Tests/LinuxSubsetCheck.sh` on nixos for the structural
pass, then one batched `./build.sh --test` on kooshas-laptop for the gate.

Linux subset, full tail:

```text
agent-session-catalog: OK (13 checks, 0.03s)
agent-transcript: OK (17 checks, 2.06s)
agent-session-source-rules: OK (4 checks, 0.00s)
agent-insights-wiring: OK (9 checks, 0.00s)
SUBSET OK (220 checks) — not the release gate
```

The subset was 177 checks before this change.

Mac gate on `kooshas-laptop` (arm64), `./build.sh --test`, one run, no retry:

```text
  agent-session-source-rules: OK (4 checks, 0.00s)
  agent-insights-wiring: OK (9 checks, 0.00s)
agent-sessions: OK (43 checks, 0.99s)
TESTS OK (124596 checks)
PREFERENCE CLEANUP TESTS OK
UNINSTALL SPACES TESTS OK
DEVELOPER INSTALL ISOLATION TESTS OK
```

Zero lines containing `FAIL` in the whole log. The full suite was 123918 checks on
`df491e0a`, so this is +678 checks and the new work is 43 of them.

What the gate proves: the catalog and transcript read what their tests say they read,
and the two sections are mounted in the agents page with the transcript view unable to
be handed a session the page did not choose. What it does not prove: anything about how
the page looks. Nothing was rendered, and no window was opened.

## 2026-11-28 — P86-4 option B: the closed-lid flag through the signed helper

Tree `0acb12fb` on `kooshas-laptop`, one run of `./build.sh --test`, read from
`/tmp/gate-p86-4b.log`:

```
  sleep-disable-arguments: OK (3 checks, 0.00s)
  sleep-disable-wiring: OK (14 checks, 0.00s)
privileged-sleep: OK (17 checks, 0.00s)
TESTS OK (124614 checks)
PREFERENCE CLEANUP TESTS OK
UNINSTALL SPACES TESTS OK
DEVELOPER INSTALL ISOLATION TESTS OK
```

Zero lines containing `FAIL` in the whole log. The previous gate on `d1e6f1dc` was
124596 checks, so this is +18, and every one of the 18 is accounted for:

| Delta | Source | Why |
|---|---|---|
| +17 | `privileged-sleep` | the new group: 3 argument checks, 14 wiring checks, the same 17 the Linux subset reports |
| +1 | `harness` 419 → 420 | `PreferenceNamespaceTests` adds one check per discovered `Tests/*.swift`, and one test file was added |

What the gate proves: the helper's new operation compiles into the helper binary, the
app's XPC client compiles against it, and `Sudoers` resolves the client in the test
build as well as the app build. What it does not prove: that the helper *answers*. That
needs the daemon registered and approved on this Mac, and it was not exercised — no
`pmset` was run, no preference was toggled, and the fan-control service was not started.
`docs/P86-4-B-PRIVILEGED-HELPER.md` states this as unproven rather than done.

## 2026-11-28 — the test gate does not compile the app, and HEAD did not compile

Found while producing the F1 artifact, not by a test. `./build.sh` (the full app build) on
`kooshas-laptop` at `03a9463f`:

```
Sources/Vorssaint/UI/Settings/NotchAgentsInsights.swift:225:86: error:
  type 'HierarchicalShapeStyle' has no member 'accentColor'
EXIT=1
```

The line was `.foregroundStyle(line.isUser ? .secondary : .accentColor)`, added by `6afcc8a5`.
A ternary needs both branches to be one type, and there the expected type is a
`ShapeStyle`, which has `secondary` but no `accentColor`. `6d9aaeac` names `Color.` on both
branches, which keeps the rendering and compiles.

**The gate passed the whole time.** `TESTS OK (124614 checks)` at `0acb12fb` is a true
statement about `TEST_SOURCES`, and `TEST_SOURCES` is an explicit list (`build.sh:269`) that
contains no `UI/` file this screen compiles, so the test build never saw the error. The
`--test` branch runs `generate_sources.py`, compiles that list with `swiftc`, runs the
binaries, and `exit`s at `build.sh:669`; the app compile starts at `build.sh:672`.

| Claim | What actually proves it |
|---|---|
| the test suite passes | `./build.sh --test` |
| the app compiles | `./build.sh`, `▸ Compiling (release) against MacOSX26.sdk…` with no `error:` |
| the bundle is signed and packaged | `./build.sh` to `✓ Bundle ready`, then `Tools/make-dmg.sh` |

The release compile of the fixed tree is the evidence for `6d9aaeac`: `grep -c "error:"` on
`/tmp/f1-build.log` is `0`, and the build then failed only at signing (`errSecInternalComponent`,
below), which is after compilation. So the compile fix is verified by a real app compile, and
the app-target compile is now a step that has to be run rather than assumed.

### The package chain runs, to the notary boundary

`VORSSAINT_SKIP_DEVELOPER_ID=1 ./build.sh` on the same tree, then `Tools/make-dmg.sh`:

```
✓ Bundle ready: build/stage/Vorssaint.app
✓ DMG ready: dist/Vorssaint-3.4.4.dmg

build/stage/Vorssaint.app: valid on disk
build/stage/Vorssaint.app: satisfies its Designated Requirement
Authority=Vorssaint Utils Signing   TeamIdentifier=not set   flags=0x0(none)
spctl -a -vvv -t exec build/stage/Vorssaint.app  ->  rejected
dist/Vorssaint-3.4.4.dmg   53464 blocks   sha256 485c50a31eece64c…
```

Signed with the local identity, so no hardened runtime and no Team ID: `spctl` rejecting it is
the correct answer, not a defect. What this proves is that compile → bundle → nested helpers →
icon → styled DMG all work and the artifact chain has no gap of its own. What it does not prove
is anything about notarisation.

Without `VORSSAINT_SKIP_DEVELOPER_ID=1` the same build fails at signing, three retries:

```
Developer ID signing failed; retrying (3/3)
.../Vorssaint.app/Contents/Library/LaunchServices/com.vorssaint.utils.fan-control: errSecInternalComponent
EXIT=1
```

`build.sh:70-78` already documents why: a build outside the GUI session cannot use the login
keychain's Developer ID key. That makes the Developer ID build a step only the operator can run,
by running `./build.sh` in a Terminal window on the Mac.

### Notary credentials: searched, not assumed

Enumerated on the Mac without reading any value: no `NOTARY_*`, `APPLE_ID` or `ASC_*` in the
environment; no `AuthKey_*.p8` in `~/.appstoreconnect/private_keys`, `~/private_keys`,
`~/.private_keys`, `~/Downloads` or `~/Documents`; `xcrun notarytool` 1.1.0 present but no
stored profile (`security find-generic-password` absent for `vorssaint`, `AC_PASSWORD`,
`notary`, `vorssaint-notary`); `security find-identity` does show the Developer ID Application
identity. Infisical is installed and logged in (`v0.44.15`, `kooshapari@gmail.com`), and its 10
cached project backups under `~/.infisical/secrets-backup/` contain **no** key whose name matches
`NOTARY`, `APPLE` or `ASC_`. So the three values are not on this Mac in any place an agent may
read, and `Tools/notarize.sh` will not run without all three.

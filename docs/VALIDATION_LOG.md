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


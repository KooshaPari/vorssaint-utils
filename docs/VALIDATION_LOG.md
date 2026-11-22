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
3. `c0316be3`, the delivered tip: all three green.

```sh
VORSSAINT_SKIP_DEVELOPER_ID=1 ./build.sh --test-suite=network
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


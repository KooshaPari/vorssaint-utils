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

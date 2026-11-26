# NixOS Readiness Note

This file is the lane's answer to the "move fully to NixOS under reduced storage & compute (preferred)" prompt.

## What was tried

- Cloned `KooshaPari/vorssaint-utils` from GitHub onto `nixos` (no SMB on the path; `git clone` over HTTPS).
- Found a built Swift 6.4 toolchain already in the nix store (`/nix/store/knsk3b46gbprwwi43zna5gf415i752yb-swift-6.4.0`).
- Added swiftpm (`/nix/store/nq5rw2s80divkzrb5sv6q5zrkigvnwdi-swiftpm-6.4.0`) and binutils (`ar`) to PATH, then ran `swift build` on `dev/maccy-clipboard-parity`.
- Build failed immediately: `no such module 'AppKit'`. SwiftPM resolved the target as `x86_64-unknown-linux-gnu` (linux build) and cannot find Apple frameworks.

## Verdict

- **Vorssaint cannot be built on nixOS.** It is a macOS-only Swift app (`platforms: [.macOS(.v14)]`, imports `AppKit`, `CoreAudio`, `HIDEventSystem`, `VMStatisticsCompat`). There is no cross-build path on nixOS without the macOS SDK and Xcode toolchain, and nixOS has no Apple SDK. Verified, not inferred.
- **nixOS is still useful for this lane, but only as a git/coordination node**, not as a build node: clone/pull/branch/push, ledger edits, dispatching work, reading diffs. The actual build/test/macOS run stays on the Mac (`kooshas-laptop`, 100.112.14.98) over ssh.
- **Recommended posture:** keep the repo on nixOS for fast git operations and agent dispatch (avoids SMB latency), but treat the Mac as the sole release build/verify target. Do not attempt to move Vorssaint's build to nixOS; that path is blocked by the Apple SDK, not by storage or compute.
- **Storage/compute on nixOS:** 16 cores, 31 GB RAM, ~140 GB free on `/` at the time of this note (273 GB used of 434 GB). Adequate for git + agent work; not a constraint for this lane's real work.

## Correction (2026-11-26): the app cannot build here, but a subset can and does

The verdict above is about the **app**, and it holds. It was too broad as a
statement about testing, and that breadth cost real time: four failures in the
SMB and compute-mesh suites were discovered only on the Mac, when both suites are
Foundation-only and had never needed to be.

`Tests/LinuxSubsetCheck.sh` compiles those suites here and runs them:

```
mesh-sources: OK (12 checks)     smb-configuration: OK (11 checks)
mesh-ssh: OK (7 checks)          smb-listing: OK (10 checks)
mesh-merge: OK (11 checks)       smb-mount: OK (21 checks)
                                 smb-unmount: OK (7 checks)
SUBSET OK (79 checks) — not the release gate
```

Rules that keep this honest:

- It is **not** the release gate. Only `./build.sh test` on macOS compiles every
  suite; a green subset means the listed suites are green and nothing else.
- A suite qualifies only when its production files and the test itself import
  nothing Darwin-only. `import Security` disqualifies a file, which is why the
  secret store's Keychain half is excluded and its in-memory half is extracted
  mechanically from the same source rather than copied by hand.
- Adding a suite to `SUITES`/`SOURCES` in the script is a deliberate act, taken
  when a suite's logic is worth iterating on without a Mac round trip.


## Toolchain note for future agents

- Swift 6.4 + swiftpm 6.4 + binutils are available in the nix store but only produce Linux binaries. If a future task needs a macOS binary, run it on `kooshas-laptop` via ssh, not here.
- Do not commit the `.build/` directory created during the failed probe; it was removed. `git status` is clean.

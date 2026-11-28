# P86-4 option B: the closed-lid preference through the privileged helper

The closed-lid toggle is the one setting that needs root, and it gets it today by
writing a sudoers rule from an admin prompt (`Sudoers.install`). Option B, chosen by
the operator on 2026-11-27, is to do it through the signed helper that already exists
instead of widening sudo.

## What is already true, measured on kooshas-laptop 2026-11-27

Not planned, measured:

* A Developer ID Application identity is present
  (`Developer ID Application: Koosha Paridehpour (GCT2BN8WLL)`), so the helper can be
  signed with a stable team identity rather than ad-hoc.
* A privileged helper already ships. `build.sh` compiles `Sources/FanControlHelper/main.swift`
  plus the fan-control and SMC sources into `Contents/Library/LaunchServices/com.vorssaint.utils.fan-control`,
  signs it with `--identifier` and hardened runtime, and stages
  `com.vorssaint.utils.fan-control.plist` into `Contents/Library/LaunchDaemons`. The
  app registers it with `SMAppService.daemon(plistName:)` (`FanControlService.swift:43`).
* That helper is an `NSXPCListener` on a mach service, and it sets a connection
  code-signing requirement (`listener.setConnectionCodeSigningRequirement`,
  `main.swift:602`), so the sender is already authenticated rather than trusted by name.
* The helper has no `pmset` call today and no generic "run this" method. Its surface is
  five closed operations: `status`, `startMaximumCooling`, `applyConfiguration`,
  `heartbeat`, `restoreAutomatic`.

## Why the sudoers rule exists at all

`pmset -a disablesleep` is the only supported way to keep a laptop awake with the lid
shut, and it requires root. `Sudoers.install` writes a rule so the app can call it
without a prompt each time. That is a permanent privilege grant to a path, and it is
what option B replaces.

## The change

1. One new operation on the existing helper, not a new daemon:
   `func setDisablesleep(_ enabled: Bool, withReply:)`. It runs
   `/usr/bin/pmset -a disablesleep <0|1>` and returns the exit status. No shell, no
   argument built from caller input beyond the boolean, absolute path.
2. `KeepAwakeManager` tries the helper first. Only if the helper is unreachable does it
   fall back to the sudoers path, so an unsigned development build still works and a
   user who already granted the rule is not broken.
3. The sudoers rule becomes removable: `SelfUninstall` already treats it as one of the
   things to clean up, and this makes the app work after it is removed.

## What must not happen

* No generic command method on the helper. A root service that runs a caller-supplied
  string has removed the reason to trust it.
* No change to the code-signing requirement. The sender check is the security boundary;
  the new operation inherits it rather than re-implementing one.
* No new entitlements on the helper beyond what the fan path already needs.

## Verification plan, once written

* Structural: the helper's protocol gains exactly one method; no `NSTask`/`Process` call
  in the helper takes a non-constant argument (assertable from the source, the same way
  the D2 reader asserts its one command).
* Injection: a fake helper that answers success, one that answers failure and one that
  never answers — the manager must set the preference, refuse to set it, and time out
  into the sudoers fallback respectively.
* Live, one Mac run: toggle closed-lid on, confirm `pmset -g | grep disablesleep` reads
  1, toggle off, confirm 0, and confirm `/etc/sudoers.d` has no vorssaint entry.

The live step is the only one that proves the daemon registration actually works on a
signed build, and it needs a human at the machine. Everything before it can be written
without one.

## State

Not started. The helper surface, the signing identity and the existing registration were
verified; the code above is a design, not a claim about the tree.

## What was written (2026-11-28)

The design above is now code, in two commits: `71f130f5` (the operation and its client)
and `65e3ad37` (the wiring and the build).

| Piece | Where |
|---|---|
| protocol method | `Sources/Vorssaint/Services/FanControl/FanControlXPC.swift` |
| helper side | `Sources/FanControlHelper/main.swift`, `private enum SleepDisable` |
| app side | `Sources/Vorssaint/Services/FanControl/SleepDisableControl.swift` |
| route | `Sudoers.pmsetDisableSleepOnQueue` and `restoreSleepWithAuthorization`, `Sources/Vorssaint/Services/ShellSupport.swift` |
| constant arguments | `SudoersSupport.pmsetArguments(disablesleep:)` |
| checks | `Tests/PrivilegedSleepTests.swift` — `sleep-disable-arguments`, `sleep-disable-wiring` |

Three decisions the design left open, settled while writing it:

1. **The client is deliberately tri-state.** `SleepDisableControl.apply` returns
   `Bool?`, and `nil` means only "the helper did not answer". That is what makes the
   fallback honest: an unsigned development build, or a user who has not approved the
   helper in Login Items, still gets the sudoers path rather than a silent failure.
2. **The reply is answer-once.** The XPC error handler and the reply block can both
   fire; the first one wins, so a late error cannot overwrite a real answer and a late
   answer cannot resurrect a failed call.
3. **The prompting path got the helper too.** `restoreSleepWithAuthorization` exists for
   users whose rule is absent and is the path that shows a password dialog. It now asks
   the helper before showing that dialog, so the improvement is not limited to the
   quiet path.

Proven by the gate: the macOS build. One run on `0acb12fb` reported
`TESTS OK (124614 checks)` with zero `FAIL` and `privileged-sleep: OK (17 checks)`, so
the operation compiles into the helper binary and the client links in both the app and
test builds. The Linux subset reports `SUBSET OK (237 checks)` for the constant
arguments and the source shape.

Not proven: that the helper *answers*. Nothing in that run touched `pmset`, the
preference or the fan-control service, and the daemon has to be registered and approved
in Login Items before an operation reaches it. So the fallback path is what a fresh
user will actually get until the live toggle is exercised on a signed build with a
human at the machine.

## Open question for the operator

Approving the helper's launchd service is a one-time user action in System Settings >
General > Login Items > Allow in the Background. The app registers it on first fan
control use (`SMAppService.daemon(plistName:)`), but the user has to approve it before
any operation reaches the helper. Whether the closed-lid toggle should *also* register
the helper on first use — so the approval prompt appears when the user is already in the
app, not later when they are closing the lid — is a product decision, not a technical
one. It is not registered from the closed-lid path today.

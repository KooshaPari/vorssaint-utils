# P86-2 and P86-4 — private HID SPI and a standing passwordless-root grant

Status: design note, 2026-11-26. Source-derived; nothing here was observed at runtime on a Mac.
Companion to the P86-2 and P86-4 entries in `docs/ROADMAP_LEDGER.md`.

---

## P86-2 — `IOHIDEventSystemClient` is private API, and there is no public equivalent

### What the tree does

`Sources/HIDEventSystem/include/HIDEventSystem.h:1-4` is a hand-written umbrella header over two
public IOKit headers and two private ones:

```
#include <IOKit/hid/IOHIDUsageTables.h>
#include <IOKit/hid/IOHIDManager.h>
#include <IOKit/hidsystem/IOHIDEventSystemClient.h>   // private
#include <IOKit/hidsystem/IOHIDServiceClient.h>       // private
```

It is wired in as a header-only module (`build.sh:216`, `HID_EVENT_SYSTEM_FLAGS=(-I Sources/HIDEventSystem)`),
so the app links the private symbols directly rather than going through `dlsym`. Three call sites:

| Site | Call |
|---|---|
| `Services/MouseAcceleration/MouseAccelerationService.swift:64` | `IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault)` |
| `.../MouseAccelerationService.swift:170` | same, on the recovery path |
| `.../MouseAccelerationRecovery.swift:14` | same, restoring after a crash |

The feature is per-device linear mouse mode: the app sets an acceleration property on the individual
HID service rather than the system-wide `com.apple.mouse.scaling` preference, so one mouse can be
linear while a trackpad is not.

### What is actually at risk

1. **Symbol and struct drift.** The client is created by a private constructor and its services are
   private types. A macOS release may rename, re-sign or re-shape any of it. The failure is a missing
   symbol at launch (the dynamic linker aborts the process) rather than a nil return — the worst
   shape of failure, because it is a launch crash, not a degraded feature. `MouseAccelerationRecovery`
   exists precisely because this code can leave a device modified; it does not protect against the
   client failing to exist.
2. **App Store: already moot.** Private API is Guideline 2.5.1 and is an automatic rejection, but the
   product is already outside the store on Accessibility taps and a root daemon. So the store cost of
   this item is zero *given the current target*; it stays a real cost if the target ever changes.
3. **No capability manifest.** Reading and writing HID service properties needs no declared
   entitlement, so nothing in `Resources/Vorssaint.entitlements` records that the app talks to HID
   services. Under hardened runtime that works, but it is invisible to a reviewer. `docs/PERMISSIONS.md`
   names the scroll inverter and trackpad gestures (lines 29-31) and has no entry for per-device mouse
   acceleration, so the user-facing manifest has the same hole.

### Options

**A. Keep it, and make the failure non-fatal.** Load the private symbols via `dlopen`/`dlsym` on
`/System/Library/Frameworks/IOKit.framework`, as `NowPlayingSelection.swift:30` already does for
MediaRemote, and treat a missing symbol as "linear mouse mode unavailable" instead of a launch crash.
The surface is bounded: six functions and two opaque types are actually used —
`IOHIDEventSystemClientCreateSimpleClient`, `IOHIDEventSystemClientCopyServices`,
`IOHIDServiceClientCopyProperty`, `IOHIDServiceClientSetProperty`, `IOHIDServiceClientConformsTo`,
`IOHIDServiceClientGetRegistryID`, plus `IOHIDEventSystemClient` and `IOHIDServiceClient`. Everything
else in those two files is public `IOHIDManager`/`IODKit` API. So this is a shim plus a call-site
rewrite, not a redesign — but it is not a one-liner either, and it cannot be behaviourally verified
without a Mac. This does not make the API public; it makes the app survive its removal.

**B. Replace with the system-wide preference.** `defaults write -g com.apple.mouse.scaling` plus a
`killall`/re-login is public and stable, at the cost of the per-device distinction that is the
feature. Users with a trackpad and a mouse cannot have both.

**C. Drop per-device linear mode.** Smallest tree; the feature disappears.

### Recommendation

**A now** — it is small, cannot regress a working path, and removes a launch crash from the list of
ways a macOS update can break the app. **B is a product question**, not a defect fix: it trades the
per-device behaviour for public API, and only the operator can decide whether that trade is worth it.
C only if B is refused and the maintenance burden is judged not worth carrying.

**Resolved 2026-11-26:** option A shipped as `2560553e`. What landed, what the gate said and what is
still unproven are in `docs/P86-2-HID-SPI-SHIM.md`. This note stays as the design record; the two
disagree nowhere and the implementation note supersedes nothing here.

### Not established

Whether the private symbols still exist and behave identically on the OS versions this app targets
(no Mac runtime probe). Whether `IOHIDServiceClientSetProperty` on the acceleration key is still the
mechanism (the code is read, not observed).

---

## P86-4 — the NOPASSWD rule is correctly scoped, and still a standing grant

### What the tree does

The rule is exact, one uid, two commands (`Services/SudoersSupport.swift:17-19`):

```
#<uid> ALL=(root) NOPASSWD: /usr/bin/pmset disablesleep 1, /usr/bin/pmset disablesleep 0
```

Installed at `/etc/sudoers.d/vorssaint-clamshell`, mode `0440`
(`Services/ShellSupport.swift:126-186`): written via an admin prompt, validated with
`/usr/sbin/visudo -c -f` and rolled back if validation fails, with three legacy filenames removed in
the same prompt so a rename does not cost the user a second password.

Three deliberate choices are worth recording because they are all correct:

- **Granted by uid, not username** (`#<uid>`), because a short name on an SSO-enrolled Mac can be a
  full email address, which would need sanitizing against both sudoers and shell metacharacters. A
  uid interpolates as bare digits. Comment at `SudoersSupport.swift:11-16`.
- **The grant is proven by using it, not by listing it** (`isConfigured()` runs the real `pmset`
  through `sudo -n`, `ShellSupport.swift:146-153`). `sudo -l` was observed reporting the rule as
  ready while the real call still prompted — issue #269 in the comment.
- **Argument-exact commands.** Both commands carry their argument (`disablesleep 1`, `disablesleep
  0`), so the rule does not authorize `pmset` with arbitrary arguments. `/usr/bin/pmset` at an
  absolute path, so no PATH substitution.

### What is actually at risk

The residual is the definition of `NOPASSWD` itself: **any process running as that uid can toggle
`SleepDisabled` without a password.** The blast radius is bounded (no arbitrary root command, no
shell, no editor), but the consequences are not nothing — a compromised process running as the user
can hold a Mac awake indefinitely (battery drain, defeating a screen-lock sleep policy), or force
sleep. There is no way to authorize "only when the user clicked our toggle" with sudoers; the grant
is per-uid by construction.

Secondary, smaller:

- The rule outlives the feature if the app is deleted without uninstall (`SelfUninstall.swift:227-236`
  restores `disablesleep 0`, and `Sudoers.ruleFilesPresent` exists so an uninstall prompt can clean
  up a rule that stopped working). So the *code* path is covered; a Finder-drag-to-Trash deletion is
  not, and cannot be — nothing runs.
- `remove()` deletes the file without a `visudo` re-check. Deleting a file cannot make the remaining
  sudoers invalid, so this is fine; it is noted only so a future reader does not "fix" it.

### The disclosure already exists; it is imprecise, not absent

`docs/PERMISSIONS.md:139-145` already tells the user that closed-lid mode can install "a tightly
scoped `sudoers` rule that allows only that single command", that saying no keeps the feature working
with a password each time, and that the rule goes away on uninstall. That is a real disclosure and it
is the paragraph this note would otherwise have asked for. Three things are still wrong with it:

1. **It does not say the grant is passwordless for every process of that uid.** "Allows only that
   single command" is true and reassuring; "and does not ask for a password, whoever calls it" is the
   part that has security weight. Both halves belong in the same sentence.
2. **It does not print the rule.** The exact file path and the two authorized commands fit in one
   line and would let a user verify it themselves.
3. **"It goes away on its own when you uninstall" is only true for the app's own uninstaller.** A
   drag to the Trash leaves `/etc/sudoers.d/vorssaint-clamshell` in place, because nothing runs. That
   is not fixable in code; the sentence is what should be corrected, not the behaviour.

### Options

**A. Sharpen the existing disclosure (smallest, and it is a documentation defect).** Add the
passwordless-per-uid sentence, print the rule and its path, and state the Trash case honestly. Cost:
one paragraph in `docs/PERMISSIONS.md`. No code change.

**B. Move to a privileged helper** (`SMJobBless`-style launchd daemon with an XPC interface) so the
authorization is a one-time install with a signed, auditable helper rather than a sudoers file. This
removes the standing sudo grant entirely and is the correct long-run answer for a product that
already ships a root daemon. Costs: a signed helper target, an XPC protocol, IPC hardening, and a much
larger surface than one sudoers line — a project, not a fix.

**C. Ask for the admin password on every toggle.** Removes the standing grant, makes the feature
unusable in the way it is actually used (toggled from a menu, often many times a day).

### Recommendation

**A now**, unconditionally. **B is the correct end state** and should be scheduled deliberately rather
than smuggled in — the app already ships a root daemon, so the helper pattern is established rather
than novel. **C** is a regression.

### Not established

Whether the installed rule is present on any current machine (needs a Mac; `ls -l /etc/sudoers.d`
and `sudo -l -U $(id -u)`), and whether `pmset disablesleep` remains the accepted mechanism on the
target OS (the code path is read, not run).

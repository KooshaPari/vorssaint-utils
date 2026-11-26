# P86-2 — the private HID interface, resolved at launch instead of demanded at load

Status: implemented and gated, 2026-11-26. `2560553e`, gate `TESTS OK (124511 checks)`, 0 failure
markers, all three shell suites OK. Companion to the P86-2 entry in `docs/ROADMAP_LEDGER.md`.

## The fault this removes

Five production paths called six IOHIDEventSystem functions that Apple does not publish:

| Symbol | Used for |
|---|---|
| `IOHIDEventSystemClientCreateSimpleClient` | a client to read and write service properties |
| `IOHIDEventSystemClientCopyServices` | enumerate the connected devices |
| `IOHIDServiceClientGetRegistryID` | a stable identity per device |
| `IOHIDServiceClientConformsTo` | "is this a mouse / a keyboard" |
| `IOHIDServiceClientCopyProperty` | read a mapping, read the lock state |
| `IOHIDServiceClientSetProperty` | write an acceleration or a lock state |

They live in the SDK's private-adjacent headers (`<IOKit/hidsystem/…>`), which is why the tree
carries `Sources/HIDEventSystem` as a modulemap over those headers. A header is a compile-time
promise; the symbol is a runtime one. Linking them directly means a macOS update that drops a
symbol takes the app with it: dyld cannot bind the image, and the process never starts. No error
window, no log line a user would find.

Resolving them at launch turns that into a withdrawal. `isAvailable` is true only when all six
resolve, every wrapper returns nil otherwise, and the features that need the interface stand down.

## What was built

| File | Role |
|---|---|
| `Sources/Vorssaint/Services/HID/HIDEventSystemSymbols.swift` | the six names, the framework path, in one table |
| `Sources/Vorssaint/Services/HID/HIDEventSystemShim.swift` | `dlopen` + `dlsym` + six `@convention(c)` wrappers, `isAvailable`, `dlclose` in `deinit` |

Two decisions worth stating, because both are reversals of the obvious choice:

- **The symbol names are strings, not a vendored header.** A header would keep the compile-time
  link and only defer the failure. The strings are the point: they are exactly what Apple does not
  promise.
- **The two opaque types stay compile-time** (`IOHIDEventSystemClient`, `IOHIDServiceClient`). They
  are typedef'd in the same headers, and a missing typedef is a build failure no shim can rescue.
  Only a missing *symbol* is the failure that survives compilation, so only the symbols are dynamic.

Withdrawal is layered, so a Mac without the interface loses as little as possible:

- `MouseAccelerationService.start()` withdraws and clears its client rather than half-applying a
  mode it could not restore afterwards.
- `MouseAccelerationService.isRuntimeAvailable` is the shim's own answer, and `featureWanted`
  requires it, so the toggle goes away instead of offering something that cannot work.
- `MouseAccelerationRecovery` returns nil from every step, so a pending restore is left pending
  rather than reported as done.
- `SuperKeyService` holds the shim as a dependency (`private let hid`) and silently skips the
  corrective Caps Lock write.

## Evidence

- **The signatures were measured, not guessed.** `xcrun swiftc -typecheck -I Sources/HIDEventSystem`
  against the real headers gave the exact imported shapes, including the ones that surprise:
  `ConformsTo` returns `Int32` (not `Bool`) and `CopyProperty` returns `CFTypeRef?`.
- **The symbols resolve on this Mac today:** all six, via a `ctypes` `dlsym` probe of
  `/System/Library/Frameworks/IOKit.framework/IOKit`. So the shim reports `isAvailable == true`
  here and nothing changes for the user; the change is what happens when it stops being true.
- **RED, honestly partial.** Restoring the three call sites to `HEAD` fails 6 of the 19 new checks:
  three per-file "reaches the interface through the shim", one tree scan ("no file names a private
  HID symbol outside the table", naming all three files), and the two mode-availability checks. The
  remaining thirteen test files this commit creates, so they cannot be RED by construction.
- **GREEN on both nodes.** Linux subset `SUBSET OK (142 checks)` (was 123; +19). macOS gate
  `TESTS OK (124511 checks)` (was 124491; +20: the 19 above plus the namespace guard's per-file
  read). Nothing else moved.

## The double, and why the gate rejected it twice

`Tests/generate_sources.py` copies `clearUnmappedCapsLock` **verbatim** into a test double, so the
body under test is the body that ships. That contract has a cost: the body's dependencies must exist
in the double.

- Gate attempt 1: the body reached for `HIDEventSystemShim`, which the double did not have.
- Gate attempt 2: the double declared the shim nested with a `shared` singleton, and Swift refused
  the fakes as instance members of the enclosing state ("cannot be used on instance of nested type").
- Gate attempt 3, green: the shim is a stored dependency on both sides. Production holds
  `HIDEventSystemShim.shared`; the double holds `HIDEventSystemShim(owner: self)` and forwards each
  call back through the owning state, so its counters still observe exactly the writes production
  performs.

Both failed attempts died in the test-module compile in about twenty seconds, before any test ran.
That is why there are three runs and not the two this lane budgets for a suite: no test result was
ever produced by either of the first two, and a compile fault is not a flake to be re-read.

## What remains unproven

- **The withdrawal path has never been exercised.** `isAvailable == false` is reachable only on a
  Mac where a symbol is genuinely missing, and no such Mac is available. What is proven is that the
  shim resolves, that every call site goes through it, and that the mode consults it. The withdrawal
  itself is design, not observation.
- **Compile-time types are still a hard dependency.** A macOS that removes the *headers* breaks the
  build; that is uninhabitable by design, not a gap.
- **`dlclose` never runs in practice.** The shim is a singleton held for the process lifetime; the
  `deinit` is there so a future non-singleton use cannot leak the handle.

## One guard worth keeping

`hid-event-system-shim` reads the source tree. It is a structural assertion, not a behavioural one,
and it is called what it is. Its job is the regression no other suite can catch on a Linux node: a
future edit pasting `IOHIDEventSystemClientCreateSimpleClient(` straight back into a service compiles
on macOS, passes every other suite, and reintroduces the launch failure.

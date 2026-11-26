# P86-1 — the Now Playing channel: what it costs and what replaces it

Status: design note, 2026-11-26. Source-derived; nothing here was observed on a Mac (this lane's
gate host was offline for most of the stretch and no runtime probe was made for this note).
Companion to the P86-1 entry in `docs/ROADMAP_LEDGER.md`.

## What the tree actually does

Two services read Now Playing, and both go through the same three-hop path:

| Hop | File |
|---|---|
| spawn `/usr/bin/perl` with a script and a dylib path | `Services/RadialMenu/RadialNowPlayingService.swift:356-368`, `Services/Notch/NotchMusicService.swift:126-129` |
| perl `DynaLoader` loads the adapter and calls an entry point | `Resources/now-playing.pl:24-30` |
| the adapter talks to `MediaRemote` | `Sources/NowPlayingAdapter/NowPlayingSelection.swift:30` (`dlopen` of `/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote`) |

The perl hop exists for one reason, stated in `now-playing.pl:5-7`: **perl is a platform binary, so
MediaRemote answers it where it no longer answers the app (macOS 15.4+)**. Before 15.4 the app could
call the framework directly; after it, the call is gated on the caller being Apple-signed.

Supporting facts that matter for the risk:

- The adapter is **signed on its own** with the Developer ID and `--options runtime`
  (`build.sh:171-172`), identifier `<app bundle id>.now-playing`, and staged in `Contents/Frameworks`
  (`build.sh:61-64`). So hardened-runtime library validation is satisfied by construction: same team,
  signed, inside the bundle. Nothing here is a notarization problem.
- Both spawn sites are bounded: `replyTimeout = 2.0` with `maxOutputBytes`
  (`RadialNowPlayingService.swift:350`, `:359-361`), and the watch path guards `F_SETNOSIGPIPE`
  against a child that exits mid-write (`NotchMusicService.swift:122`). A hung or crashed perl is a
  missing snapshot, not a hang and not a SIGPIPE.
- The entitlements file carries `com.apple.security.automation.apple-events`
  (`Resources/Vorssaint.entitlements`), so Apple Events are already a declared, TCC-prompted
  capability of this app.

## What the risk actually is

P86-1 says "App Store rejection and a silent-failure dependency on a deprecated scripting runtime".
That framing needs splitting, because the two halves have different sizes:

**1. App Store is already unreachable, and not because of this.** The product needs Accessibility
event taps (`Finder/FinderCutPaste.swift`, `SuperKey/SuperKeyService.swift`), private
`IOHIDEventSystemClient` SPI (P86-2), and a root daemon installed through a sudoers rule (P86-4).
Any one of those is enough to fail review. So P86-1 is not "the thing that blocks the App Store";
it is one more item on a list where the channel was already off the table. Calling it a blocker
overstates it for that reason alone. The recorded target is Developer ID + notarization, and the
perl hop does not threaten that: spawning a platform binary with a signed in-bundle dylib notarizes
fine.

**2. The real cost is runtime fragility, and it is larger than the finding says.** The path depends
on four things outside the app's control: that `/usr/bin/perl` exists (it is still shipped, but
Apple has been steering developers off scripting runtimes for years and perl's presence in a future
macOS is not a promise), that `DynaLoader` keeps working in whatever perl ships, that the private
framework's symbol names do not move in a future release, and that MediaRemote keeps accepting
platform-binary callers rather than tightening again. Each is a silent failure: the guard at
`RadialNowPlayingService.swift:356-361` `completion(nil)`s, and `NotchMusicService` calls
`connectionEnded()`. The notch simply shows no track. Nothing tells the user why, and nothing tells
us in telemetry.

That is the defect worth fixing, and it is fixable without leaving private API behind in the parts
that can avoid it.

## Options

**A. Keep the perl bridge, make its failure legible (smallest, no capability change).**
Distinguish "no player is running" from "the adapter could not be loaded": the perl script exits with
distinct statuses (it already `die`s on unknown mode, missing library and missing symbol at
`now-playing.pl:16-21`), and the Swift side maps non-zero status to a recorded reason instead of
`nil`. Surface that reason once, in the notch's own empty state ("Now Playing unavailable — see
Troubleshooting") and in `docs/TROUBLESHOOTING.md`. There is no diagnostics surface in the app
today (`find Sources -iname '*diagnos*'` returns nothing), so this note does not get to assume one.
Cost: ~30 lines across the two services and the script, plus one documentation row.
Buys: a future perl removal becomes "the notch says Now Playing is unavailable" instead of a silent
hole.

**B. Move the readable players to Apple Events, keep MediaRemote only as the fallback.**
Apple Music and Spotify are scriptable (`player state`, `current track`, artwork URL). With
`com.apple.security.automation.apple-events` already declared, this is public API with a TCC prompt
the user sees, against a private framework with none. It also survives the 15.4 gate permanently.
Cost: a per-player script surface and its own timeout/error path, plus a permission prompt at first
use (a real UX change, and the notice in `PERMISSIONS.md` has to be written first). Coverage loss is
the honest part: players with no scripting dictionary keep only the MediaRemote path.

**C. Drop "other players" and keep only what Apple Events reach.**
Removes `watch_all`, the selection machinery in `NowPlayingSelection.swift` and the private framework
entirely. Biggest deletion, smallest maintenance surface, real feature loss for users of players
without a scripting dictionary. Only worth it if B shows the MediaRemote path is covering almost
nobody.

**D. Stay as-is and record the residual.**
Defensible only if the failure mode is made legible (A). Today it is silent, so this is not a real
option on its own.

## Recommendation

A now, B next, C only if B's measurements say the fallback rarely fires. A is small, cannot regress
a working path, and turns every future break in this chain into something a user can report. B is a
product change (a new permission prompt) and needs the operator's decision before any code.

## What could not be established here

- Whether MediaRemote's 15.4 gate is in force on the OS versions this app targets (no Mac runtime
  probe; the claim is taken from the source comment and the finding, not re-measured).
- Whether `/usr/bin/perl` is present on a current macOS release and which version ships (needs a
  Mac; `perl -v`).
- How often `watch_all` finds a player Apple Events could not read (no telemetry; this is what B
  would measure).
- Notarization of the existing signed adapter: the signature flags are visible in `build.sh` but no
  `spctl`/`notarytool` result exists for this build.

## Verification any of these would need

A is testable in the existing suites without a Mac, because the failure mapping is pure logic:
`Tests/NotchMusicHardeningTests.swift` and `Tests/NowPlayingOpenContract.swift` already exist, and
`RadialNowPlayingSupport` (the reply/snapshot parsing) is Foundation-only. B needs a real Mac to
observe a TCC prompt and a scripting dictionary; nothing in the Linux subset can stand in for it.

## Option A, first half, shipped (`c87a2213`)

The failure half of A is now code, not a proposal. `Services/Notch/NowPlayingBridgeFailure.swift`
names the four ways the bridge can produce nothing — a missing bundled script or library, a non-zero
`perl` exit, an expired reply deadline, an unreadable reply — and
`NowPlayingBridgeFailureReporter` writes one line per change of class, stays quiet on repeats, and
re-arms after a readable reply so a channel that breaks twice is not silent the second time. "Nothing
is playing" is deliberately not a case: it is the normal state and giving it one would put it in the
log.

Both bridges report. The radial bridge now distinguishes a timeout from a non-zero exit from an
unreadable reply instead of collapsing all three into `completion(nil)`
(`RadialNowPlayingService.swift:363-395`), and the notch reports a missing adapter before
`connectionEnded()` (`NotchMusicService.swift:95-112`). Lines go to `Logger` at error level with
`privacy: .public`, so Console.app shows the reason without a debugger.

`Tests/NowPlayingBridgeTests.swift` proves it: 14 checks run the reporter for real (first-class write,
silent repeat, class change, post-success re-arm, distinct summaries, no normal-state case) and 9
checks read both call sites, which are the ones that fail against the pre-fix tree.

**Closed in `678a72b4`:** the user-facing half shipped. `RadialNowPlayingState` gained a fourth case,
`.unavailable`, selected when the reporter holds a failure
(`RadialNowPlayingService.swift:34-35`), and all three surfaces draw it: the notch card empty state
and its compact strip (`NotchMusicView.swift:163-180`, `:794-799`), and the wheel item label
(`RadialMenuView.swift:476`). The label is localised in all 16 language tables — a count of
`mediaPlaybackUnavailable:` against `mediaNothingPlaying:` in `RadialMenuStrings.swift` is what the
test asserts, because a table left out falls back to nothing at all.

`Tests/NowPlayingBridgeTests.swift` grew a fourth group, `now-playing-unavailable-surfaces` (9
checks). It is real RED: against the pre-change tree it fails 8 of 9, and the ninth is what
established that the wheel ships 16 language tables rather than 15.

**Known limitation, stated rather than hidden:** the notch reads the reporter at render time, so a
failure arriving while an idle card is already on screen appears on the next render rather than
immediately. The dominant path is already correct — the fetch that fails is the same one that
empties the card, and the body has not been evaluated for that state yet.

**Gate: `TESTS OK (124491 checks)` @ `678a72b4`, 0 failure markers**, all three shell suites OK.
That is baseline `124479` plus exactly the 12 new checks. The first attempt on this commit failed
one check, `RecorderFastGIFExportTests.swift:27`, a 240-second wall-clock deadline whose suite took
287.96 s under load average 11.26; the second attempt ran the same suite in 54.94 s and passed. Same
commit, same test, 5× the duration — that is load, not a regression, and now a known flake.

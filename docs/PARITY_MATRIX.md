# Superset parity matrix

How the tools the operator wants superseded compare with what Vorssaint does
today. Evidence is the feature catalog (`Core/FeatureCatalog.swift`) and the
action enums; "absent" means a search of `Sources/Vorssaint` found no
implementation, not that it was hard to find.

## Rectangle, window management

Vorssaint is already a superset here. `WindowLayoutAction` covers halves (all
four plus centred), thirds and two-thirds in both directions, quarters in rows
and columns, sixths, the four corners, maximize, margin maximize, full screen,
centre, previous and next display, and restore. Edge snapping, directional
shortcuts, per-app exclusions and screen gaps exist beside it.

Gap: Rectangle's "almost maximize" and "smaller/larger" nudges have no direct
equivalent, and they are cheap to add to the same enum if wanted.

## Background Music, per-app audio

`mixer` gives per-app volume, `audioPriority` orders devices, `soundOutputSwitcher`
moves outputs, `micMute` covers input and `musicBlock` covers the music-blocking
case. Gap: Background Music also installs a virtual audio device so one app can
be routed to a second output. Vorssaint does not ship a driver. Only worth
building if per-app output routing, rather than per-app volume, is required.

## TinkerTool and Mac Tweaks, hidden preferences

Absent. Vorssaint exposes live toggles for its own features, but no browser of
hidden system preferences (Finder, Dock, Safari, screenshot format, recent
items). This is the real build: a curated list of defaults with typed editors,
read back after writing, and a reset per key.

## OnyX, maintenance

Absent as a suite. `cleaner`, `uninstaller`, `homebrew`, `killProcess` and
`portManager` exist, but there is no cache rebuild, LaunchServices rebuild,
Spotlight reindex or verify pass. These are destructive operations, so they
belong behind explicit confirmation with a log.

## ProToys, eighteen tools

Covered already: Dynamic Island (the notch suite), colour picker, text extractor
(screen OCR), shelf, audio mixer, port watcher, system stats, break timer
(notch timer), awake (keep awake), image resizing (media tools), mouse utilities,
FancyZones-style snapping through `windowLayout`.

Absent: screen ruler, ZoomIt-style zoom and annotate, Always On Top for a foreign
window, workspaces, Crop And Lock, bulk PowerRename with regex, a theme switcher,
and file conversion with hosted link sharing.

## Flux, display colour temperature

Absent. `brightness` and `extraBrightness` change luminance only. A warm-colour
schedule needs a gamma-table write per display, which is a contained addition.

## OpenRGB, lighting

Absent, and macOS coverage is partial and device-specific. Treated as an
optional sidecar rather than a native rewrite.

## SMB and compute-mesh management

Absent: no SMB mount management. `connectedDevices` reports peripherals and
`portManager` reports listening ports, neither manages shares. A mesh view over
Tailscale peers and SSH hosts would sit with the Tailscale work.

## Deskflow, input sharing

Absent. Decision recorded: optional bundled sidecar, driven by Vorssaint, not a
native reimplementation of the protocol.

## Amphetamine, DaisyDisk

`keepAwake` already covers the Amphetamine cases that matter (display, system,
lid). DaisyDisk has no equivalent: `cleaner` removes files but does not map disk
usage visually.

## Method note

Absence checks were literal searches for the feature names and their obvious
identifiers across `Sources/Vorssaint`. A search that finds nothing is evidence
of no implementation by that name, not proof that no partial capability exists
under another name.

# Window policy engine

Intent (ledger B1 to B4): definable smart auto tiling, a per-desktop window cap
with an overflow rule, and smart grouping for windows that are minimized but not
pinned, plus the same for dock items where Vorssaint does not already do it.

## What exists today

`windowLayout` snaps a window to an edge or a half when it is dragged there, and
exposes directional shortcuts plus `windowMaximizer`. Nothing arranges windows on
its own, nothing caps how many sit on a desktop, and nothing groups minimized
windows. The only "tiling" in the code is edge snapping.

## Shape of the feature

1. **Pure policy** (`Sources/Vorssaint/Services/WindowPolicy/WindowPolicySupport.swift`).
   Given a window count, a layout and the visible frame, decide the slot frames
   and which windows overflow. No Accessibility, no windows, no screen, so it is
   unit tested directly.
2. **Application layer** (`WindowPolicyAccessibility.swift`, landed for one app
   at a time). It enumerates the windows Accessibility reports for a process,
   builds `WindowPolicyWindow` values from subrole, attribute settability, sheet
   state and minimized state, filters them through `WindowPolicyEligibility`,
   asks the policy for a plan and writes position then size. `tileFrontmostApp`
   is the first entry point; spanning every app on a space comes after the
   setting exists.
3. **Settings** (next). Layout choice (halves, thirds, quarters), the cap,
   the overflow rule, a gap, and a hotkey to tile now. Off by default, like every
   other feature.

## Overflow rules

The policy reports overflow as indexes, not actions, so the caller decides:

- **Leave in place**: the default, and what makes a trial run safe.
- **Minimize**: the cheapest reversible action, offered as a picker option.
- **New desktop**: not offered. Accessibility has no supported call that moves a
  window to another Space, and the private route is not worth the fragility.

Overflow is only reported when the windows exceed either the slots or the cap,
whichever is smaller. A cap of zero means the slots are the only bound.

## Safety

- Only windows the Accessibility API reports as movable and resizable get a new
  frame.
- Nothing runs while a modal sheet is attached to the window.
- The feature is opt-in and has an explicit "tile now" action, so a policy bug
  cannot rearrange someone's screen without an action that asked for it.
- Grouping of minimized windows does not move files or apps; it is a view, and it
  is undone by ungrouping.

## Tests

`Tests/WindowPolicyTests.swift`, registered as the `window-policy` suite, covers
grid proportions, gap insets, exact coverage with no overlap, the cap, overflow
ordering, the slot bound without a cap, and degenerate screens.

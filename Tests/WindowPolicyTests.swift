// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

/// Geometry and overflow decisions of the automatic tiling policy. Everything
/// here is pure, so it runs without Accessibility, windows or a screen.
enum WindowPolicyTests {
    static func run(_ suite: TestSuite) {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

        suite.expect(WindowPolicy.grid(for: .halves) == WindowTileGrid(columns: 2, rows: 1),
                     "halves is one row of two")
        suite.expect(WindowPolicy.grid(for: .thirds) == WindowTileGrid(columns: 3, rows: 1),
                     "thirds is one row of three")
        suite.expect(WindowPolicy.grid(for: .quarters) == WindowTileGrid(columns: 2, rows: 2),
                     "quarters is two by two")

        let quarters = WindowPolicy.slots(WindowPolicy.grid(for: .quarters), in: screen)
        suite.expect(quarters.count == 4, "quarters offers four slots")
        let covered = quarters.reduce(CGFloat(0)) { $0 + $1.width * $1.height }
        suite.expect(close(covered, screen.width * screen.height),
                     "the four quarters cover the screen exactly")
        suite.expect(!overlaps(quarters), "quarter slots do not overlap")
        suite.expect(close(quarters[0].minX, screen.minX) && close(quarters[0].maxY, screen.maxY),
                     "the first slot is the top left")
        suite.expect(close(quarters[0].width, screen.width / 2)
                        && close(quarters[0].height, screen.height / 2),
                     "a quarter is half the screen in each direction")

        let gapped = WindowPolicy.slots(WindowPolicy.grid(for: .halves), in: screen, gap: 10)
        suite.expect(gapped.count == 2, "halves offers two slots")
        suite.expect(close(gapped[0].minX, 5) && close(gapped[0].maxY, screen.maxY - 5),
                     "the gap insets the outer edge by half")
        suite.expect(close(gapped[0].maxX, screen.midX - 5) && close(gapped[1].minX, screen.midX + 5),
                     "neighbouring slots end up a whole gap apart")

        let fitted = WindowPolicy.plan(windowCount: 3, layout: .quarters, visibleFrame: screen)
        suite.expect(fitted.tiledCount == 3 && fitted.overflow.isEmpty,
                     "three windows fill three quarter slots with no overflow")

        let capped = WindowPolicy.plan(windowCount: 5, layout: .quarters, visibleFrame: screen, limit: 4)
        suite.expect(capped.tiledCount == 4 && capped.overflow == [4],
                     "a cap of four leaves the fifth window as overflow")

        let tight = WindowPolicy.plan(windowCount: 5, layout: .quarters, visibleFrame: screen, limit: 3)
        suite.expect(tight.tiledCount == 3 && tight.overflow == [3, 4],
                     "a cap of three overflows the rest in order")

        let slotBound = WindowPolicy.plan(windowCount: 6, layout: .halves, visibleFrame: screen)
        suite.expect(slotBound.tiledCount == 2 && slotBound.overflow == [2, 3, 4, 5],
                     "without a cap the slots themselves are the bound")

        let none = WindowPolicy.plan(windowCount: 0, layout: .quarters, visibleFrame: screen)
        suite.expect(none.frames.isEmpty && none.overflow.isEmpty,
                     "no windows means no plan")

        let degenerate = WindowPolicy.slots(WindowPolicy.grid(for: .halves),
                                            in: CGRect(x: 0, y: 0, width: 0, height: 0))
        suite.expect(degenerate.isEmpty, "a zero sized screen offers no slots")

        func window(_ id: Int,
                    standard: Bool = true,
                    movable: Bool = true,
                    resizable: Bool = true,
                    sheet: Bool = false,
                    minimized: Bool = false,
                    layer: Int = 0) -> WindowPolicyWindow {
            WindowPolicyWindow(id: id, isStandard: standard, isMovable: movable,
                               isResizable: resizable, hasSheet: sheet,
                               isMinimized: minimized, layer: layer)
        }

        let mixed = [window(1),
                     window(2, standard: false),
                     window(3, movable: false),
                     window(4, resizable: false),
                     window(5, sheet: true),
                     window(6, minimized: true),
                     window(7, layer: 3),
                     window(8)]
        suite.expect(WindowPolicyEligibility.eligible(mixed).map(\.id) == [1, 8],
                     "only ordinary movable resizable windows in the normal layer are eligible")
        suite.expect(WindowPolicyEligibility.eligible([]).isEmpty,
                     "no windows means no eligible windows")
    }

    private static func close(_ first: CGFloat, _ second: CGFloat) -> Bool {
        abs(first - second) < 0.001
    }

    private static func overlaps(_ rects: [CGRect]) -> Bool {
        for index in rects.indices {
            for other in rects.indices where other > index {
                if rects[index].intersects(rects[other]) { return true }
            }
        }
        return false
    }
}

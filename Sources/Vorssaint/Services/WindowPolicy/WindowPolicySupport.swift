// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics

/// How windows are arranged when they are tiled automatically. Only the shapes
/// a person can describe out loud are offered; free-form grids belong to the
/// manual layouts, not to a policy that runs by itself.
enum WindowTileLayout: String, CaseIterable {
    case halves
    case thirds
    case quarters
}

struct WindowTileGrid: Equatable {
    let columns: Int
    let rows: Int

    var capacity: Int { columns * rows }
}

/// What a policy decided for the windows it was given, in the same order.
struct WindowPolicyPlan: Equatable {
    /// A frame for each window that should be tiled, in input order.
    var frames: [CGRect]
    /// Indexes of the windows that did not fit, which the caller either
    /// minimizes or pushes to a new desktop.
    var overflow: [Int]

    var tiledCount: Int { frames.count }
}

/// What happens to windows the layout cannot hold. Moving a window to another
/// Space has no supported Accessibility call, so it is not offered here.
enum WindowPolicyOverflow: String, CaseIterable {
    case leave
    case minimize
}

/// One minimized window as the grouping model sees it.
struct MinimizedWindowInfo: Equatable {
    let id: Int
    let appBundleID: String
    let isPinned: Bool
}

/// Minimized windows collapsed by app, pinned ones left out. The point is a
/// short list a person can scan, not a second Dock: one row per app, with the
/// windows counted, in the order the apps first appear.
struct MinimizedWindowGroup: Equatable {
    let appBundleID: String
    let windowIDs: [Int]

    var count: Int { windowIDs.count }
}

enum MinimizedWindowGrouping {
    static func groups(_ windows: [MinimizedWindowInfo]) -> [MinimizedWindowGroup] {
        var order: [String] = []
        var byApp: [String: [Int]] = [:]
        for window in windows where !window.isPinned {
            if byApp[window.appBundleID] == nil {
                order.append(window.appBundleID)
                byApp[window.appBundleID] = []
            }
            byApp[window.appBundleID]?.append(window.id)
        }
        return order.compactMap { bundleID in
            guard let ids = byApp[bundleID], !ids.isEmpty else { return nil }
            return MinimizedWindowGroup(appBundleID: bundleID, windowIDs: ids)
        }
    }
}

/// One Dock item as the grouping model sees it.
struct DockItemInfo: Equatable {
    let bundleID: String
    let isPinnedInDock: Bool
    let minimizedWindowCount: Int
}

/// An app whose minimized windows are not represented by a pinned Dock icon.
struct DockItemGroup: Equatable {
    let bundleID: String
    let minimizedWindowCount: Int
}

enum DockItemGrouping {
    /// Apps with minimized windows that are not pinned in the Dock. Pinned apps
    /// are left alone: the person put them there on purpose. Duplicate entries
    /// for one app are summed, and the order given is kept.
    static func groups(_ items: [DockItemInfo]) -> [DockItemGroup] {
        var order: [String] = []
        var counts: [String: Int] = [:]
        for item in items where !item.isPinnedInDock && item.minimizedWindowCount > 0 {
            if counts[item.bundleID] == nil {
                order.append(item.bundleID)
                counts[item.bundleID] = 0
            }
            counts[item.bundleID, default: 0] += item.minimizedWindowCount
        }
        return order.compactMap { bundleID in
            guard let count = counts[bundleID], count > 0 else { return nil }
            return DockItemGroup(bundleID: bundleID, minimizedWindowCount: count)
        }
    }
}

/// What the policy knows about one window before deciding anything. A value
/// type on purpose: the Accessibility controller fills it from AX attributes,
/// and the filter below is then testable without a window server.
struct WindowPolicyWindow: Equatable {
    let id: Int
    /// AX reports `AXStandardWindow` for the windows a person thinks of as a
    /// window. Palettes, sheets, popovers and system surfaces are not.
    let isStandard: Bool
    let isMovable: Bool
    let isResizable: Bool
    /// A modal sheet belongs to its parent; moving the parent breaks the sheet.
    let hasSheet: Bool
    let isMinimized: Bool
    let layer: Int
}

enum WindowPolicyEligibility {
    /// The windows a policy may touch, in the order given. Everything that is
    /// not an ordinary, movable, resizable, unminimized window in the normal
    /// layer is left exactly where it is.
    static func eligible(_ windows: [WindowPolicyWindow]) -> [WindowPolicyWindow] {
        windows.filter { window in
            window.isStandard
                && window.isMovable
                && window.isResizable
                && !window.hasSheet
                && !window.isMinimized
                && window.layer == 0
        }
    }
}

enum WindowPolicy {
    static func grid(for layout: WindowTileLayout) -> WindowTileGrid {
        switch layout {
        case .halves: return WindowTileGrid(columns: 2, rows: 1)
        case .thirds: return WindowTileGrid(columns: 3, rows: 1)
        case .quarters: return WindowTileGrid(columns: 2, rows: 2)
        }
    }

    /// The slots of a grid inside `visibleFrame`, left to right and top to
    /// bottom. A gap insets every slot on all four sides by half the gap, so
    /// neighbouring windows end up a whole gap apart and the outer edge keeps
    /// the same breathing room.
    static func slots(_ grid: WindowTileGrid, in visibleFrame: CGRect, gap: CGFloat = 0) -> [CGRect] {
        guard grid.columns > 0, grid.rows > 0, visibleFrame.width > 0, visibleFrame.height > 0 else {
            return []
        }
        let columnWidth = visibleFrame.width / CGFloat(grid.columns)
        let rowHeight = visibleFrame.height / CGFloat(grid.rows)
        let inset = max(0, gap) / 2
        var result: [CGRect] = []
        result.reserveCapacity(grid.capacity)
        for row in 0..<grid.rows {
            for column in 0..<grid.columns {
                let cell = CGRect(x: visibleFrame.minX + CGFloat(column) * columnWidth,
                                  y: visibleFrame.maxY - CGFloat(row + 1) * rowHeight,
                                  width: columnWidth,
                                  height: rowHeight)
                let insetCell = cell.insetBy(dx: inset, dy: inset)
                if insetCell.width > 0, insetCell.height > 0 {
                    result.append(insetCell)
                }
            }
        }
        return result
    }

    /// Assigns each window to a slot until the slots or `limit` run out. A limit
    /// of zero or less means the slots are the only bound. Everything past that
    /// is reported as overflow rather than silently dropped.
    static func plan(windowCount: Int,
                     layout: WindowTileLayout,
                     visibleFrame: CGRect,
                     limit: Int = 0,
                     gap: CGFloat = 0) -> WindowPolicyPlan {
        guard windowCount > 0 else { return WindowPolicyPlan(frames: [], overflow: []) }
        let available = slots(grid(for: layout), in: visibleFrame, gap: gap)
        let capped = limit > 0 ? min(available.count, limit) : available.count
        let tiled = min(windowCount, capped)
        let frames = Array(available.prefix(tiled))
        let overflow = tiled < windowCount ? Array(tiled..<windowCount) : []
        return WindowPolicyPlan(frames: frames, overflow: overflow)
    }
}

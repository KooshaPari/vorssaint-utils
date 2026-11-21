// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import Foundation

/// Drives the window policy from the settings page. Deliberately an explicit
/// action rather than a background watcher: nothing rearranges a screen until
/// the person asks for it, and the result of the last request stays visible.
final class WindowPolicyService: ObservableObject {
    static let shared = WindowPolicyService()

    /// How many windows the last request actually moved, or nil before the
    /// first one.
    @Published private(set) var lastMovedCount: Int?
    /// Minimized windows collapsed by app, refreshed on demand. Read only.
    @Published private(set) var minimizedGroups: [MinimizedWindowGroup] = []

    private init() {}

    func tileNow() {
        let layout = WindowTileLayout(
            rawValue: UserDefaults.standard.string(forKey: DefaultsKey.windowPolicyLayout) ?? ""
        ) ?? .quarters
        let gap = CGFloat(max(0, UserDefaults.standard.integer(forKey: DefaultsKey.windowLayoutWindowGap)))
        let limit = max(0, UserDefaults.standard.integer(forKey: DefaultsKey.windowPolicyLimit))
        let overflow = WindowPolicyOverflow(
            rawValue: UserDefaults.standard.string(forKey: DefaultsKey.windowPolicyOverflow) ?? ""
        ) ?? .leave
        lastMovedCount = WindowPolicyAccessibility.tileFrontmostApp(layout: layout,
                                                                   limit: limit,
                                                                   overflow: overflow,
                                                                   gap: gap)
    }

    /// Recomputes the grouped view of minimized windows. Nothing is moved,
    /// restored or reordered by this.
    func refreshMinimizedGroups() {
        minimizedGroups = MinimizedWindowGrouping.groups(WindowPolicyAccessibility.minimizedWindows())
    }
}

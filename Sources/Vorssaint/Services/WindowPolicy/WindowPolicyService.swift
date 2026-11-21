// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import Foundation

/// Which apps have a pinned Dock icon. Returns nil when the Dock domain cannot
/// be read, and callers treat that as "everything pinned" so grouping fails
/// closed instead of inventing entries.
enum DockPinnedApps {
    static func bundleIDs() -> Set<String>? {
        guard let defaults = UserDefaults(suiteName: "com.apple.dock"),
              let apps = defaults.array(forKey: "persistent-apps") as? [[String: Any]] else {
            return nil
        }
        var result = Set<String>()
        for entry in apps {
            guard let tile = entry["tile-data"] as? [String: Any],
                  let fileData = tile["file-data"] as? [String: Any],
                  let urlString = fileData["_CFURLString"] as? String else { continue }
            let path = urlString.hasPrefix("file://")
                ? String(urlString.dropFirst("file://".count))
                : urlString
            if let bundle = Bundle(path: path), let identifier = bundle.bundleIdentifier {
                result.insert(identifier)
            }
        }
        return result
    }
}

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
    /// Apps whose minimized windows have no pinned Dock icon of their own.
    @Published private(set) var dockGroups: [DockItemGroup] = []

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
        refreshDockGroups()
    }

    /// Recomputes the dock groups from the minimized windows and the Dock's
    /// pinned apps. Read only: no Dock icon is added, moved or removed.
    private func refreshDockGroups() {
        let pinned = DockPinnedApps.bundleIDs()
        let items = minimizedGroups.map { group in
            DockItemInfo(bundleID: group.appBundleID,
                         isPinnedInDock: pinned?.contains(group.appBundleID) ?? true,
                         minimizedWindowCount: group.count)
        }
        dockGroups = DockItemGrouping.groups(items)
    }
}

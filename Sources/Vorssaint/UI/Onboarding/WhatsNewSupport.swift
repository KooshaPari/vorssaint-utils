// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// One sidebar row of the post-update "What's New" window.
struct WhatsNewRow: Identifiable, Equatable {
    enum ID: Hashable {
        case newFeature(AppFeature)
        /// An installed feature, under its Settings sidebar row.
        case settings(SettingsSidebarItem.ID)
        /// An installed feature that has no row of its own in Settings.
        case feature(AppFeature)
        case general
        case notInstalled(AppFeature)
    }

    let id: ID
    /// The row's name in the language it was built in. A row nested under the
    /// Settings row that names it takes that row's title, so one surface is not
    /// printed under two names in one window.
    var title: String
    let icon: String
    /// The feature the row stands for, when it stands for a single one. The
    /// Dynamic Island row stands for the island, not for its extensions.
    let feature: AppFeature?
    let destination: FeatureSettingsDestination?
    var changes: [ReleaseChange]
    /// True for a row announcing something this build added: the view tags it
    /// with `KnuTag` so it reads as new beside its parent row.
    var isNew = false
    /// New features shown under this row, in catalog order. The same rows also
    /// stay in `WhatsNewSections.newFeatures`, flat, for the overview counts.
    var children: [WhatsNewRow] = []

    var isNewFeature: Bool {
        if case .newFeature = id { return true }
        return false
    }
}

/// The window's sidebar, laid out like the Settings sidebar it mirrors.
struct WhatsNewSections: Equatable {
    /// Every new feature, flat, in catalog order, whether or not a Settings
    /// row took it in. The overview counts read this list.
    var newFeatures: [WhatsNewRow] = []
    var yourFeatures: [WhatsNewRow] = []
    var notInstalled: [WhatsNewRow] = []

    var rows: [WhatsNewRow] { newFeatures + yourFeatures + notInstalled }

    /// Every row the sidebar shows, the ones nested under a parent included,
    /// so a selected row can be found and read on a page of its own.
    var allRows: [WhatsNewRow] { rows + rows.flatMap(\.children) }

    /// Changes that concern this person, once each, for the overview counts.
    var changesForYou: Set<ReleaseChange> {
        Set((newFeatures + yourFeatures).flatMap(\.changes))
    }

    /// Nothing worth an interruption: no new feature, and every change is
    /// about a feature this Mac does not have.
    var hasContentForYou: Bool { !newFeatures.isEmpty || !yourFeatures.isEmpty }

    /// The same sections, narrowed to what a search keeps. Only the two lists
    /// the sidebar draws are filtered: `newFeatures` stays whole because the
    /// overview's counts describe the update, not the query.
    func searching(_ query: String) -> WhatsNewSections {
        var sections = self
        sections.yourFeatures = WhatsNewSupport.searching(yourFeatures, query: query)
        sections.notInstalled = WhatsNewSupport.searching(notInstalled, query: query)
        return sections
    }

    /// True when a search hid everything the sidebar would otherwise draw.
    func isEmpty(for query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return !needle.isEmpty && yourFeatures.isEmpty && notInstalled.isEmpty
    }
}

enum WhatsNewSupport {
    /// Installed features group under the row Settings shows them in, in the
    /// Settings order, with app-wide changes last. Features left out of the
    /// Mac's install are listed one by one, since each installs on its own;
    /// a Dynamic Island extension does nothing without the island, so it
    /// counts as installed only beside it. A new feature nests under the row
    /// it belongs to, so it reads beside the settings that already exist
    /// instead of in a group of its own; one with no Settings row keeps a row
    /// of its own, in the catalog order.
    static func sections(digest: ReleaseDigest,
                         newFeatures: [AppFeature],
                         sidebarItems: [SettingsSidebarItem],
                         isAvailable: (AppFeature) -> Bool,
                         title: (AppFeature) -> String,
                         generalTitle: String) -> WhatsNewSections {
        let introduced = Set(newFeatures)
        func isInstalled(_ feature: AppFeature) -> Bool {
            isAvailable(feature)
                && (feature.group != .dynamicIsland || feature == .notch || isAvailable(.notch))
        }
        var installedChanges: [WhatsNewRow.ID: [ReleaseChange]] = [:]
        var missingChanges: [AppFeature: [ReleaseChange]] = [:]
        func add(_ change: ReleaseChange, to list: inout [ReleaseChange]?) {
            if !(list ?? []).contains(change) { list = (list ?? []) + [change] }
        }
        for change in digest.changes {
            if change.isAppWide {
                add(change, to: &installedChanges[.general])
            }
            for feature in change.features where !introduced.contains(feature) {
                if isInstalled(feature) {
                    add(change, to: &installedChanges[rowID(for: feature, in: sidebarItems)])
                } else {
                    add(change, to: &missingChanges[feature])
                }
            }
        }

        var sections = WhatsNewSections()
        let newRows = newFeatures.map { feature in
            WhatsNewRow(id: .newFeature(feature), title: title(feature), icon: feature.symbolName,
                        feature: feature, destination: navigableDestination(of: feature),
                        changes: digest.changes.filter { $0.features.contains(feature) },
                        isNew: true)
        }
        sections.newFeatures = newRows
        // Where each new feature reads: under its Settings row when Settings
        // has one, otherwise on a row of its own. A row cannot hold itself, so
        // the feature's own row counts as having none.
        var nested: [WhatsNewRow.ID: [WhatsNewRow]] = [:]
        var standalone: [AppFeature: WhatsNewRow] = [:]
        for row in newRows {
            guard let feature = row.feature else { continue }
            let parent = rowID(for: feature, in: sidebarItems)
            if case .feature = parent {
                standalone[feature] = row
            } else {
                nested[parent, default: []].append(row)
            }
        }
        for item in sidebarItems {
            let children = (nested[.settings(item.id)] ?? []).map { row -> WhatsNewRow in
                // A new feature filed under the Settings row that stands for it
                // is that same surface, so it reads the row's name ("Clipboard
                // history") rather than the catalogue's ("Clipboard"). Derived
                // from the row it is filed under, not from a second special case.
                guard row.feature == representedFeature(of: item.id) else { return row }
                var row = row
                row.title = item.title
                return row
            }
            let changes = ownChanges(installedChanges[.settings(item.id)] ?? [], children: children)
            guard !changes.isEmpty || !children.isEmpty else { continue }
            let feature = representedFeature(of: item.id)
            sections.yourFeatures.append(WhatsNewRow(
                id: .settings(item.id), title: item.title, icon: item.icon, feature: feature,
                destination: item.destination, changes: changes, children: children))
        }
        for feature in AppFeature.allCases {
            if var row = standalone[feature] {
                // A feature that is both new and changed keeps one row, marked
                // new, rather than arriving twice.
                if let changes = installedChanges[.feature(feature)] { row.changes = changes }
                sections.yourFeatures.append(row)
            } else if let changes = installedChanges[.feature(feature)] {
                sections.yourFeatures.append(WhatsNewRow(
                    id: .feature(feature), title: title(feature), icon: feature.symbolName, feature: feature,
                    destination: navigableDestination(of: feature), changes: changes))
            }
        }
        let generalChanges = ownChanges(installedChanges[.general] ?? [], children: nested[.general] ?? [])
        let generalChildren = nested[.general] ?? []
        if !generalChanges.isEmpty || !generalChildren.isEmpty {
            sections.yourFeatures.append(WhatsNewRow(
                id: .general, title: generalTitle, icon: "gearshape", feature: nil,
                destination: nil, changes: generalChanges, children: generalChildren))
        }
        sections.notInstalled = AppFeature.allCases.compactMap { feature in
            missingChanges[feature].map {
                WhatsNewRow(id: .notInstalled(feature), title: title(feature), icon: feature.symbolName,
                            feature: feature, destination: navigableDestination(of: feature), changes: $0)
            }
        }
        return sections
    }

    /// The changes a parent row reads itself: everything filed under it except
    /// the lines a nested new feature already shows on the same page, so one
    /// line is not printed twice.
    private static func ownChanges(_ changes: [ReleaseChange], children: [WhatsNewRow]) -> [ReleaseChange] {
        let shown = Set(children.compactMap(\.feature))
        guard !shown.isEmpty else { return changes }
        return changes.filter { shown.isDisjoint(with: $0.features) }
    }

    /// Every feature the window reads as new: the features this update added,
    /// plus the ones this build tagged as having gained something
    /// (`NewFeatureBadges.tagged`), in catalog order and without repeats. An
    /// unsupported feature is not announced, matching the added list.
    static func newFeatures(added: [AppFeature], tagged: Set<AppFeature>,
                            isSupported: (AppFeature) -> Bool) -> [AppFeature] {
        let announced = Set(added).union(tagged)
        return AppFeature.allCases.filter { announced.contains($0) && isSupported($0) }
    }

    /// The Settings sidebar row an installed feature belongs to. Dynamic
    /// Island extensions, the companion included, live on the island's page;
    /// a feature Settings files under the General page, or keeps only in the
    /// Features page, gets a row of its own beside them.
    static func rowID(for feature: AppFeature, in items: [SettingsSidebarItem]) -> WhatsNewRow.ID {
        let ids = Set(items.map(\.id))
        if ids.contains(.feature(feature)) { return .settings(.feature(feature)) }
        let page = feature.settingsDestination.page
        if page == .general { return .general }
        if page != .features, ids.contains(.page(page)) { return .settings(.page(page)) }
        if feature.group == .dynamicIsland, ids.contains(.page(.notch)) { return .settings(.page(.notch)) }
        return .feature(feature)
    }

    /// Each row's title in the current language, from the same sources the
    /// rows were built with, so a language change mid-window relabels them.
    static func titles(of rows: [WhatsNewRow], sidebarItems: [SettingsSidebarItem],
                       title: (AppFeature) -> String, generalTitle: String) -> [WhatsNewRow.ID: String] {
        var resolved = Dictionary((rows + rows.flatMap(\.children)).map { row -> (WhatsNewRow.ID, String) in
            switch row.id {
            case .settings(let item):
                return (row.id, sidebarItems.first { $0.id == item }?.title ?? row.title)
            case .general:
                return (row.id, generalTitle)
            case .newFeature(let feature), .feature(let feature), .notInstalled(let feature):
                return (row.id, title(feature))
            }
        }, uniquingKeysWith: { first, _ in first })
        // A child named after the Settings row it is filed under keeps that name
        // here too, so a language change cannot rename the pair apart.
        for row in rows {
            guard case .settings(let item) = row.id, let parentTitle = resolved[row.id] else { continue }
            let owner = representedFeature(of: item)
            for child in row.children where child.feature == owner { resolved[child.id] = parentTitle }
        }
        return resolved
    }

    /// The one feature a Settings row stands for, if any: a tool row, or a
    /// page that belongs to a single feature (the Dynamic Island page counts
    /// as the island's, not its extensions'). The System Monitor page holds
    /// several and stands for none.
    static func representedFeature(of id: SettingsSidebarItem.ID) -> AppFeature? {
        switch id {
        case .feature(let feature): return feature
        case .page(let page):
            let owners = AppFeature.allCases.filter {
                $0.settingsDestination == FeatureSettingsDestination(page)
                    && !AppFeature.dynamicIslandExtensions.contains($0)
            }
            return owners.count == 1 ? owners[0] : nil
        case .setting: return nil
        }
    }

    private static func navigableDestination(of feature: AppFeature) -> FeatureSettingsDestination? {
        feature.hasNavigableSettingsDestination ? feature.settingsDestination : nil
    }

    /// Changes in the order the window lists them: new, then changed, then
    /// fixed, each keeping the newest version first.
    static func grouped(_ changes: [ReleaseChange]) -> [WhatsNewChangeGroup] {
        ReleaseChangeKind.allCases.compactMap { kind in
            let matching = changes.filter { $0.kind == kind }
            return matching.isEmpty ? nil : WhatsNewChangeGroup(kind: kind, changes: matching)
        }
    }

    // MARK: - Searching the window

    /// The rows a search keeps. A blank query is not a filter: the list it
    /// returns is the list it was given, unchanged and in the same order.
    ///
    /// A row is kept when its own name or one of its own change lines matches.
    /// A row whose nested new feature matches is kept too, so searching for
    /// what a feature does does not hide the Settings row it sits under, and
    /// that parent keeps only the children that matched. The one case that
    /// keeps a whole subtree is a parent that matches on its own: then all of
    /// its children come with it, since they are part of what matched.
    static func searching(_ rows: [WhatsNewRow], query: String) -> [WhatsNewRow] {
        let needle = folded(query)
        guard !needle.isEmpty else { return rows }
        return rows.compactMap { row in
            if matches(row, needle) { return row }
            let kept = row.children.filter { matches($0, needle) }
            guard !kept.isEmpty else { return nil }
            var row = row
            row.children = kept
            return row
        }
    }

    /// Case-, accent- and width-insensitive, so "reseau" finds "réseau" and a
    /// reader does not have to reproduce the title's capitalisation to find it.
    /// No locale: Turkish folds a dotted I to a dotless one, which would make
    /// this field answer differently there. The settings search folds the same
    /// way for the same reasons.
    private static func folded(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                     locale: nil)
    }

    private static func matches(_ row: WhatsNewRow, _ needle: String) -> Bool {
        if folded(row.title).contains(needle) { return true }
        return row.changes.contains { folded($0.text).contains(needle) }
    }
}

struct WhatsNewChangeGroup: Identifiable {
    let kind: ReleaseChangeKind
    let changes: [ReleaseChange]
    var id: ReleaseChangeKind { kind }
}

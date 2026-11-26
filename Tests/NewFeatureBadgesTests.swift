// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The review surface of this build's new-feature marker. A feature in
/// `NewFeatureBadges.tagged` is reviewable three ways, and each one reads the
/// tag from a different place, so this suite fails when one of them drifts:
///
/// - the changelog's `### What's KNU` list, under `## [Unreleased]`, names
///   every tagged feature with the change a person sees and the moment it
///   became new (ISO-8601 with time);
/// - Settings search answers to `KNU` for every tagged feature, including a
///   feature whose own Settings page absorbs its row;
/// - the post-update window nests every tagged feature under the Settings row
///   it belongs to, marked as new, while the flat list still counts it.
enum NewFeatureBadgesTests {
    /// One `What's KNU` line: the tagged feature, the change a person sees, and
    /// when it became new.
    struct Entry: Equatable {
        let feature: AppFeature
        let text: String
        let becameNewAt: Date
    }

    static func run(_ suite: TestSuite) {
        let changelog = (try? String(contentsOfFile: "CHANGELOG.md", encoding: .utf8)) ?? ""
        suite.expect(!changelog.isEmpty, "CHANGELOG.md is readable from the repository root")
        guard let section = knuSection(in: changelog) else {
            suite.expect(false, "## [Unreleased] has a ### What's KNU section")
            return
        }
        let entries = parse(section, suite: suite)
        suite.expect(becameNewAt(in: "a change, new as of 2026-11-26T10:57Z") != nil,
                     "a stamp down to the minute names the moment it became new")
        suite.expect(becameNewAt(in: "a change, new as of 2026-11-26") == nil,
                     "a bare date does not name the moment it became new")
        checkAgreement(entries, suite: suite)
        checkSearch(suite)
        checkNesting(suite)
    }

    // MARK: The changelog list

    /// The `### What's KNU` body inside `## [Unreleased]`, without its heading.
    /// A heading that only differs in case or in the apostrophe it uses is the
    /// same heading.
    static func knuSection(in changelog: String) -> String? {
        var inUnreleased = false
        var collecting = false
        var lines: [String] = []
        for line in changelog.components(separatedBy: .newlines) {
            if line.hasPrefix("## ") {
                inUnreleased = folded(line) == "## [unreleased]"
                collecting = false
                continue
            }
            guard inUnreleased else { continue }
            if line.hasPrefix("###") {
                collecting = folded(String(line.drop { $0 == "#" })) == "what's knu"
                continue
            }
            if collecting { lines.append(line) }
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    static func parse(_ section: String, suite: TestSuite) -> [Entry] {
        var entries: [Entry] = []
        for line in section.components(separatedBy: .newlines) where line.hasPrefix("- ") {
            let body = String(line.dropFirst(2))
            guard let name = backtickedName(in: body), let feature = AppFeature(rawValue: name) else {
                suite.expect(false, "a What's KNU line names its AppFeature in backticks: \(body.prefix(70))")
                continue
            }
            guard let stamp = becameNewAt(in: body) else {
                suite.expect(false, "What's KNU line for \(name) records when it became new")
                continue
            }
            let text = changeText(in: body)
            suite.expect(text.count > 10, "What's KNU line for \(name) says what a person can now do")
            entries.append(Entry(feature: feature, text: text, becameNewAt: stamp))
        }
        return entries
    }

    /// The marker and the changelog must name the same features: no tagged
    /// feature ships without a line to review, and no line outlives its tag.
    private static func checkAgreement(_ entries: [Entry], suite: TestSuite) {
        let tagged = NewFeatureBadges.tagged
        let listed = Set(entries.map(\.feature))
        suite.expect(entries.count == listed.count, "What's KNU names each tagged feature once")
        for feature in tagged.sorted(by: { $0.rawValue < $1.rawValue }) {
            suite.expect(listed.contains(feature),
                         "NewFeatureBadges.tagged has \(feature.rawValue), so What's KNU lists it")
        }
        for feature in listed.subtracting(tagged).sorted(by: { $0.rawValue < $1.rawValue }) {
            suite.expect(false, "What's KNU lists \(feature.rawValue), which NewFeatureBadges.tagged does not have")
        }
    }

    // MARK: Search

    private static func checkSearch(_ suite: TestSuite) {
        let items = SettingsSearchSupport.featureItems(language: .enUS, title: { $0.rawValue })
        for feature in NewFeatureBadges.tagged.sorted(by: { $0.rawValue < $1.rawValue }) {
            for query in ["KNU", "knu"] {
                let found = SettingsSearchSupport.matchingItems(query: query, items: items)
                    .contains { $0.feature == feature }
                suite.expect(found, "Settings search \"\(query)\" finds \(feature.rawValue)")
            }
            suite.expect(SettingsSearchSupport.matchingItems(query: "new", items: items)
                            .contains { $0.feature == feature },
                         "Settings search \"new\" finds \(feature.rawValue)")
        }

        // A feature that owns its Settings page keeps the marker when the page
        // row takes the feature row's place.
        let page = SettingsSearchItem(id: .page(.homebrew),
                                      destination: FeatureSettingsDestination(.homebrew),
                                      title: "Homebrew", icon: "mug")
        let featureRow = SettingsSearchItem(id: .feature(.homebrew),
                                           destination: AppFeature.homebrew.settingsDestination,
                                           title: "Homebrew", icon: "mug", keywords: ["KNU"],
                                           feature: .homebrew)
        let merged = SettingsSearchSupport.combinedItems(pageItems: [page], featureItems: [featureRow])
        suite.expect(merged.count == 1 && merged[0].keywords.contains("KNU"),
                     "a page row that absorbed a feature row keeps its KNU keyword")
    }

    // MARK: The post-update window

    private static func checkNesting(_ suite: TestSuite) {
        func item(_ page: SettingsPage, _ title: String) -> SettingsSidebarItem {
            SettingsSidebarItem(id: .page(page), destination: FeatureSettingsDestination(page),
                                title: title, icon: "circle")
        }
        // Clipboard history's own settings live on the Clipboard page, so it is
        // the row the window has to file it under.
        let items = [item(.general, "General"), item(.clipboard, "Clipboard")]
        // The tag alone is enough to bring a feature into the window, which is
        // what makes it reviewable on a build that added no catalog entries.
        let announced = WhatsNewSupport.newFeatures(added: [], tagged: NewFeatureBadges.tagged,
                                                    isSupported: { _ in true })
        suite.expect(Set(announced) == NewFeatureBadges.tagged,
                     "every tagged feature reaches the window without being added to the catalog")
        suite.expect(WhatsNewSupport.newFeatures(added: [.portManager], tagged: [.switcher],
                                                 isSupported: { _ in true })
                        == [.switcher, .portManager],
                     "the window reads added and tagged features in catalog order")
        suite.expect(WhatsNewSupport.newFeatures(added: [.switcher], tagged: [.switcher],
                                                 isSupported: { _ in false }).isEmpty,
                     "the window announces no feature this Mac cannot have")
        let tagged = announced
        let sections = WhatsNewSupport.sections(
            digest: ReleaseDigest(previousVersion: "3.4.4", version: "3.4.5", versions: ["3.4.5"],
                                  summary: nil, changes: []),
            newFeatures: tagged, sidebarItems: items, isAvailable: { _ in true },
            title: { $0.rawValue }, generalTitle: "General")
        suite.expect(!sections.yourFeatures.isEmpty,
                     "a build with a new feature opens the window on it")
        for feature in tagged {
            let parent = sections.yourFeatures.first { row in
                row.children.contains { $0.feature == feature }
            }
            suite.expect(parent != nil,
                         "What's New shows \(feature.rawValue) under the Settings row it belongs to")
            suite.expect(parent?.children.first { $0.feature == feature }?.isNew == true,
                         "the nested row for \(feature.rawValue) is marked as new")
            suite.expect(sections.newFeatures.contains { $0.feature == feature },
                         "the overview still counts \(feature.rawValue)")
            suite.expect(sections.allRows.contains { $0.id == .newFeature(feature) },
                         "the nested row for \(feature.rawValue) opens a page of its own")
            suite.expect(!sections.yourFeatures.contains { $0.id == .newFeature(feature) },
                         "\(feature.rawValue) is not repeated as a row of its own above its parent")
        }

        // A nested row is the same surface as the Settings row it is filed
        // under, so it reads that row's name. One window must not print one
        // surface under two names. SettingsSidebarSupport puts a tool row under
        // its page row and titles it for the surface ("Clipboard history") while
        // the catalog calls the feature "Clipboard", so the sidebar here is the
        // one Settings builds: a page row plus a row per tool.
        let titled = items + [SettingsSidebarItem(
            id: .feature(.clipboardHistory),
            destination: AppFeature.clipboardHistory.settingsDestination,
            title: "Clipboard history", icon: "doc.on.clipboard")]
        let titledSections = WhatsNewSupport.sections(
            digest: ReleaseDigest(previousVersion: "3.4.4", version: "3.4.5", versions: ["3.4.5"],
                                  summary: nil, changes: []),
            newFeatures: tagged, sidebarItems: titled, isAvailable: { _ in true },
            title: { $0.rawValue }, generalTitle: "General")
        let pairs = titledSections.yourFeatures.flatMap { parent in parent.children.map { (parent, $0) } }
            .filter { $0.0.feature == $0.1.feature }
        suite.expect(!pairs.isEmpty, "at least one new feature is filed under the row it belongs to")
        for (parent, child) in pairs {
            suite.expect(child.title == parent.title,
                         "the nested row reads its Settings row's title (\(child.title) vs \(parent.title))")
        }
        let resolved = WhatsNewSupport.titles(of: titledSections.yourFeatures, sidebarItems: titled,
                                             title: { $0.rawValue }, generalTitle: "General")
        for (parent, child) in pairs {
            suite.expect(resolved[child.id] == resolved[parent.id],
                         "a language change keeps the pair named one way")
        }

        // A feature that is both new and changed keeps one row, and a line it
        // shares with a feature already on that page reads once, on the nested
        // row, rather than under both.
        let changed = ReleaseChange(text: "Pauses history from the panel.", kind: .changed,
                                    version: "3.4.5", features: [.clipboardHistory])
        let shared = ReleaseChange(text: "Pastes without formatting.", kind: .changed,
                                   version: "3.4.5", features: [.clipboardHistory, .pastePlain])
        // Named apart from the `sections` value above: an inner `func sections`
        // loses the name to the enclosing `let`, and every call then reads as
        // "cannot call value of non-function type 'WhatsNewSections'".
        func built(for newFeatures: [AppFeature]) -> WhatsNewSections {
            WhatsNewSupport.sections(
                digest: ReleaseDigest(previousVersion: "3.4.4", version: "3.4.5", versions: ["3.4.5"],
                                      summary: nil, changes: [changed, shared]),
                newFeatures: newFeatures, sidebarItems: items, isAvailable: { _ in true },
                title: { $0.rawValue }, generalTitle: "General")
        }
        func clipboardPage(of sections: WhatsNewSections) -> WhatsNewRow? {
            sections.yourFeatures.first { $0.id == .settings(.page(.clipboard)) }
        }
        // Without the feature being new, both lines land on the Clipboard row.
        suite.expect(clipboardPage(of: built(for: []))?.changes == [changed, shared],
                     "the Clipboard page reads both lines when nothing is new")
        let both = built(for: [.clipboardHistory])
        suite.expect(clipboardPage(of: both)?.children.first?.changes == [changed, shared],
                     "the nested row reads the lines that name the new feature")
        suite.expect(clipboardPage(of: both)?.changes.isEmpty == true,
                     "no line prints on both the parent row and the nested one")
        suite.expect(both.newFeatures.map(\.id) == [.newFeature(.clipboardHistory)],
                     "the overview counts a new and changed feature once")
    }

    // MARK: Reading one line

    /// `YYYY-MM-DDTHH:MMZ`, or with seconds. The marker's date is what a person
    /// reads, so it is required to carry a time and a zone.
    private static func becameNewAt(in text: String) -> Date? {
        let separators = Set(" \t,;()[]`".map { $0 })
        for word in text.split(whereSeparator: { separators.contains($0) }) {
            let token = word.trimmingCharacters(in: CharacterSet(charactersIn: ".!*"))
            guard token.count >= 17,
                  token.contains("T"), token.hasSuffix("Z"),
                  token.first?.isNumber == true else { continue }
            return iso8601.date(from: secondsFilled(token))
        }
        return nil
    }

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// `2026-11-26T10:57Z` reads as `2026-11-26T10:57:00Z`. One formatter reads
    /// both, and a stamp that is not a date still fails to parse.
    private static func secondsFilled(_ token: String) -> String {
        guard token.range(of: "T\\d\\d:\\d\\dZ", options: .regularExpression) != nil else {
            return token
        }
        return token.replacingOccurrences(of: "Z", with: ":00Z")
    }

    /// The feature named in backticks, which is the `AppFeature` raw value the
    /// tag itself uses.
    private static func backtickedName(in text: String) -> String? {
        guard let open = text.firstIndex(of: "`"),
              let close = text[text.index(after: open)...].firstIndex(of: "`") else { return nil }
        return String(text[text.index(after: open)..<close])
    }

    /// The line without its bold title, its backticked name and its date.
    private static func changeText(in text: String) -> String {
        var rest = Substring(text)
        if let date = rest.range(of: "New as of", options: .backwards) {
            rest = rest[..<date.lowerBound]
        }
        if let open = rest.firstIndex(of: "`"),
           let close = rest[rest.index(after: open)...].firstIndex(of: "`") {
            rest = rest[rest.index(after: close)...].drop { ":) -\t".contains($0) }
        }
        return rest.trimmingCharacters(in: .whitespaces.union(.punctuationCharacters))
    }

    private static func folded(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .lowercased()
    }
}

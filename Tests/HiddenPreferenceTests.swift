// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The hidden preference catalog: the data behind the TinkerTool-style browser.
enum HiddenPreferenceTests {
    static func run(_ suite: TestSuite) {
        let core = HiddenPreferenceCatalog.core
        suite.expect(!core.isEmpty, "the catalog starts with entries")
        suite.expect(HiddenPreferenceCatalog.duplicatedIdentifiers().isEmpty,
                     "no domain and key pair appears twice")

        suite.expect(core.allSatisfy { $0.identifier.contains(":") },
                     "every entry has a domain-qualified identifier")
        suite.expect(core.allSatisfy { !$0.domain.isEmpty && !$0.key.isEmpty },
                     "every entry names a domain and a key")
        suite.expect(core.allSatisfy { HiddenPreferenceKind.allCases.contains($0.kind) },
                     "every entry uses a known value kind")

        let duplicate = HiddenPreference(domain: "com.apple.finder",
                                         key: "AppleShowAllFiles",
                                         kind: .boolean)
        let duplicates = HiddenPreferenceCatalog.duplicatedIdentifiers(core + [duplicate])
        suite.expect(duplicates == ["com.apple.finder:AppleShowAllFiles"],
                     "a repeated domain and key is reported")

        let kinds = Set(core.map(\.kind))
        suite.expect(kinds.contains(.boolean) && kinds.contains(.integer) && kinds.contains(.string),
                     "the catalog exercises all three kinds")
    }
}

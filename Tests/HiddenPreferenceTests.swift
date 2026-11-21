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

        let testDomain = "com.vorssaint.tests.hiddenprefs"
        let provider: HiddenPreferenceStore.DefaultsProvider = { domain in
            domain == testDomain ? UserDefaults(suiteName: testDomain) : nil
        }
        let flag = HiddenPreference(domain: testDomain, key: "flag", kind: .boolean)
        let number = HiddenPreference(domain: testDomain, key: "number", kind: .integer)
        let text = HiddenPreference(domain: testDomain, key: "text", kind: .string)

        HiddenPreferenceStore.reset(flag, defaults: provider)
        HiddenPreferenceStore.reset(number, defaults: provider)
        HiddenPreferenceStore.reset(text, defaults: provider)

        suite.expect(HiddenPreferenceStore.value(of: flag, defaults: provider) == nil,
                     "an unwritten key reads as nothing rather than false")
        suite.expect(HiddenPreferenceStore.apply(.boolean(true), to: flag, defaults: provider),
                     "a boolean writes")
        suite.expect(HiddenPreferenceStore.value(of: flag, defaults: provider) == .boolean(true),
                     "a written boolean reads back")
        suite.expect(HiddenPreferenceStore.apply(.integer(42), to: number, defaults: provider),
                     "an integer writes")
        suite.expect(HiddenPreferenceStore.value(of: number, defaults: provider) == .integer(42),
                     "a written integer reads back")
        suite.expect(HiddenPreferenceStore.apply(.string("png"), to: text, defaults: provider),
                     "a string writes")
        suite.expect(HiddenPreferenceStore.value(of: text, defaults: provider) == .string("png"),
                     "a written string reads back")
        suite.expect(!HiddenPreferenceStore.apply(.string("wrong kind"), to: flag, defaults: provider),
                     "a value of the wrong kind is refused")
        suite.expect(HiddenPreferenceStore.reset(text, defaults: provider),
                     "a key can be reset")
        suite.expect(HiddenPreferenceStore.value(of: text, defaults: provider) == nil,
                     "reset removes the value")
        suite.expect(!HiddenPreferenceStore.apply(.boolean(true), to: flag, defaults: { _ in nil }),
                     "an unavailable domain refuses the write")
        suite.expect(HiddenPreferenceStore.snapshot([flag, number], defaults: provider).count == 2,
                     "a snapshot covers every requested preference")
    }
}

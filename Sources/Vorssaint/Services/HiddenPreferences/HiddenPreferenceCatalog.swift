// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The shape of a hidden preference value, which decides both the editor and the
/// writer used for it.
enum HiddenPreferenceKind: String, CaseIterable {
    case boolean
    case integer
    case string
}

/// One hidden system preference a person can change from inside Vorssaint.
/// Deliberately data, not behaviour: the browser reads it, the writer writes it,
/// and both stay free of per-key branching.
struct HiddenPreference: Equatable {
    let domain: String
    let key: String
    let kind: HiddenPreferenceKind

    var identifier: String { "\(domain):\(key)" }
}

/// The curated starting set for TinkerTool parity. Every entry is a real,
/// long-standing key; nothing here is guessed, and anything that cannot be read
/// back after writing does not belong in the list.
enum HiddenPreferenceCatalog {
    static let core: [HiddenPreference] = [
        HiddenPreference(domain: "com.apple.finder", key: "AppleShowAllFiles", kind: .boolean),
        HiddenPreference(domain: "com.apple.finder", key: "ShowPathbar", kind: .boolean),
        HiddenPreference(domain: "com.apple.finder", key: "ShowStatusBar", kind: .boolean),
        HiddenPreference(domain: "com.apple.finder", key: "_FXShowPosixPathInTitle", kind: .boolean),
        HiddenPreference(domain: "com.apple.dock", key: "autohide", kind: .boolean),
        HiddenPreference(domain: "com.apple.dock", key: "tilesize", kind: .integer),
        HiddenPreference(domain: "com.apple.dock", key: "magnification", kind: .boolean),
        HiddenPreference(domain: "com.apple.dock", key: "show-recents", kind: .boolean),
        HiddenPreference(domain: "com.apple.screencapture", key: "type", kind: .string),
        HiddenPreference(domain: "com.apple.screencapture", key: "disable-shadow", kind: .boolean),
        HiddenPreference(domain: "NSGlobalDomain", key: "AppleShowScrollBars", kind: .string),
        HiddenPreference(domain: "NSGlobalDomain", key: "NSAutomaticSpellingCorrectionEnabled", kind: .boolean),
        HiddenPreference(domain: "NSGlobalDomain", key: "KeyRepeat", kind: .integer),
        HiddenPreference(domain: "NSGlobalDomain", key: "InitialKeyRepeat", kind: .integer),
    ]

    /// Identifier strings that appear more than once. The browser keys its rows
    /// by this, so a duplicate would silently shadow a row.
    static func duplicatedIdentifiers(_ preferences: [HiddenPreference] = core) -> [String] {
        var seen = Set<String>()
        var duplicates = Set<String>()
        for preference in preferences {
            if !seen.insert(preference.identifier).inserted {
                duplicates.insert(preference.identifier)
            }
        }
        return duplicates.sorted()
    }
}

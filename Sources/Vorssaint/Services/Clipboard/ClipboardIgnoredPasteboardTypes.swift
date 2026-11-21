// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import Foundation

/// Pasteboard types the history must never record, beyond the concealed and
/// transient marks it always honours. Maccy exposes the same list so a password
/// manager's own type, or Universal Clipboard's `com.apple.is-remote-clipboard`,
/// can be left out without guessing at the content.
final class ClipboardIgnoredPasteboardTypes: ObservableObject {
    static let shared = ClipboardIgnoredPasteboardTypes()

    @Published private(set) var types: [String] = []

    private var lookup: Set<String> = []

    private init() {
        reload()
    }

    func reload() {
        let defaults = UserDefaults.standard
        let raw = defaults.stringArray(forKey: DefaultsKey.clipboardHistoryIgnoredPasteboardTypes) ?? []
        let sanitized = Defaults.sanitizedPasteboardTypeList(raw)
        if raw != sanitized {
            defaults.set(sanitized, forKey: DefaultsKey.clipboardHistoryIgnoredPasteboardTypes)
        }
        types = sanitized
        lookup = Set(sanitized)
    }

    func add(_ type: String) {
        let type = type.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !type.isEmpty, !types.contains(type) else { return }
        UserDefaults.standard.set(types + [type],
                                  forKey: DefaultsKey.clipboardHistoryIgnoredPasteboardTypes)
        reload()
    }

    func remove(_ type: String) {
        guard types.contains(type) else { return }
        UserDefaults.standard.set(types.filter { $0 != type },
                                  forKey: DefaultsKey.clipboardHistoryIgnoredPasteboardTypes)
        reload()
    }

    /// Whether any type on the pasteboard is on the list. Called once per
    /// capture check, so it answers from the cached set.
    func matches(_ pasteboardTypes: [String]) -> Bool {
        guard !lookup.isEmpty else { return false }
        return pasteboardTypes.contains { lookup.contains($0) }
    }
}

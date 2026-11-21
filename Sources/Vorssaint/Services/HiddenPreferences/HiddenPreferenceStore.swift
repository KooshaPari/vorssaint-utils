// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum HiddenPreferenceValue: Equatable {
    case boolean(Bool)
    case integer(Int)
    case string(String)
}

struct HiddenPreferenceSnapshot: Equatable {
    let preference: HiddenPreference
    let value: HiddenPreferenceValue?
}

/// Reads and writes catalogued hidden preferences through a defaults provider,
/// so the caller decides which domain store is used and tests can hand in their
/// own. Nothing here knows about any particular key.
enum HiddenPreferenceStore {
    typealias DefaultsProvider = (String) -> UserDefaults?

    static let systemDefaults: DefaultsProvider = { domain in
        UserDefaults(suiteName: domain)
    }

    /// The current value, or nil when the key has never been written. A boolean
    /// absent from the domain is nil, not false, which is why the existence of
    /// the object is checked before its value.
    static func value(of preference: HiddenPreference,
                      defaults: DefaultsProvider = systemDefaults) -> HiddenPreferenceValue? {
        guard let store = defaults(preference.domain) else { return nil }
        switch preference.kind {
        case .boolean:
            guard store.object(forKey: preference.key) != nil else { return nil }
            return .boolean(store.bool(forKey: preference.key))
        case .integer:
            guard store.object(forKey: preference.key) != nil else { return nil }
            return .integer(store.integer(forKey: preference.key))
        case .string:
            guard let text = store.string(forKey: preference.key) else { return nil }
            return .string(text)
        }
    }

    static func snapshot(_ catalog: [HiddenPreference],
                         defaults: DefaultsProvider = systemDefaults) -> [HiddenPreferenceSnapshot] {
        catalog.map { HiddenPreferenceSnapshot(preference: $0, value: value(of: $0, defaults: defaults)) }
    }

    /// Writes a value and reports whether the domain store accepted it. Reading
    /// it back is the caller's job: some keys are honoured only after the owning
    /// app relaunches, so a successful write is not proof the setting took.
    @discardableResult
    static func apply(_ value: HiddenPreferenceValue,
                      to preference: HiddenPreference,
                      defaults: DefaultsProvider = systemDefaults) -> Bool {
        guard let store = defaults(preference.domain) else { return false }
        switch (preference.kind, value) {
        case (.boolean, .boolean(let flag)): store.set(flag, forKey: preference.key)
        case (.integer, .integer(let number)): store.set(number, forKey: preference.key)
        case (.string, .string(let text)): store.set(text, forKey: preference.key)
        default: return false
        }
        return true
    }

    /// Removes the key so the system default applies again.
    @discardableResult
    static func reset(_ preference: HiddenPreference,
                      defaults: DefaultsProvider = systemDefaults) -> Bool {
        guard let store = defaults(preference.domain) else { return false }
        store.removeObject(forKey: preference.key)
        return true
    }
}

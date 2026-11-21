// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// TinkerTool-style browser over the catalogued hidden system preferences.
/// Every write is followed by a re-read, so a key the system refuses to store
/// shows as unset again instead of looking applied.
struct HiddenPreferencesBrowser: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var snapshot: [HiddenPreferenceSnapshot] = []

    private var text: HiddenPreferenceStrings {
        FeatureStrings.hiddenPreferences(l10n.language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text.title)
                .font(.callout)
                .fontWeight(.medium)
            Text(text.caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(snapshot, id: \.preference.identifier) { entry in
                row(entry)
            }
        }
        .onAppear { refresh() }
    }

    private func row(_ entry: HiddenPreferenceSnapshot) -> some View {
        HStack(spacing: 8) {
            Text(entry.preference.key)
                .font(.system(size: 11, design: .monospaced))
                .frame(minWidth: 220, alignment: .leading)
            control(for: entry)
            if entry.value == nil {
                Text(text.unset)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 6)
            Button(text.reset) {
                HiddenPreferenceStore.reset(entry.preference)
                refresh()
            }
            .buttonStyle(.link)
            .font(.caption)
        }
    }

    @ViewBuilder
    private func control(for entry: HiddenPreferenceSnapshot) -> some View {
        switch entry.preference.kind {
        case .boolean:
            Toggle("", isOn: Binding(
                get: { if case .boolean(let flag)? = entry.value { return flag } else { return false } },
                set: { write(.boolean($0), to: entry.preference) }
            ))
            .labelsHidden()
        case .integer:
            TextField("", value: Binding(
                get: { if case .integer(let number)? = entry.value { return number } else { return 0 } },
                set: { write(.integer($0), to: entry.preference) }
            ), format: .number)
            .frame(width: 70)
        case .string:
            TextField("", text: Binding(
                get: { if case .string(let text)? = entry.value { return text } else { return "" } },
                set: { write(.string($0), to: entry.preference) }
            ))
            .frame(width: 130)
        }
    }

    private func write(_ value: HiddenPreferenceValue, to preference: HiddenPreference) {
        HiddenPreferenceStore.apply(value, to: preference)
        refresh()
    }

    private func refresh() {
        snapshot = HiddenPreferenceStore.snapshot(HiddenPreferenceCatalog.core)
    }
}

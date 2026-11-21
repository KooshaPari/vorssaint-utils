// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The pasteboard types the history never saves from, beyond the concealed and
/// transient marks it always honours. Sits with the other choices about what
/// gets saved, and stays quiet until there is a type in it.
struct ClipboardIgnoredTypesList: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var ignored = ClipboardIgnoredPasteboardTypes.shared
    @State private var draft = ""

    private var text: ClipboardIgnoredTypesStrings {
        FeatureStrings.clipboardIgnoredTypes(l10n.language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text.listTitle)
                .font(.callout)
                .fontWeight(.medium)
            Text(text.caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                TextField(text.addButton, text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                Button(action: add) {
                    Text(text.addButton)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            ForEach(ignored.types, id: \.self) { type in
                HStack(spacing: 8) {
                    Text(type)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                    Spacer(minLength: 6)
                    Button(text.removeButton) { ignored.remove(type) }
                        .buttonStyle(.link)
                        .font(.caption)
                }
            }
        }
    }

    private func add() {
        ignored.add(draft)
        draft = ""
    }
}

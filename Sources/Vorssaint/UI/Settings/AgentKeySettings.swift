// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The OpenCode Go keys the AI page accounts per key, under the OpenCode row
/// in the Dynamic Island settings. A key is entered once through a secure
/// field, saved to the login keychain, and only its masked row is shown after
/// that; the field is cleared as soon as the key is stored.
struct AgentKeySettings: View {
    @ObservedObject private var l10n = L10n.shared
    @StateObject private var keys = AgentKeyProvisioner()
    @State private var label = ""
    @State private var secret = ""

    private var text: AgentKeyStrings { FeatureStrings.agentKeys(l10n.language) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(alignment: .leading, spacing: 10) {
                Text(text.title).font(.subheadline.weight(.medium))
                Text(text.explanation)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if keys.isEmpty {
                    Text(text.emptyHint).font(.caption).foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(keys.rows) { row in
                            rowView(row, now: context.date)
                        }
                    }
                }
                entry
                if let error = keys.lastError {
                    Text(text.message(error))
                        .font(.caption).foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear { keys.refresh() }
    }

    /// One masked key, with the health and usage the registry has recorded.
    private func rowView(_ row: AgentKeyUsageRow, now: Date) -> some View {
        let health = row.health.resolved(at: now)
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol(health))
                .foregroundStyle(tint(health))
                .frame(width: 16)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.maskedLabel).accessibilityLabel(row.maskedLabel)
                Text(text.health(health)).font(.caption).foregroundStyle(tint(health))
                Text(text.usage(tokens: AgentFormat.tokens(row.tokens.total),
                                requests: row.requests.formatted()))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if health.isBad {
                Button(text.reset) { keys.reset(row.id) }
            }
            Button { keys.remove(row.id) } label: { Image(systemName: "minus.circle") }
                .buttonStyle(.plain)
                .help(text.remove)
                .accessibilityLabel(text.remove + ": " + row.maskedLabel)
        }
    }

    /// The one place a key is typed. The secure field masks it while it is
    /// entered, and both fields clear once the key is saved.
    private var entry: some View {
        HStack(spacing: 8) {
            TextField(text.labelPlaceholder, text: $label)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 160)
                .accessibilityLabel(text.labelPlaceholder)
            SecureField(text.secretPlaceholder, text: $secret)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(text.secretPlaceholder)
            Button(text.add) {
                guard keys.add(label: label, secret: secret) else { return }
                label = ""
                secret = ""
            }
            .disabled(secret.isEmpty)
        }
    }

    private func symbol(_ health: AgentKeyHealth) -> String {
        switch health {
        case .ready: return "key.fill"
        case .rateLimited: return "clock.fill"
        case .invalid, .exhausted: return "exclamationmark.triangle.fill"
        }
    }

    private func tint(_ health: AgentKeyHealth) -> Color {
        switch health {
        case .ready: return .secondary
        case .rateLimited: return .orange
        case .invalid, .exhausted: return .red
        }
    }
}

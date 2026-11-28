// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// What the agents have spent, over a period a person can choose.
///
/// The island's spend card is sized for a glance. This is the same reading with
/// room for the breakdown behind it: who spent it, which model, which project.
/// It reads the published snapshot and nothing else, so it cannot disagree with
/// the island.
struct NotchAgentsUsageSection: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var usage = AgentUsageService.shared
    @AppStorage(DefaultsKey.notchAgentsDailyBudget) private var dailyBudget = 0.0
    @State private var period = AgentPeriod.today

    private var text: NotchAgentStrings { FeatureStrings.notchAgents(l10n.language) }
    private var locale: Locale { l10n.language.formattingLocale() }
    private var snapshot: AgentUsageSnapshot { usage.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack {
                Text(text.spendCard).font(.subheadline.weight(.medium))
                Spacer()
                Picker("", selection: $period) {
                    ForEach(AgentPeriod.allCases) { option in
                        Text(label(option)).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 190)
                .accessibilityLabel(text.spendCard)
            }

            if !snapshot.loaded {
                Text(text.loading).font(.caption).foregroundStyle(.secondary)
            } else {
                let reading = snapshot.usage(period)
                if reading.total.requests == 0, reading.total.tokens.total == 0 {
                    Text(text.empty).font(.caption).foregroundStyle(.secondary)
                } else {
                    headline(reading)
                    providerRows(reading)
                    shareList(text.modelsCard, reading.models)
                    shareList(text.projectsCard, reading.projects)
                    if !reading.fullyPriced {
                        Text(text.unpriced).font(.caption).foregroundStyle(.secondary)
                    }
                    budget(reading)
                }
            }
        }
        // The period is the page's own state, so it survives a redraw but not
        // a preference: nothing here writes a default.
        .accessibilityElement(children: .contain)
    }

    private func label(_ option: AgentPeriod) -> String {
        switch option {
        case .today: return text.today
        case .week: return text.week
        case .month: return text.month
        }
    }

    /// Cost when every request carried a price, tokens otherwise, so the
    /// headline never adds dollars to tokens. The same rule the shares use.
    private func headline(_ reading: AgentPeriodUsage) -> some View {
        let byCost = reading.fullyPriced && reading.total.cost > 0
        let value = byCost ? AgentFormat.cost(reading.total.cost, locale: locale)
            : AgentFormat.tokens(reading.total.tokens.total, locale: locale)
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(value).font(.title2.weight(.semibold)).monospacedDigit()
            Text(text.tokens(AgentFormat.tokens(reading.total.tokens.total, locale: locale)))
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            if reading.total.savings > 0 {
                Text(text.saved(AgentFormat.cost(reading.total.savings, locale: locale)))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func providerRows(_ reading: AgentPeriodUsage) -> some View {
        let byCost = reading.fullyPriced && reading.total.cost > 0
        let total = reading.total.weight(byCost: byCost)
        let rows = AgentProvider.allCases
            .compactMap { provider -> ProviderShare? in
                guard let totals = reading.byProvider[provider], totals.requests > 0
                    || totals.tokens.total > 0 || totals.cost > 0 else { return nil }
                return ProviderShare(provider: provider, totals: totals)
            }
            .sorted { $0.totals.weight(byCost: byCost) > $1.totals.weight(byCost: byCost) }
        return ForEach(rows) { row in
            let provider = row.provider
            let totals = row.totals
            let share = total > 0 ? totals.weight(byCost: byCost) / total : 0
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(provider.displayName).font(.callout)
                    Spacer()
                    Text(byCost ? AgentFormat.cost(totals.cost, locale: locale)
                         : AgentFormat.tokens(totals.tokens.total, locale: locale))
                        .font(.callout).monospacedDigit().foregroundStyle(.secondary)
                }
                ProgressView(value: min(max(share, 0), 1))
                    .tint(provider.tint)
            }
            .help("\(provider.displayName) · \(text.tokens(AgentFormat.tokens(totals.tokens.total, locale: locale))) · "
                  + "\(AgentFormat.cost(totals.cost, locale: locale))")
        }
    }

    /// The largest few of a breakdown, which is what fits and what a person
    /// would read. The rest is a long tail the island already summarises.
    private func shareList(_ title: String, _ shares: [AgentShare]) -> some View {
        let shown = shares.prefix(5)
        return Group {
            if !shown.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    ForEach(shown) { share in
                        HStack {
                            Text(share.name).font(.caption).lineLimit(1)
                            Spacer()
                            Text(AgentFormat.tokens(share.totals.tokens.total, locale: locale))
                                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                            Text(AgentFormat.cost(share.totals.cost, locale: locale))
                                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                                .frame(width: 62, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    /// Only for today: a weekly total against a daily budget would read as an
    /// overspend that has not happened.
    private func budget(_ reading: AgentPeriodUsage) -> some View {
        Group {
            if dailyBudget > 0, period == .today {
                let left = dailyBudget - reading.total.cost
                HStack {
                    Text(text.budgetTitle).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(left >= 0 ? text.left(AgentFormat.cost(max(0, left), locale: locale))
                         : text.usedShare(AgentFormat.cost(reading.total.cost, locale: locale)))
                        .font(.caption).foregroundStyle(left >= 0 ? Color.secondary : Color.red)
                }
            }
        }
    }
}

/// One provider's slice of a period, so a sorted list keeps its identity.
private struct ProviderShare: Identifiable {
    let provider: AgentProvider
    let totals: AgentTotals
    var id: AgentProvider { provider }
}

/// The sessions this Mac's agents have written, and the tail of the one chosen.
///
/// The list is metadata only. A session's text is read when it is opened, from
/// the last few megabytes, and a line that carries an environment snapshot or a
/// system prompt is dropped rather than shown.
struct NotchAgentsSessionsSection: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var entries: [AgentSessionEntry] = []
    @State private var selection: String?
    @State private var preview: [AgentTranscriptLine] = []
    @State private var read = false

    private var text: NotchAgentStrings { FeatureStrings.notchAgents(l10n.language) }
    /// A list this long is a list a page can show without its own window.
    private let shown = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack {
                Text(text.session).font(.subheadline.weight(.medium))
                Spacer()
                Text(entries.isEmpty ? "" : "\(entries.count)")
                    .font(.caption).foregroundStyle(.secondary)
                Button {
                    reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help(text.session)
            }

            if !read {
                Text(text.loading).font(.caption).foregroundStyle(.secondary)
            } else if entries.isEmpty {
                Text(text.noSession).font(.caption).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(entries.prefix(shown)) { entry in
                            row(entry)
                        }
                    }
                }
                .frame(height: 150)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))

                if preview.isEmpty {
                    Text(text.empty).font(.caption).foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(preview) { line in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: line.isUser ? "person.fill" : "sparkles")
                                        .font(.caption2)
                                        .foregroundStyle(line.isUser ? Color.secondary : Color.accentColor)
                                        .frame(width: 12)
                                    Text(line.text)
                                        .font(.caption)
                                        .textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                    if line.truncated {
                                        Text("…").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 170)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
                }
            }
        }
        .onAppear { if !read { reload() } }
    }

    private func row(_ entry: AgentSessionEntry) -> some View {
        let chosen = entry.id == selection
        return Button {
            selection = entry.id
            preview = AgentTranscript.read(entry.url)
        } label: {
            HStack(spacing: 6) {
                Circle().fill(entry.live ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 5, height: 5)
                Text(entry.harness).font(.caption2).foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .leading)
                Text(entry.title).font(.caption).lineLimit(1)
                Spacer()
                Text(entry.modified.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(chosen ? Color.accentColor.opacity(0.18) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(entry.url.path)
    }

    /// Read on demand, off the main thread's critical path only in the sense
    /// that matters: a few hundred file attributes, not file contents.
    private func reload() {
        let sources = AgentSessionSource.defaults(home: FileManager.default.homeDirectoryForCurrentUser)
        // A turned-off agent is not listed, the same rule the cards follow.
        let allowed = Set(enabledHarnesses())
        let filtered = sources.filter { allowed.contains($0.harness) }
        let found = AgentSessionCatalog.read(filtered)
        entries = found
        read = true
        if let first = found.first?.id {
            selection = first
            preview = AgentTranscript.read(found[0].url)
        } else {
            selection = nil
            preview = []
        }
    }

    private func enabledHarnesses() -> [String] {
        let defaults = UserDefaults.standard
        var names: [String] = []
        if defaults.object(forKey: DefaultsKey.notchAgentsClaude) as? Bool ?? true { names.append("claude") }
        if defaults.object(forKey: DefaultsKey.notchAgentsCodex) as? Bool ?? true { names.append("codex") }
        if defaults.object(forKey: DefaultsKey.notchAgentsCopilot) as? Bool ?? true { names.append("copilot") }
        if defaults.object(forKey: DefaultsKey.notchAgentsJCode) as? Bool ?? true { names.append("jcode") }
        return names
    }
}

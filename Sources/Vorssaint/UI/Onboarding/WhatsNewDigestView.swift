// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The post-update window: what changed, feature by feature, laid out like the
/// Settings window. Rows are fixed when the window opens, so installing a
/// feature from here does not move the list under the pointer.
struct WhatsNewDigestView: View {
    let digest: ReleaseDigest
    var availableSize: CGSize
    let retitle: () -> [WhatsNewRow.ID: String]
    let onOpenSettings: () -> Void
    let onFinish: () -> Void

    let sections: WhatsNewSections

    @ObservedObject private var l10n = L10n.shared
    @State private var selection: Selection? = .overview
    @State private var unread: Set<WhatsNewRow.ID>
    @State private var showsNotInstalled = false
    /// What the person typed into the search field. Blank shows the window as
    /// it opens, so nothing is hidden until something is asked for.
    @State private var query = ""
    @State private var titles: [WhatsNewRow.ID: String] = [:]

    private enum Selection: Hashable {
        case overview
        case row(WhatsNewRow.ID)
    }

    init(digest: ReleaseDigest, sections: WhatsNewSections,
         availableSize: CGSize = NSScreen.pointerVisibleFrame.size,
         retitle: @escaping () -> [WhatsNewRow.ID: String] = { [:] },
         onOpenSettings: @escaping () -> Void, onFinish: @escaping () -> Void) {
        self.digest = digest
        self.availableSize = availableSize
        self.retitle = retitle
        self.onOpenSettings = onOpenSettings
        self.onFinish = onFinish
        self.sections = sections
        _unread = State(initialValue: Set((sections.newFeatures + sections.yourFeatures).map(\.id)))
    }

    private var text: WhatsNewStrings { FeatureStrings.whatsNew(l10n.language) }

    var body: some View {
        let size = WhatsNewLayout.size(in: availableSize)
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebar
                // The window does not resize, so the sidebar has one width,
                // a little wider than Settings' for longer feature names.
                .navigationSplitViewColumnWidth(230)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        }
        .navigationSplitViewStyle(.balanced)
        // The columns stay as they are, so a sidebar button would do nothing.
        // Removed here, on the split view: on the sidebar it also drops the
        // column width.
        .toolbar(removing: .sidebarToggle)
        .frame(width: size.width, height: size.height)
        .onExitCommand(perform: onFinish)
        .onChange(of: selection) { _, selected in
            if case .row(let id) = selected { unread.remove(id) }
        }
        .onChange(of: l10n.language) { _, _ in titles = retitle() }
    }

    private func title(of row: WhatsNewRow) -> String { titles[row.id] ?? row.title }

    /// The rows a search keeps. An empty query keeps everything.
    private var filtered: WhatsNewSections { sections.searching(query) }

    /// The moment a feature became new, in the reader's language, or nil for a
    /// feature that is not new, so callers never have to ask twice.
    private func newAsOfText(for row: WhatsNewRow) -> String? {
        guard row.isNew, let feature = row.feature else { return nil }
        return NewFeatureBadges.newAsOfText(for: feature, locale: l10n.language.formattingLocale())
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            searchField
            List(selection: $selection) {
                versionRow
                    .tag(Selection.overview)
                if filtered.isEmpty(for: query) {
                    Text(String(format: text.searchNoMatchFormat, query))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !filtered.yourFeatures.isEmpty {
                    Section(text.yourFeatures) {
                        ForEach(filtered.yourFeatures) { row in
                            sidebarRow(row, installed: true)
                            // What this build adds reads under the row it
                            // belongs to, rather than in a group of its own.
                            ForEach(row.children) { child in
                                sidebarRow(child, installed: true, nested: true)
                            }
                        }
                    }
                }
                if !filtered.notInstalled.isEmpty {
                    // Collapsed until asked for. The sidebar's own disclosure,
                    // unlike a header button, also opens from VoiceOver.
                    // Searching opens it, so a match in there can be seen.
                    Section(isExpanded: notInstalledExpanded) {
                        ForEach(filtered.notInstalled) { sidebarRow($0, installed: false) }
                    } header: {
                        Text(text.notInstalled)
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }

    /// Open while a search is running, otherwise as the person left it.
    private var notInstalledExpanded: Binding<Bool> {
        Binding(get: { showsNotInstalled || !query.isEmpty },
                set: { showsNotInstalled = $0 })
    }

    /// Filters the list as it is typed. Local only: nothing leaves the window.
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(text.searchPlaceholder, text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                // A field on its own has no label VoiceOver can announce, so
                // the field's own words become its name.
                .accessibilityLabel(text.searchPlaceholder)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(l10n.s.actionClear)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var versionRow: some View {
        HStack(spacing: 9) {
            BrandBadge(size: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(AppInfo.name) \(digest.version)")
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                if let previous = digest.previousVersion {
                    Text(String(format: text.updatedFromFormat, previous))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 3)
    }

    private func sidebarRow(_ row: WhatsNewRow, installed: Bool, nested: Bool = false) -> some View {
        let isSelected = selection == .row(row.id)
        let isUnread = unread.contains(row.id)
        let moment = newAsOfText(for: row).map { String(format: text.newAsOfFormat, $0) }
        let spoken = [row.isNew ? text.newFeatures : nil, isUnread ? text.updated : nil, moment]
            .compactMap { $0 }
        return HStack(spacing: 9) {
            Image(systemName: row.icon)
                .foregroundStyle(isSelected ? AnyShapeStyle(.primary)
                    : installed ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .frame(width: 18)
            Text(title(of: row))
                .foregroundStyle(installed || isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
            if row.isNew {
                KnuTag()
            }
            Spacer(minLength: 4)
            if isUnread {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
            }
        }
        // Indented under its parent row, the way a Settings sub-page reads.
        .padding(.leading, nested ? 18 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityValue(spoken.joined(separator: ", "))
        .tag(Selection.row(row.id))
        .help(title(of: row))
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        if case .row(let id) = selection, let row = filtered.allRows.first(where: { $0.id == id }) {
            WhatsNewFeaturePage(row: row, title: title(of: row), onOpenSettings: onOpenSettings)
                .id(row.id)
        } else {
            overview
        }
    }

    private var overview: some View {
        let changes = sections.changesForYou
        let counts = WhatsNewSupport.grouped(Array(changes))
        return ScrollView {
            VStack(spacing: 22) {
                BrandBadge(size: 64)
                    .accessibilityHidden(true)
                VStack(spacing: 4) {
                    Text("\(AppInfo.name) \(digest.version)")
                        .font(.system(size: 26, weight: .bold))
                    if let previous = digest.previousVersion {
                        Text(String(format: text.updatedFromFormat, previous))
                            .foregroundStyle(.secondary)
                    }
                }
                if !counts.isEmpty {
                    HStack(spacing: 40) {
                        ForEach(counts) { item in
                            VStack(spacing: 2) {
                                Text("\(item.changes.count)")
                                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                Text(WhatsNewDigestView.title(of: item.kind, text))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                if let summary = digest.summary {
                    Text(summary)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 460)
                }
                Text(text.chooseFeatureHint)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .padding(.top, 44)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Spacer()
                Button(l10n.s.supportIntroDoneButton, action: onFinish)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    static func title(of kind: ReleaseChangeKind, _ text: WhatsNewStrings) -> String {
        switch kind {
        case .new: return text.kindNew
        case .changed: return text.kindChanged
        case .fixed: return text.kindFixed
        }
    }
}

/// One feature's changes, in a grouped form like a Settings page.
private struct WhatsNewFeaturePage: View {
    let row: WhatsNewRow
    let title: String
    let onOpenSettings: () -> Void

    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared

    private var text: WhatsNewStrings { FeatureStrings.whatsNew(l10n.language) }
    private var hub: FeatureHubStrings { FeatureStrings.hub(l10n.language) }

    /// When this feature became new, written for the reader's language, or nil
    /// for a feature that is not new.
    private var newAsOfMoment: String? {
        guard row.isNew, let feature = row.feature else { return nil }
        return NewFeatureBadges.newAsOfText(for: feature, locale: l10n.language.formattingLocale())
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: row.icon)
                        .font(.system(size: 24))
                        .foregroundStyle(.tint)
                        .frame(width: 34)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.title2.bold())
                        // When this feature became new, straight under the name
                        // someone just searched for.
                        if let moment = newAsOfMoment {
                            Text(String(format: text.newAsOfFormat, moment))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let feature = row.feature {
                            Text(feature.hubDescription(hub))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 12)
                    action
                }
                .padding(.vertical, 4)
            }
            ForEach(WhatsNewSupport.grouped(row.changes)) { group in
                Section(WhatsNewDigestView.title(of: group.kind, text)) {
                    ForEach(group.changes, id: \.self) { change in
                        changeRow(change)
                    }
                }
            }
            // A row that took in a new feature reads it here too, so opening
            // the parent row never lands on a page with nothing on it.
            ForEach(row.children.filter { !$0.changes.isEmpty }) { child in
                Section(child.title) {
                    ForEach(WhatsNewSupport.grouped(child.changes)) { group in
                        ForEach(group.changes, id: \.self) { change in
                            changeRow(change)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func changeRow(_ change: ReleaseChange) -> some View {
        let parts = change.parts
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            if change.kind == .new {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(parts.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let path = parts.settingsPath {
                    Text(path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .textSelection(.enabled)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var action: some View {
        if let feature = row.feature, !feature.isAvailable {
            installButton(feature)
        } else if let destination = row.destination {
            Button(FeatureStrings.commandBar(l10n.language).actionOpenSettings) {
                SettingsRouter.shared.request(destination, sidebarFeature: row.feature)
                onOpenSettings()
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private func installButton(_ feature: AppFeature) -> some View {
        if let reason = feature.installBlockedReason {
            // .help() never fires on a disabled control, so it sits on a wrapper.
            HStack(spacing: 0) {
                Button(hub.installButton) {}
                    .buttonStyle(.bordered)
                    .disabled(true)
                    .accessibilityLabel("\(hub.installButton) \(title). \(reason)")
            }
            .help(reason)
        } else if row.isNewFeature {
            Button(hub.installButton) { install(feature) }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("\(hub.installButton) \(title)")
        } else {
            Button(hub.installButton) { install(feature) }
                .buttonStyle(.bordered)
                .accessibilityLabel("\(hub.installButton) \(title)")
        }
    }

    private func install(_ feature: AppFeature) {
        withAnimation(.easeOut(duration: 0.22)) {
            FeatureRuntime.shared.setAvailable([feature], true)
        }
    }
}

enum WhatsNewLayout {
    /// Close to the Settings window's own minimum, and never larger than the
    /// screen it opens on.
    static func size(in available: CGSize) -> CGSize {
        CGSize(width: min(800, max(1, available.width - 32)),
               height: min(560, max(1, available.height - 32)))
    }
}

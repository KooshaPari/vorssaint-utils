// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Marks features that gained something in this build. The tag is deliberately
/// terse (`KNU`) and untranslated: it is a build marker, not prose, and it is
/// meant to be spotted at a glance in the list rather than read.
enum NewFeatureBadges {
    /// Tagged for this build:
    /// - clipboard history: paste without formatting (⌥-click, ⌥⇧↩, menu item)
    ///   and a persisted pause.
    static let tagged: Set<AppFeature> = [.clipboardHistory]

    static func isNew(_ feature: AppFeature) -> Bool {
        tagged.contains(feature)
    }
}

/// The tag itself, small enough to sit beside a feature title.
struct KnuTag: View {
    var body: some View {
        Text("KNU")
            .font(.system(size: 8, weight: .heavy, design: .rounded))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .foregroundStyle(Color.green)
            .background(Capsule().fill(Color.green.opacity(0.16)))
            .accessibilityLabel("New in this build")
            .accessibilityHidden(true)
    }
}

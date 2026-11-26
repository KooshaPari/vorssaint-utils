// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
import SwiftUI

/// Marks features that gained something in this build. The tag is deliberately
/// terse (`KNU`) and untranslated: it is a build marker, not prose, and it is
/// meant to be spotted at a glance in the list rather than read.
enum NewFeatureBadges {
    /// Tagged for this build:
    /// - clipboard history: paste without formatting (⌥-click, ⌥⇧↩, menu item)
    ///   and a persisted pause.
    ///
    /// The changelog's `### What's KNU` list reads only what a person sees, so
    /// the maintenance rule lives here instead of in that section: the tag and
    /// the list must name the same features. `NewFeatureBadgesTests` fails when
    /// one is added without the other, in either direction.
    static let tagged: Set<AppFeature> = [.clipboardHistory]

    /// When each tagged feature became new, as the changelog writes it under
    /// `### What's KNU`. The tag says *which* features are new; this says
    /// *when*, so the window can show the moment instead of hiding it in the
    /// changelog. `NewFeatureBadgesTests` keeps the two sections in step: a tag
    /// without a stamp, a stamp without a tag, or a stamp that drifted from the
    /// changelog all fail.
    static let newAsOf: [AppFeature: String] = [
        .clipboardHistory: "2026-11-26T10:57Z",
    ]

    static func isNew(_ feature: AppFeature) -> Bool {
        tagged.contains(feature)
    }

    /// The moment a feature became new, or nil when it is not tagged as new.
    static func newAsOfDate(_ feature: AppFeature) -> Date? {
        newAsOf[feature].flatMap(newAsOfDate(iso8601:))
    }

    /// Reads the changelog's own `yyyy-MM-ddTHH:mmZ` spelling. Parsed by hand
    /// rather than with a shared formatter: the value is a fixed UTC instant,
    /// and a formatter's locale would make the parse depend on the reader.
    static func newAsOfDate(iso8601 raw: String) -> Date? {
        let halves = raw.split(separator: "T")
        guard halves.count == 2, halves[1].hasSuffix("Z") else { return nil }
        let day = halves[0].split(separator: "-").compactMap { Int($0) }
        let clock = halves[1].dropLast().split(separator: ":").compactMap { Int($0) }
        guard day.count == 3, clock.count >= 2 else { return nil }
        var components = DateComponents()
        components.year = day[0]
        components.month = day[1]
        components.day = day[2]
        components.hour = clock[0]
        components.minute = clock[1]
        components.second = clock.count > 2 ? clock[2] : 0
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return Calendar(identifier: .gregorian).date(from: components)
    }

    /// The moment written the way the reader's language writes a moment. The
    /// window never prints the raw stamp: `2026-11-26T10:57Z` is for the
    /// changelog, not for a person reading a list.
    static func newAsOfText(for feature: AppFeature, locale: Locale = .current,
                            timeZone: TimeZone = .current) -> String? {
        guard let date = newAsOfDate(feature) else { return nil }
        return date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened,
                                               locale: locale, timeZone: timeZone))
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

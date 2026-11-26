// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Exercises the Now Playing failure reporter and the two call sites that use
/// it. The reporter is Foundation-only, so its de-duplication runs for real on
/// any node; the call sites are read as source because both live in files that
/// import AppKit and cannot be compiled here.
enum NowPlayingBridgeTests {
    static func run(_ suite: TestSuite) {
        suite.run("now-playing-failure-reporting") {
            let reporter = NowPlayingBridgeFailureReporter()
            var lines: [String] = []

            suite.expect(reporter.report(.assetsMissing) { lines.append($0) },
                         "the first failure of a class is written")
            suite.expect(lines.count == 1, "one line for the first failure, got \(lines.count)")
            suite.expect(lines.first?.contains("assetsMissing") == true,
                         "the line names the failure class")
            suite.expect(lines.first?.contains("missing") == true,
                         "the line carries a human summary, not just the class")

            // The wheel asks on every open and the notch polls while visible, so
            // a repeat must be silent or the log stops being read.
            suite.expect(!reporter.report(.assetsMissing) { lines.append($0) },
                         "a repeated failure of the same class is not written again")
            suite.expect(lines.count == 1, "the repeat added no line, got \(lines.count)")

            suite.expect(reporter.report(.timedOut) { lines.append($0) },
                         "a different class is written even without a success between")
            suite.expect(lines.count == 2, "the class change added one line, got \(lines.count)")

            // A readable reply proves the channel recovered, so the same class
            // failing again later must be reported rather than swallowed.
            reporter.recordSuccess()
            suite.expect(reporter.lastReportedFailure == nil,
                         "a success clears the last reported class")
            suite.expect(reporter.report(.timedOut) { lines.append($0) },
                         "the same class after a success is written again")
            suite.expect(lines.count == 3, "the post-success failure added one line, got \(lines.count)")

            // Every case must be printable and distinct, or two failures read
            // as one in the log.
            let summaries = NowPlayingBridgeFailure.allCases.map(\.summary)
            suite.expect(summaries.allSatisfy { !$0.isEmpty },
                         "every failure class has a summary")
            suite.expect(Set(summaries).count == NowPlayingBridgeFailure.allCases.count,
                         "no two failure classes share a summary")

            // "Nothing is playing" must not be a class: it is the normal case
            // and would turn a quiet player into a logged fault.
            let names = NowPlayingBridgeFailure.allCases.map(\.rawValue)
            suite.expect(!names.contains("noSession"),
                         "the normal no-playback state is not a reportable failure")
        }

        // Both bridges used to collapse every outcome into `nil`/`connectionEnded`,
        // so a missing bundled adapter and an idle player looked identical. These
        // checks are the reason a future edit cannot quietly return to that.
        suite.run("now-playing-failure-call-sites") {
            for (label, relative, expected) in [
                ("radial bridge",
                 "Sources/Vorssaint/Services/RadialMenu/RadialNowPlayingService.swift",
                 [".assetsMissing", ".processFailed", ".timedOut", ".malformedReply"]),
                ("notch bridge",
                 "Sources/Vorssaint/Services/Notch/NotchMusicService.swift",
                 [".assetsMissing"]),
            ] {
                guard let source = sourceText(relative) else {
                    suite.expect(false, "\(label): source not found at \(relative)")
                    continue
                }
                for failure in expected {
                    suite.expect(source.contains("reportFailure(\(failure))"),
                                 "\(label): reports \(failure) instead of failing silently")
                }
                suite.expect(source.contains("NowPlayingBridgeFailureReporter.shared.report("),
                             "\(label): routes through the de-duplicating reporter")
                suite.expect(source.contains("privacy: .public"),
                             "\(label): the line is readable in Console.app without a debugger")
            }
        }
    }

    static func sourceText(_ relative: String) -> String? {
        var roots: [String] = []
        let fileDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        roots.append(fileDir.deletingLastPathComponent().path)
        roots.append(FileManager.default.currentDirectoryPath)
        for root in roots {
            let candidate = URL(fileURLWithPath: root).appendingPathComponent(relative).path
            if let text = try? String(contentsOfFile: candidate, encoding: .utf8) {
                return text
            }
        }
        return nil
    }
}

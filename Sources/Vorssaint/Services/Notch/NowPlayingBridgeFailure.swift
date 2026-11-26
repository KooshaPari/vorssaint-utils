// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Why the Now Playing bridge produced nothing.
///
/// The bridge runs `/usr/bin/perl` over a bundled adapter library, because
/// MediaRemote answers platform binaries and not the app. It had several ways
/// to fail and every one arrived as the same `nil`: the wheel drew an empty
/// card, the notch showed no track, and nothing was written anywhere, so a
/// broken channel and an idle player were indistinguishable from the outside.
///
/// "Nothing is playing" is deliberately absent. It is the normal case, it must
/// stay silent, and giving it a case would invite it into the log.
enum NowPlayingBridgeFailure: String, CaseIterable {
    /// The script or the adapter library is not in the bundle.
    case assetsMissing
    /// perl ran and exited unsuccessfully.
    case processFailed
    /// perl did not answer inside the reply deadline.
    case timedOut
    /// The reply arrived but could not be read.
    case malformedReply

    var summary: String {
        switch self {
        case .assetsMissing:
            return "the bundled adapter script or library is missing"
        case .processFailed:
            return "the adapter process exited unsuccessfully"
        case .timedOut:
            return "the adapter process exceeded its reply deadline"
        case .malformedReply:
            return "the adapter reply could not be read"
        }
    }
}

/// Reports a failure class when it changes, and stays quiet when it repeats.
///
/// The wheel asks for a snapshot every time it opens and the notch polls while
/// it is visible, so a channel that is broken writes one line rather than one
/// per request. The log sink is injected, which keeps this Foundation-only and
/// lets the de-duplication be exercised without a Mac or a log stream.
final class NowPlayingBridgeFailureReporter {
    static let shared = NowPlayingBridgeFailureReporter()

    private let lock = NSLock()
    private var lastReported: NowPlayingBridgeFailure?

    init() {}

    /// Returns whether the failure was written, so a caller (or a test) can
    /// assert a quiet repeat without reaching into private state.
    @discardableResult
    func report(_ failure: NowPlayingBridgeFailure, to sink: (String) -> Void) -> Bool {
        lock.lock()
        let changed = lastReported != failure
        lastReported = failure
        lock.unlock()
        guard changed else { return false }
        sink("Now Playing: \(failure.rawValue) - \(failure.summary)")
        return true
    }

    /// A readable reply proves the channel works, so the next failure is
    /// reported even when it is the same class as the last one. Without this a
    /// channel that breaks every other hour logs once a day.
    func recordSuccess() {
        lock.lock()
        lastReported = nil
        lock.unlock()
    }

    /// The class last written. `nil` means nothing has been reported since the
    /// last success.
    var lastReportedFailure: NowPlayingBridgeFailure? {
        lock.lock()
        defer { lock.unlock() }
        return lastReported
    }
}

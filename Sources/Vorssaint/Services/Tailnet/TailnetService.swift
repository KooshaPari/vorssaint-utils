// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import Foundation

/// Reads the local Tailscale node through its own CLI. Nothing is assumed
/// about Tailscale being present: a missing binary, a stopped daemon or a node
/// that is not logged in are all reported as their own unavailable state, and
/// only a running backend produces a peer list.
final class TailnetService: ObservableObject {
    static let shared = TailnetService()

    @Published private(set) var availability: TailnetAvailability
    @Published private(set) var isRefreshing = false
    @Published private(set) var hasLoadedOnce = false

    private let workQueue = DispatchQueue(label: "com.vorssaint.utils.tailnet")

    init(availability: TailnetAvailability = .unavailable(.notInstalled)) {
        self.availability = availability
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        workQueue.async {
            let result = Self.probe()
            DispatchQueue.main.async {
                self.availability = result
                self.hasLoadedOnce = true
                self.isRefreshing = false
            }
        }
    }

    /// One bounded status read. The process is killed at the runner's timeout,
    /// and the result is classified by `TailnetSupport`, so a killed or
    /// unparsable command never turns into an empty live peer list.
    static func probe() -> TailnetAvailability {
        let cliPath = TailnetSupport.locateCLI { FileManager.default.isExecutableFile(atPath: $0) }
        return TailnetSupport.availability(cliPath: cliPath) { path, arguments, timeout in
            let result = Shell.run(path, arguments, timeout: timeout, maxOutputBytes: 512 * 1024)
            return (result.status, result.output)
        }
    }

    /// The bind address a listener may use, or the named refusal. Callers must
    /// publish the refusal instead of falling back to another scope.
    static func bindHost(requested: String,
                         availability: TailnetAvailability? = nil) -> TailnetBindResolution {
        TailnetSupport.resolveBind(requested, availability: availability ?? shared.availability)
    }
}

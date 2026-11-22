// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Where the HC core keeps its state and listens. Injected, so nothing is
/// guessed at the point of use and a test can point at a temporary directory.
struct HerdrCoreLocation: Equatable {
    /// The directory holding `terminals.json`: `%LOCALAPPDATA%\herdr-core\default`
    /// on the Windows host the contract was verified on, and the matching
    /// `Application Support` directory on a Mac.
    let stateDirectory: URL
    /// The socket a core listens on, when one is named. Naming it proves
    /// nothing: only a connect does.
    let endpoint: String?
    /// The `hc` command, resolved through `PATH` unless configured.
    let command: String

    var terminalsFile: URL { stateDirectory.appendingPathComponent("terminals.json") }

    static func standard(environment: [String: String] = ProcessInfo.processInfo.environment,
                         applicationSupport: URL? = nil) -> HerdrCoreLocation {
        let directory: URL
        if let local = environment["LOCALAPPDATA"], !local.isEmpty {
            directory = URL(fileURLWithPath: local, isDirectory: true)
                .appendingPathComponent("herdr-core/default", isDirectory: true)
        } else {
            let base = applicationSupport
                ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
            directory = base.appendingPathComponent("herdr-core/default", isDirectory: true)
        }
        // The core names its own endpoint in a managed pane. A stale value
        // only costs a failed connect, and the next liveness step then has
        // its turn; `HERDR_*` is deliberately never consulted here.
        let named = environment["HC_TERMINAL_SOCKET"].flatMap { $0.isEmpty ? nil : $0 }
        let endpoint = named ?? directory.appendingPathComponent("core.sock").path
        return HerdrCoreLocation(stateDirectory: directory, endpoint: endpoint, command: "hc")
    }
}

/// The HC backend: herdr-core 0.1.21, the only herdr generation this app
/// ships. Liveness is probed in one order and only through transports: the
/// core's socket, then `hc server status`, then the freshness of its state
/// file. The reader is structurally read-only: its only command is
/// `hc server status`, and it never addresses a screen.
///
/// Polled from one queue, like the log readers it sits beside.
final class HerdrCoreBackend: HerdrPaneSource {
    let backend: HerdrPaneBackend = .herdrCore
    let capabilities = HerdrPaneCapabilities.herdrCore
    let location: HerdrCoreLocation
    /// How long a connect may take before the next step has its turn.
    let connectTimeout: TimeInterval
    /// How long `hc server status` may run before it is killed.
    let commandTimeout: TimeInterval
    /// How recently `terminals.json` must have been written to stand in for a
    /// transport. The core rewrites it on every change, so an idle core can
    /// leave it older than this; that is why it is only the last step.
    let freshnessWindow: TimeInterval

    private let probes: HerdrTransportProbes
    /// The last snapshot that decoded, so a file being replaced between its
    /// stat and its read never turns into an empty fleet.
    private var lastGood: (rows: [AgentPaneState], stamp: Date)?
    private var lastDecode: (stamp: Date, size: Int, rows: [AgentPaneState])?

    init(location: HerdrCoreLocation,
         probes: HerdrTransportProbes = .live,
         connectTimeout: TimeInterval = 0.5,
         commandTimeout: TimeInterval = 2,
         freshnessWindow: TimeInterval = 120) {
        self.location = location
        self.probes = probes
        self.connectTimeout = connectTimeout
        self.commandTimeout = commandTimeout
        self.freshnessWindow = freshnessWindow
    }

    func probe(now: Date) -> HerdrPaneProbe {
        if let endpoint = location.endpoint,
           probes.socket.canConnect(to: endpoint, timeout: connectTimeout) {
            return HerdrPaneProbe(step: .socket, availability: .live)
        }
        let command = HerdrCommand(executable: location.command, arguments: ["server", "status"])
        if let result = probes.command.run(command, timeout: commandTimeout),
           HerdrServerStatus.decode(result) != nil {
            return HerdrPaneProbe(step: .command, availability: .live)
        }
        if let stamp = stateAttributes()?.stamp, withinWindow(stamp, now) {
            return HerdrPaneProbe(step: .snapshot, availability: .snapshot)
        }
        return .unavailable
    }

    func reading(now: Date) -> HerdrPaneReading {
        let probe = probe(now: now)
        switch probe.availability {
        case .live, .snapshot:
            if let snapshot = decodeStateFile(remember: true) {
                return HerdrPaneReading(availability: probe.availability, rows: snapshot.rows,
                                        readAt: snapshot.stamp, capabilities: capabilities)
            }
            // The file is being replaced or is unreadable. Keep the last
            // snapshot that decoded rather than publishing an empty fleet.
            if let good = lastGood {
                return HerdrPaneReading(availability: probe.availability, rows: good.rows,
                                        readAt: good.stamp, capabilities: capabilities)
            }
            // A live transport whose state cannot be read publishes nothing at
            // all, never an empty list as if it were a live fleet.
            return HerdrPaneReading(availability: .unavailable, rows: [], readAt: nil,
                                    capabilities: capabilities)
        case .stale, .unavailable:
            // No transport answered. A core that is gone can still have left a
            // state file: its rows are shown as stale, never as a live fleet.
            if let snapshot = decodeStateFile(remember: false) {
                return HerdrPaneReading(availability: .stale, rows: snapshot.rows,
                                        readAt: snapshot.stamp, capabilities: capabilities)
            }
            return HerdrPaneReading(availability: .unavailable, rows: [], readAt: nil,
                                    capabilities: capabilities)
        }
    }

    private struct Snapshot {
        let rows: [AgentPaneState]
        let stamp: Date
    }

    private func withinWindow(_ stamp: Date, _ now: Date) -> Bool {
        // A clock that disagrees with the file's writer must not make an old
        // snapshot look fresh, so the window is symmetric.
        now.timeIntervalSince(stamp) <= freshnessWindow && stamp.timeIntervalSince(now) <= freshnessWindow
    }

    private func stateAttributes() -> (stamp: Date, size: Int)? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: location.terminalsFile.path),
              let stamp = attributes[.modificationDate] as? Date else { return nil }
        let size = (attributes[.size] as? NSNumber)?.intValue ?? 0
        return (stamp, size)
    }

    private func decodeStateFile(remember: Bool) -> Snapshot? {
        guard let before = stateAttributes() else { return nil }
        if let cached = lastDecode, cached.stamp == before.stamp, cached.size == before.size {
            if remember { lastGood = (cached.rows, cached.stamp) }
            return Snapshot(rows: cached.rows, stamp: cached.stamp)
        }
        guard let data = try? Data(contentsOf: location.terminalsFile) else { return nil }
        // The writer replaces the file rather than appending to it, so a
        // stat-read pair can straddle the replacement. A stamp that moved
        // underneath the read rejects the bytes and keeps the last good one.
        guard let after = stateAttributes(), after.stamp == before.stamp, after.size == before.size else {
            return nil
        }
        guard let rows = HerdrTerminalFile.decode(data, observedAt: before.stamp) else { return nil }
        lastDecode = (before.stamp, before.size, rows)
        if remember { lastGood = (rows, before.stamp) }
        return Snapshot(rows: rows, stamp: before.stamp)
    }
}

/// The shape of `hc server status`. Only a core that answered is a live core:
/// an error document is not, and neither is anything unparsable.
struct HerdrServerStatus: Equatable {
    let version: String?
    let live: Int?
    let finished: Int?

    static func decode(_ result: HerdrCommandResult) -> HerdrServerStatus? {
        guard result.status == 0 else { return nil }
        return decode(result.standardOutput)
    }

    static func decode(_ data: Data) -> HerdrServerStatus? {
        guard let object = AgentLogObject(data), object.object("error") == nil,
              object.object("core") != nil, object.value("pid") != nil else { return nil }
        return HerdrServerStatus(version: object.string("version"),
                                 live: integer(object.value("live")),
                                 finished: integer(object.value("finished")))
    }

    private static func integer(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        return value as? Int
    }
}

/// The shape of the core's `terminals.json`. Only the fields a pane reports
/// about itself are indexed: address, state, status, labels, foreground and
/// title. `screens/*.snap` holds terminal contents and is a different file
/// this decoder never opens.
enum HerdrTerminalFile {
    static func decode(_ data: Data, observedAt: Date) -> [AgentPaneState]? {
        guard let root = AgentLogObject(data), let terminals = root.object("terminals") else { return nil }
        var rows: [String: AgentPaneState] = [:]
        for member in terminals.members().values {
            guard let row = record(member, observedAt: observedAt) else { continue }
            rows[row.id] = row
        }
        return rows.values.sorted { $0.id < $1.id }
    }

    private static func record(_ object: AgentLogObject, observedAt: Date) -> AgentPaneState? {
        guard let address = object.string("address"), !address.isEmpty else { return nil }
        let labels = object.object("labels")
        let foreground = object.object("foreground")
        let argv = (foreground?.value("argv") as? [String]) ?? []
        let program = foreground?.string("name")
        // A peer's terminal arrives as `machine/tN`; the machine is part of the
        // address and is never dropped to leave a colliding bare id.
        let machine = address.firstIndex(of: "/").flatMap { index -> String? in
            let prefix = String(address[address.startIndex..<index])
            return prefix.isEmpty ? nil : prefix
        }
        return AgentPaneState(
            id: address,
            machine: machine,
            address: address,
            provider: HerdrPaneIdentity.provider(name: program, argv: argv),
            program: program,
            argv: argv,
            title: object.string("title"),
            space: labels?.string("herdr.space"),
            tab: labels?.string("herdr.tab"),
            place: labels?.string("where"),
            lifecycle: .decode(object.string("state")),
            status: .decode(object.string("status")),
            observedAt: observedAt)
    }
}

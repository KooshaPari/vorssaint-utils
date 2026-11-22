// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// One herdr pane, as the pane itself reports it. herdr is a terminal
/// workspace manager: a pane's program reports its lifecycle over OSC 7501,
/// and the core keeps that beside the terminal record. Nothing here is read
/// from a pane's screen.
///
/// A pane is not a turn. `AgentLiveSession` means an agent working on a turn
/// and carries tokens and cost; a pane can be idle, blocked or finished and
/// reports neither. This row is therefore held apart from `live` and never
/// reaches spend or trend totals.
struct AgentPaneState: Equatable, Identifiable {
    /// The full address, `t7` on this core or `mac/t1` from a peer, so two
    /// machines' terminals never collide. Never the bare terminal id.
    let id: String
    /// The peer named by a `machine/tN` address; nil on this core.
    let machine: String?
    /// The address exactly as herdr reported it.
    let address: String
    /// The agent this pane's foreground program names, when it is one the
    /// island knows. Nil for a shell, a wrapper or an unknown binary: the
    /// island does not guess.
    let provider: AgentProvider?
    /// `foreground.name`: the program running now, e.g. `kcode.exe`.
    let program: String?
    /// `foreground.argv`, which names a resumed session when there is one.
    let argv: [String]
    /// The pane's own title line, reported by herdr; never read from a screen.
    let title: String?
    /// The space and tab the pane belongs to, as herdr labels them. A core
    /// writes ids here; a reader that also has the app's list can resolve them.
    let space: String?
    let tab: String?
    /// `labels.where`, e.g. `Projects / Sloppa`.
    let place: String?
    /// `state`: whether the terminal is still running.
    let lifecycle: AgentPaneLifecycle
    /// `status`: what the program reported, `.unknown` when it reported none.
    let status: AgentPaneStatus
    /// When the reading that produced this row was taken.
    let observedAt: Date

    /// The token a program passed to its own `--resume`, read out of its argv.
    /// Mechanical, not an identity: herdr reports no agent-session channel to
    /// confirm it.
    var resumeToken: String? { HerdrPaneIdentity.resumeToken(in: argv) }

    /// Whether the program itself asked for attention.
    var needsAttention: Bool { status.needsAttention }
}

/// `state` in herdr's vocabulary. It is not `status`: a live pane can be idle,
/// and a finished one can be done. The two are never folded together.
enum AgentPaneLifecycle: String, Equatable, CaseIterable {
    case live, finished, unknown

    /// herdr writes `live` or `finished`. Anything else, including a missing
    /// field, is unknown and is never taken for live.
    static func decode(_ value: String?) -> AgentPaneLifecycle {
        guard let value, !value.isEmpty else { return .unknown }
        return AgentPaneLifecycle(rawValue: value.lowercased()) ?? .unknown
    }
}

/// `status` in herdr's vocabulary, reported by the program itself over OSC
/// 7501. A plain program reports none, and a pane is never assumed working.
enum AgentPaneStatus: String, Equatable, CaseIterable {
    case idle, working, done, blocked, error, unknown

    /// `null` is a program that reported nothing. It is unknown, never idle.
    static func decode(_ value: String?) -> AgentPaneStatus {
        guard let value, !value.isEmpty else { return .unknown }
        return AgentPaneStatus(rawValue: value.lowercased()) ?? .unknown
    }

    /// Only the two states the program raises to ask for a person.
    var needsAttention: Bool { self == .blocked || self == .error }
}

/// What a backend can report. herdr-core reports pane lifecycle but has no
/// agent-session channel and no token counts, so a session token can only come
/// from a program's own argv and a pane row is never priced.
struct HerdrPaneCapabilities: Equatable {
    let reportsPaneState: Bool
    let reportsAgentSession: Bool
    let reportsUsage: Bool

    /// herdr-core 0.1.21: OSC 7501 pane state, no session channel, no tokens.
    static let herdrCore = HerdrPaneCapabilities(reportsPaneState: true,
                                                 reportsAgentSession: false,
                                                 reportsUsage: false)
}

/// What backs a reading.
enum HerdrPaneAvailability: String, Equatable {
    /// A transport answered this poll: the core's socket or its own status.
    case live
    /// No transport answered, but the state file was written recently.
    case snapshot
    /// No transport and no fresh file: rows from an older snapshot, shown as
    /// stale rather than as a live fleet.
    case stale
    /// Nothing publishable. Never an empty fleet dressed as a live one.
    case unavailable
}

/// One published reading. A failed read keeps the last snapshot that decoded,
/// so the instant a state file is replaced never empties the island.
struct HerdrPaneReading: Equatable {
    var availability: HerdrPaneAvailability
    /// Pane rows, keyed by the full address and sorted by it.
    var rows: [AgentPaneState]
    /// When these rows were last decoded; nil when there are none.
    var readAt: Date?
    var capabilities: HerdrPaneCapabilities

    static let unavailable = HerdrPaneReading(availability: .unavailable, rows: [],
                                              readAt: nil, capabilities: .herdrCore)

    func rows(for provider: AgentProvider) -> [AgentPaneState] {
        rows.filter { $0.provider == provider }
    }

    /// The panes whose program asked for attention.
    var attention: [AgentPaneState] { rows.filter(\.needsAttention) }
}

/// Which herdr generation answered. Only the HC rewrite is shipped; the seam
/// leaves room for another backend without changing its callers.
enum HerdrPaneBackend: String, Equatable {
    case herdrCore = "herdr-core"
}

/// The liveness probe's result and the step that answered it.
struct HerdrPaneProbe: Equatable {
    enum Step: String, Equatable {
        case socket, command, snapshot, none
    }

    let step: Step
    let availability: HerdrPaneAvailability

    static let unavailable = HerdrPaneProbe(step: .none, availability: .unavailable)
}

/// A backend that reports herdr panes. The transport differs by generation
/// (the HC core listens on a socket and keeps a state document); the seam does
/// not, so another backend can occupy it later without rework.
///
/// Polled from one queue. Implementations may keep the last good snapshot.
protocol HerdrPaneSource {
    var backend: HerdrPaneBackend { get }
    var capabilities: HerdrPaneCapabilities { get }
    /// Liveness by transport only: a socket that connects, the core's own
    /// status, or a state file written inside the freshness window.
    /// `HERDR_ENV` and `HERDR_*` are never evidence: they outlive their server.
    func probe(now: Date) -> HerdrPaneProbe
    /// What the backend sees, with the transport that backs it.
    func reading(now: Date) -> HerdrPaneReading
}

/// Mechanical identity for a pane: the executable its foreground names, and
/// the `--resume` token in that program's argv. herdr-core reports no
/// agent-session channel, so nothing stronger exists and nothing is guessed.
enum HerdrPaneIdentity {
    /// The agents whose own binaries can hold a pane's foreground.
    static let programs: [String: AgentProvider] = [
        "kcode": .jcode,
        "jcode": .jcode,
        "claude": .claude,
        "codex": .codex,
        "opencode": .opencode,
        "copilot": .copilot,
        "github-copilot": .copilot,
    ]

    /// The provider a foreground program names. A shell, a wrapper or an
    /// unknown binary has none: an open pane is never counted as an agent.
    static func provider(name: String?, argv: [String]) -> AgentProvider? {
        for candidate in [name, argv.first].compactMap({ $0 }) {
            if let provider = programs[executableName(candidate)] { return provider }
        }
        return nil
    }

    /// The last path component, without a Windows executable suffix.
    static func executableName(_ path: String) -> String {
        let name = path.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last.map(String.init) ?? path
        let lowered = name.lowercased()
        return lowered.hasSuffix(".exe") ? String(lowered.dropLast(4)) : lowered
    }

    /// The value after a bare `--resume`, or after `--resume=`. Nil when the
    /// flag has no value, so a truncated argv never yields a session token.
    static func resumeToken(in argv: [String]) -> String? {
        for (index, argument) in argv.enumerated() {
            if argument == "--resume" {
                guard index + 1 < argv.count else { return nil }
                let value = argv[index + 1]
                return value.hasPrefix("-") ? nil : value
            }
            if argument.hasPrefix("--resume=") {
                let value = argument.dropFirst("--resume=".count)
                return value.isEmpty ? nil : String(value)
            }
        }
        return nil
    }
}

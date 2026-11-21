// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// One key's non-secret identity, in pool order. The tail and the secret are
/// deliberately absent: the pool rebuilds the tail from the keychain, and the
/// secret never leaves it.
struct AgentKeyRecord: Equatable {
    let id: UUID
    let provider: String
    let label: String
}

/// Everything the registry keeps between launches. The keychain holds the
/// secrets, so this state can be plain JSON in the app's owner-only folder.
struct AgentKeyRegistryState: Equatable {
    var keys: [AgentKeyRecord] = []
    var cursor: UUID?
    var usages: [AgentKeyUsage] = []
}

/// Where the registry's non-secret state lives. A file another build wrote, or
/// a hand-edited one, reads as empty and the keys start over.
protocol AgentKeyRegistryStore {
    func load() -> AgentKeyRegistryState
    @discardableResult func save(_ state: AgentKeyRegistryState) -> Bool
}

/// The real store: one small JSON file beside the app's other private state.
struct JSONAgentKeyRegistryStore: AgentKeyRegistryStore {
    static let fileName = "AgentKeyRegistry.json"
    static let format = 1

    var directory: URL?
    var fileName = JSONAgentKeyRegistryStore.fileName

    init(directory: URL? = PrivateFileStore.containerURL) {
        self.directory = directory
    }

    private var url: URL? { directory?.appendingPathComponent(fileName) }

    func load() -> AgentKeyRegistryState {
        guard let url, let data = try? Data(contentsOf: url) else { return AgentKeyRegistryState() }
        return Self.decode(data)
    }

    @discardableResult
    func save(_ state: AgentKeyRegistryState) -> Bool {
        guard let directory, let url,
              PrivateFileStore.createDirectory(at: directory) else { return false }
        return PrivateFileStore.write(Self.encode(state), to: url)
    }

    static func encode(_ state: AgentKeyRegistryState) -> Data {
        let saved = Saved(
            format: format,
            keys: state.keys.map { Saved.Key(id: $0.id.uuidString, provider: $0.provider, label: $0.label) },
            cursor: state.cursor?.uuidString,
            usages: state.usages.sorted { $0.id.uuidString < $1.id.uuidString }.map { usage in
                Saved.Usage(id: usage.id.uuidString, input: usage.tokens.input,
                            cacheWrite: usage.tokens.cacheWrite, cacheRead: usage.tokens.cacheRead,
                            output: usage.tokens.output, reasoning: usage.tokens.reasoning,
                            requests: usage.requests, failures: usage.failures,
                            lastUsed: usage.lastUsed?.timeIntervalSince1970,
                            health: Saved.Usage.state(usage.health),
                            rateLimitedUntil: Saved.Usage.until(usage.health)?.timeIntervalSince1970)
            })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(saved)) ?? Data()
    }

    static func decode(_ data: Data) -> AgentKeyRegistryState {
        guard let saved = try? JSONDecoder().decode(Saved.self, from: data), saved.format == format else {
            return AgentKeyRegistryState()
        }
        let keys = saved.keys.compactMap { key -> AgentKeyRecord? in
            guard let id = UUID(uuidString: key.id) else { return nil }
            return AgentKeyRecord(id: id, provider: key.provider, label: key.label)
        }
        let cursor = saved.cursor.flatMap(UUID.init(uuidString:))
        let usages = saved.usages.compactMap { usage -> AgentKeyUsage? in
            guard let id = UUID(uuidString: usage.id) else { return nil }
            return AgentKeyUsage(id: id,
                                 tokens: AgentTokens(input: usage.input, cacheWrite: usage.cacheWrite,
                                                     cacheRead: usage.cacheRead, output: usage.output,
                                                     reasoning: usage.reasoning),
                                 requests: max(0, usage.requests), failures: max(0, usage.failures),
                                 lastUsed: usage.lastUsed.map(Date.init(timeIntervalSince1970:)),
                                 health: Saved.Usage.health(state: usage.health,
                                                            until: usage.rateLimitedUntil.map(Date.init(timeIntervalSince1970:))))
        }
        return AgentKeyRegistryState(keys: keys, cursor: cursor, usages: usages)
    }

    private struct Saved: Codable {
        var format: Int
        var keys: [Key]
        var cursor: String?
        var usages: [Usage]

        struct Key: Codable {
            var id: String
            var provider: String
            var label: String
        }

        struct Usage: Codable {
            var id: String
            var input: Int
            var cacheWrite: Int
            var cacheRead: Int
            var output: Int
            var reasoning: Int
            var requests: Int
            var failures: Int
            var lastUsed: TimeInterval?
            /// `ready`, `rateLimited`, `invalid` or `exhausted`.
            var health: String
            var rateLimitedUntil: TimeInterval?

            static func state(_ health: AgentKeyHealth) -> String {
                switch health {
                case .ready: return "ready"
                case .rateLimited: return "rateLimited"
                case .invalid: return "invalid"
                case .exhausted: return "exhausted"
                }
            }

            static func until(_ health: AgentKeyHealth) -> Date? {
                if case .rateLimited(let until) = health { return until }
                return nil
            }

            static func health(state: String, until: Date?) -> AgentKeyHealth {
                switch state {
                case "rateLimited": return .rateLimited(until: until ?? .distantPast)
                case "invalid": return .invalid
                case "exhausted": return .exhausted
                default: return .ready
                }
            }
        }
    }
}

/// Test double with the same contract, so routing and persistence behaviour
/// are exercised without writing to the app's folder.
final class InMemoryAgentKeyRegistryStore: AgentKeyRegistryStore {
    private(set) var state: AgentKeyRegistryState
    private(set) var saves = 0

    init(_ state: AgentKeyRegistryState = AgentKeyRegistryState()) {
        self.state = state
    }

    func load() -> AgentKeyRegistryState { state }

    @discardableResult
    func save(_ state: AgentKeyRegistryState) -> Bool {
        self.state = state
        saves += 1
        return true
    }
}

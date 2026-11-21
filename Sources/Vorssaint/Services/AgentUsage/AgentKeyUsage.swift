// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The provider names a saved key can belong to. Product names stay
/// untranslated, as elsewhere in the agents section.
enum AgentKeyProvider {
    static let openCodeGo = "opencode-go"
}

/// How a provider last answered a key. A rate limit lifts by itself; an
/// invalid or exhausted key stays out of rotation until it is replaced or
/// explicitly reset, so a request never retries a key known to be bad.
enum AgentKeyHealth: Equatable {
    case ready
    case rateLimited(until: Date)
    case invalid
    case exhausted

    /// Lasting badness: a key that is invalid or has no allowance left.
    var isBad: Bool {
        switch self {
        case .ready, .rateLimited: return false
        case .invalid, .exhausted: return true
        }
    }

    /// The health at `now`, so a rate limit that has run out reads ready.
    func resolved(at now: Date) -> AgentKeyHealth {
        if case .rateLimited(let until) = self, now >= until { return .ready }
        return self
    }

    func isSelectable(at now: Date) -> Bool {
        switch resolved(at: now) {
        case .ready: return true
        case .rateLimited, .invalid, .exhausted: return false
        }
    }
}

/// Why a request failed in a way that belongs to the key rather than to the
/// network or the provider's servers. Errors outside these cases leave the
/// key alone and rotate only for that one request.
enum AgentKeyFailure: Equatable {
    case rateLimited(until: Date?)
    case invalid
    case exhausted

    /// How long a 429 keeps a key out when the provider gives no Retry-After.
    static let defaultCooldown: TimeInterval = 60

    /// The key fault a status code describes, or nil when the request failed
    /// for a reason another key would not fix.
    static func classify(status: Int) -> AgentKeyFailure? {
        switch status {
        case 401, 403: return .invalid
        case 402: return .exhausted
        case 429: return .rateLimited(until: nil)
        default: return nil
        }
    }

    func health(at now: Date) -> AgentKeyHealth {
        switch self {
        case .rateLimited(let until):
            return .rateLimited(until: until ?? now.addingTimeInterval(Self.defaultCooldown))
        case .invalid: return .invalid
        case .exhausted: return .exhausted
        }
    }
}

/// What one key has spent. There is no secret here and no label: the pool
/// supplies those, so the ledger can be written to disk as it stands.
struct AgentKeyUsage: Equatable {
    let id: UUID
    var tokens = AgentTokens()
    var requests = 0
    var failures = 0
    var lastUsed: Date?
    var health: AgentKeyHealth = .ready
}

/// One masked row of per-key usage, in the shape the agents page publishes.
struct AgentKeyUsageRow: Equatable, Identifiable {
    let id: UUID
    let provider: String
    let label: String
    /// The last four characters only, masked as on the key list.
    let masked: String
    let tokens: AgentTokens
    let requests: Int
    let failures: Int
    let lastUsed: Date?
    let health: AgentKeyHealth

    /// The label and mask together, never the secret.
    var maskedLabel: String { "\(label) \(masked)" }

    func isSelectable(at now: Date) -> Bool { health.isSelectable(at: now) }
}

/// Per-key counters and health, and the rotation rule that follows from them.
/// Pure, so the decision of which key is next can be tested without a
/// keychain, a provider or a running app.
struct AgentKeyLedger: Equatable {
    private(set) var entries: [UUID: AgentKeyUsage] = [:]

    init(_ usages: [AgentKeyUsage] = []) {
        for usage in usages where entries[usage.id] == nil { entries[usage.id] = usage }
    }

    /// Entries in a stable order for writing.
    var all: [AgentKeyUsage] {
        entries.values.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    mutating func register(_ id: UUID) {
        if entries[id] == nil { entries[id] = AgentKeyUsage(id: id) }
    }

    mutating func forget(_ id: UUID) {
        entries[id] = nil
    }

    /// Attributes one answered request to the key that made it. A successful
    /// answer also lifts a rate limit the key has recovered from.
    mutating func record(_ id: UUID, tokens: AgentTokens, requests: Int = 1, at date: Date) {
        var usage = entries[id] ?? AgentKeyUsage(id: id)
        usage.tokens += tokens
        usage.requests += max(0, requests)
        usage.lastUsed = max(usage.lastUsed ?? .distantPast, date)
        usage.health = .ready
        entries[id] = usage
    }

    @discardableResult
    mutating func mark(_ failure: AgentKeyFailure, for id: UUID, at date: Date) -> Bool {
        guard var usage = entries[id] else { return false }
        usage.failures += 1
        usage.health = failure.health(at: date)
        entries[id] = usage
        return true
    }

    /// Brings a key back after the operator says it is usable again.
    mutating func reset(_ id: UUID) {
        entries[id]?.health = .ready
    }

    func usage(_ id: UUID) -> AgentKeyUsage? { entries[id] }

    func health(_ id: UUID, at now: Date) -> AgentKeyHealth {
        entries[id]?.health.resolved(at: now) ?? .ready
    }

    func isSelectable(_ id: UUID, at now: Date) -> Bool {
        entries[id]?.health.isSelectable(at: now) ?? true
    }

    /// The first selectable key after `current`, in pool order, wrapping at
    /// the end. Nil when every key is bad, so a caller stops instead of
    /// retrying one that is known to fail.
    func nextSelectable(after current: UUID?, in pool: AgentKeyPool, at now: Date) -> AgentKeyReference? {
        guard !pool.keys.isEmpty else { return nil }
        let index: Int
        if let current, let position = pool.keys.firstIndex(where: { $0.id == current }) {
            index = (position + 1) % pool.keys.count
        } else {
            index = 0
        }
        for offset in 0..<pool.keys.count {
            let key = pool.keys[(index + offset) % pool.keys.count]
            if isSelectable(key.id, at: now) { return key }
        }
        return nil
    }
}

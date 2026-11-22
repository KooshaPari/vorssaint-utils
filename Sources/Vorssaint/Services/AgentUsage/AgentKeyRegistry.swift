// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// One key resolved for a request. The secret lives in this value and nowhere
/// else; it has no description, debug or coding conformance, so nothing prints
/// it by accident.
struct AgentKeyRoute {
    let key: AgentKeyReference
    let secret: String

    var provider: String { key.provider }
    var masked: String { key.masked }
    /// The header a provider request carries. Never log the result.
    var authorization: String { "Bearer \(secret)" }
}

/// Keeps the key references, their secrets and their usage in step. Adding a
/// key writes the secret first and only then records the reference, so a failed
/// keychain write cannot leave a pool entry with no secret behind it. Removing
/// does the reverse order: the reference goes, then the secret.
///
/// The pool, the rotation cursor and the per-key counters are written to the
/// registry store; the secrets stay in the keychain. Every mutation takes the
/// state lock, because the AI page reads status on the main thread while
/// provider requests rotate keys on their own queue. The file is written after
/// that lock is released, so a reader never waits on disk.
final class AgentKeyRegistry {
    static let shared = AgentKeyRegistry(store: KeychainAgentSecretStore(),
                                         registryStore: JSONAgentKeyRegistryStore())

    /// Posted after usage, health or the pool changes, so the agents surface
    /// can publish a fresh snapshot without polling the registry.
    static let usageDidChange = Notification.Name("com.vorssaint.agent-key-usage-did-change")

    private let lock = NSLock()
    /// Serializes registry writes. `writtenRevision` is kept under this lock so
    /// a snapshot taken earlier can never overwrite a later one.
    private let writeLock = NSLock()
    private var stateRevision: UInt64 = 0
    private var writtenRevision: UInt64 = 0
    private var storedPool: AgentKeyPool
    private var ledger: AgentKeyLedger
    private let store: AgentSecretStore
    private let registryStore: AgentKeyRegistryStore

    /// The shortest secret accepted. Anything shorter is a paste mistake, not a
    /// provider key, and storing it would only fail later at request time.
    static let minimumSecretLength = 8

    init(pool: AgentKeyPool = AgentKeyPool(), store: AgentSecretStore,
         registryStore: AgentKeyRegistryStore = InMemoryAgentKeyRegistryStore()) {
        self.store = store
        self.registryStore = registryStore
        let saved = registryStore.load()
        var prune = false
        if pool.isEmpty, !saved.keys.isEmpty {
            // The tail is the only part of a key the pool shows, and it is
            // rebuilt from the keychain rather than written to disk.
            var references: [AgentKeyReference] = []
            var restorable = Set<UUID>()
            var unreadable: [UUID] = []
            for record in saved.keys {
                guard let secret = store.secret(for: record.id), !secret.isEmpty else {
                    unreadable.append(record.id)
                    continue
                }
                references.append(AgentKeyReference(id: record.id, provider: record.provider,
                                                    label: record.label, tail: String(secret.suffix(4))))
                restorable.insert(record.id)
            }
            let cursor = saved.cursor.flatMap { restorable.contains($0) ? $0 : nil }
            let usages = saved.usages.filter { restorable.contains($0.id) }
            storedPool = AgentKeyPool(keys: references, cursor: cursor)
            ledger = AgentKeyLedger(usages)
            // A record whose secret is gone cannot be used, and leaving it in
            // the file would keep a key id no launch can resolve. Write the
            // pruned state back, but only when every dropped record is
            // affirmatively missing: an unreadable keychain must not delete a
            // key that still exists.
            prune = (references.count != saved.keys.count
                     || usages.count != saved.usages.count
                     || (saved.cursor != nil && cursor == nil))
                    && unreadable.allSatisfy { store.isMissing(for: $0) }
        } else {
            storedPool = pool
            let known = Set(pool.keys.map(\.id))
            ledger = AgentKeyLedger(saved.usages.filter { known.contains($0.id) })
        }
        if prune { persistState() }
    }

    var pool: AgentKeyPool { lock.withLock { storedPool } }

    var isEmpty: Bool { lock.withLock { storedPool.isEmpty } }

    var maskedLabels: [String] { lock.withLock { storedPool.maskedLabels } }

    @discardableResult
    func addKey(provider: String, label: String, secret: String) -> AgentKeyReference? {
        let trimmed = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= Self.minimumSecretLength,
              !provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let id = UUID()
        guard store.set(trimmed, for: id) else { return nil }
        let reference = AgentKeyReference(id: id, provider: provider, label: label,
                                          tail: String(trimmed.suffix(4)))
        lock.withLock {
            storedPool.add(reference)
            ledger.register(id)
        }
        persistState()
        notifyUsageChanged()
        return reference
    }

    func removeKey(_ id: UUID) {
        lock.withLock {
            storedPool.remove(id)
            ledger.forget(id)
        }
        persistState()
        _ = store.remove(for: id)
        notifyUsageChanged()
    }

    func secret(for id: UUID) -> String? {
        store.secret(for: id)
    }

    /// The key the next request should use, following the rotation cursor and
    /// skipping any key marked bad. Unlike `nextRoute`, this reads no secret
    /// and moves no cursor.
    var nextKey: AgentKeyReference? {
        lock.withLock {
            ledger.nextSelectable(after: storedPool.cursor, in: storedPool, at: Date())
        }
    }

    /// Resolves the next usable key for one request and moves the cursor past
    /// it. A key whose secret cannot be read is skipped, and the rotation is
    /// bounded by the pool size so an unreadable keychain cannot spin.
    func nextRoute(at now: Date = Date()) -> AgentKeyRoute? {
        lock.lock()
        defer { lock.unlock() }
        let count = storedPool.keys.count
        guard count > 0 else { return nil }
        var cursor = storedPool.cursor
        for _ in 0..<count {
            guard let key = ledger.nextSelectable(after: cursor, in: storedPool, at: now) else { return nil }
            storedPool.select(key.id)
            cursor = key.id
            if let secret = store.secret(for: key.id), !secret.isEmpty {
                return AgentKeyRoute(key: key, secret: secret)
            }
        }
        return nil
    }

    /// Attributes one answered request to the key that made it. A successful
    /// answer also clears a rate limit the key has recovered from.
    func record(_ route: AgentKeyRoute, tokens: AgentTokens, requests: Int = 1, at date: Date) {
        let changed = lock.withLock { () -> Bool in
            guard storedPool.keys.contains(where: { $0.id == route.key.id }) else { return false }
            ledger.record(route.key.id, tokens: tokens, requests: requests, at: date)
            return true
        }
        guard changed else { return }
        persistState()
        notifyUsageChanged()
    }

    /// Marks the key behind a failed request as rate-limited, invalid or
    /// exhausted, so later rotation avoids it. Statuses that another key would
    /// not fix are ignored and leave the key ready.
    @discardableResult
    func reportFailure(_ route: AgentKeyRoute, status: Int, retryAfter: Date? = nil,
                       at date: Date = Date()) -> Bool {
        guard let failure = AgentKeyFailure.classify(status: status) else { return false }
        let effective: AgentKeyFailure
        if case .rateLimited = failure {
            effective = .rateLimited(until: retryAfter)
        } else {
            effective = failure
        }
        return report(effective, for: route.key.id, at: date)
    }

    @discardableResult
    func report(_ failure: AgentKeyFailure, for id: UUID, at date: Date = Date()) -> Bool {
        let changed = lock.withLock { () -> Bool in
            guard storedPool.keys.contains(where: { $0.id == id }) else { return false }
            guard ledger.mark(failure, for: id, at: date) else { return false }
            return true
        }
        guard changed else { return false }
        persistState()
        notifyUsageChanged()
        return changed
    }

    /// Brings a key back into rotation after the operator says it is usable.
    @discardableResult
    func resetKey(_ id: UUID) -> Bool {
        let changed = lock.withLock { () -> Bool in
            guard ledger.usage(id) != nil else { return false }
            ledger.reset(id)
            return true
        }
        guard changed else { return false }
        persistState()
        notifyUsageChanged()
        return changed
    }

    func usage(_ id: UUID) -> AgentKeyUsage? { lock.withLock { ledger.usage(id) } }

    func health(_ id: UUID, at now: Date = Date()) -> AgentKeyHealth {
        lock.withLock { ledger.health(id, at: now) }
    }

    /// The masked per-key rows the agents page publishes. No row carries a
    /// secret or anything derived from one beyond the existing four-character
    /// tail.
    func usageRows(at now: Date = Date()) -> [AgentKeyUsageRow] {
        lock.withLock {
            storedPool.keys.map { key in
                let usage = ledger.usage(key.id)
                return AgentKeyUsageRow(id: key.id, provider: key.provider, label: key.label,
                                        masked: key.masked, tokens: usage?.tokens ?? AgentTokens(),
                                        requests: usage?.requests ?? 0, failures: usage?.failures ?? 0,
                                        lastUsed: usage?.lastUsed,
                                        health: usage?.health.resolved(at: now) ?? .ready)
            }
        }
    }

    // MARK: Persistence

    /// The state as it stands. Runs under the state lock.
    private func stateLocked() -> AgentKeyRegistryState {
        AgentKeyRegistryState(
            keys: storedPool.keys.map { AgentKeyRecord(id: $0.id, provider: $0.provider, label: $0.label) },
            cursor: storedPool.cursor,
            usages: ledger.all)
    }

    /// Captures the state under the lock and writes it after releasing that
    /// lock, so the agents page reading rows on the main thread is never held
    /// behind the file. A revision pair under `writeLock` keeps an older
    /// snapshot from overwriting a newer one when two mutations race.
    private func persistState() {
        let snapshot = lock.withLock { () -> (revision: UInt64, state: AgentKeyRegistryState) in
            stateRevision &+= 1
            return (stateRevision, stateLocked())
        }
        writeLock.lock()
        defer { writeLock.unlock() }
        guard snapshot.revision > writtenRevision else { return }
        writtenRevision = snapshot.revision
        _ = registryStore.save(snapshot.state)
    }

    private func notifyUsageChanged() {
        NotificationCenter.default.post(name: Self.usageDidChange, object: nil)
    }
}

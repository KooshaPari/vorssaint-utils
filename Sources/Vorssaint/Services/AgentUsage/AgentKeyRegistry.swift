// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Keeps the key references and their secrets in step. Adding a key writes the
/// secret first and only then records the reference, so a failed keychain write
/// cannot leave a pool entry with no secret behind it. Removing does the
/// reverse order: the reference goes, then the secret.
final class AgentKeyRegistry {
    private(set) var pool: AgentKeyPool
    private let store: AgentSecretStore

    init(pool: AgentKeyPool = AgentKeyPool(), store: AgentSecretStore) {
        self.pool = pool
        self.store = store
    }

    /// The shortest secret accepted. Anything shorter is a paste mistake, not a
    /// provider key, and storing it would only fail later at request time.
    static let minimumSecretLength = 8

    @discardableResult
    func addKey(provider: String, label: String, secret: String) -> AgentKeyReference? {
        let trimmed = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= Self.minimumSecretLength else { return nil }
        let id = UUID()
        guard store.set(trimmed, for: id) else { return nil }
        let reference = AgentKeyReference(id: id,
                                          provider: provider,
                                          label: label,
                                          tail: String(trimmed.suffix(4)))
        pool.add(reference)
        return reference
    }

    func removeKey(_ id: UUID) {
        pool.remove(id)
        _ = store.remove(for: id)
    }

    func secret(for id: UUID) -> String? {
        store.secret(for: id)
    }

    /// The key the next request should use, following the rotation cursor.
    var nextKey: AgentKeyReference? {
        pool.next(after: pool.cursor)
    }

    var isEmpty: Bool { pool.isEmpty }
}

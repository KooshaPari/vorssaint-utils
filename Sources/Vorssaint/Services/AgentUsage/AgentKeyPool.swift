// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// A reference to one provider key. Only the tail is kept here: the secret
/// itself belongs in the keychain, and nothing in this model can print it.
struct AgentKeyReference: Equatable {
    let id: UUID
    let provider: String
    let label: String
    /// The last four characters, for telling two keys apart on screen.
    let tail: String

    var masked: String { "••••\(tail)" }
}

/// An ordered set of provider keys with a rotation cursor, the shape needed to
/// spread work across several OpenCode Go keys. Pure: it decides which key is
/// next, and the caller does the talking to the provider.
struct AgentKeyPool: Equatable {
    private(set) var keys: [AgentKeyReference]
    private(set) var cursor: UUID?

    init(keys: [AgentKeyReference] = [], cursor: UUID? = nil) {
        self.keys = keys
        self.cursor = cursor
    }

    var isEmpty: Bool { keys.isEmpty }

    /// Adds a key. A repeated id is ignored so a re-import cannot duplicate a
    /// key and skew the rotation.
    mutating func add(_ key: AgentKeyReference) {
        guard !keys.contains(where: { $0.id == key.id }) else { return }
        keys.append(key)
        if cursor == nil { cursor = key.id }
    }

    /// Removes a key and moves the cursor to whatever follows it, so removing
    /// the current key does not silently stop rotation.
    mutating func remove(_ id: UUID) {
        guard let index = keys.firstIndex(where: { $0.id == id }) else { return }
        keys.remove(at: index)
        guard let current = cursor else { return }
        if current == id {
            cursor = keys.isEmpty ? nil : keys[min(index, keys.count - 1)].id
        } else if keys.isEmpty {
            cursor = nil
        }
    }

    /// The key after `current`, wrapping at the end. Nil for an empty pool.
    func next(after current: UUID?) -> AgentKeyReference? {
        guard !keys.isEmpty else { return nil }
        guard let current, let index = keys.firstIndex(where: { $0.id == current }) else {
            return keys.first
        }
        return keys[(index + 1) % keys.count]
    }

    mutating func advance() {
        cursor = next(after: cursor)?.id ?? cursor
    }

    /// What a settings row may show: one masked label per key, in order.
    var maskedLabels: [String] {
        keys.map { "\($0.label) \($0.masked)" }
    }
}

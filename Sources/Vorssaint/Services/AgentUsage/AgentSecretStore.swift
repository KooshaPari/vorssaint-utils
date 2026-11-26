// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
import Security

/// Where the secret half of a provider key lives. The pool only ever holds a
/// reference, so this is the one place a key is read.
protocol AgentSecretStore {
    func set(_ secret: String, for id: UUID) -> Bool
    func secret(for id: UUID) -> String?
    /// Whether the store can say the item is gone, rather than only unreadable
    /// right now. The registry prunes a saved record only on this answer, so a
    /// locked or unavailable keychain cannot delete a key that still exists.
    func isMissing(for id: UUID) -> Bool
    func remove(for id: UUID) -> Bool
}

/// The real store: one generic password item per key, in the login keychain.
/// Accessible after first unlock so a menu bar app that launches at login can
/// still reach it, never synchronised to iCloud, and never migratable to
/// another device.
struct KeychainAgentSecretStore: AgentSecretStore {
    var service = "com.vorssaint.agent-keys"

    private func query(for id: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
        ]
    }

    /// The update dict for an item that already exists. It carries the
    /// accessibility class as well as the data, because an item written by an
    /// earlier build keeps the old migratable class until a write re-classifies
    /// it; updating only the data would leave that hole open for existing
    /// installs.
    func updateAttributes(for data: Data) -> [String: Any] {
        [
            kSecValueData as String: data,
            kSecAttrAccessible as String: AgentSecretAccessibility.item,
        ]
    }

    func set(_ secret: String, for id: UUID) -> Bool {
        let data = Data(secret.utf8)
        let base = query(for: id)
        let update = updateAttributes(for: data)
        let status = SecItemUpdate(base as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = base
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = AgentSecretAccessibility.item
            add[kSecAttrSynchronizable as String] = false
            return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
        }
        return status == errSecSuccess
    }

    func secret(for id: UUID) -> String? {
        var match = query(for: id)
        match[kSecReturnData as String] = true
        match[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(match as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Only an absent item counts as missing here. A locked keychain or a
    /// refused read answers with a different status and leaves the record in
    /// place, so a launch that cannot reach the keychain cannot prune it.
    func isMissing(for id: UUID) -> Bool {
        var match = query(for: id)
        match[kSecMatchLimit as String] = kSecMatchLimitOne
        return SecItemCopyMatching(match as CFDictionary, nil) == errSecItemNotFound
    }

    func remove(for id: UUID) -> Bool {
        let status = SecItemDelete(query(for: id) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

/// The one accessibility class a Vorssaint secret may use. `AfterFirstUnlock`
/// alone is migratable: an encrypted backup restored onto a different Mac
/// brings the item with it, so a provider key or a share password would follow
/// the backup off the machine that earned it. The `ThisDeviceOnly` variant is
/// reachable after first unlock (a menu bar app that launches at login still
/// works) but can never leave the device. It lives below the Keychain store
/// because it names a Security constant, which the Linux subset cannot link.
enum AgentSecretAccessibility {
    static let item: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
}

/// Test double with the same contract, so registry behaviour is exercised
/// without touching a real keychain.
final class InMemoryAgentSecretStore: AgentSecretStore {
    private var secrets: [UUID: String] = [:]

    func set(_ secret: String, for id: UUID) -> Bool {
        secrets[id] = secret
        return true
    }

    func secret(for id: UUID) -> String? {
        secrets[id]
    }

    /// This double holds every secret in memory, so an absent id really is gone.
    func isMissing(for id: UUID) -> Bool {
        secrets[id] == nil
    }

    func remove(for id: UUID) -> Bool {
        secrets.removeValue(forKey: id) != nil
    }
}

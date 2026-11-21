// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
import Security

/// Where the secret half of a provider key lives. The pool only ever holds a
/// reference, so this is the one place a key is read.
protocol AgentSecretStore {
    func set(_ secret: String, for id: UUID) -> Bool
    func secret(for id: UUID) -> String?
    func remove(for id: UUID) -> Bool
}

/// The real store: one generic password item per key, in the login keychain.
/// Accessible after first unlock so a menu bar app that launches at login can
/// still reach it, and never synchronised to iCloud.
struct KeychainAgentSecretStore: AgentSecretStore {
    var service = "com.vorssaint.agent-keys"

    private func query(for id: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
        ]
    }

    func set(_ secret: String, for id: UUID) -> Bool {
        let data = Data(secret.utf8)
        let base = query(for: id)
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(base as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = base
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
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

    func remove(for id: UUID) -> Bool {
        let status = SecItemDelete(query(for: id) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
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

    func remove(for id: UUID) -> Bool {
        secrets.removeValue(forKey: id) != nil
    }
}

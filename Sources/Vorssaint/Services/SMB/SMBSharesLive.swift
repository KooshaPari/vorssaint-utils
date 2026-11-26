// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
import Security

/// Publishes a share password where `mount_smbfs -N` looks for it: an internet
/// password item of protocol `smb` for that server, account and share path.
/// The item exists only for the length of one mount attempt and is removed
/// immediately afterwards, so the durable copy stays the app's generic-password
/// item in `KeychainAgentSecretStore`.
struct KeychainSMBProjection: SMBKeychainProjection {
    private func query(for share: SMBShare) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrProtocol as String: kSecAttrProtocolSMB,
            kSecAttrServer as String: share.server,
            kSecAttrPath as String: "/" + share.share,
        ]
        if let username = share.username, !username.isEmpty {
            query[kSecAttrAccount as String] = username
        }
        return query
    }

    func publish(_ secret: String, for share: SMBShare) -> Bool {
        let base = query(for: share)
        let update: [String: Any] = [kSecValueData as String: Data(secret.utf8)]
        let status = SecItemUpdate(base as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = base
            add[kSecValueData as String] = Data(secret.utf8)
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            add[kSecAttrSynchronizable as String] = false
            return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
        }
        return status == errSecSuccess
    }

    func withdraw(for share: SMBShare) {
        SecItemDelete(query(for: share) as CFDictionary)
    }
}

extension SMBEnvironment {
    static var live: SMBEnvironment {
        SMBEnvironment(
            // Shell.run owns the timeout and kills the child when it expires.
            run: { path, arguments, timeout in
                Shell.run(path, arguments, timeout: timeout)
            },
            fileExists: { FileManager.default.fileExists(atPath: $0) },
            readText: { try? String(contentsOfFile: $0, encoding: .utf8) },
            createDirectory: { path in
                if FileManager.default.fileExists(atPath: path) { return true }
                return (try? FileManager.default.createDirectory(atPath: path,
                                                                 withIntermediateDirectories: true))
                    != nil
            }
        )
    }
}

extension SMBSharesService {
    static var configurationURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Vorssaint", isDirectory: true)
            .appendingPathComponent("smb-shares.json")
    }

    /// The app's instance: keychain-backed credentials, the smb keychain
    /// projection for `mount_smbfs -N`, and bounded shell calls.
    convenience init() {
        self.init(configurationURL: Self.configurationURL,
                  secrets: KeychainAgentSecretStore(service: "com.vorssaint.smb-shares"),
                  projection: KeychainSMBProjection(),
                  environment: .live)
    }
}

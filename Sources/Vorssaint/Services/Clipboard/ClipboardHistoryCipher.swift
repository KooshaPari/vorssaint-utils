// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

#if canImport(CryptoKit) && canImport(Security)
import CryptoKit
import Security

/// Encrypts the clipboard history and the copied images at rest.
///
/// The key is 32 random bytes in the login keychain, created on first use and
/// marked `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. That flag is the
/// whole design: without it the item travels in an encrypted backup and the
/// ciphertext it protects is readable on the next Mac, which is the same
/// mistake recorded against the agent secret store. With it, a restored backup
/// yields blobs nothing can open, and the file permissions plus
/// `PrivateFileStore`'s backup exclusion already stop the cheap copies.
///
/// Two rules the call sites depend on:
///
/// - `seal` returns nil rather than plaintext when it cannot encrypt. A caller
///   that fell back would leave a file the next launch reads as cleartext, and
///   the downgrade would be silent.
/// - `openOrPassThrough` returns an unsealed blob unchanged. That is how a file
///   written before this existed stays readable while it is still on disk.
enum ClipboardHistoryCipher {
    /// Whether this build can encrypt at all, which is a compile-time fact.
    /// Whether a key can actually be obtained is a runtime one: a process
    /// without the login keychain seals nothing. Callers therefore check the
    /// result of `seal` rather than assuming from this flag.
    static let isSupported = true

    private static let service = (Bundle.main.bundleIdentifier ?? "com.vorssaint.app")
        + ".clipboard-at-rest"
    private static let account = "history-key-v1"
    private static let keyLength = 32

    /// Keychain reads are not free and `seal` runs per copy, so the key is
    /// resolved once. A lock keeps two services from creating a key each and
    /// encrypting under the loser's bytes.
    private static let lock = NSLock()
    private static var cachedKey: SymmetricKey?

    /// Encrypts, or nil when encryption is unavailable. Never returns the
    /// input.
    static func seal(_ data: Data) -> Data? {
        guard let key = self.key() else { return nil }
        return seal(data, using: key)
    }

    /// Encrypts under a key the caller holds. The keychain is not reachable
    /// from every process that runs these types (an ssh-launched test process
    /// gets `errSecInteractionNotAllowed`), so the round trip is proven through
    /// this overload rather than left to the application path alone.
    static func seal(_ data: Data, using key: SymmetricKey) -> Data? {
        guard let box = try? AES.GCM.seal(data, using: key),
              let combined = box.combined
        else { return nil }
        return ClipboardHistoryEnvelope.frame(combined: combined)
    }

    /// Decrypts a sealed blob, or nil. An unsealed blob is nil here so a
    /// caller cannot mistake a pass-through for a successful decryption.
    static func open(_ data: Data) -> Data? {
        guard ClipboardHistoryEnvelope.isSealed(data), let key = key() else { return nil }
        return open(data, using: key)
    }

    /// Decrypts under a key the caller holds. Framing is checked here, not in
    /// the caller, so an unsealed blob stays nil under any key.
    static func open(_ data: Data, using key: SymmetricKey) -> Data? {
        guard ClipboardHistoryEnvelope.isSealed(data),
              let payload = ClipboardHistoryEnvelope.payload(from: data),
              let box = try? AES.GCM.SealedBox(combined: payload)
        else { return nil }
        return try? AES.GCM.open(box, using: key)
    }

    /// Reads either kind of blob on disk: decrypted when sealed, unchanged
    /// when not. Nil when a sealed blob cannot be opened, which is the honest
    /// answer for a history encrypted under a key this Mac no longer has.
    static func openOrPassThrough(_ data: Data) -> Data? {
        ClipboardHistoryEnvelope.isSealed(data) ? open(data) : data
    }

    /// Seals when this build can, and passes the bytes through unchanged when
    /// it cannot. Nil means "supported, but sealing failed": the caller must
    /// not write, because writing would be the plaintext downgrade.
    static func sealOrPassThrough(_ data: Data) -> Data? {
        guard isSupported else { return data }
        return seal(data)
    }

    // MARK: - Keychain

    private static func key() -> SymmetricKey? {
        lock.lock()
        defer { lock.unlock() }
        if let cachedKey { return cachedKey }
        let bytes = existingKeyBytes() ?? createKeyBytes()
        guard let bytes, bytes.count == keyLength else { return nil }
        let key = SymmetricKey(data: bytes)
        cachedKey = key
        return key
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private static func existingKeyBytes() -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data, data.count == keyLength
        else { return nil }
        return data
    }

    /// Adds the key, or adopts the one a concurrent insert won. The duplicate
    /// case is not an error: two paths can reach `seal` before either cached,
    /// and the loser must not keep the bytes it generated.
    private static func createKeyBytes() -> Data? {
        var bytes = Data(count: keyLength)
        let generated = bytes.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) -> Int32 in
            guard let base = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, keyLength, base)
        }
        guard generated == errSecSuccess else { return nil }
        var attributes = baseQuery
        attributes[kSecValueData as String] = bytes
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem { return existingKeyBytes() }
        return status == errSecSuccess ? bytes : nil
    }
}

#else

/// The same surface on a platform with no keychain and no AES-GCM. Everything
/// passes through untouched and nothing is ever written sealed, so the Linux
/// suite can exercise the surrounding logic without pretending to encrypt.
enum ClipboardHistoryCipher {
    static let isSupported = false

    static func seal(_ data: Data) -> Data? { nil }
    static func open(_ data: Data) -> Data? { nil }
    static func openOrPassThrough(_ data: Data) -> Data? { data }
    static func sealOrPassThrough(_ data: Data) -> Data? { data }
}

#endif

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The byte layout of an encrypted clipboard blob, and nothing else.
///
/// Kept free of `CryptoKit` on purpose: the framing is the part that can be
/// asserted on a Linux node, where the cipher itself does not exist, and the
/// framing is also the part that has to survive an upgrade. The blob is
///
///     "VSCL" | version (1) | nonce (12) | ciphertext | tag (16)
///
/// which is the sealed box's own `combined` representation behind a five-byte
/// header. A plaintext blob of either kind this app writes starts with `[`
/// (the history is a JSON array) or `\x89` (a PNG), so the magic cannot be
/// confused with an unencrypted file and the reader can tell them apart
/// without being told which is which.
enum ClipboardHistoryEnvelope {
    static let magic = Data("VSCL".utf8)
    static let version: UInt8 = 1
    static let headerLength = magic.count + 1
    /// AES-GCM's own sizes, repeated here so the envelope can reject a blob
    /// that is too short to be a sealed box without importing the cipher.
    static let nonceLength = 12
    static let tagLength = 16
    static var minimumPayloadLength: Int { nonceLength + tagLength }
    static var minimumSealedLength: Int { headerLength + minimumPayloadLength }

    static func isSealed(_ data: Data) -> Bool {
        data.count >= magic.count && data.prefix(magic.count) == magic
    }

    /// Wraps the sealed box's combined bytes in the header.
    static func frame(combined: Data) -> Data? {
        guard combined.count >= minimumPayloadLength else { return nil }
        var data = Data(capacity: headerLength + combined.count)
        data.append(magic)
        data.append(version)
        data.append(combined)
        return data
    }

    /// The sealed box's combined bytes, or nil when the blob is not a sealed
    /// box this version understands. An unknown version is a refusal, not an
    /// attempt: guessing at a later layout would decrypt garbage.
    static func payload(from data: Data) -> Data? {
        guard isSealed(data), data.count >= minimumSealedLength else { return nil }
        guard data[data.startIndex + magic.count] == version else { return nil }
        return data.subdata(in: data.startIndex + headerLength ..< data.endIndex)
    }

    /// The version byte of a sealed blob, for diagnostics that must not decode
    /// it. Nil when the blob is not sealed at all.
    static func versionByte(in data: Data) -> UInt8? {
        guard isSealed(data), data.count > magic.count else { return nil }
        return data[data.startIndex + magic.count]
    }
}

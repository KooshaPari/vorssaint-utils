// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Guards the clipboard history's at-rest layer.
///
/// Deliberately does not put anything in the keychain. A test that created a
/// real keychain item would make the macOS gate depend on login-session state
/// and could stop on a keychain prompt nobody is there to answer. The seal is
/// therefore proven under a key generated in-process, which is the same
/// AES-GCM call the application makes once the keychain answers, and the
/// keychain-dependent branch is only asserted for its rule: a seal that fails
/// writes nothing in cleartext.
enum ClipboardHistoryAtRestTests {
    static func run(_ suite: TestSuite) {
        suite.run("clipboard-at-rest-envelope") {
            let body = Data("the quick brown fox".utf8)
            // A sealed box always carries at least a nonce and a tag.
            let combined = body + Data(repeating: 0, count: 28)
            guard let framed = ClipboardHistoryEnvelope.frame(combined: combined) else {
                suite.expect(false, "a well-formed combined box is framed")
                return
            }
            suite.expect(ClipboardHistoryEnvelope.isSealed(framed),
                         "a framed blob is recognised as sealed")
            suite.expect(ClipboardHistoryEnvelope.payload(from: framed) == combined,
                         "the payload is the combined box, byte for byte")
            suite.expect(ClipboardHistoryEnvelope.versionByte(in: framed)
                            == ClipboardHistoryEnvelope.version,
                         "the framed blob carries the current version")
            suite.expect(ClipboardHistoryEnvelope.frame(combined: Data(repeating: 0, count: 27)) == nil,
                         "a box shorter than nonce plus tag is refused, not framed")

            // The two plaintext shapes this app writes must never read as
            // sealed, or a cleartext history would be "decrypted" nonsense.
            suite.expect(!ClipboardHistoryEnvelope.isSealed(Data("[]".utf8)),
                         "a JSON history is not mistaken for a sealed blob")
            suite.expect(!ClipboardHistoryEnvelope.isSealed(Data([0x89, 0x50, 0x4E, 0x47])),
                         "a PNG is not mistaken for a sealed blob")
            suite.expect(!ClipboardHistoryEnvelope.isSealed(Data()),
                         "an empty file is not sealed")

            // A later layout must be refused rather than parsed as v1, or a
            // format change would decrypt to garbage instead of starting empty.
            var future = framed
            future[future.startIndex + ClipboardHistoryEnvelope.magic.count] = 2
            suite.expect(ClipboardHistoryEnvelope.isSealed(future),
                         "the magic still identifies a blob of an unknown version")
            suite.expect(ClipboardHistoryEnvelope.payload(from: future) == nil,
                         "an unknown version is refused")
            suite.expect(ClipboardHistoryEnvelope.versionByte(in: future) == 2,
                         "the version byte is readable without decoding")

            // A truncated blob keeps the magic but has no room for a tag.
            let truncated = framed.prefix(ClipboardHistoryEnvelope.headerLength + 4)
            suite.expect(ClipboardHistoryEnvelope.payload(from: Data(truncated)) == nil,
                         "a blob too short to hold a tag is refused")
        }

        suite.run("clipboard-at-rest-passthrough") {
            // Reading an unsealed file must still work: that is how a history
            // written before this existed survives its first launch.
            let plaintext = Data("[{\"text\":\"hello\"}]".utf8)
            suite.expect(ClipboardHistoryCipher.openOrPassThrough(plaintext) == plaintext,
                         "an unsealed blob reads back unchanged")
            suite.expect(ClipboardHistoryCipher.open(plaintext) == nil,
                         "open() does not pretend an unsealed blob was decrypted")
            // A sealed-looking blob that will not open is a real refusal.
            let corrupted = ClipboardHistoryEnvelope.frame(combined: Data(repeating: 7, count: 40))
            suite.expect(corrupted.flatMap { ClipboardHistoryCipher.open($0) } == nil,
                         "a sealed blob that does not open is nil, not garbage")

            // The keychain is not reachable from this process, so the probe
            // below takes its failure branch. The round trip itself is proven
            // under a key held here, which is the same AES-GCM call the
            // application makes once the keychain answers.
            #if canImport(CryptoKit)
            let localKey = SymmetricKey(size: .bits256)
            if let held = ClipboardHistoryCipher.seal(plaintext, using: localKey) {
                suite.expect(ClipboardHistoryEnvelope.isSealed(held),
                             "a blob sealed under a held key carries the frame")
                suite.expect(ClipboardHistoryCipher.open(held, using: localKey) == plaintext,
                             "the round trip returns the original bytes")
                suite.expect(ClipboardHistoryCipher.seal(plaintext, using: localKey) != held,
                             "a second seal under the same key differs")
                let otherKey = SymmetricKey(size: .bits256)
                suite.expect(ClipboardHistoryCipher.open(held, using: otherKey) == nil,
                             "another key does not open it")
                // A flipped byte is a tag failure, not garbage output.
                var flipped = held
                flipped[flipped.count - 1] ^= 0x01
                suite.expect(ClipboardHistoryCipher.open(flipped, using: localKey) == nil,
                             "a tampered tag is refused")
            } else {
                suite.expect(false, "AES-GCM under a held key seals")
            }
            #endif

            // Sealing needs the login keychain, which a test process may not
            // have. Both worlds are asserted, because the rule that matters is
            // the same in each: when sealing is attempted and fails, nothing
            // is written in cleartext.
            let sealed = ClipboardHistoryCipher.seal(plaintext)
            if let sealed {
                suite.expect(sealed != plaintext && ClipboardHistoryEnvelope.isSealed(sealed),
                             "a sealed blob carries the frame header")
                suite.expect(ClipboardHistoryCipher.open(sealed) == plaintext,
                             "a sealed blob opens back to its bytes")
                // Sealing twice must not produce the same bytes: the nonce is
                // fresh each time, so a copy of one ciphertext teaches nothing
                // about an identical entry elsewhere in the history.
                suite.expect(ClipboardHistoryCipher.seal(plaintext) != sealed,
                             "two seals of the same bytes differ")
            } else if ClipboardHistoryCipher.isSupported {
                suite.expect(ClipboardHistoryCipher.sealOrPassThrough(plaintext) == nil,
                             "a failed seal is nil, never the plaintext")
            } else {
                suite.expect(ClipboardHistoryCipher.sealOrPassThrough(plaintext) == plaintext,
                             "a platform without the API writes bytes through unchanged")
            }
        }

        suite.run("clipboard-at-rest-bounds") {
            // The framing sizes are the contract the read bound is derived
            // from, so they are pinned here rather than only in prose.
            suite.expect(ClipboardHistoryEnvelope.minimumPayloadLength == 28,
                         "nonce plus tag is 28 bytes")
            suite.expect(ClipboardHistoryEnvelope.headerLength == 5,
                         "the header is the four-byte magic plus a version")
            suite.expect(ClipboardHistoryEnvelope.minimumSealedLength == 33,
                         "the smallest possible sealed blob is 33 bytes")
            // A history written at its own limit has to be loadable after
            // sealing, so the stored bound must sit above the encoded bound.
            guard let support = ClipboardFileSource.text(
                "Sources/Vorssaint/Services/Clipboard/ClipboardHistorySupport.swift")
            else {
                suite.expect(false, "the clipboard support file is not readable")
                return
            }
            suite.expect(support.contains("maxStoredBytes"),
                         "the store has a separate sealed bound")
            suite.expect(support.contains("maxEncodedHistoryBytes + sealOverheadBytes"),
                         "the sealed bound is the encoded bound plus the wrapper")
            guard let service = ClipboardFileSource.text(
                "Sources/Vorssaint/Services/Clipboard/ClipboardHistoryService.swift")
            else {
                suite.expect(false, "the clipboard service is not readable")
                return
            }
            // Reading through the encoded bound would reject a sealed history
            // that was written at the limit one launch earlier.
            suite.expect(service.contains("fileBytes <= ClipboardHistoryEditing.maxStoredBytes"),
                         "the file-size guard allows the sealed wrapper")
            suite.expect(service.contains("data.count <= ClipboardHistoryEditing.maxStoredBytes"),
                         "the byte-count guard allows the sealed wrapper")
        }

        suite.run("clipboard-at-rest-wiring") {
            // The rules below are the ones a future edit can quietly undo
            // while everything still compiles: a save that writes the encoded
            // snapshot instead of the sealed one leaves the whole history
            // readable, and an image read that goes straight to disk breaks
            // the moment the file is sealed.
            guard let service = ClipboardFileSource.text(
                "Sources/Vorssaint/Services/Clipboard/ClipboardHistoryService.swift")
            else {
                suite.expect(false, "the clipboard service is not readable")
                return
            }
            suite.expect(service.contains("ClipboardHistoryCipher.sealOrPassThrough(encoded.data)"),
                         "the history save seals the encoded snapshot")
            suite.expect(!service.contains("PrivateFileStore.write(encoded.data"),
                         "nothing writes the encoded snapshot unsealed")
            suite.expect(!service.contains("set(encoded.data, forKey:"),
                         "the preferences fallback seals too")
            suite.expect(service.contains("ClipboardImageStore.store(image.data)"),
                         "copied images still go through the store")
            suite.expect(service.contains("return ClipboardHistoryCipher.openOrPassThrough(raw)"),
                         "a stored image is read through the cipher")
            suite.expect(service.contains("ClipboardImageStore.sealPlaintextFiles"),
                         "a plaintext image left from an older build is sealed at launch")
            suite.expect(service.contains("ClipboardHistoryCipher.openOrPassThrough($0)"),
                         "the history file is unsealed on load, not parsed raw")

            guard let support = ClipboardFileSource.text(
                "Sources/Vorssaint/Services/Clipboard/ClipboardHistorySupport.swift")
            else {
                suite.expect(false, "the clipboard support file is not readable")
                return
            }
            suite.expect(support.contains("ClipboardHistoryCipher.openOrPassThrough(raw)"),
                         "the editor image is read through the cipher")
            suite.expect(!support.contains("NSImage(contentsOf: directory"),
                         "no caller loads a stored image straight off the path")

            guard let cipher = ClipboardFileSource.text(
                "Sources/Vorssaint/Services/Clipboard/ClipboardHistoryCipher.swift")
            else {
                suite.expect(false, "the cipher source is not readable")
                return
            }
            suite.expect(cipher.contains("kSecAttrAccessibleWhenUnlockedThisDeviceOnly"),
                         "the key never travels in a backup off this Mac")
            suite.expect(cipher.contains("AES.GCM.seal"),
                         "the payload is sealed with AES-GCM")
            suite.expect(!cipher.contains("kSecAttrAccessibleAlways"),
                         "no always-available keychain class is used")
            // A seal that returned its input on failure would be the silent
            // downgrade this whole layer exists to prevent.
            suite.expect(!cipher.contains("?? data"),
                         "seal never falls back to the plaintext")
        }
    }
}

/// File access for the structural checks, matching the helper shape the other
/// suites use so the Linux subset and the macOS gate read the same tree.
enum ClipboardFileSource {
    static func text(_ relative: String) -> String? {
        guard let root = root() else { return nil }
        return try? String(contentsOfFile: URL(fileURLWithPath: root)
            .appendingPathComponent(relative).path, encoding: .utf8)
    }

    private static func root() -> String? {
        var directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0 ..< 6 {
            let marker = directory.appendingPathComponent("Sources/Vorssaint").path
            if FileManager.default.fileExists(atPath: marker) { return directory.path }
            directory.deleteLastPathComponent()
        }
        let candidates = [
            ProcessInfo.processInfo.environment["VORSSAINT_REPO_ROOT"],
            #filePath.components(separatedBy: "/Tests/").first,
        ]
        for candidate in candidates.compactMap({ $0 }) {
            let marker = URL(fileURLWithPath: candidate)
                .appendingPathComponent("Sources/Vorssaint").path
            if FileManager.default.fileExists(atPath: marker) { return candidate }
        }
        return nil
    }
}

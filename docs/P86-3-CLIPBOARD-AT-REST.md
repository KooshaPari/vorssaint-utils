# P86-3: the clipboard history at rest

Finding as it was written: `Clipboard/ClipboardHistoryService.swift:1236` persists copied text
and image blobs unencrypted under Application Support, so they are readable by same-user
processes, enter backups, and outlive the app.

The scoping pass (`docs/ROADMAP_LEDGER.md`, "P86-3 scoped") split that into three claims and found
only one of them true as stated. This note records the delivery.

## What was actually open

| Claim | Verdict |
| --- | --- |
| Any *other account* can read the container | false. `PrivateFileStore` sets `0o700`/`0o600` and re-tightens the chain on every create. |
| The container enters backups | was true. Closed earlier: `isExcludedFromBackup` on every directory and file in the chain. |
| Any process running as the same user reads it, and there is no crypto in the clipboard path | true. That is this change. |

The strong statement is the third one. A same-user process needs no exploit: `~/Library/Application
Support/Vorssaint/clipboard-history.json` is a plain JSON array of everything copied, and each image
entry is a PNG beside it. A backup exclusion stops the file travelling, not being read.

## Shape

Two new files, one layer, and the read paths that stop naming files.

`ClipboardHistoryEnvelope.swift` is the byte layout and nothing else. `"VSCL"`, a version byte, the
12-byte nonce, the ciphertext, the 16-byte tag. It imports no crypto framework at all, which is the
whole point: the layout is the thing worth asserting, and it can be asserted on a Linux node, where
CryptoKit and Security do not exist. Its doc comment records why the magic is unambiguous here:
every plaintext this app writes starts with `[` (the JSON history) or `\x89` (PNG).

`ClipboardHistoryCipher.swift` is AES-GCM under one 32-byte key. The key is generated with
`SecRandomCopyBytes`, stored as a generic password in the login keychain under
`<bundle id>.clipboard-at-rest` / `history-key-v1`, and marked
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. That last attribute is the point of the whole
change for the backup case: a key that only exists on this device means a restored backup yields a
history nothing can open. It is the same mistake P86-5 corrected in `AgentSecretStore`, avoided here
rather than repeated.

The key is resolved once behind an `NSLock` and cached, because `seal` runs per copy and two
services resolving it independently would each create a key and encrypt under the loser's bytes.
`errSecDuplicateItem` is not an error: the loser re-reads the winner.

## Three rules the call sites depend on

1. **A save seals before it writes, and a failed seal aborts the save.** `persist()` takes the
   encoded history and writes only if `sealOrPassThrough` returns bytes. Writing cleartext over an
   encrypted history is a silent downgrade of the whole file, and one lost save is recoverable
   where a readable history is not.
2. **A read passes an unsealed blob through unchanged.** That is how a history written before this
   existed survives its first launch. `load()` notes whether the file was plaintext and re-saves at
   that same launch, so the migration does not wait for the next copy. Images left in cleartext are
   sealed on the same launch by `ClipboardImageStore.sealPlaintextFiles(in:)`, on the history's own
   persistence queue so the two cannot interleave.
3. **`open()` returns nil for an unsealed blob.** A pass-through must never be mistakable for a
   successful decryption; `openOrPassThrough()` is the read-side entry point and it is explicit
   about which one it is doing.

## Read paths move from paths to bytes

A path into the store no longer names anything readable, so three call sites stop using one:
`ClipboardImageStore.thumbnail(named:)` now decodes `imageData(named:)` through
`CGImageSourceCreateWithData` instead of `CGImageSourceCreateWithURL`, `editorImage(for:directory:)`
decrypts before building the `NSImage`, and the sidebar's OCR path takes `Data` rather than fetching
a `URL` itself. The sidebar's `imageData(_:)` replaces `imageURL(entry)` for the same reason.

## The read bound had to grow

`maxStoredBytes` is `maxEncodedHistoryBytes + sealOverheadBytes` (96 MB + 64). The encoded bound
describes the readable snapshot; the file on disk is that plus the frame header and tag. Without
the allowance, a history written at its own limit is rejected the launch after it was written,
which is a data loss dressed as a size check.

## The guard

`Tests/ClipboardHistoryAtRestTests.swift`, five suites, runs on Linux and on macOS.

- `clipboard-at-rest-envelope` (11 checks): framing round-trip, version byte, refusal of a 27-byte
  combined value, `[]` / PNG / empty not mistaken for sealed, unknown version 2 sealed but refused,
  truncated blob refused.
- `clipboard-at-rest-passthrough` (4 checks): unsealed reads back unchanged,
  `open(plaintext) == nil`, a corrupted sealed blob is nil rather than garbage, then a seal probe.
  The probe is one assertion whichever way it goes, which is why the count is the same on both
  platforms even though Linux takes the unsupported branch and macOS takes the failed-seal one.
- `clipboard-at-rest-bounds` (7 checks): the framing constants, plus the source facts that
  `maxStoredBytes` exists, is `maxEncodedHistoryBytes + sealOverheadBytes`, and that both service
  guards use it.
- `clipboard-at-rest-seal-round-trip` (5 checks, macOS only): a key is generated in-process and
  handed to `seal(_:using:)` / `open(_:using:)`, so the frame header, the round trip, the fresh
  nonce, the wrong-key refusal and the tampered-tag refusal are all observed rather than argued.
  Compiled out when `CryptoKit` is absent, which is why the Linux total does not move.
- `clipboard-at-rest-wiring` (13 checks): the source substrings that would otherwise silently
  regress. Save seals `encoded.data`; no `PrivateFileStore.write(encoded.data`; no
  `set(encoded.data, forKey:`; `ClipboardImageStore.store(image.data)`; the `imageData` read path
  returns `openOrPassThrough(raw)`; `sealPlaintextFiles` is called; history load uses
  `openOrPassThrough($0)`; the support file does not open `NSImage(contentsOf: directory`; the
  cipher names `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` and `AES.GCM.seal`, never
  `kSecAttrAccessibleAlways`, and contains no `?? data` fallback.

The wiring suite was proved to bite rather than written and assumed: `ClipboardHistoryService.swift`
was changed to `return raw` on the image read path and the subset went `FAILED (13 checks)` /
`SUBSET FAILED (1 of 178)` at exactly `Tests/ClipboardHistoryAtRestTests.swift:145`, then green
again on revert.

## How the seal is proven

The first gate attempt failed two of 124,548 checks (`this platform can seal`, `two seals of the
same bytes differ`). The cause was measured, not guessed: an ssh-launched process was asked
directly with `xcrun swift`, and `SecRandomCopyBytes` returned `0` while `SecItemAdd` returned
`-25308` (`errSecInteractionNotAllowed`) and `SecItemRead` returned `-25300` (`errSecItemNotFound`).
There is no login keychain on that session, so `seal` correctly returns nil and a test that assumed
otherwise was asserting the environment rather than the code.

Two things happened in response, and they are different kinds of proof:

1. The passthrough suite was rewritten to seal once and assert from the answer, so both worlds
   assert the real rule: when a seal is attempted and fails, nothing is written in cleartext.
2. The cipher grew caller-keyed overloads, `seal(_:using:)` and `open(_:using:)`. The application
   path resolves its keychain key and calls them, so the shape it takes is unchanged, and the test
   can now generate a key and drive AES-GCM through this code. Gate 3 observes it:
   `clipboard-at-rest: OK (40 checks)`, `TESTS OK (124552 checks)`, `FULL_RC=0`.

What remains unobserved is only the keychain lookup inside `seal(_:)` / `open(_:)` on macOS, which
a GUI session will exercise and no automated run here can. The consequence of it failing is written
where the guard is: while the keychain is unreachable, history stops surviving relaunches and the
in-memory list keeps working. There is no visible status for it yet; inventing one here would be a
UI change smuggled into a crypto change, so it is named and left.

Export, inspection and support debugging all get harder: a sealed history is opaque to a user who
wants to read it. That trade was made deliberately (operator default on the P86-3 shape question:
encrypt, keychain key, ThisDeviceOnly) and it is the reason the previous pass left it as a decision.

## Totals

Linux subset: 177 checks (`SUBSET OK`), of which 35 are these suites (11 + 4 + 7 + 13); the
held-key block is compiled out there, so that total does not include it.
macOS suite-scoped run: `clipboard-at-rest: OK (40 checks)` (11 + 4 + 7 + 13 + 5).
macOS full gate: `TESTS OK (124552 checks)`, `FULL_RC=0`, against a 124547 baseline before the
round-trip block (the +5 is exactly the new checks).

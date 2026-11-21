// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Darwin
import Foundation

/// jcode keeps one small JSON record per session beside an append-only
/// journal. The record is rewritten whole, so it is read whole and reduced to
/// the metadata and per-response counters the island keeps; the text of each
/// message and the environment snapshots it also holds are never decoded.
enum AgentJCodeReader {
    static let journalSuffix = ".journal.jsonl"
    static let sessionSuffix = ".json"
    /// A session record larger than this is not a record worth reading. It is
    /// the largest line the reader would take, so a record it cannot hold in
    /// one line is refused before it is loaded.
    static let maximumSession = 32 << 20

    /// Discovery and live file events admit the same files: journals and the
    /// session records that have no journal beside them.
    static func accepts(_ name: String) -> Bool {
        guard !name.isEmpty, !name.hasPrefix("."), !name.contains("/"),
              !name.contains(".corrupt.") else { return false }
        return name.hasSuffix(journalSuffix) || name.hasSuffix(sessionSuffix)
    }

    /// False for a journal, which is read as an append-only log.
    static func isSessionRecord(_ path: String) -> Bool {
        path.hasSuffix(sessionSuffix)
    }

    /// The journal jcode writes beside a session record, when it has one.
    static func journalPath(for path: String) -> String {
        String(path.dropLast(sessionSuffix.count)) + journalSuffix
    }

    static func hasJournal(_ path: String) -> Bool {
        guard isSessionRecord(path) else { return false }
        var info = stat()
        return stat(journalPath(for: path), &info) == 0
    }

    /// When the record last changed; nil when it is gone.
    static func modified(_ path: String) -> Date? {
        var info = stat()
        guard stat(path, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else { return nil }
        return date(info.st_mtimespec)
    }

    /// Reads a rewritten session record once per change and hands over a
    /// small line of its allowlisted fields. A truncated, corrupt or oversized
    /// record is skipped and read again only when it changes.
    static func readSession(_ cursor: AgentLogCursor, shouldContinue: () -> Bool = { true },
                            line: (Data) -> Void) {
        guard shouldContinue() else { return }
        var info = stat()
        guard stat(cursor.path, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else { return }
        let identity = UInt64(info.st_ino)
        let size = UInt64(max(0, info.st_size))
        let changed = date(info.st_mtimespec)
        guard identity != cursor.identity || size != cursor.offset || changed > cursor.modified else { return }
        if identity != cursor.identity { cursor.startOver(identity: identity) }
        cursor.modified = changed
        guard size <= UInt64(maximumSession) else {
            // Do not retry a record too large to read until it changes again.
            cursor.offset = size
            return
        }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: cursor.path)) else { return }
        cursor.offset = UInt64(data.count)
        guard data.count <= maximumSession else { return }
        cursor.fingerprintRead()
        guard shouldContinue(), let projection = sessionLine(data) else { return }
        line(projection)
    }

    /// The allowlisted fields of a session record as one small JSON object.
    /// Each message contributes only its identifier, time and token counters;
    /// its text, the title and the environment snapshots never leave it. A
    /// closed session keeps its counters here alone, because jcode removes the
    /// journal it wrote beside the record.
    static func sessionLine(_ data: Data) -> Data? {
        guard let object = AgentLogObject(data) else { return nil }
        var payload: [String: Any] = ["jcode_session": true]
        for key in ["id", "model", "working_dir", "created_at", "updated_at", "last_active_at"] {
            if let value = object.string(key), !value.isEmpty { payload[key] = value }
        }
        if let raw = object.value("status") {
            if let text = raw as? String {
                payload["status"] = text
            } else if raw is [String: Any] {
                payload["status"] = "Crashed"
            }
        }
        let usage = object.elements("messages").compactMap(usageFacts)
        if !usage.isEmpty { payload["usage"] = usage }
        return try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    }

    /// One message's counters, in the same shape a journal message has, so a
    /// single reader counts both. Text is skipped in place by `elements`.
    private static func usageFacts(_ message: AgentLogObject) -> [String: Any]? {
        guard let usage = message.object("token_usage") else { return nil }
        var tokens: [String: Int] = [:]
        for key in ["input_tokens", "prompt_tokens", "cache_read_input_tokens",
                    "cache_creation_input_tokens", "output_tokens"] {
            let value = AgentLogParser.int(usage.value(key))
            if value > 0 { tokens[key] = value }
        }
        guard !tokens.isEmpty else { return nil }
        var facts: [String: Any] = ["token_usage": tokens]
        if let id = message.string("id"), !id.isEmpty { facts["id"] = id }
        if let timestamp = message.string("timestamp"), !timestamp.isEmpty { facts["timestamp"] = timestamp }
        return facts
    }

    private static func date(_ time: timespec) -> Date {
        Date(timeIntervalSince1970: TimeInterval(time.tv_sec) + TimeInterval(time.tv_nsec) / 1_000_000_000)
    }
}

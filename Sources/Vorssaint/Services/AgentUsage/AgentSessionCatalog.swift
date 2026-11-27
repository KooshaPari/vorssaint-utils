// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// One folder a harness writes its sessions into.
///
/// `suffixes` is what names a session file there; `recursive` covers harnesses
/// that file one folder per project, which Codex and Claude both do.
struct AgentSessionSource: Equatable {
    let harness: String
    let folder: URL
    let suffixes: [String]
    let recursive: Bool

    init(harness: String, folder: URL, suffixes: [String], recursive: Bool = true) {
        self.harness = harness
        self.folder = folder
        self.suffixes = suffixes
        self.recursive = recursive
    }

    /// The layouts this app already reads, and only those. OpenCode keeps
    /// sessions in a SQLite database rather than in files, so it has no entry
    /// here instead of a reader that would guess at its schema.
    static func defaults(home: URL) -> [AgentSessionSource] {
        [
            AgentSessionSource(harness: "jcode",
                               folder: home.appending(path: ".kcode/sessions", directoryHint: .isDirectory),
                               suffixes: [".journal.jsonl", ".json"], recursive: false),
            AgentSessionSource(harness: "codex",
                               folder: home.appending(path: ".codex/sessions", directoryHint: .isDirectory),
                               suffixes: [".jsonl"]),
            AgentSessionSource(harness: "codex",
                               folder: home.appending(path: ".codex/archived_sessions", directoryHint: .isDirectory),
                               suffixes: [".jsonl"]),
            AgentSessionSource(harness: "claude",
                               folder: home.appending(path: ".claude/projects", directoryHint: .isDirectory),
                               suffixes: [".jsonl"]),
            AgentSessionSource(harness: "copilot",
                               folder: home.appending(path: ".copilot/session-state", directoryHint: .isDirectory),
                               suffixes: ["events.jsonl"]),
        ]
    }
}

/// One session file, reduced to what a list can show without reading it.
struct AgentSessionEntry: Equatable, Identifiable {
    /// The path, which is what a reader needs and what stays stable.
    let id: String
    let harness: String
    let url: URL
    let title: String
    let modified: Date
    let bytes: Int
    /// Modified inside the live window: something may still be writing it.
    let live: Bool
}

/// Finds the sessions on disk and hands back cheap metadata about each.
///
/// Nothing here decodes a message, an environment snapshot or a prompt. A
/// session's text is read only by `AgentTranscript`, only for the one session
/// the user opened, and only as many bytes as a preview needs.
enum AgentSessionCatalog {
    /// A list longer than this is not a list anyone reads, and reading every
    /// file's metadata on a machine with years of sessions is not worth it.
    static let maximumSessions = 200
    /// Codex and Claude write one file per turn of a conversation, so a live
    /// session's file can change while the list is being built.
    static let liveWindow: TimeInterval = 300
    /// How much of a file is searched for a title before the name is used.
    static let titleBytes = 64 << 10

    static func read(_ sources: [AgentSessionSource], now: Date = Date(),
                     limit: Int = maximumSessions) -> [AgentSessionEntry] {
        var entries: [AgentSessionEntry] = []
        for source in sources {
            for url in files(in: source) {
                guard let entry = entry(url, harness: source.harness, now: now) else { continue }
                entries.append(entry)
            }
        }
        // Newest first, and a path breaks a tie so the order is stable.
        entries.sort { $0.modified == $1.modified ? $0.id < $1.id : $0.modified > $1.modified }
        return limit >= 0 && entries.count > limit ? Array(entries.prefix(limit)) : entries
    }

    /// Regular files with an accepted name, never a folder, a dotfile or the
    /// corrupt copies jcode leaves behind.
    private static func files(in source: AgentSessionSource) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey]
        guard let walk = FileManager.default.enumerator(at: source.folder, includingPropertiesForKeys: keys,
                                                       options: [.skipsHiddenFiles, .skipsPackageDescendants])
        else { return [] }
        var found: [URL] = []
        for case let url as URL in walk {
            if !source.recursive, url.deletingLastPathComponent().standardizedFileURL != source.folder.standardizedFileURL {
                walk.skipDescendants()
                continue
            }
            guard accepts(url.lastPathComponent, suffixes: source.suffixes) else { continue }
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            found.append(url)
            // A folder of years of sessions costs a walk; a list this long is
            // already more than the limit will show.
            if found.count >= maximumSessions * 4 { return found }
        }
        return found
    }

    /// The name rules, restated here so this file needs no Darwin import and
    /// can be exercised off a Mac. jcode's records and journals, and nothing
    /// that is being rewritten into a corrupt copy.
    static func accepts(_ name: String, suffixes: [String]) -> Bool {
        guard !name.isEmpty, !name.hasPrefix("."), !name.contains(".corrupt.") else { return false }
        return suffixes.contains { name.hasSuffix($0) }
    }

    private static func entry(_ url: URL, harness: String, now: Date) -> AgentSessionEntry? {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
              let modified = values.contentModificationDate, let size = values.fileSize else { return nil }
        return AgentSessionEntry(id: url.path, harness: harness, url: url,
                                 title: title(url, size: size), modified: modified, bytes: size,
                                 live: now.timeIntervalSince(modified) < liveWindow)
    }

    /// The title a session records, when it records one. A harness that writes
    /// none gets its file name, which is the session id.
    private static func title(_ url: URL, size: Int) -> String {
        let stem = url.lastPathComponent
        guard size > 0, size <= titleBytes * 64 else { return stem }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return stem }
        defer { try? handle.close() }
        let head = (try? handle.read(upToCount: titleBytes)) ?? Data()
        for line in head.split(separator: UInt8(ascii: "\n")).prefix(40) {
            guard let fields = AgentTranscript.fields(Data(line)) else { continue }
            for key in ["title", "summary", "name"] {
                if let value = fields[key] as? String, !value.isEmpty, value.count < 200 {
                    return value
                }
            }
        }
        return stem
    }
}

/// One line of a session, as a preview shows it.
struct AgentTranscriptLine: Equatable, Identifiable {
    let id: Int
    /// True for what the user said, false for what the agent answered.
    let isUser: Bool
    let text: String
    /// The line was longer than a preview keeps.
    let truncated: Bool
}

/// Reads a bounded preview of one session.
///
/// It takes the tail, because the end of a session is what a person is
/// usually looking for, and it decodes only a `role` and a text field. A line
/// carrying an environment snapshot, a file blob or any other key is skipped
/// rather than partially understood.
enum AgentTranscript {
    static let maximumLines = 60
    /// A single message longer than this is cut; the rest of the line is not
    /// read, so a session holding a pasted file cannot stall the window.
    static let maximumTextBytes = 1200
    /// How far back the tail is taken from.
    static let maximumReadBytes = 4 << 20

    static func read(_ url: URL, limit: Int = maximumLines) -> [AgentTranscriptLine] {
        guard limit > 0, let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }
        let size = ((try? handle.seekToEnd()) ?? 0)
        let start = size > UInt64(maximumReadBytes) ? size - UInt64(maximumReadBytes) : 0
        guard (try? handle.seek(toOffset: start)) != nil else { return [] }
        var data = (try? handle.readToEnd()) ?? Data()
        // A cut at the start leaves a partial line, which is not a message.
        if start > 0, let first = data.firstIndex(of: UInt8(ascii: "\n")) {
            data = data[data.index(after: first)...]
        }
        var lines: [AgentTranscriptLine] = []
        for raw in data.split(separator: UInt8(ascii: "\n")) {
            guard let line = line(Data(raw), index: lines.count) else { continue }
            lines.append(line)
        }
        return limit < lines.count ? Array(lines.suffix(limit)) : lines
    }

    /// A decoded line, or nil for anything that is not one message.
    private static func line(_ raw: Data, index: Int) -> AgentTranscriptLine? {
        guard let fields = fields(raw) else { return nil }
        guard !carriesSnapshot(fields) else { return nil }
        guard let text = text(fields), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return AgentTranscriptLine(id: index, isUser: isUser(fields), text: text,
                                   truncated: text.utf8.count >= maximumTextBytes)
    }

    /// Any line naming an environment, a snapshot or a credential is dropped
    /// whole. A preview has no reason to understand one and every reason not
    /// to print one.
    private static func carriesSnapshot(_ fields: [String: Any]) -> Bool {
        let echo = ["env", "environment", "environmentvariables", "envsnapshot", "snapshot",
                    "apikey", "api_key", "token", "authorization", "systemprompt"]
        return fields.keys.contains { key in
            let lower = key.lowercased()
            return echo.contains { lower.contains($0) }
        }
    }

    /// A message's text, from the one place each harness puts it.
    private static func text(_ fields: [String: Any]) -> String? {
        for key in ["text", "content", "message", "prompt", "completion"] {
            guard let value = fields[key] else { continue }
            if let string = value as? String { return clipped(string) }
            if let parts = value as? [[String: Any]] {
                let joined = parts.compactMap { $0["text"] as? String }.joined(separator: "\n")
                if !joined.isEmpty { return clipped(joined) }
            }
            if let nested = value as? [String: Any], let string = nested["text"] as? String {
                return clipped(string)
            }
        }
        return nil
    }

    /// A role a harness states, or the type jcode writes in its place.
    private static func isUser(_ fields: [String: Any]) -> Bool {
        let stated = (fields["role"] as? String) ?? (fields["type"] as? String)
            ?? (fields["kind"] as? String) ?? ""
        let lower = stated.lowercased()
        return lower.contains("user") || lower.contains("human") || lower.contains("prompt")
    }

    private static func clipped(_ text: String) -> String {
        let bytes = Array(text.utf8.prefix(maximumTextBytes))
        // Cutting inside a character would make the preview invalid text.
        return String(decoding: bytes, as: UTF8.self)
    }

    /// One JSON object, or nil. Shared with the catalog's title search so the
    /// two never disagree about what a line is.
    static func fields(_ raw: Data) -> [String: Any]? {
        guard !raw.isEmpty, raw.count <= maximumTextBytes * 8 else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: raw) else { return nil }
        return object as? [String: Any]
    }
}

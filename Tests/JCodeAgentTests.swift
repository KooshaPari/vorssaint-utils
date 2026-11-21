// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// jcode keeps a session record beside an append-only journal. The journal
/// carries the usage; the record is a fallback that must stay readable when it
/// is truncated, corrupt or missing fields.
enum JCodeAgentTests {
    static func run(_ suite: TestSuite) {
        sessionRecords(suite)
        discovery(suite)
    }

    private static func sessionRecords(_ suite: TestSuite) {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "vorss-jcode-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        do { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
        catch { suite.expect(false, "the jcode fixture creates its folder: \(error)"); return }
        let record = folder.appending(path: "session_fake.json")
        let truncated = Data(#"{"id":"session_fake","model":"gpt-6-sol","status":"Active""#.utf8)
        try? truncated.write(to: record)
        let cursor = AgentLogCursor(path: record.path, provider: .jcode)
        var lines: [Data] = []
        AgentJCodeReader.readSession(cursor) { lines.append($0) }
        suite.expect(lines.isEmpty && cursor.offset == UInt64(truncated.count),
                     "a truncated jcode session record is skipped without a crash")

        let valid = Data("""
        {"id":"session_fake","parent_id":"","title":"SECRET-TITLE","provider_key":"SECRET-PROVIDER",
         "model":"gpt-6-sol","working_dir":"/Users/me/code/web","short_name":"otter",
         "status":"Active","created_at":"2026-09-22T12:00:00Z","updated_at":"2026-09-22T12:00:20Z",
         "last_active_at":"2026-09-22T12:00:20Z",
         "messages":[
           {"id":"message_1","role":"user","timestamp":"2026-09-22T12:00:00Z",
            "content":[{"type":"text","text":"SECRET-PROMPT \\"token_usage\\":{\\"input_tokens\\":7}"}]},
           {"id":"message_2","role":"assistant","timestamp":"2026-09-22T12:00:20Z",
            "token_usage":{"input_tokens":1000,"cache_read_input_tokens":100,
                           "cache_creation_input_tokens":50,"output_tokens":20},
            "content":[{"type":"text","text":"SECRET-REPLY"}]}],
         "env_snapshots":[{"captured_at":"2026-09-22T12:00:00Z","API_TOKEN":"SECRET-ENV"}]}
        """.utf8)
        try? valid.write(to: record)
        lines.removeAll()
        AgentJCodeReader.readSession(cursor) { lines.append($0) }
        let projection = lines.first.map { String(decoding: $0, as: UTF8.self) } ?? ""
        suite.expect(lines.count == 1 && projection.contains("session_fake")
                        && projection.contains("gpt-6-sol") && projection.contains("message_2")
                        && !projection.contains("SECRET") && !projection.contains("messages")
                        && !projection.contains("env_snapshots") && !projection.contains("title")
                        && !projection.contains("provider_key"),
                     "a jcode session record yields only metadata and counters, never its message or environment content")

        var state = AgentLogState()
        let now = AgentTimestamp.parse("2026-09-22T12:00:30Z")!
        let entries = lines.first.map { AgentProvider.jcode.reader.parse($0, state: &state, now: now) } ?? []
        let began = Date(timeIntervalSince1970: 1_790_078_420)
        suite.expect(entries.count == 3 && entries[0] == .turnBegan(began)
                        && entries[1] == .turnContext(model: "gpt-6-sol", project: "web")
                        && state.session == "session_fake",
                     "a projected jcode session record opens a recent session's turn with its context")
        if case let .usage(key, record, billable)? = entries.last, entries.count == 3 {
            suite.expect(key == "jcode:message_2" && record.provider == .jcode
                            && record.model == "gpt-6-sol" && record.project == "web"
                            && record.session == "session_fake" && record.date == began
                            && record.tokens == AgentTokens(input: 850, cacheWrite: 50, cacheRead: 100, output: 20)
                            && billable.tokens == record.tokens,
                         "a session record counts each response's prompt, cache and output tokens")
        } else {
            suite.expect(false, "a session record reports its responses' usage")
        }

        let closed = Data("""
        {"id":"session_closed","model":"gpt-6-sol","working_dir":"/Users/me/code/web","status":"Closed",
         "last_active_at":"2026-09-20T09:00:00Z",
         "messages":[{"id":"message_3","role":"assistant","timestamp":"2026-09-20T09:00:00Z",
                      "token_usage":{"input_tokens":40,"output_tokens":5}}]}
        """.utf8)
        var closedState = AgentLogState()
        let closedEntries = AgentJCodeReader.sessionLine(closed)
            .map { AgentProvider.jcode.reader.parse($0, state: &closedState, now: now) } ?? []
        if case let .usage(key, record, _)? = closedEntries.first, closedEntries.count == 1 {
            suite.expect(key == "jcode:message_3" && record.session == "session_closed"
                            && record.tokens == AgentTokens(input: 40, output: 5),
                         "a closed session with no journal still keeps the usage its record holds")
        } else {
            suite.expect(false, "a closed session record reports usage without opening a turn")
        }

        let crashed = Data("""
        {"id":"session_crash","status":{"Crashed":{"message":"fake exit"}},
         "last_active_at":"2026-09-22T12:00:20Z"}
        """.utf8)
        var crashedState = AgentLogState()
        crashedState.turnOpen = true
        let crashLine = AgentJCodeReader.sessionLine(crashed)
        let ended = crashLine.map {
            AgentProvider.jcode.reader.parse($0, state: &crashedState, now: now)
                == [.turnEnded(Date(timeIntervalSince1970: 1_790_078_420), completed: false, duration: nil)]
        } ?? false
        suite.expect(ended && !crashedState.turnOpen,
                     "a crash saved as an object ends the turn instead of reading as active")

        let missing = AgentLogCursor(path: folder.appending(path: "missing.json").path, provider: .jcode)
        var read = false
        AgentJCodeReader.readSession(missing) { _ in read = true }
        suite.expect(!read, "a missing jcode session record yields nothing")

        suite.expect(AgentJCodeReader.sessionLine(Data("[]".utf8)) == nil
                        && AgentJCodeReader.sessionLine(Data(#"{"id":"x","messages":[{"content":"#.utf8)) == nil,
                     "a jcode session record that is not one complete object yields no metadata")
    }

    private static func discovery(_ suite: TestSuite) {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "vorss-jcode-roots-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        do { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
        catch { suite.expect(false, "the jcode discovery fixture creates its folder: \(error)"); return }
        let canonical = AgentLogRoot.canonical(folder)
        let record = canonical.appending(path: "session_fake.json")
        let journal = canonical.appending(path: "session_fake.journal.jsonl")
        FileManager.default.createFile(atPath: record.path, contents: Data(#"{"id":"session_fake","status":"Closed"}"#.utf8))
        FileManager.default.createFile(atPath: journal.path, contents: Data("{\"meta\":{}}\n".utf8))
        let other = canonical.appending(path: "session_other.json")
        FileManager.default.createFile(atPath: other.path, contents: Data(#"{"id":"session_other","status":"Closed"}"#.utf8))
        let corrupt = canonical.appending(path: "session_broken.journal.corrupt.jsonl")
        FileManager.default.createFile(atPath: corrupt.path, contents: Data("not json\n".utf8))
        let backup = canonical.appending(path: "session_other.bak")
        FileManager.default.createFile(atPath: backup.path, contents: Data("{}".utf8))

        suite.expect(AgentJCodeReader.hasJournal(record.path) && !AgentJCodeReader.hasJournal(other.path),
                     "a jcode session record beside a journal defers to the journal")
        let root = AgentLogRoot(provider: .jcode, url: canonical)
        suite.expect(root.accepts(record.path) && root.accepts(journal.path) && root.accepts(other.path)
                        && !root.accepts(backup.path) && !root.accepts(corrupt.path)
                        && !root.accepts(canonical.appending(path: "nested/session_a.json").path),
                     "jcode accepts session records and journals, never backups, corrupt journals or nested files")

        let found = AgentLogReader.discover([root], since: .distantPast)
        let names = Set(found.map { ($0.path as NSString).lastPathComponent })
        suite.expect(found.allSatisfy { $0.provider == .jcode }
                        && names == Set(["session_fake.journal.jsonl", "session_other.json"]),
                     "jcode discovery reads every journal and only session records without one")
    }
}

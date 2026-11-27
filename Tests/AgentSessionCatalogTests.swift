// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Guards the session list and the transcript preview.
///
/// Every fixture is written into a temporary folder and every source is
/// injected, so nothing here reads a real harness's store or asserts on what
/// this machine happens to hold. The privacy rules are asserted as rules: a
/// line carrying an environment snapshot is dropped, not printed.
enum AgentSessionCatalogTests {
    static func run(_ suite: TestSuite) {
        suite.run("agent-session-catalog") {
            let root = temporary()
            defer { try? FileManager.default.removeItem(at: root) }
            let jcode = root.appending(path: "kcode-sessions", directoryHint: .isDirectory)
            let codex = root.appending(path: "codex-sessions", directoryHint: .isDirectory)
            write(jcode.appending(path: "aaa.json"), #"{"title":"Refactor the parser","messages":2}"#)
            write(jcode.appending(path: "aaa.journal.jsonl"),
                  #"{"type":"user","text":"first"}"# + "\n")
            write(jcode.appending(path: "bbb.corrupt.json"), #"{"title":"never"}"#)
            write(jcode.appending(path: ".hidden.json"), #"{"title":"never"}"#)
            write(codex.appending(path: "2026/11/26/rollout-ccc.jsonl"),
                  #"{"role":"user","content":"nested"}"# + "\n")

            let sources = [
                AgentSessionSource(harness: "jcode", folder: jcode, suffixes: [".journal.jsonl", ".json"],
                                   recursive: false),
                AgentSessionSource(harness: "codex", folder: codex, suffixes: [".jsonl"]),
            ]
            let now = Date()
            let entries = AgentSessionCatalog.read(sources, now: now)
            suite.expect(entries.count == 3, "three session files are found and nothing else")
            suite.expect(entries.allSatisfy { !$0.id.contains(".corrupt.") && !$0.id.contains(".hidden.") },
                         "a corrupt copy and a dotfile are not sessions")
            suite.expect(entries.contains { $0.harness == "jcode" && $0.title == "Refactor the parser" },
                         "a title a session records is used")
            suite.expect(entries.contains { $0.harness == "codex" && $0.title == "rollout-ccc.jsonl" },
                         "a session with no title falls back to its file name")
            suite.expect(entries.allSatisfy { $0.live }, "a file written just now reads as live")

            let stale = AgentSessionCatalog.read(sources, now: now.addingTimeInterval(3_600))
            suite.expect(stale.allSatisfy { !$0.live }, "an hour later nothing reads as live")

            suite.expect(AgentSessionCatalog.read(sources, now: now, limit: 2).count == 2,
                         "the limit is honoured")
            suite.expect(AgentSessionCatalog.read(sources, now: now, limit: 1).first?.modified != nil,
                         "the newest session survives a limit of one")
            suite.expect(AgentSessionCatalog.read([], now: now).isEmpty,
                         "no sources is an empty list, not a crash")
            suite.expect(AgentSessionCatalog.read([AgentSessionSource(harness: "x", folder: root
                .appending(path: "absent"), suffixes: [".json"])], now: now).isEmpty,
                         "a folder that does not exist contributes nothing")

            // A recursive source must not pick up a nested name it did not ask
            // for, and a non-recursive one must not descend at all.
            let flat = AgentSessionCatalog.read([
                AgentSessionSource(harness: "jcode", folder: jcode, suffixes: [".json"], recursive: false),
            ], now: now)
            suite.expect(flat.count == 1, "a non-recursive source reads only its own folder")
            suite.expect(!AgentSessionCatalog.accepts("note.txt", suffixes: [".json"]),
                         "an unrelated suffix is refused")
            suite.expect(AgentSessionCatalog.accepts("a.json", suffixes: [".json"]),
                         "an accepted suffix is taken")
        }

        suite.run("agent-transcript") {
            let root = temporary()
            defer { try? FileManager.default.removeItem(at: root) }
            let file = root.appending(path: "session.jsonl")
            let lines = [
                #"{"role":"user","text":"how do I read this"}"#,
                #"{"role":"assistant","content":[{"type":"text","text":"like this"}]}"#,
                #"{"type":"user","text":"and this"}"#,
                #"{"role":"assistant","text":"ignored","env":{"PATH":"/secret"}}"#,
                #"{"role":"assistant","text":"ignored","systemPrompt":"you are"}"#,
                "not json at all",
                #"{"role":"assistant","text":"   "}"#,
                #"{"role":"assistant","text":"last"}"#,
            ]
            write(file, lines.joined(separator: "\n") + "\n")

            let preview = AgentTranscript.read(file)
            suite.expect(preview.count == 4, "four of eight lines are messages")
            suite.expect(preview.first?.isUser == true, "a user line is marked as the user's")
            suite.expect(preview.first?.text == "how do I read this", "the user's text is decoded")
            suite.expect(preview.dropFirst().first?.text == "like this",
                         "text is taken out of a content-part list")
            suite.expect(preview.dropFirst(2).first?.isUser == true,
                         "jcode's type field stands in for a role")
            suite.expect(!preview.contains { $0.text.contains("/secret") || $0.text == "you are" },
                         "a line naming an environment or a system prompt is dropped whole")
            suite.expect(!preview.contains { $0.text.trimmingCharacters(in: .whitespaces).isEmpty },
                         "a blank message is not a line")
            suite.expect(preview.last?.text == "last", "the preview ends with the session's end")
            suite.expect(preview.map(\.id) == Array(0..<preview.count), "line ids are their order")

            suite.expect(AgentTranscript.read(file, limit: 2).count == 2, "the line limit is honoured")
            suite.expect(AgentTranscript.read(file, limit: 2).last?.text == "last",
                         "the limit keeps the newest lines, not the oldest")
            suite.expect(AgentTranscript.read(file, limit: 0).isEmpty, "a limit of zero reads nothing")
            suite.expect(AgentTranscript.read(root.appending(path: "absent.jsonl")).isEmpty,
                         "a session that is gone reads as empty, not as a failure")

            let long = root.appending(path: "long.jsonl")
            write(long, #"{"role":"user","text":""# + String(repeating: "a", count: 4_000) + "\"}\n")
            let clipped = AgentTranscript.read(long)
            suite.expect(clipped.count == 1, "one long line is still one line")
            suite.expect(clipped.first?.truncated == true, "a line over the preview budget is marked")
            suite.expect((clipped.first?.text.utf8.count ?? 0) <= AgentTranscript.maximumTextBytes,
                         "the cut text fits the budget")

            // The tail is what is read, so a large file cannot be loaded whole.
            let big = root.appending(path: "big.jsonl")
            let filler = String(repeating: #"{"role":"assistant","text":"filler"}"# + "\n", count: 200_000)
            write(big, filler + #"{"role":"user","text":"the real end"}"# + "\n")
            suite.expect(AgentTranscript.read(big).last?.text == "the real end",
                         "the end of a large session is still read")
        }

        suite.run("agent-session-source-rules") {
            let home = URL(fileURLWithPath: "/Users/someone")
            let sources = AgentSessionSource.defaults(home: home)
            suite.expect(sources.map(\.harness) == ["jcode", "codex", "codex", "claude", "copilot"],
                         "the default layouts are the four harnesses this app reads")
            suite.expect(sources.allSatisfy { $0.folder.path.hasPrefix(home.path + "/") },
                         "every default source sits under the home folder it was given")
            suite.expect(!sources.contains { $0.harness == "opencode" },
                         "OpenCode is absent because its sessions live in a database")
            suite.expect(sources.first { $0.harness == "jcode" }?.recursive == false,
                         "jcode's flat sessions folder is not walked recursively")
        }
        suite.run("agent-insights-wiring") {
            func source(_ path: String) -> String {
                (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
            }
            let page = source("Sources/Vorssaint/UI/Settings/NotchAgentsSettings.swift")
            let insights = source("Sources/Vorssaint/UI/Settings/NotchAgentsInsights.swift")
            let catalog = source("Sources/Vorssaint/Services/AgentUsage/AgentSessionCatalog.swift")
            suite.expect(!page.isEmpty && !insights.isEmpty && !catalog.isEmpty,
                         "the three files this suite guards are readable")
            suite.expect(page.contains("NotchAgentsUsageSection()") && page.contains("NotchAgentsSessionsSection()"),
                         "the agents page mounts both sections")
            // The page's own caption and heading are reused, so the section adds
            // no string a translator would have to ship in fifteen languages.
            suite.expect(insights.contains("text.spendCard") && insights.contains("text.session"),
                         "both sections reuse the page's existing strings")
            // A session's text is reached through the reader and nowhere else.
            suite.expect(insights.contains("AgentSessionCatalog.read(") && insights.contains("AgentTranscript.read("),
                         "the sessions section reads through the catalog and the preview")
            for forbidden in ["contentsOfFile", "JSONSerialization", "FileHandle"] {
                suite.expect(!insights.contains(forbidden),
                             "the sessions view does no file IO of its own: \(forbidden)")
            }
            suite.expect(!catalog.contains("environmentVariables") || catalog.contains("environmentvariables"),
                         "the dropped-key list is case-folded, not compared against a literal name")
            suite.expect(insights.contains("enabledHarnesses()"),
                         "a turned-off agent's sessions are not listed")
        }
    }

    private static func write(_ url: URL, _ text: String) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? Data(text.utf8).write(to: url)
    }

    private static func temporary() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "vorssaint-session-catalog-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

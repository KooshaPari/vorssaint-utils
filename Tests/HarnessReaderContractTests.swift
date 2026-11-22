// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Every provider resolves to the reader for its own harness, and each reader
/// parses its harness's lines into the entries the island keeps.
enum HarnessReaderContractTests {
    static func run(_ suite: TestSuite) {
        readersCoverProviders(suite)
        claudeGolden(suite)
        codexGolden(suite)
        openCodeGolden(suite)
        copilotGolden(suite)
        jcodeGolden(suite)
    }

    private static func line(_ json: String) -> Data { Data(json.utf8) }

    private static func readersCoverProviders(_ suite: TestSuite) {
        for provider in AgentProvider.allCases {
            let reader = provider.reader
            suite.expect(reader.provider == provider,
                         "\(provider.rawValue) resolves to its own harness reader")
            suite.expect(reader.readsFullHistoryFirst == (provider == .copilot),
                         "only the Copilot reader rereads history on its first pass")
        }
    }

    private static func claudeGolden(_ suite: TestSuite) {
        let now = Date(timeIntervalSince1970: 0)
        var state = AgentLogState()
        let reader = AgentProvider.claude.reader
        let began = Date(timeIntervalSince1970: 1_790_088_000)
        let prompt = line(#"{"type":"user","timestamp":1790088000,"sessionId":"s","cwd":"/Users/me/code/app","message":{"content":"work"}}"#)
        suite.expect(reader.parse(prompt, state: &state, now: now) == [.turnBegan(began)],
                     "a Claude prompt opens its turn")
        let interrupted = line(#"{"type":"user","timestamp":1790088010,"sessionId":"s","message":{"content":"[Request interrupted by user for now"}}"#)
        suite.expect(reader.parse(interrupted, state: &state, now: now)
                        == [.turnEnded(nil, completed: false, duration: nil)],
                     "an interrupted Claude prompt ends its turn unfinished")
        let sidechain = line(#"{"type":"user","timestamp":1790088020,"sessionId":"s","isSidechain":true,"message":{"content":"work"}}"#)
        suite.expect(reader.parse(sidechain, state: &state, now: now).isEmpty,
                     "a Claude subagent prompt never opens a turn")
        let clear = line(#"{"type":"user","timestamp":1790088030,"sessionId":"s2","cwd":"/Users/me/code/app","message":{"content":"<command-name>/clear</command-name>\n    <command-message>clear</command-message>\n    <command-args></command-args>"}}"#)
        suite.expect(reader.parse(clear, state: &state, now: now).isEmpty && !state.turnOpen
                        && state.session == "s2" && state.project == "app",
                     "/clear adopts the session and project without opening a turn")
        for alias in ["reset", "new"] {
            let reset = line(#"{"type":"user","message":{"content":[{"type":"text","text":"<command-message>clear</command-message>\n <command-name>/\#(alias)</command-name>\n <command-args>previous session</command-args>"}]}}"#)
            suite.expect(reader.parse(reset, state: &state, now: now).isEmpty && !state.turnOpen,
                         "the /\(alias) alias also resets the context without work")
        }
        let cleared = line(#"{"type":"system","subtype":"local_command","timestamp":1790088031,"sessionId":"s2","content":"<local-command-stdout></local-command-stdout>"}"#)
        suite.expect(reader.parse(cleared, state: &state, now: now).isEmpty,
                     "a Claude local command's output parses to nothing")
        // Claude Code writes that output on a line whose outer type varies.
        let clearedUser = line(#"{"type":"user","timestamp":1790088032,"sessionId":"s2","message":{"content":"<local-command-stdout></local-command-stdout>"}}"#)
        suite.expect(reader.parse(clearedUser, state: &state, now: now).isEmpty && !state.turnOpen,
                     "a Claude local command's output never opens a turn")
        let clearedReply = line(#"{"type":"assistant","timestamp":1790088033,"sessionId":"s2","message":{"role":"assistant","content":[{"type":"text","text":"<local-command-stdout>Context cleared</local-command-stdout>"}]}}"#)
        suite.expect(reader.parse(clearedReply, state: &state, now: now).isEmpty && !state.turnOpen,
                     "a Claude local command's output written as a reply opens no turn")
        let next = line(#"{"type":"user","timestamp":1790088040,"sessionId":"s2","cwd":"/Users/me/code/app","message":{"content":"<command-name>/clear</command-name>\nExplain this log entry."}}"#)
        suite.expect(reader.parse(next, state: &state, now: now)
                        == [.turnBegan(Date(timeIntervalSince1970: 1_790_088_040))],
                     "a prompt asking about the command still opens its own turn")
        let quoted = line(#"{"type":"assistant","timestamp":1790088041,"message":{"model":"claude-opus-5-5","content":[{"type":"text","text":"<local-command-stderr>example</local-command-stderr>"}],"stop_reason":null}}"#)
        suite.expect(reader.parse(quoted, state: &state, now: now) == [.turnActive(Date(timeIntervalSince1970: 1_790_088_041))],
                     "a model reply quoting local output still reports activity")
        var idle = AgentLogState()
        let question = line(#"{"type":"user","timestamp":1790088040,"message":{"content":"<local-command-stdout>ready</local-command-stdout>\nWhat does this mean?"}}"#)
        suite.expect(reader.parse(question, state: &idle, now: now) == [.turnBegan(Date(timeIntervalSince1970: 1_790_088_040))],
                     "a question quoting local output opens its own turn")
        let childOutput = line(#"{"type":"user","isSidechain":true,"message":{"content":"<local-command-stdout>Set model</local-command-stdout>"}}"#)
        suite.expect(reader.parse(childOutput, state: &state, now: now).isEmpty && state.turnOpen,
                     "a child command cannot end the parent turn")
        let unfinished = line(#"{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","id":"interrupted-tool"}],"stop_reason":"tool_use"}}"#)
        _ = reader.parse(unfinished, state: &state, now: now)
        suite.expect(state.runningCommands.contains("interrupted-tool")
                     && reader.parse(clear, state: &state, now: now) == [.turnEnded(nil, completed: false, duration: nil)]
                     && !state.turnOpen && state.runningCommands.isEmpty,
                     "clearing a resumed session drops its unfinished turn and command without a finish notice")
    }

    private static func codexGolden(_ suite: TestSuite) {
        let now = Date(timeIntervalSince1970: 0)
        var state = AgentLogState()
        let reader = AgentProvider.codex.reader
        let meta = line(#"{"type":"session_meta","timestamp":1790088000,"payload":{"id":"s","cwd":"/tmp/example"}}"#)
        suite.expect(reader.parse(meta, state: &state, now: now).isEmpty
                        && state.session == "s" && state.project == "example",
                     "Codex session metadata names the session and project")
        let started = line(#"{"type":"event_msg","timestamp":1790088000,"payload":{"type":"task_started"}}"#)
        suite.expect(reader.parse(started, state: &state, now: now)
                        == [.turnBegan(Date(timeIntervalSince1970: 1_790_088_000))],
                     "a Codex task start opens its turn")
        let bogus = line(#"{"type":"bogus","timestamp":1790088000,"payload":{}}"#)
        suite.expect(reader.parse(bogus, state: &state, now: now).isEmpty,
                     "an unknown Codex line parses to nothing")
    }

    private static func openCodeGolden(_ suite: TestSuite) {
        let now = Date(timeIntervalSince1970: 0)
        var state = AgentLogState()
        let reader = AgentProvider.opencode.reader
        let user = line(#"{"session_id":"s_oc_1","time_created":1790088000,"directory":"/Users/me/code/backend","role":"user","parts":[{"type":"text","text":"go"}]}"#)
        suite.expect(reader.parse(user, state: &state, now: now)
                        == [.turnBegan(Date(timeIntervalSince1970: 1_790_088_000))],
                     "an OpenCode prompt opens its session turn")
        let stop = line(#"{"id":"msg_2","session_id":"s_oc_1","time_created":1790088020,"directory":"/Users/me/code/backend","role":"assistant","model_id":"stealth/ox-alpha","provider_id":"relay","cost":0.0015,"tokens":{"total":500,"input":400,"output":100,"reasoning":0,"cache":{"read":0,"write":0}},"finish":"stop"}"#)
        let stopped = reader.parse(stop, state: &state, now: now)
        suite.expect(stopped.last == .turnEnded(Date(timeIntervalSince1970: 1_790_088_020),
                                                completed: true, duration: 20),
                     "a finished OpenCode reply ends its turn with its duration")
        let reset = line(#"{"type":"reset"}"#)
        suite.expect(reader.parse(reset, state: &state, now: now) == [.reset(now)],
                     "an OpenCode reset restarts every session")
    }

    private static func copilotGolden(_ suite: TestSuite) {
        let now = Date(timeIntervalSince1970: 0)
        var state = AgentLogState()
        let reader = AgentProvider.copilot.reader
        let start = line(#"{"id":"start","timestamp":1790088000,"type":"session.start","data":{"sessionId":"s","selectedModel":"gpt-6-sol","context":{"cwd":"/tmp/example"}}}"#)
        suite.expect(reader.parse(start, state: &state, now: now).isEmpty
                        && state.session == "s" && state.model == "gpt-6-sol" && state.project == "example",
                     "a Copilot session start names the session, model and project")
        let prompt = line(#"{"id":"turn","timestamp":1790088000,"type":"user.message","data":{"turnId":"0","content":"private"}}"#)
        suite.expect(reader.parse(prompt, state: &state, now: now)
                        == [.turnBegan(Date(timeIntervalSince1970: 1_790_088_000)),
                            .turnContext(model: "gpt-6-sol", project: "example")],
                     "a Copilot prompt opens its turn with its context")
        let reply = line(#"{"id":"message","timestamp":1790088000,"type":"assistant.message","data":{"model":"gpt-6-sol","content":"private"}}"#)
        suite.expect(reader.parse(reply, state: &state, now: now).count == 3,
                     "a Copilot reply counts its request and keeps the turn active")
        let end = line(#"{"id":"end","timestamp":1790088020,"type":"assistant.turn_end","data":{"turnId":"0"}}"#)
        suite.expect(reader.parse(end, state: &state, now: now)
                        == [.turnEnded(Date(timeIntervalSince1970: 1_790_088_020),
                                       completed: true, duration: nil)],
                     "a Copilot turn end finishes its turn")
        let checkpoint = line(#"{"id":"c","timestamp":1790088020,"type":"session.usage_checkpoint","data":{}}"#)
        suite.expect(reader.parse(checkpoint, state: &state, now: now).isEmpty,
                     "a Copilot usage checkpoint parses to nothing")
    }

    private static func jcodeGolden(_ suite: TestSuite) {
        let now = Date(timeIntervalSince1970: 0)
        var state = AgentLogState()
        let reader = AgentProvider.jcode.reader
        let meta = #"{"model":"claude-haiku-5-5","provider_key":"claude-oauth","working_dir":"/Users/me/code/demo","short_name":"otter","status":"Active","model_usage_turn_id":"session_otter_1:message_1","last_active_at":"2026-09-22T12:00:00Z"}"#
        let user = #"{"id":"message_1","role":"user","timestamp":"2026-09-22T12:00:00Z","content":[{"type":"text","text":"fake prompt"}]}"#
        let assistant = #"{"id":"message_2","role":"assistant","timestamp":"2026-09-22T12:00:20Z","token_usage":{"input_tokens":1000,"cache_read_input_tokens":100,"cache_creation_input_tokens":50,"output_tokens":20},"content":[{"type":"text","text":"fake reply"}]}"#
        let journal = line(#"{"meta":\#(meta),"append_messages":[\#(user),\#(assistant)]}"#)
        let entries = reader.parse(journal, state: &state, now: now)
        let began = Date(timeIntervalSince1970: 1_790_078_400)
        let replied = Date(timeIntervalSince1970: 1_790_078_420)
        suite.expect(entries.count == 4 && entries[0] == .turnBegan(began)
                        && entries[1] == .turnContext(model: "claude-haiku-5-5", project: "demo")
                        && entries[2] == .turnActive(replied),
                     "a jcode journal opens its session turn and keeps it active")
        if case let .usage(key, record, billable)? = entries.last, entries.count == 4 {
            suite.expect(key == "jcode:message_2" && record.provider == .jcode && record.model == "claude-haiku-5-5"
                            && record.project == "demo" && record.session == "session_otter_1"
                            && record.tokens == AgentTokens(input: 850, cacheWrite: 50, cacheRead: 100, output: 20)
                            && billable.tokens == record.tokens,
                         "a jcode response counts prompt, cache and output tokens apart")
        } else {
            suite.expect(false, "a jcode assistant message reports usage")
        }
        let closedMeta = #"{"model":"claude-haiku-5-5","working_dir":"/Users/me/code/demo","status":"Closed","model_usage_turn_id":"session_otter_1:message_3","last_active_at":"2026-09-22T12:01:00Z"}"#
        let closed = line(#"{"meta":\#(closedMeta),"append_messages":[]}"#)
        suite.expect(reader.parse(closed, state: &state, now: now)
                        == [.turnEnded(Date(timeIntervalSince1970: 1_790_078_460), completed: false, duration: nil)],
                     "a closed jcode session ends its turn without a notice")
        suite.expect(reader.parse(line(#"{"meta":{}}"#), state: &state, now: now).isEmpty,
                     "jcode metadata with nothing else parses to nothing")
        suite.expect(reader.parse(line(#"{"meta":{"status":"Active""#), state: &state, now: now).isEmpty,
                     "a truncated jcode line parses to nothing")
        suite.expect(reader.parse(line(#"{"meta":{},"append_env_snapshots":[{"captured_at":"2026-09-22T12:00:00Z","reason":"set_model"}]}"#),
                                  state: &state, now: now).isEmpty,
                     "jcode environment snapshots are ignored")
        var live = AgentLogState()
        let snapshot = line(#"{"jcode_session":true,"id":"session_otter_2","model":"gpt-6-sol","working_dir":"/Users/me/code/web","status":"Active","last_active_at":"2026-09-22T12:00:00Z"}"#)
        suite.expect(reader.parse(snapshot, state: &live, now: began)
                        == [.turnBegan(began), .turnContext(model: "gpt-6-sol", project: "web")],
                     "an active jcode session record opens its turn with its context")
        let closedSnapshot = line(#"{"jcode_session":true,"id":"session_otter_2","model":"gpt-6-sol","working_dir":"/Users/me/code/web","status":"Closed","last_active_at":"2026-09-22T12:00:00Z"}"#)
        suite.expect(reader.parse(closedSnapshot, state: &live, now: began)
                        == [.turnEnded(began, completed: false, duration: nil)],
                     "a closed jcode session record ends its turn")
        suite.expect(reader.parse(line(#"{"jcode_session":true,"#), state: &live, now: now).isEmpty,
                     "a truncated jcode session record parses to nothing")

        // A reply's text can quote the shape of a counter; only the message's
        // own field counts, and a non-object element is stepped over.
        var noisy = AgentLogState()
        let quoted = line(#"{"meta":{"model":"gpt-6-sol","working_dir":"/Users/me/code/demo","status":"Active"},"append_messages":["skip me",{"id":"message_6","role":"assistant","timestamp":"2026-09-22T12:00:30Z","content":[{"type":"text","text":"\"token_usage\":{\"input_tokens\":999}"}]},{"id":"message_7","role":"assistant","timestamp":"2026-09-22T12:00:31Z","token_usage":{"input_tokens":10,"output_tokens":2},"content":[]}]}"#)
        let noisyEntries = reader.parse(quoted, state: &noisy, now: now)
        suite.expect(noisyEntries.count == 4
                        && noisyEntries.compactMap(usageKey) == ["jcode:message_7"],
                     "only a jcode message's own counters count, never counter text it quotes")

        var crashed = AgentLogState()
        crashed.turnOpen = true
        let crash = line(#"{"meta":{"status":{"Crashed":{"message":"fake exit"}}},"append_messages":[]}"#)
        suite.expect(reader.parse(crash, state: &crashed, now: now)
                        == [.turnEnded(nil, completed: false, duration: nil)] && !crashed.turnOpen,
                     "a jcode crash status ends the open turn")
    }

    private static func usageKey(_ entry: AgentLogEntry) -> String? {
        if case let .usage(key, _, _) = entry { return key }
        return nil
    }
}

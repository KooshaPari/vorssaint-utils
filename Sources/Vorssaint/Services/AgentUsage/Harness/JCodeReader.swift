// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Reads jcode's session journal. Its lines carry the session's metadata and
/// the messages appended since the last save; only times, token counts, model
/// and folder names are decoded. Message text, tool payloads and the
/// environment snapshots are never read.
struct JCodeReader: AgentHarnessReader {
    var provider: AgentProvider { .jcode }

    func parse(_ line: Data, state: inout AgentLogState, now: Date) -> [AgentLogEntry] {
        guard let envelope = AgentLogObject(line) else { return [] }
        if envelope.value("jcode_session") != nil {
            return session(envelope, state: &state, now: now)
        }
        return journal(envelope, state: &state, now: now)
    }

    /// A journal line: `meta` repeats the session's current shape and
    /// `append_messages` holds what was saved with it.
    private func journal(_ envelope: AgentLogObject, state: inout AgentLogState,
                         now: Date) -> [AgentLogEntry] {
        let meta = envelope.object("meta")
        let messages = envelope.elements("append_messages")
        guard meta != nil || !messages.isEmpty else { return [] }
        if let meta { adopt(meta, into: &state) }
        let status = meta.map { readStatus($0) } ?? (text: "", closed: false)
        // A save moves `updated_at` while `last_active_at` can stay hours
        // behind, so the newest of them is the session's last sign of life.
        let activity = meta.flatMap { newest($0, ["last_active_at", "updated_at"]) }
        var entries: [AgentLogEntry] = []
        if status.closed, state.turnOpen {
            state.turnOpen = false
            entries.append(.turnEnded(activity, completed: false, duration: nil))
        }
        // A closed session's history still counts; it just opens no turn.
        let live = !status.closed
        for message in messages {
            let moment = AgentLogParser.timestamp(message.value("timestamp")) ?? activity ?? now
            if live {
                if state.turnOpen {
                    entries.append(.turnActive(moment))
                } else {
                    state.turnOpen = true
                    entries.append(.turnBegan(moment))
                    entries.append(.turnContext(model: state.model, project: state.project))
                }
            }
            if let entry = usage(message, fallback: activity, state: state, now: now) {
                entries.append(entry)
            }
        }
        return entries
    }

    /// A session file rewritten whole by jcode. It carries the session's shape
    /// and each message's counters, so a session that keeps no journal still
    /// appears while it works and its responses still count once it closes.
    private func session(_ envelope: AgentLogObject, state: inout AgentLogState,
                         now: Date) -> [AgentLogEntry] {
        if let id = envelope.string("id"), !id.isEmpty {
            state.session = AgentLogParser.native(id)
        }
        if let model = envelope.string("model"), !model.isEmpty {
            state.model = AgentLogParser.native(model)
        }
        if let working = envelope.string("working_dir"), !working.isEmpty {
            state.project = AgentLogParser.projectName(working)
        }
        let status = readStatus(envelope)
        let activity = newest(envelope, ["last_active_at", "updated_at", "created_at"])
        var entries: [AgentLogEntry] = []
        if status.closed {
            if state.turnOpen {
                state.turnOpen = false
                entries.append(.turnEnded(activity, completed: false, duration: nil))
            }
        } else if let activity, now.timeIntervalSince(activity) < NotchAgentSupport.idleTurn {
            // An old snapshot is history, not work going on now, but the
            // responses it holds still count.
            if state.turnOpen {
                entries.append(.turnActive(activity))
            } else {
                state.turnOpen = true
                entries.append(.turnBegan(activity))
            }
            entries.append(.turnContext(model: state.model, project: state.project))
        }
        for message in envelope.elements("usage") {
            if let entry = usage(message, fallback: activity, state: state, now: now) {
                entries.append(entry)
            }
        }
        return entries
    }

    /// One response's counters. The key names the response, so a record read
    /// again or followed by its journal counts each response once.
    private func usage(_ message: AgentLogObject, fallback: Date?, state: AgentLogState,
                       now: Date) -> AgentLogEntry? {
        guard let usage = message.object("token_usage") else { return nil }
        let tokens = tokens(usage)
        guard tokens.total > 0 else { return nil }
        let moment = AgentLogParser.timestamp(message.value("timestamp")) ?? fallback ?? now
        let id = message.string("id") ?? ""
        let key = id.isEmpty
            ? "jcode:\(state.session):\(moment.timeIntervalSince1970)" : "jcode:\(id)"
        var billable = AgentBillable(tokens: tokens)
        billable.fast = false
        let priced = AgentPricing.cost(billable, model: state.model)
        return .usage(key: key, record: AgentUsageRecord(
            provider: .jcode, date: moment, model: state.model, project: state.project,
            session: state.session, tokens: tokens, cost: priced.cost, savings: priced.savings),
            billable: billable)
    }

    /// Model, folder and session id, all from the metadata jcode repeats.
    private func adopt(_ meta: AgentLogObject, into state: inout AgentLogState) {
        if let model = meta.string("model"), !model.isEmpty {
            state.model = AgentLogParser.native(model)
        }
        if let working = meta.string("working_dir") ?? meta.string("original_working_dir"), !working.isEmpty {
            state.project = AgentLogParser.projectName(working)
        }
        if let turn = meta.string("model_usage_turn_id"), let colon = turn.firstIndex(of: ":") {
            let id = String(turn[..<colon])
            if !id.isEmpty { state.session = AgentLogParser.native(id) }
        }
    }

    private func readStatus(_ object: AgentLogObject) -> (text: String, closed: Bool) {
        guard let raw = object.value("status") else { return ("", false) }
        if let text = raw as? String {
            return (text, text == "Closed" || text == "Crashed")
        }
        // A crash is saved as an object naming the exit; it is never active.
        if raw is [String: Any] { return ("Crashed", true) }
        return ("", false)
    }

    private func date(_ object: AgentLogObject, _ key: String) -> Date? {
        AgentLogParser.timestamp(object.value(key))
    }

    private func newest(_ object: AgentLogObject, _ keys: [String]) -> Date? {
        keys.compactMap { date(object, $0) }.max()
    }

    /// jcode records the whole prompt as `input_tokens`, cache reads included;
    /// the island keeps cached traffic apart so it can price and count it.
    private func tokens(_ usage: AgentLogObject) -> AgentTokens {
        let cacheRead = AgentLogParser.int(usage.value("cache_read_input_tokens"))
        let cacheWrite = AgentLogParser.int(usage.value("cache_creation_input_tokens"))
        let prompt = max(AgentLogParser.int(usage.value("input_tokens")),
                         AgentLogParser.int(usage.value("prompt_tokens")))
        return AgentTokens(input: max(0, prompt - cacheRead - cacheWrite),
                           cacheWrite: cacheWrite, cacheRead: cacheRead,
                           output: AgentLogParser.int(usage.value("output_tokens")))
    }
}

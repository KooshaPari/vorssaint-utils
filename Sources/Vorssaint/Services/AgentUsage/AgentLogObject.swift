// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Darwin
import Foundation

/// Indexes just one JSON object's fields. Strings and nested payloads are
/// skipped in place; only explicitly requested small fields are decoded.
/// A nested tool result can never supply an envelope's type or agentId.
struct AgentLogObject {
    private let data: Data
    private let fields: [String: Range<Int>]

    init?(_ data: Data, range: Range<Int>? = nil) {
        let range = range ?? 0..<data.count
        guard range.lowerBound >= 0, range.upperBound <= data.count else { return nil }
        let fields: [String: Range<Int>]? = data.withUnsafeBytes { raw in
            let bytes = raw.bindMemory(to: UInt8.self)
            var position = range.lowerBound
            func space() {
                while position < range.upperBound, [9, 10, 13, 32].contains(bytes[position]) { position += 1 }
            }
            func quoted() -> Range<Int>? {
                let start = position
                guard position < range.upperBound, bytes[position] == 0x22 else { return nil }
                position += 1
                while position < range.upperBound {
                    guard let base = bytes.baseAddress,
                          let found = memchr(base + position, 0x22, range.upperBound - position) else { return nil }
                    let quote = base.distance(to: found.assumingMemoryBound(to: UInt8.self))
                    var back = quote
                    while back > start, bytes[back - 1] == 0x5C { back -= 1 }
                    position = quote + 1
                    if (quote - back).isMultiple(of: 2) { return start..<position }
                }
                return nil
            }
            func value() -> Range<Int>? {
                let start = position
                guard position < range.upperBound else { return nil }
                if bytes[position] == 0x22 { return quoted() }
                if bytes[position] == 0x7B || bytes[position] == 0x5B {
                    var closing: [UInt8] = []
                    repeat {
                        guard position < range.upperBound else { return nil }
                        switch bytes[position] {
                        case 0x22:
                            guard quoted() != nil else { return nil }
                            continue
                        case 0x7B: closing.append(0x7D)
                        case 0x5B: closing.append(0x5D)
                        case 0x7D, 0x5D:
                            guard closing.popLast() == bytes[position] else { return nil }
                        default: break
                        }
                        guard closing.count <= 128 else { return nil }
                        position += 1
                    } while !closing.isEmpty
                } else {
                    while position < range.upperBound, ![9, 10, 13, 32, 0x2C, 0x7D].contains(bytes[position]) {
                        position += 1
                    }
                }
                return position > start ? start..<position : nil
            }
            space()
            guard position < range.upperBound, bytes[position] == 0x7B else { return nil }
            position += 1
            space()
            var fields: [String: Range<Int>] = [:]
            if position < range.upperBound, bytes[position] != 0x7D {
                while true {
                    guard let keyRange = quoted(), keyRange.count <= 256,
                          let key = Self.string(data, range: keyRange),
                          fields[key] == nil else { return nil }
                    space()
                    guard position < range.upperBound, bytes[position] == 0x3A else { return nil }
                    position += 1
                    space()
                    guard let field = value() else { return nil }
                    fields[key] = field
                    space()
                    guard position < range.upperBound else { return nil }
                    if bytes[position] != 0x2C { break }
                    position += 1
                    space()
                }
            }
            guard position < range.upperBound, bytes[position] == 0x7D else { return nil }
            position += 1
            space()
            return position == range.upperBound ? fields : nil
        }
        guard let fields else { return nil }
        self.data = data
        self.fields = fields
    }

    func value(_ key: String) -> Any? {
        guard let range = fields[key] else { return nil }
        if data[range.lowerBound] == 0x22 { return Self.string(data, range: range) }
        return try? JSONSerialization.jsonObject(with: data.subdata(in: range), options: .fragmentsAllowed)
    }

    func string(_ key: String) -> String? {
        fields[key].flatMap { Self.string(data, range: $0) }
    }

    private static func string(_ data: Data, range: Range<Int>) -> String? {
        guard range.count >= 2, data[range.lowerBound] == 0x22, data[range.upperBound - 1] == 0x22 else { return nil }
        let contents = (range.lowerBound + 1)..<(range.upperBound - 1)
        if !data[contents].contains(0x5C) { return String(decoding: data[contents], as: UTF8.self) }
        return (try? JSONSerialization.jsonObject(with: data.subdata(in: range), options: .fragmentsAllowed)) as? String
    }

    func object(_ key: String) -> AgentLogObject? {
        fields[key].flatMap { AgentLogObject(data, range: $0) }
    }

    /// The object members of this object, keyed by member name and indexed in
    /// place. A member that is not an object is left out. `terminals.json`
    /// keeps one record per address under `terminals`.
    func members() -> [String: AgentLogObject] {
        fields.compactMapValues { AgentLogObject(data, range: $0) }
    }

    /// The object elements of an array field, indexed in place like the
    /// envelope: strings and nested payloads inside each element are skipped,
    /// never decoded. Non-object elements are left out.
    func elements(_ key: String) -> [AgentLogObject] {
        guard let range = fields[key] else { return [] }
        let ranges: [Range<Int>]? = data.withUnsafeBytes { raw in
            let bytes = raw.bindMemory(to: UInt8.self)
            var position = range.lowerBound
            func space() {
                while position < range.upperBound, [9, 10, 13, 32].contains(bytes[position]) { position += 1 }
            }
            func skipQuoted() -> Bool {
                let start = position
                guard position < range.upperBound, bytes[position] == 0x22 else { return false }
                position += 1
                while position < range.upperBound {
                    guard let base = bytes.baseAddress,
                          let found = memchr(base + position, 0x22, range.upperBound - position) else { return false }
                    let quote = base.distance(to: found.assumingMemoryBound(to: UInt8.self))
                    var back = quote
                    while back > start, bytes[back - 1] == 0x5C { back -= 1 }
                    position = quote + 1
                    if (quote - back).isMultiple(of: 2) { return true }
                }
                return false
            }
            func skipValue() -> Bool {
                guard position < range.upperBound else { return false }
                if bytes[position] == 0x22 { return skipQuoted() }
                if bytes[position] == 0x7B || bytes[position] == 0x5B {
                    var closing: [UInt8] = []
                    repeat {
                        guard position < range.upperBound else { return false }
                        switch bytes[position] {
                        case 0x22:
                            guard skipQuoted() else { return false }
                            continue
                        case 0x7B: closing.append(0x7D)
                        case 0x5B: closing.append(0x5D)
                        case 0x7D, 0x5D:
                            guard closing.popLast() == bytes[position] else { return false }
                        default: break
                        }
                        guard closing.count <= 128 else { return false }
                        position += 1
                    } while !closing.isEmpty
                    return true
                }
                let start = position
                while position < range.upperBound,
                      ![9, 10, 13, 32, 0x2C, 0x5D, 0x7D].contains(bytes[position]) { position += 1 }
                return position > start
            }
            space()
            guard position < range.upperBound, bytes[position] == 0x5B else { return nil }
            position += 1
            space()
            var ranges: [Range<Int>] = []
            if position < range.upperBound, bytes[position] == 0x5D {
                position += 1
                space()
                return position == range.upperBound ? ranges : nil
            }
            while true {
                space()
                let start = position
                guard skipValue() else { return nil }
                ranges.append(start..<position)
                space()
                guard position < range.upperBound else { return nil }
                if bytes[position] == 0x2C {
                    position += 1
                    continue
                }
                guard bytes[position] == 0x5D else { return nil }
                position += 1
                break
            }
            space()
            return position == range.upperBound ? ranges : nil
        }
        guard let ranges else { return [] }
        return ranges.compactMap { AgentLogObject(data, range: $0) }
    }

    func hasItems(_ key: String) -> Bool {
        guard let range = fields[key], data[range.lowerBound] == 0x5B else { return false }
        return data[(range.lowerBound + 1)..<range.upperBound]
            .first(where: { ![9, 10, 13, 32].contains($0) }) != 0x5D
    }
}

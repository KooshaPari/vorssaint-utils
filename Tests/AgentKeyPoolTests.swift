// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Rotation behaviour for a pool of provider keys.
enum AgentKeyPoolTests {
    static func run(_ suite: TestSuite) {
        func key(_ name: String, _ tail: String = "abcd") -> AgentKeyReference {
            AgentKeyReference(id: UUID(), provider: "opencode-go", label: name, tail: tail)
        }

        var empty = AgentKeyPool()
        suite.expect(empty.next(after: nil) == nil, "an empty pool has no next key")
        suite.expect(empty.maskedLabels.isEmpty, "an empty pool shows no rows")

        let first = key("work", "1111")
        let second = key("personal", "2222")
        let third = key("overflow", "3333")
        var pool = AgentKeyPool()
        pool.add(first)
        pool.add(second)
        pool.add(third)

        suite.expect(pool.cursor == first.id, "the first key added becomes the cursor")
        suite.expect(pool.next(after: first.id)?.id == second.id, "rotation moves to the next key")
        suite.expect(pool.next(after: third.id)?.id == first.id, "rotation wraps at the end")
        suite.expect(pool.next(after: UUID())?.id == first.id,
                     "an unknown cursor starts from the first key")

        pool.add(first)
        suite.expect(pool.keys.count == 3, "a repeated key id is not added twice")

        pool.advance()
        suite.expect(pool.cursor == second.id, "advancing moves the cursor forward")

        pool.remove(second.id)
        suite.expect(pool.keys.count == 2, "removing a key drops it")
        suite.expect(pool.cursor == third.id,
                     "removing the current key moves the cursor to what follows it")

        pool.remove(first.id)
        pool.remove(third.id)
        suite.expect(pool.isEmpty && pool.cursor == nil,
                     "removing every key clears the cursor")

        var single = AgentKeyPool()
        single.add(first)
        suite.expect(single.next(after: first.id)?.id == first.id,
                     "a single key rotates onto itself")

        let labels = AgentKeyPool(keys: [first, second]).maskedLabels
        suite.expect(labels == ["work ••••1111", "personal ••••2222"],
                     "rows show the label and the masked tail")
        suite.expect(labels.allSatisfy { $0.contains("••••") },
                     "every row carries the mask, so a key is never shown whole")
    }
}

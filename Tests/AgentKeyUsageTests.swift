// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Per-key accounting and provider routing for a pool of OpenCode Go keys.
enum AgentKeyUsageTests {
    static func run(_ suite: TestSuite) {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let provider = AgentKeyProvider.openCodeGo

        func reference(_ label: String, _ tail: String) -> AgentKeyReference {
            AgentKeyReference(id: UUID(), provider: provider, label: label, tail: tail)
        }

        func pool(_ keys: [AgentKeyReference]) -> AgentKeyPool {
            AgentKeyPool(keys: keys, cursor: keys.first?.id)
        }

        func rowText(_ rows: [AgentKeyUsageRow]) -> String {
            rows.map(\.maskedLabel).joined(separator: " ")
        }

        // Counting is per key, and a streamed answer adds only its delta.
        let first = UUID()
        let second = UUID()
        var ledger = AgentKeyLedger()
        ledger.register(first)
        ledger.register(second)
        ledger.record(first, tokens: AgentTokens(input: 100, output: 20), at: now)
        ledger.record(first, tokens: AgentTokens(input: 50, output: 5), requests: 2,
                      at: now.addingTimeInterval(30))
        suite.expect(ledger.usage(first)?.tokens.total == 175,
                     "per-key tokens accumulate across the requests made with that key")
        suite.expect(ledger.usage(first)?.requests == 3,
                     "per-key requests count every response and any batch a record holds")
        suite.expect(ledger.usage(first)?.lastUsed == now.addingTimeInterval(30),
                     "a key records when it was last used")
        suite.expect(ledger.usage(second)?.requests == 0 && ledger.usage(second)?.tokens.total == 0,
                     "usage is attributed to the key that made the request, not to its neighbours")

        // Rotation order, and each kind of bad key taken out of it.
        let work = reference("work", "1111")
        let personal = reference("personal", "2222")
        let overflow = reference("overflow", "3333")
        for key in [work, personal, overflow] { ledger.register(key.id) }
        let keys = pool([work, personal, overflow])
        suite.expect(ledger.nextSelectable(after: work.id, in: keys, at: now)?.id == personal.id,
                     "rotation follows the pool order")

        ledger.mark(.invalid, for: personal.id, at: now)
        suite.expect(ledger.nextSelectable(after: work.id, in: keys, at: now)?.id == overflow.id,
                     "an invalid key is skipped")

        ledger.mark(.exhausted, for: overflow.id, at: now)
        suite.expect(ledger.nextSelectable(after: work.id, in: keys, at: now)?.id == work.id,
                     "rotation falls back to the only key still good")
        ledger.mark(.invalid, for: work.id, at: now)
        suite.expect(ledger.nextSelectable(after: work.id, in: keys, at: now) == nil,
                     "no key is selected while every key is bad")
        ledger.reset(work.id)

        let rateLimitedUntil = now.addingTimeInterval(60)
        ledger.mark(.rateLimited(until: rateLimitedUntil), for: personal.id, at: now)
        ledger.reset(overflow.id)
        suite.expect(ledger.nextSelectable(after: work.id, in: keys, at: now)?.id == overflow.id,
                     "a rate-limited key is skipped until its retry time")
        suite.expect(ledger.nextSelectable(after: work.id, in: keys, at: rateLimitedUntil)?.id == personal.id,
                     "a rate-limited key returns to rotation when its retry time arrives")

        ledger.record(personal.id, tokens: AgentTokens(output: 1), at: rateLimitedUntil)
        suite.expect(ledger.health(personal.id, at: rateLimitedUntil) == .ready,
                     "a successful answer clears a rate limit")

        // Only a rate limit lifts by itself. A rejected or spent key stays out
        // until it is reset or replaced, even when a request with it answers.
        ledger.mark(.invalid, for: personal.id, at: now)
        ledger.record(personal.id, tokens: AgentTokens(output: 1), at: now)
        suite.expect(ledger.health(personal.id, at: now) == .invalid,
                     "a successful answer leaves an invalid key invalid")
        ledger.mark(.exhausted, for: personal.id, at: now)
        ledger.record(personal.id, tokens: AgentTokens(output: 1), at: now)
        suite.expect(ledger.health(personal.id, at: now) == .exhausted,
                     "a successful answer leaves an exhausted key out of credit")
        ledger.reset(personal.id)

        // Status classification keeps server and network faults away from keys.
        suite.expect(AgentKeyFailure.classify(status: 401) == .invalid,
                     "401 marks the key invalid")
        suite.expect(AgentKeyFailure.classify(status: 403) == .invalid,
                     "403 marks the key invalid")
        suite.expect(AgentKeyFailure.classify(status: 402) == .exhausted,
                     "402 marks the key exhausted")
        suite.expect(AgentKeyFailure.classify(status: 429) == .rateLimited(until: nil),
                     "429 marks the key rate-limited")
        suite.expect(AgentKeyFailure.classify(status: 500) == nil,
                     "a server error leaves the key alone")
        suite.expect(AgentKeyFailure.rateLimited(until: nil).health(at: now)
                        == .rateLimited(until: now.addingTimeInterval(AgentKeyFailure.defaultCooldown)),
                     "a 429 without Retry-After uses the default cooldown")

        // Provider routes resolve the secret and advance the cursor.
        let secrets = InMemoryAgentSecretStore()
        let registryStore = InMemoryAgentKeyRegistryStore()
        let registry = AgentKeyRegistry(store: secrets, registryStore: registryStore)
        guard let addedWork = registry.addKey(provider: provider, label: "work", secret: "sk-test-1111"),
              let addedPersonal = registry.addKey(provider: provider, label: "personal", secret: "sk-test-2222"),
              let addedOverflow = registry.addKey(provider: provider, label: "overflow", secret: "sk-test-3333") else {
            suite.expect(false, "three obviously fake keys are accepted")
            return
        }

        guard let firstRoute = registry.nextRoute(at: now),
              let secondRoute = registry.nextRoute(at: now),
              let thirdRoute = registry.nextRoute(at: now) else {
            suite.expect(false, "three saved keys resolve to routes")
            return
        }
        suite.expect(firstRoute.provider == provider && firstRoute.masked == "••••2222",
                     "a route names its provider and shows only the masked tail")
        suite.expect(firstRoute.secret == "sk-test-2222" && secondRoute.secret == "sk-test-3333"
                        && thirdRoute.secret == "sk-test-1111",
                     "each route resolves the stored secret for the key it names")
        suite.expect(firstRoute.authorization == "Bearer sk-test-2222",
                     "a route carries the authorization header the provider request needs")

        // A rejected key rotates away and is never selected again.
        suite.expect(registry.reportFailure(firstRoute, status: 401, at: now),
                     "a 401 marks the routed key invalid")
        suite.expect(registry.health(addedPersonal.id, at: now) == .invalid,
                     "the rejected key's health is recorded")
        guard let afterInvalid = registry.nextRoute(at: now) else {
            suite.expect(false, "rotation continues after an invalid key")
            return
        }
        suite.expect(afterInvalid.secret == "sk-test-3333",
                     "rotation skips the invalid key and does not return it")

        // A rate limit keeps a key out only for its retry window.
        suite.expect(registry.reportFailure(secondRoute, status: 429,
                                            retryAfter: now.addingTimeInterval(120), at: now),
                     "a 429 records a rate limit on the routed key")
        guard let duringCooldown = registry.nextRoute(at: now) else {
            suite.expect(false, "rotation continues during a rate limit")
            return
        }
        suite.expect(duringCooldown.secret == "sk-test-1111",
                     "rotation avoids a rate-limited key during its cooldown")
        guard let afterCooldown = registry.nextRoute(at: now.addingTimeInterval(121)) else {
            suite.expect(false, "rotation resumes after a cooldown")
            return
        }
        suite.expect(afterCooldown.secret == "sk-test-3333",
                     "rotation returns to a rate-limited key once its retry time passes")

        // An exhausted key stays out, and a server fault does not mark one.
        suite.expect(registry.reportFailure(thirdRoute, status: 402, at: now),
                     "a 402 marks the routed key exhausted")
        suite.expect(!registry.reportFailure(thirdRoute, status: 500, at: now),
                     "a server error is not attributed to the key")
        let healthAfterServerError = registry.health(addedWork.id, at: now)
        suite.expect(healthAfterServerError == .exhausted,
                     "a server error leaves the key's health as it was")
        suite.expect(registry.report(.exhausted, for: addedPersonal.id, at: now),
                     "every remaining key can be marked bad")
        suite.expect(registry.report(.exhausted, for: addedOverflow.id, at: now),
                     "a rate-limited key can also lose its allowance")
        suite.expect(registry.nextRoute(at: now.addingTimeInterval(121)) == nil,
                     "no route is offered while every key is bad")

        // The published surface is masked and counts the right key.
        registry.resetKey(addedWork.id)
        registry.resetKey(addedPersonal.id)
        guard let counted = registry.nextRoute(at: now.addingTimeInterval(200)) else {
            suite.expect(false, "a reset key resolves again")
            return
        }
        registry.record(counted, tokens: AgentTokens(input: 12, output: 3), requests: 1,
                        at: now.addingTimeInterval(200))
        let rows = registry.usageRows(at: now.addingTimeInterval(200))
        suite.expect(rows.count == 3, "one masked row is published per saved key")
        suite.expect(rows.contains { $0.id == counted.key.id && $0.tokens.total == 15 && $0.requests == 1 },
                     "the published row carries the routed key's tokens and requests")
        suite.expect(!rowText(rows).contains("sk-test-"),
                     "no published row carries key material")
        suite.expect(rows.allSatisfy { $0.maskedLabel.contains("••••") },
                     "every published row is masked")

        // A rejected key stays out of routing even when a request with it
        // answers: only an explicit reset returns it.
        let settledStore = InMemoryAgentKeyRegistryStore()
        let settledRegistry = AgentKeyRegistry(store: InMemoryAgentSecretStore(), registryStore: settledStore)
        guard let settledWork = settledRegistry.addKey(provider: provider, label: "settled-work",
                                                       secret: "sk-test-4444"),
              let settledSpare = settledRegistry.addKey(provider: provider, label: "settled-spare",
                                                        secret: "sk-test-5555"),
              let settledRoute = settledRegistry.nextRoute(at: now) else {
            suite.expect(false, "two health-transition keys are saved")
            return
        }
        let settledRows = settledRegistry.usageRows(at: now)
        suite.expect(settledRows.count == 2 && settledRows.contains { $0.id == settledSpare.id },
                     "both health-transition keys are published")
        suite.expect(settledRegistry.reportFailure(settledRoute, status: 401, at: now),
                     "the routed key is marked invalid")
        settledRegistry.record(settledRoute, tokens: AgentTokens(input: 4), at: now)
        suite.expect(settledRegistry.health(settledRoute.key.id, at: now) == .invalid,
                     "an answered request does not clear a key that failed auth")
        suite.expect(settledRegistry.nextRoute(at: now)?.key.id == settledWork.id,
                     "an invalid key stays out of routing after an answered request")
        suite.expect(settledRegistry.resetKey(settledRoute.key.id),
                     "the operator can reset the rejected key")
        suite.expect(settledRegistry.nextRoute(at: now)?.key.id == settledRoute.key.id,
                     "an explicit reset returns the rejected key to routing")

        // Persistence keeps counters and health, never the secret or its tail.
        let persisted = registryStore.state
        let data = JSONAgentKeyRegistryStore.encode(persisted)
        let json = String(data: data, encoding: .utf8) ?? ""
        suite.expect(json.contains(addedWork.id.uuidString) && json.contains("\"work\""),
                     "the persisted state records key ids and labels")
        suite.expect(!json.contains("sk-test-") && !json.contains("tail") && !json.contains("••"),
                     "the persisted state carries neither a secret nor a tail")
        let decoded = JSONAgentKeyRegistryStore.decode(data)
        suite.expect(decoded.keys.count == 3 && decoded.usages.count == 3,
                     "the persisted state decodes with its keys and usage")
        suite.expect(decoded.usages.contains { $0.id == addedOverflow.id && $0.health == .exhausted },
                     "a key's bad health survives persistence")
        suite.expect(JSONAgentKeyRegistryStore.decode(Data("not json".utf8)).keys.isEmpty,
                     "a file another build wrote reads as no keys")

        let restored = AgentKeyRegistry(store: secrets, registryStore: registryStore)
        suite.expect(restored.pool.keys.map(\.label) == ["work", "personal", "overflow"],
                     "a new launch restores the key order")
        suite.expect(restored.pool.keys.map(\.tail) == ["1111", "2222", "3333"],
                     "a new launch rebuilds each tail from the keychain, never from disk")
        suite.expect(restored.health(addedOverflow.id, at: now) == .exhausted,
                     "a new launch keeps a key marked bad out of rotation")
        suite.expect(restored.nextRoute(at: now.addingTimeInterval(300))?.secret == "sk-test-2222",
                     "a restored pool skips the bad key and uses the next one")

        // Removing a key drops its usage, its secret and its route.
        let removable = restored.pool.keys[2].id
        restored.removeKey(removable)
        suite.expect(restored.pool.keys.count == 2 && restored.usage(removable) == nil,
                     "removing a key drops its reference and its counters")
        suite.expect(secrets.secret(for: removable) == nil,
                     "removing a key drops its secret")
        suite.expect(!JSONAgentKeyRegistryStore.decode(
                        JSONAgentKeyRegistryStore.encode(registryStore.state)).usages.contains { $0.id == removable },
                     "removing a key drops its persisted counters")
    }
}

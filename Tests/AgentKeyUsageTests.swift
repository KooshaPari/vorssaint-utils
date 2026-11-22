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

        // Every change publishes once, so the agents page can republish without
        // polling, and the published row carries what was recorded.
        var publications = 0
        let publicationObserver = NotificationCenter.default.addObserver(
            forName: AgentKeyRegistry.usageDidChange, object: nil, queue: nil) { _ in
                publications += 1
            }
        let publishRegistry = AgentKeyRegistry(store: InMemoryAgentSecretStore(),
                                               registryStore: InMemoryAgentKeyRegistryStore())
        guard let publishKey = publishRegistry.addKey(provider: provider, label: "publish",
                                                      secret: "sk-test-7777"),
              let publishRoute = publishRegistry.nextRoute(at: now) else {
            suite.expect(false, "a key for publication is saved and routed")
            return
        }
        suite.expect(publications == 1, "saving a key publishes one usage change")
        publishRegistry.record(publishRoute, tokens: AgentTokens(input: 7, output: 2), at: now)
        suite.expect(publications == 2, "recording usage publishes one usage change")
        suite.expect(publishRegistry.usageRows(at: now).first?.tokens.total == 9,
                     "the published row carries the usage that was recorded")
        suite.expect(publishRegistry.reportFailure(publishRoute, status: 401, at: now)
                        && publications == 3,
                     "reporting a key failure publishes one usage change")
        suite.expect(publishRegistry.resetKey(publishKey.id) && publications == 4,
                     "resetting a key publishes one usage change")
        publishRegistry.removeKey(publishKey.id)
        suite.expect(publications == 5, "removing a key publishes one usage change")
        NotificationCenter.default.removeObserver(publicationObserver)

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

        // A rate limit keeps its retry time through the file, and still lifts
        // by itself at that time.
        let limitedUntil = now.addingTimeInterval(600)
        let limitedID = UUID()
        let limitedData = JSONAgentKeyRegistryStore.encode(AgentKeyRegistryState(
            keys: [AgentKeyRecord(id: limitedID, provider: provider, label: "limited")],
            cursor: limitedID,
            usages: [AgentKeyUsage(id: limitedID, health: .rateLimited(until: limitedUntil))]))
        let limitedHealth = JSONAgentKeyRegistryStore.decode(limitedData).usages.first?.health
        suite.expect(limitedHealth == .rateLimited(until: limitedUntil),
                     "a rate limit keeps its retry time through the registry file")
        suite.expect(limitedHealth?.isSelectable(at: limitedUntil.addingTimeInterval(-1)) == false
                        && limitedHealth?.isSelectable(at: limitedUntil) == true,
                     "a restored rate limit holds the key out until its retry time")

        let restored = AgentKeyRegistry(store: secrets, registryStore: registryStore)
        suite.expect(restored.pool.keys.map(\.label) == ["work", "personal", "overflow"],
                     "a new launch restores the key order")
        suite.expect(restored.pool.keys.map(\.tail) == ["1111", "2222", "3333"],
                     "a new launch rebuilds each tail from the keychain, never from disk")
        suite.expect(restored.health(addedOverflow.id, at: now) == .exhausted,
                     "a new launch keeps a key marked bad out of rotation")
        suite.expect(restored.nextRoute(at: now.addingTimeInterval(300))?.secret == "sk-test-2222",
                     "a restored pool skips the bad key and uses the next one")

        // A saved key whose secret is gone is dropped, and the pruned registry
        // is written back, so a stale id cannot survive in the file.
        let keptID = UUID()
        let orphanID = UUID()
        let orphanState = AgentKeyRegistryState(
            keys: [AgentKeyRecord(id: keptID, provider: provider, label: "kept"),
                   AgentKeyRecord(id: orphanID, provider: provider, label: "orphan")],
            cursor: orphanID,
            usages: [AgentKeyUsage(id: keptID), AgentKeyUsage(id: orphanID, requests: 9)])
        let keptSecrets = InMemoryAgentSecretStore()
        _ = keptSecrets.set("sk-test-6666", for: keptID)
        let prunedStore = InMemoryAgentKeyRegistryStore(orphanState)
        let prunedRegistry = AgentKeyRegistry(store: keptSecrets, registryStore: prunedStore)
        suite.expect(prunedRegistry.pool.keys.map(\.id) == [keptID],
                     "a saved key whose secret is gone is not restored")
        suite.expect(prunedStore.state.keys.map(\.id) == [keptID],
                     "loading writes back only the keys that still resolve")
        suite.expect(!prunedStore.state.usages.contains { $0.id == orphanID },
                     "the pruned key's counters go with it")
        suite.expect(prunedStore.state.cursor == nil && prunedStore.saves == 1,
                     "the pruned registry is saved once with no stale cursor")

        // A keychain that cannot be read now is not one that lost the item.
        // Nothing is pruned while a secret may still be there.
        final class UnreadableKeychain: AgentSecretStore {
            private var secrets: [UUID: String]
            init(_ secrets: [UUID: String]) { self.secrets = secrets }
            func set(_ secret: String, for id: UUID) -> Bool { secrets[id] = secret; return true }
            func secret(for id: UUID) -> String? { nil }
            func isMissing(for id: UUID) -> Bool { false }
            func remove(for id: UUID) -> Bool { secrets.removeValue(forKey: id) != nil }
        }
        let lockedStore = InMemoryAgentKeyRegistryStore(orphanState)
        let lockedRegistry = AgentKeyRegistry(store: UnreadableKeychain([keptID: "sk-test-6666"]),
                                              registryStore: lockedStore)
        suite.expect(lockedRegistry.pool.isEmpty,
                     "no key is offered while its secret cannot be read")
        suite.expect(lockedStore.state.keys.count == 2 && lockedStore.saves == 0,
                     "an unreadable keychain leaves the saved registry untouched")

        // The restored registry routes and publishes only what it could resolve.
        suite.expect(prunedRegistry.nextRoute(at: now)?.secret == "sk-test-6666",
                     "a restore with a missing secret routes to the key that still resolves")
        suite.expect(prunedRegistry.usageRows(at: now).map(\.id) == [keptID],
                     "a restore with a missing secret publishes only the key that resolves")

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

        // A file write no longer holds the state lock: a reader on another
        // thread finishes while the write is still in flight. The old code
        // saved under the lock, so this reader would wait for the file.
        final class BlockingRegistryStore: AgentKeyRegistryStore {
            private var state: AgentKeyRegistryState
            let started = DispatchSemaphore(value: 0)
            let release = DispatchSemaphore(value: 0)
            init(_ state: AgentKeyRegistryState) { self.state = state }
            func load() -> AgentKeyRegistryState { state }
            func save(_ state: AgentKeyRegistryState) -> Bool {
                started.signal()
                release.wait()
                self.state = state
                return true
            }
        }
        let blockingID = UUID()
        let blockingStore = BlockingRegistryStore(AgentKeyRegistryState(
            keys: [AgentKeyRecord(id: blockingID, provider: provider, label: "blocking")],
            cursor: blockingID,
            usages: [AgentKeyUsage(id: blockingID)]))
        let blockingSecrets = InMemoryAgentSecretStore()
        _ = blockingSecrets.set("sk-test-8888", for: blockingID)
        let blockingRegistry = AgentKeyRegistry(store: blockingSecrets, registryStore: blockingStore)
        guard let blockingRoute = blockingRegistry.nextRoute(at: now) else {
            suite.expect(false, "a key for the write-contention check is routed")
            return
        }
        let writeFinished = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            blockingRegistry.record(blockingRoute, tokens: AgentTokens(input: 1), at: now)
            writeFinished.signal()
        }
        let writeStarted = blockingStore.started.wait(timeout: .now() + 3) == .success
        var rowsWhileWriting = 0
        let readFinished = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            rowsWhileWriting = blockingRegistry.usageRows(at: now).count
            readFinished.signal()
        }
        let readReturned = readFinished.wait(timeout: .now() + 3) == .success
        blockingStore.release.signal()
        let writeReturned = writeFinished.wait(timeout: .now() + 3) == .success
        suite.expect(writeStarted && readReturned && rowsWhileWriting == 1 && writeReturned,
                     "a reader completes while the registry file write is in flight")
    }
}

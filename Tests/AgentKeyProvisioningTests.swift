// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The OpenCode Go key surface in Settings: adding and removing a key reach the
/// keychain-backed registry, every row stays masked, a failed add names no
/// secret, and the surfaces that show agent usage read the same rows.
enum AgentKeyProvisioningTests {
    static func run(_ suite: TestSuite) {
        let provider = AgentKeyProvider.openCodeGo
        let secrets = InMemoryAgentSecretStore()
        let registry = AgentKeyRegistry(store: secrets)
        let model = AgentKeyProvisioner(registry: registry, observesChanges: false)

        // Adding from Settings saves a key behind a masked row.
        suite.expect(model.isEmpty && model.rows.isEmpty, "a new key surface lists no keys")
        suite.expect(!model.add(label: "work", secret: "sk-test"),
                     "a key shorter than a provider key is refused")
        suite.expect(model.lastError == .secretTooShort,
                     "a refused key says it is too short without naming it")
        suite.expect(model.rows.isEmpty && registry.isEmpty,
                     "a refused key saves no row and no secret")
        suite.expect(model.add(label: "  work  ", secret: "sk-test-1111"),
                     "a real key is saved from Settings")
        suite.expect(model.lastError == nil, "a successful add clears the failure")
        suite.expect(model.rows.count == 1 && model.rows[0].maskedLabel == "work ••••1111",
                     "the new key has one masked row with its trimmed label")
        suite.expect(registry.pool.keys.first?.label == "work", "the saved label is trimmed")
        suite.expect(secrets.secret(for: registry.pool.keys.first?.id ?? UUID()) == "sk-test-1111",
                     "the typed key reaches the keychain")
        suite.expect(!model.rows.map(\.maskedLabel).joined().contains("sk-test-"),
                     "no row carries key material")
        suite.expect(model.rows.allSatisfy { $0.masked.hasPrefix("••••") && $0.masked.count == 8 },
                     "every row shows the mask and only the four-character tail")

        // A blank name becomes the product's name, a key for another provider
        // stays out, and removal drops the row, the secret and the counters.
        suite.expect(model.add(label: "   ", secret: "sk-test-2222"),
                     "a key with no name is still saved")
        suite.expect(model.rows.contains { $0.label == AgentKeyProvisioner.defaultLabel },
                     "a nameless key takes the product name as its label")
        _ = registry.addKey(provider: "another-provider", label: "elsewhere", secret: "sk-test-3333")
        model.refresh()
        suite.expect(model.rows.count == 2,
                     "a key saved for another provider stays out of this surface")
        guard let removable = model.rows.first(where: { $0.label == "work" }) else {
            suite.expect(false, "the work key is listed")
            return
        }
        model.remove(removable.id)
        suite.expect(model.rows.count == 1 && registry.pool.keys.count == 2,
                     "removing a key from Settings drops its row")
        suite.expect(secrets.secret(for: removable.id) == nil,
                     "removing a key from Settings drops its keychain secret")
        suite.expect(registry.usage(removable.id) == nil,
                     "removing a key from Settings drops its counters")

        // A rejected key is shown and can be allowed again from the same row.
        guard let kept = model.rows.first else {
            suite.expect(false, "one key remains after the removal")
            return
        }
        suite.expect(registry.report(.invalid, for: kept.id), "a rejected key's health is recorded")
        model.refresh()
        suite.expect(model.rows.first?.health == .invalid, "a rejected key reads as rejected")
        suite.expect(model.reset(kept.id), "Settings can bring a rejected key back")
        suite.expect(model.rows.first?.health == .ready, "a key allowed again reads ready")

        // Saving or removing a key posts the change every surface follows.
        var notices = 0
        let token = NotificationCenter.default.addObserver(forName: AgentKeyRegistry.usageDidChange,
                                                           object: nil, queue: nil) { _ in notices += 1 }
        _ = registry.addKey(provider: provider, label: "late", secret: "sk-test-4444")
        registry.removeKey(removable.id)
        NotificationCenter.default.removeObserver(token)
        suite.expect(notices >= 2, "each key change posts the surface refresh")

        // The app-side call sites exist and are the ones the report names.
        func source(_ path: String) -> String {
            (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        }
        let provisioner = source("Sources/Vorssaint/Services/AgentUsage/AgentKeyProvisioner.swift")
        let surface = source("Sources/Vorssaint/UI/Settings/AgentKeySettings.swift")
        let page = source("Sources/Vorssaint/UI/Settings/NotchAgentsSettings.swift")
        let service = source("Sources/Vorssaint/Services/AgentUsage/AgentUsageService.swift")
        let card = source("Sources/Vorssaint/UI/Notch/NotchAgentsView.swift")
        suite.expect(provisioner.contains("registry.addKey(") && provisioner.contains("registry.removeKey(")
                        && provisioner.contains("registry.resetKey("),
                     "the settings model calls the registry's add, remove and reset")
        suite.expect(surface.contains("SecureField"), "a key is entered behind a secure field")
        suite.expect(surface.contains("keys.add(") && surface.contains("keys.remove("),
                     "the settings surface adds and removes through the model")
        suite.expect(surface.contains("secret = \"\""), "the entered key is cleared once it is saved")
        suite.expect(!surface.contains("Text(secret"), "the entered key is never drawn as text")
        suite.expect(page.contains("AgentKeySettings("), "the AI settings page places the key surface")
        suite.expect(service.contains("usageRows") && service.contains("enabled.contains(.opencode)"),
                     "agent usage publishes per-key rows only while OpenCode is on")
        suite.expect(card.contains("snapshot.keyUsage"), "the agents page draws the per-key rows")
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import Foundation

/// Why an add from the settings surface did not save a key. It carries no
/// text and no secret: the surface supplies the words, so a failure can be
/// shown without echoing what was typed.
enum AgentKeyProvisioningError: Equatable {
    case secretTooShort
    case saveFailed
}

/// The state behind the AI page's OpenCode Go key surface. It is the app's
/// one caller of the registry's provisioning API, so adding, removing and
/// resetting a key happen from Settings without touching a file, and the
/// rows it publishes are always the registry's masked ones.
final class AgentKeyProvisioner: ObservableObject {
    /// The label a key gets when the name field is left blank. It is a
    /// product name, so it stays untranslated like the other agent names.
    static let defaultLabel = "OpenCode Go"

    /// One masked row per saved key of this provider, in rotation order.
    @Published private(set) var rows: [AgentKeyUsageRow] = []
    /// The last add failure, cleared by the next successful add.
    @Published private(set) var lastError: AgentKeyProvisioningError?

    let provider: String
    private let registry: AgentKeyRegistry
    private let now: () -> Date
    private var observer: NSObjectProtocol?

    init(registry: AgentKeyRegistry = .shared, provider: String = AgentKeyProvider.openCodeGo,
         observesChanges: Bool = true, now: @escaping () -> Date = Date.init) {
        self.registry = registry
        self.provider = provider
        self.now = now
        refresh()
        guard observesChanges else { return }
        // The settings page and the agents card read the same registry from
        // different threads, so the surface follows its notifications rather
        // than polling it on every draw.
        observer = NotificationCenter.default.addObserver(forName: AgentKeyRegistry.usageDidChange,
                                                          object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    var isEmpty: Bool { rows.isEmpty }

    /// Reads the masked rows again. The provider filter keeps a key saved for
    /// another provider out of this surface.
    func refresh() {
        rows = registry.usageRows(at: now()).filter { $0.provider == provider }
    }

    /// Saves one key and clears `lastError`. The secret goes to the keychain
    /// through the registry and is never held here beyond this call.
    @discardableResult
    func add(label: String, secret: String) -> Bool {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedLabel.isEmpty ? Self.defaultLabel : trimmedLabel
        guard registry.addKey(provider: provider, label: name, secret: secret) != nil else {
            let trimmedSecret = secret.trimmingCharacters(in: .whitespacesAndNewlines)
            lastError = trimmedSecret.count < AgentKeyRegistry.minimumSecretLength ? .secretTooShort : .saveFailed
            refresh()
            return false
        }
        lastError = nil
        refresh()
        return true
    }

    func remove(_ id: UUID) {
        registry.removeKey(id)
        refresh()
    }

    /// Brings a key the operator says is usable back into rotation.
    @discardableResult
    func reset(_ id: UUID) -> Bool {
        let changed = registry.resetKey(id)
        refresh()
        return changed
    }
}

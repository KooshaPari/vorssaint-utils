// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Every provider this app reaches over the network is declared here, once.
/// There is no default route: a provider missing from this table is refused by
/// `EgressPolicy.resolve` rather than treated as direct.
enum ProviderEgressDefaults {
    static let declarations: [ProviderEgressRoute] = [
        // The price list is this project's own file. It is declared direct so
        // the route is visible in code and cannot be inferred from silence.
        ProviderEgressRoute(provider: "agent-prices", path: .direct),
    ]

    /// nil when the declaration table itself is malformed. Callers must treat
    /// that as refusal, never as permission to go direct.
    static let policy: EgressPolicy? = try? EgressPolicy(declarations)
}

/// Applies a resolved route to a URL session. A direct binding is a session
/// with no proxy; a pinned binding carries only the probed SOCKS5 listener.
/// There is no intermediate or best-effort configuration.
enum ProviderEgressSession {
    @discardableResult
    static func configure(_ configuration: URLSessionConfiguration,
                          for binding: EgressBinding) -> URLSessionConfiguration {
        switch binding.path {
        case .direct:
            configuration.connectionProxyDictionary = nil
        case .mullvadSOCKS5(let endpoint):
            configuration.connectionProxyDictionary = [
                "SOCKSEnable": 1,
                "SOCKSProxy": endpoint.host,
                "SOCKSPort": Int(endpoint.port),
            ]
        }
        return configuration
    }
}

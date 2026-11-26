// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The local Mullvad SOCKS5 listener a provider is pinned to. It is an address
/// and a port only: no secret material belongs on this type, and none is read
/// anywhere in this file.
struct MullvadSOCKS5Endpoint: Equatable, Hashable, Sendable {
    let host: String
    let port: UInt16
}

/// A declared egress path for one provider. There are exactly two shapes:
/// explicit direct, or pinned to a probed Mullvad listener. Nothing else is a
/// valid route, so no provider can reach the network by accident.
enum EgressPath: Equatable, Sendable {
    case direct
    case mullvadSOCKS5(MullvadSOCKS5Endpoint)
}

/// One provider's declaration. A provider is named here once, in code, rather
/// than inheriting a default.
struct ProviderEgressRoute: Equatable, Sendable {
    let provider: String
    let path: EgressPath

    init(provider: String, path: EgressPath) {
        self.provider = provider
        self.path = path
    }
}

/// A route that has passed its declaration and, for a pinned path, a successful
/// availability probe. Only `EgressPolicy.resolve` may produce one.
struct EgressBinding: Equatable, Sendable {
    let provider: String
    let path: EgressPath
}

/// Named failures. Every one of these is terminal for the request it accompanies;
/// none carries a usable route, so a caller cannot continue by going direct.
enum EgressError: Error, Equatable, Sendable {
    case providerNotDeclared(String)
    case duplicateDeclaration(String)
    case invalidDeclaration(String)
    case egressUnavailable(provider: String, reason: MullvadUnavailableReason)
}

extension EgressError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .providerNotDeclared(let provider):
            return "No egress route is declared for \(provider)."
        case .duplicateDeclaration(let provider):
            return "The egress route for \(provider) is declared more than once."
        case .invalidDeclaration(let provider):
            return "The egress route declaration for \(provider) is invalid."
        case .egressUnavailable(let provider, let reason):
            return "The declared egress for \(provider) is unavailable (\(reason.rawValue)); "
                + "the request was refused rather than sent directly."
        }
    }
}

/// Per-provider egress policy. Initialisation validates every declaration and
/// resolution is the only way to learn a route, so an unknown provider fails
/// closed instead of behaving like a direct one.
struct EgressPolicy: Sendable {
    private let routes: [String: EgressPath]

    /// A policy with no declarations: every lookup is refused. A malformed
    /// declaration table degrades to this, never to a direct route.
    static let empty = EgressPolicy(routes: [:])

    private init(routes: [String: EgressPath]) {
        self.routes = routes
    }

    /// Rejects an empty provider name, a duplicate provider, and a pinned
    /// endpoint that could not be a listener. A failed declaration table leaves
    /// the caller with no policy; callers must treat that as refusal.
    init(_ declarations: [ProviderEgressRoute]) throws {
        var routes: [String: EgressPath] = [:]
        for declaration in declarations {
            let provider = declaration.provider.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !provider.isEmpty, provider == declaration.provider else {
                throw EgressError.invalidDeclaration(declaration.provider)
            }
            guard routes[provider] == nil else {
                throw EgressError.duplicateDeclaration(provider)
            }
            if case .mullvadSOCKS5(let endpoint) = declaration.path {
                let host = endpoint.host.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !host.isEmpty, endpoint.port != 0 else {
                    throw EgressError.invalidDeclaration(provider)
                }
            }
            routes[provider] = declaration.path
        }
        self.routes = routes
    }

    /// The declaration as written, or nil when the provider was never declared.
    /// Exposed for diagnostics; callers must still resolve before a request.
    func declaredPath(for provider: String) -> EgressPath? {
        routes[provider]
    }

    /// The single place a request learns its egress.
    ///
    /// A direct declaration resolves immediately and never consults the probe.
    /// A pinned declaration resolves only when the probe reports a verified
    /// listener; every unavailable state returns `egressUnavailable`. The
    /// pinned branch has no other exit and in particular never constructs a
    /// direct binding.
    func resolve(provider: String, probe: MullvadProbing) -> Result<EgressBinding, EgressError> {
        guard let path = routes[provider] else {
            return .failure(.providerNotDeclared(provider))
        }
        switch path {
        case .direct:
            return .success(EgressBinding(provider: provider, path: .direct))
        case .mullvadSOCKS5(let endpoint):
            // egress-guarantee:begin
            // Refusal only. This region may return the probed listener or a
            // named failure; a direct binding here would be a silent bypass.
            switch probe.availability(expecting: endpoint) {
            case .available(let verified):
                return .success(EgressBinding(provider: provider, path: .mullvadSOCKS5(verified)))
            case .unavailable(let reason):
                return .failure(.egressUnavailable(provider: provider, reason: reason))
            }
            // egress-guarantee:end
        }
    }
}

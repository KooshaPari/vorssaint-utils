// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Why a tailnet is not usable. Every one of these is a named state: a caller
/// can report it, and none of them can be mistaken for a live tailnet with no
/// peers. Only `.live` carries a peer list.
enum TailnetUnavailableReason: String, Equatable, CaseIterable {
    /// No Tailscale binary or app bundle was found.
    case notInstalled
    /// The binary exists but the daemon is not running.
    case stopped
    /// The daemon is up but this node is not logged in or not approved.
    case unauthenticated
    /// The status command did not answer inside its bound and was killed.
    case statusTimeout
    /// The status command answered with empty, truncated or unexpected JSON.
    case malformedStatus
}

/// The backend states `tailscale status --json` reports. Only `running` means
/// traffic can flow. An unrecognised state is treated as malformed rather than
/// assumed healthy.
enum TailnetBackendState: String, Equatable {
    case running = "Running"
    case stopped = "Stopped"
    case starting = "Starting"
    case needsLogin = "NeedsLogin"
    case needsMachineAuth = "NeedsMachineAuth"
    case noState = "NoState"
}

struct TailnetSelfNode: Equatable {
    let id: String
    let hostName: String
    let dnsName: String
    let addresses: [String]
}

struct TailnetPeer: Equatable {
    let id: String
    let hostName: String
    let dnsName: String
    let addresses: [String]
    let online: Bool

    /// Every identifier this peer can be named by, normalised for comparison.
    /// A node ID is always present; host and DNS names appear only when the
    /// status payload carried them.
    var identifiers: Set<String> {
        TailnetSupport.normalizedIdentifiers([id, hostName, dnsName])
    }
}

struct TailnetStatus: Equatable {
    let backendState: TailnetBackendState
    let selfNode: TailnetSelfNode?
    let peers: [TailnetPeer]
}

enum TailnetAvailability: Equatable {
    case live(TailnetStatus)
    case unavailable(TailnetUnavailableReason)

    var isLive: Bool { if case .live = self { return true }; return false }

    var peers: [TailnetPeer] {
        if case let .live(status) = self { return status.peers }
        return []
    }
}

/// Where a listener is allowed to bind. There are exactly two scopes: loopback
/// on this machine, or one address that provably belongs to the local tailnet
/// node. A wildcard bind is never a member of this type.
enum TailnetBindHost: Equatable {
    case loopback
    case tailnet(String)

    var address: String {
        switch self {
        case .loopback: return "127.0.0.1"
        case let .tailnet(address): return address
        }
    }
}

enum TailnetBindRefusal: String, Equatable {
    /// The request named every interface (`0.0.0.0`, `::`, `*` or empty).
    case wildcardAddress
    /// The request named an address outside loopback and the tailnet ranges.
    case outsideScope
    /// The request named a tailnet address that this node does not hold.
    case notLocalTailnetAddress
    /// A tailnet bind was requested while no live tailnet exists.
    case tailnetUnavailable
}

enum TailnetBindResolution: Equatable {
    case host(TailnetBindHost)
    case refused(TailnetBindRefusal)
}

enum TailnetPeerRejection: String, Equatable {
    /// No live tailnet status to check the peer against.
    case unavailable
    /// The address is not in the peer table at all.
    case unknownPeer
    /// The address belongs to a peer whose identity is not expected.
    case unexpectedIdentity
    /// The identity matches, but the node is reported offline.
    case offline
}

enum TailnetPeerVerdict: Equatable {
    case verified(TailnetPeer)
    case unverified(TailnetPeerRejection)

    var isVerified: Bool { if case .verified = self { return true }; return false }
}

enum TailnetSupport {
    /// Every path the macOS Tailscale build is seen at: the GUI app ships its
    /// own CLI, and the standalone CLI lands in either Homebrew prefix.
    static let cliCandidates = [
        "/Applications/Tailscale.app/Contents/MacOS/Tailscale",
        "/opt/homebrew/bin/tailscale",
        "/usr/local/bin/tailscale",
        "/usr/bin/tailscale",
    ]

    /// The status probe reads a small JSON document; anything larger is not a
    /// status payload and is truncated by the bounded runner anyway.
    static let statusArguments = ["status", "--json"]
    static let statusTimeout: TimeInterval = 4

    static func locateCLI(isExecutable: (String) -> Bool) -> String? {
        cliCandidates.first(where: isExecutable)
    }

    // MARK: - Reading status

    /// Runs the status command through an injected bounded runner. A missing
    /// binary, a non-zero exit, a kill on timeout and an unparsable payload are
    /// four distinct unavailable states.
    static func availability(cliPath: String?,
                             timeout: TimeInterval = statusTimeout,
                             run: (String, [String], TimeInterval) -> (status: Int32, output: String))
        -> TailnetAvailability {
        guard let cliPath else { return .unavailable(.notInstalled) }
        let result = run(cliPath, statusArguments, timeout)
        // A negative status is the runner's own timeout/launch failure signal.
        if result.status < 0 { return .unavailable(.statusTimeout) }
        if result.status != 0 { return .unavailable(.stopped) }
        return parseStatus(result.output)
    }

    static func parseStatus(_ output: String) -> TailnetAvailability {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawState = root["BackendState"] as? String,
              let state = TailnetBackendState(rawValue: rawState) else {
            return .unavailable(.malformedStatus)
        }

        switch state {
        case .stopped, .starting, .noState:
            return .unavailable(.stopped)
        case .needsLogin, .needsMachineAuth:
            return .unavailable(.unauthenticated)
        case .running:
            guard let peers = parsePeers(root["Peer"]) else {
                return .unavailable(.malformedStatus)
            }
            return .live(TailnetStatus(backendState: state,
                                       selfNode: parseSelf(root["Self"]),
                                       peers: peers))
        }
    }

    /// `Peer` is absent on a node with no peers, which is a normal live state.
    /// A present value of the wrong shape, or a peer record without any
    /// identity, is not silently dropped: the whole payload is untrustworthy.
    private static func parsePeers(_ value: Any?) -> [TailnetPeer]? {
        guard let value else { return [] }
        guard let table = value as? [String: Any] else { return nil }
        var peers: [TailnetPeer] = []
        for key in table.keys.sorted() {
            guard let record = table[key] as? [String: Any] else { return nil }
            let id = (record["ID"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? key
            guard !id.isEmpty else { return nil }
            let hostName = record["HostName"] as? String ?? ""
            let dnsName = record["DNSName"] as? String ?? ""
            guard !normalizedIdentifiers([id, hostName, dnsName]).isEmpty else { return nil }
            guard let addresses = stringArray(record["TailscaleIPs"]) else { return nil }
            let online = record["Online"] as? Bool ?? false
            peers.append(TailnetPeer(id: id, hostName: hostName, dnsName: dnsName,
                                     addresses: addresses, online: online))
        }
        return peers
    }

    private static func parseSelf(_ value: Any?) -> TailnetSelfNode? {
        guard let record = value as? [String: Any] else { return nil }
        guard let addresses = stringArray(record["TailscaleIPs"]) else { return nil }
        return TailnetSelfNode(id: record["ID"] as? String ?? "",
                               hostName: record["HostName"] as? String ?? "",
                               dnsName: record["DNSName"] as? String ?? "",
                               addresses: addresses)
    }

    private static func stringArray(_ value: Any?) -> [String]? {
        guard let value else { return [] }
        guard let array = value as? [Any] else { return nil }
        var strings: [String] = []
        for element in array {
            guard let string = element as? String else { return nil }
            strings.append(string)
        }
        return strings
    }

    // MARK: - Bind scope

    /// Resolves an explicit bind request to loopback or one local tailnet
    /// address. Nothing else is representable, so a caller cannot end up bound
    /// to every interface by accident: wildcard requests are refused by name.
    static func resolveBind(_ requested: String, availability: TailnetAvailability) -> TailnetBindResolution {
        let request = requested.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !request.isEmpty else { return .refused(.wildcardAddress) }
        switch request {
        case "0.0.0.0", "::", "*":
            return .refused(.wildcardAddress)
        case "loopback", "127.0.0.1", "localhost", "::1":
            return .host(.loopback)
        case "tailnet", "tailscale":
            guard case let .live(status) = availability,
                  let address = status.selfNode?.addresses.first(where: isTailnetAddress) else {
                return .refused(.tailnetUnavailable)
            }
            return .host(.tailnet(address))
        default:
            break
        }
        guard isTailnetAddress(request) else { return .refused(.outsideScope) }
        guard case let .live(status) = availability,
              status.selfNode?.addresses.contains(request) == true else {
            return .refused(.notLocalTailnetAddress)
        }
        return .host(.tailnet(request))
    }

    /// The two address ranges a tailnet uses: 100.64.0.0/10 (CGNAT) and the
    /// fd7a:115c:a1e0::/48 IPv6 prefix.
    static func isTailnetAddress(_ address: String) -> Bool {
        isTailnetIPv4(address) || address.hasPrefix("fd7a:115c:a1e0:")
    }

    private static func isTailnetIPv4(_ address: String) -> Bool {
        let parts = address.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4,
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) && Int($0).map { (0...255).contains($0) } == true }),
              let first = Int(parts[0]), let second = Int(parts[1]) else { return false }
        return first == 100 && (64...127).contains(second)
    }

    // MARK: - Peer identity

    /// Looks the peer up by address and checks its node identity against the
    /// expected set. An address that is not in the peer table is unknown; a
    /// peer whose identifiers are not expected is untrusted; an expected but
    /// offline peer is still unverified.
    static func verifyPeer(address: String,
                           availability: TailnetAvailability,
                           expectedIdentities: Set<String>) -> TailnetPeerVerdict {
        guard case let .live(status) = availability else { return .unverified(.unavailable) }
        let address = address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !address.isEmpty,
              let peer = status.peers.first(where: { $0.addresses.contains { $0.lowercased() == address } })
        else { return .unverified(.unknownPeer) }
        let expected = normalizedIdentifiers(Array(expectedIdentities))
        guard !expected.isEmpty, !peer.identifiers.isDisjoint(with: expected) else {
            return .unverified(.unexpectedIdentity)
        }
        guard peer.online else { return .unverified(.offline) }
        return .verified(peer)
    }

    static func normalizedIdentifiers(_ values: [String]) -> Set<String> {
        Set(values.compactMap { value in
            var normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            while normalized.hasSuffix(".") { normalized.removeLast() }
            return normalized.isEmpty ? nil : normalized
        })
    }
}

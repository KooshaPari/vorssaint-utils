// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The production status parser, bind resolver and peer verifier driven by
/// obviously fake payloads and a fake CLI. No tailscale binary is run, no
/// daemon is contacted and no listener is opened.
enum TailnetTests {
    enum CLI {
        static var status: Int32 = 0
        static var output = ""
        static var calls: [(path: String, arguments: [String], timeout: TimeInterval)] = []
        static func run(_ path: String, _ arguments: [String], _ timeout: TimeInterval)
            -> (status: Int32, output: String) {
            calls.append((path, arguments, timeout))
            return (status, output)
        }
        static func reset() { status = 0; output = ""; calls = [] }
    }

    private static let selfAddresses = ["100.101.102.103", "fd7a:115c:a1e0::1"]

    private static let liveWithPeers = """
        {
          "BackendState": "Running",
          "Self": {
            "ID": "self-node-1",
            "HostName": "fake-laptop",
            "DNSName": "fake-laptop.tailnet-fake.ts.net.",
            "TailscaleIPs": ["100.101.102.103", "fd7a:115c:a1e0::1"]
          },
          "Peer": {
            "node-a": {
              "ID": "node-a",
              "HostName": "fake-peer-a",
              "DNSName": "fake-peer-a.tailnet-fake.ts.net.",
              "TailscaleIPs": ["100.64.0.9"],
              "Online": true
            },
            "node-b": {
              "ID": "node-b",
              "HostName": "fake-peer-b",
              "DNSName": "fake-peer-b.tailnet-fake.ts.net.",
              "TailscaleIPs": ["100.64.0.10"],
              "Online": false
            }
          }
        }
        """

    private static let liveWithNoPeers = """
        {
          "BackendState": "Running",
          "Self": {
            "ID": "self-node-1",
            "HostName": "fake-laptop",
            "DNSName": "fake-laptop.tailnet-fake.ts.net.",
            "TailscaleIPs": ["100.101.102.103"]
          },
          "Peer": {}
        }
        """

    static func run(_ suite: TestSuite) {
        defer { CLI.reset() }

        // MARK: CLI discovery

        suite.expect(TailnetSupport.locateCLI { _ in false } == nil,
                     "no tailscale binary anywhere is a missing installation, not an empty tailnet")
        suite.expect(TailnetSupport.locateCLI { $0 == "/opt/homebrew/bin/tailscale" } == "/opt/homebrew/bin/tailscale",
                     "the first existing candidate is the CLI")
        let cli = TailnetSupport.locateCLI { $0.hasSuffix("/Tailscale.app/Contents/MacOS/Tailscale") }
        suite.expect(cli == "/Applications/Tailscale.app/Contents/MacOS/Tailscale",
                     "the app bundle's own CLI is found when the app is installed")

        // MARK: Unavailable states

        CLI.reset()
        var availability = TailnetSupport.availability(cliPath: nil, run: CLI.run)
        suite.expect(availability == .unavailable(.notInstalled),
                     "an absent binary reports notInstalled")
        suite.expect(CLI.calls.isEmpty, "an absent binary launches nothing")

        availability = TailnetSupport.availability(cliPath: cli, run: CLI.run)
        suite.expect(CLI.calls.count == 1 && CLI.calls[0].arguments == ["status", "--json"],
                     "a present binary is asked for JSON status once")
        suite.expect(CLI.calls[0].timeout == TailnetSupport.statusTimeout && CLI.calls[0].timeout > 0,
                     "the status command always carries a positive bound")

        CLI.reset(); CLI.status = -1
        availability = TailnetSupport.availability(cliPath: cli, run: CLI.run)
        suite.expect(availability == .unavailable(.statusTimeout),
                     "a killed command is a named timeout, not stopped and not empty")

        CLI.reset(); CLI.status = 1; CLI.output = "failed to connect to local tailscaled"
        availability = TailnetSupport.availability(cliPath: cli, run: CLI.run)
        suite.expect(availability == .unavailable(.stopped),
                     "a non-zero exit means the daemon is not running")

        for state in ["Stopped", "Starting", "NoState"] {
            CLI.reset(); CLI.output = #"{"BackendState":"\#(state)"}"#
            availability = TailnetSupport.availability(cliPath: cli, run: CLI.run)
            suite.expect(availability == .unavailable(.stopped),
                         "the \(state) backend is stopped, never a live tailnet")
            suite.expect(availability.peers.isEmpty,
                         "a \(state) backend exposes no peers to trust")
        }
        for state in ["NeedsLogin", "NeedsMachineAuth"] {
            CLI.reset(); CLI.output = #"{"BackendState":"\#(state)","Peer":{"node-a":{"ID":"node-a"}}}"#
            availability = TailnetSupport.availability(cliPath: cli, run: CLI.run)
            suite.expect(availability == .unavailable(.unauthenticated),
                         "the \(state) backend is unauthenticated even with peers listed")
            suite.expect(!availability.isLive, "an unauthenticated node is never live")
        }

        // MARK: Malformed payloads

        for payload in ["", "   ", "{", #"{"BackendState":"Running""#, "not json",
                        #"{"Peer":{}}"#, #"{"BackendState":"Flying"}"#,
                        #"{"BackendState":7}"#, #"{"BackendState":"Running","Peer":[]}"#,
                        #"{"BackendState":"Running","Peer":{"node-a":"not-a-record"}}"#,
                        #"{"BackendState":"Running","Peer":{"node-a":{"ID":"node-a","TailscaleIPs":"100.64.0.9"}}}"# ] {
            CLI.reset(); CLI.output = payload
            availability = TailnetSupport.availability(cliPath: cli, run: CLI.run)
            suite.expect(availability == .unavailable(.malformedStatus),
                         "malformed payload is named, never treated as a live empty tailnet: \(payload)")
        }
        suite.expect(TailnetSupport.parseStatus("[]") == .unavailable(.malformedStatus),
                     "a JSON array is not a status object")
        if case let .live(keyOnly) = TailnetSupport.parseStatus(
            #"{"BackendState":"Running","Peer":{"node-a":{"ID":"","HostName":"","DNSName":"","TailscaleIPs":["100.64.0.9"]}}}"#) {
            suite.expect(keyOnly.peers.first?.id == "node-a",
                         "a peer record with an empty ID still carries its map key as the node identity")
            suite.expect(TailnetSupport.verifyPeer(address: "100.64.0.9", availability: .live(keyOnly),
                                                   expectedIdentities: ["node-a"]).isVerified,
                         "the map-key identity is the one checked for a record without an ID field")
        } else {
            suite.expect(false, "a peer addressed by its map key is live")
        }

        // MARK: Live tailnet

        CLI.reset(); CLI.output = liveWithNoPeers
        availability = TailnetSupport.availability(cliPath: cli, run: CLI.run)
        suite.expect(availability.isLive, "a running backend with zero peers is live")
        suite.expect(availability.peers.isEmpty,
                     "a running backend with zero peers reports an empty, not invented, peer list")
        if case let .live(status) = availability {
            suite.expect(status.backendState == .running, "the live status keeps its backend state")
            suite.expect(status.selfNode?.addresses == ["100.101.102.103"],
                         "the local node addresses are read from the payload")
        } else {
            suite.expect(false, "the zero-peer fixture should be live")
        }

        CLI.reset(); CLI.output = liveWithPeers
        availability = TailnetSupport.availability(cliPath: cli, run: CLI.run)
        suite.expect(availability.isLive && availability.peers.count == 2,
                     "a running backend with peers lists exactly those peers")
        if case let .live(status) = availability {
            let byID = Dictionary(uniqueKeysWithValues: status.peers.map { ($0.id, $0) })
            suite.expect(byID["node-a"]?.online == true && byID["node-b"]?.online == false,
                         "per-peer online flags are preserved")
            suite.expect(byID["node-a"]?.addresses == ["100.64.0.9"],
                         "per-peer tailnet addresses are preserved")
            suite.expect(byID["node-a"]?.identifiers.contains("fake-peer-a.tailnet-fake.ts.net") == true,
                         "a DNS name is reduced to a comparable identifier")
            suite.expect(status.selfNode?.addresses == selfAddresses,
                         "both local tailnet address families are read")
        } else {
            suite.expect(false, "the peer fixture should be live")
        }

        // MARK: Bind scope

        let live = availability
        for wildcard in ["0.0.0.0", "::", "*", " 0.0.0.0 ", ""] {
            suite.expect(TailnetSupport.resolveBind(wildcard, availability: live)
                             == .refused(.wildcardAddress),
                         "a wildcard bind request is refused: \(wildcard.debugDescription)")
        }
        suite.expect(TailnetSupport.resolveBind("loopback", availability: live) == .host(.loopback),
                     "an explicit loopback request stays on loopback")
        suite.expect(TailnetSupport.resolveBind("127.0.0.1", availability: live).host?.address == "127.0.0.1",
                     "127.0.0.1 resolves to loopback")
        suite.expect(TailnetSupport.resolveBind("loopback", availability: .unavailable(.notInstalled))
                         == .host(.loopback),
                     "loopback binding does not require Tailscale")
        suite.expect(TailnetSupport.resolveBind("tailnet", availability: live)
                         == .host(.tailnet("100.101.102.103")),
                     "a tailnet request resolves to a local tailnet address, not a wildcard")
        suite.expect(TailnetSupport.resolveBind("fd7a:115c:a1e0::1", availability: live)
                         == .host(.tailnet("fd7a:115c:a1e0::1")),
                     "an explicit local IPv6 tailnet address is accepted")
        suite.expect(TailnetSupport.resolveBind("100.64.0.9", availability: live)
                         == .refused(.notLocalTailnetAddress),
                     "a tailnet address held by another node is not a local bind")
        suite.expect(TailnetSupport.resolveBind("192.168.1.5", availability: live) == .refused(.outsideScope),
                     "a LAN address is outside the two allowed scopes")
        suite.expect(TailnetSupport.resolveBind("10.0.0.1", availability: live) == .refused(.outsideScope),
                     "a private LAN address is outside the two allowed scopes")
        for state in [TailnetAvailability.unavailable(.notInstalled),
                      .unavailable(.stopped),
                      .unavailable(.unauthenticated),
                      .unavailable(.statusTimeout),
                      .unavailable(.malformedStatus)] {
            suite.expect(TailnetSupport.resolveBind("tailnet", availability: state)
                             == .refused(.tailnetUnavailable),
                         "a tailnet bind without a live tailnet is refused by name, not widened")
        }
        let resolved = ["loopback", "127.0.0.1", "tailnet", "100.101.102.103", "0.0.0.0", "*", "::"]
            .map { TailnetSupport.resolveBind($0, availability: live) }
        suite.expect(resolved.allSatisfy { $0.host?.address != "0.0.0.0" && $0.host?.address != "::" },
                     "no accepted resolution is ever a wildcard address")
        suite.expect(TailnetSupport.isTailnetAddress("100.64.0.1")
                     && TailnetSupport.isTailnetAddress("100.127.255.255")
                     && !TailnetSupport.isTailnetAddress("100.128.0.1")
                     && !TailnetSupport.isTailnetAddress("100.63.255.255"),
                     "the IPv4 tailnet range is 100.64.0.0/10 and nothing wider")

        // MARK: Peer identity

        let expected: Set<String> = ["fake-peer-a.tailnet-fake.ts.net"]
        suite.expect(TailnetSupport.verifyPeer(address: "100.64.0.9", availability: live,
                                               expectedIdentities: expected).isVerified,
                     "an online peer with an expected DNS identity is verified")
        suite.expect(TailnetSupport.verifyPeer(address: "100.64.0.9", availability: live,
                                               expectedIdentities: [" Fake-Peer-A.tailnet-fake.ts.net. "]).isVerified,
                     "identity comparison is case- and trailing-dot-insensitive")
        suite.expect(TailnetSupport.verifyPeer(address: "100.64.0.9", availability: live,
                                               expectedIdentities: ["fake-peer-a"]).isVerified,
                     "a host name is an accepted identity")
        suite.expect(TailnetSupport.verifyPeer(address: "100.64.0.9", availability: live,
                                               expectedIdentities: ["node-a"]).isVerified,
                     "a node ID is an accepted identity")
        suite.expect(TailnetSupport.verifyPeer(address: "100.64.0.9", availability: live,
                                               expectedIdentities: []) == .unverified(.unexpectedIdentity),
                     "an empty expected set trusts nothing")
        suite.expect(TailnetSupport.verifyPeer(address: "100.64.0.9", availability: live,
                                               expectedIdentities: ["fake-peer-b"])
                         == .unverified(.unexpectedIdentity),
                     "a peer whose identity is not expected is unverified")
        suite.expect(TailnetSupport.verifyPeer(address: "100.64.0.10", availability: live,
                                               expectedIdentities: ["fake-peer-b"])
                         == .unverified(.offline),
                     "an expected peer that is offline is not verified as live")
        suite.expect(TailnetSupport.verifyPeer(address: "100.64.0.99", availability: live,
                                               expectedIdentities: expected) == .unverified(.unknownPeer),
                     "an address absent from the peer table is an unknown peer")
        suite.expect(TailnetSupport.verifyPeer(address: "", availability: live,
                                               expectedIdentities: expected) == .unverified(.unknownPeer),
                     "an empty address never matches a peer")
        for state in [TailnetAvailability.unavailable(.notInstalled),
                      .unavailable(.stopped),
                      .unavailable(.unauthenticated),
                      .unavailable(.malformedStatus)] {
            suite.expect(TailnetSupport.verifyPeer(address: "100.64.0.9", availability: state,
                                                   expectedIdentities: expected)
                             == .unverified(.unavailable),
                         "no live tailnet means no verified peer")
        }
        suite.expect(TailnetSupport.verifyPeer(address: "100.64.0.9", availability: .live(
            TailnetStatus(backendState: .running, selfNode: nil, peers: [])),
                        expectedIdentities: expected) == .unverified(.unknownPeer),
                     "a live tailnet with zero peers verifies no one")
    }
}

private extension TailnetBindResolution {
    var host: TailnetBindHost? {
        if case let .host(host) = self { return host }
        return nil
    }
}

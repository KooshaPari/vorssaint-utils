// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Runs the production mesh service against scripted Tailscale JSON, ssh
/// config text and device lists. No Tailscale daemon is queried, no ssh config
/// is read from disk and no USB hardware is touched.
enum ComputeMeshTests {
    static let sshPath = "/Users/tester/.ssh/config"
    static let tailscalePath = "/opt/homebrew/bin/tailscale"

    final class Runtime {
        var executables: [String] = []
        var commands: [(path: String, arguments: [String], timeout: TimeInterval)] = []
        var responses: [String: (status: Int32, output: Data)] = [:]
        /// A key in `unreadableFiles` exists but cannot be read.
        var files: [String: String] = [:]
        var unreadableFiles: Set<String> = []
        var devices: [MeshDevice]? = []

        func environment() -> MeshEnvironment {
            let runtime = self
            return MeshEnvironment(
                tailscaleExecutables: executables,
                run: { path, arguments, timeout in
                    runtime.commands.append((path, arguments, timeout))
                    return runtime.responses[path] ?? (0, Data())
                },
                fileExists: {
                    runtime.files[$0] != nil || runtime.unreadableFiles.contains($0)
                        || runtime.executables.contains($0)
                },
                readText: { path in
                    runtime.unreadableFiles.contains(path) ? nil : runtime.files[path]
                },
                sshConfigPath: sshPath,
                sampleDevices: { runtime.devices }
            )
        }

        func respond(status: Int32, _ json: String) {
            responses[tailscalePath] = (status, Data(json.utf8))
        }
    }

    static func status(_ peers: [(id: String, hostName: String, dnsName: String?,
                                 ip: String, online: Bool)]) -> String {
        let entries = peers.map { peer -> String in
            var fields: [String] = []
            fields.append("\"ID\": \"\(peer.id)\"")
            fields.append("\"HostName\": \"\(peer.hostName)\"")
            if let dnsName = peer.dnsName { fields.append("\"DNSName\": \"\(dnsName)\"") }
            fields.append("\"TailscaleIPs\": [\"\(peer.ip)\"]")
            fields.append("\"Online\": \(peer.online)")
            return "\"node-\(peer.id)\": { \(fields.joined(separator: ", ")) }"
        }
        let peerMap = entries.isEmpty ? "{}" : "{ \(entries.joined(separator: ", ")) }"
        return "{ \"BackendState\": \"Running\", \"Peer\": \(peerMap) }"
    }

    /// One complete, honest setup: a Tailscale peer that is also in the ssh
    /// config, one ssh-only host, and one local device.
    static func fullRuntime() -> Runtime {
        let runtime = Runtime()
        runtime.executables = [tailscalePath]
        runtime.respond(status: 0, status([
            ("nABC123", "nas", "nas.tail4d2e.ts.net.", "100.64.0.7", true),
        ]))
        runtime.files[sshPath] = """
            Host nas
                HostName nas.tail4d2e.ts.net
                User koosh
            Host buildbox
                HostName buildbox.example.com
                Port 2222
            """
        runtime.devices = [MeshDevice(id: "usb-1", name: "Keyboard")]
        return runtime
    }

    static func run(_ suite: TestSuite) {
        suite.run("mesh-sources") {
            let unavailable = Runtime()
            let model = ComputeMeshService(environment: unavailable.environment()).reload()
            suite.expect(model.rows.isEmpty && !model.isLive,
                         "three absent backends produce no rows and are not a fleet")
            suite.expect(model.state(of: .tailscale) == .unavailable(.tailscaleNotInstalled),
                         "a missing Tailscale binary is a named unavailable state")
            suite.expect(model.state(of: .sshConfig) == .unavailable(.sshConfigMissing),
                         "a missing ssh config is a named unavailable state")
            suite.expect(model.state(of: .connectedDevice) == .unavailable(.deviceBackendUnavailable),
                         "a missing device backend is a named unavailable state")

            let runtime = Runtime()
            runtime.executables = [tailscalePath]
            runtime.respond(status: 1, "")
            runtime.unreadableFiles.insert(sshPath)
            runtime.devices = nil
            let failed = ComputeMeshService(environment: runtime.environment()).reload()
            suite.expect(failed.state(of: .tailscale) == .unavailable(.commandFailed(1)),
                         "a failing Tailscale command keeps only its status")
            suite.expect(failed.state(of: .sshConfig) == .unavailable(.unreadable),
                         "a config that exists but cannot be read is named as unreadable")

            runtime.respond(status: -1, "")
            suite.expect(ComputeMeshService(environment: runtime.environment()).reload()
                            .state(of: .tailscale) == .unavailable(.timeout),
                         "a Tailscale query that outlives its bound reports a timeout")
            let invocation = runtime.commands.first
            suite.expect(invocation?.arguments == ["status", "--json"]
                         && (invocation?.timeout ?? 0) > 0
                         && (invocation?.timeout ?? 99) <= 10,
                         "the Tailscale query is bounded, not open-ended")

            runtime.respond(status: 0, "this is not json")
            suite.expect(ComputeMeshService(environment: runtime.environment()).reload()
                            .state(of: .tailscale) == .unavailable(.malformedOutput),
                         "malformed Tailscale output is unavailable, not an empty peer list")
            runtime.respond(status: 0, "{ \"Peer\": { \"a\": 1 } }")
            suite.expect(ComputeMeshService(environment: runtime.environment()).reload()
                            .state(of: .tailscale) == .unavailable(.malformedOutput),
                         "a peer entry that is not an object fails the whole source")

            runtime.respond(status: 0, "{ \"BackendState\": \"Running\", \"Peer\": {} }")
            let solo = ComputeMeshService(environment: runtime.environment()).reload()
            suite.expect(solo.state(of: .tailscale) == .available(applied: 0) && solo.isLive,
                         "a running tailnet with no peers is available and genuinely empty")
        }

        suite.run("mesh-ssh") {
            let runtime = Runtime()
            runtime.files[sshPath] = """
                Host nas
                    HostName nas.local
                Host nas
                    HostName other.local
                Host *
                    ServerAliveInterval 30
                Host a b
                    HostName shared.example.com
                Match host shared.example.com
                    User ignored
                Host broken
                    Port 99999
                """
            let result = ComputeMeshSupport.parseSSHConfig(runtime.files[sshPath] ?? "")
            suite.expect(result == .failure(.malformedOutput),
                         "an out-of-range port makes the ssh config unreadable")

            runtime.files[sshPath] = """
                Host nas
                    HostName nas.local
                Host nas
                    HostName other.local

                Host a b
                    HostName shared.example.com
                    Port 2222
                Host *
                    ServerAliveInterval 30
                Match host shared.example.com
                    User ignored
                """
            let parsed = ComputeMeshSupport.parseSSHConfig(runtime.files[sshPath] ?? "")
            guard case .success(let hosts) = parsed else {
                suite.expect(false, "a valid ssh config must parse")
                return
            }
            suite.expect(hosts.count == 2
                         && hosts[0].hostName == "nas.local"
                         && hosts[0].aliases == ["nas"],
                         "a duplicate alias keeps the first block, as OpenSSH does")
            suite.expect(hosts[1].aliases == ["a", "b"] && hosts[1].port == 2222,
                         "two aliases for one HostName are one host with both names")
            suite.expect(!hosts.contains { $0.aliases.contains("*") },
                         "a wildcard Host block never becomes a host")

            let quoted = ComputeMeshSupport.parseSSHConfig("Host \"odd name\"\n  HostName scoped.example.com\n")
            guard case .success(let quotedHosts) = quoted else {
                suite.expect(false, "a quoted alias must parse")
                return
            }
            suite.expect(quotedHosts.first?.aliases == ["odd name"],
                         "a quoted alias keeps its space as one token")

            suite.expect(ComputeMeshSupport.parseSSHConfig("Host free \"unterminated\n") == .failure(.malformedOutput),
                         "an unterminated quote makes the ssh config unreadable")
            suite.expect(ComputeMeshSupport.parseSSHConfig("Host\n") == .failure(.malformedOutput),
                         "a Host line with no alias is malformed")
        }

        suite.run("mesh-merge") {
            let runtime = fullRuntime()
            let model = ComputeMeshService(environment: runtime.environment()).reload()
            suite.expect(model.rows.count == 3,
                         "one peer appears in two sources without becoming two rows")
            let nas = model.rows.first { $0.identity == "ts:nABC123" }
            suite.expect(nas?.sources == [.tailscale, .sshConfig]
                         && nas?.sourceList == [.tailscale, .sshConfig],
                         "a merged row carries both of the sources that produced it")
            suite.expect(nas?.verification == .online,
                         "a live Tailscale peer merged with an ssh host stays online")
            suite.expect(nas?.aliases.contains("nas") == true,
                         "the merged row keeps the ssh alias that reached it")

            let buildbox = model.rows.first { $0.identity == "host:buildbox.example.com" }
            suite.expect(buildbox?.sources == [.sshConfig]
                         && buildbox?.verification == .unverified,
                         "an ssh host with no liveness signal is unverified, never reachable")

            let device = model.rows.first { $0.sources == [.connectedDevice] }
            suite.expect(device?.verification == .localDevice
                         && device?.identity == "usb:usb-1",
                         "a local device is its own row with local presence, not reachability")

            let offlineRuntime = Runtime()
            offlineRuntime.executables = [tailscalePath]
            offlineRuntime.respond(status: 0, status([
                ("nOFF", "archive", "archive.tail4d2e.ts.net.", "100.64.0.9", false),
            ]))
            offlineRuntime.devices = nil
            let offline = ComputeMeshService(environment: offlineRuntime.environment()).reload()
            suite.expect(offline.rows.first?.verification == .offline,
                         "a peer Tailscale reports offline is shown offline")

            let lookalikeRuntime = Runtime()
            lookalikeRuntime.executables = [tailscalePath]
            lookalikeRuntime.respond(status: 0, status([
                ("nLOOK", "nas", "nas.other.ts.net.", "100.64.0.20", true),
            ]))
            lookalikeRuntime.files[sshPath] = """
                Host nas
                    HostName nas.example.com
                """
            lookalikeRuntime.devices = nil
            let lookalike = ComputeMeshService(environment: lookalikeRuntime.environment()).reload()
            suite.expect(lookalike.rows.count == 2,
                         "two machines whose names look alike stay two rows")

            let deviceCollision = Runtime()
            deviceCollision.executables = [tailscalePath]
            deviceCollision.respond(status: 0, status([
                ("nNAS", "nas", "nas.tail4d2e.ts.net.", "100.64.0.7", true),
            ]))
            deviceCollision.devices = [MeshDevice(id: "usb-9", name: "nas")]
            let collision = ComputeMeshService(environment: deviceCollision.environment()).reload()
            suite.expect(collision.rows.count == 2,
                         "a local device named like a peer never merges into it")

            let conflicting = ComputeMeshSupport.merge(tailscale: [
                TailscalePeer(id: "nDUP", hostName: "dup", dnsName: "dup.ts.net",
                              addresses: ["100.64.0.30"], online: true),
                TailscalePeer(id: "nDUP", hostName: "dup", dnsName: "dup.ts.net",
                              addresses: ["100.64.0.30"], online: false),
            ], ssh: [], devices: [])
            suite.expect(conflicting.count == 1 && conflicting[0].verification == .unverified,
                         "contradictory liveness claims degrade to unverified, not to online")

            let aliases = ComputeMeshSupport.merge(tailscale: [], ssh: [
                SSHHost(aliases: ["a"], hostName: "shared.example.com", user: nil, port: nil),
                SSHHost(aliases: ["b"], hostName: "SHARED.example.com", user: nil, port: nil),
            ], devices: [])
            suite.expect(aliases.count == 1 && aliases[0].aliases == ["a", "b"],
                         "two aliases for the same HostName are one machine")
        }
    }
}

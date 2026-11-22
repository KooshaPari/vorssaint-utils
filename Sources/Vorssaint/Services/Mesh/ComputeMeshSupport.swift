// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Where a row came from. A row can carry several of these at once; the UI can
/// always say which source produced a peer and never has to guess.
enum MeshSource: String, CaseIterable, Hashable {
    case tailscale
    case sshConfig
    case connectedDevice
}

/// How much is actually known about a row. Only a live Tailscale peer is
/// `online`; a host that merely exists in an ssh config is `unverified` and
/// must never be drawn as reachable.
enum MeshVerification: String, Equatable {
    case online
    case offline
    case unverified
    case localDevice
}

/// One row of the mesh view, merged by host identity. `aliases` keeps every
/// name that produced the row, so a merged peer still shows both of its names.
struct MeshPeer: Identifiable, Equatable {
    let identity: String
    var displayName: String
    var aliases: [String]
    var addresses: [String]
    var sources: Set<MeshSource>
    var verification: MeshVerification

    var id: String { identity }

    /// Sources in a stable order for rendering and checks.
    var sourceList: [MeshSource] {
        MeshSource.allCases.filter { sources.contains($0) }
    }
}

/// A local peripheral the connected-devices feature knows about. It is a row of
/// its own and is never merged with a network host that happens to share a name.
struct MeshDevice: Equatable {
    let id: String
    let name: String
}

struct TailscalePeer: Equatable {
    let id: String
    let hostName: String
    let dnsName: String?
    let addresses: [String]
    let online: Bool
}

struct SSHHost: Equatable {
    let aliases: [String]
    let hostName: String
    let user: String?
    let port: Int?
}

/// Why a source could not be read. A source that fails contributes no rows at
/// all, so a partial parse is never published as a complete fleet.
enum MeshSourceUnavailable: Error, Equatable {
    case tailscaleNotInstalled
    case sshConfigMissing
    case deviceBackendUnavailable
    case unreadable
    case timeout
    case commandFailed(Int32)
    case malformedOutput
}

enum MeshSourceState: Equatable {
    case available(applied: Int)
    case unavailable(MeshSourceUnavailable)
}

/// The merged view plus one state per source. `isLive` is false when nothing
/// could be read; an empty row list under a dead backend is not an empty fleet.
struct MeshModel: Equatable {
    var rows: [MeshPeer]
    var states: [MeshSource: MeshSourceState]

    var isLive: Bool {
        states.values.contains {
            if case .available = $0 { return true }
            return false
        }
    }

    var availableSources: [MeshSource] {
        MeshSource.allCases.filter {
            if case .available = states[$0] { return true }
            return false
        }
    }

    func state(of source: MeshSource) -> MeshSourceState {
        states[source] ?? .unavailable(.unreadable)
    }
}

/// Parsers and the merge rule. Pure string/work transforms so every source can
/// be driven with fixtures, including deliberately broken output.
enum ComputeMeshSupport {
    /// Lowercased, trimmed and without the trailing dot Tailscale appends to
    /// its DNS names. Used for comparing, never for display.
    static func normalisedHost(_ value: String) -> String {
        var host = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while host.hasSuffix(".") { host.removeLast() }
        return host
    }

    // MARK: Tailscale

    /// Parses `tailscale status --json`. The document is read as JSON rather
    /// than line by line: a field added or reordered upstream must not make the
    /// peer list unreadable.
    static func parseTailscaleStatus(_ data: Data) -> Result<[TailscalePeer], MeshSourceUnavailable> {
        guard !data.isEmpty,
              let root = try? JSONSerialization.jsonObject(with: data),
              let object = root as? [String: Any] else {
            return .failure(.malformedOutput)
        }
        var peers: [[String: Any]] = []
        if let rawPeers = object["Peer"] {
            guard let map = rawPeers as? [String: Any] else { return .failure(.malformedOutput) }
            for value in map.values {
                guard let entry = value as? [String: Any] else { return .failure(.malformedOutput) }
                peers.append(entry)
            }
        } else if object["BackendState"] == nil && object["Version"] == nil {
            // Neither a peer map nor the rest of a status document: refuse it.
            return .failure(.malformedOutput)
        }
        var parsed: [TailscalePeer] = []
        for entry in peers {
            let identifier = (entry["ID"] as? String) ?? ""
            let hostName = (entry["HostName"] as? String) ?? ""
            let dnsName = nonEmpty(entry["DNSName"] as? String)
                .map(normalisedHost)
            let addresses = (entry["TailscaleIPs"] as? [String])?
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty } ?? []
            guard !identifier.isEmpty || dnsName != nil || !hostName.isEmpty else {
                return .failure(.malformedOutput)
            }
            let online: Bool
            if let value = entry["Online"] as? Bool {
                online = value
            } else if let number = entry["Online"] as? NSNumber {
                online = number.boolValue
            } else {
                return .failure(.malformedOutput)
            }
            parsed.append(TailscalePeer(id: identifier,
                                        hostName: hostName,
                                        dnsName: dnsName,
                                        addresses: addresses,
                                        online: online))
        }
        return .success(parsed.sorted { $0.hostName.localizedCaseInsensitiveCompare($1.hostName) == .orderedAscending })
    }

    // MARK: SSH config

    /// Parses `~/.ssh/config`. First match wins the way OpenSSH does: an alias
    /// declared twice keeps its first block, and a wildcard or negated pattern
    /// never becomes a host. `Include` is deliberately ignored rather than
    /// followed, so one file is always one bounded read.
    static func parseSSHConfig(_ text: String) -> Result<[SSHHost], MeshSourceUnavailable> {
        var blocks: [SSHHost] = []
        var aliases: [String] = []
        var hostName: String?
        var user: String?
        var port: Int?
        var inBlock = false
        var seenAliases = Set<String>()

        func flush() {
            guard inBlock, !aliases.isEmpty else { return }
            blocks.append(SSHHost(aliases: aliases,
                                  hostName: hostName ?? aliases[0],
                                  user: user,
                                  port: port))
        }

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            guard let stripped = stripComment(String(rawLine)) else {
                return .failure(.malformedOutput)
            }
            let line = stripped.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            guard let tokens = tokenize(line), let keyword = tokens.first else {
                return .failure(.malformedOutput)
            }
            switch keyword.lowercased() {
            case "host":
                flush()
                let patterns = Array(tokens.dropFirst())
                guard !patterns.isEmpty else { return .failure(.malformedOutput) }
                aliases = []
                hostName = nil
                user = nil
                port = nil
                inBlock = false
                if patterns.contains(where: { $0.contains("*") || $0.contains("?") || $0.contains("!") }) {
                    continue
                }
                for pattern in patterns where seenAliases.insert(pattern.lowercased()).inserted {
                    aliases.append(pattern)
                }
                inBlock = !aliases.isEmpty
            case "match":
                flush()
                aliases = []
                hostName = nil
                user = nil
                port = nil
                inBlock = false
            default:
                guard inBlock, tokens.count >= 2 else { continue }
                let value = tokens.dropFirst().joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                guard !value.isEmpty else { continue }
                switch keyword.lowercased() {
                case "hostname": hostName = value
                case "user": user = value
                case "port":
                    guard let parsed = Int(value), (1...65535).contains(parsed) else {
                        return .failure(.malformedOutput)
                    }
                    port = parsed
                default: continue
                }
            }
        }
        flush()
        return .success(blocks)
    }

    /// Removes a `#` comment that is not inside a quoted value.
    static func stripComment(_ line: String) -> String? {
        var inSingle = false
        var inDouble = false
        var result = ""
        for character in line {
            switch character {
            case "'" where !inDouble: inSingle.toggle(); result.append(character)
            case "\"" where !inSingle: inDouble.toggle(); result.append(character)
            case "#" where !inSingle && !inDouble: return result
            default: result.append(character)
            }
        }
        return (inSingle || inDouble) ? nil : result
    }

    /// Whitespace tokens with single and double quotes honoured. Nil means a
    /// quote was never closed, which makes the file unreadable as a whole.
    static func tokenize(_ line: String) -> [String]? {
        var tokens: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false
        var started = false
        for character in line {
            switch character {
            case "'" where !inDouble:
                inSingle.toggle(); started = true
            case "\"" where !inSingle:
                inDouble.toggle(); started = true
            case " ", "\t":
                if inSingle || inDouble {
                    current.append(character); started = true
                } else if started {
                    tokens.append(current); current = ""; started = false
                }
            default:
                current.append(character); started = true
            }
        }
        if inSingle || inDouble { return nil }
        if started { tokens.append(current) }
        return tokens
    }

    static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    // MARK: Merge

    /// Merges the three sources by host identity. Identity keys are exact:
    /// the Tailscale node id, the exact Tailscale DNS name or address, the ssh
    /// `HostName`. A display name or a bare ssh alias is never an identity, so
    /// two machines with alike names stay two rows. Devices are identified by
    /// their own `usb:` key and never merge with network peers.
    static func merge(tailscale: [TailscalePeer],
                      ssh: [SSHHost],
                      devices: [MeshDevice]) -> [MeshPeer] {
        var builders: [Builder] = []
        var index: [String: Int] = [:]

        func find(_ keys: [String]) -> Int? {
            for key in keys where !key.isEmpty {
                if let position = index[key] { return position }
            }
            return nil
        }

        func register(_ keys: [String], _ position: Int) {
            for key in keys where !key.isEmpty { index[key] = position }
        }

        for peer in tailscale {
            var keys: [String] = []
            if !peer.id.isEmpty { keys.append("ts:" + peer.id) }
            if let dnsName = peer.dnsName {
                keys.append("host:" + dnsName)
            } else if !peer.hostName.isEmpty {
                keys.append("host:" + normalisedHost(peer.hostName))
            }
            keys.append(contentsOf: peer.addresses.map { "ip:" + normalisedHost($0) })
            let display = nonEmpty(peer.hostName) ?? peer.dnsName ?? peer.addresses.first ?? ""
            if let position = find(keys) {
                builders[position].mergeTailscale(peer, displayName: display)
            } else {
                var builder = Builder(identity: keys.first ?? ("ts:" + peer.id))
                builder.mergeTailscale(peer, displayName: display)
                register(keys, builders.count)
                builders.append(builder)
            }
        }

        for host in ssh {
            let hostName = normalisedHost(host.hostName)
            guard !hostName.isEmpty else { continue }
            let keys = ["host:" + hostName]
            if let position = find(keys) {
                builders[position].mergeSSH(host)
            } else {
                var builder = Builder(identity: "host:" + hostName)
                builder.mergeSSH(host)
                register(keys, builders.count)
                builders.append(builder)
            }
        }

        for device in devices {
            let identity = "usb:" + device.id
            if let position = find([identity]) {
                builders[position].mergeDevice(device)
            } else {
                var builder = Builder(identity: identity)
                builder.mergeDevice(device)
                register([identity], builders.count)
                builders.append(builder)
            }
        }

        return builders.map { $0.peer }
            .sorted { left, right in
                let rank = { (peer: MeshPeer) -> Int in
                    switch peer.verification {
                    case .online: return 0
                    case .localDevice: return 1
                    case .unverified: return 2
                    case .offline: return 3
                    }
                }
                if rank(left) != rank(right) { return rank(left) < rank(right) }
                return left.displayName.localizedCaseInsensitiveCompare(right.displayName)
                    == .orderedAscending
            }
    }

    private struct Builder {
        let identity: String
        var displayName = ""
        var aliases: [String] = []
        var addresses: [String] = []
        var sources: Set<MeshSource> = []
        /// Every liveness claim heard for this row. Contradiction is not
        /// resolved in favour of "online"; it degrades to unverified.
        var onlineVotes: Set<Bool> = []
        var isDevice = false

        init(identity: String) {
            self.identity = identity
        }

        /// Returns the list with one unique, non-empty value added. A mutating
        /// method taking the property as `inout` would overlap the access to
        /// self, which Swift rejects at compile time.
        static func appending(_ value: String, to list: [String]) -> [String] {
            guard !value.isEmpty, !list.contains(value) else { return list }
            return list + [value]
        }

        mutating func mergeTailscale(_ peer: TailscalePeer, displayName: String) {
            sources.insert(.tailscale)
            onlineVotes.insert(peer.online)
            if self.displayName.isEmpty { self.displayName = displayName }
            aliases = Self.appending(peer.hostName, to: aliases)
            if let dnsName = peer.dnsName {
                addresses = Self.appending(dnsName, to: addresses)
            }
            for address in peer.addresses {
                addresses = Self.appending(address, to: addresses)
            }
        }

        mutating func mergeSSH(_ host: SSHHost) {
            sources.insert(.sshConfig)
            if displayName.isEmpty { displayName = host.aliases.first ?? host.hostName }
            for alias in host.aliases {
                aliases = Self.appending(alias, to: aliases)
            }
            addresses = Self.appending(host.hostName, to: addresses)
        }

        mutating func mergeDevice(_ device: MeshDevice) {
            sources.insert(.connectedDevice)
            isDevice = true
            if displayName.isEmpty { displayName = device.name }
            aliases = Self.appending(device.name, to: aliases)
        }

        var peer: MeshPeer {
            let verification: MeshVerification
            if isDevice {
                verification = .localDevice
            } else if onlineVotes == [true] {
                verification = .online
            } else if onlineVotes == [false] {
                verification = .offline
            } else {
                verification = .unverified
            }
            return MeshPeer(identity: identity,
                            displayName: displayName.isEmpty ? identity : displayName,
                            aliases: aliases,
                            addresses: addresses,
                            sources: sources,
                            verification: verification)
        }
    }
}

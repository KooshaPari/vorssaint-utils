// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Everything the mesh view touches outside itself. The live wiring is beside
/// the app; the checks supply plain closures, including failing ones.
struct MeshEnvironment {
    /// Candidate Tailscale binaries in preference order. The first existing one
    /// is used, so both the app bundle and a Homebrew install are honoured.
    var tailscaleExecutables: [String]
    var run: (_ path: String, _ arguments: [String], _ timeout: TimeInterval)
        -> (status: Int32, output: Data)
    var fileExists: (String) -> Bool
    var readText: (String) -> String?
    var sshConfigPath: String
    /// Nil means the connected-devices backend itself is unavailable, which is
    /// a named source state rather than an empty device list.
    var sampleDevices: () -> [MeshDevice]?

    static let tailscaleTimeout: TimeInterval = 8
}

/// Reads the three sources independently, merges them by host identity and
/// reports one state per source. A source that cannot be read contributes no
/// rows, and a model with no readable source is not presented as an empty fleet.
struct ComputeMeshService {
    let environment: MeshEnvironment

    func reload() -> MeshModel {
        var states: [MeshSource: MeshSourceState] = [:]

        let (tailscaleState, tailscalePeers) = readTailscale()
        states[.tailscale] = tailscaleState

        let (sshState, sshHosts) = readSSHHosts()
        states[.sshConfig] = sshState

        let (deviceState, devices) = readDevices()
        states[.connectedDevice] = deviceState

        let rows = ComputeMeshSupport.merge(tailscale: tailscalePeers,
                                            ssh: sshHosts,
                                            devices: devices)
        return MeshModel(rows: rows, states: states)
    }

    private func readTailscale() -> (MeshSourceState, [TailscalePeer]) {
        guard let executable = environment.tailscaleExecutables.first(where: environment.fileExists) else {
            return (.unavailable(.tailscaleNotInstalled), [])
        }
        let result = environment.run(executable, ["status", "--json"],
                                     MeshEnvironment.tailscaleTimeout)
        // A negative status is the bounded runner's timeout, never a document.
        if result.status < 0 { return (.unavailable(.timeout), []) }
        guard result.status == 0 else { return (.unavailable(.commandFailed(result.status)), []) }
        switch ComputeMeshSupport.parseTailscaleStatus(result.output) {
        case .failure(let reason):
            return (.unavailable(reason), [])
        case .success(let peers):
            return (.available(applied: peers.count), peers)
        }
    }

    private func readSSHHosts() -> (MeshSourceState, [SSHHost]) {
        guard environment.fileExists(environment.sshConfigPath) else {
            return (.unavailable(.sshConfigMissing), [])
        }
        guard let text = environment.readText(environment.sshConfigPath) else {
            return (.unavailable(.unreadable), [])
        }
        switch ComputeMeshSupport.parseSSHConfig(text) {
        case .failure(let reason):
            return (.unavailable(reason), [])
        case .success(let hosts):
            return (.available(applied: hosts.count), hosts)
        }
    }

    private func readDevices() -> (MeshSourceState, [MeshDevice]) {
        guard let devices = environment.sampleDevices() else {
            return (.unavailable(.deviceBackendUnavailable), [])
        }
        return (.available(applied: devices.count), devices)
    }
}

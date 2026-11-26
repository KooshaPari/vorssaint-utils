// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Why the share list cannot be shown at all. Each case is a name the UI can
/// render; none of them ever stands for "no shares", which is `available([])`.
enum SMBUnavailable: Equatable {
    case configurationMalformed
    case mountToolMissing
    case mountTableUnavailable
    case mountTableMalformed
}

/// Whether a password is present for this share. A missing credential is a
/// state of its own, never a silent mount attempt or a generic failure.
enum SMBCredentialState: Equatable {
    case stored
    case missing
}

enum SMBMountState: Equatable {
    case unmounted
    case mounted(String)
}

struct SMBShareRow: Equatable {
    let share: SMBShare
    var credential: SMBCredentialState
    var mountState: SMBMountState
}

/// The list the view renders. `available([])` means the configuration contains
/// no shares; `unavailable` means the truth is unknown.
enum SMBListing: Equatable {
    case available([SMBShareRow])
    case unavailable(SMBUnavailable)

    var rows: [SMBShareRow] {
        if case .available(let rows) = self { return rows }
        return []
    }
}

/// A named operation failure. Tool output is deliberately absent: nothing that
/// a mount command prints can reach a log, the UI or a bug report through here.
enum SMBFailure: Equatable {
    case credentialMissing
    case credentialRejected
    case credentialPublishFailed
    case invalidConfiguration
    case mountPointUnavailable
    case mountPointBusy
    case timeout
    case commandFailed(Int32)
}

enum SMBOutcome: Equatable {
    case mounted(String)
    case unmounted
    case notMounted
    case unknownShare
    case failed(SMBFailure)
    case unavailable(SMBUnavailable)
}

/// Hands a secret to the keychain item `mount_smbfs` looks up, so no password
/// is ever placed in an argument list. Every publish is paired with a withdraw.
protocol SMBKeychainProjection {
    func publish(_ secret: String, for share: SMBShare) -> Bool
    func withdraw(for share: SMBShare)
}

/// Everything the service touches outside itself. The live wiring lives beside
/// the app; the checks supply plain closures.
struct SMBEnvironment {
    var run: (_ path: String, _ arguments: [String], _ timeout: TimeInterval)
        -> (status: Int32, output: String)
    var fileExists: (String) -> Bool
    var readText: (String) -> String?
    var createDirectory: (String) -> Bool
}

/// Lists configured SMB shares, mounts and unmounts them, and reports state
/// from the kernel's mount table rather than from what was requested.
final class SMBSharesService {
    private let configurationURL: URL
    private let secrets: AgentSecretStore
    private let projection: SMBKeychainProjection
    private let environment: SMBEnvironment

    private(set) var listing: SMBListing = .available([])

    init(configurationURL: URL,
         secrets: AgentSecretStore,
         projection: SMBKeychainProjection,
         environment: SMBEnvironment) {
        self.configurationURL = configurationURL
        self.secrets = secrets
        self.projection = projection
        self.environment = environment
    }

    var configurationPath: String { configurationURL.path }

    /// Reads the configuration, the credential states and the kernel's mount
    /// table. With configured shares, a missing mount tool or an unreadable
    /// table returns `unavailable` instead of claiming every share is unmounted.
    @discardableResult
    func reload() -> SMBListing {
        switch loadConfiguration() {
        case .invalid:
            listing = .unavailable(.configurationMalformed)
        case .absent:
            listing = .available([])
        case .shares(let shares):
            guard !shares.isEmpty else {
                listing = .available([])
                return listing
            }
            guard environment.fileExists(SMBShareSupport.mountToolPath) else {
                listing = .unavailable(.mountToolMissing)
                return listing
            }
            let table = environment.run(SMBShareSupport.mountTableToolPath, [],
                                        SMBShareSupport.tableTimeout)
            // A negative status is the runner's own timeout, not a mount table.
            guard table.status >= 0 else {
                listing = .unavailable(.mountTableUnavailable)
                return listing
            }
            let mounts: [SMBMount]
            switch SMBShareSupport.parseMountTable(table.output) {
            case .failure:
                listing = .unavailable(.mountTableMalformed)
                return listing
            case .success(let parsed):
                mounts = parsed
            }
            listing = .available(shares.map { share in
                SMBShareRow(share: share,
                            credential: credentialState(for: share.id),
                            mountState: SMBShareSupport.mountPoint(for: share, in: mounts)
                                .map(SMBMountState.mounted) ?? .unmounted)
            })
        }
        return listing
    }

    func loadConfiguration() -> SMBShareSupport.Configuration {
        guard environment.fileExists(configurationURL.path) else { return .absent }
        guard let text = environment.readText(configurationURL.path) else { return .invalid }
        return SMBShareSupport.decodeConfiguration(text)
    }

    func credentialState(for shareID: UUID) -> SMBCredentialState {
        secrets.secret(for: shareID) == nil ? .missing : .stored
    }

    /// Stores a password through the same keychain-backed store the agent keys
    /// use. Returns whether the keychain accepted it.
    @discardableResult
    func storeCredential(_ secret: String, for shareID: UUID) -> Bool {
        guard !secret.isEmpty else { return false }
        return secrets.set(secret, for: shareID)
    }

    @discardableResult
    func removeCredential(for shareID: UUID) -> Bool {
        secrets.remove(for: shareID)
    }

    /// Mounts a configured share. The credential is read from the keychain,
    /// published only for the duration of the call and withdrawn afterwards,
    /// including on every failure path.
    @discardableResult
    func mount(shareID: UUID) -> SMBOutcome {
        let shares: [SMBShare]
        switch loadConfiguration() {
        case .invalid: return .unavailable(.configurationMalformed)
        case .absent: return .unknownShare
        case .shares(let configured): shares = configured
        }
        guard let share = shares.first(where: { $0.id == shareID }) else { return .unknownShare }
        guard let secret = secrets.secret(for: shareID) else { return .failed(.credentialMissing) }
        guard environment.fileExists(SMBShareSupport.mountToolPath) else {
            return .unavailable(.mountToolMissing)
        }
        guard let source = SMBShareSupport.mountSource(share) else {
            return .failed(.invalidConfiguration)
        }
        guard environment.createDirectory(share.mountPoint) else {
            return .failed(.mountPointUnavailable)
        }
        guard projection.publish(secret, for: share) else {
            return .failed(.credentialPublishFailed)
        }
        defer { projection.withdraw(for: share) }
        let result = environment.run(SMBShareSupport.mountToolPath,
                                     ["-N", source, share.mountPoint],
                                     SMBShareSupport.mountTimeout)
        if result.status < 0 { return .failed(.timeout) }
        if result.status == 0 { return .mounted(share.mountPoint) }
        return .failed(SMBShareSupport.classifyMountFailure(status: result.status,
                                                            output: result.output))
    }

    /// Unmounts only what the kernel says is mounted. A share that is already
    /// unmounted keeps its own named outcome instead of a command failure.
    @discardableResult
    func unmount(shareID: UUID) -> SMBOutcome {
        switch loadConfiguration() {
        case .invalid: return .unavailable(.configurationMalformed)
        case .absent: return .unknownShare
        case .shares(let configured):
            guard configured.contains(where: { $0.id == shareID }) else { return .unknownShare }
        }
        reload()
        switch listing {
        case .unavailable(let reason):
            return .unavailable(reason)
        case .available(let rows):
            guard let row = rows.first(where: { $0.share.id == shareID }) else {
                return .unknownShare
            }
            guard case .mounted(let mountPoint) = row.mountState else { return .notMounted }
            guard environment.fileExists(SMBShareSupport.unmountToolPath) else {
                return .unavailable(.mountToolMissing)
            }
            let result = environment.run(SMBShareSupport.unmountToolPath, [mountPoint],
                                         SMBShareSupport.unmountTimeout)
            if result.status < 0 { return .failed(.timeout) }
            if result.status == 0 { return .unmounted }
            return .failed(SMBShareSupport.classifyMountFailure(status: result.status,
                                                                output: result.output))
        }
    }
}

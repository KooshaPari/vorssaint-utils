// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// One SMB share the person configured. Only the endpoint and the mount point
/// are stored; the password lives in the keychain under this share's
/// identifier and never reaches a plist, a log or a command line.
struct SMBShare: Equatable, Identifiable {
    let id: UUID
    var name: String
    var server: String
    var share: String
    var mountPoint: String
    var username: String?
    var domain: String?
}

/// A share the kernel reports as mounted. Read from `mount` output, never
/// inferred from a mount that was merely requested.
struct SMBMount: Equatable {
    let server: String
    let user: String?
    let share: String
    let mountPoint: String
}

enum SMBTableFailure: Error, Equatable {
    case malformed
}

/// Pure parsing and identity rules for the SMB share list and the mount table.
/// Everything here is a value transform, so the checks can drive it with plain
/// strings and no live share, kernel call or keychain.
enum SMBShareSupport {
    enum Configuration: Equatable {
        /// No configuration file exists: nothing is configured, which is not a
        /// backend failure and must not be reported as one.
        case absent
        case shares([SMBShare])
        /// The file exists but cannot be trusted: never present half of it.
        case invalid
    }

    static let mountToolPath = "/sbin/mount_smbfs"
    static let mountTableToolPath = "/sbin/mount"
    static let unmountToolPath = "/sbin/umount"
    static let mountTimeout: TimeInterval = 15
    static let unmountTimeout: TimeInterval = 10
    static let tableTimeout: TimeInterval = 5

    /// Decodes the stored configuration. A missing file is `absent`; unreadable
    /// JSON, a duplicate identifier, a duplicate endpoint or a value that could
    /// become ambiguous in a mount source is `invalid` as a whole.
    static func decodeConfiguration(_ text: String?) -> Configuration {
        guard let text else { return .absent }
        guard let data = text.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data),
              let object = root as? [String: Any],
              let rawShares = object["shares"] as? [[String: Any]] else { return .invalid }
        var shares: [SMBShare] = []
        var identifiers = Set<UUID>()
        var endpoints = Set<String>()
        for raw in rawShares {
            guard let identifierText = raw["id"] as? String,
                  let identifier = UUID(uuidString: identifierText),
                  let server = raw["server"] as? String,
                  let share = raw["share"] as? String,
                  let mountPoint = raw["mountPoint"] as? String else { return .invalid }
            let name = (raw["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let username = nonEmpty(raw["username"] as? String)
            let domain = nonEmpty(raw["domain"] as? String)
            guard isUsableServer(server), isUsableShare(share),
                  isUsablePath(mountPoint),
                  username.map(isUsableAccount) ?? true,
                  domain.map(isUsableAccount) ?? true else { return .invalid }
            guard identifiers.insert(identifier).inserted else { return .invalid }
            let endpoint = "\(server.lowercased())|\(share.lowercased())"
            // Two entries for one endpoint would compete for one mount point
            // and one keychain slot, so the configuration is rejected instead.
            guard endpoints.insert(endpoint).inserted else { return .invalid }
            shares.append(SMBShare(id: identifier,
                                   name: name.isEmpty ? share : name,
                                   server: server,
                                   share: share,
                                   mountPoint: mountPoint,
                                   username: username,
                                   domain: domain))
        }
        return .shares(shares)
    }

    /// A blank optional field means "not configured", not a malformed value.
    static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    static func isUsableServer(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        let forbidden = CharacterSet(charactersIn: "/@:").union(.whitespacesAndNewlines)
        return value.rangeOfCharacter(from: forbidden) == nil
    }

    static func isUsableShare(_ value: String) -> Bool {
        guard !value.isEmpty, value != ".", value != ".." else { return false }
        let forbidden = CharacterSet(charactersIn: "/\u{0}").union(.newlines)
        return value.rangeOfCharacter(from: forbidden) == nil
    }

    static func isUsableAccount(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        let forbidden = CharacterSet(charactersIn: "/@:;").union(.whitespacesAndNewlines)
        return value.rangeOfCharacter(from: forbidden) == nil
    }

    static func isUsablePath(_ value: String) -> Bool {
        value.hasPrefix("/") && value != "/" && value.rangeOfCharacter(from: .newlines) == nil
    }

    /// The `//[domain;][user@]server/share` form `mount_smbfs` accepts. No
    /// password segment is ever built here: the tool reads the keychain.
    static func mountSource(_ share: SMBShare) -> String? {
        guard isUsableServer(share.server), isUsableShare(share.share) else { return nil }
        var authority = ""
        if let domain = share.domain, !domain.isEmpty {
            guard isUsableAccount(domain) else { return nil }
            authority += "\(domain);"
        }
        if let username = share.username, !username.isEmpty {
            guard isUsableAccount(username) else { return nil }
            authority += "\(username)@"
        }
        return "//\(authority)\(share.server)/\(share.share)"
    }

    /// Parses `mount` output. Non-SMB lines are ignored; a line that does claim
    /// to be an SMB mount but has no recognisable shape fails the whole read,
    /// so an unreadable table is never mistaken for "nothing is mounted".
    static func parseMountTable(_ text: String) -> Result<[SMBMount], SMBTableFailure> {
        var mounts: [SMBMount] = []
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(rawLine).trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("//") else { continue }
            let body = String(line.dropFirst(2))
            guard let onRange = body.range(of: " on ") else {
                return .failure(.malformed)
            }
            let endpoint = String(body[body.startIndex..<onRange.lowerBound])
            let remainder = String(body[onRange.upperBound...])
            guard let openParen = remainder.firstIndex(of: "(") else {
                return .failure(.malformed)
            }
            let mountPoint = String(remainder[remainder.startIndex..<openParen])
                .trimmingCharacters(in: .whitespaces)
            let options = remainder[openParen...].lowercased()
            guard options.contains("smbfs") else { continue }
            let authorityAndShare = endpoint.split(separator: "/", maxSplits: 1,
                                                   omittingEmptySubsequences: false)
            guard authorityAndShare.count == 2, !authorityAndShare[1].isEmpty else {
                return .failure(.malformed)
            }
            let authority = String(authorityAndShare[0])
            let share = String(authorityAndShare[1])
            let account = authority.split(separator: "@", maxSplits: 1,
                                          omittingEmptySubsequences: false)
            let server = account.count == 2 ? String(account[1]) : authority
            let user = account.count == 2 ? String(account[0]) : nil
            guard !server.isEmpty, isUsablePath(mountPoint) else { return .failure(.malformed) }
            mounts.append(SMBMount(server: server, user: user, share: share, mountPoint: mountPoint))
        }
        return .success(mounts)
    }

    /// Where this share is mounted right now, preferring the configured mount
    /// point and otherwise reporting the one the kernel actually used. Server
    /// and share comparisons are exact, case-insensitive; two endpoints that
    /// merely resemble each other never collapse into one mount.
    static func mountPoint(for share: SMBShare, in mounts: [SMBMount]) -> String? {
        let configured = normalisedPath(share.mountPoint)
        let candidates = mounts.filter {
            $0.server.caseInsensitiveCompare(share.server) == .orderedSame
                && $0.share.caseInsensitiveCompare(share.share) == .orderedSame
        }
        if let exact = candidates.first(where: { normalisedPath($0.mountPoint) == configured }) {
            return exact.mountPoint
        }
        return candidates.first?.mountPoint
    }

    static func normalisedPath(_ value: String) -> String {
        var path = value
        while path.count > 1 && path.hasSuffix("/") { path.removeLast() }
        return path
    }

    /// Keeps `mount_smbfs` diagnostics out of the state entirely; only a named
    /// category is published, so no tool output can carry anything sensitive
    /// into a log or the UI.
    static func classifyMountFailure(status: Int32, output: String) -> SMBFailure {
        let lower = output.lowercased()
        for marker in ["permission denied", "authentication", "auth fail",
                       "access denied", "logon failure", "insufficient privileges"] {
            if lower.contains(marker) { return .credentialRejected }
        }
        for marker in ["file exists", "already mounted", "resource busy"] {
            if lower.contains(marker) { return .mountPointBusy }
        }
        return .commandFailed(status)
    }
}

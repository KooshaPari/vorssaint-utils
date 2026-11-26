// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Runs the production share service against an in-memory config, mount table,
/// tool set and keychain. No share is mounted, no tool is launched and no
/// password is stored anywhere real.
enum SMBSharesTests {
    static let configPath = "/tmp/vorssaint-smb-shares.json"
    static let mediaID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let archiveID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    final class Projection: SMBKeychainProjection {
        var published: [UUID: String] = [:]
        var publishCount = 0
        var withdrawCount = 0
        var accepts = true

        func publish(_ secret: String, for share: SMBShare) -> Bool {
            publishCount += 1
            guard accepts else { return false }
            published[share.id] = secret
            return true
        }

        func withdraw(for share: SMBShare) {
            withdrawCount += 1
            published[share.id] = nil
        }
    }

    final class Runtime {
        var files: [String: String?] = [:]
        var tools: Set<String> = [SMBShareSupport.mountToolPath,
                                  SMBShareSupport.mountTableToolPath,
                                  SMBShareSupport.unmountToolPath]
        var responses: [String: (status: Int32, output: String)] = [:]
        var commands: [(path: String, arguments: [String], timeout: TimeInterval)] = []
        var createsDirectory = true
        var createdDirectories: [String] = []

        func environment() -> SMBEnvironment {
            let runtime = self
            return SMBEnvironment(
                run: { path, arguments, timeout in
                    runtime.commands.append((path, arguments, timeout))
                    return runtime.responses[path] ?? (0, "")
                },
                fileExists: { runtime.files[$0] != nil || runtime.tools.contains($0) },
                readText: { runtime.files[$0] ?? nil },
                createDirectory: { path in
                    runtime.createdDirectories.append(path)
                    return runtime.createsDirectory
                }
            )
        }

        func respond(_ path: String, _ status: Int32, _ output: String) {
            responses[path] = (status, output)
        }
    }

    static func configuration(_ shares: [(id: UUID, server: String, share: String,
                                          mountPoint: String, name: String?,
                                          username: String?, domain: String?)]) -> String {
        let entries = shares.map { share -> String in
            var fields: [String] = []
            fields.append("\"id\": \"\(share.id.uuidString)\"")
            fields.append("\"server\": \"\(share.server)\"")
            fields.append("\"share\": \"\(share.share)\"")
            fields.append("\"mountPoint\": \"\(share.mountPoint)\"")
            if let name = share.name { fields.append("\"name\": \"\(name)\"") }
            if let username = share.username { fields.append("\"username\": \"\(username)\"") }
            if let domain = share.domain { fields.append("\"domain\": \"\(domain)\"") }
            return "{ \(fields.joined(separator: ", ")) }"
        }
        return "{ \"shares\": [ \(entries.joined(separator: ", ")) ] }"
    }

    static let mediaConfiguration = configuration([
        (mediaID, "nas.local", "media", "/Volumes/media", "Media", "koosh", nil),
    ])

    static func makeService(_ runtime: Runtime,
                            config: String? = mediaConfiguration,
                            secrets: InMemoryAgentSecretStore = InMemoryAgentSecretStore(),
                            projection: Projection = Projection()) -> SMBSharesService {
        if let config { runtime.files[configPath] = config }
        return SMBSharesService(configurationURL: URL(fileURLWithPath: configPath),
                                secrets: secrets,
                                projection: projection,
                                environment: runtime.environment())
    }

    static func run(_ suite: TestSuite) {
        suite.run("smb-configuration") {
            suite.expect(SMBShareSupport.decodeConfiguration(nil) == .absent,
                         "a missing configuration file is absent, not malformed")
            suite.expect(SMBShareSupport.decodeConfiguration("{\"shares\":[]}") == .shares([]),
                         "an explicitly empty configuration decodes to no shares")
            suite.expect(SMBShareSupport.decodeConfiguration("not json") == .invalid,
                         "unreadable configuration is rejected as a whole")

            let duplicateIdentifier = configuration([
                (mediaID, "nas.local", "media", "/Volumes/media", nil, nil, nil),
                (mediaID, "nas.local", "photos", "/Volumes/photos", nil, nil, nil),
            ])
            suite.expect(SMBShareSupport.decodeConfiguration(duplicateIdentifier) == .invalid,
                         "one identifier cannot address two shares")

            let duplicateEndpoint = configuration([
                (mediaID, "nas.local", "media", "/Volumes/media", nil, nil, nil),
                (archiveID, "NAS.local", "MEDIA", "/Volumes/other", nil, nil, nil),
            ])
            suite.expect(SMBShareSupport.decodeConfiguration(duplicateEndpoint) == .invalid,
                         "one endpoint cannot own two mount points")

            let badServer = configuration([
                (mediaID, "nas/local", "media", "/Volumes/media", nil, nil, nil),
            ])
            suite.expect(SMBShareSupport.decodeConfiguration(badServer) == .invalid,
                         "a server that would change the mount source is rejected")

            let defaults = configuration([
                (mediaID, "nas.local", "media", "/Volumes/media", nil, "", ""),
            ])
            if case .shares(let shares) = SMBShareSupport.decodeConfiguration(defaults) {
                suite.expect(shares.count == 1 && shares[0].name == "media"
                             && shares[0].username == nil && shares[0].domain == nil,
                             "a blank name and account fields fall back without becoming errors")
            } else {
                suite.expect(false, "a valid configuration must decode")
            }

            let runtime = Runtime()
            let service = makeService(runtime, config: "{\"shares\":[]}")
            suite.expect(service.reload() == .available([]),
                         "no configured shares is an available empty list")
            suite.expect(runtime.commands.isEmpty,
                         "an empty configuration launches no tool at all")
            let absent = Runtime()
            let absentService = makeService(absent, config: nil)
            suite.expect(absentService.reload() == .available([]),
                         "a missing configuration file is not a backend failure")
            absentService.storeCredential("secret", for: mediaID)
            suite.expect(absentService.mount(shareID: mediaID) == .unknownShare,
                         "a share that is not configured cannot be mounted")
        }

        suite.run("smb-listing") {
            let runtime = Runtime()
            let service = makeService(runtime)
            let listing = service.reload()
            suite.expect(listing.rows.count == 1
                         && listing.rows[0].mountState == .unmounted
                         && listing.rows[0].credential == .missing,
                         "a configured share with no mount and no password states both plainly")
            let table = runtime.commands.first { $0.path == SMBShareSupport.mountTableToolPath }
            suite.expect(table?.timeout == SMBShareSupport.tableTimeout
                         && (table?.timeout ?? 0) > 0,
                         "the mount table is read under the bounded timeout")

            runtime.files["/Volumes/media"] = ""
            service.storeCredential("correct horse", for: mediaID)
            suite.expect(service.reload().rows.first?.credential == .stored,
                         "a stored password is reported as stored without being read back")

            runtime.respond(SMBShareSupport.mountTableToolPath, 0, """
                /dev/disk3s1 on / (apfs, sealed, local, read-only, journaled)
                //koosh@nas.local/media on /Volumes/media (smbfs, nodev, nosuid, mounted by koosh)
                """)
            let mounted = service.reload()
            suite.expect(mounted.rows.first?.mountState == .mounted("/Volumes/media"),
                         "the kernel's own mount table supplies the mounted state")

            runtime.respond(SMBShareSupport.mountTableToolPath, 0,
                            "//koosh@other.local/media on /Volumes/media (smbfs, nodev)")
            suite.expect(service.reload().rows.first?.mountState == .unmounted,
                         "a different server with the same share name is not this share's mount")

            runtime.respond(SMBShareSupport.mountTableToolPath, 0,
                            "//koosh@nas.local/media on /Volumes/disks/media (smbfs, nodev)")
            suite.expect(service.reload().rows.first?.mountState == .mounted("/Volumes/disks/media"),
                         "a share mounted elsewhere reports the path the kernel used")

            runtime.respond(SMBShareSupport.mountTableToolPath, 0,
                            "//koosh@nas.local/media broken (smbfs, nodev)")
            let malformed = service.reload()
            suite.expect(malformed == .unavailable(.mountTableMalformed) && malformed.rows.isEmpty,
                         "a malformed smb row fails the read instead of inventing states")

            runtime.respond(SMBShareSupport.mountTableToolPath, 0, "")
            suite.expect(service.reload() == .available([
                SMBShareRow(share: mediaShare(),
                            credential: .stored,
                            mountState: .unmounted)]),
                         "an empty table is a genuine unmounted answer")

            runtime.respond(SMBShareSupport.mountTableToolPath, -1, "")
            suite.expect(service.reload() == .unavailable(.mountTableUnavailable),
                         "a timed-out table is unavailable, never empty")

            runtime.respond(SMBShareSupport.mountTableToolPath, 0, "")
            runtime.tools.remove(SMBShareSupport.mountToolPath)
            suite.expect(service.reload() == .unavailable(.mountToolMissing),
                         "without mount_smbfs the share list is unavailable, not unmounted")
        }

        suite.run("smb-mount") {
            let secrets = InMemoryAgentSecretStore()
            let projection = Projection()
            let runtime = Runtime()
            let service = makeService(runtime, secrets: secrets, projection: projection)
            suite.expect(service.mount(shareID: mediaID) == .failed(.credentialMissing),
                         "a mount without a password is a named credential state")
            suite.expect(runtime.commands.isEmpty && projection.publishCount == 0,
                         "a missing password never reaches a tool or the keychain projection")

            suite.expect(service.storeCredential("hunter2", for: mediaID),
                         "the password is accepted by the shared keychain store")
            runtime.respond(SMBShareSupport.mountToolPath, 0, "")
            let outcome = service.mount(shareID: mediaID)
            suite.expect(outcome == .mounted("/Volumes/media"),
                         "a successful mount reports the configured mount point")
            let invocation = runtime.commands.first { $0.path == SMBShareSupport.mountToolPath }
            suite.expect(invocation?.arguments == ["-N", "//koosh@nas.local/media", "/Volumes/media"],
                         "the tool receives a password-free source and the mount point")
            suite.expect(invocation?.timeout == SMBShareSupport.mountTimeout,
                         "the mount runs under the bounded timeout")
            suite.expect(projection.publishCount == 1 && projection.withdrawCount == 1,
                         "the projection holds the password only for the call")
            suite.expect(projection.published.isEmpty,
                         "the projected keychain item is withdrawn afterwards")
            suite.expect(!(invocation?.arguments ?? []).joined().contains("hunter2"),
                         "the password never appears in an argument list")
            suite.expect(runtime.createdDirectories == ["/Volumes/media"],
                         "the mount point is created before the mount is attempted")

            runtime.respond(SMBShareSupport.mountToolPath, 1,
                            "mount_smbfs: server connection failed: Permission denied")
            suite.expect(service.mount(shareID: mediaID) == .failed(.credentialRejected),
                         "a rejected password is reported as rejected, without tool text")
            suite.expect(projection.withdrawCount == 2,
                         "the projection is withdrawn on a rejected mount too")

            runtime.respond(SMBShareSupport.mountToolPath, 1, "mount_smbfs: File exists")
            suite.expect(service.mount(shareID: mediaID) == .failed(.mountPointBusy),
                         "an already-used mount point has its own named failure")

            runtime.respond(SMBShareSupport.mountToolPath, 1, "mount_smbfs: odd internal error")
            suite.expect(service.mount(shareID: mediaID) == .failed(.commandFailed(1)),
                         "an unclassified failure keeps only its status")

            runtime.respond(SMBShareSupport.mountToolPath, -1, "")
            suite.expect(service.mount(shareID: mediaID) == .failed(.timeout),
                         "a mount that outlives its bound reports a timeout")

            runtime.respond(SMBShareSupport.mountToolPath, 0, "")
            projection.accepts = false
            suite.expect(service.mount(shareID: mediaID) == .failed(.credentialPublishFailed),
                         "a keychain that refuses the password stops before any tool runs")

            projection.accepts = true
            runtime.createsDirectory = false
            suite.expect(service.mount(shareID: mediaID) == .failed(.mountPointUnavailable),
                         "a mount point that cannot be created is its own failure")

            runtime.createsDirectory = true
            let domainConfiguration = configuration([
                (mediaID, "nas.local", "media", "/Volumes/media", nil, "koosh", "WORKGROUP"),
            ])
            let domainRuntime = Runtime()
            let domainSecrets = InMemoryAgentSecretStore()
            let domainService = makeService(domainRuntime, config: domainConfiguration,
                                            secrets: domainSecrets)
            domainSecrets.set("hunter2", for: mediaID)
            domainService.mount(shareID: mediaID)
            let domainInvocation = domainRuntime.commands
                .first { $0.path == SMBShareSupport.mountToolPath }
            suite.expect(domainInvocation?.arguments[1] == "//WORKGROUP;koosh@nas.local/media",
                         "a domain and account are carried in the documented source form")

            let missingToolRuntime = Runtime()
            missingToolRuntime.tools.remove(SMBShareSupport.mountToolPath)
            let missingToolSecrets = InMemoryAgentSecretStore()
            let missingToolService = makeService(missingToolRuntime, secrets: missingToolSecrets)
            _ = missingToolSecrets.set("hunter2", for: mediaID)
            suite.expect(missingToolService.mount(shareID: mediaID) == .unavailable(.mountToolMissing),
                         "a mount without the tool is unavailable rather than failed")

            suite.expect(service.mount(shareID: archiveID) == .unknownShare,
                         "mounting an unconfigured identifier changes nothing")
            suite.expect(!service.storeCredential("", for: archiveID),
                         "an empty password is not stored")
        }

        suite.run("smb-unmount") {
            let runtime = Runtime()
            let service = makeService(runtime)
            suite.expect(service.unmount(shareID: mediaID) == .notMounted,
                         "unmounting a share the kernel does not list is a named not-mounted state")
            suite.expect(!runtime.commands.contains { $0.path == SMBShareSupport.unmountToolPath },
                         "no unmount command runs for a share that is not mounted")

            runtime.respond(SMBShareSupport.mountTableToolPath, 0,
                            "//koosh@nas.local/media on /Volumes/media (smbfs, nodev)")
            runtime.respond(SMBShareSupport.unmountToolPath, 0, "")
            suite.expect(service.unmount(shareID: mediaID) == .unmounted,
                         "a mounted share unmounts")
            let invocation = runtime.commands.first { $0.path == SMBShareSupport.unmountToolPath }
            suite.expect(invocation?.arguments == ["/Volumes/media"]
                         && invocation?.timeout == SMBShareSupport.unmountTimeout,
                         "the unmount targets the reported path under the bounded timeout")

            runtime.respond(SMBShareSupport.unmountToolPath, -1, "")
            suite.expect(service.unmount(shareID: mediaID) == .failed(.timeout),
                         "an unmount that outlives its bound reports a timeout")

            runtime.respond(SMBShareSupport.mountTableToolPath, 0,
                            "//koosh@nas.local/media broken (smbfs)")
            suite.expect(service.unmount(shareID: mediaID) == .unavailable(.mountTableMalformed),
                         "an unreadable table leaves the unmount unperformed and unavailable")

            suite.expect(service.unmount(shareID: archiveID) == .unknownShare,
                         "unmounting an unconfigured identifier changes nothing")
        }

        // Keychain accessibility is a source property, not a runtime one: the
        // real store needs the Security framework, so there is no way to ask an
        // item what class it was written with on a Linux node. Reading the two
        // source files is the check that can run both here and on the Mac, and
        // it is the check that catches a future edit reintroducing the
        // migratable class.
        suite.run("smb-secret-accessibility") {
            for (label, relative) in [
                ("agent secret store", "Sources/Vorssaint/Services/AgentUsage/AgentSecretStore.swift"),
                ("smb share secrets", "Sources/Vorssaint/Services/SMB/SMBSharesLive.swift"),
            ] {
                guard let source = SMBSharesTests.sourceText(relative) else {
                    suite.expect(false, "\(label): source not found at \(relative)")
                    continue
                }

                // Every line that picks an accessibility class must pick the
                // device-bound one. `AfterFirstUnlock` is a prefix of
                // `AfterFirstUnlockThisDeviceOnly`, so the test is per line:
                // a line may mention the plain constant only if it also names
                // the ThisDeviceOnly form.
                let offenders = source
                    .split(separator: "\n", omittingEmptySubsequences: false)
                    .filter { $0.contains("kSecAttrAccessibleAfterFirstUnlock") }
                    .filter { !$0.contains("ThisDeviceOnly") }
                suite.expect(offenders.isEmpty,
                             "\(label): no line uses the migratable accessibility class, found \(offenders.count)")

                // The class must be present at all, otherwise the check above
                // would pass vacuously on a file that stopped writing secrets.
                suite.expect(source.contains("AgentSecretAccessibility.item"),
                             "\(label): writes go through the shared device-bound constant")
            }

            // An item written by an earlier build keeps its old class until a
            // write re-classifies it, so the update path must carry the
            // accessibility attribute too, not only kSecValueData.
            if let store = SMBSharesTests.sourceText("Sources/Vorssaint/Services/AgentUsage/AgentSecretStore.swift") {
                let updateBodies = store
                    .components(separatedBy: "kSecValueData as String")
                    .dropFirst()
                suite.expect(updateBodies.contains { $0.contains("kSecAttrAccessible") },
                             "the existing-item update carries an accessibility class")
            }
            if let live = SMBSharesTests.sourceText("Sources/Vorssaint/Services/SMB/SMBSharesLive.swift") {
                suite.expect(live.contains("kSecAttrAccessible as String: AgentSecretAccessibility.item"),
                             "the smb update path carries the device-bound class")
            }
        }

        // Owner-only modes stop another account reading the container; they do
        // nothing about Time Machine, which copies Application Support onto a
        // backup volume and from there onto any Mac restored from it. Both the
        // directory chain and each written file must carry the exclusion flag.
        suite.run("private-file-store-backup-exclusion") {
            guard let store = SMBSharesTests.sourceText("Sources/Vorssaint/Services/PrivateFileStore.swift") else {
                suite.expect(false, "private file store: source not found")
                return
            }
            suite.expect(store.contains("isExcludedFromBackup = true"),
                         "the store marks its material excluded from backup")
            suite.expect(store.contains("URLResourceValues()"),
                         "the exclusion is set through resource values, not an xattr string")

            // Called from both creation and write, so a container or file left
            // behind by an earlier build heals on the next use.
            let callSites = store
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { $0.contains("excludeFromBackup(") && !$0.contains("static func") }
            suite.expect(callSites.count >= 2,
                         "the exclusion is applied on both directory creation and file write, found \(callSites.count) call sites")
        }
    }

    /// Resolve a repo-relative source path from either the test file's own
    /// location (a macOS build) or the process working directory (the Linux
    /// subset compiles this file into a temporary directory, where the sibling
    /// `Sources/` tree does not exist).
    static func sourceText(_ relative: String) -> String? {
        var roots: [String] = []
        let fileDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        roots.append(fileDir.deletingLastPathComponent().path)
        roots.append(FileManager.default.currentDirectoryPath)
        for root in roots {
            let candidate = URL(fileURLWithPath: root).appendingPathComponent(relative).path
            if let text = try? String(contentsOfFile: candidate, encoding: .utf8) {
                return text
            }
        }
        return nil
    }

    static func mediaShare() -> SMBShare {
        SMBShare(id: mediaID, name: "Media", server: "nas.local", share: "media",
                 mountPoint: "/Volumes/media", username: "koosh", domain: nil)
    }
}

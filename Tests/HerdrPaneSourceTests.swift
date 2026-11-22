// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Darwin
import Foundation

/// The herdr pane seam, with no live herdr required: fake fixtures for the
/// decoders, injected transport probes for liveness, and one real bounded
/// subprocess and socket to prove the deadlines hold.
enum HerdrPaneSourceTests {
    static func run(_ suite: TestSuite) {
        decodesTerminalFile(suite)
        nullStatusIsUnknown(suite)
        fullAddressKeepsMachine(suite)
        malformedSnapshotIsRejected(suite)
        serverStatus(suite)
        foregroundMapping(suite)
        resumeTokens(suite)
        probeOrder(suite)
        staleEnvironmentIsNotLiveness(suite)
        fileReplaceRace(suite)
        staleFileWithNoBackend(suite)
        neverPublishesEmptyAsLive(suite)
        capabilities(suite)
        boundedProcess(suite)
        killedOnExpiry(suite)
        boundedSocket(suite)
        structuralReadOnly(suite)
    }

    // MARK: Fixtures

    /// Two live panes, one finished one and one peer pane; addresses are fake.
    private static func fixture(title: String = "fake working") -> Data {
        Data("""
        {"next_id":7,"holder":{"id":"core-fixture","name":"fixture-desk"},"terminals":{
          "1":{"address":"t1","state":"live","status":"working","title":"\(title)","labels":{"herdr.space":"sp1","herdr.tab":"tb1","where":"Projects / Fake"},"foreground":{"name":"kcode.exe","argv":["C:\\\\fake\\\\kcode.exe","--resume","session_fake_1"]}},
          "2":{"address":"t2","state":"live","status":null,"title":null,"labels":{"where":"Projects / Shell"},"foreground":{"name":"pwsh.exe","argv":["C:\\\\fake\\\\pwsh.exe","-NoExit"]}},
          "3":{"address":"t3","state":"finished","status":"done","title":"fake done","labels":{},"foreground":null},
          "4":{"address":"mac/t1","state":"live","status":"blocked","title":"fake blocked","labels":{"where":"Mac / Fake"},"foreground":{"name":null,"argv":["/usr/local/bin/claude","--resume","session_fake_2"]}}
        }}
        """.utf8)
    }

    private static func peerFixture() -> Data {
        Data("""
        {"terminals":{
          "1":{"address":"mac/t1","state":"live","status":"idle"},
          "2":{"address":"nixos/t1","state":"live","status":"working"}
        }}
        """.utf8)
    }

    private static func statusJSON() -> Data {
        Data(#"{"core":{"id":"abc","name":"fixture-desk"},"finished":56,"holder":{"current":true,"terminals":33},"live":33,"pid":18920,"uptime_ms":89463449,"version":"0.1.21"}"#.utf8)
    }

    private static func temporaryDirectory(_ label: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("herdr-pane-\(label)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    private static func writeFixture(to directory: URL, title: String = "fake working") -> URL {
        let file = directory.appendingPathComponent("terminals.json")
        try? fixture(title: title).write(to: file)
        return file
    }

    private static func modificationDate(of url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    private static func pipeEndpoint() -> String { "\\\\.\\pipe\\herdr-core-fixture-default.sock" }

    private static func backend(directory: URL,
                                socket: FixtureSocket = FixtureSocket(connects: false),
                                commands: FixtureCommands = FixtureCommands(),
                                freshnessWindow: TimeInterval = 120) -> HerdrCoreBackend {
        HerdrCoreBackend(location: HerdrCoreLocation(stateDirectory: directory,
                                                     endpoint: pipeEndpoint(),
                                                     command: "hc"),
                         probes: HerdrTransportProbes(socket: socket, command: commands),
                         connectTimeout: 0.5, commandTimeout: 2,
                         freshnessWindow: freshnessWindow)
    }

    final class FixtureSocket: HerdrSocketProbing {
        var connects: Bool
        private(set) var endpoints: [String] = []
        private(set) var timeouts: [TimeInterval] = []

        init(connects: Bool) { self.connects = connects }

        func canConnect(to endpoint: String, timeout: TimeInterval) -> Bool {
            endpoints.append(endpoint)
            timeouts.append(timeout)
            return connects
        }
    }

    final class FixtureCommands: HerdrCommandRunning {
        var output: HerdrCommandResult?
        private(set) var calls: [HerdrCommand] = []
        private(set) var timeouts: [TimeInterval] = []

        init(output: HerdrCommandResult? = nil) { self.output = output }

        func run(_ command: HerdrCommand, timeout: TimeInterval) -> HerdrCommandResult? {
            calls.append(command)
            timeouts.append(timeout)
            return output
        }
    }

    // MARK: The HC state file

    private static func decodesTerminalFile(_ suite: TestSuite) {
        let stamp = Date(timeIntervalSince1970: 1_800_000_000)
        guard let rows = HerdrTerminalFile.decode(fixture(), observedAt: stamp) else {
            suite.expect(false, "a terminals.json fixture decodes")
            return
        }
        suite.expect(rows.map(\.id) == ["mac/t1", "t1", "t2", "t3"],
                     "rows are keyed by the full address and sorted")
        suite.expect(rows.filter { $0.lifecycle == .live }.count == 3
                        && rows.filter { $0.lifecycle == .finished }.count == 1,
                     "a mixed state file counts live and finished panes apart")
        suite.expect(rows.allSatisfy { $0.observedAt == stamp },
                     "every row is stamped with the time of its reading")

        guard let working = rows.first(where: { $0.id == "t1" }),
              let shell = rows.first(where: { $0.id == "t2" }),
              let finished = rows.first(where: { $0.id == "t3" }),
              let peer = rows.first(where: { $0.id == "mac/t1" }) else {
            suite.expect(false, "the fixture's rows are addressable")
            return
        }
        suite.expect(working.lifecycle == .live && working.status == .working,
                     "a live working pane keeps state and status apart")
        suite.expect(working.provider == .jcode && working.program == "kcode.exe",
                     "a kcode foreground names the jcode provider")
        suite.expect(working.resumeToken == "session_fake_1",
                     "a resumed kcode pane carries the token its argv names")
        suite.expect(working.space == "sp1" && working.tab == "tb1" && working.place == "Projects / Fake",
                     "space, tab and where labels survive")
        suite.expect(working.title == "fake working" && !working.needsAttention,
                     "a working pane keeps its title and asks for nothing")
        suite.expect(shell.program == "pwsh.exe" && shell.provider == nil,
                     "a bare shell pane has no provider")
        suite.expect(finished.lifecycle == .finished && finished.status == .done
                        && finished.provider == nil && finished.program == nil && finished.title == "fake done",
                     "a finished done pane keeps its state and reports no program")
        suite.expect(peer.machine == "mac" && peer.provider == .claude && peer.needsAttention,
                     "a blocked peer pane names its agent from argv and asks for attention")
        suite.expect(peer.resumeToken == "session_fake_2",
                     "the peer pane's session token comes from its own argv")
    }

    private static func nullStatusIsUnknown(_ suite: TestSuite) {
        suite.expect(AgentPaneStatus.decode(nil) == .unknown, "a null status is unknown")
        suite.expect(AgentPaneStatus.decode("") == .unknown, "an empty status is unknown")
        suite.expect(AgentPaneStatus.decode("nonsense") == .unknown,
                     "an unrecognised status is unknown, never idle")
        suite.expect(AgentPaneStatus.decode("live") == .unknown,
                     "a lifecycle value is never read as a status")
        suite.expect(AgentPaneStatus.decode("idle") == .idle
                        && AgentPaneStatus.decode("blocked").needsAttention
                        && !AgentPaneStatus.decode("done").needsAttention,
                     "reported statuses decode to themselves")
        suite.expect(AgentPaneLifecycle.decode("live") == .live
                        && AgentPaneLifecycle.decode(nil) == .unknown
                        && AgentPaneLifecycle.decode("retired") == .unknown,
                     "state decodes live, and is never defaulted to live")

        guard let rows = HerdrTerminalFile.decode(fixture(), observedAt: Date(timeIntervalSince1970: 0)),
              let shell = rows.first(where: { $0.id == "t2" }) else {
            suite.expect(false, "the shell pane decodes")
            return
        }
        suite.expect(shell.lifecycle == .live && shell.status == .unknown,
                     "a live pane whose program reported nothing is live with an unknown status, never idle")
        suite.expect(shell.status != .idle, "a null report is not an idle report")
    }

    private static func fullAddressKeepsMachine(_ suite: TestSuite) {
        let peers = HerdrTerminalFile.decode(peerFixture(), observedAt: Date(timeIntervalSince1970: 0))
        suite.expect(peers?.map(\.id) == ["mac/t1", "nixos/t1"],
                     "the same terminal id on two machines stays two rows")
        suite.expect(peers?.compactMap(\.machine) == ["mac", "nixos"],
                     "each peer row keeps its machine")
        guard let rows = HerdrTerminalFile.decode(fixture(), observedAt: Date(timeIntervalSince1970: 0)) else {
            suite.expect(false, "the fixture decodes for the address check")
            return
        }
        suite.expect(rows.first(where: { $0.id == "t1" })?.machine == nil,
                     "a local address has no machine prefix and is never invented one")
        suite.expect(Set(rows.map(\.id)).count == rows.count, "no two rows share an id")
        suite.expect(rows.first(where: { $0.id == "mac/t1" })?.address == "mac/t1",
                     "the reported address is kept verbatim")
    }

    private static func malformedSnapshotIsRejected(_ suite: TestSuite) {
        let now = Date(timeIntervalSince1970: 0)
        suite.expect(HerdrTerminalFile.decode(Data(#"{"next_id":1}"#.utf8), observedAt: now) == nil,
                     "a document without terminals decodes to nothing")
        suite.expect(HerdrTerminalFile.decode(Data(#"{"terminals":{"1":{"address":"t1""#.utf8), observedAt: now) == nil,
                     "a truncated write decodes to nothing")
        suite.expect(HerdrTerminalFile.decode(Data("not json".utf8), observedAt: now) == nil,
                     "a non-JSON file decodes to nothing")
        suite.expect(HerdrTerminalFile.decode(Data(#"{"terminals":{}}"#.utf8), observedAt: now)?.isEmpty == true,
                     "an empty fleet decodes to no rows, not to a failure")
        suite.expect(HerdrTerminalFile.decode(Data(#"{"terminals":{"1":{"state":"live"}}}"#.utf8),
                                              observedAt: now)?.isEmpty == true,
                     "a record without an address is left out")
    }

    private static func serverStatus(_ suite: TestSuite) {
        let live = HerdrServerStatus.decode(statusJSON())
        suite.expect(live?.version == "0.1.21" && live?.live == 33 && live?.finished == 56,
                     "a core's own status parses")
        suite.expect(HerdrServerStatus.decode(Data(#"{"error":{"code":"server_not_running"}}"#.utf8)) == nil,
                     "a server_not_running document is not a live core")
        suite.expect(HerdrServerStatus.decode(HerdrCommandResult(standardOutput: statusJSON(), status: 1)) == nil,
                     "a failed command is not a live core")
        suite.expect(HerdrServerStatus.decode(HerdrCommandResult(standardOutput: Data("nonsense".utf8), status: 0)) == nil,
                     "unparsable output is not a live core")
        suite.expect(HerdrServerStatus.decode(Data(#"{"error":{"kind":"usage"}}"#.utf8)) == nil,
                     "a usage error from the CLI is not a live core")
    }

    // MARK: Identity

    private static func foregroundMapping(_ suite: TestSuite) {
        let table: [(String?, [String], AgentProvider?)] = [
            ("kcode.exe", [#"C:\fake\kcode.exe"#], .jcode),
            ("jcode", ["/usr/local/bin/jcode"], .jcode),
            ("claude", ["/usr/local/bin/claude"], .claude),
            ("codex", ["/opt/homebrew/bin/codex"], .codex),
            ("opencode", ["/usr/local/bin/opencode"], .opencode),
            ("copilot", [#"C:\fake\copilot.exe"#], .copilot),
            ("pwsh.exe", [#"C:\Program Files\PowerShell\7\pwsh.exe"#], nil),
            ("zsh", ["/bin/zsh"], nil),
            ("bash", ["/bin/bash", "-l"], nil),
            ("fish", ["/usr/local/bin/fish", "-i"], nil),
            (nil, ["/bin/sh"], nil),
            ("herdr-app.exe", [#"C:\fake\herdr-app.exe"#], nil),
        ]
        for (name, argv, expected) in table {
            suite.expect(HerdrPaneIdentity.provider(name: name, argv: argv) == expected,
                         "\(name ?? "no name") maps to \(expected?.rawValue ?? "no provider")")
        }
        suite.expect(HerdrPaneIdentity.provider(name: nil, argv: ["/usr/local/bin/claude", "--resume", "s"]) == .claude,
                     "a missing name falls back to the foreground's own argv")
        suite.expect(HerdrPaneIdentity.executableName("/usr/local/bin/JCODE") == "jcode",
                     "an executable name is case-folded")
        suite.expect(HerdrPaneIdentity.executableName(#"C:\fake\Claude.EXE"#) == "claude",
                     "a Windows executable suffix is dropped")
    }

    private static func resumeTokens(_ suite: TestSuite) {
        let table: [([String], String?)] = [
            (["kcode.exe", "--resume", "session_a"], "session_a"),
            (["kcode.exe", "--resume=session_b"], "session_b"),
            (["kcode.exe", "--resume"], nil),
            (["kcode.exe", "--resume", "--verbose"], nil),
            (["kcode.exe", "--resume="], nil),
            (["kcode.exe"], nil),
            (["/usr/local/bin/claude", "--model", "x", "--resume", "session_c"], "session_c"),
        ]
        for (argv, expected) in table {
            suite.expect(HerdrPaneIdentity.resumeToken(in: argv) == expected,
                         "resume token for \(argv.joined(separator: " "))")
        }
    }

    // MARK: Liveness

    private static func probeOrder(_ suite: TestSuite) {
        let directory = temporaryDirectory("probe")
        defer { try? FileManager.default.removeItem(at: directory) }
        let socket = FixtureSocket(connects: true)
        let commands = FixtureCommands(output: HerdrCommandResult(standardOutput: statusJSON(), status: 0))

        let bySocket = backend(directory: directory, socket: socket, commands: commands).probe(now: Date())
        suite.expect(bySocket.step == .socket && bySocket.availability == .live,
                     "a connectable socket is the first liveness proof")
        suite.expect(commands.calls.isEmpty, "a connectable socket never runs the CLI")
        suite.expect(socket.timeouts == [0.5], "the connect probe is bounded to half a second")

        let byCommand = backend(directory: directory, socket: FixtureSocket(connects: false),
                                commands: commands).probe(now: Date())
        suite.expect(byCommand.step == .command && byCommand.availability == .live,
                     "the core's own status is the second proof")
        suite.expect(commands.calls.count == 1, "one poll runs one CLI probe, never a retry storm")
        suite.expect(commands.calls.first?.executable == "hc"
                        && commands.calls.first?.arguments == ["server", "status"],
                     "the only command is the core's own status")
        suite.expect(commands.timeouts.allSatisfy { $0 <= 2 }, "the CLI probe is bounded")

        writeFixture(to: directory)
        let byFile = backend(directory: directory, socket: FixtureSocket(connects: false),
                             commands: FixtureCommands()).probe(now: Date())
        suite.expect(byFile.step == .snapshot && byFile.availability == .snapshot,
                     "a freshly written state file is the last proof, named apart from a live transport")

        let empty = temporaryDirectory("probe-none")
        defer { try? FileManager.default.removeItem(at: empty) }
        let nothing = backend(directory: empty).probe(now: Date())
        suite.expect(nothing.step == .none && nothing.availability == .unavailable,
                     "with nothing reachable the probe says so")
    }

    private static func staleEnvironmentIsNotLiveness(_ suite: TestSuite) {
        let directory = temporaryDirectory("env")
        defer { try? FileManager.default.removeItem(at: directory) }
        let environment = [
            "HERDR_ENV": "1",
            "HERDR_PANE_ID": "wJ:p5G",
            "HERDR_TAB_ID": "wJ:t4",
            "HERDR_WORKSPACE_ID": "wJ",
            "HERDR_SOCKET_PATH": "/nonexistent/herdr.sock",
            "HERDR_BIN_PATH": "/nonexistent/herdr",
            "HC_TERMINAL_SOCKET": pipeEndpoint(),
        ]
        let location = HerdrCoreLocation.standard(environment: environment, applicationSupport: directory)
        suite.expect(location.endpoint == environment["HC_TERMINAL_SOCKET"],
                     "only the core's own endpoint is named")
        suite.expect(location.endpoint?.contains("herdr.sock") == false,
                     "HERDR_SOCKET_PATH is never adopted as an endpoint")

        let socket = FixtureSocket(connects: false)
        let commands = FixtureCommands()
        let subject = HerdrCoreBackend(location: location,
                                       probes: HerdrTransportProbes(socket: socket, command: commands),
                                       connectTimeout: 0.5, commandTimeout: 2, freshnessWindow: 120)
        let reading = subject.reading(now: Date())
        suite.expect(reading.availability == .unavailable && reading.rows.isEmpty,
                     "stale HERDR_ENV does not imply a live session")
        suite.expect(socket.endpoints == [pipeEndpoint()], "only the core's endpoint is probed")
        suite.expect(!socket.endpoints.contains("/nonexistent/herdr.sock"),
                     "a stale 0.9.x socket path is never connected")
        suite.expect(commands.calls.count == 1, "a stale environment still costs exactly one bounded probe")
    }

    // MARK: Degradation

    private static func fileReplaceRace(_ suite: TestSuite) {
        let directory = temporaryDirectory("race")
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = writeFixture(to: directory)
        let subject = backend(directory: directory, socket: FixtureSocket(connects: true))

        let first = subject.reading(now: Date())
        suite.expect(first.availability == .live && first.rows.count == 4,
                     "a live transport reads the fleet from the state file")
        suite.expect(first.readAt == modificationDate(of: file),
                     "a live reading is stamped with the file it decoded")

        try? FileManager.default.removeItem(at: file)
        let removed = subject.reading(now: Date())
        suite.expect(removed.availability == .live && removed.rows == first.rows,
                     "a state file removed under a live transport keeps the last good snapshot")
        suite.expect(removed.readAt == first.readAt,
                     "the retained rows keep the time they were decoded")
        suite.expect(!removed.rows.isEmpty, "a failed read is never published as an empty fleet")

        try? Data(#"{"terminals":{"1":{"address":"t1""#.utf8).write(to: file)
        let partial = subject.reading(now: Date())
        suite.expect(partial.rows == first.rows, "a half-written replacement keeps the last good snapshot")

        writeFixture(to: directory, title: "fake replaced")
        let replaced = subject.reading(now: Date())
        suite.expect(replaced.availability == .live
                        && replaced.rows.first(where: { $0.id == "t1" })?.title == "fake replaced",
                     "an intact replacement is adopted")
    }

    private static func staleFileWithNoBackend(_ suite: TestSuite) {
        let directory = temporaryDirectory("stale")
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = writeFixture(to: directory)
        try? FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -600)],
                                               ofItemAtPath: file.path)
        let stamp = modificationDate(of: file)
        let subject = backend(directory: directory)
        suite.expect(subject.probe(now: Date()).step == .none,
                     "an old state file with no transport is not liveness")
        let reading = subject.reading(now: Date())
        suite.expect(reading.availability == .stale, "an old file with no transport is stale, not a live fleet")
        suite.expect(reading.rows.count == 4, "a stale reading still shows the fleet it came from")
        suite.expect(reading.readAt == stamp, "a stale reading is stamped with the file it came from")
    }

    private static func neverPublishesEmptyAsLive(_ suite: TestSuite) {
        let directory = temporaryDirectory("empty")
        defer { try? FileManager.default.removeItem(at: directory) }
        let subject = backend(directory: directory, socket: FixtureSocket(connects: true))
        let reading = subject.reading(now: Date())
        suite.expect(reading.availability == .unavailable && reading.rows.isEmpty,
                     "a live transport with nothing readable publishes nothing, not an empty live fleet")
        suite.expect(reading.readAt == nil, "a reading with no rows has no reading time")
    }

    private static func capabilities(_ suite: TestSuite) {
        let directory = temporaryDirectory("capabilities")
        defer { try? FileManager.default.removeItem(at: directory) }
        let subject: any HerdrPaneSource = backend(directory: directory)
        suite.expect(subject.backend == .herdrCore, "the seam is occupied by the HC backend")
        suite.expect(subject.capabilities.reportsAgentSession == false,
                     "the HC backend reports no agent-session channel")
        suite.expect(subject.capabilities.reportsUsage == false,
                     "pane rows carry no tokens, so they stay out of spend and trends")
        suite.expect(subject.capabilities.reportsPaneState == true,
                     "the HC backend reports pane state")
        suite.expect(HerdrPaneReading.unavailable.capabilities == .herdrCore,
                     "an unavailable reading declares the same capabilities")
        suite.expect(HerdrPaneBackend.herdrCore.rawValue == "herdr-core",
                     "the shipped backend names its generation")
        suite.expect(HerdrPaneReading.unavailable.rows.isEmpty
                        && HerdrPaneReading.unavailable.availability == .unavailable,
                     "the unavailable reading is explicit and empty")
    }

    // MARK: Real deadlines

    private static func boundedProcess(_ suite: TestSuite) {
        let runner = HerdrProcessRunner()
        let echo = runner.run(HerdrCommand(executable: "/bin/echo", arguments: [#"{"ok":true}"#]), timeout: 2)
        let text = echo.flatMap { String(data: $0.standardOutput, encoding: .utf8) }?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        suite.expect(echo?.status == 0 && text == #"{"ok":true}"#,
                     "a probe that finishes returns its own output")

        let started = Date()
        let slow = runner.run(HerdrCommand(executable: "/bin/sleep", arguments: ["5"]), timeout: 0.2)
        suite.expect(slow == nil, "a probe that outlives its deadline returns nothing")
        suite.expect(Date().timeIntervalSince(started) < 3, "a deadline bounds the whole probe")
        suite.expect(echo?.standardOutput.isEmpty == false, "a finished probe keeps its bytes")

        let missing = runner.run(HerdrCommand(executable: "/nonexistent/herdr-fixture", arguments: []), timeout: 1)
        suite.expect(missing?.status != 0, "a command that is not there never reports success")
        suite.expect(missing.map { HerdrServerStatus.decode($0) == nil } == true,
                     "a failed command never decodes into a live core")
    }

    private static func killedOnExpiry(_ suite: TestSuite) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("herdr-kill-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let marker = "herdr-probe-\(UUID().uuidString.prefix(8))"
        let link = directory.appendingPathComponent(marker)
        try? FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "/bin/sleep")
        suite.expect(FileManager.default.fileExists(atPath: link.path), "the kill probe stages its own binary")
        guard FileManager.default.fileExists(atPath: link.path) else { return }

        let started = Date()
        let result = HerdrProcessRunner().run(HerdrCommand(executable: link.path, arguments: ["30"]),
                                              timeout: 0.2)
        let elapsed = Date().timeIntervalSince(started)
        var remaining = survivors(matching: marker)
        let deadline = Date().addingTimeInterval(2)
        while remaining > 0 && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
            remaining = survivors(matching: marker)
        }
        suite.expect(result == nil, "a probe past its deadline returns nothing")
        suite.expect(elapsed < 3, "the deadline bounds the wait, not the child")
        suite.expect(remaining == 0, "the process is killed at the deadline and leaves no orphan")
    }

    private static func survivors(matching marker: String) -> Int {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", marker]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return 1 }
        process.waitUntilExit()
        return process.terminationStatus == 0 ? 1 : 0
    }

    private static func boundedSocket(_ suite: TestSuite) {
        let probe = HerdrSocketProbe()
        let missing = "/tmp/herdr-missing-\(UUID().uuidString.prefix(8)).sock"
        let started = Date()
        let connected = probe.canConnect(to: missing, timeout: 0.5)
        suite.expect(!connected, "a socket that is not there does not connect")
        suite.expect(Date().timeIntervalSince(started) < 1, "a refused connect returns inside its bound")
        suite.expect(!probe.canConnect(to: pipeEndpoint(), timeout: 0.5),
                     "a Windows pipe path is named but not connectable from this build")

        let path = "/tmp/herdr-fixture-\(UUID().uuidString.prefix(8)).sock"
        if let listener = listeningSocket(at: path) {
            defer {
                _ = close(listener)
                _ = unlink(path)
            }
            suite.expect(probe.canConnect(to: path, timeout: 0.5),
                         "a listening core socket connects")
        } else {
            suite.expect(false, "the socket fixture could listen")
        }
    }

    private static func listeningSocket(at path: String) -> Int32? {
        _ = unlink(path)
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return nil }
        var address = sockaddr_un()
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        address.sun_family = sa_family_t(AF_UNIX)
        let length = withUnsafeMutablePointer(to: &address) { pointer -> socklen_t in
            let bytes = UnsafeMutableRawBufferPointer(start: pointer, count: MemoryLayout<sockaddr_un>.size)
            let offset = MemoryLayout<sockaddr_un>.offset(of: \.sun_path) ?? 2
            let utf8 = Array(path.utf8)
            for index in 0..<utf8.count { bytes[offset + index] = utf8[index] }
            bytes[offset + utf8.count] = 0
            return socklen_t(offset + utf8.count + 1)
        }
        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(descriptor, $0, length) }
        }
        guard bound == 0, listen(descriptor, 4) == 0 else {
            _ = close(descriptor)
            return nil
        }
        return descriptor
    }

    // MARK: Structure

    /// The reader must be incapable of touching a pane's contents, and must
    /// keep its rows out of turn, spend and trend aggregation. Both are
    /// properties of the source, so the source is what is checked.
    private static func structuralReadOnly(_ suite: TestSuite) {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let names = ["HerdrPaneSource.swift", "HerdrCoreBackend.swift", "HerdrTransport.swift"]
        let sources = names.compactMap { name -> String? in
            try? String(contentsOf: root.appendingPathComponent(
                "Sources/Vorssaint/Services/AgentUsage/Harness/\(name)"), encoding: .utf8)
        }
        suite.expect(sources.count == names.count, "the herdr sources are present to scan")
        guard sources.count == names.count else { return }

        let code = sources
            .flatMap { $0.components(separatedBy: "\n") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") }
        for token in ["screens", "terminal.read", "terminal read", "pane read", "read --lines"] {
            suite.expect(!code.contains { $0.contains(token) },
                         "the herdr reader cannot address screen content: \(token)")
        }

        let commands = code.filter { $0.contains("HerdrCommand(") }
        suite.expect(commands.count == 1, "the reader builds exactly one command")
        suite.expect(commands.first?.contains(#"["server", "status"]"#) == true,
                     "its one command is the core's own status")

        let codeText = code.joined(separator: "\n")
        for token in ["AgentLiveSession", "AgentUsageRecord", "AgentTokens", "burnRate", "AgentUsageSnapshot"] {
            suite.expect(!codeText.contains(token),
                         "herdr pane rows never reach turn, spend or trend aggregation: \(token)")
        }
        suite.expect(codeText.contains("AgentPaneState"), "the seam publishes its own pane row")
        suite.expect(codeText.contains("HerdrPaneIdentity"), "identity stays mechanical and shared")
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Darwin
import Foundation

/// One read-only herdr command, passed as an argument vector and never as a
/// shell string. The seam issues exactly one: `hc server status`. Nothing here
/// can address a pane's screen.
struct HerdrCommand: Equatable {
    let executable: String
    let arguments: [String]
}

struct HerdrCommandResult: Equatable {
    let standardOutput: Data
    let status: Int32
}

/// Runs one command under a hard deadline and kills it on expiry. An orphaned
/// herdr reporter on this host ran for sixteen hours with its parent gone, so
/// no probe may outlive its timeout: `nil` means the deadline was reached, and
/// whatever was left of the process was killed before returning.
protocol HerdrCommandRunning {
    func run(_ command: HerdrCommand, timeout: TimeInterval) -> HerdrCommandResult?
}

/// Connects to the core's endpoint and closes at once, without reading or
/// writing a byte. A successful connect is the only proof that a core is there.
protocol HerdrSocketProbing {
    func canConnect(to endpoint: String, timeout: TimeInterval) -> Bool
}

/// The probes the backend uses in the app. Tests substitute their own, so no
/// live herdr is needed to run the suite.
struct HerdrTransportProbes {
    let socket: any HerdrSocketProbing
    let command: any HerdrCommandRunning

    static let live = HerdrTransportProbes(socket: HerdrSocketProbe(), command: HerdrProcessRunner())
}

/// A bounded subprocess. The command is resolved through `/usr/bin/env` so a
/// configured name is never turned into an absolute path here.
struct HerdrProcessRunner: HerdrCommandRunning {
    /// Collected on a reader thread so a child that leaves its output open
    /// cannot hold the caller past the deadline.
    private final class Output {
        private let lock = NSLock()
        private var data = Data()

        func append(_ chunk: Data) {
            lock.withLock { data.append(chunk) }
        }

        var value: Data { lock.withLock { data } }
    }

    func run(_ command: HerdrCommand, timeout: TimeInterval) -> HerdrCommandResult? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command.executable] + command.arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }

        let output = Output()
        let finished = DispatchSemaphore(value: 0)
        let reader = pipe.fileHandleForReading
        DispatchQueue.global(qos: .utility).async {
            while true {
                let chunk = reader.availableData
                if chunk.isEmpty { break }
                output.append(chunk)
            }
            finished.signal()
        }

        let deadline = Date().addingTimeInterval(max(0.01, timeout))
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        if process.isRunning {
            // Ask first, then insist: a stuck reporter is not entitled to
            // survive its own probe.
            process.terminate()
            let grace = Date().addingTimeInterval(0.2)
            while process.isRunning && Date() < grace {
                Thread.sleep(forTimeInterval: 0.02)
            }
            if process.isRunning { _ = kill(process.processIdentifier, SIGKILL) }
            process.waitUntilExit()
            _ = finished.wait(timeout: .now() + 0.2)
            return nil
        }

        process.waitUntilExit()
        // A daemon the child started could still hold the pipe open; the
        // reader is bounded rather than trusted.
        _ = finished.wait(timeout: .now() + 0.2)
        return HerdrCommandResult(standardOutput: output.value, status: process.terminationStatus)
    }
}

/// Connects to a Unix-domain socket and closes. A Windows named pipe is named
/// like a path here but cannot be opened from this build, so it fails closed
/// and the next liveness step takes its turn.
struct HerdrSocketProbe: HerdrSocketProbing {
    func canConnect(to endpoint: String, timeout: TimeInterval) -> Bool {
        guard !endpoint.isEmpty, !endpoint.hasPrefix("\\\\.\\pipe\\") else { return false }
        let path = Array(endpoint.utf8)
        guard path.count < 104 else { return false }

        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return false }
        defer { _ = close(descriptor) }
        let flags = fcntl(descriptor, F_GETFL, 0)
        _ = fcntl(descriptor, F_SETFL, flags | O_NONBLOCK)

        var address = sockaddr_un()
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        address.sun_family = sa_family_t(AF_UNIX)
        let length = withUnsafeMutablePointer(to: &address) { pointer -> socklen_t in
            let bytes = UnsafeMutableRawBufferPointer(start: pointer, count: MemoryLayout<sockaddr_un>.size)
            let offset = MemoryLayout<sockaddr_un>.offset(of: \.sun_path) ?? 2
            for index in 0..<path.count { bytes[offset + index] = path[index] }
            bytes[offset + path.count] = 0
            return socklen_t(offset + path.count + 1)
        }

        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(descriptor, $0, length) }
        }
        if result == 0 { return true }
        guard errno == EINPROGRESS || errno == EALREADY else { return false }

        var pending = pollfd(fd: descriptor, events: Int16(POLLOUT), revents: 0)
        let milliseconds = Int32(max(1, min(timeout, 10) * 1000))
        guard poll(&pending, 1, milliseconds) == 1 else { return false }
        var error: Int32 = 0
        var size = socklen_t(MemoryLayout<Int32>.size)
        guard getsockopt(descriptor, SOL_SOCKET, SO_ERROR, &error, &size) == 0 else { return false }
        return error == 0
    }
}

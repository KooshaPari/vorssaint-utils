// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Darwin
import Foundation

/// Why a declared Mullvad egress cannot carry a request. Each case is its own
/// state: a stopped daemon, a daemon that is not connected, a live daemon whose
/// relay is unreachable and a closed listener must never look like success, and
/// must never collapse into one another.
enum MullvadUnavailableReason: String, CaseIterable, Equatable, Sendable {
    case cliMissing
    case daemonStopped
    case daemonNotConnected
    case relayUnreachable
    case socksPortClosed
    case malformedOutput
    case timedOut
}

/// The outcome of checking one declared listener.
enum MullvadSOCKS5Reading: Equatable, Sendable {
    case available(MullvadSOCKS5Endpoint)
    case unavailable(MullvadUnavailableReason)
}

/// Availability source for `EgressPolicy.resolve`. Tests substitute fakes so no
/// check depends on a real tunnel.
protocol MullvadProbing: Sendable {
    func availability(expecting endpoint: MullvadSOCKS5Endpoint) -> MullvadSOCKS5Reading
}

/// Parsing for the Mullvad CLI's `status` command. Matching is deliberately
/// narrow: an output shape this app does not recognise is malformed, never a
/// guessed success.
enum MullvadCLIOutput {
    enum Status: Equatable {
        case connected
        case disconnected
        case connecting
        case blocked
        case daemonStopped
        case malformed
    }

    static func parse(status: Int32, output: String) -> Status {
        let text = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .malformed }
        let lower = text.lowercased()
        if lower.contains("failed to connect to daemon")
            || lower.contains("daemon is not running")
            || lower.contains("daemon is stopped")
            || (lower.contains("daemon") && lower.contains("connection refused")) {
            return .daemonStopped
        }
        if text.hasPrefix("Connected") { return .connected }
        if text.hasPrefix("Connecting") { return .connecting }
        if text.hasPrefix("Disconnected") { return .disconnected }
        if text.hasPrefix("Blocked") { return .blocked }
        return .malformed
    }
}

/// Checks the local Mullvad installation without reading any secret material.
/// The CLI is asked for its connection state; the declared
/// SOCKS5 listener is then verified with a TCP connect and a SOCKS5 greeting,
/// which distinguishes a closed port from a live listener whose relay is gone.
struct MullvadProbe: MullvadProbing {
    struct CommandResult: Equatable, Sendable {
        let status: Int32
        let output: String
        let timedOut: Bool
        let launched: Bool
    }

    enum SOCKS5Handshake: Equatable, Sendable {
        case reachable
        case portClosed
        case handshakeFailed
    }

    typealias CommandRunner = @Sendable (TimeInterval) -> CommandResult
    typealias Transport = @Sendable (MullvadSOCKS5Endpoint, TimeInterval) -> SOCKS5Handshake

    static let defaultCLIPath = "/Applications/Mullvad VPN.app/Contents/Resources/mullvad"
    /// Both shell-out and socket work are bounded; neither can hold a caller.
    static let statusTimeout: TimeInterval = 3
    static let transportTimeout: TimeInterval = 2

    private let runCommand: CommandRunner
    private let transport: Transport

    init(runCommand: @escaping CommandRunner = MullvadProbe.launchStatus,
         transport: @escaping Transport = MullvadProbe.systemTransport) {
        self.runCommand = runCommand
        self.transport = transport
    }

    func availability(expecting endpoint: MullvadSOCKS5Endpoint) -> MullvadSOCKS5Reading {
        let command = runCommand(Self.statusTimeout)
        guard command.launched else { return .unavailable(.cliMissing) }
        guard !command.timedOut else { return .unavailable(.timedOut) }
        switch MullvadCLIOutput.parse(status: command.status, output: command.output) {
        case .connected:
            break
        case .daemonStopped:
            return .unavailable(.daemonStopped)
        case .disconnected, .connecting, .blocked:
            return .unavailable(.daemonNotConnected)
        case .malformed:
            return .unavailable(.malformedOutput)
        }
        switch transport(endpoint, Self.transportTimeout) {
        case .reachable:
            return .available(endpoint)
        case .portClosed:
            return .unavailable(.socksPortClosed)
        case .handshakeFailed:
            return .unavailable(.relayUnreachable)
        }
    }

    /// The only shell-out in this module. Output is bounded and the child is
    /// killed by `BoundedProcessRunner` when the timeout expires; the raw output
    /// never leaves this function, so a CLI error cannot carry tunnel material
    /// into a log or a message.
    static func launchStatus(timeout: TimeInterval) -> CommandResult {
        let path = defaultCLIPath
        guard FileManager.default.isExecutableFile(atPath: path) else {
            return CommandResult(status: -1, output: "", timedOut: false, launched: false)
        }
        let result = BoundedProcessRunner.run(path, ["status"],
                                              timeout: timeout,
                                              maxOutputBytes: 64 * 1024)
        return CommandResult(status: result.status,
                             output: String(decoding: result.output, as: UTF8.self),
                             timedOut: result.timedOut,
                             launched: true)
    }

    /// Connects to the declared listener and completes a no-auth SOCKS5
    /// greeting. A refused connect is a closed port; a connect that is accepted
    /// but cannot answer the greeting means the tunnel behind it is not carrying
    /// traffic. Both are bounded by `timeout`.
    static func systemTransport(endpoint: MullvadSOCKS5Endpoint,
                                timeout: TimeInterval) -> SOCKS5Handshake {
        guard let descriptor = connectTCP(host: endpoint.host,
                                          port: endpoint.port,
                                          timeout: timeout) else {
            return .portClosed
        }
        defer { close(descriptor) }

        let deadline = Date().addingTimeInterval(max(0.05, timeout))
        applySocketTimeout(descriptor, deadline: deadline)

        let greeting: [UInt8] = [0x05, 0x01, 0x00]
        let sent = greeting.withUnsafeBytes { buffer in
            send(descriptor, buffer.baseAddress, buffer.count, 0)
        }
        guard sent == greeting.count else { return .handshakeFailed }

        var reply = [UInt8](repeating: 0, count: 2)
        let received = reply.withUnsafeMutableBytes { buffer in
            recv(descriptor, buffer.baseAddress, buffer.count, 0)
        }
        guard received == 2, reply[0] == 0x05, reply[1] == 0x00 else {
            return .handshakeFailed
        }
        return .reachable
    }

    private static func connectTCP(host: String, port: UInt16,
                                   timeout: TimeInterval) -> Int32? {
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        hints.ai_protocol = IPPROTO_TCP
        var list: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, String(port), &hints, &list) == 0, let first = list else {
            return nil
        }
        defer { freeaddrinfo(first) }

        let deadline = Date().addingTimeInterval(max(0, timeout))
        var current: UnsafeMutablePointer<addrinfo>? = first
        while let candidate = current?.pointee {
            current = candidate.ai_next
            let descriptor = socket(candidate.ai_family, candidate.ai_socktype, candidate.ai_protocol)
            guard descriptor >= 0 else { continue }

            let flags = fcntl(descriptor, F_GETFL, 0)
            _ = fcntl(descriptor, F_SETFL, flags | O_NONBLOCK)
            if connect(descriptor, candidate.ai_addr, candidate.ai_addrlen) != 0 {
                guard errno == EINPROGRESS else {
                    close(descriptor)
                    continue
                }
                let remaining = Int32(max(0, deadline.timeIntervalSinceNow) * 1000)
                var wait = pollfd(fd: descriptor, events: Int16(POLLOUT), revents: 0)
                guard poll(&wait, 1, remaining) > 0 else {
                    close(descriptor)
                    continue
                }
                var error: Int32 = 0
                var length = socklen_t(MemoryLayout<Int32>.size)
                guard getsockopt(descriptor, SOL_SOCKET, SO_ERROR, &error, &length) == 0,
                      error == 0 else {
                    close(descriptor)
                    continue
                }
            }
            _ = fcntl(descriptor, F_SETFL, flags)
            return descriptor
        }
        return nil
    }

    private static func applySocketTimeout(_ descriptor: Int32, deadline: Date) {
        let remaining = max(0.05, deadline.timeIntervalSinceNow)
        var interval = timeval(tv_sec: Int(remaining),
                               tv_usec: Int32((remaining - Double(Int(remaining))) * 1_000_000))
        let size = socklen_t(MemoryLayout<timeval>.size)
        _ = setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &interval, size)
        _ = setsockopt(descriptor, SOL_SOCKET, SO_SNDTIMEO, &interval, size)
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The closed-lid flag through the signed helper.
///
/// This exists so the app can stop asking for a standing passwordless-root
/// grant. `pmset disablesleep` is the only supported way to keep a laptop awake
/// with the lid shut and it needs root, so the choice is a sudoers rule that
/// every process of that uid may use, or a root service that already exists,
/// is signed, and authenticates its caller by code signature.
///
/// The result is deliberately tri-state. `nil` means the helper could not be
/// reached — not installed yet, not approved in Login Items, or wedged — and it
/// is the caller's signal to fall back to the sudo rule. An unsigned
/// development build therefore keeps working, and a user who already granted
/// the rule is not broken by this change.
enum SleepDisableControl {
    /// The helper answers in milliseconds when it is running. The wait exists
    /// because a wedged helper must not hang a preference toggle forever.
    static let timeout: DispatchTimeInterval = .seconds(5)

    static func apply(_ on: Bool) -> Bool? {
        let connection = NSXPCConnection(machServiceName: FanControlIdentifiers.helperID,
                                         options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: FanControlXPCProtocol.self)
        connection.setCodeSigningRequirement(FanControlIdentifiers.helperCodeRequirement)
        connection.resume()
        defer { connection.invalidate() }

        let reply = Reply()
        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in
            reply.finish(nil)
        }) as? FanControlXPCProtocol else { return nil }

        proxy.setDisablesleep(on) { data in
            // A reply that will not decode is not a success. The helper is the
            // only writer of this shape, so unreadable means something else
            // answered or the build is mismatched; either way, fall back.
            reply.finish(FanControlIPC.decode(data)?.succeeded)
        }

        guard reply.wait(timeout: timeout) else { return nil }
        return reply.value
    }

    /// One answer, whichever of the two callbacks arrives first. A late second
    /// callback from the same connection must not overwrite the first.
    private final class Reply {
        private let lock = NSLock()
        private let signal = DispatchSemaphore(value: 0)
        private var stored: Bool?
        private var answered = false

        var value: Bool? {
            lock.lock()
            defer { lock.unlock() }
            return stored
        }

        func finish(_ result: Bool?) {
            lock.lock()
            guard !answered else {
                lock.unlock()
                return
            }
            answered = true
            stored = result
            lock.unlock()
            signal.signal()
        }

        func wait(timeout: DispatchTimeInterval) -> Bool {
            signal.wait(timeout: .now() + timeout) == .success
        }
    }
}

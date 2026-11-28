// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Guards the closed-lid flag's route: the signed helper first, the sudoers
/// rule second.
///
/// The privileged half cannot run under test — it needs root and a registered
/// launchd service — so what is asserted here is the shape that makes it safe.
/// The helper must run one absolute binary with constant arguments, must expose
/// no operation that takes a command, and the app must consult it before
/// touching sudo.
enum PrivilegedSleepTests {
    static func run(_ suite: TestSuite) {
        suite.run("sleep-disable-arguments") {
            suite.expect(SudoersSupport.pmsetArguments(disablesleep: true) == ["disablesleep", "1"],
                         "the on-flag is two constant arguments")
            suite.expect(SudoersSupport.pmsetArguments(disablesleep: false) == ["disablesleep", "0"],
                         "the off-flag is two constant arguments")
            suite.expect(SudoersSupport.pmsetArguments(disablesleep: true).count == 2,
                         "the helper never receives a variable-length argument list")
        }

        suite.run("sleep-disable-wiring") {
            guard let protocolSource = sourceText("Sources/Vorssaint/Services/FanControl/FanControlXPC.swift") else {
                suite.expect(false, "the helper protocol is readable")
                return
            }
            suite.expect(protocolSource.contains("func setDisablesleep(_ enabled: Bool, withReply reply: @escaping (Data) -> Void)"),
                         "the protocol carries the one-bit operation")
            suite.expect(protocolSource.contains("func restoreAutomatic(withReply reply: @escaping (Data) -> Void)"),
                         "the existing surface is unchanged")

            guard let helper = sourceText("Sources/FanControlHelper/main.swift") else {
                suite.expect(false, "the helper source is readable")
                return
            }
            suite.expect(helper.contains("SudoersSupport.pmsetArguments(disablesleep: on)"),
                         "the helper builds its arguments from the constant helper")
            suite.expect(helper.contains("process.executableURL = URL(fileURLWithPath: executable)"),
                         "the helper resolves its binary by absolute path, not through PATH")
            let spawns = occurrences(of: "Process()", in: helper)
            suite.expect(spawns == 1, "exactly one process spawn exists in the helper, found \(spawns)")
            for banned in ["/bin/sh", "/bin/zsh", "/usr/bin/env"] {
                suite.expect(!helper.contains(banned), "the helper never invokes \(banned)")
            }
            // A method taking caller-supplied text would undo the reason the
            // sender check exists, so the protocol must not grow one.
            suite.expect(!protocolSource.contains("(String, withReply") && !protocolSource.contains("(String,"),
                         "no operation accepts caller-supplied text")

            guard let app = sourceText("Sources/Vorssaint/Services/ShellSupport.swift") else {
                suite.expect(false, "the app's shell support is readable")
                return
            }
            guard let helperCall = app.range(of: "SleepDisableControl.apply(on)"),
                  let sudoFallback = app.range(of: "\"/usr/bin/sudo\"") else {
                suite.expect(false, "both the helper call and the sudo fallback are present")
                return
            }
            suite.expect(helperCall.lowerBound < sudoFallback.lowerBound,
                         "the helper is consulted before sudo")
            suite.expect(app.contains("SleepDisableControl.apply(false)"),
                         "the prompting path also tries the helper before asking for a password")

            guard let client = sourceText("Sources/Vorssaint/Services/FanControl/SleepDisableControl.swift") else {
                suite.expect(false, "the client is readable")
                return
            }
            suite.expect(client.contains("setCodeSigningRequirement(FanControlIdentifiers.helperCodeRequirement)"),
                         "the client refuses a helper that is not our signature")
            suite.expect(client.contains("options: .privileged"),
                         "the connection targets the privileged mach service")
            suite.expect(client.contains("guard reply.wait(timeout: timeout) else { return nil }"),
                         "an unanswered call degrades to the fallback instead of hanging")
        }

        suite.run("sleep-disable-registration") {
            guard let service = sourceText("Sources/Vorssaint/Services/FanControl/FanControlService.swift"),
                  let register = service.range(of: "static func ensureHelperForSleepControl()") else {
                suite.expect(false, "the registration entry point exists")
                return
            }
            let tail = String(service[register.upperBound...])
            let bodyEnd = tail.range(of: "\n    }")?.lowerBound ?? tail.endIndex
            let body = String(tail[..<bodyEnd])
            suite.expect(body.contains("guard service.accessState == .notRegistered"),
                         "it registers only from the unregistered state, so it never rewrites a decision")
            suite.expect(body.contains("try appService.register()"),
                         "it registers the daemon through SMAppService")
            suite.expect(!body.contains("openSystemSettingsLoginItems"),
                         "it never opens System Settings on its own, so a toggle stays silent")

            guard let keepAwake = sourceText("Sources/Vorssaint/Services/KeepAwakeManager.swift"),
                  let registration = keepAwake.range(of: "FanControlService.ensureHelperForSleepControl()"),
                  let enable = keepAwake.range(of: "Sudoers.pmsetDisableSleep(true)") else {
                suite.expect(false, "the closed-lid enable path calls it and still writes the flag")
                return
            }
            suite.expect(registration.lowerBound < enable.lowerBound,
                         "the helper is registered before the flag is written")
            suite.expect(occurrences(of: "ensureHelperForSleepControl()", in: keepAwake) == 1,
                         "the enable path registers exactly once")

            guard let delegate = sourceText("Sources/Vorssaint/App/AppDelegate.swift") else {
                suite.expect(false, "the launch path is readable")
                return
            }
            suite.expect(delegate.contains("UserDefaults.standard.bool(forKey: DefaultsKey.sleepDisabledFlag)"),
                         "the launch path only registers while an override is on record")
            suite.expect(delegate.contains("FanControlService.ensureHelperForSleepControl()"),
                         "the launch path re-registers for the restore")
        }
    }

    private static func occurrences(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    private static func sourceText(_ relative: String) -> String? {
        guard let root = repoRoot() else { return nil }
        return try? String(contentsOfFile: URL(fileURLWithPath: root)
            .appendingPathComponent(relative).path, encoding: .utf8)
    }

    private static func repoRoot() -> String? {
        let fileDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for candidate in [fileDir.deletingLastPathComponent().path, FileManager.default.currentDirectoryPath] {
            let marker = URL(fileURLWithPath: candidate).appendingPathComponent("Sources/Vorssaint").path
            if FileManager.default.fileExists(atPath: marker) { return candidate }
        }
        return nil
    }
}

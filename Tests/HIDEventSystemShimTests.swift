// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Guards the private-interface shim without a Mac.
///
/// The shim itself imports IOKit and cannot be compiled here, so what runs is
/// the part that can rot silently: the list of symbol names, and the rule that
/// every call goes through the shim. A future edit that pastes a direct
/// `IOHIDEventSystemClientCreateSimpleClient(` call back into a service still
/// compiles on macOS, still passes every other suite, and reintroduces exactly
/// the launch failure the shim exists to prevent. That is the regression this
/// catches, and reading the tree is the only way to catch it on this node.
enum HIDEventSystemShimTests {
    static func run(_ suite: TestSuite) {
        suite.run("hid-event-system-shim") {
            let symbols = HIDEventSystemSymbols.all
            suite.expect(symbols.count == 6, "six private symbols, got \(symbols.count)")
            suite.expect(Set(symbols).count == symbols.count, "no symbol is listed twice")
            suite.expect(symbols.allSatisfy { $0.hasPrefix("IOHID") },
                         "every name is an IOKit HID symbol")
            suite.expect(symbols.allSatisfy { !$0.isEmpty },
                         "no symbol name is blank")

            guard let shimPath = sourceText("Sources/Vorssaint/Services/HID/HIDEventSystemShim.swift") else {
                suite.expect(false, "the shim source is not readable")
                return
            }
            // One name list, not two: the shim must take every name from the
            // shared table, or a rename fixes one side and breaks the other.
            for name in ["createSimpleClient", "copyServices", "registryID",
                         "conformsTo", "copyProperty", "setProperty"] {
                suite.expect(shimPath.contains("HIDEventSystemSymbols.\(name)"),
                             "the shim resolves \(name) from the shared table")
            }
            // A literal here would be a second copy of the names, which is how
            // the two lists drift apart.
            suite.expect(!shimPath.contains("\"IOHID"),
                         "the shim holds no symbol name of its own")
            suite.expect(shimPath.contains("dlsym"),
                         "the shim resolves symbols at runtime rather than linking them")
            suite.expect(shimPath.contains("isAvailable"),
                         "the shim reports whether the interface survived")

            // Every call site, and nothing else in the app, may name these.
            let callSites = [
                "Sources/Vorssaint/Services/MouseAcceleration/MouseAccelerationService.swift",
                "Sources/Vorssaint/Services/MouseAcceleration/MouseAccelerationRecovery.swift",
                "Sources/Vorssaint/Services/SuperKey/SuperKeyService.swift",
            ]
            for relative in callSites {
                guard let source = sourceText(relative) else {
                    suite.expect(false, "call site not found at \(relative)")
                    continue
                }
                suite.expect(source.contains("HIDEventSystemShim.shared"),
                             "\(relative) reaches the interface through the shim")
            }

            guard let tree = swiftSources() else {
                suite.expect(false, "the sources tree is not readable")
                return
            }
            let tableFile = "Sources/Vorssaint/Services/HID/HIDEventSystemSymbols.swift"
            var offenders: [String] = []
            for relative in tree where relative != tableFile {
                guard let source = sourceText(relative) else { continue }
                if symbols.contains(where: { source.contains($0) }) {
                    offenders.append(relative)
                }
            }
            suite.expect(offenders.isEmpty,
                         "no file names a private HID symbol outside the table: "
                             + offenders.sorted().joined(separator: ", "))

            // Withdrawing is the promise made to the user: the mode goes away
            // and everything else keeps working.
            guard let service = sourceText(callSites[0]) else {
                suite.expect(false, "the mouse acceleration service is not readable")
                return
            }
            suite.expect(service.contains("isRuntimeAvailable"),
                         "the mode consults the shim before it engages")
            suite.expect(service.contains("HIDEventSystemShim.shared.isAvailable"),
                         "runtime availability is the shim's own answer, not a copy")
        }
    }

    /// Every Swift file under the app's own sources, relative to the repo root.
    private static func swiftSources() -> [String]? {
        guard let root = repoRoot() else { return nil }
        let base = URL(fileURLWithPath: root).appendingPathComponent("Sources/Vorssaint")
        guard let walker = FileManager.default.enumerator(at: base,
                                                         includingPropertiesForKeys: nil) else {
            return nil
        }
        var found: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            let path = url.path
            guard let range = path.range(of: "Sources/Vorssaint/") else { continue }
            found.append("Sources/Vorssaint/" + path[range.upperBound...])
        }
        return found
    }

    private static func repoRoot() -> String? {
        let fileDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for candidate in [fileDir.deletingLastPathComponent().path, FileManager.default.currentDirectoryPath] {
            let marker = URL(fileURLWithPath: candidate).appendingPathComponent("Sources/Vorssaint").path
            if FileManager.default.fileExists(atPath: marker) { return candidate }
        }
        return nil
    }

    private static func sourceText(_ relative: String) -> String? {
        guard let root = repoRoot() else { return nil }
        return try? String(contentsOfFile: URL(fileURLWithPath: root)
            .appendingPathComponent(relative).path, encoding: .utf8)
    }
}

#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint
#
# A narrow, deliberately incomplete harness for suites that touch no Apple
# framework, so their logic can be exercised on a Linux node instead of costing
# a macOS test run. It is NOT the release gate: only `build.sh test` on macOS
# compiles every suite and is authoritative. What this covers is exactly the
# files listed in SOURCES and SUITES below, nothing more.
#
# Why it exists: the mesh and SMB suites are Foundation-only, and their four
# failures were previously discoverable only on the Mac. Adding a suite here is
# a deliberate act; a suite whose production files import AppKit, Security or
# anything else Darwin-only cannot be added.
#
# Usage: Tests/LinuxSubsetCheck.sh [repo-root]
# Exit: 0 all assertions passed, 1 a suite failed, 2 the subset could not build.

set -u

REPO="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OUT="${TMPDIR:-/tmp}/vorssaint-linux-subset"
mkdir -p "$OUT"

SUITES=(Tests/ComputeMeshTests.swift Tests/SMBSharesTests.swift)
SOURCES=(
    Sources/Vorssaint/Services/Mesh/ComputeMeshSupport.swift
    Sources/Vorssaint/Services/Mesh/ComputeMeshService.swift
    Sources/Vorssaint/Services/SMB/SMBShares.swift
    Sources/Vorssaint/Services/SMB/SMBSharesService.swift
)

cd "$REPO" || exit 2

# The secret store's protocol and in-memory half are extracted mechanically from
# the real file so they cannot drift; the Keychain half needs Security and is
# not under test here, because every suite injects the in-memory store.
SECRETS=Sources/Vorssaint/Services/AgentUsage/AgentSecretStore.swift
{
    awk '/^struct KeychainAgentSecretStore/{exit} {print}' "$SECRETS" \
        | grep -v '^import Security'
    awk '/^final class InMemoryAgentSecretStore/{found=1} found' "$SECRETS"
} > "$OUT/SecretStoreSubset.swift"

cat > "$OUT/TestSuiteSubset.swift" <<'SWIFT'
import Foundation

/// The same assertion surface as Tests/TestSuite.swift, without the harness
/// suite that needs the localization and format helpers from other files.
final class TestSuite {
    private let lock = NSLock()
    private(set) var checks = 0
    private(set) var failures: [String] = []

    func expect(_ condition: Bool, _ message: @autoclosure () -> String,
                file: StaticString = #filePath, line: UInt = #line) {
        let failure = condition ? nil : "\(file):\(line): \(message())"
        lock.lock()
        checks += 1
        if let failure { failures.append(failure) }
        lock.unlock()
    }

    func run(_ name: String, _ body: () -> Void) {
        let before = checks
        let previousFailures = failures.count
        let started = ProcessInfo.processInfo.systemUptime
        body()
        if checks == before { expect(false, "\(name) executed no assertions") }
        let elapsed = ProcessInfo.processInfo.systemUptime - started
        let status = failures.count == previousFailures ? "OK" : "FAILED"
        print("\(name): \(status) (\(checks - before) checks, \(String(format: "%.2f", elapsed))s)")
    }

    func finish() -> Never {
        if failures.isEmpty {
            print("SUBSET OK (\(checks) checks) — not the release gate")
            exit(0)
        }
        print("SUBSET FAILED (\(failures.count) of \(checks)):")
        failures.forEach { print("  - \($0)") }
        exit(1)
    }
}
SWIFT

cat > "$OUT/main.swift" <<'SWIFT'
import Foundation

let suite = TestSuite()
ComputeMeshTests.run(suite)
SMBSharesTests.run(suite)
suite.finish()
SWIFT

if command -v swiftc >/dev/null 2>&1; then
    SWIFTC=(swiftc)
else
    SWIFTC=(nix shell nixpkgs#swift --command swiftc)
fi

"${SWIFTC[@]}" -O \
    "$OUT/TestSuiteSubset.swift" "$OUT/main.swift" "$OUT/SecretStoreSubset.swift" \
    "${SUITES[@]}" "${SOURCES[@]}" -o "$OUT/run" || exit 2

"$OUT/run"

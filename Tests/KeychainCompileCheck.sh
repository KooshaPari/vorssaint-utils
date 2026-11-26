#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint
#
# Type-check the two keychain writers on a Linux node.
#
# `LinuxSubsetCheck.sh` deliberately leaves these files out: they import
# Security, which does not exist off Darwin, so a suite that touched them could
# never build there. The cost is that an edit to them is invisible until the
# macOS gate runs, and the gate host is a laptop that can be away for a day. This
# script closes that gap narrowly: it declares the dozen Security symbols these
# two files use, compiles them with `swiftc -typecheck` against that shim, and
# says nothing about behaviour. It proves the files parse, that every symbol
# resolves, that the protocol conformances still line up and that the keychain
# calls take the argument types they are given. It does NOT prove an item is
# written with the class that was asked for.
#
# It is a pre-flight, never a gate. `build.sh test` on macOS stays authoritative.
#
# Usage: Tests/KeychainCompileCheck.sh [repo-root]
# Exit: 0 type-checked clean, 2 the shim or the compile failed.

set -u

REPO="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OUT="${TMPDIR:-/tmp}/vorssaint-keychain-check"
mkdir -p "$OUT"
cd "$REPO" || exit 2

FILES=(
    Sources/Vorssaint/Services/AgentUsage/AgentSecretStore.swift
    Sources/Vorssaint/Services/SMB/SMBSharesLive.swift
)
# The two production files these depend on. Both are Foundation-only and already
# compile in the Linux subset, so they are listed here to give the writers their
# real `SMBShare` and `SMBKeychainProjection` rather than a second copy.
SUPPORT=(
    Sources/Vorssaint/Services/SMB/SMBShares.swift
    Sources/Vorssaint/Services/SMB/SMBSharesService.swift
)

for file in "${FILES[@]}" "${SUPPORT[@]}"; do
    if [ ! -f "$file" ]; then
        echo "missing source: $file" >&2
        exit 2
    fi
done

# The shim. Every constant is a distinct value so a shim compile cannot pass by
# aliasing two symbols the real framework keeps apart; the status codes keep
# their real integer values. Only what these files actually name is declared, so
# a new keychain call shows up here as a compile error rather than silently
# relying on a symbol nobody declared.
cat > "$OUT/SecurityShim.swift" <<'SWIFT'
// A stand-in for the parts of Security.framework these two files use. Type
// checking only: nothing here stores, reads or re-classifies a real item.
import Foundation

public typealias OSStatus = Int32
public typealias CFTypeRef = Any
public typealias CFDictionary = NSDictionary
public typealias CFString = String

public let errSecSuccess: OSStatus = 0
public let errSecItemNotFound: OSStatus = -25300

public let kSecClass = "class"
public let kSecClassGenericPassword = "genp"
public let kSecClassInternetPassword = "inet"
public let kSecAttrService = "svce"
public let kSecAttrAccount = "acct"
public let kSecAttrServer = "srvr"
public let kSecAttrPath = "path"
public let kSecAttrProtocol = "ptcl"
public let kSecAttrProtocolSMB = "smb "
public let kSecValueData = "v_Data"
public let kSecAttrAccessible = "v_Acc"
public let kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly = "akpu"
public let kSecAttrSynchronizable = "sync"
public let kSecReturnData = "r_Data"
public let kSecMatchLimit = "m_Limit"
public let kSecMatchLimitOne = "m_LimitOne"

// `Shell` lives in ShellSupport.swift, which imports AppKit, CoreServices and
// Darwin and so cannot be compiled here. Only its signature is needed: the SMB
// writer hands `Shell.run` to its environment as a closure, so the closure's
// shape is what this compile checks.
public enum Shell {
    public static func run(_ path: String,
                           _ args: [String],
                           timeout: TimeInterval = 5,
                           maxOutputBytes: Int = 4 * 1024 * 1024)
        -> (status: Int32, output: String) { (0, "") }
}

public func SecItemAdd(_ attributes: CFDictionary,
                       _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus { errSecSuccess }
public func SecItemUpdate(_ query: CFDictionary,
                          _ attributesToUpdate: CFDictionary) -> OSStatus { errSecSuccess }
public func SecItemCopyMatching(_ query: CFDictionary,
                                _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus { errSecItemNotFound }
public func SecItemDelete(_ query: CFDictionary) -> OSStatus { errSecSuccess }
SWIFT

# `import Security` cannot resolve off Darwin. The copies compiled here have that
# one line removed; every other byte is the file that ships. Anything else the
# shim does not declare therefore still fails.
COPIES=()
for file in "${FILES[@]}" "${SUPPORT[@]}"; do
    copy="$OUT/$(echo "$file" | tr '/' '_')"
    grep -v '^import Security$' "$file" > "$copy"
    COPIES+=("$copy")
done

if command -v swiftc >/dev/null 2>&1; then
    SWIFTC=(swiftc)
else
    SWIFTC=(nix shell nixpkgs#swift --command swiftc)
fi

# -typecheck stops before code generation, so no Darwin-only linkage is needed.
if "${SWIFTC[@]}" -typecheck "$OUT/SecurityShim.swift" "${COPIES[@]}" 2>"$OUT/diagnostics.txt"; then
    echo "KEYCHAIN TYPECHECK OK (${#FILES[@]} writers, shimmed Security) — not the release gate"
    exit 0
fi

echo "KEYCHAIN TYPECHECK FAILED:"
cat "$OUT/diagnostics.txt"
exit 2

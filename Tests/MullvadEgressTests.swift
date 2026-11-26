// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Checks for ledger row E2: per-provider egress, pinned to Mullvad or declared
/// direct, with refusal instead of fallback. Every fixture is obviously fake:
/// TEST-NET-1 (192.0.2.0/24) for addresses and invented CLI text for output.
enum MullvadEgressTests {
    private static let endpoint = MullvadSOCKS5Endpoint(host: "192.0.2.10", port: 1080)
    private static let provider = "fake-provider"

    private struct FakeProbe: MullvadProbing {
        let reading: MullvadSOCKS5Reading
        func availability(expecting: MullvadSOCKS5Endpoint) -> MullvadSOCKS5Reading {
            reading
        }
    }

    private final class CountingProbe: MullvadProbing, @unchecked Sendable {
        private(set) var calls = 0
        func availability(expecting: MullvadSOCKS5Endpoint) -> MullvadSOCKS5Reading {
            calls += 1
            return .unavailable(.cliMissing)
        }
    }

    private static func pinnedPolicy() -> EgressPolicy {
        (try? EgressPolicy([ProviderEgressRoute(provider: provider,
                                                path: .mullvadSOCKS5(endpoint))]))
            ?? EgressPolicy.empty
    }

    private static func commandProbe(
        _ command: MullvadProbe.CommandResult,
        transport: MullvadProbe.SOCKS5Handshake = .reachable
    ) -> MullvadProbe {
        MullvadProbe(runCommand: { _ in command },
                     transport: { _, _ in transport })
    }

    private static func probe(for reason: MullvadUnavailableReason) -> MullvadProbe {
        let connected = MullvadProbe.CommandResult(
            status: 0,
            output: "Connected to us-nyc-wg-001 in New York, US\n",
            timedOut: false,
            launched: true)
        switch reason {
        case .cliMissing:
            return commandProbe(MullvadProbe.CommandResult(status: -1, output: "",
                                                           timedOut: false, launched: false))
        case .timedOut:
            return commandProbe(MullvadProbe.CommandResult(status: -1, output: "",
                                                           timedOut: true, launched: true))
        case .daemonStopped:
            return commandProbe(MullvadProbe.CommandResult(
                status: 1,
                output: "Failed to connect to daemon: Connection refused\n",
                timedOut: false,
                launched: true))
        case .daemonNotConnected:
            return commandProbe(MullvadProbe.CommandResult(
                status: 0, output: "Disconnected\n", timedOut: false, launched: true))
        case .malformedOutput:
            return commandProbe(MullvadProbe.CommandResult(
                status: 0, output: "  \n", timedOut: false, launched: true))
        case .socksPortClosed:
            return commandProbe(connected, transport: .portClosed)
        case .relayUnreachable:
            return commandProbe(connected, transport: .handshakeFailed)
        }
    }

    static func run(_ suite: TestSuite) {
        // MARK: Declarations are explicit, never implied

        let directPolicy = try? EgressPolicy([ProviderEgressRoute(provider: provider, path: .direct)])
        suite.expect(directPolicy?.declaredPath(for: provider) == .direct,
                     "a declared direct provider reads back its own declaration")
        suite.expect(directPolicy?.declaredPath(for: "undeclared-provider") == nil,
                     "a provider with no declaration has no route")

        let absent = directPolicy?.resolve(provider: "undeclared-provider",
                                           probe: FakeProbe(reading: .available(endpoint)))
        if let absent {
            switch absent {
            case .failure(.providerNotDeclared("undeclared-provider")):
                suite.expect(true, "an undeclared provider is refused by name")
            default:
                suite.expect(false, "an undeclared provider resolves to a route")
            }
        } else {
            suite.expect(false, "the direct policy resolves undeclared lookups")
        }

        var duplicate: EgressError?
        do {
            _ = try EgressPolicy([ProviderEgressRoute(provider: provider, path: .direct),
                                  ProviderEgressRoute(provider: provider, path: .direct)])
        } catch let error as EgressError {
            duplicate = error
        } catch {
            duplicate = nil
        }
        suite.expect(duplicate == .duplicateDeclaration(provider),
                     "a provider declared twice is rejected, not last-one-wins")

        var emptyName: EgressError?
        do {
            _ = try EgressPolicy([ProviderEgressRoute(provider: "  ", path: .direct)])
        } catch let error as EgressError {
            emptyName = error
        } catch {
            emptyName = nil
        }
        suite.expect(emptyName == .invalidDeclaration("  "),
                     "a blank provider name is an invalid declaration")

        var zeroPort: EgressError?
        do {
            _ = try EgressPolicy([ProviderEgressRoute(
                provider: provider,
                path: .mullvadSOCKS5(MullvadSOCKS5Endpoint(host: "192.0.2.10", port: 0)))])
        } catch let error as EgressError {
            zeroPort = error
        } catch {
            zeroPort = nil
        }
        suite.expect(zeroPort == .invalidDeclaration(provider),
                     "a pinned route with no usable port is rejected at declaration time")

        // MARK: Pinned egress only resolves when the listener is verified

        let available = try? EgressPolicy([ProviderEgressRoute(
            provider: provider, path: .mullvadSOCKS5(endpoint))])
        let resolved = available?.resolve(provider: provider,
                                          probe: FakeProbe(reading: .available(endpoint)))
        var pinnedBinding: EgressBinding?
        if let resolved {
            switch resolved {
            case .success(let binding):
                pinnedBinding = binding
                suite.expect(binding.provider == provider && binding.path == .mullvadSOCKS5(endpoint),
                             "a verified listener binds the provider to that listener")
            default:
                suite.expect(false, "a verified listener did not resolve")
            }
        } else {
            suite.expect(false, "the pinned policy resolves its own provider")
        }

        let configuration = URLSessionConfiguration.ephemeral
        if let pinnedBinding {
            ProviderEgressSession.configure(configuration, for: pinnedBinding)
            let proxy = configuration.connectionProxyDictionary ?? [:]
            suite.expect(proxy["SOCKSEnable"] as? Int == 1
                             && proxy["SOCKSProxy"] as? String == "192.0.2.10"
                             && proxy["SOCKSPort"] as? Int == 1080,
                         "a pinned session carries only the probed SOCKS5 endpoint")
        } else {
            suite.expect(false, "pinned session check needs a resolved binding")
        }

        let directConfiguration = URLSessionConfiguration.ephemeral
        ProviderEgressSession.configure(
            directConfiguration,
            for: EgressBinding(provider: provider, path: .direct))
        suite.expect(directConfiguration.connectionProxyDictionary == nil,
                     "an explicit direct session installs no proxy")

        // MARK: Every unavailable state refuses and names itself

        let policy = pinnedPolicy()
        var produced = Set<MullvadUnavailableReason>()
        for reason in MullvadUnavailableReason.allCases {
            let result = policy.resolve(provider: provider, probe: probe(for: reason))
            switch result {
            case .failure(.egressUnavailable(let named, let reported)):
                produced.insert(reported)
                suite.expect(named == provider && reported == reason,
                             "\(reason.rawValue) refuses with its own name")
            case .success:
                suite.expect(false, "\(reason.rawValue) resolved to a usable route")
            case .failure:
                suite.expect(false, "\(reason.rawValue) refused with the wrong error")
            }
        }
        suite.expect(produced == Set(MullvadUnavailableReason.allCases),
                     "all \(MullvadUnavailableReason.allCases.count) unavailable states are reachable and distinct")
        suite.expect(Set(MullvadUnavailableReason.allCases.map(\.rawValue)).count
                         == MullvadUnavailableReason.allCases.count,
                     "no two unavailable reasons share a name")

        // A pin that cannot be verified must never be reported as available.
        for reason in MullvadUnavailableReason.allCases {
            suite.expect(probe(for: reason).availability(expecting: endpoint)
                             != .available(endpoint),
                         "\(reason.rawValue) is not availability")
        }

        // MARK: The states do not collapse into one another

        let parsed: [(String, MullvadCLIOutput.Status)] = [
            ("Connected to us-nyc-wg-001 in New York, US\n", .connected),
            ("Connecting to us-nyc-wg-001 in New York, US\n", .connecting),
            ("Disconnected\n", .disconnected),
            ("Blocked: all traffic\n", .blocked),
            ("Failed to connect to daemon: Connection refused\n", .daemonStopped),
            ("Mullvad daemon is not running\n", .daemonStopped),
            ("", .malformed),
            ("   \n", .malformed),
            ("not a status this app knows\n", .malformed),
        ]
        for (output, expected) in parsed {
            suite.expect(MullvadCLIOutput.parse(status: 0, output: output) == expected,
                         "status output \(output.debugDescription) parses as expected")
        }

        let blocked = commandProbe(MullvadProbe.CommandResult(
            status: 0, output: "Blocked: all traffic\n", timedOut: false, launched: true))
        suite.expect(blocked.availability(expecting: endpoint) == .unavailable(.daemonNotConnected),
                     "a blocked daemon reads as not connected, never as success")

        // A closed listener and a dead relay are different observations.
        let closed = commandProbe(MullvadProbe.CommandResult(
            status: 0, output: "Connected\n", timedOut: false, launched: true),
            transport: .portClosed)
        let deadRelay = commandProbe(MullvadProbe.CommandResult(
            status: 0, output: "Connected\n", timedOut: false, launched: true),
            transport: .handshakeFailed)
        suite.expect(closed.availability(expecting: endpoint) == .unavailable(.socksPortClosed),
                     "a refused socket is a closed port")
        suite.expect(deadRelay.availability(expecting: endpoint) == .unavailable(.relayUnreachable),
                     "an accepted socket that cannot greet is a dead relay")
        suite.expect(closed.availability(expecting: endpoint) != deadRelay.availability(expecting: endpoint),
                     "closed port and dead relay stay distinct")

        // MARK: Malformed and empty output never looks like success

        for output in ["", "   \n\t", "something unexpected", "error: no such command"] {
            let malformed = commandProbe(MullvadProbe.CommandResult(
                status: 1, output: output, timedOut: false, launched: true))
            suite.expect(malformed.availability(expecting: endpoint)
                             == .unavailable(.malformedOutput),
                         "malformed CLI output \(output.debugDescription) is a named refusal")
        }

        // MARK: Direct is explicit, and never consults the probe

        let counting = CountingProbe()
        let directResult = directPolicy?.resolve(provider: provider, probe: counting)
        if let directResult {
            switch directResult {
            case .success(let binding):
                suite.expect(binding.path == .direct, "an explicit direct route resolves direct")
            default:
                suite.expect(false, "an explicit direct route did not resolve")
            }
        } else {
            suite.expect(false, "the direct policy resolves its own provider")
        }
        suite.expect(counting.calls == 0,
                     "a direct route never probes Mullvad, so it cannot borrow tunnel state")

        // MARK: Bounded work and no raw output in failures

        final class TimeoutRecorder: @unchecked Sendable {
            var commandTimeouts: [TimeInterval] = []
            var transportTimeouts: [TimeInterval] = []
        }
        let recorder = TimeoutRecorder()
        let bounded = MullvadProbe(
            runCommand: { timeout in
                recorder.commandTimeouts.append(timeout)
                return MullvadProbe.CommandResult(
                    status: 0, output: "Connected\n", timedOut: false, launched: true)
            },
            transport: { _, timeout in
                recorder.transportTimeouts.append(timeout)
                return .reachable
            })
        _ = bounded.availability(expecting: endpoint)
        suite.expect(recorder.commandTimeouts == [MullvadProbe.statusTimeout],
                     "the CLI shell-out receives the bounded status timeout")
        suite.expect(recorder.transportTimeouts == [MullvadProbe.transportTimeout],
                     "the socket probe receives the bounded transport timeout")
        suite.expect(MullvadProbe.statusTimeout > 0 && MullvadProbe.statusTimeout <= 5,
                     "the status timeout is bounded")
        suite.expect(MullvadProbe.transportTimeout > 0 && MullvadProbe.transportTimeout <= 5,
                     "the transport timeout is bounded")

        let secret = "FAKE-PRIVATE-KEY-MATERIAL"
        let leaky = MullvadProbe(
            runCommand: { _ in MullvadProbe.CommandResult(
                status: 0, output: "Connected\n\(secret)\n", timedOut: false, launched: true) },
            transport: { _, _ in .portClosed })
        if case .failure(let error) = policy.resolve(provider: provider, probe: leaky) {
            let text = error.errorDescription ?? ""
            suite.expect(!text.contains(secret),
                         "a failure never echoes CLI output that might hold tunnel material")
            suite.expect(text.contains(MullvadUnavailableReason.socksPortClosed.rawValue),
                         "a failure names the unavailable state")
        } else {
            suite.expect(false, "the leak fixture resolved instead of refusing")
        }

        // MARK: Regression: no direct-fallback branch can be reached

        let policyPath = "Sources/Vorssaint/Services/NetworkEgress/EgressPolicy.swift"
        let policySource = (try? String(contentsOfFile: policyPath, encoding: .utf8)) ?? ""
        suite.expect(!policySource.isEmpty, "the egress policy source reads for the fallback guard")

        let beginMarker = "// egress-guarantee:begin"
        let endMarker = "// egress-guarantee:end"
        if let begin = policySource.range(of: beginMarker),
           let end = policySource.range(of: endMarker),
           begin.upperBound <= end.lowerBound {
            let pinned = String(policySource[begin.upperBound..<end.lowerBound])
            suite.expect(!pinned.contains(".direct"),
                         "the pinned resolution branch contains no direct path")
            suite.expect(pinned.contains("return .failure(.egressUnavailable"),
                         "the pinned resolution branch refuses by name")
            suite.expect(pinned.contains("path: .mullvadSOCKS5(verified)"),
                         "the pinned resolution branch's only success is the verified listener")
            suite.expect(!pinned.contains("fallback") && !pinned.contains("fall back"),
                         "the pinned resolution branch mentions no fallback")
        } else {
            suite.expect(false, "the egress guarantee markers are present and ordered")
        }

        let banned = [
            #"\?\?\s*\.direct"#,
            #"catch[^\n]*\.direct"#,
            #"default\s*:[^\n]*\.direct"#,
            #"\.direct\s*\?\?"#,
        ]
        for pattern in banned {
            suite.expect(policySource.range(of: pattern, options: .regularExpression) == nil,
                         "the policy has no fallback form matching \(pattern)")
        }
        let directBindings = policySource.components(separatedBy: "path: .direct").count - 1
        suite.expect(directBindings == 1,
                     "exactly one direct binding exists, in the explicit direct branch")

        // MARK: The module carries and stores no credential material

        let moduleDirectory = "Sources/Vorssaint/Services/NetworkEgress"
        let moduleFiles = ((try? FileManager.default.contentsOfDirectory(atPath: moduleDirectory)) ?? [])
            .filter { $0.hasSuffix(".swift") }
            .sorted()
        suite.expect(moduleFiles.count >= 3, "the egress module files are discoverable")
        for file in moduleFiles {
            let source = (try? String(contentsOfFile: moduleDirectory + "/" + file,
                                      encoding: .utf8)) ?? ""
            suite.expect(!source.isEmpty, "\(file) reads for the credential guard")
            for bannedWord in ["account", "private key", "wireguard", "wg-private"] {
                suite.expect(source.range(of: bannedWord, options: .caseInsensitive) == nil,
                             "\(file) never mentions \(bannedWord)")
            }
        }

        let probeSource = (try? String(contentsOfFile:
            "Sources/Vorssaint/Services/NetworkEgress/MullvadProbe.swift",
            encoding: .utf8)) ?? ""
        suite.expect(probeSource.contains("BoundedProcessRunner.run("),
                     "the only shell-out goes through the bounded process runner")
        for form in ["Process()", "popen(", "posix_spawn(", "system("] {
            suite.expect(!probeSource.contains(form),
                         "the probe does not spawn through \(form)")
        }

        // MARK: The shipped declaration table is explicit and valid

        suite.expect(ProviderEgressDefaults.policy != nil,
                     "the shipped provider table parses without falling back")
        suite.expect(ProviderEgressDefaults.declarations.contains {
            $0.provider == "agent-prices" && $0.path == .direct
        }, "the price list is explicitly declared direct rather than implied")
        suite.expect(ProviderEgressDefaults.declarations.contains {
            $0.path == .mullvadSOCKS5(endpoint) && $0.provider == provider
        } == false, "the shipped table pins nothing to the fake fixture")
    }
}

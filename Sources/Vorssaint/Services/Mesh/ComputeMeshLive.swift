// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

extension MeshEnvironment {
    /// The app's environment. Tailscale is looked for in the app bundle first
    /// and then in the usual Homebrew and standalone locations; the ssh config
    /// is the person's own; local devices come from the existing connected
    /// devices sampler rather than from a second USB implementation.
    static var live: MeshEnvironment {
        let home = NSHomeDirectory()
        return MeshEnvironment(
            tailscaleExecutables: [
                "/Applications/Tailscale.app/Contents/MacOS/Tailscale",
                "/opt/homebrew/bin/tailscale",
                "/usr/local/bin/tailscale",
            ],
            run: { path, arguments, timeout in
                let result = BoundedProcessRunner.run(path, arguments,
                                                      timeout: timeout,
                                                      maxOutputBytes: 4 * 1024 * 1024)
                return (result.status, result.output)
            },
            fileExists: { FileManager.default.fileExists(atPath: $0) },
            readText: { try? String(contentsOfFile: $0, encoding: .utf8) },
            sshConfigPath: "\(home)/.ssh/config",
            sampleDevices: {
                USBDeviceSampler().sample().map {
                    MeshDevice(id: $0.id, name: $0.name.isEmpty ? $0.id : $0.name)
                }
            }
        )
    }
}

extension ComputeMeshService {
    /// The app's instance. Each `reload()` re-reads all three sources, so a
    /// source that appears later is picked up without a relaunch.
    static var live: ComputeMeshService {
        ComputeMeshService(environment: .live)
    }
}

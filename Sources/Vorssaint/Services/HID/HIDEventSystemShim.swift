// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Darwin
import Foundation
import HIDEventSystem

/// Resolves the six private IOKit functions at launch instead of linking them.
///
/// The opaque types the signatures need, `IOHIDEventSystemClient` and
/// `IOHIDServiceClient`, are still named at compile time: they are typedef'd in
/// public-adjacent SDK headers and a missing type is a build failure we cannot
/// do anything about. A missing *symbol* is the case that matters, because that
/// is how a macOS update breaks an app that linked one directly: the dyld load
/// fails and the process never starts.
///
/// With this shim a vanished symbol leaves `isAvailable` false, every wrapper
/// returns nil, and the features that need it withdraw. Nothing else notices.
final class HIDEventSystemShim {
    static let shared = HIDEventSystemShim()

    private typealias CreateSimpleClientFn = @convention(c) (CFAllocator?) -> IOHIDEventSystemClient
    private typealias CopyServicesFn = @convention(c) (IOHIDEventSystemClient) -> CFArray?
    private typealias RegistryIDFn = @convention(c) (IOHIDServiceClient) -> CFTypeRef
    private typealias ConformsToFn = @convention(c) (IOHIDServiceClient, UInt32, UInt32) -> Int32
    private typealias CopyPropertyFn = @convention(c) (IOHIDServiceClient, CFString) -> CFTypeRef?
    private typealias SetPropertyFn =
        @convention(c) (IOHIDServiceClient, CFString, CFTypeRef) -> Bool

    private let handle: UnsafeMutableRawPointer?
    private let createSimpleClientFn: CreateSimpleClientFn?
    private let copyServicesFn: CopyServicesFn?
    private let registryIDFn: RegistryIDFn?
    private let conformsToFn: ConformsToFn?
    private let copyPropertyFn: CopyPropertyFn?
    private let setPropertyFn: SetPropertyFn?

    /// True only when all six symbols resolved. Callers treat false as "this
    /// Mac's IOKit no longer offers the interface" and withdraw the feature.
    let isAvailable: Bool

    private init() {
        let handle = dlopen(HIDEventSystemSymbols.frameworkPath, RTLD_LAZY)
        self.handle = handle

        func resolve<T>(_ name: String, as type: T.Type) -> T? {
            guard let handle, let symbol = dlsym(handle, name) else { return nil }
            return unsafeBitCast(symbol, to: T.self)
        }

        createSimpleClientFn = resolve(HIDEventSystemSymbols.createSimpleClient,
                                       as: CreateSimpleClientFn.self)
        copyServicesFn = resolve(HIDEventSystemSymbols.copyServices, as: CopyServicesFn.self)
        registryIDFn = resolve(HIDEventSystemSymbols.registryID, as: RegistryIDFn.self)
        conformsToFn = resolve(HIDEventSystemSymbols.conformsTo, as: ConformsToFn.self)
        copyPropertyFn = resolve(HIDEventSystemSymbols.copyProperty, as: CopyPropertyFn.self)
        setPropertyFn = resolve(HIDEventSystemSymbols.setProperty, as: SetPropertyFn.self)
        isAvailable = createSimpleClientFn != nil
            && copyServicesFn != nil
            && registryIDFn != nil
            && conformsToFn != nil
            && copyPropertyFn != nil
            && setPropertyFn != nil
    }

    deinit {
        if let handle { dlclose(handle) }
    }

    // The wrappers below keep the C shapes but return an optional wherever a
    // missing symbol would otherwise be indistinguishable from a real answer.

    func makeClient() -> IOHIDEventSystemClient? {
        createSimpleClientFn?(kCFAllocatorDefault)
    }

    func services(of client: IOHIDEventSystemClient) -> [IOHIDServiceClient]? {
        copyServicesFn?(client) as? [IOHIDServiceClient]
    }

    func registryID(of service: IOHIDServiceClient) -> CFTypeRef? {
        registryIDFn?(service)
    }

    func conformsTo(_ service: IOHIDServiceClient, page: UInt32, usage: UInt32) -> Bool? {
        conformsToFn.map { $0(service, page, usage) != 0 }
    }

    func property(_ service: IOHIDServiceClient, _ key: CFString) -> CFTypeRef? {
        copyPropertyFn?(service, key)
    }

    /// nil means the shim is unavailable, which is not the same as IOKit
    /// refusing the write: that is `false`.
    func setProperty(_ service: IOHIDServiceClient, _ key: CFString, _ value: CFTypeRef) -> Bool? {
        setPropertyFn?(service, key, value)
    }
}

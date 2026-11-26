// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The private IOKit symbols this app needs, named once so the shim that
/// resolves them and the test that guards them cannot drift.
///
/// Six functions and two opaque types are all that is private here. Everything
/// else the pointer and keyboard paths touch, `IOHIDManager` above all, is
/// public API in `<IOKit/hid/IOHIDManager.h>` and is called directly.
///
/// The names are strings rather than a vendored header on purpose: a vendored
/// header is a build-time promise that the symbol exists, and these are exactly
/// the symbols Apple does not promise.
enum HIDEventSystemSymbols {
    /// IOKit is already loaded by any process that touches HID, so this handle
    /// is a lookup table rather than a second copy of the framework.
    static let frameworkPath = "/System/Library/Frameworks/IOKit.framework/IOKit"

    static let createSimpleClient = "IOHIDEventSystemClientCreateSimpleClient"
    static let copyServices = "IOHIDEventSystemClientCopyServices"
    static let registryID = "IOHIDServiceClientGetRegistryID"
    static let conformsTo = "IOHIDServiceClientConformsTo"
    static let copyProperty = "IOHIDServiceClientCopyProperty"
    static let setProperty = "IOHIDServiceClientSetProperty"

    /// Every symbol the shim must resolve before it reports itself usable. One
    /// missing name is enough to withdraw the feature instead of calling
    /// through a null pointer.
    static let all = [
        createSimpleClient,
        copyServices,
        registryID,
        conformsTo,
        copyProperty,
        setProperty,
    ]
}

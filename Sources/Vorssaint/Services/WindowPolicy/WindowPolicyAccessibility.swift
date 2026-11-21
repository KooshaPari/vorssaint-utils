// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ApplicationServices

/// One window the policy may act on: the Accessibility element, what the policy
/// knows about it, and where it currently sits.
struct WindowPolicyTarget {
    let element: AXUIElement
    let info: WindowPolicyWindow
    let frame: CGRect
}

/// The thin Accessibility layer under the window policy. It reads windows,
/// hands their descriptions to the pure filter and policy, and writes frames
/// back. Everything that can be decided without a window server lives in
/// `WindowPolicySupport` and is tested there.
enum WindowPolicyAccessibility {
    /// Ordinary windows of one application, in the order Accessibility returns
    /// them, which is front to back.
    static func targets(of pid: pid_t) -> [WindowPolicyTarget] {
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.5)
        guard let windows = array(kAXWindowsAttribute, from: application) else {
            return []
        }
        return windows.compactMap { element in
            guard let frame = frame(of: element) else { return nil }
            let subrole: String? = attribute(kAXSubroleAttribute, from: element)
            let info = WindowPolicyWindow(
                id: Int(CFHash(element)),
                isStandard: subrole == kAXStandardWindowSubrole as String,
                // AX has no "resizable" flag: a window is movable or resizable
                // exactly when the attribute can be written.
                isMovable: isSettable(kAXPositionAttribute, on: element),
                isResizable: isSettable(kAXSizeAttribute, on: element),
                // A window with a sheet attached must not be moved. The SDK
                // exposes no constant for this attribute; the name is stable.
                hasSheet: array("AXSheets", from: element)?.isEmpty == false,
                isMinimized: bool(kAXMinimizedAttribute, from: element) ?? false,
                layer: 0
            )
            return WindowPolicyTarget(element: element, info: info, frame: frame)
        }
    }

    /// The targets of `pid` that the policy may move, in front to back order.
    static func eligibleTargets(of pid: pid_t) -> [WindowPolicyTarget] {
        let all = targets(of: pid)
        let eligibleIDs = Set(WindowPolicyEligibility.eligible(all.map(\.info)).map(\.id))
        return all.filter { eligibleIDs.contains($0.info.id) }
    }

    /// Applies a plan to the frontmost application's windows. Returns how many
    /// frames actually landed. A window that refuses its position is skipped
    /// rather than left half moved: the size is only set after the position.
    @discardableResult
    static func tileFrontmostApp(layout: WindowTileLayout,
                                 limit: Int = 0,
                                 gap: CGFloat = 0) -> Int {
        guard AXIsProcessTrusted(),
              let app = NSWorkspace.shared.frontmostApplication else { return 0 }
        let screen = NSScreen.main?.visibleFrame ?? .zero
        guard screen.width > 0, screen.height > 0 else { return 0 }
        let targets = eligibleTargets(of: app.processIdentifier)
        let plan = WindowPolicy.plan(windowCount: targets.count,
                                     layout: layout,
                                     visibleFrame: screen,
                                     limit: limit,
                                     gap: gap)
        var applied = 0
        for (target, frame) in zip(targets, plan.frames) {
            if setFrame(frame, on: target.element) { applied += 1 }
        }
        return applied
    }

    static func setFrame(_ frame: CGRect, on element: AXUIElement) -> Bool {
        var origin = CGPoint(x: frame.minX, y: frame.minY)
        var size = CGSize(width: frame.width, height: frame.height)
        guard let position = AXValueCreate(.cgPoint, &origin),
              let dimensions = AXValueCreate(.cgSize, &size) else { return false }
        guard AXUIElementSetAttributeValue(element,
                                           kAXPositionAttribute as CFString,
                                           position) == .success else { return false }
        return AXUIElementSetAttributeValue(element,
                                            kAXSizeAttribute as CFString,
                                            dimensions) == .success
    }

    static func frame(of element: AXUIElement) -> CGRect? {
        guard let origin = pointAttribute(element, kAXPositionAttribute as String),
              let size = sizeAttribute(element, kAXSizeAttribute as String) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    private static func pointAttribute(_ element: AXUIElement, _ name: String) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let attributeValue = value, CFGetTypeID(attributeValue) == AXValueGetTypeID() else {
            return nil
        }
        var point = CGPoint.zero
        guard AXValueGetValue(attributeValue as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    private static func sizeAttribute(_ element: AXUIElement, _ name: String) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let attributeValue = value, CFGetTypeID(attributeValue) == AXValueGetTypeID() else {
            return nil
        }
        var size = CGSize.zero
        guard AXValueGetValue(attributeValue as! AXValue, .cgSize, &size) else { return nil }
        return size
    }

    private static func bool(_ name: String, from element: AXUIElement) -> Bool? {
        attribute(name, from: element) as Bool?
    }

    private static func isSettable(_ name: String, on element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(element, name as CFString, &settable) == .success else {
            return false
        }
        return settable.boolValue
    }

    private static func array(_ name: String, from element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let value, CFGetTypeID(value) == CFArrayGetTypeID() else { return nil }
        let list = unsafeBitCast(value, to: CFArray.self)
        return list as? [AXUIElement]
    }

    private static func attribute<T>(_ name: String, from element: AXUIElement) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value as? T
    }
}

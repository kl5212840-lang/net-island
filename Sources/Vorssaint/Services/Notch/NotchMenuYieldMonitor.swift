// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors

import AppKit
import ApplicationServices

/// Passive observation only: never opens, closes, moves, or consumes a system
/// menu. AX measurements run off-main; only geometry and menu state are inspected.
final class NotchMenuYieldMonitor {
    struct Layout {
        var screen: CGRect
        var barHeight: CGFloat
        var island: CGRect
        var ownWindows: Set<CGWindowID>
        var primaryTop: CGFloat
        var bar: CGRect { CGRect(x: screen.minX, y: screen.maxY - barHeight, width: screen.width, height: barHeight) }
    }
    private struct Snapshot {
        var overflow: CGRect?
        var expanded = false
        var menuOpen = false
        var applicationMenuEnd: CGFloat?
    }
    private var layout: Layout?
    private var snapshot = Snapshot()
    private var state = NotchMenuYieldState()
    private var timer: Timer?
    private var monitors: [Any] = []
    private var accessibilityObservers: [pid_t: AXObserver] = [:]
    private var pending = false
    private var generation = 0
    private var lastRead: TimeInterval = -.infinity
    private let queue = DispatchQueue(label: "net-island.menu-yield", qos: .utility)
    var didChange: ((Bool) -> Void)?

    func configure(_ layout: Layout?) {
        self.layout = layout
        guard layout != nil else { stop(); return }
        guard timer == nil else { return }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .keyDown]
        if let token = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] in self?.event($0) }) { monitors.append(token) }
        if let token = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.event(event)
            return event
        }) { monitors.append(token) }
        let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in self?.read() }
        timer.tolerance = 0.03
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        read(force: true)
    }

    func stop() {
        timer?.invalidate(); timer = nil
        monitors.forEach(NSEvent.removeMonitor); monitors.removeAll()
        for observer in accessibilityObservers.values { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes) }
        accessibilityObservers.removeAll()
        generation += 1; pending = false; snapshot = Snapshot()
        if state.hidden { state = .init(); didChange?(false) }
    }

    private func event(_ event: NSEvent) {
        guard let layout else { return }
        if event.type == .keyDown {
            // Do not inspect printable keys or interfere with the target app.
            if event.keyCode == 53, state.hidden { state.dismiss(); read(force: true) }
            return
        }
        if NotchMenuYieldEvent.isOwnWindow(event.windowNumber, windows: layout.ownWindows) { return }
        let point = NSEvent.mouseLocation
        if layout.bar.contains(point) {
            let blank = snapshot.applicationMenuEnd.map { point.x > $0 + 3 && point.x < layout.island.minX } ?? false
            let nativeButton = snapshot.overflow?.insetBy(dx: -3, dy: -1).contains(point) == true
            let appMenu = snapshot.applicationMenuEnd.map { point.x <= $0 } ?? false
            // An arbitrary status item also deserves the menu bar while used;
            // do not take a click inside the island's own activation surface.
            if blank || nativeButton || appMenu || !layout.island.contains(point) {
                let wasHidden = state.hidden
                // A rapid second press can close overflow before a poll saw
                // it open. Still finish once the native state is collapsed.
                if nativeButton && wasHidden { state.dismiss() }
                if !wasHidden {
                    state.begin(now: ProcessInfo.processInfo.systemUptime)
                    didChange?(true)
                }
            }
        } else if state.hidden { state.dismiss() }
        read(force: true)
    }

    private func read(force: Bool = false) {
        guard let layout, timer != nil else { return }
        guard AXIsProcessTrusted() else {
            // Permission revocation must never leave an invisible island stuck.
            if state.hidden { state = .init(); didChange?(false) }
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        guard !pending, force || now - lastRead >= (state.hidden ? 0.14 : 0.75) else { return }
        pending = true; lastRead = now
        let revision = generation
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let agents = NSWorkspace.shared.runningApplications.filter {
            ["com.apple.MenuBarAgent", "com.apple.controlcenter", "com.apple.systemuiserver"].contains($0.bundleIdentifier ?? "")
        }.map(\.processIdentifier)
        updateObservers(Set(agents + (front.map { [$0] } ?? [])).subtracting([ProcessInfo.processInfo.processIdentifier]))
        let watchPopups = true
        queue.async { [weak self] in
            let result = Self.measure(layout, front: front, agents: agents, watchPopups: watchPopups)
            DispatchQueue.main.async { [weak self] in
                guard let self, revision == self.generation, self.timer != nil else { return }
                self.pending = false
                self.snapshot = result
                let before = self.state.hidden
                self.state.sample(open: result.expanded || result.menuOpen,
                    pointerInBar: self.layout?.bar.contains(NSEvent.mouseLocation) == true,
                    now: ProcessInfo.processInfo.systemUptime)
                if before != self.state.hidden { self.didChange?(self.state.hidden) }
            }
        }
    }

    private func updateObservers(_ pids: Set<pid_t>) {
        for pid in Array(accessibilityObservers.keys) where !pids.contains(pid) {
            if let observer = accessibilityObservers.removeValue(forKey: pid) {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
            }
        }
        for pid in pids where accessibilityObservers[pid] == nil {
            var observer: AXObserver?
            guard AXObserverCreate(pid, { _, element, notification, context in
                guard let context else { return }
                let monitor = Unmanaged<NotchMenuYieldMonitor>.fromOpaque(context).takeUnretainedValue()
                guard monitor.timer != nil else { return }
                if notification as String == kAXMenuOpenedNotification,
                   let layout = monitor.layout, let rect = NotchMenuYieldMonitor.frame(element, top: layout.primaryTop),
                   rect.intersects(layout.screen), rect.maxY >= layout.bar.minY - 8 {
                    let before = monitor.state.hidden
                    monitor.state.sample(open: true, pointerInBar: true, now: ProcessInfo.processInfo.systemUptime)
                    if !before { monitor.didChange?(true) }
                }
                monitor.read(force: true)
            }, &observer) == .success, let observer else { continue }
            let app = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(app, 0.05)
            let context = Unmanaged.passUnretained(self).toOpaque()
            for notification in [kAXMenuOpenedNotification, kAXMenuClosedNotification] {
                AXObserverAddNotification(observer, app, notification as CFString, context)
            }
            accessibilityObservers[pid] = observer
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
    }

    private static func measure(_ layout: Layout, front: pid_t?, agents: [pid_t], watchPopups: Bool) -> Snapshot {
        var result = Snapshot()
        if let front, front != ProcessInfo.processInfo.processIdentifier {
            let app = AXUIElementCreateApplication(front)
            AXUIElementSetMessagingTimeout(app, 0.08)
            if let bar = element(app, kAXMenuBarAttribute) {
                let items = children(bar)
                let frames = items.compactMap { frame($0, top: layout.primaryTop) }.filter { $0.intersects(layout.bar) }
                result.applicationMenuEnd = frames.map(\.maxX).max()
                result.menuOpen = menuShown(bar) || items.contains(where: menuShown)
            }
        }
        for pid in agents {
            let app = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(app, 0.08)
            guard let bar = element(app, kAXExtrasMenuBarAttribute) else { continue }
            for child in children(bar) {
                if value(child, kAXRoleAttribute) as? String == kAXButtonRole,
                   let description = value(child, kAXDescriptionAttribute) as? String,
                   let expanded = overflowLabels[description],
                   let rect = frame(child, top: layout.primaryTop), rect.intersects(layout.bar) {
                    result.overflow = rect; result.expanded = expanded
                }
                result.menuOpen = result.menuOpen || menuShown(child)
            }
        }
        if watchPopups, let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] {
            result.menuOpen = result.menuOpen || windows.contains { window in
                guard let number = window[kCGWindowNumber as String] as? UInt32, !layout.ownWindows.contains(number),
                      (window[kCGWindowOwnerPID as String] as? Int32) != ProcessInfo.processInfo.processIdentifier,
                      let level = window[kCGWindowLayer as String] as? Int,
                      level >= Int(CGWindowLevelForKey(.popUpMenuWindow)), level < Int(CGWindowLevelForKey(.screenSaverWindow)),
                      let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                      let x = bounds["X"], let y = bounds["Y"], let w = bounds["Width"], let h = bounds["Height"],
                      w > 0, h > layout.barHeight,
                      (window[kCGWindowAlpha as String] as? Double ?? 1) > 0 else { return false }
                let rect = CGRect(x: x, y: layout.primaryTop - y - h, width: w, height: h)
                // A menu anchored to this display's bar; unrelated floating
                // windows elsewhere must not indefinitely hold the island away.
                return rect.intersects(layout.screen) && rect.maxY >= layout.bar.minY - 8
            }
        }
        return result
    }

    /// macOS 27 exposes its overflow control by a localized accessibility
    /// description, without an identifier/value. Load the system's own labels
    /// rather than assuming English or a fixed screen coordinate.
    private static let overflowLabels: [String: Bool] = {
        var labels = ["Show Hidden Menu Bar Items": false, "Hide Menu Bar Items": true,
                      "显示隐藏菜单栏项目": false, "隐藏菜单栏项目": true]
        let url = URL(fileURLWithPath: "/System/Library/CoreServices/MenuBarAgent.app/Contents/Resources/MenuBarCore.loctable")
        if let data = try? Data(contentsOf: url),
           let table = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] {
            for case let translations as [String: Any] in table.values {
                if let show = translations["menuBar.showOverflowItemsAccessibilityLabel"] as? String { labels[show] = false }
                if let hide = translations["menuBar.hideOverflowItemsAccessibilityLabel"] as? String { labels[hide] = true }
            }
        }
        return labels
    }()

    private static func menuShown(_ element: AXUIElement) -> Bool {
        if self.element(element, kAXShownMenuUIElementAttribute) != nil { return true }
        return !(value(element, kAXSelectedChildrenAttribute) as? [AXUIElement] ?? []).isEmpty
    }
    private static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else { return nil }
        return result
    }
    private static func element(_ parent: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let raw = value(parent, attribute), CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(raw, to: AXUIElement.self)
    }
    private static func children(_ element: AXUIElement) -> [AXUIElement] {
        Array((value(element, kAXChildrenAttribute) as? [AXUIElement] ?? []).prefix(64))
    }
    private static func frame(_ element: AXUIElement, top: CGFloat) -> CGRect? {
        guard let p = value(element, kAXPositionAttribute), CFGetTypeID(p) == AXValueGetTypeID(),
              let s = value(element, kAXSizeAttribute), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero; var size = CGSize.zero
        guard AXValueGetValue(unsafeBitCast(p, to: AXValue.self), .cgPoint, &point),
              AXValueGetValue(unsafeBitCast(s, to: AXValue.self), .cgSize, &size),
              point.x.isFinite, point.y.isFinite, size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else { return nil }
        return CGRect(x: point.x, y: top - point.y - size.height, width: size.width, height: size.height)
    }
}

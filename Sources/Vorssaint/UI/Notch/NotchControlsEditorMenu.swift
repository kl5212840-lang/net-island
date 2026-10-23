// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors
import AppKit
import SwiftUI

/// Native pull-downs remain keyboard operable even when macOS's optional
/// full keyboard navigation is off. No second SwiftUI focus wrapper is needed.
struct NotchControlsEditorMenu: NSViewRepresentable {
    struct Entry {
        var title: String
        var symbol: String? = nil
        var enabled = true
        var checked = false
        var children: [Entry] = []
        var action: (() -> Void)? = nil
        static var separator: Self { .init(title: "") }
    }
    let symbol: String
    let title: String
    let entries: [Entry]
    let focus: NotchControlsEditor.Focus
    @ObservedObject private var editor = NotchControlsEditor.shared
    final class Button: NSPopUpButton {
        var focus: NotchControlsEditor.Focus = .add
        override var acceptsFirstResponder: Bool { true }
        override var canBecomeKeyView: Bool { isEnabled && !isHidden }
        override func becomeFirstResponder() -> Bool {
            let accepted = super.becomeFirstResponder()
            if accepted { NotchControlsEditor.shared.keyboardFocus = focus }
            return accepted
        }
        override func keyDown(with event: NSEvent) {
            if [36, 49, 125].contains(event.keyCode) { performClick(nil) }
            else { super.keyDown(with: event) }
        }
    }
    final class Target: NSObject {
        let action: () -> Void
        init(_ action: @escaping () -> Void) { self.action = action }
        @objc func invoke(_ sender: Any?) { action() }
    }
    final class Coordinator: NSObject, NSMenuDelegate {
        func menuWillOpen(_ menu: NSMenu) { NotchControlsEditor.shared.beginPopup(menu) }
        func menuDidClose(_ menu: NSMenu) { NotchControlsEditor.shared.endPopup(menu) }
        var targets: [Target] = []
        func menu(_ entries: [Entry]) -> NSMenu {
            let result = NSMenu(); result.autoenablesItems = false; result.delegate = self
            for entry in entries {
                if entry.title.isEmpty { result.addItem(.separator()); continue }
                let item = NSMenuItem(title: entry.title, action: nil, keyEquivalent: "")
                item.isEnabled = entry.enabled
                item.state = entry.checked ? .on : .off
                if let symbol = entry.symbol { item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
                if !entry.children.isEmpty { item.submenu = menu(entry.children) }
                if let action = entry.action {
                    let target = Target(action); targets.append(target)
                    item.target = target; item.action = #selector(Target.invoke(_:))
                }
                result.addItem(item)
            }
            return result
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> Button {
        let button = Button(frame: .zero, pullsDown: true)
        button.isBordered = false
        button.bezelStyle = .inline
        button.imagePosition = .imageOnly
        button.focusRingType = .exterior
        return button
    }
    func updateNSView(_ button: Button, context: Context) {
        button.focus = focus
        if editor.keyboardFocus == focus, button.window?.firstResponder !== button {
            DispatchQueue.main.async { [weak button] in
                guard let button, NotchControlsEditor.shared.keyboardFocus == button.focus else { return }
                button.window?.makeFirstResponder(button)
            }
        }
        context.coordinator.targets = []
        let menu = context.coordinator.menu(entries)
        let heading = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        heading.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .medium))
        menu.insertItem(heading, at: 0)
        button.menu = menu
        button.setAccessibilityLabel(title)
        button.toolTip = title
    }
}

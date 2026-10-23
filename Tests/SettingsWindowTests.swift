// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

private final class TestSettingsWindow: SettingsWindow {
    var testIsKeyWindow = true
    var activationRequests = 0

    override var isKeyWindow: Bool { testIsKeyWindow }
    override func activateForKeyboardInput() { activationRequests += 1 }
}

private final class SettingsFocusClickTarget: NSView {
    var clicked: (() -> Void)?
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { clicked?() }
}

enum SettingsWindowTests {
    static func run(expect: (Bool, String) -> Void) {
        let app = NSApplication.shared
        let defaults = UserDefaults.standard
        let keys = [DefaultsKey.mouseButtonShortcutsEnabled, DefaultsKey.mouseSpacesGestureEnabled,
                    AppFeature.radialMenu.availabilityKey, AppFeature.scrollInverter.availabilityKey]
        let previous = keys.map { defaults.object(forKey: $0) }
        for key in keys { defaults.set(false, forKey: key) }
        defaults.set(true, forKey: AppFeature.scrollInverter.availabilityKey)
        let previousMenu = app.mainMenu
        let window = TestSettingsWindow(contentRect: NSRect(x: -10_000, y: -10_000, width: 300, height: 200),
                                        styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.router = SettingsRouter()
        defer {
            window.close()
            app.mainMenu = previousMenu
            for (key, value) in zip(keys, previous) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }

        // Exercise the actual NSWindow handoff and mouse-dispatch path. The
        // fixture records activation instead of taking focus from the user.
        let originalContent = window.contentView
        let target = SettingsFocusClickTarget(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        window.contentView = target
        window.orderFrontRegardless()
        let beforeKey = window.activationRequests
        window.becomeKey()
        expect(window.activationRequests == beforeKey + 1,
               "making Settings key also requests application activation")
        var activationBeforeClick: Int?
        target.clicked = { activationBeforeClick = window.activationRequests }
        let beforeClick = window.activationRequests
        let click = NSEvent.mouseEvent(with: .leftMouseDown, location: NSPoint(x: 100, y: 80),
                                      modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                                      context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
        window.sendEvent(click)
        expect(activationBeforeClick == beforeClick + 1,
               "clicking an already-key Settings window activates before dispatching to its content")
        // Activation must not replace the editor or its marked text. New and
        // rename fields, including Chinese composition, retain AppKit editing.
        let field = NSTextField(frame: NSRect(x: 10, y: 10, width: 200, height: 24))
        target.addSubview(field)
        window.makeFirstResponder(field)
        let editor = window.firstResponder as? NSTextView
        editor?.insertText("Preset 123", replacementRange: NSRange(location: NSNotFound, length: 0))
        expect(editor?.string == "Preset 123", "the Settings field editor accepts letters and digits")
        editor?.setMarkedText("中文", selectedRange: NSRange(location: 2, length: 0),
                              replacementRange: NSRange(location: NSNotFound, length: 0))
        window.activateForKeyboardInput()
        expect(window.firstResponder === editor && editor?.hasMarkedText() == true,
               "activation recovery preserves the field editor and Chinese composition")
        editor?.unmarkText()
        window.makeFirstResponder(nil)
        window.contentView = originalContent

        let mainMenu = NSMenu()
        mainMenu.addItem(NSMenuItem())
        mainMenu.items[0].submenu = NSMenu(title: "Test")
        let host = NSMenuItem()
        let navigationMenu = SettingsWindow.navigationMenu(language: .enUS)
        host.submenu = navigationMenu
        mainMenu.addItem(host)
        app.mainMenu = mainMenu
        expect(window.isKeyWindow, "Settings navigation fixture has a key window")

        let back = navigationMenu.items[0]
        let forward = navigationMenu.items[1]
        expect(back.target == nil && forward.target == nil,
               "Settings navigation menu uses the key window's responder chain")
        expect(!window.validateMenuItem(back) && !window.validateMenuItem(forward),
               "Settings history commands are disabled before any page visits")
        window.router.page = .about
        window.router.page = .mouse
        expect(window.validateMenuItem(back) && !window.validateMenuItem(forward),
               "Mouse and Trackpad enables Back to the preceding page")

        // The production items remain targetless; direct them explicitly because this
        // isolated fixture deliberately has no active application's responder chain.
        app.sendAction(back.action!, to: window, from: back)
        expect(window.router.page == .about,
               "a Back menu action navigates from Mouse and Trackpad")
        app.sendAction(forward.action!, to: window, from: forward)
        expect(window.router.page == .mouse,
               "a Forward menu action restores Mouse and Trackpad")

        func pressKey(_ item: NSMenuItem, keyCode: UInt16) {
            let character = item.keyEquivalent
            let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
                                        timestamp: 0, windowNumber: window.windowNumber, context: nil,
                                        characters: character, charactersIgnoringModifiers: character,
                                        isARepeat: false, keyCode: keyCode)!
            expect(mainMenu.performKeyEquivalent(with: event),
                   "Settings resolves the Command-\(character) navigation shortcut")
            app.sendAction(item.action!, to: window, from: item)
        }
        pressKey(back, keyCode: 33)
        expect(window.router.page == .about, "a driver-generated Back shortcut navigates Settings")
        pressKey(forward, keyCode: 30)
        expect(window.router.page == .mouse, "a driver-generated Forward shortcut navigates Settings")

        func mouseEvent(_ type: CGEventType, button: Int64) {
            let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: .zero,
                                mouseButton: .center)!
            event.setIntegerValueField(.mouseEventButtonNumber, value: button)
            window.sendEvent(NSEvent(cgEvent: event)!)
        }
        mouseEvent(.otherMouseDown, button: 3)
        expect(window.router.page == .about, "a raw Back side button navigates Settings")
        mouseEvent(.otherMouseDragged, button: 3)
        mouseEvent(.otherMouseUp, button: 3)
        expect(window.router.page == .about, "Back drag and release do not navigate a second time")
        mouseEvent(.otherMouseDown, button: 4)
        mouseEvent(.otherMouseUp, button: 4)
        expect(window.router.page == .mouse, "a raw Forward side button restores the next page")

        window.isMouseButtonCaptureActive = { true }
        expect(!window.validateMenuItem(back), "shortcut capture disables Settings history commands")
        window.goBack(nil)
        mouseEvent(.otherMouseDown, button: 3)
        mouseEvent(.otherMouseUp, button: 3)
        expect(window.router.page == .mouse, "shortcut capture blocks both command and raw-button navigation")
        window.isMouseButtonCaptureActive = { false }
        window.testIsKeyWindow = false
        window.goBack(nil)
        expect(!window.validateMenuItem(back) && window.router.page == .mouse,
               "an unfocused Settings window cannot navigate through a command")

        // The side buttons learn where this keyboard carries Back and Forward
        // from the Go items. macOS strips the key from a hidden copy declared
        // beside them, which left German and French keyboards on the brackets.
        MouseNavigationKeys.reset()
        defer { MouseNavigationKeys.reset() }
        expect(SettingsWindow.navigationItem(for: .back, in: mainMenu) === back
                && SettingsWindow.navigationItem(for: .forward, in: mainMenu) === forward,
               "mouse navigation finds the Go item for each side button")
        for (item, key) in [(back, "ö"), (forward, "ä")] {
            // Where a German keyboard moves the commands.
            item.allowsAutomaticKeyEquivalentLocalization = false
            item.keyEquivalent = key
        }
        let movedBack = MouseNavigationKeys.shortcut(for: .back)
        let movedForward = MouseNavigationKeys.shortcut(for: .forward)
        expect(movedBack.character == "ö" && movedForward.character == "ä"
                && movedBack.menuModifiers == 0 && movedForward.menuModifiers == 0,
               "side buttons look for the keys macOS moved the Go commands to")
        expect(MouseNavigationKeys.candidates(for: .back).map(\.character) == ["ö", "["]
                && MouseNavigationKeys.candidates(for: .forward).map(\.character) == ["ä", "]"],
               "a moved key that the app in front no longer shows still leaves the declared bracket to find")
        let menuItemCount = mainMenu.numberOfItems
        MouseNavigationKeys.refresh()
        expect(mainMenu.numberOfItems == menuItemCount,
               "no hidden copy of the Go commands is added beside them")
        app.mainMenu = NSMenu()
        expect(MouseNavigationKeys.shortcut(for: .back).character == "["
                && MouseNavigationKeys.shortcut(for: .forward).character == "]",
               "without the Go menu, side buttons fall back to the declared brackets")
        expect(MouseNavigationKeys.candidates(for: .back).map(\.character) == ["["],
               "the declared bracket is looked for once when nothing moved it")

        for language in AppLanguage.allCases {
            let strings = SettingsNavigationStrings.localized(language)
            expect(!strings.go.isEmpty && !strings.back.isEmpty && !strings.forward.isEmpty,
                   "Settings navigation menu is translated for \(language.rawValue)")
            expect(!strings.showSidebar.isEmpty && !strings.hideSidebar.isEmpty
                       && strings.showSidebar != strings.hideSidebar,
                   "the sidebar button names both of its actions in \(language.rawValue)")
        }
    }
}

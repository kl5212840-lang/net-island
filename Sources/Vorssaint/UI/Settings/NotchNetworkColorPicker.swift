// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors

import AppKit
import SwiftUI

/// Retains the native color wheel/sliders and live persistence, while making
/// the panel's completion action explicit rather than relying on its close dot.
struct NotchNetworkColorPicker: View {
    let title: String
    @Binding var hex: String
    let fallback: String
    let text: NotchNetworkStrings

    var body: some View {
        HStack {
            Text(title)
            ConfirmedColorWell(hex: $hex, fallback: fallback, title: title, text: text)
                .frame(width: 44, height: 24)
            Spacer(minLength: 0)
        }
    }
}

private struct ConfirmedColorWell: NSViewRepresentable {
    @Binding var hex: String
    let fallback: String
    let title: String
    let text: NotchNetworkStrings

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> CompletionColorWell {
        let well = CompletionColorWell()
        well.supportsAlpha = false
        well.target = context.coordinator
        well.action = #selector(Coordinator.changed(_:))
        updateNSView(well, context: context)
        return well
    }

    func updateNSView(_ well: CompletionColorWell, context: Context) {
        context.coordinator.parent = self
        let rgb = MenuBarUsageBarSupport.rgb(for: hex, fallback: fallback)
        let color = NSColor(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
        if !well.color.isEqual(color) { well.color = color }
        well.doneTitle = text.done
        well.savedHint = text.colorSaved
        well.setAccessibilityLabel(title)
    }

    static func dismantleNSView(_ well: CompletionColorWell, coordinator: Coordinator) {
        if well.isActive { well.finishSelection(nil) }
    }

    final class Coordinator: NSObject {
        var parent: ConfirmedColorWell
        init(_ parent: ConfirmedColorWell) { self.parent = parent }
        @objc func changed(_ well: NSColorWell) {
            guard let rgb = well.color.usingColorSpace(.sRGB) else { return }
            parent.hex = MenuBarUsageBarSupport.hex(red: Double(rgb.redComponent), green: Double(rgb.greenComponent), blue: Double(rgb.blueComponent))
        }
    }
}

private final class CompletionColorWell: NSColorWell {
    var doneTitle = "Done"
    var savedHint = "Color changes are saved immediately."
    private var footer: NSView?

    override func activate(_ exclusive: Bool) {
        super.activate(exclusive)
        let footer = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 48))
        let hint = NSTextField(labelWithString: savedHint)
        hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hint.textColor = .secondaryLabelColor
        let button = NSButton(title: doneTitle, target: self, action: #selector(finishSelection(_:)))
        button.bezelStyle = .rounded
        button.keyEquivalent = "\r"
        for view in [hint, button] {
            view.translatesAutoresizingMaskIntoConstraints = false
            footer.addSubview(view)
        }
        NSLayoutConstraint.activate([
            hint.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 12),
            hint.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
            button.leadingAnchor.constraint(greaterThanOrEqualTo: hint.trailingAnchor, constant: 12),
            button.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -12),
            button.centerYAnchor.constraint(equalTo: footer.centerYAnchor)
        ])
        self.footer = footer
        NSColorPanel.shared.accessoryView = footer
        NSColorPanel.shared.showsAlpha = false
    }

    override func deactivate() {
        super.deactivate()
        if let footer, NSColorPanel.shared.accessoryView === footer { NSColorPanel.shared.accessoryView = nil }
        footer = nil
    }

    @objc func finishSelection(_ sender: Any?) {
        deactivate()
        NSColorPanel.shared.close()
    }
}

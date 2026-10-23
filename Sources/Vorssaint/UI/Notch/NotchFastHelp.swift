// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors

import AppKit
import SwiftUI

/// Icon-only headers need a prompt explanation instead of the system's long
/// tooltip delay. This stays below the camera strip and takes no mouse events.
private struct NotchFastHelp: ViewModifier {
    let title: String
    let leadingSide: Bool
    @State private var visible = false
    @State private var pending: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: leadingSide ? .topLeading : .topTrailing) {
                if visible {
                    let width = min(180, max(48, ceil((title as NSString).size(withAttributes: [
                        .font: NSFont.systemFont(ofSize: 11, weight: .medium)
                    ]).width)))
                    Text(title).font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white).lineLimit(3)
                        .frame(width: width, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(.black.opacity(0.96), in: RoundedRectangle(cornerRadius: 6))
                        .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                        .offset(y: 34)
                        .allowsHitTesting(false).accessibilityHidden(true)
                        .transition(.opacity)
                }
            }
            .zIndex(visible ? 1000 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: visible)
            .onHover { entered in
                pending?.cancel()
                if entered && !title.isEmpty {
                    pending = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 120_000_000)
                        guard !Task.isCancelled else { return }
                        visible = true
                    }
                } else { visible = false; pending = nil }
            }
            .onDisappear { pending?.cancel(); pending = nil; visible = false }
    }
}

extension View {
    func notchFastHelp(_ title: String, leadingSide: Bool = true) -> some View {
        modifier(NotchFastHelp(title: title, leadingSide: leadingSide))
    }
}

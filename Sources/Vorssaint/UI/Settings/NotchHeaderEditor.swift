// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors

import SwiftUI

/// Unscaled editor handles over the scaled island, like its existing floating
/// button handles. Every anchor opens the same complete action chooser.
struct NotchHeaderEditor: View {
    let island: CGRect
    let geometry: NotchGeometry
    let scale: CGFloat
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @AppStorage(DefaultsKey.notchHeaderLayout) private var data = Data()
    @AppStorage(DefaultsKey.notchHeaderNetworkIconOnly) private var iconOnly = false
    @State private var editing: NotchHeaderPosition?
    @State private var dragging: UUID?
    @State private var translation = CGSize.zero
    private var text: NotchNetworkStrings { .init(l10n.language) }
    private var editor: NotchEditorStrings { FeatureStrings.notchEditor(l10n.language) }
    private var layout: NotchHeaderConfiguration { .decoded(data) ?? .stored() }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if geometry.isNotched {
                Text(text.cameraSafeArea).font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45)).lineLimit(1).minimumScaleFactor(0.8)
                    .frame(width: max(40, geometry.cameraWidth * scale - 16), height: max(18, geometry.cameraHeight * scale))
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 5))
                    .position(x: island.midX, y: island.minY + geometry.cameraHeight * scale / 2)
                    .allowsHitTesting(false)
            }
            ForEach(NotchHeaderPosition.allCases, id: \.rawValue) { position in
                slot(position)
                    .position(point(position))
            }
        }
    }

    private func point(_ position: NotchHeaderPosition) -> CGPoint {
        let gap = geometry.headerCameraGap * scale
        let x: CGFloat = switch position {
        case .leftOuter: island.minX + 24
        case .leftInner: island.midX - gap / 2 - 22
        case .rightInner: island.midX + gap / 2 + 22
        case .rightOuter: island.maxX - 24
        }
        return CGPoint(x: x, y: island.minY + max(18, (geometry.headerTopInset + geometry.headerRowHeight / 2) * scale))
    }

    private func slot(_ position: NotchHeaderPosition) -> some View {
        let button = layout.button(at: position)
        let title = button.map { $0.label.isEmpty ? $0.action?.title(l10n) ?? editor.editButton : $0.label } ?? editor.addButton
        let hidden = button != nil && button?.action?.isAvailable() != true
        return Button { editing = position } label: {
            Image(systemName: button?.action?.symbol ?? "plus")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(button == nil ? Color.accentColor : .white.opacity(hidden ? 0.4 : 0.85))
                .frame(width: 28, height: 28)
                .background {
                    if button == nil {
                        Circle().strokeBorder(Color.accentColor.opacity(0.65), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(position.title(text) + ": " + title)
        .accessibilityLabel((button == nil ? editor.addButton : editor.editButton) + ", " + text.headerTitle + ", " + position.title(text) + ", " + title)
        .accessibilityIdentifier("notch.editor.header." + position.rawValue)
        .offset(dragging == button?.id && dragging != nil ? translation : .zero)
        .highPriorityGesture(DragGesture(minimumDistance: 5, coordinateSpace: .named("island.editor"))
            .onChanged { value in
                guard let button else { return }
                editing = nil; dragging = button.id; translation = value.translation
            }
            .onEnded { value in
                if let button, let target = NotchHeaderPosition.allCases.first(where: {
                    let p = point($0)
                    return abs(value.location.x - p.x) <= 20 && abs(value.location.y - p.y) <= 20
                }) {
                    var current = layout; current.move(button.id, to: target); data = current.encoded
                }
                dragging = nil; translation = .zero
            })
        .popover(isPresented: Binding(get: { editing == position }, set: { if !$0 { editing = nil } }), arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text(text.headerTitle + " · " + position.title(text)).font(.headline)
                if let button {
                    TextField(editor.buttonName, text: Binding(get: { layout.button(at: position)?.label ?? "" }, set: { name in
                        var current = layout
                        if let index = current.buttons.firstIndex(where: { $0.position == position }) {
                            current.buttons[index].label = NotchNetworkPresetLibrary.cleanName(name); data = current.encoded
                        }
                    }), prompt: Text(button.action?.title(l10n) ?? ""))
                    if button.action == .networkReadout { Toggle(text.headerIconOnly, isOn: $iconOnly) }
                    Button(editor.removeButton, role: .destructive) {
                        var current = layout; current.buttons.removeAll { $0.position == position }
                        data = current.encoded; editing = nil
                    }
                    Divider()
                }
                NotchActionChooser(title: "", selected: button?.action) { action in
                    var current = layout; current.set(action, at: position)
                    data = current.encoded; editing = nil
                }
                Text(text.headerEditorHint).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }.padding(16).frame(width: 340)
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors
import SwiftUI

/// The actual island is the canvas. Sliders and actions are inert while editing;
/// only this overlay handles input, so arranging a mic cannot mute it.
struct NotchControlsEditingView: View {
    let service: NotchService
    let size: CGSize
    let render: (NotchControlItem, NotchControlSizing, CGFloat) -> AnyView
    @ObservedObject private var editor = NotchControlsEditor.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedTarget: NotchControlsEditor.Focus?
    @State private var dragging: NotchControlItem?
    @State private var resizing: NotchControlItem?
    @State private var translation = CGSize.zero
    @State private var resizeRect = CGRect.zero
    @State private var pointer = CGPoint.zero
    @State private var canvasOrigin = CGPoint.zero
    @State private var dragOrigin = CGPoint.zero
    @State private var viewport = CGRect.zero
    private var chinese: Bool { NotchNetworkStrings(l10n.language).chinese }
    private func t(_ zh: String, _ en: String) -> String { chinese ? zh : en }

    var body: some View {
        VStack(spacing: 8) {
            toolbar
            Text(t("拖动排列 · 拖角缩放 · Tab 选择 · 方向键排序 · ⌥方向键缩放", "Drag to arrange · Corner to resize · Tab selects · Arrows reorder · ⌥Arrows resize"))
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let document = editor.draft {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        canvas(document)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .background(NotchControlsCanvasBounds(width: size.width))
                            .background {
                                GeometryReader { geometry in
                                    Color.clear.onGeometryChange(for: CGPoint.self) { $0.frame(in: .named("controls.editor")).origin } action: { canvasOrigin = $0 }
                                }
                            }
                    }
                    .scrollIndicators(.hidden)
                    .contentMargins(.horizontal, 0, for: .scrollContent)
                    .frame(width: size.width, alignment: .leading)
                    .accessibilityLabel(t("控制布局画布", "Control layout canvas"))
                    .notchScrollEdgeFade()
                    .background {
                        GeometryReader { geometry in
                            Color.clear.onGeometryChange(for: CGRect.self) { $0.frame(in: .named("controls.editor")) } action: { viewport = $0 }
                        }
                    }
                    .task(id: dragging) {
                        guard dragging != nil else { return }
                        while !Task.isCancelled {
                            try? await Task.sleep(nanoseconds: 180_000_000)
                            guard !Task.isCancelled, dragging != nil, let draft = editor.draft else { return }
                            let slots = draft.appearance.controlSlots(editor.items, width: size.width)
                            let top = viewport.minY - canvasOrigin.y, bottom = viewport.maxY - canvasOrigin.y
                            let target: NotchControlItem?
                            if pointer.y > viewport.maxY - 26 { target = slots.first { $0.frame.maxY > bottom + 6 }?.item }
                            else if pointer.y < viewport.minY + 26 { target = slots.last { $0.frame.minY < top - 6 }?.item }
                            else { target = nil }
                            if let target { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) { proxy.scrollTo(target, anchor: pointer.y > viewport.midY ? .bottom : .top) } }
                        }
                    }
                }
            }
            Divider().overlay(.white.opacity(0.10))
            inspector
        }
        .coordinateSpace(name: "controls.editor")
        .frame(width: size.width, height: size.height, alignment: .top)
        .onAppear { if let item = editor.selection { editor.keyboardFocus = .control(item); focusedTarget = .control(item) } }
        .onChange(of: editor.selection) { _, item in if let item { editor.keyboardFocus = .control(item) } }
        .onChange(of: editor.keyboardFocus) { _, target in
            switch target {
            case .arrange, .add, .appearance: focusedTarget = nil
            default: focusedTarget = target
            }
        }
        .onChange(of: focusedTarget) { _, target in
            if let target { editor.keyboardFocus = target }
        }
        .onDisappear { if editor.isEditing { service.finishControlsEditing(save: false) } }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            Button(t("取消", "Cancel")) { service.finishControlsEditing(save: false) }
                .focusable().focused($focusedTarget, equals: .cancel).onKeyPress(.space) { service.finishControlsEditing(save: false); return .handled }
                .accessibilityIdentifier("notch.controls.edit.cancel")
            Spacer(minLength: 2)
            Button { editor.undo() } label: { Image(systemName: "arrow.uturn.backward").frame(width: 24, height: 26) }
                .disabled(!editor.canUndo).help(t("撤销", "Undo")).accessibilityLabel(t("撤销", "Undo"))
                .keyboardShortcut("z", modifiers: .command).focusable().focused($focusedTarget, equals: .undo).onKeyPress(.space) { editor.undo(); return .handled }
            NotchControlsEditorMenu(symbol: "align.horizontal.left", title: t("整理布局", "Arrange layout"), entries: [
                .init(title: t("重做", "Redo"), enabled: editor.canRedo, action: { editor.redo() }),
                .init(title: t("排齐滑条与按钮", "Align sliders and buttons"), action: { editor.change { $0.tidy(available: editor.available) } })
            ], focus: .arrange).frame(width: 34, height: 26)
            NotchControlsEditorMenu(symbol: "plus", title: t("添加控制项", "Add control"), entries: NotchControlItem.allCases.map { item in
                .init(title: item.title(l10n), symbol: item.symbol,
                      enabled: !editor.items.contains(item) && editor.available.contains(item), checked: editor.items.contains(item),
                      action: { editor.change { $0.hidden.remove(item.rawValue) }; editor.selection = item })
            }, focus: .add).frame(width: 34, height: 26)
            Spacer(minLength: 2)
            Button(t("完成", "Done")) { service.finishControlsEditing(save: true) }
                .foregroundStyle(.cyan).keyboardShortcut(.return, modifiers: [])
                .focusable().focused($focusedTarget, equals: .done).onKeyPress(.space) { service.finishControlsEditing(save: true); return .handled }
                .accessibilityIdentifier("notch.controls.edit.done")
        }
        .font(.system(size: 11, weight: .medium)).buttonStyle(.plain)
        .frame(height: 28)
    }

    private func canvas(_ document: NotchControlsDocument) -> some View {
        let slots = document.appearance.controlSlots(editor.items, width: size.width)
        return ZStack(alignment: .topLeading) {
            if slots.isEmpty {
                Text(t("点 + 添加控制项", "Use + to add a control"))
                    .font(.callout).foregroundStyle(.secondary).frame(width: size.width, height: 100)
            }
            if let landing = landingRect(document) {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.cyan.opacity(0.65), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .frame(width: landing.width, height: landing.height)
                    .position(x: landing.midX, y: landing.midY)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
            ForEach(slots) { slot in
                let rect = document.appearance.controlContentRect(slot)
                let selected = editor.selection == slot.item
                let style = document.appearance.controlStyle(slot.item)
                ZStack {
                    render(slot.item, style, rect.width).focusable(false).allowsHitTesting(false).accessibilityHidden(true)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selected ? Color.cyan.opacity(0.035) : Color.clear)
                        .contentShape(Rectangle())
                        .overlay { RoundedRectangle(cornerRadius: 8).stroke(selected ? .cyan.opacity(0.8) : .white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: selected ? [] : [3, 3])) }
                        .onTapGesture { editor.selection = slot.item }
                        .gesture(moveGesture(slot: slot, rect: rect))
                    if selected {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 9, weight: .semibold)).foregroundStyle(.cyan)
                            .frame(width: 24, height: 24).background(.black.opacity(0.85), in: Circle())
                            .contentShape(Rectangle()).gesture(resizeGesture(slot: slot, rect: rect))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .accessibilityLabel(t("拖动调整大小", "Drag to resize"))
                    }
                }
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .offset(dragging == slot.item ? translation : .zero)
                .zIndex(dragging == slot.item || resizing == slot.item ? 2 : 0)
                .id(slot.item)
                .focusable()
                .focused($focusedTarget, equals: .control(slot.item))
                .focusEffectDisabled(!service.showsKeyboardFocus)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(slot.item.title(l10n))
                .accessibilityValue("\(Int(rect.width)) × \(Int(rect.height))")
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityAction { editor.selection = slot.item }
                .accessibilityAction(named: t("上移", "Move earlier")) { moveAccessible(slot.item, backwards: true) }
                .accessibilityAction(named: t("下移", "Move later")) { moveAccessible(slot.item, backwards: false) }
                .accessibilityAction(named: t("加宽", "Increase width")) { resizeAccessible(slot.item, dx: 8, dy: 0) }
                .accessibilityAction(named: t("收窄", "Decrease width")) { resizeAccessible(slot.item, dx: -8, dy: 0) }
                .accessibilityAction(named: t("增高", "Increase height")) { resizeAccessible(slot.item, dx: 0, dy: 4) }
                .accessibilityAction(named: t("降低", "Decrease height")) { resizeAccessible(slot.item, dx: 0, dy: -4) }
            }
        }
        .frame(width: size.width, height: max(100, document.appearance.customControlsHeight(editor.items, width: size.width)))
        .animation(reduceMotion || resizing != nil ? nil : .easeOut(duration: 0.16), value: document)
    }

    private func landingRect(_ document: NotchControlsDocument) -> CGRect? {
        guard let item = dragging,
              let source = document.appearance.controlSlots(editor.items, width: size.width).first(where: { $0.item == item }) else { return nil }
        let rect = document.appearance.controlContentRect(source)
        var proposed = document
        proposed.drop(item, center: CGPoint(x: rect.midX + translation.width, y: rect.midY + translation.height),
                      width: size.width, available: editor.available)
        return proposed.appearance.controlSlots(proposed.visible(available: editor.available), width: size.width)
            .first(where: { $0.item == item }).map { proposed.appearance.controlContentRect($0) }
    }

    private func moveGesture(slot: NotchControlSlot, rect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .named("controls.editor"))
            .onChanged { value in
                if dragging == nil { editor.selection = slot.item; dragging = slot.item; dragOrigin = canvasOrigin }
                pointer = value.location
                translation = CGSize(width: min(size.width - rect.maxX, max(-rect.minX, value.translation.width)),
                                     height: value.translation.height + dragOrigin.y - canvasOrigin.y)
            }
            .onEnded { value in
                let center = CGPoint(x: rect.midX + translation.width, y: rect.midY + translation.height)
                editor.change { $0.drop(slot.item, center: center, width: size.width, available: editor.available) }
                dragging = nil; translation = .zero
            }
    }
    private func resizeGesture(slot: NotchControlSlot, rect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named("controls.editor"))
            .onChanged { value in
                if resizing == nil { resizing = slot.item; resizeRect = rect; editor.beginGesture() }
                editor.updateGesture { $0.resize(slot.item, from: resizeRect, translation: value.translation, width: size.width) }
            }
            .onEnded { _ in editor.endGesture(); resizing = nil }
    }

    @ViewBuilder private var inspector: some View {
        if let item = editor.selection, editor.items.contains(item), let document = editor.draft {
            let style = document.appearance.controlStyle(item), key = document.appearance.controlKey(item)
            VStack(spacing: 6) {
                HStack {
                    Label(item.title(l10n), systemImage: item.symbol).lineLimit(1)
                    Spacer(minLength: 4)
                    NotchControlsEditorMenu(symbol: "ellipsis", title: t("选中项外观", "Selected control appearance"),
                        entries: appearanceEntries(item, style: style, key: key), focus: .appearance).frame(width: 34, height: 24)
                }
                .font(.system(size: 11, weight: .medium))
                if item != .music {
                    HStack(spacing: 12) {
                        sizeStepper(title: t("图标", "Icon"), value: style.glyph, range: 10...32, key: key + "icon", decrease: .iconDecrease, increase: .iconIncrease)
                        sizeStepper(title: t("文字", "Text"), value: style.font, range: 9...16, key: key + "font", decrease: .textDecrease, increase: .textIncrease)
                    }
                } else {
                    Text(t("拖动右下角调整播放区域", "Resize playback using the lower corner"))
                        .font(.system(size: 10)).foregroundStyle(.secondary).frame(height: 24)
                }
            }.frame(height: 60)
        } else {
            Text(t("点选控件后调整外观", "Select a control to adjust its appearance"))
                .font(.caption).foregroundStyle(.secondary).frame(height: 60)
        }
    }
    private func appearanceEntries(_ item: NotchControlItem, style: NotchControlSizing, key: String) -> [NotchControlsEditorMenu.Entry] {
        var result: [NotchControlsEditorMenu.Entry] = []
        if item != .music {
            let value = item.isLevel ? style.showsValues : style.labels
            result.append(.init(title: t(item.isLevel ? "名称与读数" : "显示文字", item.isLevel ? "Labels and readings" : "Show labels"),
                checked: value, action: { editor.change { $0.appearance.values[key + (item.isLevel ? "values" : "iconOnly")] = String(item.isLevel ? !value : value) } }))
        }
        if !item.isLevel && item != .music {
            result.append(.init(title: t("图标底形", "Icon background"), children: [("circle", t("圆形", "Circle")), ("square", t("圆角方形", "Rounded square")), ("plain", t("仅图形", "None"))].map { shape, title in
                .init(title: title, checked: style.shape == shape, action: { editor.change { $0.appearance.values[key + "shape"] = shape } })
            }))
        }
        result.append(.init(title: t("恢复此项大小", "Restore this item’s size"), action: { editor.change { $0.appearance.reset(key) } }))
        result.append(.separator)
        result.append(.init(title: t("从岛内移除", "Remove from island"), action: { editor.change { $0.hidden.insert(item.rawValue) }; editor.selection = editor.items.first }))
        return result
    }
    private func sizeStepper(title: String, value: CGFloat, range: ClosedRange<CGFloat>, key: String, decrease: NotchControlsEditor.Focus, increase: NotchControlsEditor.Focus) -> some View {
        HStack(spacing: 2) {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button { editor.change { $0.appearance.values[key] = String(Double(max(range.lowerBound, value - 1))) } } label: { Image(systemName: "minus").frame(width: 22, height: 24) }
                .focusable().focused($focusedTarget, equals: decrease).onKeyPress(.space) { editor.change { $0.appearance.values[key] = String(Double(max(range.lowerBound, value - 1))) }; return .handled }.disabled(value <= range.lowerBound).accessibilityLabel(t("缩小", "Decrease ") + title)
            Text("\(Int(value))").monospacedDigit().frame(width: 18)
            Button { editor.change { $0.appearance.values[key] = String(Double(min(range.upperBound, value + 1))) } } label: { Image(systemName: "plus").frame(width: 22, height: 24) }
                .focusable().focused($focusedTarget, equals: increase).onKeyPress(.space) { editor.change { $0.appearance.values[key] = String(Double(min(range.upperBound, value + 1))) }; return .handled }.disabled(value >= range.upperBound).accessibilityLabel(t("增大", "Increase ") + title)
        }.font(.system(size: 10)).buttonStyle(.plain)
    }
    private func moveAccessible(_ item: NotchControlItem, backwards: Bool) {
        editor.move(item, backwards: backwards)
    }
    private func resizeAccessible(_ item: NotchControlItem, dx: CGFloat, dy: CGFloat) {
        editor.selection = item
        editor.resizeSelected(width: size.width, dx: dx, dy: dy)
    }
}

/// Marks only the editing canvas for native legacy-scroller normalization.
/// AppKit may temporarily propose a 17pt wider scroll view when overflow starts.
private struct NotchControlsCanvasBounds: NSViewRepresentable {
    let width: CGFloat
    final class Marker: NSView {
        var canvasWidth: CGFloat = 0
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); mark() }
        func mark() {
            var ancestor = superview
            while let view = ancestor {
                if let scroll = view as? NSScrollView {
                    scroll.identifier = NSUserInterfaceItemIdentifier("notch.controls.canvas:\(canvasWidth)")
                    return
                }
                ancestor = view.superview
            }
        }
    }
    func makeNSView(context: Context) -> Marker { let view = Marker(); view.canvasWidth = width; return view }
    func updateNSView(_ view: Marker, context: Context) { view.canvasWidth = width; view.mark() }
}

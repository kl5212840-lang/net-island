// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors
import Foundation
import Combine

/// A local editing transaction. Other sections, presets and permissions are
/// outside its write boundary; Cancel and dragging never write preferences.
struct NotchControlsDocument: Equatable {
    var appearance: NotchPageAppearance
    var order: [NotchControlItem]
    var hidden: Set<String>

    init(appearance: NotchPageAppearance, order: [NotchControlItem], hidden: Set<String>) {
        self.appearance = appearance
        var seen = Set<NotchControlItem>()
        self.order = (order + NotchControlItem.allCases).filter { seen.insert($0).inserted }
        self.hidden = hidden
    }
    static func stored(in defaults: UserDefaults = .standard) -> Self {
        .init(appearance: .stored(in: defaults),
              order: (defaults.string(forKey: DefaultsKey.notchControlOrder) ?? "").split(separator: ",").compactMap { NotchControlItem(rawValue: String($0)) },
              hidden: Set((defaults.string(forKey: DefaultsKey.notchHiddenControls) ?? NotchControlItem.defaultHidden).split(separator: ",").map(String.init)))
    }
    func visible(available: Set<NotchControlItem>) -> [NotchControlItem] {
        order.filter { available.contains($0) && !hidden.contains($0.rawValue) }
    }
    func save(in defaults: UserDefaults = .standard) {
        var merged = NotchPageAppearance.stored(in: defaults)
        merged.reset("controls.")
        merged.values.merge(appearance.values.filter { $0.key.hasPrefix("controls.") }) { _, value in value }
        defaults.set(merged.encoded, forKey: NotchPageAppearance.storageKey)
        defaults.set(order.map(\.rawValue).joined(separator: ","), forKey: DefaultsKey.notchControlOrder)
        defaults.set(hidden.sorted().joined(separator: ","), forKey: DefaultsKey.notchHiddenControls)
    }
    mutating func tidy(available: Set<NotchControlItem>) {
        appearance.values["controls.custom"] = "true"
        appearance.values["controls.centerRows"] = "true"
        let items = visible(available: available), shortcuts = items.filter { !$0.isLevel && $0 != .music }
        order = items.filter { $0.isLevel || $0 == .music } + shortcuts + order.filter { !items.contains($0) }
        for item in items {
            let key = appearance.controlKey(item)
            appearance.values[key + "column"] = "0"
            appearance.values[key + "newRow"] = "false"
            appearance.values[key + "span"] = item.isLevel || item == .music ? "6" : "1"
            appearance.values[key + "width"] = "100"
            appearance.values[key + "alignment"] = "center"
            if item.isLevel { appearance.values[key + "height"] = "36" }
        }
    }
    mutating func drop(_ item: NotchControlItem, center: CGPoint, width: CGFloat, available: Set<NotchControlItem>) {
        let slots = appearance.controlSlots(visible(available: available), width: width)
        guard let source = slots.first(where: { $0.item == item }) else { return }
        let others = slots.filter { $0.item != item }
        func distance(_ frame: CGRect) -> CGFloat {
            let dx = max(frame.minX - center.x, 0, center.x - frame.maxX)
            let dy = max(frame.minY - center.y, 0, center.y - frame.maxY)
            return dx * dx + dy * dy
        }
        if let target = others.min(by: { distance($0.frame) < distance($1.frame) }) {
            order.removeAll { $0 == item }
            let sharedRow = abs(source.frame.minY - target.frame.minY) < 1
            let after = sharedRow && target.frame.contains(center) ? center.x > target.frame.midX : center.y > target.frame.midY
            let index = order.firstIndex(of: target.item) ?? order.endIndex
            order.insert(item, at: min(order.endIndex, index + (after ? 1 : 0)))
        }
        let grid = appearance.controlGrid(width: width)
        let span = max(1, min(grid.columns, Int(((source.frame.width + grid.gap) / (grid.cell + grid.gap)).rounded())))
        let column = min(grid.columns - span, max(0, Int(((center.x - source.frame.width / 2 - grid.padding) / (grid.cell + grid.gap)).rounded())))
        let key = appearance.controlKey(item)
        appearance.values[key + "column"] = String(column + 1)
        // A narrow control inside a full-width row snaps to the same three
        // anchors as its siblings rather than silently ignoring a horizontal drag.
        let contentWidth = appearance.controlContentWidth(item, slotWidth: source.frame.width)
        if contentWidth < source.frame.width - 1 {
            let fraction = (center.x - grid.padding) / max(1, width - grid.padding * 2)
            appearance.values[key + "alignment"] = fraction < 0.4 ? "left" : fraction > 0.6 ? "right" : "center"
        }
        appearance.values[key + "newRow"] = "false"
    }
    mutating func resize(_ item: NotchControlItem, from rect: CGRect, translation: CGSize, width: CGFloat) {
        let grid = appearance.controlGrid(width: width), key = appearance.controlKey(item)
        let desired = min(max(72, width - grid.padding * 2), max(72, rect.width + translation.width))
        let minimumWidth: CGFloat = item == .music ? 240 : item.isLevel ? 140 : 64
        let safeSpan = max(1, Int(ceil((minimumWidth + grid.gap) / (grid.cell + grid.gap))))
        let span = min(grid.columns, max(safeSpan, Int(ceil((desired + grid.gap) / (grid.cell + grid.gap)))))
        let slotWidth = CGFloat(span) * grid.cell + CGFloat(span - 1) * grid.gap
        appearance.values[key + "span"] = String(span)
        appearance.values[key + "width"] = String(Double(min(100, max(40, desired / slotWidth * 100))))
        appearance.values[key + "height"] = String(Double(min(260, max(36, ((rect.height + translation.height) / 4).rounded() * 4))))
    }
}

final class NotchControlsEditor: ObservableObject {
    static let shared = NotchControlsEditor()
    @Published private(set) var draft: NotchControlsDocument?
    @Published var selection: NotchControlItem?
    private var undoStack: [NotchControlsDocument] = []
    private var redoStack: [NotchControlsDocument] = []
    private var gestureStart: NotchControlsDocument?
    var available = Set<NotchControlItem>()
    enum Focus: Hashable {
        case cancel, undo, arrange, add, done, control(NotchControlItem), appearance
        case iconDecrease, iconIncrease, textDecrease, textIncrease
    }
    @Published var keyboardFocus: Focus?
    var canvasHasFocus: Bool {
        get { if case .control = keyboardFocus { return true }; return false }
        set { if newValue, let selection { keyboardFocus = .control(selection) } else if canvasHasFocus { keyboardFocus = nil } }
    }
    var focusOrder: [Focus] {
        var result: [Focus] = [.cancel]
        if canUndo { result.append(.undo) }
        result += [.arrange, .add, .done] + items.map { .control($0) }
        if let selection, items.contains(selection), let draft {
            result.append(.appearance)
            if selection != .music {
                let style = draft.appearance.controlStyle(selection)
                if style.glyph > 10 { result.append(.iconDecrease) }
                if style.glyph < 32 { result.append(.iconIncrease) }
                if style.font > 9 { result.append(.textDecrease) }
                if style.font < 16 { result.append(.textIncrease) }
            }
        }
        return result
    }
    func cycleFocus(backwards: Bool) {
        let order = focusOrder
        let index = keyboardFocus.flatMap { order.firstIndex(of: $0) } ?? (backwards ? 0 : -1)
        keyboardFocus = order[(index + (backwards ? -1 : 1) + order.count) % order.count]
        if case let .control(item) = keyboardFocus { selection = item }
    }
    private var popupMenus = Set<ObjectIdentifier>()
    var trackingPopup: Bool { !popupMenus.isEmpty }
    func beginPopup(_ menu: AnyObject) { popupMenus.insert(ObjectIdentifier(menu)) }
    func endPopup(_ menu: AnyObject) { popupMenus.remove(ObjectIdentifier(menu)) }
    var onChange: (() -> Void)?
    var isEditing: Bool { draft != nil }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var items: [NotchControlItem] { draft?.visible(available: available) ?? [] }
    func start(_ document: NotchControlsDocument, available: Set<NotchControlItem>) {
        guard !isEditing else { return }
        self.available = available
        var next = document
        if !next.appearance.controlsCustom { next.tidy(available: available) }
        next.appearance.values["controls.custom"] = "true"
        undoStack = []; redoStack = []; gestureStart = nil
        selection = next.visible(available: available).first
        draft = next
        onChange?()
    }
    func change(_ mutation: (inout NotchControlsDocument) -> Void) {
        guard var next = draft else { return }
        let previous = next; mutation(&next)
        guard next != previous else { return }
        undoStack.append(previous); undoStack = Array(undoStack.suffix(40)); redoStack = []
        draft = next; onChange?()
    }
    func beginGesture() { if gestureStart == nil { gestureStart = draft } }
    func updateGesture(_ mutation: (inout NotchControlsDocument) -> Void) {
        guard var next = gestureStart else { return }
        mutation(&next); draft = next; onChange?()
    }
    func endGesture() {
        if let start = gestureStart, start != draft {
            undoStack.append(start); undoStack = Array(undoStack.suffix(40)); redoStack = []
        }
        gestureStart = nil; objectWillChange.send()
    }
    func undo() {
        guard let previous = undoStack.popLast(), let current = draft else { return }
        redoStack.append(current); draft = previous; onChange?()
    }
    func redo() {
        guard let next = redoStack.popLast(), let current = draft else { return }
        undoStack.append(current); draft = next; onChange?()
    }
    func move(_ item: NotchControlItem, backwards: Bool) {
        let visible = items
        guard let index = visible.firstIndex(of: item) else { return }
        let next = index + (backwards ? -1 : 1)
        guard visible.indices.contains(next) else { return }
        let target = visible[next]
        change { document in
            document.order.removeAll { $0 == item }
            let targetIndex = document.order.firstIndex(of: target)!
            document.order.insert(item, at: targetIndex + (backwards ? 0 : 1))
            let key = document.appearance.controlKey(item)
            document.appearance.values[key + "column"] = "0"
            document.appearance.values[key + "newRow"] = "false"
        }
    }
    func resizeSelected(width: CGFloat, dx: CGFloat, dy: CGFloat) {
        guard let item = selection, let document = draft,
              let slot = document.appearance.controlSlots(items, width: width).first(where: { $0.item == item }) else { return }
        let rect = document.appearance.controlContentRect(slot)
        change { $0.resize(item, from: rect, translation: CGSize(width: dx, height: dy), width: width) }
    }
    func stop() {
        keyboardFocus = nil; popupMenus.removeAll()
        onChange = nil; gestureStart = nil; undoStack = []; redoStack = []
        draft = nil; selection = nil
    }
}

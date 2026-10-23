// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors

import Foundation

enum NotchHeaderPosition: String, CaseIterable, Codable {
    case leftOuter, leftInner, rightInner, rightOuter

    static func resolved(_ raw: String) -> Self { Self(rawValue: raw) ?? .leftOuter }

    /// Player/capture pages own the leading camera wing. Their shortcuts
    /// share the other wing instead of overlaying the page or the camera.
    func effective(wrapsCamera: Bool) -> Self {
        guard wrapsCamera else { return self }
        return self == .leftOuter ? .rightOuter : self == .leftInner ? .rightInner : self
    }

    func title(_ text: NotchNetworkStrings) -> String {
        switch self {
        case .leftOuter: text.headerLeftOuter
        case .leftInner: text.headerLeftInner
        case .rightInner: text.headerRightInner
        case .rightOuter: text.headerRightOuter
        }
    }
}

struct NotchHeaderButton: Codable, Equatable, Identifiable {
    var id = UUID()
    var actionID: String
    var position: NotchHeaderPosition
    var label = ""
    var action: NotchQuickAction? { .init(id: actionID) }
}

/// Four editable anchors live in the camera-safe header wings. Floating
/// left/right/bottom shortcuts have their own configuration and are untouched.
struct NotchHeaderConfiguration: Codable, Equatable {
    var buttons: [NotchHeaderButton] = []

    func sanitized() -> Self {
        var ids = Set<UUID>()
        var positions = Set<NotchHeaderPosition>()
        return Self(buttons: buttons.prefix(32).compactMap { button in
            guard button.action != nil, ids.insert(button.id).inserted,
                  positions.insert(button.position).inserted else { return nil }
            var safe = button
            safe.label = NotchNetworkPresetLibrary.cleanName(button.label)
            return safe
        })
    }
    var encoded: Data { (try? JSONEncoder().encode(sanitized())) ?? Data() }
    func button(at position: NotchHeaderPosition) -> NotchHeaderButton? { buttons.first { $0.position == position } }
    mutating func set(_ action: NotchQuickAction, at position: NotchHeaderPosition) {
        if let index = buttons.firstIndex(where: { $0.position == position }) { buttons[index].actionID = action.id }
        else { buttons.append(.init(actionID: action.id, position: position)) }
    }
    mutating func move(_ id: UUID, to position: NotchHeaderPosition) {
        guard let index = buttons.firstIndex(where: { $0.id == id }) else { return }
        let old = buttons[index].position
        if let other = buttons.firstIndex(where: { $0.position == position && $0.id != id }) { buttons[other].position = old }
        buttons[index].position = position
    }
    static func decoded(_ data: Data) -> Self? {
        guard !data.isEmpty, data.count <= 32_768,
              let value = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
        return value.sanitized()
    }
    static func stored(in defaults: UserDefaults = .standard) -> Self {
        if let data = defaults.data(forKey: DefaultsKey.notchHeaderLayout), let value = decoded(data) { return value }
        var initial = Self()
        initial.set(.networkReadout, at: .resolved(defaults.string(forKey: DefaultsKey.notchHeaderNetworkPosition) ?? "leftOuter"))
        initial.buttons[0].id = UUID(uuidString: "00000000-0000-4000-9000-000000000001")!
        if let settings = defaults.string(forKey: DefaultsKey.notchHeaderSettingsPosition), settings != "hidden" {
            let wanted = NotchHeaderPosition.resolved(settings)
            let position = initial.button(at: wanted) == nil ? wanted : NotchHeaderPosition.allCases.first { initial.button(at: $0) == nil }!
            initial.set(.settings, at: position)
            initial.buttons[1].id = UUID(uuidString: "00000000-0000-4000-9000-000000000002")!
        }
        return initial
    }
}

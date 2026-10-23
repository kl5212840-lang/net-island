// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors

import SwiftUI

struct NotchHeaderSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchHeaderSettingsPosition) private var settings = "hidden"
    @AppStorage(DefaultsKey.notchHeaderNetworkPosition) private var network = "leftOuter"
    @AppStorage(DefaultsKey.notchHeaderNetworkIconOnly) private var iconOnly = false
    private var text: NotchNetworkStrings { .init(l10n.language) }

    var body: some View {
        SettingsCard(title: text.headerTitle) {
            Toggle(text.headerSettings, isOn: Binding(get: { settings != "hidden" }, set: { settings = $0 ? "rightOuter" : "hidden" }))
            if settings != "hidden" {
                positionPicker(text.headerSettingsPosition, selection: $settings)
            }
            positionPicker(text.headerNetworkPosition, selection: $network)
            Toggle(text.headerIconOnly, isOn: $iconOnly)
            Text(text.headerHint).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func positionPicker(_ title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            ForEach(NotchHeaderPosition.allCases, id: \.rawValue) { position in
                Text(position.title(text)).tag(position.rawValue)
            }
        }.pickerStyle(.menu)
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors

import SwiftUI

struct NotchNavigationSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchNavigationPosition) private var position = "top"
    private var chinese: Bool { NotchNetworkStrings(l10n.language).chinese }

    var body: some View {
        SettingsCard(title: chinese ? "分区切换" : "Section navigation") {
            VStack(alignment: .leading, spacing: 10) {
                Text(chinese ? "两侧箭头位置" : "Side arrow position").font(.callout)
                Picker(chinese ? "两侧箭头位置" : "Side arrow position", selection: Binding(
                    get: { NotchNavigationPosition.resolved(position).rawValue }, set: { position = $0 }
                )) {
                    Text(chinese ? "上方" : "Top").tag("top")
                    Text(chinese ? "居中" : "Middle").tag("center")
                    Text(chinese ? "下方" : "Bottom").tag("bottom")
                }
                .pickerStyle(.segmented).labelsHidden()
                Text(chinese ? "左右箭头按勾选的分区顺序循环切换。仅显示一个分区时，箭头自动隐藏。" : "Arrows cycle through checked sections in order. They hide when only one section is available.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

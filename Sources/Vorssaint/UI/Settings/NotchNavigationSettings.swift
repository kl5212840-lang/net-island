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

struct NotchSystemLayoutSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchSystemLayout) private var layout = "original"
    private var chinese: Bool { NotchNetworkStrings(l10n.language).chinese }

    var body: some View {
        SettingsCard(title: chinese ? "系统卡片布局" : "System card layout") {
            VStack(alignment: .leading, spacing: 10) {
                Picker(chinese ? "排列方式" : "Arrangement", selection: Binding(
                    get: { NotchSystemLayout.resolved(layout).rawValue }, set: { layout = $0 }
                )) {
                    Text(chinese ? "原版排列" : "Original arrangement").tag("original")
                    Text(chinese ? "自动适应" : "Fit available width").tag("adaptive")
                    Text(chinese ? "双列" : "Two columns").tag("twoColumns")
                    Text(chinese ? "三列" : "Three columns").tag("threeColumns")
                }
                .pickerStyle(.menu)
                Text(chinese
                     ? "默认保留原版的卡片排列，不因左右切换箭头而减少列数。自动适应按剩余宽度排列；双列、三列在空间过窄时自动减少列数。修改立即生效并保存。"
                     : "Original preserves the previous row arrangement when side arrows are shown. Fit available width adapts to the remaining space. Two or three columns use fewer columns when the island is too narrow. Changes apply immediately and are saved.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors
import SwiftUI

struct NotchNavigationSettings: View {
    var module: NotchModule = .system
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchNavigationPosition) private var position = "top"
    @AppStorage(NotchPageAppearance.storageKey) private var data = Data()
    private var chinese: Bool { NotchNetworkStrings(l10n.language).chinese }
    private var appearance: NotchPageAppearance { .init(data: data) }
    private var overrideKey: String { "nav.\(module.rawValue).override" }
    private var prefix: String { appearance.flag(overrideKey) ? "nav.\(module.rawValue)." : "nav.shared." }
    private func t(_ zh: String, _ en: String) -> String { chinese ? zh : en }
    private func set(_ key: String, _ value: String) { var next = appearance; next.values[key] = value; data = next.encoded }
    var body: some View {
        SettingsCard(title: t("分区切换", "Section navigation")) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(t("为此分区单独设置", "Use a separate layout for this section"), isOn: Binding(get: { appearance.flag(overrideKey) }, set: { enabled in
                    var next = appearance
                    if enabled {
                        for key in ["position", "offset", "size", "margin"] where next.values["nav.\(module.rawValue)." + key] == nil {
                            next.values["nav.\(module.rawValue)." + key] = next.values["nav.shared." + key]
                        }
                    }
                    next.values[overrideKey] = String(enabled); data = next.encoded
                }))
                Text(appearance.flag(overrideKey) ? module.title(l10n.language) : t("当前编辑：所有分区的统一设置", "Editing the shared layout for all sections"))
                    .font(.caption).foregroundStyle(.secondary)
                Picker(t("两侧箭头位置", "Side arrow position"), selection: Binding(get: {
                    appearance.values[prefix + "position"] ?? position
                }, set: { set(prefix + "position", $0) })) {
                    Text(t("上方", "Top")).tag("top"); Text(t("居中", "Middle")).tag("center"); Text(t("下方", "Bottom")).tag("bottom")
                }.pickerStyle(.segmented).labelsHidden()
                Text(t("位置跟随当前可视内容计算：上方靠近首行，居中位于内容区中心，下方避开底部圆角。左右始终对称。", "Positions follow the visible content: Top sits beside the first row, Middle centers in the body, and Bottom clears the lower corners. Both sides remain symmetrical."))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                slider("offset", title: t("相对位置微调", "Relative position adjustment"), fallback: 0, range: -25...25, suffix: "%")
                slider("size", title: t("箭头大小", "Arrow size"), fallback: 11, range: 8...18)
                slider("margin", title: t("额外边距", "Additional side margin"), fallback: 0, range: 0...24)
                Button(t("恢复当前箭头设置", "Reset the current arrow layout")) {
                    var next = appearance; next.reset(prefix); data = next.encoded
                }
                Text(t("按已勾选分区的顺序循环切换；只有一个分区时自动隐藏。", "Cycles through checked sections in order. Hidden when only one section is available."))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.onChange(of: data) { _, _ in NotchService.shared.syncWithPreferences() }
    }
    private func slider(_ key: String, title: String, fallback: Double, range: ClosedRange<Double>, suffix: String = " pt") -> some View {
        let value = appearance.number(prefix + key, fallback, range)
        return VStack(alignment: .leading, spacing: 6) {
            HStack { Text(title); Spacer(); Text("\(Int(value.rounded()))" + suffix).monospacedDigit().foregroundStyle(.secondary) }
            Slider(value: Binding(get: { Double(value) }, set: { set(prefix + key, String($0)) }), in: range, step: 1).labelsHidden().accessibilityLabel(title)
        }.font(.callout)
    }
}

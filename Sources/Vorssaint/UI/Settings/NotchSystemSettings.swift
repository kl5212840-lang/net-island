// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors

import SwiftUI

extension NotchSystemMetric: PanelOrderItem {
    var kind: MetricDetailKind { MetricDetailKind(rawValue: rawValue)! }
}

struct NotchSystemLayoutSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @AppStorage(DefaultsKey.notchSystemLayout) private var layout = "original"
    @AppStorage(DefaultsKey.notchSystemCardScale) private var cardScale = 1.0
    @AppStorage(DefaultsKey.notchSystemHorizontalSpacing) private var horizontalSpacing = 10.0
    @AppStorage(DefaultsKey.notchSystemVerticalSpacing) private var verticalSpacing = 10.0
    @AppStorage(DefaultsKey.notchSystemMetricOrder) private var metricOrder = ""
    @AppStorage(DefaultsKey.notchSystemHiddenMetrics) private var hiddenMetrics = ""
    @State private var dragging: NotchSystemMetric?
    private var chinese: Bool { NotchNetworkStrings(l10n.language).chinese }
    private var configuration: NotchSystemConfiguration { .init(order: metricOrder, hidden: hiddenMetrics) }
    private var style: NotchSystemStyle {
        .init(scale: cardScale, horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing)
    }
    private var orderedMetrics: Binding<[NotchSystemMetric]> {
        Binding(get: { configuration.order }, set: { metricOrder = $0.map(\.rawValue).joined(separator: ",") })
    }

    var body: some View {
        SettingsCard(title: chinese ? "系统卡片布局" : "System card layout") {
            VStack(alignment: .leading, spacing: 14) {
                Picker(chinese ? "排列方式" : "Arrangement", selection: Binding(
                    get: { NotchSystemLayout.resolved(layout).rawValue }, set: { layout = $0 }
                )) {
                    Text(chinese ? "原版排列" : "Original arrangement").tag("original")
                    Text(chinese ? "自动适应" : "Fit available width").tag("adaptive")
                    Text(chinese ? "双列" : "Two columns").tag("twoColumns")
                    Text(chinese ? "三列" : "Three columns").tag("threeColumns")
                }.pickerStyle(.menu)
                Text(chinese
                     ? "默认保留原版排列。卡片放大或空间过窄时会减少列数，内容超出高度时仍可滚动。"
                     : "Original preserves the previous arrangement. Larger cards or narrow islands use fewer columns. Overflowing content remains scrollable.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Divider()
                slider(chinese ? "卡片大小" : "Card size", value: $cardScale, range: 0.8...1.35, step: 0.05,
                       label: "\(Int((style.scale * 100).rounded()))%")
                Text(chinese ? "同步调整卡片高度和字体；宽度随列数适配。" : "Scales card height and type. Width fits the selected columns.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                slider(chinese ? "水平间距" : "Horizontal spacing", value: $horizontalSpacing, range: 4...24, step: 1,
                       label: "\(Int(style.horizontalSpacing)) pt")
                slider(chinese ? "垂直间距" : "Vertical spacing", value: $verticalSpacing, range: 4...24, step: 1,
                       label: "\(Int(style.verticalSpacing)) pt")
                Divider()
                Text(chinese ? "显示指标与顺序" : "Readings and order").font(.callout.weight(.medium))
                Text(chinese ? "勾选显示，拖动或用上下箭头排序。仅显示已启用且硬件支持的指标；隐藏只影响岛上的卡片。"
                     : "Choose readings, then drag or use the arrows to reorder. Only enabled, hardware-supported readings appear. Hiding affects island cards only.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 0) {
                    ForEach(configuration.order) { metric in
                        PanelReorderableItem(item: metric, order: orderedMetrics, dragging: $dragging) {
                            metricRow(metric)
                        }
                    }
                }
                Divider()
                HStack {
                    Button(chinese ? "恢复系统卡片默认设置" : "Restore System card defaults", action: reset)
                    Spacer(minLength: 0)
                }
                Text(chinese ? "默认大小为 100%，间距为 10 pt。更改立即生效并保存，预览同步更新。"
                     : "Defaults: 100% size and 10 pt gaps. Changes apply immediately, are saved, and update the preview.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func title(_ metric: NotchSystemMetric) -> String {
        metric == .disk ? (chinese ? "可用空间" : "Available storage") : metric.kind.title(l10n.s)
    }

    private func metricRow(_ metric: NotchSystemMetric) -> some View {
        HStack(spacing: 8) {
            PanelDragHandle()
            Toggle(isOn: Binding(get: { !configuration.hidden.contains(metric) }, set: { visible in
                var hidden = configuration.hidden
                if visible { hidden.remove(metric) } else { hidden.insert(metric) }
                hiddenMetrics = NotchSystemMetric.allCases.filter { hidden.contains($0) }.map(\.rawValue).joined(separator: ",")
            })) {
                Label(title(metric), systemImage: metric.kind.symbolName).lineLimit(1)
            }
            .toggleStyle(.checkbox)
            .disabled(!metric.feature.isAvailable)
            if !metric.feature.isAvailable {
                Text(chinese ? "功能未启用" : "Not enabled").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            moveButton(metric, up: true)
            moveButton(metric, up: false)
        }
        .font(.callout).padding(.vertical, 5)
        .accessibilityElement(children: .contain)
    }

    private func moveButton(_ metric: NotchSystemMetric, up: Bool) -> some View {
        let index = configuration.order.firstIndex(of: metric) ?? 0
        let disabled = up ? index == 0 : index == configuration.order.count - 1
        let action = up ? (chinese ? "上移" : "Move up") : (chinese ? "下移" : "Move down")
        return Button {
            var order = configuration.order
            let destination = index + (up ? -1 : 1)
            guard order.indices.contains(destination) else { return }
            order.swapAt(index, destination)
            orderedMetrics.wrappedValue = order
        } label: {
            Image(systemName: up ? "chevron.up" : "chevron.down")
                .font(.system(size: 10, weight: .semibold)).frame(width: 22, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(disabled)
        .help(action + " " + title(metric)).accessibilityLabel(action + " " + title(metric))
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Text(title); Spacer(); Text(label).monospacedDigit().foregroundStyle(.secondary) }.font(.callout)
            Slider(value: Binding(get: {
                value.wrappedValue.isFinite ? min(range.upperBound, max(range.lowerBound, value.wrappedValue))
                    : (range.contains(1) ? 1 : 10)
            }, set: { value.wrappedValue = $0 }), in: range, step: step)
                .labelsHidden().accessibilityLabel(title)
        }
    }

    private func reset() {
        layout = "original"; cardScale = 1; horizontalSpacing = 10; verticalSpacing = 10
        metricOrder = ""; hiddenMetrics = ""
    }
}

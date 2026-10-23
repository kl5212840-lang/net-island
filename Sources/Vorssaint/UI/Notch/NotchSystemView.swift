// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

struct NotchSystemView: View {
    let size: CGSize
    var originalWidth: CGFloat? = nil
    let select: (MetricDetailKind) -> Void
    @ObservedObject private var monitor = SystemMonitor.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.networkSpeedUnit) private var networkSpeedUnit = NetworkSpeedUnit.bytes
    @AppStorage(DefaultsKey.notchSystemLayout) private var systemLayout = "original"
    @AppStorage(DefaultsKey.notchSystemCardScale) private var cardScale = 1.0
    @AppStorage(DefaultsKey.notchSystemHorizontalSpacing) private var horizontalSpacing = 10.0
    @AppStorage(DefaultsKey.notchSystemVerticalSpacing) private var verticalSpacing = 10.0
    @AppStorage(DefaultsKey.notchSystemMetricOrder) private var metricOrder = ""
    @AppStorage(DefaultsKey.notchSystemHiddenMetrics) private var hiddenMetrics = ""
    @AppStorage(NotchPageAppearance.storageKey) private var appearanceData = Data()
    private var appearance: NotchPageAppearance { .init(data: appearanceData) }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var style: NotchSystemStyle {
        .init(scale: cardScale, horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing)
    }
    private var configuration: NotchSystemConfiguration { .init(order: metricOrder, hidden: hiddenMetrics) }

    private struct Card: Identifiable {
        let kind: MetricDetailKind
        let title: String
        let symbol: String
        let value: String?
        var detail: String? = nil
        var level: Double? = nil
        /// Set when the reading itself is the news, so the meter says so
        /// without the person having to read the number.
        var wantsAttention = false
        var id: String { kind.rawValue }
    }

    private var cards: [Card] {
        let snapshot = monitor.snapshot
        var cards: [Card] = []
        if AppFeature.monitorCPU.isAvailable {
            cards.append(Card(kind: .cpu, title: l10n.s.cpuLabel, symbol: "cpu",
                              value: percent(snapshot.cpuUsage), level: snapshot.cpuUsage,
                              wantsAttention: isBusy(snapshot.cpuUsage)))
        }
        if AppFeature.monitorGPU.isAvailable {
            cards.append(Card(kind: .gpu, title: l10n.s.gpuLabel, symbol: "rectangle.connected.to.line.below",
                              value: percent(snapshot.gpuUsage), level: snapshot.gpuUsage,
                              wantsAttention: isBusy(snapshot.gpuUsage)))
        }
        if AppFeature.monitorMemory.isAvailable {
            let ratio = snapshot.memoryUsed.flatMap { used in
                snapshot.memoryTotal.flatMap { total in total > 0 ? Double(used) / Double(total) : nil }
            }
            cards.append(Card(kind: .memory, title: l10n.s.memorySection, symbol: "memorychip",
                              value: percent(ratio), level: ratio, wantsAttention: isBusy(ratio)))
        }
        if AppFeature.monitorPower.isAvailable, let power = snapshot.power, power.hasBattery {
            cards.append(Card(kind: .battery, title: l10n.s.batteryLabel,
                              symbol: power.externalConnected ? "battery.100percent.bolt" : "battery.100percent",
                              value: power.chargePercent.map { "\($0)%" },
                              level: power.chargePercent.map { Double($0) / 100 },
                              wantsAttention: !power.externalConnected && (power.chargePercent ?? 100) <= 20))
        }
        if AppFeature.monitorNetwork.isAvailable {
            // The observed unit, so a switch redraws the card at once, not on the next sample.
            let inBits = networkSpeedUnit == .bits
            cards.append(Card(kind: .network, title: l10n.s.networkSection, symbol: "network",
                              value: snapshot.netDownBytesPerSec.map { "↓ " + MetricFormat.networkRate($0, inBits: inBits) },
                              detail: snapshot.netUpBytesPerSec.map { "↑ " + MetricFormat.networkRate($0, inBits: inBits) }))
        }
        if AppFeature.monitorDisk.isAvailable {
            let disk = snapshot.disk?.devices.first(where: { $0.mountPath == "/" })
                ?? snapshot.disk?.devices.first(where: \.isInternal)
            cards.append(Card(kind: .disk, title: l10n.s.diskAvailable.localizedCapitalized, symbol: "internaldrive",
                              value: disk.map { MetricFormat.diskBytes($0.freeBytes) },
                              level: disk.map { 1 - $0.usedFraction },
                              wantsAttention: disk.map { 1 - $0.usedFraction < 0.1 } ?? false))
        }
        // The panel's power and fan sections, as cards opening the same details.
        if AppFeature.monitorPower.isAvailable {
            let power = snapshot.power
            cards.append(Card(kind: .power, title: l10n.s.powerSection, symbol: "powerplug.fill",
                              value: power?.systemWatts.map(MetricFormat.wattsCompact),
                              detail: power?.externalConnected == true ? power?.adapterWatts.map(MetricFormat.watts) : nil))
        }
        if AppFeature.fanControl.isAvailable, !snapshot.fanSpeeds.isEmpty {
            let strings = FeatureStrings.fanControl(l10n.language)
            cards.append(Card(kind: .fan, title: strings.title, symbol: "fanblades",
                              value: snapshot.fanSpeeds.first.map { String(format: strings.rpmFormat, Int($0.rounded())) }))
        }
        if AppFeature.connectedDevices.isAvailable {
            let strings = FeatureStrings.connectedDevices(l10n.language)
            cards.append(Card(kind: .connectedDevices, title: strings.title, symbol: "cable.connector",
                              value: "\(snapshot.connectedDevices.count)"))
        }
        let readings = Dictionary(uniqueKeysWithValues: cards.map { ($0.kind.rawValue, $0) })
        return configuration.order.filter { !configuration.hidden.contains($0) }.compactMap { readings[$0.rawValue] }
    }

    private func isBusy(_ level: Double?) -> Bool {
        guard let level, level.isFinite else { return false }
        return level >= 0.85
    }

    var body: some View {
        let cards = cards
        if cards.isEmpty {
            let chinese = NotchNetworkStrings(l10n.language).chinese
            NotchEmptyView(symbol: "gauge.with.dots.needle.50percent",
                           message: chinese ? "没有可显示的系统指标" : "No System readings to show") {
                Button(chinese ? "选择指标" : "Choose readings") { NotchService.shared.openSettings(showing: .system) }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
        } else {
            let inset = NotchLayout.systemHoverInset(width: size.width)
            let rows = NotchSystemLayout.resolved(systemLayout).rows(count: cards.count, width: size.width,
                                                                    originalWidth: originalWidth ?? size.width, style: style)
            let height = NotchLayout.railHeight(rows: rows.count, rowHeight: style.cardHeight,
                                               spacing: style.verticalSpacing) + inset * 2
            Group {
                if height > size.height {
                    NotchSystemScrollView {
                        grid(cards: cards, rows: rows)
                            .frame(width: max(0, size.width - inset * 2))
                            .padding(inset)
                            .contentShape(Rectangle())
                    }
                    .frame(width: size.width, height: size.height)
                    .notchScrollEdgeFade(length: 12)
                } else {
                    grid(cards: cards, rows: rows).padding(inset)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func grid(cards: [Card], rows: [Range<Int>]) -> some View {
        VStack(spacing: style.verticalSpacing) {
            ForEach(rows, id: \.lowerBound) { row in
                HStack(spacing: style.horizontalSpacing) {
                    ForEach(Array(cards[row])) { card in
                        cardButton(card)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func cardButton(_ card: Card) -> some View {
        Button { select(card.kind) } label: {
            VStack(alignment: .leading, spacing: 6 * style.scale) {
                Label(card.title, systemImage: card.symbol)
                    .font(.system(size: 10 * style.scale * appearance.systemFontScale, weight: .medium))
                    .foregroundStyle(.secondary).lineLimit(1)
                Text(card.value ?? "…")
                    .font(.system(size: (card.detail == nil ? 22 : 15) * style.scale * appearance.systemFontScale, weight: .medium, design: .rounded))
                    .monospacedDigit().contentTransition(.numericText()).lineLimit(1).minimumScaleFactor(0.75)
                    .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: card.value)
                if let detail = card.detail {
                    Text(detail).font(.system(size: 11 * style.scale * appearance.systemFontScale)).monospacedDigit().foregroundStyle(.secondary).lineLimit(1)
                } else if let level = card.level, appearance.systemMeters {
                    NotchMeter(value: level, height: 5 * style.scale, tint: meterTint(attention: card.wantsAttention))
                }
            }
            .padding(.horizontal, appearance.systemPadding * style.scale)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: style.cardHeight)
            .modifier(NotchControlSurface(cornerRadius: 18 * style.scale))
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: 18 * style.scale))
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { select(card.kind) }
        .accessibilityLabel(card.title)
        .accessibilityValue([card.value, card.detail].compactMap { $0 }.joined(separator: ", "))
    }

    private func meterTint(attention: Bool) -> Color {
        // Warnings retain their semantic contrast regardless of decoration.
        if attention { return .orange }
        switch appearance.systemTint {
        case "accent": return .accentColor
        case "cyan": return .cyan
        case "green": return .green
        case "custom":
            let rgb = MenuBarUsageBarSupport.rgb(for: appearance.values["system.color"] ?? "73F2FF", fallback: "73F2FF")
            return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
        default: return .white
        }
    }

    private func percent(_ value: Double?) -> String? {
        value.flatMap { $0.isFinite ? "\(Int((min(1, max(0, $0)) * 100).rounded()))%" : nil }
    }
}

/// SwiftUI's legacy-scroller bridge can enlarge its native viewport by one
/// scroller width even after indicators are hidden. Own this small vertical
/// viewport so its document is always exactly as wide as the visible area.
private struct NotchSystemScrollView<Content: View>: NSViewRepresentable {
    @ViewBuilder let content: Content

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.scrollerStyle = .overlay
        scroll.hasVerticalScroller = false
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.automaticallyAdjustsContentInsets = false
        scroll.horizontalScrollElasticity = .none
        let host = NSHostingView(rootView: AnyView(content.environment(\.self, context.environment)))
        host.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = host
        let clip = scroll.contentView
        NSLayoutConstraint.activate([
            host.topAnchor.constraint(equalTo: clip.topAnchor),
            host.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
            host.widthAnchor.constraint(equalTo: clip.widthAnchor)
        ])
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let host = scroll.documentView as? NSHostingView<AnyView> else { return }
        host.rootView = AnyView(content.environment(\.self, context.environment))
        host.invalidateIntrinsicContentSize()
    }
}

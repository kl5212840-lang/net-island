// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors

import SwiftUI

/// The same compact rate as the menu bar, with its direction always visible.
/// A missing first sample is a dash; a measured idle connection is zero.
struct NotchNetworkReadout: View {
    let bytesPerSecond: Double?
    var upload = false
    var inBits = false
    var fontSize: CGFloat = 10
    var fullUnits = false
    var decimals = 1
    var weight: Font.Weight = .medium
    var tint = "white"
    var opacity = 0.9
    var arrowGap: CGFloat = 3
    @ObservedObject private var l10n = L10n.shared

    private var rate: Double? {
        bytesPerSecond.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
    }
    private var title: String { upload ? l10n.s.networkUpload : l10n.s.networkDownload }
    private var detail: String {
        title + ": " + NotchNetworkFormat.reading(rate, inBits: inBits, fullUnits: true, decimals: decimals)
    }

    var body: some View {
        HStack(spacing: arrowGap) {
            Image(systemName: upload ? "arrow.up" : "arrow.down")
                .font(.system(size: max(8, fontSize - 1), weight: .semibold))
            Text(NotchNetworkFormat.reading(rate, inBits: inBits, fullUnits: fullUnits, decimals: decimals))
                .font(.system(size: fontSize, weight: weight)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.85)
        }
        .foregroundStyle((tint == "direction" ? (upload ? Color(red: 0.45, green: 0.95, blue: 1) : Color(red: 0.70, green: 0.82, blue: 1)) : .white).opacity(opacity))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(detail)
        .help(detail)
    }
}

/// Only the readings observe the snapshot, so a sample does not resize or
/// animate the island. The persisted unit follows the existing Network panel.
struct NotchNetworkWing: View {
    var upload = false
    var style = NotchNetworkStyle()
    var bodyHeight: CGFloat = 24
    @ObservedObject private var monitor = SystemMonitor.shared
    @AppStorage(DefaultsKey.networkSpeedUnit) private var unit = NetworkSpeedUnit.bytes

    var body: some View {
        NotchNetworkReadout(bytesPerSecond: upload ? monitor.snapshot.netUpBytesPerSec : monitor.snapshot.netDownBytesPerSec,
                            upload: upload, inBits: unit == .bits, fontSize: style.fontSize, fullUnits: style.fullUnits,
                            decimals: style.decimals, weight: style.fontWeight, tint: style.tint,
                            opacity: style.opacity, arrowGap: style.arrowGap)
            .frame(maxWidth: .infinity, alignment: style.readingAlignment)
            .offset(y: style.offset(in: bodyHeight))
    }
}


/// Mounted in the open island's header, including while the readout is off.
struct NotchNetworkToggle: View {
    @ObservedObject var service: NotchService = .shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchIdleContent) private var idle = ""
    @AppStorage(DefaultsKey.notchNetworkPaused) private var paused = false
    var compact = false
    private var text: NotchNetworkStrings { .init(l10n.language) }
    private var isOn: Bool { idle == "network" && !paused && AppFeature.monitorNetwork.isAvailable }

    var body: some View {
        Button(action: service.toggleNetworkReadout) {
            HStack(spacing: 5) {
                Image(systemName: isOn ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down.circle")
                    .font(.system(size: 13, weight: .medium))
                if !compact { Text(text.quickTitle).font(.system(size: 11, weight: .medium)) }
            }
            .foregroundStyle(isOn ? .white : .white.opacity(0.65))
            .padding(.horizontal, compact ? 7 : 9)
            .frame(height: 26)
            .background(.white.opacity(isOn ? 0.16 : 0.06), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: 13, lifts: false))
        .disabled(!AppFeature.monitorNetwork.isAvailable)
        .help(text.quickHint)
        .accessibilityLabel(text.title)
        .accessibilityValue(isOn ? text.on : text.off)
        .accessibilityIdentifier("notch.network.toggle")
    }
}

extension NotchNetworkStyle {
    var fontWeight: Font.Weight { weight == "bold" ? .bold : (weight == "regular" ? .regular : .medium) }
    var readingAlignment: Alignment { alignment == "leading" ? .leading : (alignment == "trailing" ? .trailing : .center) }
}

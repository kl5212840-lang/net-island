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
    var downloadColor = "B3D1FF"
    var uploadColor = "73F2FF"
    var colorScope = "all"
    @ObservedObject private var l10n = L10n.shared

    private var rate: Double? {
        bytesPerSecond.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
    }
    private var title: String { upload ? l10n.s.networkUpload : l10n.s.networkDownload }
    private var detail: String {
        title + ": " + NotchNetworkFormat.reading(rate, inBits: inBits, fullUnits: true, decimals: decimals)
    }

    private var directionColor: Color {
        if tint == "custom" {
            let rgb = MenuBarUsageBarSupport.rgb(for: upload ? uploadColor : downloadColor, fallback: "FFFFFF")
            return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
        }
        if tint == "direction" { return upload ? Color(red: 0.45, green: 0.95, blue: 1) : Color(red: 0.70, green: 0.82, blue: 1) }
        return .white
    }

    var body: some View {
        HStack(spacing: arrowGap) {
            Image(systemName: upload ? "arrow.up" : "arrow.down")
                .font(.system(size: max(8, fontSize - 1), weight: .semibold))
                .foregroundStyle(directionColor.opacity(opacity))
            Text(NotchNetworkFormat.reading(rate, inBits: inBits, fullUnits: fullUnits, decimals: decimals))
                .font(.system(size: fontSize, weight: weight)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.85)
                .foregroundStyle((colorScope == "arrows" ? Color.white : directionColor).opacity(opacity))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(detail)
        .help(detail)
    }
}

/// Readings observe samples directly; the service grows a deliberately narrow
/// island when necessary and delays shrinking to avoid per-sample jitter.
struct NotchNetworkWing: View {
    var upload = false
    var leadingSide = true
    var style = NotchNetworkStyle()
    var bodyHeight: CGFloat = 24
    @ObservedObject private var monitor = SystemMonitor.shared
    @AppStorage(DefaultsKey.networkSpeedUnit) private var unit = NetworkSpeedUnit.bytes

    var body: some View {
        GeometryReader { proxy in
            let rate = upload ? monitor.snapshot.netUpBytesPerSec : monitor.snapshot.netDownBytesPerSec
            let reading = NotchNetworkFormat.reading(rate, inBits: unit == .bits, fullUnits: style.fullUnits, decimals: style.decimals)
            let size = style.fittedFontSize(reading: reading, available: max(0, proxy.size.width - style.outerSpacing - style.innerSpacing))
            NotchNetworkReadout(bytesPerSecond: rate, upload: upload, inBits: unit == .bits,
                                fontSize: size, fullUnits: style.fullUnits, decimals: style.decimals,
                                weight: style.fontWeight, tint: style.tint, opacity: style.opacity, arrowGap: style.arrowGap,
                                downloadColor: style.downloadColor, uploadColor: style.uploadColor, colorScope: style.colorScope)
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: style.readingAlignment(leadingSide: leadingSide))
                .padding(.leading, leadingSide ? style.outerSpacing : style.innerSpacing)
                .padding(.trailing, leadingSide ? style.innerSpacing : style.outerSpacing)
                .offset(y: style.offset(in: bodyHeight))
        }
        .frame(height: bodyHeight)
    }
}


/// Mounted in the open island's header, including while the readout is off.
struct NotchNetworkToggle: View {
    @ObservedObject var service: NotchService = .shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchIdleContent) private var idle = ""
    @AppStorage(DefaultsKey.notchNetworkPaused) private var paused = false
    @AppStorage(DefaultsKey.notchNetworkPresets) private var presetsData = Data()
    @AppStorage(DefaultsKey.notchHeaderNetworkIconOnly) private var iconOnly = false
    var compact = false
    var customTitle = ""
    var leadingSide = true
    private var isCompact: Bool { compact || iconOnly }
    private var text: NotchNetworkStrings { .init(l10n.language) }
    private var isOn: Bool { idle == "network" && !paused && AppFeature.monitorNetwork.isAvailable }

    var body: some View {
        Button(action: service.toggleNetworkReadout) {
            HStack(spacing: 5) {
                Image(systemName: isOn ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down.circle")
                    .font(.system(size: 13, weight: .medium))
                if !isCompact { Text(customTitle.isEmpty ? text.quickTitle : customTitle).font(.system(size: 11, weight: .medium)).lineLimit(1) }
            }
            .foregroundStyle(isOn ? .white : .white.opacity(0.65))
            .padding(.horizontal, isCompact ? (compact ? 5 : 7) : 9)
            .frame(width: isCompact ? (compact ? 24 : 28) : nil, height: isCompact ? 28 : 26)
            .background(.white.opacity(isCompact ? 0 : (isOn ? 0.16 : 0.06)), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: 13, lifts: false))
        .disabled(!AppFeature.monitorNetwork.isAvailable)
        .notchFastHelp((customTitle.isEmpty ? text.title : customTitle) + " · " + (isOn ? text.on : text.off), leadingSide: leadingSide)
        .accessibilityHint(text.quickHint)
        .accessibilityLabel(customTitle.isEmpty ? text.title : customTitle)
        .accessibilityValue(isOn ? text.on : text.off)
        .accessibilityIdentifier("notch.network.toggle")
        .contextMenu {
            let saved = NotchNetworkPresetLibrary(data: presetsData).presets
            ForEach(saved) { preset in
                Button(preset.name) { preset.apply(); service.syncWithPreferences() }
            }
            if !saved.isEmpty { Divider() }
            Button(l10n.s.menuSettings, action: service.openSettings)
        }
    }
}

extension NotchNetworkStyle {
    var fontWeight: Font.Weight { weight == "bold" ? .bold : (weight == "regular" ? .regular : .medium) }
    func readingAlignment(leadingSide: Bool) -> Alignment {
        let side = alignment(onLeadingSide: leadingSide)
        return side == "leading" ? .leading : (side == "trailing" ? .trailing : .center)
    }
}

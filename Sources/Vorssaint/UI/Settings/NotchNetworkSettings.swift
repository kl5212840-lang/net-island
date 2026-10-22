// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors

import SwiftUI

struct NotchNetworkSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = NotchService.shared
    @AppStorage(DefaultsKey.notchNetworkFullUnits) private var fullUnits = false
    @AppStorage(DefaultsKey.notchNetworkPaused) private var paused = false
    @AppStorage(DefaultsKey.notchNetworkFontSize) private var fontSize = 10.0
    @AppStorage(DefaultsKey.notchNetworkWidth) private var width = 72.0
    @AppStorage(DefaultsKey.notchNetworkOffset) private var offset = 0.0
    @AppStorage(DefaultsKey.notchNetworkUploadOnLeft) private var uploadOnLeft = false
    @AppStorage(DefaultsKey.notchNetworkAvoidMenus) private var avoidMenus = false
    @AppStorage(DefaultsKey.notchNetworkAutoHide) private var autoHide = false
    @AppStorage(DefaultsKey.notchNetworkThreshold) private var threshold = 1024.0
    @AppStorage(DefaultsKey.notchNetworkHideDelay) private var delay = 10.0
    @AppStorage(DefaultsKey.notchCapsuleFitDrop) private var capsuleDrop = 0.0
    @AppStorage(DefaultsKey.networkSpeedUnit) private var unit = NetworkSpeedUnit.bytes
    private var text: NotchNetworkStrings { .init(l10n.language) }
    private var style: NotchNetworkStyle { .init(fontSize: fontSize, wingWidth: width, verticalOffset: offset, uploadOnLeft: uploadOnLeft, fullUnits: fullUnits) }
    private var signature: [String] {
        [String(paused), String(fullUnits), String(fontSize), String(width), String(offset), String(uploadOnLeft),
         String(avoidMenus), String(autoHide), String(threshold), String(delay), String(capsuleDrop)]
    }

    var body: some View {
        SettingsCard(title: text.title) {
            Toggle(text.title, isOn: Binding(get: { !paused }, set: { paused = !$0 }))
                .toggleStyle(.switch).help(text.quickHint)
            Text(text.quickHint).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(text.preview).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                NotchNetworkReadout(bytesPerSecond: uploadOnLeft ? 345_678 : 1_234_567, upload: uploadOnLeft,
                                    inBits: unit == .bits, fontSize: style.fontSize, fullUnits: fullUnits)
                    .frame(width: style.wingWidth - 16)
                NotchNetworkReadout(bytesPerSecond: uploadOnLeft ? 1_234_567 : 345_678, upload: !uploadOnLeft,
                                    inBits: unit == .bits, fontSize: style.fontSize, fullUnits: fullUnits)
                    .frame(width: style.wingWidth - 16)
            }
            .offset(y: style.offset(in: 32))
            .padding(.horizontal, 16).frame(height: 32)
            .background(.black, in: Capsule())
            .frame(maxWidth: .infinity)
            .accessibilityLabel(text.chinese ? "网速布局预览，示例数据" : "Network layout preview, sample values")

            Picker(text.format, selection: $fullUnits) {
                Text(text.compact).tag(false)
                Text(text.precise).tag(true)
            }.pickerStyle(.menu)
            Picker(text.unit, selection: $unit) {
                Text(text.bytes).tag(NetworkSpeedUnit.bytes)
                Text(text.bits).tag(NetworkSpeedUnit.bits)
            }.pickerStyle(.menu)
            slider(text.font, value: $fontSize, range: 9...14, step: 1, valueText: "\(Int(style.fontSize)) pt")
            slider(text.width, value: $width, range: Double(NotchNetworkStyle.minimumWidth(fontSize: style.fontSize, fullUnits: fullUnits))...144,
                   step: 1, valueText: "\(Int(style.wingWidth)) pt")
            slider(text.offset, value: $offset, range: -3...3, step: 1, valueText: "\(Int(style.verticalOffset)) pt")
            Text(text.widthHint).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Toggle(text.uploadOnLeft, isOn: $uploadOnLeft)
            if service.geometry.floats {
                slider(text.capsuleDrop, value: $capsuleDrop, range: NotchCapsuleFit.dropRange, step: 1,
                       valueText: "\(Int(NotchCapsuleFit(width: 0, height: 0, drop: capsuleDrop).drop)) pt")
            }
            Divider()
            Toggle(text.avoidMenus, isOn: $avoidMenus)
            Text(text.avoidHint).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Toggle(text.autoHide, isOn: $autoHide)
            Text(text.autoHint).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if autoHide {
                slider(text.threshold, value: $threshold, range: 0...102_400, step: 1024,
                       valueText: MetricFormat.networkRate(threshold.isFinite ? max(0, threshold) : 1024, inBits: unit == .bits))
                slider(text.delay, value: $delay, range: 3...60, step: 1, valueText: "\(Int(delay.isFinite ? min(60, max(3, delay)) : 10)) s")
            }
            HStack {
                Spacer()
                Button(text.reset) { fontSize = 10; width = 72; offset = 0; uploadOnLeft = false }
                    .controlSize(.small)
            }
        }
        .onChange(of: fontSize) { _, _ in width = max(Double(style.wingWidth), width) }
        .onChange(of: fullUnits) { _, _ in width = max(Double(style.wingWidth), width) }
        .onChange(of: signature) { _, _ in service.syncWithPreferences() }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>,
                        step: Double, valueText: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer(minLength: 10)
                Text(valueText).monospacedDigit().foregroundStyle(.secondary)
            }.font(.callout)
            Slider(value: Binding(get: {
                let raw = value.wrappedValue
                return raw.isFinite ? min(range.upperBound, max(range.lowerBound, raw)) : range.lowerBound
            }, set: { value.wrappedValue = $0 }), in: range, step: step)
                .labelsHidden().accessibilityLabel(title)
        }
    }
}

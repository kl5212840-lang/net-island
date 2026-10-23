// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors

import SwiftUI

struct NotchNetworkSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = NotchService.shared
    @AppStorage(DefaultsKey.notchNetworkFullUnits) private var fullUnits = false
    @AppStorage(DefaultsKey.notchNetworkDecimals) private var decimals = 1
    @AppStorage(DefaultsKey.notchNetworkWeight) private var weight = "medium"
    @AppStorage(DefaultsKey.notchNetworkTint) private var tint = "white"
    @AppStorage(DefaultsKey.notchNetworkDownloadColor) private var downloadColor = "B3D1FF"
    @AppStorage(DefaultsKey.notchNetworkUploadColor) private var uploadColor = "73F2FF"
    @AppStorage(DefaultsKey.notchNetworkColorScope) private var colorScope = "all"
    @AppStorage(DefaultsKey.notchNetworkOpacity) private var opacity = 0.9
    @AppStorage(DefaultsKey.notchNetworkAlignment) private var alignment = "center"
    @AppStorage(DefaultsKey.notchNetworkArrowGap) private var arrowGap = 3.0
    @AppStorage(DefaultsKey.notchNetworkOuterSpacing) private var outerSpacing = 0.0
    @AppStorage(DefaultsKey.notchNetworkInnerSpacing) private var innerSpacing = 0.0
    @State private var appearanceExpanded: Bool
    @State private var behaviorExpanded: Bool
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
    private var style: NotchNetworkStyle { .init(fontSize: fontSize, wingWidth: width, verticalOffset: offset, uploadOnLeft: uploadOnLeft, fullUnits: fullUnits,
        decimals: decimals, weight: weight, tint: tint, opacity: opacity, alignment: alignment, arrowGap: arrowGap,
        downloadColor: downloadColor, uploadColor: uploadColor, colorScope: colorScope, outerSpacing: outerSpacing, innerSpacing: innerSpacing) }
    private var signature: [String] {
        [String(paused), String(fullUnits), String(decimals), weight, tint, downloadColor, uploadColor, colorScope, String(opacity), alignment, String(arrowGap), String(outerSpacing), String(innerSpacing), String(fontSize), String(width), String(offset), String(uploadOnLeft),
         String(avoidMenus), String(autoHide), String(threshold), String(delay), String(capsuleDrop)]
    }

    init(expandAppearance: Bool = false, expandBehavior: Bool = false) {
        _appearanceExpanded = State(initialValue: expandAppearance)
        _behaviorExpanded = State(initialValue: expandBehavior)
    }

    var body: some View {
        SettingsCard(title: text.title) {
            Toggle(text.title, isOn: Binding(get: { !paused }, set: { paused = !$0 }))
                .toggleStyle(.switch).help(text.quickHint)
            Text(text.quickHint).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(text.preview).font(.caption).foregroundStyle(.secondary)
            layoutPreview
            Text(text.previewHint).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(text.presets)
                Spacer()
                Menu(text.presets) {
                    Button(text.smallPreset) { applyPreset(0) }
                    Button(text.balancedPreset) { applyPreset(1) }
                    Button(text.clearPreset) { applyPreset(2) }
                }.fixedSize().help(text.presetHint)
            }
            Picker(text.format, selection: $fullUnits) {
                Text(text.compact).tag(false)
                Text(text.precise).tag(true)
            }.pickerStyle(.menu)
            Picker(text.unit, selection: $unit) {
                Text(text.bytes).tag(NetworkSpeedUnit.bytes)
                Text(text.bits).tag(NetworkSpeedUnit.bits)
            }.pickerStyle(.menu)
            if fullUnits {
                Picker(text.decimals, selection: $decimals) {
                    ForEach(0...2, id: \.self) { Text(String($0)).tag($0) }
                }.pickerStyle(.segmented)
            }
            DisclosureGroup(text.appearance, isExpanded: $appearanceExpanded) {
                VStack(alignment: .leading, spacing: 16) {
                    Picker(text.weight, selection: $weight) {
                        Text(text.regular).tag("regular"); Text(text.medium).tag("medium"); Text(text.bold).tag("bold")
                    }.pickerStyle(.menu)
                    Picker(text.color, selection: $tint) {
                        Text(text.white).tag("white"); Text(text.directionColor).tag("direction")
                        Text(text.customColor).tag("custom")
                    }.pickerStyle(.menu)
                    if tint == "custom" {
                        NotchNetworkColorPicker(title: text.downloadColor, hex: $downloadColor, fallback: "B3D1FF", text: text)
                        NotchNetworkColorPicker(title: text.uploadColor, hex: $uploadColor, fallback: "73F2FF", text: text)
                    }
                    if tint != "white" {
                        Picker(text.colorScope, selection: $colorScope) {
                            Text(text.colorAll).tag("all"); Text(text.colorArrows).tag("arrows")
                        }.pickerStyle(.menu)
                    }
                    slider(text.opacity, value: $opacity, range: 0.6...1, step: 0.05,
                           valueText: "\(Int((style.opacity * 100).rounded()))%")
                    if style.minimumColorContrast < (colorScope == "arrows" ? 3 : 4.5) {
                        Text(text.colorContrastHint).font(.caption).foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Picker(text.alignment, selection: $alignment) {
                        Text(text.leading).tag("leading"); Text(text.center).tag("center"); Text(text.trailing).tag("trailing")
                        Text(text.outside).tag("outside")
                    }.pickerStyle(.menu)
                    Text(text.alignmentHint).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    slider(text.outerSpacing, value: $outerSpacing, range: 0...24, step: 1, valueText: "\(Int(style.outerSpacing)) pt")
                    slider(text.innerSpacing, value: $innerSpacing, range: 0...24, step: 1, valueText: "\(Int(style.innerSpacing)) pt")
                    slider(text.gap, value: $arrowGap, range: 2...10, step: 1, valueText: "\(Int(style.arrowGap)) pt")
                    slider(text.font, value: $fontSize, range: 8...18, step: 0.5, valueText: String(format: "%g pt", Double(style.fontSize)))
                    slider(text.width, value: $width,
                           range: Double(NotchNetworkStyle.minimumWidth(fontSize: style.fontSize, fullUnits: fullUnits,
                                                                        decimals: decimals, arrowGap: arrowGap, outerSpacing: outerSpacing, innerSpacing: innerSpacing))...240,
                           step: 1, valueText: "\(Int(style.wingWidth)) pt")
                    slider(text.offset, value: $offset, range: -3...3, step: 1, valueText: "\(Int(style.verticalOffset)) pt")
                    Text(text.widthHint).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Toggle(text.uploadOnLeft, isOn: $uploadOnLeft)
                    if service.geometry.floats {
                        slider(text.capsuleDrop, value: $capsuleDrop, range: NotchCapsuleFit.dropRange, step: 1,
                               valueText: "\(Int(NotchCapsuleFit(width: 0, height: 0, drop: capsuleDrop).drop)) pt")
                    }
                }.padding(.top, 10)
            }
            Divider()
            DisclosureGroup(text.behavior, isExpanded: $behaviorExpanded) {
                VStack(alignment: .leading, spacing: 16) {
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
                }.padding(.top, 10)
            }
            HStack {
                Spacer()
                Button(text.reset) { resetAppearance() }
                    .controlSize(.small)
            }
        }
        .disclosureGroupStyle(SettingsDisclosureStyle())
        .onChange(of: style) { _, new in
            if !width.isFinite || width < Double(new.wingWidth) { width = Double(new.wingWidth) }
        }
        .onChange(of: signature) { _, _ in service.syncWithPreferences() }
    }

    private func resetAppearance() {
        fontSize = 10; width = 72; offset = 0; uploadOnLeft = false
        decimals = 1; weight = "medium"; tint = "white"; opacity = 0.9; alignment = "center"; arrowGap = 3
        outerSpacing = 0; innerSpacing = 0
        downloadColor = "B3D1FF"; uploadColor = "73F2FF"; colorScope = "all"
    }

    private func applyPreset(_ preset: Int) {
        // A size preset must not discard a palette the user just selected.
        weight = "medium"
        switch preset {
        case 0: fullUnits = false; fontSize = 9; width = 64
        case 2: fullUnits = true; fontSize = 13; width = 140; weight = "bold"
        default: fullUnits = true; fontSize = 10; width = 100
        }
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

    private var layoutPreview: some View {
        GeometryReader { proxy in
            let camera = service.geometry.floats ? 0 : service.geometry.cameraWidth
            let total = style.wingWidth * 2 + camera
            let scale = min(1, proxy.size.width / max(1, total))
            HStack(spacing: 0) {
                sample(upload: uploadOnLeft, leading: true)
                if camera > 0 {
                    Text(text.chinese ? "刘海" : "Camera")
                        .font(.system(size: 9)).foregroundStyle(.white.opacity(0.28))
                        .frame(width: camera)
                        .accessibilityHidden(true)
                }
                sample(upload: !uploadOnLeft, leading: false)
            }
            .offset(y: style.offset(in: 32))
            .frame(width: total, height: 32)
            .background(.black, in: Capsule())
            .scaleEffect(scale)
            .frame(width: proxy.size.width, height: 44)
        }
        .frame(height: 44)
        .accessibilityLabel(text.chinese ? "网速布局预览，示例数据" : "Network layout preview, sample values")
    }

    private func sample(upload: Bool, leading: Bool) -> some View {
        NotchNetworkReadout(bytesPerSecond: upload ? 345_678 : 1_234_567, upload: upload,
                            inBits: unit == .bits, fontSize: style.fontSize, fullUnits: fullUnits,
                            decimals: style.decimals, weight: style.fontWeight, tint: style.tint,
                            opacity: style.opacity, arrowGap: style.arrowGap,
                            downloadColor: style.downloadColor, uploadColor: style.uploadColor, colorScope: style.colorScope)
            .frame(maxWidth: .infinity, alignment: style.readingAlignment(leadingSide: leading))
            .padding(.leading, leading ? style.outerSpacing + 16 : style.innerSpacing)
            .padding(.trailing, leading ? style.innerSpacing : style.outerSpacing + 16)
            .frame(width: style.wingWidth)
    }
}

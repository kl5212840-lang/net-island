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
    @AppStorage(DefaultsKey.notchNetworkPresets) private var presetsData = Data()
    @State private var colorsExpanded: Bool
    @State private var appearanceExpanded: Bool
    @State private var behaviorExpanded: Bool
    @AppStorage(DefaultsKey.notchNetworkPaused) private var paused = false
    @AppStorage(DefaultsKey.notchNetworkFontSize) private var fontSize = 10.0
    @AppStorage(DefaultsKey.notchNetworkFixedWidth) private var fixedWidth = false
    @AppStorage(DefaultsKey.notchMenuYield) private var menuYield = true
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
        downloadColor: downloadColor, uploadColor: uploadColor, colorScope: colorScope, outerSpacing: outerSpacing, innerSpacing: innerSpacing, fixedWidth: fixedWidth) }
    private var signature: [String] {
        [String(menuYield), String(fixedWidth), String(paused), String(fullUnits), String(decimals), weight, tint, downloadColor, uploadColor, colorScope, String(opacity), alignment, String(arrowGap), String(outerSpacing), String(innerSpacing), String(fontSize), String(width), String(offset), String(uploadOnLeft),
         String(avoidMenus), String(autoHide), String(threshold), String(delay), String(capsuleDrop)]
    }

    init(expandAppearance: Bool = false, expandBehavior: Bool = false) {
        _colorsExpanded = State(initialValue: expandAppearance)
        _appearanceExpanded = State(initialValue: expandAppearance)
        _behaviorExpanded = State(initialValue: expandBehavior)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard(title: text.title) {
                Toggle(text.title, isOn: Binding(get: { !paused }, set: { paused = !$0 }))
                    .toggleStyle(.switch).help(text.quickHint)
                Text(text.quickHint).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text(text.preview).font(.caption).foregroundStyle(.secondary)
                layoutPreview
                Text(text.previewHint).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            SettingsCard(title: text.chinese ? "预设与切换" : "Presets and switching") {
            HStack {
                Text(text.presets)
                Spacer()
                Menu(text.presets) {
                    Button(text.smallPreset) { applyPreset(0) }
                    Button(text.balancedPreset) { applyPreset(1) }
                    Button(text.clearPreset) { applyPreset(2) }
                    let saved = NotchNetworkPresetLibrary(data: presetsData).presets
                    if !saved.isEmpty { Divider() }
                    ForEach(saved) { preset in
                        Button(preset.name) { preset.apply(); service.syncWithPreferences() }
                    }
                }.fixedSize().help(text.presetHint)
            }
            NotchNetworkPresetSettings(appearanceSignature: signature + [unit.rawValue])
            }
            SettingsCard(title: text.chinese ? "格式与字体" : "Format and type") {
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
                    Picker(text.weight, selection: $weight) {
                        Text(text.regular).tag("regular"); Text(text.medium).tag("medium"); Text(text.bold).tag("bold")
                    }.pickerStyle(.menu)
                    slider(text.font, value: $fontSize, range: 8...18, step: 0.5, valueText: String(format: "%g pt", Double(style.fontSize)))
            }
            SettingsCard {
                DisclosureGroup(text.chinese ? "颜色与明暗" : "Colors and brightness", isExpanded: $colorsExpanded) {
                    VStack(alignment: .leading, spacing: 14) {
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
                    }
                }
            }
            SettingsCard {
                DisclosureGroup(text.chinese ? "尺寸、对齐与留白" : "Size, alignment and padding", isExpanded: $appearanceExpanded) {
                    VStack(alignment: .leading, spacing: 14) {
                    Picker(text.chinese ? "宽度模式" : "Width mode", selection: $fixedWidth) {
                        Text(text.chinese ? "自适应（原版）" : "Adaptive (original)").tag(false)
                        Text(text.chinese ? "固定宽度" : "Fixed width").tag(true)
                    }.pickerStyle(.menu)
                    Text(text.chinese
                        ? (fixedWidth ? "外框不随网速变化。读数在可用空间内缩小字号，始终保留所选单位和小数位；不会跨入刘海。" : "读数变长时对称扩宽，持续较短读数保持 15 秒后收紧。")
                        : (fixedWidth ? "The outline stays fixed. Readings fit inside the available space, retaining your units and decimal places, clear of the camera." : "Longer readings expand both sides. Smaller readings must persist for 15 seconds before shrinking."))
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Picker(text.alignment, selection: $alignment) {
                        Text(text.leading).tag("leading"); Text(text.center).tag("center"); Text(text.trailing).tag("trailing")
                        Text(text.outside).tag("outside")
                    }.pickerStyle(.menu)
                    Text(text.alignmentHint).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    slider(text.outerSpacing, value: $outerSpacing, range: 0...24, step: 1, valueText: "\(Int(style.outerSpacing)) pt")
                    slider(text.innerSpacing, value: $innerSpacing, range: 0...24, step: 1, valueText: "\(Int(style.innerSpacing)) pt")
                    slider(text.gap, value: $arrowGap, range: 2...10, step: 1, valueText: "\(Int(style.arrowGap)) pt")
                    slider(text.chinese ? (fixedWidth ? "固定每侧宽度" : "目标每侧宽度") : (fixedWidth ? "Fixed width per side" : "Target width per side"), value: $width,
                           range: max(Double(NotchNetworkStyle.minimumWidth(fontSize: style.fontSize, fullUnits: fullUnits,
                                                                        decimals: decimals, arrowGap: arrowGap, outerSpacing: outerSpacing, innerSpacing: innerSpacing)), fixedWidth ? Double(style.fixedMinimumWidth(inBits: unit == .bits, curveInset: service.geometry.floats ? 8 : 16)) : 0)...240,
                           step: 1, valueText: "\(Int(fixedWidth ? max(style.wingWidth, style.fixedMinimumWidth(inBits: unit == .bits, curveInset: service.geometry.floats ? 8 : 16)) : style.wingWidth)) pt")
                    Text((text.chinese ? "当前实际每侧宽度：" : "Current actual width per side: ") + "\(Int(service.geometry.resolvedNetworkWidth.rounded())) pt")
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    slider(text.offset, value: $offset, range: -3...3, step: 1, valueText: "\(Int(style.verticalOffset)) pt")
                    Text(text.chinese ? (fixedWidth ? "固定模式下限预留完整读数在 8 pt 时的空间，不随实时流量变化。保存的目标宽度不变；低于安全下限时，实际宽度使用安全下限。" : "下限按当前字号与最短读数计算；刘海和圆角安全区始终保留。") : (fixedWidth ? "The fixed minimum reserves complete readings at 8 pt and never follows live traffic. A saved target below that minimum is retained; the safe minimum is used on screen." : "The lower bound follows the font and shortest reading. Camera and corner clearances remain protected.")).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Toggle(text.uploadOnLeft, isOn: $uploadOnLeft)
                    if service.geometry.floats {
                        slider(text.capsuleDrop, value: $capsuleDrop, range: NotchCapsuleFit.dropRange, step: 1,
                               valueText: "\(Int(NotchCapsuleFit(width: 0, height: 0, drop: capsuleDrop).drop)) pt")
                    }
                    }
                }
            }
            SettingsCard {
            DisclosureGroup(text.behavior, isExpanded: $behaviorExpanded) {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle(text.chinese ? "使用菜单栏时临时避让" : "Temporarily yield to the menu bar", isOn: $menuYield)
                    Text(text.chinese ? "点击应用菜单、原生展开按钮或岛左侧空白处时暂时隐藏；菜单收起后自动恢复。仅点击空白处时，移出菜单栏、点击别处或按 Esc 即恢复。不会停止网速采集或修改预设。需要现有的辅助功能权限。" : "Hide while using app menus, the native overflow button, or blank space to the island’s left. Restore after menus close. A blank-space session ends on leaving the bar, clicking elsewhere, or Escape. Sampling and presets stay intact. Requires Accessibility access.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
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
            }
            HStack {
                Text(text.chinese ? "更改自动保存" : "Changes save automatically").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 12)
                Button(text.reset) { resetAppearance() }.controlSize(.small)
            }.padding(.horizontal, 4)
        }
        .disclosureGroupStyle(SettingsDisclosureStyle())
        .onChange(of: style) { _, new in
            if !width.isFinite || width < Double(new.wingWidth) { width = Double(new.wingWidth) }
        }
        .onChange(of: signature) { _, _ in service.syncWithPreferences() }
    }

    private func resetAppearance() {
        fixedWidth = false
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

    private var previewWingWidth: CGFloat {
        style.usesFixedWidth ? max(style.wingWidth, style.fixedMinimumWidth(inBits: unit == .bits))
            : max(style.wingWidth, style.requiredWidth(download: 1_234_567, upload: 345_678, inBits: unit == .bits))
    }
    private var layoutPreview: some View {
        GeometryReader { proxy in
            let camera = service.geometry.floats ? 0 : service.geometry.cameraWidth
            let total = previewWingWidth * 2 + camera
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
        let rate = upload ? 345_678.0 : 1_234_567.0
        let reading = NotchNetworkFormat.reading(rate, inBits: unit == .bits, fullUnits: fullUnits, decimals: decimals)
        let font = style.fittedFontSize(reading: reading, available: previewWingWidth - 16 - outerSpacing - innerSpacing)
        return NotchNetworkReadout(bytesPerSecond: rate, upload: upload,
                            inBits: unit == .bits, fontSize: font, fullUnits: fullUnits,
                            decimals: style.decimals, weight: style.fontWeight, tint: style.tint,
                            opacity: style.opacity, arrowGap: style.arrowGap,
                            downloadColor: style.downloadColor, uploadColor: style.uploadColor, colorScope: style.colorScope)
            .frame(maxWidth: .infinity, alignment: style.readingAlignment(leadingSide: leading))
            .padding(.leading, leading ? style.outerSpacing + 16 : style.innerSpacing)
            .padding(.trailing, leading ? style.innerSpacing : style.outerSpacing + 16)
            .frame(width: previewWingWidth)
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors

#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// Offscreen production-view captures and a live, network-only sampling check.
/// Uses volatile launch defaults and never launches the app's other features.
enum NotchNetworkProbe {
    static func runAndExit() -> Never {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--output-dir"), arguments.indices.contains(index + 1) else {
            print("NETWORK ISLAND FAILED: --output-dir is required")
            exit(1)
        }
        let output = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        let language = arguments.contains("--chinese") ? "zh-Hans" : "en-US"
        var overrides: [String: Any] = [
            DefaultsKey.notchEnabled: true,
            DefaultsKey.notchIdleContent: "network",
            DefaultsKey.notchNetworkPaused: arguments.contains("--paused"),
            DefaultsKey.notchNetworkFullUnits: arguments.contains("--full"),
            DefaultsKey.notchNetworkAutoHide: false,
            DefaultsKey.notchNetworkAvoidMenus: false,
            DefaultsKey.notchNetworkFontSize: arguments.contains("--large") ? 18.0 : arguments.contains("--small") ? 8.0 : 10.0,
            DefaultsKey.notchNetworkDecimals: arguments.contains("--large") ? 2 : 1,
            DefaultsKey.notchNetworkTint: arguments.contains("--custom") ? "custom" : arguments.contains("--large") ? "direction" : "white",
            DefaultsKey.notchNetworkDownloadColor: "CDB5FF",
            DefaultsKey.notchNetworkUploadColor: "FFD27D",
            DefaultsKey.notchNetworkColorScope: arguments.contains("--arrows-only") ? "arrows" : "all",
            DefaultsKey.notchNetworkWeight: arguments.contains("--large") ? "bold" : "medium",
            DefaultsKey.notchNetworkArrowGap: arguments.contains("--large") ? 10.0 : 3.0,
            DefaultsKey.notchNetworkOpacity: 0.9,
            DefaultsKey.notchNetworkAlignment: arguments.contains("--outside") ? "outside" : "center",
            DefaultsKey.notchNetworkOuterSpacing: arguments.contains("--large") ? 24.0 : 0.0,
            DefaultsKey.notchNetworkInnerSpacing: arguments.contains("--large") ? 24.0 : 0.0,
            DefaultsKey.notchNavigationPosition: "top",
            DefaultsKey.notchSystemLayout: "original",
            DefaultsKey.notchSystemCardScale: 1.0,
            DefaultsKey.notchSystemHorizontalSpacing: 10.0,
            DefaultsKey.notchSystemVerticalSpacing: 10.0,
            DefaultsKey.notchSystemMetricOrder: "",
            DefaultsKey.notchSystemHiddenMetrics: "",
            "AppleShowScrollBars": "Always",
            DefaultsKey.notchNetworkWidth: arguments.contains("--large") ? 240.0 : arguments.contains("--small") ? 48.0 : 72.0,
            DefaultsKey.notchNetworkOffset: arguments.contains("--large") ? 3.0 : 0.0,
            DefaultsKey.notchNetworkUploadOnLeft: arguments.contains("--swap"),
            DefaultsKey.notchMascotEnabled: false,
            DefaultsKey.notchAgentsEnabled: false,
            DefaultsKey.notchShowPlayingMusic: false,
            DefaultsKey.monitorInterval: 1,
            DefaultsKey.language: language,
            DefaultsKey.networkSpeedUnit: "bytes",
        ]
        for feature in AppFeature.allCases { overrides[feature.availabilityKey] = true }
        UserDefaults.standard.setVolatileDomain(overrides, forName: UserDefaults.argumentDomain)
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        var failures: [String] = []
        do { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }
        catch { print("NETWORK ISLAND FAILED: \(error)"); exit(1) }

        if arguments.contains("--menu-fixed-only") {
            overrides[DefaultsKey.notchNetworkFixedWidth] = true
            overrides[DefaultsKey.notchMenuYield] = true
            overrides[DefaultsKey.notchNetworkFullUnits] = true
            overrides[DefaultsKey.notchNetworkDecimals] = 2
            overrides[DefaultsKey.notchNetworkWidth] = 72.0
            overrides[DefaultsKey.notchNetworkFontSize] = 12.0
            overrides[DefaultsKey.notchNetworkTint] = "direction"
            UserDefaults.standard.setVolatileDomain(overrides, forName: UserDefaults.argumentDomain)
            var geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1470, height: 956),
                safeAreaTop: 32, cameraWidth: 180, compactSideRoom: 300)
            geometry.networkStyle = .stored()
            NotchService.shared.prepareNetworkProbe(geometry: geometry, expanded: false)
            for width: CGFloat in [460, 760] {
                capture(AnyView(NotchNetworkSettings(expandAppearance: true, expandBehavior: true).padding(20)
                    .background(Color(nsColor: .windowBackgroundColor))), size: CGSize(width: width, height: 3100),
                    name: "fixed-settings-\(language)-\(Int(width))", output: output, failures: &failures)
            }
            for target in [24.0, 72, 120, 240] {
                let style = NotchNetworkStyle(fontSize: 12, wingWidth: target, fullUnits: true, decimals: 2,
                    tint: "direction", alignment: "outside", fixedWidth: true)
                let wing = max(style.wingWidth, style.fixedMinimumWidth(inBits: true))
                let samples: [(Double, Double)] = [(0, 0), (1023.99 * 1024, 12), (999.99 * 1024 * 1024, Double(UInt64.max))]
                let rows = VStack(alignment: .leading, spacing: 16) {
                    Text(language == "zh-Hans" ? "固定宽度 · 完整单位与两位小数" : "Fixed width · Full units and two decimal places").font(.caption)
                    ForEach(samples.indices, id: \.self) { index in
                        let values = samples[index]
                        HStack(spacing: 0) {
                            ForEach(0..<2) { side in
                                let rate = side == 0 ? values.0 : values.1
                                let reading = NotchNetworkFormat.reading(rate, inBits: true, fullUnits: true, decimals: 2)
                                let font = style.fittedFontSize(reading: reading, available: wing - 16)
                                NotchNetworkReadout(bytesPerSecond: rate, upload: side == 1, inBits: true,
                                    fontSize: font, fullUnits: true, decimals: 2, tint: "direction")
                                    .fixedSize().frame(width: wing - 16, alignment: side == 0 ? .leading : .trailing)
                                    .padding(side == 0 ? .leading : .trailing, 16)
                                if side == 0 { Color.clear.frame(width: 180) }
                            }
                        }.frame(height: 32).background(.black, in: Capsule())
                    }
                }.padding(20).background(Color(nsColor: .windowBackgroundColor))
                capture(AnyView(rows), size: CGSize(width: wing * 2 + 220, height: 210),
                    name: "fixed-readings-\(language)-\(Int(target))", output: output, failures: &failures)
            }
            print(failures.isEmpty ? "FIXED NETWORK OK" : "FIXED NETWORK FAILED: " + failures.joined(separator: "; "))
            exit(failures.isEmpty ? 0 : 1)
        }

        if arguments.contains("--direct-controls-only") {
            var header = NotchHeaderConfiguration()
            header.set(.networkReadout, at: .leftOuter); header.set(.control(.microphone), at: .leftMiddle)
            header.set(.settings, at: .rightOuter); header.set(.pin, at: .rightMiddle)
            overrides[DefaultsKey.notchHeaderLayout] = header.encoded
            overrides[DefaultsKey.notchHeaderNetworkIconOnly] = true
            overrides[DefaultsKey.notchQuickAccessLayout] = NotchQuickAccessConfiguration(buttons: []).encoded
            overrides[DefaultsKey.brightnessControlEnabled] = true
            let shown: [NotchControlItem] = [.brightness, .keyboardLight, .keepAwake, .microphone]
            overrides[DefaultsKey.notchControlOrder] = shown.map(\.rawValue).joined(separator: ",")
            overrides[DefaultsKey.notchHiddenControls] = NotchControlItem.allCases.filter { !shown.contains($0) }.map(\.rawValue).joined(separator: ",")
            overrides[DefaultsKey.notchHiddenModules] = ""
            var custom = NotchPageAppearance(values: ["controls.custom": "true", "controls.values": "true",
                "controls.item.brightness.span": "3", "controls.item.brightness.width": "75", "controls.item.brightness.icon": "20",
                "controls.item.keyboardLight.span": "3", "controls.item.keyboardLight.width": "75", "controls.item.keyboardLight.icon": "12"])
            var arranged = NotchControlsDocument(appearance: custom, order: shown, hidden: [])
            arranged.tidy(available: Set(shown))
            custom = arranged.appearance
            let editor = NotchControlsEditor.shared
            for width: CGFloat in [360, 600] {
                for variant in ["original", "aligned", "editing", "empty"] {
                    editor.stop()
                    overrides[NotchPageAppearance.storageKey] = (variant == "original" ? NotchPageAppearance() : custom).encoded
                    UserDefaults.standard.setVolatileDomain(overrides, forName: UserDefaults.argumentDomain)
                    let geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1470, height: 956), safeAreaTop: 32, cameraWidth: 180,
                        layout: .custom, customWidth: Double(width), customHeight: 380)
                    NotchService.shared.prepareNetworkProbe(geometry: geometry, expanded: true, selected: .controls)
                    if variant == "editing" || variant == "empty" {
                        var document = NotchControlsDocument.stored()
                        if variant == "empty" { document.hidden = Set(NotchControlItem.allCases.map(\.rawValue)) }
                        editor.start(document, available: Set(shown))
                    }
                    let size = NotchService.shared.surfaceSize
                    capture(AnyView(NotchView(service: .shared).background(.black)), size: size,
                        name: "direct-\(variant)-\(language)-\(Int(width))", output: output, failures: &failures, island: true)
                }
            }
            editor.stop()
            for width: CGFloat in [460, 760] {
                capture(AnyView(NotchPageAppearanceSettings(module: .controls).padding(20)
                    .background(Color(nsColor: .windowBackgroundColor))), size: CGSize(width: width, height: 620),
                    name: "direct-settings-\(language)-\(Int(width))", output: output, failures: &failures)
            }
            print(failures.isEmpty ? "DIRECT CONTROLS OK" : "DIRECT CONTROLS FAILED: " + failures.joined(separator: "; "))
            exit(failures.isEmpty ? 0 : 1)
        }

        let monitor = SystemMonitor.shared
        monitor.setInterval(seconds: 1)
        monitor.setNotchDetailNeeds(.init(network: true))
        RunLoop.current.run(until: Date().addingTimeInterval(2.4))
        let snapshot = monitor.snapshot
        if snapshot.netDownBytesPerSec == nil || snapshot.netUpBytesPerSec == nil {
            failures.append("live network samples did not arrive")
        }
        if snapshot.cpuUsage != nil || snapshot.gpuUsage != nil {
            failures.append("network-only demand sampled CPU or GPU")
        }
        print("NETWORK LIVE down=\(snapshot.netDownBytesPerSec ?? -1) B/s up=\(snapshot.netUpBytesPerSec ?? -1) B/s")

        var hanging = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1470, height: 956),
                                    safeAreaTop: 32, cameraWidth: 180, compactSideRoom: 100)
        hanging.networkStyle = .stored()
        hanging.compactSideRoom = max(100, hanging.networkStyle.wingWidth)
        var capsule = NotchGeometry(screen: hanging.screen, safeAreaTop: 0, cameraWidth: 0,
                                    menuBarHeight: 24, compactSideRoom: 100, silhouette: .capsule)
        capsule.networkStyle = .stored()
        let hangingSize = hanging.restingSize(showsContent: true, content: .network)
        let capsuleSize = capsule.restingSize(showsContent: false, content: .network)
        let readouts = VStack(alignment: .leading, spacing: 20) {
            Text("Net Island · Network").font(.system(size: 16, weight: .semibold))
            NotchRestingStrip(service: .shared, displayGeometry: hanging)
                .frame(width: hangingSize.width, height: hangingSize.height)
                .background(.black).clipShape(NotchShape.island(height: hangingSize.height, geometry: hanging))
            NotchCapsuleRestingView(service: .shared, size: capsuleSize, displayGeometry: capsule)
                .frame(width: capsuleSize.width, height: capsuleSize.height)
                .background(.black, in: Capsule())
            HStack(spacing: 24) {
                NotchNetworkReadout(bytesPerSecond: nil, fullUnits: arguments.contains("--full"))
                NotchNetworkReadout(bytesPerSecond: 0, fullUnits: arguments.contains("--full"))
                NotchNetworkReadout(bytesPerSecond: 1_234_567, fullUnits: arguments.contains("--full"))
                NotchNetworkReadout(bytesPerSecond: 125_000_000, upload: true, inBits: true, fullUnits: arguments.contains("--full"))
            }.padding(12).background(.black, in: RoundedRectangle(cornerRadius: 8))
            Text("Live views above · Formatting samples below").font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(24)
        .background(Color(nsColor: .windowBackgroundColor))
        capture(AnyView(readouts), size: CGSize(width: max(540, hangingSize.width + 48), height: 260),
                name: "network-readouts-\(language)", output: output, failures: &failures)
        if arguments.contains("--page-layout-only") || arguments.contains("--controls-grid-only") {
            let gridOnly = arguments.contains("--controls-grid-only")
            var header = NotchHeaderConfiguration()
            header.set(.networkReadout, at: .leftOuter); header.set(.control(.microphone), at: .leftMiddle)
            header.set(.settings, at: .rightOuter); header.set(.pin, at: .rightMiddle)
            overrides[DefaultsKey.notchHeaderLayout] = header.encoded
            overrides[DefaultsKey.notchHeaderNetworkIconOnly] = true
            overrides[DefaultsKey.notchQuickAccessLayout] = NotchQuickAccessConfiguration(buttons: []).encoded
            overrides[DefaultsKey.notchHiddenControls] = "music"
            overrides[DefaultsKey.notchControlOrder] = "brightness,keyboardLight,volume,keepAwake"
            overrides[DefaultsKey.brightnessControlEnabled] = true
            if gridOnly {
                let shown: [NotchControlItem] = [.brightness, .keyboardLight, .keepAwake, .microphone, .timer, .music]
                overrides[DefaultsKey.notchHiddenControls] = NotchControlItem.allCases.filter { !shown.contains($0) }.map(\.rawValue).joined(separator: ",")
                overrides[DefaultsKey.notchControlOrder] = shown.map(\.rawValue).joined(separator: ",")
            }
            let grid = NotchPageAppearance(values: ["controls.custom": "true", "controls.gridColumns": "3", "controls.values": "true",
                "controls.padding": "8", "controls.item.brightness.span": "3", "controls.item.brightness.width": "75",
                "controls.item.brightness.icon": "20", "controls.item.keyboardLight.span": "2",
                "controls.item.microphone.icon": "26", "controls.item.microphone.circle": "48", "controls.item.microphone.column": "3"])
            var iconsGrid = grid
            for item in [NotchControlItem.keepAwake, .microphone, .timer] {
                iconsGrid.values[grid.controlKey(item) + "iconOnly"] = "true"
                iconsGrid.values[grid.controlKey(item) + "height"] = "52"
                iconsGrid.values[grid.controlKey(item) + "shape"] = item == .microphone ? "plain" : "square"
            }
            let variants: [(String, NotchPageAppearance)] = gridOnly ? [("original", .init()), ("grid", grid), ("icons", iconsGrid)] : [
                ("original", .init()),
                ("custom", .init(values: ["tools.columns": "4", "tools.scale": "1.2", "tools.font": "12", "tools.padding": "10", "tools.alignColumns": "true", "controls.columns": "1", "controls.values": "true", "controls.track": "75", "system.font": "1.2", "system.padding": "16", "system.tint": "cyan", "nav.shared.size": "14", "nav.shared.margin": "6"])),
                ("icons", .init(values: ["tools.iconOnly": "true", "tools.columns": "6", "tools.alignColumns": "true", "tools.padding": "8", "nav.tools.override": "true", "nav.tools.position": "bottom"]))
            ]
            for (name, appearance) in variants {
                overrides[NotchPageAppearance.storageKey] = appearance.encoded
                UserDefaults.standard.setVolatileDomain(overrides, forName: UserDefaults.argumentDomain)
                for width: CGFloat in [360, 600] {
                    for module: NotchModule in (gridOnly ? [.controls] : [.system, .tools, .controls]) {
                        let geometry = NotchGeometry(screen: hanging.screen, safeAreaTop: 32, cameraWidth: 180,
                            layout: .custom, customWidth: Double(width), customHeight: gridOnly ? 620 : name == "custom" ? 420 : 300)
                        NotchService.shared.prepareNetworkProbe(geometry: geometry, expanded: true, selected: module)
                        let size = NotchService.shared.surfaceSize
                        capture(AnyView(NotchView(service: .shared).environment(\.notchSettingsPreview, gridOnly).background(.black)
                            .clipShape(NotchShape.island(height: size.height, geometry: geometry))), size: size,
                            name: "page-\(module.rawValue)-\(name)-\(language)-\(Int(width))", output: output, failures: &failures, island: true)
                    }
                }
            }
            if gridOnly {
                for width: CGFloat in [460, 760] {
                    capture(AnyView(NotchPageAppearanceSettings(module: .controls, expandControls: true, control: .microphone)
                        .padding(20).background(Color(nsColor: .windowBackgroundColor))), size: CGSize(width: width, height: 1800),
                        name: "control-icon-settings-\(language)-\(Int(width))", output: output, failures: &failures)
                }
                let geometry = NotchGeometry(screen: hanging.screen, safeAreaTop: 32, cameraWidth: 180,
                    layout: .custom, customWidth: 360, customHeight: 240)
                NotchService.shared.prepareNetworkProbe(geometry: geometry, expanded: true, selected: .controls)
                let size = NotchService.shared.surfaceSize
                capture(AnyView(NotchView(service: .shared).environment(\.notchSettingsPreview, true).background(.black)), size: size,
                    name: "control-short-viewport-\(language)", output: output, failures: &failures, island: true)
                var large = grid
                large.values["controls.gap"] = "4"
                for item in [NotchControlItem.brightness, .keyboardLight] {
                    large.values[grid.controlKey(item) + "icon"] = "32"
                    large.values[grid.controlKey(item) + "font"] = "16"
                    large.values[grid.controlKey(item) + "height"] = "36"
                }
                overrides[NotchPageAppearance.storageKey] = large.encoded
                overrides[DefaultsKey.brightnessControlEnabled] = false
                UserDefaults.standard.setVolatileDomain(overrides, forName: UserDefaults.argumentDomain)
                for width: CGFloat in [360, 600] {
                    let geometry = NotchGeometry(screen: hanging.screen, safeAreaTop: 32, cameraWidth: 180,
                        layout: .custom, customWidth: Double(width), customHeight: 620)
                    NotchService.shared.prepareNetworkProbe(geometry: geometry, expanded: true, selected: .controls)
                    let size = NotchService.shared.surfaceSize
                    capture(AnyView(NotchView(service: .shared).environment(\.notchSettingsPreview, true).background(.black)), size: size,
                        name: "control-large-setup-\(language)-\(Int(width))", output: output, failures: &failures, island: true)
                }
            }
            for module: NotchModule in (gridOnly ? [.controls] : [.system, .tools, .controls]) {
                for width: CGFloat in [460, 760] {
                    capture(AnyView(VStack(alignment: .leading, spacing: 16) {
                        NotchNavigationSettings(module: module)
                        NotchPageAppearanceSettings(module: module, expandControls: gridOnly)
                        NotchPagePresetSettings()
                    }.padding(20).background(Color(nsColor: .windowBackgroundColor))),
                        size: CGSize(width: width, height: module == .tools || gridOnly ? 2400 : 1200),
                        name: "page-settings-\(module.rawValue)-\(language)-\(Int(width))", output: output, failures: &failures)
                }
            }
            overrides[DefaultsKey.notchNetworkFullUnits] = true
            overrides[DefaultsKey.notchNetworkFontSize] = 9.0
            overrides[DefaultsKey.notchNetworkWidth] = 24.0
            overrides[DefaultsKey.notchNetworkTint] = "custom"
            overrides[DefaultsKey.notchNetworkDownloadColor] = "FF454A"
            overrides[DefaultsKey.notchNetworkUploadColor] = "00D8E8"
            UserDefaults.standard.setVolatileDomain(overrides, forName: UserDefaults.argumentDomain)
            var networkGeometry = hanging
            networkGeometry.networkStyle = .stored()
            networkGeometry.networkRequiredWidth = networkGeometry.networkStyle.requiredWidth(
                download: monitor.snapshot.netDownBytesPerSec, upload: monitor.snapshot.netUpBytesPerSec, inBits: false)
            networkGeometry.compactSideRoom = 240
            NotchService.shared.prepareNetworkProbe(geometry: networkGeometry, expanded: false)
            for width: CGFloat in [460, 760] {
                capture(AnyView(NotchNetworkSettings(expandAppearance: true, expandBehavior: true).padding(20)
                    .background(Color(nsColor: .windowBackgroundColor))), size: CGSize(width: width, height: 2400),
                    name: "network-density-\(language)-\(Int(width))", output: output, failures: &failures)
            }
            let style = NotchNetworkStyle.stored()
            for (name, down, up) in [("short", 15.0 * 1024, 1000.0), ("long", 999.0 * 1024 * 1024, 123.4 * 1024), ("zero", 0.0, 0.0)] {
                let wing = max(style.wingWidth, style.requiredWidth(download: down, upload: up, inBits: false))
                let sample = VStack(alignment: .leading, spacing: 10) {
                    Text(language == "zh-Hans" ? "示例读数 · 动态最小宽度" : "Sample readings · Adaptive minimum width").font(.caption)
                    HStack(spacing: 0) {
                        NotchNetworkReadout(bytesPerSecond: down, fontSize: 9, fullUnits: true)
                            .frame(width: wing - 16).padding(.leading, 16)
                        Color.clear.frame(width: 180)
                        NotchNetworkReadout(bytesPerSecond: up, upload: true, fontSize: 9, fullUnits: true)
                            .frame(width: wing - 16).padding(.trailing, 16)
                    }.frame(height: 32).background(.black, in: Capsule())
                }.padding(16).background(Color(nsColor: .windowBackgroundColor))
                capture(AnyView(sample), size: CGSize(width: wing * 2 + 212, height: 100), name: "network-fit-\(name)-\(language)", output: output, failures: &failures)
            }
            monitor.setNotchDetailNeeds(.none)
            print(failures.isEmpty ? "NETWORK ISLAND OK" : "NETWORK ISLAND FAILED: " + failures.joined(separator: "; "))
            exit(failures.isEmpty ? 0 : 1)
        }
        if arguments.contains("--named-presets-only") {
            var saved = NotchNetworkPresetLibrary(data: Data())
            saved.presets = [NotchNetworkPreset.capture(name: language == "zh-Hans" ? "日常 · 柔和配色" : "Everyday · Soft colors"),
                             NotchNetworkPreset.capture(name: language == "zh-Hans" ? "下载任务 · 大字清晰精准读数" : "Download sessions · Large precise readings")]
            overrides[DefaultsKey.notchNetworkPresets] = saved.encoded!
            overrides[DefaultsKey.notchHeaderLayout] = Data()
            overrides[DefaultsKey.notchHeaderNetworkIconOnly] = true
            overrides[DefaultsKey.notchHeaderSettingsPosition] = "rightOuter"
            overrides[DefaultsKey.notchHeaderNetworkPosition] = "leftOuter"
            UserDefaults.standard.setVolatileDomain(overrides, forName: UserDefaults.argumentDomain)
            NotchService.shared.prepareNetworkProbe(geometry: hanging, expanded: false)
            for width: CGFloat in [460, 760] {
                capture(AnyView(NotchNetworkSettings().padding(20).background(Color(nsColor: .windowBackgroundColor))),
                        size: CGSize(width: width, height: 1000), name: "named-presets-\(language)-\(Int(width))", output: output, failures: &failures)
            }
            for width: CGFloat in [460, 760] {
                capture(AnyView(NotchLayoutEditor(configuration: .constant(.initial), size: .constant("compact"),
                    width: .constant(560), height: .constant(300), editContents: {}).padding(20)
                    .background(Color(nsColor: .windowBackgroundColor))), size: CGSize(width: width, height: 620),
                        name: "header-editor-\(language)-\(Int(width))", output: output, failures: &failures)
            }
            for position in NotchHeaderPosition.allCases {
                overrides[DefaultsKey.notchHeaderSettingsPosition] = position.rawValue
                overrides[DefaultsKey.notchHeaderNetworkPosition] = position.rawValue
                UserDefaults.standard.setVolatileDomain(overrides, forName: UserDefaults.argumentDomain)
                for width: CGFloat in (language == "zh-Hans" ? [360, 600] : [600]) {
                    let geometry = NotchGeometry(screen: hanging.screen, safeAreaTop: 32, cameraWidth: 180,
                                                 layout: .custom, customWidth: Double(width), customHeight: 300)
                    NotchService.shared.prepareNetworkProbe(geometry: geometry, expanded: true, selected: .system)
                    let size = NotchService.shared.surfaceSize
                    capture(AnyView(NotchView(service: .shared).background(.black)
                        .clipShape(NotchShape.island(height: size.height, geometry: geometry))), size: size,
                            name: "header-\(position.rawValue)-\(language)-\(Int(width))", output: output, failures: &failures, island: true)
                }
            }
            var allActions = NotchHeaderConfiguration()
            allActions.set(.networkReadout, at: .leftOuter)
            allActions.set(.module(.tools), at: .leftMiddle)
            allActions.set(.module(.system), at: .leftInner)
            allActions.set(.pin, at: .rightInner)
            allActions.set(.control(.microphone), at: .rightMiddle)
            allActions.set(.settings, at: .rightOuter)
            overrides[DefaultsKey.notchHeaderLayout] = allActions.encoded
            UserDefaults.standard.setVolatileDomain(overrides, forName: UserDefaults.argumentDomain)
            let fullGeometry = NotchGeometry(screen: hanging.screen, safeAreaTop: 32, cameraWidth: 180,
                                             layout: .custom, customWidth: 600, customHeight: 300)
            NotchService.shared.prepareNetworkProbe(geometry: fullGeometry, expanded: true, selected: .system)
            capture(AnyView(NotchView(service: .shared).background(.black)), size: NotchService.shared.surfaceSize,
                    name: "header-all-actions-\(language)", output: output, failures: &failures, island: true)
            overrides[DefaultsKey.notchQuickAccessLayout] = NotchQuickAccessConfiguration(buttons: []).encoded
            UserDefaults.standard.setVolatileDomain(overrides, forName: UserDefaults.argumentDomain)
            let denseGeometry = NotchGeometry(screen: hanging.screen, safeAreaTop: 32, cameraWidth: 180,
                                              layout: .custom, customWidth: 480, customHeight: 300)
            NotchService.shared.prepareNetworkProbe(geometry: denseGeometry, expanded: true, selected: .system)
            capture(AnyView(NotchView(service: .shared).background(.black)), size: NotchService.shared.surfaceSize,
                    name: "header-six-with-sections-\(language)", output: output, failures: &failures, island: true)
            overrides[DefaultsKey.notchHeaderLayout] = Data()
            overrides[DefaultsKey.notchHeaderSettingsPosition] = "rightOuter"
            overrides[DefaultsKey.notchHeaderNetworkPosition] = "leftOuter"
            overrides[DefaultsKey.notchHeaderNetworkIconOnly] = false
            UserDefaults.standard.setVolatileDomain(overrides, forName: UserDefaults.argumentDomain)
            let floating = NotchGeometry(screen: hanging.screen, safeAreaTop: 0, cameraWidth: 0, layout: .custom,
                                          customWidth: 600, customHeight: 300, silhouette: .capsule)
            NotchService.shared.prepareNetworkProbe(geometry: floating, expanded: true, selected: .tools)
            let size = NotchService.shared.surfaceSize
            capture(AnyView(NotchView(service: .shared).background(.black)
                .clipShape(NotchShape.island(height: size.height, geometry: floating))), size: size,
                    name: "header-floating-\(language)", output: output, failures: &failures, island: true)
            monitor.setNotchDetailNeeds(.none)
            print(failures.isEmpty ? "NETWORK ISLAND OK" : "NETWORK ISLAND FAILED: " + failures.joined(separator: "; "))
            exit(failures.isEmpty ? 0 : 1)
        }
        if arguments.contains("--network-ux-only") {
            NotchService.shared.prepareNetworkProbe(geometry: hanging, expanded: false)
            capture(AnyView(NotchNetworkSettings().padding(20).background(Color(nsColor: .windowBackgroundColor))),
                    size: CGSize(width: 460, height: 700), name: "network-collapsed-\(language)", output: output, failures: &failures)
            for width: CGFloat in [460, 760] {
                capture(AnyView(NotchNetworkSettings(expandAppearance: true, expandBehavior: true).padding(20)
                    .background(Color(nsColor: .windowBackgroundColor))), size: CGSize(width: width, height: 2000),
                        name: "network-expanded-\(language)-\(Int(width))", output: output, failures: &failures)
            }
            monitor.setNotchDetailNeeds(.none)
            print(failures.isEmpty ? "NETWORK ISLAND OK" : "NETWORK ISLAND FAILED: " + failures.joined(separator: "; "))
            exit(failures.isEmpty ? 0 : 1)
        }
        for width: CGFloat in [360, 480, 600] {
            let geometry = NotchGeometry(screen: hanging.screen, safeAreaTop: 32, cameraWidth: 180,
                                         layout: .custom, compactSideRoom: 100,
                                         customWidth: Double(width), customHeight: width == 480 ? 260 : 360)
            for module: NotchModule in [.system, .tools] {
                NotchService.shared.prepareNetworkProbe(geometry: geometry, expanded: true, selected: module)
                let size = NotchService.shared.surfaceSize
                let header = NotchView(service: .shared).background(.black)
                    .clipShape(NotchShape.island(height: size.height, geometry: geometry))
                capture(AnyView(header), size: size, name: "navigation-\(module.rawValue)-\(language)-\(Int(width))", output: output, failures: &failures, island: true)
            }
        }
        for position in NotchNavigationPosition.allCases {
            overrides[DefaultsKey.notchNavigationPosition] = position.rawValue
            UserDefaults.standard.setVolatileDomain(overrides, forName: UserDefaults.argumentDomain)
            let geometry = NotchGeometry(screen: hanging.screen, safeAreaTop: 32, cameraWidth: 180,
                                         layout: .custom, customWidth: 600, customHeight: 360)
            NotchService.shared.prepareNetworkProbe(geometry: geometry, expanded: true, selected: .system)
            capture(AnyView(NotchView(service: .shared).background(.black)
                .clipShape(NotchShape.island(height: NotchService.shared.surfaceSize.height, geometry: geometry))), size: NotchService.shared.surfaceSize,
                    name: "arrows-\(position.rawValue)-\(language)", output: output, failures: &failures, island: true)
        }
        capture(AnyView(NotchNavigationSettings().padding(20).background(Color(nsColor: .windowBackgroundColor))),
                size: CGSize(width: 460, height: 200), name: "navigation-settings-\(language)", output: output, failures: &failures)
        for layout in NotchSystemLayout.allCases {
            overrides[DefaultsKey.notchSystemLayout] = layout.rawValue
            UserDefaults.standard.setVolatileDomain(overrides, forName: UserDefaults.argumentDomain)
            for width: CGFloat in [360, 480, 600] {
                let geometry = NotchGeometry(screen: hanging.screen, safeAreaTop: 32, cameraWidth: 180,
                                             layout: .custom, customWidth: Double(width), customHeight: 360)
                NotchService.shared.prepareNetworkProbe(geometry: geometry, expanded: true, selected: .system)
                let size = NotchService.shared.surfaceSize
                capture(AnyView(NotchView(service: .shared).background(.black)
                    .clipShape(NotchShape.island(height: size.height, geometry: geometry))), size: size,
                        name: "system-\(layout.rawValue)-\(language)-\(Int(width))", output: output, failures: &failures, island: true)
            }
        }
        overrides[DefaultsKey.notchSystemLayout] = "original"
        UserDefaults.standard.setVolatileDomain(overrides, forName: UserDefaults.argumentDomain)
        capture(AnyView(NotchSystemLayoutSettings().padding(20).background(Color(nsColor: .windowBackgroundColor))),
                size: CGSize(width: 460, height: 1000), name: "system-layout-settings-\(language)", output: output, failures: &failures)
        for profile in ["small", "large", "reordered", "empty"] {
            overrides[DefaultsKey.notchNavigationPosition] = "top"
            overrides[DefaultsKey.notchSystemCardScale] = profile == "small" ? 0.8 : profile == "large" ? 1.35 : 1.0
            overrides[DefaultsKey.notchSystemHorizontalSpacing] = profile == "small" ? 4.0 : profile == "large" ? 24.0 : 10.0
            overrides[DefaultsKey.notchSystemVerticalSpacing] = profile == "small" ? 4.0 : profile == "large" ? 24.0 : 10.0
            overrides[DefaultsKey.notchSystemMetricOrder] = profile == "reordered" ? "network,memory,cpu" : ""
            overrides[DefaultsKey.notchSystemHiddenMetrics] = profile == "empty"
                ? NotchSystemMetric.allCases.map(\.rawValue).joined(separator: ",")
                : profile == "reordered" ? "gpu,disk,power,connectedDevices" : ""
            UserDefaults.standard.setVolatileDomain(overrides, forName: UserDefaults.argumentDomain)
            for width: CGFloat in [360, 480, 600] {
                let geometry = NotchGeometry(screen: hanging.screen, safeAreaTop: 32, cameraWidth: 180,
                                             layout: .custom, customWidth: Double(width), customHeight: 360)
                NotchService.shared.prepareNetworkProbe(geometry: geometry, expanded: true, selected: .system)
                let size = NotchService.shared.surfaceSize
                capture(AnyView(NotchView(service: .shared).background(.black)
                    .clipShape(NotchShape.island(height: size.height, geometry: geometry))), size: size,
                        name: "system-\(profile)-\(language)-\(Int(width))", output: output, failures: &failures, island: true)
            }
            if profile == "reordered" {
                capture(AnyView(NotchSystemLayoutSettings().padding(20).background(Color(nsColor: .windowBackgroundColor))),
                        size: CGSize(width: 760, height: 1000), name: "system-custom-settings-\(language)", output: output, failures: &failures)
            }
        }
        overrides[DefaultsKey.notchSystemCardScale] = 1.0
        overrides[DefaultsKey.notchSystemHorizontalSpacing] = 10.0
        overrides[DefaultsKey.notchSystemVerticalSpacing] = 10.0
        overrides[DefaultsKey.notchSystemMetricOrder] = ""
        overrides[DefaultsKey.notchSystemHiddenMetrics] = ""
        UserDefaults.standard.setVolatileDomain(overrides, forName: UserDefaults.argumentDomain)
        let arrowStates = HStack(spacing: 40) {
            arrowState("Resting", pressed: false, reduced: false)
            arrowState("Pressed", pressed: true, reduced: false)
            arrowState("Reduce Motion", pressed: true, reduced: true)
        }.padding(24).foregroundStyle(.white).background(.black)
        capture(AnyView(arrowStates), size: CGSize(width: 460, height: 130), name: "arrow-press-states-\(language)", output: output, failures: &failures)
        NotchService.shared.prepareNetworkProbe(geometry: hanging, expanded: false)
        overrides[DefaultsKey.notchNetworkAutoHide] = true
        UserDefaults.standard.setVolatileDomain(overrides, forName: UserDefaults.argumentDomain)
        let settings = NotchNetworkSettings(expandAppearance: arguments.contains("--expanded"), expandBehavior: arguments.contains("--expanded")).padding(20)
            .background(Color(nsColor: .windowBackgroundColor))
        for width: CGFloat in [460, 760] {
            capture(AnyView(settings), size: CGSize(width: width, height: arguments.contains("--expanded") ? 1400 : 650),
                    name: "network-settings-\(language)-\(Int(width))", output: output, failures: &failures)
        }
        capture(AnyView(NetworkPrivacySettings().padding(20).background(Color(nsColor: .windowBackgroundColor))),
                size: CGSize(width: 460, height: 420), name: "privacy-\(language)", output: output, failures: &failures)
        monitor.setNotchDetailNeeds(.none)
        print(failures.isEmpty ? "NETWORK ISLAND OK" : "NETWORK ISLAND FAILED: " + failures.joined(separator: "; "))
        exit(failures.isEmpty ? 0 : 1)
    }

    private static func arrowState(_ title: String, pressed: Bool, reduced: Bool) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.system(size: 11))
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
                .modifier(NotchArrowPressFeedback(pressed: pressed, reduceMotion: reduced))
                .frame(width: 24, height: 44)
        }
    }

    private static func capture(_ view: AnyView, size: CGSize, name: String, output: URL, failures: inout [String], island: Bool = false) {
        let proposed = view.environment(\.colorScheme, .dark).tint(.blue)
        let measured = NSHostingController(rootView: proposed).sizeThatFits(in: size)
        let framed = AnyView(proposed.frame(width: size.width, height: size.height, alignment: .topLeading))
        let host: NSHostingView<AnyView> = island ? NotchHostingView(rootView: framed) : NSHostingView(rootView: framed)
        host.sizingOptions = []
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: .borderless,
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = host
        host.frame = CGRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        if island {
            // A volatile preference does not reliably update AppKit's cached
            // preferred style. Exercise the actual native legacy-gutter case.
            func forceLegacy(_ view: NSView) {
                if let scroll = view as? NSScrollView {
                    scroll.scrollerStyle = .legacy
                    scroll.hasVerticalScroller = true
                    scroll.tile()
                }
                for child in view.subviews { forceLegacy(child) }
            }
            forceLegacy(host)
            host.needsLayout = true
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        host.layoutSubtreeIfNeeded()
        if island {
            func inspect(_ view: NSView) {
                if let scroll = view as? NSScrollView, scroll.hasVerticalScroller || scroll.hasHorizontalScroller {
                    failures.append("\(name) exposes a native scroller")
                }
                if let scroll = view as? NSScrollView,
                   scroll.scrollerStyle != .overlay || abs(scroll.contentView.frame.width - scroll.bounds.width) > 1 {
                    failures.append("\(name) retains an asymmetric native scrollbar gutter")
                }
                if let scroll = view as? NSScrollView, name.contains("system") || name.hasPrefix("arrows-") || name.hasPrefix("direct-editing"),
                   let document = scroll.documentView, abs(document.frame.width - scroll.contentView.bounds.width) > 1 {
                    failures.append("\(name) retains a narrower System document: \(document.frame.width) / \(scroll.contentView.bounds.width)")
                }
                for child in view.subviews { inspect(child) }
            }
            inspect(host)
        }
        if measured.width > size.width + 1 || measured.height > size.height + 1 {
            failures.append("\(name) exceeds its capture: \(measured)")
        }
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            failures.append("\(name) has no bitmap"); return
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            failures.append("\(name) has no PNG"); return
        }
        do { try png.write(to: output.appendingPathComponent(name + ".png")) }
        catch { failures.append("\(name): \(error)") }
        window.close()
    }
}
#endif

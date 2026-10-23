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
            DefaultsKey.notchNetworkFontSize: arguments.contains("--large") ? 16.0 : 10.0,
            DefaultsKey.notchNetworkDecimals: arguments.contains("--large") ? 2 : 1,
            DefaultsKey.notchNetworkTint: arguments.contains("--custom") ? "custom" : arguments.contains("--large") ? "direction" : "white",
            DefaultsKey.notchNetworkDownloadColor: "CDB5FF",
            DefaultsKey.notchNetworkUploadColor: "FFD27D",
            DefaultsKey.notchNetworkColorScope: arguments.contains("--arrows-only") ? "arrows" : "all",
            DefaultsKey.notchNetworkWeight: arguments.contains("--large") ? "bold" : "medium",
            DefaultsKey.notchNetworkArrowGap: arguments.contains("--large") ? 10.0 : 3.0,
            DefaultsKey.notchNetworkOpacity: 0.9,
            DefaultsKey.notchNetworkAlignment: "center",
            DefaultsKey.notchNavigationPosition: "top",
            DefaultsKey.notchSystemLayout: "original",
            DefaultsKey.notchSystemCardScale: 1.0,
            DefaultsKey.notchSystemHorizontalSpacing: 10.0,
            DefaultsKey.notchSystemVerticalSpacing: 10.0,
            DefaultsKey.notchSystemMetricOrder: "",
            DefaultsKey.notchSystemHiddenMetrics: "",
            "AppleShowScrollBars": "Always",
            DefaultsKey.notchNetworkWidth: arguments.contains("--large") ? 144.0 : 72.0,
            DefaultsKey.notchNetworkOffset: arguments.contains("--large") ? 3.0 : 0.0,
            DefaultsKey.notchNetworkUploadOnLeft: false,
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
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        host.layoutSubtreeIfNeeded()
        if island {
            func inspect(_ view: NSView) {
                if let scroll = view as? NSScrollView, scroll.hasVerticalScroller || scroll.hasHorizontalScroller {
                    failures.append("\(name) exposes a native scroller")
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

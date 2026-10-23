// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors

import Foundation

/// The order is the upstream System page's reading order. Hidden and
/// temporarily unavailable readings keep their place in the saved queue.
enum NotchSystemMetric: String, CaseIterable, Identifiable, Hashable {
    case cpu, gpu, memory, battery, network, disk, power, fan, connectedDevices

    var id: String { rawValue }
    var feature: AppFeature {
        switch self {
        case .cpu: return .monitorCPU
        case .gpu: return .monitorGPU
        case .memory: return .monitorMemory
        case .battery, .power: return .monitorPower
        case .network: return .monitorNetwork
        case .disk: return .monitorDisk
        case .fan: return .fanControl
        case .connectedDevices: return .connectedDevices
        }
    }

    func available(hasBattery: Bool, fans: Int, in defaults: UserDefaults) -> Bool {
        feature.isAvailable(in: defaults) && (self != .battery || hasBattery) && (self != .fan || fans > 0)
    }
}

struct NotchSystemStyle: Equatable {
    var scale: CGFloat
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    init(scale: Double = 1, horizontalSpacing: Double = 10, verticalSpacing: Double = 10) {
        self.scale = scale.isFinite ? min(1.35, max(0.8, scale)) : 1
        self.horizontalSpacing = horizontalSpacing.isFinite ? min(24, max(4, horizontalSpacing)) : 10
        self.verticalSpacing = verticalSpacing.isFinite ? min(24, max(4, verticalSpacing)) : 10
    }

    var cardHeight: CGFloat { NotchLayout.systemCardHeight * scale }
    var cardWidth: CGFloat { NotchLayout.systemCardWidth * scale }

    static func stored(in defaults: UserDefaults = .standard) -> Self {
        .init(scale: defaults.object(forKey: DefaultsKey.notchSystemCardScale) as? Double ?? 1,
              horizontalSpacing: defaults.object(forKey: DefaultsKey.notchSystemHorizontalSpacing) as? Double ?? 10,
              verticalSpacing: defaults.object(forKey: DefaultsKey.notchSystemVerticalSpacing) as? Double ?? 10)
    }
}

struct NotchSystemConfiguration: Equatable {
    var order: [NotchSystemMetric]
    var hidden: Set<NotchSystemMetric>

    init(order: String = "", hidden: String = "") {
        var seen = Set<NotchSystemMetric>()
        let saved = order.split(separator: ",").compactMap { NotchSystemMetric(rawValue: String($0)) }
        self.order = (saved + NotchSystemMetric.allCases).filter { seen.insert($0).inserted }
        self.hidden = Set(hidden.split(separator: ",").compactMap { NotchSystemMetric(rawValue: String($0)) })
    }

    func visible(hasBattery: Bool, fans: Int, in defaults: UserDefaults = .standard) -> [NotchSystemMetric] {
        order.filter { !hidden.contains($0) && $0.available(hasBattery: hasBattery, fans: fans, in: defaults) }
    }

    static func stored(in defaults: UserDefaults = .standard) -> Self {
        .init(order: defaults.string(forKey: DefaultsKey.notchSystemMetricOrder) ?? "",
              hidden: defaults.string(forKey: DefaultsKey.notchSystemHiddenMetrics) ?? "")
    }
}

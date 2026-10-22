// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors

import Foundation
import CoreGraphics

struct NotchNetworkStyle: Equatable {
    var fontSize: CGFloat = 10
    var wingWidth: CGFloat = 72
    var verticalOffset: CGFloat = 0
    var uploadOnLeft = false
    var fullUnits = false

    init(fontSize: Double = 10, wingWidth: Double = 72, verticalOffset: Double = 0, uploadOnLeft: Bool = false, fullUnits: Bool = false) {
        self.fontSize = Self.clamp(fontSize, 9...14, fallback: 10).rounded()
        self.wingWidth = max(Self.minimumWidth(fontSize: self.fontSize, fullUnits: fullUnits),
                             Self.clamp(wingWidth, 64...144, fallback: 72).rounded())
        self.verticalOffset = Self.clamp(verticalOffset, -3...3, fallback: 0).rounded()
        self.uploadOnLeft = uploadOnLeft
        self.fullUnits = fullUnits
    }

    static func minimumWidth(fontSize: CGFloat, fullUnits: Bool = false) -> CGFloat { ceil(fontSize * (fullUnits ? 8 : 4.9) + 19) }

    private static func clamp(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> CGFloat {
        CGFloat(value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback)
    }

    func offset(in height: CGFloat) -> CGFloat {
        let room = max(0, (height - fontSize - 4) / 2)
        return min(room, max(-room, verticalOffset))
    }

    static func stored(in defaults: UserDefaults = .standard) -> Self {
        Self(fontSize: defaults.object(forKey: DefaultsKey.notchNetworkFontSize) as? Double ?? 10,
             wingWidth: defaults.object(forKey: DefaultsKey.notchNetworkWidth) as? Double ?? 72,
             verticalOffset: defaults.double(forKey: DefaultsKey.notchNetworkOffset),
             uploadOnLeft: defaults.bool(forKey: DefaultsKey.notchNetworkUploadOnLeft),
             fullUnits: defaults.bool(forKey: DefaultsKey.notchNetworkFullUnits))
    }
}

enum NotchNetworkSupport {
    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.string(forKey: DefaultsKey.notchIdleContent) == "network"
            && !defaults.bool(forKey: DefaultsKey.notchNetworkPaused)
            && AppFeature.monitorNetwork.isAvailable(in: defaults)
    }

    static func toggle(in defaults: UserDefaults = .standard) {
        if isEnabled(in: defaults) {
            defaults.set(true, forKey: DefaultsKey.notchNetworkPaused)
        } else {
            defaults.set("network", forKey: DefaultsKey.notchIdleContent)
            defaults.set(false, forKey: DefaultsKey.notchNetworkPaused)
        }
    }

    static func avoidsMenus(in defaults: UserDefaults = .standard) -> Bool {
        isEnabled(in: defaults) && defaults.bool(forKey: DefaultsKey.notchNetworkAvoidMenus)
    }
}

/// Hold the readout through short pauses. Hidden traffic still needs samples
/// so an arriving transfer can reveal it; explicit pause releases that demand.
struct NotchNetworkActivity {
    private var quietSince: TimeInterval?
    private(set) var visible = true

    mutating func update(download: Double?, upload: Double?, threshold: Double,
                         delay: TimeInterval, now: TimeInterval) -> Bool {
        guard let download, let upload, download.isFinite, upload.isFinite,
              download >= 0, upload >= 0 else { return visible }
        let threshold = threshold.isFinite ? min(1_024_000, max(0, threshold)) : 1024
        let delay = delay.isFinite ? min(60, max(3, delay)) : 10
        if max(download, upload) > threshold {
            quietSince = nil
            visible = true
        } else {
            if quietSince == nil || now < quietSince! { quietSince = now }
            visible = now - (quietSince ?? now) < delay
        }
        return visible
    }
}


/// Compact shares the existing panel convention; full always spells /s and
/// keeps a decimal on scaled units instead of rounding a transfer to an integer.
enum NotchNetworkFormat {
    static func reading(_ bytesPerSecond: Double?, inBits: Bool = false, fullUnits: Bool = false,
                        locale: Locale = MetricFormat.locale) -> String {
        guard let bytesPerSecond, bytesPerSecond.isFinite, bytesPerSecond >= 0 else { return "—" }
        guard fullUnits else { return MetricFormat.networkRateCompact(bytesPerSecond, inBits: inBits) }
        let units = inBits ? ["bit/s", "Kbit/s", "Mbit/s", "Gbit/s", "Tbit/s", "Pbit/s"]
                           : ["B/s", "KB/s", "MB/s", "GB/s", "TB/s", "PB/s"]
        let base = inBits ? 1000.0 : 1024.0
        var value = bytesPerSecond * (inBits ? 8 : 1)
        guard value.isFinite else { return "—" }
        var index = 0
        while index < units.count - 1 && (value * 10).rounded() / 10 >= base {
            value /= base
            index += 1
        }
        return String(format: index == 0 ? "%.0f %@" : "%.1f %@", locale: locale, value, units[index])
    }
}

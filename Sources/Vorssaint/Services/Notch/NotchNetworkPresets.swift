// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors

import Foundation

/// Only appearance is restored. A preset never enables monitoring or changes
/// pause, privacy, menu avoidance, or low-traffic behavior.
struct NotchNetworkPreset: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var style: NotchNetworkStyle
    var unit: String
    var capsuleDrop: Double

    static func capture(name: String, in defaults: UserDefaults = .standard) -> Self {
        .init(name: name, style: .stored(in: defaults),
              unit: defaults.string(forKey: DefaultsKey.networkSpeedUnit) == "bits" ? "bits" : "bytes",
              capsuleDrop: Double(NotchCapsuleFit(width: 0, height: 0, drop: defaults.double(forKey: DefaultsKey.notchCapsuleFitDrop)).drop))
    }

    func apply(in defaults: UserDefaults = .standard) {
        // Reuse the live style normalizer, including its fitted minimum width.
        let s = normalizedStyle
        let values: [String: Any] = [
            DefaultsKey.notchNetworkFixedWidth: s.usesFixedWidth,
            DefaultsKey.notchNetworkFontSize: Double(s.fontSize), DefaultsKey.notchNetworkWidth: Double(s.wingWidth),
            DefaultsKey.notchNetworkOffset: Double(s.verticalOffset), DefaultsKey.notchNetworkUploadOnLeft: s.uploadOnLeft,
            DefaultsKey.notchNetworkFullUnits: s.fullUnits, DefaultsKey.notchNetworkDecimals: s.decimals,
            DefaultsKey.notchNetworkWeight: s.weight, DefaultsKey.notchNetworkTint: s.tint,
            DefaultsKey.notchNetworkDownloadColor: s.downloadColor, DefaultsKey.notchNetworkUploadColor: s.uploadColor,
            DefaultsKey.notchNetworkColorScope: s.colorScope, DefaultsKey.notchNetworkOpacity: s.opacity,
            DefaultsKey.notchNetworkAlignment: s.alignment, DefaultsKey.notchNetworkArrowGap: Double(s.arrowGap),
            DefaultsKey.notchNetworkOuterSpacing: Double(s.outerSpacing), DefaultsKey.notchNetworkInnerSpacing: Double(s.innerSpacing),
            DefaultsKey.networkSpeedUnit: unit == "bits" ? "bits" : "bytes",
            DefaultsKey.notchCapsuleFitDrop: Double(NotchCapsuleFit(width: 0, height: 0, drop: capsuleDrop).drop)
        ]
        for (key, value) in values { defaults.set(value, forKey: key) }
    }

    var normalizedStyle: NotchNetworkStyle {
        .init(fontSize: Double(style.fontSize), wingWidth: Double(style.wingWidth), verticalOffset: Double(style.verticalOffset),
              uploadOnLeft: style.uploadOnLeft, fullUnits: style.fullUnits, decimals: style.decimals, weight: style.weight,
              tint: style.tint, opacity: style.opacity, alignment: style.alignment, arrowGap: Double(style.arrowGap),
              downloadColor: style.downloadColor, uploadColor: style.uploadColor, colorScope: style.colorScope,
              outerSpacing: Double(style.outerSpacing), innerSpacing: Double(style.innerSpacing), fixedWidth: style.usesFixedWidth)
    }

    func matches(in defaults: UserDefaults = .standard) -> Bool {
        let current = Self.capture(name: name, in: defaults)
        return normalizedStyle == current.style && unit == current.unit && capsuleDrop == current.capsuleDrop
    }
}

struct NotchNetworkPresetLibrary {
    static let limit = 30
    var presets: [NotchNetworkPreset] = []
    private(set) var readable = true

    init(data: Data) {
        guard !data.isEmpty else { return }
        guard data.count <= 262_144, let decoded = try? JSONDecoder().decode([NotchNetworkPreset].self, from: data),
              decoded.count <= Self.limit else { readable = false; return }
        var ids = Set<UUID>()
        var names = Set<String>()
        for var preset in decoded {
            preset.name = Self.cleanName(preset.name)
            guard !preset.name.isEmpty, ids.insert(preset.id).inserted,
                  names.insert(Self.nameKey(preset.name)).inserted else { readable = false; presets = []; return }
            preset.style = preset.normalizedStyle
            presets.append(preset)
        }
    }

    var encoded: Data? { readable ? try? JSONEncoder().encode(presets) : nil }
    static func cleanName(_ name: String) -> String {
        String(name.components(separatedBy: .controlCharacters).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
    }
    private static func nameKey(_ name: String) -> String {
        cleanName(name).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
    func accepts(_ name: String, excluding id: UUID? = nil) -> Bool {
        readable && !Self.cleanName(name).isEmpty
            && !presets.contains { $0.id != id && Self.nameKey($0.name) == Self.nameKey(name) }
    }
}

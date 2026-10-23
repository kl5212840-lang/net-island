// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors
import Foundation

/// Island-only appearance. Missing values preserve the incumbent presentation.
/// A single bounded document lets presets capture layout without touching permissions.
struct NotchPageAppearance: Codable, Equatable {
    var values: [String: String] = [:]
    static let storageKey = "notchPageAppearance"
    static let presetsKey = "notchPageAppearancePresets"
    static let prefixes = ["tools.", "controls.", "system.", "nav."]
    init(values: [String: String] = [:]) { self.values = values }
    init(data: Data) {
        self.init()
        guard data.count <= 65_536, let decoded = try? JSONDecoder().decode(Self.self, from: data),
              decoded.values.count <= 150 else { return }
        values = decoded.values.filter { entry in
            Self.prefixes.contains(where: { entry.key.hasPrefix($0) }) && entry.key.count <= 80 && entry.value.count <= 2000
        }
    }
    static func stored(in defaults: UserDefaults = .standard) -> Self { .init(data: defaults.data(forKey: storageKey) ?? Data()) }
    var encoded: Data { (try? JSONEncoder().encode(self)) ?? Data() }
    func number(_ key: String, _ fallback: Double, _ range: ClosedRange<Double>) -> CGFloat {
        guard let value = values[key].flatMap(Double.init), value.isFinite else { return CGFloat(fallback) }
        return CGFloat(min(range.upperBound, max(range.lowerBound, value)))
    }
    func flag(_ key: String, _ fallback: Bool = false) -> Bool { values[key].map { $0 == "true" } ?? fallback }
    var toolsScale: CGFloat { number("tools.scale", 1, 0.7...1.4) }
    var toolsFont: CGFloat { number("tools.font", 10, 8...16) }
    var toolsLabels: Bool { !flag("tools.iconOnly") }
    var toolsGap: CGFloat { number("tools.gap", 6, 4...32) }
    var toolsRowGap: CGFloat { number("tools.rowGap", 6, 4...32) }
    var toolsPadding: CGFloat { number("tools.padding", 0, 0...24) }
    var toolsWidth: CGFloat { max(56, NotchLayout.toolWidth * toolsScale) }
    var toolsHeight: CGFloat { toolsLabels ? max(NotchLayout.toolHeight * toolsScale, 32 * toolsScale + toolsFont * 2.5 + 14) : max(44, 40 * toolsScale) }
    var toolsColumns: Int { Int(number("tools.columns", 0, 0...8)) }
    var toolsAligned: Bool { flag("tools.alignColumns") }
    var toolsItems: [String]? { values["tools.items"].map { $0.split(separator: ",").map(String.init) } }
    func toolsCapacity(width: CGFloat) -> Int {
        let capacity = NotchLayout.railCapacity(width: max(0, width - toolsPadding * 2), itemWidth: toolsWidth, spacing: toolsGap)
        return toolsColumns > 0 ? min(toolsColumns, capacity) : capacity
    }
    func toolsRows(count: Int, width: CGFloat, height: CGFloat) -> Int {
        if toolsColumns > 0 { return max(1, (count + toolsCapacity(width: width) - 1) / toolsCapacity(width: width)) }
        return NotchLayout.railRows(count: count, perRow: toolsCapacity(width: width), rowHeight: toolsHeight,
                                   spacing: toolsRowGap, height: max(0, height - toolsPadding * 2))
    }
    var controlsColumns: Int { Int(number("controls.columns", 2, 1...2)) }
    var controlsTrack: CGFloat { number("controls.track", 100, 50...100) / 100 }
    var controlsValues: Bool { flag("controls.values") }
    var legacyLevelRow: Bool { values["controls.placement"] == "header" && values["controls.columns"] == nil }
    func controlsColumnCount(levels: Int) -> Int { legacyLevelRow ? max(1, levels) : controlsColumns }
    var controlsRowHeight: CGFloat { controlsValues ? 52 : legacyLevelRow ? NotchLayout.levelRowHeight : 36 }
    func controlsHeight(levels: Int) -> CGFloat {
        guard levels > 0 else { return 0 }
        let columns = controlsColumnCount(levels: levels)
        return CGFloat((levels + columns - 1) / columns) * controlsRowHeight
            + CGFloat(max(0, (levels + columns - 1) / columns - 1)) * NotchLayout.bandLevelSpacing
    }
    /// A top-row request is honored only without custom header buttons. Even
    /// one such button reserves its wing; levels then move into the body.
    func bandLevels(_ count: Int, band: NotchBand, headerHasButtons: Bool) -> Int {
        guard values["controls.placement"] == "header", !headerHasButtons else { return 0 }
        return NotchLayout.bandLevelCount(count, band: band)
    }
    var systemFontScale: CGFloat { number("system.font", 1, 0.75...1.4) }
    var systemPadding: CGFloat { number("system.padding", 12, 6...24) }
    var systemMeters: Bool { !flag("system.hideMeters") }
    var systemTint: String { values["system.tint"] ?? "original" }
    func navigation(module: String, fallback: String) -> NotchNavigationStyle {
        let prefix = flag("nav.\(module).override") ? "nav.\(module)." : "nav.shared."
        return .init(position: values[prefix + "position"] ?? fallback,
                     offset: number(prefix + "offset", 0, -25...25),
                     size: number(prefix + "size", 11, 8...18),
                     margin: number(prefix + "margin", 0, 0...24))
    }
    mutating func reset(_ prefix: String) { values = values.filter { !$0.key.hasPrefix(prefix) } }
}

struct NotchNavigationStyle: Equatable {
    var position = "top"
    var offset: CGFloat = 0
    var size: CGFloat = 11
    var margin: CGFloat = 0
    /// Arrow centers follow the actual visible body, not a hypothetical full
    /// header. Short pages collapse the interval instead of pushing targets out.
    func topInset(contentTop: CGFloat, contentBottom: CGFloat, firstRowHeight: CGFloat) -> CGFloat {
        let start = max(0, contentTop)
        let end = max(start, contentBottom)
        let firstCenter = min(max(start + 22, end - 22), start + max(22, firstRowHeight / 2))
        let lastCenter = max(firstCenter, end - 22)
        let fraction: CGFloat = position == "bottom" ? 1 : position == "center" ? 0.5 : 0
        let center = min(lastCenter, max(firstCenter, firstCenter + (lastCenter - firstCenter) * (fraction + offset / 100)))
        return max(0, center - 22)
    }
}

struct NotchPagePreset: Codable, Identifiable {
    var id = UUID()
    var name: String
    var appearance: NotchPageAppearance
    var system: [String: String]
    static let systemKeys = [DefaultsKey.notchSystemLayout, DefaultsKey.notchSystemCardScale,
        DefaultsKey.notchSystemHorizontalSpacing, DefaultsKey.notchSystemVerticalSpacing,
        DefaultsKey.notchSystemMetricOrder, DefaultsKey.notchSystemHiddenMetrics, DefaultsKey.notchNavigationPosition,
        DefaultsKey.notchControlOrder, DefaultsKey.notchHiddenControls]
    static let numericKeys = Set([DefaultsKey.notchSystemCardScale, DefaultsKey.notchSystemHorizontalSpacing, DefaultsKey.notchSystemVerticalSpacing])
    static func capture(name: String, toolItems: [String]? = nil, in defaults: UserDefaults = .standard) -> Self {
        var appearance = NotchPageAppearance.stored(in: defaults)
        if let toolItems { appearance.values["tools.items"] = toolItems.joined(separator: ",") }
        return .init(name: name, appearance: appearance, system: Dictionary(uniqueKeysWithValues:
            systemKeys.compactMap { key in defaults.object(forKey: key).map { (key, String(describing: $0)) } }))
    }
    func apply(in defaults: UserDefaults = .standard) {
        defaults.set(NotchPageAppearance(data: appearance.encoded).encoded, forKey: NotchPageAppearance.storageKey)
        for key in Self.systemKeys {
            guard let value = system[key] else { defaults.removeObject(forKey: key); continue }
            if Self.numericKeys.contains(key) { if let number = Double(value), number.isFinite { defaults.set(number, forKey: key) } }
            else { defaults.set(value, forKey: key) }
        }
    }
}
struct NotchPagePresetLibrary {
    var items: [NotchPagePreset] = []
    var readable = true
    init(data: Data) {
        guard !data.isEmpty else { return }
        guard data.count <= 262_144, let decoded = try? JSONDecoder().decode([NotchPagePreset].self, from: data), decoded.count <= 30 else { readable = false; return }
        var ids = Set<UUID>(), names = Set<String>()
        for var preset in decoded {
            preset.name = NotchNetworkPresetLibrary.cleanName(preset.name)
            guard !preset.name.isEmpty, ids.insert(preset.id).inserted, names.insert(preset.name.lowercased()).inserted else { readable = false; items = []; return }
            preset.appearance = NotchPageAppearance(data: preset.appearance.encoded)
            preset.system = preset.system.filter { NotchPagePreset.systemKeys.contains($0.key) && $0.value.count <= 2000 }
            items.append(preset)
        }
    }
    var encoded: Data? { readable ? try? JSONEncoder().encode(items) : nil }
    func accepts(_ name: String, excluding: UUID? = nil) -> Bool {
        let clean = NotchNetworkPresetLibrary.cleanName(name)
        return readable && !clean.isEmpty && !items.contains { $0.id != excluding && $0.name.localizedCaseInsensitiveCompare(clean) == .orderedSame }
    }
}

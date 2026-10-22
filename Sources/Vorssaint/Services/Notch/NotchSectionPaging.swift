// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Original keeps the upstream row arrangement before navigation gutters
/// were introduced. The cards still fit inside the safe, narrower viewport.
enum NotchSystemLayout: String, CaseIterable {
    case original, adaptive, twoColumns, threeColumns

    static func resolved(_ value: String) -> Self { Self(rawValue: value) ?? .original }

    func rows(count: Int, width: CGFloat, originalWidth: CGFloat) -> [Range<Int>] {
        let available = max(0, width - NotchLayout.systemHoverInset(width: width) * 2)
        switch self {
        case .original:
            return NotchLayout.systemRowRanges(count: count, width: max(0, originalWidth
                - NotchLayout.systemHoverInset(width: originalWidth) * 2))
        case .adaptive:
            return NotchLayout.systemRowRanges(count: count, width: available)
        case .twoColumns, .threeColumns:
            // Manual columns retain readable cards on unusually narrow islands.
            let capacity = NotchLayout.railCapacity(width: available, itemWidth: 100, spacing: NotchLayout.rowSpacing)
            let columns = min(self == .twoColumns ? 2 : 3, capacity)
            return stride(from: 0, to: max(0, count), by: columns).map { $0..<min(count, $0 + columns) }
        }
    }
}

enum NotchNavigationPosition: String, CaseIterable {
    case top, center, bottom

    static func resolved(_ value: String) -> Self { Self(rawValue: value) ?? .top }

    /// Keep the 44-point target below the header and clear of the lower curve.
    func topInset(pageTop: CGFloat, height: CGFloat) -> CGFloat {
        let lower = max(pageTop, height - 44 - 28)
        let upper = min(pageTop + 20, lower)
        switch self {
        case .top: return upper
        case .center: return (upper + lower) / 2
        case .bottom: return lower
        }
    }
}

/// The checked, ordered pages form a ring; unavailable pages never enter it.
enum NotchSectionNavigation {
    static func sideInset(height: CGFloat) -> CGFloat { NotchLayout.shoulder(height: height) + 4 }

    /// A shared full-row header keeps the target still when one page has no
    /// toolbar or another wraps its controls around the camera.
    static func headerBoundary(in geometry: NotchGeometry) -> CGFloat {
        var header = geometry
        header.pageTop = .row
        header.requiresFullWidthHeader = true
        return header.pageTopInset
    }

    static func neighbor<T: Equatable>(of selected: T, in pages: [T], forward: Bool) -> T? {
        guard pages.count > 1 else { return nil }
        guard let index = pages.firstIndex(of: selected) else { return pages.first }
        return pages[(index + (forward ? 1 : pages.count - 1)) % pages.count]
    }
}

/// The gallery rests on a row boundary at all times: rows step whole, and a
/// highlighted tile pulls its row into view with the least movement.
enum NotchSectionPaging {
    static func rows(count: Int, columns: Int) -> Int {
        let columns = max(1, columns)
        return max(1, (max(0, count) + columns - 1) / columns)
    }

    /// Rows the first visible row can rest on.
    static func positions(rows: Int, visible: Int) -> Int {
        max(1, max(1, rows) - max(1, visible) + 1)
    }

    static func clamped(_ row: Int, rows: Int, visible: Int) -> Int {
        min(max(0, row), positions(rows: rows, visible: visible) - 1)
    }

    /// The first row that keeps `row` in view while moving as little as
    /// possible away from `first`.
    static func revealing(row: Int, first: Int, rows: Int, visible: Int) -> Int {
        let visible = max(1, visible)
        var first = clamped(first, rows: rows, visible: visible)
        if row < first { first = row } else if row >= first + visible { first = row - visible + 1 }
        return clamped(first, rows: rows, visible: visible)
    }
}

/// Wheel and trackpad input becomes whole rows. A flick moves one row: the
/// first step needs the same small distance as the island's own gestures,
/// later steps of one continuous drag follow the row pitch, and momentum
/// after the fingers lift is left alone. A wheel notch steps one row.
struct NotchSectionScroll {
    static let firstStep = 24.0
    static let rowStep = Double(NotchLayout.sectionTileHeight + NotchLayout.sectionSpacing)
    /// Continuous sequences without phases (wheel smoothing glides, some
    /// mice) end when their events pause.
    static let sequenceGap = 0.35
    private var distance = 0.0
    private var direction = 0
    private var stepped = false
    private var lastTimestamp: TimeInterval?

    /// Rows to move; positive reveals the rows below. `deltaY` is AppKit's
    /// scrolling delta, already flipped for natural scrolling.
    mutating func steps(deltaY: Double, timestamp: TimeInterval, precise: Bool, hasPhase: Bool,
                        began: Bool, ended: Bool, momentum: Bool) -> Int {
        guard deltaY.isFinite, timestamp.isFinite else { self = Self(); return 0 }
        if momentum { return 0 }
        if ended { self = Self(); return 0 }
        guard precise else {
            self = Self()
            return deltaY == 0 ? 0 : (deltaY < 0 ? 1 : -1)
        }
        if began || lastTimestamp.map({ timestamp < $0 || (!hasPhase && timestamp - $0 > Self.sequenceGap) }) == true {
            self = Self()
        }
        lastTimestamp = timestamp
        // Turning back starts over with the short first step, so a change
        // of mind answers as quickly as the first movement did.
        if deltaY != 0 {
            let incomingDirection = deltaY < 0 ? 1 : -1
            if direction != 0, direction != incomingDirection { distance = 0; stepped = false }
            direction = incomingDirection
        }
        distance += deltaY
        var steps = 0
        while abs(distance) >= (stepped ? Self.rowStep : Self.firstStep) {
            distance += Double(direction) * (stepped ? Self.rowStep : Self.firstStep)
            stepped = true
            steps += 1
        }
        return direction * steps
    }
}

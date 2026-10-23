// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors

import Foundation

enum NotchHeaderPosition: String, CaseIterable {
    case leftOuter, leftInner, rightInner, rightOuter

    static func resolved(_ raw: String) -> Self { Self(rawValue: raw) ?? .leftOuter }

    /// Player/capture pages own the leading camera wing. Their shortcuts
    /// share the other wing instead of overlaying the page or the camera.
    func effective(wrapsCamera: Bool) -> Self {
        guard wrapsCamera else { return self }
        return self == .leftOuter ? .rightOuter : self == .leftInner ? .rightInner : self
    }

    func title(_ text: NotchNetworkStrings) -> String {
        switch self {
        case .leftOuter: text.headerLeftOuter
        case .leftInner: text.headerLeftInner
        case .rightInner: text.headerRightInner
        case .rightOuter: text.headerRightOuter
        }
    }
}

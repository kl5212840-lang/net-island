// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors

import Foundation

/// Presentation only. No preference, sampling lease or selected page changes.
/// Closure is debounced across menu handoffs, never a timeout on an open menu.
struct NotchMenuYieldState {
    private(set) var hidden = false
    private var began = 0.0
    private var sawOpen = false
    private var dismissed = false
    private var closedSince: TimeInterval?

    mutating func begin(now: TimeInterval) {
        hidden = true; began = now; sawOpen = false; dismissed = false; closedSince = nil
    }
    mutating func dismiss() { dismissed = true }
    mutating func sample(open: Bool, pointerInBar: Bool, now: TimeInterval) {
        if open {
            if !hidden { begin(now: now) }
            sawOpen = true; closedSince = nil
            return
        }
        guard hidden else { return }
        guard now - began >= 0.45, sawOpen || dismissed || !pointerInBar else { closedSince = nil; return }
        if closedSince == nil { closedSince = now }
        if now - (closedSince ?? now) >= 0.25 { self = Self() }
    }
}

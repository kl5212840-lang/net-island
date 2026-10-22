// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors

import SwiftUI

/// The same compact rate as the menu bar, with its direction always visible.
/// A missing first sample is a dash; a measured idle connection is zero.
struct NotchNetworkReadout: View {
    let bytesPerSecond: Double?
    var upload = false
    var inBits = false
    @ObservedObject private var l10n = L10n.shared

    private var rate: Double? {
        bytesPerSecond.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
    }
    private var title: String { upload ? l10n.s.networkUpload : l10n.s.networkDownload }
    private var detail: String {
        title + ": " + (rate.map { MetricFormat.networkRate($0, inBits: inBits) } ?? "—")
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: upload ? "arrow.up" : "arrow.down")
                .font(.system(size: 9, weight: .semibold))
            Text(rate.map { MetricFormat.networkRateCompact($0, inBits: inBits) } ?? "—")
                .font(.system(size: 10, weight: .medium)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.85)
        }
        .foregroundStyle(.white.opacity(0.9))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(detail)
        .help(detail)
    }
}

/// Only the readings observe the snapshot, so a sample does not resize or
/// animate the island. The persisted unit follows the existing Network panel.
struct NotchNetworkWing: View {
    var upload = false
    @ObservedObject private var monitor = SystemMonitor.shared
    @AppStorage(DefaultsKey.networkSpeedUnit) private var unit = NetworkSpeedUnit.bytes

    var body: some View {
        NotchNetworkReadout(bytesPerSecond: upload ? monitor.snapshot.netUpBytesPerSec : monitor.snapshot.netDownBytesPerSec,
                            upload: upload, inBits: unit == .bits)
    }
}

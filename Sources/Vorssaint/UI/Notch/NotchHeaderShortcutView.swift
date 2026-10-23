// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors

import SwiftUI

struct NotchHeaderShortcutView: View {
    let button: NotchHeaderButton
    @ObservedObject var service: NotchService
    var compact = false
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var awake = KeepAwakeManager.shared
    @ObservedObject private var microphone = MicMuteService.shared
    @ObservedObject private var recorder = ScreenRecorderService.shared

    var body: some View {
        if let action = button.action {
            if action == .networkReadout {
                NotchNetworkToggle(service: service, compact: compact, customTitle: button.label)
            } else {
                let selected = isSelected(action)
                Button { service.activateQuickAction(action) } label: {
                    Image(systemName: symbol(action))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(selected ? 1 : 0.65))
                        .frame(width: compact ? 24 : 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(NotchButtonStyle(cornerRadius: 9, lifts: false))
                .help(title(action))
                .accessibilityLabel(title(action))
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("notch.header." + action.id)
            }
        }
    }

    private func title(_ action: NotchQuickAction) -> String {
        if !button.label.isEmpty { return button.label }
        switch action {
        case .pin where service.pinned: return FeatureStrings.notch(l10n.language).unpin
        case .explore where service.showingSections: return l10n.s.obBack
        case .control(.microphone) where microphone.isMuted: return l10n.s.micUnmuteName
        default: return action.title(l10n)
        }
    }
    private func isSelected(_ action: NotchQuickAction) -> Bool {
        switch action {
        case .pin: service.pinned
        case .explore: service.showingSections
        case .control(.microphone): microphone.isMuted
        case .control(.keepAwake): awake.isActive
        case .control(.recording): recorder.isRecording
        case .module(let module): !service.showingSections && service.selected == module
        default: false
        }
    }
    private func symbol(_ action: NotchQuickAction) -> String {
        switch action {
        case .pin where service.pinned: "pin.fill"
        case .explore where service.showingSections: "chevron.left"
        case .control(.microphone) where microphone.isMuted: "mic.slash.fill"
        case .control(.keepAwake) where awake.isActive: "cup.and.saucer.fill"
        case .control(.recording) where recorder.isRecording: "stop.circle.fill"
        default: action.symbol
        }
    }
}

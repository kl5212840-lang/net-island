// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors

import SwiftUI

struct NotchNetworkPresetSettings: View {
    var appearanceSignature: [String] = []
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchNetworkPresets) private var data = Data()
    @State private var name = ""
    @State private var renaming: UUID?
    @State private var editedName = ""
    private var text: NotchNetworkStrings { .init(l10n.language) }
    private var library: NotchNetworkPresetLibrary { .init(data: data) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text.customPresets).font(.callout.weight(.semibold))
            Text(text.presetEmpty).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if library.readable {
                HStack(spacing: 8) {
                    TextField(text.presetName, text: $name).textFieldStyle(.roundedBorder)
                        .onSubmit(save)
                    Button(text.savePreset, action: save)
                        .disabled(!library.accepts(name) || library.presets.count >= NotchNetworkPresetLibrary.limit)
                }
                Text(text.presetNameHint).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(library.presets) { preset in
                    HStack(spacing: 8) {
                        if renaming == preset.id {
                            TextField(text.presetName, text: $editedName).textFieldStyle(.roundedBorder)
                                .onSubmit { rename(preset.id) }
                            Button(text.done) { rename(preset.id) }
                                .disabled(!library.accepts(editedName, excluding: preset.id))
                            Button(text.cancel) { renaming = nil }
                        } else {
                            Button {
                                preset.apply()
                                NotchService.shared.syncWithPreferences()
                            } label: {
                                HStack(spacing: 8) {
                                    Text(preset.name).lineLimit(1).truncationMode(.tail)
                                    Spacer(minLength: 8)
                                    if preset.matches() {
                                        Image(systemName: "checkmark").accessibilityLabel(text.presetApplied)
                                    }
                                }.contentShape(Rectangle())
                            }.buttonStyle(.plain).help(preset.name)
                            Menu {
                                Button(text.renamePreset) { editedName = preset.name; renaming = preset.id }
                                Button(text.updatePreset) {
                                    modify { items in
                                        guard let index = items.firstIndex(where: { $0.id == preset.id }) else { return }
                                        var replacement = NotchNetworkPreset.capture(name: items[index].name)
                                        replacement.id = preset.id
                                        items[index] = replacement
                                    }
                                }
                                Button(text.deletePreset, role: .destructive) {
                                    modify { $0.removeAll { $0.id == preset.id } }
                                }
                            } label: { Image(systemName: "ellipsis") }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                            .accessibilityLabel(preset.name + ": " + text.customPresets)
                        }
                    }.frame(minHeight: 30)
                }
            } else {
                Text(text.presetUnreadable).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func save() {
        guard library.accepts(name), library.presets.count < NotchNetworkPresetLibrary.limit else { return }
        let preset = NotchNetworkPreset.capture(name: NotchNetworkPresetLibrary.cleanName(name))
        modify { $0.append(preset) }
        name = ""
    }
    private func rename(_ id: UUID) {
        guard library.accepts(editedName, excluding: id) else { return }
        let newName = NotchNetworkPresetLibrary.cleanName(editedName)
        modify { items in
            guard let index = items.firstIndex(where: { $0.id == id }) else { return }
            items[index].name = newName
        }
        renaming = nil
    }
    private func modify(_ action: (inout [NotchNetworkPreset]) -> Void) {
        var latest = NotchNetworkPresetLibrary(data: data)
        guard latest.readable else { return }
        action(&latest.presets)
        if let encoded = latest.encoded { data = encoded }
    }
}

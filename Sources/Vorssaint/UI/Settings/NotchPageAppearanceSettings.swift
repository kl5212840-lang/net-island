// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors
import SwiftUI

struct NotchPageAppearanceSettings: View {
    let module: NotchModule
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var launcher = QuickLauncherService.shared
    @AppStorage(NotchPageAppearance.storageKey) private var data = Data()
    @AppStorage(DefaultsKey.notchControlOrder) private var controlOrder = ""
    @State private var toolsListExpanded = false
    @State private var controlDetailsExpanded = false
    @State private var editingControl: NotchControlItem = .brightness
    @State private var dragging: QuickLauncherItem?
    init(module: NotchModule, expandControls: Bool = false, control: NotchControlItem = .brightness) {
        self.module = module
        _controlDetailsExpanded = State(initialValue: expandControls)
        _editingControl = State(initialValue: control)
    }
    private var chinese: Bool { NotchNetworkStrings(l10n.language).chinese }
    private var appearance: NotchPageAppearance { .init(data: data) }
    private func t(_ zh: String, _ en: String) -> String { chinese ? zh : en }
    private func string(_ key: String, _ fallback: String) -> Binding<String> {
        Binding(get: { appearance.values[key] ?? fallback }, set: { update(key, $0) })
    }
    private func flag(_ key: String, _ fallback: Bool = false) -> Binding<Bool> {
        Binding(get: { appearance.flag(key, fallback) }, set: { update(key, String($0)) })
    }
    private func update(_ key: String, _ value: String) {
        var next = NotchPageAppearance(data: data); next.values[key] = value; data = next.encoded
    }
    var body: some View {
        SettingsCard(title: module.title(l10n.language) + t("外观与布局", " appearance and layout")) {
            VStack(alignment: .leading, spacing: 14) {
                if module == .tools { tools }
                if module == .controls { controls }
                if module == .system { system }
                Divider()
                Button(t("恢复此分区外观默认值", "Restore this section’s appearance defaults")) {
                    var next = appearance; next.reset(module.rawValue + "."); data = next.encoded
                }
                Text(t("调整仅作用于岛内，立即生效。", "Changes apply immediately to the island only."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .onChange(of: data) { _, _ in NotchService.shared.syncWithPreferences(); launcher.objectWillChange.send() }
        .onChange(of: controlOrder) { _, _ in NotchService.shared.syncWithPreferences() }
    }
    private var tools: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(t("排列与留白", "Arrangement and padding")).font(.callout.weight(.semibold))
            Picker(t("列数", "Columns"), selection: string("tools.columns", "0")) {
                Text(t("原版自动排列", "Original automatic arrangement")).tag("0")
                ForEach(2...8, id: \.self) { Text("\($0)").tag(String($0)) }
            }
            Text(t("窄岛会自动减少列数，避免文字和两侧箭头重叠。", "Narrow islands reduce columns to keep labels and side arrows clear."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            slider("tools.gap", t("水平间距", "Horizontal spacing"), fallback: 6, range: 4...32)
            slider("tools.rowGap", t("垂直间距", "Vertical spacing"), fallback: 6, range: 4...32)
            slider("tools.padding", t("四周留白", "Content padding"), fallback: 0, range: 0...24)
            Divider().padding(.vertical, 4)
            Text(t("图标与文字", "Icons and labels")).font(.callout.weight(.semibold))
            Toggle(t("仅显示图标", "Icons only"), isOn: flag("tools.iconOnly"))
            Toggle(t("末行与上方列对齐", "Align the last row with the columns above"), isOn: flag("tools.alignColumns"))
            slider("tools.scale", t("图标大小", "Icon size"), fallback: 1, range: 0.7...1.4, step: 0.05, percent: true)
            slider("tools.font", t("文字大小", "Label size"), fallback: 10, range: 8...16)
            Divider()
            DisclosureGroup(isExpanded: $toolsListExpanded) {
            VStack(alignment: .leading, spacing: 10) {
            Text(t("默认继承现有工具列表。这里的勾选与排序独立保存，不改动独立工具面板。", "Initially follows your existing tool list. Choices and order here are saved separately from the standalone panel."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            ForEach(allTools) { item in
                PanelReorderableItem(item: item, order: toolsOrder, dragging: $dragging) {
                    HStack(spacing: 8) {
                        PanelDragHandle()
                        Toggle(item.islandTitle(l10n), isOn: Binding(get: { selectedTools.contains(item) }, set: { shown in
                            var items = selectedTools
                            if shown { items.append(item) } else { items.removeAll { $0 == item } }
                            update("tools.items", items.map(\.rawValue).joined(separator: ","))
                        })).toggleStyle(.checkbox).disabled(!item.feature.isAvailable)
                        Spacer(minLength: 0)
                        move(item, up: true); move(item, up: false)
                    }.padding(.vertical, 4)
                }
            }
            }
            } label: { Text(t("显示工具与顺序", "Visible tools and order")) }
                .disclosureGroupStyle(SettingsDisclosureStyle())
        }
    }
    private var selectedTools: [QuickLauncherItem] { appearance.toolsItems?.compactMap(QuickLauncherItem.init(rawValue:)) ?? launcher.visibleItems }
    private var allTools: [QuickLauncherItem] {
        let stored = (appearance.values["tools.order"] ?? "").split(separator: ",").compactMap { QuickLauncherItem(rawValue: String($0)) }
        var seen = Set<QuickLauncherItem>()
        return (stored + selectedTools + QuickLauncherItem.allCases).filter { seen.insert($0).inserted }
    }
    private var toolsOrder: Binding<[QuickLauncherItem]> {
        Binding(get: { allTools }, set: { items in
            update("tools.order", items.map(\.rawValue).joined(separator: ","))
            update("tools.items", items.filter { selectedTools.contains($0) }.map(\.rawValue).joined(separator: ","))
        })
    }
    private func move(_ item: QuickLauncherItem, up: Bool) -> some View {
        let index = allTools.firstIndex(of: item) ?? 0
        return Button {
            var order = allTools; let next = index + (up ? -1 : 1)
            guard order.indices.contains(next) else { return }; order.swapAt(index, next); toolsOrder.wrappedValue = order
        } label: { Image(systemName: up ? "chevron.up" : "chevron.down").frame(width: 22, height: 24) }
            .buttonStyle(.plain).disabled(up ? index == 0 : index == allTools.count - 1)
            .accessibilityLabel(t(up ? "上移" : "下移", up ? "Move up" : "Move down") + " " + item.islandTitle(l10n))
    }
    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker(t("布局方式", "Layout mode"), selection: flag("controls.custom")) {
                Text(t("原版分组", "Original groups")).tag(false)
                Text(t("自定义网格", "Custom grid")).tag(true)
            }
            if appearance.controlsCustom {
                customControls
            } else {
            Text(t("位置与排列", "Placement and arrangement")).font(.callout.weight(.semibold))
            Picker(t("滑条位置", "Slider placement"), selection: string("controls.placement", "body")) {
                Text(t("岛内正文（推荐）", "Inside the body (recommended)")).tag("body")
                Text(t("顶部两侧（空间允许时）", "Header wings when space permits")).tag("header")
            }
            Text(t("顶部有自定义快捷图标时，滑条自动放入正文，始终避开刘海和图标。", "When custom shortcuts occupy the header, sliders move into the body and stay clear of the camera and icons."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Picker(t("滑条排列", "Slider arrangement"), selection: string("controls.columns", "2")) {
                Text(t("单列", "One column")).tag("1"); Text(t("双列", "Two columns")).tag("2")
            }
            Divider().padding(.vertical, 4)
            Text(t("读数与尺寸", "Readings and size")).font(.callout.weight(.semibold))
            Toggle(t("显示名称与百分比", "Show labels and percentages"), isOn: flag("controls.values"))
            slider("controls.track", t("滑条长度", "Slider length"), fallback: 100, range: 50...100, suffix: "%")
            Text(t("控件显隐与拖动排序在下方设置，亮度等滑条也可拖动排序。", "Choose and reorder controls below, including the brightness and other sliders."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    private var customControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(t("滑条、播放和快捷操作可混合排序；所有控制项放在岛内，避开顶部图标和刘海。", "Mix sliders, playback and shortcuts in one order. All controls stay inside the body, clear of top shortcuts and the camera."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Picker(t("网格列数", "Grid columns"), selection: string("controls.gridColumns", "3")) {
                ForEach(1...6, id: \.self) { Text("\($0)").tag(String($0)) }
            }
            slider("controls.gap", t("项目间距", "Item spacing"), fallback: 10, range: 4...28)
            slider("controls.padding", t("四周留白", "Content padding"), fallback: 0, range: 0...24)
            Toggle(t("显示滑条名称与百分比", "Show slider labels and percentages"), isOn: flag("controls.values"))
            Text(t("窄岛会减少列数，滑条和播放区域会自动保留足够宽度；超出可见高度的内容可以滚动查看。", "Narrow islands reduce columns and keep sliders and playback wide enough. Scroll to reach content beyond the visible height."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            DisclosureGroup(isExpanded: $controlDetailsExpanded) {
                controlDetails
            } label: { Text(t("逐项顺序、位置与大小", "Per-item order, position and size")) }
                .disclosureGroupStyle(SettingsDisclosureStyle())
        }
    }
    private var orderedControls: [NotchControlItem] {
        let stored = controlOrder.split(separator: ",").compactMap { NotchControlItem(rawValue: String($0)) }
        var seen = Set<NotchControlItem>()
        return (stored + NotchControlItem.allCases).filter { seen.insert($0).inserted }
    }
    private var controlDetails: some View {
        let item = editingControl, key = appearance.controlKey(item), style = appearance.controlStyle(item)
        let index = orderedControls.firstIndex(of: item) ?? 0
        let isShortcut = !item.isLevel && item != .music
        let minimum = Double(style.minimumHeight)
        return VStack(alignment: .leading, spacing: 14) {
            Picker(t("控制项", "Control"), selection: $editingControl) {
                ForEach(orderedControls) { Label($0.title(l10n), systemImage: $0.symbol).tag($0) }
            }
            HStack {
                Text(t("队列顺序", "Queue order")); Spacer()
                Text("\(index + 1) / \(orderedControls.count)").monospacedDigit().foregroundStyle(.secondary)
                controlMove(up: true); controlMove(up: false)
            }
            Text(t("也可调整尚未启用的控制项；在下方勾选后生效。", "You can prepare hidden controls here; enable them below to show them."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            Picker(t("起始列", "Starting column"), selection: string(key + "column", "0")) {
                Text(t("自动接排", "Automatic")).tag("0")
                ForEach(1...6, id: \.self) { Text("\($0)").tag(String($0)) }
            }
            Picker(t("占用列数", "Column span"), selection: string(key + "span", item == .music ? "6" : item.isLevel ? "2" : "1")) {
                ForEach(1...6, id: \.self) { Text("\($0)").tag(String($0)) }
            }
            Toggle(t("另起一行", "Start a new row"), isOn: flag(key + "newRow"))
            Picker(t("区域内对齐", "Alignment within the area"), selection: string(key + "alignment", "center")) {
                Text(t("靠左", "Left")).tag("left"); Text(t("居中", "Center")).tag("center"); Text(t("靠右", "Right")).tag("right")
            }
            slider(key + "width", t("区域内目标宽度", "Target width within the area"), fallback: Double(style.width * 100), range: 40...100, suffix: "%")
            Text(t("会自动保留文字、图标与滑条所需的最小空间，避免拥挤或重叠。", "The minimum space needed by labels, icons and sliders is retained to prevent crowding or overlap."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            slider(key + "height", t("项目高度", "Item height"), fallback: Double(style.height), range: minimum...260)
            if item != .music {
                Divider()
                slider(key + "icon", t("图标字号", "Icon size"), fallback: item.isLevel ? 12 : 17, range: 10...32)
                if isShortcut {
                    Picker(t("图标底形", "Icon background"), selection: string(key + "shape", "circle")) {
                        Text(t("圆形", "Circle")).tag("circle")
                        Text(t("圆角方形", "Rounded square")).tag("square")
                        Text(t("仅图形", "No background")).tag("plain")
                    }
                    slider(key + "circle", t("图标区域大小", "Icon area size"), fallback: 40, range: Double(max(24, style.glyph + 12))...64)
                    Toggle(t("仅显示图标", "Icon only"), isOn: flag(key + "iconOnly"))
                }
                if !isShortcut || style.labels {
                    slider(key + "font", t("文字大小", "Label size"), fallback: 11, range: 9...16)
                }
            }
            Button(t("恢复此控制项默认值", "Restore this control’s defaults")) {
                var next = appearance; next.reset(key); data = next.encoded
            }
        }
    }
    private func controlMove(up: Bool) -> some View {
        let index = orderedControls.firstIndex(of: editingControl) ?? 0
        return Button {
            var items = orderedControls; let destination = index + (up ? -1 : 1)
            guard items.indices.contains(destination) else { return }
            items.swapAt(index, destination); controlOrder = items.map(\.rawValue).joined(separator: ",")
        } label: { Image(systemName: up ? "chevron.up" : "chevron.down").frame(width: 24, height: 26) }
            .buttonStyle(.plain).disabled(up ? index == 0 : index == orderedControls.count - 1)
            .accessibilityLabel(t(up ? "上移" : "下移", up ? "Move up" : "Move down") + " " + editingControl.title(l10n))
    }
    private var system: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(t("文字与留白", "Type and padding")).font(.callout.weight(.semibold))
            slider("system.font", t("独立字号比例", "Independent type scale"), fallback: 1, range: 0.75...1.4, step: 0.05, percent: true)
            slider("system.padding", t("卡片内部左右留白", "Card horizontal padding"), fallback: 12, range: 6...24)
            Divider().padding(.vertical, 4)
            Text(t("进度条", "Meters")).font(.callout.weight(.semibold))
            Toggle(t("隐藏进度条", "Hide meters"), isOn: flag("system.hideMeters"))
            Picker(t("进度条颜色", "Meter color"), selection: string("system.tint", "original")) {
                Text(t("原版", "Original")).tag("original"); Text(t("系统强调色", "System accent")).tag("accent")
                Text(t("青色", "Cyan")).tag("cyan"); Text(t("绿色", "Green")).tag("green")
                Text(t("自定义颜色", "Custom color")).tag("custom")
            }
            if appearance.systemTint == "custom" {
                NotchNetworkColorPicker(title: t("自定义进度条颜色", "Custom meter color"),
                    hex: string("system.color", "73F2FF"), fallback: "73F2FF", text: .init(l10n.language))
            }
            Text(t("高占用与低电量等警示仍使用原有警示色。", "High usage and low battery retain their warning colors."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    private func slider(_ key: String, _ title: String, fallback: Double, range: ClosedRange<Double>, step: Double = 1,
                        percent: Bool = false, suffix: String = " pt") -> some View {
        let current = Double(appearance.number(key, fallback, range))
        return VStack(alignment: .leading, spacing: 6) {
            HStack { Text(title); Spacer(); Text("\(Int((percent ? current * 100 : current).rounded()))" + (percent ? "%" : suffix)).monospacedDigit().foregroundStyle(.secondary) }
            Slider(value: Binding(get: { current }, set: { update(key, String($0)) }), in: range, step: step).labelsHidden().accessibilityLabel(title)
        }.font(.callout)
    }
}

struct NotchPagePresetSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(NotchPageAppearance.presetsKey) private var data = Data()
    @State private var name = ""
    @State private var renaming: UUID?
    @State private var edited = ""
    private var library: NotchPagePresetLibrary { .init(data: data) }
    private var text: NotchNetworkStrings { .init(l10n.language) }
    private var chinese: Bool { text.chinese }
    var body: some View {
        SettingsCard(title: chinese ? "岛内布局预设" : "Island layout presets") {
            VStack(alignment: .leading, spacing: 10) {
                Text(chinese ? "保存系统、工具、控制和箭头布局。网速预设、权限与顶部按钮不受影响。" : "Save System, Tools, Controls and arrow layouts. Network presets, permissions and top shortcuts are unchanged.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if library.readable {
                    HStack { TextField(text.presetName, text: $name).textFieldStyle(.roundedBorder).onSubmit(save)
                        Button(text.savePreset, action: save).disabled(!library.accepts(name) || library.items.count >= 30) }
                    ForEach(library.items) { preset in
                        HStack {
                            if renaming == preset.id {
                                TextField(text.presetName, text: $edited).textFieldStyle(.roundedBorder)
                                Button(text.done) { mutate { list in
                                    guard let i = list.firstIndex(where: { $0.id == preset.id }), library.accepts(edited, excluding: preset.id) else { return }
                                    list[i].name = NotchNetworkPresetLibrary.cleanName(edited)
                                }; renaming = nil }.disabled(!library.accepts(edited, excluding: preset.id))
                                Button(text.cancel) { renaming = nil }
                            } else {
                                Button(preset.name) { preset.apply(); NotchService.shared.syncWithPreferences(); QuickLauncherService.shared.objectWillChange.send() }.buttonStyle(.plain)
                                Spacer()
                                Menu {
                                    Button(text.renamePreset) { edited = preset.name; renaming = preset.id }
                                    Button(text.updatePreset) { mutate { list in
                                        guard let i = list.firstIndex(where: { $0.id == preset.id }) else { return }
                                        var next = NotchPagePreset.capture(name: preset.name, toolItems: QuickLauncherService.shared.islandItems.map(\.rawValue)); next.id = preset.id; list[i] = next
                                    } }
                                    Button(text.deletePreset, role: .destructive) { mutate { $0.removeAll { $0.id == preset.id } } }
                                } label: { Image(systemName: "ellipsis") }
                                    .menuStyle(.borderlessButton)
                                    .fixedSize()
                            }
                        }.frame(minHeight: 30)
                    }
                } else { Text(text.presetUnreadable).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
    private func save() {
        guard library.accepts(name), library.items.count < 30 else { return }
        let preset = NotchPagePreset.capture(name: NotchNetworkPresetLibrary.cleanName(name), toolItems: QuickLauncherService.shared.islandItems.map(\.rawValue)); mutate { $0.append(preset) }; name = ""
    }
    private func mutate(_ action: (inout [NotchPagePreset]) -> Void) {
        var next = NotchPagePresetLibrary(data: data); guard next.readable else { return }; action(&next.items)
        if let encoded = next.encoded { data = encoded }
    }
}

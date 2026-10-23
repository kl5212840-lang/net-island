// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors

struct NotchNetworkStrings {
    let chinese: Bool
    let traditional: Bool
    init(_ language: AppLanguage) {
        chinese = [.zhHans, .zhTW, .zhHK].contains(language)
        traditional = [.zhTW, .zhHK].contains(language)
    }
    private func text(_ english: String, _ simplified: String, _ traditional: String? = nil) -> String {
        chinese ? (self.traditional ? traditional ?? simplified : simplified) : english
    }
    var quickTitle: String { text("Speed", "网速", "網速") }
    var title: String { text("Network readout", "网速显示", "網速顯示") }
    var on: String { text("On", "开启", "開啟") }
    var off: String { text("Off", "关闭", "關閉") }
    var quickHint: String { text("Show or hide idle network speeds. Other island activities stay on.", "开关空闲时的网速显示，不影响岛上的其他活动。", "開關閒置時的網速顯示，不影響島上的其他活動。") }
    var preview: String { text("Layout preview · Sample values", "布局预览 · 示例数据", "佈局預覽 · 範例數據") }
    var format: String { text("Number format", "显示格式", "顯示格式") }
    var compact: String { text("Compact (45K)", "简洁（45K）", "簡潔（45K）") }
    var precise: String { text("Precise (45.0 KB/s)", "精准数值（45.0 KB/s）", "精準數值（45.0 KB/s）") }
    var unit: String { text("Speed unit", "速度单位", "速度單位") }
    var bytes: String { text("Bytes per second (B/s)", "字节/秒（B/s）", "位元組/秒（B/s）") }
    var bits: String { text("Bits per second (bit/s)", "比特/秒（bit/s）", "位元/秒（bit/s）") }
    var font: String { text("Font size", "字体大小", "字體大小") }
    var width: String { text("Resting island width per side", "空闲岛每侧宽度", "閒置島每側寬度") }
    var offset: String { text("Reading vertical offset", "读数上下偏移", "讀數上下偏移") }
    var widthHint: String { text("Smaller side widths make the resting island narrower. The minimum fits the selected font, units and padding. Camera space stays fixed; overall height and expanded size are in the Layout tab.", "每侧越窄，空闲岛越窄；最小宽度会适配字号、单位和留白。刘海区域保持固定，整体高度和展开大小可在“布局”标签页调整。", "每側越窄，閒置島越窄；最小寬度會適應字體大小、單位和留白。瀏海區域保持固定，整體高度和展開大小可在「佈局」標籤頁調整。") }
    var uploadOnLeft: String { text("Upload on the left", "上传显示在左侧", "上傳顯示在左側") }
    var avoidMenus: String { text("Yield to native menus", "优先避让原生菜单", "優先避讓原生選單") }
    var avoidHint: String { text("Hide both readings when the menu bar has too little room. Requires Accessibility; other island activities follow their own setting.", "菜单栏空间不足时隐藏两侧读数，需要辅助功能权限。其他活动仍使用原来的遮挡设置。", "選單列空間不足時隱藏兩側讀數，需要輔助使用權限。其他活動仍使用原來的遮擋設定。") }
    var autoHide: String { text("Hide during low traffic", "低流量时自动隐藏", "低流量時自動隱藏") }
    var autoHint: String { text("Keeps detecting traffic while hidden and returns when either direction exceeds the threshold.", "隐藏后仍检测流量，任一方向超过阈值便自动恢复显示。", "隱藏後仍偵測流量，任一方向超過門檻便自動恢復顯示。") }
    var threshold: String { text("Traffic threshold", "流量阈值", "流量門檻") }
    var delay: String { text("Hide after", "持续低流量后隐藏", "持續低流量後隱藏") }
    var capsuleDrop: String { text("Capsule distance from top", "胶囊距屏幕顶部", "膠囊距螢幕頂部") }
    var reset: String { text("Reset network layout", "重置网速布局", "重設網速佈局") }
    var presets: String { text("Quick presets", "快捷预设", "快捷預設") }
    var smallPreset: String { text("Save space", "省空间", "省空間") }
    var balancedPreset: String { text("Balanced", "均衡", "均衡") }
    var clearPreset: String { text("Easy to read", "清晰", "清晰") }
    var presetHint: String { text("Presets adjust size, format and weight. Your colors, alignment, padding and behavior choices stay as set.", "预设调整字号、宽度、格式和字重，保留颜色、对齐、留白及行为设置。", "預設調整字體大小、寬度、格式和字重，保留顏色、對齊、留白及行為設定。") }
    var decimals: String { text("Decimal places", "小数位数", "小數位數") }
    var appearance: String { text("Font and layout", "字体与布局", "字體與佈局") }
    var behavior: String { text("Menu space and automatic hiding", "菜单空间与自动隐藏", "選單空間與自動隱藏") }
    var weight: String { text("Font weight", "字重", "字重") }
    var regular: String { text("Regular", "常规", "標準") }
    var medium: String { text("Medium", "中等", "中等") }
    var bold: String { text("Bold", "加粗", "粗體") }
    var color: String { text("Readout color", "读数颜色", "讀數顏色") }
    var white: String { text("White", "白色", "白色") }
    var customColor: String { text("Custom colors", "自定义颜色", "自訂顏色") }
    var downloadColor: String { text("Download color", "下载颜色", "下載顏色") }
    var uploadColor: String { text("Upload color", "上传颜色", "上傳顏色") }
    var colorScope: String { text("Apply color to", "颜色应用于", "顏色套用於") }
    var colorAll: String { text("Arrows and numbers", "箭头与数字", "箭頭與數字") }
    var colorArrows: String { text("Arrows only · White numbers", "仅箭头 · 数字保持白色", "僅箭頭 · 數字保持白色") }
    var colorContrastHint: String { text("This color may be hard to read on the dark island. Increase brightness or choose a lighter color.", "当前颜色在深色岛上可能不易辨认，可以提高亮度或选择浅一些的颜色。", "目前顏色在深色島上可能不易辨認，可以提高亮度或選擇淺一些的顏色。") }
    var directionColor: String { text("Blue download · Cyan upload", "下载蓝色 · 上传青色", "下載藍色 · 上傳青色") }
    var opacity: String { text("Readout brightness", "读数明暗", "讀數明暗") }
    var alignment: String { text("Alignment within each side", "每侧读数对齐", "每側讀數對齊") }
    var leading: String { text("Left", "左对齐", "靠左") }
    var center: String { text("Center", "居中", "置中") }
    var trailing: String { text("Right", "右对齐", "靠右") }
    var outside: String { text("Both outer edges", "两侧对齐", "兩側對齊") }
    var alignmentHint: String { text("Both outer edges aligns the left reading left and the right reading right, even when upload/download swap sides.", "两侧对齐：左侧读数靠左，右侧读数靠右；交换上下行位置后仍保持对称。", "兩側對齊：左側讀數靠左，右側讀數靠右；交換上下行位置後仍保持對稱。") }
    var outerSpacing: String { text("Extra outer padding", "外侧额外留白", "外側額外留白") }
    var innerSpacing: String { text("Padding beside the camera", "靠近刘海的留白", "靠近瀏海的留白") }
    var previewHint: String { text("Camera space, when present, stays reserved. Side widths control the resting island’s total width. Preview scales to fit; actual font size stays as set.", "有刘海时会固定预留中间区域；每侧宽度决定空闲岛的总宽度。预览按可用空间缩放，实际字号不变。", "有瀏海時會固定預留中間區域；每側寬度決定閒置島的總寬度。預覽依可用空間縮放，實際字體大小不變。") }
    var done: String { text("Done", "完成", "完成") }
    var colorSaved: String { text("Color changes are saved immediately.", "颜色已实时保存", "顏色已即時儲存") }
    var expanded: String { text("Expanded", "已展开", "已展開") }
    var collapsed: String { text("Collapsed", "已收起", "已收起") }
    var gap: String { text("Arrow spacing", "箭头与数值间距", "箭頭與數值間距") }
    var customPresets: String { text("My presets", "自定义预设", "自訂預設") }
    var presetName: String { text("Preset name", "预设名称", "預設名稱") }
    var savePreset: String { text("Save current", "保存当前", "儲存目前") }
    var presetEmpty: String { text("Save the current colors, size, spacing, alignment and number format. Click a name to switch, or right-click the network icon.", "保存当前颜色、字号、宽度、对齐、留白和显示格式。点击名称可切换，也可右键岛上的网速图标选用。", "儲存目前顏色、字體大小、寬度、對齊、留白和顯示格式。點擊名稱可切換，也可右鍵島上的網速圖示選用。") }
    var presetNameHint: String { text("Use a unique name, up to 40 characters. Up to 30 presets stay on this Mac.", "名称不可重复，最多40个字符。最多保存30套，仅存储在本机。", "名稱不可重複，最多40個字元。最多儲存30套，僅儲存在本機。") }
    var presetUnreadable: String { text("Saved presets could not be read. Existing data has been kept intact.", "无法读取已保存的预设，原始数据已保留。", "無法讀取已儲存的預設，原始資料已保留。") }
    var renamePreset: String { text("Rename", "重命名", "重新命名") }
    var updatePreset: String { text("Update with current appearance", "用当前外观更新", "以目前外觀更新") }
    var deletePreset: String { text("Delete preset", "删除预设", "刪除預設") }
    var presetApplied: String { text("Current appearance", "与当前外观一致", "與目前外觀一致") }
    var cancel: String { text("Cancel", "取消", "取消") }
    var headerTitle: String { text("Top-row shortcuts", "顶部快捷图标", "頂部快捷圖示") }
    var headerSettings: String { text("Additional Settings shortcut", "额外显示设置图标", "額外顯示設定圖示") }
    var headerSettingsPosition: String { text("Settings icon position", "设置图标位置", "設定圖示位置") }
    var headerNetworkPosition: String { text("Network switch position", "网速开关位置", "網速開關位置") }
    var headerIconOnly: String { text("Network switch: icon only", "网速开关仅显示图标", "網速開關僅顯示圖示") }
    var headerLeftOuter: String { text("Left · Slot 1", "左侧第1位", "左側第1位") }
    var headerLeftMiddle: String { text("Left · Slot 2", "左侧第2位", "左側第2位") }
    var headerLeftInner: String { text("Left · Slot 3", "左侧第3位", "左側第3位") }
    var headerRightInner: String { text("Right · Slot 1", "右侧第1位", "右側第1位") }
    var headerRightMiddle: String { text("Right · Slot 2", "右侧第2位", "右側第2位") }
    var headerRightOuter: String { text("Right · Slot 3", "右侧第3位", "右側第3位") }
    var headerHint: String { text("Adds shortcuts inside the open island without moving its floating buttons. Camera clearance stays reserved. Crowded rows use icons first, then omit extra shortcuts. Pages with their own left header use the right side.", "在展开的岛内额外添加快捷图标，不改动原有悬浮按钮。自动预留刘海安全距离；空间不足时先简化为图标，再隐藏额外快捷项。自行布局左侧标题栏的分区会改用右侧。", "在展開的島內額外新增快捷圖示，不更動原有浮動按鈕。自動預留瀏海安全距離；空間不足時先簡化為圖示，再隱藏額外快捷項。自行配置左側標題列的分區會改用右側。") }

    var cameraSafeArea: String { text("Camera safe area", "刘海安全区", "瀏海安全區") }
    var headerEditorHint: String { text("Six top slots, three per side. Click + to add an action; click an icon to rename, replace or remove it. Drag between slots to swap. Filled icons pack with equal gaps; empty slots take no space. Camera clearance and floating buttons stay independent.", "顶部左右各3位。点＋添加操作，点图标改名、替换或移除，拖动可交换位置。实际图标等距紧凑排列，空位不占宽度。中间保留刘海安全区，悬浮按钮独立配置。", "頂部左右各3位。點＋新增操作，點圖示改名、替換或移除，拖曳可交換位置。實際圖示等距緊湊排列，空位不占寬度。中間保留瀏海安全區，浮動按鈕獨立設定。") }

}

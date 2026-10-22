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
    var width: String { text("Width on each side", "每侧读数区宽度", "每側讀數區寬度") }
    var offset: String { text("Reading vertical offset", "读数上下偏移", "讀數上下偏移") }
    var widthHint: String { text("Width grows when needed for larger text. The physical camera stays fixed.", "字号较大时，宽度会自动保证读数完整。摄像头的位置保持固定。", "字體較大時，寬度會自動確保讀數完整。攝像頭的位置保持固定。") }
    var uploadOnLeft: String { text("Upload on the left", "上传显示在左侧", "上傳顯示在左側") }
    var avoidMenus: String { text("Yield to native menus", "优先避让原生菜单", "優先避讓原生選單") }
    var avoidHint: String { text("Hide both readings when the menu bar has too little room. Requires Accessibility; other island activities follow their own setting.", "菜单栏空间不足时隐藏两侧读数，需要辅助功能权限。其他活动仍使用原来的遮挡设置。", "選單列空間不足時隱藏兩側讀數，需要輔助使用權限。其他活動仍使用原來的遮擋設定。") }
    var autoHide: String { text("Hide during low traffic", "低流量时自动隐藏", "低流量時自動隱藏") }
    var autoHint: String { text("Keeps detecting traffic while hidden and returns when either direction exceeds the threshold.", "隐藏后仍检测流量，任一方向超过阈值便自动恢复显示。", "隱藏後仍偵測流量，任一方向超過門檻便自動恢復顯示。") }
    var threshold: String { text("Traffic threshold", "流量阈值", "流量門檻") }
    var delay: String { text("Hide after", "持续低流量后隐藏", "持續低流量後隱藏") }
    var capsuleDrop: String { text("Capsule distance from top", "胶囊距屏幕顶部", "膠囊距螢幕頂部") }
    var reset: String { text("Reset network layout", "重置网速布局", "重設網速佈局") }
}

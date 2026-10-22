// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Net Island contributors

import SwiftUI

enum NetworkPrivacyStrings {
    static var chinese: Bool { [.zhHans, .zhTW, .zhHK].contains(L10n.shared.language) }
    static var blocked: String { chinese ? "此版本已关闭在线传输。" : "Online transfer is disabled in this build." }
    static var localLyrics: String { chinese ? "在线歌词查询已关闭，可以导入本地歌词。" : "Online lyrics are disabled. You can import a local lyrics file." }
}

struct NetworkPrivacySettings: View {
    @ObservedObject private var l10n = L10n.shared
    private var chinese: Bool { NetworkPrivacyStrings.chinese }
    var body: some View {
        SettingsCard(title: chinese ? "隐私与联网" : "Privacy and network access") {
            Label(chinese ? "本地优先保护已生效" : "Local privacy protections are active", systemImage: "checkmark.shield")
                .font(.headline)
            Text(chinese
                 ? "已封闭截图、录屏与反馈上传。在线歌词、远程封面、网站图标、价格表刷新、应用更新查询及 AI 账户查询已停用。导入旧设置也无法开启这些接口。"
                 : "Screenshot, recording and feedback uploads are blocked. Online lyrics, remote artwork, favicons, price refreshes, app update lookups and AI account queries are disabled, including after importing old settings.")
                .font(.callout).fixedSize(horizontal: false, vertical: true)
            Text(chinese
                 ? "网速和系统监测在本机完成。主动测速、Homebrew 安装/搜索、浏览器打开链接仍可联网；本应用调用 Homebrew 时关闭其使用统计。历史分享链接仍可手动撤销。"
                 : "Network and system monitoring stay on this Mac. Explicit speed tests, Homebrew operations and links opened in your browser can use the network. Homebrew analytics are disabled for commands run here. Existing shared links can still be revoked manually.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text(chinese
                 ? "剪贴板、截图等本地记录仍可能包含敏感内容，请按需清理。这些保护适用于本应用，不是系统防火墙。"
                 : "Local clipboard and capture history can still contain sensitive content. Clear it when needed. These protections apply to this app; they are not a system firewall.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

import SwiftUI
import BarlyKit

/// 终端区：单个标签、预览、空状态直接铺在主区面板里（面板底 = 终端底色）；
/// 分屏时每一边是主区面板里的一块小面板（圆角 8、一圈细边，聚焦的那块边线亮一级）
struct TerminalPanel<Content: View>: View {
    var focused = true
    /// 分屏时用：画成小面板，聚焦的那块边线亮一级
    var showsFocus = false
    @ViewBuilder var content: Content
    @Environment(\.barly) private var t

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: WorkspaceMetrics.trackRadius, style: .continuous)
        if showsFocus {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(t.panelBg)
                .clipShape(shape)
                .overlay(shape.strokeBorder(focused ? t.borderStrong : t.hairline, lineWidth: 1))
        } else {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(t.panelBg)
        }
    }
}

/// 面板头：项目名 / 标题 · 路径 ……  CLI 标签（· 关闭）。项目名和标签栏的组头同色，
/// 一眼看出「这是哪个项目的哪个会话、在哪个目录、跑的什么」
struct PanelHeader: View {
    let tab: TerminalTab
    /// 所在的标签组（项目名 + 组色）
    var group: TabGroup?
    var focused = true
    /// 分屏时才有：这一边不分屏了
    var onClose: (() -> Void)?
    @Environment(\.barly) private var t

    private var cli: CLIKind? {
        if let cli = tab.kind.cli { return cli }
        return nil
    }

    /// 本机路径把家目录缩成 ~；SSH 主机前面带主机名
    private var path: String {
        var p = tab.projectPath
        if tab.hostID == Host.localID {
            let home = NSHomeDirectory()
            if p.hasPrefix(home) { p = "~" + p.dropFirst(home.count) }
            return p
        }
        return "\(tab.hostID):\(p)"
    }

    var body: some View {
        HStack(spacing: 8) {
            if let group {
                // 「项目 / 会话」：项目名用组色，和标签栏的组头对得上
                Text(group.name).barlyText(.product.small.weight(500), color: t.text2)
                    .lineLimit(1).fixedSize()
                Text("/").barlyText(.product.small, color: t.text4)
            } else {
                Image(systemName: "terminal")
                    .font(.system(size: BarlyScale.pt(11)))
                    .foregroundStyle(t.text4)
            }
            Text(tab.title)
                .barlyText(.product.small.weight(500), color: focused ? t.text : t.text2)
                .lineLimit(1)
                .layoutPriority(1)
            Text(path)
                .barlyText(.product.caption, color: t.text4)
                .lineLimit(1).truncationMode(.head)
            Spacer(minLength: 8)
            if !tab.isPlainTerminal { ActivityLamp(tab.activity, size: 6) }
            Text(cli?.executable ?? "zsh")
                .barlyText(.product.caption.monospaced, color: t.text3)
                .padding(.horizontal, 7)
                .frame(height: BarlyScale.pt(20))
                .background(t.shellSelected, in: RoundedRectangle(cornerRadius: BarlyRadius.xs, style: .continuous))
                .help(cli?.title ?? L("终端"))
            if let onClose {
                PaneIcon(symbol: "xmark", help: L("这一边不分屏了（标签还开着）"), action: onClose)
                    .scaleEffect(0.85)
            }
        }
        .padding(.leading, 16).padding(.trailing, onClose == nil ? 10 : 4)
        .frame(height: WorkspaceMetrics.panelHeader)
    }
}

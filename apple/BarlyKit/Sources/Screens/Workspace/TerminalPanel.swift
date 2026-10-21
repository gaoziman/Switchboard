import SwiftUI
import BarlyKit

/// 终端面板：浮在外壳底上的一块（面板底 = 终端底色，一圈发丝线，8pt 圆角，不加阴影）。
/// 单个标签、分屏的每一边、预览和空状态都放在它里面，所以主区永远是「底 + 面板」两层
struct TerminalPanel<Content: View>: View {
    var focused = true
    /// 分屏时用：聚焦的那块边线深一级
    var showsFocus = false
    @ViewBuilder var content: Content
    @Environment(\.barly) private var t

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: WorkspaceMetrics.panelRadius)
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(t.panelBg)
            .clipShape(shape)
            .overlay(shape.strokeBorder(showsFocus && focused ? t.borderStrong : t.hairline, lineWidth: 1))
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
        if case .session(_, let cli) = tab.kind { return cli }
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
                Text(group.name).barlyText(.product.small.weight(600), color: t.groupColor(group.tint))
                    .lineLimit(1).fixedSize()
                Text("/").barlyText(.product.small, color: t.text4)
            } else {
                Image(systemName: "terminal")
                    .font(.system(size: BarlyScale.pt(11)))
                    .foregroundStyle(t.text4)
            }
            Text(tab.title)
                .barlyText(.product.small.weight(600), color: focused ? t.text : t.text2)
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
                .background(t.fill1, in: RoundedRectangle(cornerRadius: 4))
                .help(cli?.title ?? L("终端"))
            if let onClose {
                PaneIcon(symbol: "xmark", help: L("这一边不分屏了（标签还开着）"), action: onClose)
                    .scaleEffect(0.85)
            }
        }
        .padding(.leading, 14).padding(.trailing, onClose == nil ? 10 : 4)
        .frame(height: WorkspaceMetrics.panelHeader)
    }
}

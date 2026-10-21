import SwiftUI
import BarlyKit

/// 顶部标签栏：类 Chrome 标签组。每个项目一组，组前一个组色标签（点一下折叠），
/// 选中的标签和下面的终端同底色连成一片，顶上一根组色细线。标签随数量收窄，到最窄后横向滚动。
public struct TabBar: View {
    @Bindable var store: WorkspaceStore
    var sidebarHidden: Bool
    var onNewSession: () -> Void
    @Environment(\.barly) private var t

    public init(store: WorkspaceStore, sidebarHidden: Bool = false, onNewSession: @escaping () -> Void = {}) {
        self.store = store
        self.sidebarHidden = sidebarHidden
        self.onNewSession = onNewSession
    }

    public var body: some View {
        GeometryReader { proxy in
            let width = tabWidth(available: proxy.size.width)
            HStack(alignment: .bottom, spacing: 0) {
                if sidebarHidden { TrafficLights().padding(.leading, 16).frame(height: WorkspaceMetrics.tabHeight) }
                BarlyScroll(.horizontal) {
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(store.tabGroups) { group in
                            GroupLabel(group: group) { store.toggleCollapsed(group) }
                            if !group.isCollapsed {
                                ForEach(group.tabs) { tab in
                                    TabItem(tab: tab, tint: group.tint,
                                            selected: store.selectedTab?.id == tab.id || store.activeSplit?.contains(tab.id) == true,
                                            width: width) {
                                        store.selection = .tab(tab.id)
                                    } onClose: {
                                        store.requestClose(tab)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.leading, 6)
                }
                .frame(height: WorkspaceMetrics.header, alignment: .bottom)
                PaneIcon(symbol: "plus", help: L("新会话（⌘T）"), action: onNewSession)
                    .padding(.horizontal, 8)
                    .frame(height: WorkspaceMetrics.tabHeight)
            }
            .frame(height: WorkspaceMetrics.header, alignment: .bottom)
        }
        .frame(height: WorkspaceMetrics.header)
        .background(t.bg)
        .overlay(alignment: .bottom) { Hairline() }
    }

    /// 展开的标签平分可用宽度，夹在最窄和最宽之间
    private func tabWidth(available: CGFloat) -> CGFloat {
        let visible = store.tabGroups.filter { !$0.isCollapsed }.reduce(0) { $0 + $1.tabs.count }
        guard visible > 0 else { return WorkspaceMetrics.tabMax }
        let labels = CGFloat(store.tabGroups.count) * 110
        let share = (available - labels - 60) / CGFloat(visible)
        return min(WorkspaceMetrics.tabMax, max(WorkspaceMetrics.tabMin, share))
    }
}

/// 组色：取身份的图标色池，按项目稳定分配（不是强调色）
extension BarlyPalette {
    func groupColor(_ tint: Int) -> Color { chipIcon(tint, force: true) }
}

private struct GroupLabel: View {
    let group: TabGroup
    let action: () -> Void
    @Environment(\.barly) private var t

    var body: some View {
        let c = t.groupColor(group.tint)
        Button(action: action) {
            HStack(spacing: 5) {
                Text(group.name).barlyText(.product.caption.weight(500), color: c)
                if group.isCollapsed {
                    Text("\(group.tabs.count)").barlyText(.product.caption.monospaced, color: c.opacity(0.8))
                    ActivityLamp(group.mostUrgent, size: 5)
                }
            }
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background(c.opacity(0.13), in: RoundedRectangle(cornerRadius: BarlyRadius.xs))
            .fixedSize()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .handCursor()
        .padding(.horizontal, 6)
        .frame(height: WorkspaceMetrics.tabHeight)
        .help(group.isCollapsed ? "展开 \(group.name)" : "折叠 \(group.name)")
    }
}

private struct TabItem: View {
    let tab: TerminalTab
    let tint: Int
    let selected: Bool
    let width: CGFloat
    let action: () -> Void
    var onClose: () -> Void = {}
    @Environment(\.barly) private var t
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 7) {
            if tab.isPlainTerminal {
                Image(systemName: "terminal").font(.system(size: 10)).foregroundStyle(t.text3)
            } else {
                ActivityLamp(tab.activity, size: 6)
            }
            Color.clear.frame(maxWidth: .infinity).overlay(alignment: .leading) {
                Text(tab.title)
                    .barlyText(.product.small.weight(selected ? 500 : 400), color: selected ? t.text : t.text3)
                    .lineLimit(1).fixedSize()
            }
            .clipped()
            .mask(LinearGradient(stops: [.init(color: .black, location: 0.78), .init(color: .clear, location: 1)],
                                 startPoint: .leading, endPoint: .trailing))
            if selected || hovered {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(t.text3)
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onClose)
                    .handCursor()
                    .help("关闭标签（⌘W）")
            }
        }
        .padding(.horizontal, 10)
        .frame(width: width, height: WorkspaceMetrics.tabHeight)
        .background { background }
        .overlay(alignment: .trailing) {
            if !selected { Rectangle().fill(t.hairline).frame(width: 1, height: 14) }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .onHover { hovered = $0 }
        .handCursor()
        .help(tab.title)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder private var background: some View {
        if selected {
            UnevenRoundedRectangle(topLeadingRadius: BarlyRadius.sm, topTrailingRadius: BarlyRadius.sm)
                .fill(t.canvas)
                .overlay(alignment: .top) { Rectangle().fill(t.groupColor(tint)).frame(height: 2) }
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: BarlyRadius.sm, topTrailingRadius: BarlyRadius.sm))
                .padding(.bottom, -1)
        } else if hovered {
            RoundedRectangle(cornerRadius: BarlyRadius.sm).fill(t.fill1).padding(.vertical, 4)
        }
    }
}

/// 终端区（原型阶段是假画面；阶段④ 换成 SwiftTerm / Ghostty 的真实终端视图，外框不变）
public struct TerminalPane: View {
    let tab: TerminalTab
    var banner: TerminalBanner?
    @Environment(\.barly) private var t

    public init(tab: TerminalTab, banner: TerminalBanner? = nil) {
        self.tab = tab
        self.banner = banner
    }

    private var lines: [(MockData.LineStyle, String)] {
        if case .failed(let code, let hint)? = banner {
            return [(.prompt, "$ claudee --resume 4f1a9c2e"), (.text, hint), (.dim, ""), (.dim, "[exited \(code)]")]
        }
        if case .exited? = banner {
            return MockData.terminalLines.dropLast(3) + [(.prompt, "> /exit"), (.dim, "  ⎿  Goodbye!"), (.text, ""), (.dim, "[exited 0]")]
        }
        if case .session(_, .codex) = tab.kind { return MockData.codexLines }
        return MockData.terminalLines
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line.1.isEmpty ? " " : line.1)
                    .barlyText(.product.small.size(13).monospaced, color: color(line.0))
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(background(line.0))
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(t.canvas)
    }

    private func color(_ s: MockData.LineStyle) -> Color {
        switch s {
        case .text, .added, .removed, .prompt: t.text
        case .dim: t.text3
        case .tool: t.dataPos
        case .working: t.warning
        }
    }

    private func background(_ s: MockData.LineStyle) -> Color {
        switch s {
        case .added: t.success.opacity(0.13)
        case .removed: t.danger.opacity(0.13)
        case .prompt: t.fill1
        default: .clear
        }
    }
}

import SwiftUI
import BarlyKit
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

extension UTType {
    /// 拖动中的标签（Info.plist 里登记为导出类型）
    static let switchboardTab = UTType(exportedAs: "design.barly.switchboard.tab")
}

/// 拖动的标签：只带标签 ID，真正的状态在 WorkspaceStore 里搬（见 TabMoving）
struct TabDragItem: Codable, Transferable, Identifiable {
    let id: UUID
    static var transferRepresentation: some TransferRepresentation { CodableRepresentation(contentType: .switchboardTab) }
}

/// 顶部标签栏：类 Chrome 标签组。每个项目一组，组前一个组色标签（点一下折叠），
/// 选中的标签和下面的终端同底色连成一片，顶上一根组色细线。标签随数量收窄，到最窄后横向滚动。
public struct TabBar: View {
    @Bindable var store: WorkspaceStore
    var sidebarHidden: Bool
    var onNewSession: () -> Void
    @Environment(\.barly) private var t
    @Environment(\.openWindow) private var openWindow

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
                                    .draggable(TabDragItem.self, item: TabDragItem(id: tab.id))
                                    .dropDestination(for: TabDragItem.self) { items, _ in drop(items.first?.id, before: tab.id) }
                                    .contextMenu { tabMenu(tab) }
                                }
                            }
                        }
                    }
                    .padding(.leading, 6)
                    .onDragSessionUpdated(dragUpdated)
                }
                .frame(height: WorkspaceMetrics.header, alignment: .bottom)
                // 标签栏空白处：放到最后（别的窗口拖来的进它项目的组）
                .dropDestination(for: TabDragItem.self) { items, _ in drop(items.first?.id, before: nil) }
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

    /// 放下一个标签：同一窗口就调顺序（只在同一个项目组里），别的窗口拖来的就搬过来
    @discardableResult
    private func drop(_ id: UUID?, before target: UUID?) -> Bool {
        guard let id, id != target else { return false }
        if let tab = store.tab(id) {
            if let target, store.tab(target)?.projectID != tab.projectID { return false }
            store.moveTab(id, before: target)
            return true
        }
        guard let owner = WorkspaceWindows.owner(ofTab: id), let moving = owner.tab(id) else { return false }
        let sameGroup = target.flatMap { store.tab($0) }?.projectID == moving.projectID
        owner.moveTab(id, to: store, before: sameGroup ? target : nil)
        return true
    }

    /// 拖到所有窗口外面松手：开一个新窗口放这个标签（像 Chrome）
    private func dragUpdated(_ session: DragSession) {
        #if os(macOS)
        guard case .ended(.cancel) = session.phase,
              let id = session.draggedItemIDs(for: UUID.self).first, store.tab(id) != nil else { return }
        let mouse = NSEvent.mouseLocation
        let insideSomeWindow = NSApp.windows.contains { $0.isVisible && $0.frame.contains(mouse) }
        guard !insideSomeWindow else { return }
        tearOff(id)
        #endif
    }

    private func tearOff(_ id: UUID) {
        if store.moveTabToNewWindow(id) { openWindow(id: "workspace") }
    }

    @ViewBuilder private func tabMenu(_ tab: TerminalTab) -> some View {
        Button("移到新窗口") { tearOff(tab.id) }
        let others = store.otherWindows
        if !others.isEmpty {
            Menu("移到窗口") {
                ForEach(Array(others.enumerated()), id: \.offset) { _, other in
                    Button(other.windowTitle) { store.moveTab(tab.id, to: other) }
                }
            }
        }
        Divider()
        Button("关闭标签") { store.requestClose(tab) }
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
            .frame(height: BarlyScale.pt(20))
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

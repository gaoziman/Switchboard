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

/// 顶部标签栏：按项目分组。每组上面一行「跨栏组头」——组色小字项目名 + 一根同色细线横跨整组（点一下折叠），
/// 下面一行是这组的标签（26pt，同组之间细竖线，选中是一块浅底）。项目名在标签之上、不和标签抢同一行，
/// 一个项目开多个对话也一眼看出归属。标签随数量收窄，到最窄后横向滚动。
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
                if sidebarHidden { TrafficLights().padding(.leading, 16 - WorkspaceMetrics.gutter).frame(height: WorkspaceMetrics.tabBar) }
                BarlyScroll(.horizontal) {
                    HStack(alignment: .bottom, spacing: 14) {
                        ForEach(store.tabGroups) { group in
                            if group.isCollapsed {
                                CollapsedGroup(group: group) { store.toggleCollapsed(group) }
                            } else {
                                VStack(alignment: .leading, spacing: 0) {
                                    GroupHeader(group: group) { store.toggleCollapsed(group) }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    HStack(spacing: 0) {
                                        ForEach(Array(group.tabs.enumerated()), id: \.element.id) { index, tab in
                                            let selected = isSelected(tab)
                                            TabItem(tab: tab, selected: selected,
                                                    divider: index > 0 && !selected && !isSelected(group.tabs[index - 1]),
                                                    width: width) {
                                                store.selection = .tab(tab.id)
                                            } onClose: {
                                                store.requestClose(tab)
                                            }
                                            .live { $0.draggable(TabDragItem.self, item: TabDragItem(id: tab.id))
                                                .dropDestination(for: TabDragItem.self) { items, _ in drop(items.first?.id, before: tab.id) } }
                                            .contextMenu { tabMenu(tab) }
                                            .tabAnchor(tab.id)
                                        }
                                    }
                                }
                                // 组头横跨整组：组宽 = 标签总宽和项目名里较宽的那个，横线铺满
                                .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                    }
                    .padding(.bottom, 5)
                    .frame(height: WorkspaceMetrics.tabBar, alignment: .bottom)
                    .padding(.leading, 6)
                    .live { $0.onDragSessionUpdated(dragUpdated) }
                }
                .frame(height: WorkspaceMetrics.tabBar)
                // 标签栏空白处：放到最后（别的窗口拖来的进它项目的组）
                .live { $0.dropDestination(for: TabDragItem.self) { items, _ in drop(items.first?.id, before: nil) } }
                PaneIcon(symbol: "plus", help: L("新会话（⌘T）"), action: onNewSession)
                    .padding(.horizontal, 8)
                    .frame(height: WorkspaceMetrics.tabHeight)
            }
            .frame(height: WorkspaceMetrics.tabBar, alignment: .bottom)
        }
        .frame(height: WorkspaceMetrics.tabBar)
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

    /// 和终端区右键同一份（TerminalMenu），少了文字操作；「移到窗口」放在关标签那组上面
    @ViewBuilder private func tabMenu(_ tab: TerminalTab) -> some View {
        let sections = TerminalMenu.sections(for: tab, in: store, text: false)
        Group {
            ForEach(Array(sections.dropLast().enumerated()), id: \.offset) { _, section in
                ForEach(Array(section.enumerated()), id: \.offset) { _, item in tabMenuItem(item, tab) }
                Divider()
            }
            Button { tearOff(tab.id) } label: { Label("移到新窗口", systemImage: "macwindow.badge.plus") }
            let others = store.otherWindows
            if !others.isEmpty {
                Menu {
                    ForEach(Array(others.enumerated()), id: \.offset) { _, other in
                        Button(other.windowTitle) { store.moveTab(tab.id, to: other) }
                    }
                } label: { Label("移到窗口", systemImage: "macwindow") }
            }
            Divider()
            ForEach(Array((sections.last ?? []).enumerated()), id: \.offset) { _, item in tabMenuItem(item, tab) }
        }
        .labelStyle(.titleAndIcon)      // macOS 的 SwiftUI 菜单默认只显示文字
    }

    @ViewBuilder private func tabMenuItem(_ item: TerminalMenu.Item, _ tab: TerminalTab) -> some View {
        if case .export(let formats) = item {
            Menu {
                ForEach(Array(formats.enumerated()), id: \.offset) { _, format in
                    Button(TerminalMenu.exportTitle(format)) { TerminalMenu.export(format, tab: tab, in: store) }
                }
            } label: { Label(item.title, systemImage: item.symbol) }
        } else {
            Button { TerminalMenu.perform(item, tab: tab, in: store) } label: { Label(item.title, systemImage: item.symbol) }
        }
    }

    /// 单个标签选中，或在当前分屏里
    private func isSelected(_ tab: TerminalTab) -> Bool {
        store.selectedTab?.id == tab.id || store.activeSplit?.contains(tab.id) == true
    }

    /// 展开的标签平分可用宽度，夹在最窄和最宽之间
    private func tabWidth(available: CGFloat) -> CGFloat {
        let visible = store.tabGroups.filter { !$0.isCollapsed }.reduce(0) { $0 + $1.tabs.count }
        guard visible > 0 else { return WorkspaceMetrics.tabMax }
        // 组间距 14；折叠的组只剩一个小块 ≈ 100
        let labels = store.tabGroups.reduce(CGFloat(0)) { $0 + ($1.isCollapsed ? 114 : 14) }
        let share = (available - labels - 60) / CGFloat(visible)
        return min(WorkspaceMetrics.tabMax, max(WorkspaceMetrics.tabMin, share))
    }
}

/// 组色：标签栏组头、已打开视图共用的项目色（不是强调色）。
/// 不用蓝 / 靛（深色底上发闷）；离当前主题的强调色 ≥ 40°（每套主题强调色不同，靠近的那一两个跳过），组头不会被看成状态灯。
/// 彩度压低一档，只给小字和细线用，不抢状态灯；深色提亮、浅色压暗，小字都读得清
enum GroupColors {
    //                         珊瑚       金        玫红      紫        橄榄绿     青（备用：前面有被跳过的才轮到）
    static let dark:  [UInt32] = [0xE39A72, 0xD9B864, 0xE48BB0, 0xB49AE8, 0xA9C46E, 0x6CC4B8]
    static let light: [UInt32] = [0xB5582A, 0x8E6B12, 0xB3456F, 0x7556C4, 0x5F7A1C, 0x1F7F74]
    static let minDistance: Double = 40

    /// 色相（度）；灰（饱和度太低）没有色相，返回 nil
    static func hue(of color: Color) -> Double? {
        #if os(macOS)
        guard let c = NSColor(color).usingColorSpace(.sRGB), c.saturationComponent > 0.2 else { return nil }
        return Double(c.hueComponent) * 360
        #else
        return nil
        #endif
    }

    /// 这个强调色下能用的组色，按上面的顺序取 5 个
    static func colors(avoiding accent: Color, dark: Bool) -> [UInt32] {
        let all = dark ? Self.dark : Self.light
        guard let a = hue(of: accent) else { return Array(all.prefix(5)) }
        let ok = all.filter { hex in
            guard let h = hue(of: Color(hex: hex)) else { return true }
            return abs((h - a + 540).truncatingRemainder(dividingBy: 360) - 180) >= minDistance
        }
        return Array(ok.prefix(5))
    }

    static func count(avoiding accent: Color, dark: Bool) -> Int { colors(avoiding: accent, dark: dark).count }
}

extension BarlyPalette {
    func groupColor(_ tint: Int) -> Color {
        let list = GroupColors.colors(avoiding: accent, dark: isDark)
        let i = ((tint % list.count) + list.count) % list.count
        return Color(hex: list[i])
    }
}

/// 组头：组色小字项目名 + 一根组色细线横跨整组，右端一个小竖钩收尾（像表格的分组表头）
private struct GroupHeader: View {
    let group: TabGroup
    let action: () -> Void
    @Environment(\.barly) private var t
    @State private var hovered = false

    var body: some View {
        let c = t.groupColor(group.tint)
        HStack(spacing: 6) {
            Button(action: action) {
                Text(group.name)
                    .barlyText(.product.caption.size(11).weight(500), color: hovered ? c.barlyMix(t.text, 0.35) : c)
                    .lineLimit(1)
                    .fixedSize()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovered = $0 }
            .handCursor()
            .help(L("折叠 \(group.name)"))
            Capsule().fill(c.opacity(0.4)).frame(height: 1.5)
        }
        .padding(.leading, 10).padding(.trailing, 4)
        .frame(height: WorkspaceMetrics.groupHeader - 2, alignment: .center)
    }
}

/// 折叠的组：组头那行照样是项目名，下面一行是「N 个 · 最紧急的状态」
private struct CollapsedGroup: View {
    let group: TabGroup
    let action: () -> Void
    @Environment(\.barly) private var t
    @State private var hovered = false

    var body: some View {
        let c = t.groupColor(group.tint)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Text(group.name).barlyText(.product.caption.size(11).weight(500), color: c)
                    .padding(.leading, 8)
                    .frame(height: WorkspaceMetrics.groupHeader - 2)
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right").font(.system(size: BarlyScale.pt(8), weight: .bold)).foregroundStyle(t.text4)
                    Text(verbatim: L("\(group.tabs.count) 个标签")).barlyText(.product.caption, color: t.text3)
                    ActivityLamp(group.mostUrgent, size: 5)
                }
                .padding(.horizontal, 8)
                .frame(height: WorkspaceMetrics.tabHeight)
                .background(hovered ? t.shellHover : .clear, in: RoundedRectangle(cornerRadius: WorkspaceMetrics.rowRadius, style: .continuous))
            }
            .padding(.leading, 2)
            .fixedSize()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .handCursor()
        .help(L("展开 \(group.name)"))
    }
}

private struct TabItem: View {
    let tab: TerminalTab
    let selected: Bool
    /// 左边一根细竖线（同组相邻、两边都没选中）
    var divider = false
    let width: CGFloat
    let action: () -> Void
    var onClose: () -> Void = {}
    @Environment(\.barly) private var t
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 6) {
            if tab.isPlainTerminal {
                Image(systemName: "terminal").font(.system(size: BarlyScale.pt(9))).foregroundStyle(t.text3)
            } else {
                ActivityLamp(tab.activity, size: 5)
            }
            Color.clear.frame(maxWidth: .infinity).overlay(alignment: .leading) {
                Text(tab.title)
                    .barlyText(.product.caption.size(12).weight(selected ? 500 : 400), color: selected ? t.text : hovered ? t.text2 : t.text3)
                    .lineLimit(1).fixedSize()
            }
            .clipped()
            .mask(LinearGradient(stops: [.init(color: .black, location: 0.8), .init(color: .clear, location: 1)],
                                 startPoint: .leading, endPoint: .trailing))
            if selected || hovered {
                Image(systemName: "xmark")
                    .font(.system(size: BarlyScale.pt(7), weight: .bold))
                    .foregroundStyle(t.text3)
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
                    .tapButton(L("关闭标签"), perform: onClose)
                    .handCursor()
                    .help("关闭标签（⌘W）")
            }
        }
        .padding(.horizontal, 10)
        .frame(width: width, height: WorkspaceMetrics.tabHeight)
        .background(selected ? t.shellSelected : hovered ? t.shellHover : .clear,
                    in: RoundedRectangle(cornerRadius: WorkspaceMetrics.rowRadius, style: .continuous))
        .overlay(alignment: .leading) {
            if divider { Rectangle().fill(t.hairline).frame(width: 1, height: 12) }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .onHover { hovered = $0 }
        .handCursor()
        .help(tab.title)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        // 合成一个元素后关闭按钮读屏点不到：放进动作菜单
        .accessibilityAction(.default, action)
        .accessibilityAction(named: L("关闭标签"), onClose)
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

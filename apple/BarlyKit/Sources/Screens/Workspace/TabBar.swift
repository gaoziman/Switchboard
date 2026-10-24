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

/// 顶部标签栏：按项目分组。每组是一个「描边托盘」——淡组色细框围住这组的标签，组色项目名嵌在上框线里（点一下折叠），
/// 组色落在整组上但只是一圈线。选中的标签是浮起的小卡片（实底 + 细边 + 一点阴影），没选中的用 text2，都看得清。
/// 标签随数量收窄，到最窄后横向滚动。
public struct TabBar: View {
    @Bindable var store: WorkspaceStore
    var sidebarHidden: Bool
    var onNewSession: () -> Void
    @Environment(\.barly) private var t
    @Environment(\.openWindow) private var openWindow
    /// 鼠标下的标签：它两边的分隔线不画
    @State private var hoveredTab: UUID?

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
                    HStack(alignment: .bottom, spacing: 12) {
                        ForEach(store.tabGroups) { group in
                            GroupTray(group: group, onToggle: { store.toggleCollapsed(group) }) {
                                if group.isCollapsed {
                                    CollapsedSummary(group: group) { store.toggleCollapsed(group) }
                                } else {
                                    ForEach(Array(group.tabs.enumerated()), id: \.element.id) { index, tab in
                                        // 同组相邻的两个标签之间一根短竖线；挨着选中的卡片、悬停的标签时不画
                                        let quiet: (TerminalTab) -> Bool = { !isSelected($0) && hoveredTab != $0.id }
                                        TabItem(tab: tab, selected: isSelected(tab), width: width,
                                                divider: index > 0 && quiet(tab) && quiet(group.tabs[index - 1]),
                                                naming: tab.kind.sessionID.map { store.data.naming.contains($0) } ?? false,
                                                onHover: { hoveredTab = $0 ? tab.id : (hoveredTab == tab.id ? nil : hoveredTab) }) {
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
                        }
                    }
                    .padding(.bottom, 4)
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
        // 每组：组间距 12 + 托盘内边距和框线 10 + 标签间距 2；折叠的组只剩一个小托盘 ≈ 110
        let labels = store.tabGroups.reduce(CGFloat(0)) { $0 + ($1.isCollapsed ? 122 : 22 + CGFloat($1.tabs.count - 1) * 2) }
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

/// 描边托盘：一圈淡组色细框围住这组的标签，组色项目名像分组框的标题一样嵌在上框线里（背后垫面板底色把线遮住）。
/// 点项目名折叠 / 展开。托盘至少和项目名一样宽，只开一个短标签时项目名也不会伸出框外
private struct GroupTray<Content: View>: View {
    let group: TabGroup
    let onToggle: () -> Void
    @ViewBuilder let content: Content
    @Environment(\.barly) private var t
    @State private var hovered = false

    /// 托盘离标签的内边距
    private static var inset: CGFloat { 4 }

    var body: some View {
        let c = t.groupColor(group.tint)
        VStack(alignment: .leading, spacing: 0) {
            legendText(c).padding(.horizontal, 16).frame(height: 0).hidden()    // 只撑宽度
            HStack(spacing: 2) { content }
        }
        .padding(.horizontal, Self.inset).padding(.top, Self.inset + 1).padding(.bottom, Self.inset)
        // 框里垫一层很淡的组色：选中的卡片（浅色是白底）才浮得出来
        .background(c.opacity(t.isDark ? 0.035 : 0.05), in: RoundedRectangle(cornerRadius: WorkspaceMetrics.trackRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: WorkspaceMetrics.trackRadius, style: .continuous).strokeBorder(c.opacity(0.38)))
        .overlay(alignment: .topLeading) {
            Button(action: onToggle) {
                legendText(hovered ? c.barlyMix(t.text, 0.35) : c)
                    .padding(.horizontal, 5)
                    .background(t.panelBg)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovered = $0 }
            .handCursor()
            .help(group.isCollapsed ? L("展开 \(group.name)") : L("折叠 \(group.name)"))
            .offset(x: 9, y: -BarlyScale.pt(7))
        }
        .fixedSize()
    }

    private func legendText(_ color: Color) -> some View {
        Text(group.name)
            .barlyText(.product.caption.size(11).weight(600), color: color)
            .lineLimit(1)
            .fixedSize()
    }
}

/// 折叠的组：托盘里只剩「› N 个标签 · 最紧急的状态」
private struct CollapsedSummary: View {
    let group: TabGroup
    let action: () -> Void
    @Environment(\.barly) private var t
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right").font(.system(size: BarlyScale.pt(8), weight: .bold)).foregroundStyle(t.text3)
                Text(verbatim: L("\(group.tabs.count) 个标签")).barlyText(.product.caption.size(12), color: hovered ? t.text : t.text2)
                ActivityLamp(group.mostUrgent, size: 5)
            }
            .padding(.horizontal, 9)
            .frame(height: WorkspaceMetrics.tabHeight)
            .background(hovered ? t.shellHover : .clear, in: RoundedRectangle(cornerRadius: WorkspaceMetrics.tabRadius, style: .continuous))
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
    let width: CGFloat
    /// 左边一根短竖线（同组相邻、两边都没选中也没悬停）
    var divider = false
    /// 正在 AI 起名：状态灯换成转圈
    var naming = false
    var onHover: (Bool) -> Void = { _ in }
    let action: () -> Void
    var onClose: () -> Void = {}
    @Environment(\.barly) private var t
    @State private var hovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: WorkspaceMetrics.tabRadius, style: .continuous)
        HStack(spacing: 7) {
            if naming {
                ProgressView().controlSize(.mini).frame(width: 10, height: 10)
            } else if tab.isPlainTerminal {
                Image(systemName: "terminal").font(.system(size: BarlyScale.pt(9))).foregroundStyle(t.text3)
            } else {
                ActivityLamp(tab.activity, size: 5)
            }
            SessionName.text(tab.title, separator: t.text4)
                .barlyText(.product.caption.size(12).weight(selected ? 600 : 400), color: selected || hovered ? t.text : t.text2)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
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
        .padding(.horizontal, 9)
        .frame(width: width, height: WorkspaceMetrics.tabHeight)
        .background {
            // 选中：浮起的小卡片（和灯板的浮起面板同一套：实底 + 细边 + 一点阴影）
            if selected {
                shape.fill(t.tabCard)
                    .overlay(shape.strokeBorder(t.tabCardEdge))
                    .shadow(color: .black.opacity(t.isDark ? 0.45 : 0.14), radius: 1.5, y: 1)
            } else if hovered {
                shape.fill(t.shellHover)
            }
        }
        .overlay(alignment: .leading) {
            if divider { Rectangle().fill(t.text4).frame(width: 1, height: 12).offset(x: -1.5) }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .onHover { hovered = $0; onHover($0) }
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

import SwiftUI

// MARK: - macOS 外壳骨架（identity.layout.shell + inspector，见 references/layouts.md §1）
//
//   sidebar       白色宽侧栏 272（Brisk）                        → Sidebar
//   sidebar-gray  灰侧栏 264 + ⌘K 搜索 + MENU 分组 + 白色选中块（Finnie） → GraySidebar
//   rail          80 图标窄栏（Lumeo）                            → IconRail
//   rail-list     窄栏 + 264 二级列表栏（RECENTS / PROJECTS）（Lumix / Omnize） → IconRail + ListColumn
//   topnav        无侧栏：56 顶栏（logo · 一级 tabs · 搜索 · 头像）+ 可选 44 二级 tab 条，内容居中最大宽 1200
//                 （lovable 应用内页：meeting-booker、journal、continuum、okr 等「只有顶部导航」的工具）→ TopNavBar + SubnavStrip
//   + inspector   右侧 320 检查栏（整栏 bgSubtle + 左沿发丝线，卡片白底）
//
// 屏幕只描述「有哪些导航、列表、检查栏内容」（ShellSpec），外壳由身份决定；同一屏在四种外壳下都成立。

public struct ShellListItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let detail: String?
    public let icon: String?
    public init(_ id: String, _ title: String, detail: String? = nil, icon: String? = nil) {
        self.id = id; self.title = title; self.detail = detail; self.icon = icon
    }
}

public struct ShellListSection: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let items: [ShellListItem]
    public init(_ title: String, _ items: [ShellListItem]) { self.id = title; self.title = title; self.items = items }
}

/// 一屏的导航描述：四种外壳各取所需
public struct ShellSpec {
    public var brand: (String, String)
    public var workspace: String
    public var nav: [SidebarNavItem]
    public var selection: String
    public var groups: [SidebarGroup]
    public var footer: [SidebarNavItem]
    public var storage: (Double, String)?
    public var user: (String, String)
    /// rail-list 的二级栏：标题、顶部按钮、分组列表、选中项
    public var listTitle: String
    public var listAction: String
    public var list: [ShellListSection]
    public var listSelection: String?
    /// topnav 的二级 tab 条（空 = 不显示）；其他外壳忽略
    public var subnav: [String]
    public var subnavSelection: Int
    public init(brand: (String, String), workspace: String = "Workspace", nav: [SidebarNavItem], selection: String,
                groups: [SidebarGroup] = [], footer: [SidebarNavItem] = [], storage: (Double, String)? = nil,
                user: (String, String), listTitle: String = "Chats", listAction: String = "New chat",
                list: [ShellListSection] = [], listSelection: String? = nil,
                subnav: [String] = [], subnavSelection: Int = 0) {
        self.brand = brand; self.workspace = workspace; self.nav = nav; self.selection = selection
        self.groups = groups; self.footer = footer; self.storage = storage; self.user = user
        self.listTitle = listTitle; self.listAction = listAction; self.list = list; self.listSelection = listSelection
        self.subnav = subnav; self.subnavSelection = subnavSelection
    }
}

public enum ShellMetrics {
    public static let grayBar: CGFloat = 264
    public static let listColumn: CGFloat = 264
    public static let inspector: CGFloat = 320
    /// topnav：顶栏高、二级 tab 条高、内容列最大宽
    public static let topNav: CGFloat = 56
    public static let subnav: CGFloat = 44
    public static let topNavMaxWidth: CGFloat = 1200
    /// 外壳左侧总宽
    public static func sideWidth(_ shell: String) -> CGFloat {
        switch shell {
        case "topnav": 0
        case "sidebar-gray": grayBar
        case "rail": BarlyMetrics.rail
        case "rail-list": BarlyMetrics.rail + listColumn
        default: BarlyMetrics.sidebar
        }
    }
}

/// 按身份骨架切外壳；inspector 内容由屏幕给，身份 inspector=false 时不显示
public struct AppShell<Content: View, Inspector: View>: View {
    let spec: ShellSpec
    let content: Content
    let inspector: Inspector
    let onSelect: (String) -> Void
    @Environment(\.barlyShell) private var shell
    @Environment(\.barlyInspector) private var showInspector
    @Environment(\.barly) private var t

    public init(_ spec: ShellSpec, onSelect: @escaping (String) -> Void = { _ in },
                @ViewBuilder content: () -> Content, @ViewBuilder inspector: () -> Inspector) {
        self.spec = spec; self.onSelect = onSelect; self.content = content(); self.inspector = inspector()
    }

    public var body: some View {
        if shell == "topnav" { topnav } else { sided }
    }

    /// topnav：顶栏 + 可选二级 tab 条，内容列居中（≤ 1200），检查栏贴右
    private var topnav: some View {
        GeometryReader { g in
            let insp = showInspector ? ShellMetrics.inspector : 0
            let col = min(ShellMetrics.topNavMaxWidth, g.size.width - insp)
            VStack(spacing: 0) {
                TopNavBar(spec: spec, onSelect: onSelect)
                if !spec.subnav.isEmpty { SubnavStrip(spec.subnav, selection: spec.subnavSelection, width: col) }
                HStack(spacing: 0) {
                    content
                        .frame(width: col)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .environment(\.barlyContentWidth, max(480, col))
                    if showInspector { InspectorColumn(inset: false) { inspector } }
                }
            }
            .background(t.bg)
            .ignoresSafeArea()
        }
    }

    private var sided: some View {
        GeometryReader { g in
            let side = ShellMetrics.sideWidth(shell)
            let insp = showInspector ? ShellMetrics.inspector : 0
            MacShell {
                sidebar
            } content: {
                HStack(spacing: 0) {
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .environment(\.barlyContentWidth, max(480, g.size.width - side - insp))
                    if showInspector { InspectorColumn { inspector } }
                }
            }
        }
    }

    @ViewBuilder private var sidebar: some View {
        switch shell {
        case "sidebar-gray":
            GraySidebar(spec: spec, onSelect: onSelect)
        case "rail":
            IconRail(items: spec.nav, selection: spec.selection, user: spec.user.0, onSelect: onSelect)
        case "rail-list":
            HStack(spacing: 0) {
                IconRail(items: spec.nav, selection: spec.selection, user: spec.user.0, onSelect: onSelect)
                ListColumn(spec: spec)
            }
        default:
            Sidebar(brand: spec.brand, workspace: spec.workspace, nav: spec.nav, selection: spec.selection,
                    groups: spec.groups, footer: spec.footer, storage: spec.storage, user: spec.user, onSelect: onSelect)
        }
    }
}

public extension AppShell where Inspector == EmptyView {
    init(_ spec: ShellSpec, onSelect: @escaping (String) -> Void = { _ in }, @ViewBuilder content: () -> Content) {
        self.init(spec, onSelect: onSelect, content: content, inspector: { EmptyView() })
    }
}

// MARK: - topnav（无侧栏，只有顶部导航）

/// 56 顶栏：[红绿灯位] logo 28 + 品牌 · 一级 tabs（spec.nav）…… ⌘K 搜索 · 通知 · 头像；底部发丝线。
/// 选中 tab：Barly / soft / noir = 弱底块 + 500 字；线框族（editorial / swiss / press / console / brutal / flood / gallery）= 底边 2pt 主文字色下划线。
public struct TopNavBar: View {
    let spec: ShellSpec
    let onSelect: (String) -> Void
    @State private var q = ""
    @Environment(\.barly) private var t
    @Environment(\.barlyTitlebarInset) private var inset
    public init(spec: ShellSpec, onSelect: @escaping (String) -> Void = { _ in }) { self.spec = spec; self.onSelect = onSelect }

    static var underline: Bool { ![.barly, .soft, .noir].contains(BarlyFamily.current) }

    public var body: some View {
        HStack(spacing: 0) {
            if inset > 0 { Color.clear.frame(width: 72, height: 1) }   // 红绿灯
            HStack(spacing: 10) {
                LogoMark(size: 28)
                Text(spec.brand.0).barlyText(FamilyType.pageTitle(BarlyTokens.Product.sectionTitle), color: t.text).lineLimit(1)
            }
            .padding(.trailing, 28)
            HStack(spacing: Self.underline ? 22 : 4) {
                ForEach(spec.nav) { n in tab(n, on: n.id == spec.selection).onTapGesture { onSelect(n.id) } }
            }
            .frame(maxHeight: .infinity)
            Spacer(minLength: 16)
            HStack(spacing: 12) {
                SearchField(BarlyTokens.lang == "zh" ? "搜索" : "Search", text: $q, shortcut: "⌘K", width: 220)
                IconButton("bell", size: 34, style: .ghost, badge: true)
                Avatar(spec.user.0, size: 30)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: ShellMetrics.topNav)
        .padding(.top, inset > 0 ? max(0, inset - 14) : 0)
        .background(t.bg)
        .overlay(alignment: .bottom) { Hairline() }
    }

    @ViewBuilder private func tab(_ n: SidebarNavItem, on: Bool) -> some View {
        let label = HStack(spacing: 7) {
            Text(n.title).barlyText(on ? .product.body.weight(500) : .product.body, color: on ? t.text : t.text2)
            if let b = n.badge { Text(b).barlyText(.product.caption, color: t.text3) }
        }
        .fixedSize()
        if Self.underline {
            label.frame(maxHeight: .infinity)
                .overlay(alignment: .bottom) { if on { Rectangle().fill(t.text).frame(height: 2) } }
                .contentShape(Rectangle())
        } else {
            label.padding(.horizontal, 12).frame(height: 32)
                .background(RoundedRectangle(cornerRadius: BarlyRadius.sm, style: .continuous).fill(on ? t.softSurface : .clear))
                .contentShape(Rectangle())
        }
    }
}

/// 44 二级 tab 条：和内容列同宽居中，选中 = 主文字 500 + 2pt 下划线；整条底部发丝线
public struct SubnavStrip: View {
    let items: [String]
    let selection: Int
    let width: CGFloat
    @Environment(\.barly) private var t
    public init(_ items: [String], selection: Int, width: CGFloat) { self.items = items; self.selection = selection; self.width = width }
    public var body: some View {
        HStack(spacing: 24) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, s in
                Text(s).barlyText(i == selection ? .product.body.weight(500) : .product.body, color: i == selection ? t.text : t.text3)
                    .frame(maxHeight: .infinity)
                    .overlay(alignment: .bottom) { if i == selection { Rectangle().fill(t.text).frame(height: 2) } }
            }
            Spacer()
        }
        .padding(.horizontal, BarlyMetrics.contentPad)
        .frame(width: width, height: ShellMetrics.subnav)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) { Hairline() }
    }
}

// MARK: - sidebar-gray（Finnie）

/// 灰侧栏 264：品牌行 → ⌘K 搜索框 40 → MENU 分组 → 行距 44 的导航（选中 = 40 高白块）→ GENERAL → 底部白色用户卡
public struct GraySidebar: View {
    let spec: ShellSpec
    let onSelect: (String) -> Void
    @State private var q = ""
    @Environment(\.barly) private var t
    @Environment(\.barlyTitlebarInset) private var inset
    public init(spec: ShellSpec, onSelect: @escaping (String) -> Void = { _ in }) { self.spec = spec; self.onSelect = onSelect }

    private var barBg: Color { t.isDark ? t.bgSubtle : t.bgMuted.barlyMix(t.bg, 0.25) }
    private var selBg: Color { t.isDark ? t.fill2 : t.surface }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                LogoMark(size: 32)
                Text(spec.brand.0).barlyText(FamilyType.pageTitle(BarlyTokens.Product.sectionTitle), color: t.text)
                Spacer()
                BarlyIcon("sidebar.left", size: 16, color: t.text3)
            }
            .padding(.top, 20 + inset)
            // ⌘K 搜索：比侧栏深一级的槽，无边
            HStack(spacing: 8) {
                BarlyIcon("magnifyingglass", size: 15, color: t.text3)
                Text(BarlyTokens.lang == "zh" ? "搜索" : "Search").barlyText(.product.body, color: t.text3)
                Spacer()
                Text("⌘K").barlyText(.product.caption.weight(500), color: t.text3)
                    .padding(.horizontal, 6).frame(height: 22)
                    .background(RoundedRectangle(cornerRadius: BarlyRadius.xs).fill(selBg))
            }
            .padding(.horizontal, 12).frame(height: 40)
            .background(RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous).fill(t.isDark ? t.fill1 : t.bgMuted.barlyMix(.black, 0.035)))
            .padding(.top, 20)

            MonoLabel("Menu", color: t.text3).padding(.top, 28).padding(.leading, 4)
            VStack(spacing: 4) {
                ForEach(spec.nav) { n in row(n, selected: n.id == spec.selection).onTapGesture { onSelect(n.id) } }
            }
            .padding(.top, 10)
            if !spec.footer.isEmpty {
                MonoLabel("General", color: t.text3).padding(.top, 24).padding(.leading, 4)
                VStack(spacing: 4) { ForEach(spec.footer) { row($0, selected: false) } }.padding(.top, 10)
            }
            Spacer(minLength: 16)
            // 底部白色用户卡
            UserCard(name: spec.user.0, email: spec.user.1)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: BarlyRadius.lg, style: .continuous).fill(selBg))
                .overlay(RoundedRectangle(cornerRadius: BarlyRadius.lg, style: .continuous).strokeBorder(t.isDark ? .clear : t.border.opacity(0.7), lineWidth: 1))
                .padding(.bottom, 20)
        }
        .padding(.horizontal, 16)
        .frame(width: ShellMetrics.grayBar)
        .frame(maxHeight: .infinity)
        .background(barBg)
    }

    private func row(_ n: SidebarNavItem, selected: Bool) -> some View {
        // dna v2 §1.2：--intensity full 的深色主题，选中块 = 强调色暗 tint 横向渐变 + 亮字（Enigma）；其余保持中性灰块
        let tinted = BarlyTokens.Style.isFull && t.isDark
        let fg = selected ? (tinted ? t.navSelectedFg : t.text) : t.text2
        return HStack(spacing: 12) {
            BarlyIcon(n.icon, size: 17, color: fg)
            Text(n.title).barlyText(selected ? .product.body.weight(500) : .product.body, color: fg)
            Spacer()
            if let b = n.badge { Text(b).barlyText(.product.caption, color: t.text3) }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background {
            if selected && tinted {
                RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous)
                    .fill(LinearGradient(colors: [t.navSelectedFrom, t.navSelectedTo], startPoint: .leading, endPoint: .trailing))
            } else if selected {
                RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous).fill(selBg)
                    .overlay(RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous).strokeBorder(t.isDark ? .clear : t.border.opacity(0.6), lineWidth: 1))
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - rail-list 的二级列表栏（Lumix / Omnize）

/// 264 宽，底比主区深一级（浅 bgSubtle，深 surface）；顶部标题 + 「+ 新对话」；mono 分组（RECENTS / PROJECTS）；条目 36 高，选中浅灰块
public struct ListColumn: View {
    let spec: ShellSpec
    @Environment(\.barly) private var t
    @Environment(\.barlyTitlebarInset) private var inset
    public init(spec: ShellSpec) { self.spec = spec }
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(spec.listTitle).barlyText(FamilyType.pageTitle(BarlyTokens.Product.sectionTitle), color: t.text)
                Spacer()
                BarlyIcon("magnifyingglass", size: 15, color: t.text3)
            }
            .frame(height: 40)
            .padding(.top, 20 + inset)
            BarlyButton(spec.listAction, icon: "plus", variant: .outline, size: .md, fullWidth: true)
                .padding(.top, 14)
            ForEach(spec.list) { sec in
                MonoLabel(sec.title, color: t.text3).padding(.top, 26).padding(.leading, 10).padding(.bottom, 8)
                VStack(spacing: 2) {
                    ForEach(sec.items) { it in item(it, selected: it.id == spec.listSelection) }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(width: ShellMetrics.listColumn)
        .frame(maxHeight: .infinity)
        .background(t.isDark ? t.bgSubtle : t.bgSubtle)
        .overlay(alignment: .trailing) { Hairline(vertical: true) }
    }

    private func item(_ it: ShellListItem, selected: Bool) -> some View {
        HStack(spacing: 10) {
            if let icon = it.icon { BarlyIcon(icon, size: 15, color: selected ? t.text : t.text3) }
            Text(it.title).barlyText(.product.body, color: selected ? t.text : t.text2).lineLimit(1)
            Spacer(minLength: 6)
            if let d = it.detail { Text(d).barlyText(.product.caption, color: t.text3) }
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(RoundedRectangle(cornerRadius: BarlyRadius.sm, style: .continuous).fill(selected ? (t.isDark ? t.fill2 : t.bgMuted) : .clear))
    }
}

// MARK: - inspector 右栏

/// 320 宽整栏：浅 bgSubtle / 深 bgSubtle，左沿发丝线，内边距 16，卡间距 16（卡片用 Card，白底 1px 边）
public struct InspectorColumn<Content: View>: View {
    let content: Content
    let useInset: Bool
    @Environment(\.barly) private var t
    @Environment(\.barlyTitlebarInset) private var inset
    /// inset = 顶部给红绿灯留位（topnav 下检查栏在顶栏下面，不用留）
    public init(inset: Bool = true, @ViewBuilder content: () -> Content) { self.content = content(); self.useInset = inset }
    public var body: some View {
        BarlyScroll {
            VStack(alignment: .leading, spacing: 16) { content }
                .padding(16)
                .padding(.top, useInset ? inset : 0)
        }
        .frame(width: ShellMetrics.inspector)
        .frame(maxHeight: .infinity)
        .background(t.isDark ? t.bgSubtle : t.bgSubtle)
        .overlay(alignment: .leading) { Hairline(vertical: true) }
    }
}

/// 检查栏里的一节：标题 + 内容（Card 包好）
public struct InspectorSection<Content: View>: View {
    let title: String
    let action: String?
    let content: Content
    @Environment(\.barly) private var t
    public init(_ title: String, action: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title; self.action = action; self.content = content()
    }
    public var body: some View {
        Card(padding: 16, fill: t.isDark ? t.fill0 : t.surface) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title).barlyText(FamilyType.pageTitle(BarlyTokens.Product.sectionTitle), color: t.text)
                    Spacer()
                    if let action { Text(action).barlyText(.product.caption, color: t.text3) }
                }
                content
            }
        }
    }
}

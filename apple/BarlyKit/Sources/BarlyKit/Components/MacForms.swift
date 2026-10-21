import SwiftUI

// macOS 三种 app 形态的外壳组件（身份轴 --mac-form window|menubar|panel，references/apple.md「Mac 形态」）。
// Barly 没有 Mac 作品：视觉沿用 Web / 产品 UI 的 DNA（中性骨架、1px 发丝线、mono 小标签、一个强调色），
// 尺寸取 macOS 惯例（菜单栏弹窗 340–400 宽、Spotlight 式面板 640–720 宽、设置窗口 640–720 宽）。

// MARK: - 快捷键提示

/// 键帽：↵ ↑ ↓ esc 等**单个按键提示**（启动器底部「打开 ↵ · 切换 ↑↓」）。组合键（⌥⇧Space）一律用 KeyCombo，不要逐键套 KeyCap。
public struct KeyCap: View {
    let key: String
    @Environment(\.barly) private var t
    public init(_ key: String) { self.key = key }
    public var body: some View {
        Text(key).barlyText(.monoText(11), color: t.text2)
            .padding(.horizontal, 5).frame(minWidth: 20, minHeight: 20)
            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(t.fill2))
    }
}

/// 快捷键组合：**一串紧凑文字**「⌥⇧Space」，Mac 菜单和系统设置都这样写（2026-10-19 用户反馈：每个键一个方框太丑、缝隙太大）。
/// 默认无底（菜单行、设置行的右侧）；boxed = 一个整体的浅灰小底（行内提示「按 ⌥⇧Space 呼出」时用）。
/// 修饰键顺序按 Apple 规范：⌃ ⌥ ⇧ ⌘，传入时可以乱序。
public struct KeyCombo: View {
    let keys: [String]
    let boxed: Bool
    @Environment(\.barly) private var t
    public init(_ keys: [String], boxed: Bool = false) { self.keys = keys; self.boxed = boxed }
    static let order = ["⌃", "⌥", "⇧", "⌘"]
    var text: String {
        let mods = Self.order.filter { keys.contains($0) }
        let rest = keys.filter { !Self.order.contains($0) }
        return (mods + rest).joined()
    }
    public var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .regular))
            .tracking(0.6)
            .foregroundStyle(t.text2)
            .padding(.horizontal, boxed ? 6 : 0)
            .frame(minHeight: boxed ? 20 : nil)
            .background(boxed ? RoundedRectangle(cornerRadius: 5, style: .continuous).fill(t.fill1) : nil)
    }
}

/// 一行「动作 · 快捷键」（菜单栏弹窗底部、面板底部、命令列表）。
public struct ShortcutRow: View {
    let icon: String?
    let title: String
    let keys: [String]
    @Environment(\.barly) private var t
    public init(_ title: String, icon: String? = nil, keys: [String] = []) { self.title = title; self.icon = icon; self.keys = keys }
    public var body: some View {
        HStack(spacing: 10) {
            if let icon { BarlyIcon(icon, size: 15, color: t.text2) }
            Text(title).barlyText(.product.body, color: t.text)
            Spacer(minLength: 8)
            if !keys.isEmpty { KeyCombo(keys) }
        }
        .padding(.horizontal, 10).frame(height: 30)
        .contentShape(Rectangle())
    }
}

// MARK: - 菜单栏弹窗（--mac-form menubar）

/// 菜单栏弹窗外壳：顶栏（logo 方块 + 产品名 + 状态 / 右侧图标按钮）→ 内容 → 发丝线 → 底部动作行（打开主窗口 / 设置 / 退出，带快捷键）。
/// 宽 340–400；底色 = 产品底色（浅白 / 深 surface），由 NSPopover 承载（App/macOS/menubar/StatusItemController.swift）。
public struct MenuBarPopover<Content: View>: View {
    let title: String
    let subtitle: String?
    let logo: String
    let width: CGFloat
    let footer: [(String, String, [String])]
    let onFooter: ((Int) -> Void)?
    let content: Content
    @Environment(\.barly) private var t
    @Environment(\.barlySnapshot) private var snapshot
    /// footer：(标题, SF Symbol, 键位)；onFooter 收到被点的序号（App/macOS/menubar 里接到「打开主窗口 / 设置 / 退出」）
    public init(title: String, subtitle: String? = nil, logo: String = "sparkle", width: CGFloat = 360,
                footer: [(String, String, [String])] = [("打开主窗口", "macwindow", ["⌘", "O"]), ("设置…", "gearshape", ["⌘", ","]), ("退出", "power", ["⌘", "Q"])],
                onFooter: ((Int) -> Void)? = nil,
                @ViewBuilder content: () -> Content) {
        self.title = title; self.subtitle = subtitle; self.logo = logo; self.width = width; self.footer = footer; self.onFooter = onFooter; self.content = content()
    }
    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                BarlyIcon(logo, size: 15, color: t.accentFg)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(t.accent))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).barlyText(.product.body.weight(500), color: t.text)
                    if let subtitle { Text(subtitle).barlyText(.product.caption, color: t.text3) }
                }
                Spacer()
                BarlyIcon("ellipsis", size: 15, color: t.text2)
            }
            .padding(.horizontal, 14).frame(height: 54)
            Rectangle().fill(t.border).frame(height: 1)
            content.frame(maxWidth: .infinity, alignment: .topLeading)
            Rectangle().fill(t.border).frame(height: 1)
            VStack(spacing: 0) {
                ForEach(Array(footer.enumerated()), id: \.offset) { i, f in
                    Button { onFooter?(i) } label: { ShortcutRow(f.0, icon: f.1, keys: f.2) }
                        .buttonStyle(.plain)
                        .modifier(KeyEquivalentModifier(keys: f.2))
                }
            }
            .padding(6)
        }
        .frame(width: width)
        // NSPopover 自带系统材质（毛玻璃 + 箭头），内容层透明才透得出来（references/mac-native.md）；快照里画不出材质，退成实色
        .background(snapshot ? (t.isDark ? Color(hex: 0x2A2B2F) : Color(hex: 0xF6F6F8)) : Color.clear)
    }
}

/// 把 ["⌘", "O"] 这种键位描述挂成真实快捷键（只认「⌘ / ⇧ / ⌥ / ⌃ + 单个字符」）。
struct KeyEquivalentModifier: ViewModifier {
    let keys: [String]
    func body(content: Content) -> some View {
        guard let last = keys.last, last.count == 1, let ch = last.lowercased().first else { return AnyView(content) }
        var mods: EventModifiers = []
        if keys.contains("⌘") { mods.insert(.command) }
        if keys.contains("⇧") { mods.insert(.shift) }
        if keys.contains("⌥") { mods.insert(.option) }
        if keys.contains("⌃") { mods.insert(.control) }
        return AnyView(content.keyboardShortcut(KeyEquivalent(ch), modifiers: mods))
    }
}

// MARK: - 浮动面板 / 启动器（--mac-form panel）

/// Spotlight 式浮动面板：大搜索框（mono 键位提示）→ 分组结果（mono 组名，选中行 navSelected 块）→ 底部键位提示条。
/// 宽 640–720，r16，1px 边 + 浮层阴影；由无边框 NSPanel 承载（App/macOS/panel/PanelController.swift），⌥Space 呼出。
public struct LauncherPanel<Results: View>: View {
    let query: String
    let placeholder: String
    let width: CGFloat
    let hints: [(String, [String])]
    let results: Results
    @Environment(\.barly) private var t
    public init(query: String = "", placeholder: String = "搜索或输入命令…", width: CGFloat = 680,
                hints: [(String, [String])] = [("打开", ["↵"]), ("切换", ["↑", "↓"]), ("关闭", ["esc"])],
                @ViewBuilder results: () -> Results) {
        self.query = query; self.placeholder = placeholder; self.width = width; self.hints = hints; self.results = results()
    }
    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                BarlyIcon("magnifyingglass", size: 20, color: t.text2)
                Text(query.isEmpty ? placeholder : query)
                    .barlyText(.product.body.size(20), color: query.isEmpty ? t.text3 : t.text)
                Spacer()
                KeyCombo(["⌥", "Space"], boxed: true)
            }
            .padding(.horizontal, 18).frame(height: 62)
            Rectangle().fill(t.border).frame(height: 1)
            VStack(alignment: .leading, spacing: 2) { results }
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Rectangle().fill(t.border).frame(height: 1)
            HStack(spacing: 16) {
                Spacer()
                ForEach(Array(hints.enumerated()), id: \.offset) { _, h in
                    HStack(spacing: 6) { Text(h.0).barlyText(.product.caption, color: t.text3); HStack(spacing: 3) { ForEach(h.1, id: \.self) { KeyCap($0) } } }
                }
            }
            .padding(.horizontal, 14).frame(height: 40)
        }
        .frame(width: width)
        .barlyGlass(16)   // 系统毛玻璃（Spotlight / Raycast 同款），见 references/mac-native.md
    }
}

/// 启动器结果分组标题（mono 小标签）。
public struct LauncherSection: View {
    let title: String
    @Environment(\.barly) private var t
    public init(_ title: String) { self.title = title }
    public var body: some View { Text(title).barlyText(.product.label, color: t.text3).padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 4) }
}

/// 启动器结果行：图标块 + 标题 / 副标题 + 右侧类型或快捷键；选中 = navSelected 块。
public struct LauncherRow: View {
    let icon: String
    let tone: Int
    let title: String
    let subtitle: String?
    let trailing: String?
    let selected: Bool
    @Environment(\.barly) private var t
    public init(_ title: String, subtitle: String? = nil, icon: String, tone: Int = 1, trailing: String? = nil, selected: Bool = false) {
        self.title = title; self.subtitle = subtitle; self.icon = icon; self.tone = tone; self.trailing = trailing; self.selected = selected
    }
    public var body: some View {
        HStack(spacing: 12) {
            IconTile(icon, tone: tone, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).barlyText(.product.body.weight(selected ? 500 : 400), color: t.text)
                if let subtitle { Text(subtitle).barlyText(.product.caption, color: t.text3) }
            }
            Spacer()
            if let trailing { Text(trailing).barlyText(.product.caption, color: t.text3) }
            if selected { KeyCap("↵") }
        }
        .padding(.horizontal, 10).frame(height: 50)
        .background(selected ? RoundedRectangle(cornerRadius: 10, style: .continuous).fill(LinearGradient(colors: [t.navSelectedFrom, t.navSelectedTo], startPoint: .leading, endPoint: .trailing)) : nil)
    }
}

// MARK: - 设置窗口（三种形态共用，⌘,）

/// 设置窗口：左 180 分页目录（图标 + 名称，选中 navSelected 块）+ 右侧表单（SettingsGroup / SettingsRow，见 Components/Apps/AppSettings.swift）。
/// Mac 用户默认去 ⌘, 找选项：所有偏好放这里，不藏进主窗口。窗口 680×460 起。
public struct SettingsWindow<Content: View>: View {
    public struct Pane: Identifiable, Sendable {
        public let id: String, title: String, icon: String
        public init(_ id: String, title: String, icon: String) { self.id = id; self.title = title; self.icon = icon }
    }
    let panes: [Pane]
    let selection: String
    let onSelect: (String) -> Void
    let content: Content
    @Environment(\.barly) private var t
    @Environment(\.barlyTitlebarInset) private var inset
    public init(panes: [Pane], selection: String, onSelect: @escaping (String) -> Void = { _ in }, @ViewBuilder content: () -> Content) {
        self.panes = panes; self.selection = selection; self.onSelect = onSelect; self.content = content()
    }
    public var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(panes) { p in
                    NavRowV2(p.title, icon: p.icon, selected: p.id == selection)
                        .onTapGesture { onSelect(p.id) }
                }
                Spacer()
            }
            .padding(.horizontal, 10).padding(.top, 14 + inset)
            .frame(width: 190)
            .frame(maxHeight: .infinity)
            .background(t.sidebarBg)
            .overlay(alignment: .trailing) { Rectangle().fill(t.border).frame(width: 1) }
            BarlyScroll { VStack(alignment: .leading, spacing: 20) { content }.padding(.horizontal, 28).padding(.top, 22 + inset).padding(.bottom, 24) }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(t.canvas)
        }
    }
}

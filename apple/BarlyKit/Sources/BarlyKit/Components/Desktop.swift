import SwiftUI

// MARK: - 品牌块 / Logo

/// 方块 logo：40 圆角方块（深色 ink 或强调色）+ 品牌符号。
/// 品牌符号优先读 Resources/Brand/symbol.png（logo.mjs --sync 拷进来，按 glyph 色着色），没有就用模板的放射光芒标。
public struct LogoMark: View {
    let size: CGFloat
    let circle: Bool
    let useAccent: Bool
    @Environment(\.barly) private var t
    public init(size: CGFloat = 40, circle: Bool = false, useAccent: Bool = false) { self.size = size; self.circle = circle; self.useAccent = useAccent }
    public var body: some View {
        let fill = useAccent ? t.accent : (t.isDark ? t.fill2 : t.ink)
        let glyph = useAccent ? Color.white : (t.isDark ? t.text : t.inkFg)
        ZStack {
            if circle { Circle().fill(fill) } else { RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous).fill(fill) }
            if let img = BrandSymbol.image {
                img.resizable().renderingMode(.template).interpolation(.high).scaledToFit()
                    .frame(width: size * 0.62, height: size * 0.62).foregroundStyle(glyph)
            } else {
                BarlyIcon("barly.radiant", size: size * 0.6, color: glyph)
            }
        }
        .frame(width: size, height: size)
    }
}

/// 定稿品牌符号（logo.mjs --sync → Resources/Brand/symbol.png）。没有同步过时为 nil。
public enum BrandSymbol {
    public static let image: Image? = {
        guard let url = Bundle.module.url(forResource: "symbol", withExtension: "png", subdirectory: "Brand") else { return nil }
        #if os(macOS)
        guard let ns = NSImage(contentsOf: url) else { return nil }
        return Image(nsImage: ns)
        #else
        guard let ui = UIImage(contentsOfFile: url.path) else { return nil }
        return Image(uiImage: ui)
        #endif
    }()
}

/// 公司 logo（20 方块 + 白色 glyph）——表格里的公司标占位（演示用虚构公司，SF Symbol 只限 Apple 平台），颜色取该公司本色
public struct CompanyLogo: View {
    let glyph: String
    let color: Color
    let size: CGFloat
    public init(_ glyph: String, color: Color, size: CGFloat = 20) { self.glyph = glyph; self.color = color; self.size = size }
    public var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous).fill(color)
            .overlay(Image(systemName: glyph).font(.system(size: size * 0.52, weight: .semibold)).foregroundStyle(.white))
            .frame(width: size, height: size)
    }
}

// MARK: - 侧栏（Brisk 结构）

public struct SidebarNavItem: Identifiable, Sendable {
    public let id: String
    public let icon: String
    public let title: String
    public let badge: String?
    public init(_ id: String, icon: String, title: String, badge: String? = nil) { self.id = id; self.icon = icon; self.title = title; self.badge = badge }
}

public struct SidebarGroup: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let color: Color
    public let children: [String]
    public init(_ title: String, color: Color, children: [String]) { self.id = title; self.title = title; self.color = color; self.children = children }
}

/// 工作区 logo 块：40 方块 + 两行字 + 收起侧栏按钮
public struct SidebarBrand: View {
    let title: String
    let subtitle: String
    @Environment(\.barly) private var t
    public init(_ title: String, subtitle: String) { self.title = title; self.subtitle = subtitle }
    public var body: some View {
        HStack(spacing: 12) {
            LogoMark(size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).barlyText(.product.cardTitle, color: t.text)
                Text(subtitle).barlyText(.product.caption, color: t.text2)
            }
            Spacer()
            BarlyIcon("sidebar.left", size: 16, color: t.text3)
        }
    }
}

/// 工作区切换器：白底描边 40 高，右侧上下双箭头小方钮
public struct WorkspaceSwitcher: View {
    let name: String
    @Environment(\.barly) private var t
    public init(_ name: String) { self.name = name }
    public var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: BarlyRadius.xs, style: .continuous).fill(t.fill2)
                .overlay(Image(systemName: "square.grid.2x2").font(.system(size: 10, weight: .semibold)).foregroundStyle(t.text))
                .frame(width: 22, height: 22)
            Text(name).barlyText(.product.body.weight(500), color: t.text)
            Spacer()
            Image(systemName: "chevron.up.chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(t.text2)
                .frame(width: 22, height: 22)
                .overlay(RoundedRectangle(cornerRadius: BarlyRadius.xs, style: .continuous).strokeBorder(t.border, lineWidth: 1))
        }
        .padding(.horizontal, 10)
        .frame(height: 40)
        .background(RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous).fill(t.fieldBg))
        .overlay(RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous).strokeBorder(t.fieldBorder, lineWidth: 1))
    }
}

/// 导航行：高 36、行距 44；选中 = 弱底 + 主文字 500，无色条、无强调色
public struct SidebarRow: View {
    let icon: String
    let title: String
    let selected: Bool
    let trailing: String?
    @Environment(\.barly) private var t
    public init(icon: String, title: String, selected: Bool = false, trailing: String? = nil) {
        self.icon = icon; self.title = title; self.selected = selected; self.trailing = trailing
    }
    public var body: some View {
        HStack(spacing: 12) {
            BarlyIcon(icon, size: 17, color: selected ? t.text : t.text2)
            Text(title).barlyText(selected ? .product.body.weight(500) : .product.body, color: selected ? t.text : t.text2)
            Spacer()
            if let trailing { BarlyIcon(trailing, size: 13, color: t.text3) }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(RoundedRectangle(cornerRadius: BarlyRadius.sm, style: .continuous).fill(selected ? (t.isDark ? t.fill1 : t.bgSubtle) : .clear))
        .contentShape(Rectangle())
    }
}

/// 分组（收藏 / 项目）：彩色 16 方块 + 标题 + ··· +；子项用 1px 虚线竖线串成树
public struct SidebarGroupView: View {
    let group: SidebarGroup
    @Environment(\.barly) private var t
    public init(_ group: SidebarGroup) { self.group = group }
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 4, style: .continuous).fill(group.color)
                    .overlay(Rectangle().fill(.white).frame(width: 7, height: 1.5))
                    .frame(width: 16, height: 16)
                Text(group.title).barlyText(.product.body, color: t.text2)
                Spacer()
                BarlyIcon("ellipsis", size: 14, color: t.text2)
                BarlyIcon("plus", size: 14, color: t.text2)
            }
            .padding(.horizontal, 12).frame(height: 36)
            if !group.children.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(group.children, id: \.self) { c in
                        Text(c).barlyText(.product.body, color: t.text2).frame(height: 36)
                    }
                }
                .padding(.leading, 50)
                .overlay(alignment: .leading) {
                    Line().stroke(t.borderStrong, style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                        .frame(width: 1).padding(.leading, 31).padding(.vertical, 6)
                }
            }
        }
    }
}

struct Line: Shape {
    func path(in r: CGRect) -> Path { var p = Path(); p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.midX, y: r.maxY)); return p }
}

/// 存储卡：弱底 r12，进度条 + 内嵌白按钮 + 强调色小圆点
public struct StorageCard: View {
    let title: String
    let value: Double
    let detail: String
    let cta: String
    @Environment(\.barly) private var t
    public init(title: String = "Cloud Storage", value: Double, detail: String, cta: String = "Upgrade Storage") {
        self.title = title; self.value = value; self.detail = detail; self.cta = cta
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).barlyText(.product.body.weight(500), color: t.text)
                Spacer()
                Text("\(Int(value * 100))%").barlyText(.product.caption, color: t.text2)
            }
            ProgressBar(value, height: 5)
            Text(detail).barlyText(.product.caption, color: t.text2)
            HStack {
                Text(cta).barlyText(.product.caption.weight(500), color: t.text)
                Spacer()
                Circle().fill(t.accent).frame(width: 14, height: 14)
                    .overlay(Image(systemName: "arrow.up").font(.system(size: 7, weight: .bold)).foregroundStyle(.white))
            }
            .padding(.horizontal, 10).frame(height: 32)
            .background(RoundedRectangle(cornerRadius: BarlyRadius.sm, style: .continuous).fill(t.isDark ? t.fill2 : t.surface))
            .padding(.top, 2)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: BarlyRadius.lg, style: .continuous).fill(t.isDark ? t.fill1 : t.bgSubtle.barlyMix(t.bgMuted, 0.5)))
    }
}

/// 用户卡：36 头像 + 姓名（认证章）+ 邮箱 + ›
public struct UserCard: View {
    let name: String
    let email: String
    @Environment(\.barly) private var t
    public init(name: String, email: String) { self.name = name; self.email = email }
    public var body: some View {
        HStack(spacing: 12) {
            Avatar(name, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(name).barlyText(.product.body.weight(500), color: t.text).lineLimit(1)
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 11)).foregroundStyle(t.text3)
                }
                Text(email).barlyText(.product.caption, color: t.text2).lineLimit(1)
            }
            Spacer(minLength: 4)
            BarlyIcon("chevron.right", size: 13, color: t.text2)
        }
    }
}

/// 整个 Brisk 式侧栏：logo 块 → 工作区切换 → 导航 → 分组 → Settings/Help → 存储卡 → 用户卡
public struct Sidebar: View {
    let brand: (String, String)
    let workspace: String
    let nav: [SidebarNavItem]
    let selection: String
    let groups: [SidebarGroup]
    let footer: [SidebarNavItem]
    let storage: (Double, String)?
    let user: (String, String)
    let storageLabels: (String, String)
    let onSelect: (String) -> Void
    @Environment(\.barly) private var t
    @Environment(\.barlyTitlebarInset) private var inset
    /// storageLabels = (卡片标题, 按钮文案)，中文界面传 ("云端空间", "扩容")
    public init(brand: (String, String), workspace: String, nav: [SidebarNavItem], selection: String,
                groups: [SidebarGroup] = [], footer: [SidebarNavItem] = [], storage: (Double, String)? = nil,
                storageLabels: (String, String) = ("Cloud Storage", "Upgrade Storage"),
                user: (String, String), onSelect: @escaping (String) -> Void = { _ in }) {
        self.brand = brand; self.workspace = workspace; self.nav = nav; self.selection = selection
        self.groups = groups; self.footer = footer; self.storage = storage; self.storageLabels = storageLabels
        self.user = user; self.onSelect = onSelect
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SidebarBrand(brand.0, subtitle: brand.1)
                .padding(.top, 20 + inset)
            WorkspaceSwitcher(workspace).padding(.top, 20)
            Hairline().padding(.vertical, 16)
            VStack(spacing: 8) {
                ForEach(nav) { n in
                    SidebarRow(icon: n.icon, title: n.title, selected: n.id == selection)
                        .onTapGesture { onSelect(n.id) }
                }
            }
            if !groups.isEmpty {
                Hairline().padding(.vertical, 16)
                VStack(alignment: .leading, spacing: 8) { ForEach(groups) { SidebarGroupView($0) } }
            }
            Spacer(minLength: 16)
            Hairline().padding(.bottom, 12)
            VStack(spacing: 6) {
                ForEach(footer) { f in SidebarRow(icon: f.icon, title: f.title, trailing: "chevron.right") }
            }
            if let storage { StorageCard(title: storageLabels.0, value: storage.0, detail: storage.1, cta: storageLabels.1).padding(.top, 14) }
            UserCard(name: user.0, email: user.1).padding(.top, 18).padding(.bottom, 20)
        }
        .padding(.horizontal, 20)
        .frame(width: BarlyMetrics.sidebar)
        .frame(maxHeight: .infinity)
        .background(t.isDark ? t.bg : t.surface)
        .overlay(alignment: .trailing) { Hairline(vertical: true) }
    }
}

// MARK: - 图标窄栏（Lumeo AI 对话型）

public struct IconRail: View {
    let items: [SidebarNavItem]
    let selection: String
    let footer: [String]
    let user: String
    let onSelect: (String) -> Void
    @Environment(\.barly) private var t
    @Environment(\.barlyTitlebarInset) private var inset
    public init(items: [SidebarNavItem], selection: String, footer: [String] = ["headphones", "gearshape"], user: String,
                onSelect: @escaping (String) -> Void = { _ in }) {
        self.items = items; self.selection = selection; self.footer = footer; self.user = user; self.onSelect = onSelect
    }
    public var body: some View {
        VStack(spacing: 0) {
            LogoMark(size: 40, circle: true).padding(.top, 24 + inset)
            VStack(spacing: 8) {
                ForEach(items) { i in
                    let on = i.id == selection
                    BarlyIcon(i.icon, size: 18, color: on ? t.accentText : t.text2)
                        .frame(width: 40, height: 40)
                        .background(RoundedRectangle(cornerRadius: BarlyRadius.sm, style: .continuous).fill(on ? t.softSurface : .clear))
                        .frame(maxWidth: .infinity)
                        .overlay(alignment: .leading) {
                            if on { UnevenRoundedRectangle(bottomTrailingRadius: 2, topTrailingRadius: 2).fill(t.accent).frame(width: 3, height: 24) }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(i.id) }
                }
            }
            .padding(.top, 36)
            Spacer()
            VStack(spacing: 18) {
                ForEach(footer, id: \.self) { BarlyIcon($0, size: 18, color: t.text2) }
            }
            Avatar(user, size: 32).padding(.top, 36).padding(.bottom, 24)
        }
        .frame(width: BarlyMetrics.rail)
        .frame(maxHeight: .infinity)
        .background(t.isDark ? t.bg : t.surface)
        .overlay(alignment: .trailing) { Hairline(vertical: true) }
    }
}

// MARK: - 顶栏 / 工具栏

/// 标题栏（64）：左页面标题 20/500，右侧 通知 · 搜索 · Share。
/// topnav 外壳下它是内容列里的页头：高 76、标题大一号、不画底线（导航和搜索已经在顶栏里）
public struct TitleBar<Trailing: View>: View {
    let title: String
    let trailing: Trailing
    @Environment(\.barly) private var t
    @Environment(\.barlyShell) private var shell
    public init(_ title: String, @ViewBuilder trailing: () -> Trailing) { self.title = title; self.trailing = trailing() }
    public var body: some View {
        let top = shell == "topnav"
        HStack(spacing: 12) {
            Text(title).barlyText(top ? FamilyType.pageTitle(BarlyTokens.Product.pageTitle.size(24)) : FamilyType.pageTitle(), color: t.text)
            Spacer()
            trailing
        }
        .padding(.horizontal, BarlyMetrics.contentPad)
        .padding(.top, top ? 12 : 0)
        .frame(height: top ? 76 : BarlyMetrics.titleBar)
        .overlay(alignment: .bottom) { if !top { Hairline() } }
    }
}

/// 工具栏（64）：[Ask AI] | 次按钮… …… ✓ Last updated now · 描边次按钮 · 近黑主按钮▾
public struct Toolbar<Leading: View, Trailing: View>: View {
    let leading: Leading
    let trailing: Trailing
    public init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading(); self.trailing = trailing()
    }
    public var body: some View {
        HStack(spacing: 10) {
            leading
            Spacer()
            trailing
        }
        .padding(.horizontal, BarlyMetrics.contentPad)
        .frame(height: BarlyMetrics.toolbar)
        .overlay(alignment: .bottom) { Hairline() }
    }
}

/// 工具栏里的 1px 竖分隔
public struct ToolbarDivider: View {
    @Environment(\.barly) private var t
    public init() {}
    public var body: some View { Rectangle().fill(t.hairline).frame(width: 1, height: 22).padding(.horizontal, 4) }
}

/// 「✓ Last updated now」成功色字，无底
public struct StatusNote: View {
    let text: String
    @Environment(\.barly) private var t
    public init(_ text: String = "Last updated now") { self.text = text }
    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark").font(.system(size: 12, weight: .medium))
            Text(text).barlyText(.product.body)
        }
        .foregroundStyle(t.success)
    }
}

/// 描边下拉（模型切换「✧ Lyra 2.1 ⌄」）
public struct DropdownButton: View {
    let title: String
    let icon: String?
    let size: BarlyButtonSize
    public init(_ title: String, icon: String? = nil, size: BarlyButtonSize = .md) { self.title = title; self.icon = icon; self.size = size }
    public var body: some View {
        BarlyButton(title, icon: icon, trailingIcon: "chevron.down", variant: .outline, size: size)
    }
}

// MARK: - macOS 自绘外壳

/// 整窗外壳：内容到顶、无系统标题栏；App 里配合 `.windowStyle(.hiddenTitleBar)` 使用
public struct MacShell<Side: View, Content: View>: View {
    let side: Side
    let content: Content
    @Environment(\.barly) private var t
    public init(@ViewBuilder side: () -> Side, @ViewBuilder content: () -> Content) { self.side = side(); self.content = content() }
    public var body: some View {
        HStack(spacing: 0) {
            side
            content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(t.bg)
        .ignoresSafeArea()
    }
}

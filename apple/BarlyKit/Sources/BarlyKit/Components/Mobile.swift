import SwiftUI

// MARK: - 顶栏

/// 「⚡ Get Plus」：强调色 tint 底 + 强调色字，r = Radius.sm，高 36（back = 左侧带返回箭头的变体）
public struct GetPlusPill: View {
    let title: String
    let back: Bool
    let action: () -> Void
    @Environment(\.barly) private var t
    public init(_ title: String = "Get Plus", back: Bool = false, action: @escaping () -> Void = {}) {
        self.title = title; self.back = back; self.action = action
    }
    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: BarlyRadius.sm, style: .continuous)
        Button(action: action) {
            HStack(spacing: 8) {
                if back { Image(systemName: "chevron.left").font(.system(size: 12, weight: .medium)) }
                Image(systemName: "bolt.fill").font(.system(size: 14))
                Text(title).barlyText(.mobile.headline.weight(500))
            }
            .foregroundStyle(t.accentText)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(shape.fill(t.accentSoft))
            .overlay(shape.strokeBorder(t.isDark ? t.accentText.opacity(0.18) : .clear, lineWidth: 1))
        }
        .buttonStyle(BarlyPressStyle())
    }
}

/// 移动顶栏 44pt：左 · 中 · 右三段，无标题、无分隔线、无毛玻璃
public struct MobileTopBar<L: View, C: View, R: View>: View {
    let leading: L, center: C, trailing: R
    public init(@ViewBuilder leading: () -> L, @ViewBuilder center: () -> C, @ViewBuilder trailing: () -> R) {
        self.leading = leading(); self.center = center(); self.trailing = trailing()
    }
    public var body: some View {
        ZStack {
            HStack { leading; Spacer(); trailing }
            center
        }
        .frame(height: BarlyMetrics.topBar)
        .padding(.horizontal, BarlyMetrics.pageX)
    }
}

public extension MobileTopBar where C == EmptyView {
    init(@ViewBuilder leading: () -> L, @ViewBuilder trailing: () -> R) {
        self.init(leading: leading, center: { EmptyView() }, trailing: trailing)
    }
}

/// 居中模型切换 pill「Lumix.AI ⌄」：L1 实色、r = Radius.lg、高 40
public struct ModelPill: View {
    let title: String
    @Environment(\.barly) private var t
    public init(_ title: String) { self.title = title }
    public var body: some View {
        HStack(spacing: 6) {
            Text(title).barlyText(.mobile.headline.size(17).weight(500), color: t.text)
            Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(t.text2)
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .background(RoundedRectangle(cornerRadius: BarlyRadius.lg, style: .continuous).fill(t.isDark ? t.fill1 : t.surface))
        .overlay(RoundedRectangle(cornerRadius: BarlyRadius.lg, style: .continuous).strokeBorder(t.isDark ? .clear : t.border, lineWidth: 1))
    }
}

// MARK: - 快捷 chip

public struct QuickChipItem: Identifiable, Sendable {
    public let id = UUID()
    public let icon: String?
    public let title: String
    public init(_ title: String, icon: String? = nil) { self.title = title; self.icon = icon }
}

public enum QuickChipStyle: Sendable {
    /// 白底 1px 描边、r = Radius.md、高 36（Bimbo）
    case outline
    /// L1 实色无边、r = Radius.sm、高 42（Lumix Services）
    case filled
}

/// 单个快捷 chip；colorIndex 给多色线性图标（深色下统一回灰，除非 forceColor）
public struct QuickChip: View {
    let item: QuickChipItem
    let colorIndex: Int?
    let style: QuickChipStyle
    let forceColor: Bool
    let iconColor: Color?
    let selected: Bool
    @Environment(\.barly) private var t
    /// selected：选中 = selectedBg 浅灰底 + selectedBorder 1px + 深字 500（不用实心黑 / 实心强调色，buttons.md §4）
    public init(_ item: QuickChipItem, colorIndex: Int? = nil, style: QuickChipStyle = .outline, forceColor: Bool = false, iconColor: Color? = nil, selected: Bool = false) {
        self.item = item; self.colorIndex = colorIndex; self.style = style; self.forceColor = forceColor; self.iconColor = iconColor; self.selected = selected
    }
    public var body: some View {
        let filled = style == .filled
        let r = filled ? BarlyRadius.sm : BarlyRadius.md
        let iconColor: Color = self.iconColor ?? {
            // 多色线性图标是 Barly 首页的招牌；其他风格族统一单色
            guard let i = colorIndex, BarlyFamily.current.isBarly else { return t.text2 }
            return t.chipIcon(i, force: forceColor)
        }()
        HStack(spacing: 8) {
            if let icon = item.icon { BarlyIcon(icon, size: filled ? 20 : 18, color: iconColor) }
            Text(item.title).barlyText((filled ? BarlyTokens.Mobile.body : BarlyTokens.Mobile.label).weight(selected ? 500 : 400), color: selected ? t.selectedFg : t.text2).lineLimit(1)
        }
        .padding(.leading, item.icon == nil ? 16 : 12)
        .padding(.trailing, filled ? 16 : 14)
        .frame(height: filled ? 42 : BarlyMetrics.chipH)
        .background(RoundedRectangle(cornerRadius: r, style: .continuous).fill(selected ? AnyShapeStyle(t.selectedBg) : filled ? AnyShapeStyle(LinearGradient(colors: [t.fill1, t.fill1.barlyMix(t.bg, 0.3)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(t.fieldBg)))
        .overlay(RoundedRectangle(cornerRadius: r, style: .continuous).strokeBorder(selected ? t.selectedBorder : filled ? .clear : t.fieldBorder, lineWidth: 1))
    }
}

/// 两行横滑 chip，右侧被屏幕裁切（暗示可滑）；第二行错位
public struct QuickChips: View {
    let rows: [[QuickChipItem]]
    let colored: Bool
    let style: QuickChipStyle
    let forceColor: Bool
    /// 选中的 chip（按行优先展平后的序号；nil = 都不选）
    let selected: Int?
    public init(_ rows: [[QuickChipItem]], colored: Bool = true, style: QuickChipStyle = .outline, forceColor: Bool = false, selected: Int? = nil) {
        self.rows = rows; self.colored = colored; self.style = style; self.forceColor = forceColor; self.selected = selected
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: BarlyMetrics.gap) {
            ForEach(Array(rows.enumerated()), id: \.offset) { r, row in
                BarlyScroll(.horizontal) {
                    HStack(spacing: BarlyMetrics.gap) {
                        ForEach(Array(row.enumerated()), id: \.offset) { i, item in
                            QuickChip(item, colorIndex: colored ? (r * 3 + i) : nil, style: style, forceColor: forceColor,
                                      selected: selected == rows.prefix(r).reduce(0) { $0 + $1.count } + i)
                        }
                    }
                    .padding(.horizontal, BarlyMetrics.pageX)
                }
                .frame(height: style == .filled ? 42 : BarlyMetrics.chipH)
            }
        }
    }
}

// MARK: - Lumix 首页零件

/// 起手卡：顶部 L1′ 渐隐进底色、无边框；第一张的 Generate = outline + 强调色字（卡内不放实心）
public struct StarterCard: View {
    let icon: String
    let title: String
    let detail: String
    let primary: Bool
    let width: CGFloat
    @Environment(\.barly) private var t
    public init(icon: String, title: String, detail: String, primary: Bool, width: CGFloat = 194) {
        self.icon = icon; self.title = title; self.detail = detail; self.primary = primary; self.width = width
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BarlyIcon(icon, size: 18, color: t.text)
            Text(title).barlyText(.mobile.headline, color: t.text).lineLimit(1).minimumScaleFactor(0.85).padding(.top, 14)
            Text(detail).barlyText(.mobile.micro.leading(16), color: t.text3).lineLimit(2).padding(.top, 6)
            Spacer(minLength: 16)
            BarlyButton("Generate", variant: primary ? .outlineAccent : .filled, size: .sm, fullWidth: true)   // 卡内按钮不实心（buttons.md §3）
        }
        .padding(.horizontal, 14).padding(.vertical, 16)
        .frame(width: width, height: 197, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: BarlyRadius.lg, style: .continuous)
                .fill(LinearGradient(colors: t.isDark ? [t.fill0, t.fill0.barlyMix(t.bg, 0.5), t.bg] : [t.softSurface, t.softSurface, t.bg],
                                     startPoint: .top, endPoint: .bottom))
        )
    }
}

/// 会话行：L1 实色 r = Radius.sm 高 42；气泡图标 + 单行截断标题 + 右侧时间
public struct ConversationRow: View {
    let title: String
    let time: String
    let filled: Bool
    @Environment(\.barly) private var t
    public init(_ title: String, time: String, filled: Bool = true) { self.title = title; self.time = time; self.filled = filled }
    public var body: some View {
        HStack(spacing: 10) {
            BarlyIcon("bubble.left", size: 16, color: t.text3)
            Text(title).barlyText(.mobile.body, color: t.text2).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 8)
            Text(time).barlyText(.mobile.caption, color: t.text3)
        }
        .padding(.horizontal, 16)
        .frame(height: 42)
        .background(RoundedRectangle(cornerRadius: BarlyRadius.sm, style: .continuous).fill(filled ? (t.isDark ? t.fill1 : t.softSurface) : .clear))
    }
}

// MARK: - 语音零件

/// 朗读高亮：已读主色、未读灰，句中切换
public struct ReadAloudText: View {
    let read: String
    let unread: String
    let style: BarlyTextStyle
    @Environment(\.barly) private var t
    public init(read: String, unread: String, style: BarlyTextStyle = BarlyTokens.Mobile.body.size(17).leading(26)) {
        self.read = read; self.unread = unread; self.style = style
    }
    public var body: some View {
        Text("\(Text(read).foregroundStyle(t.text))\(Text(unread).foregroundStyle(t.isDark ? t.text3 : t.text3.barlyMix(t.bg, 0.1)))")
            .barlyText(style)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 人声卡：r = Radius.xl，名字 24 Regular，属性 15 灰，底行 ‹ 分页点 ›
public struct VoiceCard: View {
    let name: String
    let traits: [String]
    let page: Int
    let pages: Int
    @Environment(\.barly) private var t
    public init(name: String, traits: [String], page: Int = 2, pages: Int = 4) {
        self.name = name; self.traits = traits; self.page = page; self.pages = pages
    }
    public var body: some View {
        VStack(spacing: 10) {
            Text(name).barlyText(.mobile.display, color: t.text)
            HStack(spacing: 24) {
                ForEach(traits, id: \.self) { Text($0).barlyText(.mobile.body, color: t.text2) }
            }
            HStack {
                BarlyIcon("chevron.left", size: 16, color: t.text2)
                Spacer()
                PageDots(count: pages, selected: page)
                Spacer()
                BarlyIcon("chevron.right", size: 16, color: t.text2)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: BarlyRadius.xl, style: .continuous)
                .fill(t.isDark ? AnyShapeStyle(LinearGradient(colors: [t.fill0.opacity(0.92), t.fill2.opacity(0.7)], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(t.surface))
                .shadow(color: .black.opacity(t.isDark ? 0 : 0.04), radius: 16, y: 4)
        )
        .overlay(RoundedRectangle(cornerRadius: BarlyRadius.xl, style: .continuous).strokeBorder(t.isDark ? t.litEdgeTop : t.border, lineWidth: 1))
    }
}

/// 语音底部三键：中间强调色实心圆 + 外圈光环，左右半透明圆
public struct VoiceControls: View {
    let main: CGFloat
    let halo: CGFloat
    let side: CGFloat
    let leftIcon: String
    let rightIcon: String
    @Environment(\.barly) private var t
    public init(main: CGFloat = 58, halo: CGFloat = 84, side: CGFloat = 48, leftIcon: String = "keyboard", rightIcon: String = "xmark") {
        self.main = main; self.halo = halo; self.side = side; self.leftIcon = leftIcon; self.rightIcon = rightIcon
    }
    public var body: some View {
        HStack {
            IconButton(leftIcon, size: side, style: t.isDark ? .glass : .circle, iconColor: t.isDark ? .white.opacity(0.9) : t.text2)
            Spacer()
            ZStack {
                Circle().fill(t.accent.opacity(t.isDark ? 0.26 : 0.2)).frame(width: halo, height: halo)
                Circle().strokeBorder(t.accent.opacity(0.35), lineWidth: 1).frame(width: halo, height: halo)
                Circle().fill(LinearGradient(colors: [t.accentGradientFrom, t.accentGradientTo], startPoint: .top, endPoint: .bottom))
                    .frame(width: main, height: main)
                Image(systemName: "mic").font(.system(size: 20, weight: .regular)).foregroundStyle(.white)
            }
            Spacer()
            IconButton(rightIcon, size: side, style: t.isDark ? .glass : .circle, iconColor: t.isDark ? .white.opacity(0.9) : t.text2)
        }
        .padding(.horizontal, 32)
    }
}

/// 权益行：强调色八芒闪光图标 + 15 Regular
public struct PerkRow: View {
    let text: String
    @Environment(\.barly) private var t
    public init(_ text: String) { self.text = text }
    public var body: some View {
        HStack(spacing: 12) {
            BarlyIcon("barly.sparkle", size: 19, color: t.accentText)
            Text(text).barlyText(.mobile.body, color: t.text)
        }
    }
}

/// 历史卡（浅色 hug 宽度 / 深色全宽）
public struct HistoryCard: View {
    let title: String
    let time: String
    @Environment(\.barly) private var t
    public init(_ title: String, time: String) { self.title = title; self.time = time }
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).barlyText(.mobile.body, color: t.text2).lineLimit(1)
            Text(time).barlyText(.mobile.caption, color: t.text3)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous).fill(t.isDark ? t.fill0 : t.bgMuted))
        .overlay(RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous).strokeBorder(t.isDark ? t.litEdgeTop : t.border, lineWidth: 1))
    }
}

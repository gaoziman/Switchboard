import SwiftUI

// dna v2 组件（references/dna.md §1.2 强度、§1.4 分类图标块 / 便签、§5 助手面板 / 工作区窄栏、§7 点阵图）。
// 和 Web 模板 src/barly/v2.tsx 一一对应，读同一套令牌（identity.mjs 生成的 navSelected* / tile1…6 / banner* / canvas / slot / chartEmpty）。
// 出处：推特作品 Enigma Traces（2026-10-16）、Rekann Dashboard（2026-09-28）、Autumn Insight（2026-07-15），取色见 evidence/x/era-4.md §2.0。

// MARK: - 文字样式小工具

public extension BarlyTextStyle {
    /// 等宽数字 / 代码（表格数字列、坐标轴刻度）
    static func monoText(_ size: CGFloat = 13, weight: Int = 400) -> BarlyTextStyle {
        BarlyTextStyle(size: size, lineHeight: 1.35, weight: weight, tracking: 0, upper: false, mono: true)
    }
}

// MARK: - 分类图标块

public extension BarlyPalette {
    /// 多色分类图标块的第 n 色（1…6）
    func tile(_ n: Int) -> Color {
        switch (n - 1) % 6 { case 0: tile1; case 1: tile2; case 2: tile3; case 3: tile4; case 4: tile5; default: tile6 }
    }
}

/// 一组并列类别的图标块（dna §1.4-5）。--icons multi：实心圆角方块（tile1…6）+ 白色线性图标（Rekann 待办 40 方块 r10）；
/// mono：描边方块 + 次级灰图标。只用在「一组并列的类别」上，不用在导航和按钮上。
public struct IconTile: View {
    let icon: String
    let tone: Int
    let size: CGFloat
    let multi: Bool
    let iconColor: Color?
    @Environment(\.barly) private var t
    public init(_ icon: String, tone: Int = 1, size: CGFloat = 40, multi: Bool = BarlyTokens.Style.multiIcons, iconColor: Color? = nil) {
        self.icon = icon; self.tone = tone; self.size = size; self.multi = multi; self.iconColor = iconColor
    }
    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
        BarlyIcon(icon, size: size * 0.45, color: iconColor ?? (multi ? .white : t.text2))
            .frame(width: size, height: size)
            .background(shape.fill(multi ? t.tile(tone) : t.surface))
            .overlay(multi ? nil : shape.strokeBorder(t.border, lineWidth: 1))
    }
}

// MARK: - 工作区窄栏 + 分组标题

/// --shell rail-sidebar 的工作区窄栏（Enigma：64 宽，顶部产品 logo 方块，每个工作区一个 40 方块，选中项外加 2px 强调色环）。
public struct WorkspaceRail: View {
    public struct Item: Identifiable, Sendable {
        public let id: String, icon: String, tone: Int
        public init(_ id: String, icon: String, tone: Int) { self.id = id; self.icon = icon; self.tone = tone }
    }
    let logo: String
    let items: [Item]
    let active: String?
    let bottom: [String]
    let width: CGFloat
    @Environment(\.barly) private var t
    @Environment(\.barlyTitlebarInset) private var inset
    public init(logo: String, items: [Item], active: String? = nil, bottom: [String] = [], width: CGFloat = 64) {
        self.logo = logo; self.items = items; self.active = active; self.bottom = bottom; self.width = width
    }
    public var body: some View {
        VStack(spacing: 12) {
            BarlyIcon(logo, size: 20, color: t.bg)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(t.text))
                .padding(.bottom, 6)
            ForEach(items) { it in
                IconTile(it.icon, tone: it.tone, size: 40, multi: true)
                    .padding(3)
                    .overlay(it.id == active ? RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(t.accent, lineWidth: 2) : nil)
            }
            Spacer(minLength: 0)
            VStack(spacing: 16) { ForEach(bottom, id: \.self) { BarlyIcon($0, size: 18, color: t.text2) } }
        }
        .padding(.top, 12 + inset)
        .padding(.bottom, 14)
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .background(t.sidebarBg)
        .overlay(alignment: .trailing) { Rectangle().fill(t.border).frame(width: 1) }
    }
}

/// 侧栏分组标题：mono 大写小标签（OVERVIEW / MANAGE / MONITOR）。
public struct NavGroupLabel: View {
    let text: String
    @Environment(\.barly) private var t
    public init(_ text: String) { self.text = text }
    public var body: some View {
        Text(text).barlyText(.product.label, color: t.text3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.top, 20).padding(.bottom, 6)
    }
}

/// 侧栏一行（v2）：选中态读 navSelected 令牌——克制 = 中性灰块；--intensity full 的深色 = 强调色暗 tint 横向渐变（Enigma）。
public struct NavRowV2: View {
    let icon: String
    let title: String
    let selected: Bool
    let trailing: AnyView?
    @Environment(\.barly) private var t
    public init(_ title: String, icon: String, selected: Bool = false, trailing: AnyView? = nil) {
        self.title = title; self.icon = icon; self.selected = selected; self.trailing = trailing
    }
    public var body: some View {
        HStack(spacing: 11) {
            BarlyIcon(icon, size: 16, color: selected ? t.navSelectedFg : t.text2)
            Text(title).barlyText(selected ? .product.body.weight(500) : .product.body, color: selected ? t.navSelectedFg : t.text2)
            Spacer(minLength: 0)
            if let trailing { trailing }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(selected ? RoundedRectangle(cornerRadius: 8, style: .continuous).fill(LinearGradient(colors: [t.navSelectedFrom, t.navSelectedTo], startPoint: .leading, endPoint: .trailing)) : nil)
        .contentShape(Rectangle())
    }
}

// MARK: - 提示横幅

/// 提示横幅（dna §1.2）：--intensity full = 强调色极淡底 + 1px 强调色描边 + 一句强调色引导语（Enigma）；克制 = 中性弱底 + 发丝线。
public struct BarlyBanner<Actions: View>: View {
    let lead: String?
    let text: String
    let actions: Actions
    @Environment(\.barly) private var t
    public init(lead: String? = nil, _ text: String, @ViewBuilder actions: () -> Actions = { EmptyView() }) {
        self.lead = lead; self.text = text; self.actions = actions()
    }
    public var body: some View {
        HStack(spacing: 12) {
            (Text(lead.map { $0 + " " } ?? "").foregroundColor(t.bannerFg).fontWeight(.medium) + Text(text).foregroundColor(t.text2))
                .barlyText(.product.body)
                .lineLimit(1)
            Spacer(minLength: 8)
            actions
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(t.bannerBg))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(t.bannerBorder, lineWidth: 1))
    }
}

// MARK: - 图表：点阵 / 双柱 / 迷你柱 / 图例

/// 方块点阵柱图（dna §7 dots；Enigma Traces、Autumn）：每列一串 r2 小方块，自下而上；柱身 = 暗一级强调色，柱顶 peak 格 = 强调色本色，空格 chartEmpty。
public struct DotMatrix: View {
    let values: [Double]
    let rows: Int
    let cell: CGFloat
    let gap: CGFloat
    let peak: Int
    let yTicks: [String]
    let xLabels: (String, String)?
    @Environment(\.barly) private var t
    public init(values: [Double], rows: Int = 14, cell: CGFloat = 9, gap: CGFloat = 4.5, peak: Int = 2, yTicks: [String] = [], xLabels: (String, String)? = nil) {
        self.values = values; self.rows = rows; self.cell = cell; self.gap = gap; self.peak = peak; self.yTicks = yTicks; self.xLabels = xLabels
    }
    public var body: some View {
        let h = CGFloat(rows) * cell + CGFloat(rows - 1) * gap
        let body = t.accent.barlyMix(t.chartEmpty, 0.38)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                if !yTicks.isEmpty {
                    VStack(alignment: .trailing) {
                        ForEach(Array(yTicks.enumerated()), id: \.offset) { i, s in
                            Text(s).barlyText(.monoText(11), color: t.text3)
                            if i < yTicks.count - 1 { Spacer(minLength: 0) }
                        }
                    }.frame(height: h)
                }
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                        let n = Int((max(0, min(1, v)) * Double(rows)).rounded())
                        VStack(spacing: gap) {
                            ForEach((0..<rows).reversed(), id: \.self) { r in
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(r < n ? (r >= n - peak ? t.accent : body) : t.chartEmpty)
                                    .frame(width: cell, height: cell)
                            }
                        }
                        if i < values.count - 1 { Spacer(minLength: 0) }
                    }
                }
                .frame(height: h)
            }
            if let xLabels {
                HStack { Text(xLabels.0); Spacer(); Text(xLabels.1) }
                    .barlyText(.product.caption, color: t.text3)
                    .padding(.leading, yTicks.isEmpty ? 0 : 50)
            }
        }
    }
}

/// 双序列细柱（Enigma Latency P50 / P99）：强调色 + 浅灰，第二序列永远用灰（dna §0-1），背后一根暗轨道。
public struct PairedBars: View {
    let pairs: [(Double, Double)]
    let maxValue: Double
    let height: CGFloat
    let yTicks: [String]
    let xLabels: (String, String)?
    @Environment(\.barly) private var t
    public init(pairs: [(Double, Double)], max: Double, height: CGFloat = 160, yTicks: [String] = [], xLabels: (String, String)? = nil) {
        self.pairs = pairs; self.maxValue = max; self.height = height; self.yTicks = yTicks; self.xLabels = xLabels
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                if !yTicks.isEmpty {
                    VStack(alignment: .leading) {
                        ForEach(Array(yTicks.enumerated()), id: \.offset) { i, s in
                            Text(s).barlyText(.monoText(11), color: t.text3)
                            if i < yTicks.count - 1 { Spacer(minLength: 0) }
                        }
                    }.frame(height: height)
                }
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(Array(pairs.enumerated()), id: \.offset) { i, p in
                        HStack(alignment: .bottom, spacing: 5) {
                            bar(p.0, color: t.accent)
                            bar(p.1, color: t.text.barlyMix(t.bg, 0.22))
                        }
                        if i < pairs.count - 1 { Spacer(minLength: 0) }
                    }
                }.frame(height: height)
            }
            if let xLabels {
                HStack { Text(xLabels.0); Spacer(); Text(xLabels.1) }
                    .barlyText(.product.caption, color: t.text3)
                    .padding(.leading, yTicks.isEmpty ? 0 : 30)
            }
        }
    }
    private func bar(_ v: Double, color: Color) -> some View {
        ZStack(alignment: .bottom) {
            Capsule().fill(t.chartEmpty)
            Capsule().fill(color).frame(height: height * CGFloat(min(1, v / maxValue)))
        }.frame(width: 5, height: height)
    }
}

/// 表格行内迷你柱（Enigma Vol (30d) 列）：灰色细柱，不用强调色。
public struct MiniBars: View {
    let values: [Double]
    let width: CGFloat
    let height: CGFloat
    @Environment(\.barly) private var t
    public init(_ values: [Double], width: CGFloat = 112, height: CGFloat = 22) { self.values = values; self.width = width; self.height = height }
    public var body: some View {
        let mx = values.max() ?? 1
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                RoundedRectangle(cornerRadius: 1).fill(t.text.barlyMix(t.bg, 0.45))
                    .frame(width: 3, height: max(height * 0.14, height * CGFloat(v / mx)))
                if i < values.count - 1 { Spacer(minLength: 0) }
            }
        }.frame(width: width, height: height, alignment: .bottom)
    }
}

/// 图例圆点（P50 ● P99 ●）。
public struct DotLegend: View {
    let items: [(String, Color)]
    @Environment(\.barly) private var t
    public init(_ items: [(String, Color)]) { self.items = items }
    public var body: some View {
        HStack(spacing: 18) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                HStack(spacing: 7) { Circle().fill(it.1).frame(width: 7, height: 7); Text(it.0).barlyText(.monoText(12), color: t.text2) }
            }
        }
    }
}

// MARK: - 便签

/// 便签卡（dna §1.4-7；Rekann）：柔和黄底 + 深一档黄边，右下近黑小方块「+」。一屏最多一张。
public struct StickyNote: View {
    let placeholder: String
    @Environment(\.barly) private var t
    public init(_ placeholder: String = "Write your personal notes…") { self.placeholder = placeholder }
    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        ZStack(alignment: .topLeading) {
            shape.fill(t.isDark ? Color(hex: 0x3A3220) : Color(hex: 0xFFE8A4))
            Text(placeholder).barlyText(.product.body.size(16), color: t.isDark ? Color(hex: 0xA89A72) : Color(hex: 0x8A7A4E)).padding(22)
            BarlyIcon("plus", size: 14, color: .white)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(t.ink))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(18)
        }
        .overlay(shape.strokeBorder(t.isDark ? Color(hex: 0x4A3F24) : Color(hex: 0xFEDA79), lineWidth: 1))
    }
}

// MARK: - AI 助手面板 / 草稿卡 / 过程行

/// 右侧 AI 助手面板（dna §5；Rekann、Asphalt）：放在助手槽（slot）里的白卡 r16，顶栏「标题 ⤢ ▣」+ 对话流 + 底部输入框 + 免责小字。
public struct AssistantPanel<Content: View, Composer: View>: View {
    let title: String
    let width: CGFloat
    let footnote: String?
    let content: Content
    let composer: Composer
    @Environment(\.barly) private var t
    public init(title: String = "Assistant", width: CGFloat = 420, footnote: String? = nil, @ViewBuilder content: () -> Content, @ViewBuilder composer: () -> Composer) {
        self.title = title; self.width = width; self.footnote = footnote; self.content = content(); self.composer = composer()
    }
    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(title).barlyText(.product.body.weight(500), color: t.text)
                Spacer()
                BarlyIcon("arrow.up.left.and.arrow.down.right", size: 14, color: t.text2)
                BarlyIcon("sidebar.right", size: 15, color: t.text2)
            }
            .padding(.horizontal, 18).frame(height: 52)
            Rectangle().fill(t.border).frame(height: 1)
            VStack(alignment: .leading, spacing: 16) { content }
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            composer.padding(.horizontal, 14)
            if let footnote { Text(footnote).barlyText(.product.caption, color: t.text3).padding(.vertical, 10) }
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(t.surface))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(t.border, lineWidth: 1))
        .padding(12)
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .background(t.slot)
    }
}

/// AI 生成的结构化草稿卡（Rekann「Maternity leave (draft)」）：标题 + 灰说明 → 发丝线 → 两列字段表 → 警示条 → 发丝线 → 一个按钮。
public struct DraftCard<Action: View>: View {
    let title: String
    let description: String?
    let rows: [(String, String)]
    let note: String?
    let action: Action
    @Environment(\.barly) private var t
    public init(title: String, description: String? = nil, rows: [(String, String)], note: String? = nil, @ViewBuilder action: () -> Action = { EmptyView() }) {
        self.title = title; self.description = description; self.rows = rows; self.note = note; self.action = action()
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).barlyText(.product.body.weight(500), color: t.text)
            if let description { Text(description).barlyText(.product.small, color: t.text2).padding(.top, 5) }
            Rectangle().fill(t.border).frame(height: 1).padding(.vertical, 14)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 11) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                    GridRow {
                        Text(r.0).barlyText(.product.small, color: t.text2).frame(width: 96, alignment: .leading)
                        Text(r.1).barlyText(.product.small, color: t.text)
                    }
                }
            }
            if let note {
                Text(note).barlyText(.product.small, color: t.warningFg)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(t.warningSoft))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(t.warning.opacity(0.35), lineWidth: 1))
                    .padding(.top, 14)
            }
            Rectangle().fill(t.border).frame(height: 1).padding(.vertical, 14)
            action
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(t.surface))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(t.border, lineWidth: 1))
    }
}

/// 「Worked for 15 seconds」过程行：小图标 + 灰字。
public struct WorkedFor: View {
    let icon: String
    let text: String
    @Environment(\.barly) private var t
    public init(_ text: String, icon: String = "lightbulb") { self.text = text; self.icon = icon }
    public var body: some View {
        HStack(spacing: 8) { BarlyIcon(icon, size: 15, color: t.text2); Text(text).barlyText(.product.body, color: t.text2) }
    }
}

/// 渐变圆球头像（Rekann 占位头像：桃、紫、橙渐变小球）。
public struct OrbAvatar: View {
    let hue: Double
    let size: CGFloat
    public init(hue: Double, size: CGFloat = 34) { self.hue = hue; self.size = size }
    public var body: some View {
        Circle()
            .fill(RadialGradient(colors: [Color(hue: hue / 360, saturation: 0.08, brightness: 1),
                                          Color(hue: hue / 360, saturation: 0.45, brightness: 0.98),
                                          Color(hue: (hue + 20) / 360, saturation: 0.7, brightness: 0.82)],
                                 center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.75))
            .frame(width: size, height: size)
    }
}

import SwiftUI

// MARK: - 按钮

public enum BarlyButtonVariant: Sendable {
    /// 转化：购买 / 预约 / 发布 / 发送 / 订阅 / 注册 / 营销主 CTA —— 强调色（flood 是前景色），按 ctaFx 渐变 / 光晕（references/buttons.md）
    case cta
    /// 主操作：读身份的 primary —— 工具品类（crm / analytics / devtool / agent / admin / console…）= 带色相近黑，其余 = 强调色，深色主题 = 强调色
    case primary
    /// 带色相近黑：只在工具品类里替代 primary；竖向渐变 + 顶部 1px 内高光，不平涂
    case ink
    /// 白底 1px 深一级边（次要：聊一聊、查看、取消、行内「下一步」）
    case outline
    /// outline + 强调色字：卡 / 行内需要提示「下一步」时用，代替实心（buttons.md §3）
    case outlineAccent
    /// 无底无边（分享、更多、列表内文字操作）
    case ghost
    /// 深色下的 L2 实心灰（Lumix「Generate」次按钮、Copy/Edit）
    case filled
    /// 危险：描边红字（确认弹窗里才用实心红：`.dangerSolid`）
    case danger
    case dangerSolid
    /// 旧名，等于 .cta（新代码写 .cta）
    case accent
}

public enum BarlyButtonSize: Sendable {
    /// 30 / 13pt（卡内小按钮、表格工具）
    case sm
    /// 36 / 14pt（后台默认：Brisk）
    case md
    /// 44 / 15pt（AI 对话型桌面顶栏、Composer 内：Lumeo）
    case lg
    /// 47 / 16pt（移动端全宽主 CTA：Lumix New Chat）
    case xl
    var height: CGFloat { switch self { case .sm: 30; case .md: 36; case .lg: 44; case .xl: 47 } }
    var padX: CGFloat { switch self { case .sm: 12; case .md: 14; case .lg: 16; case .xl: 18 } }
    var text: BarlyTextStyle {
        switch self {
        case .sm: BarlyTokens.Product.small.weight(500)
        case .md: BarlyTokens.Product.body.weight(500)
        case .lg: BarlyTokens.Product.body.size(15).weight(500)
        case .xl: BarlyTokens.Mobile.headline.weight(500)
        }
    }
    var radius: CGFloat { self == .sm ? BarlyRadius.sm : BarlyRadius.md }
}

/// 主按钮质感：flat 平涂 / gradient 竖向 1–2 级渐变 + 顶部 1px 高光 / glow 渐变 + 同色光晕
public enum BarlyCTAFx: String, Sendable {
    case flat, gradient, glow
    public static var identity: BarlyCTAFx { BarlyCTAFx(rawValue: BarlyTokens.ctaFx) ?? .flat }
}

public struct BarlyButton: View {
    let title: String
    let icon: String?
    let trailingIcon: String?
    let variant: BarlyButtonVariant
    let size: BarlyButtonSize
    let fx: BarlyCTAFx
    let fullWidth: Bool
    let split: Bool
    let action: () -> Void
    @Environment(\.barly) private var t

    public init(_ title: String, icon: String? = nil, trailingIcon: String? = nil,
                variant: BarlyButtonVariant = .outline, size: BarlyButtonSize = .md,
                fx: BarlyCTAFx = .identity, fullWidth: Bool = false, split: Bool = false,
                action: @escaping () -> Void = {}) {
        self.title = title; self.icon = icon; self.trailingIcon = trailingIcon
        self.variant = variant; self.size = size; self.fx = fx
        self.fullWidth = fullWidth; self.split = split; self.action = action
    }

    /// 实际画法：accent 系（强调色渐变）/ ink 系（近黑渐变）/ 其他
    private enum Paint { case accentLike(Color, Color), inkLike(Color, Color), solid(Color, Color), outline, ghost, filled, danger, dangerSolid }

    private var paint: Paint {
        switch variant {
        case .cta, .accent:
            // flood：cta 令牌已经是前景色（整屏就是强调色）
            if t.cta == t.accent { return .accentLike(t.cta, t.ctaFg) }
            if t.cta == t.ink { return .inkLike(t.ink, t.inkFg) }
            return .solid(t.cta, t.ctaFg)
        case .primary:
            if t.primary == t.accent { return .accentLike(t.primary, t.primaryFg) }
            if t.primary == t.ink { return .inkLike(t.ink, t.inkFg) }
            return .solid(t.primary, t.primaryFg)
        case .ink: return .inkLike(t.ink, t.inkFg)
        case .outline, .outlineAccent: return .outline
        case .ghost: return .ghost
        case .filled: return .filled
        case .danger: return .danger
        case .dangerSolid: return .dangerSolid
        }
    }

    private var isSolid: Bool {
        switch paint { case .accentLike, .inkLike, .solid, .dangerSolid: true; default: false }
    }

    private var fg: Color {
        switch paint {
        case .accentLike(_, let f), .inkLike(_, let f), .solid(_, let f): f
        case .outline, .filled: variant == .outlineAccent ? t.accentText : t.text
        case .ghost: t.text2
        case .danger: t.danger
        case .dangerSolid: .white
        }
    }

    private var fam: BarlyFamily { .current }
    /// soft 的实心主按钮是胶囊；其余产品内按钮矩形（圆角已按风格族收紧）
    private var radius: CGFloat { fam.pillButtons && isSolid ? size.height / 2 : size.radius }
    /// brutal / press：按钮字大写（press 用 mono 小字）
    private var labelStyle: BarlyTextStyle {
        switch fam {
        case .brutal: size.text.uppercased.tracked(0.02).weight(600)
        case .press: size.text.size(size.text.size - 2).monospaced.uppercased.tracked(0.12)
        default: size.text
        }
    }

    @ViewBuilder private var fill: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        switch paint {
        case .accentLike(let c, _):
            if fx == .flat || fam == .brutal {
                shape.fill(c)
            } else {
                shape.fill(LinearGradient(colors: [t.accentGradientFrom, t.accentGradientTo], startPoint: .top, endPoint: .bottom))
                    .overlay(shape.inset(by: 0.5).stroke(LinearGradient(colors: [.white.opacity(0.24), .clear], startPoint: .top, endPoint: .center), lineWidth: 1))
                    .shadow(color: fx == .glow ? t.accentGlow : .clear, radius: 14, y: 6)
            }
        case .inkLike:
            if fam == .brutal {
                // brutal：纯黑实心是身份的一部分
                shape.fill(t.ink)
            } else {
                // 带色相近黑：竖向渐变（上浅下深）+ 顶部 1px 内高光（Finnie / Brisk Exports）
                shape.fill(LinearGradient(colors: [t.inkGradientFrom, t.inkGradientTo], startPoint: .top, endPoint: .bottom))
                    .overlay(shape.inset(by: 0.5).stroke(LinearGradient(colors: [t.inkEdge, .clear], startPoint: .top, endPoint: .center), lineWidth: 1))
            }
        case .solid(let c, _):
            shape.fill(c)
        case .outline:
            if fam.isBarly {
                shape.fill(t.isDark ? t.fill1 : t.surface)
                    .overlay(shape.strokeBorder(t.isDark ? t.fieldBorder : t.borderStrong, lineWidth: 1))
            } else {
                // 风格族：透明底 + 线框（brutal 2px 主文字色；press / flood 主文字色发丝线）
                shape.fill(Color.clear)
                    .overlay(shape.strokeBorder([.brutal, .press, .flood].contains(fam) ? t.text : t.borderStrong, lineWidth: fam.stroke))
            }
        case .filled:
            shape.fill(t.fill2)
        case .ghost:
            Color.clear
        case .danger:
            shape.fill(Color.clear).overlay(shape.strokeBorder(t.danger.opacity(0.55), lineWidth: 1))
        case .dangerSolid:
            shape.fill(t.danger)
        }
    }

    private var quietIcon: Bool { variant == .outline }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { BarlyIcon(icon, size: 16, color: quietIcon ? t.text2 : fg) }
                Text(title).barlyText(labelStyle, color: fg).lineLimit(1)
                if let trailingIcon { BarlyIcon(trailingIcon, size: 14, color: quietIcon ? t.text3 : fg.opacity(0.8)) }
                if split {
                    Rectangle().fill(fg.opacity(0.25)).frame(width: 1, height: size.height * 0.5).padding(.leading, 4)
                    BarlyIcon("chevron.down", size: 14, color: fg)
                }
            }
            .padding(.horizontal, size.padX)
            .frame(height: size.height)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(fill)
            .contentShape(Rectangle())
        }
        .buttonStyle(BarlyPressStyle())
    }
}

/// 按下变暗一点，不做缩放弹跳
public struct BarlyPressStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.82 : 1)
    }
}

/// 唯一的 AI 入口：竖向强调色渐变 + 深一级 1px 边 + 底部极淡投影（Brisk「Ask AI」）
public struct AskAIButton: View {
    let title: String
    let height: CGFloat
    let action: () -> Void
    @Environment(\.barly) private var t
    public init(_ title: String = "Ask AI", height: CGFloat = 34, action: @escaping () -> Void = {}) {
        self.title = title; self.height = height; self.action = action
    }
    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous)
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles").font(.system(size: 13, weight: .medium))
                Text(title).barlyText(.product.body.weight(500))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 13)
            .frame(height: height)
            .background(
                shape.fill(LinearGradient(colors: [t.accent.barlyMix(.black, 0.18), t.accent.barlyShift(light: 0.06)], startPoint: .top, endPoint: .bottom))
                    .overlay(shape.strokeBorder(t.accent.barlyMix(.black, 0.3), lineWidth: 1))
                    .overlay(shape.inset(by: 1).strokeBorder(LinearGradient(colors: [.white.opacity(0.18), .clear], startPoint: .top, endPoint: .center), lineWidth: 1))
                    .shadow(color: t.accent.opacity(0.28), radius: 1.5, y: 1.5)
            )
        }
        .buttonStyle(BarlyPressStyle())
    }
}

public enum BarlyIconButtonStyle: Sendable { case outline, filled, ghost, circle, glass }

/// 方形图标钮（桌面 36 / 移动 38），描边 / L1 实心 / 无底 / 正圆
public struct IconButton: View {
    let icon: String
    let size: CGFloat
    let style: BarlyIconButtonStyle
    let iconColor: Color?
    let badge: Bool
    let action: () -> Void
    @Environment(\.barly) private var t
    public init(_ icon: String, size: CGFloat = 36, style: BarlyIconButtonStyle = .outline, iconColor: Color? = nil, badge: Bool = false, action: @escaping () -> Void = {}) {
        self.icon = icon; self.size = size; self.style = style; self.iconColor = iconColor; self.badge = badge; self.action = action
    }
    public var body: some View {
        Button(action: action) {
            ZStack {
                switch style {
                case .outline:
                    RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous).fill(t.fieldBg)
                        .overlay(RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous).strokeBorder(t.fieldBorder, lineWidth: 1))
                case .filled:
                    RoundedRectangle(cornerRadius: BarlyRadius.sm, style: .continuous).fill(t.fill1)
                case .ghost:
                    Color.clear
                case .circle:
                    Circle().fill(t.isDark ? t.fill1 : t.surface)
                case .glass:
                    Circle().fill(Color.white.opacity(0.18))
                }
                BarlyIcon(icon, size: size >= 44 ? 18 : 16, color: iconColor ?? (style == .glass ? .white : t.text2))
            }
            .frame(width: size, height: size)
            .overlay(alignment: .topTrailing) {
                if badge { Circle().fill(t.danger).frame(width: 6, height: 6).offset(x: -9, y: 9) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(BarlyPressStyle())
    }
}

// MARK: - Chip / 涨跌徽标 / 小标签

public enum BarlyTone: Sendable { case neutral, success, danger, warning, info, accent }

extension BarlyPalette {
    func toneColors(_ tone: BarlyTone) -> (bg: Color, fg: Color) {
        switch tone {
        case .neutral: (isDark ? fill2 : bgMuted, text2)
        case .success: (successSoft, successFg)
        case .danger: (dangerSoft, dangerFg)
        case .warning: (warningSoft, warningFg)
        case .info: (infoSoft, infoFg)
        case .accent: (accentSoft, accentSoftFg)
        }
    }
}

/// 语义 chip：浅底 + 同色相深字，6px 小圆角（不是胶囊）；mono = 看板阶段写法
public struct Chip: View {
    let text: String
    let tone: BarlyTone
    let mono: Bool
    let dot: Bool
    @Environment(\.barly) private var t
    public init(_ text: String, tone: BarlyTone = .neutral, mono: Bool = false, dot: Bool = false) {
        self.text = text; self.tone = tone; self.mono = mono; self.dot = dot
    }
    public var body: some View {
        let c = t.toneColors(tone)
        HStack(spacing: 5) {
            if dot { Circle().fill(c.fg).frame(width: 5, height: 5) }
            Text(text).barlyText(mono ? .product.label : .product.small.weight(500), color: c.fg).lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(RoundedRectangle(cornerRadius: BarlyRadius.xs, style: .continuous).fill(c.bg))
    }
}

/// KPI 涨跌：唯一用胶囊的 chip，▲▼ 实心小三角，比表格 chip 饱和一档
public struct DeltaBadge: View {
    let value: String
    let up: Bool
    @Environment(\.barly) private var t
    public init(_ value: String, up: Bool = true) { self.value = value; self.up = up }
    public var body: some View {
        let bg = up ? t.successSoft.barlyMix(t.success, t.isDark ? 0.1 : 0.16) : t.dangerSoft.barlyMix(t.danger, t.isDark ? 0.1 : 0.2)
        let fg = up ? t.successFg : t.dangerFg
        HStack(spacing: 3) {
            Image(systemName: up ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill").font(.system(size: 6.5))
            Text(value).barlyText(.product.caption.weight(500))
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 7)
        .frame(height: 20)
        .background(Capsule().fill(bg))
    }
}

/// mono 大写小标签（FEATURES / GET STARTED…）
public struct MonoLabel: View {
    let text: String
    let color: Color?
    let mono: Bool
    @Environment(\.barly) private var t
    public init(_ text: String, color: Color? = nil, mono: Bool = true) { self.text = text; self.color = color; self.mono = mono }
    public var body: some View {
        // 含中文：dna.md §2「mono 小标签改 12px 中文 + 0.04em」（Web / 小程序已这样处理），不用等宽、不加宽字距
        if BarlyCJK.contains(text) {
            Text(text).barlyText(.product.caption.weight(500).tracked(0.04), color: color ?? t.text2)
        } else {
            Text(text).barlyText(mono ? FamilyType.label(BarlyTokens.Product.label) : .product.caption.weight(500).tracked(0.06).uppercased, color: color ?? t.text2)
        }
    }
}

// MARK: - 输入框

/// 单行输入框：浅色 = 白 + 1px 边，深色 = L1 实色。快照模式下渲染成静态文字。
public struct BarlyTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String?
    let height: CGFloat
    let style: BarlyTextStyle
    let trailing: AnyView?
    @Environment(\.barly) private var t
    @Environment(\.barlySnapshot) private var snapshot

    public init(_ placeholder: String, text: Binding<String>, icon: String? = nil, height: CGFloat = 36,
                style: BarlyTextStyle = BarlyTokens.Product.body, trailing: AnyView? = nil) {
        self.placeholder = placeholder; self._text = text; self.icon = icon
        self.height = height; self.style = style; self.trailing = trailing
    }

    public var body: some View {
        HStack(spacing: 8) {
            if let icon { BarlyIcon(icon, size: 16, color: t.text3) }
            BarlyBareField(placeholder: placeholder, text: $text, style: style)
            if let trailing { trailing }
        }
        .padding(.horizontal, 12)
        .frame(height: height)
        .background(RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous).fill(t.fieldBg))
        .overlay(RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous).strokeBorder(t.fieldBorder, lineWidth: 1))
    }
}

/// 无外框的文字输入（Composer 内部用）；快照模式下换成 Text
public struct BarlyBareField: View {
    let placeholder: String
    @Binding var text: String
    let style: BarlyTextStyle
    let axis: Axis
    @Environment(\.barly) private var t
    @Environment(\.barlySnapshot) private var snapshot
    public init(placeholder: String, text: Binding<String>, style: BarlyTextStyle, axis: Axis = .horizontal) {
        self.placeholder = placeholder; self._text = text; self.style = style; self.axis = axis
    }
    public var body: some View {
        if snapshot {
            Text(text.isEmpty ? placeholder : text)
                .barlyText(style, color: text.isEmpty ? t.text3 : t.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(t.text3), axis: axis)
                .textFieldStyle(.plain)
                .barlyText(style, color: t.text)
                .tint(t.accent)
        }
    }
}

/// 搜索框：放大镜 + 占位；可带 ⌘K 键帽
public struct SearchField: View {
    let placeholder: String
    @Binding var text: String
    let shortcut: String?
    let width: CGFloat?
    @Environment(\.barly) private var t
    public init(_ placeholder: String = "Search", text: Binding<String>, shortcut: String? = nil, width: CGFloat? = nil) {
        self.placeholder = placeholder; self._text = text; self.shortcut = shortcut; self.width = width
    }
    public var body: some View {
        BarlyTextField(placeholder, text: $text, icon: "magnifyingglass", height: 36,
                       trailing: shortcut.map { s in
                           AnyView(Text(s).barlyText(.product.caption.weight(500), color: t.text3)
                               .padding(.horizontal, 6).frame(height: 20)
                               .background(RoundedRectangle(cornerRadius: BarlyRadius.xs).fill(t.fill2)))
                       })
            .frame(width: width)
    }
}

// MARK: - 分段控件 / 开关

/// 槽 = 浅灰，选中段 = 白底 + 1px 边 + 主文字；未选 = 三级灰
public struct Segmented: View {
    let options: [String]
    @Binding var selection: Int
    let height: CGFloat
    let style: BarlyTextStyle
    let fullWidth: Bool
    @Environment(\.barly) private var t
    public init(_ options: [String], selection: Binding<Int>, height: CGFloat = 36,
                style: BarlyTextStyle = BarlyTokens.Product.small, fullWidth: Bool = false) {
        self.options = options; self._selection = selection; self.height = height; self.style = style; self.fullWidth = fullWidth
    }
    public var body: some View {
        let pad: CGFloat = height >= 40 ? 3.5 : 4
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { i, o in
                let on = i == selection
                Button { selection = i } label: {
                    Text(o).barlyText(on ? style.weight(500) : style, color: on ? t.text : t.text3)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: fullWidth ? .infinity : nil)
                        .frame(height: height - pad * 2)
                        .background {
                            if on {
                                RoundedRectangle(cornerRadius: BarlyRadius.xs, style: .continuous)
                                    .fill(t.isDark ? t.fill3 : t.surface)
                                    .overlay(RoundedRectangle(cornerRadius: BarlyRadius.xs, style: .continuous).strokeBorder(t.isDark ? .clear : t.border, lineWidth: 1))
                                    .shadow(color: .black.opacity(t.isDark ? 0 : 0.04), radius: 1.5, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(pad)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .background(RoundedRectangle(cornerRadius: BarlyRadius.sm + 2, style: .continuous).fill(t.isDark ? t.fill1 : t.bgSubtle))
        .overlay(RoundedRectangle(cornerRadius: BarlyRadius.sm + 2, style: .continuous).strokeBorder(t.isDark ? .clear : t.border.opacity(0.6), lineWidth: 1))
    }
}

// MARK: - 选中态（references/buttons.md §4：不用实心黑、不用实心强调色）

/// 筛选 chip / 分类 tab / 列表选中项：浅灰底 + 深字 500 + 1px 深一级边（可加强调色小圆点 `t.selectedMark`）
public struct BarlySelectedChrome: ViewModifier {
    let on: Bool
    let radius: CGFloat
    let idleFill: Color?
    let idleBorder: Color?
    @Environment(\.barly) private var t
    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(shape.fill(on ? t.selectedBg : (idleFill ?? .clear)))
            .overlay(shape.strokeBorder(on ? t.selectedBorder : (idleBorder ?? .clear), lineWidth: 1))
    }
}

/// 规格 / 日期 / 时段选择卡：不填充，白底 + 1.5pt 深色（selectedFg）边 + 右上角强调色小勾
public struct BarlySelectCardChrome: ViewModifier {
    let on: Bool
    let radius: CGFloat
    let mark: Bool
    let idleFill: Color?
    @Environment(\.barly) private var t
    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(shape.fill(idleFill ?? t.fieldBg))
            .overlay(shape.strokeBorder(on ? t.selectedFg : t.fieldBorder, lineWidth: on ? 1.5 : 1))
            .overlay(alignment: .topTrailing) {
                if on && mark {
                    Image(systemName: "checkmark").font(.system(size: 7, weight: .heavy)).foregroundStyle(t.accentFg)
                        .frame(width: 14, height: 14)
                        .background(Circle().fill(t.selectedMark))
                        .offset(x: 4, y: -4)
                }
            }
    }
}

public extension View {
    /// 选中 chip / tab / 列表项（浅灰底 + 1px 深一级边）
    func barlySelected(_ on: Bool, radius: CGFloat = BarlyRadius.sm, idleFill: Color? = nil, idleBorder: Color? = nil) -> some View {
        modifier(BarlySelectedChrome(on: on, radius: radius, idleFill: idleFill, idleBorder: idleBorder))
    }
    /// 规格 / 日期 / 时段卡（1.5pt 深色边 + 小勾，不填充）
    func barlySelectCard(_ on: Bool, radius: CGFloat = BarlyRadius.md, mark: Bool = true, idleFill: Color? = nil) -> some View {
        modifier(BarlySelectCardChrome(on: on, radius: radius, mark: mark, idleFill: idleFill))
    }
}

/// 选中项文字色：深字（selectedFg）
public extension BarlyPalette {
    func selectedText(_ on: Bool, idle: Color? = nil) -> Color { on ? selectedFg : (idle ?? text2) }
}

/// 开关：28×16 胶囊，开 = 强调色（状态点属于强调色合法位置）
public struct BarlyToggleStyle: ToggleStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        BarlyToggleBody(configuration: configuration)
    }
}

struct BarlyToggleBody: View {
    let configuration: ToggleStyleConfiguration
    @Environment(\.barly) private var t
    var body: some View {
        HStack(spacing: 8) {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule().fill(configuration.isOn ? t.accent : t.fill3)
                Circle().fill(.white).frame(width: 12, height: 12).padding(2)
                    .shadow(color: .black.opacity(0.12), radius: 1, y: 0.5)
            }
            .frame(width: 28, height: 16)
            configuration.label
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.snappy(duration: 0.18)) { configuration.isOn.toggle() } }
    }
}

public extension ToggleStyle where Self == BarlyToggleStyle {
    static var barly: BarlyToggleStyle { BarlyToggleStyle() }
}

// MARK: - 卡片 / 头像 / 滚动 / 分页点

/// 1px 边、无阴影的卡片（浅色同白，深色 L1）
public struct Card<Content: View>: View {
    let padding: CGFloat
    let radius: CGFloat
    let fill: Color?
    let content: Content
    @Environment(\.barly) private var t
    public init(padding: CGFloat = 16, radius: CGFloat = BarlyRadius.lg, fill: Color? = nil, @ViewBuilder content: () -> Content) {
        self.padding = padding; self.radius = radius; self.fill = fill; self.content = content()
    }
    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let inner = content.padding(padding).frame(maxWidth: .infinity, alignment: .topLeading)
        switch BarlyFamily.current.surface {
        case .outline:
            inner
                .background(shape.fill(fill ?? (t.isDark ? t.fill0 : t.surface)))
                .overlay(shape.strokeBorder(t.isDark ? t.fieldBorder : t.border, lineWidth: 1))
        case .rule:
            // 不画框：顶部一条线（press / flood 用主文字色，editorial / swiss 用发丝线）
            inner
                .background(fill ?? .clear)
                .overlay(alignment: .top) {
                    Rectangle().fill([.press, .flood].contains(BarlyFamily.current) ? t.text : t.borderStrong).frame(height: 1)
                }
        case .grid:
            inner
                .background(Rectangle().fill(fill ?? t.bg))
                .overlay(Rectangle().strokeBorder(t.border, lineWidth: 1))
        case .filled:
            inner.background(shape.fill(fill ?? t.surface))
        case .block:
            inner.background(RoundedRectangle(cornerRadius: max(radius, BarlyRadius.xl), style: .continuous).fill(fill ?? t.bgMuted))
        case .thick:
            inner
                .background(Rectangle().fill(t.text).offset(x: 4, y: 4))
                .background(Rectangle().fill(fill ?? t.bg))
                .overlay(Rectangle().strokeBorder(t.text, lineWidth: 2))
        case .bare:
            inner.background(fill ?? .clear)
        }
    }
}

/// 头像：缺照片时浅色底 + 首字母（Brisk 实测写法）
public struct Avatar: View {
    let name: String
    let size: CGFloat
    let tint: Int?
    @Environment(\.barly) private var t
    public init(_ name: String, size: CGFloat = 36, tint: Int? = nil) { self.name = name; self.size = size; self.tint = tint }
    public var body: some View {
        let idx = tint ?? abs(name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }) % BarlyPalette.avatarTints.count
        let c = BarlyPalette.avatarTints[idx]
        let initials = name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
        Circle().fill(t.isDark ? c.bg.barlyMix(.black, 0.62) : c.bg)
            .overlay(Text(initials).font(BarlyFonts.font(BarlyTokens.Font.ui, size: size * 0.38, weight: 500))
                .foregroundStyle(t.isDark ? c.bg : c.fg))
            .frame(width: size, height: size)
    }
}

/// 叠放头像组 + 「+7」
public struct AvatarStack: View {
    let names: [String]
    let extra: Int
    let size: CGFloat
    @Environment(\.barly) private var t
    public init(_ names: [String], extra: Int = 0, size: CGFloat = 22) { self.names = names; self.extra = extra; self.size = size }
    public var body: some View {
        HStack(spacing: -size * 0.32) {
            ForEach(Array(names.enumerated()), id: \.offset) { _, n in
                Avatar(n, size: size).overlay(Circle().strokeBorder(t.bg, lineWidth: 1.5))
            }
            if extra > 0 {
                Text("+\(extra)").barlyText(.product.caption.size(10).weight(500), color: t.text2)
                    .frame(width: size, height: size)
                    .background(Circle().fill(t.fill1)).overlay(Circle().strokeBorder(t.bg, lineWidth: 1.5))
            }
        }
    }
}

/// 滚动容器：快照模式下换成裁切的静态栈（ImageRenderer 画不出 NSScrollView）
public struct BarlyScroll<Content: View>: View {
    let axis: Axis.Set
    let content: Content
    @Environment(\.barlySnapshot) private var snapshot
    public init(_ axis: Axis.Set = .vertical, @ViewBuilder content: () -> Content) { self.axis = axis; self.content = content() }
    public var body: some View {
        if snapshot {
            Color.clear.overlay(alignment: .topLeading) {
                content.fixedSize(horizontal: axis.contains(.horizontal), vertical: axis.contains(.vertical))
            }
            .clipped()
        } else {
            ScrollView(axis, showsIndicators: false) { content }
        }
    }
}

/// 分页点：未选 6pt 灰圆，选中 20×6 强调色胶囊
public struct PageDots: View {
    let count: Int
    let selected: Int
    @Environment(\.barly) private var t
    public init(count: Int, selected: Int) { self.count = count; self.selected = selected }
    public var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule().fill(i == selected ? (t.isDark ? t.accentText : t.accent) : (t.isDark ? t.fill3 : t.text4))
                    .frame(width: i == selected ? 20 : 6, height: 6)
            }
        }
    }
}

/// 1px 发丝线
public struct Hairline: View {
    let vertical: Bool
    @Environment(\.barly) private var t
    public init(vertical: Bool = false) { self.vertical = vertical }
    public var body: some View {
        Rectangle().fill(t.hairline).frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
    }
}

/// 进度条（存储卡、预算）——强调色只在填充段
public struct ProgressBar: View {
    let value: Double
    let height: CGFloat
    let color: Color?
    @Environment(\.barly) private var t
    public init(_ value: Double, height: CGFloat = 6, color: Color? = nil) { self.value = value; self.height = height; self.color = color }
    public var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(t.isDark ? t.fill3 : t.bgMuted.barlyMix(.black, 0.05))
                Capsule().fill(color ?? t.accent).frame(width: g.size.width * min(1, max(0, value)))
            }
        }
        .frame(height: height)
    }
}

import SwiftUI

// MARK: - 发送键 / 工具 pill

/// 发送键：圆角方块（不是圆），转化动作 = cta（强调色渐变 + 白箭头）；ink = 带色相近黑渐变（桌面工具品类浅色）
public struct SendKey: View {
    let size: CGFloat
    let icon: String
    let ink: Bool
    let busy: Bool
    @Environment(\.barly) private var t
    public init(size: CGFloat = BarlyMetrics.sendKey, icon: String = "arrow.up", ink: Bool = false, busy: Bool = false) {
        self.size = size; self.icon = icon; self.ink = ink; self.busy = busy
    }
    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: min(BarlyRadius.sm, size * 0.26), style: .continuous)
        ZStack {
            if busy {
                shape.fill(t.accent.barlyMix(t.bg, 0.55))
                BarlyIcon("barly.radiant", size: size * 0.55, color: t.accentText.barlyMix(.white, 0.5))
            } else if ink || BarlyFamily.current == .flood {   // flood：底色就是强调色，发送键用前景色（= cta 令牌）
                shape.fill(LinearGradient(colors: [t.inkGradientFrom, t.inkGradientTo], startPoint: .top, endPoint: .bottom))
                    .overlay(shape.inset(by: 0.5).stroke(LinearGradient(colors: [t.inkEdge, .clear], startPoint: .top, endPoint: .center), lineWidth: 1))
            } else {
                shape.fill(LinearGradient(colors: [t.cta, t.cta.barlyMix(.black, 0.08)], startPoint: .top, endPoint: .bottom))
                    .overlay(shape.strokeBorder(LinearGradient(colors: [.black.opacity(0.12), .clear], startPoint: .top, endPoint: .center), lineWidth: 1))
            }
            if !busy {
                Image(systemName: icon).font(.system(size: size * 0.46, weight: .medium)).foregroundStyle(ink || BarlyFamily.current == .flood ? t.inkFg : t.ctaFg)
            }
        }
        .frame(width: size, height: size)
    }
}

/// 输入框里的工具开关（Deep Think / Search）：灰底无边 pill，r = Radius.xs；on = L3
public struct ToolPill: View {
    let title: String
    let icon: String
    let on: Bool
    @Environment(\.barly) private var t
    public init(_ title: String, icon: String, on: Bool = false) { self.title = title; self.icon = icon; self.on = on }
    public var body: some View {
        HStack(spacing: 6) {
            BarlyIcon(icon, size: 15, color: on ? t.text : t.text2)
            Text(title).barlyText(.mobile.label, color: on ? t.text : t.text2)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(RoundedRectangle(cornerRadius: BarlyRadius.xs + 1, style: .continuous).fill(on ? t.fill3 : (t.isDark ? t.fill2 : t.bgMuted)))
    }
}

// MARK: - 移动 Composer

/// 单行输入（48pt）：📎 + 占位 + 🎙 + 发送方块
public struct MobileInput: View {
    let placeholder: String
    @Binding var text: String
    let sendIcon: String
    @Environment(\.barly) private var t
    public init(_ placeholder: String, text: Binding<String>, sendIcon: String = "arrow.up") {
        self.placeholder = placeholder; self._text = text; self.sendIcon = sendIcon
    }
    public var body: some View {
        HStack(spacing: 10) {
            BarlyIcon("paperclip", size: 17, color: t.text3)
            BarlyBareField(placeholder: placeholder, text: $text, style: .mobile.headline.weight(400))
            BarlyIcon("mic", size: 18, color: t.text3)
            SendKey(icon: sendIcon)
        }
        .padding(.leading, 16).padding(.trailing, 9)
        .frame(height: BarlyMetrics.inputH)
        .background(RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous).fill(t.fieldBg))
        .overlay(RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous).strokeBorder(t.fieldBorder, lineWidth: 1))
    }
}

/// 两层 Composer（120pt）：上 占位，下 工具 pill …… 📎 🎙 发送
public struct MobileComposer: View {
    let placeholder: String
    @Binding var text: String
    let tools: [ToolPill]
    let showPlus: Bool
    let busy: Bool
    let sendIcon: String
    @Environment(\.barly) private var t
    public init(_ placeholder: String, text: Binding<String>, tools: [ToolPill] = [], showPlus: Bool = false, busy: Bool = false, sendIcon: String = "arrow.up") {
        self.placeholder = placeholder; self._text = text; self.tools = tools
        self.showPlus = showPlus; self.busy = busy; self.sendIcon = sendIcon
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BarlyBareField(placeholder: placeholder, text: $text, style: .mobile.headline.weight(400))
                .padding(.top, 4)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                if showPlus {
                    BarlyIcon("plus", size: 16, color: t.text2)
                        .frame(width: 30, height: 30)
                        .background(RoundedRectangle(cornerRadius: BarlyRadius.xs + 1, style: .continuous).fill(t.isDark ? t.fill2 : t.bgMuted))
                }
                ForEach(Array(tools.enumerated()), id: \.offset) { _, p in p }
                Spacer(minLength: 4)
                if !showPlus {
                    BarlyIcon("paperclip", size: 17, color: t.text2).padding(.trailing, 6)
                    BarlyIcon("mic", size: 17, color: t.text2).padding(.trailing, 4)
                }
                SendKey(size: 30, icon: sendIcon, busy: busy)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(height: BarlyMetrics.composerH)
        .background(RoundedRectangle(cornerRadius: BarlyRadius.lg, style: .continuous).fill(t.fieldBg))
        .overlay(RoundedRectangle(cornerRadius: BarlyRadius.lg, style: .continuous).strokeBorder(t.fieldBorder, lineWidth: 1))
    }
}

// MARK: - 桌面 Composer

/// 大输入框（856×200）：✧ + 占位；底行 Attach · Writing Styles ▾ …… Citation 开关 · 近黑发送方块
public struct DesktopComposer: View {
    let placeholder: String
    @Binding var text: String
    @Binding var citation: Bool
    let height: CGFloat
    let compact: Bool
    @Environment(\.barly) private var t
    public init(_ placeholder: String = "Ask AI a question or make a request...", text: Binding<String>, citation: Binding<Bool>,
                height: CGFloat = 200, compact: Bool = false) {
        self.placeholder = placeholder; self._text = text; self._citation = citation; self.height = height; self.compact = compact
    }
    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: BarlyRadius.lg, style: .continuous)
        Group {
            if compact {
                HStack(spacing: 12) {
                    IconButton("paperclip", size: 32)
                    BarlyBareField(placeholder: placeholder, text: $text, style: .product.body.size(15))
                    Toggle(isOn: $citation) { Text("Citation").barlyText(.product.body, color: t.text) }.toggleStyle(.barly)
                    SendKey(size: 32)   // 发送 = 转化 cta（buttons.md）
                }
                .padding(.horizontal, 14)
                .frame(height: 64)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "sparkles").font(.system(size: 14)).foregroundStyle(t.text)
                        BarlyBareField(placeholder: placeholder, text: $text, style: .product.body.size(15), axis: .vertical)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 12) {
                        BarlyButton("Attach", icon: "paperclip", variant: .outline, size: .lg)
                        BarlyButton("Writing Styles", trailingIcon: "chevron.down", variant: .outline, size: .lg)
                        Spacer()
                        Toggle(isOn: $citation) { Text("Citation").barlyText(.product.body, color: t.text) }.toggleStyle(.barly)
                        SendKey(size: 34)
                    }
                }
                .padding(16)
                .frame(height: height)
            }
        }
        .background(shape.fill(t.fieldBg).shadow(color: .black.opacity(t.isDark ? 0 : 0.035), radius: 10, y: 3))
        .overlay(shape.strokeBorder(t.fieldBorder, lineWidth: 1))
    }
}

// MARK: - 对话流

public enum UserBubbleStyle: Sendable {
    /// 白底 1px 描边（Bimbo 浅色）；深色自动变 L1
    case outline
    /// 强调色 tint 底（Lumeo 薰衣草）
    case tint
}

/// 用户消息：右对齐气泡，右下直角当尾巴
public struct UserBubble: View {
    let text: String
    let style: UserBubbleStyle
    let maxWidth: CGFloat
    let textStyle: BarlyTextStyle
    @Environment(\.barly) private var t
    public init(_ text: String, style: UserBubbleStyle = .outline, maxWidth: CGFloat = 280, textStyle: BarlyTextStyle = BarlyTokens.Mobile.body) {
        self.text = text; self.style = style; self.maxWidth = maxWidth; self.textStyle = textStyle
    }
    public var body: some View {
        let r = BarlyRadius.lg
        let shape = UnevenRoundedRectangle(topLeadingRadius: r, bottomLeadingRadius: r, bottomTrailingRadius: 2, topTrailingRadius: r, style: .continuous)
        let fill: Color = style == .tint ? (t.isDark ? t.accentSoft : t.accentSoft.barlyMix(t.accent, 0.06)) : t.fieldBg
        HStack {
            Spacer(minLength: 40)
            Text(text)
                .barlyText(textStyle.leading(max(textStyle.lineHeightPt, textStyle.size * 1.3)), color: style == .tint ? t.text : (t.isDark ? t.text : t.text2))
                .padding(.horizontal, 16).padding(.vertical, 11)
                .background(shape.fill(fill))
                .overlay(shape.strokeBorder(style == .outline && !t.isDark ? t.border : .clear, lineWidth: 1))
                .frame(maxWidth: maxWidth, alignment: .trailing)
        }
    }
}

/// AI 回复：无气泡、无头像，正文铺满；下方一行反馈图标
public struct AIMessage<Content: View>: View {
    let feedback: Bool
    let content: Content
    public init(feedback: Bool = true, @ViewBuilder content: () -> Content) { self.feedback = feedback; self.content = content() }
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
            if feedback { FeedbackRow().padding(.top, 4) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 正文段落（移动 15/21，桌面 16/28）
public struct AIParagraph: View {
    let text: String
    let style: BarlyTextStyle
    @Environment(\.barly) private var t
    public init(_ text: String, style: BarlyTextStyle = BarlyTokens.Mobile.body.leading(21)) { self.text = text; self.style = style }
    public var body: some View {
        Text(text).barlyText(style, color: t.isDark ? t.text : t.text.barlyMix(t.bg, 0.1)).fixedSize(horizontal: false, vertical: true)
    }
}

/// 圆点列表
public struct AIBullets: View {
    let items: [String]
    let style: BarlyTextStyle
    @Environment(\.barly) private var t
    public init(_ items: [String], style: BarlyTextStyle = BarlyTokens.Mobile.body.leading(21)) { self.items = items; self.style = style }
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(items, id: \.self) { s in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("•").barlyText(style, color: t.text2)
                    Text(s).barlyText(style, color: t.isDark ? t.text : t.text.barlyMix(t.bg, 0.1)).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 6)
            }
        }
    }
}

/// 回复下方 5–6 个 16pt 线性反馈图标，三级灰
public struct FeedbackRow: View {
    let icons: [String]
    let boxed: Bool
    @Environment(\.barly) private var t
    public init(icons: [String] = ["doc.on.doc", "arrow.triangle.2.circlepath", "square.and.arrow.up", "hand.thumbsup", "hand.thumbsdown", "ellipsis"], boxed: Bool = false) {
        self.icons = icons; self.boxed = boxed
    }
    public var body: some View {
        HStack(spacing: boxed ? 6 : 22) {
            ForEach(icons, id: \.self) { i in
                if boxed {
                    BarlyIcon(i, size: 15, color: t.text3).frame(width: 26, height: 26)
                        .background(RoundedRectangle(cornerRadius: BarlyRadius.xs, style: .continuous).fill(t.fill0))
                } else {
                    BarlyIcon(i, size: 16, color: t.text3)
                }
            }
        }
    }
}

// MARK: - 来源

public struct SourceIcon: Sendable {
    public let color: Color
    public let glyph: String
    public let fg: Color
    public init(_ color: Color, glyph: String, fg: Color = .white) { self.color = color; self.glyph = glyph; self.fg = fg }
}

/// 叠放圆形 favicon（白描边，相互压 30%）
public struct FaviconStack: View {
    let icons: [SourceIcon]
    let size: CGFloat
    @Environment(\.barly) private var t
    public init(_ icons: [SourceIcon], size: CGFloat = 20) { self.icons = icons; self.size = size }
    public var body: some View {
        HStack(spacing: -size * 0.32) {
            ForEach(Array(icons.enumerated()), id: \.offset) { _, i in
                Circle().fill(i.color)
                    .overlay(Image(systemName: i.glyph).font(.system(size: size * 0.48, weight: .semibold)).foregroundStyle(i.fg))
                    .frame(width: size, height: size)
                    .overlay(Circle().strokeBorder(t.fieldBg, lineWidth: 1.5))
            }
        }
    }
}

/// 来源计数 chip：「◐◐◐ 20 Web Source」
public struct SourceChip: View {
    let icons: [SourceIcon]
    let label: String
    @Environment(\.barly) private var t
    public init(_ label: String, icons: [SourceIcon]) { self.label = label; self.icons = icons }
    public var body: some View {
        HStack(spacing: 8) {
            FaviconStack(icons)
            Text(label).barlyText(.mobile.label, color: t.text2)
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous).fill(t.fieldBg))
        .overlay(RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous).strokeBorder(t.fieldBorder, lineWidth: 1))
    }
}

/// 一行来源 chip
public struct SourceChips: View {
    let chips: [(String, [SourceIcon])]
    public init(_ chips: [(String, [SourceIcon])]) { self.chips = chips }
    public var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, c in SourceChip(c.0, icons: c.1) }
        }
    }
}

/// 桌面来源卡（Lumeo）：浅灰无边，标题 + favicon · 域名 · 序号
public struct SourceCard: View {
    let title: String
    let domain: String
    let index: Int
    let icon: SourceIcon
    @Environment(\.barly) private var t
    public init(_ title: String, domain: String, index: Int, icon: SourceIcon) { self.title = title; self.domain = domain; self.index = index; self.icon = icon }
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).barlyText(.product.body.weight(500), color: t.text).lineLimit(1)
            HStack(spacing: 6) {
                Image(systemName: icon.glyph).font(.system(size: 13, weight: .semibold)).foregroundStyle(icon.color)
                Text(domain).barlyText(.product.body, color: t.text2)
                Text("•").barlyText(.product.caption, color: t.text3)
                Text("\(index)").barlyText(.product.body, color: t.text2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous).fill(t.softSurface))
    }
}

// MARK: - 过程卡（Deep Search / Thinking）

public struct ProcessStep: Identifiable, Sendable {
    public let id = UUID()
    public let icon: String
    public let title: String
    public let detail: String
    public init(icon: String, title: String, detail: String) { self.icon = icon; self.title = title; self.detail = detail }
}

public struct ProcessCard: View {
    let title: String
    let time: String?
    let subtitle: String?
    let steps: [ProcessStep]
    let generating: Bool
    @Environment(\.barly) private var t
    public init(_ title: String = "Deep Searched", time: String? = "54s", subtitle: String? = "Tap to read my mind",
                steps: [ProcessStep] = [], generating: Bool = false) {
        self.title = title; self.time = time; self.subtitle = subtitle; self.steps = steps; self.generating = generating
    }
    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                BarlyIcon("dot.radiowaves.left.and.right", size: 16, color: t.isDark ? t.text2 : t.text)
                Text(title).barlyText(.mobile.headline, color: t.isDark ? t.text2 : t.text)
                if let time { Text(time).barlyText(.mobile.headline.weight(400), color: t.text3) }
                Spacer()
                BarlyIcon(steps.isEmpty ? "chevron.down" : "chevron.up", size: 13, color: t.text3)
            }
            if generating {
                HStack(spacing: 6) {
                    Text("Generating…").barlyText(.mobile.body, color: t.text2)
                    BarlyIcon("barly.radiant", size: 14, color: t.text2)
                }
                .padding(.top, 8)
            } else if let subtitle, steps.isEmpty {
                Text(subtitle).barlyText(.mobile.caption, color: t.text3)
            }
            if !steps.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(steps) { s in
                        HStack(alignment: .top, spacing: 10) {
                            BarlyIcon(s.icon, size: 15, color: t.text2).padding(.top, 1)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(s.title).barlyText(.mobile.label.weight(500), color: t.text)
                                Text(s.detail).barlyText(.mobile.caption.leading(17), color: t.text2).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(.top, 12)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            shape.fill(t.isDark ? AnyShapeStyle(LinearGradient(colors: [t.fill0.barlyMix(.white, 0.012), t.fill0.barlyMix(t.bg, 0.15)], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(t.surface))
        )
        .overlay(alignment: .topTrailing) {
            if t.isDark && !steps.isEmpty { DotGrid().frame(width: 140, height: 90).clipShape(shape) }
        }
        .overlay(shape.strokeBorder(LinearGradient(colors: [t.litEdgeTop, t.litEdgeBottom], startPoint: .top, endPoint: .bottom), lineWidth: 1))
    }
}

// MARK: - 代码块

public struct CodeBlock: View {
    let language: String
    let code: String
    let codeStyle: BarlyTextStyle
    @Environment(\.barly) private var t
    public init(language: String, code: String, codeStyle: BarlyTextStyle = BarlyTokens.Mobile.caption.monospaced.leading(19)) {
        self.language = language; self.code = code; self.codeStyle = codeStyle
    }
    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language).barlyText(codeStyle.leading(1.2), color: t.text)
                Spacer()
                HStack(spacing: 6) {
                    BarlyIcon("doc.on.doc", size: 14, color: t.text2)
                    Text("Copy").barlyText(.mobile.caption, color: t.text2)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(t.codeHeader)
            Rectangle().fill(t.isDark ? t.hairline : t.border.opacity(0.6)).frame(height: 1)
            Text(CodeHighlighter.highlight(code, palette: t))
                .barlyText(codeStyle)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(t.codeBg)
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(t.isDark ? AnyShapeStyle(LinearGradient(colors: [t.litEdgeTop, t.litEdgeBottom], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(t.border.opacity(0.7)), lineWidth: 1))
    }
}

/// 极简语法高亮：注释 / 字符串 / 关键字 / 数字（降饱和色，见 BarlyPalette.code*）
public enum CodeHighlighter {
    static let keywords: Set<String> = ["def", "return", "import", "from", "for", "in", "if", "else", "elif", "while", "class",
                                        "print", "let", "var", "func", "const", "function", "await", "async", "struct",
                                        "@keyframes", "animation", "transform", "true", "false", "None", "self"]
    public static func highlight(_ code: String, palette t: BarlyPalette) -> AttributedString {
        var out = AttributedString()
        for (li, line) in code.components(separatedBy: "\n").enumerated() {
            if li > 0 { out += AttributedString("\n") }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") || trimmed.hasPrefix("//") {
                var a = AttributedString(line); a.foregroundColor = t.codeComment; out += a; continue
            }
            var i = line.startIndex
            while i < line.endIndex {
                let ch = line[i]
                if ch == "\"" || ch == "'" {
                    var j = line.index(after: i)
                    while j < line.endIndex && line[j] != ch { j = line.index(after: j) }
                    if j < line.endIndex { j = line.index(after: j) }
                    var a = AttributedString(String(line[i..<j])); a.foregroundColor = t.codeString; out += a; i = j; continue
                }
                if ch.isLetter || ch == "_" || ch == "@" {
                    var j = i
                    while j < line.endIndex && (line[j].isLetter || line[j].isNumber || line[j] == "_" || line[j] == "@" || line[j] == "-") { j = line.index(after: j) }
                    let w = String(line[i..<j])
                    var a = AttributedString(w)
                    a.foregroundColor = keywords.contains(w) ? t.codeKeyword : t.codeText
                    out += a; i = j; continue
                }
                if ch.isNumber {
                    var j = i
                    while j < line.endIndex && (line[j].isNumber || line[j] == ".") { j = line.index(after: j) }
                    var a = AttributedString(String(line[i..<j])); a.foregroundColor = t.codeNumber; out += a; i = j; continue
                }
                var a = AttributedString(String(ch))
                a.foregroundColor = "=*+-/<>%".contains(ch) ? t.codeNumber : t.codeText
                out += a
                i = line.index(after: i)
            }
        }
        return out
    }
}

// MARK: - 示例卡（问候空状态下方 4 列）

public struct ExampleCard: View {
    let text: String
    let icon: String
    @Environment(\.barly) private var t
    public init(_ text: String, icon: String) { self.text = text; self.icon = icon }
    public var body: some View {
        VStack(alignment: .leading) {
            Text(text).barlyText(.product.body.leading(22), color: t.text2).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 20)
            BarlyIcon(icon, size: 16, color: t.text)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: BarlyRadius.lg, style: .continuous).fill(t.softSurface))
    }
}

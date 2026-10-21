import SwiftUI

/// 两行双色标题（Barly 签名的「降调」）：第一行主文字色，第二行 headline2 灰。
/// `keyword` 出现在任一行时上招牌渐变（name-gradient / 关键词着色）。
public struct TwoToneHeading: View {
    let first: String
    let second: String
    let style: BarlyTextStyle
    let keyword: String?
    let mutedSecond: Bool
    let alignment: TextAlignment
    @Environment(\.barly) private var t

    public init(_ first: String, _ second: String, style: BarlyTextStyle = BarlyTokens.Mobile.display,
                keyword: String? = nil, mutedSecond: Bool = true, alignment: TextAlignment = .center) {
        self.first = first; self.second = second; self.style = style
        self.keyword = keyword; self.mutedSecond = mutedSecond; self.alignment = alignment
    }

    private func line(_ s: String, base: Color) -> Text {
        let grad = LinearGradient(colors: t.nameGradient, startPoint: .leading, endPoint: .trailing)
        guard let k = keyword, let r = s.range(of: k) else { return Text(s).foregroundStyle(base) }
        // 中文关键词（名字）不上渐变：一律降调灰 headline2（anti-slop S1，Web Hl / 小程序 BGreeting 同规则）
        let kw = String(s[r])
        let kwText = BarlyCJK.contains(kw) ? Text(kw).foregroundStyle(t.headline2) : Text(kw).foregroundStyle(grad)
        return Text(String(s[..<r.lowerBound])).foregroundStyle(base)
            + kwText
            + Text(String(s[r.upperBound...])).foregroundStyle(base)
    }

    /// 中文标题默认 400（PingFang Medium 在大字号下读起来像粗体，dna.md §2）
    private var resolved: BarlyTextStyle {
        let zh = BarlyTokens.lang == "zh" || BarlyCJK.contains(first) || BarlyCJK.contains(second)
        return zh && style.size >= 20 ? style.weight(min(style.weight, 400)) : style
    }

    public var body: some View {
        if BarlyFamily.current.isBarly { barlyBody } else {
            // 风格族：衬线 + 斜体词 / 压缩体大写 / grotesk（见 Theme/Family.swift DisplayTitle）
            DisplayTitle([first, second], style: FamilyType.display(resolved), keyword: keyword, mutedTail: mutedSecond,
                         alignment: alignment == .leading ? .leading : (alignment == .trailing ? .trailing : .center))
        }
    }

    private var barlyBody: some View {
        VStack(alignment: alignment == .leading ? .leading : (alignment == .trailing ? .trailing : .center), spacing: 0) {
            line(first, base: t.text)
            line(second, base: mutedSecond ? t.headline2 : t.text)
        }
        .barlyText(resolved.leading(resolved.lineHeight > 4 ? resolved.lineHeight : max(resolved.lineHeight, 1.3)))
        .multilineTextAlignment(alignment)
    }
}

/// 问候语：「Welcome, Martin / What can I help with?」——名字渐变 + 第二行灰
public struct Greeting: View {
    let hello: String
    let name: String
    let question: String
    let style: BarlyTextStyle
    let gradientName: Bool
    let alignment: TextAlignment
    public init(hello: String = "Welcome,", name: String, question: String = "What can I help with?",
                style: BarlyTextStyle = BarlyTokens.Mobile.display, gradientName: Bool = true, alignment: TextAlignment = .center) {
        self.hello = hello; self.name = name; self.question = question; self.style = style
        self.gradientName = gradientName; self.alignment = alignment
    }
    public var body: some View {
        // 中文不插空格：「你好，林夏」而不是「你好， 林夏」
        let sep = BarlyCJK.isCJK(hello.last) || BarlyCJK.isCJK(name.first) ? "" : " "
        return TwoToneHeading("\(hello)\(sep)\(name)", question, style: style, keyword: gradientName ? name : nil, alignment: alignment)
    }
}

/// 区块标题行：「Services ······ View all」
public struct SectionHeader: View {
    let title: String
    let action: String?
    let style: BarlyTextStyle
    @Environment(\.barly) private var t
    public init(_ title: String, action: String? = "View all", style: BarlyTextStyle = BarlyTokens.Mobile.headline.size(17)) {
        self.title = title; self.action = action; self.style = style
    }
    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).barlyText(FamilyType.pageTitle(style), color: t.text)
            Spacer()
            if let action { Text(action).barlyText(.mobile.body, color: t.text3) }
        }
    }
}

/// 大数字分色：`$` 最弱灰 + 整数主色 + 小数中灰 + 单位小字（Brisk $462.72 average）
public struct SplitNumber: View {
    let prefix: String
    let integer: String
    let fraction: String
    let unit: String?
    let style: BarlyTextStyle
    @Environment(\.barly) private var t
    public init(prefix: String = "", _ integer: String, fraction: String = "", unit: String? = nil,
                style: BarlyTextStyle = BarlyTokens.Product.heroNumber) {
        self.prefix = prefix; self.integer = integer; self.fraction = fraction; self.unit = unit; self.style = style
    }
    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            (Text(prefix).foregroundStyle(t.text4) + Text(integer).foregroundStyle(t.text) + Text(fraction).foregroundStyle(t.text3))
                .barlyText(FamilyType.numeric(style))
            if let unit { Text(unit).barlyText(.product.body, color: t.text3) }
        }
    }
}

/// 中日韩字判断（标题字重、问候拼接用）
public enum BarlyCJK {
    public static func isCJK(_ c: Character?) -> Bool {
        guard let c else { return false }
        return c.unicodeScalars.contains { s in
            (0x2E80...0x9FFF).contains(s.value) || (0xAC00...0xD7AF).contains(s.value) || (0xF900...0xFAFF).contains(s.value) || (0xFF00...0xFFEF).contains(s.value)
        }
    }
    public static func contains(_ s: String) -> Bool { s.contains { isCJK($0) } }
}

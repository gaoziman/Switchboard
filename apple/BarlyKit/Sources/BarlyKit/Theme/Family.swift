import SwiftUI
import CoreText

// MARK: - 风格族（identity.style → BarlyTokens.family）
//
// 颜色、默认字体、圆角阶梯由 identity.mjs 的 applyFamily 写进令牌；这里只决定「组件怎么用这些令牌」：
// 标题走哪种字形、卡片是描边 / 发丝线 / 色块 / 粗框、圆角收多少、数字要不要等宽、照片要不要去色。
// 组件按 BarlyFamily.current 切样式，不为每个风格族复制页面。规则见 references/apple.md §8。

public enum BarlyFamily: String, CaseIterable, Sendable {
    case barly, console, editorial, swiss, brutal, flood, press, noir, soft, gallery

    /// 编译进来的风格族（换风格族 = identity.mjs new … --style x → new-apple.sh sync）
    public static let current: BarlyFamily = BarlyFamily(rawValue: BarlyTokens.family) ?? .barly

    /// 标题字形
    public enum Title: Sendable {
        /// Barly：两行双色 + 关键词渐变
        case twoTone
        /// 衬线 display 300–400 + 一个斜体词（editorial / press / soft / flood）
        case serif
        /// 压缩体大写（brutal / noir）
        case condensed
        /// Inter Tight 紧字距（swiss / gallery / console）
        case grotesk
    }

    public var title: Title {
        switch self {
        case .barly: .twoTone
        case .editorial, .press, .soft, .flood: .serif
        case .brutal, .noir: .condensed
        case .swiss, .gallery, .console: .grotesk
        }
    }

    /// 卡片 / 容器怎么分层
    public enum Surface: Sendable {
        /// 白底 1px 边 + 圆角（Barly）
        case outline
        /// 不画框，只在顶部一条发丝线（editorial / press / swiss / flood：靠线和位置分区）
        case rule
        /// 1px 线框、直角、无底色（console：数据台不用卡片，用线切格）
        case grid
        /// 抬一级的实色块、无边（noir：黑底上的深灰块）
        case filled
        /// 粉彩 / 奶油色块 + 大圆角、无边（soft）
        case block
        /// 2px 实线框 + 硬偏移影（brutal）
        case thick
        /// 什么都不画，照片和留白自己分区（gallery）
        case bare
    }

    public var surface: Surface {
        switch self {
        case .barly: .outline
        case .editorial, .press, .swiss, .flood: .rule
        case .console: .grid
        case .noir: .filled
        case .soft: .block
        case .brutal: .thick
        case .gallery: .bare
        }
    }

    public var isBarly: Bool { self == .barly }
    /// 数字用等宽（console）
    public var monoNumbers: Bool { self == .console }
    /// 照片一律去色（swiss；press 的头版照片也去色）
    public var grayscalePhotos: Bool { self == .swiss || self == .press }
    /// 照片主导：界面让位给照片（noir / gallery）
    public var photoLed: Bool { self == .noir || self == .gallery }
    /// mono 小标签字距（editorial 更宽）
    public var labelTracking: CGFloat { self == .editorial ? 0.18 : (self == .barly ? 0.08 : 0.12) }
    /// 主按钮是不是胶囊（soft 的深色 pill；其余产品内按钮都是矩形）
    public var pillButtons: Bool { self == .soft }
    /// 描边粗细（brutal 2，其余 1）
    public var stroke: CGFloat { self == .brutal ? 2 : 1 }
}

// MARK: - 圆角：令牌圆角按风格族收紧 / 放大

/// 组件里一律用 `BarlyRadius.md`，不要直接用 `BarlyTokens.Radius`（风格族会改写）
public enum BarlyRadius {
    static func adj(_ v: CGFloat) -> CGFloat {
        switch BarlyFamily.current {
        case .barly: v
        case .brutal, .press: 0
        case .swiss: min(v, 2)
        case .editorial, .gallery, .noir, .console, .flood: min(v, 4)
        case .soft: (v * 1.5).rounded()
        }
    }
    public static var xs: CGFloat { adj(BarlyTokens.Radius.xs) }
    public static var sm: CGFloat { adj(BarlyTokens.Radius.sm) }
    public static var md: CGFloat { adj(BarlyTokens.Radius.md) }
    public static var lg: CGFloat { adj(BarlyTokens.Radius.lg) }
    public static var xl: CGFloat { adj(BarlyTokens.Radius.xl) }
    public static var window: CGFloat { adj(BarlyTokens.Radius.window) }
    public static var pill: CGFloat { BarlyTokens.Radius.pill }
    public static var cta: CGFloat { BarlyFamily.current.pillButtons ? 999 : adj(BarlyTokens.Radius.cta) }
}

// MARK: - 标题字阶

public enum FamilyType {
    /// 把一个标题字阶换成当前风格族的 display 写法。
    /// scale = 按风格族放大字号（衬线 ×1.3、压缩体 ×1.7、grotesk ×1.15）；Barly 原样返回。
    public static func display(_ base: BarlyTextStyle, scale: Bool = true) -> BarlyTextStyle {
        let f = BarlyFamily.current
        var s = base
        switch f.title {
        case .twoTone:
            return base
        case .serif:
            s.family = BarlyTokens.Font.display
            s.weight = f == .soft ? 300 : 400
            s.tracking = -0.02
            s.lineHeight = 1.06
            if scale { s.size = (base.size * 1.3).rounded() }
        case .condensed:
            s.family = BarlyTokens.Font.display
            s.weight = 400
            s.upper = true
            s.tracking = 0
            s.lineHeight = 0.94
            if scale { s.size = (base.size * 1.7).rounded() }
        case .grotesk:
            s.family = BarlyTokens.Font.display
            s.weight = f == .gallery ? 400 : 500
            s.tracking = -0.035
            s.lineHeight = 1.05
            if scale { s.size = (base.size * 1.15).rounded() }
        }
        return s
    }

    /// 页面标题（桌面 TitleBar、移动区块大标题）：衬线族用 display，其余不变
    public static func pageTitle(_ base: BarlyTextStyle = BarlyTokens.Product.pageTitle) -> BarlyTextStyle {
        switch BarlyFamily.current.title {
        case .twoTone: base
        case .serif: display(base.size(base.size + 6), scale: false)
        case .condensed: display(base.size(base.size + 10), scale: false)
        case .grotesk: display(base, scale: false)
        }
    }

    /// 数字：console 用等宽
    public static func numeric(_ base: BarlyTextStyle) -> BarlyTextStyle {
        BarlyFamily.current.monoNumbers ? base.monospaced.tracked(-0.02) : base
    }

    /// mono 小标签：按风格族字距
    public static func label(_ base: BarlyTextStyle = BarlyTokens.Mobile.sectionLabel) -> BarlyTextStyle {
        // editorial 的眉标是 UI 无衬线大写 + 宽字距（editorial-portfolio「DESIGN & BRAND STRATEGY」），不是等宽
        var s = base.tracked(BarlyFamily.current.labelTracking)
        if BarlyFamily.current == .editorial { s.mono = false; s.weight = 500 }
        return s
    }
}

// MARK: - 斜体：优先用真斜体文件（identity 给衬线 display 配的「字体名#italic」，sync 时自动拷进 Resources/Fonts），
// 没有斜体文件的字体才用 CTFont 斜切矩阵合成（12°）

public extension BarlyFonts {
    static func italic(_ family: String, size: CGFloat, weight: Int) -> Font {
        register()
        if has(family + "#italic") { return font(family + "#italic", size: size, weight: weight) }
        let base = ctFont(family, size: size, weight: weight)
        var m = CGAffineTransform(a: 1, b: 0, c: 0.21, d: 1, tx: 0, ty: 0)
        let d = CTFontCopyFontDescriptor(base)
        return Font(CTFontCreateWithFontDescriptor(d, size, &m))
    }
}

// MARK: - DisplayTitle：风格族标题（多行、可带一个特殊词）

/// 风格族标题。`keyword` 是那个「特殊词」（anti-slop S1 / dna.md §3，Web sections.css / 小程序 BTitle 同规则）：
/// 西文：Barly = 名字渐变；衬线 = 真斜体 + 同一文字色（只换字形不换色）；压缩体 = 强调色；grotesk = 降一级灰。
/// 中文：没有斜体 → 一律降调灰 headline2，不用强调色、不换字体、不加粗（brutal 的 headline2 是强调色，改用 text3）。
/// 第二行起：Barly / grotesk / 压缩体用 headline2 降调，衬线族保持主文字色（降调交给斜体）。
/// 行距自己控制（每行一个 Text，frame 高 = 字号 × lineHeight），压缩体 0.94 也排得紧。
public struct DisplayTitle: View {
    let lines: [String]
    let style: BarlyTextStyle
    let keyword: String?
    let mutedTail: Bool
    let alignment: HorizontalAlignment
    let color: Color?
    @Environment(\.barly) private var t

    public init(_ lines: [String], style: BarlyTextStyle, keyword: String? = nil, mutedTail: Bool = true,
                alignment: HorizontalAlignment = .leading, color: Color? = nil) {
        self.lines = lines; self.style = style; self.keyword = keyword; self.mutedTail = mutedTail
        self.alignment = alignment; self.color = color
    }

    private var fam: BarlyFamily { .current }

    private func lineColor(_ i: Int) -> Color {
        if let color { return color }
        guard i > 0, mutedTail else { return t.text }
        return fam.title == .serif ? t.text : t.headline2
    }

    private func segment(_ s: String, base: Color) -> Text {
        let txt = style.upper ? s.uppercased() : s
        return Text(txt).font(style.font).foregroundStyle(base)
    }

    private func keywordText(_ s: String, base: Color) -> Text {
        let txt = style.upper ? s.uppercased() : s
        if BarlyCJK.contains(s) {
            return Text(txt).font(style.font).foregroundStyle(fam == .brutal ? t.text3 : t.headline2)
        }
        switch fam.title {
        case .twoTone:
            return Text(txt).font(style.font).foregroundStyle(LinearGradient(colors: t.nameGradient, startPoint: .leading, endPoint: .trailing))
        case .serif:
            return Text(txt).font(BarlyFonts.italic(style.resolvedFamily, size: style.size, weight: style.weight)).foregroundStyle(base)
        case .condensed:
            return Text(txt).font(style.font).foregroundStyle(t.isDark && fam == .noir ? t.accentText : t.accent)
        case .grotesk:
            return Text(txt).font(style.font).foregroundStyle(t.text3)
        }
    }

    private func line(_ s: String, _ i: Int) -> Text {
        let base = lineColor(i)
        guard let k = keyword, let r = s.range(of: k) else { return segment(s, base: base) }
        let before = segment(String(s[..<r.lowerBound]), base: base), after = segment(String(s[r.upperBound...]), base: base)
        return Text("\(before)\(keywordText(String(s[r]), base: base))\(after)")
    }

    public var body: some View {
        // 行距自己算：目标行高 − 字体自然行高 = 行间距（可为负，压缩体 / 衬线的大字号才排得紧）
        let target = style.lineHeight > 4 ? style.lineHeight : style.size * style.lineHeight
        let natural = BarlyFonts.naturalLineHeight(style.resolvedFamily, size: style.size, weight: style.weight)
        let ta: TextAlignment = alignment == .center ? .center : (alignment == .trailing ? .trailing : .leading)
        VStack(alignment: alignment, spacing: target - natural) {
            ForEach(Array(lines.enumerated()), id: \.offset) { i, s in
                line(s, i)
                    .tracking(style.trackingPt)
                    .lineSpacing(0)
                    .multilineTextAlignment(ta)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - 占位照片（原来的 Resources/Photos 来源不明，已从包里删掉；没有图片时显示灰色占位）

public enum PhotoMask: Sendable { case rect, arch, blob, circle, rounded(CGFloat) }

/// 占位照片：`BarlyPhoto("stage")`。名字：still-life interior stage portrait-dark dunes sea mountain board lamp street playroom garden
/// swiss / press 自动去色；mask 给 soft 的拱门 / 云朵遮罩。
public struct BarlyPhoto: View {
    let name: String
    let mask: PhotoMask
    let grayscale: Bool?
    let alignment: Alignment
    public init(_ name: String, mask: PhotoMask = .rect, grayscale: Bool? = nil, alignment: Alignment = .center) {
        self.name = name; self.mask = mask; self.grayscale = grayscale; self.alignment = alignment
    }
    public var body: some View {
        let gray = grayscale ?? BarlyFamily.current.grayscalePhotos
        Color.clear
            .overlay(alignment: alignment) {
                if let img = BarlyPhotoStore.image(name) {
                    img.resizable().interpolation(.high).scaledToFill()
                } else {
                    Rectangle().fill(Color.gray.opacity(0.3))
                }
            }
            .saturation(gray ? 0 : 1)
            .clipShape(PhotoMaskShape(mask: mask))
    }
}

enum BarlyPhotoStore {
    nonisolated(unsafe) static var cache: [String: Image] = [:]
    static func image(_ name: String) -> Image? {
        if let i = cache[name] { return i }
        guard let url = Bundle.module.url(forResource: name, withExtension: "jpg", subdirectory: "Photos") else { return nil }
        #if os(macOS)
        guard let ns = NSImage(contentsOf: url) else { return nil }
        let img = Image(nsImage: ns)
        #else
        guard let ui = UIImage(contentsOfFile: url.path) else { return nil }
        let img = Image(uiImage: ui)
        #endif
        cache[name] = img
        return img
    }
}

public struct PhotoMaskShape: Shape {
    let mask: PhotoMask
    public init(mask: PhotoMask) { self.mask = mask }
    public func path(in r: CGRect) -> Path {
        switch mask {
        case .rect: return Path(r)
        case .circle: return Path(ellipseIn: r)
        case .rounded(let c): return Path(roundedRect: r, cornerRadius: c, style: .continuous)
        case .arch:
            var p = Path()
            let rad = r.width / 2
            p.move(to: CGPoint(x: r.minX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.minY + rad))
            p.addArc(center: CGPoint(x: r.midX, y: r.minY + rad), radius: rad, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.closeSubpath()
            return p
        case .blob:
            // 云朵：四段大圆弧拼成的软方块（Ashcombe 式异形遮罩）
            let w = r.width, h = r.height
            var p = Path()
            p.move(to: CGPoint(x: r.minX + w * 0.18, y: r.minY + h * 0.12))
            p.addCurve(to: CGPoint(x: r.minX + w * 0.82, y: r.minY + h * 0.08), control1: CGPoint(x: r.minX + w * 0.38, y: r.minY - h * 0.04), control2: CGPoint(x: r.minX + w * 0.62, y: r.minY + h * 0.02))
            p.addCurve(to: CGPoint(x: r.maxX - w * 0.04, y: r.minY + h * 0.62), control1: CGPoint(x: r.maxX + w * 0.04, y: r.minY + h * 0.18), control2: CGPoint(x: r.maxX + w * 0.02, y: r.minY + h * 0.44))
            p.addCurve(to: CGPoint(x: r.minX + w * 0.3, y: r.maxY - h * 0.02), control1: CGPoint(x: r.maxX - w * 0.1, y: r.maxY + h * 0.02), control2: CGPoint(x: r.minX + w * 0.52, y: r.maxY + h * 0.04))
            p.addCurve(to: CGPoint(x: r.minX + w * 0.18, y: r.minY + h * 0.12), control1: CGPoint(x: r.minX - w * 0.04, y: r.maxY - h * 0.1), control2: CGPoint(x: r.minX - w * 0.06, y: r.minY + h * 0.3))
            p.closeSubpath()
            return p
        }
    }
}

// 风格族专属颜色（paper、pastel1–3、dataPos / dataNeg）由 identity.mjs 为所有风格族、明暗两套都生成：直接用 BarlyPalette 字段。
// 自己写 BarlyPalette 扩展时名字不能和生成字段重名。
// MARK: - soft 粉彩：生成的 pastel1–3（styles.mjs pastelSet：OKLCH(0.9, 0.06, h + 0 / 110 / 220)）

public extension BarlyPalette {
    /// soft 的 3 个平级粉彩块（其他风格族也能用，但只有 soft 该大面积用）
    var pastels: [Color] { [pastel1, pastel2, pastel3] }
}

public struct BarlyOKLCH: Sendable {
    public var l: Double, c: Double, h: Double
    public init(l: Double, c: Double, h: Double) { self.l = l; self.c = c; self.h = h }
    public var color: Color {
        var cc = c
        while true {
            let hr = h * .pi / 180
            let a = cc * cos(hr), b = cc * sin(hr)
            let l_ = pow(l + 0.3963377774 * a + 0.2158037573 * b, 3)
            let m_ = pow(l - 0.1055613458 * a - 0.0638541728 * b, 3)
            let s_ = pow(l - 0.0894841775 * a - 1.291485548 * b, 3)
            let rgb = [4.0767416621 * l_ - 3.3077115913 * m_ + 0.2309699292 * s_,
                       -1.2684380046 * l_ + 2.6097574011 * m_ - 0.3413193965 * s_,
                       -0.0041960863 * l_ - 0.7034186147 * m_ + 1.707614701 * s_]
            if rgb.allSatisfy({ $0 >= -0.0005 && $0 <= 1.0005 }) || cc < 0.006 {
                func g(_ x: Double) -> Double { let v = min(1, max(0, x)); return v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1 / 2.4) - 0.055 }
                return Color(.sRGB, red: g(rgb[0]), green: g(rgb[1]), blue: g(rgb[2]), opacity: 1)
            }
            cc -= 0.005
        }
    }
}

public extension Color {
    var barlyOklch: BarlyOKLCH {
        let c = barlyRGBA
        func lin(_ x: Double) -> Double { x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4) }
        let r = lin(c.r), g = lin(c.g), b = lin(c.b)
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        let L = 0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s
        let A = 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s
        let B = 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s
        return BarlyOKLCH(l: L, c: (A * A + B * B).squareRoot(), h: (atan2(B, A) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360))
    }
}

// MARK: - 骨架（identity.layout → BarlyTokens.Layout），可在环境里临时覆盖（snap --shell / --mobile-home / --inspector）

public extension EnvironmentValues {
    @Entry var barlyShellOverride: String? = nil
    @Entry var barlyInspectorOverride: Bool? = nil
    @Entry var barlyMobileHomeOverride: String? = nil
    /// AppShell 算好的内容区宽度（去掉侧栏 / 二级栏 / 检查栏），屏幕据此决定一行放几张卡
    @Entry var barlyContentWidth: CGFloat = 1168

    /// sidebar | sidebar-gray | rail | rail-list | topnav
    var barlyShell: String { barlyShellOverride ?? BarlyTokens.Layout.shell }
    var barlyInspector: Bool { barlyInspectorOverride ?? BarlyTokens.Layout.inspector }
    /// greeting-bottom | hub | orb-center
    var barlyMobileHome: String { barlyMobileHomeOverride ?? BarlyTokens.Layout.mobileHome }
}

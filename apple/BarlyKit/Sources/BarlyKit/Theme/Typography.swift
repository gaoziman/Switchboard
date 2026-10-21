import SwiftUI
import CoreText

// MARK: - BarlyTextStyle —— Theme.generated.swift 的字阶都是它

/// 一个字阶。`lineHeight` ≤ 4 视为倍数（1.4），> 4 视为绝对 pt（21）。`tracking` 单位 em。
public struct BarlyTextStyle: Sendable, Hashable {
    public var size: CGFloat
    public var lineHeight: CGFloat
    public var weight: Int
    public var tracking: CGFloat
    public var upper: Bool
    public var mono: Bool
    /// 指定字族（nil = 按 mono 取 ui / mono 字体）
    public var family: String?

    public init(size: CGFloat, lineHeight: CGFloat, weight: Int, tracking: CGFloat, upper: Bool, mono: Bool, family: String? = nil) {
        self.size = size; self.lineHeight = lineHeight; self.weight = weight
        self.tracking = tracking; self.upper = upper; self.mono = mono; self.family = family
    }

    public var lineHeightPt: CGFloat { lineHeight > 4 ? lineHeight : size * lineHeight }
    public var trackingPt: CGFloat { tracking * size }

    // 小改动的链式写法：.mobile.body.weight(500).size(16)
    public func weight(_ w: Int) -> Self { var s = self; s.weight = w; return s }
    public func size(_ v: CGFloat) -> Self { var s = self; s.size = v; return s }
    public func leading(_ v: CGFloat) -> Self { var s = self; s.lineHeight = v; return s }
    public func tracked(_ em: CGFloat) -> Self { var s = self; s.tracking = em; return s }
    public var monospaced: Self { var s = self; s.mono = true; return s }
    public var uppercased: Self { var s = self; s.upper = true; return s }
    /// 用展示字体（BarlyTokens.Font.display）
    public var display: Self { var s = self; s.family = BarlyTokens.Font.display; return s }

    /// 界面缩放：字号和（绝对值的）行高一起乘
    public func scaled(_ f: CGFloat) -> Self {
        guard f != 1 else { return self }
        var s = self
        s.size = (size * f * 2).rounded() / 2
        if lineHeight > 4 { s.lineHeight = (lineHeight * f).rounded() }
        return s
    }

    public var resolvedFamily: String { family ?? (mono ? BarlyTokens.Font.mono : BarlyTokens.Font.ui) }
    public var font: Font { BarlyFonts.font(resolvedFamily, size: size, weight: weight) }

    // `.barlyText(.product.body)` / `.barlyText(.mobile.display)` / `.barlyText(.marketing.hero)`
    public static var product: BarlyTokens.Product.Type { BarlyTokens.Product.self }
    public static var mobile: BarlyTokens.Mobile.Type { BarlyTokens.Mobile.self }
    public static var marketing: BarlyTokens.Marketing.Type { BarlyTokens.Marketing.self }
}

// MARK: - 字体注册（CTFontManager）

public enum BarlyFonts {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var registered = false
    nonisolated(unsafe) private static var descriptors: [String: CTFontDescriptor] = [:]   // family → descriptor
    nonisolated(unsafe) private static var cache: [String: CTFont] = [:]

    /// 注册包内 Resources/Fonts 里的全部字体（幂等）。App 启动时调用一次；BarlyFonts.font 也会自动调用。
    public static func register() {
        lock.lock(); defer { lock.unlock() }
        guard !registered else { return }
        registered = true
        let urls = (Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])
            + (Bundle.module.urls(forResourcesWithExtension: "otf", subdirectory: "Fonts") ?? [])
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            guard let descs = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] else { continue }
            // 真斜体文件（identity 的 files 里「字体名#italic」，如 InstrumentSerif-Italic.ttf）和正体同字族名：
            // 单独登记成「字族#italic」，不能抢正体的基底
            let isItalic = url.lastPathComponent.range(of: "Italic", options: .caseInsensitive) != nil
            for d in descs {
                if let fam = CTFontDescriptorCopyAttribute(d, kCTFontFamilyNameAttribute) as? String {
                    let short = fam.replacingOccurrences(of: " Variable", with: "")
                    for key in [fam, short].map({ isItalic ? $0 + "#italic" : $0 }) {
                        // 变体字体文件会给出多个实例，保留第一个（Regular）做基底；「General Sans Variable」也能用「General Sans」取到
                        if descriptors[key] == nil { descriptors[key] = d }
                    }
                }
            }
        }
    }

    /// 已注册的字族名（调试用）
    public static var families: [String] { register(); return Array(descriptors.keys).sorted() }
    /// 是否注册了某字族（含「字族#italic」）
    public static func has(_ family: String) -> Bool { register(); lock.lock(); defer { lock.unlock() }; return descriptors[family] != nil }

    public static func ctFont(_ family: String, size: CGFloat, weight: Int) -> CTFont {
        register()
        let key = "\(family)|\(size)|\(weight)"
        lock.lock(); defer { lock.unlock() }
        if let f = cache[key] { return f }
        let f: CTFont
        if let base = descriptors[family] {
            // wght 轴 = 'wght' = 0x77676874；非变体字体会忽略
            let attrs: [CFString: Any] = [kCTFontVariationAttribute: [0x7767_6874: weight] as CFDictionary]
            let d = CTFontDescriptorCreateCopyWithAttributes(base, attrs as CFDictionary)
            f = CTFontCreateWithFontDescriptor(d, size, nil)
        } else {
            f = CTFontCreateUIFontForLanguage(.system, size, nil) ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
        }
        cache[key] = f
        return f
    }

    public static func font(_ family: String, size: CGFloat, weight: Int) -> Font {
        if descriptors[family] == nil { register() }
        if descriptors[family] == nil {
            return .system(size: size, weight: weight.swiftUIWeight, design: family.lowercased().contains("mono") ? .monospaced : .default)
        }
        return Font(ctFont(family, size: size, weight: weight))
    }

    /// 字体自然行高（ascent + descent + leading）
    public static func naturalLineHeight(_ family: String, size: CGFloat, weight: Int) -> CGFloat {
        let f = ctFont(family, size: size, weight: weight)
        return CTFontGetAscent(f) + CTFontGetDescent(f) + CTFontGetLeading(f)
    }
}

extension Int {
    var swiftUIWeight: Font.Weight {
        switch self {
        case ..<250: return .thin
        case ..<350: return .light
        case ..<450: return .regular
        case ..<550: return .medium
        case ..<650: return .semibold
        default: return .bold
        }
    }
}

// MARK: - .barlyText 修饰符

/// 界面缩放（设置 › 外观，90%–150%）：所有 barlyText 的字号、以及要装下文字的尺寸（行高、按钮、栏头）都乘它。
/// 存在 UserDefaults 的 interfaceScale；截图时可以用环境变量 BARLY_SCALE 指定。改了之后窗口内容整个重建（见 App 的 .id）
public enum BarlyScale {
    public static let defaultsKey = "interfaceScale"
    public static let range: ClosedRange<Double> = 0.9...1.5

    public static var factor: CGFloat {
        if let env = ProcessInfo.processInfo.environment["BARLY_SCALE"], let v = Double(env) { return CGFloat(min(max(v, range.lowerBound), range.upperBound)) }
        let v = UserDefaults.standard.double(forKey: defaultsKey)
        return v == 0 ? 1 : CGFloat(min(max(v, range.lowerBound), range.upperBound))
    }

    /// 按缩放取整后的点数
    public static func pt(_ x: CGFloat) -> CGFloat { (x * factor).rounded() }
}

public struct BarlyTextModifier: ViewModifier {
    let style: BarlyTextStyle
    let color: Color?
    @Environment(\.barlySystemUIFont) private var systemUI
    public func body(content: Content) -> some View {
        let style = self.style.scaled(BarlyScale.factor)
        // Mac 工具形态（菜单栏 / 面板 / 货架 / 设置）的界面字用系统字体 SF Pro（references/mac-native.md）；
        // mono 和指定了字族的（品牌标题）不换
        let useSystem = systemUI && !style.mono && style.family == nil
        let natural = useSystem ? style.size * 1.2 : BarlyFonts.naturalLineHeight(style.resolvedFamily, size: style.size, weight: style.weight)
        let extra = max(0, style.lineHeightPt - natural)
        content
            .font(useSystem ? .system(size: style.size, weight: Self.weight(style.weight)) : style.font)
            .tracking(style.trackingPt)
            .lineSpacing(extra)
            .textCase(style.upper ? .uppercase : nil)
            .foregroundStyle(color.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.foreground))
    }
}

extension BarlyTextModifier {
    static func weight(_ w: Int) -> Font.Weight {
        switch w { case ..<350: .light; case ..<450: .regular; case ..<550: .medium; case ..<650: .semibold; default: .bold }
    }
}

public extension View {
    /// `.barlyText(.mobile.body)`、`.barlyText(.product.label, color: t.text3)`
    func barlyText(_ style: BarlyTextStyle, color: Color? = nil) -> some View {
        modifier(BarlyTextModifier(style: style, color: color))
    }
}

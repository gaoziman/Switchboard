import SwiftUI
import BarlyKit
#if os(macOS)
import AppKit
#endif

/// App 主题（设置 · 外观）：12 套，各有深色和浅色。Switchboard 是身份本身，强调色跟全局那一个（见 accent(dark:)）；
/// 另外 11 套各带自己的强调色，同一屏仍只有这一个强调色。代码高亮、图表色、状态色保留身份的。终端配色默认跟着它（见 TerminalScheme）
public enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case switchboard, bamboo, xuan, mist, amber, moss, polar, dune, celadon, verdigris, slate, mono

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .switchboard: "Switchboard"
        case .bamboo: L("墨竹")
        case .xuan: L("宣纸")
        case .mist: L("晨雾")
        case .amber: L("琥珀")
        case .moss: L("苔原")
        case .polar: L("北极")
        case .dune: L("沙丘")
        case .celadon: L("青瓷")
        case .verdigris: L("铜绿")
        case .slate: L("石板")
        case .mono: L("素")
        }
    }

    /// 外壳用到的 9 个颜色
    public struct Spec: Sendable {
        public var canvas: UInt32, sidebar: UInt32, surface: UInt32, border: UInt32
        public var text: UInt32, text2: UInt32, text3: UInt32, text4: UInt32
        public var accent: UInt32
    }

    /// 主题本身的颜色
    public func baseSpec(dark: Bool) -> Spec { spec(dark: dark) }

    /// 主题的颜色。Switchboard 的强调色换成全局那一个（和系统控件同色），其他主题用自己的
    public func spec(dark: Bool) -> Spec {
        var s = ownSpec(dark: dark)
        if self == .switchboard { s.accent = Self.accent(dark: dark) }
        return s
    }

    /// Switchboard 主题的强调色：就是系统控件（开关、焦点环、设置窗口的标签图标）读的颜色——app 包里的 AccentColor
    /// （身份色，系统强调色设成「多彩」时生效），用户在系统设置里选了别的强调色就是那个。
    /// 自绘的按钮、状态灯、选中条和系统控件因此永远同一个颜色，换主题也不会出现两种主体色
    public static func accent(dark: Bool) -> UInt32 {
        #if os(macOS)
        var hex: UInt32 = dark ? 0x31C0B3 : 0x19B3A6
        NSAppearance(named: dark ? .darkAqua : .aqua)?.performAsCurrentDrawingAppearance {
            if let c = NSColor.controlAccentColor.usingColorSpace(.sRGB) {
                let v = { (x: CGFloat) in UInt32((max(0, min(1, x)) * 255).rounded()) }
                hex = v(c.redComponent) << 16 | v(c.greenComponent) << 8 | v(c.blueComponent)
            }
        }
        return hex
        #else
        return dark ? 0x31C0B3 : 0x19B3A6
        #endif
    }

    /// 各主题自己的配色（Switchboard 的强调色一栏只是它原来的样子，实际用的是 accent(dark:)）。
    /// Switchboard 是身份本身：石墨底，面板比窗口底亮一档
    private func ownSpec(dark: Bool) -> Spec {
        switch (self, dark) {
        case (.switchboard, true): Spec(canvas: 0x1B1C1F, sidebar: 0x141517, surface: 0x24262A, border: 0x2E3034,
                                        text: 0xECEDEE, text2: 0xA9ABAF, text3: 0x75787D, text4: 0x45484C, accent: 0x19B3A6)
        case (.switchboard, false): Spec(canvas: 0xFFFFFF, sidebar: 0xF2F3F3, surface: 0xF4F5F5, border: 0xE3E6E6,
                                         text: 0x0E1212, text2: 0x565A5B, text3: 0x989C9D, text4: 0xC8CCCC, accent: 0x12A094)
        case (.bamboo, true): Spec(canvas: 0x1D2320, sidebar: 0x161B18, surface: 0x262E2A, border: 0x343F39,
                    text: 0xE7E9E8, text2: 0xB9C0BD, text3: 0x858E8A, text4: 0x545A57, accent: 0x3DBE8B)
        case (.bamboo, false): Spec(canvas: 0xFBFCFB, sidebar: 0xEEF1F0, surface: 0xF2F5F4, border: 0xDADFDD,
                    text: 0x1C211F, text2: 0x4C5752, text3: 0x7E8B85, text4: 0xB7BDBA, accent: 0x1F8F63)
        case (.xuan, true): Spec(canvas: 0x24211C, sidebar: 0x1B1915, surface: 0x2F2B25, border: 0x403B32,
                    text: 0xEAE8E6, text2: 0xC1BEB9, text3: 0x8F8B84, text4: 0x5A5853, accent: 0xE0533F)
        case (.xuan, false): Spec(canvas: 0xF7F4F0, sidebar: 0xEFEAE1, surface: 0xF2EDE6, border: 0xDFD8CB,
                    text: 0x221F1B, text2: 0x58534B, text3: 0x8C877D, text4: 0xBDBBB7, accent: 0xC23B2A)
        case (.mist, true): Spec(canvas: 0x1C2124, sidebar: 0x15191B, surface: 0x252B2F, border: 0x323B40,
                    text: 0xE6E8EA, text2: 0xB9BDC1, text3: 0x848B8F, text4: 0x53575A, accent: 0x5AA9C4)
        case (.mist, false): Spec(canvas: 0xFBFBFC, sidebar: 0xEEF0F2, surface: 0xF2F4F5, border: 0xD9DDE0,
                    text: 0x1B1F22, text2: 0x4B5358, text3: 0x7D868C, text4: 0xB7BBBD, accent: 0x2A7E9B)
        case (.amber, true): Spec(canvas: 0x22201D, sidebar: 0x1A1816, surface: 0x2D2A27, border: 0x3E3935,
                    text: 0xE9E8E7, text2: 0xBFBDBA, text3: 0x8D8A86, text4: 0x595754, accent: 0xF0A63A)
        case (.amber, false): Spec(canvas: 0xFCFBFB, sidebar: 0xF2F0EE, surface: 0xF5F4F2, border: 0xE0DDD9,
                    text: 0x211F1C, text2: 0x56524D, text3: 0x898580, text4: 0xBCBAB8, accent: 0xB06C0B)
        case (.moss, true): Spec(canvas: 0x21241C, sidebar: 0x191B15, surface: 0x2B2F25, border: 0x3B4032,
                    text: 0xE8EAE6, text2: 0xBDC1B9, text3: 0x8B8F84, text4: 0x575A53, accent: 0x9CC55A)
        case (.moss, false): Spec(canvas: 0xFAFBF9, sidebar: 0xEFF1EC, surface: 0xF3F4F0, border: 0xDCDFD7,
                    text: 0x1F221B, text2: 0x53584B, text3: 0x868C7D, text4: 0xBBBDB7, accent: 0x5B8723)
        case (.polar, true): Spec(canvas: 0x1D2123, sidebar: 0x16191B, surface: 0x262B2E, border: 0x343B3F,
                    text: 0xE7E9E9, text2: 0xB9BEC0, text3: 0x858B8E, text4: 0x54585A, accent: 0x4CB7F5)
        case (.polar, false): Spec(canvas: 0xFCFDFD, sidebar: 0xEEF2F4, surface: 0xF3F5F7, border: 0xD9E0E3,
                    text: 0x1C2021, text2: 0x4C5457, text3: 0x7E878B, text4: 0xB7BBBD, accent: 0x1A80C2)
        case (.dune, true): Spec(canvas: 0x25211B, sidebar: 0x1C1914, surface: 0x312B23, border: 0x433B30,
                    text: 0xEAE8E6, text2: 0xC2BEB7, text3: 0x918B82, text4: 0x5C5852, accent: 0x3FB3B0)
        case (.dune, false): Spec(canvas: 0xF6F2EC, sidebar: 0xEFE7DC, surface: 0xF1EBE2, border: 0xDFD5C6,
                    text: 0x231F1A, text2: 0x5B5348, text3: 0x8E867B, text4: 0xBFBBB6, accent: 0x1E8582)
        case (.celadon, true): Spec(canvas: 0x1B2422, sidebar: 0x151C1A, surface: 0x24302D, border: 0x31413D,
                    text: 0xE6EAE9, text2: 0xB8C1BF, text3: 0x83908D, text4: 0x525B59, accent: 0x6CC1AE)
        case (.celadon, false): Spec(canvas: 0xF9FBFA, sidebar: 0xEBF1F0, surface: 0xF0F5F3, border: 0xD6E0DE,
                    text: 0x1B2221, text2: 0x4A5A56, text3: 0x7C8D89, text4: 0xB6BEBC, accent: 0x2D8875)
        case (.verdigris, true): Spec(canvas: 0x1A2626, sidebar: 0x131D1D, surface: 0x223232, border: 0x2E4545,
                    text: 0xE5EBEB, text2: 0xB6C3C3, text3: 0x809393, text4: 0x515D5D, accent: 0xE09A62)
        case (.verdigris, false): Spec(canvas: 0xF9FBFB, sidebar: 0xECF1F1, surface: 0xF0F4F4, border: 0xD7DFDF,
                    text: 0x192424, text2: 0x465D5D, text3: 0x789191, text4: 0xB5C0C0, accent: 0xA9622A)
        case (.slate, true): Spec(canvas: 0x1D1F23, sidebar: 0x16171B, surface: 0x26292E, border: 0x34373F,
                    text: 0xE7E8E9, text2: 0xB9BCC0, text3: 0x85888E, text4: 0x54565A, accent: 0x8090F5)
        case (.slate, false): Spec(canvas: 0xFCFCFD, sidebar: 0xEFF0F3, surface: 0xF4F4F6, border: 0xDBDDE1,
                    text: 0x1C1E21, text2: 0x4C5057, text3: 0x7E838B, text4: 0xB7B9BD, accent: 0x4B5BD6)
        case (.mono, true): Spec(canvas: 0x202020, sidebar: 0x181818, surface: 0x2A2A2A, border: 0x393939,
                    text: 0xE8E8E8, text2: 0xBDBDBD, text3: 0x8A8A8A, text4: 0x575757, accent: 0xEDEDED)
        case (.mono, false): Spec(canvas: 0xFEFEFE, sidebar: 0xF2F2F2, surface: 0xF6F6F6, border: 0xDFDFDF,
                    text: 0x1F1F1F, text2: 0x525252, text3: 0x858585, text4: 0xBABABA, accent: 0x161616)
        }
    }

    /// 设置里的色样：底 · 面板 · 强调色
    public func swatch(dark: Bool) -> [Color] {
        let s = ThemeColors.apply(ThemeColors.changes(self, dark: dark), to: baseSpec(dark: dark), dark: dark)
        return [Color(hex: s.canvas), Color(hex: s.surface), Color(hex: s.accent)]
    }

    /// 这套主题的完整色板，含你改过的颜色（nil = 用身份本身，没改过）
    public func palette(dark: Bool) -> BarlyPalette? {
        let custom = ThemeColors.changes(self, dark: dark)
        let s = ThemeColors.apply(custom, to: baseSpec(dark: dark), dark: dark)
        let base = dark ? BarlyTokens.dark : BarlyTokens.light
        let canvas = Color(hex: s.canvas), sidebar = Color(hex: s.sidebar), surface = Color(hex: s.surface)
        let border = Color(hex: s.border), accent = Color(hex: s.accent)
        let lift: Color = dark ? .white : .black
        let accentFg: Color = Self.contrastWithWhite(s.accent) >= 3 ? .white : .black   // 白字够 3:1（按钮是粗体）就白字
        let accentHover = accent.barlyMix(lift, 0.12)
        return base.replacing([
            .bg: sidebar, .sidebarBg: sidebar, .canvas: canvas, .slot: surface,
            .bgSubtle: canvas.barlyMix(surface, 0.5), .bgMuted: surface,
            .surface: surface, .surfaceRaised: surface.barlyMix(lift, 0.04), .surfaceTop: surface.barlyMix(lift, 0.08),
            .border: border, .borderStrong: border.barlyMix(lift, 0.12), .divider: border,
            .text: Color(hex: s.text), .text2: Color(hex: s.text2), .text3: Color(hex: s.text3), .text4: Color(hex: s.text4),
            .headline2: Color(hex: s.text3),
            .accent: accent, .accentHover: accentHover, .accentFg: accentFg, .accentText: accent,
            .accentSoft: canvas.barlyMix(accent, 0.15), .accentSoftFg: accent,
            .accentGradientFrom: accentHover, .accentGradientTo: accent,
            .cta: accent, .ctaFg: accentFg, .ctaHover: accentHover,
            .primary: accent, .primaryFg: accentFg,
            .selectedBg: surface.barlyMix(lift, 0.06), .selectedFg: Color(hex: s.text), .selectedBorder: border, .selectedMark: accent,
        ])
    }

    /// 和白色的 WCAG 对比度
    static func contrastWithWhite(_ hex: UInt32) -> Double {
        func channel(_ v: UInt32) -> Double {
            let c = Double(v) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let l = 0.2126 * channel((hex >> 16) & 0xFF) + 0.7152 * channel((hex >> 8) & 0xFF) + 0.0722 * channel(hex & 0xFF)
        return 1.05 / (l + 0.05)
    }

    /// 当前设置：主题 + 明暗（system 跟随系统）
    public static var current: AppTheme { current(.standard) }

    /// 存的是已经删掉的主题（老版本的 GitHub、Atom One 之类）：当没设过，用 Switchboard
    public static func current(_ defaults: UserDefaults) -> AppTheme {
        AppTheme(rawValue: defaults.string(forKey: "appTheme") ?? "") ?? .switchboard
    }
}

/// 「外观」设置：light / dark / system。外壳的 @AppStorage、终端、AppKit 面板读同一个默认值，
/// 不然没动过设置时外壳是深色、终端却跟着浅色的系统走
public enum AppAppearance {
    public static let defaultsKey = "appearance"
    public static let defaultValue = "dark"

    public static func current(_ defaults: UserDefaults = .standard) -> String { defaults.string(forKey: defaultsKey) ?? defaultValue }

    /// nil = 跟随系统
    public static func isDark(_ value: String) -> Bool? {
        switch value { case "light": false; case "dark": true; default: nil }
    }

    /// 外壳、终端、窗口外观都按这一条定明暗：设了浅 / 深就照设置，跟随系统才看 macOS
    public static func resolveDark(_ value: String, systemDark: Bool) -> Bool { isDark(value) ?? systemDark }

    /// macOS 本身是不是深色：读全局设置，不看 app 的外观（窗口被设成深色时 NSApp 的外观不一定还是系统的）
    public static func systemIsDark(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.string(forKey: "AppleInterfaceStyle") == "Dark"
    }
}

/// 根视图用：按设置里的主题给整棵视图换色板。
/// 明暗按「外观」设置定（跟随系统才看外面传进来的 colorScheme），再把结果写回 colorScheme：
/// 主窗口里 preferredColorScheme 不一定传得到（实测设深色、系统浅色时侧栏仍是浅色，终端却是深色），不能靠它
public struct ThemedRoot: ViewModifier {
    @AppStorage("appTheme") private var theme = AppTheme.switchboard.rawValue
    @AppStorage(AppAppearance.defaultsKey) private var appearance = AppAppearance.defaultValue
    /// 自定义颜色改了就加一，让色板重算
    @AppStorage(ThemeColors.revisionKey) private var revision = 0
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    public init() {}

    public func body(content: Content) -> some View {
        _ = revision
        let dark = AppAppearance.resolveDark(appearance, systemDark: scheme == .dark)
        var palette = (AppTheme(rawValue: theme) ?? .switchboard).palette(dark: dark)
        if contrast == .increased { palette = AppTheme.raisingContrast(palette ?? (dark ? BarlyTokens.dark : BarlyTokens.light)) }
        return content
            .environment(\.barlyPaletteOverride, palette)
            .environment(\.colorScheme, dark ? .dark : .light)
    }
}

public extension AppTheme {
    /// 系统设置里开了「增强对比度」：次要文字各提一档。时间、数量、路径这些用 text3 / text4 的字在浅色主题上只有 1.4–2.4 : 1
    static func raisingContrast(_ p: BarlyPalette) -> BarlyPalette {
        p.replacing([.text3: p.text2, .text4: p.text3, .headline2: p.text2])
    }
}

public extension View {
    func switchboardTheme() -> some View { modifier(ThemedRoot()) }
}

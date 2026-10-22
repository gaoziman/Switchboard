import SwiftUI
import BarlyKit
#if os(macOS)
import AppKit
#endif

/// App 主题（设置 · 外观）：6 套，各有深色和浅色。Switchboard 是身份本身；其他 5 套只换外壳的底色、文字和边框，
/// 强调色全局只有一个（见 accent(dark:)），代码高亮、图表色、状态色保留身份的。终端配色默认跟着它（见 TerminalScheme）
public enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case switchboard, github, atom, tokyo, catppuccin, gruvbox

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .switchboard: "Switchboard"
        case .github: "GitHub"
        case .atom: "Atom One"
        case .tokyo: "Tokyo Night"
        case .catppuccin: "Catppuccin"
        case .gruvbox: "Gruvbox"
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

    /// 主题的颜色：底色、文字、边框用主题自己的，强调色换成全局那一个
    public func spec(dark: Bool) -> Spec {
        var s = ownSpec(dark: dark)
        s.accent = Self.accent(dark: dark)
        return s
    }

    /// 强调色全局只有一个：就是系统控件（开关、焦点环、设置窗口的标签图标）读的颜色——app 包里的 AccentColor
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

    /// 各主题原本的配色（强调色一栏只是它原来的样子，实际用的是 accent(dark:)）。
    /// Switchboard 是身份本身：石墨底，面板比窗口底亮一档
    private func ownSpec(dark: Bool) -> Spec {
        switch (self, dark) {
        case (.switchboard, true): Spec(canvas: 0x1B1C1F, sidebar: 0x141517, surface: 0x24262A, border: 0x2E3034,
                                        text: 0xECEDEE, text2: 0xA9ABAF, text3: 0x75787D, text4: 0x45484C, accent: 0x19B3A6)
        case (.switchboard, false): Spec(canvas: 0xFFFFFF, sidebar: 0xF2F3F3, surface: 0xF4F5F5, border: 0xE3E6E6,
                                         text: 0x0E1212, text2: 0x565A5B, text3: 0x989C9D, text4: 0xC8CCCC, accent: 0x12A094)
        case (.github, true): Spec(canvas: 0x0D1117, sidebar: 0x010409, surface: 0x161B22, border: 0x30363D,
                                   text: 0xE6EDF3, text2: 0xC9D1D9, text3: 0x8B949E, text4: 0x6E7681, accent: 0x2F81F7)
        case (.github, false): Spec(canvas: 0xFFFFFF, sidebar: 0xF6F8FA, surface: 0xF6F8FA, border: 0xD0D7DE,
                                    text: 0x1F2328, text2: 0x424A53, text3: 0x656D76, text4: 0x8C959F, accent: 0x0969DA)
        case (.atom, true): Spec(canvas: 0x282C34, sidebar: 0x21252B, surface: 0x2C313A, border: 0x3E4451,
                                 text: 0xD7DAE0, text2: 0xABB2BF, text3: 0x7F848E, text4: 0x5C6370, accent: 0x61AFEF)
        case (.atom, false): Spec(canvas: 0xFAFAFA, sidebar: 0xEAEAEB, surface: 0xF0F0F1, border: 0xDBDBDC,
                                  text: 0x383A42, text2: 0x4F525D, text3: 0x696C77, text4: 0xA0A1A7, accent: 0x4078F2)
        case (.tokyo, true): Spec(canvas: 0x1A1B26, sidebar: 0x16161E, surface: 0x1F2335, border: 0x292E42,
                                  text: 0xC0CAF5, text2: 0xA9B1D6, text3: 0x737AA2, text4: 0x565F89, accent: 0x7AA2F7)
        case (.tokyo, false): Spec(canvas: 0xE1E2E7, sidebar: 0xD0D5E3, surface: 0xE9E9ED, border: 0xC4C8DA,
                                   text: 0x343B58, text2: 0x3760BF, text3: 0x6172B0, text4: 0x8990B3, accent: 0x2E7DE9)
        case (.catppuccin, true): Spec(canvas: 0x1E1E2E, sidebar: 0x181825, surface: 0x313244, border: 0x45475A,
                                       text: 0xCDD6F4, text2: 0xBAC2DE, text3: 0x9399B2, text4: 0x6C7086, accent: 0xCBA6F7)
        case (.catppuccin, false): Spec(canvas: 0xEFF1F5, sidebar: 0xE6E9EF, surface: 0xDCE0E8, border: 0xBCC0CC,
                                        text: 0x4C4F69, text2: 0x5C5F77, text3: 0x7C7F93, text4: 0x9CA0B0, accent: 0x8839EF)
        case (.gruvbox, true): Spec(canvas: 0x282828, sidebar: 0x1D2021, surface: 0x32302F, border: 0x504945,
                                    text: 0xEBDBB2, text2: 0xD5C4A1, text3: 0xA89984, text4: 0x7C6F64, accent: 0xFE8019)
        case (.gruvbox, false): Spec(canvas: 0xFBF1C7, sidebar: 0xF2E5BC, surface: 0xEBDBB2, border: 0xD5C4A1,
                                     text: 0x3C3836, text2: 0x504945, text3: 0x7C6F64, text4: 0xA89984, accent: 0xAF3A03)
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
    public static var current: AppTheme { AppTheme(rawValue: UserDefaults.standard.string(forKey: "appTheme") ?? "") ?? .switchboard }
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
}

/// 根视图用：按设置里的主题给整棵视图换色板
public struct ThemedRoot: ViewModifier {
    @AppStorage("appTheme") private var theme = AppTheme.switchboard.rawValue
    /// 自定义颜色改了就加一，让色板重算
    @AppStorage(ThemeColors.revisionKey) private var revision = 0
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    public init() {}

    public func body(content: Content) -> some View {
        _ = revision
        let dark = scheme == .dark
        var palette = (AppTheme(rawValue: theme) ?? .switchboard).palette(dark: dark)
        if contrast == .increased { palette = AppTheme.raisingContrast(palette ?? (dark ? BarlyTokens.dark : BarlyTokens.light)) }
        return content.environment(\.barlyPaletteOverride, palette)
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

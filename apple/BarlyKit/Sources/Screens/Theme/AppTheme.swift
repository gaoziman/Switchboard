import SwiftUI
import BarlyKit

/// App 主题（设置 · 外观）：6 套，各有深色和浅色。Switchboard 是身份本身；其他 5 套只换外壳的底色、文字、
/// 边框和强调色，代码高亮、图表色、状态色保留身份的。终端配色默认跟着它（见 TerminalScheme）
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
        let canvas: UInt32, sidebar: UInt32, surface: UInt32, border: UInt32
        let text: UInt32, text2: UInt32, text3: UInt32, text4: UInt32
        let accent: UInt32
    }

    public func spec(dark: Bool) -> Spec? {
        switch (self, dark) {
        case (.switchboard, _): nil
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
        if let s = spec(dark: dark) { return [Color(hex: s.canvas), Color(hex: s.surface), Color(hex: s.accent)] }
        let p = dark ? BarlyTokens.dark : BarlyTokens.light
        return [p.canvas, p.surface, p.accent]
    }

    /// 这套主题的完整色板（nil = 用身份本身）
    public func palette(dark: Bool) -> BarlyPalette? {
        guard let s = spec(dark: dark) else { return nil }
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

/// 根视图用：按设置里的主题给整棵视图换色板
public struct ThemedRoot: ViewModifier {
    @AppStorage("appTheme") private var theme = AppTheme.switchboard.rawValue
    @Environment(\.colorScheme) private var scheme

    public init() {}

    public func body(content: Content) -> some View {
        content.environment(\.barlyPaletteOverride, (AppTheme(rawValue: theme) ?? .switchboard).palette(dark: scheme == .dark))
    }
}

public extension View {
    func switchboardTheme() -> some View { modifier(ThemedRoot()) }
}

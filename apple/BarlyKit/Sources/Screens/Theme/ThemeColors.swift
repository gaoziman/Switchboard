import SwiftUI
import BarlyKit

/// 自定义颜色：改选中主题的几个颜色，浅色、深色各一套，没改的沿用主题自己的。
/// 存在 UserDefaults 的 themeColors.<主题>.<light|dark>（角色 → 十六进制），换主题再换回来还在
public enum ThemeColorRole: String, CaseIterable, Identifiable, Sendable {
    case canvas, sidebar, surface, text, accent
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .canvas: L("背景")
        case .sidebar: L("侧栏和标签栏")
        case .surface: L("面板、输入框和按钮")
        case .text: L("文字")
        case .accent: L("强调色")
        }
    }
}

public enum ThemeColors {
    public static let revisionKey = "themeColorsRevision"

    static func key(_ theme: AppTheme, dark: Bool) -> String { "themeColors.\(theme.rawValue).\(dark ? "dark" : "light")" }

    public static func changes(_ theme: AppTheme, dark: Bool, defaults: UserDefaults = .standard) -> [ThemeColorRole: UInt32] {
        let raw = defaults.dictionary(forKey: key(theme, dark: dark)) as? [String: String] ?? [:]
        var out: [ThemeColorRole: UInt32] = [:]
        for (k, v) in raw { if let role = ThemeColorRole(rawValue: k), let hex = UInt32(v, radix: 16) { out[role] = hex & 0xFFFFFF } }
        return out
    }

    /// nil = 改回主题自己的
    public static func set(_ hex: UInt32?, for role: ThemeColorRole, theme: AppTheme, dark: Bool, defaults: UserDefaults = .standard) {
        var raw = defaults.dictionary(forKey: key(theme, dark: dark)) as? [String: String] ?? [:]
        raw[role.rawValue] = hex.map { String(format: "%06X", $0 & 0xFFFFFF) }
        defaults.set(raw.isEmpty ? nil : raw, forKey: key(theme, dark: dark))
        defaults.set(defaults.integer(forKey: revisionKey) + 1, forKey: revisionKey)
    }

    public static func reset(_ theme: AppTheme, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key(theme, dark: true))
        defaults.removeObject(forKey: key(theme, dark: false))
        defaults.set(defaults.integer(forKey: revisionKey) + 1, forKey: revisionKey)
    }

    public static func hasChanges(_ theme: AppTheme, defaults: UserDefaults = .standard) -> Bool {
        !changes(theme, dark: true, defaults: defaults).isEmpty || !changes(theme, dark: false, defaults: defaults).isEmpty
    }

    /// 把改动套到主题的颜色上。改了文字，次要文字按它往背景方向调淡；改了背景 / 面板，边框跟着从新颜色推出来
    static func apply(_ c: [ThemeColorRole: UInt32], to base: AppTheme.Spec, dark: Bool) -> AppTheme.Spec {
        guard !c.isEmpty else { return base }
        var s = base
        if let v = c[.canvas] { s.canvas = v }
        if let v = c[.sidebar] { s.sidebar = v }
        if let v = c[.surface] { s.surface = v }
        if let v = c[.accent] { s.accent = v }
        if c[.surface] != nil || c[.canvas] != nil { s.border = mix(s.surface, dark ? 0xFFFFFF : 0x000000, 0.12) }
        if let v = c[.text] {
            s.text = v
            s.text2 = mix(v, s.canvas, 0.25)
            s.text3 = mix(v, s.canvas, 0.45)
            s.text4 = mix(v, s.canvas, 0.65)
        }
        return s
    }

    static func mix(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
        func ch(_ v: UInt32, _ shift: UInt32) -> Double { Double((v >> shift) & 0xFF) }
        func m(_ shift: UInt32) -> UInt32 { UInt32((ch(a, shift) * (1 - t) + ch(b, shift) * t).rounded()) << shift }
        return m(16) | m(8) | m(0)
    }
}

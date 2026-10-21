import Foundation
#if os(macOS)
import AppKit
#endif

/// 终端配色：背景、前景、16 色。默认跟着 app 主题；也可以单独选一套，或从 iTerm2 导入
public struct TerminalColors: Codable, Equatable, Sendable {
    public var background: UInt32
    public var foreground: UInt32
    public var ansi: [UInt32]   // 16 个

    public static let schemeChoices: [(id: String, title: String)] = [("app", L("跟随 App 主题"))]
        + AppTheme.allCases.map { ($0.rawValue, $0.title) } + [("dracula", "Dracula"), ("nord", "Nord"), ("iterm", L("iTerm2 导入的配色"))]

    /// 设置里选的配色 + 明暗；app 主题的底色给 Switchboard 用
    public static func resolve(scheme: String, appTheme: AppTheme, dark: Bool, appCanvas: UInt32, appText: UInt32) -> TerminalColors {
        switch scheme {
        case "dracula": return dracula
        case "nord": return nord
        case "iterm": return imported ?? themed(appTheme, dark: dark, canvas: appCanvas, text: appText)
        default:
            let theme = scheme == "app" ? appTheme : (AppTheme(rawValue: scheme) ?? appTheme)
            return themed(theme, dark: dark, canvas: appCanvas, text: appText)
        }
    }

    static func themed(_ theme: AppTheme, dark: Bool, canvas: UInt32, text: UInt32) -> TerminalColors {
        let spec = theme.spec(dark: dark)
        let bg = spec?.canvas ?? canvas, fg = spec?.text ?? text
        let ansi: [UInt32] = switch (theme, dark) {
        case (.switchboard, true): [0x1E1F22, 0xE5664A, 0x5FB86F, 0xE0A84A, 0x5B8DEF, 0xB07BE0, 0x4FB3B3, 0xC9CCD1,
                                    0x5A5D63, 0xF27A5E, 0x77CC85, 0xF0BE62, 0x7AA5F5, 0xC495EC, 0x6CCACA, 0xF2F3F5]
        case (.switchboard, false): [0x2A2B2E, 0xC4432B, 0x2F8A43, 0x9A6A12, 0x2F63C9, 0x8247B8, 0x1F7F80, 0x8A8D93,
                                     0x5A5D63, 0xD9553A, 0x3A9E51, 0xB07D1E, 0x3F73D9, 0x9558C9, 0x2C9293, 0xB4B7BC]
        case (.github, true): [0x484F58, 0xFF7B72, 0x3FB950, 0xD29922, 0x58A6FF, 0xBC8CFF, 0x39C5CF, 0xB1BAC4,
                               0x6E7681, 0xFFA198, 0x56D364, 0xE3B341, 0x79C0FF, 0xD2A8FF, 0x56D4DD, 0xF0F6FC]
        case (.github, false): [0x24292F, 0xCF222E, 0x116329, 0x4D2D00, 0x0969DA, 0x8250DF, 0x1B7C83, 0x6E7781,
                                0x57606A, 0xA40E26, 0x1A7F37, 0x633C01, 0x218BFF, 0xA475F9, 0x3192AA, 0x8C959F]
        case (.atom, true): [0x282C34, 0xE06C75, 0x98C379, 0xE5C07B, 0x61AFEF, 0xC678DD, 0x56B6C2, 0xABB2BF,
                             0x5C6370, 0xE06C75, 0x98C379, 0xE5C07B, 0x61AFEF, 0xC678DD, 0x56B6C2, 0xFFFFFF]
        case (.atom, false): [0x383A42, 0xE45649, 0x50A14F, 0xC18401, 0x4078F2, 0xA626A4, 0x0184BC, 0xA0A1A7,
                              0x696C77, 0xE45649, 0x50A14F, 0xC18401, 0x4078F2, 0xA626A4, 0x0184BC, 0x383A42]
        case (.tokyo, true): [0x15161E, 0xF7768E, 0x9ECE6A, 0xE0AF68, 0x7AA2F7, 0xBB9AF7, 0x7DCFFF, 0xA9B1D6,
                              0x414868, 0xF7768E, 0x9ECE6A, 0xE0AF68, 0x7AA2F7, 0xBB9AF7, 0x7DCFFF, 0xC0CAF5]
        case (.tokyo, false): [0x343B58, 0xF52A65, 0x587539, 0x8C6C3E, 0x2E7DE9, 0x9854F1, 0x007197, 0x6172B0,
                               0xA1A6C5, 0xF52A65, 0x587539, 0x8C6C3E, 0x2E7DE9, 0x9854F1, 0x007197, 0x3760BF]
        case (.catppuccin, true): [0x45475A, 0xF38BA8, 0xA6E3A1, 0xF9E2AF, 0x89B4FA, 0xF5C2E7, 0x94E2D5, 0xBAC2DE,
                                   0x585B70, 0xF38BA8, 0xA6E3A1, 0xF9E2AF, 0x89B4FA, 0xF5C2E7, 0x94E2D5, 0xA6ADC8]
        case (.catppuccin, false): [0x5C5F77, 0xD20F39, 0x40A02B, 0xDF8E1D, 0x1E66F5, 0xEA76CB, 0x179299, 0xACB0BE,
                                    0x6C6F85, 0xD20F39, 0x40A02B, 0xDF8E1D, 0x1E66F5, 0xEA76CB, 0x179299, 0xBCC0CC]
        case (.gruvbox, true): [0x282828, 0xCC241D, 0x98971A, 0xD79921, 0x458588, 0xB16286, 0x689D6A, 0xA89984,
                                0x928374, 0xFB4934, 0xB8BB26, 0xFABD2F, 0x83A598, 0xD3869B, 0x8EC07C, 0xEBDBB2]
        case (.gruvbox, false): [0xFBF1C7, 0xCC241D, 0x98971A, 0xD79921, 0x458588, 0xB16286, 0x689D6A, 0x7C6F64,
                                 0x928374, 0x9D0006, 0x79740E, 0xB57614, 0x076678, 0x8F3F71, 0x427B58, 0x3C3836]
        }
        return TerminalColors(background: bg, foreground: fg, ansi: ansi)
    }

    static let dracula = TerminalColors(background: 0x282A36, foreground: 0xF8F8F2, ansi: [
        0x21222C, 0xFF5555, 0x50FA7B, 0xF1FA8C, 0xBD93F9, 0xFF79C6, 0x8BE9FD, 0xF8F8F2,
        0x6272A4, 0xFF6E6E, 0x69FF94, 0xFFFFA5, 0xD6ACFF, 0xFF92DF, 0xA4FFFF, 0xFFFFFF])

    static let nord = TerminalColors(background: 0x2E3440, foreground: 0xD8DEE9, ansi: [
        0x3B4252, 0xBF616A, 0xA3BE8C, 0xEBCB8B, 0x81A1C1, 0xB48EAD, 0x88C0D0, 0xE5E9F0,
        0x4C566A, 0xBF616A, 0xA3BE8C, 0xEBCB8B, 0x81A1C1, 0xB48EAD, 0x8FBCBB, 0xECEFF4])

    // MARK: 色彩强度

    /// 16 色按强度调饱和度（亮度不变，字一样好认）；1.0 = 原样
    public func intensified(_ k: Double) -> TerminalColors {
        guard abs(k - 1) > 0.01 else { return self }
        var out = self
        out.ansi = ansi.map { Self.scaleSaturation($0, k) }
        return out
    }

    static func scaleSaturation(_ hex: UInt32, _ k: Double) -> UInt32 {
        var r = Double((hex >> 16) & 0xFF) / 255, g = Double((hex >> 8) & 0xFF) / 255, b = Double(hex & 0xFF) / 255
        let gray = 0.299 * r + 0.587 * g + 0.114 * b   // 亮度不变：围绕灰度点拉伸
        r = min(1, max(0, gray + (r - gray) * k))
        g = min(1, max(0, gray + (g - gray) * k))
        b = min(1, max(0, gray + (b - gray) * k))
        return (UInt32((r * 255).rounded()) << 16) | (UInt32((g * 255).rounded()) << 8) | UInt32((b * 255).rounded())
    }

    // MARK: iTerm2 导入

    /// 存在 UserDefaults「itermScheme」里
    public static var imported: TerminalColors? {
        guard let data = UserDefaults.standard.data(forKey: "itermScheme") else { return nil }
        return try? JSONDecoder().decode(TerminalColors.self, from: data)
    }

    /// 读 .itermcolors（plist：Ansi 0–15 Color、Background Color、Foreground Color，分量 0–1）
    public static func parseITermColors(_ data: Data) -> TerminalColors? {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return nil }
        func color(_ key: String) -> UInt32? {
            guard let d = plist[key] as? [String: Any],
                  let r = d["Red Component"] as? Double, let g = d["Green Component"] as? Double, let b = d["Blue Component"] as? Double
            else { return nil }
            return (UInt32((r * 255).rounded()) << 16) | (UInt32((g * 255).rounded()) << 8) | UInt32((b * 255).rounded())
        }
        let ansi = (0..<16).compactMap { color("Ansi \($0) Color") }
        guard ansi.count == 16, let bg = color("Background Color"), let fg = color("Foreground Color") else { return nil }
        return TerminalColors(background: bg, foreground: fg, ansi: ansi)
    }

    public static func saveImported(_ colors: TerminalColors) {
        if let data = try? JSONEncoder().encode(colors) { UserDefaults.standard.set(data, forKey: "itermScheme") }
    }
}

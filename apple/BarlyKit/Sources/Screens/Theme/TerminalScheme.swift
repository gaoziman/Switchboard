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
        // Switchboard 用 app 色板的底色和字色（含设置里改过的颜色），别的主题用它自己的
        let spec = theme.spec(dark: dark)
        let bg = theme == .switchboard ? canvas : spec.canvas, fg = theme == .switchboard ? text : spec.text
        let ansi: [UInt32] = switch (theme, dark) {
        case (.switchboard, true): [0x1E1F22, 0xE5664A, 0x5FB86F, 0xE0A84A, 0x5B8DEF, 0xB07BE0, 0x4FB3B3, 0xC9CCD1,
                                    0x5A5D63, 0xF27A5E, 0x77CC85, 0xF0BE62, 0x7AA5F5, 0xC495EC, 0x6CCACA, 0xF2F3F5]
        case (.switchboard, false): [0x2A2B2E, 0xC4432B, 0x2F8A43, 0x9A6A12, 0x2F63C9, 0x8247B8, 0x1F7F80, 0x8A8D93,
                                     0x5A5D63, 0xD9553A, 0x3A9E51, 0xB07D1E, 0x3F73D9, 0x9558C9, 0x2C9293, 0xB4B7BC]
        case (.bamboo, true): [0x262E2A, 0xDB8976, 0x76DB90, 0xDBC576, 0x76AADB, 0xBE76DB, 0x76D5DB, 0xB9C0BD,
                    0x545A57, 0xEAA999, 0x99EAAF, 0xEAD999, 0x99C3EA, 0xD399EA, 0x99E6EA, 0xE7E9E8]
        case (.bamboo, false): [0x1C211F, 0xA53F27, 0x27A548, 0xA58B27, 0x2768A5, 0x8127A5, 0x279EA5, 0x7E8B85,
                    0x4C5752, 0xC24A2E, 0x2EC255, 0xC2A32E, 0x2E7BC2, 0x982EC2, 0x2EBAC2, 0xB7BDBA]
        case (.xuan, true): [0x2F2B25, 0xDB8076, 0x76DB87, 0xDBBC76, 0x76B4DB, 0xD376DB, 0x76DBD7, 0xC1BEB9,
                    0x5A5853, 0xEAA199, 0x99EAA7, 0xEAD299, 0x99CBEA, 0xE499EA, 0x99EAE7, 0xEAE8E6]
        case (.xuan, false): [0x221F1B, 0xA53327, 0x27A53C, 0xA57F27, 0x2774A5, 0x9C27A5, 0x27A5A0, 0x8C877D,
                    0x58534B, 0xC23C2E, 0x2EC247, 0xC2952E, 0x2E88C2, 0xB72EC2, 0x2EC2BC, 0xBDBBB7]
        case (.mist, true): [0x252B2F, 0xDB767D, 0x76DB95, 0xDBCA76, 0x76A6DB, 0xC376DB, 0x76D1DB, 0xB9BDC1,
                    0x53575A, 0xEA999F, 0x99EAB2, 0xEADD99, 0x99C0EA, 0xD799EA, 0x99E2EA, 0xE6E8EA]
        case (.mist, false): [0x1B1F22, 0xA5272F, 0x27A54E, 0xA59027, 0x2763A5, 0x8727A5, 0x2799A5, 0x7D868C,
                    0x4B5358, 0xC22E37, 0x2EC25B, 0xC2AA2E, 0x2E74C2, 0x9F2EC2, 0x2EB3C2, 0xB7BBBD]
        case (.amber, true): [0x2D2A27, 0xDB7F76, 0x76DB86, 0xDBBB76, 0x7696DB, 0xD276DB, 0x76DBD6, 0xBFBDBA,
                    0x595754, 0xEAA199, 0x99EAA7, 0xEAD199, 0x99B3EA, 0xE399EA, 0x99EAE6, 0xE9E8E7]
        case (.amber, false): [0x211F1C, 0xA53227, 0x27A53B, 0xA57E27, 0x274FA5, 0x9B27A5, 0x27A59F, 0x898580,
                    0x56524D, 0xC23B2E, 0x2EC246, 0xC2942E, 0x2E5DC2, 0xB62EC2, 0x2EC2BB, 0xBCBAB8]
        case (.moss, true): [0x2B2F25, 0xDB8476, 0x76DB8B, 0xDBC076, 0x76B0DB, 0xD776DB, 0x76DBDB, 0xBDC1B9,
                    0x575A53, 0xEAA499, 0x99EAAA, 0xEAD599, 0x99C8EA, 0xE799EA, 0x99EAEA, 0xE8EAE6]
        case (.moss, false): [0x1F221B, 0xA53827, 0x27A541, 0xA58427, 0x276FA5, 0xA027A5, 0x27A5A5, 0x868C7D,
                    0x53584B, 0xC2412E, 0x2EC24D, 0xC29B2E, 0x2E83C2, 0xBD2EC2, 0x2EC2C2, 0xBBBDB7]
        case (.polar, true): [0x262B2E, 0xDB767D, 0x76DB95, 0xDBCA76, 0x76A6DB, 0xC276DB, 0x76D1DB, 0xB9BEC0,
                    0x54585A, 0xEA999F, 0x99EAB2, 0xEADD99, 0x99C0EA, 0xD799EA, 0x99E2EA, 0xE7E9E9]
        case (.polar, false): [0x1C2021, 0xA52730, 0x27A54D, 0xA59027, 0x2763A5, 0x8727A5, 0x2799A5, 0x7E878B,
                    0x4C5457, 0xC22E38, 0x2EC25B, 0xC2A92E, 0x2E74C2, 0x9E2EC2, 0x2EB4C2, 0xB7BBBD]
        case (.dune, true): [0x312B23, 0xDB7F76, 0x76DB87, 0xDBBC76, 0x76B4DB, 0xD376DB, 0x76DBD6, 0xC2BEB7,
                    0x5C5852, 0xEAA199, 0x99EAA7, 0xEAD199, 0x99CBEA, 0xE499EA, 0x99EAE7, 0xEAE8E6]
        case (.dune, false): [0x231F1A, 0xA53227, 0x27A53C, 0xA57F27, 0x2774A5, 0x9B27A5, 0x27A5A0, 0x8E867B,
                    0x5B5348, 0xC23B2E, 0x2EC246, 0xC2952E, 0x2E89C2, 0xB62EC2, 0x2EC2BC, 0xBFBBB6]
        case (.celadon, true): [0x24302D, 0xDB8A76, 0x76DB92, 0xDBC776, 0x76A9DB, 0xBF76DB, 0x76D4DB, 0xB8C1BF,
                    0x525B59, 0xEAAA99, 0x99EAB0, 0xEADA99, 0x99C2EA, 0xD499EA, 0x99E5EA, 0xE6EAE9]
        case (.celadon, false): [0x1B2221, 0xA54027, 0x27A54A, 0xA58C27, 0x2767A5, 0x8327A5, 0x279DA5, 0x7C8D89,
                    0x4A5A56, 0xC24B2E, 0x2EC256, 0xC2A52E, 0x2E79C2, 0x9A2EC2, 0x2EB8C2, 0xB6BEBC]
        case (.verdigris, true): [0x223232, 0xDB8B76, 0x76DB93, 0xDBC876, 0x76A8DB, 0xC176DB, 0x76D3DB, 0xB6C3C3,
                    0x515D5D, 0xEAAB99, 0x99EAB1, 0xEADB99, 0x99C1EA, 0xD599EA, 0x99E4EA, 0xE5EBEB]
        case (.verdigris, false): [0x192424, 0xA54227, 0x27A54B, 0xA58E27, 0x2765A5, 0x8527A5, 0x279BA5, 0x789191,
                    0x465D5D, 0xC24D2E, 0x2EC258, 0xC2A72E, 0x2E77C2, 0x9C2EC2, 0x2EB6C2, 0xB5C0C0]
        case (.slate, true): [0x26292E, 0xDB767B, 0x76DB96, 0xDBCB76, 0x76A4DB, 0xC476DB, 0x76CFDB, 0xB9BCC0,
                    0x54565A, 0xEA999E, 0x99EAB3, 0xEADE99, 0x99BFEA, 0xD899EA, 0x99E1EA, 0xE7E8E9]
        case (.slate, false): [0x1C1E21, 0xA5272E, 0x27A54F, 0xA59227, 0x2761A5, 0x8927A5, 0x2797A5, 0x7E838B,
                    0x4C5057, 0xC22E35, 0x2EC25D, 0xC2AC2E, 0x2E72C2, 0xA12EC2, 0x2EB1C2, 0xB7B9BD]
        case (.mono, true): [0x2A2A2A, 0xDB7C76, 0x76DB84, 0xDBB976, 0x7699DB, 0xD076DB, 0x76C4DB, 0xBDBDBD,
                    0x575757, 0xEA9F99, 0x99EAA5, 0xEACF99, 0x99B5EA, 0xE199EA, 0x99D8EA, 0xE8E8E8]
        case (.mono, false): [0x1F1F1F, 0xA52F27, 0x27A538, 0xA57B27, 0x2752A5, 0x9827A5, 0x2788A5, 0x858585,
                    0x525252, 0xC2372E, 0x2EC242, 0xC2902E, 0x2E61C2, 0xB22EC2, 0x2EA0C2, 0xBABABA]
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

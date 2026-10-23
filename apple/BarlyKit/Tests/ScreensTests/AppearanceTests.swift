import Foundation
import SwiftUI
import Testing
import BarlyKit
@testable import Screens

@Suite struct ThemeColorsTests {
    func defaults() -> UserDefaults { UserDefaults(suiteName: "sb-colors-\(UUID().uuidString)")! }

    @Test func untouchedThemeKeepsItsColors() {
        let base = AppTheme.bamboo.baseSpec(dark: true)
        let s = ThemeColors.apply([:], to: base, dark: true)
        #expect(s.canvas == base.canvas && s.text3 == base.text3 && s.accent == base.accent)
    }

    @Test func changesAreSeparatePerVersionAndTheme() {
        let d = defaults()
        ThemeColors.set(0x112233, for: .accent, theme: .bamboo, dark: true, defaults: d)
        #expect(ThemeColors.changes(.bamboo, dark: true, defaults: d) == [.accent: 0x112233])
        #expect(ThemeColors.changes(.bamboo, dark: false, defaults: d).isEmpty)
        #expect(ThemeColors.changes(.xuan, dark: true, defaults: d).isEmpty)
        ThemeColors.set(nil, for: .accent, theme: .bamboo, dark: true, defaults: d)
        #expect(!ThemeColors.hasChanges(.bamboo, defaults: d))
    }

    @Test func resetClearsBothVersions() {
        let d = defaults()
        ThemeColors.set(0xFFFFFF, for: .canvas, theme: .mist, dark: true, defaults: d)
        ThemeColors.set(0x000000, for: .text, theme: .mist, dark: false, defaults: d)
        let before = d.integer(forKey: ThemeColors.revisionKey)
        ThemeColors.reset(.mist, defaults: d)
        #expect(!ThemeColors.hasChanges(.mist, defaults: d))
        #expect(d.integer(forKey: ThemeColors.revisionKey) > before)
    }

    @Test func textChangeDerivesSecondaryShades() {
        let base = AppTheme.switchboard.baseSpec(dark: true)
        let s = ThemeColors.apply([.text: 0xFFFFFF], to: base, dark: true)
        #expect(s.text == 0xFFFFFF)
        // 次要文字介于新文字和背景之间，越往后越淡
        func lum(_ v: UInt32) -> UInt32 { (v >> 16) & 0xFF }
        #expect(lum(s.text) > lum(s.text2) && lum(s.text2) > lum(s.text3) && lum(s.text3) > lum(s.text4) && lum(s.text4) > lum(s.canvas))
    }

    @Test func mixIsLinearPerChannel() {
        #expect(ThemeColors.mix(0x000000, 0xFFFFFF, 0.5) == 0x808080)
        #expect(ThemeColors.mix(0xFF0000, 0x0000FF, 0) == 0xFF0000)
    }
}

@Suite struct InterfaceScaleTests {
    @Test func scalesSizeAndAbsoluteLineHeight() {
        let style = BarlyTextStyle(size: 13, lineHeight: 20, weight: 400, tracking: 0, upper: false, mono: false)
        let big = style.scaled(1.5)
        #expect(big.size == 19.5 && big.lineHeight == 30)
        // 相对行高（倍数）不用改
        let relative = BarlyTextStyle(size: 14, lineHeight: 1.4, weight: 400, tracking: 0, upper: false, mono: false).scaled(1.2)
        #expect(relative.lineHeight == 1.4)
        #expect(style.scaled(1) == style)
    }
}

@MainActor
@Suite struct AppearanceDefaultTests {
    @Test("没动过「外观」设置时，终端和外壳用同一个默认值（外壳深色，终端也深色）")
    func terminalFollowsShellDefault() {
        let untouched = UserDefaults(suiteName: "sb-appearance-\(UUID().uuidString)")!
        let dark = UserDefaults(suiteName: "sb-appearance-\(UUID().uuidString)")!
        dark.set("dark", forKey: AppAppearance.defaultsKey)
        #expect(AppAppearance.current(untouched) == AppAppearance.defaultValue)
        #expect(AppAppearance.isDark(AppAppearance.defaultValue) == true)
        #expect(TerminalStyle.current(defaults: untouched).key == TerminalStyle.current(defaults: dark).key)
    }
}

@Suite struct AppearanceResolveTests {
    @Test("外壳和终端用同一条规则定明暗：设了浅 / 深就照设置，跟随系统才看 macOS")
    func sixCombinations() {
        #expect(AppAppearance.resolveDark("dark", systemDark: false) == true)
        #expect(AppAppearance.resolveDark("dark", systemDark: true) == true)
        #expect(AppAppearance.resolveDark("light", systemDark: false) == false)
        #expect(AppAppearance.resolveDark("light", systemDark: true) == false)
        #expect(AppAppearance.resolveDark("system", systemDark: false) == false)
        #expect(AppAppearance.resolveDark("system", systemDark: true) == true)
    }

    @Test("系统明暗按全局设置读（不看 app 自己的外观，app 被设成深色时也读得到系统是浅色）")
    func systemFromGlobalDefaults() {
        let d = UserDefaults(suiteName: "sb-sys-\(UUID().uuidString)")!
        #expect(AppAppearance.systemIsDark(d) == false)
        d.set("Dark", forKey: "AppleInterfaceStyle")
        #expect(AppAppearance.systemIsDark(d) == true)
    }
}

@Suite struct IncreasedContrastTests {
    @Test("系统开了「增强对比度」：次要文字各提一档（text4 → text3，text3 → text2）")
    func raisesSecondaryText() {
        for dark in [false, true] {
            let p = AppTheme.switchboard.palette(dark: dark) ?? (dark ? BarlyTokens.dark : BarlyTokens.light)
            let raised = AppTheme.raisingContrast(p)
            #expect(raised.text4 == p.text3 && raised.text3 == p.text2)
            #expect(raised.text == p.text && raised.text2 == p.text2 && raised.canvas == p.canvas)
        }
    }
}

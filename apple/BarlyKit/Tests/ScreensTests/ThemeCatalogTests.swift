import Foundation
import SwiftUI
import Testing
import BarlyKit
@testable import Screens

/// 主题清单：Switchboard + 11 套新主题，各有浅色和深色、自己的强调色和终端 16 色
@Suite("主题")
struct ThemeCatalogTests {
    private func luminance(_ hex: UInt32) -> Double {
        func ch(_ v: UInt32) -> Double { let c = Double(v) / 255; return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * ch((hex >> 16) & 0xFF) + 0.7152 * ch((hex >> 8) & 0xFF) + 0.0722 * ch(hex & 0xFF)
    }
    private func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    @Test("12 套：Switchboard 在最前；删掉的主题读到时退回 Switchboard")
    func catalog() {
        #expect(AppTheme.allCases.count == 12)
        #expect(AppTheme.allCases.first == .switchboard)
        for removed in ["github", "atom", "tokyo", "catppuccin", "gruvbox", "noir", "dusk", "oled", "abyss", "sakura", "terracotta"] {
            #expect(AppTheme(rawValue: removed) == nil)
        }
        let d = UserDefaults(suiteName: "sb-theme-\(UUID().uuidString)")!
        d.set("atom", forKey: "appTheme")
        #expect(AppTheme.current(d) == .switchboard)
    }

    @Test("新主题用自己的强调色；Switchboard 仍用全局那一个")
    func ownAccent() {
        #expect(AppTheme.amber.spec(dark: true).accent == 0xF0A63A)
        #expect(AppTheme.xuan.spec(dark: false).accent == 0xC23B2A)
        #expect(AppTheme.switchboard.spec(dark: true).accent == AppTheme.accent(dark: true))
    }

    @Test("每套每个明暗：正文对比 ≥ 7，次要文字 ≥ 4.5")
    func readable() {
        for theme in AppTheme.allCases {
            for dark in [false, true] {
                let s = theme.spec(dark: dark)
                #expect(contrast(s.text, s.canvas) >= 7, "\(theme) \(dark ? "深" : "浅") 正文")
                #expect(contrast(s.text2, s.canvas) >= 4.5, "\(theme) \(dark ? "深" : "浅") 次要文字")
            }
        }
    }

    @Test("终端配色：每套每个明暗都是 16 色，底色和字色取主题的")
    func terminal() {
        for theme in AppTheme.allCases where theme != .switchboard {
            for dark in [false, true] {
                let c = TerminalColors.themed(theme, dark: dark, canvas: 0, text: 0)
                #expect(c.ansi.count == 16)
                #expect(c.background == theme.spec(dark: dark).canvas)
            }
        }
    }

    @Test("组色避开当前主题的强调色（色相差 ≥ 40°），组头不会被看成状态灯")
    func groupColorsAvoidAccent() {
        for theme in AppTheme.allCases {
            for dark in [false, true] {
                guard let p = theme.palette(dark: dark), let accent = GroupColors.hue(of: p.accent) else { continue }
                for tint in 0..<GroupColors.count(avoiding: p.accent, dark: dark) {
                    let hue = GroupColors.hue(of: p.groupColor(tint))!
                    let d = abs(((hue - accent) + 540).truncatingRemainder(dividingBy: 360) - 180)
                    #expect(d >= 40, "\(theme) \(dark) 组色 \(tint)")
                }
            }
        }
    }
}

import Foundation
import SwiftUI
import Testing
@testable import Screens
@testable import BarlyKit

@Suite("主题与终端配色")
struct ThemeTests {
    @Test("每套主题的深浅两版都能出色板")
    func palettes() {
        for theme in AppTheme.allCases {
            for dark in [true, false] {
                #expect(theme.palette(dark: dark) != nil, "\(theme) \(dark)")
                #expect(theme.swatch(dark: dark).count == 3)
            }
        }
    }

    @Test("每套主题：窗口底比面板暗（面板浮在上面）")
    func panelsFloat() {
        let luma = { (c: UInt32) in Double((c >> 16) & 0xFF) * 0.299 + Double((c >> 8) & 0xFF) * 0.587 + Double(c & 0xFF) * 0.114 }
        for theme in AppTheme.allCases {
            for d in [true, false] {
                let s = theme.spec(dark: d)
                #expect(luma(s.sidebar) < luma(s.canvas), "\(theme) \(d)")
            }
        }
    }

    @Test("每套都有 16 色；终端底色跟主题")
    func schemes() {
        for theme in AppTheme.allCases {
            for dark in [true, false] {
                let c = TerminalColors.themed(theme, dark: dark, canvas: 0x111111, text: 0xEEEEEE)
                #expect(c.ansi.count == 16)
                // Switchboard 跟着 app 色板（含改过的颜色），别的主题用自己的底色
                #expect(c.background == (theme == .switchboard ? 0x111111 : theme.spec(dark: dark).canvas))
            }
        }
        #expect(TerminalColors.resolve(scheme: "dracula", appTheme: .bamboo, dark: false, appCanvas: 0, appText: 0).background == 0x282A36)
        #expect(TerminalColors.resolve(scheme: "app", appTheme: .amber, dark: true, appCanvas: 0, appText: 0).background == AppTheme.amber.spec(dark: true).canvas)
        #expect(TerminalColors.resolve(scheme: "mist", appTheme: .bamboo, dark: true, appCanvas: 0, appText: 0).background == AppTheme.mist.spec(dark: true).canvas)
    }

    @Test("色彩强度：100% 原样；灰色不变；更强 = 离灰更远")
    func intensity() {
        let c = TerminalColors(background: 0, foreground: 0, ansi: Array(repeating: 0x808080, count: 15) + [0xCC4444])
        #expect(c.intensified(1).ansi == c.ansi)
        let strong = c.intensified(1.5)
        #expect(strong.ansi[0] == 0x808080)
        #expect(((strong.ansi[15] >> 16) & 0xFF) > 0xCC)
        let soft = c.intensified(0.5)
        #expect(((soft.ansi[15] >> 16) & 0xFF) < 0xCC)
    }

    @Test("读 iTerm2 配色")
    func iterm() throws {
        func comp(_ r: Double, _ g: Double, _ b: Double) -> [String: Any] { ["Red Component": r, "Green Component": g, "Blue Component": b] }
        var plist: [String: Any] = ["Background Color": comp(0, 0, 0), "Foreground Color": comp(1, 1, 1)]
        for i in 0..<16 { plist["Ansi \(i) Color"] = comp(Double(i) / 15, 0, 0) }
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let c = TerminalColors.parseITermColors(data)
        #expect(c?.background == 0x000000)
        #expect(c?.foreground == 0xFFFFFF)
        #expect(c?.ansi.count == 16)
        #expect(c?.ansi[15] == 0xFF0000)
        plist["Ansi 3 Color"] = nil
        #expect(TerminalColors.parseITermColors(try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)) == nil)
    }
}

@MainActor
@Suite("分屏")
struct SplitTests {
    @Test func swapAndClose() {
        let s = WorkspaceStore.fixture("split")
        let split = s.split!
        s.swapSplit()
        #expect(s.split?.left == split.right)
        #expect(s.split?.right == split.left)
        #expect(abs((s.split?.ratio ?? 0) - (1 - split.ratio)) < 0.0001)
        s.closeSplitSide(split.left)
        #expect(s.split == nil)
        #expect(s.selectedTab?.id == split.right)
    }

    @Test("开分屏：当前标签在左，右边先选；选了之后两边都显示")
    func start() {
        let s = WorkspaceStore.fixture("default")
        s.split = nil
        let current = s.selectedTab!.id
        s.startSplit()
        #expect(s.split?.left == current && s.split?.right == nil)
        let pick = s.splitCandidates.first!
        s.fillSplit(with: pick)
        #expect(s.activeSplit?.right == pick.id)
    }
}

@Suite("按钮字色")
struct ContrastTests {
    @Test func picks() {
        #expect(AppTheme.contrastWithWhite(0x2F81F7) >= 3)   // GitHub 蓝：白字
        #expect(AppTheme.contrastWithWhite(0x7AA2F7) < 3)    // Tokyo 浅蓝：黑字
        #expect(AppTheme.contrastWithWhite(0xFE8019) < 3)    // Gruvbox 橙：黑字
        #expect(AppTheme.contrastWithWhite(0x0969DA) >= 4.5) // GitHub 浅色版蓝：白字
    }
}

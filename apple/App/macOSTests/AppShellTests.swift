import SwiftUI
import Testing
import Screens
@testable import Switchboard

/// 外壳自己的逻辑（业务逻辑的单测在 BarlyKit 包的 ScreensTests 里）
struct AppShellTests {
    @Test("「外观」设置 → 配色方案；跟随系统是 nil")
    func appearanceScheme() {
        #expect(barlyScheme("light") == .light)
        #expect(barlyScheme("dark") == .dark)
        #expect(barlyScheme("system") == nil)
        #expect(barlyScheme(AppAppearance.defaultValue) == .dark)
    }
}

import CoreGraphics
import Testing
@testable import Screens

/// 首启引导：说明卡放在讲到的那块旁边，跟着真实位置走，不出窗口
@Suite("首启引导的位置")
struct TourLayoutTests {
    let card = CGSize(width: 320, height: 180)
    let window = CGSize(width: 1440, height: 900)

    @Test("放在右边，和讲到的那块顶端对齐")
    func rightOfSpot() {
        let origin = TourLayout.cardOrigin(spot: CGRect(x: 6, y: 92, width: 276, height: 600), card: card, in: window)
        #expect(origin == CGPoint(x: 6 + 276 + 28, y: 92 + 58))
    }

    @Test("底下那块：卡往上挪，不出窗口底边")
    func clampedToBottom() {
        let origin = TourLayout.cardOrigin(spot: CGRect(x: 6, y: 852, width: 160, height: 40), card: card, in: window)
        #expect(origin.y == CGFloat(900 - 180 - 16))
        #expect(origin.x == CGFloat(6 + 160 + 28))
    }

    @Test("右边放不下（侧栏很宽或窗口很窄）：放到左边")
    func flipsLeft() {
        let origin = TourLayout.cardOrigin(spot: CGRect(x: 900, y: 10, width: 44, height: 40), card: card, in: CGSize(width: 1100, height: 900))
        #expect(origin.x == CGFloat(900 - 28 - 320))
    }

    @Test("讲到的那块不在界面上（侧栏收起来了）：卡放在窗口中间")
    func centeredWithoutSpot() {
        let origin = TourLayout.cardOrigin(spot: nil, card: card, in: window)
        #expect(origin == CGPoint(x: (1440 - 320) / 2, y: (900 - 180) / 2))
    }
}

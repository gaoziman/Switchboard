import CoreGraphics
import Testing
@testable import Screens

/// 关标签确认气泡摆在哪：箭头对着标签的 ×，气泡不出窗口；标签不在界面上就挂在标签栏下面正中、不画箭头
@MainActor
@Suite("关闭标签气泡的位置")
struct CloseTabBubbleTests {
    private let window = CGSize(width: 1200, height: 800)

    @Test("箭头对着 ×（标签右边内缩 17），气泡贴着标签下沿")
    func pointsAtCloseButton() {
        let tab = CGRect(x: 500, y: 30, width: 180, height: 26)
        let p = CloseTabLayer.place(tab: tab, bubbleWidth: 260, in: window)
        #expect(p.x + p.arrowX! == tab.maxX - 17)
        #expect(p.y == tab.maxY + 2)
    }

    @Test("靠窗口左右边的标签：气泡留在窗口里，箭头仍对着 ×")
    func staysInsideWindow() {
        let left = CGRect(x: 10, y: 30, width: 120, height: 26)
        let l = CloseTabLayer.place(tab: left, bubbleWidth: 260, in: window)
        #expect(l.x == 8)
        #expect(l.x + l.arrowX! == left.maxX - 17)
        // 最右边的标签右边还有「+」（约 40pt）
        let right = CGRect(x: 1030, y: 30, width: 120, height: 26)
        let r = CloseTabLayer.place(tab: right, bubbleWidth: 260, in: window)
        #expect(r.x + 260 <= window.width - 8)
        #expect(r.x + r.arrowX! == right.maxX - 17)
    }

    @Test("× 贴到窗口边上（对不准也不能画到圆角外）：箭头留在气泡里")
    func arrowStaysOnBubble() {
        let edge = CGRect(x: 1080, y: 30, width: 120, height: 26)
        let p = CloseTabLayer.place(tab: edge, bubbleWidth: 260, in: window)
        #expect((14...246).contains(p.arrowX!))
    }

    @Test("标签不在界面上：标签栏下面正中，不画箭头")
    func fallsBackToCenter() {
        let p = CloseTabLayer.place(tab: nil, bubbleWidth: 260, in: window)
        #expect(p.arrowX == nil)
        #expect(p.x == (window.width - 260) / 2)
    }
}

#if os(macOS)
import AppKit

/// 菜单栏状态图标（references/mac-native.md §5「菜单栏图标」）。
///
/// 规格（Apple HIG + 菜单栏实测）：画布 18×18pt、图形约 14–16pt、线宽 1.25–1.5pt、**模板图**（isTemplate = true，系统按菜单栏明暗自动反色）、
/// 线条图形、细节少（菜单栏上只有 16pt，三个以上的小部件就糊成一团）。
/// 2026-10-19 用户反馈：直接用 SF Symbol `tray.and.arrow.down` 太粗太满、像通用图标——所以：
/// - logo 定稿后（logo.mjs --sync 写了 Resources/Brand/symbol.png）：用品牌符号缩成 16pt 模板图；
/// - 没定稿前：用下面按形态手绘的细线图标，不用系统默认粗细的 SF Symbol。
public enum StatusIcon {
    public enum Glyph: Sendable { case shelf, spark, search, window }

    /// 状态栏按钮用的图：有品牌符号优先用品牌符号
    @MainActor public static func image(_ fallback: Glyph) -> NSImage {
        if let url = Bundle.module.url(forResource: "symbol", withExtension: "png", subdirectory: "Brand"),
           let brand = NSImage(contentsOf: url) {
            let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { r in
                brand.draw(in: r.insetBy(dx: 1.5, dy: 1.5))
                return true
            }
            img.isTemplate = true
            return img
        }
        return drawn(fallback)
    }

    /// 手绘细线图标（1.4pt，圆头圆角，18pt 画布）
    public static func drawn(_ g: Glyph) -> NSImage {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            NSColor.black.setStroke()
            func stroke(_ p: NSBezierPath) { p.lineWidth = 1.4; p.lineCapStyle = .round; p.lineJoinStyle = .round; p.stroke() }
            switch g {
            case .shelf:
                // 两张错开叠放的卡片 + 下面一道托架：「先放一放」
                let back = NSBezierPath(roundedRect: NSRect(x: 5.5, y: 2.8, width: 9, height: 7), xRadius: 1.8, yRadius: 1.8)
                stroke(back)
                let front = NSBezierPath(roundedRect: NSRect(x: 3.5, y: 5.3, width: 9, height: 7), xRadius: 1.8, yRadius: 1.8)
                // 前卡挡住后卡的线：模板图只看 alpha，不能用白色去盖，要把前卡区域擦成透明
                NSGraphicsContext.current?.compositingOperation = .clear; front.fill(); NSGraphicsContext.current?.compositingOperation = .sourceOver
                stroke(front)
                let tray = NSBezierPath()
                tray.move(to: NSPoint(x: 2.2, y: 13.2)); tray.line(to: NSPoint(x: 2.2, y: 15.2)); tray.line(to: NSPoint(x: 15.8, y: 15.2)); tray.line(to: NSPoint(x: 15.8, y: 13.2))
                stroke(tray)
            case .spark:
                let p = NSBezierPath()
                p.move(to: NSPoint(x: 9, y: 2)); p.curve(to: NSPoint(x: 16, y: 9), controlPoint1: NSPoint(x: 9.6, y: 7.2), controlPoint2: NSPoint(x: 10.8, y: 8.4))
                p.curve(to: NSPoint(x: 9, y: 16), controlPoint1: NSPoint(x: 10.8, y: 9.6), controlPoint2: NSPoint(x: 9.6, y: 10.8))
                p.curve(to: NSPoint(x: 2, y: 9), controlPoint1: NSPoint(x: 8.4, y: 10.8), controlPoint2: NSPoint(x: 7.2, y: 9.6))
                p.curve(to: NSPoint(x: 9, y: 2), controlPoint1: NSPoint(x: 7.2, y: 8.4), controlPoint2: NSPoint(x: 8.4, y: 7.2))
                stroke(p)
            case .search:
                stroke(NSBezierPath(ovalIn: NSRect(x: 2.5, y: 2.5, width: 9.5, height: 9.5)))
                let h = NSBezierPath(); h.move(to: NSPoint(x: 11, y: 11)); h.line(to: NSPoint(x: 15.5, y: 15.5)); stroke(h)
            case .window:
                stroke(NSBezierPath(roundedRect: NSRect(x: 2.5, y: 3.5, width: 13, height: 11), xRadius: 2.2, yRadius: 2.2))
                let bar = NSBezierPath(); bar.move(to: NSPoint(x: 2.5, y: 6.8)); bar.line(to: NSPoint(x: 15.5, y: 6.8)); stroke(bar)
            }
            return true
        }
        img.isTemplate = true
        return img
    }
}
#endif

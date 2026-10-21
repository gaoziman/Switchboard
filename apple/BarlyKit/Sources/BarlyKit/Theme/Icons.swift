import SwiftUI

/// 线性图标：SF Symbols 的非 fill 变体，按尺寸选字重，模拟 Lucide 1.5 描边。
/// 桌面 16、移动 18–20；颜色默认跟文字次级色。
public struct BarlyIcon: View {
    let name: String
    let size: CGFloat
    let color: Color?
    public init(_ name: String, size: CGFloat = 16, color: Color? = nil) {
        self.name = name; self.size = size; self.color = color
    }
    @Environment(\.barly) private var t
    public var body: some View {
        Group {
            switch name {
            case "barly.menu": MenuGlyph().stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            case "barly.menu2": Menu2Glyph().stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            case "barly.sparkle": SparkleGlyph().stroke(style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
            case "barly.wave": WaveGlyph().stroke(style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            case "barly.radiant": RadiantGlyph().stroke(style: StrokeStyle(lineWidth: max(1.2, size / 11), lineCap: .round))
            default:
                Image(systemName: name)
                    .font(.system(size: size * 0.96, weight: size >= 20 ? .light : .regular))
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
        .foregroundStyle(color ?? t.text2)
    }
}

/// Bimbo 的「≡」变体：上长、中短、下更短，左对齐
struct MenuGlyph: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        for (i, f) in [0.85, 0.62, 0.42].enumerated() {
            let y = r.minY + h * (0.28 + 0.22 * Double(i))
            p.move(to: CGPoint(x: r.minX + w * 0.1, y: y))
            p.addLine(to: CGPoint(x: r.minX + w * (0.1 + f * 0.8), y: y))
        }
        return p
    }
}

/// Lumix 的两条横线
struct Menu2Glyph: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        for y in [0.4, 0.62] {
            p.move(to: CGPoint(x: r.minX + r.width * 0.08, y: r.minY + r.height * y))
            p.addLine(to: CGPoint(x: r.maxX - r.width * 0.08, y: r.minY + r.height * y))
        }
        return p
    }
}

/// 八芒「闪光」：四长四短射线 + 中心点（Plus 权益图标）
struct SparkleGlyph: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY), R = min(r.width, r.height) / 2
        for i in 0..<8 {
            let a = Double(i) * .pi / 4
            let long = i % 2 == 0
            let r0 = R * 0.34, r1 = long ? R * 0.98 : R * 0.66
            p.move(to: CGPoint(x: c.x + cos(a) * r0, y: c.y + sin(a) * r0))
            p.addLine(to: CGPoint(x: c.x + cos(a) * r1, y: c.y + sin(a) * r1))
        }
        p.addEllipse(in: CGRect(x: c.x - R * 0.1, y: c.y - R * 0.1, width: R * 0.2, height: R * 0.2))
        return p
    }
}

/// 7 根竖条声波（中高边低）
struct WaveGlyph: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let hs: [Double] = [0.3, 0.55, 0.8, 1.0, 0.8, 0.55, 0.3]
        for (i, h) in hs.enumerated() {
            let x = r.minX + r.width * (0.08 + 0.84 * Double(i) / 6)
            let half = r.height * 0.42 * h
            p.move(to: CGPoint(x: x, y: r.midY - half))
            p.addLine(to: CGPoint(x: x, y: r.midY + half))
        }
        return p
    }
}

/// 放射光芒标（12 芒长短交替）——logo / 「Results」图标 / 生成中 spinner
struct RadiantGlyph: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY), R = min(r.width, r.height) / 2
        for i in 0..<12 {
            let a = Double(i) * .pi / 6 - .pi / 2
            let r0 = R * 0.3, r1 = i % 2 == 0 ? R * 0.95 : R * 0.72
            p.move(to: CGPoint(x: c.x + cos(a) * r0, y: c.y + sin(a) * r0))
            p.addLine(to: CGPoint(x: c.x + cos(a) * r1, y: c.y + sin(a) * r1))
        }
        return p
    }
}

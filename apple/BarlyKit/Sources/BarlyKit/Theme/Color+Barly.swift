import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Color(hex:) —— Theme.generated.swift 依赖它

public extension Color {
    /// `Color(hex: 0x178C4E)`，可选不透明度
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    /// `Color(hex: "#178C4E")` / `"178C4E"` / `"#178C4E80"`
    init(hex string: String) {
        var s = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        if s.count == 8 {
            self.init(hex: UInt32(v >> 8), opacity: Double(v & 0xFF) / 255)
        } else {
            self.init(hex: UInt32(v & 0xFFFFFF))
        }
    }
}

// MARK: - 取分量 / 混色 / HSL（派生令牌用）

public struct BarlyRGBA: Sendable, Equatable {
    public var r: Double, g: Double, b: Double, a: Double
    public init(r: Double, g: Double, b: Double, a: Double = 1) { self.r = r; self.g = g; self.b = b; self.a = a }
    public var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
    /// WCAG 相对亮度
    public var luminance: Double {
        func lin(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }
    public func mixed(with o: BarlyRGBA, _ t: Double) -> BarlyRGBA {
        BarlyRGBA(r: r + (o.r - r) * t, g: g + (o.g - g) * t, b: b + (o.b - b) * t, a: a + (o.a - a) * t)
    }
    /// h 0–360, s/l 0–1
    public var hsl: (h: Double, s: Double, l: Double) {
        let mx = max(r, g, b), mn = min(r, g, b)
        let l = (mx + mn) / 2
        guard mx != mn else { return (0, 0, l) }
        let d = mx - mn
        let s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn)
        var h: Double
        if mx == r { h = (g - b) / d + (g < b ? 6 : 0) }
        else if mx == g { h = (b - r) / d + 2 }
        else { h = (r - g) / d + 4 }
        return (h * 60, s, l)
    }
    public static func fromHSL(_ h: Double, _ s: Double, _ l: Double, a: Double = 1) -> BarlyRGBA {
        let hh = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 360
        func f(_ p: Double, _ q: Double, _ t0: Double) -> Double {
            var t = t0
            if t < 0 { t += 1 }; if t > 1 { t -= 1 }
            if t < 1 / 6 { return p + (q - p) * 6 * t }
            if t < 1 / 2 { return q }
            if t < 2 / 3 { return p + (q - p) * (2 / 3 - t) * 6 }
            return p
        }
        if s == 0 { return BarlyRGBA(r: l, g: l, b: l, a: a) }
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q
        return BarlyRGBA(r: f(p, q, hh + 1 / 3), g: f(p, q, hh), b: f(p, q, hh - 1 / 3), a: a)
    }
}

public extension Color {
    /// sRGB 分量（经平台颜色转换）
    var barlyRGBA: BarlyRGBA {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return BarlyRGBA(r: Double(r), g: Double(g), b: Double(b), a: Double(a))
        #else
        let c = NSColor(self).usingColorSpace(.sRGB) ?? .black
        return BarlyRGBA(r: Double(c.redComponent), g: Double(c.greenComponent), b: Double(c.blueComponent), a: Double(c.alphaComponent))
        #endif
    }

    /// 线性混色：t=0 是自己，t=1 是 other
    func barlyMix(_ other: Color, _ t: Double) -> Color {
        barlyRGBA.mixed(with: other.barlyRGBA, t).color
    }

    /// 色相旋转 + 可选调明度/饱和度
    func barlyShift(hue dh: Double = 0, sat ds: Double = 0, light dl: Double = 0) -> Color {
        let c = barlyRGBA
        let (h, s, l) = c.hsl
        return BarlyRGBA.fromHSL(h + dh, min(1, max(0, s + ds)), min(1, max(0, l + dl)), a: c.a).color
    }

    var barlyLuminance: Double { barlyRGBA.luminance }
}

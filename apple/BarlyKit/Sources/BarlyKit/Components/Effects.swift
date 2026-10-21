import SwiftUI

// MARK: - 光球 Orb（mobile-bimbo 2.7 的 5 步做法）

public enum OrbTone: Sendable {
    /// 玻璃珠：饱和的强调色（Lumeo 80px 紫珠）
    case vivid
    /// 淡彩：强调色冲淡到 mint / 水青，高光偏黄、暗部偏青（Bimbo Plus 164pt）
    case pale
    /// 浅色用 pale、深色用 vivid
    case auto
}

public struct Orb: View {
    let diameter: CGFloat
    let tone: OrbTone
    @Environment(\.barly) private var t
    public init(diameter: CGFloat = 80, tone: OrbTone = .vivid) { self.diameter = diameter; self.tone = tone }

    private var resolvedTone: OrbTone { tone == .auto ? (t.isDark ? .vivid : .pale) : tone }

    private var stops: (hi: Color, body: Color, shade: Color, glow: Color, glow2: Color) {
        switch resolvedTone {
        case .vivid:
            return (t.orbHighlight, t.orbMid, t.orbShadow, t.orbGlow.opacity(1), t.nameGradientTo)
        case .pale, .auto:
            let a = t.accent
            let (h, _, _) = a.barlyRGBA.hsl
            if h < 60 || h > 330 {
                // 暖色：桃色主体、奶黄高光、珊瑚暗部
                return (a.barlyShift(hue: 30, sat: -0.1, light: 0.42).barlyMix(.white, 0.35),
                        a.barlyShift(hue: 8, sat: -0.2, light: 0.36),
                        a.barlyShift(hue: -6, sat: -0.15, light: 0.22),
                        a.barlyShift(hue: 0, sat: 0, light: 0.25),
                        a.barlyShift(hue: 30, sat: 0.1, light: 0.35))
            }
            // 冷色（Bimbo 实测）：高光偏黄绿、主体水青、暗部青蓝
            return (a.barlyShift(hue: -55, sat: -0.25, light: 0.5).barlyMix(.white, 0.25),
                    a.barlyShift(hue: 22, sat: -0.35, light: 0.48),
                    a.barlyShift(hue: 40, sat: -0.3, light: 0.3),
                    a.barlyShift(hue: 0, sat: 0.05, light: 0.32),
                    a.barlyShift(hue: 60, sat: 0.1, light: 0.4))
        }
    }

    public var body: some View {
        if BarlyFamily.current.isBarly || BarlyFamily.current == .noir || BarlyFamily.current == .gallery { glossy } else { FamilyOrb(diameter: diameter) }
    }

    private var glossy: some View {
        let d = diameter
        let s = stops
        return ZStack {
            // 大范围极淡光环（Lumeo 球四周的浅紫底）
            Circle().fill(s.glow.opacity(t.isDark ? 0.10 : 0.07)).frame(width: d * 2.3, height: d * 2.3).blur(radius: d * 0.4)
            // ④ 外层同色光晕：放大 1.4×、模糊、向下偏移（光晕不往上走）
            Circle().fill(s.glow.opacity(resolvedTone == .pale ? 0.32 : 0.30))
                .frame(width: d * 1.15, height: d * 1.0)
                .blur(radius: d * (resolvedTone == .pale ? 0.3 : 0.22))
                .offset(y: d * 0.2)
            if resolvedTone == .pale {
                Circle().fill(s.glow2.opacity(0.22)).frame(width: d * 0.9, height: d * 0.8)
                    .blur(radius: d * 0.3).offset(x: d * 0.32, y: d * 0.24)
            }
            // ① 主体：左上高光 → 中心 → 右下暗
            Circle().fill(RadialGradient(colors: [s.hi, s.body, s.shade], center: UnitPoint(x: 0.34, y: 0.28),
                                         startRadius: 0, endRadius: d * 0.78))
                .frame(width: d, height: d)
            // ② 左上柔和高光
            Circle().fill(RadialGradient(colors: [.white.opacity(resolvedTone == .pale ? 0.55 : 0.45), .clear],
                                         center: UnitPoint(x: 0.3, y: 0.26), startRadius: 0, endRadius: d * 0.4))
                .frame(width: d, height: d)
            // 右下月牙反光（玻璃珠质感）
            Circle().trim(from: 0.05, to: 0.22).stroke(.white.opacity(0.55), style: StrokeStyle(lineWidth: d * 0.035, lineCap: .round))
                .frame(width: d * 0.8, height: d * 0.8)
                .blur(radius: d * 0.012)
            // ③ 白色边缘光
            Circle().strokeBorder(.white.opacity(0.6), lineWidth: max(1, d * 0.012))
                .frame(width: d, height: d).blur(radius: 0.6)
            Circle().strokeBorder(.white.opacity(0.35), lineWidth: d * 0.04)
                .frame(width: d, height: d).blur(radius: d * 0.03)
                .mask(Circle().frame(width: d, height: d))
        }
        .frame(width: d, height: d)
    }
}

/// 风格族的「光球」：玻璃珠是 Barly 的 AI 母题，其他风格族换成各自的几何记号
/// soft = 三个粉彩圆叠放；editorial = 土色细同心环 + 实心小点（像印章）；swiss / press = 近黑实心圆；
/// brutal = 强调色圆 + 2px 黑框 + 硬偏移；flood = 前景色圆环；console = 发丝同心环 + 强调色点
struct FamilyOrb: View {
    let diameter: CGFloat
    @Environment(\.barly) private var t
    var body: some View {
        let d = diameter
        ZStack {
            switch BarlyFamily.current {
            case .soft:
                let p = t.pastels
                Circle().fill(p[0]).frame(width: d * 0.62, height: d * 0.62).offset(x: -d * 0.16, y: -d * 0.1)
                Circle().fill(p[1]).frame(width: d * 0.55, height: d * 0.55).offset(x: d * 0.18, y: -d * 0.04)
                Circle().fill(p[2]).frame(width: d * 0.5, height: d * 0.5).offset(x: -d * 0.02, y: d * 0.2)
            case .editorial:
                ForEach(0..<4, id: \.self) { i in
                    Circle().strokeBorder(t.accentText.opacity(0.85 - Double(i) * 0.18), lineWidth: 1)
                        .frame(width: d * (1 - CGFloat(i) * 0.2), height: d * (1 - CGFloat(i) * 0.2))
                }
                Circle().fill(t.accentText).frame(width: d * 0.16, height: d * 0.16)
            case .swiss, .press:
                Circle().fill(t.text).frame(width: d * 0.7, height: d * 0.7)
            case .brutal:
                Circle().fill(t.text).frame(width: d * 0.7, height: d * 0.7).offset(x: 5, y: 5)
                Circle().fill(t.accent).frame(width: d * 0.7, height: d * 0.7).overlay(Circle().strokeBorder(t.text, lineWidth: 2))
            case .flood:
                Circle().strokeBorder(t.text, lineWidth: 1.5).frame(width: d * 0.8, height: d * 0.8)
                Circle().fill(t.text).frame(width: d * 0.22, height: d * 0.22)
            default:
                ForEach(0..<3, id: \.self) { i in
                    Circle().strokeBorder(t.border, lineWidth: 1).frame(width: d * (1 - CGFloat(i) * 0.28), height: d * (1 - CGFloat(i) * 0.28))
                }
                Circle().fill(t.accent).frame(width: d * 0.12, height: d * 0.12)
            }
        }
        .frame(width: d, height: d)
    }
}

// MARK: - 底部发光地平线（语音模式）

public enum GlowStyle: Sendable {
    /// 强调色 → 邻近暖/冷色横向渐变 × 由下往上消失（Lumix 橙→黄，峰值 ≈40%）
    case horizon
    /// 浅色淡彩：mint → 淡蓝对角光（Bimbo 语音底部）
    case pastel
    /// 暖色强调 → horizon，冷色 → pastel
    case auto
}

public struct GlowHorizon: View {
    let style: GlowStyle
    let heightFraction: CGFloat
    let intensity: Double
    @Environment(\.barly) private var t
    public init(_ style: GlowStyle = .horizon, heightFraction: CGFloat = 0.35, intensity: Double = 1) {
        self.style = style; self.heightFraction = heightFraction; self.intensity = intensity
    }
    public var body: some View {
        GeometryReader { g in
            let h = g.size.height * heightFraction
            let (hue0, _, _) = t.accent.barlyRGBA.hsl
            let style: GlowStyle = self.style != .auto ? self.style : ((hue0 < 60 || hue0 > 330) ? .horizon : .pastel)
            let colors: [Color] = {
                switch style {
                case .horizon:
                    let (hh, _, _) = t.accent.barlyRGBA.hsl
                    let warm = hh < 60 || hh > 330
                    return [t.accent, t.accent.barlyShift(hue: warm ? 32 : 40, sat: 0.1, light: warm ? 0.08 : 0.15)]
                case .pastel, .auto:
                    return [t.accent.barlyShift(hue: 0, sat: -0.1, light: t.isDark ? 0.42 : 0.55),
                            t.accent.barlyShift(hue: 55, sat: -0.35, light: t.isDark ? 0.45 : 0.6)]
                }
            }()
            let peak = (style == .horizon ? 0.42 : (t.isDark ? 0.9 : 0.85)) * intensity
            LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
                .mask(LinearGradient(stops: [.init(color: .clear, location: 0),
                                             .init(color: .black.opacity(peak * 0.25), location: 0.5),
                                             .init(color: .black.opacity(peak), location: 1)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(height: h)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .allowsHitTesting(false)
    }
}

/// 页面级顶部淡彩（Bimbo：顶部 ≈6% 强调色竖向渐变，60% 屏高归白）
public struct TopWash: View {
    let amount: Double
    @Environment(\.barly) private var t
    public init(amount: Double = 0.06) { self.amount = amount }
    public var body: some View {
        // 顶部强调色淡彩是 Barly 的母题；风格族（纸 / 黑 / 满铺色）保持底色干净
        if !BarlyFamily.current.isBarly { t.bg } else {
        LinearGradient(stops: [.init(color: t.bg.barlyMix(t.accent, t.isDark ? amount * 0.4 : amount), location: 0),
                               .init(color: t.bg.barlyMix(t.accent, (t.isDark ? amount * 0.4 : amount) * 0.25), location: 0.4),
                               .init(color: t.bg, location: 0.62)],
                       startPoint: .top, endPoint: .bottom)
        }
    }
}

// MARK: - 粒子圆环（Lumix 语音可视化：2pt 方点网格 + 环带渐隐）

public struct ParticleRing: View {
    let diameter: CGFloat
    let band: CGFloat
    let dot: CGFloat
    let grid: CGFloat
    let seed: UInt64
    let color: Color?
    @Environment(\.barly) private var t
    public init(diameter: CGFloat = 286, band: CGFloat = 70, dot: CGFloat = 2, grid: CGFloat = 4.5, seed: UInt64 = 7, color: Color? = nil) {
        self.diameter = diameter; self.band = band; self.dot = dot; self.grid = grid; self.seed = seed; self.color = color
    }
    public var body: some View {
        let c = color ?? t.text
        Canvas { ctx, size in
            let cx = size.width / 2, cy = size.height / 2
            let rOuter = diameter / 2, rMid = rOuter - band / 2
            var rng = SplitMix(seed: seed)
            var y = cy - rOuter
            while y <= cy + rOuter {
                var x = cx - rOuter
                while x <= cx + rOuter {
                    let dx = x - cx, dy = y - cy
                    let r = sqrt(dx * dx + dy * dy)
                    let n = Double(rng.next() % 10_000) / 10_000
                    // 环带中段最密最亮，内外缘按高斯衰减 + 随机抖动渐隐
                    let z = Double((r - rMid) / (band * 0.5))
                    let fall = exp(-z * z * 1.25)
                    let ang = atan2(dy, dx)
                    let wobble = 0.82 + 0.18 * sin(ang * 3 + Double(seed)) // 不同 seed = 不同帧
                    if n < fall * wobble * 1.25 {
                        let a = (0.25 + 0.75 * Double(rng.next() % 1000) / 1000) * min(1, fall * 1.7)
                        ctx.fill(Path(CGRect(x: x - dot / 2, y: y - dot / 2, width: dot, height: dot)), with: .color(c.opacity(a)))
                    }
                    x += grid
                }
                y += grid
            }
        }
        .frame(width: diameter + 8, height: diameter + 8)
        .allowsHitTesting(false)
    }
}

struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// 点阵底纹（过程卡右上角，向左下渐隐）
public struct DotGrid: View {
    let spacing: CGFloat
    @Environment(\.barly) private var t
    public init(spacing: CGFloat = 4) { self.spacing = spacing }
    public var body: some View {
        Canvas { ctx, size in
            var rng = SplitMix(seed: 3)
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    let fade = Double((x / size.width) * (1 - y / size.height))
                    if Double(rng.next() % 100) / 100 < fade * 0.8 {
                        ctx.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)), with: .color(t.text.opacity(0.22 * fade)))
                    }
                    x += spacing
                }
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }
}

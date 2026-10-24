#if os(macOS)
import AppKit
#endif
import SwiftUI
import BarlyKit

/// 状态灯（接线台的信号灯）：只用一个强调色，靠形状区分。工作中 = 实心点，等你回答 = 实心点 + 一圈呼吸光晕，
/// 没看过的完成 = 强调色空心圈，回合结束 = 灰勾，已结束 = 灰色空心圈（灰用 text3：text4 在深色底上只有 1.9:1）
public struct ActivityLamp: View {
    let activity: Activity
    var size: CGFloat
    @Environment(\.barly) private var t
    @Environment(\.barlySnapshot) private var snapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(_ activity: Activity, size: CGFloat = 7) {
        self.activity = activity
        self.size = size
    }

    /// 图形的直径：比旧的圆点大一圈，形状才看得清
    private var glyph: CGFloat { size + 5 }

    public var body: some View {
        Group {
            switch activity {
            case .notRunning: EmptyView()
            case .working: Circle().fill(t.accent).frame(width: dot, height: dot)
            case .waitingForAnswer: halo
            case .idle:
                Image(systemName: "checkmark")
                    .font(.system(size: glyph * 0.7, weight: .semibold))
                    .foregroundStyle(t.text3)
            case .doneUnseen: Circle().strokeBorder(t.accent, lineWidth: 1.5).frame(width: dot + 2, height: dot + 2)
            case .ended: Circle().strokeBorder(t.text3, lineWidth: 1.2).frame(width: dot + 1, height: dot + 1)
            }
        }
        .frame(width: glyph, height: glyph)
        .help(activity.label)
        .accessibilityLabel(activity.label)
    }

    /// 实心点的直径
    private var dot: CGFloat { size }

    /// 等你回答：芯 + 光晕。光晕 1.6 秒呼吸一次；截图和「减弱动态效果」时停在最亮
    @ViewBuilder private var halo: some View {
        if snapshot || reduceMotion {
            HaloLamp(dot: dot, glyph: glyph, phase: 1)
        } else {
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                let x = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.6) / 1.6
                HaloLamp(dot: dot, glyph: glyph, phase: 0.5 - 0.5 * cos(x * 2 * .pi))
            }
        }
    }
}

private struct HaloLamp: View {
    let dot: CGFloat
    let glyph: CGFloat
    /// 0…1，光晕的亮度
    let phase: Double
    @Environment(\.barly) private var t

    var body: some View {
        ZStack {
            Circle().fill(t.accent.opacity(0.12 + 0.18 * phase)).frame(width: glyph + 2, height: glyph + 2)
            Circle().fill(t.accent).frame(width: dot, height: dot)
        }
    }
}

/// CLI 小标记：每种 CLI 一个小图形，全部单色灰，不和状态灯抢颜色（屏上的彩色只留给状态和组色）
public struct CLIMark: View {
    let cli: CLIKind
    var size: CGFloat
    /// nil = 次要灰；选中的卡片里传强调色
    var color: Color?
    @Environment(\.barly) private var t

    public init(_ cli: CLIKind, size: CGFloat = 16, color: Color? = nil) {
        self.cli = cli
        self.size = size
        self.color = color
    }

    public var body: some View {
        glyph
            .frame(width: size, height: size)
            .help(cli.title)
            .accessibilityLabel(cli.title)
    }

    @ViewBuilder private var glyph: some View {
        switch cli {
        case .claude:
            Image(systemName: "asterisk").font(.system(size: size * 0.72, weight: .bold))
                .foregroundStyle(color ?? t.text3)
        case .codex:
            Image(systemName: "hexagon").font(.system(size: size * 0.66, weight: .semibold)).foregroundStyle(color ?? t.text3)
        case .opencode:
            Image(systemName: "curlybraces").font(.system(size: size * 0.62, weight: .semibold)).foregroundStyle(color ?? t.text3)
        case .omp:
            Text("π").font(.system(size: size * 0.8, weight: .semibold)).foregroundStyle(color ?? t.text3)
        }
    }
}

/// 没在运行的会话：显示多久前活跃
public struct RelativeAge: View {
    let date: Date
    @Environment(\.barly) private var t

    public init(_ date: Date) { self.date = date }

    public var body: some View {
        Text(Self.format(date)).barlyText(.product.caption.monospaced, color: t.text4)
    }

    public static func format(_ date: Date, now: Date = .now) -> String {
        let minutes = now.timeIntervalSince(date) / 60
        if minutes < 1 { return L("刚刚") }
        if minutes < 60 { return L("\(Int(minutes))分") }
        if minutes < 60 * 24 { return L("\(Int(minutes / 60))时") }
        if minutes < 60 * 48 { return L("昨天") }
        if minutes < 60 * 24 * 7 { return L("\(Int(minutes / 60 / 24))天") }
        let c = Calendar.current.dateComponents([.month, .day], from: date)
        return "\(c.month ?? 0)/\(c.day ?? 0)"
    }
}

/// 红绿灯占位：快照里画出来（真窗口里是系统的），app 里只让位
struct TrafficLights: View {
    @Environment(\.barlySnapshot) private var snapshot

    var body: some View {
        HStack(spacing: 8) {
            ForEach([UInt32(0xFF5F57), 0xFEBC2E, 0x28C840], id: \.self) { c in
                Circle().fill(Color(hex: c)).frame(width: 12, height: 12)
            }
        }
        .opacity(snapshot ? 1 : 0)
        .frame(width: 60, alignment: .leading)
    }
}

/// 图标按钮的小号版本：28pt，无底，悬停浅底（侧栏和标签栏用）
struct PaneIcon: View {
    let symbol: String
    let help: String
    var badge = false
    var action: () -> Void = {}
    @Environment(\.barly) private var t
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: BarlyScale.pt(14), weight: .regular))
                .foregroundStyle(hovered ? t.text : t.text2)
                .frame(width: BarlyScale.pt(28), height: BarlyScale.pt(28))
                .background(hovered ? t.fill2 : .clear, in: RoundedRectangle(cornerRadius: BarlyRadius.sm))
                .overlay(alignment: .topTrailing) {
                    if badge { Circle().fill(t.accent).frame(width: 6, height: 6).offset(x: -6, y: 6) }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .handCursor()
        .help(help)
        .accessibilityLabel(help)
    }
}

extension View {
    /// 可点处一律手型光标。用系统的 pointerStyle：NSCursor push / pop 在「悬停才出现、点完就消失」的元素上
    /// （标签的关闭按钮）收不到移出，光标栈不平衡，会一直是手型
    func handCursor() -> some View { modifier(HandCursor()) }

    /// 用点按手势做的按钮（为了不套一层 Button 改掉外观）：补上按钮语义和 VoiceOver 的「按下」，不然读屏只当它是文字
    func tapButton(_ label: String? = nil, perform action: @escaping () -> Void) -> some View {
        onTapGesture(perform: action)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, action)
            .modifier(OptionalAccessibilityLabel(label: label))
    }
}

/// 只在真窗口里加的修饰（拖放这类系统交互）：离屏截图（ImageRenderer）画不了它们，会把整行画成黄色占位块
struct LiveOnly<Base: View, Live: View>: View {
    let base: Base
    let transform: (Base) -> Live
    @Environment(\.barlySnapshot) private var snapshot

    var body: some View {
        if snapshot { base } else { transform(base) }
    }
}

extension View {
    func live<V: View>(@ViewBuilder _ transform: @escaping (Self) -> V) -> some View {
        LiveOnly(base: self, transform: transform)
    }
}

/// 离屏截图（ImageRenderer）画不了 pointerStyle，会画成黄色占位块：截图时不加
private struct HandCursor: ViewModifier {
    @Environment(\.barlySnapshot) private var snapshot

    func body(content: Content) -> some View {
        #if os(macOS)
        if snapshot { content } else { content.pointerStyle(.link) }
        #else
        content
        #endif
    }
}

private struct OptionalAccessibilityLabel: ViewModifier {
    let label: String?
    func body(content: Content) -> some View {
        if let label { content.accessibilityLabel(label) } else { content }
    }
}

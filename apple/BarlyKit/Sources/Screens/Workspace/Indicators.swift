#if os(macOS)
import AppKit
#endif
import SwiftUI
import BarlyKit

/// 状态灯：靠形状区分，不用记颜色。等你回答 = 强调色圆环 + 芯（全屏唯一的强调色，接线台的来电灯），
/// 工作中 = 转动的弧，没看过的完成 = 实心勾，回合结束 = 灰勾，已结束 = 空心圈
public struct ActivityLamp: View {
    let activity: Activity
    var size: CGFloat
    @Environment(\.barly) private var t
    @Environment(\.barlySnapshot) private var snapshot

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
            case .working: arc
            case .waitingForAnswer:
                Circle().strokeBorder(t.accent, lineWidth: 1.5)
                    .overlay(Circle().fill(t.accent).frame(width: glyph * 0.38, height: glyph * 0.38))
                    .frame(width: glyph, height: glyph)
            case .idle:
                Image(systemName: "checkmark")
                    .font(.system(size: glyph * 0.78, weight: .semibold))
                    .foregroundStyle(t.text3)
            case .doneUnseen:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: glyph, weight: .regular))
                    .foregroundStyle(t.text)
            case .ended: Circle().strokeBorder(t.text4, lineWidth: 1.2).frame(width: glyph - 2, height: glyph - 2)
            }
        }
        .frame(width: glyph, height: glyph)
        .help(activity.label)
        .accessibilityLabel(activity.label)
    }

    @ViewBuilder private var arc: some View {
        if snapshot {
            WorkingArc(size: glyph - 1, angle: -30)
        } else {
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                WorkingArc(size: glyph - 1,
                           angle: context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.1) / 1.1 * 360)
            }
        }
    }
}

private struct WorkingArc: View {
    let size: CGFloat
    let angle: Double
    @Environment(\.barly) private var t

    var body: some View {
        Circle().trim(from: 0, to: 0.72)
            .stroke(t.text2, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(angle))
    }
}

/// CLI 小标记：每种 CLI 一个小图形。只有 Claude 用它自己的珊瑚色星号，其余单色，不和状态灯抢颜色
public struct CLIMark: View {
    let cli: CLIKind
    var size: CGFloat
    @Environment(\.barly) private var t

    public init(_ cli: CLIKind, size: CGFloat = 16) {
        self.cli = cli
        self.size = size
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
                .foregroundStyle(Color(hex: t.isDark ? 0xE0876A : 0xC96442))
        case .codex:
            Image(systemName: "hexagon").font(.system(size: size * 0.66, weight: .semibold)).foregroundStyle(t.text3)
        case .opencode:
            Image(systemName: "curlybraces").font(.system(size: size * 0.62, weight: .semibold)).foregroundStyle(t.text3)
        case .omp:
            Text("π").font(.system(size: size * 0.8, weight: .semibold)).foregroundStyle(t.text3)
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
                .font(.system(size: 14, weight: .regular))
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
    /// 可点处一律手型光标（macOS 14 没有 pointerStyle，用 NSCursor）
    func handCursor() -> some View {
        #if os(macOS)
        onHover { inside in
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        #else
        self
        #endif
    }
}

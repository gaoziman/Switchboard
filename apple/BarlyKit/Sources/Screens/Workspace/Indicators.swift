#if os(macOS)
import AppKit
#endif
import SwiftUI
import BarlyKit

/// 状态灯（招牌：接线台的来电灯）。等你回答 = 强调色 + 光晕（全屏唯一会亮的强调色点，像来电时亮起的那盏灯），
/// 工作中 = 一段弧，没看过的完成 = 蓝，空闲 = 绿，已结束 = 空心圈
public struct ActivityLamp: View {
    let activity: Activity
    var size: CGFloat
    @Environment(\.barly) private var t
    @Environment(\.barlySnapshot) private var snapshot

    public init(_ activity: Activity, size: CGFloat = 7) {
        self.activity = activity
        self.size = size
    }

    public var body: some View {
        Group {
            switch activity {
            case .notRunning: EmptyView()
            case .working: arc
            case .waitingForAnswer:
                Circle().fill(t.accent).frame(width: size, height: size)
                    .background(Circle().fill(t.accent.opacity(0.28)).frame(width: size + 5, height: size + 5))
            case .idle: Circle().fill(t.success).frame(width: size, height: size)
            case .doneUnseen: Circle().fill(t.dataPos).frame(width: size, height: size)
            case .ended: Circle().strokeBorder(t.text4, lineWidth: 1.2).frame(width: size, height: size)
            }
        }
        .frame(width: size + 5, height: size + 5)
        .help(activity.label)
        .accessibilityLabel(activity.label)
    }

    @ViewBuilder private var arc: some View {
        if snapshot {
            WorkingArc(size: size + 2, angle: -30)
        } else {
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                WorkingArc(size: size + 2,
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
        Circle().trim(from: 0, to: 0.7)
            .stroke(t.text2, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(angle))
    }
}

/// CLI 小标记：两个字母的单色小方块，只靠字母区分（颜色留给状态灯）
public struct CLIMark: View {
    let cli: CLIKind
    var size: CGFloat
    @Environment(\.barly) private var t

    public init(_ cli: CLIKind, size: CGFloat = 16) {
        self.cli = cli
        self.size = size
    }

    public var body: some View {
        Text(cli.monogram)
            .font(.system(size: size * 0.5, weight: .bold, design: .monospaced))
            .foregroundStyle(t.text2)
            .frame(width: size, height: size)
            .background(t.fill2, in: RoundedRectangle(cornerRadius: 3))
            .help(cli.title)
            .accessibilityLabel(cli.title)
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
                .frame(width: 28, height: 28)
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

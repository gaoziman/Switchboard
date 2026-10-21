import SwiftUI

// MARK: - 应用页面模式：日记（Journal）与习惯打卡（Habits）
//
// 日记依据：lovable journal（「Sunday, 18 October」日期大标题 + 「1 day in a row」+ 单列阅读宽度的条目卡，按月分组）、note-taking-app。
//   单列 ≤ 680（iOS 满宽），日期大标题走 FamilyType.display（衬线族 = 衬线大字），心情 = 5 档圆点，习惯 = 一排小打点。
// 习惯依据：continuum-daily-habit-tracker（「Perfect day」+ 右上完成环 + 今日习惯行 + 连续天数「12d」+ 30 天方格）、okr-goal-tracker。
//   今日打卡行：完成 = 实心圆勾（强调色，状态色合法），未完成 = 1px 圈；热力格 = 数据色 5 级（dataFaint → dataDeep）。

public struct JournalEntry: Identifiable, Sendable {
    public let id: String
    public let date: String
    public let title: String
    public let body: String
    /// 0…4（nil = 没记心情）
    public let mood: Int?
    public let tags: [String]
    public let words: Int
    public init(_ id: String, date: String, title: String, body: String, mood: Int? = nil, tags: [String] = [], words: Int = 0) {
        self.id = id; self.date = date; self.title = title; self.body = body; self.mood = mood; self.tags = tags; self.words = words
    }
}

public enum JournalMood {
    public static let labels = ["Rough", "Low", "Okay", "Good", "Great"]
    public static let icons = ["cloud.rain", "cloud", "cloud.sun", "sun.min", "sun.max"]
}

extension BarlyPalette {
    /// 5 级数据色：空 → 最深
    func heat(_ level: Int) -> Color {
        switch level {
        case ...0: isDark ? fill2 : bgMuted   // 深色卡片是 fill0，空格用 fill2 才看得出格子
        case 1: dataFaint
        case 2: dataLight
        case 3: dataBase
        default: dataDeep
        }
    }
}

/// 日期大标题：「Sunday,」+「18 October」，下一行连续天数（风格族 display 字形）
public struct DateHeading: View {
    let weekday: String
    let date: String
    let note: String?
    let compact: Bool
    @Environment(\.barly) private var t
    public init(weekday: String, date: String, note: String? = nil, compact: Bool = BarlyPlatform.compact) {
        self.weekday = weekday; self.date = date; self.note = note; self.compact = compact
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let base = (compact ? BarlyTokens.Mobile.display.size(30) : BarlyTokens.Product.pageTitle.size(36)).leading(1.12).tracked(-0.02)
            // 手机宽度放不下一行：拆两行（Barly = 第二行降灰的双色标题）
            DisplayTitle(compact ? ["\(weekday),", date] : ["\(weekday), \(date)"], style: FamilyType.display(base, scale: false),
                         keyword: BarlyFamily.current.title == .serif ? date : nil)
            if let note {
                HStack(spacing: 6) {
                    BarlyIcon("flame", size: 13, color: t.text3)
                    Text(note).barlyText(compact ? .mobile.caption : .product.body, color: t.text2)
                }
            }
        }
    }
}

/// 心情选择：5 个圆点 + 下方文字，选中 = 数据色实心 + 主文字
public struct MoodScale: View {
    let selected: Int?
    let compact: Bool
    @Environment(\.barly) private var t
    public init(selected: Int?, compact: Bool = BarlyPlatform.compact) { self.selected = selected; self.compact = compact }
    public var body: some View {
        HStack(spacing: compact ? 0 : 10) {
            ForEach(0..<5, id: \.self) { i in
                let on = i == selected
                VStack(spacing: 6) {
                    // 选中 = 浅灰底 + 1.5pt 深色圈，图标带该档的数据色（不用实心色块，buttons.md §4）
                    Circle().fill(on ? t.selectedBg : .clear)
                        .overlay(Circle().strokeBorder(on ? t.selectedFg : t.borderStrong, lineWidth: on ? 1.5 : 1))
                        .overlay(BarlyIcon(JournalMood.icons[i], size: compact ? 17 : 15, color: on ? (i >= 2 ? t.heat(i) : t.selectedFg) : t.text3))
                        .frame(width: compact ? 44 : 38, height: compact ? 44 : 38)
                    Text(JournalMood.labels[i]).barlyText(.product.caption, color: on ? t.text : t.text3)
                }
                .frame(maxWidth: compact ? .infinity : nil)
            }
        }
    }
}

/// 习惯小打点：一个习惯一个 10pt 圆（完成 = 数据色，未完成 = 1px 圈）+ 名称
public struct HabitDots: View {
    let items: [(String, Bool)]
    @Environment(\.barly) private var t
    public init(_ items: [(String, Bool)]) { self.items = items }
    public var body: some View {
        HStack(spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, h in
                HStack(spacing: 6) {
                    Circle().fill(h.1 ? t.dataBase : .clear)
                        .overlay(Circle().strokeBorder(h.1 ? .clear : t.borderStrong, lineWidth: 1))
                        .frame(width: 10, height: 10)
                    Text(h.0).barlyText(.product.caption, color: h.1 ? t.text2 : t.text3)
                }
            }
        }
    }
}

/// 日记条目卡：标题 · 正文（3 行截断）· 日期 / 心情 / 字数
public struct JournalEntryCard: View {
    let entry: JournalEntry
    let compact: Bool
    let lines: Int
    @Environment(\.barly) private var t
    public init(_ entry: JournalEntry, compact: Bool = BarlyPlatform.compact, lines: Int = 3) { self.entry = entry; self.compact = compact; self.lines = lines }
    public var body: some View {
        Card(padding: compact ? 16 : 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.title).barlyText(FamilyType.pageTitle(compact ? BarlyTokens.Mobile.headline : BarlyTokens.Product.sectionTitle), color: t.text)
                Text(entry.body).barlyText(compact ? .mobile.body.size(15).leading(23) : .product.body.size(15).leading(24), color: t.text2)
                    .lineLimit(lines)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    BarlyIcon("book.closed", size: 12, color: t.text3)
                    Text(entry.date).barlyText(.product.caption, color: t.text3)
                    if let m = entry.mood {
                        Circle().fill(t.heat(m)).frame(width: 8, height: 8)
                        Text(JournalMood.labels[m]).barlyText(.product.caption, color: t.text3)
                    }
                    Spacer()
                    if entry.words > 0 { Text("\(entry.words) words").barlyText(FamilyType.numeric(BarlyTokens.Product.caption), color: t.text3) }
                }
                .padding(.top, 6)
                .overlay(alignment: .top) { Hairline().offset(y: -4) }
            }
        }
    }
}

// MARK: - Habits

public struct HabitItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let target: String
    public let icon: String
    public let done: Bool
    public let streak: Int
    /// 最近 N 天的完成强度 0…4（热力格用）
    public let history: [Int]
    public init(_ id: String, _ title: String, target: String, icon: String, done: Bool, streak: Int, history: [Int] = []) {
        self.id = id; self.title = title; self.target = target; self.icon = icon; self.done = done; self.streak = streak; self.history = history
    }
}

/// 今日打卡行：勾选圈 · 名称（完成后删除线降灰）+ 目标 · 连续天数
public struct HabitRow: View {
    let habit: HabitItem
    let compact: Bool
    @Environment(\.barly) private var t
    public init(_ habit: HabitItem, compact: Bool = BarlyPlatform.compact) { self.habit = habit; self.compact = compact }
    public var body: some View {
        Card(padding: compact ? 14 : 14, radius: BarlyRadius.lg) {
            HStack(spacing: 14) {
                // 完成 = 1.5pt 深色圈 + 深色勾，不填充（不用实心 ink，buttons.md §4；强调色留给完成环和热力格）
                Circle().fill(Color.clear)
                    .overlay(Circle().strokeBorder(habit.done ? t.selectedFg : t.borderStrong, lineWidth: 1.5))
                    .overlay { if habit.done { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(t.selectedFg) } }
                    .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.title).barlyText(compact ? .mobile.label.weight(500) : .product.body.weight(500), color: habit.done ? t.text3 : t.text)
                        .strikethrough(habit.done, color: t.text3)
                    HStack(spacing: 5) {
                        BarlyIcon(habit.icon, size: 11, color: t.text3)
                        Text(habit.target).barlyText(.product.caption, color: t.text3)
                    }
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(habit.streak)").barlyText(FamilyType.numeric((compact ? BarlyTokens.Mobile.headline : BarlyTokens.Product.cardTitle).size(17).weight(500)), color: t.text)
                    Text("d").barlyText(.product.caption, color: t.text3)
                }
            }
        }
    }
}

/// 完成环：「3/5 DONE」，进度 = 强调色描边（这一屏唯一的强调色块）
public struct ProgressRing: View {
    let done: Int
    let total: Int
    let size: CGFloat
    @Environment(\.barly) private var t
    public init(done: Int, total: Int, size: CGFloat = 56) { self.done = done; self.total = total; self.size = size }
    public var body: some View {
        ZStack {
            Circle().stroke(t.isDark ? t.fill2 : t.bgMuted, lineWidth: 4)
            Circle().trim(from: 0, to: CGFloat(done) / CGFloat(max(1, total)))
                .stroke(t.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(done)/\(total)").barlyText(FamilyType.numeric(BarlyTokens.Product.body.weight(600)), color: t.text)
                Text("DONE").barlyText(.product.caption.size(8).tracked(0.1), color: t.text3)
            }
        }
        .frame(width: size, height: size)
    }
}

/// 连续天数热力格：weeks 列 × 7 行（周一在上），最后一格 = 今天（主文字色细框）
public struct HabitHeatmap: View {
    let values: [Int]
    let cell: CGFloat
    let gap: CGFloat
    let showDays: Bool
    @Environment(\.barly) private var t
    public init(_ values: [Int], cell: CGFloat = 14, gap: CGFloat = 3, showDays: Bool = true) {
        self.values = values; self.cell = cell; self.gap = gap; self.showDays = showDays
    }
    public var body: some View {
        let weeks = Int((Double(values.count) / 7).rounded(.up))
        HStack(alignment: .top, spacing: gap) {
            if showDays {
                VStack(alignment: .trailing, spacing: gap) {
                    ForEach(0..<7, id: \.self) { d in
                        Text(d % 2 == 0 ? ["M", "", "W", "", "F", "", "S"][d] : "").barlyText(.product.caption.size(9), color: t.text3)
                            .frame(height: cell)
                    }
                }
                .padding(.trailing, 3)
            }
            ForEach(0..<weeks, id: \.self) { w in
                VStack(spacing: gap) {
                    ForEach(0..<7, id: \.self) { d in
                        let i = w * 7 + d
                        RoundedRectangle(cornerRadius: min(3, BarlyRadius.xs), style: .continuous)
                            .fill(i < values.count ? t.heat(values[i]) : .clear)
                            .overlay {
                                if i == values.count - 1 {
                                    RoundedRectangle(cornerRadius: min(3, BarlyRadius.xs), style: .continuous).strokeBorder(t.text, lineWidth: 1)
                                }
                            }
                            .frame(width: cell, height: cell)
                    }
                }
            }
        }
    }
}

/// 热力格图例：Less ▢▢▢▢▢ More
public struct HeatLegend: View {
    @Environment(\.barly) private var t
    public init() {}
    public var body: some View {
        HStack(spacing: 4) {
            Text("Less").barlyText(.product.caption.size(11), color: t.text3)
            ForEach(0..<5, id: \.self) { RoundedRectangle(cornerRadius: 2).fill(t.heat($0)).frame(width: 10, height: 10) }
            Text("More").barlyText(.product.caption.size(11), color: t.text3)
        }
    }
}

/// 小统计格：大数字（mono 数字族等宽）+ 标签
public struct StatTile: View {
    let value: String
    let label: String
    let compact: Bool
    @Environment(\.barly) private var t
    public init(_ value: String, _ label: String, compact: Bool = BarlyPlatform.compact) { self.value = value; self.label = label; self.compact = compact }
    public var body: some View {
        VStack(spacing: 2) {
            Text(value).barlyText(FamilyType.numeric((compact ? BarlyTokens.Mobile.title : BarlyTokens.Product.kpi).weight(500)), color: t.text)
            Text(label).barlyText(.product.caption, color: t.text3)
        }
        .frame(maxWidth: .infinity)
    }
}
